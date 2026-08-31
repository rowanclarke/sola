use std::ffi::{c_char, c_void};
use std::io::Cursor;
use std::path::Path;

use hnsw_rs::prelude::*;
use ndarray::{Array2, ArrayD, Axis};
use rkyv::deserialize;
use rkyv::rancor::Error as RkyvError;
use rkyv::vec::ArchivedVec;
use tokenizers::Tokenizer;
use tract_onnx::prelude::*;
use usfm::BookIdentifier;

use crate::error::SolaError;
use crate::ffi::{read_bytes, read_ref, read_str, run_ffi, write_vec};
use crate::log;
use crate::painter::ArchivedIndex;
use crate::reference::RefIndex;

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

struct Model {
    model: RunnableModel<TypedFact, Box<dyn TypedOp>, TypedModel>,
    tokenizer: Tokenizer,
}

struct SearchEngine {
    model: Model,
    // SAFETY: hnsw references mmap data owned by _io. Field drop order (declaration
    // order) ensures hnsw is dropped before _io. Lifetime erased via transmute
    // because this struct lives behind a raw FFI pointer and is never moved.
    hnsw: Hnsw<'static, f32, DistCosine>,
    _io: Box<HnswIo>,
    idx_bytes: Vec<u8>,
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn mean_pooling(last_hidden: &Tensor, attention_mask: &Tensor) -> Result<Tensor, SolaError> {
    let last_hidden: ArrayD<f32> = last_hidden
        .to_array_view::<f32>()
        .map_err(|e| SolaError::Search(e.to_string()))?
        .to_owned();
    let mask: ArrayD<f32> = attention_mask
        .to_array_view::<i64>()
        .map_err(|e| SolaError::Search(e.to_string()))?
        .to_owned()
        .mapv(|v| v as f32);

    let mask = mask.insert_axis(Axis(2));
    let expanded_mask = mask
        .broadcast(last_hidden.raw_dim())
        .ok_or(SolaError::Search("Shape mismatch in mean pooling".into()))?;

    let masked = &last_hidden * &expanded_mask;
    let sum_embeddings = masked.sum_axis(Axis(1));
    let sum_mask = expanded_mask.sum_axis(Axis(1)).mapv(|x| x.max(1e-9));

    let pooled = &sum_embeddings / &sum_mask;
    Ok(tract_ndarray::Array::into_tensor(pooled))
}

fn encode_query(model: &Model, query_text: &str) -> Result<ArrayD<f32>, SolaError> {
    let encoding = model
        .tokenizer
        .encode(query_text, true)
        .map_err(|e| SolaError::Search(e.to_string()))?;
    let token_ids: Vec<i64> = encoding.get_ids().iter().map(|&id| id as i64).collect();
    let mask_values: Vec<i64> = encoding
        .get_attention_mask()
        .iter()
        .map(|&m| m as i64)
        .collect();

    let input_ids = Array2::from_shape_vec((1, token_ids.len()), token_ids)
        .map_err(|e| SolaError::Search(e.to_string()))?;
    let attention_mask = Array2::from_shape_vec((1, mask_values.len()), mask_values)
        .map_err(|e| SolaError::Search(e.to_string()))?;

    let input_ids_tensor = tract_ndarray::Array::into_tensor(input_ids);
    let attention_mask_tensor = tract_ndarray::Array::into_tensor(attention_mask);

    let outputs = model
        .model
        .run(
            tvec![input_ids_tensor.clone(), attention_mask_tensor.clone()]
                .into_iter()
                .map(TValue::from)
                .collect(),
        )
        .map_err(|e| SolaError::Search(e.to_string()))?;
    let last_hidden = outputs[0].clone();
    let pooled = mean_pooling(&last_hidden, &attention_mask_tensor)?;
    let pooled_array: ArrayD<f32> = pooled
        .to_array_view::<f32>()
        .map_err(|e| SolaError::Search(e.to_string()))?
        .to_owned();
    let norm = pooled_array.mapv(|x| x.powi(2)).sum().sqrt().max(1e-9);
    Ok(&pooled_array / norm)
}

// ---------------------------------------------------------------------------
// FFI: Search engine
// ---------------------------------------------------------------------------

#[unsafe(no_mangle)]
pub extern "C" fn load_search_engine(
    model: *const u8,
    model_len: usize,
    tokenizer: *const u8,
    tokenizer_len: usize,
    hnsw_dir: *const u8,
    hnsw_dir_len: usize,
    hnsw_basename: *const u8,
    hnsw_basename_len: usize,
    idx: *const u8,
    idx_len: usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> *mut c_void {
    log!(
        "[FFI] load_search_engine: model={}B tokenizer={}B idx={}B",
        model_len,
        tokenizer_len,
        idx_len
    );
    run_ffi(
        || {
            let model_bytes = unsafe { read_bytes(model, model_len) };
            let tokenizer_bytes = unsafe { read_bytes(tokenizer, tokenizer_len) };
            let hnsw_dir_str = unsafe { read_str(hnsw_dir, hnsw_dir_len) };
            let hnsw_basename_str = unsafe { read_str(hnsw_basename, hnsw_basename_len) };
            let idx_bytes = unsafe { read_bytes(idx, idx_len) }.to_vec();

            let onnx_model = tract_onnx::onnx()
                .model_for_read(&mut Cursor::new(model_bytes))
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?
                .into_optimized()
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?
                .into_runnable()
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?;
            let tokenizer_model = Tokenizer::from_bytes(tokenizer_bytes)
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?;
            log!("[FFI] load_search_engine: model + tokenizer loaded");

            let dir = Path::new(hnsw_dir_str);
            let mut io = Box::new(HnswIo::new(dir, hnsw_basename_str));
            let hnsw: Hnsw<'_, f32, DistCosine> = io
                .load_hnsw()
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?;
            // SAFETY: io is kept alive in SearchEngine._io, dropped after hnsw
            let hnsw: Hnsw<'static, f32, DistCosine> = unsafe { std::mem::transmute(hnsw) };
            log!("[FFI] load_search_engine: HNSW index loaded");

            Ok(Box::into_raw(Box::new(SearchEngine {
                model: Model {
                    model: onnx_model,
                    tokenizer: tokenizer_model,
                },
                hnsw,
                _io: io,
                idx_bytes,
            })) as *mut c_void)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn search(
    engine: *const c_void,
    query: *const u8,
    query_len: usize,
    top_k: usize,
    ef: usize,
    out_ids: *mut *const usize,
    out_distances: *mut *const f32,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    log!(
        "[FFI] search: query_len={} top_k={} ef={}",
        query_len,
        top_k,
        ef
    );
    let results: Vec<_> = run_ffi(
        || {
            let engine = unsafe { read_ref::<SearchEngine>(engine) };
            let query_text = unsafe { read_str(query, query_len) }.trim();
            let normed = encode_query(&engine.model, query_text)?;
            let (emb_vec, _) = normed.into_raw_vec_and_offset();
            let neighbours = engine.hnsw.search(&emb_vec, top_k, ef);

            log!("[FFI] search: {} results", neighbours.len());
            Ok(neighbours
                .into_iter()
                .map(|n| (n.d_id, n.distance))
                .collect::<Vec<_>>())
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(vec![]);
    let ids: Vec<usize> = results.iter().map(|(id, _)| *id).collect();
    let distances: Vec<f32> = results.iter().map(|(_, d)| *d).collect();
    unsafe {
        write_vec(ids, out_ids, out_len);
        write_vec(distances, out_distances, out_len);
    }
}

/// Resolves one HNSW result id into the reference it points at, and the page
/// that reference was rendered on.
///
/// The semantic index (`idx_bytes`) is built separately from the rendered
/// output, so the two are matched on `(book, chapter, verse)` alone — never on
/// the display name, which the two sides can spell differently. The name shown
/// to the reader comes from [`RefIndex`], which borrows it for as long as the
/// index lives, so nothing here needs freeing.
#[unsafe(no_mangle)]
pub extern "C" fn get_search_result(
    engine: *const c_void,
    ref_index: *const c_void,
    id: usize,
    out_page: *mut usize,
    out_book: *mut *const u8,
    out_book_len: *mut usize,
    out_header: *mut *const u8,
    out_header_len: *mut usize,
    out_chapter: *mut u16,
    out_verse: *mut u16,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some((page, book, header, chapter, verse)) = run_ffi(
        || {
            let engine = unsafe { read_ref::<SearchEngine>(engine) };
            let ref_index = unsafe { read_ref::<RefIndex>(ref_index) };
            let verse_refs =
                rkyv::access::<ArchivedVec<ArchivedIndex>, RkyvError>(&engine.idx_bytes)
                    .map_err(|e| SolaError::Search(e.to_string()))?;
            let verse_ref = verse_refs
                .get(id)
                .ok_or(SolaError::Search(format!("Invalid HNSW result id: {}", id)))?;

            let book: BookIdentifier = deserialize::<_, RkyvError>(&verse_ref.book)
                .map_err(|e| SolaError::Search(e.to_string()))?;
            let book = book.to_identifier();
            let chapter = verse_ref.chapter.as_ref().map(|c| c.to_native());
            let verse = verse_ref.verse.as_ref().map(|v| v.to_native());

            let page = ref_index.page_or_nearest(book, chapter, verse) as usize;
            let header = ref_index.book_name(book).unwrap_or("");
            log!(
                "[FFI] get_search_result: id={} {} {:?}:{:?} page={}",
                id,
                book,
                chapter,
                verse,
                page
            );
            Ok((page, book, header, chapter, verse))
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
    unsafe {
        *out_page = page;
        *out_book = book.as_ptr();
        *out_book_len = book.len();
        *out_header = header.as_ptr();
        *out_header_len = header.len();
        if let Some(chapter) = chapter {
            *out_chapter = chapter;
        }
        if let Some(verse) = verse {
            *out_verse = verse;
        }
    }
}

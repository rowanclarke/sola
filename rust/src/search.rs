use std::ffi::{c_char, c_void};

use ndarray::{Array2, ArrayD, Axis, Ix2};
use ndarray_npy::ReadNpyExt;
use rkyv::rancor::Error as RkyvError;
use rkyv::vec::ArchivedVec;
use std::io::Cursor;
use tokenizers::Tokenizer;
use tract_onnx::prelude::*;

use crate::error::SolaError;
use crate::ffi::{read_bytes, read_ref, read_str, run_ffi, write_vec};
use crate::log;
use crate::painter::{ArchivedIndex, ArchivedIndices};

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

struct Model {
    model: RunnableModel<TypedFact, Box<dyn TypedOp>, TypedModel>,
    tokenizer: Tokenizer,
}

type VerseRefs = ArchivedVec<ArchivedIndex>;

const DISTANCE_THRESHOLD: f32 = 0.35;

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

fn parse_npy(npy_bytes: &[u8]) -> Result<Array2<f32>, SolaError> {
    let reader = Cursor::new(npy_bytes);
    let array = Array2::<f32>::read_npy(reader).map_err(|e| SolaError::ModelLoad(e.to_string()))?;
    let tensor = tract_ndarray::Array::into_tensor(array);
    let view = tensor
        .to_array_view::<f32>()
        .map_err(|e| SolaError::ModelLoad(e.to_string()))?;
    Ok(view
        .into_dimensionality::<Ix2>()
        .map_err(|e| SolaError::ModelLoad(e.to_string()))?
        .to_owned())
}

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
// FFI functions
// ---------------------------------------------------------------------------

#[unsafe(no_mangle)]
pub extern "C" fn load_model(
    model: *const u8,
    model_len: usize,
    tokenizer: *const u8,
    tokenizer_len: usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> *mut c_void {
    log!(
        "[FFI] load_model: model={}B tokenizer={}B",
        model_len,
        tokenizer_len
    );
    run_ffi(
        || {
            let model = unsafe { read_bytes(model, model_len) };
            let tokenizer = unsafe { read_bytes(tokenizer, tokenizer_len) };

            let onnx_model = tract_onnx::onnx()
                .model_for_read(&mut Cursor::new(model))
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?
                .into_optimized()
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?
                .into_runnable()
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?;
            let tokenizer_model = Tokenizer::from_bytes(tokenizer)
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?;
            Ok(Box::into_raw(Box::new(Model { model: onnx_model, tokenizer: tokenizer_model })) as *mut c_void)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn get_result(
    model: *const c_void,
    embeddings: *const c_void,
    verse_refs: *const c_void,
    query: *const u8,
    query_len: usize,
    out: *mut *const *const c_void,
    out_distances: *mut *const f32,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    log!("[FFI] get_result: query_len={}", query_len);
    let results: Vec<_> = run_ffi(
        || {
            let model = unsafe { read_ref::<Model>(model) };
            let embeddings = unsafe { read_ref::<Array2<f32>>(embeddings) };
            let verse_refs = unsafe { read_ref::<&VerseRefs>(verse_refs) };

            let query_text = unsafe { read_str(query, query_len) }.trim();
            let normed = encode_query(model, query_text)?;

            let scores = embeddings.dot(
                &normed
                    .clone()
                    .t()
                    .into_dimensionality::<tract_ndarray::Ix2>()
                    .map_err(|e| SolaError::Search(e.to_string()))?,
            );

            let mut matches: Vec<(*const c_void, f32)> = scores
                .indexed_iter()
                .filter_map(|(idx, &similarity)| {
                    let distance = 1.0 - similarity;
                    if distance <= DISTANCE_THRESHOLD {
                        let verse: &ArchivedIndex = &verse_refs[idx.0];
                        Some((verse as *const ArchivedIndex as *const c_void, distance))
                    } else {
                        None
                    }
                })
                .collect();
            matches.sort_by(|a, b| a.1.partial_cmp(&b.1).unwrap_or(std::cmp::Ordering::Equal));
            log!(
                "[FFI] get_result: {} matches within threshold",
                matches.len()
            );
            Ok(matches)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(vec![]);
    let pointers: Vec<*const c_void> = results.iter().map(|(ptr, _)| *ptr).collect();
    let distances: Vec<f32> = results.iter().map(|(_, d)| *d).collect();
    unsafe {
        write_vec(pointers, out, out_len);
        write_vec(distances, out_distances, out_len);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn search_index(
    page_map: *const c_void,
    query: *const u8,
    query_len: usize,
    out: *mut *const *const c_void,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let matches: Vec<_> = run_ffi(
        || {
            let page_map = unsafe { read_ref::<ArchivedIndices>(page_map) };
            let query = unsafe { read_str(query, query_len) }.trim();
            let matches: Vec<*const c_void> = page_map
                .keys()
                .filter(|i| i.verse.is_none() && i.chapter.is_none())
                .filter(|i| i.header.to_lowercase().contains(&query.to_lowercase()))
                .map(|i: &ArchivedIndex| i as *const ArchivedIndex as *const c_void)
                .take(5)
                .collect();
            log!("{:?}", matches);
            Ok(matches)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(vec![]);
    unsafe { write_vec(matches, out, out_len) };
}

#[unsafe(no_mangle)]
pub extern "C" fn load_embeddings(
    embeddings: *const u8,
    embeddings_len: usize,
    verse_refs: *const u8,
    verse_refs_len: usize,
    out_embeddings: *mut *const c_void,
    out_verse_refs: *mut *const c_void,
) {
    log!("[FFI] load_embeddings");
    let embeddings = unsafe { read_bytes(embeddings, embeddings_len) };
    let verse_refs = unsafe { read_bytes(verse_refs, verse_refs_len) };
    let embeddings = Box::new(parse_npy(embeddings).unwrap());
    let verse_refs = Box::new(rkyv::access::<VerseRefs, RkyvError>(verse_refs).unwrap());
    unsafe {
        *out_embeddings = Box::into_raw(embeddings) as *const c_void;
        *out_verse_refs = Box::into_raw(verse_refs) as *const c_void;
    }
}

mod error;
mod painter;

use error::SolaError;
use painter::{
    ArchivedIndex, ArchivedIndices, ArchivedPages, Dimensions, Index, Paint, Painter, Renderer,
    Style, Text, TextStyle,
};
use rkyv::rancor::Error as RkyvError;
use rkyv::vec::ArchivedVec;
use rkyv::deserialize;
use skia_safe::FontMgr;
use std::ffi::{c_char, c_void};
use std::panic::AssertUnwindSafe;
use std::slice::from_raw_parts;
use std::str::from_utf8_unchecked;
use std::{mem, slice};
use usfm::{ArchivedBook, parse};

// ---------------------------------------------------------------------------
// FFI error helpers
// ---------------------------------------------------------------------------

unsafe fn write_error(msg: String, out_error: *mut *mut c_char, out_error_len: *mut usize) {
    let bytes = msg.into_bytes().into_boxed_slice();
    let leaked: &mut [u8] = Box::leak(bytes);
    unsafe {
        *out_error = leaked.as_mut_ptr() as *mut c_char;
        *out_error_len = leaked.len();
    }
}

fn run_ffi<F, T>(
    f: F,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> Option<T>
where
    F: FnOnce() -> Result<T, SolaError>,
{
    unsafe {
        *out_error = std::ptr::null_mut();
        *out_error_len = 0;
    }
    match std::panic::catch_unwind(AssertUnwindSafe(f)) {
        Ok(Ok(val)) => Some(val),
        Ok(Err(e)) => {
            log!("[FFI] Error: {}", e);
            unsafe { write_error(e.to_string(), out_error, out_error_len) };
            None
        }
        Err(panic) => {
            let msg = if let Some(s) = panic.downcast_ref::<&str>() {
                s.to_string()
            } else if let Some(s) = panic.downcast_ref::<String>() {
                s.clone()
            } else {
                "Unknown panic".to_string()
            };
            log!("[FFI] Panic: {}", msg);
            unsafe { write_error(msg, out_error, out_error_len) };
            None
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn free_error(error: *mut c_char, len: usize) {
    if error.is_null() || len == 0 {
        return;
    }
    unsafe {
        drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(
            error as *mut u8,
            len,
        )));
    }
}

// ---------------------------------------------------------------------------
// Renderer setup (infallible)
// ---------------------------------------------------------------------------

#[unsafe(no_mangle)]
pub extern "C" fn renderer() -> *mut c_void {
    Box::into_raw(Box::new(Renderer::new())) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn register_font_family(
    renderer: *mut c_void,
    family: *const c_char,
    family_len: usize,
    data: *mut u8,
    len: usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    log!("[FFI] register_font_family: {} bytes", len);
    let Some(()) = run_ffi(
        || {
            let renderer = unsafe { &mut *(renderer as *mut Renderer) };
            let bytes: &[u8] = unsafe { slice::from_raw_parts(data, len) };
            let typeface = FontMgr::new()
                .new_from_data(bytes, None)
                .ok_or(SolaError::FontLoad)?;
            let family = unsafe {
                from_utf8_unchecked(slice::from_raw_parts(family as *const u8, family_len))
            };
            renderer.register_typeface(typeface, family);
            Ok(())
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
}

#[unsafe(no_mangle)]
pub extern "C" fn register_style(renderer: *mut c_void, style: Style, text_style: *mut TextStyle) {
    let renderer = unsafe { &mut *(renderer as *mut Renderer) };
    let text_style = unsafe { &*text_style };
    renderer.insert_style(style, text_style.clone());
    match style {
        Style::Normal => {
            let mut chapter_style = text_style.clone();
            chapter_style.font_size *= 2.0 * chapter_style.height;
            chapter_style.height = 1.0;
            renderer.insert_style(Style::Chapter, chapter_style);
        }
        _ => (),
    }
}

// ---------------------------------------------------------------------------
// USFM serialization
// ---------------------------------------------------------------------------

#[unsafe(no_mangle)]
pub extern "C" fn serialize_usfm(
    usfm: *const u8,
    usfm_len: usize,
    out: *mut *const u8,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    log!("[FFI] serialize_usfm: {} bytes input", usfm_len);
    let Some(bytes) = run_ffi(
        || {
            let usfm = unsafe { from_utf8_unchecked(from_raw_parts(usfm, usfm_len)) };
            let book = parse(&usfm);
            rkyv::to_bytes::<RkyvError>(&book)
                .map_err(|e| SolaError::Serialization(e.to_string()))
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
    log!("[FFI] serialize_usfm: output {} bytes", bytes.len());
    unsafe {
        *out = bytes.as_ptr();
        *out_len = bytes.len();
    }
    mem::forget(bytes);
}

#[unsafe(no_mangle)]
pub extern "C" fn archived_book(
    book: *const u8,
    book_len: usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> *const c_void {
    run_ffi(
        || {
            let bytes = unsafe { from_raw_parts(book, book_len) };
            let archived = rkyv::access::<ArchivedBook, RkyvError>(bytes)
                .map_err(|e| SolaError::Deserialization(e.to_string()))?;
            Ok(archived as *const ArchivedBook as *const c_void)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(std::ptr::null())
}

#[unsafe(no_mangle)]
pub extern "C" fn book_identifier(
    usfm: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some((ptr, len)) = run_ffi(
        || {
            use usfm::ArchivedBookContents as C;
            let usfm = unsafe { &*(usfm as *const ArchivedBook) };
            if let Some(C::Id { code, .. }) =
                usfm.contents.iter().find(|c| matches!(c, C::Id { .. }))
            {
                let id = code.to_identifier();
                Ok((id.as_ptr(), id.len()))
            } else {
                Err(SolaError::MissingIdentifier)
            }
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
    unsafe {
        *out = ptr;
        *out_len = len;
    }
}

// ---------------------------------------------------------------------------
// Layout & pages
// ---------------------------------------------------------------------------

#[unsafe(no_mangle)]
pub extern "C" fn layout(
    renderer: *const c_void,
    usfm: *const c_void,
    dim: *mut Dimensions,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> *mut c_void {
    log!("[FFI] layout starting...");
    run_ffi(
        || {
            let renderer = unsafe { &*(renderer as *const Renderer) };
            let usfm = unsafe { &*(usfm as *const ArchivedBook) };
            let dim = unsafe { Box::from_raw(dim) };

            let mut painter = Painter::new(renderer, *dim.clone());
            usfm.paint(&mut painter);
            log!("[FFI] layout complete");
            Ok(Box::into_raw(Box::new(painter)) as *mut c_void)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn serialize_pages(
    painter: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some(pages) = run_ffi(
        || {
            let painter = unsafe { &*(painter as *const Painter) };
            painter
                .get_pages()
                .map_err(|e| SolaError::Serialization(e))
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
    unsafe {
        *out = pages.as_ptr();
        *out_len = pages.len();
    }
    mem::forget(pages);
}

#[unsafe(no_mangle)]
pub extern "C" fn archived_pages(
    pages: *const u8,
    pages_len: usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> *const c_void {
    run_ffi(
        || {
            let bytes = unsafe { from_raw_parts(pages, pages_len) };
            let archived = rkyv::access::<ArchivedPages, RkyvError>(bytes)
                .map_err(|e| SolaError::Deserialization(e.to_string()))?;
            Ok(archived as *const ArchivedPages as *const c_void)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(std::ptr::null())
}

#[unsafe(no_mangle)]
pub extern "C" fn num_pages(archived_pages: *const c_void) -> usize {
    let archived_pages = unsafe { &*(archived_pages as *const ArchivedPages) };
    archived_pages.len()
}

#[unsafe(no_mangle)]
pub extern "C" fn page(
    renderer: *const c_void,
    archived_pages: *const c_void,
    n: usize,
    out: *mut *const Text,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some(()) = run_ffi(
        || {
            let renderer = unsafe { &*(renderer as *const Renderer) };
            let archived_pages = unsafe { &*(archived_pages as *const ArchivedPages) };
            let page = renderer.page(&archived_pages[n]).leak();
            unsafe {
                *out = page.as_ptr();
                *out_len = page.len();
            }
            Ok(())
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
}

// ---------------------------------------------------------------------------
// Indices & verses
// ---------------------------------------------------------------------------

#[unsafe(no_mangle)]
pub extern "C" fn serialize_indices(
    painter: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some(indices) = run_ffi(
        || {
            let painter = unsafe { &*(painter as *const Painter) };
            painter
                .get_indices()
                .map_err(|e| SolaError::Serialization(e))
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
    unsafe {
        *out = indices.as_ptr();
        *out_len = indices.len();
    }
    mem::forget(indices);
}

#[unsafe(no_mangle)]
pub extern "C" fn archived_indices(
    indices: *const u8,
    indices_len: usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> *const c_void {
    run_ffi(
        || {
            let bytes = unsafe { from_raw_parts(indices, indices_len) };
            let archived = rkyv::access::<ArchivedIndices, RkyvError>(bytes)
                .map_err(|e| SolaError::Deserialization(e.to_string()))?;
            Ok(archived as *const ArchivedIndices as *const c_void)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(std::ptr::null())
}

#[unsafe(no_mangle)]
pub extern "C" fn get_index(
    archived_indices: *const c_void,
    index: *const c_void,
    out_page: *mut usize,
    out_book: *mut *const u8,
    out_book_len: *mut usize,
    out_chapter: *mut u16,
    out_verse: *mut u16,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some((page_val, book_ptr, book_len, chapter, verse)) = run_ffi(
        || {
            let archived_indices = unsafe { &*(archived_indices as *const ArchivedIndices) };
            let index = unsafe { &*(index as *const ArchivedIndex) };
            let page_val: usize = archived_indices[index]
                .try_into()
                .map_err(|e| SolaError::Deserialization(format!("{e}")))?;
            let deserialized: Index = deserialize::<_, RkyvError>(index)
                .map_err(|e| SolaError::Deserialization(e.to_string()))?;
            let book = deserialized.book.to_identifier();
            Ok((page_val, book.as_ptr(), book.len(), deserialized.chapter, deserialized.verse))
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
    unsafe {
        *out_page = page_val;
        *out_book = book_ptr;
        *out_book_len = book_len;
        *out_chapter = chapter;
        *out_verse = verse;
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn serialize_verses(
    painter: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some(verses) = run_ffi(
        || {
            let painter = unsafe { &*(painter as *const Painter) };
            painter
                .get_verses()
                .map_err(|e| SolaError::Serialization(e))
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
    unsafe {
        *out = verses.as_ptr();
        *out_len = verses.len();
    }
    mem::forget(verses);
}

// ---------------------------------------------------------------------------
// Search / ML model
// ---------------------------------------------------------------------------

use ndarray::{Array2, ArrayD, Axis, Ix2};
use ndarray_npy::ReadNpyExt;
use std::io::Cursor;
use tokenizers::Tokenizer;
use tract_onnx::prelude::*;

fn load_embeddings(npy_bytes: &[u8]) -> Result<Array2<f32>, SolaError> {
    let reader = Cursor::new(npy_bytes);
    let array = Array2::<f32>::read_npy(reader)
        .map_err(|e| SolaError::ModelLoad(e.to_string()))?;
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
    let sum_mask = expanded_mask
        .sum_axis(Axis(1))
        .mapv(|x| x.max(1e-9));

    let pooled = &sum_embeddings / &sum_mask;
    Ok(tract_ndarray::Array::into_tensor(pooled))
}

struct Model<'a> {
    embeddings: Array2<f32>,
    verses: &'a Verses,
    model: RunnableModel<TypedFact, Box<dyn TypedOp>, TypedModel>,
    tokenizer: Tokenizer,
}

type Verses = ArchivedVec<ArchivedIndex>;

#[unsafe(no_mangle)]
pub extern "C" fn load_model(
    embeddings: *const u8,
    embeddings_len: usize,
    verses: *const u8,
    verses_len: usize,
    model: *const u8,
    model_len: usize,
    tokenizer: *const u8,
    tokenizer_len: usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> *mut c_void {
    log!("[FFI] load_model: embeddings={}B model={}B tokenizer={}B", embeddings_len, model_len, tokenizer_len);
    run_ffi(
        || {
            let embeddings = unsafe { from_raw_parts(embeddings, embeddings_len) };
            let verses = unsafe { from_raw_parts(verses, verses_len) };
            let verses = rkyv::access::<Verses, RkyvError>(verses)
                .map_err(|e| SolaError::Deserialization(e.to_string()))?;
            let model = unsafe { from_raw_parts(model, model_len) };
            let tokenizer = unsafe { from_raw_parts(tokenizer, tokenizer_len) };

            let embeddings = load_embeddings(embeddings)?;
            let model = tract_onnx::onnx()
                .model_for_read(&mut Cursor::new(model))
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?
                .into_optimized()
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?
                .into_runnable()
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?;
            let tokenizer = Tokenizer::from_bytes(tokenizer)
                .map_err(|e| SolaError::ModelLoad(e.to_string()))?;
            Ok(Box::into_raw(Box::new(Model {
                embeddings,
                verses,
                model,
                tokenizer,
            })) as *mut c_void)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn get_result(
    model: *const c_void,
    query: *const u8,
    query_len: usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> *const c_void {
    log!("[FFI] get_result: query_len={}", query_len);
    run_ffi(
        || {
            let Model {
                embeddings,
                verses,
                model,
                tokenizer,
            } = unsafe { &*(model as *const Model) };

            let input = unsafe { from_utf8_unchecked(from_raw_parts(query, query_len)).trim() };
            let encoding = tokenizer
                .encode(input, true)
                .map_err(|e| SolaError::Search(e.to_string()))?;
            let ids: Vec<i64> = encoding.get_ids().iter().map(|&id| id as i64).collect();
            let mask: Vec<i64> = encoding
                .get_attention_mask()
                .iter()
                .map(|&m| m as i64)
                .collect();

            let input_ids = Array2::from_shape_vec((1, ids.len()), ids)
                .map_err(|e| SolaError::Search(e.to_string()))?;
            let attention_mask = Array2::from_shape_vec((1, mask.len()), mask)
                .map_err(|e| SolaError::Search(e.to_string()))?;

            let input_ids_tensor = tract_ndarray::Array::into_tensor(input_ids);
            let attention_mask_tensor = tract_ndarray::Array::into_tensor(attention_mask);

            let outputs = model
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
            let normed = &pooled_array / norm;

            let dot = embeddings.dot(
                &normed
                    .clone()
                    .t()
                    .into_dimensionality::<tract_ndarray::Ix2>()
                    .map_err(|e| SolaError::Search(e.to_string()))?,
            );

            let (idx, _) = dot
                .indexed_iter()
                .max_by(|a, b| a.1.partial_cmp(b.1).unwrap_or(std::cmp::Ordering::Equal))
                .ok_or(SolaError::Search("No results found".into()))?;
            Ok(&verses[idx.0] as *const ArchivedIndex as *const c_void)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(std::ptr::null())
}

// ---------------------------------------------------------------------------
// Android logging
// ---------------------------------------------------------------------------

#[cfg(target_os = "android")]
#[link(name = "log")]
unsafe extern "C" {
    fn __android_log_print(prio: i32, tag: *const c_char, fmt: *const c_char, ...) -> i32;
}

#[cfg(target_os = "android")]
#[macro_export]
macro_rules! log {
    ($($arg:tt)*) => {{
        use std::ffi::{CString, c_char};
        let message = CString::new(format!($($arg)*)).unwrap();

        const ANDROID_LOG_INFO: i32 = 4;
        unsafe {
            crate::__android_log_print(
                ANDROID_LOG_INFO,
                b"bible\0".as_ptr() as *const c_char,
                b"%s\0".as_ptr() as *const c_char,
                message.as_ptr()
            );
        }
    }};
}

#[cfg(not(target_os = "android"))]
#[macro_export]
macro_rules! log {
    ($($arg:tt)*) => {{
        println!($($arg)*);
    }}
}

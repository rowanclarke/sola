mod painter;

use painter::{
    ArchivedIndex, ArchivedIndices, ArchivedPages, Dimensions, Index, Paint, Painter, Renderer,
    Style, Text, TextStyle,
};
use rkyv::rancor::Error;
use rkyv::vec::ArchivedVec;
use rkyv::{Deserialize, deserialize};
use skia_safe::FontMgr;
use std::ffi::{c_char, c_void};
use std::slice::from_raw_parts;
use std::str::from_utf8_unchecked;
use std::{mem, slice};
use usfm::{BookIdentifier, parse};

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
) {
    let renderer = unsafe { &mut *(renderer as *mut Renderer) };
    let bytes: &[u8] = unsafe { slice::from_raw_parts(data, len) };
    let typeface = FontMgr::new()
        .new_from_data(bytes, None)
        .expect("Invalid font");
    let family =
        unsafe { from_utf8_unchecked(slice::from_raw_parts(family as *const u8, family_len)) };
    renderer.register_typeface(typeface, family);
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

#[unsafe(no_mangle)]
pub extern "C" fn layout(
    renderer: *const c_void,
    usfm: *const u8,
    len: usize,
    dim: *mut Dimensions,
) -> *mut c_void {
    let renderer = unsafe { &*(renderer as *const Renderer) };
    let usfm = unsafe { from_utf8_unchecked(from_raw_parts(usfm, len)) };
    let dim = unsafe { Box::from_raw(dim) };
    let usfm = parse(&usfm);

    let mut painter = Painter::new(renderer, *dim.clone());
    usfm.paint(&mut painter);
    Box::into_raw(Box::new(painter)) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn serialize_pages(
    painter: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
) {
    let painter = unsafe { &*(painter as *const Painter) };
    let pages = painter.get_pages();
    unsafe {
        *out = pages.as_ptr();
        *out_len = pages.len()
    }
    mem::forget(pages);
}

#[unsafe(no_mangle)]
pub extern "C" fn archived_pages(pages: *const u8, pages_len: usize) -> *const ArchivedPages {
    let bytes = unsafe { from_raw_parts(pages, pages_len) };
    rkyv::access::<ArchivedPages, Error>(bytes).unwrap()
}

#[unsafe(no_mangle)]
pub extern "C" fn page(
    renderer: *const c_void,
    archived_pages: *const c_void,
    n: usize,
    out: *mut *const Text,
    out_len: *mut usize,
) {
    let renderer = unsafe { &*(renderer as *const Renderer) };
    let archived_pages = unsafe { &*(archived_pages as *const ArchivedPages) };
    let page = renderer.page(&archived_pages[n]).leak();
    unsafe {
        *out = page.as_ptr();
        *out_len = page.len();
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn num_pages(archived_pages: *const c_void) -> usize {
    let archived_pages = unsafe { &*(archived_pages as *const ArchivedPages) };
    archived_pages.len()
}

#[unsafe(no_mangle)]
pub extern "C" fn serialize_indices(
    painter: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
) {
    let painter = unsafe { &*(painter as *const Painter) };
    let indices = painter.get_indices();
    unsafe {
        *out = indices.as_ptr();
        *out_len = indices.len()
    }
    mem::forget(indices);
}

#[unsafe(no_mangle)]
pub extern "C" fn archived_indices(
    indices: *const u8,
    indices_len: usize,
) -> *const ArchivedIndices {
    let bytes = unsafe { from_raw_parts(indices, indices_len) };
    rkyv::access::<ArchivedIndices, Error>(bytes).unwrap()
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
) {
    let archived_indices = unsafe { &*(archived_indices as *const ArchivedIndices) };
    let index = unsafe { &*(index as *const ArchivedIndex) };
    unsafe { *out_page = archived_indices[index].try_into().unwrap() };
    let index = deserialize::<_, Error>(index).unwrap();
    let book = format!("{:?}", index.book).leak();
    unsafe {
        *out_book = book.as_ptr();
        *out_book_len = book.len();
        *out_chapter = index.chapter;
        *out_verse = index.verse;
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn serialize_verses(
    painter: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
) {
    let painter = unsafe { &*(painter as *const Painter) };
    let verses = painter.get_verses();
    unsafe {
        *out = verses.as_ptr();
        *out_len = verses.len();
    }
    mem::forget(verses);
}

use ndarray::{Array2, ArrayD, Axis, Ix2};
use ndarray_npy::ReadNpyExt;
use std::io::Cursor;
use tokenizers::Tokenizer;
use tract_onnx::prelude::*;

fn load_embeddings(npy_bytes: &[u8]) -> Array2<f32> {
    let reader = Cursor::new(npy_bytes);
    let array = Array2::<f32>::read_npy(reader).unwrap();
    tract_ndarray::Array::into_tensor(array)
        .to_array_view::<f32>()
        .unwrap()
        .into_dimensionality::<Ix2>()
        .unwrap()
        .to_owned()
}

fn mean_pooling(last_hidden: &Tensor, attention_mask: &Tensor) -> Tensor {
    let last_hidden: ArrayD<f32> = last_hidden.to_array_view::<f32>().unwrap().to_owned();
    let mask: ArrayD<f32> = attention_mask
        .to_array_view::<i64>()
        .unwrap()
        .to_owned()
        .mapv(|v| v as f32);

    let mask = mask.insert_axis(Axis(2)); // [1, seq_len, 1]
    let expanded_mask = mask.broadcast(last_hidden.raw_dim()).unwrap();

    let masked = &last_hidden * &expanded_mask;
    let sum_embeddings = masked.sum_axis(Axis(1));
    let sum_mask = expanded_mask.sum_axis(Axis(1)).mapv(|x| x.max(1e-9));

    let pooled = &sum_embeddings / &sum_mask;
    tract_ndarray::Array::into_tensor(pooled)
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
) -> *mut c_void {
    let embeddings = unsafe { from_raw_parts(embeddings, embeddings_len) };
    let verses = unsafe { from_raw_parts(verses, verses_len) };
    let verses = rkyv::access::<Verses, Error>(verses).unwrap();
    let model = unsafe { from_raw_parts(model, model_len) };
    let tokenizer = unsafe { from_raw_parts(tokenizer, tokenizer_len) };

    let embeddings = load_embeddings(embeddings);
    let model = tract_onnx::onnx()
        .model_for_read(&mut Cursor::new(model))
        .unwrap()
        .into_optimized()
        .unwrap()
        .into_runnable()
        .unwrap();
    let tokenizer = Tokenizer::from_bytes(tokenizer).unwrap();

    Box::into_raw(Box::new(Model {
        embeddings,
        verses,
        model,
        tokenizer,
    })) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn get_result(
    model: *const c_void,
    query: *const u8,
    query_len: usize,
) -> *const ArchivedIndex {
    let Model {
        embeddings,
        verses,
        model,
        tokenizer,
    } = unsafe { &*(model as *const Model) };

    let input = unsafe { from_utf8_unchecked(from_raw_parts(query, query_len)).trim() };
    let encoding = tokenizer.encode(input, true).unwrap();
    let ids: Vec<i64> = encoding.get_ids().iter().map(|&id| id as i64).collect();
    let mask: Vec<i64> = encoding
        .get_attention_mask()
        .iter()
        .map(|&m| m as i64)
        .collect();

    let input_ids = Array2::from_shape_vec((1, ids.len()), ids).unwrap();
    let attention_mask = Array2::from_shape_vec((1, mask.len()), mask).unwrap();

    let input_ids_tensor = tract_ndarray::Array::into_tensor(input_ids);
    let attention_mask_tensor = tract_ndarray::Array::into_tensor(attention_mask);

    let outputs = model
        .run(
            tvec![input_ids_tensor.clone(), attention_mask_tensor.clone()]
                .into_iter()
                .map(TValue::from)
                .collect(),
        )
        .unwrap();
    let last_hidden = outputs[0].clone();
    let pooled = mean_pooling(&last_hidden, &attention_mask_tensor);
    let pooled_array: ArrayD<f32> = pooled.to_array_view::<f32>().unwrap().to_owned();
    let norm = pooled_array.mapv(|x| x.powi(2)).sum().sqrt().max(1e-9);
    let normed = &pooled_array / norm;

    let dot = embeddings.dot(
        &normed
            .clone()
            .t()
            .into_dimensionality::<tract_ndarray::Ix2>()
            .unwrap(),
    );

    let (idx, _) = dot
        .indexed_iter()
        .max_by(|a, b| a.1.partial_cmp(b.1).unwrap())
        .unwrap();
    return &verses[idx.0];
}

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

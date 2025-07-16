mod layout;
mod words;

use layout::{ArchivedPage, Dimensions, Layout, Text};
use rkyv::rancor::Error;
use rkyv::vec::ArchivedVec;
use rkyv::{Archive, Deserialize, Serialize, result};
use skia_safe::textlayout::TypefaceFontProvider;
use skia_safe::{EncodedText, FontMgr};
use std::collections::HashMap;
use std::ffi::{c_char, c_void};
use std::slice::from_raw_parts;
use std::str::from_utf8_unchecked;
use std::{mem, slice};
use usfm::parse;

#[derive(Archive, Serialize, Deserialize, Debug, Hash, PartialEq, Eq, Clone, Copy)]
#[repr(i32)]
pub enum Style {
    Verse = 0,
    Normal = 1,
    Header = 2,
    Chapter = 3,
}

#[derive(Debug, Clone, Copy)]
#[repr(C)]
pub struct TextStyle {
    font_family: *const c_char,
    font_family_len: usize,
    font_size: f32,
    height: f32,
    letter_spacing: f32,
    word_spacing: f32,
}

#[derive(Debug)]
struct Renderer {
    font_provider: TypefaceFontProvider,
    style_collection: HashMap<Style, TextStyle>,
}

#[unsafe(no_mangle)]
pub extern "C" fn renderer() -> *mut c_void {
    Box::into_raw(Box::new(Renderer {
        font_provider: TypefaceFontProvider::new(),
        style_collection: HashMap::new(),
    })) as *mut c_void
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
    renderer.font_provider.register_typeface(typeface, family);
}

#[unsafe(no_mangle)]
pub extern "C" fn register_style(renderer: *mut c_void, style: Style, text_style: *mut TextStyle) {
    let renderer = unsafe { &mut *(renderer as *mut Renderer) };
    let text_style = unsafe { &*text_style };
    renderer.style_collection.insert(style, text_style.clone());
    match style {
        Style::Normal => {
            let height = renderer.line_height(&Style::Normal);
            let mut chapter_style = text_style.clone();
            chapter_style.font_size = 2.0 * height;
            chapter_style.height =
                2.0 * renderer.line_height(&Style::Normal) / chapter_style.font_size;
            renderer
                .style_collection
                .insert(Style::Chapter, chapter_style);
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
    let mut layout = Box::new(Layout::new(renderer, *dim));
    layout.layout(&usfm.contents);
    Box::into_raw(layout) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn page(
    renderer: *const c_void,
    pages: *const u8,
    pages_len: usize,
    n: usize,
    out: *mut *const Text,
    out_len: *mut usize,
) {
    let renderer = unsafe { &*(renderer as *const Renderer) };
    let bytes = unsafe { from_raw_parts(pages, pages_len) };
    let archived_pages: &ArchivedVec<ArchivedPage> = rkyv::access::<_, Error>(bytes).unwrap();
    let page = renderer.page(&archived_pages[n]).leak();
    unsafe {
        *out = page.as_ptr();
        *out_len = page.len();
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn serialize_pages(layout: *const c_void, out: *mut *const u8, out_len: *mut usize) {
    let layout = unsafe { &*(layout as *const Layout) };
    let pages = layout.serialised_pages();
    unsafe {
        *out = pages.as_ptr();
        *out_len = pages.len()
    }
    mem::forget(pages);
}

use ndarray::{Array2, ArrayD, Axis, Ix2};
use ndarray_npy::ReadNpyExt;
use std::fs::File;
use std::io::Cursor;
use std::io::{BufRead, BufReader};
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
    lines: Vec<&'a str>,
    model: RunnableModel<TypedFact, Box<dyn TypedOp>, TypedModel>,
    tokenizer: Tokenizer,
}

#[unsafe(no_mangle)]
pub extern "C" fn load_model(
    embeddings: *const u8,
    embeddings_len: usize,
    lines: *const u8,
    lines_len: usize,
    model: *const u8,
    model_len: usize,
    tokenizer: *const u8,
    tokenizer_len: usize,
) -> *mut c_void {
    let embeddings = unsafe { from_raw_parts(embeddings, embeddings_len) };
    let lines = unsafe { from_utf8_unchecked(from_raw_parts(lines, lines_len)) };
    let model = unsafe { from_raw_parts(model, model_len) };
    let tokenizer = unsafe { from_raw_parts(tokenizer, tokenizer_len) };

    let embeddings = load_embeddings(embeddings);
    let lines = lines.lines().collect::<Vec<_>>();
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
        lines,
        model,
        tokenizer,
    })) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn get_result(
    model: *const c_void,
    query: *const u8,
    len: usize,
    out: *mut *const u8,
    out_len: *mut usize,
) {
    let Model {
        embeddings,
        lines,
        model,
        tokenizer,
    } = unsafe { &*(model as *const Model) };

    let input = unsafe { from_utf8_unchecked(from_raw_parts(query, len)).trim() };
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
    let result = lines[idx.0];

    unsafe {
        *out = result.as_ptr();
        *out_len = result.len();
    }
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
        use std::ffi::CString;
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

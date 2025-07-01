mod layout;
mod words;

use layout::{Dimensions, Layout, Text};
use skia_safe::FontMgr;
use skia_safe::textlayout::TypefaceFontProvider;
use std::collections::HashMap;
use std::ffi::{c_char, c_void};
use std::slice;
use std::slice::from_raw_parts;
use std::str::from_utf8_unchecked;
use usfm::parse;

#[derive(Debug, Hash, PartialEq, Eq, Clone, Copy)]
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
            let metrics = renderer.get_metrics(&Style::Normal);
            let mut chapter_style = text_style.clone();
            chapter_style.font_size += metrics.leading;
            chapter_style.font_size *= 2.0;
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
pub extern "C" fn page(layout: *const c_void, out: *mut *const Text, out_len: *mut usize) {
    let layout = unsafe { &*(layout as *const Layout) };
    let page = layout.page(0);
    let page = page.leak();
    unsafe {
        *out = page.as_ptr();
        *out_len = page.len();
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

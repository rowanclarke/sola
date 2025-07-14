mod painter;

// use layout::{ArchivedPage, Layout};
// use new::{Paint, Painter};
use painter::{ArchivedPages, Dimensions, Paint, Painter, Renderer, Style, Text, TextStyle};
use rkyv::rancor::Error;
use skia_safe::FontMgr;
use std::ffi::{c_char, c_void};
use std::slice::from_raw_parts;
use std::str::from_utf8_unchecked;
use std::{mem, slice};
use usfm::parse;

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

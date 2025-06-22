mod layout;
mod words;

use layout::{Dimensions, Layout, Text};
use std::slice::from_raw_parts;
use std::str::from_utf8_unchecked;
use std::{collections::HashMap, ffi::c_void};
use usfm::{BookContents, parse};

pub type CharsMap = HashMap<(u32, Style), f32>;

#[derive(Debug, Hash, PartialEq, Eq, Clone, Copy)]
#[repr(i32)]
pub enum Style {
    Verse = 0,
    Normal = 1,
    Header = 2,
    Chapter = 3,
}

#[unsafe(no_mangle)]
pub extern "C" fn chars_map(
    usfm: *const u8,
    len: usize,
    out: *mut *const u32,
    out_len: *mut usize,
) -> *mut c_void {
    let usfm = unsafe { from_utf8_unchecked(from_raw_parts(usfm, len)) };
    let map: Box<CharsMap> = Box::new(
        usfm.chars()
            .filter(|c| !"\n\r\t".contains(*c))
            .map(|c| ((c as u32, Style::Normal), 0.0))
            .collect(),
    );
    let mut chars: Vec<u32> = map.keys().map(|(c, _)| c).cloned().collect();
    chars.sort();
    let chars = chars.leak();
    unsafe {
        *out = chars.as_ptr();
        *out_len = chars.len();
    }
    Box::into_raw(map) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn insert(map: *mut c_void, chr: u32, style: Style, width: f32) {
    let map = unsafe { &mut *(map as *mut CharsMap) };
    map.insert((chr, style), width);
}

#[unsafe(no_mangle)]
pub extern "C" fn layout(
    map: *const c_void,
    usfm: *const u8,
    len: usize,
    dim: *mut Dimensions,
) -> *mut c_void {
    let map = unsafe { &*(map as *const CharsMap) };
    let usfm = unsafe { from_utf8_unchecked(from_raw_parts(usfm, len)) };
    let dim = unsafe { Box::from_raw(dim) };
    let usfm = parse(&usfm);
    let mut layout = Box::new(Layout::new(map, *dim));
    layout.layout(&usfm.contents);
    Box::into_raw(layout) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn page(layout: *const c_void, out: *mut *const Text, out_len: *mut usize) {
    let layout = unsafe { &*(layout as *const Layout) };
    unsafe {
        *out = layout.page(0).as_ptr();
        *out_len = layout.page(0).len();
    }
}

#[cfg(target_os = "android")]
use std::os::raw::c_char;

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
        use std::os::raw::c_char;
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

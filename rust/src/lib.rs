use std::collections::HashMap;
use std::ffi::c_void;
use std::slice::from_raw_parts;
use std::str::from_utf8;

type CharsMap = HashMap<u32, (f32, f32)>;

#[unsafe(no_mangle)]
pub extern "C" fn chars_map(
    usfm: *const u8,
    len: usize,
    out: *mut *const u32,
    out_len: *mut usize,
) -> *mut c_void {
    let usfm = from_utf8(unsafe { from_raw_parts(usfm, len) }).unwrap();
    let map: CharsMap = usfm.chars().map(|c| (c as u32, (0.0, 0.0))).collect();
    let mut chars: Vec<u32> = map.keys().cloned().collect();
    chars.sort();
    let chars = chars.leak();
    unsafe {
        *out = chars.as_ptr();
        *out_len = chars.len();
    }
    let map: Box<CharsMap> = Box::new(map);
    Box::into_raw(map) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn insert(map: *mut c_void, chr: u32, width: f32, height: f32) {
    let map = unsafe { &mut *(map as *mut CharsMap) };
    map.insert(chr, (width, height));
}

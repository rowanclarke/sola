use std::ffi::c_char;
use std::panic::AssertUnwindSafe;
use std::slice::from_raw_parts;
use std::str::from_utf8_unchecked;

use crate::error::SolaError;
use crate::log;

pub unsafe fn write_error(msg: String, out_error: *mut *mut c_char, out_error_len: *mut usize) {
    let bytes = msg.into_bytes().into_boxed_slice();
    let leaked: &mut [u8] = Box::leak(bytes);
    unsafe {
        *out_error = leaked.as_mut_ptr() as *mut c_char;
        *out_error_len = leaked.len();
    }
}

pub fn run_ffi<F, T>(f: F, out_error: *mut *mut c_char, out_error_len: *mut usize) -> Option<T>
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

pub unsafe fn read_str<'a>(ptr: *const u8, len: usize) -> &'a str {
    unsafe { from_utf8_unchecked(from_raw_parts(ptr, len)) }
}

pub unsafe fn read_bytes<'a>(ptr: *const u8, len: usize) -> &'a [u8] {
    unsafe { from_raw_parts(ptr, len) }
}

pub unsafe fn read_ref<'a, T>(ptr: *const std::ffi::c_void) -> &'a T {
    unsafe { &*(ptr as *const T) }
}

pub unsafe fn write_vec<T>(vec: Vec<T>, out: *mut *const T, out_len: *mut usize) {
    unsafe {
        *out = vec.as_ptr();
        *out_len = vec.len();
    }
    std::mem::forget(vec);
}

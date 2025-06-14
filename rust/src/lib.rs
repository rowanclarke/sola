use std::ffi::CStr;
use std::os::raw::c_char;

#[unsafe(no_mangle)]
pub extern "C" fn length(s: *const c_char) -> usize {
    let c_str = unsafe { CStr::from_ptr(s) };
    c_str.count_bytes()
}

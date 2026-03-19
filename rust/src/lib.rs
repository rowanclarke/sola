mod error;
mod ffi;
mod painter;
mod search;

use error::SolaError;
use ffi::{read_bytes, read_ref, read_str, run_ffi};
use painter::{
    ArchivedIndex, ArchivedIndices, ArchivedPages, Dimensions, Index, Paint, Painter, Renderer,
    Style, Text, TextStyle,
};
use rkyv::deserialize;
use rkyv::rancor::Error as RkyvError;
use skia_safe::FontMgr;
use std::ffi::{c_char, c_void};
use std::mem;
use std::num::TryFromIntError;
use usfm::{ArchivedBook, parse};

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
            let bytes: &[u8] = unsafe { read_bytes(data as *const u8, len) };
            let typeface = FontMgr::new()
                .new_from_data(bytes, None)
                .ok_or(SolaError::FontLoad)?;
            let family = unsafe { read_str(family as *const u8, family_len) };
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
            let usfm = unsafe { read_str(usfm, usfm_len) };
            let book = parse(&usfm);
            rkyv::to_bytes::<RkyvError>(&book).map_err(|e| SolaError::Serialization(e.to_string()))
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
            let bytes = unsafe { read_bytes(book, book_len) };
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
    book: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some((ptr, len)) = run_ffi(
        || {
            use usfm::ArchivedBookContents as Content;
            let book = unsafe { read_ref::<ArchivedBook>(book) };
            if let Some(Content::Id { code, .. }) = book
                .contents
                .iter()
                .find(|c| matches!(c, Content::Id { .. }))
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
    book: *const c_void,
    dim: *mut Dimensions,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> *mut c_void {
    log!("[FFI] layout starting...");
    run_ffi(
        || {
            let renderer = unsafe { read_ref::<Renderer>(renderer) };
            let book = unsafe { read_ref::<ArchivedBook>(book) };
            let dim = unsafe { Box::from_raw(dim) };

            let mut painter = Painter::new(renderer, *dim.clone());
            book.paint(&mut painter);
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
            let painter = unsafe { read_ref::<Painter>(painter) };
            painter.get_pages().map_err(|e| SolaError::Serialization(e))
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
            let bytes = unsafe { read_bytes(pages, pages_len) };
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
    let archived_pages = unsafe { read_ref::<ArchivedPages>(archived_pages) };
    archived_pages.len()
}

#[unsafe(no_mangle)]
pub extern "C" fn page(
    renderer: *const c_void,
    archived_pages: *const c_void,
    page_index: usize,
    out: *mut *const Text,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some(()) = run_ffi(
        || {
            let renderer = unsafe { read_ref::<Renderer>(renderer) };
            let archived_pages = unsafe { read_ref::<ArchivedPages>(archived_pages) };
            let page = renderer.page(&archived_pages[page_index]).leak();
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
            let painter = unsafe { read_ref::<Painter>(painter) };
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
            let bytes = unsafe { read_bytes(indices, indices_len) };
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
    page_map: *const c_void,
    index: *const c_void,
    out_page: *mut usize,
    out_book: *mut *const u8,
    out_book_len: *mut usize,
    out_header: *mut *const u8,
    out_header_len: *mut usize,
    out_chapter: *mut u16,
    out_verse: *mut u16,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some((page_val, book_ptr, book_len, header_ptr, header_len, chapter, verse)) = run_ffi(
        || {
            let page_map = unsafe { read_ref::<ArchivedIndices>(page_map) };
            let index = unsafe { read_ref::<ArchivedIndex>(index) };
            log!("[FFI] get_index {:?}", index);
            let page_val: usize = page_map
                .get(index)
                .ok_or(SolaError::MissingIndex)?
                .to_native()
                .try_into()
                .map_err(|e: TryFromIntError| SolaError::Deserialization(e.to_string()))?;
            let deserialized: Index = deserialize::<_, RkyvError>(index)
                .map_err(|e| SolaError::Deserialization(e.to_string()))?;
            let book = deserialized.book.to_identifier();
            let header = deserialized.header;
            Ok((
                page_val,
                book.as_ptr(),
                book.len(),
                header.as_ptr(),
                header.len(),
                deserialized.chapter,
                deserialized.verse,
            ))
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
        *out_header = header_ptr;
        *out_header_len = header_len;
        if let Some(chapter) = chapter {
            *out_chapter = chapter;
        }
        if let Some(verse) = verse {
            *out_verse = verse;
        }
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
            let painter = unsafe { read_ref::<Painter>(painter) };
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

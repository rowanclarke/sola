mod error;
mod ffi;
mod painter;
mod reference;
mod search;

use error::SolaError;
use ffi::{read_bytes, read_ref, read_str, run_ffi, write_bytes_out};
use painter::{
    Dimensions, Index, Indices, Paint, Painter, Renderer, Style, Text, TextStyle,
};
use rkyv::rancor::Error as RkyvError;
use skia_safe::FontMgr;
use std::ffi::{c_char, c_void};
use usfm::{ArchivedBook, parse};

use crate::painter::layout::{ArchivedPage, Page};

/// Magic and version of the offset table written alongside `pages`, so a
/// stale table from an older format is rejected rather than misread.
const PAGE_INDEX_MAGIC: &[u8; 4] = b"SOPI";
const PAGE_INDEX_VERSION: u32 = 1;

/// Holds the result of layout() for FFI access.
struct LayoutResult {
    pages: Vec<Page>,
    indices: Indices,
    verses: Vec<Index>,
}

impl LayoutResult {
    /// Serializes each page as its own self-contained archive, concatenated
    /// into one blob, plus an offset table over them.
    ///
    /// Splitting the archive per page is what lets a reader pull a single page
    /// off disk — seek to `offsets[n]`, read `offsets[n + 1] - offsets[n]`
    /// bytes, and access that slice on its own — instead of mapping the whole
    /// book to reach one page.
    ///
    /// The table is `SOPI`, a `u32` version, a `u32` page count, then
    /// `count + 1` little-endian `u32` offsets.
    fn serialize_pages(&self) -> Result<(Vec<u8>, Vec<u8>), SolaError> {
        let mut data = Vec::new();
        let mut offsets: Vec<u32> = Vec::with_capacity(self.pages.len() + 1);
        offsets.push(0);
        for page in &self.pages {
            let bytes = rkyv::to_bytes::<RkyvError>(page)
                .map_err(|e| SolaError::Serialization(e.to_string()))?;
            data.extend_from_slice(&bytes);
            let end = u32::try_from(data.len()).map_err(|_| {
                SolaError::Serialization("pages exceed the 4 GiB offset table limit".to_string())
            })?;
            offsets.push(end);
        }

        let mut index = Vec::with_capacity(12 + 4 * offsets.len());
        index.extend_from_slice(PAGE_INDEX_MAGIC);
        index.extend_from_slice(&PAGE_INDEX_VERSION.to_le_bytes());
        index.extend_from_slice(&(self.pages.len() as u32).to_le_bytes());
        for offset in offsets {
            index.extend_from_slice(&offset.to_le_bytes());
        }
        Ok((data, index))
    }

    fn compute_verse_ranges(&self) -> Vec<u8> {
        let num_pages = self.pages.len();
        let mut page_verses: Vec<Vec<(u16, u16)>> = vec![Vec::new(); num_pages];
        for (index, &page) in &self.indices {
            if let (Some(chapter), Some(verse)) = (index.chapter, index.verse) {
                if page < num_pages {
                    page_verses[page].push((chapter, verse));
                }
            }
        }

        let mut parts: Vec<String> = Vec::with_capacity(num_pages);
        for verses in &page_verses {
            if verses.is_empty() {
                parts.push(String::new());
                continue;
            }
            let mut sorted = verses.clone();
            sorted.sort();
            let (fc, fv) = sorted.first().unwrap();
            let (lc, lv) = sorted.last().unwrap();
            parts.push(format!("{}:{}\t{}:{}", fc, fv, lc, lv));
        }
        parts.join("\n").into_bytes()
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
    unsafe { write_bytes_out(bytes.into_vec(), out, out_len) };
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

            let (pages, indices) = painter.layout();

            // Extract verses from indices (all entries with a verse field)
            let verses: Vec<Index> = indices
                .keys()
                .filter(|idx| idx.verse.is_some())
                .cloned()
                .collect();

            let result = LayoutResult {
                pages,
                indices,
                verses,
            };
            log!("[FFI] layout complete");
            Ok(Box::into_raw(Box::new(result)) as *mut c_void)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn serialize_pages(
    layout_result: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
    out_index: *mut *const u8,
    out_index_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some((data, index)) = run_ffi(
        || {
            let result = unsafe { read_ref::<LayoutResult>(layout_result) };
            result.serialize_pages()
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
    log!(
        "[FFI] serialize_pages: {} bytes, {} byte index",
        data.len(),
        index.len()
    );
    unsafe {
        write_bytes_out(data, out, out_len);
        write_bytes_out(index, out_index, out_index_len);
    }
}

/// Materializes one page from the bytes of its own archive — the slice of the
/// `pages` blob the offset table points at.
///
/// The returned [`Text`] values borrow their strings from `page`, so the caller
/// must keep that buffer alive until it has copied them out, then release the
/// list with [`page_free`].
#[unsafe(no_mangle)]
pub extern "C" fn page_from_bytes(
    renderer: *const c_void,
    page: *const u8,
    page_len: usize,
    out: *mut *const Text,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some((ptr, len)) = run_ffi(
        || {
            let renderer = unsafe { read_ref::<Renderer>(renderer) };
            let bytes = unsafe { read_bytes(page, page_len) };
            let archived = rkyv::access::<ArchivedPage, RkyvError>(bytes)
                .map_err(|e| SolaError::Deserialization(e.to_string()))?;
            let texts = renderer.page(archived).into_boxed_slice();
            let len = texts.len();
            Ok((Box::into_raw(texts) as *const Text, len))
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

#[unsafe(no_mangle)]
pub extern "C" fn page_free(page: *mut Text, len: usize) {
    if page.is_null() || len == 0 {
        return;
    }
    unsafe {
        drop(Box::from_raw(std::ptr::slice_from_raw_parts_mut(page, len)));
    }
}

// ---------------------------------------------------------------------------
// Indices & verses
// ---------------------------------------------------------------------------

#[unsafe(no_mangle)]
pub extern "C" fn serialize_indices(
    layout_result: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some(bytes) = run_ffi(
        || {
            let result = unsafe { read_ref::<LayoutResult>(layout_result) };
            rkyv::to_bytes::<RkyvError>(&result.indices)
                .map_err(|e| SolaError::Serialization(e.to_string()))
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
    unsafe { write_bytes_out(bytes.into_vec(), out, out_len) };
}

#[unsafe(no_mangle)]
pub extern "C" fn serialize_verses(
    layout_result: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some(bytes) = run_ffi(
        || {
            let result = unsafe { read_ref::<LayoutResult>(layout_result) };
            rkyv::to_bytes::<RkyvError>(&result.verses)
                .map_err(|e| SolaError::Serialization(e.to_string()))
        },
        out_error,
        out_error_len,
    ) else {
        return;
    };
    unsafe { write_bytes_out(bytes.into_vec(), out, out_len) };
}

#[unsafe(no_mangle)]
pub extern "C" fn serialize_verse_ranges(
    layout_result: *const c_void,
    out: *mut *const u8,
    out_len: *mut usize,
) {
    let result = unsafe { read_ref::<LayoutResult>(layout_result) };
    unsafe { write_bytes_out(result.compute_verse_ranges(), out, out_len) };
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi::{bytes_free, free_error};
    use std::ptr;

    const STYLES: [(Style, f32, f32); 8] = [
        (Style::Normal, 16.0, 1.5),
        (Style::Header, 24.0, 1.0),
        (Style::Verse, 10.0, 1.0),
        (Style::Chapter, 48.0, 1.0),
        (Style::Word, 16.0, 1.5),
        (Style::Caller, 10.0, 1.0),
        (Style::Footnote, 12.0, 1.5),
        (Style::CrossRef, 12.0, 1.5),
    ];

    struct Out {
        error: *mut c_char,
        error_len: usize,
    }

    impl Out {
        fn new() -> Self {
            Self {
                error: ptr::null_mut(),
                error_len: 0,
            }
        }

        fn check(&self) {
            if self.error_len > 0 {
                let msg = unsafe { read_str(self.error as *const u8, self.error_len) };
                panic!("FFI error: {msg}");
            }
        }
    }

    /// Lays out the test book exactly as the app does, and returns the
    /// renderer and the `pages`/`page_offsets` pair written to disk.
    fn render() -> (*mut c_void, Vec<u8>, Vec<u8>) {
        let manifest = env!("CARGO_MANIFEST_DIR");
        let usfm = std::fs::read_to_string(format!("{manifest}/test.usfm")).unwrap();
        let font =
            std::fs::read(format!("{manifest}/../assets/fonts/AveriaSerifLibre-Regular.ttf"))
                .unwrap();

        let mut out = Out::new();
        let renderer = renderer();

        let family = "AveriaSerifLibre";
        register_font_family(
            renderer,
            family.as_ptr() as *const c_char,
            family.len(),
            font.as_ptr() as *mut u8,
            font.len(),
            &mut out.error,
            &mut out.error_len,
        );
        out.check();

        for (style, font_size, height) in STYLES {
            let mut text_style = TextStyle {
                font_family: family.as_ptr() as *const c_char,
                font_family_len: family.len(),
                font_size,
                height,
                letter_spacing: 0.0,
                word_spacing: 0.0,
                underline: 0,
            };
            register_style(renderer, style, &mut text_style);
        }

        let mut book_bytes: *const u8 = ptr::null();
        let mut book_len = 0;
        serialize_usfm(
            usfm.as_ptr(),
            usfm.len(),
            &mut book_bytes,
            &mut book_len,
            &mut out.error,
            &mut out.error_len,
        );
        out.check();

        let book = archived_book(book_bytes, book_len, &mut out.error, &mut out.error_len);
        out.check();

        let dim = Box::into_raw(Box::new(Dimensions {
            width: 344.0,
            height: 702.0,
            header_height: 702.0 / 5.0,
            drop_cap_padding: 20.0,
        }));
        let result = layout(renderer, book, dim, &mut out.error, &mut out.error_len);
        out.check();

        let mut pages: *const u8 = ptr::null();
        let mut pages_len = 0;
        let mut offsets: *const u8 = ptr::null();
        let mut offsets_len = 0;
        serialize_pages(
            result,
            &mut pages,
            &mut pages_len,
            &mut offsets,
            &mut offsets_len,
            &mut out.error,
            &mut out.error_len,
        );
        out.check();

        let owned = (
            renderer,
            unsafe { read_bytes(pages, pages_len) }.to_vec(),
            unsafe { read_bytes(offsets, offsets_len) }.to_vec(),
        );
        bytes_free(book_bytes as *mut u8, book_len);
        bytes_free(pages as *mut u8, pages_len);
        bytes_free(offsets as *mut u8, offsets_len);
        owned
    }

    fn read_u32(bytes: &[u8], at: usize) -> u32 {
        u32::from_le_bytes(bytes[at..at + 4].try_into().unwrap())
    }

    #[test]
    fn offset_table_covers_every_page_exactly_once() {
        let (_, pages, offsets) = render();

        assert_eq!(&offsets[..4], PAGE_INDEX_MAGIC);
        assert_eq!(read_u32(&offsets, 4), PAGE_INDEX_VERSION);

        let count = read_u32(&offsets, 8) as usize;
        assert!(count > 1, "test book should span several pages, got {count}");
        assert_eq!(offsets.len(), 12 + 4 * (count + 1));

        assert_eq!(read_u32(&offsets, 12), 0, "first page starts at 0");
        for page in 0..count {
            let start = read_u32(&offsets, 12 + 4 * page);
            let end = read_u32(&offsets, 12 + 4 * (page + 1));
            assert!(start < end, "page {page} is empty");
        }
        assert_eq!(
            read_u32(&offsets, 12 + 4 * count) as usize,
            pages.len(),
            "offsets should end at the end of the blob"
        );
    }

    /// Reading one page's segment on its own is the whole point of the format:
    /// no page may depend on the bytes of any other.
    #[test]
    fn each_page_reads_back_from_its_own_segment() {
        let (renderer, pages, offsets) = render();
        let count = read_u32(&offsets, 8) as usize;

        let mut total_fragments = 0;
        for page in 0..count {
            let start = read_u32(&offsets, 12 + 4 * page) as usize;
            let end = read_u32(&offsets, 12 + 4 * (page + 1)) as usize;
            let segment = pages[start..end].to_vec();

            let mut out = Out::new();
            let mut fragments: *const Text = ptr::null();
            let mut len = 0;
            page_from_bytes(
                renderer,
                segment.as_ptr(),
                segment.len(),
                &mut fragments,
                &mut len,
                &mut out.error,
                &mut out.error_len,
            );
            out.check();
            assert!(len > 0, "page {page} came back with no fragments");

            for i in 0..len {
                let text = unsafe { &*fragments.add(i) };
                let string = unsafe { read_str(text.0 as *const u8, text.1) };
                assert!(
                    text.2.height > 0.0,
                    "fragment {i} of page {page} has no height: {string:?}"
                );
            }
            total_fragments += len;
            page_free(fragments as *mut Text, len);
        }
        assert!(total_fragments > count, "expected real text on every page");
    }

    /// A stale or wrong offset table hands `page_from_bytes` a segment that is
    /// not a whole archive. That has to come back as an error, not a crash.
    #[test]
    fn a_truncated_segment_is_an_error_not_a_crash() {
        let (renderer, pages, offsets) = render();
        let end = read_u32(&offsets, 16) as usize;
        let truncated = pages[..end / 2].to_vec();

        let mut out = Out::new();
        let mut fragments: *const Text = ptr::null();
        let mut len = 0;
        page_from_bytes(
            renderer,
            truncated.as_ptr(),
            truncated.len(),
            &mut fragments,
            &mut len,
            &mut out.error,
            &mut out.error_len,
        );
        assert!(out.error_len > 0, "expected an error message");
        free_error(out.error, out.error_len);
    }
}

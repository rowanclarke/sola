use std::ffi::c_char;

use crate::{Model, log};
use usfm::ArchivedBook;

pub struct Indexer {
    books: Vec<(String, String)>,
}

#[derive(Debug)]
#[repr(C)]
pub struct BookIndex {
    book: *const c_char,
    book_len: usize,
    header: *const c_char,
    header_len: usize,
}

impl Indexer {
    pub fn new() -> Self {
        Self { books: vec![] }
    }

    pub fn add_book(&mut self, id: &str, book: &ArchivedBook) {
        use usfm::ArchivedBookContents as C;
        use usfm::ArchivedElement as E;
        use usfm::ArchivedElementContents::Line;
        use usfm::ArchivedElementType::Header;
        if let Some(C::Element(E { contents, .. })) = book
            .contents
            .iter()
            .find(|c| matches!(c, C::Element(E { ty: Header, .. })))
            && let Line(s) = &contents[0]
        {
            log!("{} {}", id, s);
            self.books.push((id.to_string(), s.to_string()));
        }
    }

    pub fn search(&self, query: &str) -> Vec<BookIndex> {
        self.books
            .iter()
            .filter(|(_, s)| s.to_lowercase().contains(&query.to_lowercase()))
            .map(|(id, s)| Self::book_index(id, s))
            .collect()
    }

    fn book_index(id: &str, query: &str) -> BookIndex {
        let book = Box::leak(id.to_string().into_bytes().into_boxed_slice());
        let header = Box::leak(query.to_string().into_bytes().into_boxed_slice());
        BookIndex {
            book: book.as_ptr() as *const c_char,
            book_len: book.len(),
            header: header.as_ptr() as *const c_char,
            header_len: header.len(),
        }
    }
}

//! Reference search: fuzzy book → chapter → verse lookup over the page index.
//!
//! The renderer already emits, for every book, a `HashMap<Index, usize>` mapping
//! each book title / chapter / verse to the page it lands on (see
//! `painter::Painter::index_book` / `index_chapter` / `index_verse`). That map is
//! the complete navigation table for a rendered translation, but it is keyed by a
//! struct containing a per-entry copy of the book's display name and it offers no
//! ordered enumeration — so answering "which chapters of Genesis start with 1?"
//! means scanning all ~32k entries.
//!
//! [`RefIndex`] re-shapes exactly that data into a CSR (compressed sparse row)
//! layout: books in canonical order, each pointing at a contiguous run of
//! chapters, each pointing at a contiguous run of verses. Display names are
//! stored once per book instead of once per verse. The result is ~200 KB of flat
//! arrays that can be enumerated, binary-searched, and scanned per keystroke.

use std::collections::BTreeMap;
use std::ffi::{c_char, c_void};
use std::fmt::Write as _;

use rkyv::deserialize;
use rkyv::rancor::Error as RkyvError;
use unicode_normalization::UnicodeNormalization;

use crate::error::SolaError;
use crate::ffi::{read_bytes, read_ref, read_str, run_ffi, write_vec};
use crate::log;
use crate::painter::{ArchivedIndices, Indices};

// ---------------------------------------------------------------------------
// Text folding and fuzzy primitives
// ---------------------------------------------------------------------------

fn is_combining_mark(c: char) -> bool {
    matches!(c,
        '\u{0300}'..='\u{036F}'
        | '\u{1AB0}'..='\u{1AFF}'
        | '\u{1DC0}'..='\u{1DFF}'
        | '\u{20D0}'..='\u{20FF}'
        | '\u{FE20}'..='\u{FE2F}'
    )
}

/// Case-, accent- and punctuation-insensitive form used for all name matching.
///
/// "1 John" → "1john", "Éphésiens" → "ephesiens".
pub fn fold(s: &str) -> String {
    s.nfd()
        .filter(|c| !is_combining_mark(*c))
        .flat_map(|c| c.to_lowercase())
        .filter(|c| c.is_alphanumeric())
        .collect()
}

/// Folded word tokens of a name: "Song of Songs" → ["song", "of", "songs"].
fn tokens(name: &str) -> Vec<String> {
    name.split(|c: char| !c.is_alphanumeric())
        .map(fold)
        .filter(|t| !t.is_empty())
        .collect()
}

/// True when every char of `q` appears in `s`, in order (fzf-style match).
fn is_subsequence(q: &str, s: &str) -> bool {
    let mut it = s.chars();
    q.chars().all(|c| it.any(|x| x == c))
}

/// Byte width spanned by a greedy leftmost subsequence match, for ranking.
/// A tighter span means the query characters sit closer together in the name.
fn match_span(q: &str, s: &str) -> Option<usize> {
    if q.is_empty() {
        return Some(0);
    }
    let mut first = None;
    let mut last = 0;
    let mut it = s.char_indices();
    for c in q.chars() {
        let (i, ch) = it.by_ref().find(|(_, x)| *x == c)?;
        if first.is_none() {
            first = Some(i);
        }
        last = i + ch.len_utf8();
    }
    Some(last - first.unwrap_or(0))
}

// ---------------------------------------------------------------------------
// Query parsing
// ---------------------------------------------------------------------------

fn is_sep(c: char) -> bool {
    c.is_whitespace() || matches!(c, ':' | '.' | ',' | ';' | '-' | '\u{2013}' | '_' | '/')
}

fn has_alpha(s: &str) -> bool {
    s.chars().any(char::is_alphabetic)
}

/// Splits off the maximal run of trailing ASCII digits: "gen 1" → ("gen ", "1").
fn split_trailing_digits(s: &str) -> (&str, &str) {
    let idx = s
        .char_indices()
        .rev()
        .take_while(|(_, c)| c.is_ascii_digit())
        .last()
        .map(|(i, _)| i)
        .unwrap_or(s.len());
    (&s[..idx], &s[idx..])
}

#[derive(Debug, PartialEq, Eq)]
pub struct ParsedRef<'a> {
    pub book: &'a str,
    pub chapter: Option<&'a str>,
    pub verse: Option<&'a str>,
    /// The query ends on a separator, i.e. the user is about to type the next
    /// level down. "Gen " wants chapters; "Gen 1:" wants verses.
    pub trailing_sep: bool,
}

/// Parses `<book> [sep <chapter> [sep <verse>]]`, scanning right to left so a
/// leading numeral stays with the book name ("1 John 3:16", "2ki2").
///
/// A digit run is only taken as a chapter/verse if what remains still contains a
/// letter — otherwise the whole query is treated as book text.
pub fn parse_reference(query: &str) -> ParsedRef<'_> {
    let raw = query.trim_start();
    let trailing_sep = raw.chars().next_back().is_some_and(is_sep);
    let s0 = raw.trim_end_matches(is_sep);

    let (h1, d1) = split_trailing_digits(s0);
    let h1 = h1.trim_end_matches(is_sep);
    if d1.is_empty() || !has_alpha(h1) {
        return ParsedRef { book: s0, chapter: None, verse: None, trailing_sep };
    }

    let (h2, d2) = split_trailing_digits(h1);
    let h2 = h2.trim_end_matches(is_sep);
    if d2.is_empty() || !has_alpha(h2) {
        return ParsedRef { book: h1, chapter: Some(d1), verse: None, trailing_sep };
    }

    ParsedRef { book: h2, chapter: Some(d2), verse: Some(d1), trailing_sep }
}

// ---------------------------------------------------------------------------
// Index
// ---------------------------------------------------------------------------

pub const LEVEL_BOOK: u8 = 0;
pub const LEVEL_CHAPTER: u8 = 1;
pub const LEVEL_VERSE: u8 = 2;

#[derive(Debug, PartialEq, Eq, Clone)]
pub struct Hit {
    pub book: usize,
    pub chapter: Option<u16>,
    pub verse: Option<u16>,
    pub page: u32,
    pub level: u8,
}

/// Books, chapters and verses of one rendered translation in CSR form.
///
/// `ch_start[b]..ch_start[b + 1]` indexes book `b`'s chapters; likewise
/// `vs_start[c]..vs_start[c + 1]` indexes chapter `c`'s verses. Chapters and
/// verses are stored ascending, so both are binary-searchable.
pub struct RefIndex {
    book_code: Vec<&'static str>,
    book_name: Vec<String>,
    book_folded: Vec<String>,
    book_code_folded: Vec<String>,
    book_tokens: Vec<Vec<String>>,
    book_page: Vec<u32>,
    ch_start: Vec<u32>,

    ch_num: Vec<u16>,
    ch_page: Vec<u32>,
    vs_start: Vec<u32>,

    vs_num: Vec<u16>,
    vs_page: Vec<u32>,
}

impl RefIndex {
    pub fn book_count(&self) -> usize {
        self.book_code.len()
    }

    pub fn chapter_count(&self) -> usize {
        self.ch_num.len()
    }

    pub fn verse_count(&self) -> usize {
        self.vs_num.len()
    }

    fn book_slot(&self, code: &str) -> Option<usize> {
        self.book_code.iter().position(|c| *c == code)
    }

    fn chapter_slot(&self, book: usize, chapter: u16) -> Option<usize> {
        let lo = self.ch_start[book] as usize;
        let hi = self.ch_start[book + 1] as usize;
        self.ch_num[lo..hi].binary_search(&chapter).ok().map(|k| lo + k)
    }

    fn verse_slot(&self, chapter: usize, verse: u16) -> Option<usize> {
        let lo = self.vs_start[chapter] as usize;
        let hi = self.vs_start[chapter + 1] as usize;
        self.vs_num[lo..hi].binary_search(&verse).ok().map(|k| lo + k)
    }

    /// Page for a reference, used to place semantic-search results.
    /// `chapter`/`verse` of `None` address the book title and chapter opening.
    pub fn page_of(&self, code: &str, chapter: Option<u16>, verse: Option<u16>) -> Option<u32> {
        let b = self.book_slot(code)?;
        let Some(c) = chapter else {
            return Some(self.book_page[b]);
        };
        let c = self.chapter_slot(b, c)?;
        let Some(v) = verse else {
            return Some(self.ch_page[c]);
        };
        Some(self.vs_page[self.verse_slot(c, v)?])
    }

    /// Page for a reference, degrading to the chapter then the book opening
    /// rather than failing — a translation may not carry every verse the
    /// semantic index was built from.
    pub fn page_or_nearest(&self, code: &str, chapter: Option<u16>, verse: Option<u16>) -> u32 {
        self.page_of(code, chapter, verse)
            .or_else(|| self.page_of(code, chapter, None))
            .or_else(|| self.page_of(code, None, None))
            .unwrap_or(0)
    }

    pub fn book_name(&self, code: &str) -> Option<&str> {
        self.book_slot(code).map(|b| self.book_name[b].as_str())
    }

    fn book_hit(&self, b: usize) -> Hit {
        Hit { book: b, chapter: None, verse: None, page: self.book_page[b], level: LEVEL_BOOK }
    }

    fn chapter_hit(&self, b: usize, c: usize) -> Hit {
        Hit {
            book: b,
            chapter: Some(self.ch_num[c]),
            verse: None,
            page: self.ch_page[c],
            level: LEVEL_CHAPTER,
        }
    }

    fn verse_hit(&self, b: usize, c: usize, v: usize) -> Hit {
        Hit {
            book: b,
            chapter: Some(self.ch_num[c]),
            verse: Some(self.vs_num[v]),
            page: self.vs_page[v],
            level: LEVEL_VERSE,
        }
    }

    // --- Book matching ---

    /// Candidate books for a folded query, in tiers. Only the strongest
    /// non-empty tier is returned: a plain subsequence match is loose enough
    /// that "ps" would otherwise also hit Ephesians and Philippians, which
    /// would keep Psalms from ever resolving.
    fn match_books(&self, q: &str) -> Vec<usize> {
        let mut prefix = Vec::new();
        let mut word = Vec::new();
        let mut loose = Vec::new();

        for b in 0..self.book_count() {
            let name = &self.book_folded[b];
            let code = &self.book_code_folded[b];
            if name.starts_with(q) || code == q {
                prefix.push(b);
            } else if self.book_tokens[b].iter().any(|w| w.starts_with(q))
                || is_subsequence(q, code)
            {
                word.push(b);
            } else if is_subsequence(q, name) {
                loose.push(b);
            }
        }

        for tier in [prefix, word, loose] {
            if !tier.is_empty() {
                return tier;
            }
        }
        Vec::new()
    }

    fn rank_books(&self, cands: &mut [usize], q: &str) {
        cands.sort_by_key(|&b| {
            let name = &self.book_folded[b];
            (
                name != q,                                    // exact name first
                !name.starts_with(q),                         // then prefixes
                match_span(q, name).unwrap_or(usize::MAX),     // then tightest match
                b,                                            // then canonical order
            )
        });
    }

    /// A book is resolved when it is the only candidate, or the only one whose
    /// folded name equals the query exactly — "john" must reach John even
    /// though 1/2/3 John also contain it.
    fn resolve_book(&self, cands: &[usize], q: &str) -> Option<usize> {
        if cands.len() == 1 {
            return Some(cands[0]);
        }
        let mut exact = cands.iter().filter(|&&b| self.book_folded[b] == q);
        let first = exact.next()?;
        exact.next().is_none().then_some(*first)
    }

    // --- Reference lookup ---

    /// Fuzzy reference lookup. Returns at most `limit` hits, best first, or an
    /// empty vec when the query does not name a book — the caller then falls
    /// back to semantic search.
    pub fn lookup(&self, query: &str, limit: usize) -> Vec<Hit> {
        if limit == 0 {
            return Vec::new();
        }
        let parsed = parse_reference(query);
        let qb = fold(parsed.book);
        if qb.is_empty() {
            return Vec::new();
        }

        let mut books = self.match_books(&qb);
        if books.is_empty() {
            return Vec::new();
        }

        // Ranking only decides display order, so it is needed only when the
        // query leaves the book ambiguous.
        let Some(b) = self.resolve_book(&books, &qb) else {
            self.rank_books(&mut books, &qb);
            books.truncate(limit);
            return books.into_iter().map(|b| self.book_hit(b)).collect();
        };

        let ch_lo = self.ch_start[b] as usize;
        let ch_hi = self.ch_start[b + 1] as usize;

        // No chapter typed: offer the book itself, then its chapters to browse.
        let Some(ct) = parsed.chapter else {
            let mut hits = vec![self.book_hit(b)];
            for c in ch_lo..ch_hi.min(ch_lo + limit) {
                hits.push(self.chapter_hit(b, c));
            }
            hits.truncate(limit);
            return hits;
        };

        let (mut chapters, has_exact) = match_numbers(&self.ch_num[ch_lo..ch_hi], ct);
        if chapters.is_empty() {
            return vec![self.book_hit(b)];
        }

        let verse_part = parsed.verse.is_some() || parsed.trailing_sep;
        let Some(c) = resolve_number(&chapters, has_exact, verse_part) else {
            chapters.truncate(limit);
            return chapters.into_iter().map(|k| self.chapter_hit(b, ch_lo + k)).collect();
        };
        let c = ch_lo + c;

        let vs_lo = self.vs_start[c] as usize;
        let vs_hi = self.vs_start[c + 1] as usize;

        // No verse typed: offer the chapter itself, then its verses to browse.
        let Some(vt) = parsed.verse else {
            let mut hits = vec![self.chapter_hit(b, c)];
            for v in vs_lo..vs_hi.min(vs_lo + limit) {
                hits.push(self.verse_hit(b, c, v));
            }
            hits.truncate(limit);
            return hits;
        };

        let (mut verses, _) = match_numbers(&self.vs_num[vs_lo..vs_hi], vt);
        if verses.is_empty() {
            return vec![self.chapter_hit(b, c)];
        }
        verses.truncate(limit);
        verses.into_iter().map(|k| self.verse_hit(b, c, vs_lo + k)).collect()
    }
}

// ---------------------------------------------------------------------------
// Numeric matching
// ---------------------------------------------------------------------------

/// Chapter and verse numbers match on decimal prefix, not subsequence: typing
/// "12" means chapter 12 or 120-129, never 112.
///
/// Returns indices into `nums`, ascending, except that an exact match is
/// floated to the front — "1" should offer chapter 1 before 10-19. Since at
/// most one number can equal the token, the flag also says whether index 0 of
/// the result is that exact match.
fn match_numbers(nums: &[u16], token: &str) -> (Vec<usize>, bool) {
    let mut matches = Vec::new();
    let mut exact = None;
    let mut buf = String::new();
    for (i, n) in nums.iter().enumerate() {
        buf.clear();
        let _ = write!(buf, "{}", n);
        if buf.starts_with(token) {
            if buf.len() == token.len() {
                exact = Some(matches.len());
            }
            matches.push(i);
        }
    }
    if let Some(pos) = exact {
        matches[..=pos].rotate_right(1);
    }
    (matches, exact.is_some())
}

/// Unique candidate, or the exact one when a deeper level was typed —
/// "gen 1:1" must reach chapter 1 even though "1" also prefixes 10-19.
fn resolve_number(matches: &[usize], has_exact: bool, child_typed: bool) -> Option<usize> {
    if matches.len() == 1 {
        return Some(matches[0]);
    }
    (child_typed && has_exact).then(|| matches[0])
}

// ---------------------------------------------------------------------------
// Builder
// ---------------------------------------------------------------------------

#[derive(Default)]
struct ChapterAccum {
    page: Option<u32>,
    verses: BTreeMap<u16, u32>,
}

struct BookAccum {
    code: &'static str,
    name: String,
    page: Option<u32>,
    chapters: BTreeMap<u16, ChapterAccum>,
}

/// Accumulates per-book `indices` maps into a [`RefIndex`].
///
/// Books keep insertion order, which the caller supplies in canonical order.
#[derive(Default)]
pub struct RefIndexBuilder {
    books: Vec<BookAccum>,
}

impl RefIndexBuilder {
    pub fn add(&mut self, indices: Indices) {
        for (index, page) in indices {
            let page = page as u32;
            let code = index.book.to_identifier();
            let slot = match self.books.iter().position(|b| b.code == code) {
                Some(slot) => slot,
                None => {
                    self.books.push(BookAccum {
                        code,
                        name: index.header.clone(),
                        page: None,
                        chapters: BTreeMap::new(),
                    });
                    self.books.len() - 1
                }
            };
            let book = &mut self.books[slot];

            match (index.chapter, index.verse) {
                (None, _) => {
                    book.name = index.header;
                    book.page = Some(page);
                }
                (Some(chapter), None) => {
                    book.chapters.entry(chapter).or_default().page = Some(page);
                }
                (Some(chapter), Some(verse)) => {
                    book.chapters.entry(chapter).or_default().verses.insert(verse, page);
                }
            }
        }
    }

    pub fn finish(self) -> RefIndex {
        let n = self.books.len();
        let mut index = RefIndex {
            book_code: Vec::with_capacity(n),
            book_name: Vec::with_capacity(n),
            book_folded: Vec::with_capacity(n),
            book_code_folded: Vec::with_capacity(n),
            book_tokens: Vec::with_capacity(n),
            book_page: Vec::with_capacity(n),
            ch_start: Vec::with_capacity(n + 1),
            ch_num: Vec::new(),
            ch_page: Vec::new(),
            vs_start: Vec::new(),
            vs_num: Vec::new(),
            vs_page: Vec::new(),
        };
        index.ch_start.push(0);
        index.vs_start.push(0);

        for book in self.books {
            // A book or chapter whose own marker never landed on a page falls
            // back to where its first child starts.
            let first_chapter_page = book
                .chapters
                .values()
                .find_map(|c| c.page.or_else(|| c.verses.values().next().copied()));

            index.book_code.push(book.code);
            index.book_folded.push(fold(&book.name));
            index.book_code_folded.push(fold(book.code));
            index.book_tokens.push(tokens(&book.name));
            index.book_name.push(book.name);
            index.book_page.push(book.page.or(first_chapter_page).unwrap_or(0));

            for (number, chapter) in book.chapters {
                let first_verse_page = chapter.verses.values().next().copied();
                index.ch_num.push(number);
                index.ch_page.push(chapter.page.or(first_verse_page).unwrap_or(0));
                for (verse, page) in chapter.verses {
                    index.vs_num.push(verse);
                    index.vs_page.push(page);
                }
                index.vs_start.push(index.vs_num.len() as u32);
            }
            index.ch_start.push(index.ch_num.len() as u32);
        }

        index
    }
}

// ---------------------------------------------------------------------------
// FFI
// ---------------------------------------------------------------------------

/// One reference hit. `book` and `header` borrow from the [`RefIndex`], which
/// outlives every hit it produces, so nothing here needs freeing beyond the
/// enclosing array (see `ref_hits_free`).
///
/// A `chapter` or `verse` of 0 means the hit stops at the level above: a book
/// hit carries neither, a chapter hit carries only a chapter.
#[repr(C)]
pub struct RefHit {
    pub page: usize,
    pub book: *const u8,
    pub book_len: usize,
    pub header: *const u8,
    pub header_len: usize,
    pub chapter: u16,
    pub verse: u16,
}

#[unsafe(no_mangle)]
pub extern "C" fn ref_index_builder_new() -> *mut c_void {
    log!("[FFI] ref_index_builder_new");
    Box::into_raw(Box::new(RefIndexBuilder::default())) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn ref_index_builder_add(
    builder: *mut c_void,
    data: *const u8,
    data_len: usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    run_ffi(
        || {
            let builder = unsafe { &mut *(builder as *mut RefIndexBuilder) };
            let bytes = unsafe { read_bytes(data, data_len) };
            let archived = rkyv::access::<ArchivedIndices, RkyvError>(bytes)
                .map_err(|e| SolaError::Deserialization(e.to_string()))?;
            let indices: Indices = deserialize::<_, RkyvError>(archived)
                .map_err(|e| SolaError::Deserialization(e.to_string()))?;
            log!("[FFI] ref_index_builder_add: {} entries", indices.len());
            builder.add(indices);
            Ok(())
        },
        out_error,
        out_error_len,
    );
}

#[unsafe(no_mangle)]
pub extern "C" fn ref_index_builder_finish(
    builder: *mut c_void,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) -> *mut c_void {
    run_ffi(
        || {
            let builder = unsafe { Box::from_raw(builder as *mut RefIndexBuilder) };
            let index = builder.finish();
            log!(
                "[FFI] ref_index_builder_finish: {} books, {} chapters, {} verses",
                index.book_count(),
                index.chapter_count(),
                index.verse_count()
            );
            Ok(Box::into_raw(Box::new(index)) as *mut c_void)
        },
        out_error,
        out_error_len,
    )
    .unwrap_or(std::ptr::null_mut())
}

#[unsafe(no_mangle)]
pub extern "C" fn ref_index_free(index: *mut c_void) {
    if index.is_null() {
        return;
    }
    log!("[FFI] ref_index_free");
    drop(unsafe { Box::from_raw(index as *mut RefIndex) });
}

#[unsafe(no_mangle)]
pub extern "C" fn ref_index_lookup(
    index: *const c_void,
    query: *const u8,
    query_len: usize,
    limit: usize,
    out: *mut *const RefHit,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let hits: Vec<RefHit> = run_ffi(
        || {
            let index = unsafe { read_ref::<RefIndex>(index) };
            let query = unsafe { read_str(query, query_len) };
            Ok(index
                .lookup(query, limit)
                .into_iter()
                .map(|hit| {
                    let code = index.book_code[hit.book];
                    let header = &index.book_name[hit.book];
                    RefHit {
                        page: hit.page as usize,
                        book: code.as_ptr(),
                        book_len: code.len(),
                        header: header.as_ptr(),
                        header_len: header.len(),
                        chapter: hit.chapter.unwrap_or(0),
                        verse: hit.verse.unwrap_or(0),
                    }
                })
                .collect())
        },
        out_error,
        out_error_len,
    )
    .unwrap_or_default();
    unsafe { write_vec(hits, out, out_len) };
}

#[unsafe(no_mangle)]
pub extern "C" fn ref_hits_free(hits: *mut RefHit, len: usize) {
    if hits.is_null() || len == 0 {
        return;
    }
    drop(unsafe { Vec::from_raw_parts(hits, len, len) });
}

/// Reads the book title out of a raw per-book `indices` buffer.
///
/// The returned pointer borrows from `data`, which the caller owns for the
/// duration of the call.
#[unsafe(no_mangle)]
pub extern "C" fn indices_book_title(
    data: *const u8,
    data_len: usize,
    out: *mut *const u8,
    out_len: *mut usize,
    out_error: *mut *mut c_char,
    out_error_len: *mut usize,
) {
    let Some((ptr, len)) = run_ffi(
        || {
            let bytes = unsafe { read_bytes(data, data_len) };
            let archived = rkyv::access::<ArchivedIndices, RkyvError>(bytes)
                .map_err(|e| SolaError::Deserialization(e.to_string()))?;
            let title = archived
                .keys()
                .find(|i| i.chapter.is_none() && i.verse.is_none())
                .map(|i| i.header.as_str())
                .unwrap_or("");
            Ok((title.as_ptr(), title.len()))
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
// Tests
// ---------------------------------------------------------------------------

#[cfg(test)]
mod tests {
    use super::*;
    use usfm::BookIdentifier;

    use crate::painter::Index;

    /// The 66 canonical books, so book matching is exercised against the real
    /// set of names it has to disambiguate between.
    const BOOKS: [(&str, BookIdentifier); 66] = {
        use BookIdentifier::*;
        [
            ("Genesis", Genesis),
            ("Exodus", Exodus),
            ("Leviticus", Leviticus),
            ("Numbers", Numbers),
            ("Deuteronomy", Deuteronomy),
            ("Joshua", Joshua),
            ("Judges", Judges),
            ("Ruth", Ruth),
            ("1 Samuel", OneSamuel),
            ("2 Samuel", TwoSamuel),
            ("1 Kings", OneKings),
            ("2 Kings", TwoKings),
            ("1 Chronicles", OneChronicles),
            ("2 Chronicles", TwoChronicles),
            ("Ezra", Ezra),
            ("Nehemiah", Nehemiah),
            ("Esther", Esther),
            ("Job", Job),
            ("Psalms", Psalms),
            ("Proverbs", Proverbs),
            ("Ecclesiastes", Ecclesiastes),
            ("Song of Songs", SongOfSongs),
            ("Isaiah", Isaiah),
            ("Jeremiah", Jeremiah),
            ("Lamentations", Lamentations),
            ("Ezekiel", Ezekiel),
            ("Daniel", Daniel),
            ("Hosea", Hosea),
            ("Joel", Joel),
            ("Amos", Amos),
            ("Obadiah", Obadiah),
            ("Jonah", Jonah),
            ("Micah", Micah),
            ("Nahum", Nahum),
            ("Habakkuk", Habakkuk),
            ("Zephaniah", Zephaniah),
            ("Haggai", Haggai),
            ("Zechariah", Zechariah),
            ("Malachi", Malachi),
            ("Matthew", Matthew),
            ("Mark", Mark),
            ("Luke", Luke),
            ("John", John),
            ("Acts", Acts),
            ("Romans", Romans),
            ("1 Corinthians", OneCorinthians),
            ("2 Corinthians", TwoCorinthians),
            ("Galatians", Galatians),
            ("Ephesians", Ephesians),
            ("Philippians", Philippians),
            ("Colossians", Colossians),
            ("1 Thessalonians", OneThessalonians),
            ("2 Thessalonians", TwoThessalonians),
            ("1 Timothy", OneTimothy),
            ("2 Timothy", TwoTimothy),
            ("Titus", Titus),
            ("Philemon", Philemon),
            ("Hebrews", Hebrews),
            ("James", James),
            ("1 Peter", OnePeter),
            ("2 Peter", TwoPeter),
            ("1 John", OneJohn),
            ("2 John", TwoJohn),
            ("3 John", ThreeJohn),
            ("Jude", Jude),
            ("Revelation", Revelation),
        ]
    };

    /// Builds an index over all 66 books. Every book gets `chapters` chapters of
    /// `verses` verses each, with pages allocated sequentially so that each
    /// reference maps to a distinct, predictable page.
    fn index_with(chapters: u16, verses: u16) -> RefIndex {
        let mut builder = RefIndexBuilder::default();
        let mut page = 0usize;
        for (name, book) in BOOKS {
            let mut indices = Indices::new();
            indices.insert(Index::new(book.clone(), name.to_string(), None, None), page);
            page += 1;
            for c in 1..=chapters {
                indices.insert(Index::new(book.clone(), name.to_string(), Some(c), None), page);
                page += 1;
                for v in 1..=verses {
                    indices.insert(
                        Index::new(book.clone(), name.to_string(), Some(c), Some(v)),
                        page,
                    );
                    page += 1;
                }
            }
            builder.add(indices);
        }
        builder.finish()
    }

    fn refs(index: &RefIndex, query: &str, limit: usize) -> Vec<String> {
        index
            .lookup(query, limit)
            .into_iter()
            .map(|h| match (h.chapter, h.verse) {
                (Some(c), Some(v)) => format!("{} {}:{}", index.book_name[h.book], c, v),
                (Some(c), None) => format!("{} {}", index.book_name[h.book], c),
                _ => index.book_name[h.book].clone(),
            })
            .collect()
    }

    // --- Folding ---

    #[test]
    fn folding_strips_case_accents_and_punctuation() {
        assert_eq!(fold("1 John"), "1john");
        assert_eq!(fold("Song of Songs"), "songofsongs");
        assert_eq!(fold("Éphésiens"), "ephesiens");
        assert_eq!(fold("Ma\u{0301}rk"), "mark");
        assert_eq!(fold("  "), "");
    }

    #[test]
    fn subsequence_and_span() {
        assert!(is_subsequence("gen", "genesis"));
        assert!(is_subsequence("mt", "matthew"));
        assert!(!is_subsequence("gen", "exodus"));
        assert_eq!(match_span("gen", "genesis"), Some(3));
        assert_eq!(match_span("mt", "matthew"), Some(3));
        assert_eq!(match_span("zzz", "genesis"), None);
    }

    // --- Parsing ---

    #[test]
    fn parses_book_chapter_verse() {
        let p = parse_reference("1 John 3:16");
        assert_eq!(p, ParsedRef { book: "1 John", chapter: Some("3"), verse: Some("16"), trailing_sep: false });
    }

    #[test]
    fn leading_numeral_stays_with_the_book() {
        assert_eq!(parse_reference("1 John").book, "1 John");
        assert_eq!(parse_reference("3 John").chapter, None);
        let p = parse_reference("3 john 1");
        assert_eq!((p.book, p.chapter, p.verse), ("3 john", Some("1"), None));
    }

    #[test]
    fn parses_without_separators() {
        let p = parse_reference("gen12");
        assert_eq!((p.book, p.chapter, p.verse), ("gen", Some("12"), None));
        let p = parse_reference("1co13:4");
        assert_eq!((p.book, p.chapter, p.verse), ("1co", Some("13"), Some("4")));
        let p = parse_reference("2ki2");
        assert_eq!((p.book, p.chapter, p.verse), ("2ki", Some("2"), None));
    }

    #[test]
    fn trailing_separator_signals_the_next_level() {
        assert!(parse_reference("gen ").trailing_sep);
        assert!(parse_reference("gen 1:").trailing_sep);
        assert!(!parse_reference("gen 1").trailing_sep);
        // "Gen." is an abbreviation, not a chapter separator, and parses the same.
        assert_eq!(parse_reference("Gen.").book, "Gen");
    }

    #[test]
    fn digits_without_a_letter_stay_book_text() {
        let p = parse_reference("23");
        assert_eq!((p.book, p.chapter), ("23", None));
        let p = parse_reference("1 1");
        assert_eq!((p.book, p.chapter), ("1 1", None));
    }

    // --- Book matching ---

    #[test]
    fn common_abbreviations_resolve_to_one_book() {
        let index = index_with(3, 3);
        for (query, expected) in [
            ("gen", "Genesis"),
            ("genesis", "Genesis"),
            ("ex", "Exodus"),
            ("num", "Numbers"),
            ("deut", "Deuteronomy"),
            ("judg", "Judges"),
            ("2ki", "2 Kings"),
            ("1ch", "1 Chronicles"),
            ("ps", "Psalms"),
            ("psa", "Psalms"),
            ("prov", "Proverbs"),
            ("eccl", "Ecclesiastes"),
            ("song", "Song of Songs"),
            ("sng", "Song of Songs"),
            ("isa", "Isaiah"),
            ("jer", "Jeremiah"),
            ("lam", "Lamentations"),
            ("ezek", "Ezekiel"),
            ("dan", "Daniel"),
            ("hos", "Hosea"),
            ("joel", "Joel"),
            ("amos", "Amos"),
            ("obad", "Obadiah"),
            ("jonah", "Jonah"),
            ("mic", "Micah"),
            ("nah", "Nahum"),
            ("hab", "Habakkuk"),
            ("zep", "Zephaniah"),
            ("zech", "Zechariah"),
            ("mal", "Malachi"),
            ("mat", "Matthew"),
            ("mk", "Mark"),
            ("lk", "Luke"),
            ("john", "John"),
            ("acts", "Acts"),
            ("rom", "Romans"),
            ("1co", "1 Corinthians"),
            ("php", "Philippians"),
            ("heb", "Hebrews"),
            ("jas", "James"),
            ("1jo", "1 John"),
            ("1 jo", "1 John"),
            ("rev", "Revelation"),
        ] {
            let hits = index.lookup(query, 5);
            assert_eq!(hits[0].level, LEVEL_BOOK, "{query}");
            assert_eq!(index.book_name[hits[0].book], expected, "{query}");
            // Resolved, so the rest of the list is that book's chapters.
            assert!(
                hits[1..].iter().all(|h| h.level == LEVEL_CHAPTER && h.book == hits[0].book),
                "{query} did not resolve to a single book",
            );
        }
    }

    #[test]
    fn genuinely_ambiguous_prefixes_list_every_match() {
        let index = index_with(3, 3);
        for (query, expected) in [
            ("ez", vec!["Ezra", "Ezekiel"]),
            ("phil", vec!["Philippians", "Philemon"]),
            ("cor", vec!["1 Corinthians", "2 Corinthians"]),
            ("tim", vec!["1 Timothy", "2 Timothy"]),
            ("pet", vec!["1 Peter", "2 Peter"]),
            ("sam", vec!["1 Samuel", "2 Samuel"]),
            ("chr", vec!["1 Chronicles", "2 Chronicles"]),
            ("ki", vec!["1 Kings", "2 Kings"]),
        ] {
            let hits = index.lookup(query, 8);
            assert!(hits.iter().all(|h| h.level == LEVEL_BOOK), "{query}");
            let names: Vec<_> = hits.iter().map(|h| index.book_name[h.book].as_str()).collect();
            assert_eq!(names, expected, "{query}");
        }
    }

    #[test]
    fn exact_name_wins_over_books_that_merely_contain_it() {
        let index = index_with(3, 3);
        // "john" is a subsequence of 1/2/3 John too, but only John matches exactly.
        assert_eq!(refs(&index, "john", 1), vec!["John"]);
        // Whereas a shared prefix with no exact match stays ambiguous.
        assert_eq!(refs(&index, "jo", 4), vec!["Joshua", "Job", "Joel", "Jonah"]);
    }

    #[test]
    fn unknown_book_returns_nothing_for_semantic_fallback() {
        let index = index_with(3, 3);
        assert!(index.lookup("in the beginning god created", 5).is_empty());
        assert!(index.lookup("xyzzy", 5).is_empty());
        assert!(index.lookup("", 5).is_empty());
        assert!(index.lookup("   ", 5).is_empty());
    }

    #[test]
    fn accented_book_names_match_unaccented_queries() {
        let mut builder = RefIndexBuilder::default();
        let mut indices = Indices::new();
        indices.insert(
            Index::new(BookIdentifier::Ephesians, "Éphésiens".to_string(), None, None),
            7,
        );
        builder.add(indices);
        let index = builder.finish();
        assert_eq!(index.lookup("eph", 5)[0].page, 7);
        assert_eq!(index.lookup("éph", 5)[0].page, 7);
    }

    // --- Cascade ---

    #[test]
    fn resolved_book_lists_the_book_then_its_chapters() {
        let index = index_with(50, 31);
        assert_eq!(
            refs(&index, "gen", 5),
            vec!["Genesis", "Genesis 1", "Genesis 2", "Genesis 3", "Genesis 4"],
        );
        // A trailing separator means the same thing: start browsing chapters.
        assert_eq!(refs(&index, "gen ", 3), vec!["Genesis", "Genesis 1", "Genesis 2"]);
    }

    #[test]
    fn chapter_digits_match_on_prefix_with_the_exact_one_first() {
        let index = index_with(50, 31);
        assert_eq!(
            refs(&index, "gen 1", 5),
            vec!["Genesis 1", "Genesis 10", "Genesis 11", "Genesis 12", "Genesis 13"],
        );
        // Two digits narrow it to a single chapter, which then resolves.
        assert_eq!(refs(&index, "gen 12", 1), vec!["Genesis 12"]);
    }

    #[test]
    fn a_typed_verse_resolves_an_ambiguous_chapter_to_the_exact_one() {
        let index = index_with(50, 31);
        assert_eq!(
            refs(&index, "gen 1:1", 5),
            vec!["Genesis 1:1", "Genesis 1:10", "Genesis 1:11", "Genesis 1:12", "Genesis 1:13"],
        );
        // The colon alone is enough to commit to chapter 1 and start browsing.
        assert_eq!(
            refs(&index, "gen 1:", 4),
            vec!["Genesis 1", "Genesis 1:1", "Genesis 1:2", "Genesis 1:3"],
        );
    }

    #[test]
    fn three_digit_chapters_narrow_the_way_two_digit_ones_do() {
        let index = index_with(150, 176);
        assert_eq!(
            refs(&index, "ps 11", 5),
            vec!["Psalms 11", "Psalms 110", "Psalms 111", "Psalms 112", "Psalms 113"],
        );
        // 119 prefixes nothing longer, so it resolves and offers its verses.
        assert_eq!(
            refs(&index, "ps 119", 3),
            vec!["Psalms 119", "Psalms 119:1", "Psalms 119:2"],
        );
        assert_eq!(refs(&index, "ps 119:176", 5), vec!["Psalms 119:176"]);
        // The colon commits to 11 rather than 110-119, even though "11" alone
        // would still be ambiguous.
        assert_eq!(
            refs(&index, "ps 11:", 3),
            vec!["Psalms 11", "Psalms 11:1", "Psalms 11:2"],
        );
    }

    #[test]
    fn a_unique_verse_is_the_only_result() {
        let index = index_with(50, 31);
        assert_eq!(refs(&index, "gen 12:20", 5), vec!["Genesis 12:20"]);
        assert_eq!(refs(&index, "1 john 3:16", 5), vec!["1 John 3:16"]);
    }

    #[test]
    fn out_of_range_numbers_fall_back_to_the_nearest_real_reference() {
        let index = index_with(50, 31);
        // Genesis has 50 chapters, so 99 cannot match — offer the book.
        assert_eq!(refs(&index, "gen 99", 5), vec!["Genesis"]);
        // Chapter 1 has 31 verses, so 99 cannot match — offer the chapter.
        assert_eq!(refs(&index, "gen 1:99", 5), vec!["Genesis 1"]);
    }

    #[test]
    fn ambiguous_book_ignores_the_chapter_rather_than_guessing() {
        let index = index_with(50, 31);
        assert_eq!(refs(&index, "phil 3", 5), vec!["Philippians", "Philemon"]);
    }

    #[test]
    fn limit_is_respected_at_every_level() {
        let index = index_with(50, 31);
        for query in ["gen", "gen ", "gen 1", "gen 1:", "gen 1:1", "jo"] {
            for limit in 1..=5 {
                assert!(index.lookup(query, limit).len() <= limit, "{query} @ {limit}");
            }
            assert!(index.lookup(query, 0).is_empty(), "{query} @ 0");
        }
    }

    // --- Pages ---

    #[test]
    fn hits_carry_the_page_the_reference_was_rendered_on() {
        let index = index_with(2, 2);
        // Genesis: page 0 title, 1 = ch1, 2 = 1:1, 3 = 1:2, 4 = ch2, 5 = 2:1, 6 = 2:2.
        assert_eq!(index.lookup("gen", 1)[0].page, 0);
        assert_eq!(index.lookup("gen 1", 1)[0].page, 1);
        assert_eq!(index.lookup("gen 1:2", 1)[0].page, 3);
        assert_eq!(index.lookup("gen 2:1", 1)[0].page, 5);
    }

    #[test]
    fn page_of_resolves_semantic_results() {
        let index = index_with(2, 2);
        assert_eq!(index.page_of("GEN", None, None), Some(0));
        assert_eq!(index.page_of("GEN", Some(2), None), Some(4));
        assert_eq!(index.page_of("GEN", Some(2), Some(2)), Some(6));
        assert_eq!(index.page_of("GEN", Some(9), None), None);
        assert_eq!(index.page_of("ZZZ", None, None), None);
    }

    #[test]
    fn page_or_nearest_degrades_instead_of_failing() {
        let index = index_with(2, 2);
        // A verse the translation does not carry falls back to its chapter.
        assert_eq!(index.page_or_nearest("GEN", Some(2), Some(9)), 4);
        // A chapter it does not carry falls back to the book.
        assert_eq!(index.page_or_nearest("GEN", Some(9), Some(1)), 0);
        // An unknown book is page 0 rather than a panic.
        assert_eq!(index.page_or_nearest("ZZZ", Some(1), Some(1)), 0);
    }

    #[test]
    fn builder_recovers_pages_for_markers_that_never_landed() {
        // A book and chapter with no marker of their own, only verses.
        let mut builder = RefIndexBuilder::default();
        let mut indices = Indices::new();
        indices.insert(
            Index::new(BookIdentifier::Jude, "Jude".to_string(), Some(1), Some(3)),
            11,
        );
        indices.insert(
            Index::new(BookIdentifier::Jude, "Jude".to_string(), Some(1), Some(1)),
            9,
        );
        builder.add(indices);
        let index = builder.finish();
        assert_eq!(index.page_of("JUD", None, None), Some(9));
        assert_eq!(index.page_of("JUD", Some(1), None), Some(9));
        assert_eq!(index.page_of("JUD", Some(1), Some(3)), Some(11));
    }

    // --- End to end ---

    /// Renders `test.usfm` through the real layout engine and indexes what it
    /// emits, so the builder is checked against the renderer's actual output
    /// rather than a hand-built map.
    #[test]
    fn indexes_what_the_renderer_actually_emits() {
        use skia_safe::FontMgr;
        use std::ffi::c_char;

        use crate::painter::{Dimensions, Paint, Painter, Renderer, Style, TextStyle};

        let root = std::path::Path::new(env!("CARGO_MANIFEST_DIR"));
        let usfm = std::fs::read_to_string(root.join("test.usfm")).unwrap();
        let font = std::fs::read(
            root.join("../assets/fonts/AveriaSerifLibre-Regular.ttf"),
        )
        .unwrap();

        let book = usfm::parse(&usfm);
        let bytes = rkyv::to_bytes::<RkyvError>(&book).unwrap();
        let archived = rkyv::access::<usfm::ArchivedBook, RkyvError>(&bytes).unwrap();

        let mut renderer = Renderer::new();
        renderer.register_typeface(
            FontMgr::new().new_from_data(&font, None).unwrap(),
            "AveriaSerifLibre",
        );
        let family = "AveriaSerifLibre";
        for (style, size, height) in [
            (Style::Normal, 16.0, 1.5),
            (Style::Header, 24.0, 1.0),
            (Style::Verse, 10.0, 1.0),
            (Style::Chapter, 48.0, 1.0),
            (Style::Word, 16.0, 1.5),
            (Style::Caller, 10.0, 1.0),
            (Style::Footnote, 12.0, 1.5),
            (Style::CrossRef, 12.0, 1.5),
        ] {
            renderer.insert_style(
                style,
                TextStyle {
                    font_family: family.as_ptr() as *const c_char,
                    font_family_len: family.len(),
                    font_size: size,
                    height,
                    letter_spacing: 0.0,
                    word_spacing: 0.0,
                    underline: 0,
                },
            );
        }

        let mut painter = Painter::new(
            &renderer,
            Dimensions { width: 344.0, height: 702.0, header_height: 702.0 / 5.0, drop_cap_padding: 20.0, columns: 2, gutter: 16.0 },
        );
        archived.paint(&mut painter);
        let (pages, indices) = painter.layout();
        assert!(!indices.is_empty(), "renderer produced no indices");

        let mut builder = RefIndexBuilder::default();
        builder.add(indices.clone());
        let index = builder.finish();

        // \id JHN with \h "Test Book": the code drives page lookup, the header
        // drives name matching.
        assert_eq!(index.book_count(), 1);
        assert_eq!(index.book_name("JHN"), Some("Test Book"));

        // Every rendered reference is reachable, on the page it was laid out on.
        for (reference, &page) in &indices {
            assert_eq!(
                index.page_of(reference.book.to_identifier(), reference.chapter, reference.verse),
                Some(page as u32),
                "{reference:?}",
            );
            assert!(page < pages.len(), "{reference:?} points past the last page");
        }

        // And the query path reaches them by name.
        assert_eq!(refs(&index, "test", 1), vec!["Test Book"]);
        let verse = &index.lookup("test 1:3", 1)[0];
        assert_eq!((verse.chapter, verse.verse), (Some(1), Some(3)));
        assert_eq!(
            verse.page as usize,
            indices[&Index::new(usfm::BookIdentifier::John, "Test Book".into(), Some(1), Some(3))],
        );
    }

    // --- FFI ---

    /// Drives the exact sequence Dart uses: build from serialized per-book
    /// `indices`, look up, read the hits, free everything.
    #[test]
    fn ffi_round_trip() {
        let mut books = Vec::new();
        for (name, book) in [("Genesis", BookIdentifier::Genesis), ("John", BookIdentifier::John)] {
            let mut indices = Indices::new();
            indices.insert(Index::new(book.clone(), name.to_string(), None, None), 0);
            indices.insert(Index::new(book.clone(), name.to_string(), Some(3), None), 1);
            indices.insert(Index::new(book, name.to_string(), Some(3), Some(16)), 2);
            books.push(rkyv::to_bytes::<RkyvError>(&indices).unwrap());
        }

        let mut error: *mut c_char = std::ptr::null_mut();
        let mut error_len: usize = 0;

        let builder = ref_index_builder_new();
        for bytes in &books {
            ref_index_builder_add(builder, bytes.as_ptr(), bytes.len(), &mut error, &mut error_len);
            assert_eq!(error_len, 0);
        }
        let index = ref_index_builder_finish(builder, &mut error, &mut error_len);
        assert_eq!(error_len, 0);
        assert!(!index.is_null());

        let query = "john 3:16";
        let mut hits: *const RefHit = std::ptr::null();
        let mut len: usize = 0;
        ref_index_lookup(
            index,
            query.as_ptr(),
            query.len(),
            5,
            &mut hits,
            &mut len,
            &mut error,
            &mut error_len,
        );
        assert_eq!(error_len, 0);
        assert_eq!(len, 1);

        let hit = unsafe { &*hits };
        let book = unsafe { std::slice::from_raw_parts(hit.book, hit.book_len) };
        let header = unsafe { std::slice::from_raw_parts(hit.header, hit.header_len) };
        assert_eq!(std::str::from_utf8(book).unwrap(), "JHN");
        assert_eq!(std::str::from_utf8(header).unwrap(), "John");
        assert_eq!((hit.page, hit.chapter, hit.verse), (2, 3, 16));

        ref_hits_free(hits as *mut RefHit, len);
        ref_index_free(index);
    }

    #[test]
    fn ffi_lookup_of_a_non_reference_returns_an_empty_array() {
        let mut error: *mut c_char = std::ptr::null_mut();
        let mut error_len: usize = 0;
        let builder = ref_index_builder_new();
        let index = ref_index_builder_finish(builder, &mut error, &mut error_len);

        let query = "the beginning";
        let mut hits: *const RefHit = std::ptr::null();
        let mut len: usize = 1;
        ref_index_lookup(
            index,
            query.as_ptr(),
            query.len(),
            5,
            &mut hits,
            &mut len,
            &mut error,
            &mut error_len,
        );
        assert_eq!(error_len, 0);
        assert_eq!(len, 0);

        ref_hits_free(hits as *mut RefHit, len);
        ref_index_free(index);
    }

    #[test]
    fn ffi_reads_the_book_title_out_of_raw_indices() {
        let mut indices = Indices::new();
        indices.insert(
            Index::new(BookIdentifier::Genesis, "Genesis".to_string(), Some(1), Some(1)),
            1,
        );
        indices.insert(Index::new(BookIdentifier::Genesis, "Genesis".to_string(), None, None), 0);
        let bytes = rkyv::to_bytes::<RkyvError>(&indices).unwrap();

        let mut error: *mut c_char = std::ptr::null_mut();
        let mut error_len: usize = 0;
        let mut out: *const u8 = std::ptr::null();
        let mut out_len: usize = 0;
        indices_book_title(
            bytes.as_ptr(),
            bytes.len(),
            &mut out,
            &mut out_len,
            &mut error,
            &mut error_len,
        );
        assert_eq!(error_len, 0);
        let title = unsafe { std::slice::from_raw_parts(out, out_len) };
        assert_eq!(std::str::from_utf8(title).unwrap(), "Genesis");
    }

    #[test]
    fn chapters_and_verses_are_stored_ascending() {
        let index = index_with(12, 12);
        for b in 0..index.book_count() {
            let chapters = &index.ch_num[index.ch_start[b] as usize..index.ch_start[b + 1] as usize];
            assert!(chapters.windows(2).all(|w| w[0] < w[1]));
        }
        for c in 0..index.chapter_count() {
            let verses = &index.vs_num[index.vs_start[c] as usize..index.vs_start[c + 1] as usize];
            assert!(verses.windows(2).all(|w| w[0] < w[1]));
        }
    }
}

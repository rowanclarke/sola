use std::collections::{HashMap, VecDeque};
use std::ffi::{CString, c_void};
use std::mem;
use std::os::raw::c_char;
use std::slice::from_raw_parts;
use std::str::from_utf8_unchecked;
use usfm::{BookContents, CharacterContents, ParagraphContents, parse};

pub type CharsMap = HashMap<u32, (f32, f32)>;

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
            .map(|c| (c as u32, (0.0, 0.0)))
            .collect(),
    );
    let mut chars: Vec<u32> = map.keys().cloned().collect();
    chars.sort();
    let chars = chars.leak();
    unsafe {
        *out = chars.as_ptr();
        *out_len = chars.len();
    }
    Box::into_raw(map) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn insert(map: *mut c_void, chr: u32, width: f32, height: f32) {
    let map = unsafe { &mut *(map as *mut CharsMap) };
    map.insert(chr, (width, height));
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
    let mut paragraphs = usfm
        .contents
        .iter()
        .filter_map(|c| match c {
            BookContents::Paragraph { contents, .. } => Some(contents),
            _ => None,
        })
        .take(1);
    let mut layout = Box::new(Layout::new(map, *dim));
    let paragraph = paragraphs.next().unwrap();
    layout.layout(paragraph);
    Box::into_raw(layout) as *mut c_void
}

#[unsafe(no_mangle)]
pub extern "C" fn page(layout: *const c_void, out: *mut *const Text, out_len: *mut usize) {
    let layout = unsafe { &*(layout as *const Layout) };
    unsafe {
        *out = layout.page.as_ptr();
        *out_len = layout.page.len();
    }
}

pub type Book = Vec<Page>;
pub type Page = Vec<Text>;

#[derive(Debug)]
#[repr(C)]
pub struct Text(pub *const c_char, pub usize, pub Rectangle, pub Style);

#[derive(Debug)]
#[repr(C)]
pub struct Rectangle {
    pub top: f32,
    pub left: f32,
    pub width: f32,
    pub height: f32,
}

#[derive(Debug)]
#[repr(C)]
pub struct Style {
    pub word_spacing: f32,
}

#[derive(Debug)]
#[repr(C)]
pub struct Dimensions {
    pub width: f32,
    pub height: f32,
    pub line_height: f32,
}

#[derive(Debug)]
pub struct Layout<'a> {
    dim: Dimensions,
    pub page: Page,
    line: Line,
    pub text: Vec<Inline>,
    queue: VecDeque<Inline>,
    map: &'a CharsMap,
}

#[derive(Debug)]
pub struct Line {
    start: bool,
    top: f32,
    left: f32,
    width: f32,
    rem: f32,
}

#[derive(Debug)]
pub enum Inline {
    Word(String, f32),
    Space(f32),
}

impl<'a> Layout<'a> {
    pub fn new(map: &'a CharsMap, dim: Dimensions) -> Self {
        Self {
            map,
            line: Line {
                start: true,
                top: 0.0,
                left: 0.0,
                width: dim.width,
                rem: dim.width,
            },
            dim,
            page: Page::new(),
            text: Vec::new(),
            queue: VecDeque::new(),
        }
    }

    pub fn layout(&mut self, paragraph: &Vec<ParagraphContents>) {
        for contents in paragraph {
            use ParagraphContents::*;
            match contents {
                Verse(n) => {
                    self.queue.push_back(self.space());
                    self.queue.push_back(self.word(&n.to_string()));
                }
                Line(s) => self.line(s),
                Character { contents, .. } => self.character(contents),
                _ => (),
            }
        }
        self.write_line(false);
    }

    pub fn character(&mut self, contents: &Vec<CharacterContents>) {
        use CharacterContents::*;
        for contents in contents {
            match contents {
                Line(s) => self.line(s),
                Character { contents, .. } => self.character(contents),
            }
        }
    }

    pub fn line(&mut self, s: &str) {
        let words = words(s);
        for w in words {
            match w {
                " " => self.queue.push_back(self.space()),
                w => {
                    self.queue.push_back(self.word(w));
                    self.commit_or_else();
                }
            }
        }
    }

    pub fn word(&self, s: &str) -> Inline {
        let width = s.chars().map(|c| self.map[&(c as u32)].0).sum::<f32>();
        Inline::Word(s.to_string(), width)
    }

    pub fn space(&self) -> Inline {
        Inline::Space(self.map[&(' ' as u32)].0)
    }

    pub fn commit_or_else(&mut self) {
        if self.commit().is_err() {
            self.write_line(true);
        }
    }

    pub fn write_line(&mut self, justified: bool) {
        let rect = Rectangle {
            top: self.line.top,
            left: self.line.left,
            width: self.line.width,
            height: self.dim.height,
        };
        let (text, spaces, width) =
            self.text
                .iter()
                .fold((String::new(), 0.0, 0.0), |(s, n, w), i| match i {
                    Inline::Word(text, width) => (s + text, n, w + width),
                    Inline::Space(width) => (s + " ", n + 1.0, w + width),
                });
        self.text = Vec::new();
        let style = Style {
            word_spacing: if justified {
                self.line.rem / spaces
            } else {
                0.0
            },
        };
        let text = text.into_bytes();
        let len = text.len();
        let ptr = text.as_ptr() as *const c_char;
        std::mem::forget(text);
        self.page.push(Text(ptr, len, rect, style));
        if self.new_line().is_err() {
            println!("End");
        }
    }

    pub fn commit(&mut self) -> Result<(), ()> {
        if self.line.start && matches!(self.queue[0], Inline::Space(_)) {
            self.queue.pop_front();
        }
        let width: f32 = self
            .queue
            .iter()
            .map(|i| match i {
                Inline::Word(_, width) | Inline::Space(width) => width,
            })
            .sum();
        if width <= self.line.rem {
            self.line.rem -= width;
            let queue = mem::replace(&mut self.queue, VecDeque::new());
            self.text.extend(queue);
            self.line.start = false;
            Ok(())
        } else {
            Err(())
        }
    }

    pub fn new_line(&mut self) -> Result<(), ()> {
        self.line = Line {
            start: true,
            top: self.line.top + self.dim.line_height,
            left: self.line.left,
            width: self.dim.width,
            rem: self.dim.width,
        };
        if self.line.top + self.dim.line_height <= self.dim.height {
            Ok(())
        } else {
            Err(())
        }
    }
}

pub struct Words<'a> {
    s: &'a str,
}

impl<'a> Iterator for Words<'a> {
    type Item = &'a str;
    fn next(&mut self) -> Option<Self::Item> {
        if self.s.is_empty() {
            return None;
        }
        let s = match self.s.split(' ').next().unwrap() {
            "" => " ",
            w => w,
        };
        self.s = &self.s[s.len()..];
        Some(s)
    }
}

pub fn words<'a>(s: &'a str) -> Words<'a> {
    Words { s }
}

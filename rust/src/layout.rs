#[cfg(test)]
mod tests;

use std::{collections::VecDeque, ffi::c_char, mem};

use itertools::Itertools;
use usfm::{BookContents, CharacterContents, ParagraphContents};

use crate::{CharsMap, Style, words::words};

#[derive(Debug)]
pub struct Layout<'a> {
    dim: Dimensions,
    pages: Vec<Page>,
    line: Line,
    text: Vec<Inline>,
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

type Inline = (String, Style, f32);

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
            pages: vec![Page::new()],
            text: Vec::new(),
            queue: VecDeque::new(),
        }
    }

    pub fn layout(&mut self, contents: &Vec<BookContents>) {
        use BookContents::*;
        for contents in contents.into_iter().take(18) {
            match contents {
                Paragraph { contents, .. } => self.paragraph(contents),
                _ => (),
            }
        }
    }

    pub fn page(&self, n: usize) -> &Page {
        &self.pages[n]
    }

    fn paragraph(&mut self, contents: &Vec<ParagraphContents>) {
        use ParagraphContents::*;
        for contents in contents {
            match contents {
                Verse(n) => {
                    self.queue.push_back(self.space(Style::Normal));
                    self.queue
                        .push_back(self.word(&n.to_string(), Style::Verse));
                }
                Line(s) => self.line(s),
                Character { contents, .. } => self.character(contents),
                _ => (),
            }
        }
        self.commit().unwrap();
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
                " " => {
                    self.commit_or_else();
                    self.queue.push_back(self.space(Style::Normal));
                }
                w => self.queue.push_back(self.word(w, Style::Normal)),
            }
        }
    }

    pub fn word(&self, s: &str, style: Style) -> Inline {
        let width = s.chars().map(|c| self.map[&(c as u32, style)]).sum::<f32>();
        (s.to_string(), style, width)
    }

    pub fn space(&self, style: Style) -> Inline {
        let width = self.map[&(' ' as u32, Style::Normal)];
        (" ".to_string(), style, width)
    }

    pub fn commit_or_else(&mut self) {
        if self.commit().is_err() {
            self.write_line(true);
        }
    }

    pub fn write_line(&mut self, justified: bool) {
        let current = self.pages.last_mut().unwrap();
        let whitespace: f32 = self
            .text
            .iter()
            .filter(|(text, _, _)| text == " ")
            .map(|(_, _, width)| width)
            .sum();
        let ratio = self.line.rem / whitespace;
        let mut left = self.line.left;
        for (style, group) in self.text.iter().chunk_by(|(_, style, _)| style).into_iter() {
            let (text, whitespace, spaces, width) = group.fold(
                (String::new(), 0.0, 0.0, 0.0),
                |(acc, whitespace, spaces, total), (text, _, width)| {
                    (
                        acc + text,
                        match text.as_str() {
                            " " => whitespace + width,
                            _ => whitespace,
                        },
                        match text.as_str() {
                            " " => spaces + 1.0,
                            _ => spaces,
                        },
                        total + width,
                    )
                },
            );
            let spacing = ratio * whitespace;
            let width = width + spacing;
            let rect = Rectangle {
                top: self.line.top,
                left,
                width,
                height: self.dim.line_height,
            };
            left += width;
            let style = TextStyle {
                style: style.clone(),
                word_spacing: if justified { spacing / spaces } else { 0.0 },
            };
            let text = text.into_bytes();
            let len = text.len();
            let ptr = text.as_ptr() as *const c_char;
            std::mem::forget(text);
            current.push(Text(ptr, len, rect, style));
        }
        self.text = Vec::new();
        if self.new_line().is_err() {
            self.line = Line {
                start: true,
                top: 0.0,
                left: 0.0,
                width: self.dim.width,
                rem: self.dim.width,
            };
            self.pages.push(Page::new());
        }
    }

    pub fn commit(&mut self) -> Result<(), ()> {
        if self.line.start && self.queue[0].0 == " " {
            self.queue.pop_front();
        }
        let width: f32 = self.queue.iter().map(|i| i.2).sum();
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

pub type Page = Vec<Text>;

#[derive(Debug)]
#[repr(C)]
pub struct Text(*const c_char, usize, Rectangle, TextStyle);

#[derive(Debug)]
#[repr(C)]
pub struct Rectangle {
    top: f32,
    left: f32,
    width: f32,
    height: f32,
}

#[derive(Debug)]
#[repr(C)]
pub struct TextStyle {
    style: Style,
    word_spacing: f32,
}

#[derive(Debug)]
#[repr(C)]
pub struct Dimensions {
    width: f32,
    height: f32,
    line_height: f32,
}

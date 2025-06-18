#[cfg(test)]
mod tests;

use std::{collections::VecDeque, ffi::c_char, mem};

use usfm::{CharacterContents, ParagraphContents};

use crate::{CharsMap, words::words};

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
        let (text, spaces) = self
            .text
            .iter()
            .fold((String::new(), 0.0), |(s, n), i| match i {
                Inline::Word(text, _) => (s + text, n),
                Inline::Space(_) => (s + " ", n + 1.0),
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

pub type Book = Vec<Page>;
pub type Page = Vec<Text>;

#[derive(Debug)]
#[repr(C)]
pub struct Text(*const c_char, usize, Rectangle, Style);

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
pub struct Style {
    word_spacing: f32,
}

#[derive(Debug)]
#[repr(C)]
pub struct Dimensions {
    width: f32,
    height: f32,
    line_height: f32,
}

#[cfg(test)]
mod tests;

use std::{collections::VecDeque, ffi::c_char, mem};

use itertools::Itertools;
use usfm::{BookContents, CharacterContents, ElementContents, ElementType, ParagraphContents};

use crate::{CharsMap, Style, words::words};

#[derive(Debug)]
pub struct Layout<'a> {
    dim: Dimensions,
    region: Rectangle,
    lines: VecDeque<Line>,
    pages: Vec<Page>,
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
        let region = Rectangle {
            top: 0.0,
            left: 0.0,
            width: dim.width,
            height: dim.height,
        };
        Self {
            dim,
            region,
            lines: VecDeque::new(),
            pages: vec![Page::new()],
            text: Vec::new(),
            queue: VecDeque::new(),
            map,
        }
    }

    pub fn layout(&mut self, contents: &Vec<BookContents>) {
        use BookContents::*;
        for contents in contents.into_iter().take(18) {
            match contents {
                Chapter(n) => {
                    let height = self.dim.line_height * 2.0;
                    self.request(height);
                    let (text, style, width) = self.word(&n.to_string(), Style::Chapter);
                    let width = width + self.dim.header_padding;
                    let page = self.pages.last_mut().unwrap();
                    Self::write_text(
                        page,
                        text,
                        Rectangle {
                            top: self.region.top,
                            left: self.region.left,
                            width,
                            height,
                        },
                        TextStyle {
                            style,
                            word_spacing: 0.0,
                        },
                    );
                    self.lines.push_back(Line {
                        start: true,
                        top: self.region.top,
                        left: self.region.left + width,
                        width: self.region.width - width,
                        rem: self.region.width - width,
                    });
                    self.lines.push_back(Line {
                        start: true,
                        top: self.region.top + self.dim.line_height,
                        left: self.region.left + width,
                        width: self.region.width - width,
                        rem: self.region.width - width,
                    });
                    self.region.top += height;
                }
                Element { ty, contents } => self.element(ty, contents),
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
        self.next_line();
        for contents in contents {
            match contents {
                Verse(n) => {
                    self.queue.push_back(self.space(Style::Normal));
                    self.queue
                        .push_back(self.word(&n.to_string(), Style::Verse));
                }
                Line(s) => self.write(s),
                Character { contents, .. } => self.character(contents),
                _ => (),
            }
        }
        self.commit().unwrap();
        self.write_unjustified();
    }

    fn element(&mut self, ty: &ElementType, contents: &Vec<ElementContents>) {
        use ElementContents::*;
        use ElementType::*;
        for contents in contents {
            match (ty, contents) {
                (Header, Line(s)) => {
                    let height = self.dim.height / 5.0;
                    let (text, style, width) = self.word(&s, Style::Header);
                    let page = self.pages.last_mut().unwrap();
                    Self::write_text(
                        page,
                        text,
                        Rectangle {
                            top: (height - self.dim.header_height) / 2.0,
                            left: (self.dim.width - width) / 2.0,
                            width,
                            height: self.dim.header_height,
                        },
                        TextStyle {
                            style,
                            word_spacing: 0.0,
                        },
                    );
                    self.region.top = height;
                }
                _ => (),
            }
        }
    }

    fn character(&mut self, contents: &Vec<CharacterContents>) {
        use CharacterContents::*;
        for contents in contents {
            match contents {
                Line(s) => self.write(s),
                Character { contents, .. } => self.character(contents),
            }
        }
    }

    fn write(&mut self, s: &str) {
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

    fn word(&self, s: &str, style: Style) -> Inline {
        let width = s.chars().map(|c| self.map[&(c as u32, style)]).sum::<f32>();
        (s.to_string(), style, width)
    }

    fn space(&self, style: Style) -> Inline {
        let width = self.map[&(' ' as u32, Style::Normal)];
        (" ".to_string(), style, width)
    }

    fn commit_or_else(&mut self) {
        if self.commit().is_err() {
            self.write_justified();
        }
    }

    fn write_unjustified(&mut self) {
        let page = self.pages.last_mut().unwrap();
        let mut left = self.lines[0].left;
        for (style, group) in self.text.iter().chunk_by(|(_, style, _)| style).into_iter() {
            let (text, width) = group
                .fold((String::new(), 0.0), |(acc, total), (text, _, width)| {
                    (acc + text, total + width)
                });
            let rect = Rectangle {
                top: self.lines[0].top,
                left,
                width,
                height: self.dim.line_height,
            };
            left += width;
            let style = TextStyle {
                style: style.clone(),
                word_spacing: 0.0,
            };
            Self::write_text(page, text, rect, style);
        }
        self.pop_line();
    }

    fn write_justified(&mut self) {
        let page = self.pages.last_mut().unwrap();
        let whitespace: f32 = self
            .text
            .iter()
            .filter(|(text, _, _)| text == " ")
            .map(|(_, _, width)| width)
            .sum();
        let ratio = self.lines[0].rem / whitespace;
        let mut left = self.lines[0].left;
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
                top: self.lines[0].top,
                left,
                width,
                height: self.dim.line_height,
            };
            left += width;
            let style = TextStyle {
                style: style.clone(),
                word_spacing: spacing / spaces,
            };
            Self::write_text(page, text, rect, style);
        }
        self.pop_line();
        self.next_line();
    }

    fn commit(&mut self) -> Result<(), ()> {
        if self.lines[0].start && self.queue[0].0 == " " {
            self.queue.pop_front();
        }
        let width: f32 = self.queue.iter().map(|i| i.2).sum();
        if width <= self.lines[0].rem {
            self.lines[0].rem -= width;
            let queue = mem::replace(&mut self.queue, VecDeque::new());
            self.text.extend(queue);
            self.lines[0].start = false;
            Ok(())
        } else {
            Err(())
        }
    }

    fn write_text(page: &mut Page, text: String, rect: Rectangle, style: TextStyle) {
        let text = text.into_bytes();
        let len = text.len();
        let ptr = text.as_ptr() as *const c_char;
        std::mem::forget(text);
        page.push(Text(ptr, len, rect, style));
    }

    fn pop_line(&mut self) {
        self.text.drain(..);
        self.lines.pop_front();
    }

    fn next_line(&mut self) {
        if self.lines.is_empty() {
            self.request(self.dim.line_height);
            self.lines.push_back(Line {
                start: true,
                top: self.region.top,
                left: self.region.left,
                width: self.region.width,
                rem: self.region.width,
            });
            self.region.top += self.dim.line_height;
        }
    }

    fn next_page(&mut self) {
        self.pages.push(Page::new());
        self.region = Rectangle {
            top: 0.0,
            left: 0.0,
            width: self.dim.width,
            height: self.dim.height,
        };
        self.lines.drain(..);
    }

    fn request(&mut self, height: f32) {
        if self.region.top + height > self.dim.height {
            self.next_page();
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
    header_height: f32,
    header_padding: f32,
}

#[cfg(test)]
mod tests;

use std::{
    collections::VecDeque, ffi::c_char, mem, slice::from_raw_parts, str::from_utf8_unchecked,
};

use itertools::Itertools;
use skia_safe::{
    Font, FontMgr, GlyphId, Point, Shaper,
    shaper::{
        AsRunHandler, RunHandler,
        run_handler::{Buffer, RunInfo},
    },
    textlayout::{
        FontCollection, ParagraphBuilder, ParagraphStyle, TextStyle as ParagraphTextStyle,
    },
};
use usfm::{BookContents, CharacterContents, ElementContents, ElementType, ParagraphContents};

use crate::{Renderer, Style, TextStyle, log, words::words};

#[derive(Debug)]
pub struct Layout<'a> {
    renderer: &'a Renderer,
    dim: Dimensions,
    region: Rectangle,
    lines: VecDeque<Line>,
    pages: Vec<Page>,
    text: Vec<Inline>,
    queue: VecDeque<Inline>,
}

#[derive(Debug)]
pub struct Line {
    start: bool,
    top: f32,
    left: f32,
    rem: f32,
}

type Inline = (String, Style, f32);

impl<'a> Layout<'a> {
    pub fn new(renderer: &'a Renderer, dim: Dimensions) -> Self {
        let region = Rectangle {
            top: 0.0,
            left: 0.0,
            width: dim.width,
            height: dim.height,
        };
        Self {
            renderer,
            dim,
            region,
            lines: VecDeque::new(),
            pages: vec![Page::new()],
            text: Vec::new(),
            queue: VecDeque::new(),
        }
    }

    pub fn layout(&mut self, contents: &Vec<BookContents>) {
        use BookContents::*;
        for contents in contents.into_iter().take(18) {
            match contents {
                Chapter(n) => {
                    let text = n.to_string();
                    let width = self.renderer.measure_str(&text, &Style::Chapter);
                    let height = self.renderer.line_height(&Style::Chapter);
                    self.request(height);
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
                        Style::Chapter,
                        0.0,
                    );
                    self.lines.push_back(Line {
                        start: true,
                        top: self.region.top,
                        left: self.region.left + width,
                        rem: self.region.width - width,
                    });
                    self.lines.push_back(Line {
                        start: true,
                        top: self.region.top + self.renderer.line_height(&Style::Normal),
                        left: self.region.left + width,
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

    pub fn page(&self, n: usize) -> Vec<Text> {
        self.pages[n]
            .iter()
            .map(|PartialText(text, rect, style, word_spacing)| {
                let mut style = self.renderer.style_collection[&style];
                style.word_spacing += word_spacing;
                let text = text.as_bytes();
                let len = text.len();
                let ptr = text.as_ptr() as *const c_char;
                Text(ptr, len, *rect, style)
            })
            .collect()
    }

    fn paragraph(&mut self, contents: &Vec<ParagraphContents>) {
        use ParagraphContents::*;
        self.next_line(&Style::Normal);
        for contents in contents {
            match contents {
                Verse(n) => {
                    self.queue.push_back(self.inline(" ", Style::Normal));
                    self.queue
                        .push_back(self.inline(n.to_string(), Style::Verse));
                }
                Line(s) => self.write(s, Style::Normal),
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
                    let height = self.renderer.line_height(&Style::Header);
                    let (text, _, width) = self.inline(s, Style::Header);
                    let page = self.pages.last_mut().unwrap();
                    Self::write_text(
                        page,
                        text,
                        Rectangle {
                            top: (self.dim.header_height - height) / 2.0,
                            left: (self.dim.width - width) / 2.0,
                            width,
                            height: self.dim.header_height,
                        },
                        Style::Header,
                        0.0,
                    );
                    self.region.top = self.dim.header_height;
                }
                _ => (),
            }
        }
    }

    fn character(&mut self, contents: &Vec<CharacterContents>) {
        use CharacterContents::*;
        for contents in contents {
            match contents {
                Line(s) => self.write(s, Style::Normal),
                Character { contents, .. } => self.character(contents),
            }
        }
    }

    fn inline(&self, text: impl Into<String>, style: Style) -> Inline {
        let text = text.into();
        let width = self.renderer.measure_str(&text, &style);
        (text, style, width)
    }

    fn write(&mut self, s: &str, style: Style) {
        for word in words(s) {
            match word {
                " " => {
                    self.commit_or_else();
                    self.queue.push_back(self.inline(" ", style));
                }
                _ => self.queue.push_back(self.inline(word, style)),
            }
        }
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
                height: self.renderer.line_height(style),
            };
            left += width;
            Self::write_text(page, text, rect, style.clone(), 0.0);
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
                height: self.renderer.line_height(style),
            };
            left += width;
            Self::write_text(page, text, rect, style.clone(), spacing / spaces);
        }
        self.pop_line();
        self.next_line(&Style::Normal);
    }

    fn commit(&mut self) -> Result<(), ()> {
        if self.lines[0].start && self.queue[0].0 == " " {
            self.queue.pop_front();
        }
        let width: f32 = self.queue.iter().map(|i| i.2).sum();
        println!(
            "{:?} + {:?} with {} remaining",
            self.text, self.queue, self.lines[0].rem
        );
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

    fn write_text(page: &mut Page, text: String, rect: Rectangle, style: Style, word_spacing: f32) {
        println!("{} ({})", text, word_spacing);
        page.push(PartialText(text, rect, style, word_spacing));
    }

    fn pop_line(&mut self) {
        self.text.drain(..);
        self.lines.pop_front();
    }

    fn next_line(&mut self, style: &Style) {
        let height = self.renderer.line_height(style);
        if self.lines.is_empty() {
            self.request(height);
            self.lines.push_back(Line {
                start: true,
                top: self.region.top,
                left: self.region.left,
                rem: self.region.width,
            });
            self.region.top += height;
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

impl Renderer {
    fn line_height(&self, style: &Style) -> f32 {
        let text_style = &self.style_collection[style];
        text_style.height * text_style.font_size
    }

    pub fn measure_str(&self, text: &str, style: &Style) -> f32 {
        let text_style = &self.style_collection[style];
        let mut font_collection = FontCollection::new();
        let font_mgr: FontMgr = self.font_provider.clone().into();
        font_collection.set_default_font_manager(Some(font_mgr), None);
        let paragraph_style = ParagraphStyle::new();
        let mut builder = ParagraphBuilder::new(&paragraph_style, font_collection);
        let mut paragraph_text_style = ParagraphTextStyle::new();
        paragraph_text_style
            .set_font_size(text_style.font_size)
            .set_font_families(&[text_style.font_family()])
            .set_height(text_style.height)
            .set_letter_spacing(text_style.letter_spacing)
            .set_word_spacing(text_style.word_spacing);
        builder.push_style(&paragraph_text_style);
        builder.add_text(text);
        let mut paragraph = builder.build();
        paragraph.layout(f32::INFINITY);
        paragraph.max_intrinsic_width()
    }
}

impl TextStyle {
    fn font_family(&self) -> &str {
        unsafe {
            from_utf8_unchecked(from_raw_parts(
                self.font_family as *const u8,
                self.font_family_len,
            ))
        }
    }
}

struct WidthCollector {
    total_advance: f32,
    glyphs: Vec<GlyphId>,
    positions: Vec<Point>,
}

impl RunHandler for WidthCollector {
    fn begin_line(&mut self) {}
    fn run_info(&mut self, _info: &RunInfo) {}
    fn commit_run_info(&mut self) {}
    fn commit_line(&mut self) {}

    fn run_buffer(&mut self, info: &RunInfo) -> skia_safe::shaper::run_handler::Buffer {
        let count = info.glyph_count;

        self.glyphs.resize(count, 0);
        self.positions.resize(count, Point::new(0.0, 0.0));

        skia_safe::shaper::run_handler::Buffer {
            glyphs: &mut self.glyphs,
            positions: &mut self.positions,
            offsets: None,
            clusters: None,
            point: Point::new(0.0, 0.0),
        }
    }

    fn commit_run_buffer(&mut self, info: &RunInfo) {
        self.total_advance = info.advance.x;
    }
}

pub type Page = Vec<PartialText>;

#[derive(Debug)]
pub struct PartialText(String, Rectangle, Style, f32);

#[derive(Debug)]
#[repr(C)]
pub struct Text(*const c_char, usize, Rectangle, TextStyle);

#[derive(Debug, Clone, Copy)]
#[repr(C)]
pub struct Rectangle {
    top: f32,
    left: f32,
    width: f32,
    height: f32,
}

#[derive(Debug)]
#[repr(C)]
pub struct Dimensions {
    width: f32,
    height: f32,
    header_height: f32,
    header_padding: f32,
}

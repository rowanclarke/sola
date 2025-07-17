use std::collections::VecDeque;

use rkyv::{Archive, Serialize, vec::ArchivedVec};

use crate::log;

use super::{Rectangle, Style};

pub struct Line {
    pub top: f32,
    pub left: f32,
    pub width: f32,
    pub locked: bool,
    page: usize,
}

pub struct Layout {
    width: f32,
    height: f32,
    line_height: f32,
    body: Region,
    lines: VecDeque<Line>,
    pages: Vec<Page>,
}

pub type ArchivedPages = ArchivedVec<ArchivedPage>;
pub type ArchivedPage = <Page as Archive>::Archived;
pub type Page = Vec<PartialText>;

#[derive(Archive, Serialize, Debug)]
pub struct PartialText(pub String, pub Rectangle, pub Style, pub f32);

impl PartialText {
    pub fn new(text: String, rect: Rectangle, style: Style, word_spacing: f32) -> Self {
        Self(text, rect, style, word_spacing)
    }
}

#[derive(Clone)]
struct Region {
    top: f32,
    left: f32,
    width: f32,
}

impl Layout {
    pub fn new(width: f32, height: f32, line_height: f32) -> Self {
        Layout {
            width,
            height,
            line_height,
            body: Region {
                top: 0.0,
                left: 0.0,
                width,
            },
            lines: VecDeque::new(),
            pages: vec![Vec::new()],
        }
    }

    pub fn sub_layout(&self, width: f32, height: f32, line_height: f32) -> Self {
        Self {
            width,
            height,
            line_height,
            body: self.body.clone(),
            lines: VecDeque::new(),
            pages: vec![Vec::new()],
        }
    }

    pub fn get_line_height(&self) -> f32 {
        self.line_height
    }

    pub fn mutate_body(&mut self, height: f32) {
        self.body.top += height;
    }

    pub fn get_pages(&self) -> &'_ Vec<Page> {
        &self.pages
    }

    fn next_page(&mut self) {
        self.pages.push(Page::new());
        self.body = Region {
            top: 0.0,
            left: 0.0,
            width: self.width,
        }
    }

    pub fn request_height(&mut self, height: f32) -> usize {
        if self.body.top + height > self.height {
            self.next_page();
        }
        self.pages.len() - 1
    }

    pub fn next_line(&mut self) {
        let page = self.request_height(self.line_height);
        self.lines.push_back(Line {
            top: self.body.top,
            left: self.body.left,
            width: self.body.width,
            locked: false,
            page,
        });
        self.body.top += self.line_height;
    }

    pub fn get_line(&mut self, line: usize) -> &mut Line {
        for _ in self.lines.len()..=line {
            self.next_line();
        }
        &mut self.lines[line]
    }

    pub fn get_line_unchecked(&mut self, line: usize) -> &mut Line {
        &mut self.lines[line]
    }

    pub fn write_line(
        &mut self,
        line: usize,
        text: String,
        style: Style,
        width: f32,
        word_spacing: f32,
        top_offset: f32,
    ) {
        let line = &mut self.lines[line];
        let page = line.page;
        let rect = Rectangle {
            top: line.top + top_offset,
            left: line.left,
            width,
            height: self.line_height,
        };
        line.left += width;
        self.write(page, text, rect, style, word_spacing);
    }

    pub fn write(
        &mut self,
        page: usize,
        text: String,
        rect: Rectangle,
        style: Style,
        word_spacing: f32,
    ) {
        let text = PartialText::new(text, rect, style, word_spacing);
        self.pages[page].push(text);
    }

    pub fn from_body(&mut self, width: f32, height: f32) -> Rectangle {
        Rectangle {
            top: self.body.top,
            left: self.body.left,
            width,
            height,
        }
    }

    pub fn drain_lines(&mut self) {
        self.lines.drain(..);
    }
}

impl Line {
    pub fn get_width(&self) -> f32 {
        self.width
    }

    pub fn mutate(&mut self, left: f32, width: f32) -> &mut Self {
        if !self.locked {
            self.left += left;
            self.width += width;
        }
        self
    }

    pub fn lock(&mut self) -> &mut Self {
        self.locked = true;
        self
    }
}

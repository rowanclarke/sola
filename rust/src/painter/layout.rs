use std::collections::{HashMap, VecDeque};

use rkyv::{Archive, Deserialize, Serialize, vec::ArchivedVec};
use usfm::BookIdentifier;

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
    body: Area,
    footer: Area,
    pages: Vec<Page>,
    indices: Indices,
    verses: Vec<Index>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Section {
    Body,
    Footer,
}

pub enum Anchor {
    Top,
    Bottom,
}

pub enum Direction {
    RightToLeft,
    LeftToRight,
}

pub struct Area {
    region: Region,
    anchor: Anchor,
    direction: Direction,
    height: f32,
    line_height: f32,
    lines: VecDeque<Line>,
}

pub struct Write {
    page: usize,
    text: String,
    rect: Rectangle,
    style: Style,
    word_spacing: f32,
}

#[derive(Debug, PartialEq, Eq, Clone, Hash, Serialize, Archive, Deserialize)]
#[rkyv(derive(Debug, PartialEq, Eq, Hash))]
pub struct Index {
    pub book: BookIdentifier,
    pub header: String,
    pub chapter: Option<u16>,
    pub verse: Option<u16>,
}

impl Index {
    pub fn new(
        book: BookIdentifier,
        header: String,
        chapter: Option<u16>,
        verse: Option<u16>,
    ) -> Self {
        Self {
            book,
            header,
            chapter,
            verse,
        }
    }
}

pub type ArchivedPages = ArchivedVec<ArchivedPage>;
pub type ArchivedPage = <Page as Archive>::Archived;
pub type Page = Vec<TextFragment>;
pub type ArchivedIndices = <Indices as Archive>::Archived;
pub type Indices = HashMap<Index, usize>;

#[derive(Archive, Serialize, Debug)]
pub struct TextFragment {
    pub text: String,
    pub rect: Rectangle,
    pub style: Style,
    pub word_spacing: f32,
}

impl TextFragment {
    pub fn new(text: String, rect: Rectangle, style: Style, word_spacing: f32) -> Self {
        Self {
            text,
            rect,
            style,
            word_spacing,
        }
    }
}

#[derive(Clone)]
struct Region {
    top: f32,
    left: f32,
    width: f32,
}

impl Region {
    fn new(width: f32) -> Self {
        Self {
            top: 0.0,
            left: 0.0,
            width,
        }
    }
}

impl Layout {
    pub fn new(width: f32, height: f32, line_height: f32) -> Self {
        Layout {
            width,
            height,
            body: Area {
                region: Region::new(width),
                anchor: Anchor::Top,
                direction: Direction::LeftToRight,
                height: 0.0,
                line_height,
                lines: VecDeque::new(),
            },
            footer: Area {
                region: Region::new(width),
                anchor: Anchor::Bottom,
                direction: Direction::LeftToRight,
                height: 0.0,
                line_height,
                lines: VecDeque::new(),
            },
            pages: vec![Vec::new()],
            indices: HashMap::new(),
            verses: Vec::new(),
        }
    }

    pub fn mutate_body(&mut self, height: f32) {
        self.body.region.top += height;
    }

    pub fn add_verse_index(&mut self, index: Index, line: usize) {
        self.verses.push(index.clone());
        self.add_index(index, self.body.lines[line].page);
    }

    pub fn add_index(&mut self, index: Index, page: usize) {
        self.indices.insert(index, page);
    }

    pub fn get_pages(&self) -> &Vec<Page> {
        &self.pages
    }

    pub fn get_indices(&self) -> &Indices {
        &self.indices
    }

    pub fn get_verses(&self) -> &Vec<Index> {
        &self.verses
    }

    fn next_page(&mut self) {
        self.pages.push(Page::new());
        // TODO new body and footer areas
    }

    pub fn request_height(&mut self, height: f32) -> usize {
        if self.body.height + self.footer.height + height > self.height {
            self.next_page();
        }
        self.pages.len() - 1
    }

    pub fn next_line(&mut self, section: Section) {
        let page = self.request_height(self.area(section).line_height);
        self.area_mut(section).next_line(page);
    }

    pub fn get_line(&mut self, section: Section, line: usize) -> &mut Line {
        for _ in self.area(section).lines.len()..=line {
            self.next_line(section);
        }
        &mut self.area_mut(section).lines[line]
    }

    pub fn get_line_unchecked(&mut self, section: Section, line: usize) -> &mut Line {
        &mut self.area_mut(section).lines[line]
    }

    pub fn write_line(
        &mut self,
        section: Section,
        line: usize,
        text: String,
        style: Style,
        width: f32,
        word_spacing: f32,
        top_offset: f32,
    ) {
        let write = {
            self.area_mut(section)
                .write_line(line, text, style, width, word_spacing, top_offset)
        };
        self.write(write);
    }

    pub fn write(
        &mut self,
        Write {
            page,
            text,
            rect,
            style,
            word_spacing,
        }: Write,
    ) {
        let text = TextFragment::new(text, rect, style, word_spacing);
        self.pages[page].push(text);
    }

    pub fn drain_lines(&mut self) {
        self.body.drain_lines();
        self.footer.drain_lines();
    }

    fn area_mut(&mut self, section: Section) -> &mut Area {
        match section {
            Section::Body => &mut self.body,
            Section::Footer => &mut self.footer,
        }
    }

    fn area(&self, section: Section) -> &Area {
        match section {
            Section::Body => &self.body,
            Section::Footer => &self.footer,
        }
    }
}

impl Area {
    pub fn get_line_height(&self) -> f32 {
        self.line_height
    }

    pub fn next_line(&mut self, page: usize) {
        self.lines.push_back(Line {
            top: self.region.top,
            left: self.region.left,
            width: self.region.width,
            locked: false,
            page,
        });
        self.region.top += self.line_height;
    }

    pub fn write_line(
        &mut self,
        line: usize,
        text: String,
        style: Style,
        width: f32,
        word_spacing: f32,
        top_offset: f32,
    ) -> Write {
        let line = &mut self.lines[line];
        let page = line.page;
        // TODO for footer
        let rect = Rectangle {
            top: line.top + top_offset,
            left: line.left,
            width,
            height: self.line_height,
        };
        line.left += width;
        log!("> ({}, {:?}):\n{}", word_spacing, style, text);
        Write {
            page,
            text,
            rect,
            style,
            word_spacing,
        }
    }

    pub fn rectangle(&mut self, width: f32, height: f32) -> Rectangle {
        // TODO for footer
        // match self.anchor {
        //     todo!()
        // }
        Rectangle {
            top: self.region.top,
            left: self.region.left,
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

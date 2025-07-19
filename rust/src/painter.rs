mod format;
mod layout;
mod paint;
mod renderer;
mod writer;

use std::{ffi::c_char, ops, slice::from_ref};

use format::{Action, Format, get_unformatted, justify, left};
use layout::Layout;
pub use layout::{ArchivedIndex, ArchivedIndices, ArchivedPages, Index};
pub use paint::Paint;
use renderer::{Inline, inline};
pub use renderer::{Renderer, TextStyle};
use rkyv::{Archive, Deserialize, Serialize, rancor::Error, util::AlignedVec};
use skia_safe::textlayout::ParagraphBuilder;
use usfm::BookIdentifier;
use writer::{LineFormat, Writer};

use crate::log;

pub struct Painter {
    renderer: Renderer,
    builder: ParagraphBuilder,
    dim: Dimensions,
    properties: Vec<(usize, Properties)>,
    queue: Vec<Properties>,
    layout: Layout,
    index: PartialIndex,
}

#[derive(Default)]
struct PartialIndex {
    book: Option<BookIdentifier>,
    chapter: Option<u16>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Properties {
    style: Style,
    action: Option<Action>,
}

impl Painter {
    pub fn new(renderer: &Renderer, dim: Dimensions) -> Self {
        Self {
            renderer: renderer.clone(),
            builder: renderer.new_builder(),
            properties: Vec::new(),
            queue: Vec::new(),
            layout: Layout::new(dim.width, dim.height, renderer.line_height(&Style::Normal)),
            dim,
            index: PartialIndex::default(),
        }
    }

    fn get_dimensions(&self) -> &Dimensions {
        &self.dim
    }

    fn paint_region(&mut self, format: Format, height: f32) {
        let (_, text, inline) = inline(&self.renderer, &mut self.builder, &self.properties);
        // HACK assume line height is the first inline
        let line_height = self.renderer.line_height(&inline[0].properties.style);
        let mut layout = self.layout.sub_layout(self.dim.width, height, line_height);
        let mut writer = Writer::new(
            &text[..],
            inline.as_slice(),
            LineFormat::default(),
            &mut layout,
        );
        writer.write().trim();
        let unformatted = get_unformatted(&text, &inline, writer.get_lines());
        let page = self
            .layout
            .request_height(height + 2.0 * self.layout.get_line_height());
        self.layout.mutate_body(height);

        match format {
            Format::Center => {
                let total_height = unformatted.len() as f32 * line_height;
                let top_offset = (height - total_height) / 2.0;
                for line in unformatted {
                    let region = &layout.get_line_unchecked(line.line);
                    let rect = Rectangle {
                        top: region.top + top_offset,
                        left: region.left + line.metrics.remaining / 2.0,
                        width: line.width,
                        height: line_height,
                    };
                    self.layout.write(
                        page,
                        line.text.iter().collect::<String>(),
                        rect,
                        line.properties.style,
                        0.0,
                    );
                }
            }
            Format::Left => todo!(),
            _ => (),
        }
        self.clean();
    }

    fn paint_drop_cap(&mut self) {
        let (raw, _, inline) = inline(&self.renderer, &mut self.builder, &self.properties);
        let Inline {
            properties, width, ..
        } = &inline[0];
        let width = width + self.dim.drop_cap_padding;
        let height = 2.0 * self.layout.get_line_height();
        let page = self.layout.request_height(height);
        let rect = self.layout.from_body(width, height);
        self.layout.get_line(0).mutate(width, -width).lock();
        self.layout.get_line(1).mutate(width, -width).lock();
        self.layout
            .write(page, raw.to_string(), rect, properties.style, 0.0);
        self.properties.drain(..);
        self.builder.reset();
    }

    fn paint_paragraph(&mut self, format: Format, line_format: LineFormat) {
        let (_, text, inline) = inline(&self.renderer, &mut self.builder, &self.properties);

        let mut writer = Writer::new(&text[..], inline.as_slice(), line_format, &mut self.layout);
        writer.write().trim();
        let unformatted = get_unformatted(&text, &inline, writer.get_lines());

        match format {
            Format::Justified => {
                let (tail, head) = unformatted.split_last().unwrap();
                justify(&mut self.layout, head);
                left(&mut self.layout, from_ref(tail));
            }
            Format::Left => {
                left(&mut self.layout, &unformatted);
            }
            _ => (),
        }

        self.clean();
    }

    fn clean(&mut self) {
        self.properties.drain(..);
        self.layout.drain_lines();
        self.builder.reset();
    }

    fn push_style(&mut self, style: Style) -> &mut Self {
        let properties = Properties {
            style,
            action: None,
        };
        self.queue.push(properties.clone());
        self.builder.push_style(&self.renderer.get_style(&style));
        self.properties.push((self.index(), properties));
        self
    }

    fn pop_style(&mut self) -> &mut Self {
        self.queue.pop();
        self.builder.pop();
        self
    }

    fn add_text(&mut self, text: impl AsRef<str>) -> &mut Self {
        let current = self.properties.last().unwrap().clone();
        let style = self.queue.last().unwrap();
        if &current.1 != style {
            self.properties.push((current.0, style.clone()));
        }
        let current = self.properties.last_mut().unwrap();
        current.0 += text.as_ref().chars().count();
        self.builder.add_text(text);
        self
    }

    fn index(&self) -> usize {
        self.properties.last().map_or(0, |(i, _)| *i)
    }

    pub fn index_book(&mut self, book: BookIdentifier) -> &mut Self {
        self.index.book = Some(book);
        self
    }

    pub fn index_chapter(&mut self, chapter: u16) -> &mut Self {
        self.index.chapter = Some(chapter);
        self
    }

    pub fn index_verse(&mut self, verse: u16) -> &mut Self {
        let index = Index::new(
            self.index.book.clone().unwrap(),
            self.index.chapter.unwrap(),
            verse,
        );
        self.set_action(Action::Index(index));
        self
    }

    fn set_action(&mut self, action: Action) {
        self.properties.last_mut().unwrap().1.action = Some(action.clone());
        self.queue.last_mut().unwrap().action = Some(action);
    }

    fn done(&mut self) {}

    pub fn get_pages(&self) -> AlignedVec {
        rkyv::to_bytes::<Error>(self.layout.get_pages()).unwrap()
    }

    pub fn get_indices(&self) -> AlignedVec {
        rkyv::to_bytes::<Error>(self.layout.get_indices()).unwrap()
    }

    pub fn get_verses(&self) -> AlignedVec {
        rkyv::to_bytes::<Error>(self.layout.get_verses()).unwrap()
    }
}

#[derive(Archive, Serialize, Deserialize, Debug, Hash, PartialEq, Eq, Clone, Copy)]
#[repr(i32)]
pub enum Style {
    Verse = 0,
    Normal = 1,
    Header = 2,
    Chapter = 3,
}

#[derive(Debug)]
#[repr(C)]
pub struct Text(*const c_char, usize, Rectangle, TextStyle);

#[derive(Archive, Serialize, Deserialize, Debug, Clone, Copy)]
#[repr(C)]
pub struct Rectangle {
    top: f32,
    left: f32,
    width: f32,
    height: f32,
}

#[derive(Debug, Clone)]
#[repr(C)]
pub struct Dimensions {
    width: f32,
    height: f32,
    header_height: f32,
    drop_cap_padding: f32,
}

pub type Range = ops::Range<usize>;

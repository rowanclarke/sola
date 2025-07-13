mod format;
mod layout;
mod paint;
mod renderer;
mod writer;

use std::{ffi::c_char, ops, slice::from_ref};

use format::{Format, Unformatted, get_unformatted};
use layout::Layout;
pub use layout::{ArchivedPage, Page};
pub use paint::Paint;
use renderer::{Inline, inline};
pub use renderer::{Renderer, TextStyle};
use rkyv::{Archive, Deserialize, Serialize, rancor::Error, util::AlignedVec};
use skia_safe::textlayout::ParagraphBuilder;
use writer::{LineFormat, Writer};

pub struct Painter {
    renderer: Renderer,
    builder: ParagraphBuilder,
    dim: Dimensions,
    styled: Vec<(usize, Style)>,
    styles: Vec<Style>,
    layout: Layout,
}

impl Painter {
    pub fn new(renderer: &Renderer, dim: Dimensions) -> Self {
        Self {
            renderer: renderer.clone(),
            builder: renderer.new_builder(),
            styled: Vec::new(),
            styles: Vec::new(),
            layout: Layout::new(dim.width, dim.height, renderer.line_height(&Style::Normal)),
            dim,
        }
    }

    fn get_dimensions(&self) -> &Dimensions {
        &self.dim
    }

    fn paint_region(&mut self, format: Format, height: f32) {
        let (_, text, inline) = inline(&self.renderer, &mut self.builder, &self.styled);
        // HACK assume line height is the first inline
        let line_height = self.renderer.line_height(&inline[0].style);
        let mut layout = self.layout.sub_layout(self.dim.width, height, line_height);
        let mut writer = Writer::new(
            &text[..],
            inline.as_slice(),
            LineFormat::default(),
            &mut layout,
        );
        writer.write().trim();
        let unformatted = get_unformatted(&text, &inline, writer.get_lines());
        self.layout
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
                    self.layout
                        .write(line.text.iter().collect::<String>(), rect, line.style, 0.0);
                }
            }
            Format::Left => todo!(),
            _ => (),
        }

        self.styled.drain(..);
        self.layout.drain_lines();
        self.builder.reset();
    }

    fn paint_drop_cap(&mut self) {
        let (raw, _, inline) = inline(&self.renderer, &mut self.builder, &self.styled);
        let Inline { style, width, .. } = inline[0];
        let width = width + self.dim.header_padding;
        let rect = self
            .layout
            .from_body(width, 2.0 * self.layout.get_line_height());
        self.layout.get_line(0).mutate(width, -width).lock();
        self.layout.get_line(1).mutate(width, -width).lock();
        self.layout.write(raw.to_string(), rect, style, 0.0);
        self.styled.drain(..);
        self.builder.reset();
    }

    fn paint_paragraph(&mut self, format: Format, line_format: LineFormat) {
        let (_, text, inline) = inline(&self.renderer, &mut self.builder, &self.styled);

        let mut writer = Writer::new(&text[..], inline.as_slice(), line_format, &mut self.layout);
        writer.write().trim();
        let unformatted = get_unformatted(&text, &inline, writer.get_lines());

        fn justify(layout: &mut Layout, unformatted: &[Unformatted]) {
            for words in unformatted {
                let ratio = words.metrics.remaining / words.metrics.whitespace;
                let spaces = words.text.iter().filter(|c| c.is_whitespace()).count() as f32;
                let spacing = ratio * words.whitespace;
                let word_spacing = if spaces == 0.0 { 0.0 } else { spacing / spaces };
                let width = words.width + spacing;
                layout.write_line(
                    words.line,
                    words.text.iter().collect(),
                    words.style,
                    width,
                    word_spacing,
                    words.top_offset,
                );
            }
        }

        fn left(layout: &mut Layout, unformatted: &[Unformatted]) {
            for words in unformatted {
                layout.write_line(
                    words.line,
                    words.text.iter().collect(),
                    words.style,
                    words.width,
                    0.0,
                    words.top_offset,
                );
            }
        }

        match format {
            Format::Justified => {
                let (tail, head) = unformatted.split_last().unwrap();
                justify(&mut self.layout, head);
                left(&mut self.layout, from_ref(tail));
            }
            _ => (),
        }

        self.styled.drain(..);
        self.layout.drain_lines();
        self.builder.reset();
    }

    fn push_style(&mut self, style: Style) -> &mut Self {
        self.styles.push(style);
        self.builder.push_style(&self.renderer.get_style(&style));
        self.styled.push((self.index(), style));
        self
    }

    fn pop_style(&mut self) -> &mut Self {
        self.styles.pop();
        self.builder.pop();
        self
    }

    fn add_text(&mut self, text: impl AsRef<str>) -> &mut Self {
        let current = self.styled.last().unwrap().clone();
        let style = self.styles.last().unwrap();
        if &current.1 != style {
            self.styled.push((current.0, *style));
        }
        let current = self.styled.last_mut().unwrap();
        current.0 += text.as_ref().chars().count();
        self.builder.add_text(text);
        self
    }

    fn index(&self) -> usize {
        self.styled.last().map_or(0, |(i, _)| *i)
    }

    fn done(&mut self) {}

    pub fn get_pages(&self) -> AlignedVec {
        rkyv::to_bytes::<Error>(self.layout.get_pages()).unwrap()
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
    header_padding: f32, // TODO: rename to drop_cap_padding
}

pub type Range = ops::Range<usize>;

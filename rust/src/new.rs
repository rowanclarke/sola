use core::str;
use std::{collections::VecDeque, ops, slice::from_ref};

use rkyv::{rancor::Error, util::AlignedVec};
use skia_safe::textlayout::{ParagraphBuilder, RectHeightStyle, RectWidthStyle};
use usfm::{Book, Character, Element, Paragraph};

use crate::{
    Dimensions, Rectangle, Renderer, Style,
    layout::{Page, PartialText},
    log,
};

pub trait Paint {
    fn paint(&self, painter: &mut Painter);
}

impl Paint for Book {
    fn paint(&self, painter: &mut Painter) {
        use usfm::BookContents as C;
        for contents in self.contents.iter().take(12) {
            match contents {
                C::Paragraph(paragraph) => paragraph.paint(painter),
                C::Element(element) => element.paint(painter),
                C::Chapter(n) => painter
                    .push_style(Style::Chapter)
                    .add_text(n.to_string())
                    .pop_style()
                    .paint_drop_cap(),
                _ => (),
            }
        }
    }
}

impl Paint for Paragraph {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ParagraphContents as C;
        painter.push_style(Style::Normal);
        for contents in &self.contents {
            match contents {
                C::Verse(n) => painter
                    .add_text(" ")
                    .push_style(Style::Verse)
                    .add_text(n.to_string())
                    .pop_style()
                    .done(),
                C::Line(s) => painter.add_text(s).done(),
                C::Character(character) => character.paint(painter),
                _ => (),
            }
        }
        painter.pop_style().paint_paragraph(
            Format::Justified,
            LineFormat {
                head: 20.0,
                tail: 0.0,
                shrink: 0.0,
            },
        );
    }
}

impl Paint for Element {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ElementContents as C;
        use usfm::ElementType::*;
        let header_height = painter.get_dimensions().header_height;
        for contents in &self.contents {
            match (&self.ty, contents) {
                (Header, C::Line(s)) => painter
                    .push_style(Style::Header)
                    .add_text(s)
                    .pop_style()
                    .paint_region(Format::Center, header_height),
                _ => (),
            }
        }
    }
}

impl Paint for Character {
    fn paint(&self, painter: &mut Painter) {
        use usfm::CharacterContents as C;
        for contents in &self.contents {
            match contents {
                C::Line(s) => painter.add_text(s).done(),
                C::Character(character) => character.paint(painter),
            }
        }
    }
}

enum Format {
    Justified,
    Left,
    Center,
}

enum Placement {
    Body,
    Footer,
}

struct Line {
    top: f32,
    left: f32,
    width: f32,
    locked: bool,
}

struct Layout {
    width: f32,
    height: f32,
    line_height: f32,
    body: Region,
    lines: VecDeque<Line>,
    pages: Vec<Page>,
}

#[derive(Clone)]
struct Region {
    top: f32,
    left: f32,
    width: f32,
}

type Range = ops::Range<usize>;

impl Layout {
    fn next_page(&mut self) {
        self.pages.push(Page::new());
        self.body = Region {
            top: 0.0,
            left: 0.0,
            width: self.width,
        }
    }

    fn request_height(&mut self, height: f32) {
        if self.body.top + height > self.height {
            self.next_page();
        }
    }

    fn next_line(&mut self) {
        self.request_height(self.line_height);
        self.lines.push_back(Line {
            top: self.body.top,
            left: self.body.left,
            width: self.body.width,
            locked: false,
        });
        self.body.top += self.line_height;
    }

    fn get_line(&mut self, line: usize) -> &mut Line {
        for _ in self.lines.len()..=line {
            self.next_line();
        }
        &mut self.lines[line]
    }

    fn write_line(
        &mut self,
        line: usize,
        text: String,
        style: Style,
        width: f32,
        word_spacing: f32,
        top_offset: f32,
    ) {
        let line = &mut self.lines[line];
        let rect = Rectangle {
            top: line.top + top_offset,
            left: line.left,
            width,
            height: self.line_height,
        };
        line.left += width;
        self.write(text, rect, style, word_spacing);
    }

    fn write(&mut self, text: String, rect: Rectangle, style: Style, word_spacing: f32) {
        let text = PartialText::new(text, rect, style, word_spacing);
        self.pages.last_mut().unwrap().push(text);
    }

    fn from_body(&mut self, width: f32, height: f32) -> Rectangle {
        Rectangle {
            top: self.body.top,
            left: self.body.left,
            width,
            height,
        }
    }

    fn drain_lines(&mut self) {
        self.lines.drain(..);
    }
}

impl Line {
    fn get_width(&self) -> f32 {
        self.width
    }

    fn mutate(&mut self, left: f32, width: f32) -> &mut Self {
        if !self.locked {
            self.left += left;
            self.width += width;
        }
        self
    }

    fn lock(&mut self) -> &mut Self {
        self.locked = true;
        self
    }
}

#[derive(Debug)]
struct Inline {
    // TODO: index &str instead of &[char]
    range: Range,
    is_whitespace: bool,
    style: Style,
    width: f32,
    top_offset: f32,
}

struct Writer<'a> {
    text: &'a [char],
    inline: &'a [Inline],
    line_format: LineFormat,
    layout: &'a mut Layout, // TODO: next_line: impl FnMut()
    lines: Vec<Words<'a>>,
}

impl<'a> Writer<'a> {
    // TODO: include LineFormat in available
    // TODO: do not worry about spaces before/after - write fn trim() instead
    // TODO: write get_metrics() for getting whitespace
    fn write(&mut self) -> &mut Self {
        let (mut a, mut b) = (0, 0);
        let mut total = 0.0;
        let mut get_available = |left: f32, i: usize| {
            self.layout
                .get_line(i)
                .mutate(left, -left - self.line_format.shrink)
                .get_width()
        };
        let mut available = get_available(self.line_format.head, 0);
        for Inline { width, .. } in self.inline.iter() {
            if total + width > available {
                self.lines
                    .push(Words::new(self.text, self.inline, a..b, available));
            }
            if total + width > available {
                available = get_available(self.line_format.tail, self.lines.len());
                a = b;
                total = 0.0;
            }
            b += 1;
            total += width;
        }
        self.lines
            .push(Words::new(self.text, self.inline, a..b, available));
        self
    }

    fn trim(&mut self) -> &mut Self {
        for Words { range, .. } in self.lines.iter_mut() {
            for (start, offset, incr) in [(&mut range.start, 0, 1), (&mut range.end, -1, -1)] {
                while self.inline[start.wrapping_add_signed(offset)].is_whitespace {
                    *start = start.wrapping_add_signed(incr);
                }
            }
        }
        self
    }

    fn get_lines(self) -> Vec<Words<'a>> {
        self.lines
    }
}

#[derive(Clone, Debug)]
struct LineMetrics {
    remaining: f32,
    whitespace: f32,
}

#[derive(Debug)]
struct Words<'a> {
    text: &'a [char],
    inline: &'a [Inline],
    range: Range,
    available: f32,
}

impl<'a> Words<'a> {
    fn get_metrics(&self) -> LineMetrics {
        let words = &self.inline[self.range.clone()];
        let whitespace: f32 = words
            .iter()
            .filter_map(|Inline { range, width, .. }| {
                self.text[range.clone()]
                    .iter()
                    .find(|chr| chr.is_whitespace())
                    .and(Some(width))
            })
            .sum();
        let total: f32 = words.iter().map(|inline| inline.width).sum();
        LineMetrics {
            remaining: self.available - total,
            whitespace,
        }
    }

    fn new(text: &'a [char], inline: &'a [Inline], range: Range, available: f32) -> Self {
        Self {
            text,
            inline,
            range,
            available,
        }
    }
}

struct LineFormat {
    head: f32,
    tail: f32,
    shrink: f32,
}

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
            layout: Layout {
                width: dim.width,
                height: dim.height,
                line_height: renderer.line_height(&Style::Normal),
                body: Region {
                    top: 0.0,
                    left: 0.0,
                    width: dim.width,
                },
                lines: VecDeque::new(),
                pages: vec![Vec::new()],
            },
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
        let mut layout = Layout {
            width: self.dim.width,
            height,
            line_height,
            body: self.layout.body.clone(),
            lines: VecDeque::new(),
            pages: vec![],
        };
        let mut writer = Writer {
            text: &text[..],
            inline: inline.as_slice(),
            line_format: LineFormat {
                head: 0.0,
                tail: 0.0,
                shrink: 0.0,
            },
            layout: &mut layout,
            lines: vec![],
        };
        writer.write().trim();
        let unformatted = get_unformatted(&text, &inline, writer.get_lines());
        self.layout
            .request_height(height + 2.0 * self.layout.line_height);
        self.layout.body.top += height;

        match format {
            Format::Center => {
                let total_height = unformatted.len() as f32 * line_height;
                let top_offset = (height - total_height) / 2.0;
                for line in unformatted {
                    let region = &layout.lines[line.line];
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
        let rect = self.layout.from_body(width, 2.0 * self.layout.line_height);
        self.layout.get_line(0).mutate(width, -width).lock();
        self.layout.get_line(1).mutate(width, -width).lock();
        self.layout.write(raw.to_string(), rect, style, 0.0);
        self.styled.drain(..);
        self.builder.reset();
    }

    fn paint_paragraph(&mut self, format: Format, line_format: LineFormat) {
        let (_, text, inline) = inline(&self.renderer, &mut self.builder, &self.styled);

        let mut writer = Writer {
            text: &text[..],
            inline: inline.as_slice(),
            line_format,
            layout: &mut self.layout,
            lines: vec![],
        };
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
        rkyv::to_bytes::<Error>(&self.layout.pages).unwrap()
    }
}

#[derive(Debug, Clone)]
struct Unformatted<'a> {
    line: usize,
    text: &'a [char],
    style: Style,
    width: f32,
    top_offset: f32,
    whitespace: f32,
    metrics: LineMetrics,
}

fn get_unformatted<'a, 'b>(
    text: &'a [char],
    inline: &'a [Inline],
    lines: Vec<Words<'b>>,
) -> Vec<Unformatted<'a>> {
    let mut unformatted = vec![];
    let mut line = 0;
    let mut total = 0.0;
    let mut whitespace = 0.0;

    for words in lines.iter() {
        let metrics = words.get_metrics();
        let words = &inline[words.range.clone()];
        let mut last = &words[0];
        let mut index = last.range.start;
        for (i, inline) in words.iter().enumerate() {
            if inline.is_whitespace {
                whitespace += inline.width;
            }
            let is_last = i == words.len() - 1;
            let (end, width) = if is_last {
                (inline.range.end, total + inline.width)
            } else {
                (inline.range.start, total)
            };
            total += inline.width;
            if inline.style != last.style || is_last {
                unformatted.push(Unformatted {
                    line,
                    text: &text[index..end],
                    style: last.style.clone(),
                    width,
                    whitespace,
                    metrics: metrics.clone(),
                    top_offset: last.top_offset,
                });
                whitespace = 0.0;
                total -= width;
                last = &inline;
                index = end;
            }
        }
        line += 1;
    }
    unformatted
}

fn inline<'a>(
    renderer: &'a Renderer,
    builder: &'a mut ParagraphBuilder,
    styled: &'a [(usize, Style)],
) -> (&'a str, Vec<char>, Vec<Inline>) {
    let mut paragraph = builder.build();
    paragraph.layout(f32::INFINITY);
    let raw = builder.get_text();
    let text: Vec<_> = raw.chars().collect();
    let mut inline: Vec<Inline> = vec![];
    let mut start = 0;
    let mut push = |range: Range, style: usize| {
        let rect = paragraph.get_rects_for_range(
            range.clone(),
            RectHeightStyle::Tight,
            RectWidthStyle::Tight,
        )[0]
        .rect;
        let is_whitespace = text[range.clone()]
            .iter()
            .find(|chr| chr.is_whitespace())
            .is_some();
        let style = styled[style].1;
        let top_offset = renderer.top_offset(&style);
        inline.push(Inline {
            range,
            is_whitespace,
            style,
            width: rect.width(),
            top_offset,
        });
    };
    let mut style = 0;
    let mut word = !text[0].is_whitespace();
    for (i, chr) in text.iter().enumerate() {
        if i >= styled[style].0 {
            push(start..i, style);
            start = i;
            style += 1;
            word = !chr.is_whitespace();
            continue;
        }
        if chr.is_whitespace() {
            if word {
                push(start..i, style);
                start = i;
                word = false;
            }
        } else if !word {
            push(start..i, style);
            start = i;
            word = true;
        }
    }
    push(start..text.len(), style);
    (raw, text, inline)
}

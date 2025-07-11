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
        for contents in self.contents.iter().skip(10).take(2) {
            match contents {
                C::Paragraph(paragraph) => paragraph.paint(painter),
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
        painter.push_style(Style::Normal);
        for contents in &self.contents {
            match (&self.ty, contents) {
                (Header, C::Line(s)) => painter
                    .push_style(Style::Header)
                    .add_text(s)
                    .pop_style()
                    .done(),
                _ => (),
            }
        }
        painter.pop_style();
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
}

struct Layout {
    width: f32,
    height: f32,
    line_height: f32,
    body: Region,
    lines: VecDeque<Line>,
    pages: Vec<Page>,
}

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
        });
        self.body.top += self.line_height;
    }

    fn next_line_width(&mut self, line: usize) -> f32 {
        if line >= self.lines.len() {
            self.next_line();
        }
        self.lines[line].width
    }

    fn mutate_line(&mut self, line: usize, left: f32, width: f32) {
        self.lines[line].left += left;
        self.lines[line].width += width;
    }

    fn write_line(
        &mut self,
        line: usize,
        text: String,
        style: Style,
        width: f32,
        word_spacing: f32,
    ) {
        let page = self.pages.last_mut().unwrap();
        let line = &mut self.lines[line];
        let rect = Rectangle {
            top: line.top,
            left: line.left,
            width,
            height: self.line_height,
        };
        let text = PartialText::new(text, rect, style, word_spacing);
        log!("{:?}", text);
        page.push(text);
        line.left += width;
    }

    fn drain_lines(&mut self) {
        self.lines.drain(..);
    }
}

struct Writer<'a> {
    text: &'a [char],
    inline: &'a [(Range, Style, f32)],
    line_format: LineFormat,
    layout: &'a mut Layout, // TODO: next_line: impl FnMut()
}

impl<'a> Writer<'a> {
    // TODO: include LineFormat in available
    // TODO: do not worry about spaces before/after - write fn trim() instead
    // TODO: write get_metrics() for getting whitespace
    fn write(&mut self) -> Vec<Words> {
        let (mut a, mut b) = (0, 0);
        let mut total = 0.0;
        let mut total_ws = 0.0;
        let mut lines: Vec<Words> = vec![];
        let mut available = self.layout.next_line_width(0);
        for (range, _, width) in self.inline.iter() {
            if total + width > available {
                // log!("{}, {} > {}", total, total + width, available);
                lines.push(Words::new(a..b, available, available - total, total_ws));
            }
            if total + width > available {
                available = self.layout.next_line_width(lines.len());
                a = b;
                total = 0.0;
                total_ws = 0.0;
            }
            if self.text[range.clone()].contains(&' ') {
                total_ws += width;
            }
            b += 1;
            total += width;
        }
        lines.push(Words::new(a..b, available, available - total, total_ws));
        lines
    }
}

struct Words {
    range: Range,
    available: f32,
    remaining: f32,
    whitespace: f32,
}

impl Words {
    fn new(range: Range, available: f32, remaining: f32, whitespace: f32) -> Self {
        Self {
            range,
            available,
            remaining,
            whitespace,
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

    fn paint_drop_cap(&mut self) {}

    fn paint_paragraph(&mut self, format: Format, line_format: LineFormat) {
        let (text, inline) = inline(&mut self.builder, &self.styled);
        let chars: Vec<char> = text.chars().collect();

        let mut writer = Writer {
            text: &chars[..],
            inline: inline.as_slice(),
            line_format,
            layout: &mut self.layout,
        };
        let lines = writer.write();

        #[derive(Debug)]
        struct Unformatted<'a> {
            line: usize,
            text: &'a [char],
            style: Style,
            width: f32,
            whitespace: f32,
        }

        let mut unformatted = vec![];
        let mut line = 0;
        let mut total = 0.0;
        let mut whitespace = 0.0;
        let mut index = 0;
        let mut last = &self.styled[0].1;

        for Words { range, .. } in lines.iter() {
            let words = &inline[range.clone()];
            // TODO: use split_last
            for (i, (range, style, width)) in words.iter().enumerate() {
                if chars[range.clone()].contains(&' ') {
                    whitespace += width;
                }
                if style != last {
                    unformatted.push(Unformatted {
                        line,
                        text: &chars[index..range.start],
                        style: last.clone(),
                        width: total,
                        whitespace,
                    });
                    whitespace = 0.0;
                    total = 0.0;
                    last = style;
                    index = range.start;
                }
                total += width;
                if i == words.len() - 1 {
                    unformatted.push(Unformatted {
                        line,
                        text: &chars[index..range.end],
                        style: last.clone(),
                        width: total,
                        whitespace,
                    });
                    whitespace = 0.0;
                    total = 0.0;
                    last = style;
                    index = range.end;
                }
            }
            line += 1;
        }

        fn justify(layout: &mut Layout, lines: &[Words], unformatted: &[Unformatted]) {
            for words in unformatted {
                let Words {
                    remaining,
                    whitespace,
                    ..
                } = lines[words.line];
                let ratio = remaining / whitespace;
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
                );
            }
        }

        match format {
            Format::Justified => {
                let (tail, head) = unformatted.split_last().unwrap();
                justify(&mut self.layout, &lines, head);
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

fn inline<'a>(
    builder: &'a mut ParagraphBuilder,
    styled: &'a [(usize, Style)],
) -> (&'a str, Vec<(Range, Style, f32)>) {
    let mut paragraph = builder.build();
    paragraph.layout(f32::INFINITY);

    let text = builder.get_text();
    let mut inline: Vec<(Range, Style, f32)> = vec![];
    let mut start = 0;
    let mut push = |range: Range, style: usize| {
        let rect = paragraph.get_rects_for_range(
            range.clone(),
            RectHeightStyle::Tight,
            RectWidthStyle::Tight,
        )[0]
        .rect;
        inline.push((range, styled[style].1, rect.width()));
    };
    let mut style = 0;
    let mut word = false;
    for (i, chr) in text.chars().enumerate() {
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
    push(start..text.chars().count(), style);
    (text, inline)
}

use crate::log;

use super::{Range, layout::Layout, renderer::Inline};

pub struct Writer<'a> {
    text: &'a [char],
    inline: &'a [Inline],
    line_format: LineFormat,
    layout: &'a mut Layout, // TODO: next_line: impl FnMut()
    words: Vec<Range>,      // index into inline
    lines: Vec<Words<'a>>,
}

impl<'a> Writer<'a> {
    pub fn new(
        text: &'a [char],
        inline: &'a [Inline],
        line_format: LineFormat,
        layout: &'a mut Layout,
    ) -> Self {
        let (mut a, mut b) = (0, 0);
        let mut words = Vec::new();
        let mut is_whitespace = inline[a].is_whitespace;
        for inline in inline {
            if inline.is_whitespace != is_whitespace {
                words.push(a..b);
                is_whitespace = !is_whitespace;
                a = b;
            }
            b += 1;
        }
        words.push(a..b);
        Self {
            text,
            inline,
            line_format,
            layout,
            words,
            lines: vec![],
        }
    }

    // TODO: include LineFormat in available
    // TODO: do not worry about spaces before/after - write fn trim() instead
    // TODO: write get_metrics() for getting whitespace
    pub fn write(&mut self) -> &mut Self {
        let (mut a, mut b) = (0, 0); // index self.words
        let mut total = 0.0;
        let mut get_available = |left: f32, i: usize| {
            self.layout
                .get_line(i)
                .mutate(left, -left - self.line_format.shrink)
                .get_width()
        };
        let mut available = get_available(self.line_format.head, 0);
        for (n, width) in self.words.iter().map(|r| {
            (
                r.end - r.start,
                r.clone().map(|i| self.inline[i].width).sum::<f32>(),
            )
        }) {
            if total + width > available {
                self.lines
                    .push(Words::new(self.text, self.inline, a..b, available));
                available = get_available(self.line_format.tail, self.lines.len());
                a = b;
                total = 0.0;
            }
            b += n;
            total += width;
        }
        self.lines
            .push(Words::new(self.text, self.inline, a..b, available));
        self
    }

    pub fn trim(&mut self) -> &mut Self {
        for Words { range, .. } in self.lines.iter_mut() {
            for (start, offset, incr) in [(&mut range.start, 0, 1), (&mut range.end, -1, -1)] {
                while self.inline[start.wrapping_add_signed(offset)].is_whitespace {
                    *start = start.wrapping_add_signed(incr);
                }
            }
        }
        self
    }

    pub fn get_lines(self) -> Vec<Words<'a>> {
        self.lines
    }
}

#[derive(Clone, Debug)]
pub struct LineMetrics {
    pub remaining: f32,
    pub whitespace: f32,
}

#[derive(Debug)]
pub struct Words<'a> {
    pub text: &'a [char],
    pub inline: &'a [Inline],
    pub range: Range,
    pub available: f32,
}

impl<'a> Words<'a> {
    pub fn get_metrics(&self) -> LineMetrics {
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

    pub fn new(text: &'a [char], inline: &'a [Inline], range: Range, available: f32) -> Self {
        Self {
            text,
            inline,
            range,
            available,
        }
    }
}

pub struct LineFormat {
    head: f32,
    tail: f32,
    shrink: f32,
}

impl LineFormat {
    pub fn new(head: f32, tail: f32, shrink: f32) -> Self {
        Self { head, tail, shrink }
    }
}

impl Default for LineFormat {
    fn default() -> Self {
        Self::new(0.0, 0.0, 0.0)
    }
}

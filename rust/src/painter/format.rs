use crate::log;

use super::{
    Index, Properties, Style,
    layout::Layout,
    renderer::Inline,
    writer::{LineMetrics, Words},
};

pub enum Format {
    Justified,
    Left,
    Center,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Action {
    Index(Index),
}

#[derive(Debug, Clone)]
pub struct Unformatted<'a> {
    pub line: usize,
    pub text: &'a [char],
    pub properties: Properties,
    pub width: f32,
    pub top_offset: f32,
    pub whitespace: f32,
    pub metrics: LineMetrics,
}

pub fn get_unformatted<'a, 'b>(
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
            if inline.properties != last.properties {
                unformatted.push(Unformatted {
                    line,
                    text: &text[index..inline.range.start],
                    properties: last.properties.clone(),
                    width: total,
                    whitespace,
                    metrics: metrics.clone(),
                    top_offset: last.top_offset,
                });
                whitespace = 0.0;
                total = 0.0;
                last = &inline;
                index = inline.range.start;
            }
            total += inline.width;
            if is_last {
                unformatted.push(Unformatted {
                    line,
                    text: &text[index..inline.range.end],
                    properties: inline.properties.clone(),
                    width: total,
                    whitespace,
                    metrics: metrics.clone(),
                    top_offset: inline.top_offset,
                });
                whitespace = 0.0;
                total = 0.0;
                last = &inline;
                index = inline.range.end;
            }
        }
        line += 1;
    }
    unformatted
}

pub fn justify(layout: &mut Layout, unformatted: &[Unformatted]) {
    for words in unformatted {
        let ratio = words.metrics.remaining / words.metrics.whitespace;
        let spaces = words.text.iter().filter(|c| c.is_whitespace()).count() as f32;
        let spacing = ratio * words.whitespace;
        let word_spacing = if spaces == 0.0 { 0.0 } else { spacing / spaces };
        words.write_line(layout, spacing, word_spacing);
    }
}

pub fn left(layout: &mut Layout, unformatted: &[Unformatted]) {
    for words in unformatted {
        words.write_line(layout, 0.0, 0.0);
    }
}

impl<'a> Unformatted<'a> {
    fn write_line(&self, layout: &mut Layout, spacing: f32, word_spacing: f32) {
        match self.properties.action {
            Some(Action::Index(ref index)) => layout.add_index(index.clone(), self.line),
            None => (),
        }
        layout.write_line(
            self.line,
            self.text.iter().collect(),
            self.properties.style,
            self.width + spacing,
            word_spacing,
            self.top_offset,
        );
    }
}

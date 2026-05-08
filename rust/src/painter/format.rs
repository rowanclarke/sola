use crate::{
    log,
    painter::{
        Range,
        layout::{Area, Section},
    },
};

use super::{
    Index, Properties,
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
pub struct Unformatted {
    pub line: usize,
    pub text: String,
    pub properties: Properties,
    pub width: f32,
    pub top_offset: f32,
    pub whitespace: f32,
    pub metrics: LineMetrics,
}

pub fn get_text<'a>(text: &'a [char], ranges: &Vec<Range>) -> String {
    ranges
        .iter()
        .map(|r| text[r.clone()].iter())
        .flatten()
        .collect()
}

pub fn get_unformatted<'a, 'b>(
    text: &'a [char],
    inline: &'a [Inline],
    lines: Vec<Words<'b>>,
) -> Vec<Unformatted> {
    let mut unformatted = vec![];
    let mut line = 0;
    let mut total = 0.0;
    let mut whitespace = 0.0;

    for words in lines.iter() {
        let metrics = words.get_metrics();
        let words = &inline[words.range.clone()];
        let mut prev_inline = &words[0];
        let mut ranges = vec![];
        for (i, inline) in words.iter().enumerate() {
            if inline.is_whitespace {
                whitespace += inline.width;
            }
            let is_last = i == words.len() - 1;
            if inline.properties != prev_inline.properties {
                unformatted.push(Unformatted {
                    line,
                    text: get_text(text, &ranges),
                    properties: prev_inline.properties.clone(),
                    width: total,
                    whitespace,
                    metrics: metrics.clone(),
                    top_offset: prev_inline.top_offset,
                });
                whitespace = 0.0;
                total = 0.0;
                prev_inline = &inline;
            }
            total += inline.width;
            ranges.push(inline.range.clone());
            if is_last {
                unformatted.push(Unformatted {
                    line,
                    text: get_text(text, &ranges),
                    properties: inline.properties.clone(),
                    width: total,
                    whitespace,
                    metrics: metrics.clone(),
                    top_offset: inline.top_offset,
                });
                whitespace = 0.0;
                total = 0.0;
                prev_inline = &inline;
            }
        }
        line += 1;
    }
    unformatted
}

pub fn justify(layout: &mut Layout, section: Section, unformatted: &[Unformatted]) {
    for words in unformatted {
        let ratio = words.metrics.remaining / words.metrics.whitespace;
        let spaces = words.text.chars().filter(|c| c.is_whitespace()).count() as f32;
        let spacing = ratio * words.whitespace;
        let word_spacing = if spaces == 0.0 { 0.0 } else { spacing / spaces };
        words.write_line(layout, section, spacing, word_spacing);
    }
}

pub fn left(layout: &mut Layout, section: Section, unformatted: &[Unformatted]) {
    for words in unformatted {
        words.write_line(layout, section, 0.0, 0.0);
    }
}

impl Unformatted {
    fn write_line(&self, layout: &mut Layout, section: Section, spacing: f32, word_spacing: f32) {
        // for action in self.properties.actions.iter() {
        //     match action {
        //         Action::Index(index) => {
        //             layout.add_verse_index(index.clone(), self.line);
        //         }
        //     }
        // }
        layout.write_line(
            section,
            self.line,
            self.text.clone(),
            self.properties.style,
            self.width + spacing,
            word_spacing,
            self.top_offset,
        );
    }
}

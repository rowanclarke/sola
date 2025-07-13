use super::{
    Style,
    layout::Layout,
    renderer::Inline,
    writer::{LineMetrics, Words},
};

pub enum Format {
    Justified,
    Left,
    Center,
}

#[derive(Debug, Clone)]
pub struct Unformatted<'a> {
    pub line: usize,
    pub text: &'a [char],
    pub style: Style,
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

pub fn justify(layout: &mut Layout, unformatted: &[Unformatted]) {
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

pub fn left(layout: &mut Layout, unformatted: &[Unformatted]) {
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

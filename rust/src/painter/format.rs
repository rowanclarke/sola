use super::{
    Style,
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

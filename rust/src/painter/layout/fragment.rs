use std::mem;

use rkyv::{Archive, Serialize};

use crate::painter::{Rectangle, Style};

use super::Alignment;
use super::inline::{BrokenLine, InlineItem, ItemKind};

#[derive(Archive, Serialize, Debug, Clone)]
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

pub fn extract_fragments(
    items: &[InlineItem],
    line: &BrokenLine,
    top: f32,
    line_height: f32,
    left_offset: f32,
    line_width: f32,
    is_last_line: bool,
    alignment: &Alignment,
) -> Vec<TextFragment> {
    if line.item_range.is_empty() {
        return vec![];
    }

    let word_spacing = match alignment {
        Alignment::Justified if !is_last_line && line.glue_count > 0 => {
            (line_width - line.content_width) / line.glue_count as f32
        }
        _ => 0.0,
    };

    let start_left = match alignment {
        Alignment::Center => left_offset + (line_width - line.content_width) / 2.0,
        _ => left_offset,
    };

    let mut fragments = Vec::new();
    let mut left = start_left;
    let mut current_text = String::new();
    let mut current_style: Option<Style> = None;
    let mut current_left = left;
    let mut current_width = 0.0f32;
    let mut current_word_spacing = 0.0f32;

    for idx in line.item_range.clone() {
        let item = &items[idx];
        let segment = &item.text;

        let effective_width = if matches!(item.kind, ItemKind::Glue) {
            item.width + word_spacing
        } else {
            item.width
        };

        let item_word_spacing = if matches!(item.kind, ItemKind::Glue) {
            word_spacing
        } else {
            0.0
        };

        if current_style == Some(item.style) {
            current_text.push_str(segment);
            current_width += effective_width;
            if item_word_spacing > current_word_spacing {
                current_word_spacing = item_word_spacing;
            }
            left += effective_width;
        } else {
            if let Some(style) = current_style {
                fragments.push(TextFragment::new(
                    mem::take(&mut current_text),
                    Rectangle {
                        top,
                        left: current_left,
                        width: current_width,
                        height: line_height,
                    },
                    style,
                    current_word_spacing,
                ));
            }
            left += effective_width;
            if matches!(item.kind, ItemKind::Glue) {
                current_text = String::new();
                current_style = Some(item.style);
                current_left = left;
                current_width = 0.0;
                current_word_spacing = item_word_spacing;
            } else {
                current_text = segment.to_string();
                current_style = Some(item.style);
                current_left = left - effective_width;
                current_width = effective_width;
                current_word_spacing = item_word_spacing;
            }
        }
    }

    if let Some(style) = current_style {
        fragments.push(TextFragment::new(
            current_text,
            Rectangle {
                top,
                left: current_left,
                width: current_width,
                height: line_height,
            },
            style,
            current_word_spacing,
        ));
    }

    fragments
}

pub fn usize_to_letters(mut i: usize) -> String {
    let mut s = String::new();

    loop {
        let rem = i % 26;
        s.push((b'a' + rem as u8) as char);

        if i < 26 {
            break;
        }

        i = i / 26 - 1;
    }

    s.chars().rev().collect()
}

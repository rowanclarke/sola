use std::{
    collections::HashMap,
    ffi::c_char,
    slice::from_raw_parts,
    str::from_utf8_unchecked,
};

use rkyv::{api::low::deserialize, rancor::Error};
use skia_safe::{
    Font, FontMetrics, FontMgr, FontStyle, Typeface,
    textlayout::{
        FontCollection, ParagraphBuilder, ParagraphStyle, RectHeightStyle, RectWidthStyle,
        TextStyle as ParagraphTextStyle, TypefaceFontProvider,
    },
};

use super::{Style, Text, layout::ArchivedPage};
use super::layout::{InlineItem, ItemKind, Section};

#[derive(Debug, Clone, Copy)]
#[repr(C)]
pub struct TextStyle {
    pub font_family: *const c_char,
    pub font_family_len: usize,
    pub font_size: f32,
    pub height: f32,
    pub letter_spacing: f32,
    pub word_spacing: f32,
}

impl TextStyle {
    fn font_family(&self) -> &str {
        unsafe {
            from_utf8_unchecked(from_raw_parts(
                self.font_family as *const u8,
                self.font_family_len,
            ))
        }
    }
}

#[derive(Debug, Clone)]
pub struct Renderer {
    font_provider: TypefaceFontProvider,
    style_collection: HashMap<Style, TextStyle>,
}

impl Renderer {
    pub fn new() -> Self {
        Self {
            font_provider: TypefaceFontProvider::new(),
            style_collection: HashMap::new(),
        }
    }

    pub fn register_typeface(&mut self, typeface: Typeface, family: &'_ str) {
        self.font_provider.register_typeface(typeface, family);
    }

    pub fn insert_style(&mut self, style: Style, text_style: TextStyle) {
        self.style_collection.insert(style, text_style);
    }

    pub fn line_height(&self, style: &Style) -> f32 {
        let text_style = &self.style_collection[style];
        text_style.height * text_style.font_size
    }

    #[allow(dead_code)]
    pub fn line_padding(&self, style: &Style) -> f32 {
        let height = self.line_height(style);
        let metrics = self.get_metrics(style);
        height + metrics.ascent - metrics.descent
    }

    #[allow(dead_code)]
    pub fn top_offset(&self, style: &Style) -> f32 {
        match style {
            Style::Verse => self.line_padding(&Style::Normal) / 2.0,
            _ => 0.0,
        }
    }

    pub fn new_builder(&self) -> ParagraphBuilder {
        let mut font_collection = FontCollection::new();
        let font_mgr: FontMgr = self.font_provider.clone().into();
        font_collection.set_default_font_manager(Some(font_mgr), None);
        let paragraph_style = ParagraphStyle::new();
        ParagraphBuilder::new(&paragraph_style, font_collection)
    }

    pub fn get_style(&self, style: &Style) -> ParagraphTextStyle {
        let text_style = &self.style_collection[style];
        let mut paragraph_text_style = ParagraphTextStyle::new();
        paragraph_text_style
            .set_font_size(text_style.font_size)
            .set_font_families(&[text_style.font_family()])
            .set_height(text_style.height)
            .set_letter_spacing(text_style.letter_spacing)
            .set_word_spacing(text_style.word_spacing);
        paragraph_text_style
    }

    #[allow(dead_code)]
    pub fn get_metrics(&self, style: &Style) -> FontMetrics {
        let text_style = &self.style_collection[style];
        let font_mgr: FontMgr = self.font_provider.clone().into();
        let typeface = font_mgr
            .match_family_style(text_style.font_family(), FontStyle::normal())
            .unwrap();
        let font = Font::from_typeface(typeface, text_style.font_size);
        font.metrics().1
    }

    pub fn page(&self, page: &ArchivedPage) -> Vec<Text> {
        page.iter()
            .map(|fragment| {
                let mut style =
                    self.style_collection[&deserialize::<_, Error>(&fragment.style).unwrap()];
                style.word_spacing += fragment.word_spacing.to_native();
                let text = fragment.text.as_bytes();
                let len = text.len();
                let ptr = text.as_ptr() as *const c_char;
                Text(
                    ptr,
                    len,
                    deserialize::<_, Error>(&fragment.rect).unwrap(),
                    style,
                )
            })
            .collect()
    }
}

/// Shape a list of (text, style) segments into InlineItems with Skia-measured widths.
///
/// All segments are laid out as a single Skia paragraph at infinite width for measurement,
/// then split on word/whitespace boundaries and style boundaries.
/// Each InlineItem carries its text directly as a String.
pub fn shape_segments(
    renderer: &Renderer,
    segments: &[(String, Style)],
    section: Section,
) -> Vec<InlineItem> {
    // Concatenate all segment text for shaping
    let full_text: String = segments.iter().map(|(t, _)| t.as_str()).collect();
    if full_text.is_empty() {
        return vec![];
    }

    let mut builder = renderer.new_builder();

    // Build Skia paragraph from all segments
    for (text, style) in segments {
        builder.push_style(&renderer.get_style(style));
        builder.add_text(text);
        builder.pop();
    }

    let mut paragraph = builder.build();
    paragraph.layout(f32::INFINITY);

    // Build style map: for each byte offset, which style applies
    let mut style_runs: Vec<(usize, usize, Style)> = Vec::new();
    let mut offset = 0;
    for (text, style) in segments {
        let len = text.len();
        if len > 0 {
            style_runs.push((offset, offset + len, *style));
        }
        offset += len;
    }

    let style_at = |pos: usize| -> Style {
        for &(start, end, style) in &style_runs {
            if pos >= start && pos < end {
                return style;
            }
        }
        Style::Normal
    };

    // Build style boundaries
    let mut style_boundaries: Vec<usize> = Vec::new();
    for &(start, end, _) in &style_runs {
        style_boundaries.push(start);
        style_boundaries.push(end);
    }
    style_boundaries.sort();
    style_boundaries.dedup();

    // Split text into segments at word/whitespace and style boundaries
    let text = &full_text;
    let mut seg_ranges: Vec<(usize, usize)> = Vec::new();
    let mut seg_start = 0;

    for (i, ch) in text.char_indices() {
        let byte_len = ch.len_utf8();
        let next = i + byte_len;

        let is_style_boundary = style_boundaries.contains(&next) && next < text.len();

        let current_ws = ch.is_whitespace();
        let next_ws = if next < text.len() {
            text[next..].chars().next().map_or(false, |c| c.is_whitespace())
        } else {
            current_ws
        };
        let is_word_boundary = next < text.len() && current_ws != next_ws;

        if is_style_boundary || is_word_boundary {
            if seg_start < next {
                seg_ranges.push((seg_start, next));
            }
            seg_start = next;
        }
    }
    if seg_start < text.len() {
        seg_ranges.push((seg_start, text.len()));
    }

    // Build UTF-16 offset mapping for Skia
    let utf16_offsets: Vec<usize> = {
        let mut offsets = vec![0usize; text.len() + 1];
        let mut utf16_pos = 0;
        for (byte_pos, ch) in text.char_indices() {
            offsets[byte_pos] = utf16_pos;
            utf16_pos += ch.len_utf16();
        }
        offsets[text.len()] = utf16_pos;
        offsets
    };

    // Measure each segment and produce InlineItems
    let mut items: Vec<InlineItem> = Vec::new();
    for (start, end) in seg_ranges {
        let segment_text = &text[start..end];
        let style = style_at(start);
        let is_whitespace = segment_text.chars().all(|c| c.is_whitespace());

        let rects = paragraph.get_rects_for_range(
            utf16_offsets[start]..utf16_offsets[end],
            RectHeightStyle::Tight,
            RectWidthStyle::Tight,
        );
        let width = if rects.is_empty() {
            0.0
        } else {
            rects.iter().map(|r| r.rect.width()).sum()
        };

        let kind = if is_whitespace {
            ItemKind::Glue
        } else {
            ItemKind::Word
        };

        items.push(InlineItem {
            text: segment_text.to_string(),
            style,
            width,
            kind,
            section,
            index_id: None,
        });
    }

    items
}

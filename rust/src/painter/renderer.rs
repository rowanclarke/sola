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

use super::{InlineItem, ItemKind, ParagraphSpec, Style, Text, layout::ArchivedPage};

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

/// Shape a ParagraphSpec into a sequence of InlineItems with Skia-measured widths.
///
/// 1. Build a Skia paragraph from spec.text + spec.styles
/// 2. Layout at f32::INFINITY for measurement
/// 3. Walk text, split on word/whitespace boundaries and style boundaries
/// 4. For each segment: get_rects_for_range() to measure width
/// 5. Produce InlineItem with appropriate ItemKind
/// 6. Copy index markers from spec onto corresponding items
pub fn shape(renderer: &Renderer, spec: &ParagraphSpec) -> Vec<InlineItem> {
    if spec.text.is_empty() {
        return vec![];
    }

    let mut builder = renderer.new_builder();

    // Build Skia paragraph with styled ranges
    // We need to push styles in order of the styled ranges
    let mut last_end = 0;
    for (range, style) in &spec.styles {
        // If there's a gap, push default style for it
        if range.start > last_end {
            builder.push_style(&renderer.get_style(&Style::Normal));
            builder.add_text(&spec.text[last_end..range.start]);
            builder.pop();
        }
        builder.push_style(&renderer.get_style(style));
        builder.add_text(&spec.text[range.clone()]);
        builder.pop();
        last_end = range.end;
    }
    // Handle trailing text
    if last_end < spec.text.len() {
        builder.push_style(&renderer.get_style(&Style::Normal));
        builder.add_text(&spec.text[last_end..]);
        builder.pop();
    }

    let mut paragraph = builder.build();
    paragraph.layout(f32::INFINITY);

    // Walk text, splitting on word/whitespace boundaries and style boundaries
    let text = &spec.text;
    let mut items: Vec<InlineItem> = Vec::new();

    // Build a sorted list of style boundary byte offsets
    let mut style_boundaries: Vec<usize> = Vec::new();
    for (range, _) in &spec.styles {
        style_boundaries.push(range.start);
        style_boundaries.push(range.end);
    }
    style_boundaries.sort();
    style_boundaries.dedup();

    // Find which style applies at a given byte offset
    let style_at = |offset: usize| -> Style {
        for (range, style) in spec.styles.iter().rev() {
            if offset >= range.start && offset < range.end {
                return *style;
            }
        }
        Style::Normal
    };

    // Build a set of caller offsets (byte offsets where a caller placeholder sits)
    let mut caller_offsets: HashMap<usize, usize> = HashMap::new();
    // We detect callers by finding '+' characters with Style::Caller
    {
        let mut fn_counter = 0;
        for (range, style) in &spec.styles {
            if *style == Style::Caller {
                caller_offsets.insert(range.start, fn_counter);
                fn_counter += 1;
            }
        }
    }

    // Split text into segments at word/whitespace and style boundaries
    let mut segments: Vec<(usize, usize)> = Vec::new(); // (start, end) byte ranges
    let mut seg_start = 0;

    for (i, ch) in text.char_indices() {
        let byte_len = ch.len_utf8();
        let next = i + byte_len;

        // Check if this is a style boundary
        let is_style_boundary = style_boundaries.contains(&next) && next < text.len();

        // Check if word/whitespace boundary
        let current_ws = ch.is_whitespace();
        let next_ws = if next < text.len() {
            text[next..].chars().next().map_or(false, |c| c.is_whitespace())
        } else {
            current_ws
        };
        let is_word_boundary = next < text.len() && current_ws != next_ws;

        if is_style_boundary || is_word_boundary {
            if seg_start < next {
                segments.push((seg_start, next));
            }
            seg_start = next;
        }
    }
    // Final segment
    if seg_start < text.len() {
        segments.push((seg_start, text.len()));
    }

    // Build UTF-8 byte offset -> UTF-16 code unit offset mapping.
    // Skia's get_rects_for_range uses UTF-16 code unit positions internally,
    // so we must convert our byte offsets.
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
    for (start, end) in segments {
        let segment_text = &text[start..end];
        let style = style_at(start);
        let is_whitespace = segment_text.chars().all(|c| c.is_whitespace());

        // Measure width with Skia (using UTF-16 offsets)
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

        // Determine kind
        let kind = if let Some(&fn_id) = caller_offsets.get(&start) {
            ItemKind::Caller { footnote_id: fn_id }
        } else if is_whitespace {
            ItemKind::Glue
        } else {
            ItemKind::Word
        };

        // Check for index markers at this position
        let index_id = spec
            .index_markers
            .iter()
            .find(|(offset, _)| *offset >= start && *offset < end)
            .map(|(_, id)| *id);

        items.push(InlineItem {
            range: start..end,
            style,
            width,
            kind,
            index_id,
        });
    }

    items
}

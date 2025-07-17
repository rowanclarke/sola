use std::{
    collections::HashMap,
    ffi::c_char,
    ops::{self, Index},
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

use crate::log;

use super::{
    Range, Style, Text,
    layout::{ArchivedPage, ArchivedPartialText},
};

#[derive(Debug, Clone, Copy)]
#[repr(C)]
pub struct TextStyle {
    font_family: *const c_char,
    font_family_len: usize,
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

    pub fn line_padding(&self, style: &Style) -> f32 {
        let height = self.line_height(style);
        let metrics = self.get_metrics(style);
        height + metrics.ascent - metrics.descent
    }

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
            .map(|ArchivedPartialText(text, rect, style, word_spacing)| {
                let mut style = self.style_collection[&deserialize::<_, Error>(style).unwrap()];
                style.word_spacing += word_spacing.to_native();
                let text = text.as_bytes();
                let len = text.len();
                let ptr = text.as_ptr() as *const c_char;
                Text(ptr, len, deserialize::<_, Error>(rect).unwrap(), style)
            })
            .collect()
    }
}

#[derive(Debug)]
pub struct Inline {
    // TODO: index &str instead of &[char]
    pub range: Range,
    pub is_whitespace: bool,
    pub style: Style,
    pub width: f32,
    pub top_offset: f32,
}

pub fn inline<'a>(
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

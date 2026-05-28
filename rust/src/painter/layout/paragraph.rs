use std::ops;

use crate::painter::Style;

#[derive(Debug, Clone)]
pub enum Alignment {
    Justified,
    Left,
    Center,
}

#[derive(Debug, Clone)]
pub struct DropCap {
    pub line_span: usize,
    pub padding: f32,
}

#[derive(Debug, Clone)]
pub struct ParagraphSpec {
    pub text: String,
    pub styles: Vec<(ops::Range<usize>, Style)>,
    pub alignment: Alignment,
    pub indent: (f32, f32), // (first_line, continuation)
    pub drop_cap: Option<DropCap>,
    pub spacing_before: f32,
    pub spacing_after: f32,
    pub index_markers: Vec<(usize, usize)>, // (byte_offset, index_registry_id)
}

#[derive(Debug, Clone)]
pub struct FootnoteSpec {
    pub caller_body_offset: usize,
    pub content: ParagraphSpec,
}

#[derive(Debug, Clone)]
pub struct CollectedParagraph {
    pub body: ParagraphSpec,
    pub footnotes: Vec<FootnoteSpec>,
}

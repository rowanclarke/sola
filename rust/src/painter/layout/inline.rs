use std::ops;

use crate::painter::Style;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ItemKind {
    Word,
    Glue,
    Caller { footnote_id: usize },
}

#[derive(Debug, Clone)]
pub struct InlineItem {
    pub range: ops::Range<usize>, // byte range into source text
    pub style: Style,
    pub width: f32,
    pub kind: ItemKind,
    pub index_id: Option<usize>,
}

#[derive(Debug, Clone)]
pub struct BrokenLine {
    pub item_range: ops::Range<usize>,
    pub content_width: f32,
    pub glue_count: u32,
}

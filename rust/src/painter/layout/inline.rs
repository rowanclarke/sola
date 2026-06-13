use std::ops;

use crate::painter::Style;

use super::Section;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ItemKind {
    Word,
    Glue,
}

#[derive(Debug, Clone)]
pub struct InlineItem {
    pub text: String,
    pub style: Style,
    pub width: f32,
    pub kind: ItemKind,
    pub section: Section,
    pub index_id: Option<usize>,
}

#[derive(Debug, Clone)]
pub struct BrokenLine {
    pub item_range: ops::Range<usize>,
    pub content_width: f32,
    pub glue_count: u32,
}

#[derive(Debug)]
pub enum StreamItem {
    Inline(InlineItem),
    BeginGrouped,
    EndGrouped,
    BeginExpanded,
    EndExpanded,
}

impl StreamItem {
    pub fn as_inline(&self) -> Option<&InlineItem> {
        match self {
            StreamItem::Inline(item) => Some(item),
            _ => None,
        }
    }

    pub fn is_marker(&self) -> bool {
        !matches!(self, StreamItem::Inline(_))
    }
}

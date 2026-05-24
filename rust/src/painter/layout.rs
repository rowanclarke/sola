use std::collections::HashMap;

use rkyv::{Archive, Deserialize, Serialize, vec::ArchivedVec};
use usfm::BookIdentifier;

use super::{Rectangle, Style};

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum Section {
    Body,
    Footer,
}

#[derive(Debug, PartialEq, Eq, Clone, Hash, Serialize, Archive, Deserialize)]
#[rkyv(derive(Debug, PartialEq, Eq, Hash))]
pub struct Index {
    pub book: BookIdentifier,
    pub header: String,
    pub chapter: Option<u16>,
    pub verse: Option<u16>,
}

impl Index {
    pub fn new(
        book: BookIdentifier,
        header: String,
        chapter: Option<u16>,
        verse: Option<u16>,
    ) -> Self {
        Self {
            book,
            header,
            chapter,
            verse,
        }
    }
}

pub type ArchivedPages = ArchivedVec<ArchivedPage>;
pub type ArchivedPage = <Page as Archive>::Archived;
pub type Page = Vec<TextFragment>;
pub type ArchivedIndices = <Indices as Archive>::Archived;
pub type Indices = HashMap<Index, usize>;

#[derive(Archive, Serialize, Debug)]
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

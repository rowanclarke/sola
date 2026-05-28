#[allow(dead_code)]
pub mod artefact;
#[allow(dead_code)]
pub mod column;
#[allow(dead_code)]
pub mod container;
pub mod fragment;
pub mod inline;
pub mod line_breaker;
pub mod paragraph;
pub mod pipeline;
#[allow(dead_code)]
pub mod scaffold;
#[allow(dead_code)]
pub mod template;

use std::collections::HashMap;

use rkyv::{Archive, Deserialize, Serialize, vec::ArchivedVec};
use usfm::BookIdentifier;

// Re-exports
pub use fragment::{Section, TextFragment};
pub use inline::{InlineItem, ItemKind};
pub use paragraph::{Alignment, CollectedParagraph, DropCap, FootnoteSpec, ParagraphSpec};

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

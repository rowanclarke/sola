pub mod layout;
mod paint;
mod renderer;

use std::{ffi::c_char, mem, ops};

pub use layout::{
    Alignment, ArchivedIndex, ArchivedIndices, ArchivedPages,
    CollectedParagraph, DropCap, FootnoteSpec, Index, Indices, ParagraphSpec,
};
pub use paint::Paint;
pub use renderer::{Renderer, TextStyle};
use rkyv::{Archive, Deserialize, Serialize, rancor::Error};
use usfm::{ArchivedBookIdentifier, BookIdentifier};

use layout::{
    Page, Section,
    pipeline::layout_book,
};

// ---------------------------------------------------------------------------
// Style stack entry
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
#[allow(dead_code)]
struct StackEntry {
    style: Style,
    section: Section,
}

// ---------------------------------------------------------------------------
// Location tracking
// ---------------------------------------------------------------------------

#[derive(Default)]
struct LocationState {
    book: Option<BookIdentifier>,
    header: Option<String>,
    chapter: Option<u16>,
}

// ---------------------------------------------------------------------------
// Painter (span collection phase)
// ---------------------------------------------------------------------------

pub struct Painter {
    renderer: Renderer,
    dim: Dimensions,
    // Style stack
    style_stack: Vec<StackEntry>,
    // Current paragraph accumulation
    current_text: String,
    current_styles: Vec<(ops::Range<usize>, Style)>,
    current_index_markers: Vec<(usize, usize)>,
    // Footnote collection
    collecting_footnote: bool,
    footnote_id_in_progress: usize,
    current_footnotes: Vec<FootnoteSpec>,
    footnote_text: String,
    footnote_styles: Vec<(ops::Range<usize>, Style)>,
    // Pending state
    pending_drop_cap: Option<DropCap>,
    pending_drop_cap_text: Option<String>,
    pending_drop_cap_style: Option<Style>,
    // Index registry
    index_registry: Vec<Index>,
    // Location tracking
    location: LocationState,
    // Output
    collected: Vec<CollectedParagraph>,
}

impl Painter {
    pub fn new(renderer: &Renderer, dim: Dimensions) -> Self {
        Self {
            renderer: renderer.clone(),
            dim,
            style_stack: Vec::new(),
            current_text: String::new(),
            current_styles: Vec::new(),
            current_index_markers: Vec::new(),
            collecting_footnote: false,
            footnote_id_in_progress: 0,
            current_footnotes: Vec::new(),
            footnote_text: String::new(),
            footnote_styles: Vec::new(),
            pending_drop_cap: None,
            pending_drop_cap_text: None,
            pending_drop_cap_style: None,
            index_registry: Vec::new(),
            location: LocationState::default(),
            collected: Vec::new(),
        }
    }

    pub fn get_dimensions(&self) -> &Dimensions {
        &self.dim
    }

    fn current_style(&self) -> Style {
        self.style_stack
            .last()
            .map(|e| e.style)
            .unwrap_or(Style::Normal)
    }

    pub fn push_properties(&mut self, style: Style, section: Section) -> &mut Self {
        self.style_stack.push(StackEntry { style, section });
        self
    }

    pub fn pop_properties(&mut self) -> &mut Self {
        self.style_stack.pop();
        self
    }

    pub fn add_text(&mut self, text: impl AsRef<str>) -> &mut Self {
        let text = text.as_ref();
        let style = self.current_style();

        if self.collecting_footnote {
            let start = self.footnote_text.len();
            self.footnote_text.push_str(text);
            let end = self.footnote_text.len();
            if start < end {
                self.footnote_styles.push((start..end, style));
            }
        } else {
            let start = self.current_text.len();
            self.current_text.push_str(text);
            let end = self.current_text.len();
            if start < end {
                self.current_styles.push((start..end, style));
            }
        }
        self
    }

    pub fn insert_caller(&mut self, _footnote_id: usize) {
        // Insert a placeholder "+" character in the body text
        // It will be replaced with the actual caller letter during page breaking
        let style = Style::Caller;
        let start = self.current_text.len();
        self.current_text.push('+');
        let end = self.current_text.len();
        self.current_styles.push((start..end, style));
    }

    fn next_footnote_id(&mut self) -> usize {
        let id = self.current_footnotes.len();
        id
    }

    pub fn begin_footnote(&mut self, footnote_id: usize) {
        self.collecting_footnote = true;
        self.footnote_id_in_progress = footnote_id;
        self.footnote_text.clear();
        self.footnote_styles.clear();
    }

    pub fn end_footnote(&mut self) {
        self.collecting_footnote = false;
        // The caller_body_offset is the byte position of the "+" we inserted
        // Find it by looking at the last Caller-styled range in current_styles
        let caller_offset = self
            .current_styles
            .iter()
            .rev()
            .find(|(_, s)| *s == Style::Caller)
            .map(|(r, _)| r.start)
            .unwrap_or(0);

        let content = ParagraphSpec {
            text: mem::take(&mut self.footnote_text),
            styles: mem::take(&mut self.footnote_styles),
            alignment: Alignment::Left,
            indent: (0.0, 0.0),
            drop_cap: None,
            spacing_before: 0.0,
            spacing_after: 0.0,
            index_markers: Vec::new(),
        };

        self.current_footnotes.push(FootnoteSpec {
            caller_body_offset: caller_offset,
            content,
        });
    }

    pub fn set_pending_drop_cap(&mut self, drop_cap: DropCap) {
        self.pending_drop_cap = Some(drop_cap);
    }

    pub fn set_pending_drop_cap_text(&mut self, text: String, style: Style) {
        self.pending_drop_cap_text = Some(text);
        self.pending_drop_cap_style = Some(style);
    }

    pub fn paint_paragraph(&mut self) {
        self.finalize_paragraph(Alignment::Justified, (20.0, 0.0), 0.0, 0.0);
    }

    pub fn paint_paragraph_with_indent(&mut self, first: f32, cont: f32) {
        self.finalize_paragraph(Alignment::Left, (first, cont), 0.0, 0.0);
    }

    pub fn paint_heading(&mut self) {
        self.finalize_paragraph(
            Alignment::Center,
            (0.0, 0.0),
            self.dim.header_height / 2.0,
            self.dim.header_height / 2.0,
        );
    }

    fn finalize_paragraph(
        &mut self,
        alignment: Alignment,
        indent: (f32, f32),
        spacing_before: f32,
        spacing_after: f32,
    ) {
        // Prepend drop cap text if pending
        if let Some(dc_text) = self.pending_drop_cap_text.take() {
            let dc_style = self.pending_drop_cap_style.take().unwrap_or(Style::Chapter);
            let dc_len = dc_text.len();

            // Shift all existing style ranges and index markers
            for (range, _) in &mut self.current_styles {
                range.start += dc_len;
                range.end += dc_len;
            }
            for (offset, _) in &mut self.current_index_markers {
                *offset += dc_len;
            }
            for footnote in &mut self.current_footnotes {
                footnote.caller_body_offset += dc_len;
            }

            // Prepend
            self.current_text.insert_str(0, &dc_text);
            self.current_styles.insert(0, (0..dc_len, dc_style));
        }

        let body = ParagraphSpec {
            text: mem::take(&mut self.current_text),
            styles: mem::take(&mut self.current_styles),
            alignment,
            indent,
            drop_cap: self.pending_drop_cap.take(),
            spacing_before,
            spacing_after,
            index_markers: mem::take(&mut self.current_index_markers),
        };

        let footnotes = mem::take(&mut self.current_footnotes);

        self.collected.push(CollectedParagraph { body, footnotes });
    }

    pub fn clean(&mut self) {
        self.current_text.clear();
        self.current_styles.clear();
        self.current_index_markers.clear();
        self.current_footnotes.clear();
        self.pending_drop_cap = None;
        self.pending_drop_cap_text = None;
        self.pending_drop_cap_style = None;
    }

    // Index methods

    pub fn index_book(&mut self, book: &ArchivedBookIdentifier) -> &mut Self {
        let book: BookIdentifier = rkyv::deserialize::<_, Error>(book).unwrap();
        self.location.book = Some(book);
        self
    }

    pub fn index_header(&mut self, header: &rkyv::string::ArchivedString) -> &mut Self {
        let header: String = rkyv::deserialize::<_, Error>(header).unwrap();
        self.location.header = Some(header.clone());
        let index = Index::new(
            self.location.book.clone().unwrap(),
            header,
            None,
            None,
        );
        let id = self.index_registry.len();
        self.index_registry.push(index);
        let offset = if self.collecting_footnote {
            self.footnote_text.len()
        } else {
            self.current_text.len()
        };
        self.current_index_markers.push((offset, id));
        self
    }

    pub fn index_chapter(&mut self, chapter: u16) -> &mut Self {
        self.location.chapter = Some(chapter);
        let index = Index::new(
            self.location.book.clone().unwrap(),
            self.location.header.clone().unwrap(),
            self.location.chapter,
            None,
        );
        let id = self.index_registry.len();
        self.index_registry.push(index);
        let offset = if self.collecting_footnote {
            self.footnote_text.len()
        } else {
            self.current_text.len()
        };
        self.current_index_markers.push((offset, id));
        self
    }

    pub fn index_verse(&mut self, verse: u16) -> &mut Self {
        let index = Index::new(
            self.location.book.clone().unwrap(),
            self.location.header.clone().unwrap(),
            self.location.chapter,
            Some(verse),
        );
        let id = self.index_registry.len();
        self.index_registry.push(index);
        let offset = if self.collecting_footnote {
            self.footnote_text.len()
        } else {
            self.current_text.len()
        };
        self.current_index_markers.push((offset, id));
        self
    }

    // Layout: run the full pipeline after all Paint visitors complete

    pub fn layout(&mut self) -> (Vec<Page>, Indices) {
        let output = layout_book(&self.renderer, &self.dim, &self.collected, &self.index_registry);
        (output.pages, output.indices)
    }

}

// ---------------------------------------------------------------------------
// Style enum
// ---------------------------------------------------------------------------

#[derive(Archive, Serialize, Deserialize, Debug, Hash, PartialEq, Eq, Clone, Copy)]
#[repr(i32)]
pub enum Style {
    Verse = 0,
    Normal = 1,
    Header = 2,
    Chapter = 3,

    Caller = 9,
    Footnote = 10,
    CrossRef = 11,
}

#[derive(Debug)]
#[repr(C)]
pub struct Text(*const c_char, usize, Rectangle, TextStyle);

#[derive(Archive, Serialize, Deserialize, Debug, Clone, Copy)]
#[repr(C)]
pub struct Rectangle {
    pub top: f32,
    pub left: f32,
    pub width: f32,
    pub height: f32,
}

#[derive(Debug, Clone)]
#[repr(C)]
pub struct Dimensions {
    pub width: f32,
    pub height: f32,
    pub header_height: f32,
    pub drop_cap_padding: f32,
}


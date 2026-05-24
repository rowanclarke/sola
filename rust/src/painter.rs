pub mod layout;
mod paint;
mod renderer;

use std::{collections::HashMap, ffi::c_char, mem, ops};

pub use layout::{ArchivedIndex, ArchivedIndices, ArchivedPages, Index, Indices};
pub use paint::Paint;
use renderer::shape;
pub use renderer::{Renderer, TextStyle};
use rkyv::{Archive, Deserialize, Serialize, rancor::Error};
use usfm::{ArchivedBookIdentifier, BookIdentifier};

use layout::{Page, Section, TextFragment};

// ---------------------------------------------------------------------------
// Core data types
// ---------------------------------------------------------------------------

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
        let mut breaker = PageBreaker::new(&self.renderer, &self.dim, &self.index_registry);

        for collected in &self.collected {
            breaker.process_paragraph(collected);
        }

        breaker.finalize()
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

// ---------------------------------------------------------------------------
// LineBreaker iterator
// ---------------------------------------------------------------------------

struct LineBreaker<'a> {
    items: &'a [InlineItem],
    cursor: usize,
    line_index: usize,
    width_fn: Box<dyn Fn(usize) -> (f32, f32) + 'a>, // line_index -> (left_offset, max_width)
}

impl<'a> LineBreaker<'a> {
    fn new(
        items: &'a [InlineItem],
        width_fn: Box<dyn Fn(usize) -> (f32, f32) + 'a>,
    ) -> Self {
        Self {
            items,
            cursor: 0,
            line_index: 0,
            width_fn,
        }
    }
}

impl<'a> Iterator for LineBreaker<'a> {
    type Item = BrokenLine;

    fn next(&mut self) -> Option<BrokenLine> {
        if self.cursor >= self.items.len() {
            return None;
        }

        let (_left_offset, max_width) = (self.width_fn)(self.line_index);

        // Skip leading glue on all lines
        while self.cursor < self.items.len()
            && matches!(self.items[self.cursor].kind, ItemKind::Glue)
        {
            self.cursor += 1;
        }

        if self.cursor >= self.items.len() {
            return None;
        }

        let start = self.cursor;
        let mut width = 0.0f32;
        let mut last_break: Option<(usize, f32, u32)> = None;
        let mut glue_count = 0u32;

        while self.cursor < self.items.len() {
            let item = &self.items[self.cursor];
            match item.kind {
                ItemKind::Glue => {
                    last_break = Some((self.cursor, width, glue_count));
                    glue_count += 1;
                    width += item.width;
                    self.cursor += 1;
                }
                ItemKind::Word | ItemKind::Caller { .. } => {
                    if width + item.width > max_width && self.cursor > start {
                        if let Some((brk, w, gc)) = last_break {
                            self.cursor = brk + 1;
                            self.line_index += 1;
                            return Some(BrokenLine {
                                item_range: start..brk,
                                content_width: w,
                                glue_count: gc,
                            });
                        }
                        // No break opportunity: forced break after this word
                        self.cursor += 1;
                        self.line_index += 1;
                        return Some(BrokenLine {
                            item_range: start..self.cursor,
                            content_width: width + item.width,
                            glue_count,
                        });
                    }
                    width += item.width;
                    self.cursor += 1;
                }
            }
        }

        // Last line: trim trailing glue from content_width
        let mut end = self.cursor;
        let mut trimmed_width = width;
        let mut trimmed_glue = glue_count;
        while end > start && matches!(self.items[end - 1].kind, ItemKind::Glue) {
            end -= 1;
            trimmed_width -= self.items[end].width;
            trimmed_glue -= 1;
        }

        self.line_index += 1;
        Some(BrokenLine {
            item_range: start..end,
            content_width: trimmed_width,
            glue_count: trimmed_glue,
        })
    }
}

// ---------------------------------------------------------------------------
// PageBreaker
// ---------------------------------------------------------------------------

struct PageBreaker<'a> {
    renderer: &'a Renderer,
    dim: &'a Dimensions,
    // Current page accumulation
    header_fragments: Vec<TextFragment>,
    body_fragments: Vec<TextFragment>,
    footer_fragments: Vec<TextFragment>,
    body_height: f32,
    footer_height: f32,
    caller_counter: usize,
    page_index: usize,
    // Output
    pages: Vec<Page>,
    indices: Indices,
    index_registry: &'a [Index],
}

impl<'a> PageBreaker<'a> {
    fn new(renderer: &'a Renderer, dim: &'a Dimensions, index_registry: &'a [Index]) -> Self {
        Self {
            renderer,
            dim,
            header_fragments: Vec::new(),
            body_fragments: Vec::new(),
            footer_fragments: Vec::new(),
            body_height: 0.0,
            footer_height: 0.0,
            caller_counter: 0,
            page_index: 0,
            pages: Vec::new(),
            indices: HashMap::new(),
            index_registry,
        }
    }

    fn available_body_height(&self) -> f32 {
        self.dim.height - self.footer_height - self.body_height
    }

    fn emit_page(&mut self) {
        let mut page_fragments = Vec::new();
        page_fragments.append(&mut self.header_fragments);
        page_fragments.append(&mut self.body_fragments);
        page_fragments.append(&mut self.footer_fragments);
        self.pages.push(page_fragments);

        self.page_index += 1;
        self.body_height = 0.0;
        self.footer_height = 0.0;
        self.caller_counter = 0;
    }

    /// Shape a footnote's ParagraphSpec with the actual caller letter substituted
    /// for the "+" placeholder, so Skia measures the real glyph widths.
    fn shape_footnote_with_caller(
        renderer: &Renderer,
        fn_spec: &FootnoteSpec,
        caller_letter: &str,
    ) -> (ParagraphSpec, Vec<InlineItem>) {
        let orig = &fn_spec.content;

        // Find the Caller-styled range (the "+" placeholder)
        let caller_range = orig
            .styles
            .iter()
            .find(|(_, s)| *s == Style::Caller)
            .map(|(r, _)| r.clone());

        let Some(cr) = caller_range else {
            // No caller in this footnote content — shape as-is
            let items = shape(renderer, orig);
            return (orig.clone(), items);
        };

        let old_len = cr.end - cr.start; // byte length of "+"
        let new_len = caller_letter.len();
        let delta = new_len as isize - old_len as isize;

        // Build new text with caller letter substituted
        let mut new_text = String::with_capacity(orig.text.len().wrapping_add_signed(delta));
        new_text.push_str(&orig.text[..cr.start]);
        new_text.push_str(caller_letter);
        new_text.push_str(&orig.text[cr.end..]);

        // Shift style ranges
        let new_styles: Vec<(ops::Range<usize>, Style)> = orig
            .styles
            .iter()
            .map(|(r, s)| {
                if r.start == cr.start {
                    // This is the caller range itself
                    (cr.start..cr.start + new_len, *s)
                } else if r.start >= cr.end {
                    // After the caller — shift by delta
                    let start = (r.start as isize + delta) as usize;
                    let end = (r.end as isize + delta) as usize;
                    (start..end, *s)
                } else {
                    // Before the caller — unchanged
                    (r.clone(), *s)
                }
            })
            .collect();

        // Shift index markers
        let new_index_markers: Vec<(usize, usize)> = orig
            .index_markers
            .iter()
            .map(|(offset, id)| {
                if *offset >= cr.end {
                    ((*offset as isize + delta) as usize, *id)
                } else {
                    (*offset, *id)
                }
            })
            .collect();

        let new_spec = ParagraphSpec {
            text: new_text,
            styles: new_styles,
            alignment: orig.alignment.clone(),
            indent: orig.indent,
            drop_cap: orig.drop_cap.clone(),
            spacing_before: orig.spacing_before,
            spacing_after: orig.spacing_after,
            index_markers: new_index_markers,
        };

        let items = shape(renderer, &new_spec);
        (new_spec, items)
    }

    /// Compute footnote height by shaping with the given caller letter and
    /// breaking into lines. Returns (shaped_spec, shaped_items, line_count).
    fn measure_footnote(
        renderer: &Renderer,
        fn_spec: &FootnoteSpec,
        caller_letter: &str,
        page_width: f32,
    ) -> (ParagraphSpec, Vec<InlineItem>, usize) {
        let (spec, items) = Self::shape_footnote_with_caller(renderer, fn_spec, caller_letter);
        let breaker = LineBreaker::new(&items, Box::new(move |_| (0.0, page_width)));
        let line_count = breaker.count();
        // Re-shape to get items again (iterator consumed them by reference, but
        // LineBreaker borrows &items so we can't move items before counting).
        // Actually LineBreaker borrows items, so count consumes the iterator not
        // the items. Let's just break again for rendering.
        (spec, items, line_count)
    }

    fn process_paragraph(&mut self, collected: &CollectedParagraph) {
        let spec = &collected.body;

        // Add spacing before
        if spec.spacing_before > 0.0 {
            if spec.spacing_before > self.available_body_height() {
                self.emit_page();
            }
            self.body_height += spec.spacing_before;
        }

        // Shape the body paragraph
        let all_items = shape(self.renderer, spec);

        // If there's a drop cap, the drop cap text was prepended to spec.text.
        // Find the byte length of the drop cap text so we can exclude those
        // InlineItems from line breaking (the drop cap is rendered as a fixed
        // fragment separately).
        let dc_text_len = if spec.drop_cap.is_some() {
            spec.styles
                .iter()
                .find(|(_, s)| *s == Style::Chapter)
                .map(|(r, _)| r.end)
                .unwrap_or(0)
        } else {
            0
        };

        // Split items: drop cap items vs body items
        let body_item_start = all_items
            .iter()
            .position(|item| item.range.start >= dc_text_len)
            .unwrap_or(all_items.len());
        let body_items = &all_items[body_item_start..];

        // Body line height is always Normal (drop cap has its own sizing)
        let body_line_height = self.renderer.line_height(&Style::Normal);
        let footer_line_height = self.renderer.line_height(&Style::Footnote);

        // Create width function for line breaker
        let page_width = self.dim.width;
        let drop_cap = spec.drop_cap.clone();
        let indent = spec.indent;

        // If there's a drop cap, measure it
        let dc_width = if let Some(ref _dc) = drop_cap {
            // The drop cap text is the first styled range with Chapter style
            let dc_range = spec
                .styles
                .iter()
                .find(|(_, s)| *s == Style::Chapter)
                .map(|(r, _)| r.clone());
            if let Some(range) = dc_range {
                let dc_text = &spec.text[range.clone()];
                let mut builder = self.renderer.new_builder();
                builder
                    .push_style(&self.renderer.get_style(&Style::Chapter))
                    .add_text(dc_text);
                let mut paragraph = builder.build();
                paragraph.layout(f32::INFINITY);
                use skia_safe::textlayout::{RectHeightStyle, RectWidthStyle};
                let rects = paragraph.get_rects_for_range(
                    0..dc_text.len(),
                    RectHeightStyle::Tight,
                    RectWidthStyle::Tight,
                );
                if rects.is_empty() {
                    0.0
                } else {
                    rects[0].rect.width()
                }
            } else {
                0.0
            }
        } else {
            0.0
        };

        let width_fn = move |line: usize| -> (f32, f32) {
            if let Some(ref dc) = drop_cap {
                if line < dc.line_span {
                    return (dc_width + dc.padding, page_width - dc_width - dc.padding);
                }
            }
            match line {
                0 => (indent.0, page_width - indent.0),
                _ => (indent.1, page_width - indent.1),
            }
        };

        // Break body into lines
        let breaker = LineBreaker::new(&body_items, Box::new(width_fn));
        let body_lines: Vec<BrokenLine> = breaker.collect();

        // Track the top of the first body line (may differ from initial
        // body_height if a page break occurs before/during the first line).
        let mut first_line_top: Option<f32> = None;

        // Record indices from drop cap items (excluded from body_items)
        for item in &all_items[..body_item_start] {
            if let Some(index_id) = item.index_id {
                if index_id < self.index_registry.len() {
                    self.indices
                        .insert(self.index_registry[index_id].clone(), self.page_index);
                }
            }
        }

        let num_lines = body_lines.len();

        for (line_idx, line) in body_lines.iter().enumerate() {
            let is_last_line = line_idx == num_lines - 1;

            // Scan for callers in this line, assign provisional caller letters,
            // and shape each footnote with the assigned letter for accurate widths.
            let mut line_footnote_height = 0.0;
            // (item_idx, caller_letter, footnote_id)
            let mut line_callers: Vec<(usize, String, usize)> = Vec::new();
            // Shaped footnote data, keyed by footnote_id
            let mut shaped_footnotes: HashMap<usize, (ParagraphSpec, Vec<InlineItem>, usize)> =
                HashMap::new();

            for idx in line.item_range.clone() {
                let item = &body_items[idx];
                if let ItemKind::Caller { footnote_id } = item.kind {
                    let caller_letter = usize_to_letters(self.caller_counter);
                    line_callers.push((idx, caller_letter.clone(), footnote_id));
                    self.caller_counter += 1;

                    // Shape footnote with actual caller letter and compute height
                    if footnote_id < collected.footnotes.len() {
                        let (fn_spec_shaped, fn_items, fn_line_count) = Self::measure_footnote(
                            self.renderer,
                            &collected.footnotes[footnote_id],
                            &caller_letter,
                            page_width,
                        );
                        line_footnote_height += fn_line_count as f32 * footer_line_height;
                        shaped_footnotes
                            .insert(footnote_id, (fn_spec_shaped, fn_items, fn_line_count));
                    }
                }
            }

            // Check if line + footnotes fit on current page
            let total_needed = body_line_height + line_footnote_height;
            if total_needed > self.available_body_height()
                && self.body_height > 0.0
            {
                self.emit_page();

                // Re-assign callers with reset counter and re-shape footnotes
                shaped_footnotes.clear();
                for (_item_idx, caller_letter, footnote_id) in &mut line_callers {
                    *caller_letter = usize_to_letters(self.caller_counter);
                    self.caller_counter += 1;

                    if *footnote_id < collected.footnotes.len() {
                        let (fn_spec_shaped, fn_items, fn_line_count) = Self::measure_footnote(
                            self.renderer,
                            &collected.footnotes[*footnote_id],
                            caller_letter,
                            page_width,
                        );
                        shaped_footnotes
                            .insert(*footnote_id, (fn_spec_shaped, fn_items, fn_line_count));
                    }
                }
            }

            // On the first body line, render the drop cap immediately so it
            // ends up on the correct page (before any later page breaks move
            // us to a different page).
            if first_line_top.is_none() {
                let flt = self.body_height;
                first_line_top = Some(flt);

                if let Some(ref dc) = spec.drop_cap {
                    let dc_range = spec
                        .styles
                        .iter()
                        .find(|(_, s)| *s == Style::Chapter)
                        .map(|(r, _)| r.clone());
                    if let Some(range) = dc_range {
                        let dc_text = spec.text[range].to_string();
                        let dc_line_height = body_line_height * dc.line_span as f32;
                        self.body_fragments.push(TextFragment::new(
                            dc_text,
                            Rectangle {
                                top: flt,
                                left: 0.0,
                                width: dc_width,
                                height: dc_line_height,
                            },
                            Style::Chapter,
                            0.0,
                        ));
                    }
                }
            }

            // Compute left offset for this line
            let (left_offset, line_width) = {
                if let Some(ref dc) = spec.drop_cap {
                    if line_idx < dc.line_span {
                        (dc_width + dc.padding, page_width - dc_width - dc.padding)
                    } else {
                        match line_idx {
                            0 => (spec.indent.0, page_width - spec.indent.0),
                            _ => (spec.indent.1, page_width - spec.indent.1),
                        }
                    }
                } else {
                    match line_idx {
                        0 => (spec.indent.0, page_width - spec.indent.0),
                        _ => (spec.indent.1, page_width - spec.indent.1),
                    }
                }
            };

            // Build the (item_idx, caller_letter) slice for body extract_fragments
            let body_caller_pairs: Vec<(usize, String)> = line_callers
                .iter()
                .map(|(idx, letter, _)| (*idx, letter.clone()))
                .collect();

            // Extract body fragments for this line
            let top = self.body_height;
            let fragments = extract_fragments(
                &body_items,
                &spec.text,
                line,
                top,
                body_line_height,
                left_offset,
                line_width,
                is_last_line,
                &spec.alignment,
                &body_caller_pairs,
            );

            // Record indices
            for idx in line.item_range.clone() {
                if let Some(index_id) = body_items[idx].index_id {
                    if index_id < self.index_registry.len() {
                        self.indices
                            .insert(self.index_registry[index_id].clone(), self.page_index);

                    }
                }
            }

            self.body_fragments.extend(fragments);
            self.body_height += body_line_height;

            // Render footnote content for callers on this line using the
            // properly shaped footnote items (with correct caller letter widths)
            for (_item_idx, _caller_letter, footnote_id) in &line_callers {
                if let Some((fn_spec_shaped, fn_items, _fn_line_count)) =
                    shaped_footnotes.get(footnote_id)
                {
                    let fn_breaker =
                        LineBreaker::new(fn_items, Box::new(|_| (0.0, page_width)));
                    let fn_lines: Vec<BrokenLine> = fn_breaker.collect();

                    let fn_num_lines = fn_lines.len();
                    for (fn_line_idx, fn_line) in fn_lines.iter().enumerate() {
                        let fn_top = self.dim.height
                            - self.footer_height
                            - (fn_num_lines - fn_line_idx) as f32 * footer_line_height;
                        let fn_fragments = extract_fragments(
                            fn_items,
                            &fn_spec_shaped.text,
                            fn_line,
                            fn_top,
                            footer_line_height,
                            0.0,
                            page_width,
                            fn_line_idx == fn_num_lines - 1,
                            &Alignment::Left,
                            &[], // no caller substitution needed — text already has the real letter
                        );
                        self.footer_fragments.extend(fn_fragments);
                    }
                    self.footer_height += fn_num_lines as f32 * footer_line_height;
                }
            }
        }

        // Add spacing after
        self.body_height += spec.spacing_after;
    }

    fn finalize(mut self) -> (Vec<Page>, Indices) {
        // Emit the last page if it has content
        if !self.body_fragments.is_empty()
            || !self.footer_fragments.is_empty()
            || !self.header_fragments.is_empty()
        {
            let mut page_fragments = Vec::new();
            page_fragments.append(&mut self.header_fragments);
            page_fragments.append(&mut self.body_fragments);
            page_fragments.append(&mut self.footer_fragments);
            self.pages.push(page_fragments);
        }

        (self.pages, self.indices)
    }
}

// ---------------------------------------------------------------------------
// Fragment extraction
// ---------------------------------------------------------------------------

fn extract_fragments(
    items: &[InlineItem],
    text: &str,
    line: &BrokenLine,
    top: f32,
    line_height: f32,
    left_offset: f32,
    line_width: f32,
    is_last_line: bool,
    alignment: &Alignment,
    callers: &[(usize, String)], // (item_idx, caller_letter)
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

        // Get the text for this item - if it's a caller, use the assigned letter
        let segment: String = if let ItemKind::Caller { .. } = item.kind {
            callers
                .iter()
                .find(|(i, _)| *i == idx)
                .map(|(_, letter)| letter.clone())
                .unwrap_or_else(|| text[item.range.clone()].to_string())
        } else {
            text[item.range.clone()].to_string()
        };

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
            current_text.push_str(&segment);
            current_width += effective_width;
            // Use the max word_spacing for the merged fragment
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
            // When a new fragment starts with glue, absorb it as a
            // positional gap instead of text content.  Flutter's
            // wordSpacing doesn't apply to a leading space in a TextSpan.
            if matches!(item.kind, ItemKind::Glue) {
                current_text = String::new();
                current_style = Some(item.style);
                current_left = left;
                current_width = 0.0;
                current_word_spacing = item_word_spacing;
            } else {
                current_text = segment;
                current_style = Some(item.style);
                current_left = left - effective_width;
                current_width = effective_width;
                current_word_spacing = item_word_spacing;
            }
        }
    }

    // Flush last fragment
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

// ---------------------------------------------------------------------------
// Utility functions
// ---------------------------------------------------------------------------

fn usize_to_letters(mut i: usize) -> String {
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


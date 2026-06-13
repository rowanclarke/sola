#[allow(dead_code)]
pub mod layout;
mod paint;
mod renderer;

use std::{ffi::c_char, mem};

pub use layout::{
    Alignment, ArchivedIndex, ArchivedIndices, ArchivedPages, Index, Indices,
};
pub use paint::Paint;
pub use renderer::{Renderer, TextStyle};
use rkyv::{Archive, Deserialize, Serialize, rancor::Error};
use usfm::{ArchivedBookIdentifier, BookIdentifier};

use layout::{
    Page, Section, TextFragment,
    inline::{ItemKind, StreamItem},
    container::{BufferEntry, StackDirection},
    scaffold::Scaffold,
    template::{ContainerFill, Template},
    artefact::{Artefact, ArtefactAnchor, ArtefactPadding},
    state::LayoutState,
};
use renderer::shape_segments;

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
// Location tracking
// ---------------------------------------------------------------------------

#[derive(Default)]
struct LocationState {
    book: Option<BookIdentifier>,
    header: Option<String>,
    chapter: Option<u16>,
}

// ---------------------------------------------------------------------------
// Container config for paint_paragraph
// ---------------------------------------------------------------------------

struct ContainerConfig {
    max_lines: usize,
    available_width: f32,
    direction: StackDirection,
    line_height: f32,
    alignment: Alignment,
    indent: (f32, f32),
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

pub struct Painter {
    renderer: Renderer,
    dim: Dimensions,

    // Buffer: cross-container flat stream
    buffer: Vec<BufferEntry>,
    active_section: Section,

    // Style stack (per-section would be complex; keep simple: one stack)
    style_stack: Vec<Style>,

    // Index registry
    index_registry: Vec<Index>,
    location: LocationState,

    // Scaffold + pages
    scaffold: Scaffold,
    pages: Vec<Page>,
    indices: layout::Indices,

    // Pending artefact for next template
    pending_artefacts: Vec<(Section, Artefact)>,

    // Layout state (resets on page break)
    state: LayoutState,
}

impl Painter {
    pub fn new(renderer: &Renderer, dim: Dimensions) -> Self {
        let scaffold = Scaffold::new(dim.width, dim.height);
        Self {
            renderer: renderer.clone(),
            dim,
            buffer: Vec::new(),
            active_section: Section::Body,
            style_stack: Vec::new(),
            index_registry: Vec::new(),
            location: LocationState::default(),
            scaffold,
            pages: Vec::new(),
            indices: layout::Indices::new(),
            pending_artefacts: Vec::new(),
            state: LayoutState::new(),
        }
    }

    pub fn get_dimensions(&self) -> &Dimensions {
        &self.dim
    }

    // --- Style management ---

    fn current_style(&self) -> Style {
        self.style_stack.last().copied().unwrap_or(Style::Normal)
    }

    pub fn push_properties(&mut self, style: Style, _section: Section) -> &mut Self {
        self.style_stack.push(style);
        self
    }

    pub fn pop_properties(&mut self) -> &mut Self {
        self.style_stack.pop();
        self
    }

    // --- Container management ---

    pub fn set_container(&mut self, section: Section) -> &mut Self {
        self.active_section = section;
        self
    }

    // --- Buffer filling ---

    pub fn add_text(&mut self, text: impl AsRef<str>) -> &mut Self {
        let text = text.as_ref();
        if text.is_empty() {
            return self;
        }
        let style = self.current_style();
        let section = self.active_section;
        self.buffer.push(BufferEntry::Segment {
            text: text.to_string(),
            style,
            section,
        });
        self
    }

    pub fn add_state_dependent(
        &mut self,
        f: Box<dyn Fn(&mut LayoutState) -> (String, Style)>,
    ) -> &mut Self {
        let section = self.active_section;
        self.buffer.push(BufferEntry::StateDep(f, section));
        self
    }

    pub fn begin_group(&mut self) -> &mut Self {
        self.buffer.push(BufferEntry::BeginGrouped);
        self
    }

    pub fn end_group(&mut self) -> &mut Self {
        self.buffer.push(BufferEntry::EndGrouped);
        self
    }

    pub fn begin_expanded(&mut self) -> &mut Self {
        self.buffer.push(BufferEntry::BeginExpanded);
        self
    }

    pub fn end_expanded(&mut self) -> &mut Self {
        self.buffer.push(BufferEntry::EndExpanded);
        self
    }

    pub fn add_index_marker(&mut self, index_id: usize) -> &mut Self {
        self.buffer.push(BufferEntry::IndexMarker(index_id));
        self
    }

    // --- Artefact ---

    pub fn add_artefact(&mut self, section: Section, artefact: Artefact) {
        self.pending_artefacts.push((section, artefact));
    }

    // --- Footnote convenience (group pattern) ---

    pub fn begin_footnote(&mut self) {
        self.begin_group();
        // Insert caller in body
        self.set_container(Section::Body);
        let section = self.active_section;
        self.buffer.push(BufferEntry::StateDep(
            Box::new(|state: &mut LayoutState| state.get_next_caller()),
            section,
        ));
        // Begin expanded for footer content
        self.begin_expanded();
        self.set_container(Section::Footer);
        // Insert caller in footer
        let section = self.active_section;
        self.buffer.push(BufferEntry::StateDep(
            Box::new(|state: &mut LayoutState| state.get_current_caller()),
            section,
        ));
    }

    pub fn end_footnote(&mut self) {
        self.end_expanded();
        self.set_container(Section::Body);
        self.end_group();
    }

    // --- Shape a single text+style for raw fragment creation ---

    pub fn raw(&self, text: &str, style: Style) -> TextFragment {
        let segments = vec![(text.to_string(), style)];
        let items = shape_segments(&self.renderer, &segments, Section::Body);
        let width: f32 = items.iter().map(|i| i.width).sum();
        let line_height = self.renderer.line_height(&style);
        TextFragment::new(
            text.to_string(),
            Rectangle {
                top: 0.0,
                left: 0.0,
                width,
                height: line_height,
            },
            style,
            0.0,
        )
    }

    // --- Index methods ---

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
        self.add_index_marker(id);
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
        self.add_index_marker(id);
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
        self.add_index_marker(id);
        self
    }

    // --- Paint paragraph variants ---

    pub fn paint_paragraph(&mut self) {
        self.do_paint_paragraph(Alignment::Justified, (20.0, 0.0));
    }

    pub fn paint_paragraph_with_indent(&mut self, first: f32, cont: f32) {
        self.do_paint_paragraph(Alignment::Left, (first, cont));
    }

    pub fn paint_heading(&mut self, text: impl AsRef<str>) {
        // Discard any text segments from buffer, keep index markers
        self.buffer.retain(|e| matches!(e, BufferEntry::IndexMarker(_)));

        // Create centered header fragment as a non-wrapping artefact
        let fragment = self.raw(text.as_ref(), Style::Header);
        let centered_x = (self.dim.width - fragment.rect.width) / 2.0;
        let mut centered = fragment;
        centered.rect.left = centered_x;

        let padding = self.dim.header_height / 2.0;
        let artefact = Artefact::new(
            ArtefactPadding { top: padding, bottom: padding, left: 0.0, right: 0.0 },
            self.dim.width,
            centered.rect.height,
            ArtefactAnchor::Left,
            false, // non-wrapping: takes its own vertical space
            0,
            vec![centered],
        );
        self.pending_artefacts.push((Section::Body, artefact));

        self.do_paint_paragraph(Alignment::Center, (0.0, 0.0));
    }

    pub fn clean(&mut self) {
        self.buffer.clear();
        self.pending_artefacts.clear();
    }

    // --- The core: paint_paragraph ---

    fn do_paint_paragraph(
        &mut self,
        alignment: Alignment,
        indent: (f32, f32),
    ) {
        let buffer = mem::take(&mut self.buffer);
        let artefacts = mem::take(&mut self.pending_artefacts);

        self.fill_paragraph(&buffer, &artefacts, alignment, indent, 0);
    }

    fn fill_paragraph(
        &mut self,
        buffer: &[BufferEntry],
        artefacts: &[(Section, Artefact)],
        alignment: Alignment,
        indent: (f32, f32),
        stream_offset: usize,
    ) {
        // 1. Resolve and shape: walk buffer entries, resolve state-deps, shape text
        let (stream, buf_map) = self.resolve_and_shape(buffer);

        if stream.is_empty() && artefacts.is_empty() {
            return;
        }

        // Handle artefact-only templates (e.g., headers with no text in stream)
        if stream.is_empty() {
            // Record any index markers directly
            for entry in buffer {
                if let BufferEntry::IndexMarker(id) = entry {
                    if *id < self.index_registry.len() {
                        self.indices.insert(
                            self.index_registry[*id].clone(),
                            self.pages.len(),
                        );
                    }
                }
            }

            let body_line_height = self.renderer.line_height(&Style::Normal);
            let mut template = Template::new();
            template.ensure_container(
                Section::Body,
                ContainerFill::new(
                    1, self.dim.width, StackDirection::TopDown,
                    body_line_height, alignment, indent,
                ),
            );
            for (section, artefact) in artefacts.iter() {
                eprintln!("[paint_paragraph] artefact-only: adding {:?} artefact (height={})",
                    section, artefact.total_height());
                template.add_artefact(*section, artefact.clone());
            }
            if let Some(fill) = template.containers.get_mut(&Section::Body) {
                fill.is_paragraph_end = true;
            }
            eprintln!("[paint_paragraph] artefact-only template height={}", template.total_height());
            match self.scaffold.push(template) {
                Ok(()) => {
                    eprintln!("[paint_paragraph]   scaffold accepted artefact template (remaining={})",
                        self.scaffold.remaining());
                }
                Err(rejected) => {
                    eprintln!("[paint_paragraph]   scaffold FULL, page break for artefact template");
                    let page = self.scaffold.finalize(
                        &self.index_registry, self.pages.len(), &mut self.indices,
                    );
                    self.pages.push(page);
                    self.scaffold = Scaffold::new(self.dim.width, self.dim.height);
                    self.state.reset();
                    let _ = self.scaffold.push(rejected);
                }
            }
            return;
        }

        // 2. Build template and fill
        let body_line_height = self.renderer.line_height(&Style::Normal);
        let footer_line_height = self.renderer.line_height(&Style::Footnote);

        let footer_config = ContainerConfig {
            max_lines: usize::MAX,
            available_width: self.dim.width,
            direction: StackDirection::BottomUp,
            line_height: footer_line_height,
            alignment: Alignment::Left,
            indent: (0.0, 0.0),
        };

        eprintln!("[paint_paragraph] stream has {} items, {} artefacts, alignment={:?}, indent={:?}",
            stream.len(), artefacts.len(), alignment, indent);

        // 3. Walk stream, fill templates, push to scaffold
        let mut cursor = stream_offset;
        let mut template_idx = if stream_offset > 0 { 1 } else { 0 };
        while cursor < stream.len() {
            let mut template = Template::new();

            // Only the first template uses the first-line indent;
            // continuation templates use (indent.1, indent.1)
            let template_indent = if template_idx == 0 {
                indent
            } else {
                (indent.1, indent.1)
            };

            // Set up containers in the template
            template.ensure_container(
                Section::Body,
                ContainerFill::new(
                    1, // max_lines: one line per template for body
                    self.dim.width,
                    StackDirection::TopDown,
                    body_line_height,
                    alignment,
                    template_indent,
                ),
            );

            // Add pending artefacts only to first template
            if template_idx == 0 {
                for (section, artefact) in artefacts.iter() {
                    eprintln!("[paint_paragraph]   template #{}: adding artefact to {:?} (line_span={}, {} fragments)",
                        template_idx, section, artefact.line_span, artefact.fragments.len());
                    template.add_artefact(*section, artefact.clone());
                }
            }

            // Fill the template using next_template algorithm
            let cursor_before = cursor;
            match self.next_template(&mut template, &stream, &mut cursor, &footer_config) {
                Ok(()) => {
                    eprintln!("[paint_paragraph]   template #{}: filled OK, cursor {} -> {}",
                        template_idx, cursor_before, cursor);
                }
                Err(rollback_cursor) => {
                    eprintln!("[paint_paragraph]   template #{}: Err, rollback cursor {} -> {}",
                        template_idx, cursor_before, rollback_cursor);
                    cursor = rollback_cursor;
                }
            }

            if template.is_empty() {
                eprintln!("[paint_paragraph]   template #{}: empty, breaking", template_idx);
                break;
            }

            // Mark the last template of this paragraph so justification works correctly
            let reached_end = cursor >= stream.len();
            if reached_end {
                if let Some(fill) = template.containers.get_mut(&Section::Body) {
                    fill.is_paragraph_end = true;
                }
            }

            eprintln!("[paint_paragraph]   template #{}: height={}, containers: {:?}, paragraph_end={}",
                template_idx, template.total_height(),
                template.containers.keys().collect::<Vec<_>>(), reached_end);

            // Push template to scaffold
            match self.scaffold.push(template) {
                Ok(()) => {
                    eprintln!("[paint_paragraph]   scaffold accepted template #{} (remaining={})",
                        template_idx, self.scaffold.remaining());
                }
                Err(_rejected) => {
                    eprintln!("[paint_paragraph]   scaffold FULL (remaining={}), page break",
                        self.scaffold.remaining());
                    // Page break: finalize current scaffold
                    let page = self.scaffold.finalize(
                        &self.index_registry,
                        self.pages.len(),
                        &mut self.indices,
                    );
                    self.pages.push(page);
                    self.scaffold = Scaffold::new(self.dim.width, self.dim.height);
                    self.state.reset();

                    // Find remaining buffer entries and recurse
                    let buf_start = buf_map[cursor_before];
                    let entry_first_stream = buf_map.iter().position(|&b| b == buf_start).unwrap_or(0);
                    let items_to_skip = cursor_before - entry_first_stream;

                    // Recursive re-fill with remaining buffer + continuation indent
                    self.fill_paragraph(
                        &buffer[buf_start..],
                        &[],                    // no artefacts on continuation
                        alignment,
                        (indent.1, indent.1),   // continuation indent
                        items_to_skip,
                    );
                    return;
                }
            }
            template_idx += 1;
        }
    }

    /// Walk the stream from `cursor`, filling `template`.
    /// Returns Ok(()) when template is full (one line in active container filled).
    /// Returns Err(rollback_cursor) if we need to back up.
    fn next_template(
        &self,
        template: &mut Template,
        stream: &[StreamItem],
        cursor: &mut usize,
        footer_config: &ContainerConfig,
    ) -> Result<(), usize> {
        let mut index = *cursor; // last break point
        let mut committed = 0usize; // items in template at last break point
        let mut in_group = false;
        let mut in_expanded = false;
        let mut active_section = Section::Body;

        while *cursor < stream.len() {
            let item = &stream[*cursor];

            match item {
                StreamItem::BeginGrouped => {
                    in_group = true;
                    *cursor += 1;
                }
                StreamItem::EndGrouped => {
                    in_group = false;
                    // Update break point at end of group
                    index = *cursor + 1;
                    committed = template.item_count(active_section);
                    *cursor += 1;
                }
                StreamItem::BeginExpanded => {
                    in_expanded = true;
                    *cursor += 1;
                }
                StreamItem::EndExpanded => {
                    in_expanded = false;
                    // Restore active section to Body after expanded ends
                    active_section = Section::Body;
                    *cursor += 1;
                }
                StreamItem::Inline(inline_item) => {
                    active_section = inline_item.section;

                    if in_expanded {
                        // Expanded items: ensure footer container exists, force push
                        let default_fill = ContainerFill::new(
                            footer_config.max_lines,
                            footer_config.available_width,
                            footer_config.direction,
                            footer_config.line_height,
                            footer_config.alignment,
                            footer_config.indent,
                        );
                        template.force_push(inline_item, &default_fill);
                        *cursor += 1;
                    } else {
                        // Normal fill
                        if matches!(inline_item.kind, ItemKind::Glue) && !in_group {
                            // Glue outside group: update break point
                            index = *cursor;
                            committed = template.item_count(active_section);
                        }

                        match template.push(inline_item) {
                            Ok(()) => {
                                *cursor += 1;
                            }
                            Err(()) => {
                                // Template full
                                if in_group {
                                    // Roll back to last break point
                                    template.truncate(active_section, committed);
                                    *cursor = index;
                                    return Err(index);
                                }
                                // Not in group: truncate to last break point
                                template.truncate(active_section, committed);
                                *cursor = index + 1; // skip the glue at break point
                                return Ok(());
                            }
                        }
                    }
                }
            }
        }

        // Reached end of stream
        Ok(())
    }

    /// Resolve buffer entries: evaluate state-deps, shape each entry independently.
    /// Returns (stream, buf_map) where buf_map[i] is the buffer entry index that
    /// produced stream[i].
    fn resolve_and_shape(&mut self, buffer: &[BufferEntry]) -> (Vec<StreamItem>, Vec<usize>) {
        let mut stream: Vec<StreamItem> = Vec::new();
        let mut buf_map: Vec<usize> = Vec::new();
        let mut pending_index_id: Option<usize> = None;

        // First pass: resolve all entries into (text, style, section) segments + markers
        struct ResolvedSegment {
            text: String,
            style: Style,
            section: Section,
            index_id: Option<usize>,
            buf_idx: usize,
        }
        enum ResolvedEntry {
            Segment(ResolvedSegment),
            BeginGrouped(usize),
            EndGrouped(usize),
            BeginExpanded(usize),
            EndExpanded(usize),
        }

        let mut resolved: Vec<ResolvedEntry> = Vec::new();

        for (buf_idx, entry) in buffer.iter().enumerate() {
            match entry {
                BufferEntry::Segment { text, style, section } => {
                    let idx = pending_index_id.take();
                    resolved.push(ResolvedEntry::Segment(ResolvedSegment {
                        text: text.clone(),
                        style: *style,
                        section: *section,
                        index_id: idx,
                        buf_idx,
                    }));
                }
                BufferEntry::StateDep(f, section) => {
                    let (text, style) = f(&mut self.state);
                    if !text.is_empty() {
                        let idx = pending_index_id.take();
                        resolved.push(ResolvedEntry::Segment(ResolvedSegment {
                            text,
                            style,
                            section: *section,
                            index_id: idx,
                            buf_idx,
                        }));
                    }
                }
                BufferEntry::BeginGrouped => {
                    resolved.push(ResolvedEntry::BeginGrouped(buf_idx));
                }
                BufferEntry::EndGrouped => {
                    resolved.push(ResolvedEntry::EndGrouped(buf_idx));
                }
                BufferEntry::BeginExpanded => {
                    resolved.push(ResolvedEntry::BeginExpanded(buf_idx));
                }
                BufferEntry::EndExpanded => {
                    resolved.push(ResolvedEntry::EndExpanded(buf_idx));
                }
                BufferEntry::IndexMarker(id) => {
                    pending_index_id = Some(*id);
                }
            }
        }

        // Second pass: shape each segment independently (no batching)
        let mut i = 0;
        while i < resolved.len() {
            match &resolved[i] {
                ResolvedEntry::BeginGrouped(bi) => {
                    buf_map.push(*bi);
                    stream.push(StreamItem::BeginGrouped);
                    i += 1;
                }
                ResolvedEntry::EndGrouped(bi) => {
                    buf_map.push(*bi);
                    stream.push(StreamItem::EndGrouped);
                    i += 1;
                }
                ResolvedEntry::BeginExpanded(bi) => {
                    buf_map.push(*bi);
                    stream.push(StreamItem::BeginExpanded);
                    i += 1;
                }
                ResolvedEntry::EndExpanded(bi) => {
                    buf_map.push(*bi);
                    stream.push(StreamItem::EndExpanded);
                    i += 1;
                }
                ResolvedEntry::Segment(seg) => {
                    let segments = vec![(seg.text.clone(), seg.style)];
                    let mut items = shape_segments(&self.renderer, &segments, seg.section);
                    // Assign index_id to first item if present
                    if let Some(idx_id) = seg.index_id {
                        if let Some(first) = items.first_mut() {
                            first.index_id = Some(idx_id);
                        }
                    }
                    for item in items {
                        buf_map.push(seg.buf_idx);
                        stream.push(StreamItem::Inline(item));
                    }
                    i += 1;
                }
            }
        }

        (stream, buf_map)
    }

    // --- Final layout ---

    pub fn layout(&mut self) -> (Vec<Page>, Indices) {
        // Finalize last scaffold
        if !self.scaffold.templates.is_empty() {
            let page = self.scaffold.finalize(
                &self.index_registry,
                self.pages.len(),
                &mut self.indices,
            );
            self.pages.push(page);
        }

        (mem::take(&mut self.pages), mem::take(&mut self.indices))
    }
}

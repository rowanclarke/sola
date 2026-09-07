use super::artefact::ArtefactAnchor;
use super::container::StackDirection;
use super::fragment::{TextFragment, extract_fragments};
use super::inline::BrokenLine;
use super::line_breaker::LineBreaker;
use super::template::{ContainerFill, Template};
use super::{Index, Indices};

#[allow(dead_code)]
pub struct Scaffold {
    pub width: f32,
    pub height: f32,
    pub columns: usize,
    pub gutter: f32,
    pub col_width: f32,
    pub templates: Vec<Template>,
    /// `cuts[c]..cuts[c + 1]` is the slice of `templates` held by column `c`.
    /// Always `columns + 1` long, and always in step with `templates`.
    cuts: Vec<usize>,
    /// Full-width band across the top of the page, above every column.
    span: Vec<TextFragment>,
    span_height: f32,
}

impl Scaffold {
    pub fn new(width: f32, height: f32, columns: usize, gutter: f32) -> Self {
        let columns = columns.max(1);
        let col_width = (width - (columns - 1) as f32 * gutter) / columns as f32;
        Self {
            width,
            height,
            columns,
            gutter,
            col_width,
            templates: Vec::new(),
            cuts: vec![0; columns + 1],
            span: Vec::new(),
            span_height: 0.0,
        }
    }

    pub fn is_empty(&self) -> bool {
        self.templates.is_empty() && self.span.is_empty()
    }

    /// Place a full-width band across the top of the page, above every column.
    ///
    /// Only valid while the page is still empty. A band part-way down would
    /// have to cut every column at the same height and restart them below it,
    /// turning a page into a stack of column regions; that is a much larger
    /// problem, and nothing needs it while `\h` (the only heading source) is
    /// the first thing painted in a book.
    pub fn push_span(&mut self, fragments: Vec<TextFragment>, height: f32) -> Result<(), ()> {
        if !self.is_empty() {
            return Err(());
        }
        self.span = fragments;
        self.span_height = height;
        Ok(())
    }

    /// Height of the page-wide footer: every note raised by every column.
    fn footer_height(&self) -> f32 {
        self.templates.iter().map(|t| t.footer_height()).sum()
    }

    /// Body height left to each column once the spanning band and the footer
    /// have taken their share.
    fn budget(&self) -> f32 {
        self.height - self.span_height - self.footer_height()
    }

    /// Greedily pack every template into `columns` columns of `budget` height.
    /// Returns the cut points, or None if they do not all fit.
    fn distribute(&self, budget: f32) -> Option<Vec<usize>> {
        let mut cuts = Vec::with_capacity(self.columns + 1);
        cuts.push(0);
        let mut i = 0;
        for _ in 0..self.columns {
            let mut used = 0.0f32;
            while i < self.templates.len() {
                let h = self.templates[i].body_height();
                // `used > 0.0` stops an over-tall template being rejected by an
                // empty column, which would stall the painter.
                if used > 0.0 && used + h > budget {
                    break;
                }
                used += h;
                i += 1;
            }
            cuts.push(i);
        }
        (i == self.templates.len()).then_some(cuts)
    }

    /// Try to push a template. Returns Ok on success, Err(template) if the page is full.
    ///
    /// Nothing is positioned until [`Scaffold::finalize`], so the whole page is
    /// re-split against the current footer budget on every push. That is what
    /// keeps a note raised in a later column from silently overflowing an
    /// earlier one: templates are already shaped and measured, so re-splitting
    /// is a scan of `f32` adds rather than a re-render.
    pub fn push(&mut self, template: Template) -> Result<(), Template> {
        self.templates.push(template);
        match self.distribute(self.budget()) {
            Some(cuts) => {
                self.cuts = cuts;
                Ok(())
            }
            // Popping restores the previous valid state exactly: it takes back
            // both the body height and the footer height this template added,
            // so the page breaks at the note that no longer fits.
            None => Err(self.templates.pop().unwrap()),
        }
    }

    /// Even out the columns of a partially filled page. Full pages are already
    /// balanced (every column was packed to the same budget), so this is only
    /// worth running on the last page of a book.
    pub fn balance(&mut self) {
        if self.columns < 2 || self.templates.is_empty() {
            return;
        }

        // The page's notes are all known by now, so the footer height is fixed
        // and `hi` is a budget the invariant guarantees will fit.
        let mut hi = self.budget();
        let total: f32 = self.templates.iter().map(|t| t.body_height()).sum();
        let mut lo = total / self.columns as f32;
        if lo >= hi {
            return;
        }
        if let Some(cuts) = self.distribute(lo) {
            self.cuts = cuts;
            return;
        }

        // Smallest budget that still holds every template in `columns` columns.
        for _ in 0..32 {
            if hi - lo < 0.5 {
                break;
            }
            let mid = 0.5 * (lo + hi);
            match self.distribute(mid) {
                Some(_) => hi = mid,
                None => lo = mid,
            }
        }

        if let Some(cuts) = self.distribute(hi) {
            self.cuts = cuts;
        }
    }

    /// Finalize scaffold into a Page, recording indices.
    pub fn finalize(
        &self,
        index_registry: &[Index],
        page_index: usize,
        indices: &mut Indices,
    ) -> Vec<TextFragment> {
        let mut all_fragments = Vec::new();

        // Pass 0: the spanning band, already positioned in full-page
        // coordinates. It sits above every column and takes no column offset.
        all_fragments.extend(self.span.iter().cloned());

        // Pass 1: TopDown containers (body text, headers, etc.), column by
        // column. Each column restarts at the top of the page and is shifted
        // right by its own share of the width.
        for col in 0..self.columns {
            let x = col as f32 * (self.col_width + self.gutter);
            let mut y_top = self.span_height;
            for template in &self.templates[self.cuts[col]..self.cuts[col + 1]] {
                for (_, fill) in template
                    .containers
                    .iter()
                    .filter(|(_, f)| f.direction == StackDirection::TopDown)
                {
                    let h = fill.total_height();
                    let mut placed = Vec::new();
                    // Add artefact fragments for this container
                    for artefact in &fill.artefacts {
                        for frag in &artefact.fragments {
                            let mut frag = frag.clone();
                            frag.rect.top += y_top + artefact.padding.top;
                            placed.push(frag);
                        }
                    }
                    placed.extend(self.extract_container(
                        fill,
                        y_top,
                        index_registry,
                        page_index,
                        indices,
                    ));
                    for frag in placed.iter_mut() {
                        frag.rect.left += x;
                    }
                    y_top += h;
                    all_fragments.extend(placed);
                }
            }
        }

        // Pass 2: BottomUp containers (footnotes) pool into one page-wide block
        // at the foot, laid out top-to-bottom from where the body stops. No
        // column offset: the block spans the full width.
        let mut y_footer = self.height - self.footer_height();
        for template in &self.templates {
            for (_, fill) in template
                .containers
                .iter()
                .filter(|(_, f)| f.direction == StackDirection::BottomUp)
            {
                let frags =
                    self.extract_container(fill, y_footer, index_registry, page_index, indices);
                // Add artefact fragments for this container
                for artefact in &fill.artefacts {
                    for frag in &artefact.fragments {
                        let mut placed = frag.clone();
                        placed.rect.top += y_footer + artefact.padding.top;
                        all_fragments.push(placed);
                    }
                }
                y_footer += fill.total_height();
                all_fragments.extend(frags);
            }
        }

        all_fragments
    }

    fn extract_container(
        &self,
        fill: &ContainerFill,
        y_start: f32,
        index_registry: &[Index],
        page_index: usize,
        indices: &mut Indices,
    ) -> Vec<TextFragment> {
        if fill.items.is_empty() {
            return Vec::new();
        }

        let mut fragments = Vec::new();
        let line_height = fill.line_height;

        // Run LineBreaker to get proper line breaks
        let indent = fill.indent;
        let available_width = fill.available_width;
        let artefacts = &fill.artefacts;
        let width_fn: Box<dyn Fn(usize) -> (f32, f32)> = Box::new(move |line: usize| {
            let ind = if line == 0 { indent.0 } else { indent.1 };
            let left_artefact: f32 = artefacts
                .iter()
                .filter(|a| line < a.line_span && a.anchor == ArtefactAnchor::Left)
                .map(|a| a.total_width())
                .sum();
            let left_offset = ind.max(left_artefact);
            let right_artefact: f32 = artefacts
                .iter()
                .filter(|a| line < a.line_span && a.anchor == ArtefactAnchor::Right)
                .map(|a| a.total_width())
                .sum();
            (left_offset, available_width - left_offset - right_artefact)
        });

        let mut breaker = LineBreaker::new(&fill.items, width_fn);
        let mut lines: Vec<BrokenLine> = Vec::new();
        while let Some(bl) = breaker.next() {
            lines.push(bl);
        }

        let num_lines = lines.len();
        for (line_idx, broken_line) in lines.iter().enumerate() {
            // Only the last line of the paragraph (not just this template) skips justification
            let is_last = line_idx == num_lines - 1 && fill.is_paragraph_end;
            let y = y_start + (line_idx as f32 * line_height);

            let (left_offset, line_width) = {
                let ind = if line_idx == 0 {
                    fill.indent.0
                } else {
                    fill.indent.1
                };
                let left_artefact: f32 = fill
                    .artefacts
                    .iter()
                    .filter(|a| line_idx < a.line_span && a.anchor == ArtefactAnchor::Left)
                    .map(|a| a.total_width())
                    .sum();
                let left_offset = ind.max(left_artefact);
                let right_artefact: f32 = fill
                    .artefacts
                    .iter()
                    .filter(|a| line_idx < a.line_span && a.anchor == ArtefactAnchor::Right)
                    .map(|a| a.total_width())
                    .sum();
                (
                    left_offset,
                    fill.available_width - left_offset - right_artefact,
                )
            };

            // Record indices
            for item_idx in broken_line.item_range.clone() {
                if let Some(index_id) = fill.items[item_idx].index_id {
                    if index_id < index_registry.len() {
                        indices.insert(index_registry[index_id].clone(), page_index);
                    }
                }
            }

            let frags = extract_fragments(
                &fill.items,
                broken_line,
                y,
                line_height,
                left_offset,
                line_width,
                is_last,
                &fill.alignment,
            );
            fragments.extend(frags);
        }

        fragments
    }
}

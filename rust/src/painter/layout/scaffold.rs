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
    pub top_cursor: f32,
    pub bottom_cursor: f32,
    pub templates: Vec<Template>,
}

impl Scaffold {
    pub fn new(width: f32, height: f32) -> Self {
        Self {
            width,
            height,
            top_cursor: 0.0,
            bottom_cursor: height,
            templates: Vec::new(),
        }
    }

    pub fn remaining(&self) -> f32 {
        self.bottom_cursor - self.top_cursor
    }

    /// Try to push a template. Returns Ok on success, Err(template) if scaffold is full.
    pub fn push(&mut self, template: Template) -> Result<(), Template> {
        let height = template.total_height();
        if height > self.remaining() && !self.templates.is_empty() {
            return Err(template);
        }

        // Advance cursors based on container directions
        for fill in template.containers.values() {
            let container_height = fill.total_height();
            match fill.direction {
                StackDirection::TopDown => {
                    self.top_cursor += container_height;
                }
                StackDirection::BottomUp => {
                    self.bottom_cursor -= container_height;
                }
            }
        }

        self.templates.push(template);
        Ok(())
    }

    /// Finalize scaffold into a Page, recording indices.
    pub fn finalize(
        &self,
        index_registry: &[Index],
        page_index: usize,
        indices: &mut Indices,
    ) -> Vec<TextFragment> {
        let mut all_fragments = Vec::new();

        // Pass 1: TopDown containers (body text, headers, etc.)
        let mut y_top = 0.0f32;
        for template in &self.templates {
            for (_, fill) in template.containers.iter().filter(|(_, f)| f.direction == StackDirection::TopDown) {
                let h = fill.total_height();
                let frags = self.extract_container(
                    fill, y_top, index_registry, page_index, indices,
                );
                // Add artefact fragments for this container
                for artefact in &fill.artefacts {
                    for frag in &artefact.fragments {
                        let mut placed = frag.clone();
                        placed.rect.top += y_top + artefact.padding.top;
                        all_fragments.push(placed);
                    }
                }
                y_top += h;
                all_fragments.extend(frags);
            }
        }

        // Pass 2: BottomUp containers (footnotes), placed top-to-bottom
        // within the footer area starting at self.bottom_cursor
        let mut y_footer = self.bottom_cursor;
        for template in &self.templates {
            for (_, fill) in template.containers.iter().filter(|(_, f)| f.direction == StackDirection::BottomUp) {
                let frags = self.extract_container(
                    fill, y_footer, index_registry, page_index, indices,
                );
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
                let ind = if line_idx == 0 { fill.indent.0 } else { fill.indent.1 };
                let left_artefact: f32 = fill.artefacts
                    .iter()
                    .filter(|a| line_idx < a.line_span && a.anchor == ArtefactAnchor::Left)
                    .map(|a| a.total_width())
                    .sum();
                let left_offset = ind.max(left_artefact);
                let right_artefact: f32 = fill.artefacts
                    .iter()
                    .filter(|a| line_idx < a.line_span && a.anchor == ArtefactAnchor::Right)
                    .map(|a| a.total_width())
                    .sum();
                (left_offset, fill.available_width - left_offset - right_artefact)
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

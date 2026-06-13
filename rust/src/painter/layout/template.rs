use std::collections::HashMap;

use super::Alignment;
use super::Section;
use super::artefact::{Artefact, ArtefactAnchor};
use super::container::StackDirection;
use super::inline::{InlineItem, ItemKind};

/// Tracks the fill state of one container within a template.
#[derive(Debug, Clone)]
pub struct ContainerFill {
    pub items: Vec<InlineItem>,
    pub num_lines: usize,
    pub current_line_width: f32,
    pub max_lines: usize,
    pub available_width: f32,
    pub direction: StackDirection,
    pub line_height: f32,
    pub alignment: Alignment,
    pub indent: (f32, f32),
    pub artefacts: Vec<Artefact>,
    pub is_paragraph_end: bool,
}

impl ContainerFill {
    pub fn new(
        max_lines: usize,
        available_width: f32,
        direction: StackDirection,
        line_height: f32,
        alignment: Alignment,
        indent: (f32, f32),
    ) -> Self {
        Self {
            items: Vec::new(),
            num_lines: 1,
            current_line_width: 0.0,
            max_lines,
            available_width,
            direction,
            line_height,
            alignment,
            indent,
            artefacts: Vec::new(),
            is_paragraph_end: false,
        }
    }

    /// Width available for a given line index, accounting for indent and artefacts.
    /// Left-anchored artefacts replace (not add to) the indent when larger.
    fn line_width(&self, line_idx: usize) -> f32 {
        let indent = if line_idx == 0 {
            self.indent.0
        } else {
            self.indent.1
        };
        let left_artefact: f32 = self
            .artefacts
            .iter()
            .filter(|a| line_idx < a.line_span && a.anchor == ArtefactAnchor::Left)
            .map(|a| a.total_width())
            .sum();
        let left_offset = indent.max(left_artefact);
        let right_artefact: f32 = self
            .artefacts
            .iter()
            .filter(|a| line_idx < a.line_span && a.anchor == ArtefactAnchor::Right)
            .map(|a| a.total_width())
            .sum();
        self.available_width - left_offset - right_artefact
    }

    /// Try to push an item. Returns Err if container is full (max_lines exceeded).
    pub fn push(&mut self, item: InlineItem) -> Result<(), ()> {
        let width = self.line_width(self.num_lines - 1);
        match item.kind {
            ItemKind::Glue => {
                self.current_line_width += item.width;
                self.items.push(item);
                Ok(())
            }
            ItemKind::Word => {
                if self.current_line_width + item.width > width
                    && self.current_line_width > 0.0
                {
                    // Need a new line
                    if self.num_lines >= self.max_lines {
                        return Err(());
                    }
                    self.num_lines += 1;
                    self.current_line_width = item.width;
                    self.items.push(item);
                    Ok(())
                } else {
                    self.current_line_width += item.width;
                    self.items.push(item);
                    Ok(())
                }
            }
        }
    }

    /// Force push an item, ignoring max_lines constraint.
    pub fn force_push(&mut self, item: InlineItem) {
        let width = self.line_width(self.num_lines - 1);
        match item.kind {
            ItemKind::Glue => {
                self.current_line_width += item.width;
            }
            ItemKind::Word => {
                if self.current_line_width + item.width > width
                    && self.current_line_width > 0.0
                {
                    self.num_lines += 1;
                    self.current_line_width = item.width;
                } else {
                    self.current_line_width += item.width;
                }
            }
        }
        self.items.push(item);
    }

    /// Truncate to n items and recalculate line state.
    pub fn truncate(&mut self, n: usize) {
        self.items.truncate(n);
        // Recalculate
        self.num_lines = 1;
        self.current_line_width = 0.0;
        for i in 0..self.items.len() {
            let width = self.line_width(self.num_lines - 1);
            match self.items[i].kind {
                ItemKind::Glue => {
                    self.current_line_width += self.items[i].width;
                }
                ItemKind::Word => {
                    if self.current_line_width + self.items[i].width > width
                        && self.current_line_width > 0.0
                    {
                        self.num_lines += 1;
                        self.current_line_width = self.items[i].width;
                    } else {
                        self.current_line_width += self.items[i].width;
                    }
                }
            }
        }
    }

    pub fn item_count(&self) -> usize {
        self.items.len()
    }

    pub fn total_height(&self) -> f32 {
        let text_height = if self.items.is_empty() {
            0.0
        } else {
            self.num_lines as f32 * self.line_height
        };

        let mut height = text_height;
        for a in &self.artefacts {
            if a.wrap {
                // Wrapping artefact overlaps with text lines;
                // container must be at least as tall as the artefact
                height = height.max(a.total_height());
            } else {
                // Non-wrapping artefact takes its own vertical space
                height += a.total_height();
            }
        }

        height
    }

    pub fn is_empty(&self) -> bool {
        self.items.is_empty()
    }
}

/// A template represents one "placement unit" pushed to the scaffold.
/// Usually one line in the active container plus associated expanded content.
pub struct Template {
    pub containers: HashMap<Section, ContainerFill>,
    pub hot: bool,
}

impl Template {
    pub fn new() -> Self {
        Self {
            containers: HashMap::new(),
            hot: false,
        }
    }

    pub fn ensure_container(&mut self, section: Section, fill: ContainerFill) {
        self.containers.entry(section).or_insert(fill);
    }

    /// Add artefact to a container, adjusting its max_lines.
    pub fn add_artefact(&mut self, section: Section, artefact: Artefact) {
        if let Some(fill) = self.containers.get_mut(&section) {
            if artefact.line_span > fill.max_lines {
                fill.max_lines = artefact.line_span;
            }
            fill.artefacts.push(artefact);
        }
    }

    /// Push item to its container. Returns Err if the container is full.
    pub fn push(&mut self, item: &InlineItem) -> Result<(), ()> {
        let section = item.section;
        if let Some(fill) = self.containers.get_mut(&section) {
            fill.push(item.clone())
        } else {
            // Container doesn't exist yet — shouldn't happen if properly initialized
            Err(())
        }
    }

    /// Force push item (expanded). Creates container if needed with unlimited lines.
    pub fn force_push(&mut self, item: &InlineItem, default_config: &ContainerFill) {
        let section = item.section;
        let fill = self.containers.entry(section).or_insert_with(|| {
            ContainerFill::new(
                usize::MAX,
                default_config.available_width,
                default_config.direction,
                default_config.line_height,
                default_config.alignment,
                (0.0, 0.0),
            )
        });
        fill.force_push(item.clone());
    }

    /// Truncate a container back to n items.
    pub fn truncate(&mut self, section: Section, n: usize) {
        if let Some(fill) = self.containers.get_mut(&section) {
            fill.truncate(n);
        }
    }

    /// Number of items in a container.
    pub fn item_count(&self, section: Section) -> usize {
        self.containers.get(&section).map_or(0, |f| f.item_count())
    }

    /// Total height across all containers.
    pub fn total_height(&self) -> f32 {
        self.containers.values().map(|f| f.total_height()).sum()
    }

    pub fn mark_hot(&mut self) {
        self.hot = true;
    }

    pub fn is_hot(&self) -> bool {
        self.hot
    }

    pub fn is_empty(&self) -> bool {
        self.containers.values().all(|f| f.is_empty())
    }
}

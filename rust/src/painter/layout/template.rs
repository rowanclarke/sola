use crate::painter::Style;
use crate::painter::renderer::Renderer;

use super::container::{
    ContainerId, ContainerSpec, FilledContainer, PlacedLine, StackDirection,
};
use super::fragment::usize_to_letters;
use super::inline::{InlineItem, ItemKind};
use super::line_breaker::LineBreaker;
use super::paragraph::DropCap;

#[derive(Debug, Clone)]
pub struct ContentSource {
    pub id: usize,
    pub text: String,
    pub items: Vec<InlineItem>,
    pub style: Style,
}

#[derive(Debug, Clone)]
pub struct TemplateState {
    pub caller_counter: usize,
}

impl TemplateState {
    pub fn new() -> Self {
        Self { caller_counter: 0 }
    }

    pub fn caller_letter(&self, counter: usize) -> String {
        usize_to_letters(counter)
    }

    pub fn next_caller(&mut self) -> usize {
        let current = self.caller_counter;
        self.caller_counter += 1;
        current
    }

    pub fn reset_callers(&mut self) {
        self.caller_counter = 0;
    }
}

#[derive(Debug, Clone)]
pub struct Overflow {
    pub container_id: ContainerId,
    pub source_id: usize,
    pub item_cursor: usize,
    pub remaining_items: Vec<InlineItem>,
    pub remaining_text: String,
    pub continuation_style: Style,
    pub indent: (f32, f32),
    pub drop_cap: Option<DropCap>,
    pub drop_cap_width: f32,
}

#[derive(Debug)]
pub enum AllocResult {
    Placed,
    Full(Overflow),
    Hot,
}

struct ContainerState {
    spec: ContainerSpec,
    direction: StackDirection,
    lines: Vec<PlacedLine>,
    consumed_height: f32,
    /// Tracks the line_breaker cursor for the current source being allocated
    line_breaker_cursor: usize,
    /// Current line index within this container (for width_fn)
    line_index: usize,
}

pub struct Template {
    column_width: f32,
    column_height: f32,
    containers: Vec<ContainerState>,
    sources: Vec<ContentSource>,
    state: TemplateState,
    is_hot: bool,
    /// Callers found during allocation: (item_idx, source_id, caller_letter)
    callers: Vec<(usize, usize, String)>,
    /// Current source allocation state
    current_indent: (f32, f32),
    current_drop_cap: Option<DropCap>,
    current_drop_cap_width: f32,
}

/// Compute (left_offset, line_width) for a given line index, indent, and optional drop cap.
fn compute_line_dims(
    line: usize,
    column_width: f32,
    indent: (f32, f32),
    drop_cap_width: f32,
    drop_cap: &Option<DropCap>,
) -> (f32, f32) {
    if let Some(dc) = drop_cap {
        if line < dc.line_span {
            return (
                drop_cap_width + dc.padding,
                column_width - drop_cap_width - dc.padding,
            );
        }
    }
    match line {
        0 => (indent.0, column_width - indent.0),
        _ => (indent.1, column_width - indent.1),
    }
}

impl Template {
    pub fn new(column_width: f32, column_height: f32) -> Self {
        Self {
            column_width,
            column_height,
            containers: Vec::new(),
            sources: Vec::new(),
            state: TemplateState::new(),
            is_hot: false,
            callers: Vec::new(),
            current_indent: (0.0, 0.0),
            current_drop_cap: None,
            current_drop_cap_width: 0.0,
        }
    }

    pub fn add_container(
        &mut self,
        spec: ContainerSpec,
        direction: StackDirection,
    ) -> ContainerId {
        let id = spec.id;
        self.containers.push(ContainerState {
            spec,
            direction,
            lines: Vec::new(),
            consumed_height: 0.0,
            line_breaker_cursor: 0,
            line_index: 0,
        });
        id
    }

    pub fn register_source(
        &mut self,
        text: String,
        items: Vec<InlineItem>,
        style: Style,
    ) -> usize {
        let id = self.sources.len();
        self.sources.push(ContentSource {
            id,
            text,
            items,
            style,
        });
        id
    }

    pub fn sources(&self) -> &[ContentSource] {
        &self.sources
    }

    pub fn callers(&self) -> &[(usize, usize, String)] {
        &self.callers
    }

    fn container_index(&self, id: ContainerId) -> usize {
        self.containers
            .iter()
            .position(|c| c.spec.id == id)
            .expect("container not found")
    }

    fn total_consumed(&self) -> f32 {
        self.containers.iter().map(|c| c.consumed_height).sum()
    }

    pub fn remaining_column_height(&self) -> f32 {
        self.column_height - self.total_consumed()
    }

    pub fn consumed_height(&self, container_id: ContainerId) -> f32 {
        let idx = self.container_index(container_id);
        self.containers[idx].consumed_height
    }

    pub fn remaining_height(&self, container_id: ContainerId) -> f32 {
        let idx = self.container_index(container_id);
        let other_consumed: f32 = self
            .containers
            .iter()
            .enumerate()
            .filter(|(i, _)| *i != idx)
            .map(|(_, c)| c.consumed_height)
            .sum();
        self.column_height - other_consumed - self.containers[idx].consumed_height
    }

    pub fn set_source_layout(
        &mut self,
        indent: (f32, f32),
        drop_cap: Option<DropCap>,
        drop_cap_width: f32,
    ) {
        self.current_indent = indent;
        self.current_drop_cap = drop_cap;
        self.current_drop_cap_width = drop_cap_width;
    }

    pub fn alloc_line(
        &mut self,
        container_id: ContainerId,
        source_id: usize,
        renderer: &Renderer,
    ) -> AllocResult {
        let idx = self.container_index(container_id);
        let style = self.sources[source_id].style;
        let line_height = renderer.line_height(&style);

        // Check if there's space
        if line_height > self.remaining_height(container_id) {
            let cursor = self.containers[idx].line_breaker_cursor;
            if cursor < self.sources[source_id].items.len() {
                return AllocResult::Full(Overflow {
                    container_id,
                    source_id,
                    item_cursor: cursor,
                    remaining_items: self.sources[source_id].items[cursor..].to_vec(),
                    remaining_text: self.sources[source_id].text.clone(),
                    continuation_style: style,
                    indent: self.current_indent,
                    drop_cap: self.current_drop_cap.clone(),
                    drop_cap_width: self.current_drop_cap_width,
                });
            }
            return AllocResult::Placed;
        }

        let cursor = self.containers[idx].line_breaker_cursor;
        if cursor >= self.sources[source_id].items.len() {
            return AllocResult::Placed;
        }

        // Break one line
        let line_index = self.containers[idx].line_index;
        let indent = self.current_indent;
        let dc_width = self.current_drop_cap_width;
        let dc = self.current_drop_cap.clone();
        let col_width = self.column_width;

        let (broken_line, new_cursor) = {
            let items_slice = &self.sources[source_id].items[cursor..];
            let width_fn = Box::new(move |line: usize| {
                compute_line_dims(line + line_index, col_width, indent, dc_width, &dc)
            });
            let mut breaker = LineBreaker::new(items_slice, width_fn);
            match breaker.next() {
                Some(mut bl) => {
                    bl.item_range.start += cursor;
                    bl.item_range.end += cursor;
                    (bl, cursor + breaker.cursor())
                }
                None => {
                    // No more content
                    let items_len = items_slice.len();
                    return {
                        self.containers[idx].line_breaker_cursor = cursor + items_len;
                        AllocResult::Placed
                    };
                }
            }
        };

        // Scan for callers and check hot
        for item_idx in broken_line.item_range.clone() {
            if let ItemKind::Caller { .. } = self.sources[source_id].items[item_idx].kind {
                let expected_letter = self.state.caller_letter(self.state.caller_counter);
                let shaped_text =
                    &self.sources[source_id].text[self.sources[source_id].items[item_idx].range.clone()];

                if shaped_text != expected_letter {
                    self.is_hot = true;
                    return AllocResult::Hot;
                }

                self.callers
                    .push((item_idx, source_id, expected_letter));
                self.state.next_caller();
            }
        }

        // Compute y position
        let direction = self.containers[idx].direction;
        let consumed = self.containers[idx].consumed_height;
        let y = match direction {
            StackDirection::TopDown => consumed,
            StackDirection::BottomUp => self.column_height - consumed - line_height,
        };

        // Compute x and width for this line
        let (left_offset, line_width) = compute_line_dims(
            line_index,
            self.column_width,
            self.current_indent,
            self.current_drop_cap_width,
            &self.current_drop_cap,
        );

        let placed = PlacedLine {
            line: broken_line,
            y,
            x: left_offset,
            width: line_width,
            source_id,
        };

        let container = &mut self.containers[idx];
        container.lines.push(placed);
        container.consumed_height += line_height;
        container.line_breaker_cursor = new_cursor;
        container.line_index += 1;

        AllocResult::Placed
    }

    pub fn alloc_all(
        &mut self,
        container_id: ContainerId,
        source_id: usize,
        renderer: &Renderer,
    ) -> Option<Overflow> {
        let idx = self.container_index(container_id);
        self.containers[idx].line_breaker_cursor = 0;
        self.containers[idx].line_index = 0;

        loop {
            let idx = self.container_index(container_id);
            let cursor = self.containers[idx].line_breaker_cursor;
            if cursor >= self.sources[source_id].items.len() {
                return None;
            }

            match self.alloc_line(container_id, source_id, renderer) {
                AllocResult::Placed => {
                    let idx = self.container_index(container_id);
                    let cursor = self.containers[idx].line_breaker_cursor;
                    if cursor >= self.sources[source_id].items.len() {
                        return None;
                    }
                }
                AllocResult::Full(overflow) => return Some(overflow),
                AllocResult::Hot => return None,
            }
        }
    }

    pub fn alloc_spacing(&mut self, container_id: ContainerId, height: f32) -> bool {
        if height <= 0.0 {
            return true;
        }
        if height > self.remaining_height(container_id) {
            return false;
        }
        let idx = self.container_index(container_id);
        self.containers[idx].consumed_height += height;
        true
    }

    pub fn place_artefact(
        &mut self,
        _container_id: ContainerId,
        _artefact: super::artefact::Artefact,
    ) {
        // Artefact placement - future implementation
    }

    pub fn is_hot(&self) -> bool {
        self.is_hot
    }

    pub fn clear(&mut self) {
        for container in &mut self.containers {
            container.lines.clear();
            container.consumed_height = 0.0;
            container.line_breaker_cursor = 0;
            container.line_index = 0;
        }
        self.sources.clear();
        self.callers.clear();
        self.is_hot = false;
    }

    pub fn state_mut(&mut self) -> &mut TemplateState {
        &mut self.state
    }

    pub fn state(&self) -> &TemplateState {
        &self.state
    }

    pub fn mark_hot(&mut self) {
        self.is_hot = true;
    }

    pub fn into_filled(self) -> (Vec<FilledContainer>, TemplateState, Vec<ContentSource>) {
        let filled = self
            .containers
            .into_iter()
            .map(|c| FilledContainer {
                spec: c.spec,
                lines: c.lines,
                consumed_height: c.consumed_height,
            })
            .collect();
        (filled, self.state, self.sources)
    }

    pub fn drain_overflow(&mut self) -> Vec<Overflow> {
        Vec::new()
    }
}

use super::container::{ContainerId, FilledContainer, PlacedLine};
use super::fragment::{TextFragment, extract_fragments};
use super::paragraph::Alignment;
use super::template::ContentSource;
use super::{Index, Indices};

#[derive(Debug, Clone)]
pub struct ScaffoldLine {
    pub top: f32,
    pub left: f32,
    pub width: f32,
    pub placed: PlacedLine,
}

#[derive(Debug, Clone)]
pub struct ScaffoldContainer {
    pub id: ContainerId,
    pub alignment: Alignment,
    pub lines: Vec<ScaffoldLine>,
}

#[derive(Debug, Clone)]
pub struct Scaffold {
    pub column_x: f32,
    pub column_y: f32,
    pub column_width: f32,
    pub column_height: f32,
    pub containers: Vec<ScaffoldContainer>,
}

impl Scaffold {
    pub fn from_filled(
        column_x: f32,
        column_y: f32,
        column_width: f32,
        column_height: f32,
        filled: Vec<FilledContainer>,
        _sources: &[ContentSource],
    ) -> Self {
        let containers = filled
            .into_iter()
            .map(|fc| {
                let lines = fc
                    .lines
                    .into_iter()
                    .map(|pl| {
                        ScaffoldLine {
                            top: column_y + pl.y,
                            left: column_x + pl.x,
                            width: pl.width,
                            placed: pl,
                        }
                    })
                    .collect();
                ScaffoldContainer {
                    id: fc.spec.id,
                    alignment: fc.spec.alignment,
                    lines,
                }
            })
            .collect();

        Scaffold {
            column_x,
            column_y,
            column_width,
            column_height,
            containers,
        }
    }

    pub fn to_fragments(
        &self,
        sources: &[ContentSource],
        callers: &[(usize, usize, String)], // (item_idx, source_id, caller_letter)
    ) -> Vec<TextFragment> {
        let mut all_fragments = Vec::new();

        for container in &self.containers {
            let num_lines = container.lines.len();

            for (line_idx, scaffold_line) in container.lines.iter().enumerate() {
                let source = &sources[scaffold_line.placed.source_id];
                let is_last_line = line_idx == num_lines - 1;
                let line_height =
                    scaffold_line.placed.line.item_range.clone().next().map_or(0.0, |_| {
                        // We need the actual line height from the source style.
                        // Since we don't have the renderer here, we rely on the
                        // y-difference between consecutive lines or the placed data.
                        // For now, we calculate from top differences or use a stored value.
                        0.0 // Will be filled by caller
                    });

                // Build caller pairs for this line and source
                let line_callers: Vec<(usize, String)> = callers
                    .iter()
                    .filter(|(item_idx, src_id, _)| {
                        *src_id == scaffold_line.placed.source_id
                            && scaffold_line.placed.line.item_range.contains(item_idx)
                    })
                    .map(|(item_idx, _, letter)| (*item_idx, letter.clone()))
                    .collect();

                let fragments = extract_fragments(
                    &source.items,
                    &source.text,
                    &scaffold_line.placed.line,
                    scaffold_line.top,
                    line_height,
                    scaffold_line.left,
                    scaffold_line.width,
                    is_last_line,
                    &container.alignment,
                    &line_callers,
                );

                all_fragments.extend(fragments);
            }
        }

        all_fragments
    }

    pub fn to_fragments_with_heights(
        &self,
        sources: &[ContentSource],
        callers: &[(usize, usize, String)],
        renderer: &crate::painter::renderer::Renderer,
    ) -> Vec<TextFragment> {
        let mut all_fragments = Vec::new();

        for container in &self.containers {
            let num_lines = container.lines.len();

            for (line_idx, scaffold_line) in container.lines.iter().enumerate() {
                let source = &sources[scaffold_line.placed.source_id];
                let is_last_line = line_idx == num_lines - 1;
                let line_height = renderer.line_height(&source.style);

                let line_callers: Vec<(usize, String)> = callers
                    .iter()
                    .filter(|(item_idx, src_id, _)| {
                        *src_id == scaffold_line.placed.source_id
                            && scaffold_line.placed.line.item_range.contains(item_idx)
                    })
                    .map(|(item_idx, _, letter)| (*item_idx, letter.clone()))
                    .collect();

                let fragments = extract_fragments(
                    &source.items,
                    &source.text,
                    &scaffold_line.placed.line,
                    scaffold_line.top,
                    line_height,
                    scaffold_line.left,
                    scaffold_line.width,
                    is_last_line,
                    &container.alignment,
                    &line_callers,
                );

                all_fragments.extend(fragments);
            }
        }

        all_fragments
    }

    pub fn record_indices(
        &self,
        sources: &[ContentSource],
        index_registry: &[Index],
        page_index: usize,
        indices: &mut Indices,
    ) {
        for container in &self.containers {
            for scaffold_line in &container.lines {
                let source = &sources[scaffold_line.placed.source_id];
                for item_idx in scaffold_line.placed.line.item_range.clone() {
                    if let Some(index_id) = source.items[item_idx].index_id {
                        if index_id < index_registry.len() {
                            indices.insert(index_registry[index_id].clone(), page_index);
                        }
                    }
                }
            }
        }
    }
}

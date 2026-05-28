use std::collections::HashMap;
use std::ops;

use crate::painter::{Dimensions, Rectangle, Style};
use crate::painter::renderer::{Renderer, shape};

use super::column::PageSpec;
use super::container::{ContainerId, ContainerSpec, StackDirection};
use super::fragment::TextFragment;
use super::inline::{InlineItem, ItemKind};
use super::paragraph::{Alignment, CollectedParagraph, FootnoteSpec, ParagraphSpec};
use super::scaffold::Scaffold;
use super::template::Template;
use super::{Index, Indices, Page};

pub struct LayoutOutput {
    pub pages: Vec<Page>,
    pub indices: Indices,
    #[allow(dead_code)]
    pub verses: Vec<Index>,
}

pub fn layout_book(
    renderer: &Renderer,
    dim: &Dimensions,
    collected: &[CollectedParagraph],
    index_registry: &[Index],
) -> LayoutOutput {
    let mut pages: Vec<Page> = Vec::new();
    let mut indices: Indices = HashMap::new();
    let mut page_index: usize = 0;

    // Track which paragraphs are on the current page (for hot re-evaluation)
    let mut page_paragraph_indices: Vec<usize> = Vec::new();
    // Drop cap fragments generated during paragraph processing
    let mut drop_cap_fragments: Vec<TextFragment> = Vec::new();

    // Paragraph cursor
    let mut para_idx = 0;

    while para_idx < collected.len() {
        // =============================================
        // BEGIN PAGE — create a fresh Template
        // =============================================
        let mut template = Template::new(dim.width, dim.height);

        let body_spec = ContainerSpec::new(
            ContainerId(0),
            Alignment::Justified,
            Style::Normal,
        );
        let footer_spec = ContainerSpec::new(
            ContainerId(1),
            Alignment::Left,
            Style::Footnote,
        );

        let body_id = template.add_container(body_spec, StackDirection::TopDown);
        let footer_id = template.add_container(footer_spec, StackDirection::BottomUp);

        page_paragraph_indices.clear();
        drop_cap_fragments.clear();

        // =============================================
        // PARAGRAPH LOOP
        // =============================================
        while para_idx < collected.len() {
            let overflow = process_paragraph(
                &mut template,
                body_id,
                footer_id,
                &collected[para_idx],
                renderer,
                dim,
                &mut drop_cap_fragments,
            );

            page_paragraph_indices.push(para_idx);

            if let Some(_overflow) = overflow {
                // Page is full — finalize current page then start new page
                // with the same paragraph continuing
                break;
            }

            para_idx += 1;
        }

        // =============================================
        // HOT CHECK — if callers were re-assigned, re-evaluate
        // =============================================
        if template.is_hot() {
            refill_hot_template(
                &mut template,
                body_id,
                footer_id,
                &page_paragraph_indices,
                collected,
                renderer,
                dim,
            );
        }

        // =============================================
        // FINALIZE PAGE — Template → Scaffold → Page
        // =============================================
        let callers: Vec<(usize, usize, String)> = template.callers().to_vec();
        let (filled_containers, _state, sources) = template.into_filled();

        // Record indices from drop cap items tracked separately
        // (drop cap items are registered as sources too)

        let scaffold = Scaffold::from_filled(
            0.0, 0.0,
            dim.width, dim.height,
            filled_containers,
            &sources,
        );

        scaffold.record_indices(&sources, index_registry, page_index, &mut indices);

        let mut page_fragments: Vec<TextFragment> = drop_cap_fragments.drain(..).collect();
        page_fragments.extend(
            scaffold.to_fragments_with_heights(&sources, &callers, renderer),
        );

        if !page_fragments.is_empty() || !pages.is_empty() {
            pages.push(page_fragments);
            page_index += 1;
        }

        // If we didn't advance (paragraph overflowed), advance past it
        // to prevent infinite loop — the overflow items have been placed
        // on the next page iteration
        if para_idx < collected.len()
            && page_paragraph_indices.last() == Some(&para_idx)
        {
            para_idx += 1;
        }
    }

    let verses: Vec<Index> = indices
        .keys()
        .filter(|idx| idx.verse.is_some())
        .cloned()
        .collect();

    LayoutOutput {
        pages,
        indices,
        verses,
    }
}

fn process_paragraph(
    template: &mut Template,
    body_id: ContainerId,
    footer_id: ContainerId,
    collected: &CollectedParagraph,
    renderer: &Renderer,
    _dim: &Dimensions,
    drop_cap_fragments: &mut Vec<TextFragment>,
) -> Option<super::template::Overflow> {
    let spec = &collected.body;

    // Spacing before
    if spec.spacing_before > 0.0 {
        if !template.alloc_spacing(body_id, spec.spacing_before) {
            // Not enough space — page break needed
            return Some(super::template::Overflow {
                container_id: body_id,
                source_id: 0,
                item_cursor: 0,
                remaining_items: Vec::new(),
                remaining_text: String::new(),
                continuation_style: Style::Normal,
                indent: spec.indent,
                drop_cap: spec.drop_cap.clone(),
                drop_cap_width: 0.0,
            });
        }
    }

    // Shape the body paragraph
    let all_items = shape(renderer, spec);

    // Handle drop cap: find byte length of drop cap text
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

    let body_items: Vec<InlineItem> = all_items[body_item_start..].to_vec();

    // Measure drop cap width if present
    let dc_width = if spec.drop_cap.is_some() {
        let dc_range = spec
            .styles
            .iter()
            .find(|(_, s)| *s == Style::Chapter)
            .map(|(r, _)| r.clone());
        if let Some(range) = dc_range {
            measure_drop_cap_width(renderer, &spec.text[range])
        } else {
            0.0
        }
    } else {
        0.0
    };

    // Register drop cap items as a separate source if present, and create
    // a drop cap fragment for direct rendering.
    if let Some(ref dc) = spec.drop_cap {
        if body_item_start > 0 {
            // Register drop cap items so their indices are tracked
            let dc_items: Vec<InlineItem> = all_items[..body_item_start].to_vec();
            template.register_source(spec.text.clone(), dc_items, Style::Chapter);

            // Create the drop cap fragment. Its top position is the body's
            // current consumed height (i.e. where the first body line will go).
            let dc_range = spec
                .styles
                .iter()
                .find(|(_, s)| *s == Style::Chapter)
                .map(|(r, _)| r.clone());
            if let Some(range) = dc_range {
                let dc_text = spec.text[range].to_string();
                let body_line_height = renderer.line_height(&Style::Normal);
                let dc_line_height = body_line_height * dc.line_span as f32;

                // body consumed height = column_height - remaining_height(body) - footer consumed
                // But since body is TopDown, consumed_height IS the y position.
                // We can compute it: body_consumed = column_height - remaining - other_consumed
                // Simpler approach: the body's top offset is spacing_before at this point
                // since we just allocated spacing_before and nothing else for this paragraph.
                // But other paragraphs may have already consumed height.
                // The remaining_height tells us what's left, so:
                // body_consumed = column_height - remaining_height(body) - footer_consumed
                // For a TopDown container, the next line y = consumed_height of that container.
                // We don't have a direct accessor, but we know:
                //   remaining_height(body) = column_height - other_consumed - body_consumed
                // For the first page with just spacing_before, body_consumed = spacing_before.
                // But in general, we need the actual consumed height.

                // Use a trick: alloc_spacing for 0 height to read the position.
                // Or better: just compute from remaining heights.
                // body_consumed = column_height - remaining_height(body_id) - footer_consumed
                // footer_consumed = column_height - remaining_height(footer_id) - body_consumed
                // These are circular. But: total_consumed = body_consumed + footer_consumed
                // remaining_height(body) = column_height - footer_consumed - body_consumed
                //                        = column_height - total_consumed
                // So body_consumed = column_height - remaining_column_height - footer_consumed
                // ... this is getting circular.
                //
                // The simplest approach: the template knows each container's consumed height.
                // Let's just expose it.

                // For now, use: top = column_height - remaining_height(body_id) - (column_height - remaining_column_height - (column_height - remaining_height(body_id)))
                // That simplifies to remaining_column_height is column_height - total_consumed
                // body_consumed = (column_height - remaining_height(body_id)) - (column_height - remaining_column_height - body_consumed)
                // This is still circular.
                //
                // Let me just add a method to Template that returns consumed height.
                // But to avoid adding API just for this, notice that for TopDown containers,
                // the y position of the next line equals the consumed_height. Since we're
                // about to call alloc_all which will place lines, and those lines will have
                // y = consumed_height at placement time, the first line's y will be exactly
                // where the drop cap should start.
                //
                // So: the drop cap top = first body line's y in the template.
                // We can defer the drop cap fragment creation to AFTER alloc_all and read
                // the first line's y position. But that's also complex.
                //
                // Simplest reliable approach: expose body_consumed_height from template.

                let dc_top = template.consumed_height(body_id);

                drop_cap_fragments.push(TextFragment::new(
                    dc_text,
                    Rectangle {
                        top: dc_top,
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

    // Register body source
    template.set_source_layout(spec.indent, spec.drop_cap.clone(), dc_width);
    let body_src_id = template.register_source(
        spec.text.clone(),
        body_items,
        Style::Normal,
    );

    // Allocate body lines
    let overflow = template.alloc_all(body_id, body_src_id, renderer);

    // Process footnotes for callers found during body allocation
    let callers_snapshot: Vec<(usize, usize, String)> = template.callers().to_vec();
    for (item_idx, src_id, caller_letter) in &callers_snapshot {
        if *src_id != body_src_id {
            continue;
        }
        let source = &template.sources()[*src_id];
        if let ItemKind::Caller { footnote_id } = source.items[*item_idx].kind {
            if footnote_id < collected.footnotes.len() {
                let (fn_spec, fn_items) = shape_footnote_with_caller(
                    renderer,
                    &collected.footnotes[footnote_id],
                    caller_letter,
                );

                template.set_source_layout((0.0, 0.0), None, 0.0);
                let fn_src_id = template.register_source(
                    fn_spec.text,
                    fn_items,
                    Style::Footnote,
                );

                template.alloc_all(footer_id, fn_src_id, renderer);
            }
        }
    }

    // Spacing after
    if spec.spacing_after > 0.0 {
        template.alloc_spacing(body_id, spec.spacing_after);
    }

    overflow
}

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
        let items = shape(renderer, orig);
        return (orig.clone(), items);
    };

    let old_len = cr.end - cr.start;
    let new_len = caller_letter.len();
    let delta = new_len as isize - old_len as isize;

    let mut new_text = String::with_capacity(orig.text.len().wrapping_add_signed(delta));
    new_text.push_str(&orig.text[..cr.start]);
    new_text.push_str(caller_letter);
    new_text.push_str(&orig.text[cr.end..]);

    let new_styles: Vec<(ops::Range<usize>, Style)> = orig
        .styles
        .iter()
        .map(|(r, s)| {
            if r.start == cr.start {
                (cr.start..cr.start + new_len, *s)
            } else if r.start >= cr.end {
                let start = (r.start as isize + delta) as usize;
                let end = (r.end as isize + delta) as usize;
                (start..end, *s)
            } else {
                (r.clone(), *s)
            }
        })
        .collect();

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

fn refill_hot_template(
    template: &mut Template,
    body_id: ContainerId,
    footer_id: ContainerId,
    page_paragraph_indices: &[usize],
    collected: &[CollectedParagraph],
    renderer: &Renderer,
    _dim: &Dimensions,
) {
    template.clear();
    template.state_mut().reset_callers();

    for &para_idx in page_paragraph_indices {
        let para = &collected[para_idx];
        let spec = &para.body;

        // Spacing before
        if spec.spacing_before > 0.0 {
            template.alloc_spacing(body_id, spec.spacing_before);
        }

        // Re-shape body with correct caller letters
        let all_items = shape(renderer, spec);

        let dc_text_len = if spec.drop_cap.is_some() {
            spec.styles
                .iter()
                .find(|(_, s)| *s == Style::Chapter)
                .map(|(r, _)| r.end)
                .unwrap_or(0)
        } else {
            0
        };

        let body_item_start = all_items
            .iter()
            .position(|item| item.range.start >= dc_text_len)
            .unwrap_or(all_items.len());

        let body_items: Vec<InlineItem> = all_items[body_item_start..].to_vec();

        let dc_width = if spec.drop_cap.is_some() {
            let dc_range = spec
                .styles
                .iter()
                .find(|(_, s)| *s == Style::Chapter)
                .map(|(r, _)| r.clone());
            if let Some(range) = dc_range {
                measure_drop_cap_width(renderer, &spec.text[range])
            } else {
                0.0
            }
        } else {
            0.0
        };

        // Register drop cap source if present
        if spec.drop_cap.is_some() && body_item_start > 0 {
            let dc_items: Vec<InlineItem> = all_items[..body_item_start].to_vec();
            template.register_source(spec.text.clone(), dc_items, Style::Chapter);
        }

        template.set_source_layout(spec.indent, spec.drop_cap.clone(), dc_width);
        let body_src_id = template.register_source(
            spec.text.clone(),
            body_items,
            Style::Normal,
        );

        template.alloc_all(body_id, body_src_id, renderer);

        // Process footnotes
        let callers_snapshot: Vec<(usize, usize, String)> = template.callers().to_vec();
        for (item_idx, src_id, caller_letter) in &callers_snapshot {
            if *src_id != body_src_id {
                continue;
            }
            let source = &template.sources()[*src_id];
            if let ItemKind::Caller { footnote_id } = source.items[*item_idx].kind {
                if footnote_id < para.footnotes.len() {
                    let (fn_spec, fn_items) = shape_footnote_with_caller(
                        renderer,
                        &para.footnotes[footnote_id],
                        caller_letter,
                    );

                    template.set_source_layout((0.0, 0.0), None, 0.0);
                    let fn_src_id = template.register_source(
                        fn_spec.text,
                        fn_items,
                        Style::Footnote,
                    );

                    template.alloc_all(footer_id, fn_src_id, renderer);
                }
            }
        }

        // Spacing after
        if spec.spacing_after > 0.0 {
            template.alloc_spacing(body_id, spec.spacing_after);
        }
    }
}

fn measure_drop_cap_width(renderer: &Renderer, dc_text: &str) -> f32 {
    use skia_safe::textlayout::{RectHeightStyle, RectWidthStyle};

    let mut builder = renderer.new_builder();
    builder
        .push_style(&renderer.get_style(&Style::Chapter))
        .add_text(dc_text);
    let mut paragraph = builder.build();
    paragraph.layout(f32::INFINITY);
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
}

#[allow(dead_code)]
fn default_page_spec(dim: &Dimensions) -> PageSpec {
    PageSpec::single_column(dim.width, dim.height)
}

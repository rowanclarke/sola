use super::inline::{BrokenLine, InlineItem, ItemKind};

pub type WidthFn<'a> = Box<dyn Fn(usize) -> (f32, f32) + 'a>;

pub struct LineBreaker<'a> {
    items: &'a [InlineItem],
    cursor: usize,
    line_index: usize,
    width_fn: WidthFn<'a>,
}

impl<'a> LineBreaker<'a> {
    pub fn new(items: &'a [InlineItem], width_fn: WidthFn<'a>) -> Self {
        Self {
            items,
            cursor: 0,
            line_index: 0,
            width_fn,
        }
    }

    pub fn cursor(&self) -> usize {
        self.cursor
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
                ItemKind::Word => {
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

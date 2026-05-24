use usfm::ArchivedPoetry;

use crate::painter::{Style, layout::Section};

use super::Paint;

impl Paint for ArchivedPoetry {
    fn paint(&self, painter: &mut crate::painter::Painter) {
        use usfm::ArchivedParagraphContents as Content;
        use usfm::ArchivedPoetryStyle as PoetryKind;
        painter.push_properties(Style::Normal, Section::Body);
        for content in self.contents.iter() {
            match content {
                Content::Verse(verse_num) => {
                    painter
                        .add_text(" ")
                        .push_properties(Style::Verse, Section::Body)
                        .index_verse(verse_num.to_native())
                        .add_text(verse_num.to_string())
                        .pop_properties();
                }
                Content::Line(text) => {
                    painter.add_text(text);
                }
                Content::Character(character) => character.paint(painter),
                _ => (),
            }
        }
        match self.style {
            PoetryKind::Normal(indent_level) => {
                painter.pop_properties();
                painter.paint_paragraph_with_indent(
                    20.0 * indent_level as f32,
                    20.0 * 2.0,
                );
            }
            _ => painter.clean(),
        }
    }
}

use usfm::ArchivedPoetry;

use crate::painter::{Style, layout::Section, paint::verse::Verse};

use super::Paint;

impl Paint for ArchivedPoetry {
    fn paint(&self, painter: &mut crate::painter::Painter) {
        use usfm::ArchivedParagraphContents as Content;
        use usfm::ArchivedPoetryStyle as PoetryKind;
        painter.set_container(Section::Body);
        painter.push_properties(Style::Normal, Section::Body);
        for content in self.contents.iter() {
            match content {
                Content::Verse(verse) => {
                    Verse(verse).paint(painter);
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
                painter.paint_paragraph_with_indent(20.0 * indent_level as f32, 20.0 * 3.0);
            }
            _ => painter.clean(),
        }
    }
}

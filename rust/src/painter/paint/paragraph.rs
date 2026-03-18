use usfm::ArchivedParagraph;

use crate::painter::{Painter, Style, format::Format, writer::LineFormat};

use super::Paint;

impl Paint for ArchivedParagraph {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedParagraphContents as Content;
        painter.push_style(Style::Normal);
        for content in self.contents.iter() {
            match content {
                Content::Verse(verse_num) => {
                    painter
                        .add_text(" ")
                        .push_style(Style::Verse)
                        .index_verse(verse_num.to_native())
                        .add_text(verse_num.to_string())
                        .pop_style();
                }
                Content::Line(text) => { painter.add_text(text); }
                Content::Character(character) => character.paint(painter),
                _ => (),
            }
        }
        painter
            .pop_style()
            .paint_paragraph(Format::Justified, LineFormat::new(20.0, 0.0, 0.0));
    }
}

use usfm::ArchivedParagraph;

use crate::painter::{Painter, Style, format::Format, layout::Section, writer::LineFormat};

use super::Paint;

impl Paint for ArchivedParagraph {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedParagraphContents as Content;
        painter.push_properties(Style::Normal, Section::Body);
        for content in self.contents.iter() {
            match content {
                Content::Verse(verse_num) => {
                    painter
                        .add_text(" ")
                        .push_properties(Style::Verse, Section::Body)
                        // .index_verse(verse_num.to_native())
                        .add_text(verse_num.to_string())
                        .pop_properties();
                }
                Content::Line(text) => {
                    painter.add_text(text);
                }
                Content::Character(character) => character.paint(painter),
                Content::Footnote(footnote) => footnote.paint(painter),
                Content::CrossRef(cross_ref) => cross_ref.paint(painter),
                _ => (),
            }
        }
        painter
            .pop_properties()
            .paint_paragraph(Format::Justified, LineFormat::new(20.0, 0.0, 0.0));
    }
}

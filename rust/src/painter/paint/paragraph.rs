use usfm::ArchivedParagraph;

use crate::painter::{Painter, Style, layout::Section, paint::verse::Verse};

use super::Paint;

impl Paint for ArchivedParagraph {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedParagraphContents as Content;
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
                Content::Footnote(footnote) => footnote.paint(painter),
                Content::CrossRef(cross_ref) => cross_ref.paint(painter),
                _ => (),
            }
        }
        painter.pop_properties();
        painter.paint_paragraph();
    }
}

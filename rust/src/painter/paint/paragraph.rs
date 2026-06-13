use usfm::ArchivedParagraph;

use crate::painter::{Painter, Style, layout::Section};

use super::Paint;

impl Paint for ArchivedParagraph {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedParagraphContents as Content;
        painter.set_container(Section::Body);
        painter.push_properties(Style::Normal, Section::Body);
        for content in self.contents.iter() {
            match content {
                Content::Verse(verse_num) => {
                    let v = verse_num.to_native();
                    if v > 1 {
                        painter
                            .add_text(" ")
                            .push_properties(Style::Verse, Section::Body)
                            .index_verse(v)
                            .add_text(v.to_string())
                            .pop_properties();
                    } else {
                        painter.index_verse(v);
                    }
                }
                Content::Line(text) => {
                    painter.add_text(text);
                }
                Content::Character(character) => character.paint(painter),
                Content::Footnote(footnote) => footnote.paint(painter),
                Content::CrossRef(cross_ref) => cross_ref.paint(painter),
            }
        }
        painter.pop_properties();
        painter.paint_paragraph();
    }
}

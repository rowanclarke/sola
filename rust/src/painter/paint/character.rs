use usfm::ArchivedCharacter;

use crate::painter::{Painter, Style};
use crate::painter::layout::Section;

use super::Paint;

impl Paint for ArchivedCharacter {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedCharacterContents as Content;
        use usfm::ArchivedCharacterType;

        let is_word = matches!(self.ty, ArchivedCharacterType::Word);
        if is_word {
            painter.push_properties(Style::Word, Section::Body);
        }

        for content in self.contents.iter() {
            match content {
                Content::Line(text) => {
                    painter.add_text(text);
                }
                Content::Character(character) => character.paint(painter),
            }
        }

        if is_word {
            painter.pop_properties();
        }
    }
}

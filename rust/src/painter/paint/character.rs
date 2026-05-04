use usfm::ArchivedCharacter;

use crate::painter::Painter;

use super::Paint;

impl Paint for ArchivedCharacter {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedCharacterContents as Content;
        for content in self.contents.iter() {
            match content {
                Content::Line(text) => { painter.add_text(text); }
                Content::Character(character) => character.paint(painter),
            }
        }
    }
}

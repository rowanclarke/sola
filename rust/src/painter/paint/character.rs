use usfm::{ArchivedCharacter, Character};

use crate::painter::Painter;

use super::Paint;

impl Paint for ArchivedCharacter {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedCharacterContents as C;
        for contents in self.contents.iter() {
            match contents {
                C::Line(s) => painter.add_text(s).done(),
                C::Character(character) => character.paint(painter),
            }
        }
    }
}

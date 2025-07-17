use usfm::Character;

use crate::painter::Painter;

use super::Paint;

impl Paint for Character {
    fn paint(&self, painter: &mut Painter) {
        use usfm::CharacterContents as C;
        for contents in &self.contents {
            match contents {
                C::Line(s) => painter.add_text(s).done(),
                C::Character(character) => character.paint(painter),
            }
        }
    }
}

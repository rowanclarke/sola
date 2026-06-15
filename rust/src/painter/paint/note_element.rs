use core::{fmt::Debug, hash::Hash};
use rkyv::Archive;
use usfm::ArchivedNoteElement;

use crate::painter::Painter;

use super::Paint;

impl<NoteStyle: Archive> Paint for ArchivedNoteElement<NoteStyle>
where
    <NoteStyle as Archive>::Archived: Debug + Eq + Hash,
{
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedCharacterContents as Content;
        for content in self.contents.iter() {
            match content {
                Content::Line(text) => {
                    painter.add_text(text);
                }
                Content::Character(character) => character.paint(painter),
            }
        }
    }
}

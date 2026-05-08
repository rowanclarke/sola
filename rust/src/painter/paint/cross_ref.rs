use usfm::ArchivedCrossRef;

use crate::painter::Painter;

use super::Paint;

impl Paint for ArchivedCrossRef {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedCrossRefElement as Element;
        for content in self.elements.iter() {
            match content {
                Element::Reference(note_ref) => {
                    painter.add_text(format!("{}: ", note_ref.verse));
                }
                Element::Element(note_element) => note_element.paint(painter),
            }
        }
    }
}

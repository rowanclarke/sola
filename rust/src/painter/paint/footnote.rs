use usfm::ArchivedFootnote;

use crate::painter::{Painter, Style, layout::Section};

use super::Paint;

impl Paint for ArchivedFootnote {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedFootnoteElement as Element;
        painter.push_properties(Style::Normal, Section::Footer);
        for element in self.elements.iter() {
            match element {
                Element::Reference(note_ref) => {
                    painter.add_text(format!("{}: ", note_ref.verse));
                }
                Element::Element(note_element) => note_element.paint(painter),
            }
        }
        painter.pop_properties();
    }
}

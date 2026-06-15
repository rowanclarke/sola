use usfm::ArchivedCrossRef;

use crate::painter::{Painter, Style, layout::Section};

use super::Paint;

impl Paint for ArchivedCrossRef {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedCrossRefElement as Element;

        // Cross references use the same group pattern as footnotes
        painter.begin_footnote();

        painter.push_properties(Style::CrossRef, Section::Footer);
        for content in self.elements.iter() {
            match content {
                Element::Reference(note_ref) => {
                    painter.add_text(format!("{}: ", note_ref.verse));
                }
                Element::Element(note_element) => note_element.paint(painter),
            }
        }
        painter.pop_properties();

        painter.end_footnote();
    }
}

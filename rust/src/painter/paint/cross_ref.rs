use usfm::ArchivedCrossRef;

use crate::painter::{Painter, Style, layout::Section};

use super::Paint;

impl Paint for ArchivedCrossRef {
    fn paint(&self, painter: &mut Painter) {
        // Cross references use the same group pattern as footnotes
        painter.begin_footnote();

        painter.push_properties(Style::CrossRef, Section::Footer);
        for element in self.elements.iter() {
            // element.paint(painter);
        }
        painter.pop_properties();

        painter.end_footnote();
    }
}

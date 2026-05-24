use usfm::{ArchivedCaller, ArchivedFootnote};

use crate::painter::{Painter, Style, layout::Section};

use super::Paint;

impl Paint for ArchivedFootnote {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedFootnoteElement as Element;

        // 1. Insert caller placeholder in BODY text
        let fn_id = painter.next_footnote_id();
        painter.insert_caller(fn_id);

        // 2. Collect footnote CONTENT as separate paragraph
        painter.begin_footnote(fn_id);

        painter.push_properties(Style::Caller, Section::Footer);
        match &self.caller {
            ArchivedCaller::Auto => painter.add_text("+"),
            ArchivedCaller::Some(s) => painter.add_text(s.to_string()),
            _ => painter,
        }
        .pop_properties();

        painter.push_properties(Style::Footnote, Section::Footer);
        for element in self.elements.iter() {
            match element {
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

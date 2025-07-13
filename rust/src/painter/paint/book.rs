use usfm::Book;

use crate::painter::{Painter, Style};

use super::Paint;

impl Paint for Book {
    fn paint(&self, painter: &mut Painter) {
        use usfm::BookContents as C;
        for contents in self.contents.iter().take(16) {
            match contents {
                C::Paragraph(paragraph) => paragraph.paint(painter),
                C::Poetry(poetry) => poetry.paint(painter),
                C::Element(element) => element.paint(painter),
                C::Chapter(n) => painter
                    .push_style(Style::Chapter)
                    .add_text(n.to_string())
                    .pop_style()
                    .paint_drop_cap(),
                _ => (),
            }
        }
    }
}

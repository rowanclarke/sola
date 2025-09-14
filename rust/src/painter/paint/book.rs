use usfm::ArchivedBook;

use crate::painter::{Painter, Style};

use super::Paint;

impl Paint for ArchivedBook {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedBookContents as C;
        for contents in self.contents.iter() {
            match contents {
                C::Id { code, .. } => painter.index_book(code).done(),
                C::Paragraph(paragraph) => paragraph.paint(painter),
                C::Poetry(poetry) => poetry.paint(painter),
                C::Element(element) => element.paint(painter),
                C::Chapter(n) => painter
                    .index_chapter(n.to_native())
                    .push_style(Style::Chapter)
                    .add_text(n.to_string())
                    .pop_style()
                    .paint_drop_cap(),
                _ => (),
            }
        }
    }
}

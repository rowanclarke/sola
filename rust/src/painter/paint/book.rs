use usfm::ArchivedBook;

use crate::painter::{Painter, Style};

use super::Paint;

impl Paint for ArchivedBook {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedBookContents as Content;
        for content in self.contents.iter() {
            match content {
                Content::Id { code, .. } => {
                    painter.index_book(code);
                }
                Content::Paragraph(paragraph) => paragraph.paint(painter),
                Content::Poetry(poetry) => poetry.paint(painter),
                Content::Element(element) => element.paint(painter),
                // Content::Chapter(n) => painter
                //     .push_style(Style::Chapter)
                //     .index_chapter(n.to_native())
                //     .add_text(n.to_string())
                //     .pop_style()
                //     .paint_drop_cap(),
                _ => (),
            }
        }
    }
}

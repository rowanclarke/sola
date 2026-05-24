use usfm::ArchivedBook;

use crate::painter::{DropCap, Painter, Style, layout::Section};

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
                Content::Chapter(n) => {
                    painter.set_pending_drop_cap(DropCap {
                        line_span: 2,
                        padding: painter.get_dimensions().drop_cap_padding,
                    });
                    painter.push_properties(Style::Chapter, Section::Body);
                    painter.index_chapter(n.to_native());
                    let chapter_text = n.to_string();
                    painter.set_pending_drop_cap_text(chapter_text, Style::Chapter);
                    painter.pop_properties();
                }
                _ => (),
            }
        }
    }
}

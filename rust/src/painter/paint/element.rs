use usfm::ArchivedElement;

use crate::painter::{Painter, Style};

use super::Paint;

impl Paint for ArchivedElement {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedElementContents as Content;
        use usfm::ArchivedElementType::*;
        let header_height = painter.get_dimensions().header_height;
        for content in self.contents.iter() {
            match (&self.ty, content) {
                // (Header, Content::Line(header)) => painter
                //     .push_style(Style::Header)
                //     .index_header(header)
                //     .add_text(header)
                //     .pop_style()
                //     .paint_region(Format::Center, header_height),
                _ => (),
            }
        }
    }
}

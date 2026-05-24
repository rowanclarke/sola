use usfm::ArchivedElement;

use crate::painter::{Painter, Style, layout::Section};

use super::Paint;

impl Paint for ArchivedElement {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedElementContents as Content;
        use usfm::ArchivedElementType;
        for content in self.contents.iter() {
            match (&self.ty, content) {
                (ArchivedElementType::Header, Content::Line(header)) => {
                    painter.push_properties(Style::Header, Section::Body);
                    painter.index_header(header);
                    painter.add_text(header);
                    painter.pop_properties();
                    painter.paint_heading();
                }
                _ => (),
            }
        }
    }
}

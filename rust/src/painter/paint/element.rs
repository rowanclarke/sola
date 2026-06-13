use usfm::ArchivedElement;

use crate::painter::Painter;

use super::Paint;

impl Paint for ArchivedElement {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedElementContents as Content;
        use usfm::ArchivedElementType;
        for content in self.contents.iter() {
            match (&self.ty, content) {
                (ArchivedElementType::Header, Content::Line(header)) => {
                    painter.index_header(header);
                    painter.paint_heading(header);
                }
                _ => (),
            }
        }
    }
}

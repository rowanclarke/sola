use usfm::ArchivedElement;

use crate::painter::{Painter, Style, format::Format};

use super::Paint;

impl Paint for ArchivedElement {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ArchivedElementContents as C;
        use usfm::ArchivedElementType::*;
        let header_height = painter.get_dimensions().header_height;
        for contents in self.contents.iter() {
            match (&self.ty, contents) {
                (Header, C::Line(s)) => painter
                    .push_style(Style::Header)
                    .add_text(s)
                    .pop_style()
                    .paint_region(Format::Center, header_height),
                _ => (),
            }
        }
    }
}

use usfm::Element;

use crate::painter::{Painter, Style, format::Format};

use super::Paint;

impl Paint for Element {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ElementContents as C;
        use usfm::ElementType::*;
        let header_height = painter.get_dimensions().header_height;
        for contents in &self.contents {
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

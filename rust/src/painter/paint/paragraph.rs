use usfm::Paragraph;

use crate::painter::{Painter, Style, format::Format, writer::LineFormat};

use super::Paint;

impl Paint for Paragraph {
    fn paint(&self, painter: &mut Painter) {
        use usfm::ParagraphContents as C;
        painter.push_style(Style::Normal);
        for contents in &self.contents {
            match contents {
                C::Verse(n) => painter
                    .index_verse(*n)
                    .add_text(" ")
                    .push_style(Style::Verse)
                    .add_text(n.to_string())
                    .pop_style()
                    .done(),
                C::Line(s) => painter.add_text(s).done(),
                C::Character(character) => character.paint(painter),
                _ => (),
            }
        }
        painter
            .pop_style()
            .paint_paragraph(Format::Justified, LineFormat::new(20.0, 0.0, 0.0));
    }
}

use usfm::{Poetry, PoetryStyle};

use crate::painter::{Style, format::Format, writer::LineFormat};

use super::Paint;

impl Paint for Poetry {
    fn paint(&self, painter: &mut crate::painter::Painter) {
        use usfm::ParagraphContents as C;
        painter.push_style(Style::Normal);
        for contents in &self.contents {
            match contents {
                C::Verse(n) => painter
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
        match self.style {
            PoetryStyle::Normal(n) => painter.pop_style().paint_paragraph(
                Format::Left,
                LineFormat::new(20. * n as f32, 20. * 2.0, 0.0),
            ),
            _ => painter.clean(),
        }
    }
}

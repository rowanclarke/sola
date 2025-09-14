use usfm::{ArchivedPoetry, Poetry, PoetryStyle};

use crate::painter::{Style, format::Format, writer::LineFormat};

use super::Paint;

impl Paint for ArchivedPoetry {
    fn paint(&self, painter: &mut crate::painter::Painter) {
        use usfm::ArchivedParagraphContents as C;
        use usfm::ArchivedPoetryStyle as S;
        painter.push_style(Style::Normal);
        for contents in self.contents.iter() {
            match contents {
                C::Verse(n) => painter
                    .add_text(" ")
                    .push_style(Style::Verse)
                    .index_verse(n.to_native())
                    .add_text(n.to_string())
                    .pop_style()
                    .done(),
                C::Line(s) => painter.add_text(s).done(),
                C::Character(character) => character.paint(painter),
                _ => (),
            }
        }
        match self.style {
            S::Normal(n) => painter.pop_style().paint_paragraph(
                Format::Left,
                LineFormat::new(20. * n as f32, 20. * 2.0, 0.0),
            ),
            _ => painter.clean(),
        }
    }
}

use usfm::ArchivedPoetry;

use crate::painter::{Style, format::Format, writer::LineFormat};

use super::Paint;

impl Paint for ArchivedPoetry {
    fn paint(&self, painter: &mut crate::painter::Painter) {
        use usfm::ArchivedParagraphContents as Content;
        use usfm::ArchivedPoetryStyle as PoetryKind;
        painter.push_style(Style::Normal);
        for content in self.contents.iter() {
            match content {
                Content::Verse(verse_num) => {
                    painter
                        .add_text(" ")
                        .push_style(Style::Verse)
                        .index_verse(verse_num.to_native())
                        .add_text(verse_num.to_string())
                        .pop_style();
                }
                Content::Line(text) => { painter.add_text(text); }
                Content::Character(character) => character.paint(painter),
                _ => (),
            }
        }
        match self.style {
            PoetryKind::Normal(indent_level) => painter.pop_style().paint_paragraph(
                Format::Left,
                LineFormat::new(20. * indent_level as f32, 20. * 2.0, 0.0),
            ),
            _ => painter.clean(),
        }
    }
}

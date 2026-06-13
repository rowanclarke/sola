use usfm::ArchivedBook;

use crate::painter::{Painter, Style};
use crate::painter::layout::Section;
use crate::painter::layout::artefact::{Artefact, ArtefactAnchor, ArtefactPadding};

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
                    let chapter_num = n.to_native();
                    painter.index_chapter(chapter_num);

                    let chapter_text = chapter_num.to_string();
                    let fragment = painter.raw(&chapter_text, Style::Chapter);
                    let padding = painter.get_dimensions().drop_cap_padding;

                    let artefact = Artefact::new(
                        ArtefactPadding {
                            top: 0.0,
                            bottom: 0.0,
                            left: 0.0,
                            right: padding,
                        },
                        fragment.rect.width,
                        fragment.rect.height,
                        ArtefactAnchor::Left,
                        true,
                        2,
                        vec![fragment],
                    );
                    painter.add_artefact(Section::Body, artefact);
                }
                _ => (),
            }
        }
    }
}

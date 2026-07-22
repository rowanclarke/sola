use rkyv::string::ArchivedString;

use crate::painter::{Paint, Style, layout::Section};

const SEPS: &[char] = &[
    '-', '\u{200F}', '\u{200E}', '\u{200B}', '\u{200C}', '\u{200D}', '\u{2068}', '\u{2069}',
    '\u{FEFF}', '\u{061C}',
];

pub struct Verse<'a>(pub &'a ArchivedString);

impl<'a> Paint for Verse<'a> {
    fn paint(&self, painter: &mut crate::painter::Painter) {
        let Verse(verse) = self;
        if let Some(n) = verse.parse().ok() {
            if n > 1 {
                painter
                    .add_text(" ")
                    .push_properties(Style::Verse, Section::Body)
                    .index_verse(n)
                    .add_text(n.to_string())
                    .pop_properties();
            } else {
                painter.index_verse(n);
            }
        } else if let Some(r) = verse
            .split_once(SEPS)
            .map(|(a, b): (&str, &str)| a.parse::<usize>().unwrap()..=b.parse::<usize>().unwrap())
        {
        }
    }
}

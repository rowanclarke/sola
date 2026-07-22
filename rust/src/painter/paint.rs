use super::Painter;

mod book;
mod character;
mod cross_ref;
mod element;
mod footnote;
mod footnote_element;
mod paragraph;
mod poetry;
mod verse;

pub trait Paint {
    fn paint(&self, painter: &mut Painter);
}

use super::Painter;

mod book;
mod character;
mod cross_ref;
mod element;
mod footnote;
mod note_element;
mod paragraph;
mod poetry;

pub trait Paint {
    fn paint(&self, painter: &mut Painter);
}

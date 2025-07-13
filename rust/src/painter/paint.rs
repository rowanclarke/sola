use super::Painter;

mod book;
mod character;
mod element;
mod paragraph;
mod poetry;

pub trait Paint {
    fn paint(&self, painter: &mut Painter);
}

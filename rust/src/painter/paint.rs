use super::Painter;

mod book;
mod character;
mod element;
mod paragraph;

pub trait Paint {
    fn paint(&self, painter: &mut Painter);
}

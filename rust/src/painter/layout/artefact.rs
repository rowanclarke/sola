use rkyv::{Archive, Deserialize, Serialize};

use crate::painter::Rectangle;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ArtefactAnchor {
    Left,
    Right,
}

#[derive(Debug, Clone, Copy)]
pub struct ArtefactPadding {
    pub top: f32,
    pub bottom: f32,
    pub left: f32,
    pub right: f32,
}

#[derive(Debug, Clone)]
pub struct Artefact {
    pub padding: ArtefactPadding,
    pub width: f32,
    pub height: f32,
    pub anchor: ArtefactAnchor,
    pub wrap: bool,
    pub line_span: usize,
}

impl Artefact {
    pub fn new(
        _padding: ArtefactPadding,
        _width: f32,
        _height: f32,
        _anchor: ArtefactAnchor,
        _wrap: bool,
    ) -> Self {
        todo!()
    }

    pub fn total_width(&self) -> f32 {
        todo!()
    }

    pub fn total_height(&self) -> f32 {
        todo!()
    }

    pub fn compute_line_span(&mut self, _line_height: f32) {
        todo!()
    }
}

#[derive(Archive, Serialize, Deserialize, Debug, Clone)]
pub struct ArtefactFragment {
    pub artefact_id: usize,
    pub rect: Rectangle,
}

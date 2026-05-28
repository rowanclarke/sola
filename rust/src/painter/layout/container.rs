use crate::painter::Style;

use super::artefact::Artefact;
use super::inline::BrokenLine;
use super::paragraph::Alignment;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct ContainerId(pub usize);

/// Text direction — determines last-line alignment for justified text.
/// Justified + Ltr = left-aligned last line. Justified + Rtl = right-aligned last line.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TextDirection {
    Ltr,
    Rtl,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StackDirection {
    TopDown,
    BottomUp,
}

#[derive(Debug, Clone)]
pub struct ContainerSpec {
    pub id: ContainerId,
    pub padding_top: f32,
    pub padding_bottom: f32,
    pub max_height: Option<f32>,
    pub alignment: Alignment,
    pub direction: TextDirection,
    pub line_style: Style,
    pub artefacts: Vec<Artefact>,
}

impl ContainerSpec {
    pub fn new(id: ContainerId, alignment: Alignment, line_style: Style) -> Self {
        Self {
            id,
            padding_top: 0.0,
            padding_bottom: 0.0,
            max_height: None,
            alignment,
            direction: TextDirection::Ltr,
            line_style,
            artefacts: Vec::new(),
        }
    }

    pub fn with_padding(mut self, top: f32, bottom: f32) -> Self {
        self.padding_top = top;
        self.padding_bottom = bottom;
        self
    }

    pub fn with_max_height(mut self, max_height: f32) -> Self {
        self.max_height = Some(max_height);
        self
    }

    pub fn with_artefact(mut self, artefact: Artefact) -> Self {
        self.artefacts.push(artefact);
        self
    }
}

#[derive(Debug, Clone)]
pub struct PlacedLine {
    pub line: BrokenLine,
    pub y: f32,
    pub x: f32,
    pub width: f32,
    pub source_id: usize,
}

#[derive(Debug, Clone)]
pub struct FilledContainer {
    pub spec: ContainerSpec,
    pub lines: Vec<PlacedLine>,
    pub consumed_height: f32,
}

use super::fragment::TextFragment;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[allow(dead_code)]
pub enum ArtefactAnchor {
    Left,
    Right,
}

#[derive(Debug, Clone, Copy)]
#[allow(dead_code)]
pub struct ArtefactPadding {
    pub top: f32,
    pub bottom: f32,
    pub left: f32,
    pub right: f32,
}

#[derive(Debug, Clone)]
#[allow(dead_code)]
pub struct Artefact {
    pub padding: ArtefactPadding,
    pub width: f32,
    pub height: f32,
    pub anchor: ArtefactAnchor,
    pub wrap: bool,
    pub line_span: usize,
    pub fragments: Vec<TextFragment>,
}

#[allow(dead_code)]
impl Artefact {
    pub fn new(
        padding: ArtefactPadding,
        width: f32,
        height: f32,
        anchor: ArtefactAnchor,
        wrap: bool,
        line_span: usize,
        fragments: Vec<TextFragment>,
    ) -> Self {
        Self {
            padding,
            width,
            height,
            anchor,
            wrap,
            line_span,
            fragments,
        }
    }

    pub fn total_width(&self) -> f32 {
        self.width + self.padding.left + self.padding.right
    }

    pub fn total_height(&self) -> f32 {
        self.height + self.padding.top + self.padding.bottom
    }

    /// Width reduction applied to lines within the artefact span.
    pub fn width_reduction(&self) -> f32 {
        self.total_width()
    }
}

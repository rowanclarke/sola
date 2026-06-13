use crate::painter::Style;

use super::Section;
use super::state::LayoutState;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StackDirection {
    TopDown,
    BottomUp,
}

/// What lives in the painter's buffer before paint_paragraph() processes it.
/// This is a cross-container flat stream.
pub enum BufferEntry {
    Segment { text: String, style: Style, section: Section },
    StateDep(Box<dyn Fn(&mut LayoutState) -> (String, Style)>, Section),
    BeginGrouped,
    EndGrouped,
    BeginExpanded,
    EndExpanded,
    IndexMarker(usize),
}

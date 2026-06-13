use crate::painter::Style;

use super::fragment::usize_to_letters;

pub struct LayoutState {
    pub caller_counter: usize,
}

impl LayoutState {
    pub fn new() -> Self {
        Self { caller_counter: 0 }
    }

    pub fn reset(&mut self) {
        self.caller_counter = 0;
    }

    /// Increment counter and return the letter + style for the new caller.
    pub fn get_next_caller(&mut self) -> (String, Style) {
        let letter = usize_to_letters(self.caller_counter);
        self.caller_counter += 1;
        (letter, Style::Caller)
    }

    /// Return the letter + style for the most recently assigned caller.
    pub fn get_current_caller(&mut self) -> (String, Style) {
        if self.caller_counter == 0 {
            return (String::new(), Style::Caller);
        }
        (usize_to_letters(self.caller_counter - 1), Style::Caller)
    }
}

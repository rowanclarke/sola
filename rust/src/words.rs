pub struct Words<'a> {
    s: &'a str,
}

impl<'a> Iterator for Words<'a> {
    type Item = &'a str;
    fn next(&mut self) -> Option<Self::Item> {
        if self.s.is_empty() {
            return None;
        }
        let s = match self.s.split(' ').next().unwrap() {
            "" => " ",
            w => w,
        };
        self.s = &self.s[s.len()..];
        Some(s)
    }
}

pub fn words<'a>(s: &'a str) -> Words<'a> {
    Words { s }
}

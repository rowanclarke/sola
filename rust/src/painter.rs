// mod format;
mod layout;
mod paint;
mod renderer;
// mod writer;

use std::{collections::VecDeque, ffi::c_char, mem, ops, slice::from_ref};

// use format::{Action, Format, get_unformatted, justify, left};
// use layout::Layout;
pub use layout::{ArchivedIndex, ArchivedIndices, ArchivedPages, Index};
pub use paint::Paint;
use renderer::{Inline, inline};
pub use renderer::{Renderer, TextStyle};
use rkyv::{
    Archive, Deserialize, Serialize, deserialize, rancor::Error, string::ArchivedString,
    util::AlignedVec,
};
use skia_safe::textlayout::{ParagraphBuilder, RectHeightStyle, RectWidthStyle};
use usfm::{ArchivedBookIdentifier, BookIdentifier};
// use writer::{LineFormat, Writer};

use crate::{log, painter::layout::Section};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Action {
    Index(Index),
}

pub struct Painter {
    renderer: Renderer,
    builder: ParagraphBuilder,
    dim: Dimensions,
    properties: Vec<(usize, Properties)>,
    queue: Vec<Properties>,
    callers: Vec<Caller>,
    layout: Layout,
    location: LocationState,
    pages: Vec<Page>,
}

#[derive(Default)]
struct LocationState {
    book: Option<BookIdentifier>,
    header: Option<String>,
    chapter: Option<u16>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Properties {
    style: Style,
    section: Section,
    actions: Vec<Action>,
}

pub struct Caller {
    text: String,
    width: f32,
}

#[derive(Debug, Clone)]
struct OwnedInline {
    text: String,
    style: Style,
    width: f32,
    whitespace: f32, // width of whitespace
}

#[derive(Debug, Clone)]
struct Line {
    alignment: Alignment,
    inlines: Vec<OwnedInline>,
    used: f32,
    total: f32,
}

#[derive(Debug, Clone)]
struct PageBuilder {
    current_body: usize,
    current_footer: usize,
    body: Vec<Line>,
    footer: Vec<Line>,
}

// #[derive(Debug, Clone)]
// struct Page {

//     // body: Vec<Line>,
//     // footer: Vec<Line>,
// }

type Page = Vec<TextFragment>;

#[derive(Archive, Serialize, Debug, Clone)]
pub struct TextFragment {
    pub text: String,
    pub rect: Rectangle,
    pub style: Style,
    pub word_spacing: f32,
}

pub enum Direction {
    RightToLeft,
    LeftToRight,
}

// per paragraph
struct Format {
    direction: Direction,
}

// per line
#[derive(Debug, Clone)]
enum Alignment {
    Left(f32),
    Right(f32),
    Center,
}

impl OwnedInline {
    fn new(inline: &Inline, text: &[char]) -> Self {
        Self {
            text: text[inline.range.clone()].iter().collect(),
            style: inline.properties.style,
            width: inline.width,
            whitespace: 0.0,
        }
    }

    fn push(&mut self, inline: &Inline, text: &[char]) {
        self.text.extend(&text[inline.range.clone()]);
        self.width += inline.width;
        if inline.is_whitespace {
            self.whitespace += inline.width;
        }
    }
}

// impl Page {
//     fn empty() -> Self {
//         Self {
//             body: vec![],
//             footer: vec![],
//         }
//     }

// }

impl PageBuilder {
    fn append_page(&mut self, page: &mut Page) {
        // self.body.append(&mut self.body);
        // if self.footer.last().unwrap().inlines.is_empty() {
        //     self.footer.pop();
        // }
        // self.footer.append(&mut self.footer);
    }

    // render the full page, cannot be partial page since footer needs to be complete to know where it is positioned
    fn render_page(
        self,
        format: &Format,
        template: Template,
        body_line_height: f32,
        footer_line_height: f32,
        mut top: f32,
    ) -> Vec<TextFragment> {
        let mut vec: Vec<TextFragment> = template.fixed;
        vec.iter_mut().for_each(|f| f.rect.top += top);
        top += template.top;
        for (LineTemplate { width, mut left }, line) in
            template.lines.into_iter().zip(self.body.into_iter())
        {
            let whitespace: f32 = line.inlines.iter().map(|i| i.whitespace).sum();
            let remaining = line.total - line.used;
            let ratio = remaining / whitespace;
            for inline in line.inlines {
                let spacing = ratio * inline.whitespace;
                let spaces = inline.text.chars().filter(|c| c.is_whitespace()).count() as f32;
                let word_spacing = if spaces == 0.0 { 0.0 } else { spacing / spaces };
                let height = body_line_height;
                let width = inline.width + spacing;
                vec.push(TextFragment {
                    text: inline.text,
                    rect: Rectangle {
                        top,
                        left,
                        width,
                        height,
                    },
                    style: inline.style,
                    word_spacing,
                });
                left += width;
            }
        }
        let top = height - footer_line_height * self.footer.len() as f32;
        vec
    }

    fn get_body_width(&self) -> (f32, f32) {
        let current = &self.body[self.current_body];
        (current.used, current.total)
    }

    fn get_footer_width(&self) -> (f32, f32) {
        let current = &self.footer[self.current_footer];
        (current.used, current.total)
    }

    fn get_current_body_mut(&mut self) -> &mut Line {
        &mut self.body[self.current_body]
    }

    fn get_current_footer_mut(&mut self) -> &mut Line {
        &mut self.footer[self.current_footer]
    }

    fn get_height(&self, body_line_height: f32, footer_line_height: f32) -> f32 {
        self.body.len() as f32 * body_line_height + self.footer.len() as f32 * footer_line_height
    }

    fn add_body(&mut self, inline: &Inline, text: &[char]) {
        let line = self.get_current_body_mut();
        match line.inlines.last_mut() {
            Some(current) if current.style == inline.properties.style => current.push(inline, text),
            Some(_) | None => line.inlines.push(OwnedInline::new(inline, text)),
        }
        line.used += inline.width;
    }

    fn add_footer(&mut self, inline: &Inline, text: &[char]) {
        let line = self.get_current_footer_mut();
        match line.inlines.last_mut() {
            Some(current) if current.style == inline.properties.style => current.push(inline, text),
            Some(_) | None => line.inlines.push(OwnedInline::new(inline, text)),
        }
        line.used += inline.width;
    }

    fn new_line_footer(&mut self, footer_width: f32) {
        self.footer.push(Line {
            alignment: Alignment::Left(0.0),
            inlines: vec![],
            used: 0.0,
            total: footer_width,
        });
        self.current_footer += 1;
    }

    fn try_add(&mut self, inline: &Inline, text: &[char]) -> bool {
        match inline.properties.section {
            Section::Body => {
                let (used, total) = self.get_body_width();
                if used + inline.width < total {
                    self.add_body(&inline, text);
                } else if self.current_body < self.body.len() - 1 {
                    self.current_body += 1;
                } else {
                    return true;
                }
            }
            Section::Footer => {
                let (used, total) = self.get_footer_width();
                if used + inline.width < total {
                    self.add_footer(&inline, text);
                } else {
                    self.new_line_footer(total);
                }
            }
        }
        false
    }
}

#[derive(Clone, Copy)]
struct LineTemplate {
    width: f32,
    left: f32,
}

#[derive(Clone)]
struct Template {
    lines: Vec<LineTemplate>,
    top: f32,                 // top of first line
    fixed: Vec<TextFragment>, // fixed graphics
    width: f32,
}

impl Template {
    fn new(width: f32) -> Self {
        Self {
            lines: vec![LineTemplate { width, left: 0.0 }],
            top: 0.0,
            fixed: vec![],
            width,
        }
    }

    fn push_fixed(&mut self, frag: TextFragment) {
        self.fixed.push(frag);
    }

    // push line before current line
    fn push_line(&mut self, width: f32, left: f32, shrink: f32) {
        self.lines.push(LineTemplate {
            width: width - left - shrink,
            left,
        });
    }

    fn get_page(&self) -> PageBuilder {
        PageBuilder {
            current_body: 0,
            current_footer: 0,
            body: self
                .lines
                .iter()
                .map(|t| Line {
                    alignment: Alignment::Left(0.0),
                    inlines: vec![],
                    used: 0.0,
                    total: t.width,
                })
                .collect(),
            footer: vec![Line {
                alignment: Alignment::Left(0.0),
                inlines: vec![],
                used: 0.0,
                total: self.width,
            }],
        }
    }
}

struct Layout {
    body_template: Template,
    body_line_height: f32,
    footer_line_height: f32,
    top: f32,
    width: f32,
    height: f32,
    available: f32,
    footnote: usize,
    cross_ref: usize,
}

impl Layout {
    fn get_template(&mut self) -> Template {
        mem::replace(&mut self.body_template, Template::new(self.width))
    }

    fn get_footer_width(&self) -> f32 {
        self.width
    }

    fn reset(&mut self) {
        self.top = 0.0;
        self.footnote = 0;
        self.cross_ref = 0;
        self.available = self.height;
    }
}

impl Painter {
    pub fn new(renderer: &Renderer, dim: Dimensions) -> Self {
        let body_line_height = renderer.line_height(&Style::Normal);
        let footer_line_height = renderer.line_height(&Style::Footnote);
        Self {
            renderer: renderer.clone(),
            builder: renderer.new_builder(),
            properties: Vec::new(),
            queue: Vec::new(),
            layout: Layout {
                body_template: Template::new(dim.width),
                body_line_height,
                footer_line_height,
                top: 0.0,
                width: dim.width,
                height: dim.height,
                available: dim.height,
                footnote: 0,
                cross_ref: 0,
            },
            location: LocationState::default(),
            callers: vec![],
            pages: vec![vec![]],
            dim,
        }
    }

    fn get_dimensions(&self) -> &Dimensions {
        &self.dim
    }

    // fn paint_region(&mut self, format: Format, height: f32) {
    //     let (_, text, inline) = inline(&self.renderer, &mut self.builder, &self.properties);
    //     // HACK assume line height is the first inline, instead get max height of each line
    //     let line_height = self.renderer.line_height(&inline[0].properties.style);
    //     let mut layout = self.layout.sub_layout(self.dim.width, height, line_height);
    //     let mut writer = Writer::new(
    //         &text[..],
    //         inline.as_slice(),
    //         LineFormat::default(),
    //         &mut layout,
    //     );
    //     writer.write().trim();
    //     let unformatted = get_unformatted(&text, &inline, writer.get_lines());
    //     let page = self.layout.request_height(height);
    //     self.layout.mutate_body(height);
    //     for action in self.properties.last_mut().unwrap().1.actions.iter() {
    //         // HACK better management of actions
    //         match action {
    //             Action::Index(index) => {
    //                 self.layout.add_index(index.clone(), page);
    //             }
    //         }
    //     }
    //     match format {
    //         Format::Center => {
    //             let total_height = unformatted.len() as f32 * line_height;
    //             let top_offset = (height - total_height) / 2.0;
    //             for line in unformatted {
    //                 let region = &layout.get_line_unchecked(line.line);
    //                 let rect = Rectangle {
    //                     top: region.top + top_offset,
    //                     left: region.left + line.metrics.remaining / 2.0,
    //                     width: line.width,
    //                     height: line_height,
    //                 };
    //                 self.layout.write(
    //                     page,
    //                     line.text.iter().collect::<String>(),
    //                     rect,
    //                     line.properties.style,
    //                     0.0,
    //                 );
    //             }
    //         }
    //         Format::Left => todo!(),
    //         _ => (),
    //     }
    //     self.clean();
    // }

    // fn paint_drop_cap(&mut self) {
    //     let (raw, _, inline) = inline(&self.renderer, &mut self.builder, &self.properties);
    //     let Inline {
    //         properties, width, ..
    //     } = &inline[0];
    //     let width = width + self.dim.drop_cap_padding;
    //     let height = 2.0 * self.layout.get_line_height();
    //     let page = self.layout.request_height(height);
    //     let rect = self.layout.from_body(width, height);
    //     self.layout.get_line(0).mutate(width, -width).lock();
    //     self.layout.get_line(1).mutate(width, -width).lock();
    //     self.layout
    //         .write(page, raw.to_string(), rect, properties.style, 0.0);
    //     for action in self.properties.last_mut().unwrap().1.actions.iter() {
    //         // HACK better management of actions
    //         match action {
    //             Action::Index(index) => {
    //                 self.layout.add_index(index.clone(), page);
    //             }
    //         }
    //     }
    //     self.properties.drain(..);
    //     self.builder.reset();
    // }

    fn paint_paragraph(&mut self) {
        let (_, text, mut inline) = inline(&self.renderer, &mut self.builder, &self.properties);

        // log!("{:?}", text);
        log!("{:#?}", inline);
        // log!("{} x {}", self.layout.width, self.layout.height);

        let mut i = 0;
        let mut template = Some(self.layout.get_template());
        loop {
            // get the next block of text we need to write to the same page
            let (block, j) = self.next_block(
                template.as_ref().unwrap().get_page(),
                &mut inline.as_mut_slice()[i..],
                &text,
            );
            // log!("{:?}", block);
            // is there enough room on the current page
            let height =
                block.get_height(self.layout.body_line_height, self.layout.footer_line_height);

            if height < self.layout.available {
                self.layout.available -= height;
                self.pages.last_mut().unwrap().extend(block.render_page(
                    &Format {
                        direction: Direction::LeftToRight,
                    },
                    template.take().unwrap(),
                    self.layout.body_line_height,
                    self.layout.footer_line_height,
                    self.layout.top,
                ));

                match j {
                    // wrote up to j, write the next block
                    Some(j) => {
                        i = j;
                        template = Some(self.layout.get_template());
                    }
                    // finished everything
                    None => break,
                }
            } else {
                self.layout.reset();
            }
        }

        log!("{:?}", self.pages.last().unwrap());

        // get ranges (over inline) of inlines in the next line of the current page
        //

        // TODO know where to write to

        // let mut writer = Writer::new(
        //     &text[..],
        //     inline.as_slice(),
        //     line_format,
        //     &mut self.layout,
        //     Section::Body,
        // );
        // writer.write().trim();

        // let lines = writer.get_lines();
        // let unformatted = get_unformatted(&text, &inline[&Section::Body], lines);

        // match format {
        //     Format::Justified => {
        //         let (tail, head) = unformatted.split_last().unwrap();
        //         justify(&mut self.layout, layout::Section::Body, head);
        //         left(&mut self.layout, layout::Section::Body, from_ref(tail));
        //     }
        //     Format::Left => {
        //         left(&mut self.layout, layout::Section::Body, &unformatted);
        //     }
        //     _ => (),
        // }

        // self.clean();
    }

    fn next_block(
        &mut self,
        mut page: PageBuilder,
        inline: &mut [Inline],
        text: &[char],
    ) -> (PageBuilder, Option<usize>) {
        let mut publish = page.clone();
        let mut reached = 0;
        for (i, inline) in inline
            .iter_mut()
            .enumerate()
            .skip_while(|(_, c)| c.is_whitespace)
        {
            if inline.is_whitespace {
                publish = page.clone();
                reached = i;
            }
            let new_block = if inline.properties.style == Style::Caller {
                let caller = self.get_caller(self.layout.footnote);
                let text = caller.text.chars().collect::<Vec<_>>();
                inline.range = 0..text.len();
                inline.width = caller.width;
                let mut caller = inline.clone();
                caller.properties.section = Section::Body;
                self.layout.footnote += 1;
                page.try_add(&caller, &text) || page.try_add(inline, &text)
            } else {
                page.try_add(inline, text)
            };
            if new_block {
                return (publish, Some(reached));
            }
        }
        (page, None) // we know everything has fitted in the line
    }

    fn get_caller(&mut self, i: usize) -> &Caller {
        get_or_insert_with(&mut self.callers, i, |i| {
            let mut builder = self.renderer.new_builder();
            let text = usize_to_letters(i);
            builder
                .push_style(&self.renderer.get_style(&Style::Caller))
                .add_text(&text);
            let mut paragraph = builder.build();
            paragraph.layout(f32::INFINITY);
            let width = paragraph.get_rects_for_range(
                0..text.len(),
                RectHeightStyle::Tight,
                RectWidthStyle::Tight,
            )[0]
            .rect
            .width();
            Caller { text, width }
        })
    }

    fn clean(&mut self) {
        self.properties.drain(..);
        // self.layout.drain_lines();
        self.builder.reset();
    }

    fn push_properties(&mut self, style: Style, section: Section) -> &mut Self {
        let properties = Properties {
            style,
            section,
            actions: vec![],
        };
        self.queue.push(properties.clone());
        self.builder.push_style(&self.renderer.get_style(&style));
        self.properties.push((self.text_cursor(), properties));
        self
    }

    fn pop_properties(&mut self) -> &mut Self {
        self.queue.pop();
        self.builder.pop();
        self
    }

    fn add_text(&mut self, text: impl AsRef<str>) -> &mut Self {
        let current = self.properties.last().unwrap().clone();
        let style = self.queue.last().unwrap();
        if &current.1 != style {
            self.properties.push((current.0, style.clone()));
        }
        let current = self.properties.last_mut().unwrap();
        current.0 += text.as_ref().chars().count();
        self.builder.add_text(text);
        self
    }

    fn text_cursor(&self) -> usize {
        self.properties.last().map_or(0, |(i, _)| *i)
    }

    pub fn index_book(&mut self, book: &ArchivedBookIdentifier) -> &mut Self {
        self.location.book = Some(deserialize::<_, Error>(book).unwrap());
        self
    }

    pub fn index_header(&mut self, header: &ArchivedString) -> &mut Self {
        self.location.header = Some(deserialize::<_, Error>(header).unwrap());
        let index = Index::new(
            self.location.book.clone().unwrap(),
            self.location.header.clone().unwrap(),
            None,
            None,
        );
        self.add_action(Action::Index(index));
        self
    }

    pub fn index_chapter(&mut self, chapter: u16) -> &mut Self {
        self.location.chapter = Some(chapter);
        let index = Index::new(
            self.location.book.clone().unwrap(),
            self.location.header.clone().unwrap(),
            self.location.chapter,
            None,
        );
        self.add_action(Action::Index(index));
        self
    }

    pub fn index_verse(&mut self, verse: u16) -> &mut Self {
        let index = Index::new(
            self.location.book.clone().unwrap(),
            self.location.header.clone().unwrap(),
            self.location.chapter,
            Some(verse),
        );
        self.add_action(Action::Index(index));
        self
    }

    fn add_action(&mut self, action: Action) {
        self.properties
            .last_mut()
            .unwrap()
            .1
            .actions
            .push(action.clone());
        self.queue.last_mut().unwrap().actions.push(action);
    }

    pub fn get_pages(&self) -> Result<AlignedVec, String> {
        unimplemented!()
        // rkyv::to_bytes::<Error>(self.layout.get_pages()).map_err(|e| e.to_string())
    }

    pub fn get_indices(&self) -> Result<AlignedVec, String> {
        unimplemented!()
        // rkyv::to_bytes::<Error>(self.layout.get_indices()).map_err(|e| e.to_string())
    }

    pub fn get_verses(&self) -> Result<AlignedVec, String> {
        unimplemented!()
        // rkyv::to_bytes::<Error>(self.layout.get_verses()).map_err(|e| e.to_string())
    }
}

#[derive(Archive, Serialize, Deserialize, Debug, Hash, PartialEq, Eq, Clone, Copy)]
#[repr(i32)]
pub enum Style {
    Verse = 0,
    Normal = 1,
    Header = 2,
    Chapter = 3,

    Caller = 9,
    Footnote = 10,
    CrossRef = 11,
}

#[derive(Debug)]
#[repr(C)]
pub struct Text(*const c_char, usize, Rectangle, TextStyle);

#[derive(Archive, Serialize, Deserialize, Debug, Clone, Copy)]
#[repr(C)]
pub struct Rectangle {
    top: f32,
    left: f32,
    width: f32,
    height: f32,
}

#[derive(Debug, Clone)]
#[repr(C)]
pub struct Dimensions {
    pub width: f32,
    pub height: f32,
    pub header_height: f32,
    pub drop_cap_padding: f32,
}

pub type Range = ops::Range<usize>;

fn usize_to_letters(mut i: usize) -> String {
    let mut s = String::new();

    loop {
        let rem = i % 26;
        s.push((b'a' + rem as u8) as char);

        if i < 26 {
            break;
        }

        i = i / 26 - 1;
    }

    s.chars().rev().collect()
}

fn get_or_insert_with<T, F>(vec: &mut Vec<T>, i: usize, mut f: F) -> &mut T
where
    F: FnMut(usize) -> T,
{
    if i >= vec.len() {
        vec.extend((vec.len()..=i).map(&mut f));
    }

    &mut vec[i]
}

fn pop_or_copy_last<T: Clone>(v: &mut Vec<T>) -> Option<T> {
    match v.len() {
        0 => None,
        1 => Some(v[0].clone()),
        _ => v.pop(),
    }
}

// mod format;
mod layout;
mod paint;
mod renderer;
// mod writer;

use std::{ffi::c_char, ops, slice::from_ref};

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

type Line = (Vec<Range>, f32);

#[derive(Debug)]
struct Page {
    body: Vec<Line>,
    footer: Vec<Line>,
}

impl Page {
    fn new() -> Self {
        Self {
            body: vec![(vec![0..0], 0.0)],
            footer: vec![(vec![0..0], 0.0)],
        }
    }

    fn append_page(&mut self, page: Page) -> Result<(), ()> {
        todo!();
    }

    fn get_body_width(&self) -> f32 {
        self.body.last().unwrap().1
    }

    fn get_footer_width(&self) -> f32 {
        self.footer.last().unwrap().1
    }

    fn add_body(&mut self, i: usize, width: f32) {
        let line = self.body.last_mut().unwrap();
        let inline = line.0.last_mut().unwrap();
        if inline.end < i {
            line.0.push(i..(i + 1));
        } else {
            inline.end += 1;
        }
        line.1 += width;
    }

    fn add_footer(&mut self, i: usize, width: f32) {
        let line = self.footer.last_mut().unwrap();
        let inline = line.0.last_mut().unwrap();
        if inline.end < i {
            line.0.push(i..(i + 1));
        } else {
            inline.end += 1;
        }
        line.1 += width;
    }

    fn new_line_body(&mut self) {
        self.body.push((vec![0..0], 0.0));
    }

    fn new_line_footer(&mut self) {
        self.footer.push((vec![0..0], 0.0));
    }
}

struct Layout {
    width: f32,
    height: f32,
    page: Page,
    footnote: usize,
    cross_ref: usize,
}

impl Painter {
    pub fn new(renderer: &Renderer, dim: Dimensions) -> Self {
        Self {
            renderer: renderer.clone(),
            builder: renderer.new_builder(),
            properties: Vec::new(),
            queue: Vec::new(),
            layout: Layout {
                width: dim.width,
                height: dim.height,
                page: Page::new(),
                footnote: 0,
                cross_ref: 0,
            },
            dim,
            location: LocationState::default(),
            callers: vec![],
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

        log!("{:?}", text);
        log!("{:#?}", inline);
        log!("{}", self.layout.width);

        log!("{:#?}", self.next_block(inline.as_mut_slice()));

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

    fn next_block(&mut self, inline: &mut [Inline]) -> Page {
        let mut page = Page::new();
        for (i, inline) in inline
            .iter_mut()
            .enumerate()
            .skip_while(|(_, c)| c.is_whitespace)
        {
            log!("{i}");
            if inline.properties.style == Style::Caller {
                let caller = self.get_caller(self.layout.footnote);
                inline.width = caller.width;
                println!("using caller {} ({})", caller.text, caller.width);
            }
            match inline.properties.section {
                Section::Body => {
                    if page.get_body_width() + inline.width < self.layout.width {
                        page.add_body(i, inline.width);
                    } else {
                        log!("Hi");
                        return page;
                    }
                }
                Section::Footer => {
                    if page.get_footer_width() + inline.width < self.layout.width {
                        page.add_footer(i, inline.width);
                    } else {
                        log!("{}", inline.width);
                        page.new_line_footer();
                    }
                }
            }
        }
        log!("Hey");
        page
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

mod error;
mod painter;

use error::SolaError;
use painter::Style;
use rkyv::rancor::Error;
use skia_safe::FontMgr;
use std::env;
use std::ffi::c_char;
use std::fs;
use usfm::{ArchivedBook, parse};

use crate::painter::{Dimensions, Paint, Painter, Renderer, TextStyle};

fn main() {
    // Get the file path from command line arguments
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage: {} <usfm_path> <font_path>", args[0]);
        return;
    }

    let file_path = &args[1];

    // Read the file into a string
    let contents = fs::read_to_string(file_path).expect("Failed to read file");
    let book = parse(&contents);
    let bytes = rkyv::to_bytes::<Error>(&book).unwrap();
    let archived = rkyv::access::<ArchivedBook, Error>(&*bytes).unwrap();

    let file_path = &args[2];

    let mut renderer = Renderer::new();
    let bytes = fs::read(file_path).expect("Failed to read file");
    let typeface = FontMgr::new()
        .new_from_data(&bytes, None)
        .ok_or(SolaError::FontLoad)
        .unwrap();
    renderer.register_typeface(typeface, "AveriaSerifLibre");

    let font = "AveriaSerifLibre";
    let font_family = font.as_ptr() as *const c_char;
    let font_family_len = font.len();

    // (rust.Style.NORMAL, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 16, height: 1.5, letterSpacing: 0, wordSpacing: 0)),
    // (rust.Style.HEADER, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 24, height: 1.0, letterSpacing: 0, wordSpacing: 0)),
    // (rust.Style.VERSE, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 10, height: 1.0, letterSpacing: 0, wordSpacing: 0)),
    // (rust.Style.CHAPTER, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 48, height: 1.0, letterSpacing: 0, wordSpacing: 0)),
    // (rust.Style.CALLER, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 10, height: 1.0, letterSpacing: 0, wordSpacing: 0)),
    // (rust.Style.FOOTNOTE, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 12, height: 1.5, letterSpacing: 0, wordSpacing: 0)),
    // (rust.Style.CROSSREF, TextStyle(fontFamily: 'AveriaSerifLibre', fontSize: 12, height: 1.5, letterSpacing: 0, wordSpacing: 0)),

    renderer.insert_style(
        Style::Normal,
        TextStyle {
            font_family,
            font_family_len,
            font_size: 16.0,
            height: 1.5,
            letter_spacing: 0.0,
            word_spacing: 0.0,
        },
    );
    renderer.insert_style(
        Style::Header,
        TextStyle {
            font_family,
            font_family_len,
            font_size: 24.0,
            height: 1.0,
            letter_spacing: 0.0,
            word_spacing: 0.0,
        },
    );
    renderer.insert_style(
        Style::Verse,
        TextStyle {
            font_family,
            font_family_len,
            font_size: 10.0,
            height: 1.0,
            letter_spacing: 0.0,
            word_spacing: 0.0,
        },
    );
    renderer.insert_style(
        Style::Chapter,
        TextStyle {
            font_family,
            font_family_len,
            font_size: 48.0,
            height: 1.0,
            letter_spacing: 0.0,
            word_spacing: 0.0,
        },
    );
    renderer.insert_style(
        Style::Caller,
        TextStyle {
            font_family,
            font_family_len,
            font_size: 10.0,
            height: 1.0,
            letter_spacing: 0.0,
            word_spacing: 0.0,
        },
    );
    renderer.insert_style(
        Style::Footnote,
        TextStyle {
            font_family,
            font_family_len,
            font_size: 12.0,
            height: 1.5,
            letter_spacing: 0.0,
            word_spacing: 0.0,
        },
    );
    renderer.insert_style(
        Style::CrossRef,
        TextStyle {
            font_family,
            font_family_len,
            font_size: 12.0,
            height: 1.5,
            letter_spacing: 0.0,
            word_spacing: 0.0,
        },
    );
    let dim = Dimensions {
        width: 344.0,
        height: 702.0,
        header_height: 702.0 / 5.0,
        drop_cap_padding: 20.0,
    };
    let mut painter = Painter::new(&renderer, dim);

    archived.paint(&mut painter);

    let (pages, indices) = painter.layout();
    println!("Pages: {}", pages.len());
    for (i, page) in pages.iter().enumerate() {
        println!("  Page {}: {} fragments", i, page.len());
        for frag in page {
            println!(
                "    {:?} @ ({:.1}, {:.1}) {:.1}x{:.1} +{:.2}: {:?}",
                frag.style,
                frag.rect.left,
                frag.rect.top,
                frag.rect.width,
                frag.rect.height,
                frag.word_spacing,
                frag.text
            );
        }
    }
    println!("Indices: {}", indices.len());
    for (index, page) in &indices {
        println!("  {:?} -> page {}", index, page);
    }
}

#[macro_export]
macro_rules! log {
    ($($arg:tt)*) => {{
        println!($($arg)*);
    }}
}

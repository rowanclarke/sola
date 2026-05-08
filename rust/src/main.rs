mod error;
mod painter;

use error::SolaError;
use painter::{
    ArchivedIndex, ArchivedIndices, ArchivedPages, Dimensions, Index, Paint, Painter, Renderer,
    Style, Text, TextStyle,
};
use rkyv::deserialize;
use rkyv::rancor::Error;
use rkyv::vec::ArchivedVec;
use skia_safe::FontMgr;
use std::backtrace::Backtrace;
use std::env;
use std::ffi::{c_char, c_void};
use std::fs;
use std::num::TryFromIntError;
use std::panic::AssertUnwindSafe;
use std::slice::from_raw_parts;
use std::str::from_utf8_unchecked;
use std::{mem, slice};
use usfm::{ArchivedBook, parse};

fn main() {
    // Get the file path from command line arguments
    let args: Vec<String> = env::args().collect();

    if args.len() < 2 {
        eprintln!("Usage: {} <file_path>", args[0]);
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
            font_size: 32.0,
            height: 1.0,
            letter_spacing: 0.0,
            word_spacing: 0.0,
        },
    );

    let dim = Dimensions {
        width: 344.0,
        height: 686.0,
        header_height: 686.0 / 5.0,
        drop_cap_padding: 20.0,
    };
    let mut painter = Painter::new(&renderer, dim);

    archived.paint(&mut painter);
}

#[macro_export]
macro_rules! log {
    ($($arg:tt)*) => {{
        println!($($arg)*);
    }}
}

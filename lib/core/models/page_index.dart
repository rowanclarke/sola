import 'dart:typed_data';

/// Offset table over a book's `pages` file.
///
/// Page `n` lives at `[offsetOf(n), offsetOf(n) + lengthOf(n))` and that range
/// is a self-contained archive, so a reader can seek straight to one page
/// instead of loading the book to reach it.
///
/// Layout, all little-endian: `SOPI`, a `u32` version, a `u32` page count, then
/// `count + 1` `u32` offsets. Written by `serialize_pages` in the renderer.
class PageIndex {
  static const _magic = 'SOPI';
  static const _version = 1;
  static const _headerBytes = 12;

  /// `pageCount + 1` offsets, so a page's length is the gap to the next entry.
  final Uint32List _offsets;

  PageIndex._(this._offsets);

  factory PageIndex.parse(Uint8List bytes) {
    if (bytes.length < _headerBytes) {
      throw const FormatException('Page offset table is truncated');
    }
    final data = ByteData.sublistView(bytes);
    final magic = String.fromCharCodes(bytes, 0, 4);
    if (magic != _magic) {
      throw FormatException('Not a page offset table: "$magic"');
    }
    final version = data.getUint32(4, Endian.little);
    if (version != _version) {
      throw FormatException('Page offset table version $version, expected $_version');
    }
    final count = data.getUint32(8, Endian.little);
    final expected = _headerBytes + 4 * (count + 1);
    if (bytes.length < expected) {
      throw FormatException(
        'Page offset table holds ${bytes.length} bytes, expected $expected for $count pages',
      );
    }
    final offsets = Uint32List(count + 1);
    for (var i = 0; i <= count; i++) {
      offsets[i] = data.getUint32(_headerBytes + 4 * i, Endian.little);
    }
    return PageIndex._(offsets);
  }

  int get pageCount => _offsets.length - 1;

  int offsetOf(int page) => _offsets[page];

  int lengthOf(int page) => _offsets[page + 1] - _offsets[page];
}

/// Where a book, chapter or verse landed in the rendered translation.
///
/// [chapter] and [verse] narrow the reference: a book has neither, a chapter
/// opening has only a chapter, a verse has both.
class Index {
  final int page;
  final String book;
  final String header;
  final int? chapter;
  final int? verse;

  Index(this.page, this.book, this.header, [this.chapter, this.verse]);

  String get reference {
    if (chapter == null) return header;
    if (verse == null) return '$header $chapter';
    return '$header $chapter:$verse';
  }
}

class Index {
  final int page;
  final String book;
  final String header;
  final int? chapter;
  final int? verse;

  Index(this.page, this.book, this.header, [this.chapter, this.verse]);

  String get reference {
    if (chapter == null || verse == null) {
      return header;
    } else if (verse == null) {
      return "$header $chapter";
    } else {
      return "$header $chapter:$verse";
    }
  }
}

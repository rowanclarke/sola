sealed class Index {
  final String book;
  final int page;
  Index(this.book, this.page);

  String get reference;
}

class VerseIndex extends Index {
  final int chapter;
  final int verse;

  VerseIndex(super.book, super.page, this.chapter, this.verse);

  @override
  String get reference => '$book $chapter:$verse';
}

class ChapterIndex extends Index {
  final int chapter;

  ChapterIndex(super.book, super.page, this.chapter);

  @override
  String get reference => '$book $chapter';
}

class BookIndex extends Index {
  BookIndex(book) : super(book, 0);

  @override
  String get reference => book;
}

/// Represents a Bible book with its chapters and verses.
/// Used as the structured data model after USFM parsing.
class Book {
  final String bookId;
  final String translationId;
  final List<Chapter> chapters;

  const Book({
    required this.bookId,
    required this.translationId,
    required this.chapters,
  });

  /// Creates a copy of this book with some fields replaced.
  Book copyWith({
    String? bookId,
    String? translationId,
    List<Chapter>? chapters,
  }) {
    throw UnimplementedError();
  }
}

/// Represents a chapter within a book.
class Chapter {
  final int chapterNumber;
  final List<Verse> verses;

  const Chapter({required this.chapterNumber, required this.verses});

  /// Creates a copy of this chapter with some fields replaced.
  Chapter copyWith({int? chapterNumber, List<Verse>? verses}) {
    throw UnimplementedError();
  }
}

/// Represents a single verse within a chapter.
class Verse {
  final int verseNumber;
  final String text;

  const Verse({required this.verseNumber, required this.text});

  /// Creates a copy of this verse with some fields replaced.
  Verse copyWith({int? verseNumber, String? text}) {
    throw UnimplementedError();
  }
}

/// Represents verse data for search results.
class VerseData {
  final String bookId;
  final int chapterNumber;
  final int verseNumber;
  final String text;

  const VerseData({
    required this.bookId,
    required this.chapterNumber,
    required this.verseNumber,
    required this.text,
  });

  /// Returns a formatted verse reference (e.g., "Genesis 1:1").
  String get reference {
    throw UnimplementedError();
  }
}

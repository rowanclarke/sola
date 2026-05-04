class Book {
  final String bookId;
  final String translationId;
  final List<Chapter> chapters;

  const Book({
    required this.bookId,
    required this.translationId,
    required this.chapters,
  });

  Book copyWith({
    String? bookId,
    String? translationId,
    List<Chapter>? chapters,
  }) {
    return Book(
      bookId: bookId ?? this.bookId,
      translationId: translationId ?? this.translationId,
      chapters: chapters ?? this.chapters,
    );
  }
}

class Chapter {
  final int chapterNumber;
  final List<Verse> verses;

  const Chapter({required this.chapterNumber, required this.verses});

  Chapter copyWith({int? chapterNumber, List<Verse>? verses}) {
    return Chapter(
      chapterNumber: chapterNumber ?? this.chapterNumber,
      verses: verses ?? this.verses,
    );
  }
}

class Verse {
  final int verseNumber;
  final String text;

  const Verse({required this.verseNumber, required this.text});

  Verse copyWith({int? verseNumber, String? text}) {
    return Verse(
      verseNumber: verseNumber ?? this.verseNumber,
      text: text ?? this.text,
    );
  }
}

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

  String get reference => '$bookId $chapterNumber:$verseNumber';
}

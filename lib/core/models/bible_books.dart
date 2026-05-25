class BibleBook {
  final String id;
  final String name;
  final String abbr;
  final int pageCount;
  final String testament;

  const BibleBook({
    required this.id,
    required this.name,
    required this.abbr,
    required this.pageCount,
    required this.testament,
  });
}

class BookPageInfo {
  final BibleBook book;
  final int localPage; // 0-based page within the book

  const BookPageInfo({required this.book, required this.localPage});
}

class BibleBooks {
  BibleBooks._();

  static const List<BibleBook> books = [
    // Old Testament
    BibleBook(id: 'GEN', name: 'Genesis', abbr: 'Gen', pageCount: 83, testament: 'OT'),
    BibleBook(id: 'EXO', name: 'Exodus', abbr: 'Exo', pageCount: 64, testament: 'OT'),
    BibleBook(id: 'LEV', name: 'Leviticus', abbr: 'Lev', pageCount: 45, testament: 'OT'),
    BibleBook(id: 'NUM', name: 'Numbers', abbr: 'Num', pageCount: 60, testament: 'OT'),
    BibleBook(id: 'DEU', name: 'Deuteronomy', abbr: 'Deu', pageCount: 54, testament: 'OT'),
    BibleBook(id: 'JOS', name: 'Joshua', abbr: 'Jos', pageCount: 38, testament: 'OT'),
    BibleBook(id: 'JDG', name: 'Judges', abbr: 'Jdg', pageCount: 36, testament: 'OT'),
    BibleBook(id: 'RUT', name: 'Ruth', abbr: 'Rut', pageCount: 8, testament: 'OT'),
    BibleBook(id: '1SA', name: '1 Samuel', abbr: '1Sa', pageCount: 52, testament: 'OT'),
    BibleBook(id: '2SA', name: '2 Samuel', abbr: '2Sa', pageCount: 46, testament: 'OT'),
    BibleBook(id: '1KI', name: '1 Kings', abbr: '1Ki', pageCount: 50, testament: 'OT'),
    BibleBook(id: '2KI', name: '2 Kings', abbr: '2Ki', pageCount: 48, testament: 'OT'),
    BibleBook(id: '1CH', name: '1 Chronicles', abbr: '1Ch', pageCount: 44, testament: 'OT'),
    BibleBook(id: '2CH', name: '2 Chronicles', abbr: '2Ch', pageCount: 52, testament: 'OT'),
    BibleBook(id: 'EZR', name: 'Ezra', abbr: 'Ezr', pageCount: 18, testament: 'OT'),
    BibleBook(id: 'NEH', name: 'Nehemiah', abbr: 'Neh', pageCount: 22, testament: 'OT'),
    BibleBook(id: 'EST', name: 'Esther', abbr: 'Est', pageCount: 16, testament: 'OT'),
    BibleBook(id: 'JOB', name: 'Job', abbr: 'Job', pageCount: 62, testament: 'OT'),
    BibleBook(id: 'PSA', name: 'Psalms', abbr: 'Psa', pageCount: 150, testament: 'OT'),
    BibleBook(id: 'PRO', name: 'Proverbs', abbr: 'Pro', pageCount: 48, testament: 'OT'),
    BibleBook(id: 'ECC', name: 'Ecclesiastes', abbr: 'Ecc', pageCount: 20, testament: 'OT'),
    BibleBook(id: 'SNG', name: 'Song of Solomon', abbr: 'Sng', pageCount: 14, testament: 'OT'),
    BibleBook(id: 'ISA', name: 'Isaiah', abbr: 'Isa', pageCount: 98, testament: 'OT'),
    BibleBook(id: 'JER', name: 'Jeremiah', abbr: 'Jer', pageCount: 90, testament: 'OT'),
    BibleBook(id: 'LAM', name: 'Lamentations', abbr: 'Lam', pageCount: 10, testament: 'OT'),
    BibleBook(id: 'EZK', name: 'Ezekiel', abbr: 'Ezk', pageCount: 74, testament: 'OT'),
    BibleBook(id: 'DAN', name: 'Daniel', abbr: 'Dan', pageCount: 28, testament: 'OT'),
    BibleBook(id: 'HOS', name: 'Hosea', abbr: 'Hos', pageCount: 22, testament: 'OT'),
    BibleBook(id: 'JOL', name: 'Joel', abbr: 'Jol', pageCount: 8, testament: 'OT'),
    BibleBook(id: 'AMO', name: 'Amos', abbr: 'Amo', pageCount: 16, testament: 'OT'),
    BibleBook(id: 'OBA', name: 'Obadiah', abbr: 'Oba', pageCount: 4, testament: 'OT'),
    BibleBook(id: 'JON', name: 'Jonah', abbr: 'Jon', pageCount: 6, testament: 'OT'),
    BibleBook(id: 'MIC', name: 'Micah', abbr: 'Mic', pageCount: 12, testament: 'OT'),
    BibleBook(id: 'NAM', name: 'Nahum', abbr: 'Nam', pageCount: 6, testament: 'OT'),
    BibleBook(id: 'HAB', name: 'Habakkuk', abbr: 'Hab', pageCount: 6, testament: 'OT'),
    BibleBook(id: 'ZEP', name: 'Zephaniah', abbr: 'Zep', pageCount: 6, testament: 'OT'),
    BibleBook(id: 'HAG', name: 'Haggai', abbr: 'Hag', pageCount: 4, testament: 'OT'),
    BibleBook(id: 'ZEC', name: 'Zechariah', abbr: 'Zec', pageCount: 22, testament: 'OT'),
    BibleBook(id: 'MAL', name: 'Malachi', abbr: 'Mal', pageCount: 8, testament: 'OT'),
    // New Testament
    BibleBook(id: 'MAT', name: 'Matthew', abbr: 'Mat', pageCount: 56, testament: 'NT'),
    BibleBook(id: 'MRK', name: 'Mark', abbr: 'Mrk', pageCount: 36, testament: 'NT'),
    BibleBook(id: 'LUK', name: 'Luke', abbr: 'Luk', pageCount: 52, testament: 'NT'),
    BibleBook(id: 'JHN', name: 'John', abbr: 'Jhn', pageCount: 42, testament: 'NT'),
    BibleBook(id: 'ACT', name: 'Acts', abbr: 'Act', pageCount: 54, testament: 'NT'),
    BibleBook(id: 'ROM', name: 'Romans', abbr: 'Rom', pageCount: 32, testament: 'NT'),
    BibleBook(id: '1CO', name: '1 Corinthians', abbr: '1Co', pageCount: 30, testament: 'NT'),
    BibleBook(id: '2CO', name: '2 Corinthians', abbr: '2Co', pageCount: 24, testament: 'NT'),
    BibleBook(id: 'GAL', name: 'Galatians', abbr: 'Gal', pageCount: 12, testament: 'NT'),
    BibleBook(id: 'EPH', name: 'Ephesians', abbr: 'Eph', pageCount: 12, testament: 'NT'),
    BibleBook(id: 'PHP', name: 'Philippians', abbr: 'Php', pageCount: 8, testament: 'NT'),
    BibleBook(id: 'COL', name: 'Colossians', abbr: 'Col', pageCount: 8, testament: 'NT'),
    BibleBook(id: '1TH', name: '1 Thessalonians', abbr: '1Th', pageCount: 8, testament: 'NT'),
    BibleBook(id: '2TH', name: '2 Thessalonians', abbr: '2Th', pageCount: 6, testament: 'NT'),
    BibleBook(id: '1TI', name: '1 Timothy', abbr: '1Ti', pageCount: 10, testament: 'NT'),
    BibleBook(id: '2TI', name: '2 Timothy', abbr: '2Ti', pageCount: 8, testament: 'NT'),
    BibleBook(id: 'TIT', name: 'Titus', abbr: 'Tit', pageCount: 6, testament: 'NT'),
    BibleBook(id: 'PHM', name: 'Philemon', abbr: 'Phm', pageCount: 4, testament: 'NT'),
    BibleBook(id: 'HEB', name: 'Hebrews', abbr: 'Heb', pageCount: 26, testament: 'NT'),
    BibleBook(id: 'JAS', name: 'James', abbr: 'Jas', pageCount: 10, testament: 'NT'),
    BibleBook(id: '1PE', name: '1 Peter', abbr: '1Pe', pageCount: 10, testament: 'NT'),
    BibleBook(id: '2PE', name: '2 Peter', abbr: '2Pe', pageCount: 6, testament: 'NT'),
    BibleBook(id: '1JN', name: '1 John', abbr: '1Jn', pageCount: 10, testament: 'NT'),
    BibleBook(id: '2JN', name: '2 John', abbr: '2Jn', pageCount: 2, testament: 'NT'),
    BibleBook(id: '3JN', name: '3 John', abbr: '3Jn', pageCount: 2, testament: 'NT'),
    BibleBook(id: 'JUD', name: 'Jude', abbr: 'Jud', pageCount: 4, testament: 'NT'),
    BibleBook(id: 'REV', name: 'Revelation', abbr: 'Rev', pageCount: 44, testament: 'NT'),
  ];

  /// Pre-computed cumulative page starts for each book.
  /// _pageStarts[i] = sum of pageCount for books[0..i-1].
  static final List<int> _pageStarts = _computePageStarts();

  static List<int> _computePageStarts() {
    final starts = <int>[];
    int cumulative = 0;
    for (final book in books) {
      starts.add(cumulative);
      cumulative += book.pageCount;
    }
    return starts;
  }

  /// Total page count across all 66 books.
  static final int totalPages =
      books.fold<int>(0, (sum, b) => sum + b.pageCount);

  /// Map from book ID to index for fast lookup.
  static final Map<String, int> _idToIndex = {
    for (int i = 0; i < books.length; i++) books[i].id: i,
  };

  /// Convert a global page index (0-based across all books) to book + local page.
  static BookPageInfo globalPageToBookInfo(int globalIndex) {
    globalIndex = globalIndex.clamp(0, totalPages - 1);
    // Binary search for the book
    int lo = 0, hi = books.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_pageStarts[mid] <= globalIndex) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return BookPageInfo(
      book: books[lo],
      localPage: globalIndex - _pageStarts[lo],
    );
  }

  /// Convert a book ID + local page (0-based) to a global page index.
  static int bookToGlobalPage(String bookId, int localPage) {
    final idx = _idToIndex[bookId];
    if (idx == null) return 0;
    return _pageStarts[idx] + localPage.clamp(0, books[idx].pageCount - 1);
  }

  /// Get a book by ID, or null if not found.
  static BibleBook? bookById(String bookId) {
    final idx = _idToIndex[bookId];
    return idx != null ? books[idx] : null;
  }

  /// Get the cumulative page start for a book index.
  static int pageStartForIndex(int bookIndex) => _pageStarts[bookIndex];
}

/// Reusable widget for displaying a single search result.
///
/// Displays a verse reference and preview text from a search result.
/// Used in SearchScreen's results list.
///
/// Shows:
/// - Verse reference (e.g., "Genesis 1:1")
/// - Preview text excerpt
/// - Tap to navigate to verse

import 'package:flutter/material.dart';

import '../../core/models/book.dart';

/// Widget for a single search result item in a list.
///
/// Displays:
/// - Verse reference (book, chapter, verse)
/// - Text preview (first ~100 chars of the verse)
/// - Visual separator/divider
///
/// Expects parent (SearchScreen) to handle onTap.
///
/// Example:
/// ```dart
/// SearchResultTile(
///   verse: verseData,
///   onTap: () {
///     viewModel.selectVerse(verseData);
///     Navigator.pop(context);
///   },
/// )
/// ```
class SearchResultTile extends StatelessWidget {
  /// The verse data to display.
  final VerseData verse;

  /// Callback when user taps this result.
  final VoidCallback onTap;

  /// Creates a search result tile.
  const SearchResultTile({super.key, required this.verse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }

  /// Builds the verse reference text (e.g., "Genesis 1:1").
  ///
  /// Formatted as "[BookName] [Chapter]:[Verse]"
  static String _buildReference(VerseData verse) {
    throw UnimplementedError();
  }

  /// Builds the text preview (first 100 chars of verse text).
  ///
  /// Truncates with "..." if text is longer than preview length.
  static String _buildPreview(String verseText, {int maxLength = 100}) {
    throw UnimplementedError();
  }
}

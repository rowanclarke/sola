import 'package:flutter/material.dart';

const _ink = Color(0xFF18181b);
const _line = Color(0xFFE4E4E7);
const _fill = Color(0xFFF4F4F5);

/// The square abbreviation tile a translation is recognised by.
///
/// Translations carry no abbreviation of their own, so the id stands in for
/// one; anything longer than the tile holds is cut.
class TranslationBadge extends StatelessWidget {
  final String translationId;
  final double size;
  final double fontSize;

  /// Filled black with white text, rather than outlined on a grey fill.
  final bool isFilled;

  const TranslationBadge({
    super.key,
    required this.translationId,
    this.size = 48,
    this.fontSize = 11,
    this.isFilled = false,
  });

  static String label(String translationId) => translationId.length > 6
      ? translationId.substring(0, 6)
      : translationId;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isFilled ? _ink : _fill,
        borderRadius: BorderRadius.circular(size / 4.8),
        border: Border.all(color: isFilled ? _ink : _line),
      ),
      alignment: Alignment.center,
      child: Text(
        label(translationId),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: isFilled ? Colors.white : _ink,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

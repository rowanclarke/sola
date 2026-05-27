import 'package:flutter/material.dart';

const _ink = Color(0xFF18181b);
const _mid = Color(0xFF71717a);
const _fill = Color(0xFFF4F4F5);
const _line = Color(0xFFE4E4E7);

class SelectableListRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SelectableListRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.isSelected = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _fill : Colors.transparent,
          border: const Border(
            bottom: BorderSide(color: _line, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: _ink,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: _mid),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ?? _defaultTrailing(),
          ],
        ),
      ),
    );
  }

  Widget _defaultTrailing() {
    const size = 22.0;
    if (isSelected) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: _ink,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 12),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _line, width: 1.5),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Reusable multi-select chip group widget.
///
/// Displays a [Wrap] of [FilterChip] widgets. Selected items
/// are highlighted in the primary color.
class MultiSelectChips extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const MultiSelectChips({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  void _toggle(String option) {
    final updated = List<String>.from(selected);
    if (updated.contains(option)) {
      updated.remove(option);
    } else {
      updated.add(option);
    }
    onChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(
                option,
                style: TextStyle(
                  fontSize: 13,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF1e3a8a),
              checkmarkColor: Colors.white,
              backgroundColor: Colors.grey[100],
              onSelected: (_) => _toggle(option),
            );
          }).toList(),
        ),
      ],
    );
  }
}

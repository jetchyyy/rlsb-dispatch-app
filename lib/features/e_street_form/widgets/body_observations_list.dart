import 'package:flutter/material.dart';

import '../models/body_parts_data.dart';

/// Displays a summary list of all body observations with
/// per-item delete and a "Clear All" button.
class BodyObservationsList extends StatelessWidget {
  final Map<String, String> observations;
  final ValueChanged<Map<String, String>> onChanged;

  const BodyObservationsList({
    super.key,
    required this.observations,
    required this.onChanged,
  });

  void _remove(String key) {
    final updated = Map<String, String>.from(observations)..remove(key);
    onChanged(updated);
  }

  void _clearAll() {
    onChanged({});
  }

  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: Colors.grey[400]),
            const SizedBox(width: 8),
            const Text(
              'No body observations recorded',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '${observations.length} observation${observations.length > 1 ? "s" : ""}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear All', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ...observations.entries.map((entry) {
          final part = BodyPartsData.findByKey(entry.key);
          final label = part?.label ?? entry.key.replaceAll('_', ' ');
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.2)),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.circle, size: 10, color: Colors.green),
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              subtitle: Text(entry.value, style: const TextStyle(fontSize: 12)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 16, color: Colors.red),
                onPressed: () => _remove(entry.key),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          );
        }),
      ],
    );
  }
}

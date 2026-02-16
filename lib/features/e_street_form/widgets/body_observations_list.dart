import 'package:flutter/material.dart';

import '../models/body_parts_data.dart';

/// Displays a summary list of all body observations with delete buttons.
class BodyObservationsList extends StatelessWidget {
  final Map<String, String> observations;
  final Future<void> Function(Map<String, String>) onObservationsChanged;

  const BodyObservationsList({
    super.key,
    required this.observations,
    required this.onObservationsChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (observations.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Column(
          children: [
            Icon(Icons.touch_app, size: 32, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Tap on body regions above to record injury observations',
              textAlign: TextAlign.center,
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
            const Icon(Icons.list_alt, size: 18, color: Color(0xFF1976D2)),
            const SizedBox(width: 6),
            Text(
              'Observations (${observations.length})',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (observations.isNotEmpty)
              TextButton.icon(
                onPressed: () => onObservationsChanged({}),
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
          ],
        ),
        const SizedBox(height: 4),
        ...observations.entries.map((entry) {
          final part = BodyPartsData.findByKey(entry.key);
          final label = part?.label ?? entry.key;

          return Card(
            margin: const EdgeInsets.only(bottom: 6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            child: ListTile(
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0x1A28A745),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF28A745),
                  size: 18,
                ),
              ),
              title: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              subtitle: Text(
                entry.value,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                onPressed: () {
                  final updated = Map<String, String>.from(observations);
                  updated.remove(entry.key);
                  onObservationsChanged(updated);
                },
              ),
            ),
          );
        }),
      ],
    );
  }
}

import 'package:flutter/material.dart';

/// Dialog for entering/editing an observation for a body part.
class BodyObservationDialog extends StatefulWidget {
  final String partLabel;
  final String? currentObservation;

  const BodyObservationDialog({
    super.key,
    required this.partLabel,
    this.currentObservation,
  });

  /// Shows the dialog and returns the observation text.
  /// Returns null if dismissed, empty string if cleared.
  static Future<String?> show(
    BuildContext context, {
    required String partLabel,
    String? currentObservation,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => BodyObservationDialog(
        partLabel: partLabel,
        currentObservation: currentObservation,
      ),
    );
  }

  @override
  State<BodyObservationDialog> createState() => _BodyObservationDialogState();
}

class _BodyObservationDialogState extends State<BodyObservationDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentObservation ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting =
        widget.currentObservation != null && widget.currentObservation!.isNotEmpty;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasExisting
                  ? const Color(0x1A28A745)
                  : const Color(0x1A1976D2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              hasExisting ? Icons.edit_note : Icons.add_circle_outline,
              color:
                  hasExisting ? const Color(0xFF28A745) : const Color(0xFF1976D2),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.partLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Describe injuries, findings, or observations:',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'e.g., 3cm laceration, bruising, swelling...',
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          if (hasExisting) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(''),
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              label: const Text(
                'Remove Observation',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

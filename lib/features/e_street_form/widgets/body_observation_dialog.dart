import 'package:flutter/material.dart';

/// Dialog for entering or editing a body observation note.
///
/// Returns:
/// - `null` if dismissed
/// - `''` (empty string) if "Remove" was pressed
/// - observation text otherwise
class BodyObservationDialog extends StatefulWidget {
  final String partLabel;
  final String? currentObservation;

  const BodyObservationDialog._({
    required this.partLabel,
    this.currentObservation,
  });

  /// Show the dialog and return the result.
  static Future<String?> show(
    BuildContext context, {
    required String partLabel,
    String? currentObservation,
  }) {
    return showDialog<String>(
      context: context,
      builder: (_) => BodyObservationDialog._(
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
    final hasExisting = widget.currentObservation != null &&
        widget.currentObservation!.isNotEmpty;

    return AlertDialog(
      title: Text(widget.partLabel),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Describe any observed injury or condition:',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'e.g., 2cm laceration, swelling, bruising…',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (hasExisting)
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isNotEmpty) {
              Navigator.pop(context, text);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

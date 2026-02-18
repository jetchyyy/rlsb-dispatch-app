import 'package:flutter/material.dart';

/// GCS (Glasgow Coma Scale) selector with 3 dropdowns.
///
/// Eye (1-4), Verbal (1-5), Motor (1-6) with computed total and severity label.
class GcsSelector extends StatelessWidget {
  final int? eye;
  final int? verbal;
  final int? motor;
  final ValueChanged<int?> onEyeChanged;
  final ValueChanged<int?> onVerbalChanged;
  final ValueChanged<int?> onMotorChanged;

  const GcsSelector({
    super.key,
    this.eye,
    this.verbal,
    this.motor,
    required this.onEyeChanged,
    required this.onVerbalChanged,
    required this.onMotorChanged,
  });

  int get _total => (eye ?? 0) + (verbal ?? 0) + (motor ?? 0);
  bool get _hasValues => eye != null || verbal != null || motor != null;

  String get _severityLabel {
    if (!_hasValues) return '';
    final t = _total;
    if (t <= 8) return 'Severe';
    if (t <= 12) return 'Moderate';
    return 'Mild';
  }

  Color get _severityColor {
    if (!_hasValues) return Colors.grey;
    final t = _total;
    if (t <= 8) return Colors.red;
    if (t <= 12) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Glasgow Coma Scale (GCS)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _dropdown('Eye', eye, 4, onEyeChanged)),
            const SizedBox(width: 8),
            Expanded(child: _dropdown('Verbal', verbal, 5, onVerbalChanged)),
            const SizedBox(width: 8),
            Expanded(child: _dropdown('Motor', motor, 6, onMotorChanged)),
          ],
        ),
        if (_hasValues) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _severityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _severityColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assessment, size: 16, color: _severityColor),
                const SizedBox(width: 6),
                Text(
                  'Total: $_total / 15 — $_severityLabel',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _severityColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _dropdown(
    String label,
    int? value,
    int max,
    ValueChanged<int?> onChanged,
  ) {
    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('—')),
        ...List.generate(max, (i) {
          final v = i + 1;
          return DropdownMenuItem(value: v, child: Text('$v'));
        }),
      ],
      onChanged: onChanged,
    );
  }
}

import 'package:flutter/material.dart';

/// Glasgow Coma Scale selector with 3 dropdowns and real-time total.
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

  int get total => (eye ?? 0) + (verbal ?? 0) + (motor ?? 0);

  String get totalLabel {
    if (eye == null && verbal == null && motor == null) return '--';
    final t = total;
    if (t <= 8) return '$t (Severe)';
    if (t <= 12) return '$t (Moderate)';
    return '$t (Mild)';
  }

  Color get totalColor {
    if (eye == null && verbal == null && motor == null) return Colors.grey;
    final t = total;
    if (t <= 8) return Colors.red;
    if (t <= 12) return Colors.orange;
    return const Color(0xFF28A745);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Glasgow Coma Scale',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF424242),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Eye',
                value: eye,
                items: const {
                  4: 'Spontaneous',
                  3: 'To Voice',
                  2: 'To Pain',
                  1: 'None',
                },
                onChanged: onEyeChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown(
                label: 'Verbal',
                value: verbal,
                items: const {
                  5: 'Oriented',
                  4: 'Confused',
                  3: 'Words',
                  2: 'Sounds',
                  1: 'None',
                },
                onChanged: onVerbalChanged,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDropdown(
                label: 'Motor',
                value: motor,
                items: const {
                  6: 'Obeys',
                  5: 'Localizes',
                  4: 'Withdraws',
                  3: 'Flexion',
                  2: 'Extension',
                  1: 'None',
                },
                onChanged: onMotorChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: totalColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: totalColor.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('GCS Total: ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              Text(
                totalLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: totalColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required int? value,
    required Map<int, String> items,
    required ValueChanged<int?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        DropdownButtonFormField<int>(
          value: value,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          hint: const Text('--', style: TextStyle(fontSize: 12)),
          items: items.entries
              .map((e) => DropdownMenuItem(
                    value: e.key,
                    child: Text('${e.key}: ${e.value}',
                        style: const TextStyle(fontSize: 11)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

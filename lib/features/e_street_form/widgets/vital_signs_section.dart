import 'package:flutter/material.dart';

/// Vital signs input grid — 2 columns × 3 rows.
class VitalSignsSection extends StatelessWidget {
  final TextEditingController bpController;
  final TextEditingController pulseController;
  final TextEditingController respController;
  final TextEditingController tempController;
  final TextEditingController spo2Controller;
  final TextEditingController glucoseController;

  const VitalSignsSection({
    super.key,
    required this.bpController,
    required this.pulseController,
    required this.respController,
    required this.tempController,
    required this.spo2Controller,
    required this.glucoseController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vital Signs',
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
              child: _buildField(
                controller: bpController,
                label: 'Blood Pressure',
                hint: 'e.g. 120/80',
                icon: Icons.favorite,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                controller: pulseController,
                label: 'Pulse (bpm)',
                hint: 'e.g. 88',
                icon: Icons.monitor_heart_outlined,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildField(
                controller: respController,
                label: 'Respiratory (/min)',
                hint: 'e.g. 18',
                icon: Icons.air,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                controller: tempController,
                label: 'Temperature (°C)',
                hint: 'e.g. 36.8',
                icon: Icons.thermostat,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildField(
                controller: spo2Controller,
                label: 'SpO₂ (%)',
                hint: 'e.g. 97',
                icon: Icons.opacity,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildField(
                controller: glucoseController,
                label: 'Blood Glucose',
                hint: 'mg/dL',
                icon: Icons.bloodtype,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        prefixIcon: Icon(icon, size: 18),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }
}

import 'package:flutter/material.dart';

/// 2×3 grid of vital sign input fields.
///
/// Fields: Blood Pressure, Pulse, Respiratory Rate,
///         Temperature, SpO₂, Blood Glucose
class VitalSignsSection extends StatelessWidget {
  final TextEditingController bpController;
  final TextEditingController pulseController;
  final TextEditingController respiratoryController;
  final TextEditingController temperatureController;
  final TextEditingController spo2Controller;
  final TextEditingController bloodGlucoseController;

  const VitalSignsSection({
    super.key,
    required this.bpController,
    required this.pulseController,
    required this.respiratoryController,
    required this.temperatureController,
    required this.spo2Controller,
    required this.bloodGlucoseController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vital Signs', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _vitalField(
                controller: bpController,
                label: 'Blood Pressure',
                hint: '120/80',
                icon: Icons.favorite,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _vitalField(
                controller: pulseController,
                label: 'Pulse',
                hint: 'bpm',
                icon: Icons.monitor_heart,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _vitalField(
                controller: respiratoryController,
                label: 'Respiratory',
                hint: 'breaths/min',
                icon: Icons.air,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _vitalField(
                controller: temperatureController,
                label: 'Temperature',
                hint: '°C',
                icon: Icons.thermostat,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _vitalField(
                controller: spo2Controller,
                label: 'SpO₂',
                hint: '%',
                icon: Icons.bloodtype,
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _vitalField(
                controller: bloodGlucoseController,
                label: 'Blood Glucose',
                hint: 'mg/dL',
                icon: Icons.science,
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _vitalField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType ?? TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        isDense: true,
      ),
    );
  }
}

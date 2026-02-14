import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/custom_button.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final responder = authProvider.responder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ── Avatar ─────────────────────────────────────
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              child: const Icon(
                Icons.person,
                size: 56,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              responder?.name ?? 'Responder',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              responder?.email ?? '',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            // ── Info Cards ─────────────────────────────────
            _infoTile(Icons.badge, 'Badge', responder?.badge ?? 'N/A'),
            _infoTile(Icons.phone, 'Phone', responder?.phone ?? 'N/A'),
            _infoTile(Icons.group, 'Team', responder?.team ?? 'N/A'),
            _infoTile(Icons.security, 'Role', responder?.role ?? 'N/A'),
            _infoTile(Icons.circle,
                'Status', responder?.status ?? 'N/A'),
            const SizedBox(height: 32),

            // ── Logout ─────────────────────────────────────
            CustomButton(
              text: 'Logout',
              icon: Icons.logout,
              backgroundColor: AppColors.error,
              isLoading: authProvider.isLoading,
              onPressed: () async {
                await authProvider.logout();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      subtitle:
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      contentPadding: EdgeInsets.zero,
    );
  }
}

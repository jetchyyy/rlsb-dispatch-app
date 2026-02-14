import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.user;

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
              user?.name ?? 'Dispatcher',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              user?.email ?? '',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),

            // ── Info Cards ─────────────────────────────────
            _infoTile(Icons.badge, 'ID Number', user?.idNumber ?? 'N/A'),
            _infoTile(Icons.business, 'Division', user?.division ?? 'N/A'),
            _infoTile(Icons.work, 'Position', user?.position ?? 'N/A'),
            _infoTile(Icons.phone, 'Phone', user?.phoneNumber ?? 'N/A'),
            _infoTile(Icons.security, 'Roles',
                user?.roles.join(', ') ?? 'N/A'),
            const SizedBox(height: 32),

            // ── Logout ─────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: authProvider.isLoading
                    ? null
                    : () async {
                        await authProvider.logout();
                        if (context.mounted) context.go('/login');
                      },
                icon: authProvider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.logout),
                label: Text(authProvider.isLoading ? 'Logging out...' : 'Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
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

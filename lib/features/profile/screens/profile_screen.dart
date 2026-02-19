import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// Counter for hidden admin mode unlock.
  /// Tap "Roles" 10 times to reveal the dispatcher tracker.
  int _adminTapCount = 0;

  static const int _adminUnlockTaps = 10;

  void _onRolesTapped(BuildContext context) {
    setState(() {
      _adminTapCount++;
    });

    if (_adminTapCount >= _adminUnlockTaps) {
      _adminTapCount = 0; // Reset counter
      context.push('/admin/tracker');
    } else if (_adminTapCount >= 5) {
      // Hint after 5 taps
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_adminUnlockTaps - _adminTapCount} more taps...'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

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
            _infoTile(Icons.local_fire_department, 'Unit', user?.unit ?? 'N/A'),
            _infoTile(Icons.work, 'Position', user?.position ?? 'N/A'),
            _infoTile(Icons.phone, 'Phone', user?.phoneNumber ?? 'N/A'),
            // Tappable Roles tile for hidden admin mode
            GestureDetector(
              onTap: () => _onRolesTapped(context),
              child: _infoTile(Icons.security, 'Roles',
                  user?.roles.join(', ') ?? 'N/A'),
            ),
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

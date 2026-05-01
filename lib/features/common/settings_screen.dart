import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.fullName ?? 'User',
                  style: GoogleFonts.workSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Role: ${profile?.role ?? 'unknown'}',
                  style: GoogleFonts.workSans(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: AppTheme.surface,
            child: ListTile(
              leading: const Icon(Icons.logout, color: AppTheme.error),
              title: Text(
                'Logout',
                style: GoogleFonts.workSans(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.error,
                ),
              ),
              subtitle: Text(
                'Ends session and clears Remember Me',
                style: GoogleFonts.workSans(fontSize: 12),
              ),
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (!context.mounted) return;
                context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

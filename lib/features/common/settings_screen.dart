import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../l10n/l10n.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final currentLocale = ref.watch(localeProvider);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: GoogleFonts.workSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Profile Header ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    (profile?.fullName ?? 'U').substring(0, 1).toUpperCase(),
                    style: GoogleFonts.workSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.fullName ?? 'User',
                        style: GoogleFonts.workSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile?.role.toUpperCase() ?? 'USER',
                        style: GoogleFonts.workSans(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Language Selector Card (Instant Toggle) ──
          Card(
            elevation: 0,
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.language,
                          color: AppTheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${l10n.language} / Language',
                          style: GoogleFonts.workSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppTheme.divider),

                  RadioGroup<String>(
                    groupValue: currentLocale.languageCode,
                    onChanged: (value) async {
                      if (value != null) {
                        await ref
                            .read(localeProvider.notifier)
                            .setLocale(Locale(value));
                      }
                    },
                    child: Column(
                      children: [
                        // Hindi Option (Hindi-First Default)
                        RadioListTile<String>(
                          value: 'hi',
                          title: Row(
                            children: [
                              Text(
                                'हिंदी (Hindi)',
                                style: GoogleFonts.workSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'अ',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'डिफ़ॉल्ट भाषा (दूध वितरण एवं हिसाब)',
                            style: GoogleFonts.workSans(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          activeColor: AppTheme.primary,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                        ),
                        const Divider(
                          height: 1,
                          indent: 16,
                          endIndent: 16,
                          color: AppTheme.divider,
                        ),

                        // English Option
                        RadioListTile<String>(
                          value: 'en',
                          title: Row(
                            children: [
                              Text(
                                'English',
                                style: GoogleFonts.workSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.background,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'A',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'English language interface',
                            style: GoogleFonts.workSans(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          activeColor: AppTheme.primary,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Logout Card ──
          Card(
            elevation: 0,
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.logout, color: AppTheme.error, size: 22),
              ),
              title: Text(
                l10n.logout,
                style: GoogleFonts.workSans(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.error,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                l10n.logoutSubtitle,
                style: GoogleFonts.workSans(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              onTap: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (!context.mounted) return;
                ref.invalidate(profileProvider);
                context.go('/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

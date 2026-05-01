import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color? iconBgColor;
  final Color? iconColor;
  final Color? valueColor;
  final Color? bgColor;
  final bool highlight;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    this.iconBgColor,
    this.iconColor,
    this.valueColor,
    this.bgColor,
    this.highlight = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: highlight ? AppTheme.primary : (bgColor ?? AppTheme.surface),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: highlight
                      ? Colors.white.withValues(alpha: 0.2)
                      : (iconBgColor ?? AppTheme.primaryLight),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: highlight
                      ? Colors.white
                      : (iconColor ?? AppTheme.primary),
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: GoogleFonts.workSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color:
                      highlight ? Colors.white : (valueColor ?? AppTheme.textPrimary),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                style: GoogleFonts.workSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: highlight
                      ? Colors.white.withValues(alpha: 0.8)
                      : AppTheme.textSecondary,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.workSans(
                    fontSize: 11,
                    color: highlight
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppTheme.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

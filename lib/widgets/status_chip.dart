import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  static String label(String status) {
    return switch (status) {
      'pending' => 'Pending',
      'validated' => 'Validated',
      'rejected' => 'Rejected',
      _ => 'Not submitted',
    };
  }

  static Color color(String status) {
    return switch (status) {
      'pending' => AppColors.warning,
      'validated' => AppColors.success,
      'rejected' => AppColors.danger,
      _ => AppColors.muted,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label(status),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';

import '../../domain/models/nfc_support_status.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({required this.status, super.key});

  final NfcSupportStatus status;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = switch (status) {
      NfcSupportStatus.enabled => (Icons.check_circle_rounded, colors.primary),
      NfcSupportStatus.disabled => (Icons.nfc_rounded, colors.error),
      NfcSupportStatus.unsupported => (Icons.block_rounded, colors.error),
      NfcSupportStatus.unknown => (Icons.help_rounded, colors.outline),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

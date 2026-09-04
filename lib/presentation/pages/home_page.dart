import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/byte_utils.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/models/nfc_scan.dart';
import '../../domain/models/nfc_support_status.dart';
import '../../domain/models/tag_identity_stability.dart';
import '../../domain/services/tag_classifier.dart';
import '../controllers/nfc_scan_controller.dart';
import '../widgets/key_value_row.dart';
import '../widgets/section_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/tag_assessment_card.dart';
import 'scan_detail_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({required this.controller, super.key});

  final NfcScanController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final NfcScan? scan = controller.currentScan;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/branding/tagverity_app_icon.png',
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Inspect an NFC tag',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'Read, check, and understand a tag in one tap.',
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(status: controller.supportStatus),
                    ],
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed:
                        controller.supportStatus == NfcSupportStatus.unsupported
                        ? null
                        : () {
                            if (controller.isScanning) {
                              unawaited(controller.stopScan());
                            } else {
                              unawaited(controller.startScan());
                            }
                          },
                    icon: controller.isScanning
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sensors_rounded),
                    label: Text(
                      controller.isScanning ? 'Stop scanning' : 'Scan NFC tag',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        unawaited(controller.refreshAvailability()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Check NFC availability'),
                  ),
                ],
              ),
            ),
            if (controller.errorMessage case final String message) ...<Widget>[
              const SizedBox(height: 14),
              _ErrorCard(message: message, onClose: controller.clearError),
            ],
            const SizedBox(height: 14),
            if (scan == null)
              const _GettingStartedCard()
            else ...<Widget>[
              TagAssessmentCard(assessment: controller.currentAssessment!),
              const SizedBox(height: 14),
              _CurrentScanCard(controller: controller, scan: scan),
            ],
            const SizedBox(height: 14),
            const SectionCard(
              title: 'Safe by design',
              child: Text(
                'TagVerity is read-only. It does not clone cards, emulate tags, recover keys, '
                'send arbitrary APDUs, or modify protected tag memory.',
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CurrentScanCard extends StatelessWidget {
  const _CurrentScanCard({required this.controller, required this.scan});

  final NfcScanController controller;
  final NfcScan scan;

  @override
  Widget build(BuildContext context) {
    final classification = TagClassifier.classify(scan);
    return SectionCard(
      title: 'Latest scan',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Copy scan JSON',
            onPressed: () async {
              await controller.copyCurrentScanJson();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scan JSON copied')),
                );
              }
            },
            icon: const Icon(Icons.copy_all_rounded),
          ),
          IconButton(
            tooltip: 'Share scan report',
            onPressed: () => unawaited(controller.shareCurrentScanJson()),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      child: Column(
        children: <Widget>[
          KeyValueRow(
            label: 'Time',
            value: DateTimeUtils.formatLocal(scan.scannedAt),
          ),
          KeyValueRow(label: 'Type', value: classification.label),
          KeyValueRow(label: 'Identity', value: scan.identityStability.label),
          KeyValueRow(
            label: 'UID',
            value: scan.uidHex ?? 'Not exposed by this platform',
          ),
          KeyValueRow(
            label: 'Fingerprint',
            value: ByteUtils.shortFingerprint(scan.uidFingerprint),
          ),
          KeyValueRow(
            label: 'Technology',
            value: scan.technologies.isEmpty
                ? 'Not reported'
                : scan.technologies.join(', '),
          ),
          KeyValueRow(
            label: 'NDEF records',
            value: scan.ndefRecords.length.toString(),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () {
              unawaited(
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (BuildContext context) => ScanDetailPage(
                      scan: scan,
                      showAdvancedFields:
                          controller.settings.showAdvancedFields,
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('View full details'),
          ),
        ],
      ),
    );
  }
}

class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'What TagVerity checks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _FeatureLine(
            icon: Icons.check_circle_outline_rounded,
            text: 'Whether the tag is detected cleanly',
          ),
          _FeatureLine(
            icon: Icons.layers_outlined,
            text: 'NFC technology and public tag metadata',
          ),
          _FeatureLine(
            icon: Icons.description_outlined,
            text: 'Standard NDEF content and capacity',
          ),
          _FeatureLine(
            icon: Icons.warning_amber_rounded,
            text: 'Read warnings that need review',
          ),
        ],
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline_rounded, color: colors.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

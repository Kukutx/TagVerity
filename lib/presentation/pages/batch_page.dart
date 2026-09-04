import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/byte_utils.dart';
import '../../domain/models/nfc_scan.dart';
import '../../domain/models/tag_assessment.dart';
import '../../domain/services/tag_assessor.dart';
import '../controllers/nfc_scan_controller.dart';
import '../widgets/section_card.dart';
import 'scan_detail_page.dart';

class BatchPage extends StatelessWidget {
  const BatchPage({required this.controller, super.key});

  final NfcScanController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final List<NfcScan> scans = controller.batchScans;
        final Set<String> duplicates = controller.batchDuplicateFingerprints;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            SectionCard(
              title: 'Batch check',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Text(
                    'Scan a set of NFC tags, spot duplicates, and review tags that need attention.',
                  ),
                  const SizedBox(height: 14),
                  if (controller.batchSessionActive) ...<Widget>[
                    FilledButton.icon(
                      onPressed: controller.isScanning
                          ? () => unawaited(controller.stopScan())
                          : () => unawaited(controller.startBatchScan()),
                      icon: controller.isScanning
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.nfc_rounded),
                      label: Text(
                        controller.isScanning
                            ? 'Stop scanning'
                            : 'Scan next tag',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: controller.isScanning
                          ? null
                          : controller.finishBatchSession,
                      icon: const Icon(Icons.flag_rounded),
                      label: const Text('Finish batch'),
                    ),
                  ] else
                    FilledButton.icon(
                      onPressed: controller.startBatchSession,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        scans.isEmpty ? 'Start batch' : 'Start new batch',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _BatchSummary(controller: controller),
            if (scans.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              SectionCard(
                title: 'Batch results',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Copy CSV',
                      onPressed: () async {
                        await controller.copyBatchCsv();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Batch CSV copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_all_rounded),
                    ),
                    IconButton(
                      tooltip: 'Share CSV report',
                      onPressed: () => unawaited(controller.shareBatchCsv()),
                      icon: const Icon(Icons.ios_share_rounded),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: scans.reversed
                      .map(
                        (NfcScan scan) => _BatchScanTile(
                          scan: scan,
                          duplicate: duplicates.contains(scan.uidFingerprint),
                          showAdvancedFields:
                              controller.settings.showAdvancedFields,
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => unawaited(controller.clearBatchSession()),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear batch results'),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _BatchSummary extends StatelessWidget {
  const _BatchSummary({required this.controller});

  final NfcScanController controller;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Summary',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _Metric(
                label: 'Scanned',
                value: controller.batchScans.length.toString(),
              ),
              _Metric(
                label: 'Pass',
                value: controller.batchHealthyCount.toString(),
              ),
              _Metric(
                label: 'Limited',
                value: controller.batchLimitedCount.toString(),
              ),
              _Metric(
                label: 'Review',
                value: controller.batchReviewCount.toString(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _Metric(
                label: 'Comparable',
                value: controller.batchComparableCount.toString(),
              ),
              _Metric(
                label: 'Unique',
                value: controller.batchUniqueCount.toString(),
              ),
              _Metric(
                label: 'Duplicates',
                value: controller.batchDuplicateFingerprints.length.toString(),
              ),
              _Metric(
                label: 'Session-only',
                value: controller.batchSessionOnlyCount.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _BatchScanTile extends StatelessWidget {
  const _BatchScanTile({
    required this.scan,
    required this.duplicate,
    required this.showAdvancedFields,
  });

  final NfcScan scan;
  final bool duplicate;
  final bool showAdvancedFields;

  @override
  Widget build(BuildContext context) {
    final TagAssessment assessment = TagAssessor.assess(scan);
    final bool comparable = scan.hasComparableIdentity;
    final IconData icon = switch (assessment.status) {
      TagAssessmentStatus.healthy => Icons.check_circle_rounded,
      TagAssessmentStatus.limited => Icons.info_rounded,
      TagAssessmentStatus.review => Icons.warning_amber_rounded,
    };

    return ListTile(
      leading: Icon(icon),
      title: Text('Tag ${ByteUtils.shortFingerprint(scan.uidFingerprint)}'),
      subtitle: Text(
        !comparable
            ? 'Stable identity unavailable; duplicate check skipped'
            : duplicate
                ? 'Duplicate in this batch'
                : (scan.technologies.isEmpty
                      ? 'Technology not reported'
                      : scan.technologies.join(', ')),
      ),
      trailing: duplicate
          ? const Chip(
              visualDensity: VisualDensity.compact,
              label: Text('DUPLICATE'),
            )
          : !comparable
              ? const Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('SESSION'),
                )
              : const Icon(Icons.chevron_right_rounded),
      onTap: () {
        unawaited(
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => ScanDetailPage(
                scan: scan,
                showAdvancedFields: showAdvancedFields,
              ),
            ),
          ),
        );
      },
    );
  }
}

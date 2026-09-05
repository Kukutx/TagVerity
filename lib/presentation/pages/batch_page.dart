import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/byte_utils.dart';
import '../../domain/models/batch_summary.dart';
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
        final BatchSummary summary = controller.batchSummary;
        final int itemCount = scans.isEmpty ? 2 : scans.length + 4;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: itemCount,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return _BatchControls(controller: controller);
            }
            if (index == 1) {
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _BatchSummaryCard(summary: summary),
              );
            }
            if (scans.isEmpty) {
              return const SizedBox.shrink();
            }
            if (index == 2) {
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _BatchResultsHeader(controller: controller),
              );
            }
            final int resultIndex = index - 3;
            if (resultIndex < scans.length) {
              final NfcScan scan = scans[scans.length - 1 - resultIndex];
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Card(
                  child: _BatchScanTile(
                    scan: scan,
                    repeated: summary.repeatedFingerprints.contains(
                      scan.uidFingerprint,
                    ),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton.icon(
                onPressed: () => unawaited(controller.clearBatchSession()),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Clear batch results'),
              ),
            );
          },
        );
      },
    );
  }
}

class _BatchControls extends StatelessWidget {
  const _BatchControls({required this.controller});
  final NfcScanController controller;
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Batch check',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Scan a set of NFC tags, spot repeated comparable IDs, and review tags that need attention.',
          ),
          const SizedBox(height: 14),
          if (controller.batchSessionActive) ...<Widget>[
            const Text(
              'Continuous mode starts a fresh reader session immediately after each successful read. '
              'On iPhone, the system NFC sheet may reopen between tags.',
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: controller.batchAutoContinue
                  ? () => unawaited(controller.stopContinuousBatchScan())
                  : controller.isScanning
                  ? null
                  : () => unawaited(controller.startContinuousBatchScan()),
              icon: Icon(
                controller.batchAutoContinue
                    ? Icons.stop_circle_outlined
                    : Icons.repeat_rounded,
              ),
              label: Text(
                controller.batchAutoContinue
                    ? 'Stop continuous scan'
                    : 'Start continuous scan',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.batchAutoContinue
                  ? null
                  : controller.isScanning
                  ? () => unawaited(controller.stopScan())
                  : () => unawaited(controller.startBatchScan()),
              icon: controller.isScanning
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.nfc_rounded),
              label: Text(
                controller.isScanning ? 'Stop current scan' : 'Scan one tag',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.finishBatchSession,
              icon: const Icon(Icons.flag_rounded),
              label: const Text('Finish batch'),
            ),
          ] else ...<Widget>[
            FilledButton.icon(
              onPressed: () => unawaited(controller.startContinuousBatchScan()),
              icon: const Icon(Icons.repeat_rounded),
              label: Text(
                controller.batchScans.isEmpty
                    ? 'Start continuous batch'
                    : 'Start new continuous batch',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: controller.startBatchSession,
              icon: const Icon(Icons.touch_app_rounded),
              label: const Text('Start manual batch'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BatchSummaryCard extends StatelessWidget {
  const _BatchSummaryCard({required this.summary});
  final BatchSummary summary;
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Summary',
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _Metric(label: 'Scanned', value: summary.total.toString()),
              _Metric(label: 'Pass', value: summary.healthy.toString()),
              _Metric(label: 'Limited', value: summary.limited.toString()),
              _Metric(label: 'Review', value: summary.review.toString()),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _Metric(
                label: 'Comparable',
                value: summary.comparable.toString(),
              ),
              _Metric(
                label: 'Distinct IDs',
                value: summary.distinctComparableIds.toString(),
              ),
              _Metric(
                label: 'Repeated IDs',
                value: summary.repeatedIdCount.toString(),
              ),
              _Metric(
                label: 'Session-only',
                value: summary.sessionOnly.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BatchResultsHeader extends StatelessWidget {
  const _BatchResultsHeader({required this.controller});
  final NfcScanController controller;
  @override
  Widget build(BuildContext context) {
    return SectionCard(
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
      child: const Text(
        'Newest scans appear first. Open a row for the full inspection result.',
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
  const _BatchScanTile({required this.scan, required this.repeated});
  final NfcScan scan;
  final bool repeated;
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
            ? 'Comparable identity unavailable; repeated-ID check skipped'
            : repeated
            ? 'Repeated comparable identifier in this batch'
            : (scan.technologies.isEmpty
                  ? 'Technology not reported'
                  : scan.technologies.join(', ')),
      ),
      trailing: repeated
          ? const Chip(
              visualDensity: VisualDensity.compact,
              label: Text('REPEATED ID'),
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
              builder: (BuildContext context) => ScanDetailPage(scan: scan),
            ),
          ),
        );
      },
    );
  }
}

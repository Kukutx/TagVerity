import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/byte_utils.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/models/nfc_scan.dart';
import '../../domain/models/tag_assessment.dart';
import '../../domain/services/tag_assessor.dart';
import '../controllers/nfc_scan_controller.dart';
import '../widgets/section_card.dart';
import 'scan_detail_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({required this.controller, super.key});
  final NfcScanController controller;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final List<NfcScan> history = widget.controller.history;
        final String normalized = _query.trim().toLowerCase();
        final List<NfcScan> filtered = normalized.isEmpty
            ? history
            : history
                  .where((NfcScan scan) => _matches(scan, normalized))
                  .toList(growable: false);
        final int itemCount = filtered.isEmpty ? 2 : filtered.length + 1;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          itemCount: itemCount,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return _HistoryHeader(
                controller: widget.controller,
                historyCount: history.length,
                onQueryChanged: (String value) =>
                    setState(() => _query = value),
                onClear: () => _confirmClear(context),
              );
            }
            if (filtered.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: SectionCard(
                  child: history.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 28),
                            child: Column(
                              children: <Widget>[
                                Icon(Icons.history_rounded, size: 48),
                                SizedBox(height: 10),
                                Text('No scans yet'),
                              ],
                            ),
                          ),
                        )
                      : const Text('No history entries match this search.'),
                ),
              );
            }
            final NfcScan scan = filtered[index - 1];
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _HistoryTile(controller: widget.controller, scan: scan),
            );
          },
        );
      },
    );
  }

  bool _matches(NfcScan scan, String query) {
    final String haystack = <String>[
      scan.uidHex ?? '',
      scan.uidFingerprint,
      scan.platform,
      ...scan.technologies,
      ...scan.details.values,
      ...scan.ndefRecords.map((record) => record.summary),
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  Future<void> _confirmClear(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Clear scan history?'),
        content: const Text(
          'This removes saved scans from this device. It does not change NFC tags.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final bool cleared = await widget.controller.clearHistory();
    if (cleared && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('History cleared')));
    }
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.controller,
    required this.historyCount,
    required this.onQueryChanged,
    required this.onClear,
  });
  final NfcScanController controller;
  final int historyCount;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Scan history',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            '$historyCount saved scan${historyCount == 1 ? '' : 's'}. '
            'Sensitive identifiers are minimized by default.',
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search_rounded),
              hintText: 'Search tags, technology, or content',
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: historyCount == 0
                    ? null
                    : () async {
                        await controller.copyHistoryJson();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('History JSON copied'),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.copy_all_rounded),
                label: const Text('Copy JSON'),
              ),
              OutlinedButton.icon(
                onPressed: historyCount == 0
                    ? null
                    : () => unawaited(controller.shareHistoryJson()),
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share'),
              ),
              OutlinedButton.icon(
                onPressed: historyCount == 0 ? null : onClear,
                icon: const Icon(Icons.delete_sweep_rounded),
                label: const Text('Clear'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.controller, required this.scan});
  final NfcScanController controller;
  final NfcScan scan;
  @override
  Widget build(BuildContext context) {
    final TagAssessment assessment = TagAssessor.assess(scan);
    final IconData statusIcon = switch (assessment.status) {
      TagAssessmentStatus.healthy => Icons.check_circle_rounded,
      TagAssessmentStatus.limited => Icons.info_rounded,
      TagAssessmentStatus.review => Icons.warning_amber_rounded,
    };
    return Dismissible(
      key: ValueKey<String>(scan.id),
      direction: DismissDirection.endToStart,
      background: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 24),
            child: Icon(Icons.delete_rounded),
          ),
        ),
      ),
      confirmDismiss: (DismissDirection direction) async {
        return controller.deleteHistoryItem(scan.id);
      },
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          leading: CircleAvatar(child: Icon(statusIcon)),
          title: Text(
            scan.uidHex == null
                ? 'Tag ${ByteUtils.shortFingerprint(scan.uidFingerprint)}'
                : ByteUtils.maskUid(scan.uidHex),
          ),
          subtitle: Text(
            '${DateTimeUtils.formatLocal(scan.scannedAt)}\n'
            '${scan.technologies.isEmpty ? scan.platform : scan.technologies.join(', ')}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            unawaited(
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => ScanDetailPage(scan: scan),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

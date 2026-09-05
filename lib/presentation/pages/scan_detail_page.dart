import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/byte_utils.dart';
import '../../core/utils/date_time_utils.dart';
import '../../domain/models/ndef_record_info.dart';
import '../../domain/models/nfc_scan.dart';
import '../../domain/models/tag_fact_catalog.dart';
import '../../domain/models/tag_identity_stability.dart';
import '../../domain/services/tag_assessor.dart';
import '../../domain/services/tag_classifier.dart';
import '../widgets/key_value_row.dart';
import '../widgets/section_card.dart';
import '../widgets/tag_assessment_card.dart';

class ScanDetailPage extends StatefulWidget {
  const ScanDetailPage({required this.scan, super.key});
  final NfcScan scan;
  @override
  State<ScanDetailPage> createState() => _ScanDetailPageState();
}

class _ScanDetailPageState extends State<ScanDetailPage> {
  bool _showAdvancedFields = false;
  @override
  Widget build(BuildContext context) {
    final NfcScan scan = widget.scan;
    final classification = TagClassifier.classify(scan);
    final List<MapEntry<String, String>> details = scan.details.entries
        .where(
          (MapEntry<String, String> entry) =>
              _showAdvancedFields || !TagFactCatalog.isAdvanced(entry.key),
        )
        .toList(growable: false);
    final bool hasAdvancedFields = scan.details.keys.any(
      TagFactCatalog.isAdvanced,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tag details'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Copy JSON',
            onPressed: () async {
              final String text = const JsonEncoder.withIndent('  ')
                  .convert(scan.toJson());
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scan JSON copied')),
                );
              }
            },
            icon: const Icon(Icons.data_object_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: <Widget>[
          TagAssessmentCard(assessment: TagAssessor.assess(scan)),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Identity',
            child: Column(
              children: <Widget>[
                KeyValueRow(
                  label: 'Scanned',
                  value: DateTimeUtils.formatLocal(scan.scannedAt),
                ),
                KeyValueRow(label: 'Platform', value: scan.platform),
                KeyValueRow(
                  label: 'Identity comparability',
                  value: scan.identityStability.label,
                ),
                KeyValueRow(
                  label: 'UID',
                  value: scan.uidHex ?? 'Not exposed by this platform',
                  copyable: scan.uidHex != null,
                ),
                KeyValueRow(
                  label: 'Fingerprint',
                  value: scan.uidFingerprint,
                  copyable: true,
                ),
                KeyValueRow(
                  label: 'Short fingerprint',
                  value: ByteUtils.shortFingerprint(scan.uidFingerprint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Classification',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                KeyValueRow(label: 'Likely type', value: classification.label),
                const SizedBox(height: 8),
                Text(classification.detail),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Technology',
            child: scan.technologies.isEmpty
                ? const Text(
                    'The operating system did not report a technology stack.',
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: scan.technologies
                        .map((String value) => Chip(label: Text(value)))
                        .toList(growable: false),
                  ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Public tag data',
            trailing: hasAdvancedFields
                ? TextButton(
                    onPressed: () => setState(
                      () => _showAdvancedFields = !_showAdvancedFields,
                    ),
                    child: Text(
                      _showAdvancedFields ? 'Hide technical' : 'Show technical',
                    ),
                  )
                : null,
            child: details.isEmpty
                ? const Text('No additional public tag data was exposed.')
                : Column(
                    children: details
                        .map(
                          (MapEntry<String, String> entry) => KeyValueRow(
                            label: TagFactCatalog.label(entry.key),
                            value: entry.value,
                          ),
                        )
                        .toList(growable: false),
                  ),
          ),
          if (scan.ndefRecords.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            SectionCard(
              title: 'NDEF records',
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: scan.ndefRecords
                    .map(
                      (NdefRecordInfo record) =>
                          _NdefRecordTile(record: record),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          if (scan.warnings.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            SectionCard(
              title: 'Read warnings',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: scan.warnings
                    .map(
                      (String warning) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(Icons.warning_amber_rounded, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(warning)),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const _ScopeNotice(),
        ],
      ),
    );
  }
}

class _NdefRecordTile extends StatelessWidget {
  const _NdefRecordTile({required this.record});
  final NdefRecordInfo record;
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text('Record ${record.index + 1} · ${record.type}'),
      subtitle: Text(
        record.summary,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      children: <Widget>[
        KeyValueRow(label: 'TNF', value: record.typeNameFormat),
        KeyValueRow(label: 'Type', value: record.type),
        KeyValueRow(label: 'Identifier', value: record.identifierHex),
        KeyValueRow(
          label: 'Payload length',
          value: '${record.payloadLength} bytes',
        ),
        KeyValueRow(
          label: 'Record length',
          value: '${record.byteLength} bytes',
        ),
        KeyValueRow(label: 'Payload preview', value: record.payloadPreviewHex),
      ],
    );
  }
}

class _ScopeNotice extends StatelessWidget {
  const _ScopeNotice();
  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'TagVerity reports information exposed by the phone and standard NDEF. '
          'A successful read does not prove ownership, authenticity, access rights, or '
          'the validity of a proprietary card system.',
        ),
      ),
    );
  }
}

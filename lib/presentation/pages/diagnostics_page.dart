import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/nfc_support_status.dart';
import '../controllers/nfc_scan_controller.dart';
import '../widgets/key_value_row.dart';
import '../widgets/section_card.dart';

class DiagnosticsPage extends StatelessWidget {
  const DiagnosticsPage({required this.controller, super.key});
  final NfcScanController controller;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics')),
      body: ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, Widget? child) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: <Widget>[
              SectionCard(
                title: 'Runtime',
                child: Column(
                  children: <Widget>[
                    const KeyValueRow(
                      label: 'App version',
                      value: AppConstants.appVersion,
                    ),
                    const KeyValueRow(
                      label: 'Flutter baseline',
                      value: AppConstants.flutterBaseline,
                    ),
                    const KeyValueRow(
                      label: 'Dart baseline',
                      value: AppConstants.dartBaseline,
                    ),
                    KeyValueRow(
                      label: 'Platform',
                      value: Platform.operatingSystem,
                    ),
                    KeyValueRow(
                      label: 'NFC',
                      value: controller.supportStatus.label,
                    ),
                    const KeyValueRow(
                      label: 'Polling',
                      value: 'ISO 14443 · ISO 15693 · ISO 18092',
                    ),
                    const KeyValueRow(label: 'Network access', value: 'None'),
                    const KeyValueRow(
                      label: 'Tag writing',
                      value: 'Not implemented',
                    ),
                    const KeyValueRow(
                      label: 'Card emulation',
                      value: 'Not implemented',
                    ),
                    KeyValueRow(
                      label: 'Diagnostic events',
                      value:
                          '${controller.diagnosticEvents.length} / '
                          '${AppConstants.maximumDiagnosticEvents}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SectionCard(
                title: 'Diagnostic log',
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await controller.copyDiagnosticsJson();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Diagnostics JSON copied'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.bug_report_outlined),
                        label: const Text('Copy'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.diagnosticEvents.isEmpty
                            ? null
                            : controller.clearDiagnostics,
                        icon: const Icon(Icons.clear_all_rounded),
                        label: const Text('Clear'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const SectionCard(
                child: Text(
                  'Diagnostics are kept in memory only and redact common long hex identifiers. '
                  'They are never uploaded automatically.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

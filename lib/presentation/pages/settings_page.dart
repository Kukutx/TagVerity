import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../domain/models/nfc_support_status.dart';
import '../../domain/models/scan_settings.dart';
import '../controllers/nfc_scan_controller.dart';
import '../widgets/key_value_row.dart';
import '../widgets/section_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.controller, super.key});

  final NfcScanController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final ScanSettings settings = controller.settings;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            SectionCard(
              title: 'Scanning',
              child: Column(
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Read standard NDEF'),
                    subtitle: const Text(
                      'Read-only; TagVerity never writes or formats tags',
                    ),
                    value: settings.readNdef,
                    onChanged: (bool value) {
                      unawaited(
                        controller.updateSettings(
                          settings.copyWith(readNdef: value),
                        ),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Use system NFC sounds'),
                    value: settings.platformSounds,
                    onChanged: (bool value) {
                      unawaited(
                        controller.updateSettings(
                          settings.copyWith(platformSounds: value),
                        ),
                      );
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show advanced public fields'),
                    subtitle: const Text(
                      'Includes low-level capability and timing values',
                    ),
                    value: settings.showAdvancedFields,
                    onChanged: (bool value) {
                      unawaited(
                        controller.updateSettings(
                          settings.copyWith(showAdvancedFields: value),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: ValueKey<int>(settings.scanTimeoutSeconds),
                    initialValue: settings.scanTimeoutSeconds,
                    decoration: const InputDecoration(
                      labelText: 'Scan timeout',
                    ),
                    items: const <int>[10, 20, 30, 60, 120]
                        .map(
                          (int value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value seconds'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (int? value) {
                      if (value != null) {
                        unawaited(
                          controller.updateSettings(
                            settings.copyWith(scanTimeoutSeconds: value),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Privacy & history',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save raw UID in history'),
                    subtitle: const Text('Off by default'),
                    value: settings.saveRawUidInHistory,
                    onChanged: (bool value) {
                      unawaited(_changeRawUidSetting(context, value));
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save NDEF content in history'),
                    subtitle: const Text('Off by default'),
                    value: settings.saveNdefInHistory,
                    onChanged: (bool value) {
                      unawaited(_changeNdefHistorySetting(context, value));
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save linkable technical identifiers'),
                    subtitle: const Text(
                      'Off by default; not needed for normal inspection',
                    ),
                    value: settings.saveTechnicalIdentifiersInHistory,
                    onChanged: (bool value) {
                      unawaited(
                        _changeTechnicalIdentifierSetting(context, value),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    key: ValueKey<int>(settings.historyLimit),
                    initialValue: settings.historyLimit,
                    decoration: const InputDecoration(
                      labelText: 'Maximum history',
                    ),
                    items: const <int>[25, 50, 100, 200, 500]
                        .map(
                          (int value) => DropdownMenuItem<int>(
                            value: value,
                            child: Text('$value scans'),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (int? value) {
                      if (value != null) {
                        unawaited(
                          controller.updateSettings(
                            settings.copyWith(historyLimit: value),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: controller.history.isEmpty
                        ? null
                        : () async {
                            await controller.scrubRawUidsFromHistory();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Raw UIDs removed from history',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Remove saved raw UIDs'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: controller.history.isEmpty
                        ? null
                        : () async {
                            await controller.scrubNdefFromHistory();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'NDEF content removed from history',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Remove saved NDEF content'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: controller.history.isEmpty
                        ? null
                        : () async {
                            await controller
                                .scrubTechnicalIdentifiersFromHistory();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Linkable technical identifiers removed',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.shield_outlined),
                    label: const Text('Remove technical identifiers'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Diagnostics',
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
                  const KeyValueRow(label: 'Polling', value: 'ISO 14443'),
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
                  const SizedBox(height: 12),
                  Row(
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
                          label: const Text('Copy diagnostics'),
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
                ],
              ),
            ),
            const SizedBox(height: 14),
            const SectionCard(
              title: 'About TagVerity',
              child: Text(
                'A privacy-first, read-only NFC inspector for checking individual tags and '
                'small batches. No account, no ads, no telemetry, and no background uploads.',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _changeRawUidSetting(BuildContext context, bool value) async {
    if (!value) {
      await controller.updateSettings(
        controller.settings.copyWith(saveRawUidInHistory: false),
      );
      return;
    }
    if (await _confirmSensitiveSetting(
          context,
          'Save raw UID?',
          'A raw UID can remain associated with the same physical tag. Enable this only if you need it.',
        ) ==
        true) {
      await controller.updateSettings(
        controller.settings.copyWith(saveRawUidInHistory: true),
      );
    }
  }

  Future<void> _changeNdefHistorySetting(
    BuildContext context,
    bool value,
  ) async {
    if (!value) {
      await controller.updateSettings(
        controller.settings.copyWith(saveNdefInHistory: false),
      );
      return;
    }
    if (await _confirmSensitiveSetting(
          context,
          'Save NDEF content?',
          'NDEF may contain text, URLs, contact information, or other public payloads.',
        ) ==
        true) {
      await controller.updateSettings(
        controller.settings.copyWith(saveNdefInHistory: true),
      );
    }
  }

  Future<void> _changeTechnicalIdentifierSetting(
    BuildContext context,
    bool value,
  ) async {
    if (!value) {
      await controller.updateSettings(
        controller.settings.copyWith(saveTechnicalIdentifiersInHistory: false),
      );
      return;
    }
    if (await _confirmSensitiveSetting(
          context,
          'Save technical identifiers?',
          'Some public protocol fields may help correlate the same tag or card over time.',
        ) ==
        true) {
      await controller.updateSettings(
        controller.settings.copyWith(saveTechnicalIdentifiersInHistory: true),
      );
    }
  }

  Future<bool?> _confirmSensitiveSetting(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}

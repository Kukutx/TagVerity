import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/models/scan_settings.dart';
import '../controllers/nfc_scan_controller.dart';
import '../widgets/section_card.dart';
import 'diagnostics_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.controller, super.key});
  final NfcScanController controller;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        final ScanSettings settings = controller.settings;
        final bool settingsBusy = controller.settingsBusy;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: <Widget>[
            SectionCard(
              title: 'Scanning',
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Read standard NDEF'),
                subtitle: const Text(
                  'Read-only; TagVerity never writes or formats tags',
                ),
                value: settings.readNdef,
                onChanged: settingsBusy
                    ? null
                    : (bool value) => unawaited(
                        controller.updateSettings(
                          (ScanSettings current) =>
                              current.copyWith(readNdef: value),
                        ),
                      ),
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
                    onChanged: settingsBusy
                        ? null
                        : (bool value) => unawaited(
                            _changeSensitiveSetting(
                              context,
                              value: value,
                              title: 'Save raw UID?',
                              message: 'A raw UID can remain associated with the same physical tag. Enable this only if you need it.',
                              update: (ScanSettings current) =>
                                  current.copyWith(saveRawUidInHistory: value),
                            ),
                          ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save NDEF content in history'),
                    subtitle: const Text('Off by default'),
                    value: settings.saveNdefInHistory,
                    onChanged: settingsBusy
                        ? null
                        : (bool value) => unawaited(
                            _changeSensitiveSetting(
                              context,
                              value: value,
                              title: 'Save NDEF content?',
                              message: 'NDEF may contain text, URLs, contact information, or other public payloads.',
                              update: (ScanSettings current) =>
                                  current.copyWith(saveNdefInHistory: value),
                            ),
                          ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save linkable technical identifiers'),
                    subtitle: const Text(
                      'Off by default; not needed for normal inspection',
                    ),
                    value: settings.saveTechnicalIdentifiersInHistory,
                    onChanged: settingsBusy
                        ? null
                        : (bool value) => unawaited(
                            _changeSensitiveSetting(
                              context,
                              value: value,
                              title: 'Save technical identifiers?',
                              message: 'Some public protocol fields may help correlate the same tag or card over time.',
                              update: (ScanSettings current) =>
                                  current.copyWith(
                                    saveTechnicalIdentifiersInHistory: value,
                                  ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: settingsBusy || controller.history.isEmpty
                        ? null
                        : () async {
                            final bool removed = await controller
                                .scrubSensitiveHistory();
                            if (removed && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Sensitive saved history data removed',
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Remove sensitive saved data'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SectionCard(
              title: 'Support',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Diagnostics'),
                subtitle: const Text(
                  'NFC status, runtime information, and privacy-safe event log',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  unawaited(
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (BuildContext context) =>
                            DiagnosticsPage(controller: controller),
                      ),
                    ),
                  );
                },
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

  Future<void> _changeSensitiveSetting(
    BuildContext context, {
    required bool value,
    required String title,
    required String message,
    required ScanSettings Function(ScanSettings current) update,
  }) async {
    if (value) {
      final bool? confirmed = await _confirmSensitiveSetting(
        context,
        title,
        message,
      );
      if (confirmed != true) {
        return;
      }
    }
    final bool saved = await controller.updateSettings(update);
    if (saved && !value && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setting disabled; matching saved data was removed'),
        ),
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

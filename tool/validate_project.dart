import 'dart:convert';
import 'dart:io';

void main() {
  final String pubspec = File('pubspec.yaml').readAsStringSync();
  final String constants = File('lib/core/constants/app_constants.dart')
      .readAsStringSync();
  final Map<String, dynamic> scanSchema = jsonDecode(
    File('docs/nfc-scan-export.schema.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final Map<String, dynamic> diagnosticsSchema = jsonDecode(
    File('docs/diagnostics-export.schema.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final RegExpMatch? pubspecVersion = RegExp(
    r'^version:\s*([^+\s]+)(?:\+\d+)?\s*$',
    multiLine: true,
  ).firstMatch(pubspec);
  final RegExpMatch? appVersion = RegExp(r"appVersion\s*=\s*'([^']+)'")
      .firstMatch(constants);
  if (pubspecVersion == null || appVersion == null) {
    _fail('Could not locate project version metadata.');
  }
  if (pubspecVersion.group(1) != appVersion.group(1)) {
    _fail(
      'Version mismatch: pubspec=${pubspecVersion.group(1)}, '
      'AppConstants=${appVersion.group(1)}',
    );
  }
  final int scanVersion = _constantInt(constants, 'exportSchemaVersion');
  final int diagnosticsVersion = _constantInt(
    constants,
    'diagnosticsSchemaVersion',
  );
  final int? scanSchemaVersion =
      ((scanSchema['properties'] as Map<String, dynamic>)['schemaVersion']
              as Map<String, dynamic>)['const']
          as int?;
  final int? diagnosticsSchemaVersion =
      ((diagnosticsSchema['properties']
                  as Map<String, dynamic>)['schemaVersion']
              as Map<String, dynamic>)['const']
          as int?;
  if (scanSchemaVersion != scanVersion) {
    _fail(
      'Scan schema mismatch: constants=$scanVersion, schema=$scanSchemaVersion',
    );
  }
  if (diagnosticsSchemaVersion != diagnosticsVersion) {
    _fail(
      'Diagnostics schema mismatch: constants=$diagnosticsVersion, '
      'schema=$diagnosticsSchemaVersion',
    );
  }
  final Map<String, dynamic> diagnosticSettings =
      ((diagnosticsSchema['properties'] as Map<String, dynamic>)['settings']
          as Map<String, dynamic>);
  final Set<String> requiredSettings =
      (diagnosticSettings['required'] as List<dynamic>)
          .whereType<String>()
          .toSet();
  const Set<String> expectedSettings = <String>{
    'readNdef',
    'saveRawUidInHistory',
    'saveNdefInHistory',
    'saveTechnicalIdentifiersInHistory',
  };
  if (requiredSettings.length != expectedSettings.length ||
      !requiredSettings.containsAll(expectedSettings)) {
    _fail('Diagnostics schema settings no longer match ScanSettings.');
  }
  final String infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  if (!infoPlist.contains(
        'com.apple.developer.nfc.readersession.felica.systemcodes',
      ) ||
      !infoPlist.contains('<string>12FC</string>')) {
    _fail('iOS NFC-F Type 3 system code 12FC is missing from Info.plist.');
  }
  stdout.writeln(
    'Project metadata OK: version ${appVersion.group(1)}, '
    'scan schema $scanVersion, diagnostics schema $diagnosticsVersion.',
  );
}

int _constantInt(String source, String name) {
  final RegExpMatch? match = RegExp('$name\\s*=\\s*(\\d+)').firstMatch(source);
  if (match == null) {
    _fail('Could not locate $name in AppConstants.');
  }
  return int.parse(match.group(1)!);
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

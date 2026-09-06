import 'dart:convert';
import 'dart:io';

void main() {
  final String pubspec = File('pubspec.yaml').readAsStringSync();
  final String constants = File('lib/core/constants/app_constants.dart')
      .readAsStringSync();
  final String scanContract = File('lib/domain/services/scan_contract.dart')
      .readAsStringSync();
  final String ciWorkflow = File('.github/workflows/ci.yml').readAsStringSync();
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
  final Map<String, dynamic> scanDefinitions =
      scanSchema[r'$defs'] as Map<String, dynamic>;
  final Map<String, dynamic> scanProperties =
      (scanDefinitions['scan'] as Map<String, dynamic>)['properties']
          as Map<String, dynamic>;
  final Map<String, dynamic> ndefProperties =
      (scanDefinitions['ndefRecord'] as Map<String, dynamic>)['properties']
          as Map<String, dynamic>;
  final String fingerprintPattern = _constantString(
    scanContract,
    '_fingerprintPatternSource',
  );
  final String uidHexPattern = _constantString(
    scanContract,
    '_uidHexPatternSource',
  );
  final String colonHexPattern = _constantString(
    scanContract,
    '_colonHexPatternSource',
  );
  final int maximumPayloadPreviewBytes = _constantInt(
    scanContract,
    '_maximumPayloadPreviewBytes',
  );
  final int maximumPayloadPreviewCharacters = maximumPayloadPreviewBytes == 0
      ? 0
      : maximumPayloadPreviewBytes * 3 - 1;
  if ((scanProperties['uidFingerprint'] as Map<String, dynamic>)['pattern'] !=
          fingerprintPattern ||
      (scanProperties['uidHex'] as Map<String, dynamic>)['pattern'] !=
          uidHexPattern ||
      (ndefProperties['identifierHex'] as Map<String, dynamic>)['pattern'] !=
          colonHexPattern ||
      (ndefProperties['payloadPreviewHex']
              as Map<String, dynamic>)['pattern'] !=
          colonHexPattern ||
      (ndefProperties['payloadPreviewHex']
              as Map<String, dynamic>)['maxLength'] !=
          maximumPayloadPreviewCharacters) {
    _fail(
      'Scan export schema constraints no longer match the runtime scan contract.',
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

  const List<String> requiredCiReleaseChecks = <String>[
    'flutter build appbundle --release --target-platform android-arm,android-arm64',
    'base/lib/armeabi-v7a/libapp.so',
    'base/lib/armeabi-v7a/libflutter.so',
    'base/lib/arm64-v8a/libapp.so',
    'base/lib/arm64-v8a/libflutter.so',
    'flutter build ios --release --no-codesign',
  ];
  for (final String required in requiredCiReleaseChecks) {
    if (!ciWorkflow.contains(required)) {
      _fail('CI release gate is missing: $required');
    }
  }
  if (RegExp(r'timeout-minutes:\s*20').allMatches(ciWorkflow).length < 2) {
    _fail('Both CI build jobs must keep a bounded 20-minute timeout.');
  }

  final String androidManifest = File(
    'android/app/src/main/AndroidManifest.xml',
  ).readAsStringSync();
  if (!androidManifest.contains('android:allowBackup="false"') ||
      !androidManifest.contains(
        'android:fullBackupContent="@xml/backup_rules"',
      ) ||
      !androidManifest.contains(
        'android:dataExtractionRules="@xml/data_extraction_rules"',
      )) {
    _fail('Android backup protections are missing from the release manifest.');
  }
  const Set<String> backupDomains = <String>{
    'root',
    'file',
    'database',
    'sharedpref',
    'external',
  };
  final String legacyBackupRules = File(
    'android/app/src/main/res/xml/backup_rules.xml',
  ).readAsStringSync();
  if (backupDomains.any(
    (String domain) => _backupExclusionCount(legacyBackupRules, domain) < 1,
  )) {
    _fail('Android 11-and-lower backup rules do not exclude all app data.');
  }
  final String dataExtractionRules = File(
    'android/app/src/main/res/xml/data_extraction_rules.xml',
  ).readAsStringSync();
  if (!dataExtractionRules.contains('<cloud-backup>') ||
      !dataExtractionRules.contains('<device-transfer>') ||
      backupDomains.any(
        (String domain) =>
            _backupExclusionCount(dataExtractionRules, domain) < 2,
      )) {
    _fail('Android 12+ cloud/D2D rules do not exclude all app data.');
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

int _backupExclusionCount(String source, String domain) {
  return RegExp('<exclude\\s+domain="$domain"\\s+path="\\."\\s*/>')
      .allMatches(source)
      .length;
}

int _constantInt(String source, String name) {
  final RegExpMatch? match = RegExp('$name\\s*=\\s*(\\d+)').firstMatch(source);
  if (match == null) {
    _fail('Could not locate integer constant $name.');
  }
  return int.parse(match.group(1)!);
}

String _constantString(String source, String name) {
  final RegExpMatch? match = RegExp("$name\\s*=\\s*r?'([^']*)'")
      .firstMatch(source);
  if (match == null) {
    _fail('Could not locate string constant $name.');
  }
  return match.group(1)!;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}

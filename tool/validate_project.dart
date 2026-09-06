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
    'base/manifest/AndroidManifest.xml',
    'android.permission.NFC',
    'android.hardware.nfc',
    'android.permission.INTERNET',
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
  if (!RegExp(
        r'<uses-permission\s+android:name="android\.permission\.NFC"\s*/>',
      ).hasMatch(androidManifest) ||
      !RegExp(
        r'<uses-feature\s+android:name="android\.hardware\.nfc"\s+android:required="true"\s*/>',
      ).hasMatch(androidManifest)) {
    _fail('Android release manifest must require NFC hardware and permission.');
  }
  final String fileProviderPaths = File(
    'android/app/src/main/res/xml/file_paths.xml',
  ).readAsStringSync();
  final List<RegExpMatch> sharedPathEntries = RegExp(
    r'<(?:cache-path|files-path|external-path|root-path|external-files-path|external-cache-path)\b',
  ).allMatches(fileProviderPaths).toList(growable: false);
  if (sharedPathEntries.length != 1 ||
      !RegExp(r'<cache-path\s+name="exports"\s+path="exports/"\s*/>')
          .hasMatch(fileProviderPaths)) {
    _fail('Android FileProvider must expose only cache/exports/.');
  }
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
  final String usageDescription =
      _plistStringValue(infoPlist, 'NFCReaderUsageDescription') ?? '';
  if (usageDescription.trim().isEmpty) {
    _fail('iOS NFCReaderUsageDescription is missing or empty.');
  }
  if (!_plistArrayContains(
    infoPlist,
    'com.apple.developer.nfc.readersession.felica.systemcodes',
    '12FC',
  )) {
    _fail('iOS NFC-F Type 3 system code 12FC is missing from Info.plist.');
  }
  if (!_plistArrayContains(
    infoPlist,
    'com.apple.developer.nfc.readersession.iso7816.select-identifiers',
    'D2760000850101',
  )) {
    _fail('iOS NFC Forum Type 4 / NDEF AID is missing from Info.plist.');
  }
  final String entitlements = File('ios/Runner/Runner.entitlements')
      .readAsStringSync();
  if (!_plistArrayContains(
    entitlements,
    'com.apple.developer.nfc.readersession.formats',
    'TAG',
  )) {
    _fail('iOS NFC TAG reader-session entitlement is missing.');
  }
  final String xcodeProject = File('ios/Runner.xcodeproj/project.pbxproj')
      .readAsStringSync();
  const Set<String> expectedAppConfigurations = <String>{
    'Debug',
    'Profile',
    'Release',
  };
  final Set<String> wiredAppConfigurations = <String>{};
  final RegExp buildConfiguration = RegExp(
    r'buildSettings = \{(.*?)\};\s*name = (Debug|Release|Profile);',
    dotAll: true,
  );
  for (final RegExpMatch match in buildConfiguration.allMatches(xcodeProject)) {
    final String block = match.group(1)!;
    final String configuration = match.group(2)!;
    if (!block.contains('PRODUCT_BUNDLE_IDENTIFIER = dev.kukutx.tagverity;')) {
      continue;
    }
    wiredAppConfigurations.add(configuration);
    if (!block.contains('INFOPLIST_FILE = Runner/Info.plist;') ||
        !block.contains(
          'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;',
        )) {
      _fail(
        'iOS $configuration app configuration is not wired to the NFC plist/entitlements.',
      );
    }
  }
  if (wiredAppConfigurations.length != expectedAppConfigurations.length ||
      !wiredAppConfigurations.containsAll(expectedAppConfigurations)) {
    _fail(
      'iOS app Debug/Profile/Release NFC configuration wiring is incomplete.',
    );
  }
  stdout.writeln(
    'Project metadata OK: version ${appVersion.group(1)}, '
    'scan schema $scanVersion, diagnostics schema $diagnosticsVersion.',
  );
}

String? _plistStringValue(String source, String key) {
  final RegExpMatch? match = RegExp(
    '<key>\\s*${RegExp.escape(key)}\\s*</key>\\s*<string>(.*?)</string>',
    dotAll: true,
  ).firstMatch(source);
  return match?.group(1);
}

bool _plistArrayContains(String source, String key, String value) {
  final RegExpMatch? match = RegExp(
    '<key>\\s*${RegExp.escape(key)}\\s*</key>\\s*<array>(.*?)</array>',
    dotAll: true,
  ).firstMatch(source);
  if (match == null) {
    return false;
  }
  return RegExp('<string>\\s*${RegExp.escape(value)}\\s*</string>')
      .hasMatch(match.group(1)!);
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

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:tagverity/data/storage/shared_preferences_scan_history_repository.dart';
import 'package:tagverity/domain/models/ndef_record_info.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';

import 'package:tagverity/domain/models/scan_settings.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';

void main() {
  group('SharedPreferencesScanHistoryRepository', () {
    test('round-trips current history and settings', () async {
      final store = InMemorySharedPreferencesAsync.empty();
      SharedPreferencesAsyncPlatform.instance = store;
      final prefs = SharedPreferencesAsync();
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: prefs,
      );
      final scan = _scan();

      await repository.saveHistory(<NfcScan>[scan]);
      await repository.saveSettings(
        const ScanSettings(readNdef: false, saveRawUidInHistory: true),
      );

      final history = await repository.loadHistory();
      final settings = await repository.loadSettings();

      expect(history, hasLength(1));
      expect(history.single.id, scan.id);
      expect(history.single.uidHex, scan.uidHex);
      expect(settings.readNdef, isFalse);
      expect(settings.saveRawUidInHistory, isTrue);
    });

    test('legacy history migrates with sensitive fields scrubbed', () async {
      final scan = _scan(id: '1780000000000000-abcdef123456');
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'nfc_inspector.history.v1': jsonEncode(<Object?>[scan.toJson()]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final prefs = SharedPreferencesAsync();
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: prefs,
      );

      final history = await repository.loadHistory();

      expect(history, hasLength(1));
      expect(history.single.id, isNot(scan.id));
      expect(history.single.id, contains('-migrated-1'));
      expect(history.single.id, isNot(contains('abcdef123456')));
      expect(history.single.uidHex, isNull);
      expect(history.single.uidFingerprint, isNot(scan.uidFingerprint));
      expect(history.single.uidFingerprint, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(
        history.single.identityStability,
        TagIdentityStability.sessionOnly,
      );
      expect(history.single.ndefRecords, isEmpty);
      expect(history.single.details['barcode.value'], isNull);
      expect(history.single.details['nfca.sak'], '0x08');
      expect(await prefs.getString('nfc_inspector.history.v1'), isNull);
      final String? migratedJson = await prefs.getString(
        'tagverity.history.v2',
      );
      expect(migratedJson, isNotNull);
      final List<dynamic> persisted =
          jsonDecode(migratedJson!) as List<dynamic>;
      final Map<String, dynamic> persistedScan =
          persisted.single as Map<String, dynamic>;
      expect(persistedScan['id'], history.single.id);
      expect(persistedScan['uidHex'], isNull);
      expect(persistedScan['uidFingerprint'], history.single.uidFingerprint);
      expect(persistedScan['identityStability'], 'sessionOnly');
    });

    test('legacy history is blanked before a failed key removal', () async {
      final NfcScan scan = _scan(id: '1780000000000000-abcdef123456');
      final String rawLegacy = jsonEncode(<Object?>[scan.toJson()]);
      final store = _FailLegacyHistoryClearStore(<String, Object>{
        'nfc_inspector.history.v1': rawLegacy,
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final prefs = SharedPreferencesAsync();
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: prefs,
      );

      final List<NfcScan> history = await repository.loadHistory();

      expect(history, hasLength(1));
      expect(await prefs.getString('nfc_inspector.history.v1'), '[]');
      expect(await prefs.getString('tagverity.history.v2'), isNotNull);
      expect(
        await prefs.getString('nfc_inspector.history.v1'),
        isNot(contains('04:AA:BB:CC')),
      );
    });

    test('legacy history removes raw warning error payloads', () async {
      final Map<String, Object?> json = _scan().toJson();
      json['warnings'] = <String>[
        'Could not read standard NDEF: private@example.com',
      ];
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'nfc_inspector.history.v1': jsonEncode(<Object?>[json]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      final List<NfcScan> history = await repository.loadHistory();

      expect(history.single.warnings, const <String>[
        'Could not read standard NDEF.',
      ]);
    });

    test('invalid JSON errors do not echo persisted scan content', () async {
      const String sensitive = 'private-ndef@example.com';
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': '{"payload":"$sensitive"',
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      try {
        await repository.loadHistory();
        fail('Expected malformed history to throw.');
      } on FormatException catch (error) {
        expect(error.message, 'Saved scan history is not valid JSON.');
        expect(error.toString(), isNot(contains(sensitive)));
      }
    });

    test('corrupt current history is reported instead of hidden', () async {
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': '{not-json',
        'nfc_inspector.history.v1': jsonEncode(<Object?>[_scan().toJson()]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test(
      'atomic clear keeps both history keys when storage clear fails',
      () async {
        final current = jsonEncode(<Object?>[_scan(id: 'current').toJson()]);
        final legacy = jsonEncode(<Object?>[_scan(id: 'legacy').toJson()]);
        final store = _FailCurrentHistoryClearStore(<String, Object>{
          'tagverity.history.v2': current,
          'nfc_inspector.history.v1': legacy,
        });
        SharedPreferencesAsyncPlatform.instance = store;
        final prefs = SharedPreferencesAsync();
        final repository = SharedPreferencesScanHistoryRepository(
          preferences: prefs,
        );

        await expectLater(repository.clearHistory(), throwsStateError);

        expect(await prefs.getString('nfc_inspector.history.v1'), legacy);
        expect(await prefs.getString('tagverity.history.v2'), current);
      },
    );

    test('empty current history is reported instead of falling back', () async {
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': '',
        'nfc_inspector.history.v1': jsonEncode(<Object?>[_scan().toJson()]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test('nested corrupt history fields are rejected', () async {
      final Map<String, Object?> json = _scan().toJson();
      json['technologies'] = <Object?>['NfcA', 42];
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(<Object?>[json]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test('schema-incompatible fingerprints are rejected', () async {
      final Map<String, Object?> json = _scan().toJson();
      json['uidFingerprint'] = 'not-a-sha256-fingerprint';
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(<Object?>[json]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test('invalid persisted raw UID format is rejected', () async {
      final Map<String, Object?> json = _scan().toJson();
      json['uidHex'] = 'not-a-byte-sequence';
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(<Object?>[json]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test('duplicate persisted scan IDs are rejected', () async {
      final Map<String, Object?> first = _scan(id: 'duplicate-id').toJson();
      final Map<String, Object?> second = _scan(id: 'duplicate-id').toJson();
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(<Object?>[first, second]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test('duplicate persisted NDEF indexes are rejected', () async {
      final Map<String, Object?> json = _scan().toJson();
      final List<dynamic> records = json['ndefRecords']! as List<dynamic>;
      json['ndefRecords'] = <Object?>[
        records.single,
        <String, Object?>{
          ...(records.single as Map<String, Object?>),
          'index': 0,
        },
      ];
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(<Object?>[json]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test(
      'invalid outgoing history is rejected before replacing saved data',
      () async {
        final store = InMemorySharedPreferencesAsync.withData(
          <String, Object>{},
        );
        SharedPreferencesAsyncPlatform.instance = store;
        final repository = SharedPreferencesScanHistoryRepository(
          preferences: SharedPreferencesAsync(),
        );
        final NfcScan original = _scan(id: 'original');
        await repository.saveHistory(<NfcScan>[original]);

        await expectLater(
          repository.saveHistory(<NfcScan>[
            _scan(id: 'duplicate-write'),
            _scan(id: 'duplicate-write'),
          ]),
          throwsFormatException,
        );

        final List<NfcScan> history = await repository.loadHistory();
        expect(history, hasLength(1));
        expect(history.single.id, 'original');
      },
    );

    test('unknown persisted scan fields are rejected', () async {
      final Map<String, Object?> json = _scan().toJson();
      json['futureTopLevelField'] = 'must not be silently dropped';
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(<Object?>[json]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test('unknown persisted NDEF record fields are rejected', () async {
      final Map<String, Object?> json = _scan().toJson();
      final List<dynamic> records = json['ndefRecords']! as List<dynamic>;
      final Map<String, Object?> record = Map<String, Object?>.from(
        records.single as Map,
      );
      record['futureRecordField'] = 'unknown';
      json['ndefRecords'] = <Object?>[record];
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(<Object?>[json]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test('early current v2 history infers comparable identity semantics', () async {
      final Map<String, Object?> stableJson = _scan(id: 'stable-old-v2')
          .toJson();
      stableJson.remove('identityStability');
      stableJson['uidFingerprint'] =
          '732f6986a0dc9a440072e6868883900086befc53f156041f3778bb763a3dbd95';
      final Map<String, Object?> sessionJson = _scan(id: 'session-old-v2')
          .toJson();
      sessionJson
        ..remove('identityStability')
        ..['uidHex'] = null
        ..['uidFingerprint'] =
            'baa768aac3b46551fa758b0590cf0490377ce167b7c1e6389ab1a680c302beb8';
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(<Object?>[stableJson, sessionJson]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      final List<NfcScan> history = await repository.loadHistory();
      expect(history, hasLength(2));
      expect(history[0].identityStability, TagIdentityStability.stable);
      expect(history[0].hasComparableIdentity, isTrue);
      expect(history[1].identityStability, TagIdentityStability.sessionOnly);
      expect(history[1].hasComparableIdentity, isFalse);
    });

    test('exactly 500 legacy-compatible history records still load', () async {
      final List<Object?> maximum = List<Object?>.generate(
        500,
        (int index) => _scan(id: 'max-$index').toJson(),
      );
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(maximum),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      final List<NfcScan> history = await repository.loadHistory();
      expect(history, hasLength(500));
    });

    test(
      'history record count is bounded to the legacy 500-record maximum',
      () async {
        final List<Object?> oversized = List<Object?>.generate(
          501,
          (int index) => _scan(id: 'scan-$index').toJson(),
        );
        final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
          'tagverity.history.v2': jsonEncode(oversized),
        });
        SharedPreferencesAsyncPlatform.instance = store;
        final repository = SharedPreferencesScanHistoryRepository(
          preferences: SharedPreferencesAsync(),
        );

        await expectLater(repository.loadHistory(), throwsFormatException);
        await expectLater(
          repository.saveHistory(
            List<NfcScan>.generate(
              501,
              (int index) => _scan(id: 'save-$index'),
            ),
          ),
          throwsFormatException,
        );
      },
    );

    test('duplicate persisted technologies are rejected', () async {
      final Map<String, Object?> json = _scan().toJson();
      json['technologies'] = <Object?>['NfcA', 'NfcA'];
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(<Object?>[json]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test('invalid persisted NDEF invariants are rejected', () async {
      Future<void> expectRejected(
        void Function(Map<String, Object?> record) mutate,
      ) async {
        final Map<String, Object?> json = _scan().toJson();
        final List<dynamic> records = json['ndefRecords']! as List<dynamic>;
        final Map<String, Object?> record = Map<String, Object?>.from(
          records.single as Map,
        );
        mutate(record);
        json['ndefRecords'] = <Object?>[record];
        final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
          'tagverity.history.v2': jsonEncode(<Object?>[json]),
        });
        SharedPreferencesAsyncPlatform.instance = store;
        final repository = SharedPreferencesScanHistoryRepository(
          preferences: SharedPreferencesAsync(),
        );

        await expectLater(repository.loadHistory(), throwsFormatException);
      }

      await expectRejected(
        (Map<String, Object?> record) => record['identifierHex'] = '0G',
      );
      await expectRejected(
        (Map<String, Object?> record) => record['payloadPreviewHex'] = '68:6Z',
      );
      await expectRejected(
        (Map<String, Object?> record) => record['payloadPreviewHex'] = '68:65',
      );
      await expectRejected(
        (Map<String, Object?> record) => record['byteLength'] = 4,
      );
      await expectRejected(
        (Map<String, Object?> record) => record['index'] = 1,
      );
    });

    test('corrupt nested NDEF records are rejected', () async {
      final Map<String, Object?> json = _scan().toJson();
      json['ndefRecords'] = <Object?>[
        <String, Object?>{
          'index': 0,
          'typeNameFormat': 'wellKnown',
          'type': 'T',
          'identifierHex': '',
          'payloadLength': 'not-an-int',
          'byteLength': 8,
          'summary': 'hello',
          'payloadPreviewHex': '68:65:6C:6C:6F',
        },
      ];
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.history.v2': jsonEncode(<Object?>[json]),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadHistory(), throwsFormatException);
    });

    test(
      'empty current settings are reported instead of falling back',
      () async {
        final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
          'tagverity.settings.v2': '',
          'nfc_inspector.settings.v1': jsonEncode(
            const ScanSettings().toJson(),
          ),
        });
        SharedPreferencesAsyncPlatform.instance = store;
        final repository = SharedPreferencesScanHistoryRepository(
          preferences: SharedPreferencesAsync(),
        );

        await expectLater(repository.loadSettings(), throwsFormatException);
      },
    );

    test('legacy settings migration survives a failed key removal', () async {
      final store = _FailLegacySettingsClearStore(<String, Object>{
        'nfc_inspector.settings.v1': jsonEncode(<String, Object?>{
          'readNdef': false,
          'saveRawUidInHistory': true,
          'saveNdefInHistory': false,
          'saveTechnicalIdentifiersInHistory': false,
          'platformSounds': false,
          'historyLimit': 500,
        }),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final prefs = SharedPreferencesAsync();
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: prefs,
      );

      final ScanSettings settings = await repository.loadSettings();

      expect(settings.readNdef, isFalse);
      expect(settings.saveRawUidInHistory, isTrue);
      expect(await prefs.getString('tagverity.settings.v2'), isNotNull);
      expect(await prefs.getString('nfc_inspector.settings.v1'), '{}');
    });

    test(
      'current settings load ignores stale legacy cleanup failure',
      () async {
        final store = _FailLegacySettingsClearStore(<String, Object>{
          'tagverity.settings.v2': jsonEncode(
            const ScanSettings(readNdef: false).toJson(),
          ),
          'nfc_inspector.settings.v1': jsonEncode(
            const ScanSettings(saveRawUidInHistory: true).toJson(),
          ),
        });
        SharedPreferencesAsyncPlatform.instance = store;
        final prefs = SharedPreferencesAsync();
        final repository = SharedPreferencesScanHistoryRepository(
          preferences: prefs,
        );

        final ScanSettings settings = await repository.loadSettings();

        expect(settings.readNdef, isFalse);
        expect(settings.saveRawUidInHistory, isFalse);
        expect(await prefs.getString('nfc_inspector.settings.v1'), '{}');
      },
    );

    test('early current v2 settings with removed fields still load', () async {
      final Map<String, Object?> json = <String, Object?>{
        ...const ScanSettings(readNdef: false).toJson(),
        'platformSounds': false,
        'showAdvancedFields': true,
        'scanTimeoutSeconds': 15,
        'historyLimit': 500,
      };
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.settings.v2': jsonEncode(json),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      final ScanSettings settings = await repository.loadSettings();

      expect(settings.readNdef, isFalse);
    });

    test('wrong setting value types are rejected', () async {
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.settings.v2': jsonEncode(<String, Object?>{
          'readNdef': 'yes',
          'saveRawUidInHistory': false,
        }),
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadSettings(), throwsFormatException);
    });

    test('corrupt settings are reported', () async {
      final store = InMemorySharedPreferencesAsync.withData(<String, Object>{
        'tagverity.settings.v2': '[]',
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final repository = SharedPreferencesScanHistoryRepository(
        preferences: SharedPreferencesAsync(),
      );

      await expectLater(repository.loadSettings(), throwsFormatException);
    });
  });
}

NfcScan _scan({String id = 'scan-1'}) {
  return NfcScan(
    id: id,
    scannedAt: DateTime.utc(2026, 9, 5),
    platform: 'android',
    uidHex: '04:AA:BB:CC',
    uidFingerprint:
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    identityStability: TagIdentityStability.stable,
    technologies: const <String>['NfcA'],
    details: const <String, String>{
      'nfca.sak': '0x08',
      'barcode.value': 'DE:AD:BE: EF',
      'ndef.supported': 'yes',
      'ndef.readStatus': 'ok',
      'ndef.recordCount': '1',
    },
    ndefRecords: const <NdefRecordInfo>[
      NdefRecordInfo(
        index: 0,
        typeNameFormat: 'wellKnown',
        type: 'T',
        identifierHex: '',
        payloadLength: 5,
        byteLength: 8,
        summary: 'hello',
        payloadPreviewHex: '68:65:6C:6C:6F',
      ),
    ],
    warnings: const <String>[],
  );
}

final class _FailCurrentHistoryClearStore
    extends InMemorySharedPreferencesAsync {
  _FailCurrentHistoryClearStore(super.data) : super.withData();

  @override
  Future<bool> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    if (parameters.filter.allowList?.contains('tagverity.history.v2') ??
        false) {
      throw StateError('simulated current-history clear failure');
    }
    return super.clear(parameters, options);
  }
}

final class _FailLegacyHistoryClearStore
    extends InMemorySharedPreferencesAsync {
  _FailLegacyHistoryClearStore(super.data) : super.withData();

  @override
  Future<bool> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    if (parameters.filter.allowList?.contains('nfc_inspector.history.v1') ??
        false) {
      throw StateError('simulated legacy-history remove failure');
    }
    return super.clear(parameters, options);
  }
}

final class _FailLegacySettingsClearStore
    extends InMemorySharedPreferencesAsync {
  _FailLegacySettingsClearStore(super.data) : super.withData();

  @override
  Future<bool> clear(
    ClearPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async {
    if (parameters.filter.allowList?.contains('nfc_inspector.settings.v1') ??
        false) {
      throw StateError('simulated legacy-settings remove failure');
    }
    return super.clear(parameters, options);
  }
}

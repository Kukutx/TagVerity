import 'package:flutter_test/flutter_test.dart';
import 'package:tagverity/domain/models/ndef_record_info.dart';
import 'package:tagverity/domain/models/nfc_scan.dart';
import 'package:tagverity/domain/models/tag_identity_stability.dart';
import 'package:tagverity/domain/services/scan_contract.dart';

void main() {
  test('valid scan satisfies the model-level contract', () {
    expect(() => ScanContract.validate(_scan()), returnsNormally);
  });

  test('scan contract rejects invalid fingerprint UID and duplicate tech', () {
    expect(
      () => ScanContract.validate(_scan().copyWith(uidFingerprint: 'not-sha')),
      throwsFormatException,
    );
    expect(
      () => ScanContract.validate(_scan().copyWith(uidHex: '04:+A')),
      throwsFormatException,
    );
    expect(
      () => ScanContract.validate(_scan().copyWith(uidFingerprint: 'f' * 64)),
      throwsFormatException,
    );
    expect(
      () => ScanContract.validate(
        _scan().copyWith(identityStability: TagIdentityStability.sessionOnly),
      ),
      throwsFormatException,
    );
    expect(
      () => ScanContract.validate(
        _scan().copyWith(technologies: const <String>['NfcA', 'NfcA']),
      ),
      throwsFormatException,
    );
  });

  test('scan contract rejects inconsistent NDEF metadata', () {
    final NdefRecordInfo record = _scan().ndefRecords.single;
    expect(
      () => ScanContract.validate(
        _scan().copyWith(
          ndefRecords: <NdefRecordInfo>[
            NdefRecordInfo(
              index: 1,
              typeNameFormat: record.typeNameFormat,
              type: record.type,
              identifierHex: record.identifierHex,
              payloadLength: record.payloadLength,
              byteLength: record.byteLength,
              summary: record.summary,
              payloadPreviewHex: record.payloadPreviewHex,
            ),
          ],
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => ScanContract.validate(
        _scan().copyWith(
          ndefRecords: <NdefRecordInfo>[
            NdefRecordInfo(
              index: 0,
              typeNameFormat: record.typeNameFormat,
              type: record.type,
              identifierHex: '0G',
              payloadLength: record.payloadLength,
              byteLength: record.byteLength,
              summary: record.summary,
              payloadPreviewHex: record.payloadPreviewHex,
            ),
          ],
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => ScanContract.validate(
        _scan().copyWith(
          ndefRecords: <NdefRecordInfo>[
            NdefRecordInfo(
              index: 0,
              typeNameFormat: record.typeNameFormat,
              type: record.type,
              identifierHex: record.identifierHex,
              payloadLength: 5,
              byteLength: 4,
              summary: record.summary,
              payloadPreviewHex: '68:65:6C:6C:6F',
            ),
          ],
        ),
      ),
      throwsFormatException,
    );
    expect(
      () => ScanContract.validate(
        _scan().copyWith(
          ndefRecords: <NdefRecordInfo>[
            NdefRecordInfo(
              index: 0,
              typeNameFormat: record.typeNameFormat,
              type: record.type,
              identifierHex: record.identifierHex,
              payloadLength: 5,
              byteLength: 8,
              summary: record.summary,
              payloadPreviewHex: '68:65',
            ),
          ],
        ),
      ),
      throwsFormatException,
    );
  });
}

NfcScan _scan() => NfcScan(
  id: 'scan-contract',
  scannedAt: DateTime.utc(2026, 9, 6),
  platform: 'android',
  uidHex: '04:AA:BB:CC',
  uidFingerprint:
      '732f6986a0dc9a440072e6868883900086befc53f156041f3778bb763a3dbd95',
  identityStability: TagIdentityStability.stable,
  technologies: const <String>['NfcA'],
  details: const <String, String>{},
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

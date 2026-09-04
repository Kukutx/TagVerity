import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

import '../../core/utils/byte_utils.dart';
import '../../core/utils/ndef_decoder.dart';
import '../../domain/models/ndef_record_info.dart';
import '../../domain/models/nfc_scan.dart';
import '../../domain/models/nfc_support_status.dart';
import '../../domain/models/scan_settings.dart';
import '../../domain/models/tag_identity_stability.dart';
import 'nfc_reader_service.dart';

final class NfcManagerReaderService implements NfcReaderService {
  bool _sessionActive = false;
  bool _terminalCallbackDelivered = false;
  Timer? _timeoutTimer;

  @override
  Future<NfcSupportStatus> checkAvailability() async {
    try {
      final NfcAvailability availability = await NfcManager.instance
          .checkAvailability();
      return switch (availability) {
        NfcAvailability.enabled => NfcSupportStatus.enabled,
        NfcAvailability.disabled => NfcSupportStatus.disabled,
        NfcAvailability.unsupported => NfcSupportStatus.unsupported,
      };
    } on Object {
      return NfcSupportStatus.unknown;
    }
  }

  @override
  Future<void> startScan({
    required ScanSettings settings,
    required ScanResultCallback onScan,
    required ScanErrorCallback onError,
  }) async {
    if (_sessionActive) {
      await stopScan();
    }

    _sessionActive = true;
    _terminalCallbackDelivered = false;
    _timeoutTimer?.cancel();

    try {
      await NfcManager.instance.startSession(
        pollingOptions: const <NfcPollingOption>{NfcPollingOption.iso14443},
        alertMessageIos: 'Hold the NFC tag near the top of your iPhone.',
        invalidateAfterFirstReadIos: true,
        noPlatformSoundsAndroid: !settings.platformSounds,
        onSessionErrorIos: (NfcReaderSessionErrorIos error) {
          _sessionActive = false;
          _timeoutTimer?.cancel();
          if (!_terminalCallbackDelivered) {
            _terminalCallbackDelivered = true;
            onError(_friendlyIosError(error));
          }
        },
        onDiscovered: (NfcTag tag) async {
          if (_terminalCallbackDelivered) {
            return;
          }
          _terminalCallbackDelivered = true;
          _timeoutTimer?.cancel();
          try {
            final NfcScan scan = await _inspectTag(tag, settings);
            await onScan(scan);
            await _stopNativeSession(alertMessageIos: 'Tag read successfully');
          } on Object catch (error) {
            onError('Could not inspect this tag: ${_cleanError(error)}');
            await _stopNativeSession(errorMessageIos: 'Tag read failed');
          }
        },
      );
      if (_sessionActive && !_terminalCallbackDelivered) {
        _timeoutTimer = Timer(
          Duration(seconds: settings.scanTimeoutSeconds),
          () {
            if (!_sessionActive || _terminalCallbackDelivered) {
              return;
            }
            _terminalCallbackDelivered = true;
            onError(
              'Scan timed out after ${settings.scanTimeoutSeconds} seconds. '
              'Move the tag and try again.',
            );
            unawaited(_stopNativeSession(errorMessageIos: 'Scan timed out'));
          },
        );
      }
    } on Object catch (error) {
      _sessionActive = false;
      _timeoutTimer?.cancel();
      onError('Could not start NFC scanning: ${_cleanError(error)}');
      rethrow;
    }
  }

  @override
  Future<void> stopScan() async {
    _terminalCallbackDelivered = true;
    _timeoutTimer?.cancel();
    if (!_sessionActive) {
      return;
    }
    await _stopNativeSession();
  }

  Future<void> _stopNativeSession({
    String? alertMessageIos,
    String? errorMessageIos,
  }) async {
    try {
      await NfcManager.instance.stopSession(
        alertMessageIos: alertMessageIos,
        errorMessageIos: errorMessageIos,
      );
    } on Object {
      // The OS may already have invalidated the NFC session.
    } finally {
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      _sessionActive = false;
    }
  }

  Future<NfcScan> _inspectTag(NfcTag tag, ScanSettings settings) async {
    final DateTime scannedAt = DateTime.now();
    final Map<String, String> details = <String, String>{};
    final List<String> technologies = <String>[];
    final List<String> warnings = <String>[];
    Uint8List? identifier;

    if (Platform.isAndroid) {
      final _PlatformInspection result = await _inspectAndroid(
        tag,
        details,
        technologies,
        warnings,
      );
      identifier = result.identifier;
    } else if (Platform.isIOS) {
      final _PlatformInspection result = _inspectIos(
        tag,
        details,
        technologies,
        warnings,
      );
      identifier = result.identifier;
    } else {
      throw UnsupportedError('TagVerity supports Android and iOS NFC devices.');
    }

    final List<NdefRecordInfo> ndefRecords = await _inspectNdef(
      tag,
      settings,
      details,
      warnings,
    );

    final bool stableIdentity = identifier != null && identifier.isNotEmpty;
    final List<int> fingerprintSource = stableIdentity
        ? identifier
        : utf8.encode(
            '${Platform.operatingSystem}|${technologies.join("|")}|'
            '${scannedAt.microsecondsSinceEpoch}',
          );
    final String fingerprint = sha256.convert(fingerprintSource).toString();
    final String? uidHex = stableIdentity ? ByteUtils.hex(identifier) : null;

    return NfcScan(
      id: '${scannedAt.microsecondsSinceEpoch}-${fingerprint.substring(0, 12)}',
      scannedAt: scannedAt,
      platform: Platform.operatingSystem,
      uidHex: uidHex,
      uidFingerprint: fingerprint,
      identityStability: stableIdentity
          ? TagIdentityStability.stable
          : TagIdentityStability.sessionOnly,
      technologies: technologies.toSet().toList(growable: false),
      details: details,
      ndefRecords: ndefRecords,
      warnings: warnings,
    );
  }

  Future<_PlatformInspection> _inspectAndroid(
    NfcTag tag,
    Map<String, String> details,
    List<String> technologies,
    List<String> warnings,
  ) async {
    final NfcTagAndroid? androidTag = NfcTagAndroid.from(tag);
    if (androidTag == null) {
      throw StateError('Android did not expose a readable NFC tag object.');
    }

    technologies.addAll(
      androidTag.techList.map((String value) => value.split('.').last),
    );

    await _guard('NFC-A metadata', warnings, () async {
      final NfcAAndroid? nfcA = NfcAAndroid.from(tag);
      if (nfcA == null) {
        return;
      }
      details['protocol'] = 'NFC-A / ISO 14443-3A';
      details['nfca.atqa'] = ByteUtils.hex(nfcA.atqa);
      details['nfca.sak'] =
          '0x${nfcA.sak.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      details['nfca.maxTransceiveLength'] =
          '${await nfcA.getMaxTransceiveLength()} bytes';
      details['nfca.timeout'] = '${await nfcA.getTimeout()} ms';
    });

    await _guard('NFC-B metadata', warnings, () async {
      final NfcBAndroid? nfcB = NfcBAndroid.from(tag);
      if (nfcB == null) {
        return;
      }
      details['protocol'] = 'NFC-B / ISO 14443-3B';
      details['nfcb.applicationData'] = ByteUtils.hex(nfcB.applicationData);
      details['nfcb.protocolInfo'] = ByteUtils.hex(nfcB.protocolInfo);
      details['nfcb.maxTransceiveLength'] =
          '${await nfcB.getMaxTransceiveLength()} bytes';
    });

    await _guard('ISO-DEP metadata', warnings, () async {
      final IsoDepAndroid? isoDep = IsoDepAndroid.from(tag);
      if (isoDep == null) {
        return;
      }
      technologies.add('ISO-DEP / ISO 14443-4');
      details['isodep.supported'] = 'yes';
      details['isodep.extendedLengthApduSupported'] =
          isoDep.isExtendedLengthApduSupported ? 'yes' : 'no';
      details['isodep.maxTransceiveLength'] =
          '${await isoDep.getMaxTransceiveLength()} bytes';
      details['isodep.timeout'] = '${await isoDep.getTimeout()} ms';
      if (isoDep.historicalBytes case final Uint8List value) {
        details['isodep.historicalBytes'] = ByteUtils.hex(value);
      }
      if (isoDep.hiLayerResponse case final Uint8List value) {
        details['isodep.hiLayerResponse'] = ByteUtils.hex(value);
      }
    });

    await _guard('MIFARE Ultralight metadata', warnings, () async {
      final MifareUltralightAndroid? ultralight = MifareUltralightAndroid.from(
        tag,
      );
      if (ultralight == null) {
        return;
      }
      details['mifare.ultralight.type'] = ultralight.type.name;
      details['mifare.ultralight.maxTransceiveLength'] =
          '${await ultralight.getMaxTransceiveLength()} bytes';
      details['mifare.ultralight.timeout'] =
          '${await ultralight.getTimeout()} ms';
    });

    await _guard('MIFARE Classic metadata', warnings, () async {
      final MifareClassicAndroid? classic = MifareClassicAndroid.from(tag);
      if (classic == null) {
        return;
      }
      details['mifare.classic.type'] = classic.type.name;
      details['mifare.classic.size'] = '${classic.size} bytes';
      details['mifare.classic.sectorCount'] = classic.sectorCount.toString();
      details['mifare.classic.blockCount'] = classic.blockCount.toString();
    });

    await _guard('NFC Barcode metadata', warnings, () async {
      final NfcBarcodeAndroid? barcode = NfcBarcodeAndroid.from(tag);
      if (barcode == null) {
        return;
      }
      details['barcode.type'] = barcode.type.name;
      details['barcode.value'] = ByteUtils.hex(barcode.barcode);
    });

    return _PlatformInspection(identifier: androidTag.id);
  }

  _PlatformInspection _inspectIos(
    NfcTag tag,
    Map<String, String> details,
    List<String> technologies,
    List<String> warnings,
  ) {
    Uint8List? identifier;

    try {
      final MiFareIos? mifare = MiFareIos.from(tag);
      if (mifare != null) {
        identifier = mifare.identifier;
        technologies.add('MiFareIos');
        details['ios.mifare.family'] = mifare.mifareFamily.name;
        if (mifare.historicalBytes case final Uint8List value) {
          details['ios.mifare.historicalBytes'] = ByteUtils.hex(value);
        }
      }
    } on Object catch (error) {
      warnings.add('Could not read iOS MIFARE metadata: ${_cleanError(error)}');
    }

    try {
      final Iso7816Ios? iso7816 = Iso7816Ios.from(tag);
      if (iso7816 != null) {
        identifier ??= iso7816.identifier;
        technologies.add('Iso7816Ios');
        details['ios.iso7816.supported'] = 'yes';
        details['ios.iso7816.initialSelectedAid'] =
            iso7816.initialSelectedAID.isEmpty
            ? 'not provided'
            : iso7816.initialSelectedAID;
        details['ios.iso7816.proprietaryApplicationDataCoding'] =
            iso7816.proprietaryApplicationDataCoding ? 'yes' : 'no';
        if (iso7816.applicationData case final Uint8List value) {
          details['ios.iso7816.applicationData'] = ByteUtils.hex(value);
        }
        if (iso7816.historicalBytes case final Uint8List value) {
          details['ios.iso7816.historicalBytes'] = ByteUtils.hex(value);
        }
      }
    } on Object catch (error) {
      warnings.add(
        'Could not read iOS ISO 7816 metadata: ${_cleanError(error)}',
      );
    }


    return _PlatformInspection(identifier: identifier);
  }

  Future<List<NdefRecordInfo>> _inspectNdef(
    NfcTag tag,
    ScanSettings settings,
    Map<String, String> details,
    List<String> warnings,
  ) async {
    try {
      final Ndef? ndef = Ndef.from(tag);
      if (ndef == null) {
        details['ndef.supported'] = 'no';
        details['ndef.readStatus'] = 'not-supported';
        return const <NdefRecordInfo>[];
      }

      details['ndef.supported'] = 'yes';
      details['ndef.maxSize'] = '${ndef.maxSize} bytes';
      details['ndef.writable'] = ndef.isWritable ? 'yes' : 'no';

      if (!settings.readNdef) {
        details['ndef.readEnabled'] = 'no';
        details['ndef.readStatus'] = 'disabled';
        return const <NdefRecordInfo>[];
      }
      details['ndef.readEnabled'] = 'yes';

      final NdefMessage? message = ndef.cachedMessage ?? await ndef.read();
      details['ndef.readStatus'] = 'ok';
      if (message == null) {
        details['ndef.messageLength'] = '0 bytes';
        details['ndef.recordCount'] = '0';
        return const <NdefRecordInfo>[];
      }

      details['ndef.messageLength'] = '${message.byteLength} bytes';
      details['ndef.recordCount'] = message.records.length.toString();
      return NdefDecoder.decodeMessage(message);
    } on Object catch (error) {
      details['ndef.readStatus'] = 'error';
      warnings.add('Could not read standard NDEF: ${_cleanError(error)}');
      return const <NdefRecordInfo>[];
    }
  }

  Future<void> _guard(
    String label,
    List<String> warnings,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } on Object catch (error) {
      warnings.add('$label read failed: ${_cleanError(error)}');
    }
  }

  String _friendlyIosError(NfcReaderSessionErrorIos error) {
    final String message = error.message.trim();
    return message.isEmpty
        ? 'The iOS NFC session ended (${error.code.name}).'
        : message;
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst(RegExp(r'^(Exception|StateError):\s*'), '')
        .trim();
  }
}

final class _PlatformInspection {
  const _PlatformInspection({required this.identifier});

  final Uint8List? identifier;
}

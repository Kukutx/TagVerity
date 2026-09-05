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

import '../../core/constants/app_constants.dart';
import '../../core/utils/byte_utils.dart';
import '../../core/utils/error_text.dart';
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
        pollingOptions: const <NfcPollingOption>{
          NfcPollingOption.iso14443,
          NfcPollingOption.iso15693,
          NfcPollingOption.iso18092,
        },
        alertMessageIos: 'Hold the NFC tag near the top of your iPhone.',
        invalidateAfterFirstReadIos: true,
        noPlatformSoundsAndroid: false,
        onSessionErrorIos: (NfcReaderSessionErrorIos error) {
          _sessionActive = false;
          _timeoutTimer?.cancel();
          _timeoutTimer = null;
          if (_terminalCallbackDelivered) {
            return;
          }
          _terminalCallbackDelivered = true;
          onError(_friendlyIosError(error));
        },
        onDiscovered: (NfcTag tag) async {
          if (_terminalCallbackDelivered) {
            return;
          }
          _terminalCallbackDelivered = true;
          _timeoutTimer?.cancel();
          _timeoutTimer = null;
          try {
            final NfcScan scan = await _inspectTag(tag, settings);
            // Complete the native session before notifying the controller. This
            // lets continuous batch scanning rearm immediately without a
            // timing delay or overlapping reader sessions.
            await _stopNativeSession(alertMessageIos: 'Tag read successfully');
            await onScan(scan);
          } on Object catch (error) {
            await _stopNativeSession(errorMessageIos: 'Tag read failed');
            onError('Could not inspect this tag: ${ErrorText.clean(error)}');
          }
        },
      );
      if (_sessionActive && !_terminalCallbackDelivered) {
        _timeoutTimer = Timer(
          const Duration(seconds: AppConstants.defaultScanTimeoutSeconds),
          () => unawaited(_handleTimeout(onError)),
        );
      }
    } on Object catch (error) {
      _sessionActive = false;
      _timeoutTimer?.cancel();
      _timeoutTimer = null;
      throw StateError(
        'Could not start NFC scanning: ${ErrorText.clean(error)}',
      );
    }
  }

  Future<void> _handleTimeout(ScanErrorCallback onError) async {
    if (!_sessionActive || _terminalCallbackDelivered) {
      return;
    }
    _terminalCallbackDelivered = true;
    await _stopNativeSession(errorMessageIos: 'Scan timed out');
    onError(
      'Scan timed out after ${AppConstants.defaultScanTimeoutSeconds} seconds. '
      'Move the tag and try again.',
    );
  }

  @override
  Future<void> stopScan() async {
    _terminalCallbackDelivered = true;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
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
      identifier = (await _inspectAndroid(
        tag,
        details,
        technologies,
      )).identifier;
    } else if (Platform.isIOS) {
      identifier = _inspectIos(tag, details, technologies).identifier;
    } else {
      throw UnsupportedError('TagVerity supports Android and iOS NFC devices.');
    }
    final List<NdefRecordInfo> ndefRecords = await _inspectNdef(
      tag,
      settings,
      details,
      warnings,
    );
    final bool comparableIdentity = identifier != null && identifier.isNotEmpty;
    final List<int> fingerprintSource = comparableIdentity
        ? identifier
        : utf8.encode(
            '${Platform.operatingSystem}|${technologies.join('|')}|'
            '${scannedAt.microsecondsSinceEpoch}',
          );
    final String fingerprint = sha256.convert(fingerprintSource).toString();
    final String? uidHex = comparableIdentity
        ? ByteUtils.hex(identifier)
        : null;
    return NfcScan(
      id: '${scannedAt.microsecondsSinceEpoch}-${fingerprint.substring(0, 12)}',
      scannedAt: scannedAt,
      platform: Platform.operatingSystem,
      uidHex: uidHex,
      uidFingerprint: fingerprint,
      identityStability: comparableIdentity
          ? TagIdentityStability.stable
          : TagIdentityStability.sessionOnly,
      technologies: technologies.toSet().toList(growable: false),
      details: Map<String, String>.unmodifiable(details),
      ndefRecords: ndefRecords,
      warnings: List<String>.unmodifiable(warnings),
    );
  }

  Future<_PlatformInspection> _inspectAndroid(
    NfcTag tag,
    Map<String, String> details,
    List<String> technologies,
  ) async {
    final NfcTagAndroid? androidTag = NfcTagAndroid.from(tag);
    if (androidTag == null) {
      throw StateError('Android did not expose a readable NFC tag object.');
    }
    technologies.addAll(
      androidTag.techList.map((String value) => value.split('.').last),
    );
    await _bestEffort(() async {
      final NfcAAndroid? nfcA = NfcAAndroid.from(tag);
      if (nfcA == null) return;
      _addProtocol(details, 'NFC-A / ISO 14443-3A');
      details['nfca.atqa'] = ByteUtils.hex(nfcA.atqa);
      details['nfca.sak'] =
          '0x${nfcA.sak.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      details['nfca.maxTransceiveLength'] =
          '${await nfcA.getMaxTransceiveLength()} bytes';
      details['nfca.timeout'] = '${await nfcA.getTimeout()} ms';
    });
    await _bestEffort(() async {
      final NfcBAndroid? nfcB = NfcBAndroid.from(tag);
      if (nfcB == null) return;
      _addProtocol(details, 'NFC-B / ISO 14443-3B');
      details['nfcb.applicationData'] = ByteUtils.hex(nfcB.applicationData);
      details['nfcb.protocolInfo'] = ByteUtils.hex(nfcB.protocolInfo);
      details['nfcb.maxTransceiveLength'] =
          '${await nfcB.getMaxTransceiveLength()} bytes';
    });
    await _bestEffort(() async {
      final NfcFAndroid? nfcF = NfcFAndroid.from(tag);
      if (nfcF == null) return;
      _addProtocol(details, 'NFC-F / ISO 18092');
      details['nfcf.manufacturer'] = ByteUtils.hex(nfcF.manufacturer);
      details['nfcf.systemCode'] = ByteUtils.hex(nfcF.systemCode);
      details['nfcf.maxTransceiveLength'] =
          '${await nfcF.getMaxTransceiveLength()} bytes';
      details['nfcf.timeout'] = '${await nfcF.getTimeout()} ms';
    });
    await _bestEffort(() async {
      final NfcVAndroid? nfcV = NfcVAndroid.from(tag);
      if (nfcV == null) return;
      _addProtocol(details, 'NFC-V / ISO 15693');
      details['nfcv.dsfId'] =
          '0x${nfcV.dsfId.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      details['nfcv.responseFlags'] =
          '0x${nfcV.responseFlags.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      details['nfcv.maxTransceiveLength'] =
          '${await nfcV.getMaxTransceiveLength()} bytes';
    });
    await _bestEffort(() async {
      final IsoDepAndroid? isoDep = IsoDepAndroid.from(tag);
      if (isoDep == null) return;
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
    await _bestEffort(() async {
      final MifareUltralightAndroid? ultralight = MifareUltralightAndroid.from(
        tag,
      );
      if (ultralight == null) return;
      details['mifare.ultralight.type'] = ultralight.type.name;
      details['mifare.ultralight.maxTransceiveLength'] =
          '${await ultralight.getMaxTransceiveLength()} bytes';
      details['mifare.ultralight.timeout'] =
          '${await ultralight.getTimeout()} ms';
    });
    await _bestEffort(() async {
      final MifareClassicAndroid? classic = MifareClassicAndroid.from(tag);
      if (classic == null) return;
      details['mifare.classic.type'] = classic.type.name;
      details['mifare.classic.size'] = '${classic.size} bytes';
      details['mifare.classic.sectorCount'] = classic.sectorCount.toString();
      details['mifare.classic.blockCount'] = classic.blockCount.toString();
    });
    await _bestEffort(() async {
      final NfcBarcodeAndroid? barcode = NfcBarcodeAndroid.from(tag);
      if (barcode == null) return;
      details['barcode.type'] = barcode.type.name;
      details['barcode.value'] = ByteUtils.hex(barcode.barcode);
    });
    return _PlatformInspection(identifier: androidTag.id);
  }

  _PlatformInspection _inspectIos(
    NfcTag tag,
    Map<String, String> details,
    List<String> technologies,
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
    } on Object {
      // Optional platform metadata is best-effort.
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
    } on Object {
      // Optional platform metadata is best-effort.
    }
    try {
      final FeliCaIos? feliCa = FeliCaIos.from(tag);
      if (feliCa != null) {
        identifier ??= feliCa.currentIDm;
        technologies.add('FeliCaIos');
        _addProtocol(details, 'NFC-F / ISO 18092');
        details['ios.felica.systemCode'] = ByteUtils.hex(
          feliCa.currentSystemCode,
        );
      }
    } on Object {
      // Optional platform metadata is best-effort.
    }
    try {
      final Iso15693Ios? iso15693 = Iso15693Ios.from(tag);
      if (iso15693 != null) {
        identifier ??= iso15693.identifier;
        technologies.add('Iso15693Ios');
        _addProtocol(details, 'NFC-V / ISO 15693');
        details['ios.iso15693.icManufacturerCode'] =
            '0x${iso15693.icManufacturerCode.toRadixString(16).padLeft(2, '0').toUpperCase()}';
      }
    } on Object {
      // Optional platform metadata is best-effort.
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
      warnings.add('Could not read standard NDEF: ${ErrorText.clean(error)}');
      return const <NdefRecordInfo>[];
    }
  }

  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Optional public metadata varies by controller and OS. Failure here is
      // not a tag-health failure and must not force REVIEW.
    }
  }

  void _addProtocol(Map<String, String> details, String protocol) {
    final String? existing = details['protocol'];
    if (existing == null || existing.isEmpty) {
      details['protocol'] = protocol;
      return;
    }
    final List<String> protocols = existing.split(' | ');
    if (!protocols.contains(protocol)) {
      details['protocol'] = '$existing | $protocol';
    }
  }

  String _friendlyIosError(NfcReaderSessionErrorIos error) {
    final String message = error.message.trim();
    return message.isEmpty
        ? 'The iOS NFC session ended (${error.code.name}).'
        : message;
  }
}

final class _PlatformInspection {
  const _PlatformInspection({required this.identifier});
  final Uint8List? identifier;
}

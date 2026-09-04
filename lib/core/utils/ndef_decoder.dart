import 'dart:convert';
import 'dart:typed_data';

import 'package:ndef_record/ndef_record.dart';

import '../../domain/models/ndef_record_info.dart';
import 'byte_utils.dart';

abstract final class NdefDecoder {
  static const int maximumSummaryCharacters = 300;

  static List<NdefRecordInfo> decodeMessage(NdefMessage message) {
    return <NdefRecordInfo>[
      for (int index = 0; index < message.records.length; index++)
        decodeRecord(index, message.records[index]),
    ];
  }

  static NdefRecordInfo decodeRecord(int index, NdefRecord record) {
    final String type = _decodeAscii(record.type);
    return NdefRecordInfo(
      index: index,
      typeNameFormat: record.typeNameFormat.name,
      type: type.isEmpty ? ByteUtils.hex(record.type) : type,
      identifierHex: ByteUtils.hex(record.identifier),
      payloadLength: record.payload.length,
      byteLength: record.byteLength,
      summary: _truncate(_summarize(record, type)),
      payloadPreviewHex: ByteUtils.hex(record.payload, maxBytes: 64),
    );
  }

  static String _summarize(NdefRecord record, String type) {
    if (record.typeNameFormat == TypeNameFormat.wellKnown && type == 'T') {
      return _decodeText(record.payload);
    }
    if (record.typeNameFormat == TypeNameFormat.wellKnown && type == 'U') {
      return _decodeUri(record.payload);
    }
    if (record.typeNameFormat == TypeNameFormat.media) {
      final String text = _decodeUtf8(record.payload);
      return text.isEmpty
          ? 'Media record: $type (${record.payload.length} bytes)'
          : text;
    }
    if (record.typeNameFormat == TypeNameFormat.absoluteUri) {
      return type.isEmpty ? _decodeUtf8(record.payload) : type;
    }
    if (record.typeNameFormat == TypeNameFormat.external) {
      return 'External type: $type (${record.payload.length} bytes)';
    }
    if (record.payload.isEmpty) {
      return 'Empty payload';
    }
    final String text = _decodeUtf8(record.payload);
    return text.isEmpty ? '${record.payload.length} bytes' : text;
  }

  static String _decodeText(Uint8List payload) {
    if (payload.isEmpty) {
      return 'Empty text record';
    }
    final int status = payload.first;
    final bool utf16 = (status & 0x80) != 0;
    final int languageLength = status & 0x3F;
    final int textStart = 1 + languageLength;
    if (textStart > payload.length) {
      return 'Invalid text record';
    }
    final String language = _decodeAscii(payload.sublist(1, textStart));
    if (utf16) {
      return 'UTF-16 text${language.isEmpty ? '' : ' [$language]'} '
          '(${payload.length - textStart} bytes)';
    }
    final String text = _decodeUtf8(payload.sublist(textStart));
    return language.isEmpty ? text : '$text [$language]';
  }

  static String _decodeUri(Uint8List payload) {
    if (payload.isEmpty) {
      return 'Empty URI record';
    }
    final String prefix = _uriPrefixes[payload.first] ?? '';
    return '$prefix${_decodeUtf8(payload.sublist(1))}';
  }

  static String _decodeAscii(Iterable<int> bytes) {
    if (bytes.isEmpty) {
      return '';
    }
    try {
      return ascii.decode(bytes.toList(growable: false), allowInvalid: true);
    } on FormatException {
      return '';
    }
  }

  static String _decodeUtf8(Iterable<int> bytes) {
    if (bytes.isEmpty) {
      return '';
    }
    final String value = utf8
        .decode(bytes.toList(growable: false), allowMalformed: true)
        .trim();
    final bool mostlyPrintable =
        value.runes.where((int rune) => rune >= 32 || rune == 10).length >=
        (value.runes.length * 0.8);
    return mostlyPrintable ? value : '';
  }

  static const Map<int, String> _uriPrefixes = <int, String>{
    0x00: '',
    0x01: 'http://www.',
    0x02: 'https://www.',
    0x03: 'http://',
    0x04: 'https://',
    0x05: 'tel:',
    0x06: 'mailto:',
    0x07: 'ftp://anonymous:anonymous@',
    0x08: 'ftp://ftp.',
    0x09: 'ftps://',
    0x0A: 'sftp://',
    0x0B: 'smb://',
    0x0C: 'nfs://',
    0x0D: 'ftp://',
    0x0E: 'dav://',
    0x0F: 'news:',
    0x10: 'telnet://',
    0x11: 'imap:',
    0x12: 'rtsp://',
    0x13: 'urn:',
    0x14: 'pop:',
    0x15: 'sip:',
    0x16: 'sips:',
    0x17: 'tftp:',
    0x18: 'btspp://',
    0x19: 'btl2cap://',
    0x1A: 'btgoep://',
    0x1B: 'tcpobex://',
    0x1C: 'irdaobex://',
    0x1D: 'file://',
    0x1E: 'urn:epc:id:',
    0x1F: 'urn:epc:tag:',
    0x20: 'urn:epc:pat:',
    0x21: 'urn:epc:raw:',
    0x22: 'urn:epc:',
    0x23: 'urn:nfc:',
  };
}

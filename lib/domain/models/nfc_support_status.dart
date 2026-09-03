enum NfcSupportStatus { unknown, enabled, disabled, unsupported }

extension NfcSupportStatusLabel on NfcSupportStatus {
  String get label => switch (this) {
    NfcSupportStatus.unknown => 'Not checked',
    NfcSupportStatus.enabled => 'NFC ready',
    NfcSupportStatus.disabled => 'NFC is off',
    NfcSupportStatus.unsupported => 'NFC unavailable',
  };
}

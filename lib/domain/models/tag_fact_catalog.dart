abstract final class TagFactCatalog {
  static const Set<String> advancedKeys = <String>{
    'nfca.maxTransceiveLength',
    'nfca.timeout',
    'nfcb.maxTransceiveLength',
    'nfcf.maxTransceiveLength',
    'nfcf.timeout',
    'nfcv.maxTransceiveLength',
    'isodep.extendedLengthApduSupported',
    'isodep.maxTransceiveLength',
    'isodep.timeout',
    'isodep.hiLayerResponse',
    'mifare.ultralight.maxTransceiveLength',
    'mifare.ultralight.timeout',
    'ndef.readStatus',
  };
  static const Set<String> linkableKeys = <String>{
    'nfcb.applicationData',
    'nfcb.protocolInfo',
    'isodep.historicalBytes',
    'isodep.hiLayerResponse',
    'barcode.value',
    'ios.iso7816.initialSelectedAid',
    'ios.iso7816.applicationData',
    'ios.iso7816.historicalBytes',
    'ios.mifare.historicalBytes',
    // Legacy v1 display labels retained only so old local history can migrate safely.
    'Application Data',
    'Protocol Info',
    'Historical Bytes',
    'Hi-Layer Response',
    'NFC Barcode',
    '初始选中 AID',
  };
  static String label(String key) => switch (key) {
    'protocol' => 'Protocol',
    'nfca.atqa' => 'ATQA',
    'nfca.sak' => 'SAK',
    'nfca.maxTransceiveLength' => 'NFC-A max transceive',
    'nfca.timeout' => 'NFC-A timeout',
    'nfcb.applicationData' => 'NFC-B application data',
    'nfcb.protocolInfo' => 'NFC-B protocol info',
    'nfcb.maxTransceiveLength' => 'NFC-B max transceive',
    'nfcf.manufacturer' => 'NFC-F manufacturer parameter',
    'nfcf.systemCode' => 'NFC-F system code',
    'nfcf.maxTransceiveLength' => 'NFC-F max transceive',
    'nfcf.timeout' => 'NFC-F timeout',
    'nfcv.dsfId' => 'NFC-V DSFID',
    'nfcv.responseFlags' => 'NFC-V response flags',
    'nfcv.maxTransceiveLength' => 'NFC-V max transceive',
    'isodep.supported' => 'ISO-DEP',
    'isodep.extendedLengthApduSupported' => 'Extended-length APDU capability',
    'isodep.maxTransceiveLength' => 'ISO-DEP max transceive',
    'isodep.timeout' => 'ISO-DEP timeout',
    'isodep.historicalBytes' => 'Historical bytes',
    'isodep.hiLayerResponse' => 'Hi-layer response',
    'mifare.ultralight.type' => 'MIFARE Ultralight type',
    'mifare.ultralight.maxTransceiveLength' => 'Ultralight max transceive',
    'mifare.ultralight.timeout' => 'Ultralight timeout',
    'mifare.classic.type' => 'MIFARE Classic type',
    'mifare.classic.size' => 'MIFARE Classic capacity',
    'mifare.classic.sectorCount' => 'MIFARE Classic sectors',
    'mifare.classic.blockCount' => 'MIFARE Classic blocks',
    'barcode.type' => 'NFC Barcode type',
    'barcode.value' => 'NFC Barcode',
    'ios.mifare.family' => 'MIFARE family',
    'ios.mifare.historicalBytes' => 'MIFARE historical bytes',
    'ios.felica.systemCode' => 'NFC-F system code',
    'ios.iso15693.icManufacturerCode' => 'ISO 15693 manufacturer code',
    'ios.iso7816.supported' => 'ISO 7816',
    'ios.iso7816.initialSelectedAid' => 'Initial selected AID',
    'ios.iso7816.proprietaryApplicationDataCoding' =>
      'Proprietary app-data coding',
    'ios.iso7816.applicationData' => 'Application data',
    'ios.iso7816.historicalBytes' => 'ISO 7816 historical bytes',
    'ndef.supported' => 'NDEF support',
    'ndef.maxSize' => 'NDEF capacity',
    'ndef.writable' => 'NDEF writable',
    'ndef.readEnabled' => 'NDEF content reading',
    'ndef.readStatus' => 'NDEF read status',
    'ndef.messageLength' => 'NDEF message length',
    'ndef.recordCount' => 'NDEF records',
    _ => key,
  };
  static bool isAdvanced(String key) => advancedKeys.contains(key);
  static bool isLinkable(String key) => linkableKeys.contains(key);
  static Map<String, String> privacyScrubbedDetails(
    Map<String, String> details,
  ) {
    return Map<String, String>.unmodifiable(
      Map<String, String>.fromEntries(
        details.entries.where(
          (MapEntry<String, String> entry) => !isLinkable(entry.key),
        ),
      ),
    );
  }
}

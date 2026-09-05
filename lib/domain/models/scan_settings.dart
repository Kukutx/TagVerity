class ScanSettings {
  const ScanSettings({
    this.readNdef = true,
    this.saveRawUidInHistory = false,
    this.saveNdefInHistory = false,
    this.saveTechnicalIdentifiersInHistory = false,
  });
  final bool readNdef;
  final bool saveRawUidInHistory;
  final bool saveNdefInHistory;
  final bool saveTechnicalIdentifiersInHistory;
  ScanSettings copyWith({
    bool? readNdef,
    bool? saveRawUidInHistory,
    bool? saveNdefInHistory,
    bool? saveTechnicalIdentifiersInHistory,
  }) {
    return ScanSettings(
      readNdef: readNdef ?? this.readNdef,
      saveRawUidInHistory: saveRawUidInHistory ?? this.saveRawUidInHistory,
      saveNdefInHistory: saveNdefInHistory ?? this.saveNdefInHistory,
      saveTechnicalIdentifiersInHistory:
          saveTechnicalIdentifiersInHistory ??
          this.saveTechnicalIdentifiersInHistory,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'readNdef': readNdef,
    'saveRawUidInHistory': saveRawUidInHistory,
    'saveNdefInHistory': saveNdefInHistory,
    'saveTechnicalIdentifiersInHistory': saveTechnicalIdentifiersInHistory,
  };
  factory ScanSettings.fromJson(Map<String, dynamic> json) {
    return ScanSettings(
      readNdef: json['readNdef'] as bool? ?? true,
      saveRawUidInHistory: json['saveRawUidInHistory'] as bool? ?? false,
      saveNdefInHistory: json['saveNdefInHistory'] as bool? ?? false,
      saveTechnicalIdentifiersInHistory:
          json['saveTechnicalIdentifiersInHistory'] as bool? ?? false,
    );
  }
}

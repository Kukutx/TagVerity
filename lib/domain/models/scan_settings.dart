import '../../core/constants/app_constants.dart';

class ScanSettings {
  const ScanSettings({
    this.readNdef = true,
    this.platformSounds = true,
    this.saveRawUidInHistory = false,
    this.saveNdefInHistory = false,
    this.saveTechnicalIdentifiersInHistory = false,
    this.showAdvancedFields = true,
    this.scanTimeoutSeconds = AppConstants.defaultScanTimeoutSeconds,
    this.historyLimit = AppConstants.defaultHistoryLimit,
  });

  final bool readNdef;
  final bool platformSounds;
  final bool saveRawUidInHistory;
  final bool saveNdefInHistory;
  final bool saveTechnicalIdentifiersInHistory;
  final bool showAdvancedFields;
  final int scanTimeoutSeconds;
  final int historyLimit;

  ScanSettings copyWith({
    bool? readNdef,
    bool? platformSounds,
    bool? saveRawUidInHistory,
    bool? saveNdefInHistory,
    bool? saveTechnicalIdentifiersInHistory,
    bool? showAdvancedFields,
    int? scanTimeoutSeconds,
    int? historyLimit,
  }) {
    return ScanSettings(
      readNdef: readNdef ?? this.readNdef,
      platformSounds: platformSounds ?? this.platformSounds,
      saveRawUidInHistory: saveRawUidInHistory ?? this.saveRawUidInHistory,
      saveNdefInHistory: saveNdefInHistory ?? this.saveNdefInHistory,
      saveTechnicalIdentifiersInHistory:
          saveTechnicalIdentifiersInHistory ??
          this.saveTechnicalIdentifiersInHistory,
      showAdvancedFields: showAdvancedFields ?? this.showAdvancedFields,
      scanTimeoutSeconds: (scanTimeoutSeconds ?? this.scanTimeoutSeconds)
          .clamp(
            AppConstants.minimumScanTimeoutSeconds,
            AppConstants.maximumScanTimeoutSeconds,
          )
          .toInt(),
      historyLimit: (historyLimit ?? this.historyLimit)
          .clamp(
            AppConstants.minimumHistoryLimit,
            AppConstants.maximumHistoryLimit,
          )
          .toInt(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'readNdef': readNdef,
    'platformSounds': platformSounds,
    'saveRawUidInHistory': saveRawUidInHistory,
    'saveNdefInHistory': saveNdefInHistory,
    'saveTechnicalIdentifiersInHistory': saveTechnicalIdentifiersInHistory,
    'showAdvancedFields': showAdvancedFields,
    'scanTimeoutSeconds': scanTimeoutSeconds,
    'historyLimit': historyLimit,
  };

  factory ScanSettings.fromJson(Map<String, dynamic> json) {
    return ScanSettings(
      readNdef: json['readNdef'] as bool? ?? true,
      platformSounds: json['platformSounds'] as bool? ?? true,
      saveRawUidInHistory: json['saveRawUidInHistory'] as bool? ?? false,
      saveNdefInHistory: json['saveNdefInHistory'] as bool? ?? false,
      saveTechnicalIdentifiersInHistory:
          json['saveTechnicalIdentifiersInHistory'] as bool? ?? false,
      showAdvancedFields: json['showAdvancedFields'] as bool? ?? true,
      scanTimeoutSeconds:
          (json['scanTimeoutSeconds'] as int? ??
                  AppConstants.defaultScanTimeoutSeconds)
              .clamp(
                AppConstants.minimumScanTimeoutSeconds,
                AppConstants.maximumScanTimeoutSeconds,
              )
              .toInt(),
      historyLimit:
          (json['historyLimit'] as int? ?? AppConstants.defaultHistoryLimit)
              .clamp(
                AppConstants.minimumHistoryLimit,
                AppConstants.maximumHistoryLimit,
              )
              .toInt(),
    );
  }
}

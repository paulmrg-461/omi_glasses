class BluetoothConstants {
  // Main Service UUID (OMI Service)
  static const String serviceUuid = "19b10000-e8f2-537e-4f6c-d104768a1214";

  // Audio UUIDs
  static const String audioDataUuid = "19b10001-e8f2-537e-4f6c-d104768a1214";
  static const String audioCodecUuid = "19b10002-e8f2-537e-4f6c-d104768a1214";

  // Photo UUIDs
  static const String photoDataUuid = "19b10005-e8f2-537e-4f6c-d104768a1214";
  static const String photoControlUuid = "19b10006-e8f2-537e-4f6c-d104768a1214";

  // Battery UUIDs
  static const String batteryServiceUuid = "180f";
  static const String batteryLevelUuid = "2a19";

  // Heart Rate UUIDs
  static const String heartRateServiceUuid = "180d";
  static const String heartRateMeasurementUuid = "2a37";

  // Wi-Fi UUIDs (NOT SUPPORTED IN FIRMWARE v2.1.1)
  // Kept for reference but not available on OMI Glasses
  static const String wifiServiceUuid = "30295780-4301-eabd-2904-2849adfeae43";
  static const String wifiCharacteristicUuid =
      "30295783-4301-eabd-2904-2849adfeae43";
}

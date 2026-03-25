// lib/features/exposure/domain/entities/exposure_record.dart
import '../../../../models/air_quality_model.dart'; // For UserProfile

class ExposureRecord {
  final DateTime timestamp;
  final int aqi;
  final double durationMinutes;
  final UserProfile profile;
  final double latitude;
  final double longitude;
  final String locationName;

  const ExposureRecord({
    required this.timestamp,
    required this.aqi,
    required this.durationMinutes,
    required this.profile,
    required this.latitude,
    required this.longitude,
    required this.locationName,
  });

  /// Weighted exposure = AQI × duration × profile_sensitivity
  double get weightedExposure {
    final sensitivity = switch (profile) {
      UserProfile.sick    => 2.0,   // Très sensible
      UserProfile.child   => 1.8,
      UserProfile.elderly => 1.6,
      UserProfile.cyclist => 1.5,   // Respiration intense
      UserProfile.athlete => 1.5,
      UserProfile.normal  => 1.0,
    };
    return aqi * (durationMinutes / 60.0) * sensitivity;
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'aqi': aqi,
    'durationMinutes': durationMinutes,
    'profile': profile.index,
    'latitude': latitude,
    'longitude': longitude,
    'locationName': locationName,
  };

  factory ExposureRecord.fromJson(Map<String, dynamic> json) => ExposureRecord(
    timestamp: DateTime.parse(json['timestamp'] as String),
    aqi: json['aqi'] as int,
    durationMinutes: (json['durationMinutes'] as num).toDouble(),
    profile: UserProfile.values[json['profile'] as int],
    latitude: (json['latitude'] as num).toDouble(),
    longitude: (json['longitude'] as num).toDouble(),
    locationName: json['locationName'] as String,
  );
}

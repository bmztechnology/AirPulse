// lib/core/errors/location_exception.dart

enum LocationError {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timeout,
  unknown
}

class LocationException implements Exception {
  final LocationError error;
  LocationException(this.error);
  @override
  String toString() => 'LocationException: $error';
}

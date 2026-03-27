// lib/core/config/app_config.dart

class AppConfig {
  static const String appName = 'AirPulse';
  static const String appVersion = '1.0.0';

  // ── API Endpoints ──────────────────────────────────────────────────────────
  static const String waqiEndpoint = 'https://api.waqi.info/map/bounds/';
  static const String openMeteoWeatherEndpoint = 'https://api.open-meteo.com/v1/forecast';
  static const String openMeteoAirQualityEndpoint = 'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const String nominatimEndpoint = 'https://nominatim.openstreetmap.org/reverse';
  static const String groqEndpoint = 'https://api.groq.com/openai/v1/chat/completions';

  // ── API Tokens ─────────────────────────────────────────────────────────────
  // IMPORTANT: Demo token is for testing. Real projects should rotate this.
  static const String waqiToken = 'demo'; 
  static const String groqDefaultModel = 'llama-3.3-70b-versatile';

  // ── Business Rules ─────────────────────────────────────────────────────────
  static const int gpsDistanceFilter = 3; // Meters
  static const int gpsTimeoutSeconds = 12;
  static const int apiTimeoutSeconds = 10;
  static const int cacheHistoryLimit = 200;
  
  // AI
  static const String aiEndpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const String aiModel = 'llama-3.3-70b-versatile';
}

// lib/core/i18n/localization_helper.dart

class LocalizationHelper {
  /// Provides notification labels for a given language code.
  /// This is used in background tasks where AppLocalizations.of(context) is unavailable.
  static Map<String, String> getNotificationLabels(String lang) {
    if (lang == 'fr') {
      return {
        'title': 'Alerte AirPulse',
        'body': 'L\'AQI est de {aqi} à {station}',
        'titlePoor': '⚠️ Qualité de l\'air mauvaise',
        'bodyPoor': 'AQI {aqi} à {station}. Évitez les activités extérieures.',
        'titleThreshold': '🛑 Seuil personnel dépassé',
        'bodyThreshold': 'L\'AQI {aqi} dépasse votre seuil de {threshold} à {station}.',
      };
    }
    // Default: English
    return {
      'title': 'AirPulse Alert',
      'body': 'AQI is {aqi} at {station}',
      'titlePoor': '⚠️ Poor Air Quality',
      'bodyPoor': 'AQI {aqi} at {station}. Avoid outdoor activities.',
      'titleThreshold': '🛑 Personal threshold exceeded',
      'bodyThreshold': 'AQI {aqi} exceeds your threshold of {threshold} at {station}.',
    };
  }
}

// lib/providers/app_provider.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/air_quality_model.dart';

class AppProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  UserProfile _profile = UserProfile.cyclist;
  UserProfile get profile => _profile;

  AirQualityData _data = AirQualityData.mock();
  AirQualityData get data => _data;

  bool _loading = false;
  bool get loading => _loading;

  String _locationName = 'Paris 11e, Île-de-France';
  String get locationName => _locationName;

  List<AqiStation> _stations = AqiStation.mockStations();
  List<AqiStation> get stations => _stations;

  Map<String, bool> _alerts = {
    'aqi_50': false,
    'aqi_100': true,
    'pm25_15': true,
    'cyclist': false,
    'pollen': false,
  };
  Map<String, bool> get alerts => _alerts;

  Map<String, bool> _dataSourceEnabled = {
    'waqi': true,
    'openmeteo': true,
    'openaq': false,
    'copernicus': false,
    'airparif': true,
  };
  Map<String, bool> get dataSourceEnabled => _dataSourceEnabled;

  bool _darkMode = false;
  bool get darkMode => _darkMode;

  double _personalThreshold = 100;
  double get personalThreshold => _personalThreshold;

  // ── Init ──────────────────────────────────────────────────────────────────
  AppProvider() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString('lang');
      if (langCode != null) {
        _locale = Locale(langCode);
      }
      final profileIndex = prefs.getInt('profile') ?? 0;
      _profile = UserProfile.values[
          profileIndex.clamp(0, UserProfile.values.length - 1)];
      _darkMode = prefs.getBool('darkMode') ?? false;
      _personalThreshold = prefs.getDouble('personalThreshold') ?? 100;
      for (final key in [
        'waqi', 'openmeteo', 'openaq', 'copernicus', 'airparif'
      ]) {
        final saved = prefs.getBool('ds_$key');
        if (saved != null) _dataSourceEnabled[key] = saved;
      }
    } catch (e) {
      debugPrint('AirPulse: SharedPreferences load failed: $e');
    } finally {
      notifyListeners();
    }
  }

  // ── Language ──────────────────────────────────────────────────────────────
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lang', locale.languageCode);
    } catch (e) {
      debugPrint('AirPulse: setLocale failed: $e');
    }
  }

  Future<void> applyDeviceLocale(Locale deviceLocale) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('lang') != null) return;
      const supported = ['fr', 'en', 'es', 'de', 'it', 'pt', 'ar', 'zh', 'ja'];
      final code = deviceLocale.languageCode;
      _locale = Locale(supported.contains(code) ? code : 'en');
      notifyListeners();
    } catch (e) {
      debugPrint('AirPulse: applyDeviceLocale failed: $e');
    }
  }

  // ── Profile ───────────────────────────────────────────────────────────────
  Future<void> setProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('profile', profile.index);
    } catch (e) {
      debugPrint('AirPulse: setProfile failed: $e');
    }
  }

  // ── Data refresh ──────────────────────────────────────────────────────────
  Future<void> refreshLocation() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      await Future.delayed(const Duration(milliseconds: 900));
      const cities = [
        (name: 'Paris 11e, Île-de-France', aqi: 42, lat: 48.856, lng: 2.352),
        (name: 'Lyon Part-Dieu',           aqi: 78, lat: 45.764, lng: 4.836),
        (name: 'Marseille Centre',         aqi: 112, lat: 43.296, lng: 5.370),
        (name: 'Bois de Vincennes',        aqi: 28, lat: 48.830, lng: 2.433),
        (name: 'Barcelona, España',        aqi: 65, lat: 41.385, lng: 2.173),
        (name: 'Berlin, Deutschland',      aqi: 38, lat: 52.520, lng: 13.405),
      ];
      final city = cities[DateTime.now().second % cities.length];
      _locationName = city.name;
      _data = AirQualityData(
        aqi: city.aqi,
        pm25: city.aqi * 0.19,
        pm10: city.aqi * 0.45,
        no2: city.aqi * 0.9,
        o3: (140 - city.aqi).clamp(30, 120).toDouble(),
        so2: city.aqi * 0.09,
        co: city.aqi * 0.015,
        updatedAt: DateTime.now(),
        stationName: city.name,
        stationSource: 'WAQI',
        lat: city.lat,
        lng: city.lng,
        weather: WeatherData.mock(),
        pollen: PollenData.mock(),
        forecast: HourlyForecast.mockList(),
      );
    } catch (e) {
      debugPrint('AirPulse: refreshLocation error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Alerts ────────────────────────────────────────────────────────────────
  void toggleAlert(String id) {
    _alerts[id] = !(_alerts[id] ?? false);
    notifyListeners();
  }

  Future<void> toggleDataSource(String id) async {
    _dataSourceEnabled[id] = !(_dataSourceEnabled[id] ?? true);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ds_$id', _dataSourceEnabled[id]!);
    } catch (e) {
      debugPrint('AirPulse: toggleDataSource failed: $e');
    }
  }

  // ── Dark mode ─────────────────────────────────────────────────────────────
  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', value);
    } catch (e) {
      debugPrint('AirPulse: setDarkMode failed: $e');
    }
  }

  // ── Personal threshold ────────────────────────────────────────────────────
  Future<void> setPersonalThreshold(double value) async {
    _personalThreshold = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('personalThreshold', value);
    } catch (e) {
      debugPrint('AirPulse: setPersonalThreshold failed: $e');
    }
  }
}

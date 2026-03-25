// lib/providers/app_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/air_quality_model.dart';
import '../services/ai_insight_service.dart';
import '../core/di/injection.dart';
import '../core/services/data_refresh_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppProvider
// ─────────────────────────────────────────────────────────────────────────────
class AppProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  UserProfile _profile = UserProfile.cyclist;
  UserProfile get profile => _profile;

  AirQualityData _data = AirQualityData.mock();
  AirQualityData get data => _data;

  bool _loading = false;
  bool get loading => _loading;

  bool _initialized = false;
  bool get initialized => _initialized;

  String? _error;
  DateTime? _lastRefreshTime;
  String? get error => _error;

  String _locationName = '…';
  String get locationName => _locationName;

  double? _lastLat;
  double? _lastLng;
  double? get lastLat => _lastLat;
  double? get lastLng => _lastLng;

  String? _aiInsight;
  bool    _aiLoading = false;
  String? get aiInsight  => _aiInsight;
  bool    get aiLoading  => _aiLoading;
  bool    get hasAiKey   => AiInsightService.hasKey;

  List<AqiStation> _stations = [];
  List<AqiStation> get stations => _stations;

  List<Map<String, dynamic>> _aqiHistory = [];
  List<Map<String, dynamic>> get aqiHistory => List.unmodifiable(_aqiHistory);

  List<Map<String, dynamic>> _alertHistory = [];
  List<Map<String, dynamic>> get alertHistory => List.unmodifiable(_alertHistory);

  Map<String, bool> _alerts = {
    'aqi_50': false, 'aqi_100': true, 'pm25_15': true, 'cyclist': false, 'pollen': false,
  };
  Map<String, bool> get alerts => _alerts;

  Map<String, bool> _dataSourceEnabled = {
    'waqi': true, 'openmeteo': true, 'openaq': false, 'copernicus': false, 'airparif': true,
  };
  Map<String, bool> get dataSourceEnabled => _dataSourceEnabled;

  bool _darkMode = false;
  bool get darkMode => _darkMode;

  double _personalThreshold = 100;
  double get personalThreshold => _personalThreshold;

  AppProvider() {
    _loadPrefs().then((_) => refreshLocation());
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString('lang');
      if (langCode != null) _locale = Locale(langCode);
      final idx = prefs.getInt('profile') ?? 0;
      _profile = UserProfile.values[idx.clamp(0, UserProfile.values.length - 1)];
      _darkMode = prefs.getBool('darkMode') ?? false;
      _personalThreshold = prefs.getDouble('personalThreshold') ?? 100;
      for (final k in ['waqi','openmeteo','openaq','copernicus','airparif']) {
        final v = prefs.getBool('ds_$k'); if (v != null) _dataSourceEnabled[k] = v;
      }
      for (final k in _alerts.keys.toList()) {
        final v = prefs.getBool('alert_$k'); if (v != null) _alerts[k] = v;
      }
      final ah = prefs.getString('alert_history');
      if (ah != null) { try { _alertHistory = (jsonDecode(ah) as List).cast(); } catch (_) {} }
      final qh = prefs.getString('aqi_history');
      if (qh != null) { try { _aqiHistory = (jsonDecode(qh) as List).cast(); } catch (_) {} }
      await _migrateAndLoadGroqKey(prefs);
    } catch (e) {
      debugPrint('AirPulse: prefs load: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _migrateAndLoadGroqKey(SharedPreferences prefs) async {
    const secure = FlutterSecureStorage();
    try {
      String? key = await secure.read(key: 'groq_api_key');
      if ((key == null || key.isEmpty) && prefs.containsKey('groq_api_key')) {
        key = prefs.getString('groq_api_key');
        if (key != null && key.isNotEmpty) {
          await secure.write(key: 'groq_api_key', value: key);
          await prefs.remove('groq_api_key');
        }
      }
      if (key != null && key.isNotEmpty) {
        AiInsightService.apiKey = key;
      }
    } catch (e) {
      debugPrint('AirPulse: _migrateAndLoadGroqKey: $e');
      final fallback = prefs.getString('groq_api_key');
      if (fallback != null && fallback.isNotEmpty) {
        AiInsightService.apiKey = fallback;
      }
    }
  }

  Future<void> refreshLocation() async {
    if (_loading) return;
    _loading = true; _error = null; notifyListeners();
    try {
      final res = await sl<DataRefreshService>().performRefresh(
        profile: _profile,
        lastRefreshTime: _lastRefreshTime,
      );
      
      if (res != null) {
        _lastRefreshTime = DateTime.now();
        await _loadFromCache();
        await _syncHistoryWithPrefs();
      } else {
        final cached = await _loadFromCache();
        await _syncHistoryWithPrefs();
        if (cached) _error = 'Mode hors ligne (données en cache)';
        else _error = 'Impossible de récupérer les données (offline).';
      }
    } catch (e) {
      debugPrint('AirPulse: refresh: $e');
      await _loadFromCache();
      await _syncHistoryWithPrefs();
    } finally {
      _initialized = true; _loading = false; notifyListeners();
      if (_lastLat != null) unawaited(_refreshAiInsight());
    }
  }

  Future<void> _syncHistoryWithPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ah = prefs.getString('alert_history');
      if (ah != null) { 
        try { _alertHistory = (jsonDecode(ah) as List).cast(); } catch (_) {} 
      }
      final qh = prefs.getString('aqi_history');
      if (qh != null) { 
        try { _aqiHistory = (jsonDecode(qh) as List).cast(); } catch (_) {} 
      }
    } catch (e) { debugPrint('AirPulse: _syncHistory: $e'); }
  }

  Future<bool> _loadFromCache() async {
    try {
      final box = await Hive.openBox('aqi_cache');
      final rawData = box.get('last_data');
      if (rawData != null) {
        _data = AirQualityData.fromJson(Map<String, dynamic>.from(rawData as Map));
        _lastLat = box.get('last_lat') as double?;
        _lastLng = box.get('last_lng') as double?;
        _locationName = box.get('location_name') as String? ?? '…';
        
        final rawStations = box.get('last_stations');
        if (rawStations != null) {
          _stations = (rawStations as List).map((s) => AqiStation.fromJson(Map<String, dynamic>.from(s as Map))).toList();
        }
        return true;
      }
    } catch (e) { debugPrint('AirPulse: Hive load error: $e'); }
    return false;
  }

  Future<void> setLocale(Locale locale) async {
    _locale = locale; notifyListeners();
    try { final p = await SharedPreferences.getInstance(); await p.setString('lang', locale.languageCode); }
    catch (e) { debugPrint('AirPulse: setLocale: $e'); }
  }

  Future<void> applyDeviceLocale(Locale deviceLocale) async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getString('lang') != null) return;
      const s = ['fr','en','es','de','it','pt','ar','zh','ja'];
      _locale = Locale(s.contains(deviceLocale.languageCode) ? deviceLocale.languageCode : 'en');
      notifyListeners();
    } catch (e) { debugPrint('AirPulse: applyDeviceLocale: $e'); }
  }

  Future<void> setProfile(UserProfile profile) async {
    _profile = profile; notifyListeners();
    try { final p = await SharedPreferences.getInstance(); await p.setInt('profile', profile.index); }
    catch (e) { debugPrint('AirPulse: setProfile: $e'); }
  }

  Future<void> toggleAlert(String id) async {
    _alerts[id] = !(_alerts[id] ?? false); notifyListeners();
    try { final p = await SharedPreferences.getInstance(); await p.setBool('alert_$id', _alerts[id]!); }
    catch (e) { debugPrint('AirPulse: toggleAlert: $e'); }
  }

  Future<void> toggleDataSource(String id) async {
    _dataSourceEnabled[id] = !(_dataSourceEnabled[id] ?? true); notifyListeners();
    try { final p = await SharedPreferences.getInstance(); await p.setBool('ds_$id', _dataSourceEnabled[id]!); }
    catch (e) { debugPrint('AirPulse: toggleDataSource: $e'); }
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value; notifyListeners();
    try { final p = await SharedPreferences.getInstance(); await p.setBool('darkMode', value); }
    catch (e) { debugPrint('AirPulse: setDarkMode: $e'); }
  }

  Future<void> setPersonalThreshold(double value) async {
    _personalThreshold = value; notifyListeners();
    try { final p = await SharedPreferences.getInstance(); await p.setDouble('personalThreshold', value); }
    catch (e) { debugPrint('AirPulse: setPersonalThreshold: $e'); }
  }

  Future<void> _refreshAiInsight() async {
    if (!AiInsightService.hasKey) return;
    _aiLoading = true; notifyListeners();
    final insight = await AiInsightService.getInsight(
      data: _data, profile: _profile,
      lang: _locale.languageCode, history: _aqiHistory,
    );
    _aiInsight = insight;
    _aiLoading = false; notifyListeners();
  }

  Future<void> setGroqApiKey(String key) async {
    AiInsightService.apiKey = key.trim();
    notifyListeners();
    try {
      const secure = FlutterSecureStorage();
      await secure.write(key: 'groq_api_key', value: key.trim());
      final p = await SharedPreferences.getInstance();
      if (p.containsKey('groq_api_key')) await p.remove('groq_api_key');
    } catch (e) { debugPrint('AirPulse: setGroqApiKey: $e'); }
    if (AiInsightService.hasKey && _initialized) unawaited(_refreshAiInsight());
  }

  void clearError() { _error = null; notifyListeners(); }
}

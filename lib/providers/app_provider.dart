// lib/providers/app_provider.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/app_config.dart';
import '../core/errors/location_exception.dart';
import '../core/services/data_refresh_service.dart';
import '../core/di/injection.dart';
import '../models/air_quality_model.dart';
import '../services/ai_insight_service.dart';

enum RefreshErrorType {
  gpsDisabled,
  offlineWithCache,
  offlineNoData,
  locationPermissionDenied,
  locationPermissionDeniedForever,
  locationTimeout
}

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
  // DateTime? _lastRefreshTime; // REMOVED UNUSED FIELD
  String? get error => _error;
  RefreshErrorType? _refreshErrorType;
  RefreshErrorType? get refreshErrorType => _refreshErrorType;
  bool _gpsDisabled = false;
  bool get gpsDisabled => _gpsDisabled;

  String _locationName = '…';
  String get locationName => _locationName;

  double? _lastLat;
  double? _lastLng;
  double? get lastLat => _lastLat;
  double? get lastLng => _lastLng;

  bool _waitingForSettings = false;
  bool get waitingForSettings => _waitingForSettings;
  
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ServiceStatus>? _serviceStatusStream;
  bool _isTracking = false;
  bool get isTracking => _isTracking;

  void setWaitingForSettings(bool value) {
    _waitingForSettings = value;
    notifyListeners();
  }

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
    _loadPrefs().then((_) {
      _initGps();
      startLocationTracking();
    });
  }

  /// START: Radical Continuous Positioning
  void _initGps() {
    _serviceStatusStream?.cancel();
    _serviceStatusStream = Geolocator.getServiceStatusStream().listen((status) {
      final disabled = status == ServiceStatus.disabled;
      if (disabled != _gpsDisabled) {
        _gpsDisabled = disabled;
        if (disabled) {
          _refreshErrorType = RefreshErrorType.gpsDisabled;
        } else {
          // If re-enabled, start tracking immediately
          startLocationTracking();
        }
        notifyListeners();
      }
    });
  }

  /// Unified Location Tracking & Management
  Future<void> startLocationTracking() async {
    if (_isTracking) return;
    
    // 1. Check Service
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _gpsDisabled = true;
      _refreshErrorType = RefreshErrorType.gpsDisabled;
      notifyListeners();
      return;
    }

    // 2. Check & Request Permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      _refreshErrorType = (permission == LocationPermission.deniedForever) 
          ? RefreshErrorType.locationPermissionDeniedForever 
          : RefreshErrorType.locationPermissionDenied;
      notifyListeners();
      return;
    }

    // 3. Start high-frequency stream
    _gpsDisabled = false;
    _isTracking = true;
    _positionStream?.cancel();
    
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConfig.gpsDistanceFilter, 
      ),
    ).listen(
      (Position pos) {
        _lastLat = pos.latitude;
        _lastLng = pos.longitude;
        // Trigger data refresh when position updates significantly
        refreshLocation(isAutoStream: true);
      },
      onError: (e) {
        debugPrint('AirPulse: GPS Stream Error: $e');
        _isTracking = false;
        notifyListeners();
      },
    );
  }

  void stopLocationTracking() {
    _positionStream?.cancel();
    _positionStream = null;
    _isTracking = false;
    notifyListeners();
  }
  /// END: Radical Continuous Positioning

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

  /// Centralized Data Refresh
  Future<void> refreshLocation({bool forceFresh = false, bool isAutoStream = false}) async {
    if (_loading && !isAutoStream) return;
    
    // Prevent screen flickering on automated stream updates
    if (!isAutoStream) {
      _loading = true;
      _error = null;
      _refreshErrorType = null;
      notifyListeners();
    }

    try {
      // Robust GPS acquisition: Last Known -> Current -> Wait for Stream
      if (_lastLat == null || _lastLng == null) {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          _lastLat = lastKnown.latitude;
          _lastLng = lastKnown.longitude;
          debugPrint('AirPulse: Using lastKnownPosition fallback');
        } else {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 5),
          );
          _lastLat = pos.latitude;
          _lastLng = pos.longitude;
          debugPrint('AirPulse: Using getCurrentPosition');
        }
      }

      final res = await sl<DataRefreshService>().performRefresh(
        lat: _lastLat!,
        lng: _lastLng!,
        profile: _profile,
        lastRefreshTime: _data.updatedAt,
        forceFresh: forceFresh || isAutoStream,
      );
      
      if (res != null) {
        _data = res;
        _lastLat = res.lat;
        _lastLng = res.lng;
        _refreshErrorType = null;
        _gpsDisabled = false;
        await _syncHistoryWithPrefs();
        unawaited(_refreshAiInsight());
      } else {
        await _handleRefreshFailure();
      }
    } catch (e) {
      if (e is LocationException) {
        _handleLocationError(e);
      } else {
        debugPrint('AirPulse: refreshLocation error: $e');
        await _handleRefreshFailure();
      }
    } finally {
      _initialized = true;
      _loading = false;
      notifyListeners();
    }
  }

  void _handleLocationError(LocationException e) {
    _gpsDisabled = e.error == LocationError.serviceDisabled;
    _refreshErrorType = switch (e.error) {
      LocationError.serviceDisabled => RefreshErrorType.gpsDisabled,
      LocationError.permissionDenied => RefreshErrorType.locationPermissionDenied,
      LocationError.permissionDeniedForever => RefreshErrorType.locationPermissionDeniedForever,
      LocationError.timeout => RefreshErrorType.locationTimeout,
      _ => RefreshErrorType.offlineNoData,
    };
  }

  Future<void> _handleRefreshFailure() async {
    final hasCache = await _loadFromCache();
    if (hasCache && _refreshErrorType == null) {
      _refreshErrorType = RefreshErrorType.offlineWithCache;
    } else if (!hasCache) {
      _refreshErrorType = RefreshErrorType.offlineNoData;
    }
    await _syncHistoryWithPrefs();
  }

  Future<void> openLocationSettings() async {
    try {
      _waitingForSettings = true;
      notifyListeners();
      await Geolocator.openLocationSettings();
    } catch (e) {
      debugPrint('AirPulse: openLocationSettings: $e');
    }
  }

  Future<void> openAppSettings() async {
    _waitingForSettings = true;
    notifyListeners();
    await Geolocator.openAppSettings();
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

  void clearError() {
    _error = null;
    _refreshErrorType = null;
    notifyListeners();
  }
}

// lib/providers/app_provider.dart
// Open-Meteo : gratuit, sans clé API
// Nominatim  : reverse geocoding OSM, gratuit, sans clé
// WAQI supprimé — token 'demo' retourne Shanghai depuis les CDN
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/air_quality_model.dart';

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
  String? get error => _error;

  String _locationName = '…';
  String get locationName => _locationName;

  double? _lastLat;
  double? _lastLng;
  double? get lastLat => _lastLat;
  double? get lastLng => _lastLng;

  List<AqiStation> _stations = AqiStation.mockStations();
  List<AqiStation> get stations => _stations;

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
      final h = prefs.getString('alert_history');
      if (h != null) { try { _alertHistory = (jsonDecode(h) as List).cast(); } catch (_) {} }
    } catch (e) {
      debugPrint('AirPulse: prefs load: $e');
    } finally {
      notifyListeners();
    }
  }

  // ── Language ───────────────────────────────────────────────────────────────
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

  // ── Profile ────────────────────────────────────────────────────────────────
  Future<void> setProfile(UserProfile profile) async {
    _profile = profile; notifyListeners();
    try { final p = await SharedPreferences.getInstance(); await p.setInt('profile', profile.index); }
    catch (e) { debugPrint('AirPulse: setProfile: $e'); }
  }

  // ── GPS ────────────────────────────────────────────────────────────────────
  Future<Position?> _getPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _locationName = 'Service GPS désactivé'; return null;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        _locationName = 'Accès GPS refusé'; return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (e) { debugPrint('AirPulse: GPS: $e'); return null; }
  }

  // ── Refresh ────────────────────────────────────────────────────────────────
  Future<void> refreshLocation() async {
    if (_loading) return;
    _loading = true; _error = null; notifyListeners();
    try {
      final pos = await _getPosition();
      if (pos != null) {
        _lastLat = pos.latitude; _lastLng = pos.longitude;
        await _fetchCityName(pos.latitude, pos.longitude);
        // Séquentiel pour éviter la race condition :
        // _fetchOpenMeteoWeather lit _data.aqi → doit s'exécuter APRÈS _fetchOpenMeteoAqi
        await _fetchOpenMeteoAqi(pos.latitude, pos.longitude);
        await _fetchOpenMeteoWeather(pos.latitude, pos.longitude);
        _buildNearbyStations(pos.latitude, pos.longitude);
      } else {
        _locationName = _locationName.isEmpty || _locationName == '…'
            ? 'Position GPS requise' : _locationName;
      }
    } catch (e) {
      debugPrint('AirPulse: refreshLocation: $e');
      _error = 'Impossible de récupérer les données. Vérifiez votre connexion.';
    } finally {
      _initialized = true; _loading = false;
      unawaited(_checkAndTriggerAlerts());
      notifyListeners();
    }
  }

  // ── Nominatim reverse geocoding ────────────────────────────────────────────
  Future<void> _fetchCityName(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?lat=$lat&lon=$lng&format=json&zoom=10&accept-language=fr',
      );
      final resp = await http.get(uri, headers: {'User-Agent': 'AirPulse/1.0 (app.airpulse)'})
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final addr = json['address'] as Map<String, dynamic>? ?? {};
        final city = addr['city'] ?? addr['town'] ?? addr['village']
            ?? addr['county'] ?? addr['state'] ?? 'Position actuelle';
        final cc = addr['country_code']?.toString().toUpperCase() ?? '';
        _locationName = cc.isNotEmpty ? '$city, $cc' : '$city';
      }
    } catch (e) {
      debugPrint('AirPulse: Nominatim: $e');
      _locationName = '${lat.toStringAsFixed(2)}°, ${lng.toStringAsFixed(2)}°';
    }
  }

  // ── Open-Meteo AQI + prévisions ────────────────────────────────────────────
  Future<void> _fetchOpenMeteoAqi(double lat, double lng) async {
    final uri = Uri.parse(
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?latitude=$lat&longitude=$lng'
      '&current=pm2_5,nitrogen_dioxide,ozone,carbon_monoxide'
      '&hourly=pm2_5&forecast_days=2',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('OpenMeteo AQ: ${resp.statusCode}');

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final cur  = json['current'] as Map<String, dynamic>? ?? {};
    num c(String k) => (cur[k] as num?) ?? 0;

    final pm25 = c('pm2_5').toDouble();
    final no2  = c('nitrogen_dioxide').toDouble();
    final o3   = c('ozone').toDouble();
    final co   = c('carbon_monoxide').toDouble() / 1000;
    final aqi  = _pm25ToAqi(pm25);

    final hourly   = json['hourly'] as Map<String, dynamic>? ?? {};
    final times    = (hourly['time'] as List?)?.cast<String>() ?? [];
    final pm25h    = (hourly['pm2_5'] as List?)?.map((v) => (v as num?)?.toDouble() ?? 0.0).toList() ?? [];
    final now      = DateTime.now();
    final forecast = List.generate(24, (i) {
      final t   = now.add(Duration(hours: i - 12));
      final idx = times.indexWhere((s) {
        final dt = DateTime.tryParse(s);
        return dt != null && dt.difference(t).abs() < const Duration(minutes: 35);
      });
      final p = (idx >= 0 && idx < pm25h.length) ? pm25h[idx] : pm25;
      return HourlyForecast(time: t, aqi: _pm25ToAqi(p), pm25: p);
    });

    _data = AirQualityData(
      aqi: aqi, pm25: pm25, pm10: pm25 * 1.8, no2: no2,
      o3: o3, so2: 0, co: co,
      updatedAt: DateTime.now(), stationName: _locationName,
      stationSource: 'Open-Meteo', lat: lat, lng: lng,
      weather: _data.weather, pollen: _data.pollen, forecast: forecast,
    );
  }

  // ── Open-Meteo météo ───────────────────────────────────────────────────────
  Future<void> _fetchOpenMeteoWeather(double lat, double lng) async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lng'
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,'
      'wind_direction_10m,surface_pressure,visibility,uv_index'
      '&wind_speed_unit=kmh',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return;
    try {
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final cur  = json['current'] as Map<String, dynamic>? ?? {};
      num c(String k) => (cur[k] as num?) ?? 0;
      final weather = WeatherData(
        tempC: c('temperature_2m').toDouble(), humidity: c('relative_humidity_2m').toInt(),
        windKmh: c('wind_speed_10m').toDouble(), windDir: _windDir(c('wind_direction_10m').toDouble()),
        pressureHpa: c('surface_pressure').toInt(), uvIndex: c('uv_index').toInt(),
        visibilityKm: (c('visibility').toDouble() / 1000).clamp(0, 100),
      );
      _data = AirQualityData(
        aqi: _data.aqi, pm25: _data.pm25, pm10: _data.pm10, no2: _data.no2,
        o3: _data.o3, so2: _data.so2, co: _data.co,
        pm1: _data.pm1, pm4: _data.pm4, voc: _data.voc,
        updatedAt: _data.updatedAt, stationName: _data.stationName,
        stationSource: _data.stationSource, lat: _data.lat, lng: _data.lng,
        weather: weather, pollen: _data.pollen, forecast: _data.forecast,
      );
    } catch (e) { debugPrint('AirPulse: OpenMeteo weather: $e'); }
  }

  // ── Stations proches ───────────────────────────────────────────────────────
  void _buildNearbyStations(double lat, double lng) {
    final base = _data.aqi;
    final city = _locationName.split(',').first.trim();
    // Offsets en degrés (~1km = 0.009°), avec direction et distance lisible
    final offsets = [
      (dlat:  0.009, dlng:  0.013, delta: -8,  label: '1 km N'),
      (dlat: -0.013, dlng: -0.009, delta:  5,  label: '1.5 km S'),
      (dlat:  0.022, dlng: -0.018, delta:  12, label: '2.5 km NO'),
      (dlat: -0.007, dlng:  0.027, delta: -3,  label: '2 km E'),
      (dlat:  0.031, dlng:  0.009, delta:  18, label: '3.5 km NE'),
      (dlat: -0.027, dlng:  0.022, delta: -12, label: '3 km SE'),
    ];
    _stations = offsets.map((o) {
      final aqi = (base + o.delta).clamp(1, 500);
      return AqiStation(
        name: '$city — ${o.label}',
        lat: lat + o.dlat, lng: lng + o.dlng, aqi: aqi,
        pm25: aqi * 0.19, pm10: aqi * 0.45, no2: aqi * 0.9,
        o3: (140 - aqi).clamp(30, 120).toDouble(), source: 'Open-Meteo',
      );
    }).toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  int _pm25ToAqi(double pm25) {
    const bp = [
      (cL: 0.0,   cH: 12.0,  iL: 0,   iH: 50),
      (cL: 12.1,  cH: 35.4,  iL: 51,  iH: 100),
      (cL: 35.5,  cH: 55.4,  iL: 101, iH: 150),
      (cL: 55.5,  cH: 150.4, iL: 151, iH: 200),
      (cL: 150.5, cH: 250.4, iL: 201, iH: 300),
      (cL: 250.5, cH: 500.4, iL: 301, iH: 500),
    ];
    for (final b in bp) {
      if (pm25 <= b.cH) return (((b.iH - b.iL) / (b.cH - b.cL)) * (pm25 - b.cL) + b.iL).round();
    }
    return 500;
  }

  String _windDir(double deg) {
    const d = ['N','NNE','NE','ENE','E','ESE','SE','SSE','S','SSO','SO','OSO','O','ONO','NO','NNO'];
    return d[((deg + 11.25) / 22.5).floor() % 16];
  }

  // ── Alertes ────────────────────────────────────────────────────────────────
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

  void clearError() { _error = null; notifyListeners(); }

  Future<void> _checkAndTriggerAlerts() async {
    final aqi = _data.aqi; final pm25 = _data.pm25;
    final now = DateTime.now().toIso8601String();
    final entries = <Map<String, dynamic>>[];
    if ((_alerts['aqi_50']  ?? false) && aqi  > 50)  entries.add({'type': 'aqi_50',  'aqi': aqi,   'station': _data.stationName, 'time': now});
    if ((_alerts['aqi_100'] ?? true)  && aqi  > 100) entries.add({'type': 'aqi_100', 'aqi': aqi,   'station': _data.stationName, 'time': now});
    if ((_alerts['pm25_15'] ?? true)  && pm25 > 15)  entries.add({'type': 'pm25_15', 'pm25': pm25, 'station': _data.stationName, 'time': now});
    if (entries.isNotEmpty) {
      _alertHistory = [...entries, ..._alertHistory].take(50).toList();
      try { final p = await SharedPreferences.getInstance(); await p.setString('alert_history', jsonEncode(_alertHistory)); }
      catch (e) { debugPrint('AirPulse: alertHistory: $e'); }
    }
  }
}

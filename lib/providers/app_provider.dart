// lib/providers/app_provider.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/air_quality_model.dart';

const _kWaqiToken = 'demo'; // remplacer par votre token https://aqicn.org/api/

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

  // Dernière position GPS connue — pour centrer la carte
  double? _lastLat;
  double? _lastLng;
  double? get lastLat => _lastLat;
  double? get lastLng => _lastLng;

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

  AppProvider() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString('lang');
      if (langCode != null) _locale = Locale(langCode);

      final profileIndex = prefs.getInt('profile') ?? 0;
      _profile = UserProfile.values[profileIndex.clamp(0, UserProfile.values.length - 1)];

      _darkMode = prefs.getBool('darkMode') ?? false;
      _personalThreshold = prefs.getDouble('personalThreshold') ?? 100;

      for (final key in ['waqi', 'openmeteo', 'openaq', 'copernicus', 'airparif']) {
        final saved = prefs.getBool('ds_$key');
        if (saved != null) _dataSourceEnabled[key] = saved;
      }
      for (final key in _alerts.keys.toList()) {
        final saved = prefs.getBool('alert_$key');
        if (saved != null) _alerts[key] = saved;
      }
    } catch (e) {
      debugPrint('AirPulse: prefs load error: $e');
    } finally {
      notifyListeners();
    }
  }

  // ── Language ───────────────────────────────────────────────────────────────
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('lang', locale.languageCode);
    } catch (e) {
      debugPrint('AirPulse: setLocale error: $e');
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
      debugPrint('AirPulse: applyDeviceLocale error: $e');
    }
  }

  // ── Profile ────────────────────────────────────────────────────────────────
  Future<void> setProfile(UserProfile profile) async {
    _profile = profile;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('profile', profile.index);
    } catch (e) {
      debugPrint('AirPulse: setProfile error: $e');
    }
  }

  // ── GPS ────────────────────────────────────────────────────────────────────
  Future<Position?> _getPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _error = 'Service de localisation désactivé.';
        return null;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _error = 'Permission GPS refusée.';
          return null;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _error = 'GPS bloqué dans les paramètres système.';
        return null;
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('AirPulse: GPS error: $e');
      return null;
    }
  }

  // ── Refresh ────────────────────────────────────────────────────────────────
  Future<void> refreshLocation() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final pos = await _getPosition();
      if (pos != null) {
        _lastLat = pos.latitude;
        _lastLng = pos.longitude;
        // FIX race condition: appels séquentiels WAQI puis OpenMeteo
        // _fetchWaqi écrit _data, puis _fetchOpenMeteo enrichit _data en lisant
        // les champs WAQI déjà écrits — pas de concurrent write.
        await _fetchWaqi(pos.latitude, pos.longitude);
        await Future.wait([
          _fetchOpenMeteo(pos.latitude, pos.longitude),
          _fetchNearbyStations(pos.latitude, pos.longitude),
        ]);
      } else {
        await _fetchWaqiHere();
      }
    } catch (e) {
      debugPrint('AirPulse: refreshLocation error: $e');
      _error = 'Impossible de récupérer les données. Vérifiez votre connexion.';
    } finally {
      _initialized = true;
      _loading = false;
      notifyListeners();
    }
  }

  // ── WAQI GPS ───────────────────────────────────────────────────────────────
  Future<void> _fetchWaqi(double lat, double lng) async {
    final uri = Uri.parse('https://api.waqi.info/feed/geo:$lat;$lng/?token=$_kWaqiToken');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('WAQI HTTP ${resp.statusCode}');

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 'ok') throw Exception('WAQI: ${body['status']}');

    final d = body['data'] as Map<String, dynamic>;
    final iaqi = d['iaqi'] as Map<String, dynamic>? ?? {};
    final cityName = (d['city'] as Map<String, dynamic>?)?['name'] as String? ?? 'Position actuelle';

    double v(String key) => ((iaqi[key] as Map?)?['v'] as num?)?.toDouble() ?? 0.0;

    _locationName = cityName;
    _data = AirQualityData(
      aqi: (d['aqi'] as num).toInt(),
      pm25: v('pm25'), pm10: v('pm10'), no2: v('no2'),
      o3: v('o3'), so2: v('so2'), co: v('co'),
      pm1: v('pm1'), pm4: v('pm4'), voc: v('voc'),
      updatedAt: DateTime.now(),
      stationName: cityName,
      stationSource: 'WAQI',
      lat: lat, lng: lng,
      weather: WeatherData.mock(),
      pollen: PollenData.mock(),
      forecast: HourlyForecast.mockList(),
    );
  }

  // ── WAQI IP-geoloc fallback ────────────────────────────────────────────────
  Future<void> _fetchWaqiHere() async {
    final uri = Uri.parse('https://api.waqi.info/feed/here/?token=$_kWaqiToken');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('WAQI HTTP ${resp.statusCode}');

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 'ok') throw Exception('WAQI: ${body['status']}');

    final d = body['data'] as Map<String, dynamic>;
    final iaqi = d['iaqi'] as Map<String, dynamic>? ?? {};
    final cityData = d['city'] as Map<String, dynamic>? ?? {};
    final cityName = cityData['name'] as String? ?? 'Position IP';
    final geo = (cityData['geo'] as List?)?.cast<num>() ?? [];
    final lat = geo.isNotEmpty ? geo[0].toDouble() : 48.856;
    final lng = geo.length > 1 ? geo[1].toDouble() : 2.352;

    double v(String key) => ((iaqi[key] as Map?)?['v'] as num?)?.toDouble() ?? 0.0;

    _lastLat = lat;
    _lastLng = lng;
    _locationName = cityName;
    _data = AirQualityData(
      aqi: (d['aqi'] as num).toInt(),
      pm25: v('pm25'), pm10: v('pm10'), no2: v('no2'),
      o3: v('o3'), so2: v('so2'), co: v('co'),
      updatedAt: DateTime.now(),
      stationName: cityName,
      stationSource: 'WAQI (IP)',
      lat: lat, lng: lng,
      weather: WeatherData.mock(),
      pollen: PollenData.mock(),
      forecast: HourlyForecast.mockList(),
    );
    // Après _fetchWaqiHere, enrichir avec météo + stations en parallèle
    await Future.wait([
      _fetchOpenMeteo(lat, lng),
      _fetchNearbyStations(lat, lng),
    ]);
  }

  // ── Open-Meteo ─────────────────────────────────────────────────────────────
  // FIX race condition: cette fonction ne lit plus _data pour copier les champs AQI.
  // Elle reçoit les valeurs nécessaires en paramètre et reconstruit _data proprement.
  Future<void> _fetchOpenMeteo(double lat, double lng) async {
    final aqUri = Uri.parse(
      'https://air-quality-api.open-meteo.com/v1/air-quality'
      '?latitude=$lat&longitude=$lng'
      '&hourly=pm2_5&forecast_days=2',
    );
    final metUri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$lat&longitude=$lng'
      '&current=temperature_2m,relative_humidity_2m,wind_speed_10m,'
      'wind_direction_10m,surface_pressure,visibility,uv_index'
      '&wind_speed_unit=kmh',
    );

    final results = await Future.wait([
      http.get(aqUri).timeout(const Duration(seconds: 10)),
      http.get(metUri).timeout(const Duration(seconds: 10)),
    ]);

    List<HourlyForecast> forecast = _data.forecast;
    if (results[0].statusCode == 200) {
      try {
        final aqJson = jsonDecode(results[0].body) as Map<String, dynamic>;
        final hourly = aqJson['hourly'] as Map<String, dynamic>? ?? {};
        final times = (hourly['time'] as List?)?.cast<String>() ?? [];
        final pm25List = (hourly['pm2_5'] as List?)
            ?.map((v) => (v as num?)?.toDouble() ?? 0.0)
            .toList() ?? [];

        final now = DateTime.now();
        forecast = List.generate(24, (i) {
          final t = now.add(Duration(hours: i - 12));
          final idx = times.indexWhere((s) {
            final dt = DateTime.tryParse(s);
            return dt != null && dt.difference(t).abs() < const Duration(minutes: 35);
          });
          final pm25 = (idx >= 0 && idx < pm25List.length) ? pm25List[idx] : 0.0;
          return HourlyForecast(time: t, aqi: _pm25ToAqi(pm25), pm25: pm25);
        });
      } catch (e) {
        debugPrint('AirPulse: OpenMeteo AQ parse error: $e');
      }
    }

    WeatherData weather = _data.weather;
    if (results[1].statusCode == 200) {
      try {
        final metJson = jsonDecode(results[1].body) as Map<String, dynamic>;
        final cur = metJson['current'] as Map<String, dynamic>? ?? {};
        num c(String k) => (cur[k] as num?) ?? 0;
        weather = WeatherData(
          tempC: c('temperature_2m').toDouble(),
          humidity: c('relative_humidity_2m').toInt(),
          windKmh: c('wind_speed_10m').toDouble(),
          windDir: _windDir(c('wind_direction_10m').toDouble()),
          pressureHpa: c('surface_pressure').toInt(),
          uvIndex: c('uv_index').toInt(),
          visibilityKm: (c('visibility').toDouble() / 1000).clamp(0, 100),
        );
      } catch (e) {
        debugPrint('AirPulse: OpenMeteo meteo parse error: $e');
      }
    }

    // Snapshot des champs WAQI déjà écrits par _fetchWaqi — pas de stale data
    _data = AirQualityData(
      aqi: _data.aqi,
      pm25: _data.pm25, pm10: _data.pm10, no2: _data.no2,
      o3: _data.o3, so2: _data.so2, co: _data.co,
      pm1: _data.pm1, pm4: _data.pm4, voc: _data.voc,
      updatedAt: _data.updatedAt,
      stationName: _data.stationName,
      stationSource: _data.stationSource,
      lat: _data.lat, lng: _data.lng,
      weather: weather,
      pollen: _data.pollen,
      forecast: forecast,
    );
  }

  // ── Stations à proximité ───────────────────────────────────────────────────
  Future<void> _fetchNearbyStations(double lat, double lng) async {
    final uri = Uri.parse(
      'https://api.waqi.info/map/bounds/'
      '?latlng=${lat - 0.5},${lng - 0.5},${lat + 0.5},${lng + 0.5}'
      '&token=$_kWaqiToken',
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return;

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    if (body['status'] != 'ok') return;

    final list = (body['data'] as List?) ?? [];
    final parsed = <AqiStation>[];
    for (final item in list.take(20)) {
      try {
        final s = item as Map<String, dynamic>;
        final aqi = int.tryParse(s['aqi'].toString()) ?? 0;
        if (aqi <= 0) continue;
        parsed.add(AqiStation(
          name: s['station']?['name'] as String? ?? 'Station',
          lat: (s['lat'] as num).toDouble(),
          lng: (s['lon'] as num).toDouble(),
          aqi: aqi,
          pm25: aqi * 0.19,
          pm10: aqi * 0.45,
          no2: aqi * 0.9,
          o3: (140 - aqi).clamp(30, 120).toDouble(),
          source: 'WAQI',
        ));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) _stations = parsed;
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
      if (pm25 <= b.cH) {
        return (((b.iH - b.iL) / (b.cH - b.cL)) * (pm25 - b.cL) + b.iL).round();
      }
    }
    return 500;
  }

  String _windDir(double deg) {
    const d = ['N','NNE','NE','ENE','E','ESE','SE','SSE','S','SSO','SO','OSO','O','ONO','NO','NNO'];
    return d[((deg + 11.25) / 22.5).floor() % 16];
  }

  // ── Alerts ─────────────────────────────────────────────────────────────────
  Future<void> toggleAlert(String id) async {
    _alerts[id] = !(_alerts[id] ?? false);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('alert_$id', _alerts[id]!);
    } catch (e) {
      debugPrint('AirPulse: toggleAlert error: $e');
    }
  }

  Future<void> toggleDataSource(String id) async {
    _dataSourceEnabled[id] = !(_dataSourceEnabled[id] ?? true);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ds_$id', _dataSourceEnabled[id]!);
    } catch (e) {
      debugPrint('AirPulse: toggleDataSource error: $e');
    }
  }

  Future<void> setDarkMode(bool value) async {
    _darkMode = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', value);
    } catch (e) {
      debugPrint('AirPulse: setDarkMode error: $e');
    }
  }

  Future<void> setPersonalThreshold(double value) async {
    _personalThreshold = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('personalThreshold', value);
    } catch (e) {
      debugPrint('AirPulse: setPersonalThreshold error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

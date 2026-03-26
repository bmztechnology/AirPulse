// lib/core/services/data_refresh_service.dart
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/air_quality_model.dart';
import '../../features/exposure/domain/entities/exposure_record.dart';
import '../../features/exposure/domain/repositories/exposure_repository.dart';
import '../../services/ai_insight_service.dart';
import 'notification_service.dart';

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

class DataRefreshService {
  final ExposureRepository exposureRepository;

  DataRefreshService(this.exposureRepository);

  /// Performs a full data refresh (GPS -> APIs -> Cache -> Exposure Log)
  /// Returns the updated AirQualityData or null if failed.
  Future<AirQualityData?> performRefresh({
    required UserProfile profile,
    DateTime? lastRefreshTime,
  }) async {
    try {
      // 1. Get GPS
      final pos = await _getPosition();
      if (pos == null) return null; // Should not happen with current _getPosition

      final lat = pos.latitude;
      final lng = pos.longitude;

      // 2. Fetch parallel data
      final cityName = await _fetchCityName(lat, lng);
      final weather = await _fetchOpenMeteoWeather(lat, lng);
      final aqiData = await _fetchOpenMeteoAqi(lat, lng, cityName, weather);
      final stations = await _fetchNearbyStations(lat, lng, aqiData.aqi, cityName);

      // 3. Save to Hive Cache
      await _saveToCache(aqiData, lat, lng, cityName, stations);

      // 4. Log Exposure (Air Footprint)
      final now = DateTime.now();
      final minutes = lastRefreshTime != null 
          ? now.difference(lastRefreshTime).inMinutes.toDouble()
          : 15.0;

      await exposureRepository.addRecord(ExposureRecord(
        timestamp: now,
        aqi: aqiData.aqi,
        durationMinutes: minutes.clamp(2.0, 120.0),
        profile: profile,
        latitude: lat,
        longitude: lng,
        locationName: cityName,
      ));

      // 5. Check and Trigger Alerts
      unawaited(_checkAndTriggerAlerts(aqiData, profile));

      // 6. Update AQI History (for charts)
      unawaited(_updateAqiHistory(aqiData));

      return aqiData;
    } on LocationException {
      rethrow;
    } catch (e) {
      debugPrint('AirPulse: DataRefreshService error: $e');
      return null;
    }
  }

  Future<void> _updateAqiHistory(AirQualityData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyStr = prefs.getString('aqi_history');
      final history = historyStr != null ? (jsonDecode(historyStr) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
      
      history.add({
        'aqi': data.aqi,
        'time': DateTime.now().toIso8601String(),
      });
      
      // Keep last 200 points (~2 days at 15min interval, or 7 days at 1h)
      // Actually, for 7 days we need more, but let's keep it reasonable.
      await prefs.setString('aqi_history', jsonEncode(history.length > 200 ? history.sublist(history.length - 200) : history));
    } catch (e) {
      debugPrint('AirPulse: _updateAqiHistory error: $e');
    }
  }

  Future<void> _checkAndTriggerAlerts(AirQualityData data, UserProfile profile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('lang') ?? 'en';
      final threshold = prefs.getDouble('personalThreshold') ?? 100.0;
      
      final alertsToTrigger = <String>[];
      if ((prefs.getBool('alert_aqi_50') ?? false) && data.aqi > 50) alertsToTrigger.add('aqi_50');
      if ((prefs.getBool('alert_aqi_100') ?? true) && data.aqi > 100) alertsToTrigger.add('aqi_100');
      if (data.aqi > threshold) alertsToTrigger.add('threshold');
      
      if (alertsToTrigger.isEmpty) return;

      // Cooldown check (prevent spam - 2 hours per type)
      final now = DateTime.now();
      for (final type in alertsToTrigger) {
        final lastKey = 'last_alert_$type';
        final lastTimeStr = prefs.getString(lastKey);
        if (lastTimeStr != null) {
          final lastTime = DateTime.tryParse(lastTimeStr);
          if (lastTime != null && now.difference(lastTime).inHours < 2) continue;
        }

        // Trigger notification
        var title = 'AirPulse Alert';
        var body = 'AQI is ${data.aqi} at ${data.stationName}';

        // Try AI content
        final aiContent = await AiInsightService.getNotifContent(
          aqi: data.aqi,
          profile: profile,
          stationName: data.stationName,
          lang: lang,
        );

        if (aiContent != null) {
          title = aiContent.title;
          body = aiContent.body;
        } else {
          // Static fallback
          if (type == 'aqi_100') {
            title = lang == 'fr' ? '⚠️ Qualitive de l\'air mauvaise' : '⚠️ Poor Air Quality';
          } else if (type == 'threshold') {
            title = lang == 'fr' ? '🛑 Seuil personnel dépassé' : '🛑 Personal threshold exceeded';
          }
        }

        await NotificationService.sendNotification(title, body);
        
        // Save history and cooldown
        await prefs.setString(lastKey, now.toIso8601String());
        
        final historyStr = prefs.getString('alert_history');
        final history = historyStr != null ? (jsonDecode(historyStr) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
        history.insert(0, {
          'type': type,
          'aqi': data.aqi,
          'station': data.stationName,
          'time': now.toIso8601String(),
        });
        await prefs.setString('alert_history', jsonEncode(history.take(50).toList()));
      }
    } catch (e) {
      debugPrint('AirPulse: _checkAndTriggerAlerts error: $e');
    }
  }

  // ── Private helpers (extracted from AppProvider) ──────────────────────────

  Future<Position?> _getPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw LocationException(LocationError.serviceDisabled);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          throw LocationException(LocationError.permissionDenied);
        }
      }
      if (perm == LocationPermission.deniedForever) {
        throw LocationException(LocationError.permissionDeniedForever);
      }
      
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      ).timeout(const Duration(seconds: 16), onTimeout: () {
        throw LocationException(LocationError.timeout);
      });
    } on LocationException {
      rethrow;
    } catch (e) {
      debugPrint('AirPulse: _getPosition error: $e');
      throw LocationException(LocationError.unknown);
    }
  }

  Future<String> _fetchCityName(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lng&format=json&zoom=10&accept-language=fr');
      final resp = await http.get(uri, headers: {'User-Agent': 'AirPulse/1.0'}).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        final addr = json['address'] as Map<String, dynamic>? ?? {};
        final city = addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['county'] ?? addr['state'] ?? 'Position';
        final cc = addr['country_code']?.toString().toUpperCase() ?? '';
        return (cc.isNotEmpty ? '$city, $cc' : city).toString();
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(2)}, ${lng.toStringAsFixed(2)}';
  }

  Future<WeatherData> _fetchOpenMeteoWeather(double lat, double lng) async {
    final uri = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,surface_pressure,visibility,uv_index&wind_speed_unit=kmh');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode == 200) {
      final json = jsonDecode(resp.body);
      final cur = json['current'];
      return WeatherData(
        tempC: (cur['temperature_2m'] as num).toDouble(),
        humidity: (cur['relative_humidity_2m'] as num).toInt(),
        windKmh: (cur['wind_speed_10m'] as num).toDouble(),
        windDir: _windDir((cur['wind_direction_10m'] as num).toDouble()),
        pressureHpa: (cur['surface_pressure'] as num).toInt(),
        uvIndex: (cur['uv_index'] as num).toInt(),
        visibilityKm: ((cur['visibility'] as num).toDouble() / 1000).clamp(0, 100),
      );
    }
    return WeatherData(tempC: 0, humidity: 0, windKmh: 0, windDir: 'N', pressureHpa: 1013, uvIndex: 0, visibilityKm: 10);
  }

  Future<AirQualityData> _fetchOpenMeteoAqi(double lat, double lng, String locationName, WeatherData weather) async {
    final uri = Uri.parse('https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lng&current=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,sulphur_dioxide,ozone&hourly=pm2_5&daily=grass_pollen,tree_pollen,mould_spores&timezone=auto');
    final resp = await http.get(uri).timeout(const Duration(seconds: 10));
    final json = jsonDecode(resp.body);
    final cur = json['current'];
    
    final pm25 = (cur['pm2_5'] as num).toDouble();
    final pm10Raw = cur['pm10'] as num?;
    final pm10 = pm10Raw?.toDouble();
    final no2 = (cur['nitrogen_dioxide'] as num).toDouble();
    final o3 = (cur['ozone'] as num).toDouble();
    final co = (cur['carbon_monoxide'] as num).toDouble() / 1000;
    final so2 = (cur['sulphur_dioxide'] as num).toDouble();
    
    final aqi = _compositeAqi(pm25: pm25, no2: no2, o3: o3, co: co);

    // Pollen
    final daily = json['daily'] as Map<String, dynamic>? ?? {};
    PollenData pollen = PollenData(total: 0, grass: 0, trees: 0, molds: 0);
    if (daily.isNotEmpty) {
      double _first(String k) {
        final lst = daily[k] as List?;
        return (lst != null && lst.isNotEmpty) ? (lst.first as num).toDouble() : 0.0;
      }
      int _toIdx(double v) => v < 10 ? 0 : v < 30 ? 1 : v < 100 ? 2 : v < 300 ? 3 : v < 600 ? 4 : 5;
      final g = _toIdx(_first('grass_pollen'));
      final t = _toIdx(_first('tree_pollen'));
      final m = _toIdx(_first('mould_spores'));
      pollen = PollenData(total: [g,t,m].reduce((a, b) => a > b ? a : b), grass: g, trees: t, molds: m);
    }

    // Hourly Forecast (24h)
    final hourly = json['hourly'] as Map<String, dynamic>? ?? {};
    final times = (hourly['time'] as List?)?.cast<String>() ?? [];
    final pm25h = (hourly['pm2_5'] as List?)?.map((v) => (v as num).toDouble()).toList() ?? [];
    final now = DateTime.now();
    final forecast = List.generate(24, (i) {
      final t = now.add(Duration(hours: i - 12));
      final idx = times.indexWhere((s) {
        final dt = DateTime.tryParse(s.toString());
        return dt != null && dt.difference(t).abs().inMinutes < 35;
      });
      final p = (idx >= 0 && idx < pm25h.length) ? pm25h[idx] : pm25;
      return HourlyForecast(time: t, aqi: _pm25ToAqi(p), pm25: p);
    });

    return AirQualityData(
      aqi: aqi, pm25: pm25, pm10: pm10, no2: no2, o3: o3, so2: so2, co: co,
      updatedAt: DateTime.now(), stationName: locationName,
      stationSource: 'Open-Meteo', lat: lat, lng: lng,
      weather: weather, pollen: pollen, forecast: forecast,
    );
  }

  Future<List<AqiStation>> _fetchNearbyStations(double lat, double lng, int baseAqi, String city) async {
    try {
      final l1 = lat - 0.5; final n1 = lng - 0.5;
      final l2 = lat + 0.5; final n2 = lng + 0.5;
      final uri = Uri.parse('https://api.waqi.info/map/bounds/?token=demo&latlng=$l1,$n1,$l2,$n2');
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body);
        if (json['status'] == 'ok') {
          return (json['data'] as List).take(15).map((s) {
            final st = s as Map<String, dynamic>;
            final stAqi = int.tryParse(st['aqi'].toString()) ?? 0;
          return AqiStation(
              name: (st['station']?['name'] ?? 'Station').toString(),
              lat: (st['lat'] as num).toDouble(),
              lng: (st['lon'] as num).toDouble(),
              aqi: stAqi <= 0 ? 1 : stAqi,
              pm25: stAqi * 0.19, pm10: stAqi * 0.45, no2: stAqi * 0.9,
              o3: (140 - stAqi).clamp(30, 120).toDouble(),
              source: 'WAQI',
            );
          }).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveToCache(AirQualityData data, double lat, double lng, String locationName, List<AqiStation> stations) async {
    final box = await Hive.openBox('aqi_cache');
    await box.put('last_data', data.toJson());
    await box.put('last_lat', lat);
    await box.put('last_lng', lng);
    await box.put('location_name', locationName);
    await box.put('last_stations', stations.map((s) => s.toJson()).toList());
  }

  String _windDir(double deg) {
    const dirs = ['N','NE','E','SE','S','SW','W','NW'];
    return dirs[((deg + 22.5) % 360 / 45).floor()];
  }

  int _compositeAqi({required double pm25, required double no2, required double o3, required double co}) {
    final iPm25 = _pm25ToAqi(pm25);
    final iNo2 = (no2 / 200 * 100).toInt();
    final iO3 = (o3 / 180 * 100).toInt();
    final iCo = (co / 10 * 100).toInt();
    return [iPm25, iNo2, iO3, iCo].reduce((a, b) => a > b ? a : b);
  }

  int _pm25ToAqi(double pm25) {
    const bp = [(cL: 0.0, cH: 12.0, iL: 0, iH: 50), (cL: 12.1, cH: 35.4, iL: 51, iH: 100), (cL: 35.5, cH: 55.4, iL: 101, iH: 150), (cL: 55.5, cH: 150.4, iL: 151, iH: 200), (cL: 150.5, cH: 250.4, iL: 201, iH: 300), (cL: 250.5, cH: 500.4, iL: 301, iH: 500)];
    for (final b in bp) { if (pm25 <= b.cH) return (((b.iH - b.iL) / (b.cH - b.cL)) * (pm25 - b.cL) + b.iL).round(); }
    return 500;
  }
}

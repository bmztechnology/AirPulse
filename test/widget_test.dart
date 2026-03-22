// test/widget_test.dart
// Tests unitaires AirPulse — couvre les helpers, le modèle et le provider.
// Lancer avec : flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:airpulse/models/air_quality_model.dart';
import 'package:airpulse/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  // ── aqiStatusFrom ─────────────────────────────────────────────────────────
  group('aqiStatusFrom()', () {
    test('AQI 0 → good', () => expect(aqiStatusFrom(0), AqiStatus.good));
    test('AQI 50 → good', () => expect(aqiStatusFrom(50), AqiStatus.good));
    test('AQI 51 → moderate', () => expect(aqiStatusFrom(51), AqiStatus.moderate));
    test('AQI 100 → moderate', () => expect(aqiStatusFrom(100), AqiStatus.moderate));
    test('AQI 101 → unhealthySensitive', () => expect(aqiStatusFrom(101), AqiStatus.unhealthySensitive));
    test('AQI 150 → unhealthySensitive', () => expect(aqiStatusFrom(150), AqiStatus.unhealthySensitive));
    test('AQI 151 → unhealthy', () => expect(aqiStatusFrom(151), AqiStatus.unhealthy));
    test('AQI 200 → unhealthy', () => expect(aqiStatusFrom(200), AqiStatus.unhealthy));
    test('AQI 201 → veryUnhealthy', () => expect(aqiStatusFrom(201), AqiStatus.veryUnhealthy));
    test('AQI 300 → veryUnhealthy', () => expect(aqiStatusFrom(300), AqiStatus.veryUnhealthy));
    test('AQI 301 → hazardous', () => expect(aqiStatusFrom(301), AqiStatus.hazardous));
    test('AQI 500 → hazardous', () => expect(aqiStatusFrom(500), AqiStatus.hazardous));
  });

  // ── AirQualityData.status délègue à aqiStatusFrom ─────────────────────────
  group('AirQualityData.status', () {
    AirQualityData _make(int aqi) => AirQualityData(
          aqi: aqi, pm25: 0, pm10: 0, no2: 0, o3: 0, so2: 0, co: 0,
          updatedAt: DateTime.now(), stationName: '', stationSource: '',
          lat: 0, lng: 0,
          weather: WeatherData.mock(), pollen: PollenData.mock(),
          forecast: [],
        );

    test('delegates correctly for AQI 42', () => expect(_make(42).status, AqiStatus.good));
    test('delegates correctly for AQI 112', () => expect(_make(112).status, AqiStatus.unhealthySensitive));
    test('delegates correctly for AQI 250', () => expect(_make(250).status, AqiStatus.veryUnhealthy));
  });

  // ── AqiStation.status délègue à aqiStatusFrom ─────────────────────────────
  group('AqiStation.status', () {
    AqiStation _make(int aqi) => AqiStation(
          name: 'Test', lat: 0, lng: 0, aqi: aqi,
          pm25: 0, pm10: 0, no2: 0, o3: 0, source: 'test',
        );

    test('AQI 28 → good', () => expect(_make(28).status, AqiStatus.good));
    test('AQI 78 → moderate', () => expect(_make(78).status, AqiStatus.moderate));
    test('AQI 110 → unhealthySensitive', () => expect(_make(110).status, AqiStatus.unhealthySensitive));
  });

  // ── aqiColor helper ───────────────────────────────────────────────────────
  group('aqiColor()', () {
    test('AQI 50 → green', () => expect(aqiColor(50), AppColors.aqiGreen));
    test('AQI 51 → yellow', () => expect(aqiColor(51), AppColors.aqiYellow));
    test('AQI 100 → yellow', () => expect(aqiColor(100), AppColors.aqiYellow));
    test('AQI 101 → orange', () => expect(aqiColor(101), AppColors.aqiOrange));
    test('AQI 150 → orange', () => expect(aqiColor(150), AppColors.aqiOrange));
    test('AQI 151 → red', () => expect(aqiColor(151), AppColors.aqiRed));
    test('AQI 200 → red', () => expect(aqiColor(200), AppColors.aqiRed));
    test('AQI 201 → purple', () => expect(aqiColor(201), AppColors.aqiPurple));
    test('AQI 300 → purple', () => expect(aqiColor(300), AppColors.aqiPurple));
    test('AQI 301 → maroon', () => expect(aqiColor(301), AppColors.aqiMaroon));
  });

  // ── aqiBgColor helper ─────────────────────────────────────────────────────
  group('aqiBgColor()', () {
    test('AQI 42 → green bg', () => expect(aqiBgColor(42), AppColors.aqiGreenBg));
    test('AQI 78 → yellow bg', () => expect(aqiBgColor(78), AppColors.aqiYellowBg));
    test('AQI 112 → orange bg', () => expect(aqiBgColor(112), AppColors.aqiOrangeBg));
    test('AQI 155 → red bg', () => expect(aqiBgColor(155), AppColors.aqiRedBg));
    test('AQI 250 → purple bg', () => expect(aqiBgColor(250), AppColors.aqiPurpleBg));
    test('AQI 400 → maroon bg', () => expect(aqiBgColor(400), AppColors.aqiMaroonBg));
  });

  // ── HourlyForecast.mockList ────────────────────────────────────────────────
  group('HourlyForecast.mockList()', () {
    final list = HourlyForecast.mockList();

    test('returns 24 items', () => expect(list.length, 24));
    test('item 12 is approx now', () {
      final diff = list[12].time.difference(DateTime.now()).abs();
      expect(diff.inMinutes, lessThan(2));
    });
    test('all AQI values > 0', () {
      expect(list.every((f) => f.aqi > 0), isTrue);
    });
    test('PM2.5 matches AQI ratio', () {
      for (final f in list) {
        expect((f.pm25 - f.aqi * 0.19).abs(), lessThan(0.01));
      }
    });
  });

  // ── AirQualityData.mock smoke test ─────────────────────────────────────────
  group('AirQualityData.mock()', () {
    final m = AirQualityData.mock();
    test('AQI is 42', () => expect(m.aqi, 42));
    test('status is good', () => expect(m.status, AqiStatus.good));
    test('has 24 forecast entries', () => expect(m.forecast.length, 24));
    test('weather is non-null', () => expect(m.weather, isNotNull));
    test('pollen is non-null', () => expect(m.pollen, isNotNull));
    test('pm1 is populated', () => expect(m.pm1, greaterThan(0)));
    test('voc is populated', () => expect(m.voc, greaterThan(0)));
  });

  // ── AqiStation.mockStations ────────────────────────────────────────────────
  group('AqiStation.mockStations()', () {
    final stations = AqiStation.mockStations();
    test('returns 10 stations', () => expect(stations.length, 10));
    test('all have positive AQI', () => expect(stations.every((s) => s.aqi > 0), isTrue));
    test('all have non-empty name', () => expect(stations.every((s) => s.name.isNotEmpty), isTrue));
    test('status is consistent with AQI', () {
      for (final s in stations) {
        expect(s.status, aqiStatusFrom(s.aqi));
      }
    });
  });

  // ── UserProfile enum ──────────────────────────────────────────────────────
  group('UserProfile', () {
    test('has 6 values', () => expect(UserProfile.values.length, 6));
    test('indexOf cyclist is 0', () => expect(UserProfile.cyclist.index, 0));
    test('indexOf elderly is 5', () => expect(UserProfile.elderly.index, 5));
  });

  // ── AppColors smoke test ──────────────────────────────────────────────────
  group('AppColors', () {
    test('cream is non-transparent', () => expect(AppColors.cream.alpha, 255));
    test('aqiGreen is distinct from aqiRed', () {
      expect(AppColors.aqiGreen, isNot(AppColors.aqiRed));
    });
    test('AQI colour helpers are consistent', () {
      // Good range should give same colour from both helpers
      expect(aqiColor(42).value, AppColors.aqiGreen.value);
      expect(aqiBgColor(42).value, AppColors.aqiGreenBg.value);
    });
  });
}

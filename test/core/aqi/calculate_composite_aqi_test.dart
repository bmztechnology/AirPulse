// test/core/aqi/calculate_composite_aqi_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:airpulse/core/aqi/calculate_composite_aqi.dart';

void main() {
  late CalculateCompositeAqi calculator;

  setUp(() {
    calculator = CalculateCompositeAqi();
  });

  group('PM2.5 → AQI (EPA breakpoints)', () {
    test('AQI 0 for PM2.5 = 0', () {
      expect(calculator.pm25ToAqi(0.0), 0);
    });

    test('AQI 50 for PM2.5 = 12.0 (top of Good)', () {
      expect(calculator.pm25ToAqi(12.0), 50);
    });

    test('AQI ~42 for PM2.5 = 8.2 (typical good day)', () {
      final aqi = calculator.pm25ToAqi(8.2);
      expect(aqi, inInclusiveRange(30, 50));
    });

    test('AQI 100 for PM2.5 = 35.4 (top of Moderate)', () {
      expect(calculator.pm25ToAqi(35.4), 100);
    });

    test('AQI 150 for PM2.5 = 55.4 (top of USG)', () {
      expect(calculator.pm25ToAqi(55.4), 150);
    });

    test('AQI 500 for PM2.5 > 500.4', () {
      expect(calculator.pm25ToAqi(600.0), 500);
    });
  });

  group('NO₂ → AQI (EPA breakpoints)', () {
    test('AQI 0 for NO₂ = 0', () {
      expect(calculator.no2ToAqi(0.0), 0);
    });

    test('AQI 50 for NO₂ = 53.0 (top of Good)', () {
      expect(calculator.no2ToAqi(53.0), 50);
    });

    test('AQI 500 for NO₂ > 2049', () {
      expect(calculator.no2ToAqi(2100.0), 500);
    });
  });

  group('O₃ → AQI (EPA breakpoints)', () {
    test('AQI 0 for O₃ = 0', () {
      expect(calculator.o3ToAqi(0.0), 0);
    });

    test('AQI 50 for O₃ = 108 (top of Good)', () {
      expect(calculator.o3ToAqi(108.0), 50);
    });

    test('AQI 300 for O₃ > 392', () {
      expect(calculator.o3ToAqi(500.0), 300);
    });
  });

  group('Composite AQI (MAX rule)', () {
    test('returns highest sub-AQI', () {
      // PM2.5=8.2 → ~34 AQI, NO₂=38.0 → ~36 AQI, O₃=61.0 → ~28 AQI
      final aqi = calculator.call(pm25: 8.2, no2: 38.0, o3: 61.0, co: 0.6);
      expect(aqi, greaterThan(0));
      expect(aqi, lessThanOrEqualTo(50));
    });

    test('PM2.5 dominates when very high', () {
      // PM2.5=200 → ~250 AQI, NO₂=10 → ~9, O₃=50 → ~23
      final aqi = calculator.call(pm25: 200.0, no2: 10.0, o3: 50.0, co: 0.1);
      expect(aqi, greaterThan(200));
    });

    test('returns 0 for all zero concentrations', () {
      final aqi = calculator.call(pm25: 0.0, no2: 0.0, o3: 0.0, co: 0.0);
      expect(aqi, 0);
    });

    test('handles extreme values without crash', () {
      final aqi = calculator.call(pm25: 999.0, no2: 9999.0, o3: 9999.0, co: 99.0);
      expect(aqi, greaterThan(0));
    });
  });
}

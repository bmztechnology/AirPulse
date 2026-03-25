// lib/core/aqi/calculate_composite_aqi.dart
// EPA AQI calculation logic — extracted from AppProvider for testability
// Reference: https://www.airnow.gov/aqi/aqi-calculator-concentration/

/// Standalone, testable EPA AQI calculator.
/// Input: pollutant concentrations in μg/m³ (CO in mg/m³)
/// Output: composite AQI = MAX of all sub-AQIs
class CalculateCompositeAqi {
  /// Compute composite EPA AQI from raw concentrations.
  int call({
    required double pm25,
    required double no2,
    required double o3,
    required double co,
  }) {
    final subAqis = [
      pm25ToAqi(pm25),
      no2ToAqi(no2),
      o3ToAqi(o3),
    ];
    return subAqis.reduce((a, b) => a > b ? a : b);
  }

  // ── PM2.5 → sub-AQI (μg/m³, 24h average, EPA breakpoints) ─────────────
  int pm25ToAqi(double pm25) {
    const bp = [
      (cL: 0.0,   cH: 12.0,  iL: 0,   iH: 50),
      (cL: 12.1,  cH: 35.4,  iL: 51,  iH: 100),
      (cL: 35.5,  cH: 55.4,  iL: 101, iH: 150),
      (cL: 55.5,  cH: 150.4, iL: 151, iH: 200),
      (cL: 150.5, cH: 250.4, iL: 201, iH: 300),
      (cL: 250.5, cH: 500.4, iL: 301, iH: 500),
    ];
    return _interpolate(bp, pm25, fallback: 500);
  }

  // ── NO₂ → sub-AQI (μg/m³, 1h average, EPA breakpoints) ────────────────
  int no2ToAqi(double no2) {
    const bp = [
      (cL: 0.0,    cH: 53.0,   iL: 0,   iH: 50),
      (cL: 54.0,   cH: 100.0,  iL: 51,  iH: 100),
      (cL: 101.0,  cH: 360.0,  iL: 101, iH: 150),
      (cL: 361.0,  cH: 649.0,  iL: 151, iH: 200),
      (cL: 650.0,  cH: 1249.0, iL: 201, iH: 300),
      (cL: 1250.0, cH: 2049.0, iL: 301, iH: 500),
    ];
    return _interpolate(bp, no2, fallback: 500);
  }

  // ── O₃ → sub-AQI (μg/m³, 8h average, EPA breakpoints) ─────────────────
  int o3ToAqi(double o3) {
    const bp = [
      (cL: 0.0,   cH: 108.0,  iL: 0,   iH: 50),
      (cL: 109.0, cH: 137.0,  iL: 51,  iH: 100),
      (cL: 138.0, cH: 167.0,  iL: 101, iH: 150),
      (cL: 168.0, cH: 196.0,  iL: 151, iH: 200),
      (cL: 197.0, cH: 392.0,  iL: 201, iH: 300),
    ];
    return _interpolate(bp, o3, fallback: 300);
  }

  // ── Generic breakpoint interpolation ───────────────────────────────────
  int _interpolate(
    List<({double cL, double cH, int iL, int iH})> bp,
    double concentration, {
    required int fallback,
  }) {
    for (final b in bp) {
      if (concentration <= b.cH) {
        return (((b.iH - b.iL) / (b.cH - b.cL)) * (concentration - b.cL) + b.iL).round();
      }
    }
    return fallback;
  }
}

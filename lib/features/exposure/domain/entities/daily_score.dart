// lib/features/exposure/domain/entities/daily_score.dart
import 'exposure_record.dart';

class DailyScore {
  final DateTime date;
  final double totalExposure;        // Somme des weightedExposure
  final int measurementCount;
  final int avgAqi;
  final Duration totalOutdoorTime;

  const DailyScore({
    required this.date,
    required this.totalExposure,
    required this.measurementCount,
    required this.avgAqi,
    required this.totalOutdoorTime,
  });

  /// Conversion en "équivalent cigarettes" (Berkeley Earth: AQI 22 = 1 cig/jour)
  double get cigaretteEquivalent => totalExposure / (22.0 * 24.0);

  /// Score 0-100 (100 = purement clean air)
  int get healthScore {
    if (totalExposure <= 50 * 8)  return 95;  // 8h à AQI ≤ 50
    if (totalExposure <= 100 * 8) return 75;
    if (totalExposure <= 150 * 8) return 50;
    if (totalExposure <= 200 * 8) return 25;
    return 10;
  }

  String get grade => switch (healthScore) {
    >= 90 => 'A+',
    >= 80 => 'A',
    >= 70 => 'B',
    >= 50 => 'C',
    >= 30 => 'D',
    _ => 'F',
  };

  /// Construit un score quotidien à partir d'une liste de relevés d'exposition
  factory DailyScore.fromRecords(DateTime day, List<ExposureRecord> records) {
    if (records.isEmpty) {
      return DailyScore(
        date: day,
        totalExposure: 0,
        measurementCount: 0,
        avgAqi: 0,
        totalOutdoorTime: Duration.zero,
      );
    }

    double totalWeighted = 0;
    double totalDurationMinutes = 0;
    int sumAqi = 0;

    for (var r in records) {
      totalWeighted += r.weightedExposure;
      totalDurationMinutes += r.durationMinutes;
      sumAqi += r.aqi;
    }

    return DailyScore(
      date: day,
      totalExposure: totalWeighted,
      measurementCount: records.length,
      avgAqi: (sumAqi / records.length).round(),
      totalOutdoorTime: Duration(minutes: totalDurationMinutes.toInt()),
    );
  }
}

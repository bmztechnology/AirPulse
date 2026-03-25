// lib/models/air_quality_model.dart

enum AqiStatus { good, moderate, unhealthySensitive, unhealthy, veryUnhealthy, hazardous }

enum UserProfile { cyclist, athlete, sick, normal, child, elderly }

/// M-01 fix: logique AQI extraite ici — utilisée par AirQualityData ET AqiStation.
AqiStatus aqiStatusFrom(int aqi) {
  if (aqi <= 50)  return AqiStatus.good;
  if (aqi <= 100) return AqiStatus.moderate;
  if (aqi <= 150) return AqiStatus.unhealthySensitive;
  if (aqi <= 200) return AqiStatus.unhealthy;
  if (aqi <= 300) return AqiStatus.veryUnhealthy;
  return AqiStatus.hazardous;
}

class AirQualityData {
  final int aqi;
  final double pm25;
  final double? pm10;
  final double no2;
  final double o3;
  final double so2;
  final double co;
  final double pm1;
  final double pm4;
  final double voc;
  final DateTime updatedAt;
  final String stationName;
  final String stationSource;
  final double lat;
  final double lng;
  final WeatherData weather;
  final PollenData pollen;
  final List<HourlyForecast> forecast;

  // FIX-MINOR-08: Removed misleading const — mock() uses DateTime.now() which is not const
  AirQualityData({
    required this.aqi,
    required this.pm25,
    this.pm10,
    required this.no2,
    required this.o3,
    required this.so2,
    required this.co,
    this.pm1 = 0,
    this.pm4 = 0,
    this.voc = 0,
    required this.updatedAt,
    required this.stationName,
    required this.stationSource,
    required this.lat,
    required this.lng,
    required this.weather,
    required this.pollen,
    required this.forecast,
  });

  AqiStatus get status => aqiStatusFrom(aqi);

  factory AirQualityData.mock() => AirQualityData(
    aqi: 42,
    pm25: 8.2,
    pm10: 19.0,  // mock has value; real API may return null
    no2: 38.0,
    o3: 61.0,
    so2: 4.0,
    co: 0.6,
    pm1: 5.1,
    pm4: 12.3,
    voc: 18.0,
    updatedAt: DateTime.now(),
    stationName: 'Paris Centre',
    stationSource: 'AirParif',
    lat: 48.856,
    lng: 2.352,
    weather: WeatherData.mock(),
    pollen: PollenData.mock(),
    forecast: HourlyForecast.mockList(),
  );

  Map<String, dynamic> toJson() => {
    'aqi': aqi,
    'pm25': pm25,
    'pm10': pm10,
    'no2': no2,
    'o3': o3,
    'so2': so2,
    'co': co,
    'pm1': pm1,
    'pm4': pm4,
    'voc': voc,
    'updatedAt': updatedAt.toIso8601String(),
    'stationName': stationName,
    'stationSource': stationSource,
    'lat': lat,
    'lng': lng,
    'weather': weather.toJson(),
    'pollen': pollen.toJson(),
    'forecast': forecast.map((e) => e.toJson()).toList(),
  };

  factory AirQualityData.fromJson(Map<String, dynamic> json) => AirQualityData(
    aqi: json['aqi'] as int,
    pm25: (json['pm25'] as num).toDouble(),
    pm10: json['pm10'] != null ? (json['pm10'] as num).toDouble() : null,
    no2: (json['no2'] as num).toDouble(),
    o3: (json['o3'] as num).toDouble(),
    so2: (json['so2'] as num).toDouble(),
    co: (json['co'] as num).toDouble(),
    pm1: (json['pm1'] as num).toDouble(),
    pm4: (json['pm4'] as num).toDouble(),
    voc: (json['voc'] as num).toDouble(),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    stationName: json['stationName'] as String,
    stationSource: json['stationSource'] as String,
    lat: (json['lat'] as num).toDouble(),
    lng: (json['lng'] as num).toDouble(),
    weather: WeatherData.fromJson(Map<String, dynamic>.from(json['weather'] as Map)),
    pollen: PollenData.fromJson(Map<String, dynamic>.from(json['pollen'] as Map)),
    forecast: (json['forecast'] as List).map((e) => HourlyForecast.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
  );
}

class WeatherData {
  final double tempC;
  final int humidity;
  final double windKmh;
  final String windDir;
  final int pressureHpa;
  final int uvIndex;
  final double visibilityKm;

  const WeatherData({
    required this.tempC,
    required this.humidity,
    required this.windKmh,
    required this.windDir,
    required this.pressureHpa,
    required this.uvIndex,
    required this.visibilityKm,
  });

  factory WeatherData.mock() => const WeatherData(
    tempC: 18.0,
    humidity: 62,
    windKmh: 12.0,
    windDir: 'NNO',
    pressureHpa: 1013,
    uvIndex: 3,
    visibilityKm: 9.8,
  );

  Map<String, dynamic> toJson() => {
    'tempC': tempC,
    'humidity': humidity,
    'windKmh': windKmh,
    'windDir': windDir,
    'pressureHpa': pressureHpa,
    'uvIndex': uvIndex,
    'visibilityKm': visibilityKm,
  };

  factory WeatherData.fromJson(Map<String, dynamic> json) => WeatherData(
    tempC: (json['tempC'] as num).toDouble(),
    humidity: json['humidity'] as int,
    windKmh: (json['windKmh'] as num).toDouble(),
    windDir: json['windDir'] as String,
    pressureHpa: json['pressureHpa'] as int,
    uvIndex: json['uvIndex'] as int,
    visibilityKm: (json['visibilityKm'] as num).toDouble(),
  );
}

class PollenData {
  final int total;   // 0-5
  final int grass;
  final int trees;
  final int molds;

  const PollenData({
    required this.total,
    required this.grass,
    required this.trees,
    required this.molds,
  });

  factory PollenData.mock() => const PollenData(
    total: 3,
    grass: 3,
    trees: 2,
    molds: 1,
  );

  Map<String, dynamic> toJson() => {
    'total': total,
    'grass': grass,
    'trees': trees,
    'molds': molds,
  };

  factory PollenData.fromJson(Map<String, dynamic> json) => PollenData(
    total: json['total'] as int,
    grass: json['grass'] as int,
    trees: json['trees'] as int,
    molds: json['molds'] as int,
  );
}

class HourlyForecast {
  final DateTime time;
  final int aqi;
  final double pm25;

  const HourlyForecast({
    required this.time,
    required this.aqi,
    required this.pm25,
  });

  static List<HourlyForecast> mockList() {
    final base = DateTime.now();
    final aqiValues = [42, 38, 35, 40, 55, 68, 72, 65, 58, 50, 48, 45,
                       42, 38, 36, 40, 52, 60, 65, 58, 50, 45, 42, 38];
    return List.generate(24, (i) => HourlyForecast(
      time: base.add(Duration(hours: i - 12)),
      aqi: aqiValues[i],
      pm25: aqiValues[i] * 0.19,
    ));
  }

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    'aqi': aqi,
    'pm25': pm25,
  };

  factory HourlyForecast.fromJson(Map<String, dynamic> json) => HourlyForecast(
    time: DateTime.parse(json['time'] as String),
    aqi: json['aqi'] as int,
    pm25: (json['pm25'] as num).toDouble(),
  );
}

class AqiStation {
  final String name;
  final double lat;
  final double lng;
  final int aqi;
  final double pm25;
  final double pm10;
  final double no2;
  final double o3;
  final String source;
  final double windKmh;

  const AqiStation({
    required this.name,
    required this.lat,
    required this.lng,
    required this.aqi,
    required this.pm25,
    required this.pm10,
    required this.no2,
    required this.o3,
    required this.source,
    this.windKmh = 12.0, // default; replaced by real API data
  });

  AqiStatus get status => aqiStatusFrom(aqi);

  static List<AqiStation> mockStations() => const [
    AqiStation(name: 'Paris Centre',        lat: 48.856, lng: 2.352,  aqi: 42,  pm25: 8,  pm10: 19, no2: 38, o3: 61, source: 'AirParif', windKmh: 12.0),
    AqiStation(name: 'Périphérique Est',    lat: 48.848, lng: 2.413,  aqi: 78,  pm25: 22, pm10: 41, no2: 68, o3: 52, source: 'AirParif', windKmh: 18.0),
    AqiStation(name: 'Bois de Vincennes',   lat: 48.831, lng: 2.433,  aqi: 28,  pm25: 5,  pm10: 11, no2: 12, o3: 70, source: 'WAQI', windKmh: 8.0),
    AqiStation(name: 'Montparnasse',        lat: 48.842, lng: 2.321,  aqi: 55,  pm25: 14, pm10: 28, no2: 45, o3: 58, source: 'AirParif', windKmh: 14.0),
    AqiStation(name: 'Nation',              lat: 48.848, lng: 2.396,  aqi: 66,  pm25: 18, pm10: 34, no2: 55, o3: 54, source: 'WAQI', windKmh: 16.0),
    AqiStation(name: 'Porte de la Chapelle',lat: 48.896, lng: 2.360,  aqi: 95,  pm25: 32, pm10: 58, no2: 88, o3: 42, source: 'AirParif', windKmh: 22.0),
    AqiStation(name: 'Saint-Cloud',         lat: 48.845, lng: 2.214,  aqi: 31,  pm25: 6,  pm10: 14, no2: 18, o3: 72, source: 'WAQI', windKmh: 10.0),
    AqiStation(name: 'Gare du Nord',        lat: 48.880, lng: 2.355,  aqi: 82,  pm25: 26, pm10: 46, no2: 74, o3: 47, source: 'WAQI', windKmh: 19.0),
    AqiStation(name: 'Boulogne-Billancourt',lat: 48.834, lng: 2.240,  aqi: 44,  pm25: 9,  pm10: 22, no2: 32, o3: 65, source: 'AirParif', windKmh: 9.0),
    AqiStation(name: 'Aubervilliers',       lat: 48.914, lng: 2.385,  aqi: 110, pm25: 38, pm10: 65, no2: 92, o3: 39, source: 'WAQI', windKmh: 24.0),
  ];
}

// AlertSetting removed (MINOR-09): was defined but never used — alerts use Map<String,bool> in AppProvider

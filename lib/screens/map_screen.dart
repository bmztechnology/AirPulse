// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/air_quality_model.dart';
import '../theme/app_theme.dart';
import '../widgets/aqi_widgets.dart';
import '../l10n/app_localizations.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapCtrl = MapController();
  String  _layer          = 'aqi';
  bool    _centeredOnGps  = false;
  int     _forecastHour   = 0;   // 0 = maintenant, 2/4/6/12 = dans X heures
  bool    _showAvoidZones = true;

  final _layers = ['aqi', 'pm25', 'pm10', 'no2', 'o3', 'wind'];

  String _layerLabel(String l, AppLocalizations loc) => switch (l) {
    'aqi'  => loc.mapLayerAqi,
    'pm25' => loc.mapLayerPm25,
    'pm10' => loc.mapLayerPm10,
    'no2'  => loc.mapLayerNo2,
    'o3'   => loc.mapLayerO3,
    'wind' => loc.mapLayerWind,
    _      => l.toUpperCase(),
  };

  double _stationValue(AqiStation s) => switch (_layer) {
    'pm25' => s.pm25,
    'pm10' => s.pm10,
    'no2'  => s.no2,
    'o3'   => s.o3,
    'wind' => s.windKmh,
    _      => s.aqi.toDouble(),
  };

  String _stationUnit() => switch (_layer) {
    'aqi'  => 'AQI',
    'wind' => 'km/h',
    _      => 'μg',
  };

  // AQI d'une station ajusté selon la prévision horaire
  int _forecastAqi(AqiStation s, AppProvider ap) {
    if (_forecastHour == 0) return s.aqi;
    final fc = ap.data.forecast;
    if (fc.isEmpty) return s.aqi;
    final now = DateTime.now();
    final target = now.add(Duration(hours: _forecastHour));
    final entry = fc.where((f) =>
        f.time.difference(target).abs() < const Duration(minutes: 35))
        .toList();
    if (entry.isEmpty) return s.aqi;
    // Ratio prévision/actuel appliqué à chaque station
    final ratio = entry.first.aqi / (ap.data.aqi == 0 ? 1 : ap.data.aqi);
    return ((s.aqi * ratio)).round().clamp(1, 500);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ap = context.read<AppProvider>();
      ap.addListener(_onProviderUpdate);
      _tryCenterOnGps(ap);
    });
  }

  void _onProviderUpdate() => _tryCenterOnGps(context.read<AppProvider>());

  void _tryCenterOnGps(AppProvider ap) {
    if (!_centeredOnGps && ap.lastLat != null && ap.lastLng != null && mounted) {
      _centeredOnGps = true;
      _mapCtrl.move(LatLng(ap.lastLat!, ap.lastLng!), 13);
    }
  }

  @override
  void dispose() {
    try { context.read<AppProvider>().removeListener(_onProviderUpdate); } catch (_) {}
    _mapCtrl.dispose();
    super.dispose();
  }

  void _centerMap(AppProvider ap) {
    _centeredOnGps = true;
    _mapCtrl.move(LatLng(ap.lastLat ?? 48.856, ap.lastLng ?? 2.352), 13);
  }

  @override
  Widget build(BuildContext context) {
    final ap       = context.watch<AppProvider>();
    final l        = AppLocalizations.of(context);
    final stations = ap.stations;
    final hasGps   = ap.lastLat != null && ap.lastLng != null;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [

            // ── Header ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Text(l.mapTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
                  const Spacer(),
                  // Bouton zones à éviter
                  GestureDetector(
                    onTap: () => setState(() => _showAvoidZones = !_showAvoidZones),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _showAvoidZones ? AppColors.aqiRedBg : AppColors.cream2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _showAvoidZones
                            ? AppColors.aqiRed : AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('🚫', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text('Zones',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                            color: _showAvoidZones ? AppColors.aqiRed : AppColors.ink3)),
                      ]),
                    ),
                  ),
                  // Bouton recentrer
                  GestureDetector(
                    onTap: () => _centerMap(ap),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: hasGps ? AppColors.accentLight : AppColors.cream2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: hasGps ? AppColors.accent : AppColors.border),
                      ),
                      child: const Text('📍', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Layer selector ─────────────────────────────────────────
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: _layers.map((lyr) {
                  final active = lyr == _layer;
                  return GestureDetector(
                    onTap: () => setState(() => _layer = lyr),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: active ? AppColors.ink : AppColors.cream,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: active ? AppColors.ink : AppColors.border),
                      ),
                      child: Text(_layerLabel(lyr, l),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: active ? AppColors.cream : AppColors.ink3)),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Carte ─────────────────────────────────────────────────
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapCtrl,
                    options: MapOptions(
                      initialCenter: LatLng(ap.lastLat ?? 48.856, ap.lastLng ?? 2.352),
                      initialZoom: 13,
                      maxZoom: 18,
                      minZoom: 5,
                    ),
                    children: [
                      // Fond OSM
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'app.airpulse',
                        maxNativeZoom: 19,
                        errorTileCallback: (t, e, s) => debugPrint('tile: $e'),
                      ),

                      // ── Zones à éviter (polygones rouges) ─────────────
                      if (_showAvoidZones && stations.isNotEmpty)
                        CircleLayer(
                          circles: stations
                            .where((s) => _forecastAqi(s, ap) > ap.personalThreshold)
                            .map((s) => CircleMarker(
                              point: LatLng(s.lat, s.lng),
                              radius: 900,
                              useRadiusInMeter: true,
                              color: AppColors.aqiRed.withValues(alpha: 0.18),
                              borderColor: AppColors.aqiRed.withValues(alpha: 0.5),
                              borderStrokeWidth: 1.5,
                            )).toList(),
                        ),

                      // ── Halos de pollution ─────────────────────────────
                      CircleLayer(
                        circles: stations.map((s) {
                          final aqi = _forecastAqi(s, ap);
                          return CircleMarker(
                            point: LatLng(s.lat, s.lng),
                            radius: 1100,
                            useRadiusInMeter: true,
                            color: aqiColor(aqi).withValues(alpha: 0.10),
                            borderColor: Colors.transparent,
                            borderStrokeWidth: 0,
                          );
                        }).toList(),
                      ),

                      // ── Bulles AQI ─────────────────────────────────────
                      MarkerLayer(
                        markers: stations.map((s) {
                          final aqi   = _forecastAqi(s, ap);
                          final val   = _layer == 'aqi' ? aqi.toDouble() : _stationValue(s);
                          final unit  = _stationUnit();
                          final color = aqiColor(aqi);
                          return Marker(
                            point: LatLng(s.lat, s.lng),
                            width: 56, height: 56,
                            child: GestureDetector(
                              onTap: () => _showStationPopup(context, s, aqi, l),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: color, shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.5),
                                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35),
                                      blurRadius: 8, offset: const Offset(0, 3))],
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      val > 99 ? val.toInt().toString()
                                          : val.toStringAsFixed(val >= 10 ? 0 : 1),
                                      style: const TextStyle(color: Colors.white,
                                          fontSize: 13, fontWeight: FontWeight.w800,
                                          fontFamily: 'DMMono', height: 1),
                                    ),
                                    Text(unit, style: const TextStyle(color: Colors.white70,
                                        fontSize: 7, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // ── Marqueur GPS "Vous êtes ici" ─────────────────
                      if (hasGps)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(ap.lastLat!, ap.lastLng!),
                              width: 44, height: 44,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  boxShadow: [BoxShadow(
                                      color: AppColors.accent.withValues(alpha: 0.4),
                                      blurRadius: 12)],
                                ),
                                child: const Center(
                                  child: Text('📍',
                                    style: TextStyle(fontSize: 18)),
                                ),
                              ),
                            ),
                          ],
                        ),

                      // Attribution
                      const RichAttributionWidget(attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ]),
                    ],
                  ),

                  // ── Indicateur "zones à éviter" ──────────────────────
                  if (_showAvoidZones && stations.isNotEmpty)
                    Positioned(
                      top: 10, left: 10,
                      child: _buildAvoidZonesBadge(ap, stations),
                    ),

                  // ── Indicateur prévision horaire ─────────────────────
                  if (_forecastHour > 0)
                    Positioned(
                      top: 10, right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('+$_forecastHour h',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      ),
                    ),
                ],
              ),
            ),

            // ── Légende gradient ───────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cream.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(height: 8,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.gradientGreen, AppColors.gradientYellow,
                          AppColors.gradientOrange, AppColors.aqiRed,
                          AppColors.gradientPurple, AppColors.gradientMaroon,
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ...['0','50','100','200','300+'].map((v) =>
                  Padding(padding: const EdgeInsets.only(left: 4),
                    child: Text(v, style: const TextStyle(fontSize: 9,
                        fontWeight: FontWeight.w600, color: AppColors.ink3)))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.ink,
                      borderRadius: BorderRadius.circular(100)),
                  child: Text(_layerLabel(_layer, l),
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                        color: AppColors.cream)),
                ),
              ]),
            ),

            // ── Slider temporel ────────────────────────────────────────
            _buildForecastSlider(ap),

            // ── Barre météo ────────────────────────────────────────────
            _buildWeatherBar(ap),

            // ── Liste stations ─────────────────────────────────────────
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                    child: Row(children: [
                      Text(l.mapNearbyStations,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.ink3, letterSpacing: 0.8)),
                      const Spacer(),
                      if (hasGps)
                        Text('AQI actuel : ${ap.data.aqi}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: aqiColor(ap.data.aqi))),
                    ]),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: ([...stations]..sort((a, b) =>
                          _forecastAqi(a, ap).compareTo(_forecastAqi(b, ap))))
                        .take(6)
                        .map((s) => _StationRow(
                          station: s,
                          displayAqi: _forecastAqi(s, ap),
                          exceedThreshold: _forecastAqi(s, ap) > ap.personalThreshold,
                          onTap: () => _mapCtrl.move(LatLng(s.lat, s.lng), 15)))
                        .toList(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Barre météo ───────────────────────────────────────────────────────────
  Widget _buildWeatherBar(AppProvider ap) {
    final w = ap.data.weather;
    // Si pas encore de données météo réelles (mock par défaut)
    final hasData = ap.initialized && ap.lastLat != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cream2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _weatherCell(_tempIcon(w.tempC),    '${w.tempC.toStringAsFixed(0)}°C'),
          _weatherDivider(),
          _weatherCell(_humidIcon(w.humidity), '${w.humidity}%'),
          _weatherDivider(),
          _weatherCell(_windIcon(w.windKmh),  '${w.windKmh.toStringAsFixed(0)} km/h'),
          _weatherDivider(),
          _weatherCell(_windDirIcon(w.windDir), w.windDir),
          _weatherDivider(),
          _weatherCell(_uvIcon(w.uvIndex),    'UV ${w.uvIndex}'),
          _weatherDivider(),
          _weatherCell(_visIcon(w.visibilityKm), '${w.visibilityKm.toStringAsFixed(0)} km'),
          _weatherDivider(),
          _weatherCell(_pressureIcon(w.pressureHpa), '${w.pressureHpa} hPa'),
        ],
      ),
    );
  }

  Widget _weatherCell(String icon, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(icon, style: const TextStyle(fontSize: 16)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
          color: AppColors.ink2)),
    ],
  );

  Widget _weatherDivider() => Container(
    width: 1, height: 28,
    color: AppColors.border,
    margin: const EdgeInsets.symmetric(horizontal: 2),
  );

  // ── Icônes météo contextuelles ────────────────────────────────────────────
  String _tempIcon(double t) {
    if (t < 0)   return '🥶';
    if (t < 10)  return '🌨️';
    if (t < 18)  return '🌤️';
    if (t < 28)  return '☀️';
    return '🔥';
  }

  String _humidIcon(int h) {
    if (h < 30) return '🏜️';
    if (h < 60) return '💧';
    if (h < 80) return '🌧️';
    return '🌊';
  }

  String _windIcon(double v) {
    if (v < 5)  return '🍃';
    if (v < 20) return '💨';
    if (v < 40) return '🌬️';
    return '🌪️';
  }

  String _windDirIcon(String dir) {
    const map = {
      'N': '⬆️',  'NNE': '↗️', 'NE': '↗️',  'ENE': '➡️',
      'E': '➡️',  'ESE': '↘️', 'SE': '↘️',  'SSE': '⬇️',
      'S': '⬇️',  'SSO': '↙️', 'SO': '↙️',  'OSO': '⬅️',
      'O': '⬅️',  'ONO': '↖️', 'NO': '↖️',  'NNO': '⬆️',
    };
    return map[dir] ?? '🧭';
  }

  String _uvIcon(int uv) {
    if (uv <= 2)  return '🌥️';
    if (uv <= 5)  return '🌤️';
    if (uv <= 7)  return '☀️';
    if (uv <= 10) return '🌞';
    return '☢️';
  }

  String _visIcon(double km) {
    if (km < 1)  return '🌫️';
    if (km < 5)  return '😶‍🌫️';
    if (km < 10) return '🌤️';
    return '👁️';
  }

  String _pressureIcon(int hpa) {
    if (hpa < 1000) return '🌧️';
    if (hpa < 1013) return '🌥️';
    if (hpa < 1022) return '⛅';
    return '☀️';
  }

  // ── Badge zones à éviter ──────────────────────────────────────────────────
  Widget _buildAvoidZonesBadge(AppProvider ap, List<AqiStation> stations) {
    final danger = stations
        .where((s) => _forecastAqi(s, ap) > ap.personalThreshold)
        .length;
    if (danger == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.aqiGreenBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.aqiGreen)),
        child: Text('✅ Zone sûre',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.aqiGreen)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.aqiRedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.aqiRed)),
      child: Text('🚫 $danger zone${danger > 1 ? 's' : ''} à éviter',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.aqiRed)),
    );
  }

  // ── Slider prévisions horaires ────────────────────────────────────────────
  Widget _buildForecastSlider(AppProvider ap) {
    const hours = [0, 2, 4, 6, 12];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        const Text('🕐', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        ...hours.map((h) {
          final active = _forecastHour == h;
          // Calculer l'AQI prévu pour ce créneau
          int forecastAqi = ap.data.aqi;
          if (h > 0 && ap.data.forecast.isNotEmpty) {
            final t = DateTime.now().add(Duration(hours: h));
            final entry = ap.data.forecast.where((f) =>
                f.time.difference(t).abs() < const Duration(minutes: 35))
                .toList();
            if (entry.isNotEmpty) forecastAqi = entry.first.aqi;
          }
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _forecastHour = h),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: active ? aqiColor(forecastAqi) : AppColors.cream2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: active
                      ? aqiColor(forecastAqi) : AppColors.border),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(h == 0 ? 'Maint.' : '+${h}h',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
                      color: active ? Colors.white : AppColors.ink3)),
                  Text('$forecastAqi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                      color: active ? Colors.white : aqiColor(forecastAqi),
                      fontFamily: 'DMMono')),
                ]),
              ),
            ),
          );
        }),
      ]),
    );
  }

  // ── Popup station ─────────────────────────────────────────────────────────
  void _showStationPopup(BuildContext ctx, AqiStation s, int displayAqi, AppLocalizations l) {
    if (!mounted) return;
    final color = aqiColor(displayAqi);
    final bg    = aqiBgColor(displayAqi);
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('📍 ${s.name}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.ink))),
              AqiBadge(aqi: displayAqi, fontSize: 13),
            ]),
            const SizedBox(height: 4),
            Text('📡 ${s.source}',
              style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
            if (_forecastHour > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: bg,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('Prévision dans $_forecastHour h',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                      color: color)),
              ),
            ],
            const SizedBox(height: 14),
            // Conseil selon AQI
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bg,
                  borderRadius: BorderRadius.circular(12)),
              child: Text(_aqiAdvice(displayAqi),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: color)),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 8, children: [
              _pollStat('PM2.5', '${s.pm25.toStringAsFixed(0)} μg'),
              _pollStat('PM10',  '${s.pm10.toStringAsFixed(0)} μg'),
              _pollStat('NO₂',   '${s.no2.toStringAsFixed(0)} μg'),
              _pollStat('O₃',    '${s.o3.toStringAsFixed(0)} μg'),
            ]),
          ],
        ),
      ),
    );
  }

  String _aqiAdvice(int aqi) {
    if (aqi <= 50)  return '✅ Air excellent — activités libres';
    if (aqi <= 100) return '⚠️ Air modéré — attention aux personnes sensibles';
    if (aqi <= 150) return '🚴 Réduisez les efforts prolongés';
    if (aqi <= 200) return '😷 Masque recommandé — évitez les sorties';
    return '🚫 Restez à l\'intérieur — air dangereux';
  }

  Widget _pollStat(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: AppColors.cream2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border)),
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
          color: AppColors.ink, fontFamily: 'DMMono')),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.ink3,
          fontWeight: FontWeight.w600)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// _StationRow
// ─────────────────────────────────────────────────────────────────────────────
class _StationRow extends StatelessWidget {
  final AqiStation station;
  final int        displayAqi;
  final bool       exceedThreshold;
  final VoidCallback onTap;
  const _StationRow({
    required this.station,
    required this.displayAqi,
    required this.exceedThreshold,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: exceedThreshold ? AppColors.aqiRedBg : AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: exceedThreshold ? AppColors.aqiRed.withValues(alpha: 0.4)
                : AppColors.border),
        ),
        child: Row(children: [
          Container(width: 8, height: 8,
            decoration: BoxDecoration(color: aqiColor(displayAqi),
                shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(station.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.ink), overflow: TextOverflow.ellipsis)),
                if (exceedThreshold)
                  const Text(' 🚫',
                    style: TextStyle(fontSize: 11)),
              ]),
              Text('${station.source} · PM2.5: ${station.pm25.toStringAsFixed(0)} μg',
                style: const TextStyle(fontSize: 10, color: AppColors.ink3)),
            ]),
          ),
          AqiBadge(aqi: displayAqi),
        ]),
      ),
    );
  }
}

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
  String _layer = 'aqi';

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

  // FIX-minor-5: Use real windKmh from AqiStation model
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

  @override
  void dispose() {
    _mapCtrl.dispose(); // FIX-BUG-12: Dispose MapController to prevent memory leak
    super.dispose();
  }

  void _centerMap(AppProvider ap) {
    final lat = ap.lastLat ?? 48.856;
    final lng = ap.lastLng ?? 2.352;
    _mapCtrl.move(LatLng(lat, lng), 11);
  }

  @override
  Widget build(BuildContext context) {
    final ap       = context.watch<AppProvider>();
    final l        = AppLocalizations.of(context);
    final stations = ap.stations;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Text(l.mapTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _centerMap(ap),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.cream2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text('📍', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),

            // ── Layer selector ───────────────────────────────────────────
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? AppColors.cream : AppColors.ink3,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Leaflet Map — FIX-M03: responsive height ──────────────
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.40,
              child: FlutterMap(
                mapController: _mapCtrl,
                options: MapOptions(
                  initialCenter: LatLng(ap.lastLat ?? 48.856, ap.lastLng ?? 2.352),
                  initialZoom: 11,
                  maxZoom: 18,
                  minZoom: 5,
                ),
                children: [
                  // OpenStreetMap via Carto light tiles
                  // FIX-minor-1: errorTileCallback shows user feedback on tile load failure
                  TileLayer(
                    urlTemplate: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'app.airpulse',
                    maxNativeZoom: 19,
                    errorTileCallback: (tile, error, stackTrace) {
                      debugPrint('AirPulse: map tile load failed: $error');
                    },
                  ),
                  // Pollution halo circles
                  CircleLayer(
                    circles: stations.map((s) => CircleMarker(
                      point: LatLng(s.lat, s.lng),
                      radius: 1100,
                      useRadiusInMeter: true,
                      color: aqiColor(s.aqi).withValues(alpha: 0.12),
                      borderColor: Colors.transparent,
                      borderStrokeWidth: 0,
                    )).toList(),
                  ),
                  // AQI marker bubbles
                  MarkerLayer(
                    markers: stations.map((s) {
                      final val  = _stationValue(s);
                      final unit = _stationUnit();
                      final color = aqiColor(s.aqi);
                      return Marker(
                        point: LatLng(s.lat, s.lng),
                        width: 52,
                        height: 52,
                        child: GestureDetector(
                          onTap: () => _showStationPopup(context, s, l),
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3)),
                              ],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  val > 99 ? val.toInt().toString() : val.toStringAsFixed(val >= 10 ? 0 : 1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    fontFamily: 'DMMono',
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  unit,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 7,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Attribution
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                      TextSourceAttribution('CARTO'),
                    ],
                  ),
                ],
              ),
            ),

            // ── AQI legend bar ───────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(16, -20, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.cream.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 8,
                        decoration: const BoxDecoration(
                          gradient: const LinearGradient(colors: [
                            AppColors.gradientGreen,
                            AppColors.gradientYellow,
                            AppColors.gradientOrange,
                            AppColors.aqiRed,
                            AppColors.gradientPurple,
                            AppColors.gradientMaroon,
                          ]), // FIX-MINOR-06
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ...['0', '50', '100', '200', '300+'].map((v) =>
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(v, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.ink3)),
                    )),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      _layerLabel(_layer, l),
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.cream),
                    ),
                  ),
                ],
              ),
            ),

            // ── Stations list ────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Text(
                      l.mapNearbyStations,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.ink3, letterSpacing: 0.8),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      // FIX-MAJOR-04: Rewritten to avoid cascade/take confusion.
                      children: ([...stations]..sort((a, b) => a.aqi.compareTo(b.aqi)))
                          .take(6)
                          .map((s) => _StationRow(
                              station: s,
                              onTap: () => _mapCtrl.move(LatLng(s.lat, s.lng), 14)))
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

  void _showStationPopup(BuildContext context, AqiStation s, AppLocalizations l) {
    if (!mounted) return; // FIX-MINOR-07
    showModalBottomSheet(
      context: context,
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
              Expanded(
                child: Text('📍 ${s.name}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
              ),
              AqiBadge(aqi: s.aqi, fontSize: 13),
            ]),
            const SizedBox(height: 4),
            Text('📡 ${s.source}', style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _pollStat('PM2.5', '${s.pm25.toStringAsFixed(0)} μg'),
                _pollStat('PM10',  '${s.pm10.toStringAsFixed(0)} μg'),
                _pollStat('NO₂',   '${s.no2.toStringAsFixed(0)} μg'),
                _pollStat('O₃',    '${s.o3.toStringAsFixed(0)} μg'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pollStat(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.cream2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(children: [
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink, fontFamily: 'DMMono')),
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.ink3, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _StationRow extends StatelessWidget {
  final AqiStation station;
  final VoidCallback onTap;
  const _StationRow({required this.station, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                color: aqiColor(station.aqi),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(station.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                Text('📡 ${station.source} · PM2.5: ${station.pm25.toStringAsFixed(0)} μg',
                  style: const TextStyle(fontSize: 10, color: AppColors.ink3)),
              ]),
            ),
            AqiBadge(aqi: station.aqi),
          ],
        ),
      ),
    );
  }
}

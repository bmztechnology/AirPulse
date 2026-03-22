// lib/screens/details_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/app_provider.dart';
import '../models/air_quality_model.dart';
import '../theme/app_theme.dart';
import '../widgets/aqi_widgets.dart';
import '../l10n/app_localizations.dart';

class DetailsScreen extends StatelessWidget {
  const DetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppProvider>();
    final l  = AppLocalizations.of(context);
    final d  = ap.data;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverAppBar(
              backgroundColor: AppColors.cream,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              title: Text(l.pollutantsTitle),
              centerTitle: false,
              actions: [
                IconButton(
                  icon: const Text('↺', style: TextStyle(fontSize: 18, color: AppColors.ink2)),
                  onPressed: ap.refreshLocation,
                ),
                const SizedBox(width: 8),
              ],
            ),

            // PM2.5 Chart
            SliverToBoxAdapter(
              child: _Pm25Chart(forecast: d.forecast, l: l),
            ),

            // AQI Scale
            SliverToBoxAdapter(child: _AqiScale(l: l)),

            // Particles section
            SliverToBoxAdapter(
              child: SectionHeader(title: l.particles),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
                ),
                delegate: SliverChildListDelegate([
                  PollutantCard(label: l.pm25Label, value: d.pm25.toStringAsFixed(1), unit: 'μg/m³', aqi: d.aqi),
                  PollutantCard(label: l.pm10Label, value: d.pm10.toStringAsFixed(1), unit: 'μg/m³', aqi: (d.aqi * 0.6).toInt()),
                  // PM1/PM4 masqués si 0 — Open-Meteo ne les fournit pas
                  if (d.pm1 > 0) PollutantCard(label: 'PM 1.0', value: d.pm1.toStringAsFixed(1), unit: 'μg/m³', aqi: (d.aqi * 0.4).toInt()),
                  if (d.pm4 > 0) PollutantCard(label: 'PM 4.0', value: d.pm4.toStringAsFixed(1), unit: 'μg/m³', aqi: (d.aqi * 0.5).toInt()),
                ]),
              ),
            ),

            // Gases section
            SliverToBoxAdapter(child: SectionHeader(title: l.gases)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6,
                ),
                delegate: SliverChildListDelegate([
                  PollutantCard(label: l.no2Label, value: d.no2.toStringAsFixed(0), unit: 'μg/m³', aqi: (d.aqi * 0.9).toInt()),
                  PollutantCard(label: l.o3Label,  value: d.o3.toStringAsFixed(0),  unit: 'μg/m³', aqi: (d.aqi * 0.6).toInt()),
                  PollutantCard(label: l.coLabel,  value: d.co.toStringAsFixed(2),  unit: 'mg/m³', aqi: (d.aqi * 0.05).toInt()),
                  // SO2 et VOC masqués si 0 — non fournis par Open-Meteo current
                  if (d.so2 > 0) PollutantCard(label: l.so2Label, value: d.so2.toStringAsFixed(1), unit: 'μg/m³', aqi: (d.aqi * 0.1).toInt()),
                  if (d.voc  > 0) PollutantCard(label: l.vocLabel, value: d.voc.toStringAsFixed(0), unit: 'μg/m³', aqi: (d.aqi * 0.3).toInt()),
                ]),
              ),
            ),

            // Weather
            SliverToBoxAdapter(child: SectionHeader(title: l.weather)),
            SliverToBoxAdapter(child: _WeatherGrid(w: d.weather, l: l)),

            // Biological
            SliverToBoxAdapter(child: SectionHeader(title: l.biological)),
            SliverToBoxAdapter(child: _PollenCard(p: d.pollen, l: l)),

            // Data sources
            SliverToBoxAdapter(child: SectionHeader(title: l.dataSources)),
            SliverToBoxAdapter(child: const _DataSources()),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PM2.5 24h line chart using fl_chart
// ─────────────────────────────────────────────────────────────────────────────
class _Pm25Chart extends StatelessWidget {
  final List<HourlyForecast> forecast;
  final AppLocalizations l;
  const _Pm25Chart({required this.forecast, required this.l});

  @override
  Widget build(BuildContext context) {
    if (forecast.isEmpty) {
      return const SizedBox.shrink();
    }
    final spots = forecast.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), e.value.pm25)).toList();
    final maxVal = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal * 1.3).clamp(20.0, double.infinity);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.chartTitle,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 10,
                getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (val, _) => Text(val.toInt().toString(),
                      style: const TextStyle(fontSize: 9, color: AppColors.ink3, fontFamily: 'DMMono')),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 4,
                    getTitlesWidget: (val, _) {
                      final i = val.toInt();
                      if (i < 0 || i >= forecast.length) return const SizedBox();
                      return Text('${forecast[i].time.hour}h',
                        style: const TextStyle(fontSize: 9, color: AppColors.ink3));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minY: 0,
              maxY: maxY,
              // WHO threshold line at 15
              extraLinesData: ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: 15,
                  color: AppColors.whoThresholdRed,
                  strokeWidth: 1,
                  dashArray: [4, 4],
                  // NOTE: if fl_chart 0.67.x build fails, rename labelResolver→label
                  label: HorizontalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    labelResolver: (_) => l.whoThreshold('15 μg'),
                    style: const TextStyle(fontSize: 9, color: AppColors.whoThresholdRed, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: AppColors.accent,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, _) => spot.x == 12,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 4,
                      color: AppColors.accent,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.accent.withValues(alpha: 0.2), AppColors.accent.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AQI Scale legend
// ─────────────────────────────────────────────────────────────────────────────
class _AqiScale extends StatelessWidget {
  final AppLocalizations l;
  const _AqiScale({required this.l});

  @override
  Widget build(BuildContext context) {
    final levels = [
      (range: '0–50',   color: AppColors.aqiGreen,  label: l.statusGood,              pm25: '0–15'),
      (range: '51–100', color: AppColors.aqiYellow, label: l.statusModerate,          pm25: '15–35'),
      (range: '101–150',color: AppColors.aqiOrange, label: l.statusUnhealthySensitive,pm25: '35–55'),
      (range: '151–200',color: AppColors.aqiRed,    label: l.statusUnhealthy,         pm25: '55–110'),
      (range: '201–300',color: AppColors.aqiPurple, label: l.statusVeryUnhealthy,     pm25: '110–250'),
      (range: '300+',   color: AppColors.aqiMaroon, label: l.statusHazardous,         pm25: '250+'),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(l.scaleTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          ...levels.map((lv) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border))),
            child: Row(children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(
                color: lv.color, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 10),
              SizedBox(width: 56, child: Text(lv.range,
                style: const TextStyle(fontSize: 12, fontFamily: 'DMMono', fontWeight: FontWeight.w600, color: AppColors.ink))),
              Expanded(child: Text(lv.label,
                style: const TextStyle(fontSize: 12, color: AppColors.ink2))),
              Text(lv.pm25, style: const TextStyle(fontSize: 11, color: AppColors.ink3, fontFamily: 'DMMono')),
            ]),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Weather grid
// ─────────────────────────────────────────────────────────────────────────────
class _WeatherGrid extends StatelessWidget {
  final WeatherData w;
  final AppLocalizations l;
  const _WeatherGrid({required this.w, required this.l});

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: '🌡️', label: l.tempLabel,     value: '${w.tempC.toStringAsFixed(0)}°C'),
      (icon: '💧', label: l.humidityLabel,  value: '${w.humidity}%'),
      (icon: '💨', label: l.windLabel,      value: '${w.windKmh.toStringAsFixed(0)} km/h ${w.windDir}'),
      (icon: '📊', label: l.pressureLabel,  value: '${w.pressureHpa} hPa'),
      (icon: '☀️', label: l.uvLabel,        value: '${w.uvIndex}/10'),
      (icon: '👁️', label: l.visibilityLabel,value: '${w.visibilityKm.toStringAsFixed(1)} km'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
        children: items.map((it) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(children: [
            Text(it.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(it.label, style: const TextStyle(fontSize: 10, color: AppColors.ink3, fontWeight: FontWeight.w600)),
              Text(it.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
            ]),
          ]),
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pollen card
// ─────────────────────────────────────────────────────────────────────────────
class _PollenCard extends StatelessWidget {
  final PollenData p;
  final AppLocalizations l;
  const _PollenCard({required this.p, required this.l});

  @override
  Widget build(BuildContext context) {
    final items = [
      (l.pollenTotalLabel, p.total),
      (l.grassLabel,       p.grass),
      (l.treesLabel,       p.trees),
      (l.moldsLabel,       p.molds),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            SizedBox(width: 100, child: Text(item.$1,
              style: const TextStyle(fontSize: 12, color: AppColors.ink2))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: item.$2 / 5.0,
                  backgroundColor: AppColors.cream2,
                  valueColor: AlwaysStoppedAnimation(
                    item.$2 <= 2 ? AppColors.aqiGreen : item.$2 <= 3 ? AppColors.aqiYellow : AppColors.aqiOrange),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${item.$2}/5', style: const TextStyle(
              fontSize: 11, fontFamily: 'DMMono', color: AppColors.ink3, fontWeight: FontWeight.w600)),
          ]),
        )).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data sources — FIX-MINOR-01: descriptions now use localised ARB keys
// ─────────────────────────────────────────────────────────────────────────────
class _DataSources extends StatelessWidget {
  const _DataSources();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sources = [
      (icon: '🌐', name: 'WAQI / AQICN',   desc: l.sourceWaqiDesc),
      (icon: '🌤️', name: 'Open-Meteo',      desc: l.sourceOpenMeteoDesc),
      (icon: '📡', name: 'OpenAQ v3',        desc: l.sourceOpenAqDesc),
      (icon: '🛰️', name: 'Copernicus CAMS',  desc: l.sourceCopernicusDesc),
      (icon: '🏙️', name: 'AirParif',         desc: l.sourceAirparifDesc),
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: sources.asMap().entries.map((e) { final s = e.value; return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(
              color: e.key == 0 ? Colors.transparent : AppColors.border))), // FIX-MINOR-07
          child: Row(children: [
            Text(s.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
                Text(s.desc, style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
              ]),
            ),
          ]),
        ); }).toList(),
      ),
    );
  }
}

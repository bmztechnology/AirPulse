// lib/screens/alerts_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppProvider>();
    final l = AppLocalizations.of(context);

    // FIX-BUG-11: alert definitions now use localised ARB strings.
    final alertDefs = [
      (id: 'aqi_50',  icon: '🟡', label: l.alertAqiModerate,      desc: l.alertAqiModerateDesc),
      (id: 'aqi_100', icon: '🔴', label: l.alertAqiPoor,          desc: l.alertAqiPoorDesc),
      (id: 'pm25_15', icon: '💨', label: l.alertPm25WHO,           desc: l.alertPm25WHODesc),
      (id: 'cyclist', icon: '🚴', label: l.alertCyclistReminder,   desc: l.alertCyclistReminderDesc),
      (id: 'pollen',  icon: '🌸', label: l.alertPollen,            desc: l.alertPollenDesc),
    ];

    // Historique réel depuis le provider (persisté en SharedPreferences)
    final rawHistory = ap.alertHistory;
    final history = rawHistory.isEmpty
        ? <({Color color, String icon, String text, String time})>[]
        : rawHistory.map((h) {
            final type = h['type'] as String? ?? '';
            final station = h['station'] as String? ?? '';
            final timeStr = h['time'] as String? ?? '';
            final dt = DateTime.tryParse(timeStr) ?? DateTime.now();
            String text;
            Color color;
            String icon;
            if (type == 'aqi_50') {
              text = '${l.statusModerate} · $station AQI ${h['aqi']}';
              color = AppColors.aqiYellow; icon = '⚠️';
            } else if (type == 'aqi_100') {
              text = '${l.statusUnhealthySensitive} · $station AQI ${h['aqi']}';
              color = AppColors.aqiRed; icon = '🚨';
            } else {
              text = 'PM2.5 ${(h['pm25'] as num?)?.toStringAsFixed(1)} μg/m³ · $station';
              color = AppColors.aqiOrange; icon = '💨';
            }
            return (color: color, icon: icon, text: text,
                time: _relativeTime(dt, l));
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.cream,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              title: Text(l.alertScreenTitle),
              centerTitle: false,
            ),

            // History header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text(l.alertHistoryLabel.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink3,
                        letterSpacing: 0.8)),
              ),
            ),

            // Alert history list
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: history.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            l.alertNoHistory,
                            style: const TextStyle(fontSize: 13, color: AppColors.ink3),
                            textAlign: TextAlign.center,
                          ),
                        )
                      ]
                    : history.asMap().entries.map((e) {
                        final h = e.value;
                        return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                                border: Border(
                                    top: BorderSide(
                                        color: e.key == 0
                                            ? Colors.transparent
                                            : AppColors.border))),
                            child: Row(children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: h.color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                    child: Text(h.icon,
                                        style: const TextStyle(fontSize: 14))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(h.text,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.ink)),
                                    Text(h.time,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.ink3)),
                                  ])),
                            ]));
                      }).toList(),
                ),
              ),
            ),

            // Configure alerts header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Text(l.alertConfigureLabel.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink3,
                        letterSpacing: 0.8)),
              ),
            ),

            // Alert toggles
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: alertDefs
                      .map((def) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                                border: Border(
                                    top: BorderSide(
                                        color: def == alertDefs.first
                                            ? Colors.transparent
                                            : AppColors.border))),
                            child: Row(children: [
                              Text(def.icon,
                                  style: const TextStyle(fontSize: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(def.label,
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.ink)),
                                    Text(def.desc,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.ink3)),
                                  ])),
                              Switch.adaptive(
                                value: ap.alerts[def.id] ?? false,
                                onChanged: (_) => ap.toggleAlert(def.id),
                                activeColor: AppColors.accent,
                              ),
                            ]),
                          ))
                      .toList(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  /// Returns a localised relative time string using ARB keys with placeholders.
  String _relativeTime(DateTime dt, AppLocalizations l) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 2) return l.timeDaysAgo(diff.inDays);
    if (diff.inDays == 1) return l.timeYesterday;
    if (diff.inHours >= 1) return l.timeHoursAgo(diff.inHours);
    return l.timeMinutesAgo(diff.inMinutes.clamp(1, 59));
  }
}

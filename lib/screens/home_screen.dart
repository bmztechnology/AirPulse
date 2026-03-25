// lib/screens/home_screen.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/app_provider.dart';
import '../models/air_quality_model.dart';
import '../theme/app_theme.dart';
import '../widgets/aqi_widgets.dart';
import '../l10n/app_localizations.dart';
import '../navigation/app_shell.dart' show AppShellState;
import '../screens/details_screen.dart';
import '../screens/alerts_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // L-08 fix: afficher un snackbar quand AppProvider._error est non-null
  void _listenForErrors(BuildContext context, AppProvider ap, AppLocalizations l) {
    if (ap.error == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ap.error!),
        backgroundColor: AppColors.aqiRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l.retryBtn,
          textColor: Colors.white,
          onPressed: () => ap.refreshLocation(),
        ),
      ));
      ap.clearError();
    });
  }

  String _profileEmoji(UserProfile p) => switch (p) {
        UserProfile.cyclist => '🚴',
        UserProfile.athlete => '🏃',
        UserProfile.sick => '🫁',
        UserProfile.normal => '👤',
        UserProfile.child => '👧',
        UserProfile.elderly => '👴',
      };

  String _profileLabel(UserProfile p, AppLocalizations l) => switch (p) {
        UserProfile.cyclist => l.profileCyclistLabel,
        UserProfile.athlete => l.profileAthleteLabel,
        UserProfile.sick => l.profileSickLabel,
        UserProfile.normal => l.profileNormalLabel,
        UserProfile.child => l.profileChildLabel,
        UserProfile.elderly => l.profileElderlyLabel,
      };

  /// Returns the appropriate verdict string based on profile thresholds and current AQI.
  String _verdictText(UserProfile p, int aqi, AppLocalizations l) {
    final thresholds = switch (p) {
      UserProfile.cyclist => (go: 50, caution: 75),
      UserProfile.athlete => (go: 50, caution: 80),
      UserProfile.sick => (go: 35, caution: 50),
      UserProfile.normal => (go: 100, caution: 150),
      UserProfile.child => (go: 40, caution: 65),
      UserProfile.elderly => (go: 45, caution: 70),
    };
    if (aqi <= thresholds.go) return l.verdictGo;
    if (aqi <= thresholds.caution) return l.verdictCaution;
    return l.verdictAvoid;
  }

  String _statusLabel(AqiStatus s, AppLocalizations l) => switch (s) {
        AqiStatus.good => l.statusGood,
        AqiStatus.moderate => l.statusModerate,
        AqiStatus.unhealthySensitive => l.statusUnhealthySensitive,
        AqiStatus.unhealthy => l.statusUnhealthy,
        AqiStatus.veryUnhealthy => l.statusVeryUnhealthy,
        AqiStatus.hazardous => l.statusHazardous,
      };

  /// Insights dynamiques générés depuis les vraies données AQI/météo
  List<Widget> _buildDynamicInsights(AirQualityData d, AppLocalizations l) {
    final aqi  = d.aqi;
    final pm25 = d.pm25;
    final no2  = d.no2;
    final o3   = d.o3;
    final temp = d.weather.tempC;
    final hum  = d.weather.humidity;
    final uv   = d.weather.uvIndex;
    final wind = d.weather.windKmh;

    // 🫁 Respiratoire
    final String respText;
    if (pm25 == 0.0) {
      respText = 'Données PM2.5 en cours de chargement…';
    } else if (pm25 <= 15) {
      respText = 'PM2.5 à ${pm25.toStringAsFixed(1)} μg/m³ — sous le seuil OMS (15 μg/m³). Effort physique sans risque respiratoire.';
    } else if (pm25 <= 35) {
      respText = 'PM2.5 à ${pm25.toStringAsFixed(1)} μg/m³ — seuil OMS dépassé. Limitez les efforts intenses en extérieur.';
    } else {
      respText = 'PM2.5 à ${pm25.toStringAsFixed(1)} μg/m³ — niveau élevé. Évitez toute activité physique prolongée dehors.';
    }

    // ❤️ Cardiovasculaire
    final String cardioText;
    if (no2 == 0.0) {
      cardioText = 'Données NO₂ en cours de chargement…';
    } else if (no2 <= 25) {
      cardioText = 'NO₂ à ${no2.toStringAsFixed(0)} μg/m³ — sous le seuil OMS (25 μg/m³). Risque cardiovasculaire faible.';
    } else if (no2 <= 40) {
      cardioText = 'NO₂ à ${no2.toStringAsFixed(0)} μg/m³ — attention recommandée pour les personnes cardiaques.';
    } else {
      cardioText = 'NO₂ à ${no2.toStringAsFixed(0)} μg/m³ — seuil OMS dépassé. Les personnes cardiaques doivent éviter les zones de trafic.';
    }

    // 🌿 Pollen
    final p = d.pollen;
    final pollenLabels = [
      l.pollenNone, l.pollenVeryLow, l.pollenLow,
      l.pollenModerate, l.pollenHigh, l.pollenVeryHigh,
    ];
    final pollenColors = ['🟢', '🟢', '🟡', '🟠', '🔴', '🔴'];
    final String pollenText;
    if (p.total == 0 && p.grass == 0 && p.trees == 0) {
      pollenText = l.pollenLoading;
    } else {
      final idx = p.total.clamp(0, 5);
      pollenText = '${pollenColors[idx]} ${l.pollenTotalLabel} : ${pollenLabels[idx]} (${p.total}/5)\n'
          '🌾 ${l.grassLabel} ${p.grass}/5  🌳 ${l.treesLabel} ${p.trees}/5  🍄 ${l.moldsLabel} ${p.molds}/5';
    }

    // 🌤️ Météo & dispersion
    final String meteoText;
    final dispersion = wind >= 15 ? 'Bon brassage atmosphérique (vent ${wind.toStringAsFixed(0)} km/h).' : 'Vent faible — les polluants se dispersent peu.';
    final uvTip = uv >= 7 ? ' UV élevé ($uv/10) — protection solaire recommandée.' : '';
    meteoText = '${temp.toStringAsFixed(0)}°C · Humidité $hum% · UV $uv/10. $dispersion$uvTip';

    return [
      InsightCard(icon: '🫁', title: l.insightRespTitle,    text: respText),
      InsightCard(icon: '❤️', title: l.insightCardioTitle,  text: cardioText),
      InsightCard(icon: '🌿', title: l.insightPollenTitle,  text: pollenText),
      InsightCard(icon: '🌤️', title: l.insightWeatherTitle, text: meteoText),
    ];
  }
  /// Previously pointed to _MainShellState which was never in the widget tree.
  void _navigate(BuildContext context, int index) {
    context.findAncestorStateOfType<AppShellState>()?.setTab(index);
  }

  void _showShareSheet(
      BuildContext context, AirQualityData d, UserProfile p, AppLocalizations l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ShareSheet(data: d, profile: p),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppProvider>();
    final l = AppLocalizations.of(context);
    final d = ap.data;

    _listenForErrors(context, ap, l);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ap.refreshLocation,
          color: AppColors.accent,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          child: CustomScrollView(
            // FIX-MINOR-10: Required for RefreshIndicator to trigger on short content
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── App Bar ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Row(
                    children: [
                      const Text('💨', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 8),
                      Text(l.appTitle,
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                      const Spacer(),
                      // FIX-BUG-1: _IconBtn is now defined at bottom of this file.
                      _IconBtn(
                          icon: '🔔', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen()))),
                      const SizedBox(width: 8),
                      _IconBtn(
                          icon: '⚙️', onTap: () => _navigate(context, 3)),
                    ],
                  ),
                ),
              ),

              // ── Profile selector ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(l.profileLabel,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink3,
                              letterSpacing: 0.8)),
                    ),
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: UserProfile.values
                            .map((p) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ProfileChip(
                                    emoji: _profileEmoji(p),
                                    label: _profileLabel(p, l),
                                    selected: ap.profile == p,
                                    onTap: () => ap.setProfile(p),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Loading Shimmer ou Contenu ─────────────────────────────
              if (ap.loading && !ap.initialized)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: _HomeShimmer(),
                  ),
                )
              else ...[
                // ── Location bar ───────────────────────────────────────────
                SliverToBoxAdapter(
                child: GestureDetector(
                  onTap: ap.refreshLocation,
                  child: Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.cream2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Text('📍', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(ap.locationName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink)),
                        ),
                        ap.loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.accent))
                            : const Text('↻',
                                style: TextStyle(
                                    fontSize: 14, color: AppColors.ink3)),
                      ],
                    ),
                  ),
                ),
              ),

              // ── AQI Main Card ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: _AqiMainCard(
                  data: d,
                  statusLabel: _statusLabel(d.status, l),
                  verdictText: _verdictText(ap.profile, d.aqi, l),
                  aqiSourceLabel: l.aqiSource,
                  shareLabel: l.shareBtn,
                  onShare: () => _showShareSheet(context, d, ap.profile, l),
                ),
              ),

              // ── Recommendation ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: _RecommendationCard(
                  profile: ap.profile,
                  aqi: d.aqi,
                  // FIX-BUG-7: tips are now profile-aware and fully localised.
                  profileTitle: _profileLabel(ap.profile, l),
                  l: l,
                ),
              ),

              // ── Pollutants grid ────────────────────────────────────────
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: l.sectionPollutants,
                  actionLabel: l.seeAll,
                  onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DetailsScreen())),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.6,
                  ),
                  delegate: SliverChildListDelegate([
                    PollutantCard(
                        label: l.pm25Label,
                        value: d.pm25.toStringAsFixed(1),
                        unit: 'μg/m³',
                        aqi: d.aqi,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DetailsScreen()))),
                    PollutantCard(
                        label: l.pm10Label,
                        value: d.pm10?.toStringAsFixed(1) ?? 'N/A',
                        unit: 'μg/m³',
                        aqi: (d.aqi * 0.6).toInt(),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DetailsScreen()))),
                    PollutantCard(
                        label: l.no2Label,
                        value: d.no2.toStringAsFixed(0),
                        unit: 'μg/m³',
                        aqi: (d.aqi * 0.85).toInt(),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DetailsScreen()))),
                    PollutantCard(
                        label: l.o3Label,
                        value: d.o3.toStringAsFixed(0),
                        unit: 'μg/m³',
                        aqi: (d.aqi * 0.6).toInt(),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DetailsScreen()))),
                    PollutantCard(
                        label: l.so2Label,
                        value: d.so2.toStringAsFixed(1),
                        unit: 'μg/m³',
                        aqi: (d.aqi * 0.1).toInt(),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DetailsScreen()))),
                    PollutantCard(
                        label: l.coLabel,
                        value: d.co.toStringAsFixed(2),
                        unit: 'mg/m³',
                        aqi: (d.aqi * 0.05).toInt(),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DetailsScreen()))),
                  ]),
                ),
              ),

              // ── 24h Forecast ───────────────────────────────────────────
              SliverToBoxAdapter(
                  child: SectionHeader(title: l.sectionForecast)),
              SliverToBoxAdapter(
                  child: _ForecastStrip(forecast: d.forecast, nowLabel: l.now)),

              // ── Mini map ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _MiniMapCard(
                  // FIX-BUG-8: label is now localised via ARB key.
                  label: l.mapExplore,
                  onTap: () => _navigate(context, 1),
                ),
              ),

              // ── Health insights ────────────────────────────────────────
              SliverToBoxAdapter(
                  child: SectionHeader(title: l.sectionInsights)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Si clé IA présente → carte IA unifiée
                    if (ap.hasAiKey) ...[
                      _AiInsightCard(ap: ap, l: l),
                    ] else ...[
                      // Fallback : 4 cartes statiques
                      ..._buildDynamicInsights(d, l),
                    ],
                  ]),
                ),
              ),
              ], // Fin du else (contenu principal)
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Carte IA unifiée — remplace les 4 InsightCards quand la clé Groq est active
// ─────────────────────────────────────────────────────────────────────────────
class _AiInsightCard extends StatelessWidget {
  final AppProvider ap;
  final AppLocalizations l;
  const _AiInsightCard({required this.ap, required this.l});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.06),
            blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🤖', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(l.aiInsightCard,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
            const Spacer(),
            if (ap.aiLoading)
              const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accent)),
            const SizedBox(width: 4),
            Text('LLaMA 3.3',
              style: const TextStyle(fontSize: 9, color: AppColors.ink3,
                  fontFamily: 'DMMono')),
          ]),
          const SizedBox(height: 12),
          if (ap.aiLoading && ap.aiInsight == null)
            Text(l.aiInsightLoading,
              style: const TextStyle(fontSize: 13, color: AppColors.ink3,
                  fontStyle: FontStyle.italic))
          else if (ap.aiInsight != null)
            Text(ap.aiInsight!,
              style: const TextStyle(fontSize: 13, color: AppColors.ink2,
                  height: 1.6))
          else
            Text(l.aiInsightFallback,
              style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final String icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.cream2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(child: Text(icon, style: const TextStyle(fontSize: 16))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AQI Main Card
// ─────────────────────────────────────────────────────────────────────────────
class _AqiMainCard extends StatelessWidget {
  final AirQualityData data;
  final String statusLabel;
  final String verdictText;
  final String aqiSourceLabel;
  final String shareLabel;
  final VoidCallback onShare;

  const _AqiMainCard({
    required this.data,
    required this.statusLabel,
    required this.verdictText,
    required this.aqiSourceLabel,
    required this.shareLabel,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final color = aqiColor(data.aqi);
    final bg = aqiBgColor(data.aqi);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              // FIX-BUG-9: .withOpacity() deprecated in Flutter 3.19+, replaced with .withValues()
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // FIX-BUG-10: TweenAnimationBuilder given a ValueKey so animation
              // does not restart on every parent rebuild.
              TweenAnimationBuilder<double>(
                key: ValueKey(data.aqi),
                tween: Tween(begin: 0, end: data.aqi.toDouble()),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOut,
                builder: (_, val, __) => Text(
                  val.toInt().toString(),
                  style: TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontFamily: 'DMMono',
                      letterSpacing: -3,
                      height: 0.9),
                ),
              ),
              Flexible(
                child: Padding(
                padding: const EdgeInsets.only(bottom: 10, left: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ),
                    const SizedBox(height: 4),
                    Text(aqiSourceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.ink3)),
                  ],
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AqiGauge(aqi: data.aqi),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration:
                BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Text(verdictText,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.3)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onShare,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📤', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(shareLabel,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cream)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIX-BUG-7: RecommendationCard — tips are now profile-aware and localised.
// Previously all profiles showed the same English-only generic tips.
// ─────────────────────────────────────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  final UserProfile profile;
  final int aqi;
  final String profileTitle;
  final AppLocalizations l;

  const _RecommendationCard({
    required this.profile,
    required this.aqi,
    required this.profileTitle,
    required this.l,
  });

  // FIX-M01: All tip strings fully localised — zero hardcoded French strings remain.
  List<(String, String)> get _tips {
    if (profile == UserProfile.sick || profile == UserProfile.elderly) {
      if (aqi <= 35) return [
        ('💡', l.insightRespText),
        ('😷', l.tipMaskNotRequired),
        ('✅', l.verdictGo),
      ];
      if (aqi <= 75) return [
        ('⚠️', l.tipModerateConditions),
        ('😷', l.tipMaskFFP2Recommended),
        ('💊', l.tipKeepTreatmentHandy),
      ];
      return [
        ('🚫', l.tipAvoidNonEssentialOuting),
        ('🏠', l.tipStayIndoorsWindowsClosed),
        ('🚨', l.tipConsultDoctorIfSymptoms),
      ];
    }
    if (profile == UserProfile.child) {
      if (aqi <= 40) return [
        ('✅', l.tipExcellentAirOutdoors),
        ('🌿', l.tipPreferParksFromTraffic),
      ];
      if (aqi <= 65) return [
        ('⚠️', l.tipLimitIntensePhysical),
        ('⏰', l.tipPreferOffPeakHours),
      ];
      return [
        ('🚫', l.tipAvoidProlongedOutdoor),
        ('🏠', l.tipPreferIndoor),
      ];
    }
    if (profile == UserProfile.cyclist || profile == UserProfile.athlete) {
      final sport = profile == UserProfile.cyclist
          ? l.tipCyclistSport
          : l.tipAthleteLabel;
      if (aqi <= 50) return [
        ('💡', l.tipCyclistExcellent(aqi, sport)),
        ('⏰', l.tipBestWindow),
        ('🛡️', l.tipMaskNotNeeded),
        ('🗺️', l.tipPreferGreenwaysParks),
      ];
      if (aqi <= 80) return [
        ('⚠️', l.tipReduceIntenseEffort),
        ('😷', l.tipMaskSensitivePeople),
        ('🕐', l.tipPreferOffPeakMorning),
      ];
      return [
        ('🚫', l.tipLimitLongOutdoorEffort),
        ('😷', l.tipMaskFFP2Strong),
        ('🏠', l.tipPreferIndoor),
        ('💊', l.tipBronchodilator),
      ];
    }
    // Normal / default
    if (aqi <= 100) return [
      ('✅', l.verdictGo),
      ('💡', l.insightRespText),
    ];
    return [
      ('⚠️', l.verdictCaution),
      ('🌬️', l.tipLimitTimeOutdoors),
    ];
  }
  @override
  Widget build(BuildContext context) {
    // FIX-BUG-6: color variable is now actually used for the left border accent.
    final color = aqiColor(aqi);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        // Subtle left accent border in AQI colour
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 0,
              offset: const Offset(-3, 0))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profileTitle,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 10),
          ..._tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.$1,
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(tip.$2,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.ink2,
                                height: 1.4))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Forecast strip
// ─────────────────────────────────────────────────────────────────────────────
class _ForecastStrip extends StatelessWidget {
  final List<HourlyForecast> forecast;
  final String nowLabel;
  const _ForecastStrip({required this.forecast, required this.nowLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: forecast.length,
        itemBuilder: (_, i) {
          final f = forecast[i];
          final isNow = i == 12;
          final color = aqiColor(f.aqi);
          return Container(
            width: 56,
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isNow ? AppColors.ink : AppColors.cream2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: isNow ? AppColors.ink : AppColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isNow ? nowLabel : '${f.time.hour}h',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isNow ? AppColors.cream3 : AppColors.ink3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  f.aqi.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isNow ? Colors.white : color,
                    fontFamily: 'DMMono',
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                    width: 20,
                    height: 3,
                    decoration: BoxDecoration(
                        // FIX-BUG-9: withOpacity -> withValues
                        color: color.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2))),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini map card
// FIX-BUG-8: label now passed from caller (localised), not hardcoded in French.
// ─────────────────────────────────────────────────────────────────────────────
class _MiniMapCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MiniMapCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.mapMiniBackground, // FIX-MINOR-04
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink2)),
            ],
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Share bottom sheet — partage une image PNG générée depuis la carte AQI
// ─────────────────────────────────────────────────────────────────────────────
class ShareSheet extends StatefulWidget {
  final AirQualityData data;
  final UserProfile profile;
  const ShareSheet({super.key, required this.data, required this.profile});

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  bool _sharing = false;
  final GlobalKey _cardKey = GlobalKey();

  // ── Capture le widget _ShareCard en PNG puis partage via Share.shareXFiles ──
  Future<void> _shareAsImage(AppLocalizations l) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      // Laisser le temps au widget de se rendre
      await Future.delayed(const Duration(milliseconds: 120));

      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('RenderRepaintBoundary introuvable');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('toByteData() retourne null');

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/airpulse_share.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.pop(context);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: '💨 AirPulse · AQI ${widget.data.aqi} · ${widget.data.stationName}',
      );
    } catch (e) {
      debugPrint('AirPulse: shareAsImage error: $e');
      if (!mounted) return;
      // Fallback texte si capture échoue
      Share.share(
        '💨 AirPulse\n'
        'AQI ${widget.data.aqi} · ${widget.data.stationName}\n'
        'PM2.5: ${widget.data.pm25.toStringAsFixed(1)} μg/m³\n'
        'NO₂: ${widget.data.no2.toStringAsFixed(0)} μg/m³\n'
        'O₃: ${widget.data.o3.toStringAsFixed(0)} μg/m³\n'
        '#AirQuality #AirPulse',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copyLink(AppLocalizations l) async {
    final d = widget.data;
    final url = 'https://airpulse.app/share?aqi=${d.aqi}'
        '&loc=${Uri.encodeComponent(d.stationName)}';
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.shareCopied),
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = widget.data;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.cream3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.shareTitle,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(l.shareSub,
              style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
          const SizedBox(height: 20),

          // ── Carte partageable (capturée en PNG) ────────────────────────
          RepaintBoundary(
            key: _cardKey,
            child: _ShareCard(data: d, profile: widget.profile),
          ),

          const SizedBox(height: 20),

          // ── Bouton principal : partager l'image ────────────────────────
          GestureDetector(
            onTap: _sharing ? null : () => _shareAsImage(l),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _sharing ? AppColors.ink3 : AppColors.ink,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_sharing)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.cream),
                    )
                  else
                    const Text('📤', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    _sharing ? '…' : l.shareBtn,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: AppColors.cream),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── Copier le lien ─────────────────────────────────────────────
          GestureDetector(
            onTap: () => _copyLink(l),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.cream2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔗', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Text(l.shareFmtLink,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: AppColors.ink2)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ShareCard — widget visuel capturé en PNG pour le partage
// Design : logo + AQI grand + jauge + pollutants + profil + branding
// ─────────────────────────────────────────────────────────────────────────────
class _ShareCard extends StatelessWidget {
  final AirQualityData data;
  final UserProfile profile;
  const _ShareCard({required this.data, required this.profile});

  String _profileEmoji() => switch (profile) {
    UserProfile.cyclist => '🚴',
    UserProfile.athlete => '🏃',
    UserProfile.sick    => '🫁',
    UserProfile.normal  => '👤',
    UserProfile.child   => '👧',
    UserProfile.elderly => '👴',
  };

  @override
  Widget build(BuildContext context) {
    final color = aqiColor(data.aqi);
    final bg    = aqiBgColor(data.aqi);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header : logo + lieu + heure
          Row(
            children: [
              const Text('💨', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              const Text('AirPulse',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                      color: AppColors.ink, fontFamily: 'DMSans')),
              const Spacer(),
              Text(
                '${data.updatedAt.hour.toString().padLeft(2, '0')}:'
                '${data.updatedAt.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 11, color: AppColors.ink3,
                    fontFamily: 'DMMono'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('📍 ${data.stationName}',
              style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
          const SizedBox(height: 16),

          // AQI principal
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${data.aqi}',
                style: TextStyle(
                  fontSize: 72, fontWeight: FontWeight.w800,
                  color: color, fontFamily: 'DMMono',
                  letterSpacing: -3, height: 0.9,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: bg, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      _statusLabel(context),
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_profileEmoji(),
                      style: const TextStyle(fontSize: 16)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Jauge AQI
          AqiGauge(aqi: data.aqi),
          const SizedBox(height: 16),

          // Grille pollutants
          Row(
            children: [
              _pollCell('PM2.5', data.pm25.toStringAsFixed(1), 'μg/m³', color),
              const SizedBox(width: 8),
              _pollCell('PM10',  data.pm10?.toStringAsFixed(1) ?? 'N/A', 'μg/m³', AppColors.ink2),
              const SizedBox(width: 8),
              _pollCell('NO₂',   data.no2.toStringAsFixed(0),  'μg/m³', AppColors.ink2),
              const SizedBox(width: 8),
              _pollCell('O₃',    data.o3.toStringAsFixed(0),   'μg/m³', AppColors.ink2),
            ],
          ),
          const SizedBox(height: 14),

          // Météo
          Row(
            children: [
              Text('🌡️ ${data.weather.tempC.toStringAsFixed(0)}°C',
                  style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
              const SizedBox(width: 12),
              Text('💨 ${data.weather.windKmh.toStringAsFixed(0)} km/h ${data.weather.windDir}',
                  style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
              const SizedBox(width: 12),
              Text('💧 ${data.weather.humidity}%',
                  style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
            ],
          ),
          const SizedBox(height: 14),

          // Branding bas
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'airpulse.app',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: AppColors.cream, fontFamily: 'DMMono'),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(BuildContext context) {
    return switch (aqiStatusFrom(data.aqi)) {
      AqiStatus.good               => 'Good',
      AqiStatus.moderate           => 'Moderate',
      AqiStatus.unhealthySensitive => 'Unhealthy*',
      AqiStatus.unhealthy          => 'Unhealthy',
      AqiStatus.veryUnhealthy      => 'Very Unhealthy',
      AqiStatus.hazardous          => 'Hazardous',
    };
  }

  static Widget _pollCell(String label, String value, String unit, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.cream2,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    color: AppColors.ink3)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                    color: color, fontFamily: 'DMMono')),
            Text(unit,
                style: const TextStyle(fontSize: 8, color: AppColors.ink3)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading Skeleton (Shimmer)
// ─────────────────────────────────────────────────────────────────────────────
class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.cream2,
      highlightColor: Colors.white,
      child: Column(
        children: [
          // Location bar
          Container(height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
          const SizedBox(height: 10),
          // Main card
          Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24))),
          const SizedBox(height: 20),
          // Pollutants grid
          Row(
            children: [
              Expanded(child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 90, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)))),
            ],
          ),
        ],
      ),
    );
  }
}

// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_provider.dart';
import '../models/air_quality_model.dart';
import '../theme/app_theme.dart';
import '../widgets/aqi_widgets.dart';
import '../l10n/app_localizations.dart';
import '../navigation/app_shell.dart' show AppShellState; // FIX-CRITICAL-01: no longer imports main.dart

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // L-08 fix: afficher un snackbar quand AppProvider._error est non-null
  void _listenForErrors(BuildContext context, AppProvider ap) {
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
          label: 'Réessayer',
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

  /// FIX-BUG-2: Now correctly looks for AppShellState (public, from main.dart).
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

    _listenForErrors(context, ap);

    // Premier chargement automatique — une seule fois via le flag initialized
    if (!ap.initialized && !ap.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ap.refreshLocation());
    }

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: ap.refreshLocation,
          color: AppColors.accent,
          backgroundColor: AppColors.cream,
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
                          icon: '🔔', onTap: () => _navigate(context, 3)),
                      const SizedBox(width: 8),
                      _IconBtn(
                          icon: '⚙️', onTap: () => _navigate(context, 4)),
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
                  onAction: () => _navigate(context, 1),
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
                        onTap: () => _navigate(context, 1)),
                    PollutantCard(
                        label: l.pm10Label,
                        value: d.pm10.toStringAsFixed(1),
                        unit: 'μg/m³',
                        aqi: (d.aqi * 0.6).toInt(),
                        onTap: () => _navigate(context, 1)),
                    PollutantCard(
                        label: l.no2Label,
                        value: d.no2.toStringAsFixed(0),
                        unit: 'μg/m³',
                        aqi: (d.aqi * 0.85).toInt(),
                        onTap: () => _navigate(context, 1)),
                    PollutantCard(
                        label: l.o3Label,
                        value: d.o3.toStringAsFixed(0),
                        unit: 'μg/m³',
                        aqi: (d.aqi * 0.6).toInt(),
                        onTap: () => _navigate(context, 1)),
                    PollutantCard(
                        label: l.so2Label,
                        value: d.so2.toStringAsFixed(1),
                        unit: 'μg/m³',
                        aqi: (d.aqi * 0.1).toInt(),
                        onTap: () => _navigate(context, 1)),
                    PollutantCard(
                        label: l.coLabel,
                        value: d.co.toStringAsFixed(2),
                        unit: 'mg/m³',
                        aqi: (d.aqi * 0.05).toInt(),
                        onTap: () => _navigate(context, 1)),
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
                  onTap: () => _navigate(context, 2),
                ),
              ),

              // ── Health insights ────────────────────────────────────────
              SliverToBoxAdapter(
                  child: SectionHeader(title: l.sectionInsights)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    InsightCard(
                        icon: '🫁',
                        title: l.insightRespTitle,
                        text: l.insightRespText),
                    InsightCard(
                        icon: '❤️',
                        title: l.insightCardioTitle,
                        text: l.insightCardioText),
                    InsightCard(
                        icon: '🌿',
                        title: l.insightPollenTitle,
                        text: l.insightPollenText),
                    InsightCard(
                        icon: '🌤️',
                        title: l.insightWeatherTitle,
                        text: l.insightWeatherText),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FIX-BUG-1: _IconBtn — was missing entirely (compile error).
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
              Padding(
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
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color)),
                    ),
                    const SizedBox(height: 4),
                    Text(aqiSourceLabel,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.ink3)),
                  ],
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
// Share bottom sheet
// FIX-BUG-5: Share.share() and Clipboard.setData() now actually connected.
// ─────────────────────────────────────────────────────────────────────────────
class ShareSheet extends StatefulWidget {
  final AirQualityData data;
  final UserProfile profile;
  const ShareSheet({super.key, required this.data, required this.profile});

  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  String _format = 'text';

  String _buildShareText(AirQualityData d, AppLocalizations l) {
    return '💨 AirPulse\n'
        'AQI ${d.aqi} · ${d.stationName}\n'
        'PM2.5: ${d.pm25.toStringAsFixed(1)} μg/m³ | '
        'NO₂: ${d.no2.toStringAsFixed(0)} μg | '
        'O₃: ${d.o3.toStringAsFixed(0)} μg\n'
        '#AirQuality #AirPulse';
  }

  String _buildLink(AirQualityData d) =>
      'https://airpulse.app/share?aqi=${d.aqi}&loc=${Uri.encodeComponent(d.stationName)}';

  Future<void> _copy(AirQualityData d, AppLocalizations l) async {
    final text = _format == 'link' ? _buildLink(d) : _buildShareText(d, l);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return; // FIX: mounted check before any context use
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.shareCopied),
      backgroundColor: AppColors.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _share(String target, AirQualityData d, AppLocalizations l) {
    Share.share(_buildShareText(d, l));
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
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.cream3,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(l.shareTitle,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(l.shareSub,
              style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
          const SizedBox(height: 16),
          Row(
            children: [
              _FormatBtn(
                  label: l.shareFmtCard,
                  value: 'card',
                  current: _format,
                  onTap: () => setState(() => _format = 'card')),
              const SizedBox(width: 8),
              _FormatBtn(
                  label: l.shareFmtText,
                  value: 'text',
                  current: _format,
                  onTap: () => setState(() => _format = 'text')),
              const SizedBox(width: 8),
              _FormatBtn(
                  label: l.shareFmtLink,
                  value: 'link',
                  current: _format,
                  onTap: () => setState(() => _format = 'link')),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cream2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: _buildPreview(d, l),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ShareDest(
                  icon: '💚',
                  label: l.shareWhatsApp,
                  onTap: () => _share('whatsapp', d, l)),
              _ShareDest(
                  icon: '✈️',
                  label: l.shareTelegram,
                  onTap: () => _share('telegram', d, l)),
              _ShareDest(
                  icon: '🐦',
                  label: l.shareTwitter,
                  onTap: () => _share('twitter', d, l)),
              _ShareDest(
                  icon: '📱',
                  label: l.shareSMS,
                  onTap: () => _share('sms', d, l)),
              _ShareDest(
                  icon: '📧',
                  label: l.shareEmail,
                  onTap: () => _share('email', d, l)),
              _ShareDest(
                  icon: '📋',
                  label: l.shareCopy,
                  onTap: () => _copy(d, l)),
              _ShareDest(
                  icon: '⋯',
                  label: l.shareMore,
                  onTap: () => _share('native', d, l)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(AirQualityData d, AppLocalizations l) {
    if (_format == 'link') {
      return Text(_buildLink(d),
          style: const TextStyle(
              fontSize: 11,
              color: AppColors.accent,
              fontFamily: 'DMMono'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('💨 AirPulse',
              style:
                  TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(l.now,
              style:
                  const TextStyle(fontSize: 10, color: AppColors.ink3)),
        ]),
        const SizedBox(height: 6),
        Text('AQI ${d.aqi} · ${d.stationName}',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: aqiColor(d.aqi),
                fontFamily: 'DMMono')),
        const SizedBox(height: 4),
        Text(
            'PM2.5: ${d.pm25.toStringAsFixed(1)} μg | '
            'NO₂: ${d.no2.toStringAsFixed(0)} μg | '
            'O₃: ${d.o3.toStringAsFixed(0)} μg',
            style:
                const TextStyle(fontSize: 11, color: AppColors.ink3)),
      ],
    );
  }
}

class _FormatBtn extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final VoidCallback onTap;
  const _FormatBtn(
      {required this.label,
      required this.value,
      required this.current,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = value == current;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.ink : AppColors.cream2,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: active ? AppColors.ink : AppColors.border),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.cream : AppColors.ink3)),
        ),
      ),
    );
  }
}

class _ShareDest extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _ShareDest(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.cream2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child:
                Center(child: Text(icon, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.ink2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

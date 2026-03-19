// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/air_quality_model.dart';
import '../theme/app_theme.dart';
import '../widgets/aqi_widgets.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _languages = [
    (code: 'fr', flag: '🇫🇷', label: 'Français'),
    (code: 'en', flag: '🇬🇧', label: 'English'),
    (code: 'es', flag: '🇪🇸', label: 'Español'),
    (code: 'de', flag: '🇩🇪', label: 'Deutsch'),
    (code: 'it', flag: '🇮🇹', label: 'Italiano'),
    (code: 'pt', flag: '🇵🇹', label: 'Português'),
    (code: 'ar', flag: '🇸🇦', label: 'العربية'),
    (code: 'zh', flag: '🇨🇳', label: '中文'),
    (code: 'ja', flag: '🇯🇵', label: '日本語'),
  ];

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppProvider>();
    final l  = AppLocalizations.of(context);

    final currentLangLabel = _languages
        .firstWhere((e) => e.code == ap.locale.languageCode,
            orElse: () => _languages[1])
        .label;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppColors.cream,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              title: Text(l.settingsTitle),
              centerTitle: false,
            ),

            // ── Profile card ─────────────────────────────────────────────
            SliverToBoxAdapter(child: _ProfileCard(ap: ap, l: l)),

            // ── Data sources ─────────────────────────────────────────────
            _SectionLabel(label: l.settingsDataSources),
            SliverToBoxAdapter(
              child: _SettingsGroup(children: [
                SettingsRow(icon: '🌐', label: 'WAQI / AQICN',   desc: l.sourceWaqiDesc,
                  trailing: _toggle(ap.dataSourceEnabled['waqi'] ?? true,  'waqi',  ap)),
                SettingsRow(icon: '🌤️', label: 'Open-Meteo',      desc: l.sourceOpenMeteoDesc,
                  trailing: _toggle(ap.dataSourceEnabled['openmeteo'] ?? true, 'openmeteo', ap)),
                SettingsRow(icon: '📡', label: 'OpenAQ v3',        desc: l.sourceOpenAqDesc,
                  trailing: _toggle(ap.dataSourceEnabled['openaq'] ?? false, 'openaq', ap)),
                SettingsRow(icon: '🛰️', label: 'Copernicus CAMS',  desc: l.sourceCopernicusDesc,
                  trailing: _toggle(ap.dataSourceEnabled['copernicus'] ?? false, 'copernicus', ap)),
                SettingsRow(icon: '🏙️', label: 'AirParif',         desc: l.sourceAirparifDesc,
                  trailing: _toggle(ap.dataSourceEnabled['airparif'] ?? true, 'airparif', ap)),
              ]),
            ),

            // ── Display ──────────────────────────────────────────────────
            _SectionLabel(label: l.settingsDisplay),
            SliverToBoxAdapter(
              child: _SettingsGroup(children: [
                SettingsRow(
                  icon: '📐',
                  label: l.settingsUnits,
                  desc: l.settingsUnitsDesc,
                  trailing: const Text('μg/m³ ›',
                    style: TextStyle(fontSize: 13, color: AppColors.ink3, fontWeight: FontWeight.w500)),
                ),
                // Language row — expanded to show flag picker
                _LanguageRow(ap: ap, l: l, currentLabel: currentLangLabel),
                SettingsRow(
                  icon: '🌙',
                  label: l.settingsDarkMode,
                  trailing: Switch.adaptive(
                    value: ap.darkMode,
                    onChanged: ap.setDarkMode,
                    activeColor: AppColors.accent,
                  ),
                ),
              ]),
            ),

            // ── Personal threshold ───────────────────────────────────────
            _SectionLabel(label: l.settingsPersonalThreshold),
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('⚠️', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l.settingsPersonalThresholdDesc,
                          style: const TextStyle(fontSize: 12, color: AppColors.ink3)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: aqiBgColor(ap.personalThreshold.toInt()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'AQI ${ap.personalThreshold.toInt()}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: aqiColor(ap.personalThreshold.toInt()),
                          ),
                        ),
                      ),
                    ]),
                    Slider(
                      value: ap.personalThreshold,
                      min: 25,
                      max: 200,
                      divisions: 35,
                      activeColor: aqiColor(ap.personalThreshold.toInt()),
                      inactiveColor: AppColors.cream3,
                      onChanged: ap.setPersonalThreshold,
                      semanticFormatterCallback: (v) => 'AQI ${v.toInt()}', // FIX-MINOR-08
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('25', style: TextStyle(fontSize: 10, color: AppColors.ink3, fontFamily: 'DMMono')),
                        Text('100', style: TextStyle(fontSize: 10, color: AppColors.ink3, fontFamily: 'DMMono')),
                        Text('200', style: TextStyle(fontSize: 10, color: AppColors.ink3, fontFamily: 'DMMono')),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── About ────────────────────────────────────────────────────
            _SectionLabel(label: l.settingsAbout),
            SliverToBoxAdapter(
              child: _SettingsGroup(children: [
                SettingsRow(icon: 'ℹ️', label: l.settingsVersion,     desc: l.settingsVersionDesc),
                SettingsRow(icon: '📖', label: l.settingsMethodology,  desc: l.settingsMethodologyDesc,
                  trailing: const Text('›', style: TextStyle(fontSize: 16, color: AppColors.ink3))),
                SettingsRow(icon: '🔒', label: l.settingsPrivacy,
                  trailing: const Text('›', style: TextStyle(fontSize: 16, color: AppColors.ink3))),
              ]),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // FIX-M02: Toggles now wired to provider — state persisted via SharedPreferences
  Widget _toggle(bool value, String sourceId, AppProvider ap) => Switch.adaptive(
    value: value,
    onChanged: (_) => ap.toggleDataSource(sourceId),
    activeColor: AppColors.accent,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Language selector row (expands inline)
// ─────────────────────────────────────────────────────────────────────────────
class _LanguageRow extends StatefulWidget {
  final AppProvider ap;
  final AppLocalizations l;
  final String currentLabel;
  const _LanguageRow({required this.ap, required this.l, required this.currentLabel});

  @override
  State<_LanguageRow> createState() => _LanguageRowState();
}

class _LanguageRowState extends State<_LanguageRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              const Text('🌐', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.l.settingsLanguage,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                Text(widget.l.settingsLanguageDesc(widget.currentLabel),
                  style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
              ])),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Text('›', style: TextStyle(fontSize: 16, color: AppColors.ink3)),
              ),
            ]),
          ),
        ),
        // Expanded language grid
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Container(
            padding: const EdgeInsets.fromLTRB(44, 4, 14, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: SettingsScreen._languages.map((lang) {
                final active = lang.code == widget.ap.locale.languageCode;
                return GestureDetector(
                  onTap: () {
                    widget.ap.setLocale(Locale(lang.code));
                    setState(() => _expanded = false);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? AppColors.ink : AppColors.cream2,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: active ? AppColors.ink : AppColors.border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(lang.flag, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        lang.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: active ? AppColors.cream : AppColors.ink2,
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile card (health profile summary + profile chips)
// ─────────────────────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final AppProvider ap;
  final AppLocalizations l;
  const _ProfileCard({required this.ap, required this.l});

  String _emoji(UserProfile p) => switch (p) {
    UserProfile.cyclist  => '🚴',
    UserProfile.athlete  => '🏃',
    UserProfile.sick     => '🫁',
    UserProfile.normal   => '👤',
    UserProfile.child    => '👧',
    UserProfile.elderly  => '👴',
  };

  String _label(UserProfile p) => switch (p) {
    UserProfile.cyclist  => l.profileCyclistLabel,
    UserProfile.athlete  => l.profileAthleteLabel,
    UserProfile.sick     => l.profileSickLabel,
    UserProfile.normal   => l.profileNormalLabel,
    UserProfile.child    => l.profileChildLabel,
    UserProfile.elderly  => l.profileElderlyLabel,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsMyProfile,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink3,
              letterSpacing: 0.6, textBaseline: TextBaseline.alphabetic)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserProfile.values.map((p) {
              final active = ap.profile == p;
              return GestureDetector(
                onTap: () => ap.setProfile(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? AppColors.ink : AppColors.cream2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? AppColors.ink : AppColors.border),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_emoji(p), style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(_label(p),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: active ? AppColors.cream : AppColors.ink2)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          SettingsRow(icon: '🏃', label: l.settingsActivityType,     desc: l.settingsActivityTypeDesc,
            trailing: const Text('›', style: TextStyle(color: AppColors.ink3, fontSize: 16))),
          SettingsRow(icon: '🫁', label: l.settingsRespSensitivity,  desc: l.settingsRespSensitivityDesc,
            trailing: const Text('›', style: TextStyle(color: AppColors.ink3, fontSize: 16))),
          SettingsRow(icon: '💊', label: l.settingsMedical,           desc: l.settingsMedicalDesc,
            trailing: const Text('›', style: TextStyle(color: AppColors.ink3, fontSize: 16))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(label.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.ink3, letterSpacing: 0.8)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings group card
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 20),
    decoration: BoxDecoration(
      color: AppColors.cream,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(children: children),
    ),
  );
}

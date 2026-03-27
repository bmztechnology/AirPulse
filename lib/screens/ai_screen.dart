// lib/screens/ai_screen.dart
// Écran dédié IA — analyse complète Groq/LLaMA 3.3
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/ai_insight_service.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/aqi_widgets.dart';

class AiScreen extends StatefulWidget {
  const AiScreen({super.key});
  @override
  State<AiScreen> createState() => _AiScreenState();
}

class _AiScreenState extends State<AiScreen> {
  final _keyCtrl = TextEditingController();
  bool _showKey  = false;
  bool _keyDirty = false;

  @override
  void initState() {
    super.initState();
    final ap = context.read<AppProvider>();
    _keyCtrl.text = AiInsightService.apiKey;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

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

            // ── AppBar ────────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: AppColors.cream,
              surfaceTintColor: Colors.transparent,
              pinned: true,
              title: Row(children: [
                Hero(tag: 'app_logo', child: Image.asset('assets/images/logo.png', width: 24, height: 24)),
                const SizedBox(width: 8),
                Text(l.aiScreenTitle,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                      color: AppColors.ink)),
              ]),
              centerTitle: false,
              actions: [
                if (ap.hasAiKey)
                  IconButton(
                    icon: const Text('↺', style: TextStyle(fontSize: 18,
                        color: AppColors.ink2)),
                    onPressed: ap.aiLoading ? null : ap.refreshLocation,
                    tooltip: l.locationRefresh,
                  ),
              ],
            ),

            // ── Clé API ───────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildApiKeyCard(ap, l)),

            // ── Analyse principale ────────────────────────────────────
            if (ap.hasAiKey) ...[
              SliverToBoxAdapter(child: _buildInsightCard(ap, l, d)),
              SliverToBoxAdapter(child: _buildContextCard(ap, l, d)),
              SliverToBoxAdapter(child: _buildForecastCard(ap, l, d)),
            ],

            // ── Sans clé — explication ────────────────────────────────
            if (!ap.hasAiKey)
              SliverToBoxAdapter(child: _buildNoKeyCard(l)),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ── Carte clé API ─────────────────────────────────────────────────────────
  Widget _buildApiKeyCard(AppProvider ap, AppLocalizations l) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ap.hasAiKey ? AppColors.aqiGreenBg : AppColors.accentLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ap.hasAiKey
            ? AppColors.aqiGreen.withValues(alpha: 0.4)
            : AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(ap.hasAiKey ? '🟢' : '🔑',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              ap.hasAiKey ? l.aiKeyActive : l.aiKeyRequired,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: ap.hasAiKey ? AppColors.aqiGreen : AppColors.accent),
            )),
            if (!ap.hasAiKey)
              GestureDetector(
                onTap: () => _launchGroqConsole(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(l.aiGetKey,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.white)),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _keyCtrl,
                obscureText: !_showKey,
                onChanged: (_) => setState(() => _keyDirty = true),
                style: const TextStyle(fontSize: 12, fontFamily: 'DMMono',
                    color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'gsk_...',
                  hintStyle: const TextStyle(color: AppColors.ink3, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.cream,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_showKey
                        ? Icons.visibility_off : Icons.visibility,
                        size: 16, color: AppColors.ink3),
                    onPressed: () => setState(() => _showKey = !_showKey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                context.read<AppProvider>().setGroqApiKey(_keyCtrl.text);
                setState(() => _keyDirty = false);
                FocusScope.of(context).unfocus();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(l.aiSaveKey,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.cream)),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(l.aiKeyDesc,
            style: const TextStyle(fontSize: 10, color: AppColors.ink3)),
        ],
      ),
    );
  }

  // ── Carte analyse principale ──────────────────────────────────────────────
  Widget _buildInsightCard(AppProvider ap, AppLocalizations l, d) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('🤖', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(l.aiAnalysisTitle,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
            const Spacer(),
            Text('LLaMA 3.3 · Groq',
              style: const TextStyle(fontSize: 10, color: AppColors.ink3,
                  fontFamily: 'DMMono')),
          ]),
          const SizedBox(height: 14),

          if (ap.aiLoading)
            _buildLoadingShimmer()
          else if (ap.aiInsight != null)
            Text(ap.aiInsight!,
              style: const TextStyle(fontSize: 14, color: AppColors.ink2,
                  height: 1.6))
          else
            Text(l.aiNoInsight,
              style: const TextStyle(fontSize: 13, color: AppColors.ink3)),

          if (ap.aiInsight != null) ...[
            const SizedBox(height: 14),
            Row(children: [
              const Spacer(),
              GestureDetector(
                onTap: () => Clipboard.setData(
                    ClipboardData(text: ap.aiInsight ?? '')),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.cream2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(l.shareCopy,
                    style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
                ),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ── Carte contexte (données utilisées) ───────────────────────────────────
  Widget _buildContextCard(AppProvider ap, AppLocalizations l, d) {
    final data = ap.data;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.aiContextTitle,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.ink3, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _ctxChip('AQI ${data.aqi}', aqiColor(data.aqi), aqiBgColor(data.aqi)),
            _ctxChip('PM2.5 ${data.pm25.toStringAsFixed(1)}μg', AppColors.ink2, AppColors.cream2),
            _ctxChip('NO₂ ${data.no2.toStringAsFixed(0)}μg', AppColors.ink2, AppColors.cream2),
            _ctxChip('O₃ ${data.o3.toStringAsFixed(0)}μg', AppColors.ink2, AppColors.cream2),
            _ctxChip('${data.weather.tempC.toStringAsFixed(0)}°C', AppColors.ink2, AppColors.cream2),
            _ctxChip('UV ${data.weather.uvIndex}', AppColors.ink2, AppColors.cream2),
            _ctxChip('💨 ${data.weather.windKmh.toStringAsFixed(0)}km/h', AppColors.ink2, AppColors.cream2),
            _ctxChip('🌾 ${data.pollen.grass}/5', AppColors.ink2, AppColors.cream2),
          ]),
        ],
      ),
    );
  }

  Widget _ctxChip(String label, Color color, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
    child: Text(label, style: TextStyle(fontSize: 11,
        fontWeight: FontWeight.w600, color: color)),
  );

  // ── Prévisions IA ─────────────────────────────────────────────────────────
  Widget _buildForecastCard(AppProvider ap, AppLocalizations l, d) {
    final data = ap.data;
    if (data.forecast.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.sectionForecast,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.ink3, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          // Meilleure fenêtre : heure avec AQI le plus bas
          () {
            final future = data.forecast.where((f) =>
                f.time.isAfter(DateTime.now())).toList();
            if (future.isEmpty) return const SizedBox.shrink();
            future.sort((a, b) => a.aqi.compareTo(b.aqi));
            final best = future.first;
            final color = aqiColor(best.aqi);
            final bg    = aqiBgColor(best.aqi);
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: bg,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Text('⏰', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.aiBestWindow,
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700, color: AppColors.ink)),
                    Text('${best.time.hour}h00 — AQI ${best.aqi}',
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w800, color: color,
                          fontFamily: 'DMMono')),
                  ],
                )),
              ]),
            );
          }(),
        ],
      ),
    );
  }

  // ── Sans clé ──────────────────────────────────────────────────────────────
  Widget _buildNoKeyCard(AppLocalizations l) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cream2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: [
        const Text('🤖', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 12),
        Text(l.aiNoKeyTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
              color: AppColors.ink), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(l.aiNoKeyDesc,
          style: const TextStyle(fontSize: 13, color: AppColors.ink3,
              height: 1.5), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _launchGroqConsole,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(l.aiGetKey,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white)),
          ),
        ),
      ]),
    );
  }

  // ── Shimmer de chargement ─────────────────────────────────────────────────
  Widget _buildLoadingShimmer() {
    return Column(children: [
      for (int i = 0; i < 3; i++) ...[
        Container(
          height: 12,
          width: double.infinity,
          margin: EdgeInsets.only(
              right: i == 2 ? 80 : 0, bottom: 8),
          decoration: BoxDecoration(
            color: AppColors.cream3,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ],
      const SizedBox(height: 4),
      Row(children: [
        const Text('🤖 ', style: TextStyle(fontSize: 12)),
        Text(AppLocalizations.of(context).aiInsightLoading,
          style: const TextStyle(fontSize: 11, color: AppColors.ink3,
              fontStyle: FontStyle.italic)),
      ]),
    ]);
  }

  void _launchGroqConsole() {
    Clipboard.setData(const ClipboardData(text: 'https://console.groq.com'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).groqLinkCopied),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3)),
    );
  }
}

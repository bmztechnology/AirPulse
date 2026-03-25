// lib/features/exposure/presentation/screens/exposure_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/exposure_provider.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/entities/daily_score.dart';
import '../../../../l10n/app_localizations.dart';

class ExposureDashboardScreen extends StatelessWidget {
  const ExposureDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ep = context.watch<ExposureProvider>();
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(l.airFootprintTitle, 
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      body: ep.loading && ep.todayScore == null 
        ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
        : _buildContent(context, ep, l),
    );
  }

  Widget _buildContent(BuildContext context, ExposureProvider ep, AppLocalizations l) {
    if (ep.todayScore == null) {
      return Center(child: Text(l.airFootprintNoData));
    }

    final score = ep.todayScore!;
    
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: ep.loadDashboard,
        color: AppColors.accent,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          children: [
            // ── Main Card ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.cream2,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: AppColors.ink.withValues(alpha: 0.05), 
                    blurRadius: 20, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                children: [
                  Text(l.airFootprintHealthScore, 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, 
                      letterSpacing: 1.2, color: AppColors.ink3)),
                  const SizedBox(height: 16),
                  
                  // Grade circle
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _gradeColor(score.grade).withValues(alpha: 0.2),
                      border: Border.all(color: _gradeColor(score.grade), width: 4),
                    ),
                    child: Center(
                      child: Text(score.grade,
                        style: TextStyle(fontSize: 42, fontWeight: FontWeight.w800, 
                          color: _gradeColor(score.grade), fontFamily: 'DMMono')),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Text('${score.healthScore} / 100',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, 
                      color: AppColors.ink)),
                  const SizedBox(height: 24),
                  
                  // Equivalent cigarette
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Text('🚬', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.airFootprintCigarettes(score.cigaretteEquivalent.toStringAsFixed(1)),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, 
                                  color: AppColors.ink)),
                              Text(l.airFootprintCigaretteDesc,
                                style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Temps dehors
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Text('📍', style: TextStyle(fontSize: 24)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.airFootprintOutdoorTime((score.totalOutdoorTime.inMinutes / 60).toStringAsFixed(1)),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, 
                                  color: AppColors.ink)),
                              Text(l.airFootprintAvgAqiSubi(score.avgAqi),
                                style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // ── Historique 7 jours ─────────────────────────────────────────
            Text(l.airFootprintLast7Days, 
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, 
                letterSpacing: 1.2, color: AppColors.ink3)),
            const SizedBox(height: 16),
            
            Container(
              height: 120,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.cream2,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ep.history.take(7).toList().reversed.map((s) => _buildBar(s)).toList(),
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Color _gradeColor(String grade) {
    if (grade.startsWith('A')) return AppColors.aqiGreen;
    if (grade == 'B') return AppColors.aqiYellow;
    if (grade == 'C') return AppColors.aqiOrange;
    if (grade == 'D') return AppColors.aqiRed;
    return AppColors.aqiPurple;
  }

  Widget _buildBar(DailyScore s) {
    final heightRatio = (s.healthScore / 100.0).clamp(0.1, 1.0);
    // On veut montrer le "mauvais" score comme grand ? Non, un score haut (100) est bon = barre grande.
    // L'historique des requêtes prévoyait une barre pour l'exposition. 
    // Faisons la barre basée sur l'exposition : max 1000 ? 
    // Ou inversément, la barre montre le score santé.
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 24,
          height: 60 * heightRatio, // max 60px
          decoration: BoxDecoration(
            color: _gradeColor(s.grade).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(_shortDayName(s.date), 
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.ink3)),
      ],
    );
  }

  String _shortDayName(DateTime d) {
    const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return days[d.weekday - 1];
  }
}

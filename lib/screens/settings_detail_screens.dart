// lib/screens/settings_detail_screens.dart
// Pages de contenu réelles pour les sections Settings cliquables.
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../l10n/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page : Type d'activité
// ─────────────────────────────────────────────────────────────────────────────
class ActivityTypeScreen extends StatelessWidget {
  const ActivityTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _DetailPage(
      title: l.settingsActivityType,
      sections: [
        _Section('🚴 ${l.profileCyclistLabel}', [
          l.actCycItem1,
          l.actCycItem2,
          l.actCycItem3,
        ]),
        _Section('🏃 ${l.profileAthleteLabel}', [
          l.actAthItem1,
          l.actAthItem2,
          l.actAthItem3,
        ]),
        _Section('👤 ${l.profileNormalLabel}', [
          l.actNorItem1,
          l.actNorItem2,
          l.actNorItem3,
        ]),
        _Section('👧 ${l.profileChildLabel}', [
          l.actChiItem1,
          l.actChiItem2,
          l.actChiItem3,
        ]),
        _Section('👴 ${l.profileElderlyLabel}', [
          l.actEldItem1,
          l.actEldItem2,
          l.actEldItem3,
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page : Sensibilité respiratoire
// ─────────────────────────────────────────────────────────────────────────────
class RespSensitivityScreen extends StatelessWidget {
  const RespSensitivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _DetailPage(
      title: l.settingsRespSensitivity,
      sections: [
        _Section(l.respAsthma, [
          l.respAsthma1,
          l.respAsthma2,
          l.respAsthma3,
        ]),
        _Section(l.respRhinitis, [
          l.respRhinitis1,
          l.respRhinitis2,
          l.respRhinitis3,
        ]),
        _Section(l.respCardio, [
          l.respCardio1,
          l.respCardio2,
          l.respCardio3,
        ]),
        _Section(l.respCopd, [
          l.respCopd1,
          l.respCopd2,
          l.respCopd3,
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page : Conditions médicales
// ─────────────────────────────────────────────────────────────────────────────
class MedicalConditionsScreen extends StatelessWidget {
  const MedicalConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _DetailPage(
      title: l.settingsMedical,
      sections: [
        _Section(l.medAdapt, [
          l.medAdapt1,
          l.medAdapt2,
          l.medAdapt3,
        ]),
        _Section(l.medImportant, [
          l.medImportant1,
          l.medImportant2,
          l.medImportant3,
        ]),
        _Section(l.medSources, [
          l.medSources1,
          l.medSources2,
          l.medSources3,
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page : Méthodologie
// ─────────────────────────────────────────────────────────────────────────────
class MethodologyScreen extends StatelessWidget {
  const MethodologyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _DetailPage(
      title: l.settingsMethodology,
      sections: [
        _Section(l.methCalc, [
          l.methCalc1,
          l.methCalc2,
          l.methCalc3,
        ]),
        _Section(l.methWho, [
          l.methWho1,
          l.methWho2,
          l.methWho3,
          l.methWho4,
        ]),
        _Section(l.methData, [
          l.methData1,
          l.methData2,
          l.methData3,
        ]),
        _Section(l.methForecast, [
          l.methForecast1,
          l.methForecast2,
          l.methForecast3,
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page : Politique de confidentialité
// ─────────────────────────────────────────────────────────────────────────────
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _DetailPage(
      title: l.settingsPrivacy,
      sections: [
        _Section(l.privLoc, [
          l.privLoc1,
          l.privLoc2,
          l.privLoc3,
        ]),
        _Section(l.privLocal, [
          l.privLocal1,
          l.privLocal2,
          l.privLocal3,
          l.privLocal4,
        ]),
        _Section(l.privApi, [
          l.privApi1,
          l.privApi2,
          l.privApi3,
        ]),
        _Section(l.privNo, [
          l.privNo1,
          l.privNo2,
          l.privNo3,
          l.privNo4,
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget générique pour les pages de détail
// ─────────────────────────────────────────────────────────────────────────────
class _Section {
  final String title;
  final List<String> items;
  const _Section(this.title, this.items);
}

class _DetailPage extends StatelessWidget {
  final String title;
  final List<_Section> sections;
  const _DetailPage({required this.title, required this.sections, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                color: AppColors.ink)),
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 20, color: AppColors.ink)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        itemCount: sections.length,
        itemBuilder: (_, i) {
          final s = sections[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre de section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Text(s.title,
                      style: const TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w700, color: AppColors.ink)),
                ),
                // Items
                ...s.items.map((item) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('·  ',
                          style: TextStyle(fontSize: 13, color: AppColors.ink3,
                              fontWeight: FontWeight.w700)),
                      Expanded(
                        child: Text(item,
                            style: const TextStyle(fontSize: 13,
                                color: AppColors.ink2, height: 1.5)),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}

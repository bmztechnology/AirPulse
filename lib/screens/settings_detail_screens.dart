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
          'Cyclisme urbain, VTT, cyclisme sur route.',
          'Exposition prolongée aux polluants routiers (NOx, PM2.5).',
          'Seuils de recommandation ajustés : alerte dès AQI 50.',
        ]),
        _Section('🏃 ${l.profileAthleteLabel}', [
          'Course à pied, sports intensifs en extérieur.',
          'Ventilation pulmonaire élevée = absorption accrue des polluants.',
          'Alerte dès AQI 50, déconseillé au-dessus de 80.',
        ]),
        _Section('👤 ${l.profileNormalLabel}', [
          'Activités quotidiennes normales.',
          'Sensibilité standard aux polluants.',
          'Alerte à partir de AQI 100.',
        ]),
        _Section('👧 ${l.profileChildLabel}', [
          'Enfants et adolescents de moins de 18 ans.',
          'Poumons en développement, plus vulnérables.',
          'Alerte dès AQI 40.',
        ]),
        _Section('👴 ${l.profileElderlyLabel}', [
          'Personnes de 65 ans et plus.',
          'Risques cardiovasculaires et respiratoires accrus.',
          'Alerte dès AQI 45.',
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
        _Section('🫁 Asthme', [
          'Les PM2.5, NO2 et O3 peuvent déclencher des crises.',
          'Gardez votre bronchodilatateur à portée en cas d\'AQI > 50.',
          'Évitez toute activité extérieure intense si AQI > 75.',
        ]),
        _Section('🤧 Rhinite allergique', [
          'Aggravée par les particules fines et le pollen.',
          'Consultez le niveau de pollen combiné à l\'AQI.',
          'Portez un masque FFP1 lors des pics polliniques.',
        ]),
        _Section('❤️ Maladies cardiovasculaires', [
          'PM2.5 et NO2 augmentent le risque d\'événements cardiaques.',
          'Réduisez les activités extérieures si AQI > 70.',
          'Consultez votre médecin pour adapter vos seuils personnels.',
        ]),
        _Section('🌬️ BPCO', [
          'Bronchopneumopathie chronique obstructive.',
          'Particulièrement sensible à l\'ozone et aux PM10.',
          'Restez en intérieur si AQI > 50.',
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
        _Section('💊 Comment AirPulse adapte les recommandations', [
          'Le profil de santé sélectionné ajuste les seuils d\'alerte.',
          'Les conseils affichés sur l\'écran d\'accueil sont personnalisés.',
          'Les notifications peuvent être configurées selon votre profil.',
        ]),
        _Section('⚠️ Important', [
          'AirPulse n\'est pas un dispositif médical.',
          'Les recommandations sont indicatives et ne remplacent pas l\'avis d\'un professionnel de santé.',
          'En cas de symptômes, consultez votre médecin.',
        ]),
        _Section('📊 Sources des seuils', [
          'Organisation Mondiale de la Santé (OMS) 2021.',
          'Agence de Protection Environnementale US (EPA).',
          'European Environment Agency (EEA).',
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
        _Section('📐 Calcul de l\'AQI', [
          'AirPulse utilise la formule AQI de l\'EPA américaine.',
          'L\'AQI est calculé à partir de 6 polluants : PM2.5, PM10, NO2, O3, SO2, CO.',
          'Le polluant avec l\'AQI le plus élevé détermine l\'AQI global.',
        ]),
        _Section('🌍 Seuils OMS 2021', [
          'PM2.5 : 15 μg/m³ (moyenne 24h)',
          'PM10 : 45 μg/m³ (moyenne 24h)',
          'NO2 : 25 μg/m³ (moyenne 24h)',
          'O3 : 100 μg/m³ (moyenne 8h)',
        ]),
        _Section('📡 Sources de données', [
          'WAQI / AQICN : 11 000+ stations temps réel mondiales.',
          'Open-Meteo : prévisions météo et qualité de l\'air sans clé API.',
          'Les données sont rafraîchies à chaque actualisation manuelle.',
        ]),
        _Section('🔮 Prévisions PM2.5', [
          'Modèle Open-Meteo CAMS (Copernicus Atmosphere Monitoring Service).',
          'Résolution horaire, fenêtre de 24h centrée sur maintenant.',
          'Conversion PM2.5 → AQI selon les breakpoints EPA officiels.',
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
        _Section('📍 Données de localisation', [
          'Votre position GPS est utilisée uniquement pour récupérer les données de qualité de l\'air.',
          'Les coordonnées ne sont jamais stockées ni transmises à des tiers.',
          'La position est demandée à chaque actualisation et n\'est pas conservée.',
        ]),
        _Section('💾 Données stockées localement', [
          'Préférences de langue, profil santé, seuil personnel.',
          'Paramètres de sources de données et alertes.',
          'Historique des alertes déclenchées (50 dernières).',
          'Toutes les données restent sur votre appareil.',
        ]),
        _Section('🌐 Données transmises aux API', [
          'Coordonnées GPS envoyées à WAQI/AQICN pour obtenir les données AQI.',
          'Coordonnées GPS envoyées à Open-Meteo pour la météo et les prévisions.',
          'Aucune donnée personnelle identifiante n\'est transmise.',
        ]),
        _Section('🚫 Ce que nous ne faisons pas', [
          'Pas de compte utilisateur ni d\'inscription.',
          'Pas de collecte d\'identifiants d\'appareil.',
          'Pas de publicité ni de traceurs analytiques.',
          'Pas de vente de données à des tiers.',
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

// lib/services/ai_insight_service.dart
// Groq API — LLaMA 3.3 70B — analyse IA personnalisée qualité de l'air
// Clé API : https://console.groq.com (gratuit, 14400 req/jour)
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/air_quality_model.dart';

class AiInsightService {
  static const _endpoint = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model    = 'llama-3.3-70b-versatile';

  // ── Clé API stockée statiquement — saisie dans les Settings ──────────────
  static String apiKey = '';
  static bool get hasKey => apiKey.isNotEmpty;

  // ── Cache : éviter d'appeler l'IA à chaque rebuild ────────────────────────
  static String? _cachedInsight;
  static String? _cachedContext; // fingerprint des données

  // ── Génère un fingerprint des données pour invalider le cache ─────────────
  static String _fingerprint(AirQualityData d, UserProfile p, String lang) {
    return '${d.aqi}_${d.pm25.toStringAsFixed(0)}_${d.no2.toStringAsFixed(0)}'
        '_${d.weather.tempC.toStringAsFixed(0)}_${d.pollen.total}'
        '_${p.name}_$lang';
  }

  // ── Construit le prompt selon la langue et le profil ─────────────────────
  static String _buildPrompt(
    AirQualityData d,
    UserProfile profile,
    String lang,
    List<Map<String, dynamic>> history,
  ) {
    // Description du profil
    final profileDesc = switch (profile) {
      UserProfile.cyclist  => lang == 'fr' ? 'cycliste urbain' : lang == 'ar' ? 'دراج حضري' : lang == 'es' ? 'ciclista urbano' : lang == 'de' ? 'Stadtradfahrer' : 'urban cyclist',
      UserProfile.athlete  => lang == 'fr' ? 'sportif (course à pied, sport intensif)' : lang == 'ar' ? 'رياضي' : lang == 'es' ? 'deportista' : lang == 'de' ? 'Sportler' : 'athlete (running, intense sport)',
      UserProfile.sick     => lang == 'fr' ? 'personne avec pathologie respiratoire (asthme, BPCO)' : lang == 'ar' ? 'شخص مصاب بأمراض تنفسية' : lang == 'es' ? 'persona con patología respiratoria' : lang == 'de' ? 'Person mit Atemwegserkrankung' : 'person with respiratory condition (asthma, COPD)',
      UserProfile.normal   => lang == 'fr' ? 'adulte en bonne santé' : lang == 'ar' ? 'بالغ بصحة جيدة' : lang == 'es' ? 'adulto sano' : lang == 'de' ? 'gesunder Erwachsener' : 'healthy adult',
      UserProfile.child    => lang == 'fr' ? 'enfant ou adolescent' : lang == 'ar' ? 'طفل أو مراهق' : lang == 'es' ? 'niño o adolescente' : lang == 'de' ? 'Kind oder Jugendlicher' : 'child or teenager',
      UserProfile.elderly  => lang == 'fr' ? 'senior (65+ ans, risque cardiovasculaire)' : lang == 'ar' ? 'كبير السن (65+)' : lang == 'es' ? 'persona mayor (65+)' : lang == 'de' ? 'Senior (65+, kardiovaskuläres Risiko)' : 'senior (65+, cardiovascular risk)',
    };

    // AQI prévu dans 2h et 4h
    final fc2h = d.forecast.where((f) =>
        f.time.difference(DateTime.now()).inMinutes.abs() < 35 + 120).toList();
    final fc4h = d.forecast.where((f) =>
        f.time.difference(DateTime.now().add(const Duration(hours: 4))).inMinutes.abs() < 35).toList();
    final aqi2h = fc2h.isNotEmpty ? fc2h.last.aqi : d.aqi;
    final aqi4h = fc4h.isNotEmpty ? fc4h.last.aqi : d.aqi;

    // Historique 24h
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final recent = history.where((e) {
      final t = DateTime.tryParse(e['time'] as String? ?? '');
      return t != null && t.isAfter(cutoff);
    }).toList();
    final avgLast24h = recent.isEmpty ? d.aqi :
        recent.map((e) => (e['aqi'] as num? ?? d.aqi).toInt())
            .reduce((a, b) => a + b) ~/ recent.length;

    final now = DateTime.now();
    final hour = now.hour;

    // Langue du conseil
    final langInstruct = switch (lang) {
      'fr' => 'Réponds en français.',
      'es' => 'Responde en español.',
      'de' => 'Antworte auf Deutsch.',
      'it' => 'Rispondi in italiano.',
      'pt' => 'Responde em português.',
      'ar' => 'أجب باللغة العربية.',
      'zh' => '请用中文回答。',
      'ja' => '日本語で答えてください。',
      _    => 'Answer in English.',
    };

    return '''You are a precision air quality health advisor. Give a SHORT, ACTIONABLE analysis.

Profile: $profileDesc
Time: ${hour}h, Location: ${d.stationName}
AQI now: ${d.aqi} (PM2.5: ${d.pm25.toStringAsFixed(1)}μg/m³, NO2: ${d.no2.toStringAsFixed(0)}μg/m³, O3: ${d.o3.toStringAsFixed(0)}μg/m³)
Forecast: +2h AQI $aqi2h, +4h AQI $aqi4h
Weather: ${d.weather.tempC.toStringAsFixed(0)}°C, wind ${d.weather.windKmh.toStringAsFixed(0)}km/h ${d.weather.windDir}, humidity ${d.weather.humidity}%, UV ${d.weather.uvIndex}
Pollen: grasses ${d.pollen.grass}/5, trees ${d.pollen.trees}/5, molds ${d.pollen.molds}/5
Average AQI last 24h: $avgLast24h

Rules:
- MAX 3 sentences. No markdown. No lists. No title.
- Be SPECIFIC: mention exact values, best/worst hours.
- Give ONE concrete recommendation based on the profile.
- $langInstruct''';
  }

  // ── Appel Groq API ────────────────────────────────────────────────────────
  static Future<String?> getInsight({
    required AirQualityData data,
    required UserProfile profile,
    required String lang,
    required List<Map<String, dynamic>> history,
  }) async {
    if (!hasKey) return null;

    // Cache : ne pas rappeler si les données n'ont pas changé
    final fp = _fingerprint(data, profile, lang);
    if (fp == _cachedContext && _cachedInsight != null) return _cachedInsight;

    try {
      final prompt = _buildPrompt(data, profile, lang, history);
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 180,
          'temperature': 0.4,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final content = json['choices']?[0]?['message']?['content'] as String?;
        if (content != null && content.isNotEmpty) {
          _cachedInsight = content.trim();
          _cachedContext = fp;
          return _cachedInsight;
        }
      } else {
        debugPrint('AirPulse AI: HTTP ${resp.statusCode} — ${resp.body.substring(0, 100)}');
      }
    } catch (e) {
      debugPrint('AirPulse AI: $e');
    }
    return null;
  }

  // ── Conseil court pour popup carte ────────────────────────────────────────
  static Future<String?> getMapAdvice({
    required int aqi,
    required UserProfile profile,
    required String stationName,
    required String lang,
  }) async {
    if (!hasKey) return null;
    try {
      final langInstruct = switch (lang) {
        'fr' => 'En français.',  'es' => 'En español.',
        'de' => 'Auf Deutsch.',  'ar' => 'باللغة العربية.',
        'zh' => '用中文。',       'ja' => '日本語で。',
        _    => 'In English.',
      };
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _model,
          'messages': [{'role': 'user', 'content':
            'AQI $aqi at $stationName. Profile: ${profile.name}. '
            'One sentence advice (max 15 words). No markdown. $langInstruct'
          }],
          'max_tokens': 60,
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        return (json['choices']?[0]?['message']?['content'] as String?)?.trim();
      }
    } catch (e) { debugPrint('AirPulse AI map: $e'); }
    return null;
  }

  // ── Message push intelligent ──────────────────────────────────────────────
  static Future<({String title, String body})?> getNotifContent({
    required int aqi,
    required UserProfile profile,
    required String stationName,
    required String lang,
  }) async {
    if (!hasKey) return null;
    try {
      final langInstruct = switch (lang) {
        'fr' => 'En français.', 'es' => 'En español.', 'de' => 'Auf Deutsch.',
        'ar' => 'باللغة العربية.', 'zh' => '用中文。', 'ja' => '日本語で。',
        _ => 'In English.',
      };
      final resp = await http.post(
        Uri.parse(_endpoint),
        headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': _model,
          'messages': [{'role': 'user', 'content':
            'Write a push notification for AQI $aqi at $stationName, profile ${profile.name}. '
            'Format: TITLE|BODY (max 8 words title, max 12 words body). No markdown. $langInstruct'
          }],
          'max_tokens': 80,
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        final content = (json['choices']?[0]?['message']?['content'] as String?)?.trim() ?? '';
        final parts = content.split('|');
        if (parts.length >= 2) {
          return (title: parts[0].trim(), body: parts[1].trim());
        }
      }
    } catch (e) { debugPrint('AirPulse AI notif: $e'); }
    return null;
  }
}

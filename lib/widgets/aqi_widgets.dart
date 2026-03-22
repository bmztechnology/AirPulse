// lib/widgets/aqi_widgets.dart
import 'package:flutter/material.dart';
import '../models/air_quality_model.dart';
import '../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AQI Badge
// ─────────────────────────────────────────────────────────────────────────────
class AqiBadge extends StatelessWidget {
  final int aqi;
  final double fontSize;
  const AqiBadge({super.key, required this.aqi, this.fontSize = 12});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: aqiBgColor(aqi),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        'AQI $aqi',
        style: TextStyle(
          color: aqiColor(aqi),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          fontFamily: 'DMSans',
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AQI Gauge
// ─────────────────────────────────────────────────────────────────────────────
class AqiGauge extends StatelessWidget {
  final int aqi;
  const AqiGauge({super.key, required this.aqi});

  @override
  Widget build(BuildContext context) {
    final segments = [
      (color: AppColors.aqiGreen,  label: '0–50'),
      (color: AppColors.aqiYellow, label: '51–100'),
      (color: AppColors.aqiOrange, label: '101–150'),
      (color: AppColors.aqiRed,    label: '151–200'),
      (color: AppColors.aqiPurple, label: '201–300'),
      (color: AppColors.aqiMaroon, label: '300+'),
    ];
    // pointer position: 0–1
    final position = (aqi / 300).clamp(0.0, 1.0);

    return Column(
      children: [
        // FIX-MAJOR-02: LayoutBuilder replaces MediaQuery to get actual rendered width,
        // preventing wrong pointer position on tablets, foldables, or padded containers.
        LayoutBuilder(
          builder: (context, constraints) {
            final gaugeWidth = constraints.maxWidth;
            return Stack(
              children: [
                Row(
                  children: segments.map((s) => Expanded(
                    child: Container(
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: s.color.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )).toList(),
                ),
                Positioned(
                  left: (position * gaugeWidth - 6).clamp(0.0, gaugeWidth - 12),
                  top: 0,
                  child: Container(
                    width: 12,
                    height: 8,
                    decoration: BoxDecoration(
                      color: aqiColor(aqi),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [BoxShadow(color: aqiColor(aqi).withValues(alpha: 0.4), blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: segments.map((s) => Text(
            s.label,
            style: const TextStyle(fontSize: 8, color: AppColors.ink3, fontWeight: FontWeight.w600),
          )).toList(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pollutant card (grid item)
// ─────────────────────────────────────────────────────────────────────────────
class PollutantCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final int aqi;
  final VoidCallback? onTap;
  const PollutantCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.aqi,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = aqiColor(aqi);
    final bg = aqiBgColor(aqi);
    return Semantics(
      button: onTap != null,
      label: '$label: $value $unit',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.ink3, letterSpacing: 0.6)),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, fontFamily: 'DMMono')),
                  const SizedBox(width: 3),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(unit, style: const TextStyle(fontSize: 9, color: AppColors.ink3, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (aqi / 200).clamp(0.0, 1.0),
                  backgroundColor: bg,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 4,
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
// Section header
// ─────────────────────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings row
// ─────────────────────────────────────────────────────────────────────────────
class SettingsRow extends StatelessWidget {
  final String icon;
  final String label;
  final String? desc;
  final Widget? trailing;
  final VoidCallback? onTap;
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.desc,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  if (desc != null)
                    Text(desc!, style: const TextStyle(fontSize: 11, color: AppColors.ink3)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile tab chip
// ─────────────────────────────────────────────────────────────────────────────
class ProfileChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ProfileChip({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.cream2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.ink : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.cream : AppColors.ink2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Insight card
// ─────────────────────────────────────────────────────────────────────────────
class InsightCard extends StatelessWidget {
  final String icon;
  final String title;
  final String text;
  const InsightCard({super.key, required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(fontSize: 12, color: AppColors.ink3, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

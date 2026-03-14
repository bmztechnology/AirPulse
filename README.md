# AirPulse — Flutter Application

Air quality monitor for cyclists, athletes, and sensitive users.

## Architecture

```
lib/
├── main.dart                    # Entry point, navigation shell
├── l10n/                        # ARB translation files (9 languages)
│   ├── app_en.arb               # English (template)
│   ├── app_fr.arb               # Français
│   ├── app_es.arb               # Español
│   ├── app_de.arb               # Deutsch
│   ├── app_it.arb               # Italiano
│   ├── app_pt.arb               # Português
│   ├── app_ar.arb               # العربية (RTL)
│   ├── app_zh.arb               # 中文
│   └── app_ja.arb               # 日本語
├── models/
│   └── air_quality_model.dart   # AQI, Station, Weather, Pollen data models
├── providers/
│   └── app_provider.dart        # Central state (Provider pattern)
├── theme/
│   └── app_theme.dart           # Colors, typography, AQI color helpers
├── screens/
│   ├── home_screen.dart         # Main AQI dashboard
│   ├── details_screen.dart      # Charts, full pollutant data, weather
│   ├── map_screen.dart          # OpenStreetMap via flutter_map
│   ├── alerts_screen.dart       # Alert history and toggle settings
│   └── settings_screen.dart     # Profile, language picker, preferences
└── widgets/
    └── aqi_widgets.dart         # Shared components (badge, gauge, cards)
```

## Setup

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Generate localization files
```bash
flutter gen-l10n
```
This generates `lib/l10n/app_localizations.dart` from the ARB files.

### 3. Add fonts
Download DM Sans and DM Mono from Google Fonts and place them in:
```
assets/fonts/
├── DMSans-Regular.ttf
├── DMSans-Medium.ttf
├── DMSans-SemiBold.ttf
├── DMSans-Bold.ttf
├── DMMono-Regular.ttf
└── DMMono-Medium.ttf
```

### 4. Run
```bash
flutter run
```

## Language system

Language is **detected automatically** from the device locale at startup via `localeResolutionCallback` in `MaterialApp`. If the device language is not among the 9 supported ones, the app defaults to **English**.

The user can manually override the language at any time via **Settings → Display → Language**. The choice is persisted in `SharedPreferences`.

Supported locales: `fr`, `en`, `es`, `de`, `it`, `pt`, `ar` (RTL), `zh`, `ja`.

## Key packages

| Package | Usage |
|---|---|
| `provider` | State management |
| `flutter_map` | OpenStreetMap rendering |
| `latlong2` | Map coordinates |
| `fl_chart` | PM2.5 24h line chart |
| `shared_preferences` | Persist language, profile, settings |
| `share_plus` | Native share sheet |
| `geolocator` | Device GPS (to replace mock data) |
| `http` / `dio` | API calls (WAQI, Open-Meteo) |
| `flutter_local_notifications` | Background AQI alerts |

## API integration (production)

Replace the mock data in `AppProvider.refreshLocation()` with real API calls:

```dart
// WAQI (free, 1000 req/day)
GET https://api.waqi.info/feed/here/?token=YOUR_TOKEN

// Open-Meteo (free, no key)
GET https://air-quality-api.open-meteo.com/v1/air-quality
    ?latitude=48.856&longitude=2.352
    &hourly=pm2_5,nitrogen_dioxide,ozone
```

## Screens

| Screen | Tab | Description |
|---|---|---|
| Home | 🏠 | AQI gauge, profile selector, pollutant grid, 24h forecast |
| Data | 📊 | PM2.5 chart (fl_chart), full pollutant table, weather, pollen |
| Map | 🗺️ | flutter_map + CARTO tiles, AQI markers, pollution halos |
| Alerts | 🔔 | Alert history, configurable notification toggles |
| Settings | ⚙️ | Health profile, language picker, dark mode, AQI threshold |

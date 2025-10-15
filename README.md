# MCQ Quizzer

MCQ Quizzer is a Flutter app to create, run and review multiple-choice quizzes (MCQs). It supports parsing question banks (PDF/DOCX), saving progress, per-question notes, and result analytics. This repository contains Android, iOS, web, macOS, Linux and Windows configurations.

## Features
- Import quizzes from PDF/DOCX and parse questions and answer keys
- Per-question notes and save/resume progress
- Show correct answers and explanations
- Dark mode and user preferences
- Cross-platform: Android, iOS, Web, macOS, Windows, Linux

## Quick start

Prerequisites:
- Flutter SDK (3.8+ recommended)
- Dart SDK (bundled with Flutter)
- Optional: ImageMagick (for icon generation)

Install dependencies:

```bash
flutter pub get
```

Run on a connected device or emulator:

```bash
flutter run
```

Build an APK:

```bash
flutter build apk --release
```

## App icons and branding
This repository includes generated app icons (created via `flutter_launcher_icons`). To regenerate icons use:

```bash
flutter pub run flutter_launcher_icons:main
```

If you are updating the source icon, place a 1024×1024 PNG with transparency at `assets/icons/icon.png`.

## Development notes
- Main app code lives under `lib/` (screens, providers, services, models).
- Parsing logic: `lib/services/parsing_service.dart`.
- Database helpers: `lib/services/database_service.dart`.

## Contributing
Fork the repo, create feature branches from `develop` and open pull requests against `develop`.

## License
This project is currently unlicensed. Add a LICENSE file if you want to open-source it.

## Contact
If you need help, open an issue or contact the maintainer.

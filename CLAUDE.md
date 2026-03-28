# CLAUDE.md — cockado-enrollapp

## Project Overview

**COC-CHECKIN** — offline-first mobile attendance and registration app for the Church of Christ.
Built with Flutter (Dart). Targets Android & iOS, with tablet-specific UI (Touch/fingerprint tab).

## Skills & Tools

- **Flutter development**: Always use the `flutter-development` skill for any Flutter/Dart code work.
- **UI design**: Always use the `frontend-design` and `ui-designer` skills for any interface design work.
- **No assumptions**: Always use the Ask tool to clarify ambiguities before proceeding.

## Tech Stack

| Area | Library |
|---|---|
| State management | `flutter_riverpod` + `riverpod_annotation` (code-gen) |
| Navigation | `go_router` |
| Local DB | `drift` + `sqlcipher_flutter_libs` (encrypted SQLite) |
| Secure storage | `flutter_secure_storage` (DB key + JWT) |
| Camera / QR scan | `camera` + `mobile_scanner` |
| Face detection | `google_mlkit_face_detection` |
| Face recognition | `tflite_flutter` (MobileFaceNet model) |
| HTTP | (see pubspec) |
| Fonts | Inter (400/500/600/700) |
| Utils | `uuid`, `intl`, `equatable`, `rxdart` |

## Project Structure

```
lib/
  main.dart
  core/
    db/          # Drift database + DAOs
    models/      # Core data models
    network/     # HTTP client / sync
    router/      # go_router configuration
    services/    # Business logic services
    theme/       # App theme (colors, text styles)
    utils/       # Core utilities
  features/
    auth/        # Login, session
    enrolment/   # New enrolment form
    init/        # Initialisation / sync screen
    scan/        # Ticket scan, face capture, touch/fingerprint
    settings/    # Settings screen
    standby/     # Standby / inactivity screen
  shared/
    utils/       # Shared utilities
    widgets/     # Reusable widgets
```

## Design System

- **Background**: `#0A1628` (dark navy)
- **Accent**: `#2563EB` (blue)
- **Card fill**: `#0F2236`
- **Muted text / labels**: `#4A6A8A`
- **Dividers**: `#1A3A5C`
- **Font**: Inter — uppercase labels with letter-spacing 1.5
- **Target screen**: 390×844px (phone), tablet-compatible
- State colors: blue = idle/scanning, green = success, red = error

## App Screens

| Screen | Feature folder |
|---|---|
| Splash | `core/router` or `init` |
| Login | `auth` |
| Initialisation / Sync | `init` |
| Ticket Scan | `scan` |
| Face Capture | `scan` |
| Touch / Fingerprint | `scan` (tablet-only) |
| Standby | `standby` |
| New Enrolment | `enrolment` |
| Settings | `settings` |

## Key Behaviors

- **Offline-first**: All data stored locally in encrypted SQLite (drift + SQLCipher). Sync when online.
- **Auto-capture**: Stays on scan screen after each capture; shows toast + audio beep.
- **Standby**: Triggered on inactivity — pauses camera stream. Double-tap to wake.
- **Touch tab**: Only active/visible on tablet form factor.
- **Footer**: Always shows `AUTO-CAPTURE: ON | v{version}`.

## Code Generation

Run after modifying Drift DAOs, Riverpod providers, or JSON models:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Rules

1. **Ask before assuming** — use the Ask tool whenever requirements are unclear.
2. **UI/UX work** — always use the `frontend-design` and `ui-designer` skills.
3. **Flutter code** — always use the `flutter-development` skill.
4. **No over-engineering** — minimal changes, no extra abstractions or features beyond what is asked.
5. **Security** — DB key stored in `flutter_secure_storage`; never log or expose it.

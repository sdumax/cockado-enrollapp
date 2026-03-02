# Copilot Instructions for `cockado-enrollapp`

This repository hosts a Flutter application project.

## General expectations
- Prefer minimal, targeted changes.
- Follow existing project conventions before introducing new patterns.
- Keep platform-agnostic Flutter code in `lib/` unless platform-specific behavior is required.

## Flutter development workflow
- Run dependency install before build/test commands: `flutter pub get`.
- Validate formatting with: `dart format .`
- Validate static analysis with: `flutter analyze`
- Run tests with: `flutter test`

If the repository is still being scaffolded and these commands are not yet available, add or update files conservatively and avoid assumptions about missing architecture.

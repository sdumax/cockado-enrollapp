---
name: flutter-development
description: Guide for implementing and validating Flutter app changes in this repository. Use this for Flutter feature work, bug fixes, and tests.
---

Use this skill when working on Flutter app tasks.

## Goals
- Make the smallest possible change to solve the issue.
- Keep behavior stable unless the task explicitly requires behavioral changes.
- Add or update tests only when there is existing test infrastructure to support them.

## Workflow
1. Inspect existing project structure (`pubspec.yaml`, `lib/`, `test/`, platform folders) before editing.
2. Install dependencies with `flutter pub get`.
3. Implement focused changes in the most relevant files.
4. Run targeted validation first, then broader checks as needed:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`
5. If a command is unavailable because the repository is not fully scaffolded yet, report that clearly and continue with safe, minimal edits.

## Implementation guidance
- Prefer stateless/stateful widgets and architecture already present in the app.
- Avoid adding new dependencies unless absolutely necessary.
- Keep UI logic, business logic, and data access separated according to existing project conventions.

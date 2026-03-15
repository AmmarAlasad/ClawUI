# ClawUI

ClawUI is a Flutter mobile control surface for OpenClaw. This MVP focuses on a believable operator workflow: connect to a gateway, inspect health and sessions, chat through a service abstraction, review pending devices, inspect cron jobs, and tune app settings.

## MVP Scope

- Connect screen with saved gateway profile, auth mode selection, token/password inputs, and demo fallback toggle
- Dashboard with gateway health, active sessions, connected device summary, and cron overview
- Chat screen wired through a repository abstraction with a live HTTP client surface and demo fallback adapter
- Devices screen for pending approvals and trusted devices
- Cron screen for job health and schedule visibility
- Settings screen for connection management and theme mode selection
- Dark-friendly Material 3 theme with reusable cards, section headers, and metric chips

## Architecture

The app is organized under `lib/src` with a small growth-oriented structure:

- `app/`: bootstrap, top-level controller, app scope, navigation shell
- `core/`: models, repository abstractions, HTTP client surface, local profile store, theme
- `ui/`: feature screens and reusable presentation widgets

State is owned by `AppController` and exposed through `AppScope`. The UI is wired to `OpenClawRepository`, which currently supports:

- `NetworkOpenClawRepository` for reasonable placeholder REST endpoints such as `/api/mobile/dashboard`
- `DemoOpenClawRepository` for polished fallback behavior when the real API contract is incomplete or unavailable

## Run

This repo was set up in an offline-constrained environment, so only SDK-local code was added. To run locally on a normal machine:

1. Ensure Flutter stable is installed and writable.
2. Restore/generate native folders if needed:
   `flutter create . --platforms android,ios`
3. Fetch dependencies:
   `flutter pub get`
4. Run the app:
   `flutter run`

## Current Limitations

- The exact OpenClaw mobile API contract is not yet defined, so the live client uses conservative placeholder endpoints and falls back to demo data cleanly.
- The local profile store is file-backed for now. It is intentionally abstracted so it can be swapped for `shared_preferences` or secure storage later.
- In this sandbox, the Flutter SDK wrapper under `/home/asapro/develop/flutter` is not writable, so `flutter pub get`, `flutter analyze`, `flutter create`, and full builds are blocked before they can acquire the SDK cache lockfile.
- Native platform folders are still absent. On a writable machine with the Flutter SDK available, run `flutter create . --platforms android,ios` from the repo root to generate them without replacing `lib/`.

## Important Files

- `lib/src/app/claw_ui_app.dart`
- `lib/src/app/app_controller.dart`
- `lib/src/core/openclaw_repository.dart`
- `lib/src/core/profile_store.dart`
- `lib/src/core/models.dart`
- `lib/src/ui/app_shell.dart`
- `lib/src/ui/connect_screen.dart`
- `lib/src/ui/home_screen.dart`
- `.metadata`
- `test/widget_test.dart`

## Next Steps

- Generate `android/` and `ios/` once the Flutter SDK can write its cache lockfile.
- Run `flutter pub get`, `flutter analyze`, and `flutter test` in that environment.
- Replace placeholder `/api/mobile/*` routes with the real OpenClaw contract
- Move profile persistence to secure/mobile-native storage
- Add command execution, approval actions, and richer dashboard telemetry
- Add CI after native folders and dependency resolution are available

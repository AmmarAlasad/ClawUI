# ClawUI

<img width="2377" height="1536" alt="Gemini_Generated_Image_3uitew3uitew3uit" src="https://github.com/user-attachments/assets/4219ff14-0bc1-4aab-be10-340cee34f568" />


ClawUI is a Flutter client for OpenClaw Gateway.

The goal is simple: give OpenClaw a usable mobile-style control surface instead of forcing everything through terminal commands and raw HTTP calls. The app lets you connect to a gateway, save connection profiles, chat with the assistant, inspect sessions, look at devices and cron data, and surface installed skills in a way that feels like an operator console rather than a demo.

This repo is still early-stage, but it already contains the real connection model, gateway-facing repository code, secure secret storage, WebSocket support, and the main UI screens.

## What it does

ClawUI is built around the documented OpenClaw gateway surfaces.

It currently covers these kinds of flows:

- connect to an OpenClaw gateway by direct URL, host/port, or Tailscale-style hostname
- authenticate with either a token or password
- derive the correct HTTP and WebSocket endpoints from one saved profile
- send chat messages through `/v1/chat/completions`
- call operator tooling through `/tools/invoke`
- inspect sessions, devices, cron information, and skills
- keep connection secrets out of the normal profile store
- support live or near-live session behavior over WebSocket
- provide the groundwork for notifications/background behavior on mobile platforms

## Why this exists

OpenClaw is powerful, but a lot of the operator experience still assumes you are comfortable in a shell. That is fine for development, but less ideal when you want to:

- quickly check a deployment from your phone
- chat with your assistant from a cleaner UI
- inspect sessions or devices without hopping through multiple tools
- test whether a LAN/Tailscale/gateway setup is actually reachable
- have a proper client app instead of a pile of ad-hoc scripts

ClawUI is meant to close that gap.

## Current status

This is not a polished consumer app yet. It is an active project and the structure is still being refined.

What is already real:

- Flutter project scaffold
- Android platform files
- web scaffold
- connection profile model
- secure secret storage
- gateway repository layer
- WebSocket/live session plumbing
- screens for chat, devices, cron, skills, and settings

What is still evolving:

- UI polish
- deeper feature coverage
- better error handling and edge-case recovery
- broader platform testing
- production-hardening for background behavior

## Tech stack

Main choices in this project:

- **Flutter** for the client UI
- **Dart** for app logic
- **flutter_secure_storage** for secrets such as connection auth material
- **cryptography** for device identity / signing-related logic
- **flutter_chat_ui** and **flutter_chat_core** for chat rendering primitives
- **gpt_markdown** for markdown rendering in assistant output
- **flutter_local_notifications** for local notification support
- **flutter_background_service** for background execution groundwork
- **image_picker**, **file_picker**, and **mime** for attachment-related flows

## How the app is structured

The important code lives in `lib/src` and is split by responsibility.

### `lib/main.dart`

Entry point for the Flutter app.

### `lib/src/app/`

App-level wiring.

- `claw_ui_app.dart` sets up the app and high-level dependencies
- `app_controller.dart` holds the main state and orchestration logic used by the UI
- `app_scope.dart` exposes shared app state down the widget tree

This layer is where profile loading, refresh logic, secret hydration, and top-level UI state come together.

### `lib/src/core/`

The actual application logic.

Key files:

- `models.dart`
  - shared app models
  - connection profile types
  - enums and state objects used across the app
- `openclaw_repository.dart`
  - the main gateway-facing service layer
  - turns UI actions into HTTP/tool/chat calls
  - handles connection tests, overview loading, device actions, messaging, and other gateway interactions
- `profile_store.dart`
  - persistence model for saved connection profile data
- `profile_store_factory_*.dart`
  - platform-specific profile storage selection
  - separates IO and web implementations
- `connection_secret_store.dart`
  - stores token/password data in secure storage instead of the plain profile store
- `gateway_device_auth_store.dart`
  - handles device identity and device token persistence
  - includes device key material handling for gateway device auth flows
- `gateway_http_client*.dart`
  - HTTP transport abstraction and per-platform factories
- `gateway_ws_client*.dart`
  - WebSocket client abstraction and per-platform factories
- `gateway_live_session*.dart`
  - live session support built on top of the WebSocket layer
- `background_notification_service.dart`
  - background notification-related logic
- `background_service_manager.dart`
  - mobile background-service integration hooks
- `theme.dart`
  - app theme definitions

In practice, `core/` is the part that actually makes the app useful. The UI mostly sits on top of this layer.

### `lib/src/ui/`

All visible screens and shared widgets.

- `app_shell.dart`
  - main shell/navigation wrapper
- `connect_screen.dart`
  - connection profile editing and validation UI
- `home_screen.dart`
  - top-level overview screen
- `chat_screen.dart`
  - chat interface for assistant interaction
- `devices_screen.dart`
  - device-related operator actions and visibility
- `cron_screen.dart`
  - cron-related data and actions
- `skills_screen.dart`
  - skill listing / presentation UI
- `settings_screen.dart`
  - local app settings and explanatory text
- `widgets.dart`
  - shared UI building blocks

## File structure

A cleaner view of the repo:

```text
ClawUI
├── android/
│   ├── app/
│   ├── gradle/
│   ├── build.gradle.kts
│   └── settings.gradle.kts
├── lib/
│   ├── main.dart
│   └── src/
│       ├── app/
│       │   ├── app_controller.dart
│       │   ├── app_scope.dart
│       │   └── claw_ui_app.dart
│       ├── core/
│       │   ├── background_notification_service.dart
│       │   ├── background_service_manager.dart
│       │   ├── connection_secret_store.dart
│       │   ├── gateway_device_auth_store.dart
│       │   ├── gateway_http_client.dart
│       │   ├── gateway_http_client_base.dart
│       │   ├── gateway_http_client_factory_io.dart
│       │   ├── gateway_http_client_factory_stub.dart
│       │   ├── gateway_http_client_factory_web.dart
│       │   ├── gateway_live_session.dart
│       │   ├── gateway_live_session_io.dart
│       │   ├── gateway_live_session_stub.dart
│       │   ├── gateway_ws_client.dart
│       │   ├── gateway_ws_client_base.dart
│       │   ├── gateway_ws_client_factory_io.dart
│       │   ├── gateway_ws_client_factory_stub.dart
│       │   ├── models.dart
│       │   ├── openclaw_repository.dart
│       │   ├── profile_store.dart
│       │   ├── profile_store_factory_io.dart
│       │   ├── profile_store_factory_stub.dart
│       │   ├── profile_store_factory_web.dart
│       │   └── theme.dart
│       └── ui/
│           ├── app_shell.dart
│           ├── chat_screen.dart
│           ├── connect_screen.dart
│           ├── cron_screen.dart
│           ├── devices_screen.dart
│           ├── home_screen.dart
│           ├── settings_screen.dart
│           ├── skills_screen.dart
│           └── widgets.dart
├── test/
│   └── widget_test.dart
├── web/
│   ├── index.html
│   └── manifest.json
├── analysis_options.yaml
├── LICENSE
├── pubspec.lock
├── pubspec.yaml
└── README.md
```

## How the connection model works

The app does not just store one raw URL string and hope for the best.

Instead, it stores a structured `ConnectionProfile` with fields such as:

- target type
- transport security mode
- auth mode
- direct URL or host/port input
- demo mode flag

From that profile, the app derives the actual gateway surfaces it needs:

- HTTP origin
- WebSocket origin
- `/v1/chat/completions`
- `/tools/invoke`
- `/readyz`
- `/healthz`

This is important because OpenClaw deployments can vary:

- localhost setups
- LAN IPs
- Tailscale or MagicDNS names
- TLS and non-TLS environments

The code tries to normalize those into something predictable and explicit.

## How secrets are handled

There are two important ideas in this codebase:

1. **connection profile data** is not the same thing as **connection secrets**
2. **device auth material** is not the same thing as a normal saved profile

So the app separates them.

- normal profile information is stored through the profile store
- token/password secrets are stored through `flutter_secure_storage`
- device token and device identity material are stored separately as device auth data

That separation is intentional. It reduces the chance of casually dumping secrets into plain persisted app state.

## How gateway interaction works

Most gateway-facing logic is concentrated in `openclaw_repository.dart`.

That file is effectively the bridge between the UI and OpenClaw Gateway. It is responsible for things like:

- testing connectivity
- building requests from the saved profile
- calling documented HTTP endpoints
- invoking tool-style actions through `/tools/invoke`
- sending chat requests
- handling device-related flows
- pulling overview data used by the dashboard/screens

If you want to understand the app quickly, that is one of the first files worth reading.

## Platform split

This project already accounts for differences between platforms.

You will see `*_io.dart`, `*_web.dart`, and `*_stub.dart` patterns in the codebase. That is how the app switches between implementations for:

- profile storage
- HTTP transport
- WebSocket handling
- live session behavior

That setup keeps most of the app code platform-agnostic while still allowing the right backend implementation underneath.

## Running the project

Typical local setup:

```bash
flutter pub get
flutter run
```

For web:

```bash
flutter pub get
flutter run -d chrome
```

If a clone is missing platform folders, Flutter can regenerate them:

```bash
flutter create . --platforms android,ios,web
```

## Development notes

A few practical notes:

- this repo has been worked on in environments where Flutter cache writes were constrained
- depending on your machine, `flutter pub get`, `flutter analyze`, `flutter test`, or `flutter build` may fail until the SDK cache is writable
- Android and web scaffolding are present, but not every environment used for development was capable of fully building the app end-to-end

So if something fails in a sandbox, that is not automatically a source-level problem.

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE).

## Final note

This project is trying to be practical, not flashy.

The point is not to build a generic “AI app”. The point is to build a solid OpenClaw client with a clean connection model, understandable code, and enough structure that it can grow without turning into a mess.

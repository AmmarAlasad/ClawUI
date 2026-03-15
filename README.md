# ClawUI

ClawUI is a Flutter control surface for OpenClaw Gateway. This version keeps the existing app structure but replaces the old single-URL placeholder client with an explicit connection architecture built around documented gateway surfaces:

- Gateway WebSocket concept
- HTTP `POST /v1/chat/completions`
- HTTP `POST /tools/invoke`

## What Changed

- Connection profiles now support:
  - direct URL
  - host/IP + port
  - Tailscale / MagicDNS
- Auth modes are explicit and limited to:
  - token
  - password
- URL construction is normalized from one profile into:
  - HTTP base origin
  - WebSocket origin
  - `/v1/chat/completions`
  - `/tools/invoke`
  - `/readyz`
  - `/healthz`
- The network repository no longer uses placeholder `/api/mobile/*` routes.
- Dashboard/session/device/cron data now comes from documented gateway-compatible surfaces:
  - `sessions_list` via `/tools/invoke`
  - `nodes` actions via `/tools/invoke`
  - `cron` actions via `/tools/invoke`
  - chat via `/v1/chat/completions`
- Device approval buttons now call the repository instead of being dead UI.

## Connection Model

The app stores a structured `ConnectionProfile` instead of a raw URL string.

Profile fields:

- `targetKind`: `directUrl`, `hostPort`, `tailscale`
- `transportSecurity`: `tls`, `insecure`
- `authMode`: `token`, `password`
- endpoint inputs:
  - `directUrl`
  - or `host` + `port`
- secret values:
  - `token`
  - `password`
- `demoMode`

Derived surfaces:

- HTTP origin
- Gateway WebSocket origin
- chat completions endpoint
- tools endpoint
- readiness and health probes

The connect screen now shows the derived HTTP and WS endpoints before saving.

## Security Notes

This repo now prefers explicitness over convenience:

- Direct URLs are validated as origins only.
  - No embedded credentials
  - No path beyond `/`
  - No query string
  - No hash fragment
- Host/IP and Tailscale profiles are normalized into canonical HTTP and WS origins.
- Auth is never implicit.
  - The app requires either a token or a password for live profiles
- HTTP auth now matches the OpenClaw gateway behavior.
  - Token and password are both sent as `Authorization: Bearer ...`
  - Basic auth is not used
- Insecure HTTP/WS is allowed only as an explicit choice.
  - The UI warns that it should be limited to loopback or trusted tunnels
- The profile store remains abstracted so secure storage can replace the current implementation later without changing the rest of the app.

OpenClaw-specific deployment considerations reflected here:

- Non-loopback Control UI deployments should use explicit `gateway.controlUi.allowedOrigins`
- Avoid `gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback` unless you are intentionally using break-glass behavior
- Prefer HTTPS/WSS for Tailscale or MagicDNS endpoints

## Architecture

`lib/src` remains organized by responsibility:

- `app/`
  - bootstrap
  - controller
  - inherited scope
- `core/`
  - models
  - repository/router
  - gateway HTTP adapters
  - connection profile store
  - theme
- `ui/`
  - connect
  - dashboard
  - chat
  - devices
  - cron
  - settings

Notable implementation changes:

- `OpenClawRepository` now exposes:
  - `fetchOverview`
  - `testConnection`
  - `approveDevice`
  - `rejectDevice`
  - `sendMessage`
- `AppController.refresh()` now loads a single operator snapshot instead of making three unrelated placeholder calls
- Common code no longer depends directly on `dart:io` for HTTP or profile persistence
- Platform-specific profile stores and HTTP clients are selected with conditional imports

## Web Support

This repo now includes:

- conditional profile storage:
  - file-backed on IO platforms
  - `localStorage` on web
- conditional HTTP transport:
  - `HttpClient` on IO platforms
  - browser `HttpRequest` on web
- minimal `web/` scaffolding so a future Flutter web run has the expected entry files

This does not guarantee successful web builds in the current sandbox, but it removes some of the previous code-level blockers.

## Run

On a normal writable Flutter machine:

1. `flutter pub get`
2. `flutter run`

For web:

1. `flutter pub get`
2. `flutter run -d chrome`

If native folders are still missing:

1. `flutter create . --platforms android,ios,web`

That should preserve `lib/` while generating platform scaffolding.

## What Works Here

Validated in this environment:

- repository and UI refactor completed
- formatter ran successfully with the embedded Dart SDK:
  - `/home/asapro/develop/flutter/bin/cache/dart-sdk/bin/dart format lib test web`

Partially validated:

- `dart analyze` can be launched by forcing `HOME=/tmp`
- without a resolved Flutter package config, analysis reports missing Flutter packages instead of meaningful source diagnostics

Blocked here:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter run`
- `flutter build`

Reason:

- the Flutter installation at `/home/asapro/develop/flutter` cannot update its cache stamp files in this sandbox

## Important Files

- `lib/src/core/models.dart`
- `lib/src/core/openclaw_repository.dart`
- `lib/src/core/profile_store.dart`
- `lib/src/core/gateway_http_client.dart`
- `lib/src/app/app_controller.dart`
- `lib/src/ui/connect_screen.dart`
- `lib/src/ui/home_screen.dart`
- `lib/src/ui/settings_screen.dart`
- `web/index.html`
- `README.md`

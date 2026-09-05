# Fathom iOS

Native iOS browser with the Fathom proxy built in. The proxy stays server-side on
the VPS — this is just a native client (tabs, address bar, failover, native ad
blocking) instead of the web front-end.

## How it builds

GitHub Actions (`.github/workflows/build.yml`) on every push to `main`:

1. `xcodegen` generates `Fathom.xcodeproj` from `project.yml`
2. `xcodebuild archive` with code signing **off** → `Fathom.app`
3. zipped into `Payload/Fathom.app` → `Fathom-<ver>.ipa`
4. `PUT` to `https://luxarcanum.art/_deploy/...` (bearer `DEPLOY_TOKEN`), which
   drops the IPA in `public/apps/` and refreshes `public/repo.json`
5. also attached to a GitHub Release

## Install (SideStore)

Add source: `https://luxarcanum.art/repo.json` → install Fathom → SideStore signs
it on-device with your free Apple ID (7-day refresh).

## Secrets

| name | value |
|---|---|
| `DEPLOY_TOKEN` | matches `DEPLOY_TOKEN` in the VPS `.env` |

## Config

- `Sources/UV.swift` → `UV.origins` — proxy origins, tried in order on failure.
- `Sources/WebView.swift` → `Coordinator.blockJSON` — ad/tracker block list.

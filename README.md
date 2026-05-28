# EcoSwap

A Tinder-style swap app for second-hand items. Built with Flutter + Firebase.

**For developers and contributors: read [`CLAUDE.md`](./CLAUDE.md) first.** It explains the repo layout, the WBS dictionary workflow, locked decisions, and CI/CD setup.

**For the full plan: see [`docs/EcoSwap_Planning_Package_v1_2.docx`](./docs/EcoSwap_Planning_Package_v1_2.docx).**

## Quick start

(Setup steps to be filled in as part of WBS 13.1 — for now, see CLAUDE.md.)

## DEV-MODE paste-token fallback (WBS 10.5)

The QR Scan screen includes a debug-only paste field that lets you submit a JWT
manually, bypassing the camera. This is useful when testing on an emulator or a
single device where a phone-to-phone QR scan is not possible.

### Enabling DEV-MODE

Pass the build flag at run time:

```
flutter run --dart-define=DEV_MODE=true
```

When enabled, a text field labelled "Or paste code…" and a **Submit** button
appear below the camera viewfinder on the Scan screen. Paste a valid JWT there
and tap Submit — the token is validated by the same Cloud Function path as a
real camera scan.

### Release builds

DEV-MODE is **disabled by default**. Omitting `--dart-define=DEV_MODE=true` or
building with `--release` produces a binary with no trace of the paste field.
The CI `build-apk` job explicitly passes `--dart-define=DEV_MODE=false` to
ensure the artefact shipped to teammates never includes the debug path.
# Claude Code Workflow — EcoSwap

This file tells Claude Code (and any AI coding assistant) how to work in this repo.

---

## What this repo contains

- `lib/` — Flutter app source (Dart)
- `functions/` — Firebase Cloud Functions (TypeScript)
- `prototype/` — Claude Design React+JSX prototype. **This is the visual and structural spec, not code to port.**
- `docs/`
  - `EcoSwap_WBS_Dictionary.md` — the implementation contract. One entry per leaf task.
  - `EcoSwap_Style_Guide.md` — design tokens (colours, typography, spacing).
  - `EcoSwap_Planning_Package_v1_2.docx` — sprint plan, data model, architecture, WBS.
  - `personas.md`, `journey_*.png`, `wireframes/` — UX artefacts
- `integration_test/` — end-to-end tests against the Firebase Emulator
- `.claude/agents/` — subagent definitions (Flutter implementer, Cloud Function implementer)
- `.github/workflows/` — CI/CD pipeline

---

## Workflow for any task

Tasks are identified by their WBS code (e.g., `7.3`, `10.6`). For every task:

1. **Open `docs/EcoSwap_WBS_Dictionary.md` and locate the entry.** Use the WBS code as a search anchor (e.g., `### 7.3`).
2. **Read the entry top to bottom.** Pay particular attention to:
   - **Scope** — what you're building and why
   - **Acceptance** — the bar for done
   - **Schema** / **Pseudocode** blocks — locked decisions, do not re-litigate
   - **Testing** — what tests to write alongside the code
3. **Open the file(s) listed in the entry's "Prototype Reference" row.** These live in `prototype/src/screens/` and define the visual layout, component composition, copy, and micro-interactions. **Treat the JSX as a spec, not code to port line-for-line** — re-implement the same structure in Flutter widgets.
4. **Read `docs/EcoSwap_Style_Guide.md`** for design tokens before writing UI code. Colours, typography sizes, spacing scale, and component variants are defined there.
5. **Always re-read WBS 3.6** (the Firestore data model) if your task touches Firestore in any way. Prevents schema drift.
6. **Implement in Flutter** (or TypeScript for Cloud Functions tasks). Place files at the paths listed in the entry's Deliverables section.
7. **Write the tests listed in the entry's Testing section.** Tests live in the same task — do not defer them to Phase 12.
8. **Run lint and tests locally before committing.** `flutter analyze && flutter test` for Flutter; `cd functions && npm run build && npm test` for Cloud Functions. CI will run the same checks on push — passing locally first saves a round-trip.

---

## Subagent dispatch

Two subagents are defined in `.claude/agents/`:

- **`flutter-task-implementer`** — implements Flutter UI tasks (anything in `lib/`)
- **`cloud-function-implementer`** — implements Cloud Functions and security rules (anything in `functions/`, `firestore.rules`, `storage.rules`)

### When to use a subagent vs implement inline

Use a subagent when:
- The task is a single WBS entry, well-bounded, with clear Deliverables
- The implementation is long enough to benefit from a fresh context window
- Multiple WBS tasks could be implemented in parallel (subagents can run concurrently)

Implement inline (no subagent) when:
- The task is a small fix or follow-up to recent work
- The task spans both Flutter and Cloud Functions (subagents are single-domain)
- You need to inspect or discuss before implementing

### Dispatch examples

Good dispatch prompts:

> Use the `flutter-task-implementer` subagent to implement WBS 7.3 (Swipe Card UI). The entry is in `docs/EcoSwap_WBS_Dictionary.md`. Read the prototype JSX listed in the Prototype Reference row before writing Flutter code.

> Use the `cloud-function-implementer` subagent to implement WBS 10.2 (Validate Scanned JWT). The entry is in `docs/EcoSwap_WBS_Dictionary.md`. Also read entries 10.1 and 10.6 — they're tightly coupled by the transaction in 10.2.

> Dispatch three `flutter-task-implementer` subagents in parallel for WBS 6.2, 6.3, and 6.4 (Upload Item form, My Items grid, Edit Item). They share atoms from `prototype/src/screens/upload.jsx` — each subagent should read the JSX file.

### What NOT to do

- Do NOT dispatch one subagent for multiple unrelated WBS tasks. One task per dispatch.
- Do NOT use a subagent for cross-domain work (e.g., WBS 8.3 mixes Cloud Function + match notification UI). Implement inline or split into two dispatches.
- Do NOT dispatch a subagent without telling it the WBS code. The whole workflow depends on locating the right entry.

---

## CI/CD pipeline

The pipeline lives in `.github/workflows/ci.yml`. Six jobs:

| Job | When it runs | What it does |
|---|---|---|
| `flutter-analyze-and-test` | Every push, every PR | `dart format`, `flutter analyze`, `flutter test` with coverage |
| `functions-build-and-test` | Every push, every PR | ESLint, `tsc --noEmit`, `jest` with coverage |
| `firestore-rules-test` | Every push, every PR | Rules tests against Firestore emulator |
| `integration-test` (WBS 12.1) | PR to main + push to main | Full flow against emulator suite |
| `build-apk` | PR to main + push to main | Builds debug APK as a downloadable artifact (DEV_MODE explicitly disabled in the build flag) |
| `deploy-dev` | Push to main only | Deploys Cloud Functions + security rules to `ecoswap-dev` Firebase project |

### One-time setup the repo needs

The team owner must do these once:

1. **Create the `ecoswap-dev` Firebase project** (if not already), enable Auth, Firestore, Storage, Cloud Functions.
2. **Generate a CI token** locally with `firebase login:ci`, copy the output.
3. **Add it as a GitHub secret** under repo Settings → Secrets and variables → Actions → New repository secret, named `FIREBASE_TOKEN`.
4. **Create the `dev` GitHub environment** (repo Settings → Environments → New environment, named `dev`). This is what the `deploy-dev` job's `environment: dev` references. Optionally add required reviewers if deploy should require manual approval.
5. **Enable branch protection on `main`** (repo Settings → Branches → Add rule for `main`):
   - Require pull request before merging
   - Require status checks: `flutter-analyze-and-test`, `functions-build-and-test`, `firestore-rules-test`
   - This is why the team works on feature branches and opens PRs — direct push to `main` is blocked.

### Workflow for contributors

- Work on a feature branch (`git checkout -b feat/wbs-7.3-swipe-card`)
- Push the branch — CI runs the fast jobs (lint, unit tests, rules tests)
- Open a PR to `main` — CI additionally runs the integration test and builds an APK
- Merge to `main` after CI passes — deploy-dev kicks off and pushes to the dev Firebase project

### When CI fails

- **Lint or unit tests fail** → fix locally, push the fix
- **Integration test fails** → check the emulator output in the Actions log; often a security rule or transaction timing issue
- **Deploy fails** → check `FIREBASE_TOKEN` is set, check the project ID matches

---

## Rules — locked decisions that must not be re-litigated

These are documented in the planning package and the dictionary. Do not re-introduce features the team explicitly cut.

### Location model
- **No GPS, no map API, no lat/lng, no kilometre display anywhere in the app.**
- Proximity is bucket-based: `same_district` / `same_province` / `nearby_provinces` / `all_thailand`.
- District comes from a profile-set bilingual searchable dropdown. The bundled JSON is `kongvut/thai-province-data`.
- The `homeDistrict` object is six strings (see WBS 3.6). Do not add `lat`, `lng`, `centroid`, or distance fields.

### Out of scope — do not implement, do not display in UI, do not add to data model
- User age, DOB, occupation, school
- Verification badges, "verified" status
- Activity status ("active now", "active this week", "last seen") — no presence tracking
- Star ratings, numeric trust scores on user cards
- Trust score field on `/users/` (was a Should-Have, was cut)
- Trend arrows ("↑38%"), "This month" comparison cards on the impact dashboard
- Cog or info icons on top-level screen top bars (Profile, My Items, Impact have title-only top bars)

### Impact calculation
- CO₂ saved = weight of item received × category intensity (per WBS 10.6 and 11.1)
- Waste diverted = weight of item given
- Per-user attribution: each user gets CO₂ for what they received, waste for what they gave
- Server-side only — the Cloud Function in WBS 10.6 is the **only** writer of `/trades/` and the `/users/` counter fields
- The two lookup tables (CO₂ intensity, typical weight) are duplicated in `functions/src/constants/impact.ts` and `lib/constants/impact.dart` — keep them in sync

### Item picker
- **Single-select**, not multi-select. The user picks exactly one item per swipe.
- Item declared at swipe-right time is the final lock — no separate confirmation step after match (F19 and F20 were collapsed in v1.1).

### QR Exchange
- Signed JWT via Cloud Function HMAC, 60-second expiry, refresh every 30 seconds
- DEV-MODE paste-token fallback is build-flag gated, **disabled in release builds** (WBS 10.5)
- The CI `build-apk` job explicitly sets `DEV_MODE=false` to prevent debug builds shipped to teammates from including the paste path
- Four security checks on validate: signature, expiry, counterparty, single-use (WBS 10.2)

### Vocabulary
- **Swap** — user-facing word (UI copy)
- **Trade** — data-layer word (code, Firestore, Cloud Functions)
- **Swipe** — gesture, never "like" or "vote"
- See the Glossary at the top of the WBS Dictionary for the full list.

---

## Prototype — how to read it

The prototype in `prototype/src/screens/` is the Claude Design export. Each file is one screen or set of related screens.

```
prototype/src/screens/
├── auth.jsx          # signup + signin (same screen, mode prop)
├── chat.jsx          # match chat screen
├── chats.jsx         # match list
├── discover.jsx      # swipe deck + proximity filter + swipe card
├── editprofile.jsx   # edit profile
├── impact.jsx        # impact dashboard (variant A only is MVP; B and C are out of scope)
├── match.jsx         # match celebration screen
├── myitems.jsx       # my items grid
├── picker.jsx        # item picker bottom sheet
├── profile.jsx       # profile view
├── qr.jsx            # QR exchange (stages: show / scan / success)
├── setup.jsx         # 3-step profile setup wizard
├── splash.jsx        # splash screen
├── upload.jsx        # upload + edit item form
└── userdetail.jsx    # user detail with item bottom sheet
```

**Reading conventions:**
- Component names in the prototype match what you should call the equivalent Flutter widget (e.g., `SwipeCard` in JSX → `SwipeCard` widget in Dart).
- Inline comments in each JSX file explain the screen's purpose and any notable patches.
- The prototype contains some design exploration (e.g., `impact.jsx` has three variants A/B/C — only A is MVP). The WBS entry tells you which to implement.

---

## Working style

- **Be decisive.** The dictionary and planning doc are the source of truth; don't ask for re-clarification on locked decisions.
- **Push back when something contradicts a locked decision or out-of-scope rule.** Better to flag than silently violate.
- **Write tests alongside the code**, per the Testing section in each entry. Do not defer.
- **One task at a time** unless explicitly told otherwise. The WBS owners are listed in the entry's Owner row.
- **Use subagents for well-bounded implementation work.** Use inline implementation for cross-domain or exploratory work.

---

## When in doubt

- For UI questions → check the prototype JSX, then the Style Guide
- For data shape questions → check WBS 3.6
- For impact math questions → check WBS 11.1 and 10.6
- For QR security questions → check WBS 10.1, 10.2, and §8.3 of the planning doc
- For scope questions → check the "Out of scope" list above and Appendix A.1 of the planning doc
- For CI failures → check the Actions tab on GitHub, then the relevant job log

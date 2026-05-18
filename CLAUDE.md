# Claude Code Workflow — EcoSwap

This file tells Claude Code (and any AI coding assistant) how to work in this repo.

> **For human team members:** read [`docs/TEAM_SETUP_GUIDE.md`](docs/TEAM_SETUP_GUIDE.md) instead. This file is structured for AI consumption.

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
- `.claude/skills/` — skill files (grill-me for design and planning stress-testing)
- `.github/workflows/` — CI/CD pipeline
- `.github/CODEOWNERS` — auto-assigns PR reviewers based on file paths touched

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

## Skills

Skill files in `.claude/skills/` are auto-loaded by Claude Code and trigger based on conversational cues. Currently one skill is defined:

### `grill-me` — design and planning stress-test mode

Located at `.claude/skills/grill-me/SKILL.md`. Activates when the user wants to stress-test a plan, design, or architecture decision. When triggered, Claude interviews relentlessly with numbered questions, providing a recommended answer for each, until every branch of the design tree is resolved.

**Trigger phrases:**
- "grill me", "stress-test this", "poke holes in this"
- "what could go wrong with...", "interview me on..."

**Also auto-triggers on:**
- Planning discussions (sprint plan, task ordering)
- Architecture decisions (data model, security, transactions)
- WBS entry design review before implementation
- Mid-sprint scope decisions (Day 5)
- Cross-cutting changes that touch multiple workstreams

**Does NOT trigger on:**
- Routine implementation work (just ship it)
- Syntax or API lookups
- Bug fixes with obvious cause and obvious fix
- Casual conversation

The skill file is the authoritative spec — read `.claude/skills/grill-me/SKILL.md` for the full behaviour.

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

## Pull request review process

Every PR needs review by one teammate before merging. Branch protection on `main` enforces this. Reviewers are assigned by **pair-rotation**, not a single designated reviewer, to spread the load and keep reviews fast.

### Reviewer assignment

When you open a PR, request a review from your paired reviewer based on the workstream:

| Author | Reviewer | Pairing rationale |
|---|---|---|
| M1 (auth, matching) | M4 | Both touch security and Cloud Functions |
| M4 (backend, QR Cloud Functions) | M1 | Reciprocal — both understand the JWT and transaction code |
| M2 (items, chat) | M3 | Both Flutter UI — overlapping component knowledge |
| M3 (discover, QR client) | M2 | Reciprocal |
| M5 (testing, docs, polish) | Whichever workstream the PR touches | M5's PRs are usually cross-cutting |

If your designated reviewer is genuinely unavailable (sick, in another class, asleep), request a review from any teammate who hasn't authored the PR.

**Auto-assignment via CODEOWNERS:** the file `.github/CODEOWNERS` maps file paths to owners. When you open a PR, GitHub automatically requests review from the owner of any file you touched. **You still need to ping them on Discord** — the auto-request only fires a GitHub notification, which is easy to miss.

### Coordinator role

**M5 is the PR coordinator, not a designated single reviewer.** M5's job:
- At each daily standup (1.3), spend the final 2 minutes sweeping open PRs
- Any PR older than 24 hours gets flagged; M5 nudges the reviewer publicly to clear it by lunch
- M5 does NOT do the technical review unless they're the natural reviewer for that workstream

This keeps M5 in the testing/QA lane they already own while making sure no PR rots silently.

### Discord setup for PR notifications

The team coordinates reviews on **Discord**. Set up two things:

1. **A dedicated `#pull-requests` channel** in the EcoSwap Discord server. All PR-related chatter goes here, not the general channel.
2. **GitHub-to-Discord webhook** so PR opens, reviews, and merges auto-post to the channel:
   - In Discord: `#pull-requests` → channel settings → Integrations → Webhooks → New Webhook → copy URL
   - In GitHub: repo Settings → Webhooks → Add webhook → paste URL, append `/github` to the end, content type `application/json`, select "Let me select individual events" and tick **Pull requests**, **Pull request reviews**, **Pull request review comments**
   - Test by opening a draft PR and confirming Discord posts

**The webhook posts a card but does NOT @-ping anyone.** GitHub and Discord have no shared identity layer — the webhook can't know that GitHub user `@Jedad11` is Discord user `@32+62`. So after the webhook posts, **the PR author manually pings their reviewer in `#pull-requests`** using the Discord tags from the pinned message in that channel.

### GitHub handle ↔ Discord tag mapping

Pinned in `#pull-requests`. Use these tags when @-pinging a reviewer.

| Role | GitHub | Discord |
|---|---|---|
| M1 — backend, matching | `@Jedad11` | `@32+62` |
| M2 — items, chat | `@Vannyyoda` | `@Vannydayo` |
| M3 — discover, QR client | `@Waltzz62` | `@ohmaohmagod` |
| M4 — infra, QR backend | `@PausEzi` | `@poshgg` |
| M5 — testing, docs, coordinator | `@SittaWetpa` | `@KarozRose` |

Pair rotation: **M1 ↔ M4**, **M2 ↔ M3**, **M5 → workstream pair**.

### Review SLA

- **Target: 4 hours from PR open to first review during working hours.** If you open at 10 AM, expect review by 2 PM. Not 6 PM. Not tomorrow.
- **Working hours** for this team: 9 AM – 7 PM weekdays. PRs opened after 7 PM or on weekends get reviewed next working morning, no SLA.
- **Ping your reviewer in `#pull-requests`** using their Discord tag from the mapping table above. The webhook auto-posts the PR card; the @-ping is your job.
- If a review hasn't happened in 4 hours during working hours, ping again. If 24 hours, escalate to M5 (`@KarozRose`).

### What reviewers check

Reviews are **checklist-driven**, not vibes-driven. For every PR the reviewer confirms:

1. **WBS entry compliance** — Does the PR implement what its WBS entry says? Acceptance criteria all met? Cross-reference the entry by its WBS code in `docs/EcoSwap_WBS_Dictionary.md`.
2. **Locked decisions respected** — Cross-reference the "Rules" section below. Common violations to catch:
   - GPS / lat-lng / km language sneaking back in
   - Age, verification badge, activity status appearing in UI
   - Multi-select item picker (must be single-select)
   - Trust score field on `/users/`
   - Trend arrows or "this month" cards on the impact dashboard
3. **Tests present and passing** — The WBS entry's Testing section lists specific tests. Are they written? Are they actually testing what they claim, or just calling the function?
4. **CI passing** — All required status checks green. If integration test is red, don't approve until it's fixed.
5. **No secrets committed** — No tokens, no service account JSON, no `.env` files, no `JWT_SECRET` in code. Run `git log -p <new-file-paths>` mentally; if anything looks like a secret, flag it.

The reviewer is NOT responsible for catching every bug. They ARE responsible for these five checks. A 15-minute review that hits the checklist beats a 60-minute deep dive that misses a locked-decision violation.

### Author responsibilities

When opening a PR:

- **One WBS task per PR.** If the task is large, split. Reviewers can handle a 200-line PR in 15 minutes; a 2000-line PR gets rubber-stamped.
- **Branch naming convention:** `feat/wbs-X.Y-short-desc` for features, `fix/wbs-X.Y-short-desc` for bug fixes, `chore/short-desc` for non-WBS work (e.g., updating CI, fixing docs).
- **PR title format:** `WBS X.Y — Short description` (e.g., `WBS 7.3 — Swipe Card UI`). For non-WBS work: `chore: short description`.
- **PR description must include:**
  - Link or reference to the WBS entry (e.g., `Implements WBS 7.3, see docs/EcoSwap_WBS_Dictionary.md`)
  - Bulleted list of acceptance criteria from the WBS entry, each ticked or noted
  - Screenshots if the PR touches UI
  - Anything intentionally deferred to a follow-up PR
- **Request review from the assigned reviewer explicitly** via the GitHub "Reviewers" sidebar AND a Discord ping in `#pull-requests`.

### Example PR description

```
Implements WBS 7.3 (Swipe Card UI).

Acceptance criteria:
- [x] Right-swipe gesture works smoothly
- [x] Left-swipe gesture works smoothly
- [x] Tap on card navigates to User Detail (no swipe-swallow bug)
- [x] District pill shows "Thai · English, Province" format
- [x] No fabricated UI elements (verified, active now, age, km)

Screenshots: see attached.

Tests: added widget tests for right-swipe, left-swipe, tap-navigation,
       district format, and out-of-scope element absence.

Reviewer: @Vannyyoda (M2)
Discord ping: @Vannydayo
Deferred to follow-up: SwipeCard animation polish (will address in a
                       separate chore PR after usability testing on Day 7).
```

### When a review blocks merge

If the reviewer requests changes:
- Author pushes fixes to the same branch (don't open a new PR)
- Author re-requests review explicitly in `#pull-requests`
- "Dismiss stale approvals on new commits" is enabled, so any prior approval gets invalidated — this is intentional, prevents sneaking changes past a reviewer

### Emergencies

If `main` is broken (e.g., deploy job failed, dev Firebase project is in a bad state):

1. Open a `fix/` PR immediately, even at 11 PM
2. Ping `@here` in `#pull-requests` — this overrides the SLA and working hours
3. Any teammate can review, not just the designated pair
4. After fixing, post a brief postmortem in `#general`: what broke, how it was fixed, how to prevent next time

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
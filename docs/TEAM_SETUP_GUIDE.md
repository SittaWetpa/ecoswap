# EcoSwap — Team Setup Guide (Claude Code Edition)

**Read this on Day 0. Refer back to it any time you're unsure of the workflow.**

This is the team's operations manual for a **Claude-Code-first** workflow. Every team member uses Claude Code to implement tasks. You will rarely write Dart or TypeScript by hand — your job is to **dispatch, review, and ship**.

> **For implementation details and locked technical decisions, see [`CLAUDE.md`](../CLAUDE.md).**
> **For per-task specs, see [`docs/EcoSwap_WBS_Dictionary.md`](EcoSwap_WBS_Dictionary.md).**

---

## Quick reference (skim this even if you've read the rest)

### Who you are

| Role | Owner | GitHub | Discord | Reviewer (paired) |
|---|---|---|---|---|
| M1 — backend, matching | Chetsadaphiphat | `@Jedad11` | `@32+62` | M4 |
| M2 — items, chat | Vannydayo | `@Vannyyoda` | `@Vannydayo` | M3 |
| M3 — discover, QR client | Woraprat | `@Waltzz62` | `@ohmaohmagod` | M2 |
| M4 — infra, QR backend | Pal | `@PausEzi` | `@poshgg` | M1 |
| M5 — testing, coordinator | Sitta | `@SittaWetpa` | `@KarozRose` | workstream pair |

### The 7 commandments

1. **Dispatch a subagent for every WBS task.** Don't hand-write code unless the task is truly cross-domain or a tiny fixup.
2. **Pre-dispatch self-check + grill when required.** Before every dispatch, answer 3 self-check questions (§2 step 4). For Phase 8, Phase 10, data-model changes, cross-domain, or other-people's tasks: `grill-me` is mandatory.
3. **Use the fixed prompt templates.** Copy verbatim, swap only the WBS code. Don't improvise dispatches.
4. **Read the subagent's output before merging.** Trust but verify — Claude can violate locked decisions if not prompted correctly.
5. **Run the 5-item checklist on every PR** — yours and others'. Dispatch a Claude Code review pass before approving.
6. **Branch off `main`, never push to `main` directly.** Branch protection blocks it anyway.
7. **Ping your reviewer on Discord** in `#pull-requests` after opening a PR. The webhook does NOT @-tag anyone.

### The 5 forbidden things

1. **No GPS, no lat/lng, no km display anywhere.** District buckets only.
2. **No age, no verification badge, no "active now", no star ratings, no trust score** in UI or data model.
3. **Multi-select item picker.** It's single-select. Always.
4. **Trend arrows or "this month" cards** on the impact dashboard.
5. **Committing secrets** — no tokens, no service account JSON, no `.env` files.

---

## 1. Day-0 setup

### Prerequisites — install before sprint starts

| Tool | Version | How to install |
|---|---|---|
| **Claude Code** | latest | https://claude.ai/code — install per your OS instructions |
| **Flutter SDK** | 3.24.0+ | https://flutter.dev/docs/get-started/install |
| **Android Studio + emulator** | latest | https://developer.android.com/studio |
| **Node.js** | 20.x | https://nodejs.org or via nvm |
| **Firebase CLI** | latest | `npm install -g firebase-tools` |
| **Git** | any modern | https://git-scm.com |
| **GitHub CLI (`gh`)** | latest | https://cli.github.com — makes PR opening 10x faster |
| **Discord** | desktop + mobile | https://discord.com |
| **A GitHub account** | — | Tell `@SittaWetpa` your handle |
| **A Claude account with Claude Code access** | — | Pro plan minimum |

Verify everything is installed:

```bash
claude --version
flutter doctor
node --version
firebase --version
gh --version
git --version
```

`flutter doctor` will tell you to install Android licenses or set up an emulator — follow its hints.

### Clone the repo

```bash
git clone https://github.com/SittaWetpa/ecoswap.git
cd ecoswap
```

If you get "Permission denied" — `@SittaWetpa` hasn't added you as a collaborator yet. Ping in Discord.

### Verify Claude Code is reading the project context

`cd` into the repo and run:

```bash
claude
```

In the Claude Code session, ask:

> "What is this project and what subagents are available?"

Claude Code should respond with a summary of EcoSwap, mention the WBS dictionary, and list the two subagents (`flutter-task-implementer`, `cloud-function-implementer`). If it doesn't, something is wrong — check that:

- You're in the repo root (not a subdirectory)
- `CLAUDE.md` exists at the repo root
- `.claude/agents/` directory exists with the two `.md` files
- `.claude/skills/grill-me/SKILL.md` exists

If still broken, ping `@poshgg` (M4) on Discord.

### First-time Firebase setup

Get the Firebase config files from `@PausEzi` (M4):

- `android/app/google-services.json`

Place at the indicated path. **Do NOT commit it.**

### Run the app once

Just to confirm everything works end-to-end:

```bash
flutter pub get
flutter run         # against the emulator
```

If it crashes or won't build, see FAQ or ping M4.

---

## 2. The workflow — picking up a task

Every task in the sprint is identified by a **WBS code** like `7.3` or `10.6`. Tasks are listed in [`docs/EcoSwap_WBS_Dictionary.md`](EcoSwap_WBS_Dictionary.md).

### The Claude-Code-first recipe

1. **Find your next task at standup or in Discord.** WBS dictionary's "Owner" row tells you which tasks are yours.

2. **Create a feature branch:**

   ```bash
   git checkout main && git pull
   git checkout -b feat/wbs-7.3-swipe-card
   ```

   Branch naming: `feat/wbs-X.Y-short-desc`, `fix/wbs-X.Y-short-desc`, or `chore/short-desc`.

3. **Start Claude Code in the repo root:**

   ```bash
   claude
   ```

4. **Pre-dispatch self-check** (mandatory before every dispatch). Answer these three questions in your head, or in the chat with Claude Code, or in a Discord scratch message — whichever:

   1. **What does this task DO?** Summarise in one sentence. If you can't, you don't understand the entry yet — read it again.
   2. **What's the trickiest part?** Schema change? Security check? Transaction boundary? Cross-screen state? If you don't know what's tricky, that's a sign you should `grill-me` (see below) before dispatching.
   3. **What locked decisions could this task accidentally violate?** Look at the "forbidden things" list. Name at least one risk specific to this task (e.g., "the picker UI could end up multi-select if I'm not careful").

   If any of the three feels fuzzy → run `grill-me` before dispatching. See "When grill-me is mandatory" below.

5. **Dispatch the right subagent.** Pick based on the WBS phase:

   | WBS phase | Subagent |
   |---|---|
   | 4.x, 5.x, 6.x, 7.x, 8.2, 8.4, 9.x, 10.3, 10.4, 10.5, 11.3, 11.4 | `flutter-task-implementer` |
   | 3.x, 8.1, 8.3, 8.5, 10.1, 10.2, 10.6 | `cloud-function-implementer` |
   | Cross-domain (8.3, 10.6, 11.x with both server + UI) | **Sequential dispatch** — see below |

   Use the **fixed prompt templates** below. Copy verbatim, swap only the WBS code and the task description. Don't improvise.

   #### Template A — `flutter-task-implementer`

   ```
   Use the flutter-task-implementer subagent to implement WBS <CODE>.

   Required reading, in order:
   1. CLAUDE.md (repo root) — locked decisions
   2. docs/EcoSwap_WBS_Dictionary.md — find the entry by searching "### <CODE> "
   3. docs/EcoSwap_WBS_Dictionary.md entry 3.6 — Firestore data model
      (read this even if my task doesn't seem to touch Firestore; prevents
      schema drift)
   4. The JSX file(s) listed in the entry's "Prototype Reference" row
      — these live in prototype/src/screens/
   5. docs/EcoSwap_Style_Guide.md — design tokens

   Required outputs:
   - Files at the exact paths listed in the entry's Deliverables section
   - All acceptance criteria from the entry's Acceptance section verified
   - All tests listed in the entry's Testing section written and passing
   - `flutter analyze && flutter test` both pass before you report back

   Required report format when done:
   - Files created (list paths)
   - Files modified (list paths)
   - Acceptance criteria verified (list each one with PASS/FAIL)
   - Lint and test results (PASS/FAIL with command output if failed)
   - Anything you couldn't do and why

   Do NOT:
   - Implement anything in functions/ (that's the other subagent's domain)
   - Modify docs/EcoSwap_WBS_Dictionary.md or CLAUDE.md
   - Skip the required reading because the task looks small
   - Implement multiple WBS tasks in one dispatch
   ```

   #### Template B — `cloud-function-implementer`

   ```
   Use the cloud-function-implementer subagent to implement WBS <CODE>.

   Required reading, in order:
   1. CLAUDE.md (repo root) — locked decisions
   2. docs/EcoSwap_WBS_Dictionary.md — find the entry by searching "### <CODE> "
   3. docs/EcoSwap_WBS_Dictionary.md entry 3.6 — Firestore data model
      (read every task; the schemas are the canonical source for every doc shape)
   4. If this task touches QR or trade flow: also read entries 10.1, 10.2, 10.6
      together; they are tightly coupled by transactions and security checks

   Required outputs:
   - Files at the exact paths listed in the entry's Deliverables section
   - All acceptance criteria from the entry's Acceptance section verified
   - All tests listed in the entry's Testing section written and passing
   - `cd functions && npm run build && npm test` both pass before reporting

   Required report format when done:
   - Files created (list paths)
   - Files modified (list paths)
   - Acceptance criteria verified (list each one with PASS/FAIL)
   - Build and test results (PASS/FAIL with command output if failed)
   - Anything you couldn't do and why

   Do NOT:
   - Implement anything in lib/ (that's the other subagent's domain)
   - Modify docs/EcoSwap_WBS_Dictionary.md or CLAUDE.md
   - Commit any secrets, .env files, or JWT signing keys
   - Skip the required reading because the task looks small
   - Implement multiple WBS tasks in one dispatch
   ```

   #### Template C — Cross-domain (sequential dispatch in one PR)

   For WBS entries that span both Flutter and Cloud Functions (e.g., 8.3 has a Cloud Function trigger PLUS a notification UI; 10.6 has the trade-record write PLUS a Swap Confirmed screen; 11.x has impact computation PLUS dashboard UI). **Do both halves in the same PR on the same feature branch.**

   Order:
   1. Dispatch **Template B (`cloud-function-implementer`) first** with the same WBS code. Wait for it to finish, review its output, commit if good.
   2. Dispatch **Template A (`flutter-task-implementer`) second**, on the same branch, with this prefix added at the top of Template A:

      ```
      The Cloud Function side of WBS <CODE> is already implemented in this
      branch — see the most recent commits in functions/src/. Build only the
      Flutter UI consumer side that talks to it. Do NOT modify any file in
      functions/.
      ```

   3. Review and commit the Flutter side, then open the PR.

   **Fallback — Template D, inline (no subagent)** if sequential dispatch is overkill (small cross-domain change, well-understood):

   ```
   This is a cross-domain task — WBS <CODE> spans Flutter UI and Cloud Functions.
   Don't delegate to a subagent. Implement both sides yourself in this same
   session, following the same workflow each subagent would:

   1. Read CLAUDE.md, the WBS entry, WBS 3.6 data model, and the prototype JSX
   2. Implement the Cloud Function side first, in functions/
   3. Implement the Flutter UI consumer side second, in lib/
   4. Write the tests listed in the entry's Testing section for both sides
   5. Run `flutter analyze && flutter test` AND `cd functions && npm run build
      && npm test`; report both results

   Use the same report format as the subagents:
   - Files created and modified
   - Acceptance criteria verified (PASS/FAIL)
   - Lint and test results
   - Anything you couldn't do and why
   ```

6. **Wait for the subagent to finish.** It will report back what it created/modified, whether lint and tests passed, and which acceptance criteria it verified — in the structured format required by the template.

7. **Review the output against the report.** This is your most important step. The subagent is good but not infallible:
   - Does the report list every file in the entry's Deliverables section, no more, no less?
   - Does the diff violate any locked decision? (Look for GPS, age, trust score, multi-select picker.)
   - Are the tests actually testing what they claim, or just calling the function and asserting no exception?
   - Does the UI look like the prototype JSX?
   - Did the subagent skip any required reading? (If the report doesn't mention WBS 3.6 for a Firestore-touching task, push back.)

8. **Iterate if needed.** If something's wrong, push back:

   ```
   The widget you wrote shows the user's age. Age is out of scope per
   CLAUDE.md. Remove it and use only display name + district.
   ```

9. **Smoke-test locally:**

   ```bash
   flutter analyze && flutter test
   flutter run       # eyeball the screen on the emulator
   ```

10. **Commit and push.** Use `gh` for speed:

    ```bash
    git add .
    git commit -m "feat: WBS 7.3 swipe card UI"
    git push -u origin feat/wbs-7.3-swipe-card
    ```

11. **Open a PR.** See section 3.

### When NOT to dispatch a subagent

Edge cases where inline Claude Code chat is better than a subagent dispatch:

- **Tiny fixups** (rename a variable, fix a typo, add a missing import) — just chat with Claude Code inline
- **Bug fixes where you already know the cause and fix** — describe the bug, let Claude apply the fix inline
- **Exploratory work** where you don't know what you want yet — chat with Claude Code inline until the design is clear, then dispatch a subagent
- **Cross-domain tasks** — use Template C (sequential dispatch) or Template D (inline cross-domain) above, NOT a single subagent

For everything else: **dispatch a subagent**. That's the default.

### When `grill-me` is MANDATORY

`grill-me` is the skill that interrogates a design with numbered questions until every branch is resolved. Type `grill me on WBS <CODE>` to trigger it.

**Mandatory grill-me before dispatching** for these task categories:

- ✅ **Any task in Phase 8 (matching)** — 8.1, 8.2, 8.3, 8.4, 8.5. Match creation has transaction concerns and hard-cancel logic that breaks subtly.
- ✅ **Any task in Phase 10 (QR exchange)** — 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7. Security-sensitive, highest-risk workstream.
- ✅ **Any task that touches the Firestore data model** — schema additions, new collections, new fields. WBS 3.6 is the canonical source; changing it has downstream impact.
- ✅ **All cross-domain tasks** (those using Template C or D) — grill the boundary between server and UI.
- ✅ **Any task where you are not the original owner** — e.g., if M5 picks up a stalled task from M2, M5 must grill it because they don't have the workstream context yet.

**Strongly recommended** (not mandatory but expected):

- Mid-sprint scope decisions (Day 5 review)
- Any task that introduces a new pattern not yet used in the codebase

**Optional** for everything else — simple, well-bounded tasks (4.3 Logout, 5.3 Bio editor, 6.1 Image picker) usually don't need grilling. But if your pre-dispatch self-check (step 4) flagged something fuzzy, grill it.

### How to grill before dispatching

1. Type into Claude Code:

   ```
   grill me on WBS <CODE>
   ```

2. Claude responds with numbered questions, each with a recommended answer.

3. Answer the questions in order. You can answer with "go with recommendation on Q1, push back on Q2 because X, Q3 should be Y instead of recommendation."

4. Claude may run another round of grill questions based on your answers. Repeat until all branches resolved (or Claude says "I have no more questions").

5. **Now dispatch the subagent**, using the templates above. In the dispatch prompt, include a one-line note: "Pre-grilled — decisions locked: <summarise what changed from default WBS entry, if anything>."

If grill-me reveals that the WBS entry itself has a gap (e.g., it doesn't say what to do on validation failure), pause the dispatch and open a `chore/` PR to update the WBS entry first. Don't paper over WBS gaps in the implementation.

---

## 3. Opening a PR

### PR title and description

**Title:** `WBS X.Y — Short description`

Example: `WBS 7.3 — Swipe Card UI`

For non-WBS work: `chore: short description`

**Description must include:**

```markdown
Implements WBS 7.3 (Swipe Card UI).

Implemented by: flutter-task-implementer subagent
Reviewed locally: yes (ran flutter analyze + test, eyeballed on emulator)

Acceptance criteria:
- [x] Right-swipe gesture works smoothly
- [x] Left-swipe gesture works smoothly
- [x] Tap on card navigates to User Detail
- [x] District pill shows "Thai · English, Province" format
- [x] No out-of-scope UI (verified, active now, age, km)

Screenshots: see attached.

Tests added: widget tests for right-swipe, left-swipe, tap-nav, district
            format, and out-of-scope element absence.

Reviewer: @Waltzz62 (M3)
Discord ping: @ohmaohmagod
```

The "Implemented by: ... subagent" line is a useful audit trail — the team can later see which PRs were Claude-Code-implemented vs hand-written.

### Request review

1. In the PR's right sidebar, click the gear next to **Reviewers**, select your paired reviewer.
2. Go to Discord `#pull-requests` channel.
3. Type `@` + reviewer's Discord handle (use autocomplete!), paste the PR link.
4. Send.

The webhook will have already posted a card to the channel, but **that card does NOT ping anyone**. Your @-tag is what triggers the push notification.

Example:
```
@ohmaohmagod review pls — https://github.com/SittaWetpa/ecoswap/pull/12
```

### Review SLA

- **Target: 4 hours** from PR open to first review during working hours (9 AM – 7 PM weekdays)
- PRs opened outside working hours get reviewed next working morning, no SLA
- If a review hasn't happened in 4 hours during working hours, ping again
- If >24 hours, escalate to M5 (`@KarozRose`) at next standup PR sweep

### What happens next

- CI runs automatically (Flutter, Functions, Firestore rules). Wait for green.
- Reviewer runs the 5-item checklist (see §4), approves or requests changes.
- If changes requested: dispatch the subagent again to address feedback, push, re-request review.
- Once approved + CI green: click **Merge**.
- After merge, `deploy-dev` job kicks off.
- Delete the branch.

---

## 4. Reviewing a PR (Claude-Code-assisted)

Your job as a reviewer is to confirm the 5-item checklist. **Use Claude Code as a first-pass reviewer** — it catches schema drift, locked-decision violations, and missing tests faster than you can.

### Recipe for reviewing a PR

1. **Check out the PR locally** so Claude Code can see the diff:

   ```bash
   gh pr checkout 12       # replace 12 with the PR number
   ```

2. **Start Claude Code** and dispatch a review pass:

   ```
   I'm reviewing PR #12 which implements WBS 7.3. The diff is on the current
   branch (compare with main). Run the 5-item review checklist from CLAUDE.md:

   1. Does the diff implement what WBS 7.3 says? Acceptance criteria all met?
   2. Does it violate any locked decision in CLAUDE.md? (GPS/age/verified/
      multi-select/trust score/trend arrows)
   3. Are the tests listed in WBS 7.3's Testing section actually present and
      testing what they claim?
   4. Any secrets, tokens, service account JSON, or .env files committed?
   5. Does the diff match the prototype JSX in prototype/src/screens/?

   For each item, report PASS or FAIL with specific line numbers. Don't approve
   anything yet — I'll make the final call.
   ```

3. **Review Claude's report.** It will flag any failures with file:line references. You decide what to do.

4. **Spot-check yourself.** Don't blindly trust Claude. Open the diff in your browser, eyeball the changed files, especially:
   - UI code: does it look like the prototype?
   - Data model changes: does it match WBS 3.6?
   - Security rules / Cloud Functions: are the security checks all present?

5. **Run CI checks locally if Claude flagged something CI didn't:**

   ```bash
   flutter analyze && flutter test
   ```

6. **Submit the review:**
   - **Approve** when Claude's checklist is all green AND your spot-check passes.
   - **Request changes** when Claude flagged failures OR you spotted something Claude missed. Include a one-line summary.
   - **Always ping the author on Discord** when requesting changes:
     ```
     @Vannydayo requested changes on #12 — Claude flagged that the district
     pill is missing the Thai name. Take a look.
     ```

### The 5-item review checklist (canonical)

1. **WBS entry compliance** — does the PR implement what its WBS entry says? Acceptance criteria all met?
2. **Locked decisions respected** — see the "forbidden things" list. Common Claude-Code-introduced violations:
   - Inferring "show user age" from prototype dummy data even though age is forbidden
   - Adding a "verified" badge because it's a common pattern in other apps
   - Adding a trend arrow because "the dashboard looks empty without it"
3. **Tests present and passing** — the WBS entry's Testing section lists specific tests. Are they written? Are they actually testing what they claim?
4. **CI passing** — all required status checks green.
5. **No secrets committed** — no tokens, service account JSON, `.env`, JWT signing keys.

You are NOT responsible for catching every bug. You ARE responsible for these five checks.

---

## 5. Pinging on Discord — how notifications work

GitHub and Discord don't share identities. The webhook in `#pull-requests` posts informational cards but does NOT @-tag anyone. **Every notification on someone's phone comes from a Discord message with their @-tag in it.**

### Author's job (after opening PR)

1. Add reviewer in GitHub Reviewers sidebar
2. **Go to Discord `#pull-requests`, type `@` + reviewer's Discord handle (use autocomplete!), paste PR link, send**

### Reviewer's job (after requesting changes)

1. Submit the review on GitHub
2. **Go to Discord `#pull-requests`, @-tag the author with a one-line summary**

After approving: no ping needed — author sees the green check on GitHub.

### Tips

- When typing `@` in Discord, autocomplete pops up — **click the suggestion**, don't type literally. Otherwise it's just text and won't ping.
- Don't use `@everyone` or `@here` except for true emergencies (see §10).

---

## 6. Do's and Don'ts

### Do

- ✅ **Dispatch a subagent for every WBS task** (default workflow)
- ✅ **Do the pre-dispatch self-check** (3 questions, §2 step 4) every time
- ✅ **Use `grill-me` when mandatory** — Phase 8, Phase 10, data-model changes, cross-domain tasks, tasks you didn't originally own
- ✅ **Use the fixed prompt templates** (Template A/B/C/D in §2) — don't improvise
- ✅ **Read the subagent's output before committing** — trust but verify
- ✅ **Use Claude Code as a first-pass reviewer** on PRs you're reviewing
- ✅ **Write one PR per WBS task**
- ✅ **Ping your reviewer on Discord** after opening a PR
- ✅ **Push back on Claude Code** when it introduces a locked-decision violation — restate the constraint and re-dispatch
- ✅ **Update both `lib/constants/impact.dart` AND `functions/src/constants/impact.ts`** if CO₂ tables change — they MUST stay in sync

### Don't

- ❌ **Don't skip the self-check or mandatory grill** — these catch problems before they hit Claude
- ❌ **Don't improvise dispatch prompts** — use the fixed templates
- ❌ **Don't merge a subagent's output without reading the diff.** Claude can violate locked decisions if the dispatch prompt was vague.
- ❌ **Don't dispatch one subagent for multiple WBS tasks** — one task per dispatch
- ❌ **Don't use one subagent for cross-domain work** — use sequential dispatch (Template C) or inline cross-domain (Template D)
- ❌ **Don't push to `main` directly** — feature branch and PR
- ❌ **Don't commit secrets** — no tokens, service account JSON, `.env`, JWT signing keys
- ❌ **Don't add GPS, lat/lng, km, age, verification badges, activity status, trust scores, or trend arrows** — locked-out
- ❌ **Don't approve a PR without running the 5-item review checklist** (use Claude Code to help)
- ❌ **Don't skip Wideband Delphi estimation** (1.2) on Day 0
- ❌ **Don't blindly trust Claude Code's "tests pass" claim** — actually run `flutter test` yourself before approving

> **For the full list of locked decisions, see [`CLAUDE.md`](../CLAUDE.md).**

---

## 7. Daily standup expectations

Every working day, 9 AM (or whenever the team agrees). 15 minutes max.

### Format

Each person answers three questions:

1. **What did I finish yesterday?** (link the PR if you merged something)
2. **What am I working on today?** (the WBS code, and which subagent you're dispatching)
3. **What's blocking me?** (named blocker, ideally with who can unblock)

### M5's job at standup

At the end of standup, `@KarozRose` (M5) spends 2 minutes on a **PR sweep**:

- Any open PRs >24 hours? Flag them, nudge the reviewer publicly.
- Any blockers raised today? Confirm someone owns unblocking them.

### Where standup happens

Discord voice channel or async in `#standup` channel. Pick one and stick with it.

---

## 8. When stuck — escalation path

In order:

1. **Ask Claude Code first.** It has CLAUDE.md, the WBS dictionary, and the prototype loaded. Most "how do I X" questions resolve here in 30 seconds. Use `grill me` if the design is unclear.
2. **Try yourself for 30 minutes** — re-read the WBS entry, check the prototype, check the planning doc.
3. **Ask your pair on Discord.** They know the workstream best.
4. **Ask in `#general` Discord.** Anyone available can help.
5. **Escalate to M5 (`@KarozRose`)** if blocked >2 hours.
6. **Bring to next standup** if not urgent.

### Who knows what

- **Auth / matching / Cloud Functions security** → M1 (`@32+62`) or M4 (`@poshgg`)
- **Items / chat / Firestore queries** → M2 (`@Vannydayo`) or M3 (`@ohmaohmagod`)
- **District picker / proximity / Discover UI** → M3 (`@ohmaohmagod`)
- **QR Cloud Functions / impact math / Firebase config** → M4 (`@poshgg`)
- **Style guide / prototype / usability** → M5 (`@KarozRose`)
- **CI / deployment / Claude Code config** → M4 (`@poshgg`)

---

## 9. CI/CD — what to expect

Every push runs three fast jobs:

- `flutter-analyze-and-test`
- `functions-build-and-test`
- `firestore-rules-test`

PRs to `main` additionally run:

- `integration-test` (full flow against emulator)
- `build-apk` (debug APK as a downloadable artifact)

Merges to `main` additionally run:

- `deploy-dev` (deploys to dev Firebase project)

### When CI is red

- **Dispatch Claude Code:** `"CI failed on PR #12 with [paste the error]. What's the fix?"`
- Often the fix is a one-line change (`dart format`, missing import, etc.)
- For integration test failures, retry once — often a race condition. Persistent failures → ping M4.

### Where to find the APK

Actions tab → workflow run → bottom of page → "Artifacts" section.

---

## 10. Emergencies

If `main` is broken:

1. **Open a `fix/` PR immediately**, even at 11 PM
2. **Ping `@here` in `#pull-requests`** — overrides SLA and working hours
3. **Any teammate can review**, not just the designated pair
4. **After fixing, post a brief postmortem in `#general`**

---

## 11. FAQ

### Q: Why does my push to `main` fail?

Branch protection blocks direct pushes. Always feature branch + PR.

### Q: Where do I get the Firebase config?

`google-services.json` lives outside the repo. Ask M4 (`@poshgg`) via Discord DM.

### Q: What's `--dart-define=DEV_MODE=true`?

A build-time flag enabling the QR paste-token fallback. See WBS 10.5. NEVER enable in a release build.

### Q: My subagent gave me code that violates a locked decision. What do I do?

Push back on the subagent, restate the constraint explicitly, re-dispatch. Example:

```
Your last output includes an age field on the user profile. Age is out of
scope per CLAUDE.md "Out of scope" section. Remove all references to age
and re-implement.
```

If the subagent keeps making the same mistake, the WBS entry might have a gap — open a `chore/` PR to clarify the entry.

### Q: My subagent says "tests pass" but the tests don't seem to actually test the thing. What do I do?

Read the test file yourself. If the tests are shallow (e.g., just calling the function and asserting no exception), push back:

```
The tests you wrote don't verify acceptance criterion 2 (right-swipe writes a
swipe doc with desiredItemId). Add a test that specifically asserts that
Firestore was called with the correct desiredItemId value.
```

### Q: Two of us dispatched subagents on related tasks and they made conflicting decisions. What do I do?

Bring it to standup or `#general`. Pick a winner, the loser re-dispatches with the corrected constraint.

Better: coordinate at standup before dispatching. If tasks touch the same files, agree on order — first PR merges, second PR rebases.

### Q: The subagent is taking forever. Should I cancel?

Claude Code's subagents can take 5–10 minutes for a substantial task. Cancel only if:
- It's been >15 minutes with no output
- It's clearly stuck in a loop (re-reading the same files repeatedly)

When cancelling, restart with a more specific dispatch prompt.

### Q: Can I dispatch a subagent for a task that's not mine in the WBS?

No. WBS ownership is in the entry's "Owner" row. If you've finished your tasks and want to help, ask the owner first — they might want to dispatch themselves, or hand it to you.

### Q: I want to skip Claude Code and just write this myself. Allowed?

Yes for tiny fixes, bug fixes with obvious cause, cross-domain work, and exploratory work. For everything else, dispatch a subagent — it's the team's default for a reason (consistency, audit trail, faster).

### Q: Claude Code didn't read the prototype JSX. What do I do?

Re-dispatch with an explicit instruction:

```
Read prototype/src/screens/discover.jsx in full BEFORE writing any Flutter
code. The SwipeCard component there is the visual spec.
```

If it still doesn't, check that the file exists and isn't gitignored.

### Q: I'm reviewing a PR and Claude flagged 4 things but I only see 2. What do I do?

Read Claude's flags carefully — they include file:line references. Open the file at those lines and check yourself. If Claude was right about all 4, request changes for all 4. If Claude was wrong about 2 (e.g., hallucinated), note that in your review and only request changes for the real issues.

### Q: I'm not sure if my change violates a locked decision. What do I do?

Use `grill-me` in Claude Code: `"grill me on whether this change violates any locked decision"`. It will interrogate the change with numbered questions.

### Q: The pinned message in `#pull-requests` is outdated. Who updates it?

`@KarozRose` (M5).

### Q: Can I work on Sundays?

No expectations. Sprint plan assumes weekday working hours.

### Q: I lost my Claude Code session and want to resume. What do I do?

```bash
cd ecoswap         # back to repo root
claude --resume    # opens session picker
```

Pick the session you were in. Context is preserved.

---

**Last updated:** Day 0 of Sprint 1.
**Maintained by:** M5 (`@KarozRose`).
**Questions or fixes:** open a `chore/` PR or ping in Discord.
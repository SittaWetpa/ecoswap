# WBS Dictionary
## Project: EcoSwap — Tinder-style swap app for second-hand items
**Tech Stack: Flutter (Dart) + Firebase (Authentication, Firestore, Storage, Cloud Functions) + bundled kongvut/thai-province-data JSON**

> **Implementation Reference (read before starting any task).** The Claude Design prototype is committed to the repo at `prototype/src/screens/`. Each WBS entry below has a **Prototype Reference** row in its metadata table pointing to the exact JSX file(s) the task implements. Workflow for every UI task:
>
> 1. Read the WBS entry (this file).
> 2. Open the JSX file(s) listed in **Prototype Reference** — they define layout, spacing, component composition, copy, and micro-interactions.
> 3. Read `docs/EcoSwap_Style_Guide.md` for design tokens (colours, typography, spacing scale).
> 4. Implement in Flutter, following the schemas and pseudocode in the WBS entry.
>
> The prototype is React+JSX, not Flutter — treat it as a visual and structural spec, not as code to port line-for-line. Re-implement the same component composition in Flutter widgets, using the design tokens from the Style Guide.


> Each entry covers: **Scope / Statement of Work**, **Deliverables**, **Acceptance**, **Associated Activities**, and (where applicable) **Testing** and **Schema** blocks.

---

## 📖 Term Glossary

| Term | Meaning |
|---|---|
| **Swap** | The user-facing word for an item exchange. Used in UI copy, marketing, and the app name. |
| **Trade** | The data-layer word for the same concept. Used in code, Firestore (`/trades/`), Cloud Functions, and this dictionary. Never appears in UI copy. |
| **Swipe** | A directional gesture on a discovery card. `right` = interest, `left` = pass. Stored in `/swipes/{swipeId}`. Never called "like" or "vote". |
| **Match** | A two-way swipe-right between two users, each with a declared desired item. One document in `/matches/{matchId}`. |
| **Item Picker** | The single-select modal that fires on swipe-right, forcing the swiper to pick one of the target user's items. Implements F16. |
| **Anonymous Interest** | The state after one user swipes right but before reciprocity. Target sees the swiper's card with a "Wants your X" badge (F18) but no name or photo. |
| **Proximity Bucket** | The 4-level distance model: `same_district` / `same_province` / `nearby_provinces` / `all_thailand`. Replaces GPS/kilometre distance. |
| **Home District** | The user's profile-set Thai district, stored as the six-string `homeDistrict` object (see schema in 3.6). No lat/lng. |
| **Nearby Provinces** | A hand-curated lookup table mapping each Thai province to its land-adjacent neighbours. Used for the `nearby_provinces` proximity bucket. |
| **Impact** | The per-user CO₂ and waste-diverted numbers derived from a completed trade. Calculated server-side in a Cloud Function. |
| **Intensity** | Kg of CO₂ embodied per kg of item, by category. See table in 11.1. |
| **Typical Weight** | The default kg used when a user uploads an item without specifying weight. See table in 11.1. |
| **status: active** | An item or match that is open and can still be acted on. |
| **status: traded** | An item that has been swapped (item.status). Hidden from all feeds. |
| **status: completed** | A match where the trade has been confirmed via QR (match.status). |
| **status: cancelled** | A match that was hard-cancelled because one of its items was traded elsewhere (match.status). |
| **Poster / Swiper** | The poster is the user whose card is being viewed; the swiper is the user doing the swiping. |
| **DEV-MODE** | A debug-only build path that bypasses QR scanning by allowing a JWT to be pasted into a text field. Gated by a build-time flag and disabled in release builds. |

---

> Full WBS structure, critical path, and team assignments live in **§7 and §6.1 of the EcoSwap Planning Package**. This dictionary is the implementation contract for each leaf task.

---

## Phase 1.0 — Project Management

---

### 1.1 Sprint Planning Meeting

| Field | Detail |
|---|---|
| **WBS Code** | 1.1 |
| **Type** | Work Package |
| **Requirement** | Sprint kickoff |
| **Owner** | M5 |
| **Prototype Reference** | N/A — no prototype surface (planning artefact) |

**Scope / Statement of Work**
Run a 2-hour Day-0 meeting to align the team on the 32 locked MVP functions (F01–F32), the 13 WBS workstreams, and individual task ownership per §6.1 of the planning doc. The meeting produces a written sprint plan that becomes the source of truth for the next 10 days.

**Deliverables**
- Sprint plan document committed to the repo at `/docs/sprint_plan.md`
- Confirmed task assignments per team member (M1–M5)
- List of any open questions that need answering before Day 2
- Scheduled time for the Wideband Delphi workshop (1.2) and the mid-sprint review (1.4)

**Acceptance**
- Every leaf task in §7 of the planning doc has exactly one named owner
- All five team members have read and signed off on the plan
- The plan is committed to git and linked from the README

**Associated Activities**
- Review the 32 MVP functions (F01–F32) and confirm no scope additions
- Walk through §7 WBS task list and assign owners
- Identify cross-task dependencies and flag risks
- Draft and commit the sprint plan markdown

---

### 1.2 Wideband Delphi Estimation Workshop

| Field | Detail |
|---|---|
| **WBS Code** | 1.2 |
| **Type** | Work Package |
| **Requirement** | Estimation |
| **Owner** | M5 (facilitator), all participate |
| **Prototype Reference** | N/A — no prototype surface (planning artefact) |

**Scope / Statement of Work**
Run a Wideband Delphi estimation session on Day 0 to produce story-point estimates for every leaf task in the WBS. Each team member estimates independently in two rounds, with discussion between rounds to converge. Output feeds Section 2 and the Gantt chart in Section 6.

**Deliverables**
- Filled estimation table with one story-point number per leaf task
- Round-by-round delta log showing convergence
- Identified outlier tasks (where round-2 variance > 50%) flagged for re-scoping or splitting
- Section 2 of the planning doc populated with results

**Acceptance**
- All ~60 leaf tasks have a final agreed estimate
- No leaf task remains with > 50% inter-estimator variance
- Results written into §2 of the planning package

**Associated Activities**
- Prepare estimation spreadsheet with all leaf tasks listed
- Run round 1 (silent independent estimation)
- Discuss outliers and edge cases
- Run round 2 (re-estimate after discussion)
- Compute convergence; flag remaining outliers
- Write up the section

---

### 1.3 Daily Standups

| Field | Detail |
|---|---|
| **WBS Code** | 1.3 |
| **Type** | Work Package |
| **Requirement** | Coordination |
| **Owner** | M5 (scribe), all attend |
| **Prototype Reference** | N/A — no prototype surface (process artefact) |

**Scope / Statement of Work**
Run a 15-minute standup every working day. Standard three-question format: what was done yesterday, what is planned today, what is blocked. Notes are committed to the repo so the team has a persistent record and blockers can be tracked across days.

**Deliverables**
- One markdown file per standup at `/docs/standups/YYYY-MM-DD.md`
- Each file lists the three answers per attendee plus a "blockers" section

**Acceptance**
- A standup file exists for every working day of the sprint
- Open blockers older than 24 hours are escalated in the next standup

**Associated Activities**
- Schedule the recurring 15-min slot
- Designate M5 as scribe (or rotating scribe)
- Commit notes immediately after each meeting

---

### 1.4 Mid-Sprint Review

| Field | Detail |
|---|---|
| **WBS Code** | 1.4 |
| **Type** | Work Package |
| **Requirement** | Mid-sprint checkpoint |
| **Owner** | M5 |
| **Prototype Reference** | N/A — no prototype surface (process artefact) |

**Scope / Statement of Work**
Hold a 1-hour review on Day 5 to assess progress against the sprint plan, re-prioritise remaining work, and trigger Should-Have demotions or scope cuts if any Must-Have function is at risk.

**Deliverables**
- Mid-sprint review minutes at `/docs/mid_sprint_review.md`
- Updated sprint plan if any scope changes were made
- Updated risk register (1.5)

**Acceptance**
- Status (on-track / at-risk / blocked) recorded for every WBS workstream
- Any scope changes signed off by all five team members

**Associated Activities**
- Review burn-down of estimated vs. completed story points
- Walk through risk register
- Decide on any cuts to Should-Have or simplifications to Must-Have
- Update plan and commit

---

### 1.5 Risk Register Maintenance

| Field | Detail |
|---|---|
| **WBS Code** | 1.5 |
| **Type** | Work Package |
| **Requirement** | Risk tracking |
| **Owner** | M5 |
| **Prototype Reference** | N/A — no prototype surface (process artefact) |

**Scope / Statement of Work**
Maintain a living risk register tracking known project risks, their probability, impact, and mitigation. Update at least every 3 days. Highest-priority risks at sprint start: QR Exchange complexity, Firebase Cloud Function cold-start latency, and Wideband Delphi variance on novel tasks.

**Deliverables**
- Risk register at `/docs/risk_register.md` with columns: ID, description, probability (L/M/H), impact (L/M/H), mitigation, owner, status

**Acceptance**
- Register has at least one entry per WBS workstream that touches Cloud Functions or external SDKs
- Updated at the start of each daily standup if any status changed

**Associated Activities**
- Seed the register from §7 critical-path commentary
- Add new risks as they emerge
- Close risks once their mitigation completes

---

### 1.6 Final Report Writing

| Field | Detail |
|---|---|
| **WBS Code** | 1.6 |
| **Type** | Work Package |
| **Requirement** | Course deliverable |
| **Owner** | M5 (lead), all contribute |
| **Prototype Reference** | N/A — no prototype surface (written report) |

**Scope / Statement of Work**
Write the final course report covering all 8 sections of the planning package, plus reflections on what worked, what slipped, and what was cut. Written in parallel with feature work from Day 6 onwards.

**Deliverables**
- Final report PDF at `/docs/final_report.pdf`
- Source markdown or docx at `/docs/final_report.md` or `.docx`

**Acceptance**
- Covers all 8 sections of the planning package
- Includes per-team-member reflection
- Submitted by the end of Day 10

**Associated Activities**
- Outline structure on Day 5
- Assign sections to team members
- Draft from Day 6
- Review and finalise on Day 9–10

---

## Phase 2.0 — Design and UX

---

### 2.1 Persona Finalization

| Field | Detail |
|---|---|
| **WBS Code** | 2.1 |
| **Type** | Work Package |
| **Requirement** | UX foundation |
| **Owner** | M5 |
| **Prototype Reference** | Personas inform every screen in `prototype/src/screens/`; no single file owns this |

**Scope / Statement of Work**
Finalise the three user personas already drafted in §3 of the planning package (Ploy the Thrifty Student, Fah the Eco-Conscious Office Worker, Beam the New Graduate). Each persona drives UI copy decisions, feature prioritisation, and the usability test scenarios in 2.6.

**Deliverables**
- Three persona cards (one per user type), each with: name, age range, occupation context, motivations, pain points, sample swap behaviour
- Personas referenced by name in 7.x usability test scripts

**Acceptance**
- Each persona maps to at least one usability test scenario in 2.6
- No persona references out-of-scope concepts (school name, verification status, activity status)

**Associated Activities**
- Pull existing persona text from planning doc §3
- Review for any out-of-scope references and remove
- Format as standalone reference cards in `/docs/personas.md`

---

### 2.2 User Journey Diagrams

| Field | Detail |
|---|---|
| **WBS Code** | 2.2 |
| **Type** | Work Package |
| **Requirement** | UX foundation |
| **Owner** | M5 |
| **Prototype Reference** | N/A — no prototype surface (journey diagrams are upstream) |

**Scope / Statement of Work**
Produce the as-is and to-be journey diagrams from §4 of the planning doc as polished visual assets. Each diagram shows the user's emotional state, touchpoints, and pain points across the swap discovery → match → exchange flow.

**Deliverables**
- Two diagrams (as-is, to-be) exported as PNG at `/docs/journey_as_is.png` and `/docs/journey_to_be.png`
- Source files (Miro, Figma, or equivalent) linked in `/docs/README.md`

**Acceptance**
- To-be journey reflects all 32 MVP functions
- No reference to GPS, km distance, or other out-of-scope features

**Associated Activities**
- Draft in a visual tool
- Review against §4 of the planning doc
- Export and commit

---

### 2.3 Lo-fi Wireframes

| Field | Detail |
|---|---|
| **WBS Code** | 2.3 |
| **Type** | Work Package |
| **Requirement** | UX foundation |
| **Owner** | M5, M3 assists |
| **Prototype Reference** | Lo-fi precursor to every screen in `prototype/src/screens/`; no live prototype binding |

**Scope / Statement of Work**
Produce 10 lo-fi wireframes covering the main screens: Splash, Sign Up, Profile Setup, Discover, User Detail, Item Picker, Match, Chat List, Chat, QR Show/Scan, Swap Confirmed, Impact Dashboard. Lo-fi is intentional — purpose is to lock structure before hi-fi.

**Deliverables**
- 10 wireframes exported as PNG at `/docs/wireframes/`
- One paragraph of structural notes per screen

**Acceptance**
- All MVP screens are covered
- District language used everywhere (no km, no lat/lng)
- No out-of-scope UI elements (age, verification badge, activity status)

**Associated Activities**
- Sketch on paper or Figma low-fidelity
- Review against the MVP function list
- Export and commit

---

### 2.4 Hi-fi Prototype in Claude Design

| Field | Detail |
|---|---|
| **WBS Code** | 2.4 |
| **Type** | Work Package |
| **Requirement** | UX foundation, design handoff |
| **Owner** | M5, M3 assists |
| **Prototype Reference** | Owns the entire `prototype/` tree — every file in `prototype/src/screens/` and shared components |

**Scope / Statement of Work**
Build the hi-fi clickable prototype in Claude Design covering every MVP screen. Prototype is the visual contract for the Flutter implementation — colours, typography, spacing, and component shapes are taken from it. Use the EcoSwap Style Guide (2.5) as the design token source of truth.

**Deliverables**
- Claude Design project covering: Splash, Auth, Profile Setup (3 steps), Discover, User Detail with item bottom sheet, Item Picker, Match, Chats, Match Chat, QR Show/Scan, Swap Confirmed, Impact Dashboard, My Items, Upload Item, Edit Item, Profile, Edit Profile
- Exported React+JSX bundle at `/design/ecoswap_prototype/`
- Screenshots of every screen at `/docs/screenshots/`

**Acceptance**
- All MVP screens implemented and clickable
- No out-of-scope UI (no age, no verification pill, no "active now", no km, no trust score, no trend arrows)
- Bilingual Thai-primary district picker present (e.g., "บางมด · Bang Mod, Bangkok")
- Item picker is single-select with F18 "Wants your X" badge
- Top-level screens (Profile, My Items, Impact) have title-only top bars (no cog/info icons)

**Associated Activities**
- Build screens in Claude Design using the Style Guide
- Wire up navigation flow
- Review each screen against the locked MVP function list
- Apply polish patches as feedback arrives
- Export bundle

---

### 2.5 Design System / Style Guide

| Field | Detail |
|---|---|
| **WBS Code** | 2.5 |
| **Type** | Work Package |
| **Requirement** | Design tokens |
| **Owner** | M5 |
| **Prototype Reference** | Style Guide at `docs/EcoSwap_Style_Guide.md` is the design-token source for every screen; no single file owns this |

**Scope / Statement of Work**
Maintain `EcoSwap_Style_Guide.md` as the single source of truth for design tokens (colours, typography, spacing, component variants). Includes a "things the app does not track" section mirroring §1.5 of the planning doc to prevent re-introduction of out-of-scope features.

**Deliverables**
- `EcoSwap_Style_Guide.md` with sections for: colour palette, typography scale, spacing scale, component library (cards, buttons, pills, inputs, bottom sheets), empty states, dummy data examples
- Explicit "things the app does not track" section listing: age/DOB, occupation, school, verification badges, activity status, GPS/km distance, star ratings, trust scores

**Acceptance**
- §11 dummy data contains no age column and no km distance
- §12 screen notes contain no trust score language
- "Does not track" section mirrors §1.5 of planning doc word-for-word on the key items

**Associated Activities**
- Reconciliation pass against planning doc §1.5 and §A.1
- Remove drift from earlier versions
- Verify EmptyState component wording matches §10 of the style guide

---

### 2.6 Usability Testing

| Field | Detail |
|---|---|
| **WBS Code** | 2.6 |
| **Type** | Work Package |
| **Requirement** | UX validation |
| **Owner** | M5 |
| **Prototype Reference** | Test plan exercises every screen in `prototype/src/screens/` |

**Scope / Statement of Work**
Run usability testing with 3 non-team users on Day 7. Each session is 30 minutes and covers: sign up, profile setup, discovery, swiping, item picker, match, chat, and (mocked) QR exchange. Findings are written up and feed into final polish during Day 8–9.

**Deliverables**
- Test script at `/docs/usability_test_script.md`
- One findings document per participant at `/docs/usability_findings_{1,2,3}.md`
- Consolidated action list of bugs and UX issues

**Acceptance**
- 3 non-team participants tested
- Each scenario from the script attempted by each participant
- Action list reviewed at Day 8 standup

**Associated Activities**
- Write script covering all three personas' core flows
- Recruit 3 participants
- Run sessions on Day 7
- Write up findings same day
- Prioritise fixes for Days 8–9

---

## Phase 3.0 — Backend Setup

---

### 3.1 Firebase Project Creation

| Field | Detail |
|---|---|
| **WBS Code** | 3.1 |
| **Type** | Work Package |
| **Requirement** | Infrastructure |
| **Owner** | M4 |
| **Prototype Reference** | N/A — no prototype surface (infrastructure) |

**Scope / Statement of Work**
Create the Firebase project in the Firebase Console, register the Flutter app for Android, download `google-services.json`, and wire it into the Flutter project. Set the project to Blaze plan (required for Cloud Functions).

**Deliverables**
- Firebase project named `ecoswap-{env}` (e.g., `ecoswap-dev`)
- Android app registered with package name `com.ecoswap.app`
- `google-services.json` committed to `/android/app/`
- Firebase Blaze (pay-as-you-go) plan enabled
- `firebase_core` package added to `pubspec.yaml`

**Acceptance**
- `flutter run` on an Android emulator successfully initialises Firebase with no errors
- Firebase Console shows the registered Android app

**Associated Activities**
- Create Firebase project in console
- Register Android app
- Download config file
- Add `firebase_core` to `pubspec.yaml` and run `flutter pub get`
- Initialise Firebase in `main.dart` with `await Firebase.initializeApp()`
- Commit and verify a teammate can clone and run

---

### 3.2 Firestore Security Rules

| Field | Detail |
|---|---|
| **WBS Code** | 3.2 |
| **Type** | Work Package |
| **Requirement** | Data security |
| **Owner** | M4 |
| **Prototype Reference** | N/A — no prototype surface (security rules) |

**Scope / Statement of Work**
Write Firestore security rules that enforce: only authenticated users can read or write; users can only edit their own documents in `/users/{uid}` and `/items/{itemId}` where `ownerId == uid`; `/swipes/`, `/matches/`, `/trades/`, and impact counter fields on `/users/` are write-restricted to Cloud Functions only (no client writes).

**Deliverables**
- `firestore.rules` file in repo root
- Deployed to Firebase via `firebase deploy --only firestore:rules`

**Acceptance**
- Unauthenticated client cannot read any collection
- Authenticated client A cannot write to user B's document
- Authenticated client cannot directly write to `/trades/` or `/users/{uid}.tradesCount`
- Authenticated client cannot write to `/items/{itemId}` unless `ownerId == request.auth.uid`

**Associated Activities**
- Draft `firestore.rules` covering all 6 collections
- Test against the Firebase Emulator Suite
- Deploy to dev project
- Document deny-by-default in repo README

**Schema (security rules sketch)**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == uid
                   && !affectsCounters(request.resource.data, resource.data);
    }
    match /items/{itemId} {
      allow read: if request.auth != null;
      allow create: if request.auth.uid == request.resource.data.ownerId;
      allow update, delete: if request.auth.uid == resource.data.ownerId;
    }
    match /swipes/{swipeId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == request.resource.data.swiperId;
    }
    match /matches/{matchId} {
      allow read: if request.auth.uid in resource.data.participants;
      allow write: if false; // Cloud Function only
    }
    match /trades/{tradeId} {
      allow read: if request.auth != null;
      allow write: if false; // Cloud Function only
    }
  }
}
```

**Testing**
- Emulator test: unauthenticated read of `/users/{any}` → denied
- Emulator test: user A writes to `/users/{B}` → denied
- Emulator test: user A increments own `tradesCount` → denied
- Emulator test: user A creates `/items/{x}` with `ownerId: A` → allowed
- Emulator test: user A creates `/items/{x}` with `ownerId: B` → denied

---

### 3.3 Firebase Auth Configuration

| Field | Detail |
|---|---|
| **WBS Code** | 3.3 |
| **Type** | Work Package |
| **Requirement** | F01, F02, F05 prerequisite |
| **Owner** | M1 |
| **Prototype Reference** | N/A — no prototype surface (Firebase config) |

**Scope / Statement of Work**
Enable Firebase Authentication in the Firebase Console with Email/Password as the only sign-in provider. Configure password rules (minimum 8 chars). Add the `firebase_auth` package to the Flutter project.

**Deliverables**
- Email/Password provider enabled in Firebase Console under Authentication
- `firebase_auth` package added to `pubspec.yaml`
- Password policy: minimum 8 characters (enforced client-side in 4.1 since Firebase Auth has limited server-side policy options for email/password)

**Acceptance**
- A test signup with valid email and 8+ char password succeeds via Firebase Console "Add User"
- The Flutter app can call `FirebaseAuth.instance.currentUser` without errors

**Associated Activities**
- Enable Email/Password sign-in in Firebase Console
- Add `firebase_auth` to `pubspec.yaml`
- Run `flutter pub get`
- Smoke-test by creating a test user in the console

---

### 3.4 Cloud Storage Bucket Setup

| Field | Detail |
|---|---|
| **WBS Code** | 3.4 |
| **Type** | Work Package |
| **Requirement** | F06 prerequisite |
| **Owner** | M4 |
| **Prototype Reference** | N/A — no prototype surface (Storage config) |

**Scope / Statement of Work**
Configure the default Cloud Storage bucket for the Firebase project. Write Storage security rules limiting writes to authenticated users and limiting file size to 2 MB per upload. Image compression to 1024px JPEG 75 is handled client-side in 6.1, not in a Storage Extension, to keep the dependency footprint small.

**Deliverables**
- Default Storage bucket enabled
- `storage.rules` file at repo root
- Bucket path convention: `/user_photos/{uid}.jpg` and `/item_photos/{itemId}.jpg`

**Acceptance**
- Unauthenticated upload denied
- Authenticated upload > 2 MB denied
- Authenticated user A cannot overwrite user B's photo

**Associated Activities**
- Enable Storage in Firebase Console
- Write `storage.rules`
- Deploy via `firebase deploy --only storage`

**Schema (storage rules)**
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /user_photos/{uid}.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == uid
                   && request.resource.size < 2 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
    match /item_photos/{itemId}.jpg {
      allow read: if request.auth != null;
      allow write: if request.auth != null
                   && request.resource.size < 2 * 1024 * 1024
                   && request.resource.contentType.matches('image/.*');
    }
  }
}
```

---

### 3.5 Cloud Functions Environment Setup

| Field | Detail |
|---|---|
| **WBS Code** | 3.5 |
| **Type** | Work Package |
| **Requirement** | F25, F28, F29 prerequisite |
| **Owner** | M4 |
| **Prototype Reference** | N/A — no prototype surface (Cloud Functions scaffolding) |

**Scope / Statement of Work**
Initialise the Cloud Functions environment using TypeScript. Configure the JWT signing secret in Secret Manager (never in code, never in `.env` committed to git). Set up the deploy pipeline so functions can be redeployed in under 2 minutes.

**Deliverables**
- `/functions/` directory with `package.json`, `tsconfig.json`, and `src/index.ts`
- TypeScript + ESLint configured
- JWT secret stored in Firebase Secret Manager as `JWT_SECRET`
- `firebase functions:secrets:set JWT_SECRET` documented in `/functions/README.md`
- Two function stubs: `issueQRToken` and `validateQRToken` (implementations in 10.1 and 10.2)
- Third function stub: `onTradeComplete` (implementation in 10.6)

**Acceptance**
- `firebase deploy --only functions` succeeds
- Function stubs can be invoked from the Functions Shell and return placeholder responses
- `JWT_SECRET` is readable inside a function via `defineSecret('JWT_SECRET').value()`

**Associated Activities**
- Run `firebase init functions` selecting TypeScript
- Install dependencies: `jsonwebtoken`, `firebase-admin`, `firebase-functions`
- Configure ESLint
- Set secret via CLI
- Write stubs with type signatures matching 10.1/10.2/10.6
- Deploy and smoke-test

---

### 3.6 Firestore Data Model Implementation

| Field | Detail |
|---|---|
| **WBS Code** | 3.6 |
| **Type** | Work Package |
| **Requirement** | All data-touching tasks |
| **Owner** | M1 + M4 |
| **Prototype Reference** | N/A — no prototype surface (Firestore data model); schemas in this entry are consumed by every UI entry below |

**Scope / Statement of Work**
Create the 6 Firestore collections and document their schemas in code as TypeScript types (for Cloud Functions) and Dart classes (for the Flutter app). `homeDistrict` is stored as a flat six-string object sourced from the bundled kongvut Thai district JSON; there are no GPS coordinates, centroids, or lat/lng fields anywhere. Denormalized counters live on `/users/` for cheap dashboard reads.

**Deliverables**
- TypeScript types at `/functions/src/types.ts`
- Dart classes at `/lib/models/`: `User`, `Item`, `Swipe`, `Match`, `Message`, `Trade`
- Seed script at `/scripts/seed_firestore.dart` that creates one of each document type for local emulator testing

**Acceptance**
- All 6 collections defined and writable from the seed script
- `homeDistrict` object has exactly the 6 string fields below, no extras
- Trust score field is NOT present on `/users/`
- Denormalized counters (`tradesCount`, `totalCo2Saved`, `totalWasteDiverted`) exist on `/users/` and default to 0

**Associated Activities**
- Write TypeScript interfaces
- Write Dart model classes with `fromJson` / `toJson`
- Write seed script
- Run against Firebase Emulator and verify documents created
- Smoke-test reads from Flutter

**Schema (`/users/{userId}`)**
```typescript
{
  email: string;
  displayName: string;
  photoUrl: string;
  homeDistrict: {
    provinceId: string;        // e.g., "10" (Bangkok)
    provinceNameTh: string;    // e.g., "กรุงเทพมหานคร"
    provinceNameEn: string;    // e.g., "Bangkok"
    districtId: string;        // e.g., "1023"
    districtNameTh: string;    // e.g., "บางมด"
    districtNameEn: string;    // e.g., "Bang Mod"
  };
  bio: string;                 // max 140 chars
  createdAt: Timestamp;
  tradesCount: number;         // denormalized
  totalCo2Saved: number;       // kg, denormalized
  totalWasteDiverted: number;  // kg, denormalized
}
```

**Schema (`/items/{itemId}`)**
```typescript
{
  ownerId: string;
  name: string;
  category: 'clothing' | 'books' | 'kitchenware' | 'household'
          | 'electronics' | 'furniture' | 'other';
  condition: 'new' | 'like-new' | 'good' | 'used';
  weight: number | null;       // kg, optional; null means use category typical
  description: string | null;
  wants: string | null;
  photoUrl: string;
  status: 'active' | 'traded' | 'deleted';
  createdAt: Timestamp;
}
```

**Schema (`/swipes/{swipeId}`)**
```typescript
{
  swiperId: string;
  targetUserId: string;
  desiredItemId: string;       // single-select, per F16
  direction: 'right' | 'left';
  createdAt: Timestamp;
}
```

**Schema (`/matches/{matchId}`)**
```typescript
{
  userAId: string;
  userBId: string;
  userAWantsItemId: string;    // what A picked of B's items
  userBWantsItemId: string;    // what B picked of A's items
  status: 'active' | 'completed' | 'cancelled';
  participants: string[];      // [userAId, userBId] for security rules
  createdAt: Timestamp;
  completedAt: Timestamp | null;
}
```

**Schema (`/matches/{matchId}/messages/{messageId}`)**
```typescript
{
  senderId: string;
  text: string;
  sentAt: Timestamp;           // serverTimestamp()
  readBy: string[];
}
```

**Schema (`/trades/{tradeId}`)**
```typescript
{
  matchId: string;
  completedAt: Timestamp;
  jwtTokenHash: string;        // single-use marker, SHA-256 of the token
  impact: {
    userAGains: { userId: string; co2Saved: number; wasteDiverted: number; };
    userBGains: { userId: string; co2Saved: number; wasteDiverted: number; };
  };
  itemsExchanged: { fromA: string; fromB: string; };
}
```

**Testing**
- Seed script creates one document per collection without throwing
- `User.fromJson()` round-trips through `toJson()` with no data loss
- `Item.fromJson()` correctly handles `weight: null`
- TypeScript compiler accepts all 6 type definitions with `strict: true`

---

## Phase 4.0 — Authentication

---

### 4.1 Email and Password Signup Flow

| Field | Detail |
|---|---|
| **WBS Code** | 4.1 |
| **Type** | Work Package |
| **Requirement** | F01 |
| **Owner** | M1 |
| **Prototype Reference** | `prototype/src/screens/auth.jsx` — `AuthScreen` in `mode='signup'` (owns signup form); `prototype/src/screens/splash.jsx` — `SplashScreen` (host — routing only, screen owned by 2.4) |

**Scope / Statement of Work**
Implement the signup screen and `AuthService.signUp()` wrapping `FirebaseAuth.instance.createUserWithEmailAndPassword()`. Validate email format and 8-char minimum password client-side. On success, create the corresponding `/users/{uid}` document with empty profile fields and counters defaulted to 0; the user is then routed to Profile Setup (5.x) to fill in display name, photo, district, and bio.

**Deliverables**
- `lib/services/auth_service.dart` with the `signUp(email, password)` method
- `lib/screens/auth/signup_screen.dart` with email + password fields and validation
- On successful signup, a new document at `/users/{uid}` with `tradesCount: 0`, `totalCo2Saved: 0`, `totalWasteDiverted: 0` and other fields empty/null pending Profile Setup

**Acceptance**
- A new user can sign up, the Firebase Auth user is created, and a `/users/{uid}` document exists with the three counter fields set to 0
- Email format validation rejects malformed input client-side before calling Firebase
- Password < 8 chars rejected client-side with a clear error message
- Firebase Auth errors (email in use, network failure) surface to the user with friendly text

**Associated Activities**
- Create `auth_service.dart` with `FirebaseAuth.instance` reference
- Implement `signUp(email, password)` returning a `User?` and throwing typed exceptions on failure
- Build the signup screen with TextFields, validation, loading state, and error display
- On success, write the `/users/{uid}` stub document
- Navigate to Profile Setup step 1

**Testing**
- Unit test: `signUp()` with valid email and 8+ char password → calls `createUserWithEmailAndPassword`, creates `/users/{uid}` doc with all 3 counters at 0
- Unit test: `signUp()` with invalid email format → throws `InvalidEmailException`, does NOT call Firebase
- Unit test: `signUp()` with password < 8 chars → throws `WeakPasswordException`, does NOT call Firebase
- Widget test: signup screen shows error when Firebase returns `email-already-in-use`

---

### 4.2 Login Flow and Token Persistence

| Field | Detail |
|---|---|
| **WBS Code** | 4.2 |
| **Type** | Work Package |
| **Requirement** | F02 |
| **Owner** | M1 |
| **Prototype Reference** | `prototype/src/screens/auth.jsx` — `AuthScreen` in `mode='signin'` (owns signin form and mode toggle); app-level route guard (owns, no JSX) |

**Scope / Statement of Work**
Implement the login screen and `AuthService.signIn()` wrapping `FirebaseAuth.instance.signInWithEmailAndPassword()`. Firebase Auth persists tokens automatically via `firebase_auth`; the app uses `authStateChanges()` to drive routing so a logged-in user lands on Discover after a cold start.

> **Decision change (product):** the "Forgot password?" link was **removed** from the login screen. Password reset is not implemented (it was never in scope), so the link was a dead no-op that implied a feature we don't have. Do not re-add it without also implementing the reset flow.

**Deliverables**
- `signIn(email, password)` method on `AuthService`
- `lib/screens/auth/login_screen.dart`
- Route guard at `lib/app.dart` that listens to `authStateChanges()` and routes to either Discover or the Auth flow

**Acceptance**
- A previously signed-up user can log in
- After app restart, an already-logged-in user lands on Discover without re-entering credentials
- Wrong password surfaces a friendly error
- Loading state visible during the auth request

**Associated Activities**
- Implement `signIn(email, password)` on `AuthService`
- Build login screen
- Wire `StreamBuilder<User?>` listening to `authStateChanges()` at app root
- Smoke-test cold-start with logged-in user

**Testing**
- Unit test: `signIn()` with correct credentials → returns User
- Unit test: `signIn()` with wrong password → throws `WrongPasswordException`
- Integration test: app restart after login lands on Discover

---

### 4.3 Logout

| Field | Detail |
|---|---|
| **WBS Code** | 4.3 |
| **Type** | Work Package |
| **Requirement** | F05 |
| **Owner** | M1 |
| **Prototype Reference** | `prototype/src/screens/profile.jsx` — Logout button + confirmation dialog (owns the button and dialog; rest of `ProfileScreen` owned by 5.4) |

**Scope / Statement of Work**
Implement a logout action on the Profile screen that calls `AuthService.signOut()`, which delegates to `FirebaseAuth.instance.signOut()`. The route guard from 4.2 then routes the now-unauthenticated user to Login.

**Deliverables**
- `signOut()` method on `AuthService`
- Logout button on `lib/screens/profile/profile_screen.dart`
- Confirmation dialog before signing out

**Acceptance**
- Tapping logout shows a confirmation dialog
- Confirming sign-out clears Firebase Auth state and routes to Login
- Cancel keeps the user logged in

**Associated Activities**
- Implement `signOut()`
- Add button to Profile screen
- Wire confirmation dialog

**Testing**
- Unit test: `signOut()` calls `FirebaseAuth.instance.signOut()`
- Widget test: tapping logout button shows confirmation dialog

---

### 4.4 Auth State Management in Flutter

| Field | Detail |
|---|---|
| **WBS Code** | 4.4 |
| **Type** | Work Package |
| **Requirement** | All auth-gated screens |
| **Owner** | M1 |
| **Prototype Reference** | N/A — no prototype surface (state-management plumbing); affects every authenticated screen |

**Scope / Statement of Work**
Set up app-wide auth state management using a `Provider` or `Riverpod` `StreamProvider` listening to `FirebaseAuth.instance.authStateChanges()`. All screens that require auth read this provider; the root `MaterialApp` uses it to decide whether to show the Auth flow or the main app.

**Deliverables**
- `lib/providers/auth_provider.dart` exposing `currentUser` as a stream and a sync getter
- All authenticated screens read from this provider rather than calling `FirebaseAuth.instance` directly

**Acceptance**
- Logging in or out triggers an immediate UI rebuild at the root
- No screen reads `FirebaseAuth.instance.currentUser` directly except the provider itself

**Associated Activities**
- Pick state management library (Provider or Riverpod — confirm in sprint planning)
- Implement the auth state provider
- Refactor any direct `FirebaseAuth.instance` reads in screens

**Testing**
- Widget test: provider emits new value when `signOut()` is called
- Widget test: a screen reading the provider rebuilds when auth state changes

---

## Phase 5.0 — Profile

---

### 5.1 Profile Creation: Name and Photo Upload

| Field | Detail |
|---|---|
| **WBS Code** | 5.1 |
| **Type** | Work Package |
| **Requirement** | F03 (partial) |
| **Owner** | M1 |
| **Prototype Reference** | `prototype/src/screens/setup.jsx` — `SetupScreen` step 1 with `PhotoUpload` atom (owns); `prototype/src/screens/editprofile.jsx` — `EditableAvatar` + name field (contributes — `EditProfileScreen` host owned by 5.4) |

**Scope / Statement of Work**
Build Profile Setup step 1: capture display name (required, 1–40 chars) and profile photo (optional). The photo is picked via `image_picker`, compressed to 1024px JPEG 75 using `flutter_image_compress`, uploaded to `/user_photos/{uid}.jpg` in Cloud Storage, and the resulting URL written to `/users/{uid}.photoUrl`.

**Deliverables**
- `lib/screens/profile_setup/step1_name_photo.dart`
- `lib/services/photo_service.dart` with `pickAndUpload({required String storagePath})` method
- Photo compression to 1024px JPEG 75 before upload

**Acceptance**
- User can pick a photo from gallery (camera optional in MVP)
- Uploaded photo is < 1 MB after compression
- Display name validates 1–40 chars
- Skipping the photo is allowed; `photoUrl` remains empty string

**Associated Activities**
- Add `image_picker` and `flutter_image_compress` to `pubspec.yaml`
- Implement `photo_service.dart`
- Build step 1 screen
- Wire upload progress indicator

**Testing**
- Unit test: `PhotoService.pickAndUpload()` compresses image below 1 MB before upload
- Widget test: display name field rejects empty string
- Widget test: display name field rejects > 40 chars

---

### 5.2 Home District Picker

| Field | Detail |
|---|---|
| **WBS Code** | 5.2 |
| **Type** | Work Package |
| **Requirement** | F03 (district) |
| **Owner** | M3 |
| **Prototype Reference** | `prototype/src/screens/setup.jsx` — `AreaSearch` with `AreaSearching` + `AreaSelected` states (owns); `prototype/src/screens/editprofile.jsx` — `DistrictRow` + picker (contributes) |

**Scope / Statement of Work**
Bundle `kongvut/thai-province-data` JSON (~1 MB, 928 districts, 77 provinces) as a Flutter asset. Build a searchable bilingual dropdown that lets the user type in Thai or English to filter results. Display format: `"บางมด · Bang Mod, Bangkok"`. On selection, write the six-string `homeDistrict` object to `/users/{uid}`.

**Deliverables**
- Asset file at `assets/data/thai_provinces.json` from kongvut/thai-province-data
- `lib/services/district_service.dart` with `loadAll()`, `searchByName(query)` methods
- `lib/widgets/district_picker.dart` — searchable bottom-sheet widget
- Selection persists all six fields per the homeDistrict schema in 3.6

**Acceptance**
- Typing "bang" in English filters to districts containing "bang" in English name
- Typing "บาง" in Thai filters to districts containing "บาง" in Thai name
- Selecting a district writes all six fields to `/users/{uid}.homeDistrict` — no missing fields, no extra fields
- Display format is `Thai · English, Province` (Thai primary)

**Associated Activities**
- Download `provinces.json` and `districts.json` from kongvut/thai-province-data
- Combine into a single file flattening district → province lookups
- Implement `DistrictService` with in-memory search
- Build picker UI with `TextField` + `ListView.builder`
- Wire to step 2 of profile setup

**Schema (district JSON shape after flattening)**
```json
[
  {
    "provinceId": "10",
    "provinceNameTh": "กรุงเทพมหานคร",
    "provinceNameEn": "Bangkok",
    "districtId": "1023",
    "districtNameTh": "บางมด",
    "districtNameEn": "Bang Mod"
  }
]
```

**Testing**
- Unit test: `DistrictService.searchByName('bang')` returns at least one district with "bang" in English name
- Unit test: `DistrictService.searchByName('บาง')` returns at least one district with "บาง" in Thai name
- Unit test: selecting a district produces an object with all 6 string fields populated
- Widget test: picker debounces input by 200ms to avoid filter thrash

---

### 5.3 Bio Editor

| Field | Detail |
|---|---|
| **WBS Code** | 5.3 |
| **Type** | Work Package |
| **Requirement** | F03 (bio) |
| **Owner** | M1 |
| **Prototype Reference** | `prototype/src/screens/setup.jsx` — step 3 bio editor (owns); `prototype/src/screens/editprofile.jsx` — `EpTextArea` bio field (contributes) |

**Scope / Statement of Work**
Build Profile Setup step 3: a 140-character bio editor with live character counter. Hard cap enforced both client-side (input formatter) and via the data model. Empty bio is allowed.

**Deliverables**
- `lib/screens/profile_setup/step3_bio.dart`
- Live character counter "X / 140"
- `LengthLimitingTextInputFormatter(140)` on the field

**Acceptance**
- Typing past 140 chars is impossible
- Counter updates as user types
- Empty bio is allowed and writes empty string to `/users/{uid}.bio`

**Associated Activities**
- Build step 3 screen
- Wire counter and limit formatter
- On completion, finalise the `/users/{uid}` document with all fields populated

**Testing**
- Widget test: typing 141 chars is truncated at 140
- Widget test: counter updates correctly at 0, 70, 140

---

### 5.4 Profile View and Edit Screen

| Field | Detail |
|---|---|
| **WBS Code** | 5.4 |
| **Type** | Work Package |
| **Requirement** | F04 |
| **Owner** | M1 |
| **Prototype Reference** | `prototype/src/screens/profile.jsx` — `ProfileScreen` + `SummaryStat` strip layout (host + owns layout); `prototype/src/screens/editprofile.jsx` — `EditProfileScreen` full screen (owns host and save flow; field atoms contributed by 5.1/5.2/5.3); 11.4 contributes the impact strip values; 4.3 contributes the Logout button |

**Scope / Statement of Work**
Build the Profile screen showing the user's photo, display name, bio, district pill (Thai · English), 3-stat impact summary (swaps / CO₂ / waste, populated by 11.4), and an Edit Profile button. Edit screen reuses the components from 5.1–5.3.

> **Added feature — How-It-Works tutorial:** the Profile screen hosts a "How it works" row that replays the first-run tutorial carousel. See the **How-It-Works Tutorial** note at the end of Phase 5 for the full feature description.

**Deliverables**
- `lib/screens/profile/profile_screen.dart` — view mode
- `lib/screens/profile/edit_profile_screen.dart` — edit mode
- "How it works" row that opens `TutorialScreen` in replay mode (see the tutorial note below)
- Top bar shows title only (no cog, no info icon, no settings)

**Acceptance**
- View mode displays all profile fields plus impact stats
- Edit mode is pre-filled with current values
- Save writes changes to `/users/{uid}` and pops back to view
- District display format matches 5.2 ("Thai · English, Province")
- No age, no verification badge, no activity status anywhere

**Associated Activities**
- Build view screen
- Build edit screen reusing district picker, bio editor, and photo upload components
- Wire save flow

**Testing**
- Widget test: view screen renders all 6 fields
- Widget test: edit screen pre-fills correctly from a fixture user
- Widget test: save triggers a Firestore update with the merged document
- Widget test: "How it works" row is shown and invokes its callback

---

### 5.5 How-It-Works Tutorial (added feature)

| Field | Detail |
|---|---|
| **Type** | Added feature (not in the original WBS; introduced by product request) |
| **Owner** | M3 |
| **Prototype Reference** | N/A — no prototype surface; styled with the Style Guide tokens, visual language echoes `splash.jsx` |

**Scope / Statement of Work**
A full-screen swipeable carousel explaining the four-step EcoSwap loop: (1) Discover & swipe, (2) Match & chat, (3) Meet & swap (QR), (4) Track your impact. Shown **once automatically** on first run (the first time an authenticated user lands on `MainShell`), and **replayable any time** from the "How it works" row on Profile (5.4). One reusable widget serves both entry points.

**Deliverables**
- `lib/screens/tutorial/tutorial_screen.dart` — `TutorialScreen({onDone, showSkip})` carousel + `hasSeenTutorial()` / `markTutorialSeen()` persistence helpers (SharedPreferences, key `has_seen_tutorial_v1`)
- First-run trigger in `lib/screens/shell/main_shell.dart` (post-frame, gated on `tabOverrides == null` so tests are unaffected; persists the seen flag on dismiss)
- Replay entry from `ProfileScreen.onHowItWorks` (5.4)

**Acceptance**
- First-run: carousel auto-shows once, then never again (flag persisted)
- Replay from Profile works regardless of the flag
- First-run shows "Skip"; replay shows a close (X); both dismiss the screen
- Last slide's CTA reads "Get started" and dismisses
- Copy honours locked vocabulary ("Swap"/"swipe"), no GPS/km/age/verified/activity-status language

**Testing**
- Widget test: renders first slide; "Next" advances; last slide shows "Get started" → `onDone`
- Widget test: first-run shows Skip (→ `onDone`), no close X; replay shows close X (→ `onDone`), no Skip
- Test: `hasSeenTutorial()`/`markTutorialSeen()` persistence round-trip
- Widget test (5.4): Profile "How it works" row invokes its callback

---

## Phase 6.0 — Item Management

---

### 6.1 Image Picker Integration and Compression

| Field | Detail |
|---|---|
| **WBS Code** | 6.1 |
| **Type** | Work Package |
| **Requirement** | F06 (image) |
| **Owner** | M2 |
| **Prototype Reference** | `prototype/src/screens/upload.jsx` — `PhotoField` widget (owns); reused by 6.4 Edit Item and by 5.1 profile photo |

**Scope / Statement of Work**
Reuse the `PhotoService` from 5.1 to pick and upload item photos to `/item_photos/{itemId}.jpg`. Items are limited to one photo in MVP (multi-image is Should-Have F37). Compression to 1024px JPEG 75 ensures the post-compression file is < 1 MB.

**Deliverables**
- Reuse `lib/services/photo_service.dart` with `pickAndUpload(storagePath: 'item_photos/$itemId.jpg')`
- Integration into the Upload Item screen (6.2)

**Acceptance**
- Photo picked, compressed, and uploaded successfully
- Returned URL stored in `/items/{itemId}.photoUrl`
- Storage bucket file size always < 1 MB

**Associated Activities**
- Wire `PhotoService` into upload flow
- Show upload progress indicator
- Handle upload errors with retry option

**Testing**
- Unit test: upload to `/item_photos/{itemId}.jpg` results in file < 1 MB
- Integration test: full upload flow writes URL to Firestore item doc

---

### 6.2 Upload Item Form

| Field | Detail |
|---|---|
| **WBS Code** | 6.2 |
| **Type** | Work Package |
| **Requirement** | F06 |
| **Owner** | M2 |
| **Prototype Reference** | `prototype/src/screens/upload.jsx` — full Upload Item form (owns): `FieldLabel`, `TextField`, `TextArea`, `PhotoField`, `ConditionPills`, `CategoryRow`, weight field, wants field |

**Scope / Statement of Work**
Build the Upload Item screen with fields: photo (required, 6.1), name (required, 1–60 chars), category (required, 7-option dropdown), condition (required, 4-option dropdown), weight in kg (optional decimal, defaults to category typical), description (optional, max 280 chars), wants (optional, max 140 chars). On submit, write to `/items/{itemId}` with `status: 'active'` and `ownerId: currentUid`.

**Deliverables**
- `lib/screens/items/upload_item_screen.dart`
- Form validation matching the schema in 3.6
- 7 categories rendered as a dropdown: clothing, books, kitchenware, household, electronics, furniture, other
- 4 conditions rendered as a dropdown: new, like-new, good, used
- Weight field accepts decimal kg, optional, with placeholder text showing category typical (e.g., "0.5 kg typical for clothing")

**Acceptance**
- All required fields validated before submit
- Submit creates `/items/{itemId}` with all schema fields populated
- Weight left blank stores `null` (NOT the typical weight — the fallback happens at impact calculation time, see 11.1)
- Status always written as `'active'` on creation
- All 7 categories selectable; all 4 conditions selectable

**Associated Activities**
- Build form with all 7 fields
- Implement category and condition dropdowns
- Wire submit to Firestore write
- Show success state and navigate to My Items

**Testing**
- Widget test: submit with missing required field shows validation error
- Widget test: submit with all fields creates Firestore doc with correct shape
- Widget test: weight left blank writes `null` to Firestore
- Widget test: each of the 7 categories produces a valid document

---

### 6.3 Item List View (My Items)

| Field | Detail |
|---|---|
| **WBS Code** | 6.3 |
| **Type** | Work Package |
| **Requirement** | F07 |
| **Owner** | M2 |
| **Prototype Reference** | `prototype/src/screens/myitems.jsx` — `MyItemsScreen` 2-col grid + floating add button + empty state (owns) |

**Scope / Statement of Work**
Build the My Items screen showing all items owned by the current user, filtered by `ownerId == currentUid` and `status != 'deleted'`. Items are grouped or labelled by status: active vs traded. Tap an item to edit (6.4); long-press to delete (6.4). Top bar shows title only.

> **Decision change (product):** **traded items are view-only** — they cannot be edited or deleted. A traded tile is dimmed with the "Traded" pill, exposes no edit button, and tapping it does nothing (the edit screen, which also hosts delete, is the only mutation path and is gated off). Editing/deleting a completed trade's item would corrupt the trade record. Only active items navigate to Edit Item (6.4).

**Deliverables**
- `lib/screens/items/my_items_screen.dart`
- Firestore query: `items.where('ownerId', '==', uid).where('status', '!=', 'deleted')`
- Visual distinction between `active` and `traded` items (e.g., traded items are dimmed with a pill)

**Acceptance**
- All non-deleted items for the current user displayed
- Active and traded visually distinguished
- Tap on an **active** item navigates to Edit Item (6.4); traded items are view-only (no edit/delete affordance)
- Empty state shown when user has no items
- Top bar has only the title (no cog, no info)

**Associated Activities**
- Build screen with `StreamBuilder` on the items query
- Build item tile widget
- Wire navigation to Edit Item
- Build empty state

**Testing**
- Widget test: user with 3 active and 1 traded sees 4 items, traded dimmed
- Widget test: user with 0 items sees empty state
- Widget test: deleted items do not appear

---

### 6.4 Item Edit and Delete

| Field | Detail |
|---|---|
| **WBS Code** | 6.4 |
| **Type** | Work Package |
| **Requirement** | F08, F09 |
| **Owner** | M2 |
| **Prototype Reference** | `prototype/src/screens/upload.jsx` — Upload form reused in edit mode (owns the edit-mode wiring); delete confirmation dialog (owns); reuses every atom from 6.2 |

**Scope / Statement of Work**
Edit screen reuses the Upload Item form (6.2) pre-filled with the existing item's values. Delete is a soft delete: sets `status: 'deleted'` rather than removing the document (preserves historical references in `/matches/` and `/trades/`). Active swipes referencing a deleted item are NOT auto-cancelled — only swipes referencing TRADED items are cancelled (see 8.5).

**Deliverables**
- `lib/screens/items/edit_item_screen.dart`
- Delete confirmation dialog
- Soft delete: write `status: 'deleted'` on the item document

**Acceptance**
- Edit pre-fills all fields correctly
- Save writes changes to Firestore
- Delete shows confirmation, then writes `status: 'deleted'`
- Deleted items disappear from My Items and from all discovery feeds

**Associated Activities**
- Build edit screen reusing upload form components
- Wire delete confirmation
- Implement soft delete

**Testing**
- Widget test: edit pre-fills correctly from a fixture item
- Widget test: save triggers Firestore update with merged document
- Widget test: delete with confirmation writes `status: 'deleted'`
- Widget test: delete with cancel does nothing

---

### 6.5 Item Status Lifecycle

| Field | Detail |
|---|---|
| **WBS Code** | 6.5 |
| **Type** | Work Package |
| **Requirement** | F10 |
| **Owner** | M2 |
| **Prototype Reference** | N/A — no prototype surface (status transition logic); affects visibility of items in Discover, User Detail, Item Picker, My Items |

**Scope / Statement of Work**
Items move through three states: `active` → `traded` (on successful QR exchange, handled by 10.6 Cloud Function) → never returns to active. `deleted` is a separate terminal state (set in 6.4). Items with `status != 'active'` are excluded from all discovery feeds (handled in 7.2) and from match creation (handled in 8.3).

**Deliverables**
- Status transitions enforced by Cloud Function (10.6) on the `traded` side
- Soft delete in 6.4 handles the `deleted` side
- Centralised query helper `lib/services/item_service.dart` with `activeItemsForUser(uid)` that filters by `status: 'active'`

**Acceptance**
- An item with `status: 'traded'` does not appear in any feed
- An item with `status: 'deleted'` does not appear in any feed
- Status transitions are one-way (no UI to "un-trade" or "un-delete")
- Cloud Function (10.6) is the only path that writes `status: 'traded'`

**Associated Activities**
- Implement `item_service.dart` query helper
- Audit all feed queries to use the helper
- Confirm 10.6 Cloud Function is the only client of the `status: 'traded'` write

**Testing**
- Unit test: `activeItemsForUser()` excludes traded and deleted items
- Integration test: completing a trade via 10.6 flips both items to `status: 'traded'`

---

## Phase 7.0 — Discovery and Swipe

---

### 7.1 Proximity Scoring

| Field | Detail |
|---|---|
| **WBS Code** | 7.1 |
| **Type** | Work Package |
| **Requirement** | F11 (proximity) |
| **Owner** | M3 |
| **Prototype Reference** | N/A — no prototype surface (proximity scoring logic); output consumed by 7.2 feed query |

**Scope / Statement of Work**
Implement bucket-based proximity scoring with no GPS, no lat/lng, no kilometre math. Two users are scored by comparing `homeDistrict` fields and consulting a hand-curated `nearbyProvinces` lookup table. The output is one of four bucket labels: `same_district` (most relevant) → `same_province` → `nearby_provinces` → `all_thailand` (least relevant).

**Deliverables**
- `lib/services/proximity_service.dart` with `bucketFor(User a, User b)` returning one of the four enum values
- `assets/data/nearby_provinces.json` — hand-curated map from `provinceId` to list of land-adjacent `provinceId` values, covering all 77 provinces
- Unit test fixture covering at least Bangkok, Chiang Mai, and Phuket

**Acceptance**
- Two users with identical `districtId` → `same_district`
- Two users with same `provinceId` but different `districtId` → `same_province`
- Two users where B's `provinceId` is in A's `nearbyProvinces[A.provinceId]` → `nearby_provinces`
- Otherwise → `all_thailand`
- All 77 provinces have an entry in `nearby_provinces.json`

**Associated Activities**
- Hand-curate the nearby-province table from a map of Thailand
- Implement `ProximityService.bucketFor()`
- Write the unit test fixture

**Schema (`nearby_provinces.json`)**
```json
{
  "10": ["11", "12", "13", "73", "74"],
  "_comment": "10=Bangkok, neighbours: Nonthaburi, Pathum Thani, Samut Prakan, Samut Sakhon, Nakhon Pathom"
}
```

**Pseudocode (proximity bucket)**
```dart
ProximityBucket bucketFor(User a, User b) {
  if (a.homeDistrict.districtId == b.homeDistrict.districtId) {
    return ProximityBucket.sameDistrict;
  }
  if (a.homeDistrict.provinceId == b.homeDistrict.provinceId) {
    return ProximityBucket.sameProvince;
  }
  final neighbours = nearbyProvinces[a.homeDistrict.provinceId] ?? [];
  if (neighbours.contains(b.homeDistrict.provinceId)) {
    return ProximityBucket.nearbyProvinces;
  }
  return ProximityBucket.allThailand;
}
```

**Testing**
- Unit test: same district → `sameDistrict`
- Unit test: same province, different district → `sameProvince`
- Unit test: Bangkok user vs. Nonthaburi user → `nearbyProvinces`
- Unit test: Bangkok user vs. Phuket user → `allThailand`
- Unit test: every province in `nearby_provinces.json` has at least one neighbour entry (sanity check on the data)
- Unit test: `bucketFor()` is symmetric — `bucketFor(a, b) == bucketFor(b, a)` for `sameDistrict` and `sameProvince` buckets

---

### 7.2 Feed Query

| Field | Detail |
|---|---|
| **WBS Code** | 7.2 |
| **Type** | Work Package |
| **Requirement** | F11 |
| **Owner** | M3 |
| **Prototype Reference** | N/A — no prototype surface (Firestore query); output consumed by 7.3 swipe card stack |

**Scope / Statement of Work**
Build the feed query that returns candidate users for the swipe deck, given the current user's selected proximity filter (7.4). Excludes self, anyone the current user has already swiped on, and anyone with zero active items. Firestore does not support efficient distance queries, so the approach is: query a reasonable candidate set (e.g., all users with at least one active item from the same province or nearby provinces), then filter client-side by proximity bucket.

> **Decision (product) — re-discovery after a completed trade (#3):** the swipe-exclusion is keyed on the `/swipes/` doc, so a person is hidden only while a swipe record for them exists. After a **completed trade** between two users, WBS 8.5 (`onItemTraded`) sweeps both mutual swipe docs (their `desiredItemId` is exactly the traded item), which makes each user eligible to rediscover the other — gated, as always, by the counterparty still having ≥ 1 active item. Re-discovery does **not** happen after a mere left-swipe (pass) or right-swipe with no trade: those swipe records persist, so a pass keeps meaning "don't show me this person." This is the intended behaviour, not a bug — do not "fix" re-appearance of a past trade partner.

**Deliverables**
- `lib/services/feed_service.dart` with `candidatesForUser(currentUser, ProximityBucket maxBucket)` returning a `List<User>`
- Internal logic: query `/users/` paginated, filter by proximity bucket ≤ maxBucket, exclude self and already-swiped, exclude users with zero active items

**Acceptance**
- Current user never appears in their own feed
- Already-swiped users never re-appear
- Users with no active items are excluded
- Proximity filter setting actually changes the result set
- Query returns within ~1 second for a realistic dataset (< 1000 users)

**Associated Activities**
- Fetch already-swiped user IDs into a Set
- Fetch candidate users from Firestore
- Filter client-side using `ProximityService.bucketFor()` (7.1)
- Filter out users with zero active items
- Order by bucket precedence (closer first)

**Pseudocode**
```dart
Future<List<User>> candidatesForUser(User me, ProximityBucket maxBucket) async {
  final swipedIds = await _alreadySwipedIds(me.uid);
  final allUsers = await _fetchCandidateUsers();
  return allUsers
    .where((u) => u.uid != me.uid)
    .where((u) => !swipedIds.contains(u.uid))
    .where((u) => proximityService.bucketFor(me, u).index <= maxBucket.index)
    .where((u) => _hasActiveItems(u.uid))
    .toList()..sort((a, b) =>
      proximityService.bucketFor(me, a).index
        .compareTo(proximityService.bucketFor(me, b).index));
}
```

**Testing**
- Unit test: self is excluded from results
- Unit test: already-swiped user is excluded
- Unit test: user with 0 active items is excluded
- Unit test: changing `maxBucket` from `sameDistrict` to `allThailand` increases result count
- Unit test: results sorted by bucket precedence

---

### 7.3 Swipe Card UI

| Field | Detail |
|---|---|
| **WBS Code** | 7.3 |
| **Type** | Work Package |
| **Requirement** | F13 |
| **Owner** | M3 |
| **Prototype Reference** | `prototype/src/screens/discover.jsx` — `SwipeCard` component (owns); `DiscoverScreen` host (host — also hosts 7.4 and 7.6) |

**Scope / Statement of Work**
Build the swipe card stack UI using `appinio_swiper` (or equivalent). Each card shows: user photo, display name, district pill, bio preview, and a small horizontal preview of their first 1–3 active items. Right-swipe triggers the item picker (8.2); left-swipe records a `direction: 'left'` swipe and advances. Tap on a card (not a swipe) opens the User Detail screen (7.5).

**Deliverables**
- `lib/screens/discover/discover_screen.dart`
- Swipe card widget showing user info + first 1–3 active items
- Right-swipe → item picker
- Left-swipe → write swipe doc and advance
- Tap → User Detail (NOT swallowed by swipe gesture; this was a prototype bug)

**Acceptance**
- Right-swipe gesture works smoothly
- Left-swipe gesture works smoothly
- Tap on the card (not a swipe) navigates to User Detail
- Cards show district pill in the format from 5.2
- No fabricated UI: no "verified" pill, no "active now", no age, no km

**Associated Activities**
- Add `appinio_swiper` to `pubspec.yaml`
- Build card widget
- Wire gesture handlers carefully to distinguish tap from swipe
- Build the deck screen

**Testing**
- Widget test: right-swipe on a card opens the item picker modal
- Widget test: left-swipe on a card writes a swipe doc with `direction: 'left'`
- Widget test: tap (no horizontal movement) navigates to User Detail
- Widget test: card displays district as "Thai · English, Province"
- Widget test: card displays no out-of-scope UI elements

---

### 7.4 Proximity Filter Bottom Sheet

| Field | Detail |
|---|---|
| **WBS Code** | 7.4 |
| **Type** | Work Package |
| **Requirement** | F12 |
| **Owner** | M3 |
| **Prototype Reference** | `prototype/src/screens/discover.jsx` — `ProximityPicker` bottom sheet + the tappable proximity pill at top of `DiscoverScreen` (owns); `PROXIMITY_OPTIONS` list (owns) |

**Scope / Statement of Work**
Build the proximity filter bottom sheet with exactly 4 options: "Same district" / "Same province" / "Nearby provinces" / "All Thailand". Selection is persisted in `shared_preferences` and used by 7.2 on the next feed query. The default is `same_province`. The current filter is displayed as a tappable pill at the top of Discover (this is the only filter chip — all others have been removed per locked decisions).

**Deliverables**
- `lib/widgets/proximity_filter_sheet.dart`
- Persistence via `shared_preferences` key `proximity_filter`
- Tappable pill on Discover showing current filter
- 4 options exactly, no more

**Acceptance**
- 4 options visible, no fewer and no more
- Default is `same_province`
- Selection persists across app restarts
- Changing the filter triggers a feed reload
- Pill text matches the selected option

**Associated Activities**
- Build the bottom sheet UI
- Add `shared_preferences` to `pubspec.yaml`
- Wire persistence
- Reload feed on change

**Testing**
- Widget test: bottom sheet shows 4 options
- Widget test: tapping an option dismisses the sheet and persists the choice
- Widget test: app restart preserves the selection
- Widget test: changing filter triggers `FeedService.candidatesForUser()` with the new bucket

---

### 7.5 User Detail with Item Bottom Sheet

| Field | Detail |
|---|---|
| **WBS Code** | 7.5 |
| **Type** | Work Package |
| **Requirement** | F14 |
| **Owner** | M3 |
| **Prototype Reference** | `prototype/src/screens/userdetail.jsx` — `UserDetailScreen` + `ItemDetailSheet` bottom sheet (owns both) |

**Scope / Statement of Work**
Build the User Detail screen showing the tapped user's full profile (photo, name, district, bio) and a grid of all their active items. Tap an item to open the Item Detail bottom sheet showing photo, name, category, condition, weight (if provided), description, and wants. From User Detail the swiper can still right-swipe (opens item picker 8.2) or left-swipe.

**Deliverables**
- `lib/screens/discover/user_detail_screen.dart`
- `lib/widgets/item_detail_sheet.dart` — bottom sheet
- Right-swipe and left-swipe buttons at the bottom of User Detail

**Acceptance**
- All user fields displayed (no age, no verification, no activity status)
- All active items in a grid
- Tapping an item opens the bottom sheet
- Bottom sheet shows all 7 item fields (photo, name, category, condition, weight if present, description, wants)
- Right-swipe and left-swipe buttons work the same as on the deck card

**Associated Activities**
- Build User Detail screen
- Build Item Detail bottom sheet
- Wire swipe-action buttons at the bottom

**Testing**
- Widget test: User Detail displays all profile fields correctly
- Widget test: item grid shows all active items
- Widget test: tapping an item opens the bottom sheet
- Widget test: bottom sheet hides the weight row if `weight == null`

---

### 7.6 Empty State Handling

| Field | Detail |
|---|---|
| **WBS Code** | 7.6 |
| **Type** | Work Package |
| **Requirement** | F15 |
| **Owner** | M3 |
| **Prototype Reference** | `prototype/src/screens/discover.jsx` — empty state variant inside `DiscoverScreen` (owns); follows EmptyState pattern from `docs/EcoSwap_Style_Guide.md` §10 |

**Scope / Statement of Work**
Show an empty state on the Discover screen when the feed query returns zero candidates. Copy invites the user to widen their proximity filter or come back later. Visual: large illustration, headline ("No swaps nearby"), supporting text, and a button that opens the proximity filter sheet (7.4).

**Deliverables**
- `lib/widgets/empty_state.dart` (reusable, also used elsewhere per Style Guide §10)
- Variant on Discover when feed is empty
- "Widen search" button opens 7.4 filter sheet

**Acceptance**
- Empty state shown when feed query returns `[]`
- "Widen search" button opens the proximity filter
- Copy matches Style Guide §10

**Associated Activities**
- Build `EmptyState` component
- Wire variant into Discover screen
- Verify copy against Style Guide §10

**Testing**
- Widget test: empty feed shows empty state, not blank screen
- Widget test: "widen search" button opens proximity sheet
- Widget test: non-empty feed does NOT show empty state

---

## Phase 8.0 — Matching

---

### 8.1 Swipe Write to Firestore

| Field | Detail |
|---|---|
| **WBS Code** | 8.1 |
| **Type** | Work Package |
| **Requirement** | F13 (write), F16 (item) |
| **Owner** | M1 |
| **Prototype Reference** | N/A — no prototype surface (Firestore write logic); triggered from 7.3 and 8.2 |

**Scope / Statement of Work**
On every swipe (left or right), write a document to `/swipes/{swipeId}` recording the swiper, target, direction, and (for right-swipes only) the declared desired item from the item picker (8.2). Per F19, the declared item at swipe time is the final lock — no separate confirmation step. The swipe document is the input to the mutual-match detection trigger (8.3).

**Deliverables**
- `lib/services/swipe_service.dart` with `recordSwipe(target, direction, {desiredItemId})`
- Left-swipes: `desiredItemId` is empty string `''` (Firestore requires non-null; chose empty over null for query consistency)
- Right-swipes: `desiredItemId` is required, must be a valid active item ID owned by `targetUserId`

**Acceptance**
- Every left-swipe produces a `/swipes/{swipeId}` document with `direction: 'left'` and `desiredItemId: ''`
- Every right-swipe produces a document with `direction: 'right'` and a valid `desiredItemId`
- The swipe write happens BEFORE the next card animates in (atomic from user perspective)
- Client cannot write a right-swipe without a `desiredItemId` (validated client-side and by security rules)

**Associated Activities**
- Implement `SwipeService.recordSwipe()`
- Wire to swipe gesture handlers in 7.3
- Update security rules in 3.2 to require `desiredItemId` non-empty when `direction == 'right'`

**Testing**
- Unit test: `recordSwipe(target, 'left')` writes correct doc shape
- Unit test: `recordSwipe(target, 'right', desiredItemId: 'item123')` writes correct doc shape
- Unit test: `recordSwipe(target, 'right')` without `desiredItemId` throws
- Integration test: rapid successive swipes do not produce duplicate documents

---

### 8.2 Item Picker Modal on Swipe-Right

| Field | Detail |
|---|---|
| **WBS Code** | 8.2 |
| **Type** | Work Package |
| **Requirement** | F16 |
| **Owner** | M1 |
| **Prototype Reference** | `prototype/src/screens/picker.jsx` — `PickerScreen` bottom sheet + `ItemPickCard` component (owns) |

**Scope / Statement of Work**
When the user swipes right (or taps the right-swipe button on User Detail), show a single-select modal listing all of the target user's active items. The user must pick exactly one item before the swipe is recorded. Cancelling the modal aborts the swipe entirely (the card returns to the deck, no swipe is recorded).

**Deliverables**
- `lib/widgets/item_picker_modal.dart`
- Single-select: tapping an item highlights it; only one can be selected at a time
- "Confirm" button writes the swipe via 8.1 with the selected `desiredItemId`
- "Cancel" button dismisses without writing

**Acceptance**
- Modal shows all active items of the target user
- Only one item can be selected (single-select, NOT multi-select)
- Confirm requires a selection
- Cancel aborts the swipe completely
- Target user with zero active items cannot be swiped right (shouldn't reach this modal — 7.2 already filters them out)

**Associated Activities**
- Build modal widget
- Wire single-select state
- Confirm calls `SwipeService.recordSwipe()` with `direction: 'right'` and the picked ID
- Cancel pops without writing

**Testing**
- Widget test: modal shows correct list of active items
- Widget test: tapping item A then item B leaves only B selected (single-select)
- Widget test: confirm with no selection is disabled
- Widget test: cancel does not write a swipe
- Widget test: confirm writes a swipe with the correct `desiredItemId`

---

### 8.3 Mutual Swipe Detection

| Field | Detail |
|---|---|
| **WBS Code** | 8.3 |
| **Type** | Work Package |
| **Requirement** | F19 |
| **Owner** | M1 + M4 |
| **Prototype Reference** | N/A — no prototype surface (Cloud Function trigger); output surfaces in 8.4 and 9.1 |

**Scope / Statement of Work**
When a right-swipe is written to `/swipes/`, a Cloud Function trigger (`onSwipeCreated`) checks whether the target user has previously swiped right on the swiper AND declared an item that the swiper owns. If yes, a `/matches/{matchId}` document is created atomically and both users get a match notification. The match document records each user's declared desired item from their respective swipes.

**Deliverables**
- Cloud Function `onSwipeCreated` at `/functions/src/onSwipeCreated.ts`
- Logic: when `direction: 'right'` is written, query for a reciprocal swipe; if found, create a match doc in a transaction
- Match doc shape matches the schema in 3.6 with `userAWantsItemId` and `userBWantsItemId` set from the two swipe records

**Acceptance**
- User A right-swipes user B (declaring item X) → no match yet
- User B right-swipes user A (declaring item Y) → match doc created with `userAWantsItemId: X` and `userBWantsItemId: Y`
- Only one match doc is created even under concurrent writes (transaction prevents duplicates)
- Match doc's `participants: [userAId, userBId]` field set for security rule queries
- No match created if either declared item has `status != 'active'` (defensive check inside the function)

**Associated Activities**
- Implement `onSwipeCreated` Firestore trigger
- Use transactions to prevent duplicate match docs
- Write notification to in-app notification list (no FCM in MVP; notification appears next time the user opens the app via the match list in 9.1)

**Pseudocode**
```typescript
export const onSwipeCreated = onDocumentCreated(
  'swipes/{swipeId}',
  async (event) => {
    const swipe = event.data?.data() as Swipe;
    if (swipe.direction !== 'right') return;

    // Look for a reciprocal right-swipe from target back to swiper
    const reciprocal = await db.collection('swipes')
      .where('swiperId', '==', swipe.targetUserId)
      .where('targetUserId', '==', swipe.swiperId)
      .where('direction', '==', 'right')
      .limit(1)
      .get();
    if (reciprocal.empty) return;

    const other = reciprocal.docs[0].data() as Swipe;

    // Defensive: both declared items still active?
    const [meItem, themItem] = await Promise.all([
      db.doc(`items/${other.desiredItemId}`).get(),
      db.doc(`items/${swipe.desiredItemId}`).get(),
    ]);
    if (meItem.data()?.status !== 'active') return;
    if (themItem.data()?.status !== 'active') return;

    // Create match in a transaction (idempotent across concurrent triggers)
    await db.runTransaction(async (tx) => {
      const matchId = [swipe.swiperId, swipe.targetUserId].sort().join('_');
      const matchRef = db.doc(`matches/${matchId}`);
      const existing = await tx.get(matchRef);
      if (existing.exists) return;
      tx.set(matchRef, {
        userAId: swipe.swiperId,
        userBId: swipe.targetUserId,
        userAWantsItemId: swipe.desiredItemId,
        userBWantsItemId: other.desiredItemId,
        status: 'active',
        participants: [swipe.swiperId, swipe.targetUserId],
        createdAt: FieldValue.serverTimestamp(),
        completedAt: null,
      });
    });
  }
);
```

**Testing**
- Unit test (emulator): A right-swipes B, then B right-swipes A → exactly one match doc
- Unit test: A right-swipes B, B has never swiped → no match doc
- Unit test: A and B both right-swipe; B's declared item has `status: 'traded'` → no match doc
- Integration test: rapid double-fire of the trigger (idempotency) → still exactly one match doc

---

### 8.4 Match Notification Screen

| Field | Detail |
|---|---|
| **WBS Code** | 8.4 |
| **Type** | Work Package |
| **Requirement** | F19 (UX surface) |
| **Owner** | M1 |
| **Prototype Reference** | `prototype/src/screens/match.jsx` — `MatchScreen` celebration (owns) with item-↔-item layout, both names, chat CTA |

**Scope / Statement of Work**
When a match doc is created involving the current user, show a celebratory Match screen on next foreground (or immediately if the user is on Discover). The screen shows both items being swapped, both photos, and CTAs to "Send a message" (→ 9.2) or "Keep swiping". Polling via Firestore listener on `/matches/` where `participants` contains current uid.

**Deliverables**
- `lib/screens/match/match_celebration_screen.dart`
- `lib/services/match_listener.dart` — global listener that surfaces new matches
- One-time display: a match is shown once, then marked as "seen" in local `shared_preferences` (not in Firestore — keeps the data model clean)

**Acceptance**
- New match triggers the celebration screen on next foreground
- Screen shows both items, both photos, both display names
- "Send a message" navigates to the chat (9.2)
- "Keep swiping" dismisses back to Discover
- Same match does not re-trigger the celebration on subsequent foregrounds

**Associated Activities**
- Build celebration screen
- Implement global match listener using `StreamProvider`
- Track seen matches in `shared_preferences` keyed by matchId

**Testing**
- Widget test: a new match doc surfaces the celebration screen
- Widget test: re-foregrounding with same match does not re-show
- Widget test: tapping "Send a message" navigates to chat

---

### 8.5 Hard-Cancel Pending Swipes When Item Traded

| Field | Detail |
|---|---|
| **WBS Code** | 8.5 |
| **Type** | Work Package |
| **Requirement** | F20 |
| **Owner** | M4 |
| **Prototype Reference** | N/A — no prototype surface (Cloud Function trigger); cancelled matches disappear from 9.1 list, deleted swipes vanish from 7.3 feed |

**Scope / Statement of Work**
When an item flips to `status: 'traded'` (only the 10.6 Cloud Function writes this), a separate Cloud Function trigger `onItemTraded` finds all `/swipes/` documents where `desiredItemId` equals the traded item AND no corresponding match has yet completed, and deletes them. It also marks any `/matches/` documents involving this item as `status: 'cancelled'` so they disappear from the match list. The affected swipers are surfaced a "find similar" notification in-app.

**Deliverables**
- Cloud Function `onItemTraded` at `/functions/src/onItemTraded.ts`
- Trigger: `onDocumentUpdated('items/{itemId}')`, fires when `before.status: 'active'` and `after.status: 'traded'`
- Deletes pending right-swipes referencing this item
- Cancels active matches referencing this item (one user already traded it elsewhere — the other match becomes invalid)
- Notification: a row in `/users/{uid}/notifications/{notifId}` with `type: 'item_unavailable', similarSearchQuery: <item name>`

**Acceptance**
- When item X flips to traded, every `/swipes/` doc with `desiredItemId: X` and `direction: 'right'` is deleted
- Every `/matches/` doc with `userAWantsItemId: X` OR `userBWantsItemId: X` AND `status: 'active'` is set to `cancelled`
- The two parties of the COMPLETED match (the one that caused the trade) are NOT affected — only OTHER pending matches/swipes
- Affected users get a notification entry

**Associated Activities**
- Implement `onItemTraded` trigger
- Query and delete pending swipes
- Query and cancel pending matches (NOT the one that completed)
- Write notifications

**Pseudocode**
```typescript
export const onItemTraded = onDocumentUpdated(
  'items/{itemId}',
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (before?.status !== 'active') return;
    if (after?.status !== 'traded') return;
    const itemId = event.params.itemId;

    // Find the trade that caused this status change to skip its match
    const completingTrade = await db.collection('trades')
      .where('itemsExchanged.fromA', '==', itemId)
      .get();
    const completingTradeB = await db.collection('trades')
      .where('itemsExchanged.fromB', '==', itemId)
      .get();
    const completingMatchIds = new Set([
      ...completingTrade.docs.map(d => d.data().matchId),
      ...completingTradeB.docs.map(d => d.data().matchId),
    ]);

    // Cancel other pending matches that referenced this item
    const matchesA = await db.collection('matches')
      .where('userAWantsItemId', '==', itemId)
      .where('status', '==', 'active').get();
    const matchesB = await db.collection('matches')
      .where('userBWantsItemId', '==', itemId)
      .where('status', '==', 'active').get();
    const batch = db.batch();
    for (const doc of [...matchesA.docs, ...matchesB.docs]) {
      if (completingMatchIds.has(doc.id)) continue;
      batch.update(doc.ref, { status: 'cancelled' });
      // Notify the OTHER party
      const data = doc.data();
      const otherUid = data.userAWantsItemId === itemId
        ? data.userAId : data.userBId;
      batch.set(
        db.collection('users').doc(otherUid).collection('notifications').doc(),
        { type: 'item_unavailable', itemId, createdAt: FieldValue.serverTimestamp() }
      );
    }
    // Delete pending right-swipes referencing this item
    const pendingSwipes = await db.collection('swipes')
      .where('desiredItemId', '==', itemId)
      .where('direction', '==', 'right').get();
    for (const doc of pendingSwipes.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
);
```

**Testing**
- Unit test (emulator): trade completes; the completing match is NOT cancelled
- Unit test: trade completes; a separate pending match referencing the same item IS cancelled
- Unit test: trade completes; pending right-swipes referencing the item are deleted
- Unit test: the OTHER party of a cancelled match gets a notification

---

## Phase 9.0 — Chat

---

### 9.1 Match List View

| Field | Detail |
|---|---|
| **WBS Code** | 9.1 |
| **Type** | Work Package |
| **Requirement** | F21 |
| **Owner** | M2 |
| **Prototype Reference** | `prototype/src/screens/chats.jsx` — `ChatsScreen` list + empty state (owns); `CHATS` data shape (owns) |

**Scope / Statement of Work**
Build the Chats screen listing all matches involving the current user. Query: `matches.where('participants', 'array-contains', uid).where('status', 'in', ['active', 'completed'])`. Each row shows the other user's photo and name, the most recent message preview, a relative timestamp, and a small "trade pill" summarising what's being swapped (e.g., "Your jacket ⇄ their kettle"). Cancelled matches are excluded.

> **Decision change (product) — completed-swap chat handling:** after a swap completes (QR redeemed, `match.status == 'completed'`) the chat is **kept**, not deleted. It is the durable trade record and the post-swap coordination channel. Completed rows carry a small "Swapped" chip in the list and the chat shows a "Swap completed" banner with the Exchange CTA replaced by a static "Swapped" indicator (see 9.2). Deleting the chat was explicitly rejected (it would destroy history and contradict the Swap Confirmed screen's "check Chats for the trade record" copy).

**Deliverables**
- `lib/screens/chats/match_list_screen.dart`
- Match row widget with photo, name, last message, timestamp, trade pill
- "Swapped" chip on completed-match rows (`MatchRowData.isCompleted`, derived from `match.status`)
- Cancelled matches excluded from the list
- Empty state when user has no matches

**Acceptance**
- All active and completed matches shown
- Cancelled matches NOT shown
- Completed matches show a "Swapped" chip; active matches do not
- Trade pill correctly summarises the two items being exchanged
- Tap on a row navigates to the chat (9.2)
- Empty state when no matches

**Associated Activities**
- Build screen with `StreamBuilder` on the matches query
- Build row widget
- Build trade pill component
- Wire navigation to chat

**Testing**
- Widget test: user with 2 active + 1 cancelled match sees 2 rows
- Widget test: trade pill correctly shows "Your X ⇄ their Y"
- Widget test: tap on row navigates to correct chat
- Widget test: empty state when user has 0 matches

---

### 9.2 Chat Screen UI

| Field | Detail |
|---|---|
| **WBS Code** | 9.2 |
| **Type** | Work Package |
| **Requirement** | F22 |
| **Owner** | M2 |
| **Prototype Reference** | `prototype/src/screens/chat.jsx` — `ChatScreen` header with agreed-trade pill and Ready button (owns); `Bubble` component (owns) |

**Scope / Statement of Work**
Build the chat screen with message bubbles (sender on right, recipient on left), a multi-line text input with a send button, and a sticky header showing the match's trade summary. Includes a "Ready to swap" CTA pinned at the top of the chat.

> **Decision change (product):** the original "both parties ≥ 3 messages each" engagement gate on the CTA was **removed**. The exchange is an in-person action — the two people have to meet in real life to scan each other's QR — so gating the button behind chat volume only adds friction. The CTA is now shown unconditionally.

> **Decision change (product) — completed state:** once the match's `status` is `'completed'` the chat is kept but visibly marked done: a "Swap completed — this trade is done." banner sits below the header, and the Exchange CTA is replaced by a static "Swapped" indicator (re-scanning a completed match would fail server validation anyway — single-use token, match no longer `'active'`). Driven by the injectable `isCompleted` flag. See 9.1 for the list-row chip.

**Deliverables**
- `lib/screens/chats/chat_screen.dart`
- Message bubble widget
- Text input with send button
- "Ready to swap" CTA always visible

**Acceptance**
- Messages render as bubbles, correctly aligned
- Long messages wrap and don't overflow
- Send button disabled when input is empty
- "Ready to swap" CTA always visible (no message-count gate)

**Associated Activities**
- Build chat screen layout
- Build message bubble widget
- Wire text input and send button

**Testing**
- Widget test: own messages right-aligned, other's messages left-aligned
- Widget test: send button disabled on empty input
- Widget test: "Exchange" CTA visible with zero messages
- Widget test: "Exchange" CTA visible with unevenly distributed messages

---

### 9.3 Firestore Real-Time Listener

| Field | Detail |
|---|---|
| **WBS Code** | 9.3 |
| **Type** | Work Package |
| **Requirement** | F22 |
| **Owner** | M2 |
| **Prototype Reference** | N/A — no prototype surface (Firestore listener plumbing); feeds messages into 9.2 `ChatScreen` |

**Scope / Statement of Work**
Subscribe to the messages subcollection for the current match using `snapshots()` and stream into the chat UI. The listener detaches when the user leaves the chat screen to avoid memory leaks. Initial query is `orderBy('sentAt', descending: true).limit(50)`; infinite scroll loads older messages on demand (optional polish for MVP).

**Deliverables**
- `lib/services/chat_service.dart` with `messageStream(matchId)` returning `Stream<List<Message>>`
- Stream subscription managed in `chat_screen.dart` with proper disposal in `dispose()`
- Initial load capped at 50 messages

**Acceptance**
- New messages from the other party appear within ~1 second
- Leaving and re-entering the chat does not duplicate messages
- 50-message cap on initial load
- No memory leak on rapid navigation in/out (verified manually)

**Associated Activities**
- Implement `messageStream()`
- Wire stream into chat screen via `StreamBuilder`
- Ensure subscription cancellation in `dispose()`

**Testing**
- Widget test: stream emits new message → message appears in UI
- Widget test: navigating away cancels the subscription
- Integration test: two clients see each other's messages within 1s

---

### 9.4 Message Send with serverTimestamp

| Field | Detail |
|---|---|
| **WBS Code** | 9.4 |
| **Type** | Work Package |
| **Requirement** | F22, F23 |
| **Owner** | M2 |
| **Prototype Reference** | `prototype/src/screens/chat.jsx` — message input + send button at bottom of `ChatScreen` (contributes to 9.2) |

**Scope / Statement of Work**
Implement `sendMessage(matchId, text)` which writes a document to `/matches/{matchId}/messages/{messageId}` with `senderId: currentUid`, `text`, `sentAt: FieldValue.serverTimestamp()`, and `readBy: [currentUid]`. ServerTimestamp ensures clock-skew-free ordering across devices.

**Deliverables**
- `ChatService.sendMessage(matchId, text)` method
- Optimistic UI: the message appears immediately with a "sending" indicator and resolves to "sent" once the write completes
- Validation: text trimmed, max 1000 chars, must not be empty

**Acceptance**
- Sent message appears in own UI immediately
- Appears in recipient UI within 1s
- Empty or whitespace-only messages rejected
- Messages > 1000 chars rejected with friendly error
- `sentAt` is server-side, not client-side

**Associated Activities**
- Implement `sendMessage()`
- Build optimistic UI with sending → sent transition
- Wire validation

**Testing**
- Unit test: `sendMessage('m1', '   ')` rejects with `EmptyMessageException`
- Unit test: `sendMessage('m1', 'x' * 1001)` rejects with `MessageTooLongException`
- Unit test: successful send writes doc with all required fields and `sentAt` as server timestamp
- Widget test: optimistic UI shows the message before Firestore round-trip completes

---

### 9.5 Read Receipt Logic

| Field | Detail |
|---|---|
| **WBS Code** | 9.5 |
| **Type** | Work Package |
| **Requirement** | F23 |
| **Owner** | M2 |
| **Prototype Reference** | `prototype/src/screens/chat.jsx` — read indicator on own `Bubble`s (contributes to 9.2) |

**Scope / Statement of Work**
When the user views the chat screen and a new message from the other party arrives, mark it as read by appending the current uid to the `readBy` array of each unread message. Use `FieldValue.arrayUnion()` for idempotency. Display a small "read" indicator on own messages once the other uid appears in `readBy`.

**Deliverables**
- `ChatService.markRead(matchId, messageIds)` batch-updating `readBy` arrays
- Read indicator widget on own message bubbles
- Auto-trigger of `markRead` when messages become visible

**Acceptance**
- Receiving the chat marks unread incoming messages as read for the current user
- "Read" indicator appears on own messages when other user has marked them read
- Marking already-read messages does not throw or duplicate
- No "presence" or "typing" indicators (out of scope per Style Guide)

**Associated Activities**
- Implement `markRead()` using `WriteBatch` and `arrayUnion`
- Trigger when chat screen mounts and on each new message arrival
- Build read indicator

**Testing**
- Unit test: `markRead()` is idempotent (calling twice has same effect as calling once)
- Widget test: opening a chat with 3 unread messages marks all 3 read
- Widget test: read indicator shows on own messages when other uid in `readBy`

---

### 9.6 Ready-to-Exchange Button and QR Navigation

| Field | Detail |
|---|---|
| **WBS Code** | 9.6 |
| **Type** | Work Package |
| **Requirement** | F24 |
| **Owner** | M2 |
| **Prototype Reference** | `prototype/src/screens/chat.jsx` — Ready-to-exchange button + role-pick modal at top of `ChatScreen` (contributes to 9.2) |

**Scope / Statement of Work**
The "Ready to swap" CTA from 9.2, when tapped, opens a small modal asking "Are you with the other person right now?" with two options: "I'll show the QR" (navigates to QR Show 10.3) and "I'll scan their QR" (navigates to QR Scan 10.4). The role (shower vs scanner) is decided by the user at this step — there's no server-side coordination.

**Deliverables**
- Modal widget on chat screen
- Navigation to QR Show (10.3) or QR Scan (10.4) based on selection
- The match ID is passed to the next screen via the route arguments

**Acceptance**
- Modal shown when CTA tapped
- Both options work and pass the matchId correctly
- Cancel dismisses the modal

**Associated Activities**
- Build the modal
- Wire navigation
- Pass matchId via route arguments

**Testing**
- Widget test: "Show QR" navigates to QR Show with correct matchId
- Widget test: "Scan QR" navigates to QR Scan with correct matchId
- Widget test: cancel dismisses without navigation

---

## Phase 10.0 — QR Exchange

---

### 10.1 Cloud Function: Issue Signed JWT

| Field | Detail |
|---|---|
| **WBS Code** | 10.1 |
| **Type** | Work Package |
| **Requirement** | F25 |
| **Owner** | M4 |
| **Prototype Reference** | N/A — no prototype surface (Cloud Function); QR token consumed by 10.3 `QRScreen` |

**Scope / Statement of Work**
Implement the `issueQRToken(matchId)` callable Cloud Function. Validates that the caller is a party to the match, that the match `status: 'active'`, and that both declared items are still `status: 'active'`. Returns a signed JWT with a 60-second expiry. The signing secret comes from Secret Manager (`JWT_SECRET` from 3.5). The HMAC algorithm is HS256.

**Deliverables**
- `functions/src/issueQRToken.ts` — callable function
- Returns `{ token: string, expiresAt: number }`
- Token lifetime: 60 seconds from issue
- JWT payload includes: `matchId`, `displayerUserId`, `iat`, `exp`

**Acceptance**
- Caller who is not a party to the match → permission denied
- Caller whose match has `status: 'completed'` or `'cancelled'` → error
- Caller whose declared item has `status: 'traded'` → error
- Valid call returns a JWT that verifies with the same secret
- Token expires exactly 60s after issue

**Associated Activities**
- Implement function
- Use `jsonwebtoken` library for HS256 signing
- Add input validation
- Deploy and test via Functions Shell

**Schema (JWT payload)**
```typescript
{
  matchId: string;
  displayerUserId: string;     // who is showing the QR
  iat: number;                 // issued-at, seconds since epoch
  exp: number;                 // expiry, seconds since epoch (iat + 60)
}
```

**Pseudocode**
```typescript
export const issueQRToken = onCall(
  { secrets: [JWT_SECRET] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'auth required');
    const { matchId } = request.data;
    const match = await db.doc(`matches/${matchId}`).get();
    const m = match.data();
    if (!m) throw new HttpsError('not-found', 'no such match');
    if (!m.participants.includes(uid)) throw new HttpsError('permission-denied', 'not a party');
    if (m.status !== 'active') throw new HttpsError('failed-precondition', 'match not active');
    // Defensive: items still active?
    const itemIds = [m.userAWantsItemId, m.userBWantsItemId];
    for (const id of itemIds) {
      const item = await db.doc(`items/${id}`).get();
      if (item.data()?.status !== 'active') {
        throw new HttpsError('failed-precondition', 'item no longer available');
      }
    }
    const now = Math.floor(Date.now() / 1000);
    const token = jwt.sign(
      { matchId, displayerUserId: uid, iat: now, exp: now + 60 },
      JWT_SECRET.value(),
      { algorithm: 'HS256' }
    );
    return { token, expiresAt: now + 60 };
  }
);
```

**Testing**
- Unit test: caller not in match → throws permission-denied
- Unit test: match status completed → throws failed-precondition
- Unit test: declared item status traded → throws failed-precondition
- Unit test: valid call returns token that decodes with same secret
- Unit test: token `exp` is exactly `iat + 60`

---

### 10.2 Cloud Function: Validate Scanned JWT

| Field | Detail |
|---|---|
| **WBS Code** | 10.2 |
| **Type** | Work Package |
| **Requirement** | F28 |
| **Owner** | M4 |
| **Prototype Reference** | N/A — no prototype surface (Cloud Function); triggered by 10.4 scan and 10.5 paste |

**Scope / Statement of Work**
Implement the `validateQRToken(token)` callable Cloud Function. Performs four security checks per §8.3 of the planning doc: signature valid, not expired, counterparty correct (scanner is the other party of the match, not the displayer), single-use (token hash not already in `/trades/{*}/jwtTokenHash`). On success, atomically writes the trade record and triggers 10.6 logic. On any failure, returns a typed error code.

**Deliverables**
- `functions/src/validateQRToken.ts` — callable function
- Returns `{ success: true, tradeId: string }` on success
- Returns typed errors: `INVALID_SIGNATURE`, `EXPIRED`, `WRONG_COUNTERPARTY`, `ALREADY_USED`, `MATCH_INVALID`

**Acceptance**
- Forged token (wrong signature) → `INVALID_SIGNATURE`
- Expired token (older than 60s) → `EXPIRED`
- Token's `displayerUserId == request.auth.uid` (trying to scan own QR) → `WRONG_COUNTERPARTY`
- Token whose hash already exists in `/trades/{*}.jwtTokenHash` → `ALREADY_USED`
- Match's `status != 'active'` → `MATCH_INVALID`
- Valid scan → trade record written, returns `{ success: true, tradeId }`

**Associated Activities**
- Implement validation function with all 4 security checks
- Use Firestore transaction for the single-use check
- Compute SHA-256 hash of the token for the `jwtTokenHash` field
- Call into 10.6 logic (trade record + impact write) from within the same transaction

**Pseudocode**
```typescript
export const validateQRToken = onCall(
  { secrets: [JWT_SECRET] },
  async (request) => {
    const scannerUid = request.auth?.uid;
    if (!scannerUid) throw new HttpsError('unauthenticated', '');
    const { token } = request.data;

    let payload: JwtPayload;
    try {
      payload = jwt.verify(token, JWT_SECRET.value()) as JwtPayload;
    } catch (e) {
      if (e instanceof TokenExpiredError) throw new HttpsError('deadline-exceeded', 'EXPIRED');
      throw new HttpsError('permission-denied', 'INVALID_SIGNATURE');
    }
    if (payload.displayerUserId === scannerUid) {
      throw new HttpsError('permission-denied', 'WRONG_COUNTERPARTY');
    }
    const tokenHash = sha256(token);

    return await db.runTransaction(async (tx) => {
      // Single-use check
      const existing = await tx.get(
        db.collection('trades').where('jwtTokenHash', '==', tokenHash).limit(1)
      );
      if (!existing.empty) throw new HttpsError('already-exists', 'ALREADY_USED');

      const matchRef = db.doc(`matches/${payload.matchId}`);
      const match = await tx.get(matchRef);
      const m = match.data();
      if (!m || m.status !== 'active') throw new HttpsError('failed-precondition', 'MATCH_INVALID');
      if (!m.participants.includes(scannerUid)) {
        throw new HttpsError('permission-denied', 'WRONG_COUNTERPARTY');
      }

      // Delegate to 10.6 logic: write trade, flip items, increment counters
      const tradeId = await writeTradeAndImpact(tx, m, payload.matchId, tokenHash);
      tx.update(matchRef, {
        status: 'completed',
        completedAt: FieldValue.serverTimestamp(),
      });
      return { success: true, tradeId };
    });
  }
);
```

**Testing**
- Unit test: forged token → INVALID_SIGNATURE
- Unit test: token issued 61s ago → EXPIRED
- Unit test: scanner is the displayer → WRONG_COUNTERPARTY
- Unit test: same token validated twice → second call returns ALREADY_USED
- Unit test: match already completed → MATCH_INVALID
- Integration test: full flow A issues → B validates → trade exists, both items flipped, counters incremented

---

### 10.3 QR Display Screen with Refresh Timer

| Field | Detail |
|---|---|
| **WBS Code** | 10.3 |
| **Type** | Work Package |
| **Requirement** | F26 |
| **Owner** | M3 |
| **Prototype Reference** | `prototype/src/screens/qr.jsx` — `QRScreen` with `stage='show'` (owns); `QRPattern` + `Countdown` + `FraudExplainer` components (owns) |

**Scope / Statement of Work**
Build the QR Show screen which calls 10.1 to fetch a fresh JWT, renders it as a QR code using `qr_flutter`, displays a countdown, and silently refreshes the token every 30 seconds. Includes a "Cancel" button to back out of the flow. On successful trade (detected via Firestore listener seeing match `status: 'completed'`), navigates to the Swap Confirmed screen.

> **Decision change (UX):** the countdown now tracks the **30-second refresh cycle** ("New code in 30…0s"), counting to zero exactly as the QR rotates, then resetting to 30. The original spec showed a *60-second* countdown that reset to 60 every 30s — which never reached zero and read as a contradiction ("expires in 60s" but the code visibly changes at 30s). Each token is still valid for 60s server-side; the 30s refresh keeps a safety margin against clock skew / scan latency. The live counter now reflects the *visible rotation*, not the raw expiry; the 60s validity stays stated in the fraud-explainer security note.

**Deliverables**
- `lib/screens/qr/qr_show_screen.dart`
- `qr_flutter` package added to `pubspec.yaml`
- "New code in" countdown that counts the 30s refresh cycle and resets on each fresh token
- Firestore listener on match status to detect completion
- Cancel button

**Acceptance**
- QR renders within 1 second of screen open
- Countdown shows 30, 29, 28… and resets to 30 every 30s, in sync with the token refresh (it reaches zero exactly as the QR rotates)
- On match completion (status flips to `completed`), navigates to Swap Confirmed
- Cancel returns to chat screen

**Associated Activities**
- Add `qr_flutter` to `pubspec.yaml`
- Call `issueQRToken` Cloud Function on screen mount and every 30s
- Render QR with the returned token
- Drive the countdown from the 30s refresh cycle
- Listen on `/matches/{matchId}` for completion

**Testing**
- Widget test: screen mounts, QR appears, countdown starts at 30
- Widget test: at 30s elapsed, countdown resets to 30 (next token fetched)
- Widget test: match status flips to `completed` → navigates to Swap Confirmed
- Widget test: tapping Cancel returns to chat

---

### 10.4 QR Scan Screen with Camera Permissions

| Field | Detail |
|---|---|
| **WBS Code** | 10.4 |
| **Type** | Work Package |
| **Requirement** | F27 |
| **Owner** | M3 |
| **Prototype Reference** | `prototype/src/screens/qr.jsx` — `QRScreen` with `stage='scan'` (owns); `ScannerViewfinder` + `CornerMarkers` (owns); camera permission flow (owns, no JSX) |

**Scope / Statement of Work**
Build the QR Scan screen using `mobile_scanner`. Requests camera permission on first launch (handled by the package). Scans QR codes continuously; when one is detected, decodes the text and calls 10.2 `validateQRToken`. On success, navigates to Swap Confirmed. On error, shows a friendly toast with the typed error code translated to user-facing text.

**Deliverables**
- `lib/screens/qr/qr_scan_screen.dart`
- `mobile_scanner` package added to `pubspec.yaml`
- Camera permission request flow
- Error toast mapping: `INVALID_SIGNATURE` → "QR not recognised, try again"; `EXPIRED` → "QR expired, ask them to refresh"; `WRONG_COUNTERPARTY` → "You can't scan your own QR"; `ALREADY_USED` → "This swap is already complete"; `MATCH_INVALID` → "This match is no longer active"
- Permission-denied fallback: show explanation and link to settings

**Acceptance**
- Camera permission requested correctly
- Permission denied → show settings link
- Scanning a valid QR triggers the validate call and navigates to Swap Confirmed on success
- Each error code produces the correct user-facing message
- Continuous scanning (no need to tap to trigger)

**Associated Activities**
- Add `mobile_scanner` to `pubspec.yaml`
- Build scan screen with camera preview
- Handle permission flow
- Wire validateQRToken call and error mapping

**Testing**
- Widget test: permission denied → shows settings link
- Widget test: valid scan → calls validateQRToken
- Widget test: each error code maps to the correct toast text
- Manual test: scan a fresh QR end-to-end (no automated test for camera in MVP)

---

### 10.5 DEV-MODE Paste-Token Fallback

| Field | Detail |
|---|---|
| **WBS Code** | 10.5 |
| **Type** | Work Package |
| **Requirement** | F27 (dev path) |
| **Owner** | M3 |
| **Prototype Reference** | `prototype/src/screens/qr.jsx` — DEV-MODE paste field appended to `ScannerViewfinder` (contributes to 10.4) |

**Scope / Statement of Work**
Add a debug-only paste-token UI on the QR Scan screen behind a build-time flag (`const bool kDevMode = bool.fromEnvironment('DEV_MODE')`). When enabled, a text field appears below the camera preview where a JWT can be pasted manually, bypassing the camera. This enables emulator testing without a physical phone-to-phone setup. MUST be disabled in release builds — verified by checking the compiled `--release` artefact has no trace of the paste field.

**Deliverables**
- Conditional widget in `qr_scan_screen.dart` gated by `kDevMode`
- Build flag passed via `flutter run --dart-define=DEV_MODE=true`
- Release build configuration explicitly sets `DEV_MODE=false` (or omits)
- Documentation in `/README.md` on how to enable for development

**Acceptance**
- Debug build with `--dart-define=DEV_MODE=true` shows the paste field
- Debug build without the flag does NOT show it
- Release build (`flutter build apk --release`) does NOT show it regardless of flag
- Paste field accepts a JWT and calls `validateQRToken` with it

**Associated Activities**
- Add the conditional widget
- Configure build flag
- Document in README
- Verify with a release build that the field is absent

**Testing**
- Widget test (debug + flag): paste field is visible
- Widget test (debug, no flag): paste field is NOT visible
- Manual test: build a release APK, install, verify field is not visible

---

### 10.6 Success State and Trade Record Write

| Field | Detail |
|---|---|
| **WBS Code** | 10.6 |
| **Type** | Work Package |
| **Requirement** | F29, F31 |
| **Owner** | M4 |
| **Prototype Reference** | `prototype/src/screens/qr.jsx` — `QRSuccess` screen with `stage='success'` (owns); trade record + counter increments are server-side |

**Scope / Statement of Work**
Inside the transaction started by 10.2, write a `/trades/{tradeId}` document with the structured impact object computed using the formulas in 11.1, flip both declared items to `status: 'traded'`, and increment the three denormalized counters (`tradesCount`, `totalCo2Saved`, `totalWasteDiverted`) on both `/users/{uid}` documents. Trigger `onItemTraded` (8.5) on each item flip to cancel any other pending matches referencing those items. Show the Swap Confirmed screen on both clients (driven by the match `status: 'completed'` change detected by 10.3's listener and by 10.4's success return value).

**Deliverables**
- `functions/src/writeTradeAndImpact.ts` — helper called from inside 10.2's transaction
- Trade doc shape exactly matches `/trades/{tradeId}` schema in 3.6
- Item `status` flips in the same transaction
- User counters incremented in the same transaction
- `lib/screens/qr/swap_confirmed_screen.dart` — success screen showing both items, both photos, "Swap complete!" headline, and personal impact numbers from this trade

**Acceptance**
- Successful scan writes exactly one `/trades/` doc
- Both items flip to `status: 'traded'` atomically with the trade write
- Both users' counters increment by the correct CO₂ and waste amounts
- The trade's impact object matches the worked example in 11.1 when given the same inputs
- Swap Confirmed screen appears on both clients

**Associated Activities**
- Implement `writeTradeAndImpact()` helper
- Use the intensity and typical-weight constants from 11.1
- Compute per-user CO₂ and waste per the formulas
- Atomically update items and user counters within the same Firestore transaction
- Build the Swap Confirmed screen

**Pseudocode**
```typescript
async function writeTradeAndImpact(
  tx: Transaction, match: MatchDoc, matchId: string, tokenHash: string
): Promise<string> {
  // Resolve items
  const [itemFromA, itemFromB] = await Promise.all([
    tx.get(db.doc(`items/${match.userBWantsItemId}`)),  // A gives this to B
    tx.get(db.doc(`items/${match.userAWantsItemId}`)),  // B gives this to A
  ]);
  const aGives = itemFromA.data() as ItemDoc;
  const bGives = itemFromB.data() as ItemDoc;

  const wA = aGives.weight ?? TYPICAL_WEIGHT[aGives.category];
  const wB = bGives.weight ?? TYPICAL_WEIGHT[bGives.category];
  const iA = CO2_INTENSITY[aGives.category];
  const iB = CO2_INTENSITY[bGives.category];

  // A receives bGives; A's CO2 = wB * iB. A gave away aGives; A's waste = wA.
  const aCo2 = wB * iB;
  const aWaste = wA;
  const bCo2 = wA * iA;
  const bWaste = wB;

  const tradeRef = db.collection('trades').doc();
  tx.set(tradeRef, {
    matchId, completedAt: FieldValue.serverTimestamp(), jwtTokenHash: tokenHash,
    impact: {
      userAGains: { userId: match.userAId, co2Saved: aCo2, wasteDiverted: aWaste },
      userBGains: { userId: match.userBId, co2Saved: bCo2, wasteDiverted: bWaste },
    },
    itemsExchanged: { fromA: match.userBWantsItemId, fromB: match.userAWantsItemId },
  });
  tx.update(db.doc(`items/${match.userBWantsItemId}`), { status: 'traded' });
  tx.update(db.doc(`items/${match.userAWantsItemId}`), { status: 'traded' });
  tx.update(db.doc(`users/${match.userAId}`), {
    tradesCount: FieldValue.increment(1),
    totalCo2Saved: FieldValue.increment(aCo2),
    totalWasteDiverted: FieldValue.increment(aWaste),
  });
  tx.update(db.doc(`users/${match.userBId}`), {
    tradesCount: FieldValue.increment(1),
    totalCo2Saved: FieldValue.increment(bCo2),
    totalWasteDiverted: FieldValue.increment(bWaste),
  });
  return tradeRef.id;
}
```

**Testing**
- Unit test: worked example from 11.1 (Ploy's denim jacket 0.6kg clothing ⇄ Fah's kettle 1.2kg kitchenware) produces aCo2=7.2, aWaste=0.6, bCo2=15, bWaste=1.2
- Unit test: item with `weight: null` falls back to category typical
- Unit test: all 7 categories produce non-NaN, non-negative impact values
- Integration test: successful scan flips both items to `traded` and increments all 6 counter values
- Integration test: trade doc is idempotent — a re-validate of the same token does NOT write a second trade doc (covered by 10.2's ALREADY_USED check)

---

### 10.7 Hide Traded Items from Feeds Globally

| Field | Detail |
|---|---|
| **WBS Code** | 10.7 |
| **Type** | Work Package |
| **Requirement** | F10, F29 |
| **Owner** | M3 |
| **Prototype Reference** | N/A — no prototype surface (defensive query audit); ensures traded items vanish from 7.3, 7.5, 8.2, 9.1 |

**Scope / Statement of Work**
Audit all places where items are queried for display (Discover feed 7.2, User Detail item grid 7.5, Item Picker 8.2, Match list trade pill 9.1) and ensure they all filter on `status == 'active'` via the `item_service.dart` helper from 6.5. This is a defensive consistency pass to make sure no path leaks traded items into the UI.

**Deliverables**
- Audit checklist in `/docs/audit_active_item_filter.md` listing every query path and confirming each uses `activeItemsForUser()` or an equivalent `status: 'active'` filter
- Any non-compliant queries refactored

**Acceptance**
- Every item query in the codebase filters on `status: 'active'` (or is justified in writing as an exception, e.g., the My Items screen which intentionally shows traded items)
- Audit checklist committed to repo

**Associated Activities**
- Grep the codebase for `collection('items')` and `items.where`
- Verify each call site filters correctly
- Refactor any that don't
- Write up the audit

**Testing**
- Integration test: complete a trade, then open Discover for a third user — the traded items do not appear
- Integration test: complete a trade, then re-open the chat — the trade pill still references the (now traded) items (this is expected; the chat is historical)

---

## Phase 11.0 — Impact Tracker

---

### 11.1 CO₂ Intensity and Typical-Weight Lookup Tables

| Field | Detail |
|---|---|
| **WBS Code** | 11.1 |
| **Type** | Work Package |
| **Requirement** | F31 |
| **Owner** | M4 |
| **Prototype Reference** | N/A — no prototype surface (lookup constants); values displayed by 11.3 and 11.4 |

**Scope / Statement of Work**
Bundle the two lookup tables (CO₂ intensity per category, typical weight per category) as static constants in both the Cloud Functions code (for impact computation in 10.6) and the Flutter code (for UI hints in 6.2). The two copies must stay in sync; any change requires updating both files. There are exactly 7 categories: clothing, books, kitchenware, household, electronics, furniture, other.

**Deliverables**
- `functions/src/constants/impact.ts` with `CO2_INTENSITY` and `TYPICAL_WEIGHT` constants
- `lib/constants/impact.dart` with the same constants
- Comment block in both files: "Source: §8.4 of EcoSwap Planning Package. Must be kept in sync with the other copy."

**Acceptance**
- Both files have all 7 categories
- Values match the table below exactly
- A unit test asserts both copies have the same set of categories (catches drift)

**Associated Activities**
- Create both constant files
- Write the drift-detection test
- Document in README that both files must be updated together

**Constants (kg CO₂ per kg, kg)**
```typescript
export const CO2_INTENSITY: Record<Category, number> = {
  clothing: 25,
  books: 1.5,
  kitchenware: 6,
  household: 4,
  electronics: 80,
  furniture: 4,
  other: 5,
};

export const TYPICAL_WEIGHT: Record<Category, number> = {
  clothing: 0.5,
  books: 0.4,
  kitchenware: 1.0,
  household: 0.5,
  electronics: 2.0,
  furniture: 8.0,
  other: 0.5,
};
```

**Testing**
- Unit test (drift detection): both files have exactly the same 7 keys
- Unit test: every CO₂ intensity is positive
- Unit test: every typical weight is positive
- Unit test: applying the formula `weight × intensity` to the worked example (clothing 0.6kg → 0.6 * 25 = 15) produces 15

---

### 11.2 Impact Aggregation via Denormalized Counters

| Field | Detail |
|---|---|
| **WBS Code** | 11.2 |
| **Type** | Work Package |
| **Requirement** | F30 (read side) |
| **Owner** | M4 |
| **Prototype Reference** | N/A — no prototype surface (denormalized read service); feeds 11.3 and 11.4 |

**Scope / Statement of Work**
The Impact Dashboard and Profile impact strip read directly from the three denormalized counter fields on `/users/{uid}`: `tradesCount`, `totalCo2Saved`, `totalWasteDiverted`. These are incremented in 10.6 inside the same transaction as the trade write, so they're always consistent with `/trades/`. No aggregation query at read time — the dashboard is one document read.

**Deliverables**
- `lib/services/impact_service.dart` with `getCurrentUserImpact()` returning `{ trades, co2Kg, wasteKg }`
- All three values read from `/users/{currentUid}` in a single document fetch

**Acceptance**
- Dashboard read latency is comparable to a single Firestore document read (< 200ms typical)
- No aggregation query (no `sum()`, no client-side reduce)
- Reading immediately after a completed trade reflects the new values (since they're written in the same transaction)

**Associated Activities**
- Implement `ImpactService.getCurrentUserImpact()`
- Wire into dashboard (11.3) and profile strip (11.4)

**Testing**
- Unit test: `getCurrentUserImpact()` for a user with `tradesCount: 3` returns `trades: 3`
- Integration test: complete a trade, then read impact — values reflect the new trade

---

### 11.3 Impact Dashboard UI

| Field | Detail |
|---|---|
| **WBS Code** | 11.3 |
| **Type** | Work Package |
| **Requirement** | F30 |
| **Owner** | M4 |
| **Prototype Reference** | `prototype/src/screens/impact.jsx` — `ImpactDashboard` variant + `MetricCard` + `TradeRow` (owns). NOTE: same file also contains `ImpactTimeline` (variant B) and `ImpactCompare` (variant C) — MVP uses dashboard variant ONLY; B and C are design exploration, do not implement |

**Scope / Statement of Work**
Build the Impact Dashboard with a single hero number (total CO₂ saved in kg), two supporting metric cards (swaps completed, waste diverted in kg), and a list of recent trades (latest 10) showing what was swapped and the impact contribution. Top bar has the title only — no cog, no info icon, no "this month" card, no trend arrows.

**Deliverables**
- `lib/screens/impact/impact_dashboard_screen.dart`
- Hero number widget
- Two metric cards (swaps, waste)
- Recent trades list (paginated, latest 10 by `completedAt`)
- NO trend arrow ("↑38%"), NO "This month" card, NO comparison stats

**Acceptance**
- Hero displays total CO₂ from `/users/{uid}.totalCo2Saved`
- Two cards display trades count and waste diverted
- Recent trades list shows latest 10 trades involving the current user
- No out-of-scope UI elements

**Associated Activities**
- Build dashboard screen
- Query `/trades/` for current user's recent trades
- Wire counters from `ImpactService` (11.2)

**Testing**
- Widget test: hero number reads from `totalCo2Saved`
- Widget test: dashboard shows exactly the 3 stat surfaces (hero + 2 cards)
- Widget test: trade list shows latest 10 by `completedAt`
- Widget test: NO trend arrow appears

---

### 11.4 Impact Stats on Profile

| Field | Detail |
|---|---|
| **WBS Code** | 11.4 |
| **Type** | Work Package |
| **Requirement** | F32 |
| **Owner** | M4 |
| **Prototype Reference** | `prototype/src/screens/profile.jsx` — `SummaryStat` strip (3 stats) embedded in `ProfileScreen` (contributes to 5.4) |

**Scope / Statement of Work**
Add a 3-stat horizontal strip to the Profile screen (5.4) showing: swaps, CO₂ saved (kg), waste diverted (kg). Reads from the same denormalized counters as the dashboard.

**Deliverables**
- Profile-screen widget at `lib/widgets/impact_stat_strip.dart`
- 3 stats horizontally: count, CO₂, waste
- Reads via `ImpactService.getCurrentUserImpact()`

**Acceptance**
- All 3 stats displayed
- Values match what's shown on the dashboard
- No trend arrows, no comparisons

**Associated Activities**
- Build strip widget
- Wire into Profile screen
- Format numbers with one decimal place for CO₂ and waste, integer for swaps

**Testing**
- Widget test: strip renders 3 stat values
- Widget test: values match `getCurrentUserImpact()` output

---

## Phase 12.0 — Testing and QA

> Unit tests for proximity scoring, JWT signing/validation, and impact calculation are folded into the feature tasks that own that code (7.1, 10.1, 10.2, 11.1, 10.6). This phase covers only the cross-cutting test work.

---

### 12.1 Integration Test — Full Swipe → Match → Trade Flow

| Field | Detail |
|---|---|
| **WBS Code** | 12.1 |
| **Type** | Work Package |
| **Requirement** | End-to-end verification |
| **Owner** | M5 |
| **Prototype Reference** | Test exercises every screen in `prototype/src/screens/` along the critical path |

**Scope / Statement of Work**
Write a single end-to-end integration test that exercises the critical path: two users sign up, set up profiles, upload items, swipe right on each other with item declarations, see a match created, exchange messages, complete a QR exchange via DEV-MODE paste, and verify that both items flip to `traded`, the trade record is written with correct impact numbers, and both user counters are incremented. Runs against the Firebase Emulator Suite, not production.

**Deliverables**
- `integration_test/full_flow_test.dart`
- Emulator config in `/firebase.json` and `/scripts/start_emulators.sh`
- CI hook (or documented manual run command) to execute the test

**Acceptance**
- Test runs against emulator
- Test exercises all the steps listed in the Scope
- Test asserts: both items `status: 'traded'`, 1 trade doc, both users' counters incremented by correct amounts
- Test runtime < 90 seconds
- Test is deterministic (same inputs always produce same result)

**Associated Activities**
- Configure Firebase Emulator Suite locally
- Write the integration test using `integration_test` package and DEV-MODE paste path
- Document how to run

**Testing (self)**
- The integration test IS the test; running it is the verification

---

### 12.2 Manual Test Plan

| Field | Detail |
|---|---|
| **WBS Code** | 12.2 |
| **Type** | Work Package |
| **Requirement** | Pre-demo verification |
| **Owner** | M5 |
| **Prototype Reference** | Test plan covers every screen listed in Appendix A |

**Scope / Statement of Work**
Write a manual test plan covering all 32 MVP functions (F01–F32) plus edge cases not covered by automated tests (camera permission flows, real device QR scanning, error toasts, network failure handling). Each test case is a numbered step-by-step procedure with an expected result.

**Deliverables**
- `/docs/manual_test_plan.md` with ~50 test cases
- One test case per MVP function plus targeted edge cases

**Acceptance**
- Every F01–F32 function has at least one test case
- Test cases are step-by-step and unambiguous
- Plan is reviewed by at least one other team member

**Associated Activities**
- Walk the MVP function list and write one test case per function
- Add edge cases: permission denials, network drop, expired QR scan, etc.

---

### 12.3 Bug Bash Session (Day 9 Afternoon)

| Field | Detail |
|---|---|
| **WBS Code** | 12.3 |
| **Type** | Work Package |
| **Requirement** | Pre-demo verification |
| **Owner** | M5 (coordinator), all participate |
| **Prototype Reference** | Bug bash covers every screen listed in Appendix A |

**Scope / Statement of Work**
Run a 3-hour bug bash on Day 9 where all 5 team members test the app simultaneously, each focusing on a different persona-driven scenario. Bugs are logged in a shared sheet with severity. Sev-1 and Sev-2 bugs are fixed before the demo; Sev-3 bugs are documented as known issues in the final report.

**Deliverables**
- `/docs/bug_bash_results.md` listing all bugs found, with severity, owner, and resolution
- Sev-1 and Sev-2 fixed by end of Day 9
- Sev-3 documented in final report's "known issues" section

**Acceptance**
- All 5 team members spent at least 2 hours testing
- All bugs logged with severity
- All Sev-1 and Sev-2 closed before Day 10 morning

**Associated Activities**
- Set up shared bug log
- Brief each tester on which persona/scenario to focus on
- Run the session
- Triage and assign bugs
- Fix critical issues

---

### 12.4 Demo Dry Run (Day 10 Morning)

| Field | Detail |
|---|---|
| **WBS Code** | 12.4 |
| **Type** | Work Package |
| **Requirement** | Demo readiness |
| **Owner** | M5 |
| **Prototype Reference** | Dry run walks the demo path: `splash` → `auth` → `setup` → `discover` → `picker` → `match` → `chat` → `qr` (show/scan/success) → `impact` |

**Scope / Statement of Work**
Run a full demo dry-run on Day 10 morning, including the 7-minute presentation and the live app demo. Identify any flaky steps, decide on the demo data (pre-seeded accounts), and finalise the backup demo video (13.3) in case the live demo fails.

**Deliverables**
- Demo script at `/docs/demo_script.md`
- Pre-seeded demo accounts documented at `/docs/demo_accounts.md`
- Confirmed backup demo video ready

**Acceptance**
- Dry run completes without crashes
- Demo script timing is within ±30s of the 7-minute target
- Backup video covers all the same beats as the live demo

**Associated Activities**
- Pre-seed demo accounts with prepared items and matches
- Walk through the script
- Time each section
- Record backup video if not already done (13.3)

---

## Phase 13.0 — Deliverables

---

### 13.1 Code Zip and GitHub Repo

| Field | Detail |
|---|---|
| **WBS Code** | 13.1 |
| **Type** | Work Package |
| **Requirement** | Course submission |
| **Owner** | All (M5 coordinates) |
| **Prototype Reference** | N/A — no prototype surface (repo hygiene); `prototype/` directory is committed to the repo (Option 1) |

**Scope / Statement of Work**
Final repo state: clean main branch, no commented-out code, no secrets in git history, README with full setup instructions, contributing guidelines, and license. Code is also archived as a zip for hand-in. README must enable a fresh-machine clone-and-build by a non-team developer following the steps.

**Deliverables**
- Public (or shared-private) GitHub repo
- `README.md` covering: project description, tech stack, prerequisites (Flutter version, Firebase CLI version), step-by-step setup (`firebase init`, `flutter pub get`, secrets setup, emulator commands), how to run, how to test
- `LICENSE` file
- `.gitignore` excludes `google-services.json` if it has secrets, `.env`, `firebase-debug.log`, etc.
- Zip archive at `/deliverables/ecoswap_source.zip`

**Acceptance**
- A teammate (or instructor) can clone, follow README, and run the app on an Android emulator in under 30 minutes
- No secrets in git history (verified with `git log -p | grep -i secret`)
- All branches squashed/merged into main before submission

**Associated Activities**
- Write README
- Audit git history for secrets
- Clean up commented-out code
- Create zip

---

### 13.2 Final Report

| Field | Detail |
|---|---|
| **WBS Code** | 13.2 |
| **Type** | Work Package |
| **Requirement** | Course submission |
| **Owner** | M5 (lead), all contribute |
| **Prototype Reference** | N/A — no prototype surface (written report) |

**Scope / Statement of Work**
See 1.6 — same deliverable, restated here as a Phase 13.0 entry to make submission ownership explicit.

**Deliverables**
- See 1.6

**Acceptance**
- See 1.6

**Associated Activities**
- See 1.6

---

### 13.3 Demo Video

| Field | Detail |
|---|---|
| **WBS Code** | 13.3 |
| **Type** | Work Package |
| **Requirement** | Demo backup |
| **Owner** | M3 |
| **Prototype Reference** | Video walks: `splash` → `auth` → `setup` → `discover` → `picker` → `match` → `chat` → `qr` (show/scan/success) → `impact` dashboard |

**Scope / Statement of Work**
Record a 5–7 minute screen-and-narration demo video covering the same flow as the live demo: sign up, profile setup with district picker, item upload, swipe, match, chat, QR exchange (DEV-MODE paste), and impact dashboard. Video is the fallback if the live demo fails (network issue, emulator crash, etc.).

**Deliverables**
- Video file at `/deliverables/ecoswap_demo.mp4`
- Length 5–7 minutes
- Voiceover or captions explaining each step
- Covers all the same beats as the live demo script (12.4)

**Acceptance**
- Video plays end-to-end without quality issues
- All MVP function highlights covered
- Length within target

**Associated Activities**
- Record screen capture against pre-seeded demo data
- Add narration or captions
- Export

---

### 13.4 Live Demo Presentation

| Field | Detail |
|---|---|
| **WBS Code** | 13.4 |
| **Type** | Work Package |
| **Requirement** | Course submission |
| **Owner** | All |
| **Prototype Reference** | Live demo walks the same path as 13.3 |

**Scope / Statement of Work**
Present the 7-minute live demo on Day 10. M5 narrates, M1–M4 operate the apps on two physical devices (or one device + emulator). Two-device setup is required to demonstrate real-time chat and the QR scan path. If the live setup fails, fall back to the demo video (13.3).

**Deliverables**
- Presentation slides at `/deliverables/ecoswap_slides.pdf` (optional, depending on course requirements)
- Live demo executed within the 7-minute window
- Fallback to demo video if live demo fails

**Acceptance**
- Demo presented within time limit
- All key flows shown (swipe → match → chat → QR → impact)
- Fallback plan rehearsed (i.e., having the video queued and ready)

**Associated Activities**
- Prepare slides
- Rehearse (12.4)
- Set up devices on demo day
- Present

---

## Appendix A — Screen Inventory and WBS Ownership Map

Reverse lookup: every screen and significant component in the Claude Design prototype, mapped to the WBS entry that owns its implementation. Use this on Day 5 to confirm no prototype element is orphaned, and use it during bug-bash triage to find the owner of a broken screen quickly.

Source: `prototype/src/screens/*.jsx` in the Claude Design export.

### Top-level screens (in app navigation order)

| Prototype Screen | Source File | Owner Entry | Owner Member | Notes |
|---|---|---|---|---|
| Splash | `splash.jsx` | 2.4 (export) | M5 | Entry point; no Flutter logic beyond first-launch routing |
| Auth (sign-up) | `auth.jsx` | 4.1 | M1 | One screen, two modes via `mode` prop |
| Auth (sign-in) | `auth.jsx` | 4.2 | M1 | Same screen, different mode |
| Setup wizard — step 1 (name + photo) | `setup.jsx` | 5.1 | M1 | `PhotoUpload` atom |
| Setup wizard — step 2 (district) | `setup.jsx` | 5.2 | M3 | `AreaSearch`, `AreaSearching`, `AreaSelected` |
| Setup wizard — step 3 (bio) | `setup.jsx` | 5.3 | M1 | 140-char bio editor |
| Discover (swipe feed) | `discover.jsx` | 7.3 | M3 | Host; uses `SwipeCard` |
| User Detail | `userdetail.jsx` | 7.5 | M3 | Includes `ItemDetailSheet` bottom sheet |
| Item Picker | `picker.jsx` | 8.2 | M1 | Bottom sheet, ~70% height; `ItemPickCard` component |
| Match celebration | `match.jsx` | 8.4 | M1 | `MatchScreen` with item-↔-item layout |
| Chats list | `chats.jsx` | 9.1 | M2 | `ChatsScreen` with empty state |
| Match chat | `chat.jsx` | 9.2 | M2 | `ChatScreen` with `Bubble` and Ready button |
| QR — show stage | `qr.jsx` (`stage='show'`) | 10.3 | M3 | `QRScreen` + `QRPattern` + `Countdown` + `FraudExplainer` |
| QR — scan stage | `qr.jsx` (`stage='scan'`) | 10.4 | M3 | `ScannerViewfinder` + `CornerMarkers` |
| QR — success stage | `qr.jsx` (`stage='success'`) | 10.6 | M4 (server) + M3 (UI) | `QRSuccess` screen |
| Impact dashboard | `impact.jsx` (`variant='dashboard'`) | 11.3 | M4 | `ImpactDashboard` + `MetricCard` + `TradeRow` |
| Profile | `profile.jsx` | 5.4 | M1 | Hosts `SummaryStat` strip from 11.4 |
| Edit Profile | `editprofile.jsx` | 5.4 | M1 | Reuses district picker (5.2) and bio editor (5.3) atoms |
| My Items | `myitems.jsx` | 6.3 | M2 | 2-col grid + floating add button |
| Upload Item | `upload.jsx` | 6.2 | M2 | Full form |
| Edit Item | `upload.jsx` (edit mode) | 6.4 | M2 | Reuses Upload form atoms |

### Reusable components and atoms (cross-screen)

| Component | Source File | Owner Entry | Notes |
|---|---|---|---|
| `SwipeCard` | `discover.jsx` | 7.3 | Used inside Discover |
| `ProximityPicker` bottom sheet | `discover.jsx` | 7.4 | Triggered from Discover's proximity pill |
| `ItemDetailSheet` bottom sheet | `userdetail.jsx` | 7.5 | Triggered from User Detail item grid |
| `ItemPickCard` | `picker.jsx` | 8.2 | Used inside Item Picker |
| `Bubble` | `chat.jsx` | 9.2 | Used inside Match chat |
| `QRPattern` | `qr.jsx` | 10.3 | Used inside QR show |
| `Countdown` | `qr.jsx` | 10.3 | Used inside QR show |
| `FraudExplainer` | `qr.jsx` | 10.3 | Used inside QR show |
| `ScannerViewfinder` | `qr.jsx` | 10.4 | Used inside QR scan |
| `MetricCard` | `impact.jsx` | 11.3 | Used inside Impact dashboard |
| `TradeRow` | `impact.jsx` | 11.3 | Used inside Impact dashboard |
| `SummaryStat` | `profile.jsx` | 11.4 | Strip embedded in Profile |
| `PhotoUpload` | `setup.jsx` | 5.1 | Reused for editable avatar in 5.4 |
| `AreaSearch` (with `AreaSearching` + `AreaSelected`) | `setup.jsx` | 5.2 | Reused as `DistrictRow` + picker in `editprofile.jsx` |
| `PhotoField` | `upload.jsx` | 6.1 | Reused by 6.4 Edit Item |
| `ConditionPills`, `CategoryRow`, `TextField`, `TextArea` | `upload.jsx` | 6.2 | Reused by 6.4 Edit Item |
| `EditableAvatar` | `editprofile.jsx` | 5.4 | Edit-mode avatar with camera badge |
| `DistrictRow` | `editprofile.jsx` | 5.2 | Edit-mode district tap-row |

### Out-of-scope prototype variants (do NOT implement in MVP)

These exist in the Claude Design export for design reference but are NOT part of MVP. They will not be re-implemented in Flutter.

| Prototype Element | Source | Reason |
|---|---|---|
| `ImpactTimeline` (variant B) | `impact.jsx` | MVP uses dashboard variant only; Timeline is design exploration |
| `ImpactCompare` (variant C), `GoalArc`, `CompareRow`, `CategoryBreakdown` | `impact.jsx` | MVP uses dashboard variant only; Compare is design exploration |
| `tweaks-panel.jsx` | `src/` | Prototype-only design-time control panel |
| `android-frame.jsx` | `src/` | Prototype-only chrome to simulate Android device frame |

### Coverage check

Every screen and reusable component in the prototype's `src/screens/` directory has exactly one owner entry above, with the following intentional shared cases:

- **Auth screen** is jointly owned by 4.1 (sign-up mode) and 4.2 (sign-in mode) — they implement different modes of the same screen file
- **Setup wizard** has three owners (5.1, 5.2, 5.3) — one per step
- **QR screen** has three owners (10.3, 10.4, 10.6) — one per stage
- **Upload form** is owned by 6.2; **Edit form** by 6.4 — they share atoms but are separate routes
- **Profile screen** is jointly owned by 5.4 (host + edit) and 11.4 (impact strip) and 4.3 (logout button)

No prototype element is orphaned. No MVP function is missing a UI surface (cross-checked against F01–F32).

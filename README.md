# EcoSwap

A Tinder-style swap app for second-hand items. You swipe through people near you,
discover what they're giving away, and arrange a face-to-face swap — no money, no
shipping, just a fairer way to keep good things out of landfill. Built with Flutter
+ Firebase.

> **Swap** is the user-facing word. **Trade** is the same thing in the code/data layer.

---

## How the app works — the full flow

```
Splash → Sign up / Sign in → Profile setup → How-It-Works tutorial
   → Discover (swipe) → Match → Chat → QR exchange → Swap confirmed → Impact updated
```

### 1. Sign up / Sign in
Open the app to the splash screen, then create an account or sign in. Email + password.

### 2. Set up your profile (3 quick steps)
A short wizard runs the first time you sign up:

1. **Who you are** — add a photo and a display name so other swappers recognise you.
2. **Where you are** — search and pick your **district** from a bilingual (Thai · English)
   dropdown. EcoSwap **never shows your exact location** — only your district, so the app
   can show you swappers nearby. There's no map, no GPS, no distance in kilometres.
3. **About you** — one short bio line (up to 140 characters).

Tap **Start swapping** when you're done. (You can edit any of this later from **Profile**.)

### 3. Learn the ropes
A one-time **How It Works** tutorial appears on first launch. You can replay it any time
from **Profile → How it works**.

---

## The four tabs

Once you're set up, the app is organised into four tabs along the bottom:

| Tab | What it's for |
|---|---|
| **Discover** | The swipe deck — find people and their items near you |
| **Chats** | Your matches and conversations |
| **Impact** | Your environmental impact: CO₂ saved and waste diverted |
| **Profile** | Your profile, your items, and settings |

### Before you swipe: add your items
Other people swipe on **your** stuff too, so add a few items first:

- Go to **Profile → My Items → Add**.
- Upload a photo, give it a title, pick a category, and add a short description.
- Your items appear in a grid you can edit or remove any time.

---

## Discover — swiping

The **Discover** tab shows one swipe card at a time. Each card highlights a person, their
district, and a row of the items they're offering.

- **Swipe right** → you're interested. You'll be asked to **pick one of your own items**
  to offer in return. (You choose exactly one item — that pick is final for this swap.)
- **Swipe left** → skip; the next card comes up.
- **Tap the card** → open the person's full detail to browse all their items before deciding.

Use the **proximity filter** at the top to widen or narrow how far afield the deck looks:

- **Same district** → people in your district
- **Same province** → anywhere in your province
- **Nearby provinces** → neighbouring provinces
- **All Thailand** → no proximity limit

Switching back to the Discover tab refreshes the deck, so people who became available
again after a swap can reappear.

---

## Match → Chat

When **both** of you have shown interest in each other's items, **it's a match!** A
celebration screen shows the two items side by side — what you're giving and what you're
getting.

From there:
- Tap **Send a message** to open the chat, where the new match is waiting in your **Chats** tab.
- Or **Keep swiping** and message them later.

Use the chat to agree on a time and place to meet in person.

---

## QR exchange — completing the swap

When you meet up, EcoSwap uses a **secure QR handshake** so both people confirm the swap
actually happened. From the chat, open the QR exchange:

- **Show** — your phone displays a QR code. It carries a signed, **single-use code that
  expires after 60 seconds** and refreshes every 30, so a screenshot is useless.
- **Scan** — the other person points their camera at your code (or you scan theirs).

The code is validated on the server with four checks: it's genuinely from EcoSwap, it
hasn't expired, it's between the **two of you**, and it hasn't already been used. Once it
passes, you'll see **Swap confirmed** 🎉.

### 4. Your impact updates automatically
After a confirmed swap, EcoSwap credits your environmental impact:

- **CO₂ saved** — based on the item you **received** and its category.
- **Waste diverted** — based on the weight of the item you **gave**.

See the running totals any time on the **Impact** tab.

---

## Quick start (running the app)

```bash
flutter pub get
flutter run
```

For the full development workflow, repo layout, and contribution guide, read
[`CLAUDE.md`](./CLAUDE.md). For the complete project plan, see
[`docs/EcoSwap_Planning_Package_v1_2.docx`](./docs/EcoSwap_Planning_Package_v1_2.docx).

---

## DEV-MODE paste-token fallback (WBS 10.5)

The QR Scan screen includes a debug-only paste field that lets you submit a code
manually, bypassing the camera. This is useful when testing on an emulator or a
single device where a phone-to-phone QR scan is not possible.

### Enabling DEV-MODE

Pass the build flag at run time:

```
flutter run --dart-define=DEV_MODE=true
```

When enabled, a text field labelled "Or paste code…" and a **Submit** button
appear below the camera viewfinder on the Scan screen. Paste a valid code there
and tap Submit — it is validated by the same Cloud Function path as a real camera scan.

### Release builds

DEV-MODE is **disabled by default**. Omitting `--dart-define=DEV_MODE=true` or
building with `--release` produces a binary with no trace of the paste field.
The CI `build-apk` job explicitly passes `--dart-define=DEV_MODE=false` to
ensure the artefact shipped to teammates never includes the debug path.

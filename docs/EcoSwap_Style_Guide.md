# EcoSwap — Design System

Mobile-first design tokens and guidelines for the EcoSwap prototype.
Use this as the source of truth for all screens. If a screen needs a value that isn't documented here, add it here first, then use it.

---

## 1. Brand foundation

**Product name:** EcoSwap
**Tagline:** Swap, don't shop.
**Voice:** Friendly, casual, optimistic. Never preachy about the environment. Never corporate.
**Audience:** Thai students and young professionals, 21-30, mobile-first, comfortable with Tinder-style UX.

**Visual personality:**
- Warm and trustworthy, not sterile
- Eco theme communicated through color and impact stats — never through cliché icons (no leaves, no globes, no recycling symbols)
- Confident whitespace, not crowded
- Static, calm UI — motion only on swipe gestures and trade completion

---

## 2. Color tokens

### Primary palette

| Token | Hex | Use |
|---|---|---|
| `--green-primary` | `#1D9E75` | Like button, primary CTAs, impact stat highlights, links |
| `--green-dark` | `#0F6E56` | Pressed state for primary buttons, headings on green backgrounds |
| `--green-soft` | `#E1F5EE` | Like badge background, success toast background, impact stat surfaces |

### Neutrals

| Token | Hex | Use |
|---|---|---|
| `--surface` | `#FFFFFF` | Page background, card background |
| `--surface-alt` | `#F7F5F0` | Subtle surfaces (form fields, item thumbnails behind photo) |
| `--border` | `#E5E5E0` | Card borders, dividers, input borders |
| `--text-primary` | `#1A1A1A` | Body text, headings |
| `--text-secondary` | `#6B6B66` | Captions, metadata (distance, timestamps, "X km away") |
| `--text-tertiary` | `#A0A09B` | Placeholder text, hints |

### Semantic

| Token | Hex | Use |
|---|---|---|
| `--danger` | `#C44545` | Skip button, delete confirmation, error messages |
| `--danger-soft` | `#FCEBEB` | Skip button background |
| `--warning` | `#BA7517` | "Expires soon" warnings (QR countdown under 30s), unread badge |
| `--info` | `#185FA5` | Informational toasts, link-like text |

### Color usage rules

- Never use pure black (`#000`) for text — always `--text-primary`
- Never use pure white surfaces with green accents — looks medical. Always `--surface-alt` for subtle hierarchy
- Green is for *user actions* (Like, Confirm) and *impact stats*. Don't use green for everything just because it's the brand color
- Danger red is muted on purpose. Aggressive red feels like a banking app, not a friendly swap app

---

## 3. Typography

**Font family:** Inter (or system sans-serif fallback: `-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif`)

### Type scale

| Token | Size | Weight | Line height | Use |
|---|---|---|---|---|
| `display` | 32px | 600 | 1.2 | Match notification "It's a Match!", impact dashboard hero number |
| `h1` | 24px | 600 | 1.3 | Screen titles |
| `h2` | 20px | 600 | 1.3 | Section headings, user name on card |
| `h3` | 16px | 600 | 1.4 | Item name, sub-section labels |
| `body` | 15px | 400 | 1.5 | Default text, chat messages, descriptions |
| `body-strong` | 15px | 500 | 1.5 | Emphasized inline text |
| `caption` | 13px | 400 | 1.4 | Metadata, "X km away", timestamps |
| `tiny` | 11px | 500 | 1.3 | Badge labels, status pills |

### Typography rules

- No font sizes below 11px
- Two weights only: 400 (regular) and 600 (semibold). Skip 500 except for `body-strong`
- Never use italics for body text — italics only for placeholder text or testimonial-style quotes
- Sentence case for buttons and headings. Never Title Case. Never ALL CAPS

---

## 4. Spacing

Base unit: 4px. All spacing is a multiple of 4.

| Token | Value | Use |
|---|---|---|
| `space-1` | 4px | Tight icon-to-text gaps |
| `space-2` | 8px | Compact stacks |
| `space-3` | 12px | Default gap inside components |
| `space-4` | 16px | Standard padding inside cards |
| `space-5` | 20px | Between related sections |
| `space-6` | 24px | Between distinct sections |
| `space-8` | 32px | Major vertical rhythm, before screen titles |
| `space-10` | 40px | Top of screen below status bar |

**Edge gutters:** 16px on left and right of every mobile screen. Never let content touch the edge.

---

## 5. Radius and elevation

### Border radius

| Token | Value | Use |
|---|---|---|
| `radius-sm` | 6px | Small pills, badges |
| `radius-md` | 8px | Buttons, input fields |
| `radius-lg` | 12px | Cards (item, user, message bubble) |
| `radius-xl` | 20px | Hero cards (swipe card), bottom sheets |
| `radius-full` | 9999px | Avatars, circular buttons |

### Elevation

Avoid shadows except where they communicate state. We are not iOS, we are not Material Design — we are flat with intent.

| Token | Value | Use |
|---|---|---|
| `shadow-none` | none | Default state for cards |
| `shadow-card` | `0 1px 3px rgba(0,0,0,0.06)` | Swipe card only (so it feels grabbable) |
| `shadow-modal` | `0 8px 24px rgba(0,0,0,0.12)` | Modals, bottom sheets, item picker |

**Never use shadows on:**
- Buttons
- Input fields
- Static cards in lists
- Anything that isn't draggable or floating

---

## 6. Components

### Buttons

**Primary button**
- Background: `--green-primary`
- Text color: white
- Padding: 14px 20px
- Font: body-strong (15px / 500)
- Radius: `radius-md` (8px)
- Pressed: background → `--green-dark`
- Disabled: 40% opacity
- Min height: 48px (thumb-friendly)
- Full width on mobile by default

**Secondary button**
- Background: `--surface-alt`
- Text color: `--text-primary`
- Border: 1px solid `--border`
- Same dimensions as primary

**Destructive button**
- Background: `--danger-soft`
- Text color: `--danger`
- Same dimensions

**Icon-only button (e.g., back arrow, close)**
- Size: 40x40px tap area, 24x24 icon centered
- Background: transparent
- No border in default state

### Swipe action buttons (Like / Skip)

These are visually distinct from regular buttons — they're circular and float at the bottom of the swipe card.

- Size: 56x56px circle
- Like button: white background, `--green-primary` heart icon (24px), `--green-soft` border 1px
- Skip button: white background, `--danger` X icon (24px), `--danger-soft` border 1px
- Drop shadow: `shadow-card`
- Spaced 24px apart horizontally, centered below card

### Input fields

- Background: `--surface-alt`
- Border: 1px solid `--border`
- Padding: 12px 14px
- Font: body (15px)
- Radius: `radius-md` (8px)
- Focus state: border becomes `--green-primary` 2px, no shadow
- Min height: 44px
- Label above field, never floating label

### Cards

**User card (swipe feed)**
- Background: white
- Radius: `radius-xl` (20px)
- Border: 1px solid `--border`
- Shadow: `shadow-card`
- Padding: 0 (content controls its own padding)
- Aspect ratio: roughly 3:4 (375 wide × 500 tall on iPhone)
- Content stack: photo (60%), info section (40%) with name, distance, trust score, items row

**Item card (grid)**
- Background: `--surface-alt`
- Radius: `radius-lg` (12px)
- Border: none
- Padding: 12px
- Photo: square, full width of card, radius 8px

**Message bubble**
- Own messages: background `--green-primary`, text white, align right
- Their messages: background `--surface-alt`, text `--text-primary`, align left
- Padding: 10px 14px
- Radius: `radius-lg` (12px), with one corner clipped to `radius-sm` on the side closest to the sender
- Max width: 75% of screen

### Avatar

- Circle, `radius-full`
- Default sizes: 32px (chat list), 40px (chat header), 56px (profile preview), 96px (own profile)
- Fallback: initials in `--green-soft` background, `--green-dark` text

### Badge / Pill

- Padding: 4px 10px
- Radius: `radius-full`
- Font: tiny (11px / 500)
- Variants:
  - **Trust score**: `--surface-alt` background, `--text-primary` text, star icon prefix
  - **New user**: `--green-soft` background, `--green-dark` text
  - **Condition** (new/like-new/good/used): `--surface-alt` background, `--text-secondary` text

### Bottom navigation bar

- Height: 64px + safe area inset
- Background: white
- Border-top: 1px solid `--border`
- 3 tabs: Discover, Chats, Profile
- Active state: icon and label both `--green-primary`
- Inactive state: `--text-secondary`
- No shadow

---

## 7. Iconography

**Icon library:** Lucide (or Material Symbols outlined if Claude Design uses that)

**Icon style rules:**
- Outline style only, never filled (even for active states — use color change instead)
- Stroke width: 2px
- Sizes: 16px (inline with text), 20px (default), 24px (buttons), 32px (empty states)
- Color inherits from text color of parent

**Specific icon choices** (be consistent across screens):
- Like = `heart`
- Skip = `x`
- Distance = `map-pin`
- Filter = `sliders-horizontal`
- Chat = `message-circle`
- Profile = `user`
- Discover = `compass`
- Camera = `camera`
- QR = `qr-code`
- Trust score = `star`
- Impact (CO2) = `leaf` *(only acceptable use of a "nature" icon — it appears next to a hard number, not as decoration)*
- Settings = `settings`
- Edit = `pencil`
- Delete = `trash-2`
- Send message = `send`
- Add item = `plus`

**Never use:** smiley faces, globes, recycling triangles, hand-drawn icons, multi-color icons.

---

## 8. Screen layout grid

### Mobile viewport
- Target: 390 × 844 (iPhone 14)
- Safe area top: 47px (status bar + notch)
- Safe area bottom: 34px (home indicator)
- Usable area: 390 × 763

### Standard screen template

```
┌─────────────────────────────┐
│  Status bar (47px)          │
├─────────────────────────────┤
│  Top bar (56px)             │  ← back arrow + title or filters
├─────────────────────────────┤
│                             │
│  Content area               │  ← scrollable
│  Edge gutter: 16px L/R      │
│                             │
├─────────────────────────────┤
│  Bottom nav (64px)          │  ← only on top-level screens
├─────────────────────────────┤
│  Home indicator (34px)      │
└─────────────────────────────┘
```

**Top bar variations:**
- **Hierarchical:** back arrow (left) + centered title + optional right action icon
- **Top-level:** logo or large title (left-aligned) + right action icons
- **Filter:** filter chip row, no back arrow

**Bottom nav:** shows on Discover, Chats, Profile screens only. Hides on Match Chat, QR Exchange, Item Picker, modals.

---

## 9. Motion and interaction

**Animation budget:** Keep simple. The prototype is judged on clarity, not flashiness.

| Element | Animation |
|---|---|
| Swipe card | Drag follows finger. Release < 80px = snap back. Release > 80px = fly off in swipe direction over 300ms |
| Like / Skip button tap | Scale 1 → 0.92 → 1 over 150ms, then trigger swipe animation |
| Match notification | Fade in over 200ms, then both avatars scale-in from 0.8 → 1 with slight bounce |
| QR success | Checkmark draws over 400ms, then numbers count up over 800ms |
| Page transitions | Push from right (forward) / push to right (back), 250ms ease-out |
| Modal / bottom sheet | Slide up from bottom over 300ms, backdrop fades to 40% opacity |
| Tap feedback | Background lightens 4% over 80ms then back |

**No animation on:**
- Idle states (no breathing, no shimmer, no decorative motion)
- Scroll (no parallax)
- Card grids (no stagger entrance — too gimmicky)

---

## 10. Empty states

Often skipped, often the most-seen part of an app. Generate every empty state explicitly.

**Template:**
- Center-aligned, full screen below top bar
- Small icon (40px, `--text-tertiary`)
- Headline in h3
- Description in body, `--text-secondary`, max 2 lines
- Optional CTA button below

**Specific copy:**

| Screen | Headline | Description | CTA |
|---|---|---|---|
| Discover (no users in range) | No one nearby yet | Try widening your search radius, or check back later — new swappers join every day. | Widen search |
| Chats (no matches) | No matches yet | Start swiping on the Discover tab to find people to swap with. | Go to Discover |
| My Items (no items) | Nothing to swap yet | Add an item from your room — books, clothes, kitchen things — anything you don't use anymore. | Add your first item |
| Impact (no trades) | Your impact starts soon | After your first swap, you'll see how much CO₂ and waste you've kept out of the landfill. | (no CTA, navigation lives elsewhere) |

---

## 11. Realistic dummy data

Use this set across all screens so prototypes feel coherent. Never use "User 1, Item 1."

### People

| Name | Age | Location | Bio |
|---|---|---|---|
| Ploy | 21 | Bang Mod (0.8 km) | Comm student. Decluttering my dorm. |
| Fah | 28 | Asoke (3.2 km) | Marketing. Trying to live with less. |
| Beam | 23 | Bang Na (1.4 km) | New grad setting up my first place. |
| Mint | 22 | Thonburi (2.1 km) | Architecture student. Books and design stuff to swap. |
| Nan | 26 | Phra Khanong (4.5 km) | Loves cooking, has too many kitchen gadgets. |

### Items

| Item | Category | Condition | Owner |
|---|---|---|---|
| Leather tote bag | Clothing | Like new | Ploy |
| 3 design books | Books | Good | Ploy |
| Electric kettle | Kitchenware | Like new | Fah |
| Desk lamp | Household | Good | Fah |
| Yoga mat | Household | New | Mint |
| Rice cooker (1-person) | Kitchenware | Good | Nan |
| Hardcover novels (5) | Books | Like new | Beam |

### Sample chat

```
Fah:  Hi! Saw your tote bag — would you swap for my electric kettle?
You:  Yes! When can we meet?
Fah:  How about tomorrow 6pm at Asoke BTS exit 2?
You:  Perfect, see you there 🙌
```
*(Use one emoji max per chat sample. Looks casual without looking unprofessional.)*

### Sample impact stats

- Items swapped: 7
- CO₂ saved: 47.5 kg
- Waste diverted: 12.3 kg

These numbers feel right (not a single-digit "1 item" that looks empty, not "1000 items" that looks fake).

---

## 12. Specific screen-by-screen notes

These add on to the design system, calling out the parts that need extra attention per screen.

**Splash:** Logo (text-only is fine: "EcoSwap" in display weight, `--green-primary`) + tagline. No animation, no loading spinner.

**Login / Signup:** Single-column form. Inputs full width. Primary button below. "Forgot password?" link below button. Sign-in-with-Google can be a placeholder square (not in MVP but reserve the space).

**Profile setup:** 3-step wizard. Progress dots top center. Each step has back arrow + Next button. Step 3 (bio) has "Skip" link as alternative to Next.

**Discover / Swipe Feed:** Card centered, 16px gutter. Like/Skip buttons 24px below card. Top has filter chip and small "5 km" indicator.

**User detail:** Open as full-screen modal (slide up). User photo at top, then bio, then items grid. Single "Like" button fixed at bottom (sticky), opens item picker.

**Item picker modal:** Bottom sheet, takes ~70% of screen height. Grid of their items (2 per row), tap to select (selected = green border 2px). Confirm button at bottom, disabled until at least 1 selected.

**Match notification:** Full screen, dark backdrop (40% black overlay over previous screen). Centered: both avatars side by side, display-size "It's a Match!", small description "You both want each other's items", "Start chatting" primary button + "Keep swiping" secondary text link below.

**Chats list:** Vertical list of match cards. Each card: avatar 32px, name, last message preview (1 line, ellipsis), timestamp right-aligned, unread badge if applicable.

**Match chat:** Header pinned with avatar + "Bag for kettle" pill showing the agreed trade. Messages below. Input at bottom with send button. "Ready to exchange" button at top-right of header opens QR.

**QR exchange:** Two-tab toggle at top (Show QR / Scan QR). Show side: large QR centered, countdown below ("Expires in 47s"), small text "Show to [name]" above. Scan side: camera viewfinder (placeholder square with corners), "Point at [name]'s QR" instruction, dev paste field below.

**Impact dashboard:** Display-size hero number top center (e.g., "47.5 kg" with "CO₂ saved" subtitle). Below: 2 metric cards (Items swapped / Waste diverted). Below that: trade history list with date, counterparty avatar, "Your [item] ↔ Their [item]" line.

**My items:** 2-column grid. Floating + button (radius-full, 56px, `--green-primary`, fixed bottom-right above bottom nav, 16px from edges).

**My profile:** Avatar 96px centered top. Name h1 below, bio body below. Trust score badge if 3+ trades. Mini impact summary (3 inline stats). "Edit profile" + "Logout" buttons at bottom.

---

## 13. Prompt fragment to paste into Claude Design

Use this as the opener for any screen generation:

> Generate the [SCREEN NAME] for EcoSwap, a Tinder-style swap app for second-hand items. Target users are Thai students and young professionals in Bangkok. Use the imported design system. Mobile viewport 390x844. Use Lucide icons (outline). Use the dummy data set: Ploy 21, Fah 28, Beam 23. Static screen only — no real animations needed in the prototype, but indicate hover/pressed states visually. Friendly tone, never preachy about environment.
>
> Layout: [paste from section 12 above]

---

## Quick reference card (print this and put it next to your laptop)

- Primary green: `#1D9E75`
- Body text: 15px / 400 / `#1A1A1A`
- Card radius: 12px (or 20px for swipe card)
- Edge gutter: 16px
- Button min height: 48px
- Min tap target: 44 × 44
- No shadows except swipe card and modals
- Two font weights: 400 and 600
- Sentence case, never Title Case

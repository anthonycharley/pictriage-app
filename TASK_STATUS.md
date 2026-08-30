# PicTriage — Task Status

**Last updated:** 2026-08-30 (session covering: backend build, bug fixes, personalization, localization)
**Maintainer convention:** This file is a living hand-off doc. At the end of any session that makes
non-trivial progress, update it — move finished items into "Completed," add new findings to
"Blockers," and rewrite "Next Steps" so the next session (with zero memory of this one) can pick up
immediately without re-deriving context.

---

## 1. What this project is

**PicTriage** — an iOS photo-declutter app, positioned against the incumbent "Swipewipe": on-device
scanning, privacy-first, honest single-tier pricing, no ad-gated swipe caps. Full competitive
product spec was the original brief (auto-triage engine, swipe review, storage counter, etc.).

**Where the app's current design/branding came from:** the user picked a "Gamified/Playful"
dashboard concept from 5 generated options, then iterated on it extensively inside Claude Design
(claude.ai/design) under the project name **"Photo Cleaner Dashboard"**. The full design chat
transcript is at `chats/chat1.md` — read that for *why* specific copy/UI decisions were made
(e.g. "no swipes" language, the 7-day cleanup sprint framing, amber `#E89B1C` theme, Settings
section structure). That transcript is the source of truth for design intent; don't second-guess
it without checking there first.

That Claude Design project was exported via "Send to Claude Code Web," which seeded this whole
directory — `project/Photo Cleaner Dashboard.dc.html` (the HTML/JS prototype) and, notably, an
**already-built native SwiftUI port** at `ios/PicTriage/` (built by whatever agent ran the export,
before this session started). See `ios/PicTriage/README.md` for what that port implements.

---

## 2. Completed

### Native app port (pre-existing, verified accurate)
All 5 screens (Home, Duplicates/Screenshots review, photo detail grid, delete queue, Settings) are
real SwiftUI, sharing one `AppState` — a faithful line-for-line port of the `.dc.html` prototype's
`Component` class logic. See `ios/PicTriage/README.md` "What's implemented."

### Real on-device backend (this session)
Replaced all sample/fake data with a real PhotosKit backend:
- **`PhotoLibraryService.swift`** — real permission request/status (maps to the 3-state Settings
  picker), real library scan (screenshots grouped by day; duplicates grouped via burst-ID +
  "shot within 8s of the last one" heuristic — **not** ML/perceptual-hash based), real file sizes
  (`PHAssetResource`), real deletion (`PHPhotoLibrary.performChanges` → Recently Deleted).
- **`PhotoThumbnailView.swift`** — real async thumbnails via `PHCachingImageManager`, replacing the
  `DiagonalStripes` placeholder everywhere except as the loading/fallback state.
- **Verified end-to-end, live in Simulator**: real permission dialog → real scan of seeded photos
  (`xcrun simctl addmedia`) → real duplicate grouping → real thumbnails at 3 sizes → real deletion,
  confirmed by directly querying the Simulator's `Photos.sqlite` (`ZTRASHEDSTATE` flipped to 1).

### Dev environment set up from scratch (this session)
- Installed Xcode 26.6 (was previously just Command Line Tools) and XcodeGen 2.46.0 via Homebrew.
- Fixed a real `project.yml` bug: this XcodeGen version requires an explicit `info.path` under a
  target's `info:` block (the original spec only had `properties:`, which fails to parse).
- Primary test device: **iPhone 17 Pro Max Simulator**, UDID `D78C454B-15F6-43FC-8075-8DB40260AB91`.
- The iOS Simulator control tool needed `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
  run by the user once (agents can't run `sudo`) before its `attach`/`tap`/`screenshot` actions work.

### Bug fixes (this session)
1. **Photo preview total freeze (user-reported, confirmed real)** — the full-screen photo preview
   (`PreviewOverlayView`, opened by tapping a photo in the detail grid) did not respond to any tap
   at all. Root cause: it was a plain conditional overlay inside the main `ZStack`, not a real modal
   presentation. Fixed by switching to `.fullScreenCover` in `ContentView.swift`. Confirmed fixed by
   actually toggling the delete-queue state and completing a real deletion through it.
2. **Keep/"Queue for deletion" buttons collapsed into one full-width button** — found while
   re-verifying fix #1. An unnecessary `.layoutPriority(1)` in `PreviewOverlayView.swift`'s
   `actionRow` was causing the "Keep" button to render with zero width. Removed; both buttons now
   split evenly and both are independently tappable.
3. **Persistence backward-compatibility bug (self-inflicted, caught before shipping)** — adding
   `userName`/`hasOnboarded` fields to `AppState.PersistedPrefs` (a `Codable` struct persisted to
   `UserDefaults`) initially used plain non-optional properties with default values. Swift's
   synthesized `Decodable` does **not** fall back to those defaults for missing keys — it throws,
   and the `try?` around it silently discarded *all* previously-saved state (queue history, scan
   stats, everything), not just the two new fields. Fixed with a custom `init(from:)` using
   `decodeIfPresent` + explicit fallback for every field. **Lesson for future field additions to
   this struct: always use `decodeIfPresent`, never assume a stored-property default covers a
   missing JSON key.**

### New features (this session)
- **Onboarding** (`Views/OnboardingView.swift`) — first-launch "What should we call you?" screen;
  name (or explicit skip) is persisted and used in the Home greeting. Gated in `ContentView.swift`
  via `state.hasOnboarded`.
- **Time-of-day greeting** — `AppState.greetingLine`/`timeOfDay` picks morning/afternoon/evening
  from `Calendar.current` (device's real clock + time zone), combined with the onboarded name.
  Each of the 6 greeting variants (3 times × with/without name) is localized as a **whole phrase**,
  not assembled from translated fragments — punctuation around greetings varies by language
  (Spanish wraps in "¡...!" rather than appending "!").
- **Full device-language localization infrastructure**:
  - Every user-facing string wrapped correctly: static literals passed directly to `Text("...")`
    auto-match `Localizable.strings` by exact text (no code change needed); every *dynamic*
    string (interpolated counts/names/etc.) explicitly uses `String(localized: "...")` so the
    generated lookup key is reliable, since a `Text(someStringVariable)` does **not** localize —
    it's rendered verbatim.
  - `Formatting.swift`'s `Double.fixed(_:)` gives locale-aware number formatting (comma vs. period
    decimal separators) — replaces all `String(format: "%.1f", ...)` call sites.
  - `PhotoLibraryService`'s date formatting switched from a hardcoded `dateFormat = "MMM d"` to
    `setLocalizedDateFormatFromTemplate("MMMd")` (adapts both format and field order per locale).
  - Settings' day/time chips: day names now come from `Calendar.current.weekdaySymbols` (real
    locale data, not translated by hand); the 6 preset times are still fixed English strings
    reformatted for display only — see Known Limitations below.
  - Translations written (good-faith, not professionally reviewed) for **Spanish, French, German,
    Simplified Chinese** — `Sources/PicTriage/{es,fr,de,zh-Hans}.lproj/Localizable.strings`. Other
    device languages fall back to English (Foundation's normal behavior, not a bug).
  - **Verified live end-to-end in Spanish** (`-AppleLanguages '(es)' -AppleLocale es_ES` launch
    args): greeting, Home dashboard, Duplicates list, group detail, Settings, and the preview
    overlay all rendered correctly, including comma decimal separators ("0,03 GB") and localized
    month abbreviations ("26 ene").

---

## 3. Active Blockers

### 🔴 Unresolved: small circular top-left buttons unresponsive to taps in Simulator testing
While re-verifying the freeze fix, discovered that the "×" close button in the preview overlay,
**and** the plain "‹" `BackButton` used on other, unrelated, non-modal screens
(`ReviewListView`/`DetailGridView`/`QueueView`), did not respond to automated taps at their
calculated position — consistently, across many careful coordinate recalculations, on both the
newly-fixed modal and ordinary screens. Since it reproduces on completely unrelated code paths,
this is **not** caused by the `.fullScreenCover` fix.

**What we don't know:** whether this is a real SwiftUI hit-testing bug, something specific to this
iOS 26.5 Simulator build, or purely an artifact of coordinate-based tap *automation* (vs. real
touch/mouse input, which was never tried — we ran out of ability to test that ourselves this
session). A same-pattern test on a second, fresh Simulator device was blocked by a permissions
prompt we couldn't answer non-interactively.

**Mitigation shipped:** tapping anywhere on the preview's dark background now also dismisses it
(`PreviewOverlayView.swift`), so the preview is always closable regardless. The plain `BackButton`
elsewhere has no such fallback yet.

**This is the #1 next step** — see below.

### No version control
This project has **no git repository**. Everything so far — the design export, the backend
implementation, all bug fixes — exists only as files on disk with no history and no way to diff,
branch, or recover from a bad edit. Given the amount of work already done, this is a real risk.

---

## 4. Exact Next Steps

1. **Resolve the back-button blocker, in this order:**
   - Ask the user (or do it yourself if you have a way to click, not coordinate-tap, the
     Simulator) to physically click the "‹" back button on any screen (e.g. Duplicates list) and
     the preview's "×". If a **real click** works fine, the issue is specific to this session's
     coordinate-tap automation — note that in this file and move on, no code change needed.
   - If a real click/tap *also* fails to respond: this is a genuine bug in `Components.swift`'s
     `BackButton`, used on 4 screens. Try, in order: (a) add `.contentShape(Rectangle())` to the
     button's label; (b) increase its hit target size (e.g. wrap in a larger invisible tappable
     frame); (c) try swapping `Button { }.buttonStyle(.plain)` for a `ZStack` with
     `.onTapGesture`. Re-test after each change. If nothing works, it's worth a minimal repro and
     an Apple Feedback / SwiftUI bug report, since this reproduced on a very recent iOS build
     (26.5).
   - Regardless of outcome, add the same "tap background to dismiss" — or an equivalent large
     hit-target fallback — anywhere else `BackButton` is the *only* way back, so users are never
     stuck.

2. **Initialize git.** This should probably happen before any further changes: `git init`, a
   `.gitignore` for `*.xcodeproj`/`DerivedData`/`.DS_Store`, and an initial commit capturing
   current state, so future work is diffable and revertible. Ask the user first since it's a
   meaningful, visible change to the project structure.

3. **Real-device testing.** Everything verified so far is Simulator-only. Before considering the
   backend "done," run on a physical iPhone at least once — PhotosKit permission flows and
   thumbnail loading in particular can behave subtly differently than in Simulator.

4. **Decide on remaining stubs** (not blockers, just undone; ask the user which matter for a first
   real build):
   - Weekly reminder notifications aren't scheduled — the Settings toggle/day/time UI works but
     doesn't call `UNUserNotificationCenter`.
   - "Rate PicTriage" and "Privacy policy" rows just flash a toast instead of opening
     `SKStoreReviewController` / a real URL.
   - Settings' time picker uses 6 fixed English-formatted preset strings reformatted for display
     (`AppState.localizedTimeLabel`), not real `Date` values — fine for a v1, but a proper
     device-language build should probably replace it with an actual `DatePicker` or
     `Date`-backed values.
   - Duplicate detection is a burst-ID + 8-second-window heuristic, not ML/perceptual-hash based
     (documented up front as a deliberate simplification) — revisit with
     `VNGenerateImageFeaturePrintRequest` if real-world testing shows it misses too much.

5. **Localization follow-ups**, lower priority:
   - Get the 4 existing translations (es/fr/de/zh-Hans) reviewed by an actual speaker before wide
     release — they were written in good faith but not professionally checked.
   - Add more languages if the target market needs them; the infrastructure (wrap dynamic strings
     in `String(localized:)`, add a matching key to each `Localizable.strings`) is already in
     place and mechanical to extend.

6. **Not started at all:** app icon, launch screen content, App Store metadata/screenshots,
   TestFlight setup. Flagging so it's not forgotten, not because it's urgent right now.

---

## 5. Key File Reference

| File | Purpose |
|---|---|
| `chats/chat1.md` | Design-intent source of truth — read before changing UI/copy |
| `ios/PicTriage/README.md` | Detailed "what's implemented / what's stubbed" for the native app |
| `ios/PicTriage/Sources/PicTriage/PhotoLibraryService.swift` | Real PhotosKit backend |
| `ios/PicTriage/Sources/PicTriage/PhotoThumbnailView.swift` | Real thumbnail loading |
| `ios/PicTriage/Sources/PicTriage/AppState.swift` | Central state/logic, greeting, persistence |
| `ios/PicTriage/Sources/PicTriage/Views/PreviewOverlayView.swift` | Full-screen preview (site of both bug fixes + open blocker) |
| `ios/PicTriage/Sources/PicTriage/Views/Components.swift` | `BackButton` — the component at the center of the open blocker |
| `ios/PicTriage/Sources/PicTriage/Views/OnboardingView.swift` | Name-capture first-launch screen |
| `ios/PicTriage/Sources/PicTriage/Formatting.swift` | Locale-aware number formatting |
| `ios/PicTriage/Sources/PicTriage/{es,fr,de,zh-Hans}.lproj/Localizable.strings` | Translations |
| `ios/PicTriage/project.yml` | XcodeGen spec (note the `info.path` requirement, see §2) |

**Test device:** iPhone 17 Pro Max Simulator, UDID `D78C454B-15F6-43FC-8075-8DB40260AB91`.
**To rebuild:** `cd ios/PicTriage && xcodegen generate && xcodebuild -project PicTriage.xcodeproj -scheme PicTriage -destination "generic/platform=iOS Simulator" -configuration Debug build`

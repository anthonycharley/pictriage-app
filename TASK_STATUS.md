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

### ~~`BackButton` (non-modal screens) unresponsive~~ — False alarm, resolved
Re-tested this session with careful coordinate calibration (verified against two independently
confirmed-working reference points on the same screens). The plain "‹" `BackButton` on
`ReviewListView`/`DetailGridView`/`QueueView` responds correctly and reliably to tap automation —
repeated successfully multiple times navigating Home → Duplicates → group detail → back → back.
**The previous session's finding was a tap-coordinate-precision artifact of automation, not a real
bug.** No code change needed here.

### 🔴 Still unresolved, now more precisely characterized: `PreviewOverlayView` topBar controls
The "×" close button **and** the "First"/"Last" jump pills (all three live in `topBar`, the first
row of `PreviewOverlayView`) do not respond to tap — confirmed with an extensive, deliberately
overlapping coordinate sweep across both x and y (roughly y=95 to y=220, several x values per
row), which rules out simple mis-targeting: the true button center falls well inside that swept
range and nothing in it worked. Meanwhile, in the **same view**, the photoStrip chevron buttons
and the bottom `Keep`/`Queue for deletion` buttons respond correctly and reliably at their
computed coordinates. So this is isolated to `topBar` specifically, not the whole overlay.

**Tried and did NOT fix it:** adding `.contentShape(Circle())` and a redundant
`.highPriorityGesture(TapGesture())` to the × button (reverted — it didn't help and risked
double-firing `closePreview()` on any tap that *did* land).

**New finding this session — the shipped "tap background to dismiss" mitigation is unreliable,
not solid:** tapping the dark background at (10, 900) closed the preview correctly, but identical
background taps at (10, 462), (220, 760), and (220, 20) — all well outside any button's bounds —
did nothing. Same gesture (`Color.black.opacity(0.82).contentShape(Rectangle()).onTapGesture`),
different outcomes at different points. This inconsistency (not a clean "always fails" or "always
works") suggests something coordinate- or view-hierarchy-specific that black-box tapping from
outside the app can't fully diagnose — it likely needs Xcode's live view debugger (Debug View
Hierarchy) on an actual running session, which isn't available from this environment.

**Practical impact:** not a full lockout — `Keep` and `Queue for deletion` both correctly call
`closePreview()` too and work reliably, so there's always a way out of the preview. But the
"just close without acting" affordances (× button, tap-anywhere-to-dismiss, First/Last jump) are
currently unreliable.

**This is the #1 next step** — see below.

### ~~No version control~~ — Resolved
Git is now initialized and pushed to **https://github.com/anthonycharley/pictriage-app** (branch
`main`). Root `.gitignore` excludes `.DS_Store`, `*.xcodeproj/`, `DerivedData/`,
`ios/PicTriage/Generated/`, etc. — all Xcode/XcodeGen output is regenerated via
`xcodegen generate`, never committed.

---

## 4. Exact Next Steps

1. **Resolve the `PreviewOverlayView.topBar` blocker** (× close, First/Last pills — `BackButton`
   itself is confirmed fine, see above). Black-box tap testing from outside the app has been
   pushed as far as it usefully can — next step needs to actually see the view hierarchy:
   - Run the app from Xcode directly (not this headless build path) and use **Debug View
     Hierarchy** while the preview is open, to check whether some other view (system UI, a stale
     presentation artifact, anything) is overlapping `topBar` and intercepting touches.
   - Ask the user to physically tap the "×" and "Last" pill once for a real-touch data point —
     everything tested this session was synthetic tap automation.
   - If the view hierarchy looks clean and a real tap also fails: try restructuring `topBar` away
     from being the first child of the padded `VStack` (e.g. give it its own `.zIndex()`, or move
     the dismiss/jump actions to `.safeAreaInset(edge: .top)` instead of stacking them inside the
     same `VStack` as everything else) and re-test each change.
   - Regardless of root cause, `Keep` and `Queue for deletion` both work as an exit path already,
     so this isn't a hard lockout — but worth fixing since × and tap-to-dismiss are the two
     "just look and leave" affordances users will reach for most.

2. ~~**Initialize git.**~~ Done — pushed to https://github.com/anthonycharley/pictriage-app (`main`).

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

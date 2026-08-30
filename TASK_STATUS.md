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

### App icon (this session)
Designed 4 concept directions (Sorted Stack, Triage Funnel, Progress Ring, PT Monogram) as an
Artifact, built entirely from colors already in `Theme.swift` — nothing new introduced. User
picked **PT Monogram**. Rendered at true 1024×1024 with Pillow (not a browser screenshot — those
came back scaled/soft) and wired into a proper `Assets.xcassets/AppIcon.appiconset` with the
modern single-size "universal" 1024 entry (supported since Xcode 14 for iOS 16+ targets, no need
for the old full icon-size matrix). `project.yml` now sets
`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. Verified showing correctly on the Simulator Home
Screen with iOS's own squircle mask applied.

### Settings rows — real implementations, no more fakes (this session)
All three previously-fake Settings rows now do what they say:
- **Weekly cleanup reminder** — `NotificationScheduler.swift` (new) requests real
  `UNUserNotificationCenter` authorization and schedules an actual repeating
  `UNCalendarNotificationTrigger` matching the selected day/time. Toggling off cancels it;
  changing day/time reschedules it; permission denial reverts the toggle and flashes a message
  pointing to iOS Settings. No Info.plist/entitlement changes needed — local notifications only
  need runtime authorization. Verified via `xcrun simctl ... log show`: authorization grant,
  add/remove/re-add on every day and time change, and clean cancel-with-no-reschedule on toggle
  off, all with `hasError: 0`.
- **Rate PicTriage** — now calls SwiftUI's `@Environment(\.requestReview)` (StoreKit,
  iOS 16+-native) instead of a fake toast. Verified: triggers the real system
  "Enjoying PicTriage? Tap a star to rate it" sheet.
- **Privacy policy** — real in-app policy at `Views/PrivacyPolicyView.swift`, presented as a
  sheet — no hosted URL needed. Content double-checked against the actual codebase (grepped for
  `URLSession`/analytics SDKs — none exist) before writing any claims, so "nothing leaves your
  device" is verified true, not just asserted.

**Note:** Apple's App Store Connect submission flow itself still wants a *hosted* privacy policy
URL for the store listing metadata (separate from this in-app screen) — worth remembering when
you get to that step, this doesn't fully replace it.

### Launch screen (this session)
Was `UILaunchScreen: {}` (blank white flash on cold start). Added a `LaunchBackground` color
asset (`#FDF3E4`, matching `Theme.screenBackground`) and set `UIColorName: LaunchBackground` in
`project.yml`'s `UILaunchScreen` block — no custom image, just a color-matched blank screen,
which is the standard/recommended pattern. Verified via cold `simctl terminate` + `launch`, no
crash, correct Info.plist generated.

## 3. Active Blockers

### ~~`BackButton` (non-modal screens) unresponsive~~ — False alarm, resolved
Re-tested this session with careful coordinate calibration (verified against two independently
confirmed-working reference points on the same screens). The plain "‹" `BackButton` on
`ReviewListView`/`DetailGridView`/`QueueView` responds correctly and reliably to tap automation —
repeated successfully multiple times navigating Home → Duplicates → group detail → back → back.
**The previous session's finding was a tap-coordinate-precision artifact of automation, not a real
bug.** No code change needed here.

### ~~`PreviewOverlayView` topBar controls unresponsive~~ — Root-caused and fixed
Confirmed as a genuine bug (not automation) — the user physically clicked the "×" with a real
mouse in Simulator and it didn't close, matching synthetic-tap testing. Used Xcode's Debug View
Hierarchy (Debug → View Debugging → Capture View Hierarchy while the preview was open) to inspect
the live view tree; nothing conclusively showed an occluding view, but the structural pattern was
suspicious: `topBar` was the first child of a `VStack` nested inside **two** layers of SwiftUI's
conditional/transition machinery (`fullScreenCover`'s own `if let group = ...` closure, plus
`PreviewOverlayView.body`'s `if let photo = ...`, both under `.transition(.opacity)`) — a
combination known to sometimes break hit-testing for content nested that deep.

**Fix (`PreviewOverlayView.swift`):** pulled `topBar` out of the content `VStack` entirely and
made it a direct sibling in the outer `ZStack` (`alignment: .top`), with a `Color.clear.frame(height: 34)`
spacer reserving its space in the content flow so the visual layout is unchanged. Rebuilt and
re-tested at the exact coordinates that previously failed — × now closes the preview, and
"Last"/"First" now jump correctly. Not yet re-verified with a second real mouse click (only
re-tested via automation so far, which had already matched real-click behavior for this bug) —
worth a final physical click to fully close this out, but confidence is high given the
same-coordinate before/after comparison.

The background-tap-to-dismiss mitigation's earlier inconsistency (worked at one point, not others)
was likely a symptom of this same structural issue and should be re-verified as unnecessary now
that `topBar` itself works, rather than debugged further in isolation.

### ~~photoStrip left chevron (previous photo) unresponsive~~ — Also fixed, same family of bug
Found immediately after the topBar fix above: the `chevron.left` "previous photo" button stopped
responding (right chevron / next photo kept working fine — confirmed asymmetric, not a general
photoStrip failure). Same diagnostic signature as the topBar bug: extensive coordinate sweep ruled
out mis-targeting, "First" pill (also sets the index directly) proved the underlying state logic
was fine, so this was hit-testing, not logic.

Root cause is almost certainly the same nesting-depth issue as topBar — `photoStrip`'s two chevron
buttons were still literal children of the same deeply-nested content `VStack`. Tried attaching
`photoStrip` via `.overlay()` on a space-reserving placeholder first (cheaper, kept it inside the
`VStack`) — did **not** fix it, confirming the issue is about being nested inside that `VStack` at
all, not about literal child-list position.

**Fix:** pulled just the two chevron buttons out to be direct `ZStack`-level siblings (same
treatment as `topBar`), positioned via a `GeometryReader` + `PreferenceKey`
(`PhotoStripFrameKey`) that captures the photo thumbnail's on-screen frame, so the buttons sit
exactly at its left/right edges with no hardcoded coordinates. The thumbnail itself stays in the
`VStack`'s normal flexible-height flow — it's not interactive, so it was never affected. Verified:
forward, backward, and the disabled state at both ends of a 2-photo group all work correctly.

**Takeaway for any future control added to this view:** don't nest new interactive elements
directly in the content `VStack` — anything that needs to react to taps should be a direct
`ZStack` sibling, positioned via `.position()`/alignment (with a `GeometryReader`+`PreferenceKey`
if it needs to track another view's frame, as the chevrons do here). The underlying SwiftUI
mechanism was never fully root-caused (Xcode's view debugger didn't show an obvious occluding
view), but the "nested in VStack → broken, direct ZStack sibling → works" pattern held for both
bugs found this session and is the safest working assumption going forward.

### ~~No version control~~ — Resolved
Git is now initialized and pushed to **https://github.com/anthonycharley/pictriage-app** (branch
`main`). Root `.gitignore` excludes `.DS_Store`, `*.xcodeproj/`, `DerivedData/`,
`ios/PicTriage/Generated/`, etc. — all Xcode/XcodeGen output is regenerated via
`xcodegen generate`, never committed.

---

## 4. Exact Next Steps

1. ~~Resolve the `PreviewOverlayView.topBar` blocker~~ Done — see §3. One follow-up: do a final
   real (physical, not automated) mouse click on × and the First/Last pills to fully confirm,
   since only the fix itself was re-tested via automation so far.

2. ~~**Initialize git.**~~ Done — pushed to https://github.com/anthonycharley/pictriage-app (`main`).

3. **Real-device testing.** Everything verified so far is Simulator-only. Before considering the
   backend "done," run on a physical iPhone at least once — PhotosKit permission flows and
   thumbnail loading in particular can behave subtly differently than in Simulator.

4. ~~Fake settings rows~~ Done — see above. **Still remaining, lower priority:**
   - Settings' time picker uses 6 fixed English-formatted preset strings reformatted for display
     (`AppState.localizedTimeLabel`), not real `Date` values — fine for a v1, but a proper
     device-language build should probably replace it with an actual `DatePicker` or
     `Date`-backed values.
   - Duplicate detection is a burst-ID + 8-second-window heuristic, not ML/perceptual-hash based
     (documented up front as a deliberate simplification) — revisit with
     `VNGenerateImageFeaturePrintRequest` if real-world testing shows it misses too much.
   - A *hosted* privacy policy URL is still needed for App Store Connect's own listing metadata
     (separate from the in-app screen added this session).

5. **Localization follow-ups**, lower priority:
   - Get the 4 existing translations (es/fr/de/zh-Hans) reviewed by an actual speaker before wide
     release — they were written in good faith but not professionally checked.
   - Add more languages if the target market needs them; the infrastructure (wrap dynamic strings
     in `String(localized:)`, add a matching key to each `Localizable.strings`) is already in
     place and mechanical to extend.

6. ~~App icon~~ ~~Launch screen~~ Done — see above/below. **Still not started:** App Store
   metadata/screenshots, TestFlight setup, hosted privacy policy URL.

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
| `ios/PicTriage/Sources/PicTriage/NotificationScheduler.swift` | Real weekly reminder scheduling |
| `ios/PicTriage/Sources/PicTriage/Views/PrivacyPolicyView.swift` | In-app privacy policy sheet |
| `ios/PicTriage/Sources/PicTriage/Formatting.swift` | Locale-aware number formatting |
| `ios/PicTriage/Sources/PicTriage/{es,fr,de,zh-Hans}.lproj/Localizable.strings` | Translations |
| `ios/PicTriage/project.yml` | XcodeGen spec (note the `info.path` requirement, see §2) |

**Test device:** iPhone 17 Pro Max Simulator, UDID `D78C454B-15F6-43FC-8075-8DB40260AB91`.
**To rebuild:** `cd ios/PicTriage && xcodegen generate && xcodebuild -project PicTriage.xcodeproj -scheme PicTriage -destination "generic/platform=iOS Simulator" -configuration Debug build`

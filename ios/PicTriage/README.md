# PicTriage (iOS, SwiftUI)

Native SwiftUI implementation of `project/Photo Cleaner Dashboard.dc.html`, the Claude Design
prototype exported at the repo root. Built from the `.dc.html` source and the `chats/chat1.md`
transcript describing how the design evolved.

## What's implemented

All five screens the prototype's single component switches between, as real SwiftUI views
sharing one `AppState`:

- **Home** — cleanup-sprint hero, review-progress ring, Quick Wins pills, primary CTA
- **Duplicates / Screenshots review** — grouped list, tap a group to open its photo grid
- **Photo detail grid** — per-photo grid with quick-queue toggle, "Queue rest"/"Clear all",
  and a full-screen preview overlay (Keep / Queue for deletion, First/Last/Prev/Next)
- **Delete queue** — review what's queued, remove items, confirm delete
- **Settings** — library access tier, rescan, weekly reminder (day/time picker), privacy,
  and a combined Support section (how deletion works, rate app, version)

The interaction logic (toggling photos into the queue, bulk "queue all but the best shot",
sprint day/GB tracking, toasts, etc.) is a line-for-line port of the `Component` class's
`state`/`renderVals()` logic in the `.dc.html` file's `<script>`.

## Backend: what's real now

`PhotoLibraryService.swift` and `PhotoThumbnailView.swift` replace the sample data with a real
on-device PhotosKit backend:

- **Permission** — the Settings access picker requests real `PHPhotoLibrary` authorization the
  first time, and deep-links to the Settings app after that (iOS only allows one in-app prompt).
- **Scanning** — `PhotoLibraryService.scan()` fetches every photo asset, splits out screenshots
  (grouped by day) from everything else, and groups the rest into duplicate/near-duplicate
  clusters using iOS's own burst identifiers plus a "shot within 8 seconds of the last one"
  heuristic. This is **not** ML-based perceptual hashing — it won't catch two similar photos
  taken minutes apart. Swapping in `VNGenerateImageFeaturePrintRequest`-based similarity is the
  natural next step if the heuristic misses too much.
- **Real file sizes** — read from `PHAssetResource` where the system exposes them, with a
  pixel-dimension estimate as fallback.
- **Real thumbnails** — `PhotoThumbnailView` loads images from `PHCachingImageManager`
  asynchronously, with the original diagonal-stripe placeholder as the loading/fallback state.
- **Real deletion** — `confirmDelete()` calls `PHPhotoLibrary.performChanges` to move queued
  photos to Recently Deleted. iOS shows its own native confirmation on top of the in-app one —
  that's expected, not a bug.
- **Local persistence** — the cleanup-sprint stats (days, GB freed, reminder settings) survive
  relaunches via `UserDefaults`. Scan results themselves are not cached to disk; "Rescan" and
  "Clear local scan data" both just re-run or clear the in-memory scan.

Still not wired up: weekly reminder notifications aren't scheduled (the toggle/day/time picker
is UI-only), and "Rate PicTriage" / "Privacy policy" still just flash a toast instead of opening
a real URL or review sheet.

**Testing this**: the Simulator's Photos library starts empty — seed it with
`xcrun simctl addmedia <device> <image1> <image2> ...` (any local image files work; importing the
same file twice a couple of times a few seconds apart is enough to trigger a "similar shots"
duplicate group). Grant access either through the real permission dialog on first launch, or via
`xcrun simctl privacy <device> grant photos com.pictriage.app` beforehand.

## Personalization & localization

- **Onboarding** (`OnboardingView.swift`) — first launch asks what to call the person; the name
  (or its absence) is persisted and used in the Home greeting.
- **Time-of-day greeting** — `AppState.greetingLine` picks morning/afternoon/evening from
  `Calendar.current`, i.e. the device's real clock and time zone.
- **Device-language localization** — every user-facing string is wrapped for localization
  (`String(localized:)` for dynamic/computed strings, plain `Text("literal")` for static ones,
  which auto-matches `Localizable.strings` by exact text). GB values use `Double.fixed(_:)`
  (`Formatting.swift`), which is locale-aware (comma vs. period decimal separators), and dates use
  `setLocalizedDateFormatFromTemplate` instead of a hardcoded format. Translations are provided
  for Spanish, French, German, and Simplified Chinese (`es/fr/de/zh-Hans.lproj/Localizable.strings`)
  — done in good faith, not professionally reviewed. Other languages fall back to English. Day/time
  picker chips in Settings show localized weekday names via `Calendar`, but the six preset times
  themselves are still fixed English-formatted strings reformatted for display, not real `Date`
  values — a real device-language build should probably replace that whole picker with actual
  `Date`/`DatePicker`-backed values instead of the current fixed-string presets.

## Known issue: photo preview navigation controls

While testing, the full-screen photo preview (opened by tapping a photo in the detail grid) was
completely unresponsive to any tap — a real bug, not a testing artifact, since it reproduced
consistently. Root-caused to the preview being a plain conditional overlay inside the main
`ZStack` rather than a real modal presentation; switched it to `.fullScreenCover` in
`ContentView.swift`, which fixed it. While re-verifying, also found and fixed the Keep/"Queue for
deletion" buttons collapsing to one full-width button instead of splitting evenly (an unnecessary
`.layoutPriority(1)` in `PreviewOverlayView.swift`).

Both fixes were confirmed working via real interaction (delete-queue toggle, real `PHPhotoLibrary`
deletion). However, re-testing also turned up a **still-unresolved** finding: the small circular
buttons in the screen's top-left corner (the preview's "×" close button, and the plain "‹" back
button used elsewhere, e.g. `DetailGridView`/`ReviewListView`/`QueueView`) did not respond to
automated taps at their calculated position, on *both* the new fullScreenCover preview and
ordinary (non-modal) screens — so it isn't specific to the fix above. It's unclear whether this is
a real SwiftUI/hit-testing bug, something specific to this iOS 26.5 Simulator build, or a
limitation of the coordinate-based tap automation used for testing (real touch/mouse input wasn't
tried). As a safety net, tapping anywhere on the preview's dark background now also dismisses it
(`PreviewOverlayView.swift`), so there's always a working way to close it regardless. **Please
verify the "‹" back buttons and preview's "×" respond to a real tap/click before shipping** — if
they don't, that back-button pattern (`Components.swift`'s `BackButton`) is used across four
screens and would need a real fix, likely worth a fresh SwiftUI bug report/repro to Apple if a
real device reproduces it too.

## Fonts

The design uses Nunito + IBM Plex Mono (Google Fonts, both SIL OFL licensed). Neither ships on
iOS, so this uses the system rounded design (`Font.system(design: .rounded)`) as a stand-in —
see `Theme.swift`. For full brand fidelity, add the `.ttf` files to the Xcode target and swap
the `Font.heading`/`Font.mono` helpers to `.custom(_:size:)`.

## Building

This was written without access to a macOS/Xcode toolchain, so **it has not been compiled or
run** — do that on your Mac before treating it as done.

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) if you don't have it: `brew install xcodegen`
2. From this directory: `xcodegen generate`
3. Open `PicTriage.xcodeproj` and run on an iPhone simulator (iOS 16+).

The generated `.xcodeproj` is gitignored — regenerate it from `project.yml` any time.

## Structure

```
project.yml                  XcodeGen project spec
Sources/PicTriage/
  PicTriageApp.swift          App entry point
  ContentView.swift           Root view: onboarding gate, screen switch, bottom nav/toast, preview fullScreenCover
  AppState.swift              ObservableObject holding all state + actions (port of the dc.html Component)
  PhotoLibraryService.swift   Real PhotosKit backend: permissions, scan/group, delete
  PhotoThumbnailView.swift    Async PHAsset thumbnail loading + cache
  Models.swift                Photo / PhotoGroup models
  Theme.swift                 Colors, fonts
  Formatting.swift            Locale-aware GB number formatting
  es/fr/de/zh-Hans.lproj/     Localizable.strings translations
  Views/
    OnboardingView.swift      First-launch "what should we call you?" screen
    HomeView.swift
    ReviewListView.swift
    DetailGridView.swift
    QueueView.swift
    SettingsView.swift
    BottomNavView.swift
    ToastView.swift
    PreviewOverlayView.swift
    Components.swift          BackButton, DiagonalStripes (photo placeholder), HairlineDivider
```

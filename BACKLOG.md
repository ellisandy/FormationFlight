# Formation Flight — Engineering Backlog

Generated 2026-10-07 from a five-track code review (concurrency, crash risk, navigation math, SwiftUI/persistence, test quality). Every item below was located in source and the top-priority ones were re-verified by hand. Items that several reviewers found independently are marked **(×N)**.

Priority key: **P0** ship-blocker / safety / stuck-UI · **R** App Store release readiness · **P1** pilot-visible wrong behavior · **P2** robustness & architecture · **P3** tests · **P4** hygiene.

Paths are relative to `Formation Flight/`. Tests now live in `Formation FlightTests/` and `Formation FlightUITests/` (same sub-folder layout); the project uses Xcode synchronized folders, so file membership follows the file system.

## Status (2026-10-07)

- **P0 B-01 – B-06: done** (PRs #3–#8, merged into `feature/stability-backlog`).
- **P3: done** for everything not blocked by an open P1 item. T-01 – T-13 are all addressed; "tests to add" 1, 3 (hemispheres), 4, 7, 9 (corrupt data), 10, 12, 13, 14, 15 are in. Still open because they would fail until the referenced fix lands: 2 (B-10), 3 minute padding (B-10), 5 (B-08), 6 (B-23), 8 (B-14), 9 ordering (B-12), 11 (B-07/B-22). Two residual T-07 touches remain in production code, not tests: `FlightEditorViewModel()` owns a real `CLLocationManager` (B-16) and `LocationProvider` still allocates a default manager even when one is injected.
- **P4: done.** H-01 – H-08 complete, including the string catalog (73 keys extracted, view-model strings via `String(localized:)`), `.gitignore`, and the Xcode Cloud manifest committed. `Design.swift` needed no change (the 12.5 never reached the repo). The GPX no longer ships (R-03's file half); `README` was never in the project file.
- **Enablers landed along the way:** B-29 (injectable clock), the model half of B-11 (`.unknown` status), B-38 (dead `CLLocationManager` in the map picker).
- **R (release readiness):** R-01 done (`PrivacyInfo.xcprivacy`). R-02 file half done (background modes and push/iCloud entitlements removed, `ITSAppUsesNonExemptEncryption = NO`); the purpose string and `UILaunchScreen_Generation` removal are build settings, delivered as a prepared project-file change for the owner to apply (see below). R-03 done. R-04 half done (`DefaultImage` deleted); dark and tinted icon appearances still need artwork. R-05: `.gitignore` and the Xcode Cloud manifest are committed; test-target build numbers and UI-test Swift 6 are in the same prepared project-file change (code already compiles under Swift 6, verified with a `SWIFT_VERSION=6.0` override build); deployment target 26.0 left as-is pending a decision. R-06: the full UI suite passes on iPad Pro 13-inch, so iPad stays enabled; 13-inch screenshots are required. R-07 done (first-launch disclaimer with acknowledgement, Settings entry, UI test). R-08: `docs/AppStore/` holds the privacy policy to host and the listing draft with review notes and a checklist.
- **Owner action pending (project file is policy-protected):** apply `/tmp/formationflight-r-settings.pbxproj` over `Formation Flight.xcodeproj/project.pbxproj`. It changes only: the location purpose string, removal of `INFOPLIST_KEY_UILaunchScreen_Generation` (both configs), `CURRENT_PROJECT_VERSION` 1 → 2 on both test targets, and `SWIFT_VERSION` 5.0 → 6.0 on the UI test target.
- **P2: done.** B-27 (`LocationProvider`/`LocationProviding`/`TimerScheduling` are `@MainActor`, `@preconcurrency CLLocationManagerDelegate`), B-28 (`@MainActor` `onFire`), B-29, B-30 (delete persists with rollback on failure, name snapshot for the alert, dead `.onDelete`/`handleOnDelete` removed, labelled swipe button), B-31 (sorted by mission date then name), B-32 (`@Observable` settings view model, `EditButton`), B-33 (thumbnail follows the target), B-34 (all `Int(Double)` sites guarded; angle semantics still B-10), B-35, B-36 (single forward-azimuth helper), B-37, B-38, B-39 (`verticalAccuracy >= 0`), B-40 (clock and ETE truncated to whole seconds so Time + ETE == ETA on screen). B-17 (`.common` run-loop mode) came along with B-28 since it was the same three lines.
- **P1: done except B-25/B-26.** B-07 (speed/course `>= 0` valid, cleared to the sentinel when invalid; readouts blank after 15 s without a fix), B-08, B-09 (hack anchors to the clock, works before the first tick), B-10 (`000°`–`359°`, 0° valid, degrees overload fixed, `dms` minutes zero-padded), B-11 (EARLY/LATE/ON TIME caption), B-12 (instrument order and enablement honoured in Settings and in flight; lenient per-entry decoding), B-13 (tolerance steppers with live clamping), B-14 (`FlightValidation` is the single rule set for save and Go Fly; hack 0 s and past TOT rejected; only the mission type's field is stored), B-15 (typed lat/lon with decimal comma, map follows typed value, camera `.onEnd`), B-16 (editor uses the shared provider; denied/reduced-accuracy banner with Open Settings; `authorizationStatus`/`accuracyAuthorization`/`requestWhenInUseAuthorization()` on the protocol), B-17, B-18, B-19 (via R-02), B-20, B-21 (Cancel with a discard alert; back button hidden), B-22 (fix timestamps), B-23, B-24 (Req GS tracks the clock), B-41 (launch screen on Auto Layout, system background). Discard confirmation is an alert, not a confirmation dialog: anchored to a toolbar item the dialog becomes a popover and drops its cancel-role button.
- **R-04: done to the extent the flat source allows.** Dark (transparent background) and tinted (grayscale) appearances were derived from the original tile by keying out the navy; the launch-screen image has transparent rounded corners. Verified in the compiled catalog (`assetutil`: default, dark, tintable) and on the simulator. An Icon Composer `.icon` for the full Liquid Glass treatment still needs layered artwork; the system's automatic glass rendering of the flat icon ships for 1.0.
- **Open:** B-25 and B-26 await pilot feedback (`docs/decisions/B-25-B-26-ete-and-bearing-reference.md`). R-08 needs the privacy policy hosted.

---

## P0 — Fix before next release

### B-01 · Δ (early/late) readout is garbled for negative values and unsigned for positive **(×3)**
- **Where:** `Core/UI Shared/Formatting.swift:64-71`, consumed at `Features/FlightView/FlightView.swift:213`
- **What:** `durationHMS` uses signed `Int` division and `%`. `delta = -65` renders `"00:-1:-5"`, `-3661` renders `"-1:-1:-1"`. Positive values have no sign, so `00:00:07` is ambiguous. No `isFinite` guard before `Int(_:)`.
- **Fix:** Guard `isFinite`, format `abs(seconds)`, prefix `-`/`+` (or `E`/`L`). Add negative-input tests.

### B-02 · "Go Fly" with no target presents an empty, undismissable full-screen cover
- **Where:** `Features/FlightEditor/FlightEditorView.swift:110-123, 148-165`
- **What:** No validation before `presentFlightView()` (TODO on line 111). Cover content is inside `if let _target …`; with nil target the cover shows nothing and has no dismiss. User must force-quit.
- **Fix:** Disable Go Fly until target selected and name non-empty (and hack > 0 for hack missions), or validate in `presentFlightView()` and show the existing validation alert.

### B-03 · `FlightViewModel` is built inside the cover closure, hijacks the shared location delegate, and is never torn down **(×3)**
- **Where:** `FlightEditorView.swift:157`, `Features/FlightView/FlightView.swift:193-195`, `Features/FlightView/FlightViewModel.swift:106-109, 140-146`, `Core/Location/LocationProvider.swift:34`
- **What:** `FlightViewModel.init` has side effects (`configure()` sets `LocationProvider.shared.updateDelegate = self.onLocationUpdate` with a strong capture and starts a repeating timer). The VM is constructed eagerly every time the `fullScreenCover` content closure re-evaluates; `StateObject(wrappedValue:)` keeps only the first, so each later throwaway VM steals the delegate and the on-screen instruments freeze while the clock ticks. No `deinit`, `timerToken?.cancel()`, or `stopMonitoring()` exists in app code, so every End Flight leaks a VM plus a 1 Hz timer, and GPS runs until process death.
- **Fix:** Move side effects out of `init` into `start()`/`stop()` called from `.onAppear`/`.onDisappear`; have `FlightView` own VM creation via the `StateObject` autoclosure (or `.fullScreenCover(item:)`); use `[weak self]` for the delegate; `stop()` cancels the timer, nils the delegate, and calls `stopMonitoring()`.

### B-04 · TOT hour wheel offers 1–24 while the model is 0–23 **(×3)**
- **Where:** `Core/UI Shared/TOTTimePickerView.swift:17-22`; setters at `Features/FlightEditor/FlightEditorViewModel.swift:65-68` and `FlightView.swift:66-76`
- **What:** Midnight-hour TOTs are unselectable (tag 0 missing, wheel shows invalid selection). Choosing "24" clamps to 23 in the editor but rolls to next-day 00:xx in the in-flight editor, so the two screens disagree.
- **Fix:** `ForEach(0..<24)` with `%02d` labels. Add tests for hour 0 and 23.

### B-05 · Default tolerances are 0/0, so every non-zero Δ is red on a fresh install **(×2)**
- **Where:** `Core/Domain/Settings.swift:46-47, 126-127`; `FlightViewModel.swift:178-190`
- **What:** `Settings.empty()` and `UserDefaults.integer(forKey:)` both yield 0 when unset. `absDelta <= 0` is the only "good" path. The trailing `else { .unknown }` is unreachable (`<= red` false implies `>= red` true).
- **Fix:** Non-zero defaults (e.g. yellow 5–15 s, red 15–30 s); in `load()` check `object(forKey:) == nil` before falling back; validate `yellow <= red` on save; simplify the mapping.

### B-06 · SwiftData schema has no versioning; container failure is a `fatalError` at launch
- **Where:** `Core/Formation_FlightApp.swift:25-41`, `Core/Domain/Flight.swift:23-36`
- **What:** `Flight.missionType` is non-optional with no default. Git history shows a completely different prior persisted schema with no `VersionedSchema`/`SchemaMigrationPlan`. Any installed store from the older schema crashes every launch until the app is deleted.
- **Fix:** Add a `VersionedSchema` + `SchemaMigrationPlan`; give new non-optional attributes defaults; replace `fatalError` with a recoverable fallback (delete incompatible store or in-memory container plus an error screen).

---

## R — App Store release readiness (free app)

The app will ship **free** on the App Store, so no StoreKit, in-app purchase, or Paid Apps Agreement work is needed. Everything below is what stands between the current project and a clean App Review submission. P0 items B-01 through B-06 are also release blockers.

### R-01 · Add a privacy manifest (`PrivacyInfo.xcprivacy`)
- **Where:** none exists (verified with a repo-wide search)
- **What:** The app uses `UserDefaults` (`Settings.swift`, `SettingsEditorViewModel.swift`), which is a "required reason" API. Uploads without a manifest declaring it are rejected by App Store Connect.
- **Fix:** Add `PrivacyInfo.xcprivacy` to the app target with `NSPrivacyAccessedAPICategoryUserDefaults` reason `CA92.1`, `NSPrivacyTracking = NO`, empty `NSPrivacyCollectedDataTypes` (location is used on-device only and never leaves the device), and no tracking domains.

### R-02 · Fix the Info.plist / entitlements to match what the app actually does
- **Where:** `Shared Assets/Info.plist`, `Shared Assets/Formation_Flight.entitlements`, `project.pbxproj:739-743` (also B-19, B-41)
- **What:** `UIBackgroundModes` declares `location` and `remote-notification` with no supporting code. `aps-environment = development` and empty iCloud arrays require Push and iCloud capabilities on the App ID for no benefit. The location purpose string is `"I need it. You need it."` (Guideline 5.1.1 rejection). Both `UILaunchScreen_Generation` and `UILaunchStoryboardName` are set.
- **Fix:** Remove both background modes and all three entitlement keys (or implement background location properly). Write a real purpose string, e.g. "Formation Flight uses your location to compute distance, bearing, and groundspeed to your target while you fly." Remove the generated-launch-screen key. Add `ITSAppUsesNonExemptEncryption = NO` so every upload skips the export-compliance prompt.

### R-03 · Stop shipping non-product files in the bundle
- **Where:** `project.pbxproj` Resources build phase (lines ~470-476)
- **What:** `README` and `TestAssets/TestFlight1.gpx` are copied into the app bundle. `TOT-Icon.png` is also copied loose (needed by the launch storyboard today; becomes unnecessary if B-41 switches the storyboard to the asset catalog image).
- **Fix:** Remove `README` and the GPX from the app target's Resources; keep the GPX in the test plan's location simulation only.

### R-04 · App icon and iOS 26 icon format
- **Where:** `Shared Assets/Assets.xcassets/AppIcon.appiconset`, `DefaultImage.imageset`
- **What:** A single 1024 px universal icon is valid for the iOS 26 deployment target, but there are no dark/tinted variants, and iOS 26 Liquid Glass icons are authored with Icon Composer (`.icon`). `DefaultImage.imageset` ships the same 1024 px PNG three times as 1x/2x/3x.
- **Fix:** Author an Icon Composer icon (or at minimum add dark and tinted appearances). Replace `DefaultImage` with one 1x entry or delete it if unused.

### R-05 · Project settings hygiene for archive/upload
- **Where:** `project.pbxproj:650, 730, 807, 848`
- **What:** `IPHONEOS_DEPLOYMENT_TARGET = 26.0` limits the audience to iOS 26 devices (confirm this is intentional). `CURRENT_PROJECT_VERSION` is 2 for the app and 1 for the test targets. Test target `SWIFT_VERSION = 5.0` while the app is 6.0. No `.gitignore` exists, so `.DS_Store` and `UserInterfaceState.xcuserstate` show as untracked; the Xcode Cloud `manifest.json` is also untracked and should be committed deliberately or ignored.
- **Fix:** Decide on the deployment target; align build numbers via a shared `xcconfig` or project-level setting; move test targets to Swift 6; add a standard Xcode `.gitignore` and commit the Xcode Cloud manifest if Xcode Cloud will build releases.

### R-06 · iPad support is declared but untested
- **Where:** `project.pbxproj:758` (`TARGETED_DEVICE_FAMILY = "1,2"`), `project.pbxproj:744` (all four iPad orientations)
- **What:** App Store Connect will require 13-inch iPad screenshots and App Review will test on iPad. The launch screen (B-41), fixed-size wheel pickers, and the `InstrumentCard` layout have not been checked on iPad or in landscape.
- **Fix:** Either run a full iPad/landscape pass (and add UI test coverage) or set the device family to iPhone only for 1.0.

### R-07 · Aviation safety disclaimer and first-run messaging
- **Where:** no disclaimer exists in the app or README
- **What:** The app is a supplemental timing aid for pilots. Apps that could contribute to physical harm are reviewed under Guideline 1.4; a clear "for situational awareness only, not for primary navigation" statement in-app (first launch and/or Settings) and in the App Store description reduces review risk and sets pilot expectations.
- **Fix:** Add a one-time disclaimer sheet with an acknowledgement, a persistent line in Settings, and matching copy in the store description.

### R-08 · App Store Connect metadata checklist
- Price tier: **Free**. No in-app purchases.
- Privacy policy URL (required for every app, even with no data collection). Host a one-page policy stating location is processed on-device and never transmitted.
- App Privacy nutrition label: "Data Not Collected" is accurate once R-01 is in place and nothing is logged off-device.
- Support URL and marketing URL (can be the same page).
- Category: currently `public.app-category.utilities`; consider **Navigation** as primary.
- Age rating questionnaire (expect 4+).
- Screenshots: 6.9-inch iPhone required; 13-inch iPad required while R-06 keeps iPad enabled.
- Accessibility Nutrition Labels (optional, new in 2025): only claim VoiceOver / Dynamic Type after H-04 and the missing `FlightView` identifiers are addressed.
- Review notes: explain the TOT/hack-time workflow and that location simulation (the GPX in the test plan) can be used to exercise the flight screen without flying.

---

## P1 — Pilot-visible correctness bugs

### B-07 · Stale GPS speed/course are never cleared **(×3)**
- **Where:** `LocationProvider.swift:104-127`
- **What:** `speed > 0` ignores a valid speed of 0 (stopped), `course > 0` ignores due north, and `speed == -1` only replaces the value if the manual estimate succeeds. An aircraft that stops keeps showing its last speed and ETE/ETA keep counting.
- **Fix:** Use `>= 0` for valid, `< 0` for the sentinel; on invalid with no estimate, clear the value. Blank instruments when the newest fix exceeds a staleness threshold.

### B-08 · Cur GS forced to nil until "Hack!" is pressed on hack missions **(×3)**
- **Where:** `FlightViewModel.swift:217-233`
- **What:** The `else` branch (taken when `tot == nil`) nils `currentGroundSpeed` even though it was just read.
- **Fix:** Only nil `requiredGroundSpeed` there.

### B-09 · `startHack()` anchors to the timer-sampled `currentTime`, not the button press **(×2)**
- **Where:** `FlightViewModel.swift:128-131, 150`
- **What:** Silently no-ops if pressed before the first tick; otherwise up to ~1 s stale, in an app whose tolerances are in seconds.
- **Fix:** Use `Date()` (or an injected clock) directly; also seed `currentTime` in `configure()`.

### B-10 · Bearing/track formatting: 0° shows `--`, Int overload uses radians, no 3-digit padding **(×3)**
- **Where:** `Formatting.swift:77-83, 109-111`
- **What:** `degrees <= 0` treats due north as unknown. `angle(degrees: Int)` builds the `Measurement` in `.radians` (`angle(degrees: 90)` → `"5157°"`). `359.6°` → `"360°"` while `0.4°` → `"0°"`. Minutes <10 in `dms` are not zero-padded (`%02.2f` at line 126).
- **Fix:** Sentinel check `< 0` only; normalize `% 360`; display `000°`–`359°` (or 360 for north) with `%03d`; use `.degrees`; `%05.2f` in `dms`.

### B-11 · Status color starts `.good` and is never reset; color is the only status signal **(×2)**
- **Where:** `FlightViewModel.swift:28, 178-190`; `Core/UI Shared/StatusStyling.swift`
- **Fix:** Initialize to `.unknown`, set `.unknown` when `delta == nil`, add a textual/symbol EARLY/LATE indicator alongside the tint.

### B-12 · Instrument enable/reorder settings are saved but never read
- **Where:** `Features/SettingsEditor/SettingsEditorFormView.swift:41-55`; `FlightView.swift` (no reference to `instrumentSettings`)
- **Fix:** Drive `InstrumentsSection` from `settings.instrumentSettings` (filter enabled, preserve order), or hide the section until wired. Also `Settings.load` rebuilds in default order and discards the user's ordering (`Settings.swift:137-144`).

### B-13 · Tolerance text fields may never commit before Save; capped at 360 by the wind-direction formatter
- **Where:** `SettingsEditorFormView.swift:30-34, 60-66`
- **What:** `.numberPad` has no return key, Form has no tap-to-dismiss, so `TextField(value:formatter:)` never commits; Save persists the old value. `windDirectionFormatter.maximum = 360` rejects tolerances over 6 min; `zeroSymbol = ""` renders 0 as blank.
- **Fix:** `@FocusState` + keyboard "Done", or a `Stepper`; dedicated formatter; validate `yellow <= red`.

### B-14 · Flight save bypasses `Flight.validFlight()` and writes placeholder values
- **Where:** `Features/Home/FlightsListViewModel.swift:89-96, 120-124`; `Flight.swift:67-92` (never called)
- **What:** `missionDate` and `hackTime` are always non-nil regardless of mission type, so a hack mission with a 0 s hack saves and launches; pressing Hack makes TOT = now, instantly red. No TOT-in-the-past check.
- **Fix:** Write `nil` for the inapplicable field, require hack > 0, call `validFlight()` from save and Go Fly.

### B-15 · Manual lat/lon entry in the map picker is unusable
- **Where:** `Core/UI Shared/CheckpointMapPickerView.swift:27-28, 39-41, 47-67`
- **What:** Getter re-formats to `%.6f` every render so intermediate keystrokes snap back; decimal comma rejected; `.onMapCameraChange(.continuous)` overwrites any typed value; `Map(initialPosition:)` never recentres.
- **Fix:** Separate `@State` strings parsed on submit; `Map(position:)`; only follow the camera while dragging.

### B-16 · Location denied/restricted/imprecise has no UI; editor owns a second, delegate-less `CLLocationManager`
- **Where:** `LocationProvider.swift:64-84`; `FlightEditorViewModel.swift:18, 57-62`; `FlightEditorView.swift:57` (Cupertino fallback)
- **Fix:** Publish authorization/accuracy state from `LocationProvider`; show a banner with an Open Settings link; drop the duplicate manager in favour of the shared provider.

### B-17 · 1 Hz timer runs in `.default` run-loop mode, so the clock freezes while scrolling
- **Where:** `Features/FlightView/TimerScheduling.swift:20`; `FlightView.swift:201` (ScrollView)
- **Fix:** `Timer(timeInterval:repeats:block:)` + `RunLoop.main.add(_, forMode: .common)`.

### B-18 · `hackTime` is not `@Published`, causing lost updates in the hack-time wheels **(×2)**
- **Where:** `FlightViewModel.swift:46`; `FlightView.swift:326`; `Core/UI Shared/HackTimePickerView.swift:11-13, 21, 37`
- **Fix:** Make `hackTime` (and `missionType`/`settings` if mutable) `@Published`.

### B-19 · Info.plist / entitlements declare unused capabilities; placeholder purpose string
- **Where:** `Shared Assets/Info.plist:5-9`, `Shared Assets/Formation_Flight.entitlements:5-10`, `project.pbxproj` (`NSLocationWhenInUseUsageDescription = "I need it. You need it."`)
- **What:** `UIBackgroundModes` lists `location` and `remote-notification` but nothing sets `allowsBackgroundLocationUpdates` or registers for push; iCloud entitlement arrays are empty; both `UILaunchScreen_Generation` and `UILaunchStoryboardName` set. App Review risk, and backgrounding mid-flight silently stops updates anyway.
- **Fix:** Remove unused modes/entitlements or implement background tracking properly (`allowsBackgroundLocationUpdates`, indicator, `scenePhase`). Write a real purpose string.

### B-20 · `CheckpointMapPickerView` nests a `NavigationStack` inside a pushed destination
- **Where:** `CheckpointMapPickerView.swift:24, 80-90`
- **Fix:** Remove the inner stack; keep title/toolbar on content.

### B-21 · Flight editor has no Cancel; back navigation silently discards edits
- **Where:** `FlightEditorView.swift:9, 139-147`; `FlightsListViewModel.swift:136-141` (`cancelEditor` dead)
- **Fix:** Add Cancel toolbar item; confirm discard when dirty.

### B-22 · `LocationProvider` stamps batched fixes with receipt time, not `location.timestamp`
- **Where:** `LocationProvider.swift:97-98, 156-158`
- **What:** Intra-batch `dt == 0` segments are skipped; cross-batch speed uses delivery latency. The manual speed fallback is systematically wrong and untestable.
- **Fix:** Use `$0.timestamp`.

### B-23 · `FlightViewModel.init(flight:)` drops `hackTime` and `missionDate` (latent)
- **Where:** `FlightViewModel.swift:57-75`
- **Fix:** Copy both fields; set `tot` only for `.tot` missions.

### B-24 · Required GS recomputed only on location callbacks using `.now`
- **Where:** `FlightViewModel.swift:220`
- **Fix:** Compute inside `updateTimings()` from the cached distance so it tracks the clock.

### B-25 · ETE uses raw GS rather than closing speed; stale "within tolerance" comment
- **Where:** `FlightViewModel.swift:153-156, 216`
- **Fix:** Project GS onto the bearing or flag large track/bearing divergence. Product decision.

### B-26 · Bearing/Track are true but unlabeled; heading updates started but never consumed
- **Where:** `LocationProvider.swift:54`; `FlightView.swift:150-151`
- **Fix:** Label `°T` or apply `CLHeading` magnetic variation.

### B-41 · Launch screen icon clips, overlaps the title, and hangs off-screen on every device except the design canvas
- **Where:** `View/Base.lproj/Launch Screen.storyboard:25-27` (image view), `:17` (label), `:33` (fixed background); `project.pbxproj:742-743`
- **What:** The image view has **no Auto Layout constraints** in a storyboard that uses Auto Layout. It relies on a hard-coded frame (`x=-19 y=474 w=455 h=450` on a 420×912 canvas) plus an autoresizing mask of `widthSizable + flexibleMaxX + flexibleMinY`. That pins a fixed 450 pt height with the bottom edge 12 pt *below* the screen and the left edge 19 pt *off* the screen, while width tracks the device. Combined with `scaleAspectFill` and `clipsSubviews`, the square icon is cropped differently on every device:
  - iPhone SE/8 (375×667): image top lands at ~229 pt, directly over the "Time on Target" label centred at ~222 pt. The image is added after the label, so it covers it.
  - Landscape (app supports it): 450 pt image in a 420 pt tall screen covers the whole screen and the label.
  - iPad (1024 wide): width stretches to ~1059 pt at 450 pt tall, so aspect-fill shows a horizontal strip of the icon.
  - 1024 px source drawn at ~450 pt on a 3× display is upscaled, so it also looks soft.
  The label has `clipsSubviews="YES"`, `lineBreakMode="middleTruncation"` and the deprecated `minimumFontSize`; harmless at 36 pt but worth cleaning. Both `UILaunchScreen_Generation = YES` and `UILaunchStoryboardName` are set, which is ambiguous configuration. The launch screen (dark blue, icon) also looks nothing like the first real frame (system-background `NavigationStack` list), so the hand-off is a hard visual jump.
- **Fix:** Replace the frame/autoresizing mask with constraints: centre X, a fixed square size (e.g. 200×200 or 40 % of width with `aspect 1:1`), and a vertical relationship to the label or centre Y; set `contentMode = scaleAspectFit`. Give the label trailing ≥ safe-area and remove `clipsSubviews`/`minimumFontSize`. Remove `INFOPLIST_KEY_UILaunchScreen_Generation`. Consider matching the system background so the launch frame blends into the list. Note: iOS caches launch snapshots, so delete the app or reboot the simulator to see storyboard changes.

---

## P2 — Robustness and architecture

### B-27 · `LocationProvider` is not `@MainActor`; the MainActor callback is silently erased
- **Where:** `LocationProvider.swift:32, 90-134`; `FlightViewModel.swift:107`
- **What:** Safe today only because every call site happens to be on main. Swift 6 emits no diagnostic for the erasure.
- **Fix:** Mark the class `@MainActor` with `@preconcurrency CLLocationManagerDelegate` (or `nonisolated` delegate methods + `MainActor.assumeIsolated`). Drop redundant `ObservableObject` alongside `@Observable`.

### B-28 · `TimerScheduling.onFire` is non-Sendable in a `@Sendable` block (compiler warning)
- **Where:** `TimerScheduling.swift:21`
- **Fix:** `onFire: @escaping @MainActor () -> Void`, invoke via `MainActor.assumeIsolated`.

### B-29 · No injectable clock in `FlightViewModel`
- **Where:** `FlightViewModel.swift:150, 220`
- **Fix:** Add `now: () -> Date` dependency. Unblocks exact-boundary tests (B-09, B-24, P3 items).

### B-30 · Delete flow: no explicit save, dead `.onDelete`, icon-only swipe button, `.constant` alert binding, deleted model read during dismiss
- **Where:** `FlightsListViewModel.swift:167-176, 183-195`; `FlightsListView.swift:27-32, 143-167, 188-194`
- **Fix:** `try modelContext.save()` with logging; remove `.onDelete` or add `EditButton`; `Label("Delete", systemImage:)`; `.alert(item:)`; clear `pendingDeleteFlight` before delete or store the name string.

### B-31 · `@Query var flights` has no sort descriptor
- **Where:** `FlightsListView.swift:75`
- **Fix:** `@Query(sort: \Flight.missionDate)` or by name.

### B-32 · `SettingsEditorView` stores an `ObservableObject` in `@State`; edit mode forced permanently active
- **Where:** `Features/SettingsEditor/SettingsEditorView.swift:12`; `SettingsEditorFormView.swift:12, 57`
- **Fix:** `@StateObject` or migrate to `@Observable`; use `EditButton`.

### B-33 · Target thumbnail uses `initialPosition`, never follows a moved target
- **Where:** `FlightEditorView.swift:88-89`
- **Fix:** `Map(position:)` updated in `onChange`.

### B-34 · Unguarded `Int(Double)` conversions on navigation values
- **Where:** `Formatting.swift:82, 92, 124`; `HackTimePickerView.swift:12-13`; `FlightEditorViewModel.swift:38`; `FlightEditorView.swift:46`
- **What:** Not reachable with NaN/inf today (traced), but one upstream change from a trap.
- **Fix:** `guard value.isFinite`, clamp magnitudes.

### B-35 · `Measurement.erasedType` uses `as! Dimension` on unconstrained `Unit` (dead code)
- **Where:** `Core/Extensions/CLLocation+Conversions.swift:57-61`
- **Fix:** Delete, or constrain `where UnitType: Dimension`.

### B-36 · Duplicate forward-azimuth implementations
- **Where:** `CLLocation+Conversions.swift:25-32` vs `LocationProvider.swift:199-210`
- **Fix:** Consolidate on one helper with `* 180 / .pi`; add `radiansToDegrees` next to `degreesToRadians`.

### B-37 · `requestLocationIfNeeded()` called from both `.task` and `.onAppear`
- **Where:** `FlightEditorView.swift:131-138`
- **Fix:** Keep `.task` only.

### B-38 · Unused `CLLocationManager` allocated per `CheckpointMapPickerView` init
- **Where:** `CheckpointMapPickerView.swift:8`
- **Fix:** Delete the property.

### B-39 · `altitude > 0` guard drops below-sea-level fixes
- **Where:** `LocationProvider.swift:108`
- **Fix:** Altitude is valid when `verticalAccuracy >= 0`; use that.

### B-40 · Time + ETE ≠ ETA by up to 1 s on screen (truncation vs. un-truncated ETA)
- **Where:** `Formatting.swift:66-68`; `FlightViewModel.swift:156, 164`
- **Fix:** Round consistently; update `Formatting_Tests.swift:31` accordingly.

---

## P3 — Test suite

### Defects in existing tests
- **T-01** `Core/Domain/InstrumentSetting_Tests.swift:34-93` uses stdlib `assert()` instead of `#expect`; stripped in optimized builds and aborts the runner on failure.
- **T-02** `FlightViewModelTests.swift:295-343` `statusMappingBoundaries` never uses its `expected` argument and re-derives status with `<` while production uses `<=`. Cannot fail.
- **T-03** `FlightViewModelTests.swift:144-181` never fires the mock timer, so `ete == nil` and `statusColor == .good` are just initial values. The "unknown" test asserts `.good`, encoding bug B-11.
- **T-04** `Formatting_Tests.swift:31` encodes truncation (`59.5 → "00:00:59"`); `:41` passes only because of the radians bug (B-10).
- **T-05** `MeasurementFormatters_Tests.swift:18-64` assert locale-dependent strings (`"250kn"`, `"12.0nmi"`); neither test plan pins locale/region.
- **T-06** `FlightEditorViewModelTests.swift:49, 77, 107` use `try! #require` in non-throwing tests; `Formatting_Tests.swift:21` uses `fatalError`; `CLLocation+Conversions_Tests.swift:45` exact `Measurement` equality after float round-trip.
- **T-07** Tests touch real services: `LocationProvider_Test.swift:79, 91` (real manager, real auth prompt path), every `FlightEditorViewModel()` creates a real `CLLocationManager`, `FlightsListViewModel()` reads `UserDefaults.standard` and `LocationProvider.shared`; `SettingsEditorViewModel_Tests.swift:8-12` creates persistent suites never removed.
- **T-08** No-assertion tests: `LocationProvider_Test.swift:137-146`, `Formation_FlightUITestsLaunchTests.swift:20-31`, `FlightEditorViewUITests.swift:88`, `FlightsListView_UITests.swift:110, 123`.
- **T-09** UI tests query by display strings with silent fallbacks and an `XCTSkip` escape (`FlightsListView_UITests.swift:34-181`); `app.buttons["Cancel"]` can never exist; `FlightEditorViewUITests.swift:73, 97, 165, 181-211` ignore existing identifiers and invoke another test as setup. `FlightView` has zero accessibility identifiers.
- **T-10** Wall-clock fudge (`-253` m "≈250", `abs(delta - (-7)) < 0.6`) at `FlightViewModelTests.swift:123, 138, 281, 289` — resolve via B-29.
- **T-11** Dead fixtures and duplicates: `CLLocation+Conversions_Tests.swift:23, 92-105`; `FlightsListViewModelTests.swift:227-244` ≡ `265-283`; two different `MockLocationProvider` classes; stale names/comments (`testGetCourse_*`, "inherits LocationProvider", removed bearing-tolerance feature).
- **T-12** `Date+TimeComponents_Tests.swift` and `DoubleExtensions_Tests.swift` lack an explicit `@testable import Formation_Flight`.
- **T-13** `-uiTestsSeedFlights` launch hook in `Formation_FlightApp.swift:29-36` is never used by any UI test.

### Tests to add (ordered by value)
1. `durationHMS` negative and signed output (B-01).
2. `angle` at exactly 0°, 359.6°, and `angle(degrees: 90 as Int)` (B-10).
3. `dms` with minutes < 10 and S/E hemispheres.
4. Exact tolerance boundaries (`|Δ| == yellow`, `== red`) with an injected clock; delete the tautological helper (T-02, B-29).
5. Hack mission before "Hack!": `currentGroundSpeed != nil` (B-08).
6. `init(flight:)` for a `.hackTime` flight copies `hackTime`, leaves `tot` nil (B-23).
7. Rewrite T-03 tests to actually fire the timer and assert the nil/computed pipeline.
8. `saveNewFlight` for `.hackTime` with 0 s hack and for empty name; parity with `validFlight()` (B-14).
9. `Settings.load` preserves saved ordering and drops unknown types; corrupt data → defaults (B-12).
10. `getBearing`: identical coordinates → nil; antimeridian; polar; `distance(from: [CLLocation])` with 3 points (first exercise of the summing branch).
11. `LocationProvider`: speed 20 then −1; course exactly 0; manual speed from two timestamped fixes (needs B-22).
12. `hourComponent = 0` and `= 24` behavior (B-04).
13. TOT crossing midnight: Δ from absolute dates, `timeHHmmss` shows `00:00:10`.
14. Raw-value pin tests for `MissionType` and `InFlightInfo` (on-disk contracts).
15. `FlightViewModel` teardown: after `stop()`, timer token cancelled, delegate nil, `stopMonitoring()` called (B-03).

---

## P4 — Hygiene

- **H-01** Dead code: `SlidingSheetView.swift` (incl. `TestView`), `SettingsEditorViewModel.isPresented/present/dismiss`, `SettingsEditorFormView.doubleFormatter`, `CheckpointMapPickerView.onCancel`, `Flight.title`, `InfoStatus` (typo `nutrual`), `FlightsListViewModel.delete(_:)`, `CLLocation.distance(from: [CLLocation])` (only tests call it), commented `withAnimation` in `FlightsListView.swift:121-124`. `Target.swift` header still says "Checkpoints.swift".
- **H-02** Shipped TODOs: `FlightsListViewModel.swift:17` (already abstracted), `FlightEditorView.swift:111` (B-02).
- **H-03** Logging: mission names logged `privacy: .public` (`FlightsListView.swift:178`, `FlightsListViewModel.swift:71, 109, 157, 172`); precise latitude interpolated at `FlightViewModel.swift:210`.
- **H-04** Dynamic Type: fixed `.font(.system(size:))` on symbols (`FlightsListView.swift:43`, `CheckpointMapPickerView.swift:31`, `FlightEditorView.swift:92`); wheel pickers `.frame(height: 140).scaleEffect(0.8)` shrink hit targets; `InstrumentCard` values lack `minimumScaleFactor`/`lineLimit`.
- **H-05** Localization: all UI strings are literals; only the launch screen has a string catalog.
- **H-06** Working tree on this branch: `Design.swift:18` corner radius `12 → 12.5` is unrelated to keep-screen-awake; `project.pbxproj` adds `README` to the app's Resources build phase so it ships in the bundle. Untracked `.DS_Store` and `UserInterfaceState.xcuserstate` should be gitignored.
- **H-07** `.alert(isPresented: .constant(...))` at `FlightsListView.swift:143-150` (also in B-30).
- **H-08** `let _missionType: MissionType = …` inside `if let` at `FlightEditorView.swift:155` binds a non-optional.

---

## Verified OK (for the record)
- Great-circle bearing math, haversine, and all `Measurement` unit conversions are correct.
- Required-GS, ETE, ETA, Δ sign convention and divide-by-zero guards are correct; only display (B-01) is broken.
- TOT stored as absolute `Date`, so midnight crossing is inherently handled.
- Keep-awake (`isIdleTimerDisabled`) is balanced on `FlightView` appear/disappear; sheets over it do not unbalance it.
- All SwiftData access is on the main actor; `onDelete` offsets match the iterated array; `ForEach` ids are unique UUIDs.
- All 17 test files are members of a test target; no orphans.
- No `try!`, `precondition`, `.first!`/`.last!`, or `print` in production code outside previews.

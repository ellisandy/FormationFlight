# Formation Flight — Engineering Backlog

Generated 2026-10-07 from a five-track code review (concurrency, crash risk, navigation math, SwiftUI/persistence, test quality). Every item below was located in source and the top-priority ones were re-verified by hand. Items that several reviewers found independently are marked **(×N)**.

Priority key: **P0** ship-blocker / safety / stuck-UI · **R** App Store release readiness · **P1** pilot-visible wrong behavior · **P2** robustness & architecture · **P3** tests · **P4** hygiene.

Paths are relative to `Formation Flight/`. Tests now live in `Formation FlightTests/` and `Formation FlightUITests/` (same sub-folder layout); the project uses Xcode synchronized folders, so file membership follows the file system.

## Status (2026-10-07)

### Open

| Item | Priority | Summary | Blocking release? |
|---|---|---|---|
| R-08 | R | GitHub Pages is configured to serve `docs/` from `main`; the privacy policy and support page go live when this branch merges. Remaining: enter the URLs (in `docs/AppStore/listing.md`), screenshots, and the rest of the checklist in App Store Connect. | Yes (owner action) |
| B-42 | P1 | Required GS falls back to direct-to when the 400 m/s search ceiling puts the target inside the turn circle; up to 13 s late in the close-in orbit. | Yes |
| B-43 | P1 | ETE / ETA / Δ / ORBIT caption flap when the turn detector toggles at its 1°/s threshold. | Yes |
| B-44 | P2 | `TurnDetector` uses the wall clock instead of the fix timestamp. | No |
| B-45 | P2 | `turnDuration` / `turnDirection` are published but never shown. Product call. | No |
| D-01 | D | Flight screen background inverts the colour scheme and fails contrast. | Should |
| D-02 | D | End Flight is destructive but looks like Edit TOT / Edit Hack. | Should |
| D-03 – D-06 | D | Settings title, AX Dynamic Type cards, unit spacing, smaller HIG items. | No |

Deferred by decision: deployment target stays at 26.0; iPad stays enabled (full UI suite passes on iPad Pro 13-inch, so 13-inch screenshots are required); an Icon Composer `.icon` for the full Liquid Glass treatment needs layered artwork and ships later.

### Done

- **P0 B-01 – B-06** (PRs #3–#8).
- **R-01 – R-07.** R-02/R-05 project-file parts were applied by the owner (purpose string, `UILaunchScreen_Generation` removed); the test-target `CURRENT_PROJECT_VERSION` and UI-test `SWIFT_VERSION` parts of that change were not re-checked. R-04 dark and tinted appearances derived from the flat tile; verified in the compiled catalog and on the simulator.
- **P1 B-07 – B-24, B-41.** Discard confirmation is an alert, not a confirmation dialog: anchored to a toolbar item the dialog becomes a popover and drops its cancel-role button.
- **B-25: turn-in model.** ETE = continue the current standard-rate orbit (direction from the GPS track rate; shorter turn when straight) until pointed at the target, then straight; Required GS solves the same path for TOT; Δ caption adds "+N ORBIT" when early by ≥ 120 s. `TurnToTarget` / `TurnDetector` with geometry, detector and view-model tests. A second evaluation after it landed confirmed the geometry and found the required-speed and detector issues now tracked as B-42 – B-45. Decision in `docs/decisions/`.
- **B-26: closed, no change.** Bearing and track stay true with no `°T` label; they are read relatively (steer Trk onto Brg), so only a shared reference matters. Documented on `FlightViewModel.bearing` / `track` and in `docs/decisions/`.
- **P2 B-27 – B-40** (B-17 landed with B-28).
- **P3 T-01 – T-13** and all listed "tests to add". Two residual T-07 touches remain in production code: `FlightEditorViewModel()` owns a real `CLLocationManager` (B-16) and `LocationProvider` still allocates a default manager even when one is injected.
- **P4 H-01 – H-08**, including the string catalog, `.gitignore`, and the committed Xcode Cloud manifest.

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

### B-42 · Required GS silently falls back to direct-to whenever the 400 m/s search ceiling puts the target inside the turn circle
- **Where:** `Core/Domain/TurnToTarget.swift` `requiredGroundSpeed(...)` (the `low = 0.5, high = 400.0` bisection and the `tHigh > timeRemaining || tLow < timeRemaining` fallback); consumed by `FlightViewModel.computeRequiredGroundSpeed(...)`.
- **What:** The bisection assumes `solve(...).totalTime` falls monotonically as speed rises. It does not. Turn radius `R = v / ω` grows with speed; once `R` exceeds half the target's abeam offset the near-side circle contains the target, `candidate(_:)` returns `nil` for that side, and the solver switches to a ~300° turn the other way, so the time jumps *up*. At `high = 400` (`R ≈ 7.6 km`) this happens for every target closer than about 8 nm abeam, `tHigh > timeRemaining` trips, and the function returns `distance / timeRemaining`: the straight-line speed, presented as the turn-aware one. Measured with the probe below (bearing 90°, track 0°, standard rate):

  | Geometry | Time left | Req GS shown | Modelled arrival at that speed | Correct speed |
  |---|---|---|---|---|
  | 2.0 nm abeam (3 704 m) | 100 s | 72 kt (37.0 m/s) | 113.2 s, 13 s late | 83 kt (42.9 m/s) |
  | 2.7 nm abeam (5 000 m) | 90 s | 108 kt (55.6 m/s) | 103.5 s, 13 s late | 128 kt (66.0 m/s) |
  | 2.7 nm abeam (5 000 m) | 120 s | 81 kt (41.7 m/s) | 132.7 s, 13 s late | 91 kt (46.8 m/s) |
  | 5 nm, 120° off the nose | 180 s | 117 kt | on time | 117 kt |

  The error exceeds the default red tolerance (B-05) on the one readout the pilot sets after rolling out, and it is largest exactly in the close-in orbit the B-25 decision describes.
- **Fix:** Restrict the search to the monotonic regime. Either (a) set `high = min(400, ω · dPerp / 2)` where `dPerp` is the target's perpendicular offset from the track line (so the near circle never contains the target), or (b) coarse-scan speeds upward from `low` (e.g. 2 m/s steps) for the first bracket where the time crosses `timeRemaining` *with the same `direction`*, then bisect inside that bracket. Keep the direct-to fallback only when the scan finds no speed at all. Tests: the three failing rows above as `abs(solve(..., groundSpeed: v).totalTime - T) < 0.01`; a parameterised round-trip over random distance/bearing/time that asserts `solve(requiredGroundSpeed(...)).totalTime ≈ T` whenever the result is non-nil; and a `FlightViewModelTests` case with a 2 nm abeam target and 100 s to ToT. Probe to reproduce: in `TurnToTarget.swift`, scan `solve(distance: 5_000, bearing: 90, track: 0, groundSpeed: v).totalTime` for `v` in 40…400 and watch it fall to 61 s at 120 m/s then jump to 144 s at 160 m/s.

### B-43 · ETE, ETA, Δ and the ORBIT caption flap by up to ~100 s when the turn detector toggles at its 1°/s threshold
- **Where:** `Core/Domain/TurnToTarget.swift` `TurnDetector` (`turningThresholdDegreesPerSecond = 1.0`; `smoothedRate = 0.5 * smoothedRate + 0.5 * rate`); `FlightViewModel.updateTimings()` passes `preferredDirection: turnDirection` to `solve(...)`.
- **What:** The detector is a two-sample average against a single threshold, so GPS course jitter near 1°/s (routine at low groundspeed or in turbulence) toggles `turnDirection` between a direction and `nil` from one fix to the next. With a direction the solver continues the orbit the long way round; without one it takes the shortest turn. Those two paths differ by most of a circle, up to 120 s at standard rate, so ETE, ETA, Δ, the status colour and the "+N ORBIT" caption can all alternate at 1 Hz.
- **Fix:** Hysteresis (enter "turning" at ≥ 1.5°/s, leave at ≤ 0.5°/s), a longer smoothing window (a 4–5 s exponential average or a median of the last five rates), and clear the direction only after N consecutive below-threshold samples. Tests in `TurnDetectorTests`: a right turn with ±1.5°/s of per-sample jitter stays `.right` throughout; a roll-out still returns to `nil` within about 5 s; a single wild sample mid-turn does not clear the direction.

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

### B-44 · `TurnDetector` is fed the wall clock, not the fix timestamp
- **Where:** `Features/FlightView/FlightViewModel.swift` `updateInstruments()`: `turnDetector.record(track: course, at: now())`.
- **What:** B-22 moved speed estimation onto `location.timestamp` because Core Location delivers fixes late and sometimes in batches. The detector measures a heading rate from the *receipt* time instead: two fixes delivered together give `dt ≈ 0`, which the `guard dt > 0` branch treats as a reset (direction cleared), and a fix delivered a second late halves the measured rate and can drop it under the threshold. `lastFixTimestamp` is already on `LocationProviding`.
- **Fix:** Use `locationProvider.lastFixTimestamp` as the sample time and ignore a sample whose timestamp has not advanced. Test with `MockLocationProvider` advancing the fix timestamps 1 s apart while the injected clock stands still (and the reverse: clock advancing, timestamps frozen, must not produce a turn).

### B-45 · `turnDuration` and `turnDirection` are published but nothing reads them
- **Where:** `Features/FlightView/FlightViewModel.swift` (the two `@Published private(set)` properties under "Published State (Timing)"); `FlightView.swift` has no reference to either.
- **What:** Their doc comments say they let the view explain why ETE exceeds distance / speed, but the flight screen shows nothing. The pilot cannot tell whether the ETE on screen assumes a 20° turn-in or a 300° continuation of the orbit, which is exactly the "turn in now or go around" call B-25 exists to support.
- **Fix:** Either surface them (a caption on the ETE row, e.g. "TURN 0:45 R", via the existing `LabelValueRow.caption`, and a small L/R marker on the Trk card) with accessibility identifiers and a UI test, or make them private and delete the comments. Product call; the first option is recommended.

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

## D — Design and Human Interface Guidelines audit (2026-10-07)

Rendered from the `#Preview`s on iPhone 18 Pro (iOS 27) in light and dark appearance, landscape, and Dynamic Type AX 3. D-01 and D-02 affect the flight screen a pilot reads in the cockpit; the rest are polish. Items already in good shape: purpose string, privacy manifest, first-launch disclaimer, location-denied banner with Open Settings, no unused entitlements, Cancel/Save toolbar placement in the editors.

### D-01 · Flight screen background inverts the colour scheme and fails contrast in both appearances
- **Where:** `Features/FlightView/FlightView.swift` `body` (`LinearGradient` of `Color.accentColor` at 0.5 and 0.8 opacity, `.ignoresSafeArea()`); `Shared Assets/Assets.xcassets/AccentColor.colorset/Contents.json` (both appearances reference `labelColor`).
- **What:** Because the accent colour *is* the label colour, the gradient is black over white in light mode and white over black in dark mode, while every readout uses `.primary`. Measured from the rendered previews: in light mode the "Mission Details" header is black on roughly #333 (≈ 1.7:1); in dark mode the headers are white on roughly #CCC (≈ 1.6:1); the orange `.bad` tint sits at ≈ 1.5:1 against the mid-grey in both. HIG asks for 4.5:1 (3:1 for large text) and says colour must not be the only status cue; the status tint on Cur GS, Req GS and ETA currently is. The label-coloured accent also neuters `.tint` on every control in the app (see D-06).
- **Fix:** Give `AccentColor` a real hue (the icon's navy, with a lighter dark-appearance variant) and stop deriving the flight background from it. Use a dedicated `FlightBackground` colour set with light and dark variants (a fixed dark cockpit background is fine as long as text is then forced to a light foreground, not `.primary`), keep the cards on `.ultraThinMaterial`, and verify green/orange/red pass 3:1 against the card material in both appearances and with Increase Contrast on. Run the Sufficient Contrast nutrition-label checks before claiming the label in App Store Connect (R-08).

### D-02 · "End Flight" is destructive but renders identically to "Edit TOT" / "Edit Hack"
- **Where:** `FlightView.swift` bottom `safeAreaInset` (`Button(role: .destructive)` with `.buttonStyle(.glass)`).
- **What:** The glass style ignores the destructive role for the label colour, so the preview shows two indistinguishable pills stacked directly under the buttons the pilot taps most. HIG: destructive actions should be visually distinct and placed to avoid accidental activation.
- **Fix:** `.tint(.red)` with `.glassProminent` (or keep `.glass` and set the label `.foregroundStyle(.red)`), keep the existing confirmation dialog, and consider moving End Flight to a top-trailing close position so it is not adjacent to Hack!/Edit.

### D-03 · Settings sheet has no title
- **Where:** `Features/SettingsEditor/SettingsEditorView.swift` (`NavigationStack` with Cancel, `EditButton`, Save and no `.navigationTitle`).
- **What:** The navigation bar is three bare pills; VoiceOver has no screen name to announce and the user has no confirmation of where they are.
- **Fix:** `.navigationTitle("Settings")` with `.navigationBarTitleDisplayMode(.inline)`. Optionally move `EditButton` into the Instruments section header to relieve the trailing group.

### D-04 · Instrument cards degrade at accessibility Dynamic Type sizes
- **Where:** `FlightView.swift` `InstrumentsSection` (fixed `InstrumentLayout.cardsPerRow = 3`) and `InstrumentCard` (`.minimumScaleFactor(0.6)` on the value).
- **What:** At AX 3 the "Cur GS" / "Req GS" titles wrap onto two lines and the values shrink to 60 %, so the most important numbers get *smaller* as the user asks for larger text. The bottom button inset also grows and covers more of the scroll content.
- **Fix:** Read `@Environment(\.dynamicTypeSize)`; when `isAccessibilitySize`, make `cardsPerRow` 1 or 2 (turn the static constant into a function of the size), remove `minimumScaleFactor` from the values, and use `ViewThatFits` for the title. Verify at AX 5 in portrait and landscape on iPhone and iPad; add a UI test that launches with `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityL` and asserts the cards exist and are hittable.

### D-05 · Measurement readouts have no space before the unit
- **Where:** `Core/UI Shared/MeasurementFormatters.swift` (`unitStyle = .short` in both `speedString` and `distanceString`).
- **What:** The flight screen shows "574km/h", "630km/h", "111.1km". `MeasurementFormatter`'s `.short` style drops the separator; the method doc comments promise "250 kt" / "12 nm" and system apps space the unit.
- **Fix:** `unitStyle = .medium`, or move to `Measurement.FormatStyle` (`.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: …)`), and update `MeasurementFormatters_Tests` (note T-05: pin the locale in those tests).

### D-06 · Smaller HIG items
- Edit TOT / Edit Hack sheets (`FlightView.swift`, the two `.sheet` modifiers) have no title and open full height for a wheel picker. Add a header and `.presentationDetents([.medium])` with `.presentationDragIndicator(.visible)`.
- Hard-coded `.tint(.blue)` on the empty-state button (`FlightsListView.swift` `FlightsEmptyStateView`) and the disclaimer button (`SafetyDisclaimerView.swift`). Use the accent colour once D-01 gives it a hue.
- Settings toolbar uses the `gear` symbol (`FlightsListView.swift` toolbar); `gearshape` is the current system glyph.
- `HackTimePickerView` wheel labels (`"\(m)m"`, `"%02ds"`) are neither localized nor pluralised; use `Text("\(m) min")` / `"\(s) s"` through the string catalog, or `Duration.UnitsFormatStyle`.
- `FlightView` has no navigation bar; the only exits are the bottom buttons. Acceptable for a cockpit screen, but confirm VoiceOver's escape gesture (two-finger Z) reaches the End Flight confirmation, or add `.accessibilityAction(.escape)`.
- The seeded `FlightsListView` preview renders the empty state because the seeding `ModelContext` is never saved; call `try? context.save()` so the list preview actually shows rows.

---

## Verified OK (for the record)
- Great-circle bearing math, haversine, and all `Measurement` unit conversions are correct.
- ETE, ETA, Δ sign convention and divide-by-zero guards are correct; only display (B-01) was broken. The direct-to Required GS was correct; the turn-aware solver that replaced it has the defect tracked as B-42.
- TOT stored as absolute `Date`, so midnight crossing is inherently handled.
- Keep-awake (`isIdleTimerDisabled`) is balanced on `FlightView` appear/disappear; sheets over it do not unbalance it.
- All SwiftData access is on the main actor; `onDelete` offsets match the iterated array; `ForEach` ids are unique UUIDs.
- All 17 test files are members of a test target; no orphans.
- No `try!`, `precondition`, `.first!`/`.last!`, or `print` in production code outside previews.

# App Store Connect listing — Formation Flight

Working copy for the App Store Connect record (backlog item R-08). Everything here is a draft to paste or adapt; nothing is submitted automatically.

## Basics

| Field | Value |
|---|---|
| Name | Formation Flight |
| Subtitle (30 chars) | Time-on-target timing aid |
| Price | Free, no in-app purchases |
| Primary category | Navigation |
| Secondary category | Utilities |
| Age rating | 4+ (questionnaire: no objectionable content, no unrestricted web access, no gambling) |
| Bundle ID | cc.mnmlst.Formation-Flight |
| Privacy policy URL | host `privacy-policy.md` from this folder (GitHub Pages or a static page) and paste the URL |
| Support URL | same page or the repository's Issues page |
| Marketing URL | optional; can match the support URL |

## Privacy

- App Privacy label: **Data Not Collected**. The app has a `PrivacyInfo.xcprivacy` declaring UserDefaults (reason CA92.1), no tracking, no collected data types.
- Location is "while using" only, processed on device, never transmitted.
- Export compliance: `ITSAppUsesNonExemptEncryption` is `NO` in Info.plist, so uploads skip the encryption prompt.

## Description (4000 chars max)

Formation Flight is a timing aid for pilots flying time-on-target (TOT) and hack-time missions. Set a target and a TOT, or start a hack, and the app uses your device's GPS to show the numbers you need to arrive on time:

• Time, ETE, ETA, and your early/late Δ against the TOT, colour-coded against tolerances you choose
• Current groundspeed and the groundspeed required to make the TOT
• Distance and bearing to the target, plus your current track
• Large, high-contrast readouts designed to be read at a glance in the cockpit
• Screen stays awake while a flight is active

Plan flights ahead of time, pick targets on a map or by coordinates, and adjust the TOT or hack time in flight.

Formation Flight is a supplemental situational-awareness tool. It is not a certified navigation system and must not be used as a primary means of navigation, terrain avoidance, or traffic separation. Always fly the aircraft first and cross-check against primary instruments.

## Keywords (100 chars max)

`time on target,TOT,formation,hack time,groundspeed,ETA,pilot,aviation,timing,bearing`

## What's New (1.0)

Initial release.

## Screenshots

Required sizes while iPad remains enabled: 6.9-inch iPhone and 13-inch iPad. Suggested set, in order:

1. Flights list with two or three planned missions.
2. Flight editor with a target selected on the map thumbnail.
3. In-flight view, TOT mission, Δ within tolerance (green).
4. In-flight view, hack mission, Δ late (orange or red) to show the colour coding.
5. Settings showing units and tolerances.

Capture on the simulator with location simulation enabled (the `TestFlight1.gpx` scenario in the test plan) so the in-flight readouts are populated.

## Review notes

Formation Flight is a free timing aid for pilots. To exercise the in-flight screen without flying:

1. Tap + to create a flight. Enter any mission name, choose TOT, set a time a few minutes ahead, then tap the target row and Save in the map picker to accept the default pin.
2. Tap Go Fly. The in-flight view shows time, ETE, ETA, Δ, and instrument readouts; with a simulated or real location fix the values populate within a second or two.
3. End Flight returns to the editor.

Location is used only while the app is in use and never leaves the device. A safety disclaimer is shown on first launch and is always available from Settings. No account or network access is required.

## Accessibility nutrition labels (optional)

Do not claim VoiceOver or Dynamic Type until a full pass has been done. The in-flight view has accessibility identifiers and scaled fonts, but the wheel pickers and the map picker have not been audited.

## Pre-submission checklist

- [ ] Privacy policy hosted and URL entered
- [ ] Support URL entered
- [ ] Age rating questionnaire completed
- [ ] App Privacy label set to Data Not Collected
- [ ] Screenshots uploaded for 6.9-inch iPhone (and 13-inch iPad if iPad stays enabled)
- [ ] App icon has light, dark, and tinted appearances (R-04)
- [ ] Build uploaded from Xcode Cloud with version 1.0 and a build number higher than any previous TestFlight build
- [ ] Review notes pasted

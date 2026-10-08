# App Store screenshots

Required sizes (App Store Connect, October 2026):

| Slot | Simulator | Size |
|---|---|---|
| iPhone with Dynamic Island (medium display) | iPhone 18 Pro | 1206×2622 |
| iPad 13" display | iPad Pro 13-inch (M5) | 2064×2752 |

The 6.9-inch size (1320×2868) is rejected by the iPhone slot ("File dimensions are invalid"). iPhone Duo screenshots are not required yet. Check the size list under each tab in App Store Connect before a reshoot; Apple changes it.

The Rose Bowl editor's TOT wheels show launch time + ~5 min; avoid shooting the editor just before the top of the hour, when the minute wheel sits at 58–59 with blank space under it.

## 1. Prepare the simulator

```sh
U=<simulator UDID>   # xcrun simctl list devices
xcrun simctl status_bar $U override --batteryState charged --batteryLevel 100 --cellularMode active --cellularBars 4 --wifiBars 3 --operatorName ""
xcrun simctl location $U set 34.2000,-118.4200
```

## 2. Launch with sample missions

Run the app with these launch arguments (in-memory store, so nothing persists):

```
-uiTestsResetStore -screenshotSeedFlights -hasAcknowledgedSafetyDisclaimer YES
```

`ScreenshotSeed` in `Formation_FlightApp.swift` inserts five missions; "Rose Bowl Flyover" is the TOT mission used for the flight screen.

## 3. Static screens

Navigate to each screen and save it at full resolution:

```sh
xcrun simctl io $U screenshot 01-flights.png
```

Shots: Flights list, Rose Bowl editor, map picker (tap the Target row), Lake Mead (hack) editor, Settings.

## 4. Live flight screen

The flight screen is driven by real (simulated) GPS. Shoot it in dark mode — it reads much better.

1. `xcrun simctl ui $U appearance dark`
2. Relaunch with the arguments above, open "Rose Bowl Flyover", tap **Go Fly**, and note the **TOT** shown.
3. Start the approach timed to arrive a few seconds early, wait for the readouts to settle, then capture:

   ```sh
   scripts/app-store-screenshots/fly-approach.py $U <TOT HH:MM:SS> 4 && sleep 14 && xcrun simctl io $U screenshot 06-flight-tot.png
   ```

Don't tap or capture through Xcode's device-interaction tools while the route is running — doing so interrupts the simulated location and the readouts drop to `--`. Use `simctl io` only.

4. Clean up: `xcrun simctl location $U clear; xcrun simctl ui $U appearance light`

## 5. Prepare for upload

`simctl io` writes PNGs with an alpha channel, and the iPhone and iPad sets use the same file names, which makes it easy to drop a file into the wrong size slot in App Store Connect ("File dimensions are invalid"). Flatten and prefix them before uploading:

```sh
python3 - <<'EOF'
from PIL import Image
import glob, os
for dev, prefix in (("iPhone-6.3", "iPhone63"), ("iPad-13", "iPad13")):
    os.makedirs(f"upload/{dev}", exist_ok=True)
    for src in sorted(glob.glob(f"{dev}/*.png")):
        im = Image.open(src).convert("RGBA")
        flat = Image.new("RGB", im.size, (0, 0, 0))
        flat.paste(im, mask=im.split()[3])
        flat.save(f"upload/{dev}/{prefix}-{os.path.basename(src)}", "PNG", optimize=True)
EOF
```

Upload `upload/iPhone-6.3/` to the "iPhone with Dynamic Island (medium display)" slot (1206×2622) and `upload/iPad-13/` to the "iPad 13" display" slot (2064×2752).

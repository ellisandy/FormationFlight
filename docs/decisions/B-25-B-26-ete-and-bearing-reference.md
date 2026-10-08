# Two product questions for pilot feedback

These two items from the engineering backlog (B-25 and B-26) are not bugs in the usual sense. The app does what the code says it should; the question is whether that is what a pilot wants. This note explains each one in plain language, shows the size of the effect with numbers, lays out the options, and ends with the questions we would like a pilot to answer.

Background on how the in-flight screen works today:

- You pick a target and either a Time on Target (TOT) or a hack time.
- The phone's GPS gives the app your position, groundspeed, and track (the direction you are actually moving over the ground).
- From that the app shows: Time, ETE (time to go), ETA, Δ (how early or late you will be against the TOT), Current GS, Required GS (the groundspeed you would need from here to hit the TOT exactly), Distance, Bearing to the target, and Track.

---

## B-25: What should ETE mean when you are not pointed at the target?

### What the app does now

ETE is distance to the target divided by your current GPS groundspeed. ETA is now plus ETE, and Δ is ETA minus TOT. This is the "direct-to" assumption: it answers "if I turned straight at the target right now and kept this speed, when would I get there?"

Required GS is always computed direct-to as well: distance divided by the time left until TOT.

### Why it matters

If your track is not aligned with the bearing to the target, your actual rate of closing on the target is lower than your groundspeed, so the direct-to ETE is optimistic and Δ reads earlier than you really are. The error is small when you are within a few degrees of the bearing and large when you are not.

Example: target 10 nm away, groundspeed 120 kt.

| Track relative to bearing | Closing speed | ETE shown today (direct-to) | ETE using closing speed | Difference |
|---|---|---|---|---|
| 0° (pointed at it) | 120 kt | 5:00 | 5:00 | 0 s |
| 10° off | 118 kt | 5:00 | 5:05 | 5 s |
| 30° off | 104 kt | 5:00 | 5:46 | 46 s |
| 60° off | 60 kt | 5:00 | 10:00 | 5:00 |
| 90° off (abeam) | 0 kt | 5:00 | never | n/a |

The default tolerances are ±10 s (yellow) and ±30 s (red), so a 30° offset is enough to turn a correct-looking green Δ into something that is actually well into red.

### Options

**A. Keep direct-to (current behaviour).** ETE and Required GS both assume you will fly straight to the target from here. Simple, stable, never blows up during a turn, and matches how most pilots think about a TOT when the plan is a straight run-in. The downside is the optimistic Δ shown above while you are offset, arcing, or in a holding pattern.

**B. Use closing speed for ETE.** ETE = distance divided by (groundspeed × cos(track − bearing)). ETE then reflects how fast you are actually getting closer. The downside is that it swings wildly during turns and becomes undefined when you are abeam or flying away, so the Δ readout would flicker or blank during normal manoeuvring. Required GS would still be direct-to, which means two numbers on the same screen use different assumptions.

**C. Keep direct-to, but flag divergence.** Keep ETE and Δ exactly as they are, and add a visible indicator (a small "DIRECT" or "OFF TRK 30°" tag next to ETE, or an amber tint) whenever track differs from bearing by more than a threshold, say 15°. The readout stays stable and its meaning is explicit. This is close to a feature the app had and removed earlier (a bearing tolerance for Required GS), so the plumbing is understood.

**D. Show both.** Direct-to ETE as the main number, closing-speed ETE as a smaller secondary number when they differ by more than a few seconds. Most information, most clutter.

Engineering recommendation: C. It keeps the numbers predictable in the cockpit, is cheap to build and test, and turns the ambiguity into something the pilot can see.

### Questions for the pilot

1. When you run a TOT, are you usually on a straight run-in to the target, or do you expect to be offset, arcing, or holding during the last minutes?
2. When you are 30° off the bearing, which ETE would you rather see: the "if I turn now" number, or the "at this rate" number?
3. Would a small off-track indicator next to ETE be useful, or noise? If useful, at what angle should it appear (10°, 15°, 20°)?
4. Does it bother you if Required GS and ETE make different assumptions?

---

## B-26: Should Bearing and Track be true or magnetic?

> **Decision (2026-10-07): keep both true, no label.** Pilot feedback: true was the assumption, a suffix is clutter, and the readouts are used relatively (steer until Trk matches Brg), so the only requirement is that both share one reference. Recorded as a comment on `FlightViewModel.bearing`/`track`. No code change beyond that. The options below are kept for the record.

### What the app does now

Bearing and Track are computed from GPS coordinates, so they are referenced to true north. The labels on the screen are just "Brg" and "Trk" with no T or M suffix.

### Why it matters

Cockpit heading instruments (HSI, DG, wet compass) are magnetic unless the aircraft is set up for true heading. Magnetic variation in the areas the app's test data uses (Skagit Valley, Washington) is about 15° east, so a true bearing of 333° on the phone corresponds to a magnetic bearing of about 318° on the instruments. A pilot cross-checking the phone against the HSI sees a 15° disagreement with nothing on screen to explain it. Elsewhere the difference ranges from zero to over 20°.

For a timing app this does not change ETE, ETA, Δ, or Required GS at all. It only affects the two direction readouts, but those are the ones a pilot is most likely to glance at while turning toward the target.

### Options

**A. Label as true.** Change the labels to "Brg °T" and "Trk °T" (or put a small "T" after the degree figures). No new data, no new failure modes, honest about what is shown. The pilot does the mental correction, which pilots already do when reading GPS tracks.

**B. Convert to magnetic automatically.** The phone's compass reports both a true and a magnetic heading when location is available; the difference is the local variation, which the app can apply to bearing and track. Labels become "Brg °M" and "Trk °M". Downsides: it needs the magnetometer (not available in the simulator and unreliable near metal and electronics in a cockpit), the variation reading can be noisy or absent for the first seconds, and the readout would silently fall back to true when it fails unless that case is shown clearly. A more robust alternative is bundling a World Magnetic Model calculation, which works from position alone with no sensor, at the cost of a few hundred lines of code and a coefficient table that needs updating every five years.

**C. Let the pilot choose.** A Settings switch, True or Magnetic, defaulting to magnetic, with the label always showing which is active. Combine with either sensor-based or model-based variation from option B.

**D. Manual variation per flight.** Add a "Variation" field to the flight editor (for example "15 E") that the pilot takes from the chart, exactly as on a paper flight log. Deterministic, works everywhere, no sensors, and the pilot stays in control. The cost is one more thing to enter per flight, and a stale value if they forget.

Engineering recommendation: A now (it is a label change and removes the ambiguity immediately), with C plus a World Magnetic Model as the follow-up if pilots say they want magnetic. Option B's sensor approach is the one to avoid in a cockpit.

### Questions for the pilot

1. When you glance at a bearing on a phone or tablet in flight, do you expect it to be true or magnetic?
2. Would a "°T" label be enough, or would you want the app to show magnetic so it matches your HSI directly?
3. If magnetic, would you rather the app work it out from position, or would you prefer to enter the chart variation yourself when planning the flight?
4. How much does a 15° disagreement between the phone and the HSI matter for how you use this app? Is bearing something you steer by here, or just a sanity check?

---

## What happens next

Once we have answers, each item is a small, test-first change:

- B-25 option C: an off-track indicator driven by track minus bearing, with a threshold setting, plus unit tests for the threshold and wrap-around at 360°.
- B-26: resolved, no change (see the decision above).

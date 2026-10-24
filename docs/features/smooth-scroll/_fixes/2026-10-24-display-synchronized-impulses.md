---
slug: smooth-scroll
date: 2026-10-24
triage: no-spec
acs: []
commit: 0c361c9
recurrence_of: 2026-10-24-pixel-wheel-inertia.md
---

# Fix: scrolling still feels unsmoothed compared with SmoothScroll

## Symptom

After the pixel-input fix, the user still reported little smoothness compared with their installed SmoothScroll and explicitly authorized reverse engineering to understand its behavior. At inspection time, the original was running and FlowScroll was disabled, so hardware comparison counters from that moment cannot establish how the previous build behaved while enabled.

## Root cause and evidence

The original accumulator jumps straight to maximum velocity, then exponentially decays. The UI's duration was actually a decay time constant: a 350 ms setting could produce a quantized tail lasting well beyond a second. A fixed 120 Hz Timer was independent of the display refresh rate.

Read-only inspection of the installed SmoothScroll 1.7.6 imports, Objective-C metadata, resources and x86 disassembly found a different architecture:

- CVDisplayLink follows the display under the mouse; frame time uses CACurrentMediaTime.
- An array stores independent impulses with start time, distance and previously emitted position. Each ends after animationTime, optionally applying a pulse curve.
- In its custom-acceleration mode, the wheel distance is reduced to its sign before applying stepSize and timing-based acceleration.
- The inspected emitter constructs two-axis pixel CGEvents, marks them continuous and posts at the HID tap. Gesture phases are optional for its bounce mode.
- Selected user preferences were stepSize=60, animationTime=360 ms, pulseScale=3, accelerationDelta=70 ms and accelerationMax=7.

These observations informed the architecture. FlowScroll uses its own polynomial cumulative curve, the integral of 20t(1-t)^3, and does not claim an exact recreation of the original pulse curve. The installed original was unchanged.

## Changes

DisplayClock replaces the 120 Hz timer with NSScreen/CADisplayLink on macOS 14+, with CVDisplayLink on macOS 13. Independent finite impulses accelerate and decelerate; newly arriving impulses retain their actual offset within the display frame. Fractional carry preserves distance while emitting integer pixel events. A discrete wheel event has a 60-point base step; pixel mouse input retains its point delta. Optional capped timing-based acceleration handles fast discrete rotation. Events enter at the HID tap, and generated-event tagging prevents recursion.

Defaults are 1× and 360 ms, with duration adjustable from 120 to 800 ms. Existing user settings remain until Reset. The menu warns when the original is also running. Diagnostics include version, display-frame count and maximum frame interval.

## Pinning test and validation

The added finite-duration test failed against the prior implementation:

> Fatal error: 360 ms animation must end at 360 ms, without a long quantized tail

The full suite now has 13 passing tests, including gentle attack, independently overlapping impulses, delayed input, dropped frames, bounded acceleration, reversal, native gestures and pixel mouse compatibility.

The display integration check ran outside the agent sandbox in the user's graphical session and delivered 36 frames over 0.6 seconds, with a mean interval of 16.67 ms (60 Hz). The sandbox itself lacks WindowServer access and cannot run this check. Release compilation, plist/script validation and signature verification are packaging gates. This is not an end-to-end measurement of browser-rendered scrolling; subjective matching with the physical MX Master 3S remains a user check after renewed Accessibility authorization.

The signed 0.2.0 bundle was built, passed packaging gates, and was relaunched successfully. Its runtime status confirmed version 0.2.0 and showed FlowScroll disabled, original SmoothScroll running, and Accessibility trust false following the ad-hoc rebuild. No physical-wheel sample was available before handoff. An independent read-only review of the new callback and impulse paths found no blocking regression.

## Spec patch

No spec exists to patch; README documents the new behavior and comparison steps. A survey and an independent review would be useful before expanding this prototype.

## Follow-ups

- Compare a single notch and sustained rotation against the original with only one smoother enabled.
- Observe input classification and emitted-frame counters if MX Master driver gestures still bypass smoothing.
- Real-device checks for macOS 13, multiple displays and 120/144 Hz displays remain outstanding.

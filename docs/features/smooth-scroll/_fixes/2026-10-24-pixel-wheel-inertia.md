---
slug: smooth-scroll
date: 2026-10-24
triage: no-spec
acs: []
commit: ddd818a
recurrence_of: none
---

# Fix: pixel mouse wheels bypass inertia

## Symptom

The user granted Accessibility permission and scrolled with an MX Master 3S, but felt no inertia, even with duration set to 350 ms. The app's stored settings had smoothing enabled and speed 1.9. No hardware event trace was available from the original build.

## Root cause

The original event handler rejected every continuous event, conflating pixel-based mouse input with trackpad gestures. It also read only line deltas, which can be zero for pixel-based input. This deterministic bypass was reproduced with a phase-free pixel wheel sample; whether it accounts for this specific driver's output still requires a physical-wheel check.

`ScrollInput` now uses scroll/momentum phases to preserve native gesture streams and uses point deltas for phase-free pixel wheels. This is a heuristic, not hardware identification. The engine uses this policy and exposes the latest classification plus temporary aggregate diagnostics. Permission refresh also retries a disabled tap, and its timer now runs in common modes.

## The pinning test

`testHighResolutionWheelUsesPointDistance` failed with the original policy:

> Fatal error: Phase-free pixel wheel was bypassed; inertia never starts

After the fix, all seven tests pass. They cover continuous mouse point scaling and reversal, an inertia tail after a wheel impulse, native gesture and momentum bypass, existing discrete-wheel scaling, distance conservation across frame rates, accumulation, reversal and reset.

Gate commands: `bash scripts/test.sh`, `bash scripts/build.sh`, `bash -n scripts/test.sh scripts/build.sh`, `plutil -lint Resources/Info.plist`, `codesign --verify --deep --strict build/FlowScroll.app`, and whitespace checks. Physical scrolling and native gesture behavior remain manual validation steps.

Version 0.1.1 was launched and its process remained alive. Its runtime diagnostic file reported `permission: false` and `running: false` after rebuilding: macOS must reauthorize the new ad-hoc binary before physical input can be validated. No input was reported before handoff.

## Spec patch

No spec exists to patch. README compatibility and diagnostic instructions were updated. An architecture survey may help if the app grows beyond this initial prototype.

## Follow-ups

- Validate with the user's actual MX Master 3S events using the new status and counters. If the driver emits gesture phases, investigate source identification or an explicit compatibility option rather than smoothing trackpad gestures by default.
- Ad-hoc rebuilds change the code hash; macOS may require Accessibility access to be re-enabled.

---
slug: smooth-scroll
date: 2026-10-24
triage: no-spec
acs: []
commit: d6e771b
recurrence_of: none
---

# Fix: mouse cursor jerks while scrolling is active

## Symptom

The user reported jerky pointer movement after successfully authorizing and using FlowScroll 0.2.0. FlowScroll was stopped, and the user explicitly confirmed that the jerks disappeared. The stopped process was not replaced until tests passed.

## Root cause

Each synthetic frame reused coordinates captured at the last wheel input and was posted at the HID tap. During an inertia tail, physical pointer movement could conflict with these repeated stale coordinates. This is a strong causal explanation consistent with the user's stop test, but the exact WindowServer cursor update behavior was not instrumented.

`ScrollContext` now separates the wheel origin used for display selection from the live pointer position used for outgoing frames. Every frame samples `CGEvent(source: nil)?.location` and posts at `.cgSessionEventTap`. If sampling fails, motion is cancelled instead of falling back to old coordinates. Generated-event tagging and pixel deltas remain intact.

## Pinning test

`testScrollFrameFollowsCurrentPointer` reproduced the old emitter behavior and failed:

> Fatal error: Scroll frame reused stale wheel coordinates and can pull the cursor back

It now passes for pointer positions different from the wheel origin, including negative global coordinates. Additional tests require cancellation when current coordinates are unavailable and require the session posting location. The output test also checks pixel deltas, modifier flags, the continuous flag and the recursion marker on actual constructed CGEvents.

## Validation

All 16 tests passed. Release 0.2.1 compiled and was packaged successfully. Shell syntax, plist, whitespace and code-signature validation passed. The relaunched process published version 0.2.1 and Accessibility trust false after its ad-hoc signature changed. A physical pointer test with the new build is still required after reauthorization; tests do not prove that native pointer motion is completely unaffected.

## Spec patch

No feature spec exists; README was updated with the output-coordinate behavior. A future survey can capture these requirements before further feature expansion.

## Follow-ups

- Confirm pointer movement during a long inertia tail with the physical MX Master 3S.
- Ad-hoc rebuilds may require renewed Accessibility authorization.

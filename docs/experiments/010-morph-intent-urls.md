# Experiment 010 — Google Maps in Morph: "cannot open intent addresses"

**Date:** 2026-09-05 · **Status:** ✅ answered · **Device needed:** no (verified on it)

## Symptom

Opening Google Maps in Morph shows

> unrecognized address, cannot open "intent" addresses

This is **not** a GPS or location-service fault. It was hit while testing
[009](009-gps-permissions.md) and is easy to misattribute to it.

## Cause

`intent://` is an Android-only URL scheme. Google serves it to browsers whose
user agent looks like Android, to hand off to the native app. Morph has no such
app and no handler for the scheme, so navigation fails.

Morph's own default user agent is why it looks like Android —
`/usr/lib/aarch64-linux-gnu/qt6/qml/Morph/Web/UserAgent02.qml`:

```qml
readonly property string _attributes: screenSize === "small" ? "like Android 9" : ""
readonly property string _formFactor: screenSize === "small" ? "Mobile" : ""
```

On a phone-sized screen that produces:

```
Mozilla/5.0 (Linux; Ubuntu 26.04 like Android 9) AppleWebKit/537.36 Chrome/134.0.6998.208 Mobile Safari/537.36
```

Morph here runs on **Qt6** (`qml6-module-qtwebengine` 6.10.2, Chromium 134).
The Qt5 copy of the same QML file is installed but is *not* the one in use —
reading the Qt5 path gives Chromium 87 and the wrong UA.

## Evidence

Fetched `https://www.google.com/maps` from the device with each UA and counted
the deep links:

| User agent | bytes | `intent://` |
|---|---|---|
| `… Ubuntu 26.04 like Android 9 …` | 799,965 | **2** |
| `… Ubuntu 26.04 …` (no Android token) | 189,288 | **0** |

Dropping the Android token — while keeping `Mobile`, so the mobile site is
still served — removes the deep links entirely.

## Fix

Morph supports per-domain custom user agents; they live in
`~/.local/share/morph-browser/domainsettings.sqlite` (tables `useragents` and
`domainsettings`, joined on `userAgentId`). Applied by
[`scripts/morph-google-ua.sh`](../../scripts/morph-google-ua.sh), which backs up
the database first, registers the UA above and points `www.google.com` and
`maps.google.com` at it.

It also sets `allowLocation = 1`. The values are `0` ask each time, `1`
allowed, `2` denied — it was `0`, i.e. prompting, **not** blocked, so this is a
convenience rather than part of the fix.

Both are reversible from Morph's own Settings UI.

## Note

`allowCustomUrlSchemes` was already `1` for `www.google.com`, so this is not a
scheme-permission problem. Morph genuinely has no `intent://` handler, and
allowing custom schemes cannot invent one.

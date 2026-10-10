# KeyboardLock

macOS app (Swift) that locks the whole keyboard. It runs as a regular window app or as a menu bar widget.

## Install
Download the latest `.dmg` from the [Releases](../../releases) page, drag the app to **Applications**, then:
1. First launch: right-click the app › **Open** (it is not notarized).
2. Grant **Accessibility** in System Settings › Privacy & Security, then relaunch.

## Use
Pick a duration (30 s, 1 min, 5 min, 10 min, ∞) and press **Lock**. Unlock with the **Unlock** button (mouse / trackpad) or wait for the timer to end.
Keys, modifiers and media keys are blocked. The physical power button is still handled by the system.

## Build from source
```sh
./scripts/build-app.sh      # -> build/KeyboardLock.app
open build/KeyboardLock.app
./scripts/make-dmg.sh       # -> build/KeyboardLock-<version>.dmg
```
Set `VERSION=1.2.3` to stamp a version. Signing uses the local `KeyboardLock Dev` certificate if present, otherwise an ad-hoc signature.

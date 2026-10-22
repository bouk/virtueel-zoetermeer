# Differential testing (equivalence mode)

Without a Delphi 5 compiler the decompiled source cannot be checked by byte-matching, so it
is checked by *behaviour*: the original `ROS.exe` (under Wine) and the portable build are
driven with the same input script, and their game state is dumped and compared.

## Scripts (`tests/scripts/*.zms`)

One command per line, `#` starts a comment. Coordinates are client coordinates of the main
form (1024x768).

| command | meaning |
|---|---|
| `wait <ms>` | wait |
| `move <x> <y>` | move the pointer |
| `click <x> <y> [right]` | enter the target from 60 px to the left in 3 px steps, wait 300 ms, press, release 150 ms later (the game's buttons are sprites that need the hover) |
| `key <name>` | key press, xdotool key names (`Return`, `Escape`, `Left`, `plus`, ...) |
| `seed <n>` | set `RandSeed` right before the next mouse press (Delphi's LCG; the port uses the same generator, `src/compat/ZMRandom.pas`) |
| `dump <name>` | write `<name>.state` |
| `shot <name>` | write `<name>.png` |
| `sprites <name>` | port only: write `<name>.sprites` (all sprites of the main form) |

## State format

```
level <n>
geld <n>
score <n>
reistijd <float, 6 decimals>
cell <x> <y> <Contents> <Param> <Wijk> <Wegen> <Bereikbaar>     (45 x 45 lines, '-' = empty)
```

## Running

Original (Wine + Xvfb; reads the live game objects through `/proc/<pid>/mem`):

```
nix develop --command bash -c 'export WINEPREFIX=$PWD/.wine; xvfb-run -a -s "-screen 0 1280x1024x24" \
  python tools/orig_probe.py build/run-1.1 tests/scripts/smoke.zms build/diff/orig'
```

(`build/run-1.1` is a copy of `orig/game` with the v1.1 `ROS.exe`; `tools/run-orig.sh` creates it.)

Portable build (`ZMHarness` runs the script from the message pump and injects input):

```
nix develop --command tools/build.sh src/tests/RosTest.dpr
ZM_HEADLESS=1 ZM_DATA=$PWD/orig/game ZM_EXE=$PWD/orig/game-1.1/ROS.exe \
  ZM_TESTSCRIPT=tests/scripts/smoke.zms ZM_TESTOUT=build/diff/port build/fpc/RosTest
```

Then `diff build/diff/orig/<name>.state build/diff/port/<name>.state`.

## Caveats

* Timers (the seagull, cars, trains) also draw random numbers. That is why `seed` takes
  effect right before the next mouse press: the random choices made by that click are then
  comparable, while choices made later by timers can still diverge for timing reasons.
* Screenshots differ in size (the Wine desktop is 1280x1024 with the form at +128,+128).

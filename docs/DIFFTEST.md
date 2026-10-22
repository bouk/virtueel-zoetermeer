# Differentiële tests (equivalentiemodus)

Zonder Delphi 5-compiler kan de gedecompileerde broncode niet met byte-vergelijking worden gecontroleerd,
dus wordt die gecontroleerd op *gedrag*: het originele `ROS.exe` (onder Wine) en de portable build worden
met dezelfde invoerscript aangestuurd, en hun speltoestand wordt gedumpt en vergeleken.

## Scripts (`tests/scripts/*.zms`)

Eén commando per regel, `#` begint een commentaar. Coördinaten zijn clientcoördinaten van het hoofdformulier
(1024x768).

| commando | betekenis |
|---|---|
| `wait <ms>` | wacht |
| `move <x> <y>` | verplaats de aanwijzer |
| `click <x> <y> [right]` | ga vanaf 60 px links van het doel in stappen van 3 px, wacht 300 ms, druk in, laat 150 ms later los (de knoppen van het spel zijn sprites die de hover nodig hebben) |
| `key <name>` | toetsaanslag, xdotool-toetsnamen (`Return`, `Escape`, `Left`, `plus`, ...) |
| `seed <n>` | zet `RandSeed` vlak voor de volgende muisklik (Delphi's LCG; de port gebruikt dezelfde generator, `src/compat/ZMRandom.pas`) |
| `dump <name>` | schrijft `<name>.state` |
| `shot <name>` | schrijft `<name>.png` |
| `sprites <name>` | alleen port: schrijft `<name>.sprites` (alle sprites van het hoofdformulier) |

## Toestandsformaat

```
level <n>
geld <n>
score <n>
reistijd <float, 6 decimalen>
cell <x> <y> <Contents> <Param> <Wijk> <Wegen> <Bereikbaar>     (45 x 45 regels, '-' = leeg)
```

## Uitvoeren

Origineel (Wine + Xvfb; leest de levende spelobjecten via `/proc/<pid>/mem`):

```
nix develop --command bash -c 'export WINEPREFIX=$PWD/.wine; xvfb-run -a -s "-screen 0 1280x1024x24" \
  python tools/orig_probe.py build/run-1.1 tests/scripts/smoke.zms build/diff/orig'
```

(`build/run-1.1` is een kopie van `orig/game` met het v1.1 `ROS.exe`; `tools/run-orig.sh` maakt die aan.)

Portable build (`ZMHarness` voert het script uit vanuit de berichtenlus en injecteert invoer):

```
nix develop --command tools/build.sh src/tests/RosTest.dpr
ZM_HEADLESS=1 ZM_DATA=$PWD/orig/game ZM_EXE=$PWD/orig/game-1.1/ROS.exe \
  ZM_TESTSCRIPT=tests/scripts/smoke.zms ZM_TESTOUT=build/diff/port build/fpc/RosTest
```

Vergelijk daarna met `diff build/diff/orig/<name>.state build/diff/port/<name>.state`.

## Aandachtspunten

* Timers (de meeuw, auto's, treinen) trekken ook willekeurige getallen. Daarom werkt `seed` vlak voor de
  volgende muisklik: de willekeurige keuzes die die klik maakt zijn dan vergelijkbaar, maar keuzes die
  timers later maken kunnen om timingredenen nog afwijken.
* De tikteller telt mee. Onder Wine is `GetTickCount` de uptime van de computer; vanaf 2^31 ms
  (modulo 2^32, dus 24,9 tot 49,7 dagen na het opstarten) loopt `TAutoSprite.Draw.DrawAutos` bij
  elke aanroep miljoenen keren rond (een fout in het origineel, zie `src/compat/ZMKlok.pas`).
  Elk beeld duurt dan honderden ms, de snelle timers slaan tikken over en bijvoorbeeld de knop
  "Volgende ronde" verschijnt op een willekeurig moment. `orig_probe.py` start Wine daarom in een
  eigen tijdnaamruimte (`unshare --user --time`) met een uptime van 60 s; de port telt vanaf de
  start van het programma. `ZM_GEEN_TIJDNAAMRUIMTE=1` (origineel) en `ZM_TIKBEGIN=<ms>` (port)
  spelen het gedrag bij een grote tikteller na (`tests/scripts/volgende-ronde.zms`).
* "Volgende ronde" verschijnt pas bij de derde tik van `timerRecalc` (1 s) na het bouwen; de fase
  van die timer ligt vast vanaf de start van het programma. Klik er dus niet eerder dan ruim 3 s
  na het bouwen op.
* Screenshots verschillen in grootte (het Wine-bureaublad is 1280x1024 met het formulier op +128,+128).

## CI (`nix flake check`)

Zonder Delphi 5 kan de CI geen bytes vergelijken; ze controleert het gedrag. `nix flake check`
(op x86_64-linux) bouwt:

| check | wat |
|---|---|
| `zoetermeer` | de native versie (`packages.zoetermeer`) |
| `web` | de webversie (`packages.web`) |
| `difftest` | `nix/difftest.nix`: bouwt `src/tests/RosTest.dpr`, speelt elk `tests/scripts/*.zms` zonder venster af (`ZM_HEADLESS=1`, geen X-server nodig) en vergelijkt elke `.state` met `tests/verwacht/<script>/<naam>.state` |
| `macos-compileert` | `nix/macos-compileert.nix`: compileert `src/game/Ros.dpr` met een FPC 3.2.2-cross-compiler voor aarch64-darwin (`nix/fpc-aarch64-darwin.nix`) en linkt met `ld64.lld` tegen de macOS-SDK-stubs tot een arm64-Mach-O (draaien kan op Linux niet) |

Eén check los: `nix build .#checks.x86_64-linux.difftest -L`. Het harnas draait in echte tijd,
dus `difftest` duurt een paar minuten; een afwijkend script wordt één keer opnieuw gedraaid
(timing op een drukke bouwmachine). De toestanden van de port staan daarna in `result/`.

De verwachte toestanden in `tests/verwacht/` komen van het **originele** spel onder Wine:

```
tools/ververs-verwacht.sh                        # alle scripts, na elkaar (1 tot 3 min per script)
tools/ververs-verwacht.sh tests/scripts/smoke.zms
```

Het script start zichzelf zo nodig in `nix develop`, haalt de spelbestanden uit `.#spel-data` en
draait elk script in een verse kopie (`build/verwacht/`). Nieuw script: eerst verwachte
toestanden maken, dan controleren dat de port overeenkomt (de check zelf, of met de hand zoals
hierboven), en `git diff tests/verwacht` bekijken voordat je ze commit. Een script zonder
verwachte toestanden laat de check falen.

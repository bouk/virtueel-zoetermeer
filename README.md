# Virtueel Zoetermeer

*Virtueel Zoetermeer* is een educatief stadsbouwspel uit 2003, gemaakt door Oberon Medialab
(Amsterdam) voor de gemeente Zoetermeer. Je bouwt Zoetermeer in elf levels op, van dorp in 1962
tot moderne stad: wijken, wegen en spoor, huizen, kantoren, molens en voorzieningen, terwijl je
op geld, bereikbaarheid, overlast en groen let. Het spel is vrij beschikbaar op
[archive.org](https://archive.org/details/virtueel-zoetermeer).

Deze repository bevat een **decompilatie** van het spel: de oorspronkelijke Windows-versie
(`ROS.exe` v1.1, geschreven in Delphi 5) is teruggebracht naar leesbare Object Pascal-broncode.
Die bron wordt met Free Pascal opnieuw gebouwd voor **Linux**, **macOS (ook Apple Silicon)** en
de **browser (WebAssembly)**.

## Spelen

Met [Nix](https://nixos.org) (flakes aan):

```sh
nix run .            # in een checkout van deze repository
```

De spelbestanden worden tijdens het bouwen automatisch van archive.org gehaald (met vaste
controlesom); ze staan niet in deze repository. Opgeslagen steden en de topscore komen in
`~/.local/share/zoetermeer` (macOS: `~/Library/Application Support/Virtueel Zoetermeer`).

Op macOS levert `nix build .#zoetermeer` ook `result/Applications/Virtueel Zoetermeer.app`.

### In de browser

```sh
nix build .#web          # statische site in ./result
python3 -m http.server -d result 8000
```

Open daarna <http://localhost:8000>. Klik in het spel om de muis te vangen; met Esc laat je
hem weer los. Opgeslagen steden blijven in de browser bewaard (localStorage).

## Hoe ver is het?

| Onderdeel | Stand |
|---|---|
| Decompilatie | alle 34 eigen units van `ROS.exe`; elke routine (113 KB machinecode) heeft een Pascal-tegenhanger met adresmarkering `{ @ADRES }` |
| Controle | differentiële tests: het origineel (onder Wine) en de herbouw krijgen dezelfde invoer; de speltoestand (kaart, geld, score, reistijd) is na bouwen, een volgende ronde en het rapport byte voor byte gelijk |
| Linux / macOS | draait met SDL3; schermen zijn (vrijwel) pixel-gelijk aan het origineel |
| Browser | draait als WebAssembly (Free Pascal trunk + Asyncify) |
| Byte-identieke herbouw | niet mogelijk zonder de Delphi 5-compiler (zie hieronder) |

### Waarom niet "matching"?

Een *matching* decompilatie levert met de oorspronkelijke compiler exact hetzelfde `.exe`-bestand
op. Daarvoor is Borland Delphi 5 nodig, en die is niet vrij beschikbaar. Daarom werkt dit project
in *equivalentiemodus*: de bron is zo trouw mogelijk aan het origineel (zelfde routines, in
dezelfde volgorde, met dezelfde velden, constanten en zelfs dezelfde fouten), en de juistheid wordt
aangetoond door het gedrag te vergelijken in plaats van de bytes. Mocht Delphi 5 ooit beschikbaar
komen, dan kan de bron worden aangescherpt tot een byte-identieke build (zie `PLAN.md`, fase 2).

## Opbouw van de repository

```
src/game/      de gedecompileerde spelcode (Object Pascal, Delphi 5-dialect)
src/compat/    portable nabouw van de gebruikte Delphi 5-VCL, Win32 en DirectDraw
               (eigen venstersysteem en GDI in software, met een SDL3-backend)
src/web/       de WebAssembly-backend en het webprogramma
src/tests/     testharnas (differentiële tests en interactief spelen)
web/           de browserhost (WASI, Asyncify, canvas, invoer)
tools/         analyse- en bouwgereedschap (Python, shell, Ghidra-scripts)
symbols/       teruggevonden symbolen, klassen, unitgrenzen en naamkaarten
tests/scripts/ invoerscripts voor de differentiële tests
nix/           Nix-pakketten: spelbestanden, spel, website, Free Pascal voor wasm32
docs/          werkwijze en ontwerp (DECOMP, COMPAT, WASM, DIFFTEST)
PLAN.md        het plan en de beslissingen
```

## Zelf ontwikkelen

```sh
nix develop                                   # alle gereedschap (Free Pascal, Ghidra, Wine, ...)
tools/extract-orig.sh "Virtueel Zoetermeer.zip"   # originele bestanden naar orig/
tools/build.sh                                # bouw build/fpc/Ros
ZM_DATA=$PWD/orig/game ZM_EXE=$PWD/orig/game-1.1/ROS.exe build/fpc/Ros
tools/bouw-web.sh                             # bouw de webversie in build/web
```

Analyse en decompilatie:

- `tools/delphi.py`, `tools/units.py`, `tools/symbols.py`, `tools/classes.py`: herkennen de
  unitindeling, VMT's, RTTI en klassen in `ROS.exe`; `tools/idrkb.py` en `tools/kbmatch.py`
  benoemen RTL/VCL-routines met de kennisbank van IDR.
- `tools/ghidra/analyze.sh` en `tools/refresh.sh`: Ghidra-analyse zonder scherm, met de
  teruggevonden namen en klassenstructuren; uitvoer per unit in `build/decomp-1.1/`.
- `tools/coverage.py`: welke routines al broncode hebben.

Testen:

- `tools/compat-test.sh`: tests van de compat-laag.
- Differentiële tests (`docs/DIFFTEST.md`): `tools/orig_probe.py` speelt een script af tegen het
  origineel onder Wine en leest de speltoestand uit het geheugen; `RosTest` doet hetzelfde met
  de herbouw. De uitkomsten moeten gelijk zijn.
- `tools/test-web.py`: dezelfde scripts in een headless browser.
- `tools/speel.py`: het spel stap voor stap besturen (klik, toets, foto, toestand), bedoeld voor
  een agent die het hele spel doorspeelt op zoek naar crashes.

De conventies voor de spelcode staan in `docs/DECOMP.md`. Alle broncode en documentatie is
Nederlandstalig; namen die uit het origineel komen (klassen, gepubliceerde velden en
event-handlers zoals `TSprite` of `butReadyClick`) en namen uit de Delphi/Win32-API zijn
ongewijzigd gebleven.

## Rechten

*Virtueel Zoetermeer* is gemaakt door Oberon Medialab in opdracht van de gemeente Zoetermeer.
Deze repository bevat geen spelbestanden: afbeeldingen, formulieren en gegevens worden bij het
bouwen of starten uit het origineel gehaald. De lettertypen van de compat-laag zijn gegenereerd uit
de Liberation-lettertypen (SIL Open Font License).

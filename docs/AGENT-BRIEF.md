# Opdracht voor decompilatie-agenten

Je maakt deel uit van het team dat **Virtueel Zoetermeer** (`ROS.exe` v1.1, Delphi 5, 2003), een
Nederlands educatief stadsbouwspel, decompileert naar Object Pascal-broncode. De broncode wordt later
met Free Pascal gebouwd voor Apple Silicon macOS en WebAssembly, dus hij moet getrouw *en* portable zijn.

Repository: `/home/bouke/zoetermeer`. Voer elk gereedschap uit via de Nix-dev-shell vanuit de repositorymap:
`nix develop --command <cmd>` (fpc, python met pefile/capstone, ghidra, wine zijn er allemaal).

## Eerst lezen

1. `docs/DECOMP.md`: conventies (dialect, getrouwheid, klasselay-out, naamgeving, portabiliteit,
   het `symbols/names/<Unit>.json` dat je moet schrijven). Volg die exact.
2. `src/game/uString.pas` + `symbols/names/uString.json`: een afgeronde unit, gebruik die als stijlreferentie.

## Materiaal per unit

* `build/decomp-1.1/<Unit>.s`: gesymboliseerde disassemblage, elke routine van de unit in adresvolgorde,
  inclusief try/except/finally-handlerblokken. **Primaire bron van waarheid.**
* `build/decomp-1.1/<Unit>.c`: Ghidra-decompilatie van dezelfde routines (goed voor structuur; fout over
  Delphi-strings/exceptions/details van de register-aanroepconventie; controleer met `.s`).
* `symbols/classes-1.1.md`: elke projectklasse: VMT-slots (NEW/override, met de voorouder die elk slot
  introduceerde), published velden/methoden/eigenschappen met offsets/accessors, dynamische
  (bericht)methoden, instantiegroottes.
* `symbols/vcl-vmt-slots.md`: slot → methodenamen voor VCL-klassen (`call [reg+0x34]` op een `TStrings` is
  `Add`, enz.). Veldnamen van VCL-klassen staan al in de Ghidra-C.
* `symbols/ros-1.1.tsv`: alle bekende symbolen (`adres soort unit naam`); `s`-regels zijn stringliterals
  (adres van de tekens, naam = lengte).
* `build/dfm-1.1/*.txt`: formulierresources als tekst (componentnamen/-typen/events).
* `symbols/unit-deps-1.1.json`, `symbols/units-1.1.json`: unitbereiken en kruisverwijzingen.
* Om ruwe bytes of data te bekijken (getypeerde constanten, sets, tabellen in DATA/BSS), gebruik python met
  `tools/delphi.py`: `im = delphi.Image('orig/game-1.1/ROS.exe'); im.bytes(va, n)`.

## Coördinatie

* Meerdere agenten werken parallel aan verschillende units. Schrijf alleen de bestanden die aan jou zijn toegewezen.
* **Schrijf het `interface`-gedeelte van je units eerst** (typen, klassedeclaraties met alle velden en methoden,
  globals, routinekoppen) en sla het vroeg op, met implementatiestubs als dat nodig is, zodat anderen erop
  kunnen bouwen. Vul daarna de implementaties in.
* Als je een unit gebruikt die van iemand anders is, lees `src/game/<ThatUnit>.pas` als die bestaat en gebruik
  zijn namen. Bestaat die nog niet, gebruik de namen uit `symbols/classes-1.1.md` /
  `symbols/ros-1.1.tsv`, en kies voor alles zonder naam een verstandige naam en vermeld die in de
  `"assumes"`-sectie van je namen-JSON (`{"assumes": {"TWorld": ["FCells: TCellList (+0x8)"]}}`),
  zodat de integratie het kan afstemmen.
* De platformlaag (`src/compat/`: `Windows`, `Messages`, `Graphics`, `Controls`, `Forms`,
  `StdCtrls`, `ExtCtrls`, `ddraw`, `MMSystem`, …) wordt door een andere agent geschreven. Schrijf spelcode
  tegen de gewone Delphi 5-API; werk nooit ontbrekende compat-onderdelen in spelcode heen.
* **Doe niet** aan git committen, `tools/refresh.sh` draaien of Ghidra draaien (gedeelde staat; de coördinator
  doet dat). Bewerk geen bestanden buiten je opdracht, behalve nieuwe notities onder `docs/notes/`.

## Je werk controleren

* `nix develop --command tools/build.sh src/game/<Unit>.pas` compileert een unit met FPC. Het heeft de
  compat-units nodig die je unit gebruikt; bestaan die nog niet, dan faalt de compilatie op de `uses`-clausule
  — dat is vroeg in het werk te verwachten. Probeer het opnieuw vlak voor het einde van je werk; los elke fout
  op die in *jouw* code zit. Meld compat-gaten in plaats van eromheen te patchen.
* Lees elke routine nog een keer na tegen de `.s` voordat je klaar bent: elke branch, elke aanroep, elke
  constante, elke string.

## Eindrapport (je laatste bericht)

Kort: units klaar, routines die je niet met zekerheid kon decompileren (adres + waarom), namen die je voor
leden van andere units hebt aangenomen, en compat-API die je nodig had en die ongebruikelijk leek.

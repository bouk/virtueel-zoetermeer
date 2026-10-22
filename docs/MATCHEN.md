# Matchen met Delphi 5

Dit document beschrijft de gereedschappen van de matching-pipeline (PLAN.md, fase 2): bouwen met
de originele compiler, vergelijken met het origineel, voortgang meten en de bootstrap met
asm-stubs. We hebben **nog geen Delphi 5-compiler**; het project werkt in equivalentiemodus
(zie PLAN.md, "Beslissingen"). De gereedschappen zijn daarom zo geschreven en getest dat ze klaar
liggen voor de dag dat er een Delphi 5-toolchain is. Wat wel en niet getest kon worden, staat
onderaan.

| Gereedschap | Wat het doet |
|---|---|
| `tools/bouw-delphi.sh` | bouwt `src/game/Ros.dpr` met `dcc32` onder Wine tot `build/delphi/ROS.exe` + `ROS.map` |
| `tools/diff.py` | vergelijkt herbouw en origineel: hele bestand, per PE-sectie, per routine |
| `tools/progress.py` | % van de bytes per projectunit dat in gelijke routines zit; JSON en SVG-badge |
| `tools/maak-stubs.py` | schrijft per projectunit een Pascal-unit met de originele bytes als `asm`-blokken |
| `tools/maak-testmap.py` | schrijft een Delphi-map voor het origineel (alleen om de map-route te testen) |
| `tools/test_matchpipeline.py` | regressietests van al het bovenstaande |

Originele bestanden en alles wat originele codebytes bevat (`build/stubs/`, gepatchte kopieën)
staan alleen onder `orig/` of `build/` en worden nooit gecommit. De toolchain komt in
`toolchain/` (ook genegeerd door git).

## Werkwijze zodra Delphi 5 er is

1. **Toolchain neerzetten.** Kopieer een Delphi 5-installatie naar `toolchain/`:
   `toolchain/bin/dcc32.exe` en `toolchain/lib/` (de `.dcu`'s en `.res`-bestanden van de RTL/VCL).
   Welke build (basis of Update Pack 1) het origineel gebruikte, moet eerst worden vastgesteld
   door de RTL-routines te vergelijken (stap 4 laat dat direct zien: alle bibliotheekroutines
   moeten `gelijk` zijn).
2. **Schakelaars.** `bouw-delphi.sh` neemt de compilerschakelaars uit `toolchain/schakelaars.cfg`
   als dat bestaat (vrije tekst, `#` begint commentaar, bijv. `-$O+ -$W-`). Anders leest het
   `docs/SCHAKELAARS.md`: het eerste codeblok met taal `dcc32` (of `schakelaars`), en als dat er
   niet is elke vorm `-$X+`, `-$X-`, `-$Xn` in het document. Het gebruikte stel wordt afgedrukt.
3. **Bouwen.**

   ```sh
   tools/bouw-delphi.sh            # -B -GD, uitvoer build/delphi/ROS.exe en ROS.map
   tools/bouw-delphi.sh --droog    # alleen controleren en het dcc32-commando tonen
   ```

   Extra argumenten gaan ongewijzigd naar `dcc32`. `ZM_UNITPADEN=build/stubs` zet extra
   unitmappen vóór `src/game` (voor de bootstrap, zie onder); `ZM_TOOLCHAIN=<map>` kiest een
   andere toolchain-map. Paden gaan als `Z:\…` naar Wine; de Wine-prefix is `.wine/`, net als
   bij `tools/run-orig.sh`.
4. **Vergelijken.**

   ```sh
   nix develop --command python3 tools/diff.py orig/game-1.1/ROS.exe build/delphi/ROS.exe \
       --map build/delphi/ROS.map [-v] [--alles] [--json build/diff.json]
   nix develop --command python3 tools/progress.py orig/game-1.1/ROS.exe build/delphi/ROS.exe \
       --map build/delphi/ROS.map [--json build/progress.json] [--badge build/progress.svg]
   ```

   `diff.py` eindigt met code 0 als het hele bestand byte-identiek is, anders 1 (bruikbaar in CI).

## tools/diff.py

**Bestand en secties.** sha256 van het hele bestand, van de PE-headers (alles vóór de eerste
sectie) en van de ruwe bytes van elke sectie (`CODE`, `DATA`, `BSS`, `.idata`, `.tls`,
`.rdata`, `.reloc`, `.rsrc`).

**Routines koppelen.**
* Origineel: `symbols/ros-1.1.tsv` (`adres soort unit naam`; soort `f` = routine).
* Herbouw: het gedetailleerde map van `dcc32 -GD`, sectie *Publics by Value*, regels als
  ` 0001:00001234       Unit.Routine`. Het segmentnummer wordt via de segmenttabel bovenaan het
  map (anders standaard 1 = CODE, 2 = DATA, 3 = BSS, 4 = .tls) naar de PE-sectie met dezelfde naam
  vertaald; het adres is dan imagebase + RVA van die sectie + offset. Unitbereiken komen uit
  *Detailed map of segments* (`C=CODE … M=Unit`).
* Namen worden genormaliseerd tot `unit.naam` in kleine letters (een unitvoorvoegsel in de
  tsv-naam vervalt). Dubbele namen (overloads) worden in adresvolgorde gekoppeld; wat overblijft,
  wordt op naam zonder unit gekoppeld als die aan beide kanten uniek is.
* Wat dan nog niet gekoppeld is (bijvoorbeeld geneste routines, als het map die niet noemt),
  wordt **op positie** gekoppeld: ten opzichte van de eerstvolgende gekoppelde routine (geneste
  routines staan vlak vóór hun ouder), mits het resultaat tussen de buren valt. Routines die
  alleen in het map staan, worden op dezelfde manier in het origineel geplaatst. Zulke regels
  krijgen `[positie]` of `[alleen-build]`.
* Zonder `--map` wordt de tsv voor beide kanten gebruikt. Dat is alleen zinvol als de herbouw
  dezelfde indeling heeft (een gepatchte kopie, of een build die al bijna matcht).

**Bereik van een routine.** Van het beginadres tot de volgende routine- of unitgrens in hetzelfde
bestand. De stringliterals, float-constanten en RTTI/VMT's die de compiler achter een routine
neerlegt, horen er dus bij; bytes vóór de eerste routine van een unit vormen een eigen item
`<Unit>.(kop)`. De grenzen zijn aan beide kanten dezelfde verzameling (gekoppelde routines plus
de op positie geplaatste), zodat een routine die aan één kant onbekend is niet aan één kant een
bereik afsnijdt.

**Normalisatie.** Beide kanten worden met capstone instructie voor instructie gedecodeerd, behalve
in herkende datablokken (stringliterals: uitgelijnd `FFFFFFFF`+lengte+tekst+NUL; VMT-structuren
inclusief de RTTI ervoor, via `tools/delphi.py`), die byte voor byte worden vergeleken.
* Elke dword onder een relocatie uit de `.reloc`-tabel van dat bestand wordt vervangen door zijn
  **symbolische doel**: het dichtstbijzijnde voorafgaande *gedeelde* anker plus afstand. Ankers
  zijn gekoppelde routines, datasymbolen die in beide symbooltabellen voorkomen (eerst op
  volledige naam, dan op unieke kale naam) en VMT's per klassenaam (in beide bestanden gezocht).
* Relatieve `call`/`jmp`/`Jcc`/`jmp short` naar een doel buiten de routine worden net zo
  vergeleken; binnen de routine blijven de ruwe bytes staan (die zijn positie-onafhankelijk).
* Een doel binnen de eigen routine (try/except-handlers, `case`-sprongtabellen) telt als afstand
  vanaf het begin van de routine.
* Een doel zonder gedeeld anker telt in DATA/BSS/.idata als sectie + afstand en wordt in CODE
  gemaskeerd.

Zo maakt één verschoven routine alleen zichzelf (en wat er echt anders is) `verschilt`, niet al
haar aanroepers.

**Uitvoer.** Per routine `gelijk`, `verschilt (eerste verschil op +0xNN)`, `ontbreekt` (alleen in
het origineel, niet te plaatsen) of `extra` (alleen in de herbouw). Standaard alleen de
projectunits; `--alles` toont ook RTL/VCL. `-v` drukt bij een verschil de instructies op die plek
van beide kanten af. De samenvatting telt project en bibliotheek apart. `--json` schrijft
secties, alle routines en de samenvatting.

**Projectunits** zijn de units uit `symbols/units-1.1.json` die geen bibliotheekunit zijn en ofwel
een naam hebben ofwel meer bevatten dan een init-/finalisatiestub (> 112 bytes, dezelfde grens als
`tools/ghidra/analyze.sh`). Dat zijn er 33: de 32 units van `src/game` plus `ddraw` (alleen een
stub). De naamloze stub-units (`Unit13` … `Unit73`) tellen als bibliotheek.

## tools/progress.py

Draait de vergelijking van `diff.py` en telt per projectunit (in adresvolgorde) de bytes van de
items die `gelijk` zijn, gedeeld door de grootte van de unit in `units-1.1.json`. Omdat de items
(routines met hun literals, plus de kop) de unit precies bedekken, is 100% ook echt de hele unit.
`--json` schrijft per unit en totaal `bytes`, `gelijk_bytes`, `routines`, `gelijk_routines` en
`procent`; `--badge` schrijft een SVG-badge "matching | NN.N%" in shields-stijl.

## tools/maak-stubs.py: bootstrap met asm-blokken

```sh
nix develop --command python3 tools/maak-stubs.py orig/game-1.1/ROS.exe build/stubs [--unit uTrein] [--ruw]
```

Schrijft voor elke projectunit `build/stubs/<Unit>.pas` (CRLF, Windows-1252). De uitvoermap
**moet** onder `build/` liggen; het gereedschap weigert andere plekken, omdat de uitvoer
originele codebytes bevat.

* Elke routine uit de tsv wordt `procedure <Klasse>_<Methode>; assembler; asm … end;` met een
  kop `{ @ADRES Unit.Klasse.Methode (n bytes) }`. Alle routines staan ook in de interface, zodat
  andere stub-units ze kunnen gebruiken; de benodigde units staan in een `uses` in de
  implementatie (kringverwijzingen zijn daar toegestaan).
* Het blok bevat de bytes van de routine tot de volgende routine of het volgende stuk
  compilerdata, **inclusief** de stringliterals erachter. RTTI, VMT's en de kop van de unit (data
  vóór de eerste routine) worden niet uitgegeven; die komen uit de type- en constdeclaraties en
  staan alleen als commentaar `{ niet uitgegeven: … }` in de unit.
* Relocaties worden `dd`-verwijzingen: `@@Lxxxx` (lokaal label, xxxx = afstand in het blok),
  `TTrein_Create` / `uTool.TPos_Create` (projectroutine), `System.@LStrClr` (bibliotheek),
  `uTrein.RechtA + $4` (benoemde global), `VMT_TPos - $4C` (VMT-kop), of bij geen bruikbare naam
  `<Unit>_<ADRES>` / `DATA_<ADRES>` met `{ niet herleidbaar: … }`.
* `call rel32` en `jmp rel32` naar een benoemde routine buiten het blok worden `call X` / `jmp X`,
  zodat ze blijven kloppen als er iets verschuift. Andere relatieve sprongen blijven `db`.
* **RET.** Delphi zet na elk `asm … end` zelf een `RET` en vult daarna uit tot 4 bytes
  (`90`, `8B C0`, `8D 40 00`; precies de opvulling die in ROS.exe voorkomt). Standaard laat
  maak-stubs daarom een afsluitend `C3` + opvulling weg en noteert dat als commentaar. Blokken die
  zo niet eindigen (`RET n`, literals of een sprong aan het eind) worden volledig uitgegeven en
  krijgen `{ LET OP: … }`: daar zou de extra RET van de compiler de rest verschuiven. `--ruw` laat
  nooit iets weg. Op ROS.exe: 732 routines, waarvan 483 zonder `LET OP`.

Stand van de stubs (ROS.exe v1.1): 33 units, 134 024 bytes in asm-blokken, 4 201 `call`, 209 `jmp`,
1 385 niet-lokale `dd`, waarvan 226 niet herleidbaar: 123 naar data in de kop van een unit
(literals, RTTI-verwijzingen), 89 in de init-tabel van `Ros` (die ook naar naamloze
bibliotheekunits wijst) en een handvol naar RTTI in System/SysUtils.

**Wat er nog met de hand moet** (pas te verifiëren met dcc32):
* Methoden zijn losse procedures. Voor een echte build moeten ze in de klassedeclaraties uit
  `src/game` komen (bijv. `procedure TTrein.Create; assembler;`), anders kloppen VMT's en
  published-methodetabellen niet. `Initialization`/`Finalization` horen in de
  `initialization`-/`finalization`-sectie (de compiler maakt het raamwerk zelf).
* Routines met stackparameters eindigen op `RET n`; als de stub met de echte parameterlijst
  wordt gedeclareerd, maakt de compiler zelf een stackframe. Die blokken (`LET OP`) moeten eerst
  door Pascal vervangen worden of handmatig worden ingekort.
* `VMT_<Klasse>` moet de vorm krijgen waarin BASM een klasse-VMT accepteert, en
  `<Unit>_<ADRES>`-labels moeten aan een declaratie gekoppeld worden.
* Of BASM `jmp X` naar een andere procedure altijd als `E9 rel32` codeert (en niet als korte
  sprong), moet met dcc32 worden nagegaan.

## tools/maak-testmap.py

Er bestaat geen echt `.map` van het origineel. Dit gereedschap schrijft er een in het formaat van
een Delphi 5-map (segmenttabel, *Detailed map of segments* met één CODE-regel per unit,
*Publics by Name*, *Publics by Value*, startpunt) uit de tsv, zodat de map-route van diff.py en
progress.py te testen is. `--zonder-genest` laat geneste routines weg en `--weglaten N` elke N-de
projectroutine, om de koppeling op positie te testen.

> Het precieze formaat van een Delphi 5-map is uit het hoofd nagebouwd (met `Unit.Naam` in de
> publics). Controleer het met het eerste echte `ROS.map` en pas `lees_map` in `tools/diff.py`
> aan als het afwijkt.

## Wat is getest, en hoe

`nix develop --command python3 tools/test_matchpipeline.py` (15 tests, ~80 s; zonder
`orig/game-1.1/ROS.exe` worden de 13 tests die het nodig hebben overgeslagen). Tijdelijke
bestanden komen in `build/matchtest/`.

| Test | Resultaat |
|---|---|
| diff: origineel tegen zichzelf | alle 3 939 items (762 project, 3 177 bibliotheek) `gelijk`, alle secties gelijk, afsluitcode 0 |
| diff: kopie met 1 byte veranderd in `TTrein.Step` (+0x11) en `TCell.Create` (+0x08) | precies die twee `verschilt`, op +0x11 en +0x8; alleen `CODE` en het bestand verschillen; afsluitcode 1 |
| diff: kopie waarin één relocatie in `TTrein.Create` naar een andere global wijst | alleen `TTrein.Create` verschilt |
| diff via gegenereerd map (origineel tegen zichzelf) | alles `gelijk`, alles op naam gekoppeld |
| diff via map zonder geneste routines en zonder elke 7e projectroutine | alles `gelijk`; > 50 routines op positie gekoppeld |
| diff via dat map tegen de gepatchte kopie | precies de twee gepatchte routines |
| synthetisch beeld waarin routine G 16 bytes verschuift | aanroeper F (andere `call`-bytes, zelfde doel) `gelijk`; alleen de gegroeide H `verschilt` |
| synthetisch: F roept een andere routine aan | F `verschilt` op +0x0 |
| progress: origineel tegen zichzelf | 33 units, 153 020 / 153 020 bytes, 100,0%; JSON en badge |
| progress: gepatcht, via het map met gaten | alleen `uTrein` en `Uworld` < 100%, precies minus de grootte van de twee routines |
| maak-stubs: alle 33 units opnieuw assembleren | eigen mini-assembler (db/dd/call/jmp/labels; namen terug naar adressen via de tsv): alle 732 blokken byte-gelijk aan het origineel; de weggelaten staart is altijd `C3` + Delphi-opvulling |
| maak-stubs `--ruw` | idem, zonder weggelaten staart |
| maak-stubs CLI | schrijft alleen de gevraagde units; weigert een uitvoermap buiten `build/` |
| FPC-syntaxis | `uLog` en `uTrein` compileren met FPC 3.2.2 (`{$mode delphi}{$asmmode intel}`) nadat verwijzingen naar andere units door `0` zijn vervangen. Alleen de x86_64-compiler is beschikbaar (`fpc -i` noemt geen i386-target), dus dit toetst de syntaxis van `db`/`dd`/labels/`call`, niet de i386-codering |

`tools/bouw-delphi.sh` is **nooit echt gedraaid** (geen dcc32). Getest is: de foutmelding zonder
`toolchain/` (afsluitcode 2), en met een nep-toolchain en `--droog` het inlezen van de schakelaars
uit `toolchain/schakelaars.cfg` en uit `docs/SCHAKELAARS.md` (het `dcc32`-codeblok) en het
samengestelde `dcc32`-commando.

## Beperkingen

* Het map-formaat, en of `dcc32 -GD` geneste routines en RTTI-symbolen in de publics zet, is
  aangenomen; de koppeling op positie vangt ontbrekende namen op.
* Datablokken worden alleen herkend als stringliteral of VMT-structuur. RTTI van records/enums
  zonder VMT wordt gedecodeerd alsof het code is; dat geeft pas een vals verschil als zo'n blok
  een `E8`/`E9`-achtig patroon bevat én de routine verschoven is.
* Datanamen in de tsv komen grotendeels uit de IDR-kennisbank (`PTR_…`) en zullen niet altijd
  gelijk zijn aan de namen in een echt map; dan wordt DATA/BSS op sectie + afstand vergeleken.
  Zolang de data-indeling nog niet matcht, kan dat verschillen in veel routines tegelijk geven;
  `secties` in de uitvoer laat zien of DATA/BSS zelf al gelijk zijn.

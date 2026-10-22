# Virtueel Zoetermeer: plan voor een exacte decompilatie

## Doelen

1. **Exacte decompilatie.** Object Pascal-broncode die, gebouwd met de oorspronkelijke compiler, een uitvoerbaar bestand oplevert dat byte-voor-byte gelijk is aan het uitgeleverde `ROS.exe`.
2. **Native port.** Dezelfde broncode, gebouwd met Free Pascal, draait native op Apple Silicon macOS (aarch64-darwin).
3. **Webport.** Dezelfde broncode, gebouwd voor WebAssembly, draait in een browser.

Doel 1 komt eerst. Het levert broncode op die door de bouwwijze getrouw is. Doelen 2 en 3 zijn een portabiliteitslaag bovenop die broncode, en ze mogen de exacte build nooit breken.

## Beslissingen (bevestigd 2026-10-22)

- Het onderstaande plan is bevestigd zoals het is, met één uitzondering.
- **We hebben geen Delphi 5-compiler.** Byte-matching van de projectunits vereist Borlands exacte dcc32. Tot we die hebben (een legaal tweedehands gekochte Delphi 5-licentie is de realistische route) werken we in **equivalentiemodus**:
  - **Orakel.** Het originele `ROS.exe` blijft de referentie. Byte-matching blijft het doel voor de data die niet van de compiler afhangt: VMT/RTTI-lay-out, DFM-resources, stringtabellen en het parsen van `Objecten.csv`.
  - **Compiler.** De gedecompileerde Pascal wordt gebouwd met **Free Pascal** in `{$mode delphi}`, eerst voor `i386-win32`, onder Wine gedraaid. Dit is toch dezelfde compiler die we voor de ports nodig hebben.
  - **Correctheid.** Die wordt bewezen met **differentiële tests**. We draaien het origineel en de herbouw onder Wine met dezelfde gescripte invoer, plus een vaste timer- en RNG-seed, en vergelijken speltoestand-dumps (geld, inwoners, huizenprijzen, overlast-/reistijdscores) en screenshots per frame.
  - **Per functie.** Routines worden gecontroleerd door ze na te lopen tegen Ghidra/IDR-uitvoer. Bladroutines worden ook met unittests tegen het origineel getoetst. Mogelijke aanpak: de originele code binnen een emulator (unicorn) aanroepen met dezelfde invoer.
  - **Later.** Als Delphi 5 opduikt, wordt de matching-pipeline van Fase 2 aangezet en wordt de broncode aangescherpt tot hij byte-identiek is.
- **UI-port:** een mini-VCL-shim die in een software-framebuffer tekent. Die gebruikt SDL3 op macOS en `<canvas>` in het web.

## Waar we mee te maken hebben (bevindingen tot nu toe)

`Virtueel Zoetermeer.zip` bevat:

| Bestand | Wat het is |
|---|---|
| `installatie.exe` | NSIS-installatieprogramma, in 2021 opnieuw verpakt. Het pakt de bestanden hieronder uit. |
| `ROS.exe` | **Het spel.** Delphi 5 PE32 GUI-uitvoerbaar bestand, bestandsdatum 2003-07-14, 3,7 MB. sha256 `5b76da9044bddcd14597e80b60e18c60bccad47159e5ab03c4a07429b747f041` |
| `Stub.exe` | Delphi 7-launcher uit 2011. Die toont een melding "meer spellen op zoetermeer.nl/games". sha256 `7f946e1e…0001` |
| `update.exe` | 2003 Wise Installer, een 16-bit NE-stub. Die kan een oudere of andere build van het spel bevatten. |
| `images/8bits/*.bmp` (620 bestanden), `*.Ini`, `Objecten.csv`, `wijken.dat` | Spelgegevens: 8-bit sprites, niveauregels (Nederlands), objecttabel, wijkkaart. |
| `Lespakket Ben jij een goede burgemeester.pdf` | 2015 lespakket voor in de klas (alleen documentatie). |

### ROS.exe in detail

- **Compiler: Borland Delphi 5.** Bewijs:
  - Linker 2.25 en de vaste Delphi-tijdstempel `1992-06-20`.
  - `CODE/DATA/BSS`-secties.
  - "Portions Copyright (c) 1983,99 Borland".
  - De units `TFrame` en `DsgnIntf` zijn aanwezig.
  - Er is geen `Variants`-, `Types`- of `RTLConsts`-unit, dus het dateert van vóór Delphi 6.
- **Lay-out:**
  - `CODE` is 0x87B84 bytes (ongeveer 543 KB).
  - `DATA` is 0x174C bytes.
  - `.rsrc` is ongeveer 3,1 MB, vooral 5 DFM-formulieren met ingesloten bitmaps: `TFRMMAIN` (2,6 MB), `TFRMBLACK`, `TFRMREPORT`, `TFRMSELECTDIR`, `TFORMDEBUGSHOW`.
- **Imports:** kernel32, user32, gdi32, advapi32, ole32, oleaut32, comctl32, shell32, comdlg32, winmm, **DDRAW** (DirectDraw-weergave).
- **Units, in linkvolgorde uit `PACKAGEINFO`.** Er zijn 88 units in totaal. Borland-RTL/VCL-units zijn hier weggelaten. De ~40 projectunits zijn:
  - **Spel:** `Ros` (programma), `Fmain`, `fReport`, `fBack`, `Uworld`, `Uview`, `Usett`, `Uconst`, `uAutos`, `uTrein`, `Uctrl`.
  - **Eigen sprite-/GUI-engine:**
    - `SprCtrl`, `SprBmp`, `Sprframe`, `Sprsqlst`, `Sprfrmed`, `Sprbehav`
    - `uSprite`, `uSpritebox`, `uPixie`, `uGoblin`, `uSurface`
    - `uSequence`, `uTransition`, `uTextBalloon`, `uTiming`, `uMessage`, `uResizeScreen`
    - `uQuickDirectX`, plus de `ddraw`-headerunit
  - **Hulpprogramma's / overig:** `uTool`, `uString`, `uLog`, `uDebug`, `fShow`, `Seldir`, `ExtLbox`, `cEditCtr`.
- **RTTI.** Delphi-RTTI, VMT's en de DFM's geven ons klassennamen, published velden, namen van event-handlers en formulierlay-outs gratis. Alleen privé- en lokale namen moeten worden bedacht.

### Wat "matchen" betekent voor Delphi

- We schrijven broncode alleen voor de **projectunits**.
- De RTL/VCL-code (`System`, `SysUtils`, `Classes`, `Forms`, …) wordt gelinkt uit Borlands vooraf gecompileerde Delphi 5 `.dcu`-bestanden, precies zoals het origineel. Dat klopt alleen als we **dezelfde Delphi 5-build** gebruiken (basis of Update Pack 1). Een van de eerste taken is vaststellen welke, door RTL-code tegen elke kandidaat te diffen.
- De compiler en linker van Delphi zijn deterministisch. Code wordt unit voor unit in een vaste volgorde neergelegd, en routines binnen een unit volgen de implementatievolgorde. We kunnen dus één unit tegelijk matchen en de voortgang continu verifiëren.

## Fase 0: Projectopzet

- [x] `flake.nix` dev-shell: 7z/unzip, binutils, icoutils, rizin, Ghidra, Wine (wow64), Python met pefile/capstone/lief.
- [x] git-repository. De originele binaries staan in `.gitignore` en worden nooit gecommit.
- [x] `orig/`: een script dat het zip-bestand in `orig/` uitpakt en de sha256-sommen hierboven verifieert. *Gedaan: `tools/extract-orig.sh` (ook de v1.1-`ROS.exe` uit `update.exe`), `orig.sha256`.*
- [ ] *(Uitgesteld: niet beschikbaar.)* Delphi 5 verkrijgen (dcc32.exe plus `lib/*.dcu`, `*.res`). Het is eigendomsrecht, dus het zou in een door git genegeerde `toolchain/` komen. Tot die er is, volgen we de equivalentiemodus (zie Beslissingen).
- [x] Free Pascal (met de i386-win32 cross-target) en unicorn aan de flake toevoegen. Controleren dat een FPC `{$mode delphi}` hello world zonder VCL bouwt en onder Wine draait. *Gedaan: FPC 3.2.2 (native) en unicorn in de flake; een i386-win32-build bleek niet nodig, de port draait native (fase 4).*
- [x] Harnas voor differentiële tests: het originele `ROS.exe` onder Wine starten met invoerinjectie, en de toestand dumpen via een kleine hook-DLL of geheugenlezingen. *Gedaan: `tools/orig_probe.py` leest het geheugen via `/proc/<pid>/mem` en schrijft met `process_vm_writev`; invoer via xdotool. Zie `docs/DIFFTEST.md`.*
- [x] `update.exe` (Wise) uitpakken en elk spelbinary erin vergelijken met `ROS.exe`. *Gedaan: de upgrade bevat `ROS.exe` v1.1; dat is het doel van de decompilatie.*

## Fase 1: Analyse en herstel van symbolen

- [x] **IDR (Interactive Delphi Reconstructor)** onder Wine draaien met zijn Delphi 5-kennisbank. Die herkent: *Gedaan zonder IDR-GUI: een eigen matcher gebruikt de Delphi 5-kennisbank van IDR (`tools/idrkb.py`, `tools/kbmatch.py`).*
  - RTL/VCL-routines
  - klasse-VMT's, RTTI en published methoden
  - het begin van de code van elke unit
- [x] De resultaten exporteren naar een symboolkaart: `symbols/ros.sym` (adres, grootte, unit, naam). *Gedaan: `symbols/ros-1.1.tsv`.*
- [x] De symbolen importeren in Ghidra (een script in `tools/`) voor decompilatie. *Gedaan: `tools/ghidra/`, `tools/refresh.sh`; ook klassenstructuren.*
- [x] `tools/units.py` bouwen. Die levert het adresbereik van elke projectunit uit de IDR-kaart en de PACKAGEINFO-volgorde. Dit meet ook hoeveel code van het project zelf is en hoeveel van Borland (verwacht: in de orde van 100–200 KB). *Gedaan: 34 projectunits, ~148 KB code.*
- [ ] De exacte compilerbuild en schakelaars vastleggen. Kandidaten:
  - Delphi 5 basis of Update Pack 1
  - `$O` optimalisatie, `$W` stackframes, `$R/$Q` bereik-/overloopcontroles, `$A` uitlijning, `$D/$L` debuginformatie (heeft geen invloed op het exe, wel op het `.map`)
  - `$I` I/O-controles, `$H` lange strings

  We bevestigen deze door probe-units te compileren en codepatronen en de RTL-bytes te vergelijken.
- [x] De binaire DFM-resources omzetten naar tekstuele `.dfm` om ze te kunnen lezen. We bewaren de originele binaire formulierstromen als buildinvoer, zodat ze exact overeenkomen. *Gedaan: `tools/dfm.py`; de port leest de formulieren uit `ROS.exe`.*
- [x] De `ddraw`-headerunit identificeren. Het is waarschijnlijk een publieke DirectX-headervertaling (Erik Unger / JEDI / Hori). Als we die vinden, gebruiken we de originele broncode in plaats van te decompileren. *Opgelost: alleen declaraties waren nodig; de compat-laag levert `ddraw`.*
- [x] Nagaan of `ExtLbox`, `Seldir` en `cEditCtr` publiek beschikbare voorbeeld- of third-partyunits zijn. *Opgelost: weggelinkt door de smart linker; alleen `cEditCtr` heeft code en is gedecompileerd.*

## Fase 2: Build- en verificatiepipeline

Repository-indeling:

```
src/            projectbestanden .pas/.dpr/.dfm (gedecompileerd)
src/stubs/      nog niet gedecompileerde units (zie hieronder)
res/            .res-invoer: pictogram, versie-informatie, bitmaps, binaire DFM's
tools/          python: uitpakken, symboolkaart, diff, voortgang, Ghidra-scripts
symbols/        ros.sym (originele adressen → namen)
orig/           (genegeerd) originele bestanden
build/          (genegeerd) uitvoer
```

- [ ] `make` (of `just`) draait `wine dcc32 -B -GD src/Ros.dpr` met de vastgepinde schakelaars. Dat levert `build/ROS.exe` en een gedetailleerd `.map` op.
- [ ] `tools/diff.py` vergelijkt de sha256 van het hele bestand en sectie voor sectie. Het vergelijkt ook elke functie: het koppelt routines via `build/ROS.map` en `symbols/ros.sym`, en disassembleert beide met capstone. Verplaatste operanden worden genormaliseerd, zodat één verkeerde functie niet overal adresruis veroorzaakt.
- [ ] `tools/progress.py` meldt het % van de bytes van projectunits dat matcht, per unit, en schrijft een voortgangsbadge of JSON.
- [ ] **Bootstrap-strategie.** We kunnen geen werkend exe linken zolang niet elke unit bestaat, dus:
  1. Elke nog niet gedecompileerde routine begint als een `asm … end`-blok dat de originele bytes bevat (`db`-directives). De ingebouwde assembler van Delphi accepteert dat.
  2. Relocaties worden symbolische verwijzingen, die uit `.reloc` worden hersteld.
  3. Dit levert vanaf dag één een matchende build op.
  4. Routines worden één voor één door echte Pascal vervangen, en de build moet matchend blijven.

  Dit is de standaardaanpak "split + incrementele decompilatie", aangepast voor Delphi.
- [ ] CI: een GitHub Actions- of Nix-check die bouwt en de hash controleert. Dit hangt af van de beschikbaarheid van de toolchain voor CI, wat door de Delphi-licentie misschien alleen lokaal kan.

## Fase 3: Decompileren, unit voor unit

Volgorde: bladeren eerst, zodat latere units op gedecompileerde typen kunnen steunen.

1. `Uconst`, `uString`, `uTool`, `uLog`, `uDebug`, `uTiming`. Dit zijn kleine units en ze leren ons de idiomen van de compiler.
2. Enginekern: `uQuickDirectX`, `uSurface`, `SprBmp`, `uSprite`, `uPixie`, `uGoblin`, `uSpritebox`, `Sprframe`, `Sprsqlst`, `Sprbehav`, `SprCtrl`, `uSequence`, `uTransition`, `uTextBalloon`, `uMessage`, `uResizeScreen`.
3. Spelmodel: `Uworld`, `Usett`, `uAutos`, `uTrein`, `Uview`, `Uctrl`.
4. Formulieren: `Fmain`, `fBack`, `fReport`, `fShow`, `Seldir`, en de editor-units (`Sprfrmed`, `cEditCtr`, `ExtLbox`).

Regels:
- Elke commit houdt `build/ROS.exe` byte-identiek.
- Match de declaratievolgorde van klassen, velden en virtuele methoden exact, omdat die de VMT- en RTTI-lay-out bepaalt.
- Gebruik de RTTI- en DFM-namen waar die bestaan. Bedachte namen volgen de Delphi-conventies (`F`-voorvoegsel voor velden, `T` voor typen).

Klaar wanneer er geen `asm db`-blobs meer in de projectunits zitten en de hash nog steeds klopt.

**Stand (equivalentiemodus):** alle routines van de 34 projectunits hebben Pascal-broncode met adresmarkering (`tools/coverage.py`: 100%); de differentiële tests `smoke`, `bouwen` en de eerste stappen van `level2-rapport` geven dezelfde toestand als het origineel.

## Fase 4: Portable build met Free Pascal (Apple Silicon macOS)

Free Pascal (FPC) compileert code in de Delphi-dialect (`{$mode delphi}`) en richt zich op zowel **aarch64-darwin** als **wasm32**. Dat maakt het de natuurlijke route naar beide ports, zonder het spel in een andere taal te herschrijven.

Portabiliteitskwesties om op te lossen:
- **Weergave.** `uQuickDirectX` is DirectDraw over 8-bit gepalettiseerde oppervlakken. Het wordt vervangen door een backend-onafhankelijke software-framebuffer (palet plus 8-bit oppervlakken, blits in Pascal), gepresenteerd door een kleine platformlaag.
- **VCL.** Het spel gebruikt Forms, StdCtrls, ExtCtrls, Grids, Dialogs en Buttons, maar het meeste van de UI is bitmapgebaseerd (TFRMMAIN bevat 2,6 MB aan afbeeldingen). Aanbevolen aanpak: een **mini-VCL-shim**. Die herimplementeert alleen de klassen en eigenschappen die daadwerkelijk gebruikt worden, met dezelfde namen, tekent ze in de framebuffer, en laadt de originele DFM-streams met een kleine DFM-lezer. De spelcode blijft dan vrijwel ongewijzigd. Alternatief: Lazarus LCL, dat Cocoa ondersteunt maar geen bruikbaar wasm-doel heeft.
- **Win32-API-aanroepen** (register, INI-bestanden, `timeGetTime`, `ShellExecute`, berichtvensters) komen achter `uPlatform` te staan.
- **Gegevensbestanden.** Paden worden hoofdlettergevoelig en de INI-bestanden zijn Windows-1252. Behandel beide expliciet.
- **Pascal-semantiek die tussen Delphi 5 en FPC verschilt.** Dit zijn 32-bits `Integer`/pointergrootte-aannames, `string` = AnsiString, recordpakking en setgroottes. Controleer die op 64-bit aarch64.

Stappen:
- [x] FPC (en eventueel SDL3) aan de flake toevoegen. Een cross-target `nix build .#ros-macos` (aarch64-darwin) maken. *Gedaan: `nix build .#zoetermeer` voor Linux en macOS (ook aarch64-darwin); op macOS zelf nog niet getest.*
- [x] `{$IFDEF FPC}` / `{$IFDEF PORTABLE}`-naden. De Delphi 5-matchbuild moet ongewijzigd blijven compileren. *Gedaan: naden gemarkeerd met `PORT:`.*
- [x] macOS-platformlaag: SDL3 (venster, invoer, audio via een winmm-vervanging, timer), of een native Cocoa-laag als dat de voorkeur heeft. *Gedaan: SDL3-backend; geluid is stil.*
- [x] Verpakken als `.app`-bundel met de gegevensbestanden. *Gedaan in `nix/zoetermeer.nix`.*

## Fase 5: WebAssembly-port

- [x] Bouwen met FPC's `wasm32-wasi`-target (of `wasm32-embedded`) met een dunne JS-host die voorziet in: *Gedaan: FPC trunk wasm32-wasip1 (`nix/fpc-wasm.nix`), Asyncify, `web/zoetermeer.js`.*
  - een framebuffer-blit naar `<canvas>`
  - toetsenbord- en muisevents
  - een frametimer (hoofdlus aangestuurd door requestAnimationFrame, dus de VCL-achtige berichtenlus moet herintreedbaar/callback-gestuurd worden)
  - een virtueel bestandssysteem vooraf gevuld met de BMP/INI/CSV-gegevens
  - `localStorage` voor highscores en instellingen
- [x] Terugvaloptie als FPC's wasm-target te onvolwassen is: SDL3 via Emscripten met een kleine C-brug naar de door FPC gecompileerde spelkern. Beslissen na Fase 4, op basis van hoe de platformlaag uitpakte. *Niet nodig gebleken.*
- [ ] Uitrollen als statische site. *`nix build .#web` levert de site (met de spelbestanden van archive.org); nog niet gepubliceerd.*

## Fase 6: Verificatie door een volledige playthrough (Haiku-agent)

Naast de differentiële tests (`docs/DIFFTEST.md`), die korte scenario's byte voor byte met het
origineel vergelijken, speelt een Haiku-agent het hele spel uit om te controleren dat de
herbouw nergens crasht of vastloopt.

- [x] Interactieve bediening van het draaiende spel voor een agent: `tools/speel.py` start de
  portable build (`RosTest`) headless en geeft subcommando's voor één stap tegelijk: `klik x y`,
  `toets naam`, `wacht ms`, `foto` (screenshot om te bekijken), `toestand` (state dump: level,
  geld, score, wijken) en `stop`. ZMHarness leest daarvoor commando's live uit een
  controlebestand in plaats van uit een vooraf geschreven script.
- [x] Crash- en hangdetectie: het proces loopt nog, er komen frames, er zijn geen exceptions in
  de log (`ZM_DEBUG`). Bij een crash worden het commandolog en de laatste screenshots bewaard,
  zodat het precies na te spelen is als `.zms`-script.
- [ ] Een Haiku-agent (model `haiku`) speelt alle levels door: wijken openen, wegen, spoor, *Eerste ronde: level 2 gehaald; een crash in het rapport (compat) gevonden en opgelost; vervolgronde nodig.*
  huizen, kantoren, voorzieningen en stations bouwen, rondes afsluiten, rapporten lezen, de stad
  bewaren en weer openen, en het spel afsluiten. Hij houdt een logboek bij en rapporteert elke
  crash, hang of zichtbare fout met het commandolog.
- [x] Gevonden fouten worden nagespeeld tegen het origineel onder Wine (zelfde script) om te *Gedaan: `tests/scripts/level2-rapport.zms`.*
  bepalen of het een fout van de herbouw is of oorspronkelijk gedrag.
  - Crash in het rapport van level 2: fout van compat, opgelost (`level2-rapport.zms`).
  - "Volgende ronde" reageerde soms niet: een tikteller >= 2^31 maakt `DrawAutos` extreem traag
    (fout van het origineel); de port gebruikte FPC's GetTickCount (uptime). Opgelost met
    `ZMKlok`; het origineel draait in een tijdnaamruimte (`volgende-ronde.zms`).
  - Huizen verdwijnen na het slopen van een wegstuk: oorspronkelijk gedrag. Gebouwen die niet
    aan de weg liggen knipperen (500 ms) zolang de reistijd -1 is, en "Volgende ronde" blijft weg
    (`sloop-weg.zms`, gelijk aan het origineel, ook de foto's). In het logboek bleef het gat
    open: de klik die het moest dichten plaatste Laagbouw.
- [ ] Hetzelfde voor de webversie (`tools/test-web.py`), minstens tot en met level 2.

## Buiten scope (voorlopig)

- `Stub.exe` (een Delphi 7-launcher uit 2011, triviaal) en `update.exe` (tenzij die een andere spelbuild bevat die het waard is om te matchen).
- Het distribueren van spelbestanden. De repository bevat alleen code en gereedschap; gebruikers leveren hun eigen kopie van de originele bestanden.

## Open vragen voor de gebruiker

1. Heb je een **Delphi 5**-installatie, en weet je welke editie of Update Pack? Byte-matching is zonder die onmogelijk.
2. Welke UI-aanpak voor de ports: de **mini-VCL-shim over SDL3 / canvas** (aanbevolen), of Lazarus LCL?
3. Is het doel alleen `ROS.exe` matchen, of moet `Stub.exe` ook binnen scope vallen?

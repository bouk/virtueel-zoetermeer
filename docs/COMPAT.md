# Compatibiliteitslaag (`src/compat/`)

De gedecompileerde spelunits in `src/game/` zijn geschreven tegen de Delphi 5 RTL/VCL,
Win32 en DirectDraw. `src/compat/` levert units met dezelfde namen en API, portable
geïmplementeerd, zodat de ongewijzigde spelbroncode met Free Pascal bouwt en draait op
Linux, macOS (aarch64-darwin, SDL3) en later WebAssembly. De eigen RTL van FPC levert
`System`, `SysUtils`, `Classes` (TReader/TWriter voor de DFM-streams), `Math`,
`Contnrs` en `TypInfo`; compat schaduwt die niet. `IniFiles` is de uitzondering: zie
"INI-bestanden" hieronder.

## Lagen

```
 spelunits (src/game)
   |  Delphi-API
 Windows Messages MMSystem ddraw | Graphics Controls Forms StdCtrls ExtCtrls Buttons
                                 | ComCtrls Dialogs FileCtrl Menus Grids ImgList
   |
 ZMWin    vensterbeheer + berichtenwachtrij + timers + invoer + tekenen   (portable)
 ZMGdi    software-GDI: DIBs, paletten, DC's, regio's, ROP-blits, tekst   (portable)
 ZMFonts  bitmapfonts (fonts/zmfontdata.inc, gegenereerd)                 (portable)
 ZMData   gegevensmap, PE-resources van ROS.exe, padresolutie             (portable, Unix/overig)
 ZMHandles handletabel (HWND/HDC/HBITMAP... zijn kleine gehele getallen)  (portable)
   |
 ZMPlatform   backendinterface (TZMBackend) + null-backend + PNG-schrijver
 sdl3/ZMSdl3Backend, sdl3/SDL3   SDL3-backend (dynamisch geladen libSDL3)
```

`ZMDraw` bevat de klassieke Windows 9x-tekenhulpen die de besturingselementen gebruiken.

### Platformgrens (`ZMPlatform.TZMBackend`)

Een backend opent één venster met het geëmuleerde scherm, presenteert een 32-bits XRGB-framebuffer,
levert invoerevents (muis in schermcoördinaten, Windows-VK-codes, Windows-1252-tekst), tijd (`KloktijdMs`,
`PrestatieTeller`), `Delay`, `WachtOpGebeurtenis(timeout)` en een cursorvorm. Niets anders raakt SDL aan. Een
browserbackend implementeert dezelfde klasse.

Het **enige blokkerende punt** is `ZMWin.ZMWachtOpBericht` (gebruikt door `WaitMessage`,
`GetMessage`, `Application.HandleMessage`/`Idle`, `ShowModal`, `MessageBox`, de bestandsdialogen).
Voor WebAssembly is dit de plek waar het programma de browser de beurt moet geven (Asyncify of
een equivalent); al het andere is niet-blokkerend.

### Scherm en vensters

Er is één geëmuleerd scherm, een 1024x768 32-bits bitmap (`ZMScherm`). Vensters op het hoogste niveau
(formulieren, berichtvensters, popups) worden erop geplaatst; kindvensters (TWinControls) binnen hun
ouders. Alle vensters tekenen **rechtstreeks in het scherm** via venster-DC's waarvan de zichtbare
regio het clientgebied van het venster is, min overlappende broers erboven en min zijn kindvensters
(WS_CLIPSIBLINGS | WS_CLIPCHILDREN-semantiek), zoals niet-gecomponeerd Windows. De sprite-engine van het
spel doet precies wat die op Windows deed: `GetDC(Handle)`, `BitBlt`, `ReleaseDC`. Verplaatsen/verbergen
van een venster ongeldig maakt wat het blootlegt; WM_PAINT en WM_TIMER worden gesynthetiseerd als de
wachtrij met geposte berichten leeg is; niet-clientframes (titelbalk, randen, clientranden) worden door
het vensterbeheer getekend in Win9x-stijl.
`ChangeDisplaySettings` en `IDirectDraw.SetDisplayMode` slagen zonder de schermgrootte te wijzigen;
`GetDeviceCaps(BITSPIXEL)` meldt 32 (ware kleur, geen paletapparaat).

### GDI

`ZMGdi` implementeert bitmaps van 1/4/8/16/24/32 bpp (rijen van boven naar beneden, `ScanLine[]` werkt),
kleurtabellen, logische paletten, DC's met een toestandsstapel, venster-/viewportoorsprong, kliprgio's
(rechthoeklijsten), kwasten (effen/arcering/patroon), pennen, lettertypen, `BitBlt`/`StretchBlt`/`PatBlt`
met **alle 256 ternaire ROP's** en de kleurconversieregels van Windows (mono naar kleur gebruikt de
tekst-/achtergrondkleur van de doel-DC, kleur naar mono vergelijkt met de achtergrondkleur van de bron-DC,
8-bit naar 8-bit met verschillende kleurtabellen mapt via RGB, ...), lijnen, rechthoeken, ellipsen,
veelhoeken, flood fill, `TextOut`/`ExtTextOut`/`DrawText`/`GetTextExtentPoint`/`GetTextMetrics`.

### Lettertypen

`tools/gen-fonts.py` rendert Liberation Sans/Serif/Mono (SIL OFL; metrische klonen van
Arial, Times New Roman, Courier New; pakket `liberation_ttf`) zonder anti-aliasing op een reeks
pixelgroottes naar `src/compat/fonts/zmfontdata.inc` (vastgelegd in git; opnieuw genereren met
`nix develop --command python tools/gen-fonts.py`). Lettertypekoppeling: Arial / MS Sans Serif
/ onbekend -> sans, Courier* -> mono, Times* -> serif, `System` -> een vet lettertype van 16 px waarvan de
breedtes exact overeenkomen met de DFM-labelgroottes van het origineel.

### VCL

`Controls`/`Forms` volgen de Delphi 5-structuur nauw (WndProc, berichtafhandelaars, `Perform`,
`PaintHandler`/`PaintControls`, `AlignControls`, KeyPreview, CM_DIALOGKEY voor standaard- en
annuleerknoppen, CM_MOUSEENTER/LEAVE, muisvastlegging, grafische besturingselementen worden door hun
ouder getekend, `TControlCanvas`-DC's worden bij idle vrijgegeven). Standaardbesturingselementen worden
getekend door Pascal-code (TButton, TBitBtn met standaardglyphs, TLabel, TEdit, TMemo met scrollbalk en
woordafbrekende `Lines` zoals het edit-control van Windows, TCheckBox, TRadioButton, TListBox,
TComboBox met vervolgkeuzelijst, TScrollBar, TGroupBox, TPanel, TImage, TPaintBox, TBevel,
TShape, TTimer, TTabControl (owner-draw, meerregelig), TPageControl, TProgressBar,
TStatusBar, TTrackBar, TStringGrid/TDrawGrid, TDirectoryListBox enz.). `MessageBox`,
`ShowMessage`, `MessageDlg`, `InputQuery` en `TOpenDialog`/`TSaveDialog` zijn modale formulieren
binnen het geëmuleerde scherm.

TMemo breekt regels af zoals de edit-control van Wine (`EDIT_BuildLineDefs_ML`): het
opmaakrechthoek is het clientgebied min de scrollbalk, 1 pixel per kant voor
WS_EX_CLIENTEDGE en voor TrueType-fonts een marge van een halve gemiddelde tekenbreedte;
een te brede regel krijgt een geschat breekpunt (breedte/opmaakbreedte, min 0,2 boven
1,2) en zoekt van daaruit naar links de eerste woordgrens die past. Daardoor zijn regels
vaak korter dan nodig; de originele schermen (intro- en leveltekst) laten precies die
afbrekingen zien, en het spel tekent de memoregels zelf (TBehavMemo).

### Formulieren uit ROS.exe

`TCustomForm.Create` laadt de RCDATA-resource met de naam van de formulierklasse (en zijn
voorouders, zoals `InitInheritedComponent`) **uit het ROS.exe van de gebruiker** (PE-resourcelezer in
`ZMData`) en streamt die met FPC's `TReader`. Onbekende eigenschappen worden overgeslagen (vermeld bij
`ZM_DEBUG=1`), ontbrekende event-handlers worden gemeld. Er staan geen spelgegevens in de repository;
`{$R *.dfm}` in de spelunits is alleen voor Delphi.

Anti-aliasing en breedtes, zoals Wine (de referentie) het doet:

* Per lettergrootte zijn er twee glyphsets: zwart-wit met de *mono*-gehinte advances
  (FreeType `TARGET_MONO`) en 17 grijsniveaus (GGO_GRAY4) met de normaal gehinte
  advances. Grijs wordt alleen gebruikt op doelen van meer dan 8 bpp, niet voor
  bitmapfonts (MS Sans Serif, System) en alleen waar de eigen `gasp`-tabel van het
  font grijs vraagt (Liberation Sans Regular: tot 8 en vanaf 18 ppem; Bold: altijd).
  `ZM_NO_AA=1` zet anti-aliasing uit.
* Tekstbreedtes (`GetTextExtentPoint`, `DrawText`) gebruiken altijd de normaal
  gehinte advances, ook als de glyphs zwart-wit getekend worden.
* tmAscent/tmDescent zijn usWinAscent/usWinDescent geschaald en afgerond.
* Grijsniveau = FreeType-dekking * 17 / 256 (naar beneden afgerond, zoals
  `get_bitmap_outline` in Wine); niveau 0 en 1 laten de pixel ongemoeid, 16 is de
  tekstkleur, daartussen mengt `ZMGdi.AACombineer` met de gammacurve van Wine
  (`dibdrv/primitives.c`). Hiermee zijn de teksten pixel-gelijk aan de referentie.

### Gegevensbestanden en paden

`ZMData` vindt de gegevensmap via `--data=<dir>`, `$ZM_DATA`, de huidige map of de map van het
uitvoerbare bestand, en ROS.exe via `--exe=<file>`, `$ZM_EXE` of de gegevensmap. Het spel bouwt paden als
`ExtractFilePath(ParamStr(0)) + '\'` + `images\8bits\x.bmp` en opent ze via de gewone RTL (`TIniFile`,
`AssignFile`, `FindFirst`, `TStrings.LoadFromFile`). Om dat op Unix ongewijzigd te laten werken:

* `Windows.ParamStr(0)` (schaduwt `System.ParamStr` in units die `Windows` gebruiken) geeft
  `<shadow>/ROS.exe` terug.
* De schaduwmap `$XDG_CACHE_HOME/zoetermeer/root-<hash>/` (overschrijven met `ZM_SHADOW`)
  bevat symlinks waarvan de *namen* de Windows-achtige relatieve paden van het spel zijn
  (`\ZoetermeerGame.ini`, `\images\8bits\Achterg.bmp`; backslashes zijn op Unix gewone
  bestandsnaamtekens). Bestanden in de root krijgen links in meerdere hoofdlettervarianten (het spel vraagt
  om `ZoetermeerGame.ini`, het bestand heet `ZoetermeerGame.Ini`); bestanden in submappen krijgen elk één
  link, zodat `FindFirst('<shadow>/\images\8bits\*.bmp')` elk bestand precies één keer teruggeeft (FPC's
  FindFirst somt `<shadow>/` op en haalt het `\...\`-voorvoegsel uit de namen).
  Ongeveer 660 links; bij de start in ~60 ms opgebouwd. Elk proces heeft een eigen schaduwmap
  (`root-<hash>/<pid>/`, opgeruimd bij afsluiten; mappen van beëindigde processen
  ruimt de volgende start op), zodat twee gelijktijdige runs elkaar niet storen.
* Het eigen bestandstoegang van compat (`TGraphic.LoadFromFile`, dialogen, `FileCtrl`) loopt via
  `ZMData.ZMOplosPad` (backslashes en hoofdlettergebruik worden opgelost tegen de echte boomstructuur).

**Schrijfbare overlay.** Het spel schrijft nooit in de datamap (bij `nix build
.#zoetermeer` is dat een alleen-lezen store-pad). `ZMData.ZMSchrijfPad` stuurt elke
schrijfactie op een bestand uit de data- of schaduwmap naar een map per gebruiker:
`$ZM_SAVE`, anders `$XDG_DATA_HOME/zoetermeer` (`~/.local/share/zoetermeer`), op macOS
`~/Library/Application Support/Virtueel Zoetermeer`. Een bestaand origineel wordt eerst
gekopieerd (copy-on-write). De schaduwlinks wijzen naar de overlaykopie zodra die bestaat
(ook bij een volgende start), en `ZMOplosPad` geeft voor een pad in de datamap de
overlaykopie terug: lezen geeft dus altijd de laatst geschreven versie. Via de overlay
lopen: INI-bestanden, `TGraphic.SaveToFile` en de opslaandialoog (`TSaveDialog` geeft
een pad in de overlay terug; open- en opslaandialoog beginnen daar als de game geen
andere map opgeeft, zoals op Windows de spelmap). De webversie heeft geen overlay (daar
bewaart `web/zoetermeer.js` geschreven bestanden in localStorage).

**INI-bestanden.** `src/compat/IniFiles.pas` schaduwt de unit van FPC (wiens TIniFile
bij elke wijziging het hele bestand herschrijft en commentaar en lege regels weggooit).
Zoals in Delphi 5 roept TIniFile voor alles `GetPrivateProfileString` /
`WritePrivateProfileString` aan; die zitten in `ZMProfile` en volgen Windows:
hoofdletterongevoelige namen, witruimte rond namen/waarden telt niet, aanhalingstekens
rond een waarde vallen weg, `;` is commentaar, afkappen van de buffer zoals Windows, en
schrijven gebeurt ter plekke: alleen de betreffende regel verandert (een nieuwe sleutel
komt na de laatste sleutel van zijn sectie, een nieuwe sectie achteraan), commentaar,
lege regels, volgorde en CRLF blijven. TMemIniFile werkt als in Delphi 5 in het geheugen.
Let op: de wasm-compiler zoekt de unitpaden van zijn fpc.cfg vóór `-Fu src/compat`, en
vindt dan de `IniFiles` van FPC; de webbuild moet de unit expliciet noemen
(`IniFiles in '../compat/IniFiles.pas'` in de uses van `RosWeb.dpr`).

Een schoner alternatief, als de spelunits FPC-specifieke naden mogen krijgen: laat `uString.AddPath`
en de `AppPath`-initialisatie in `uTool` `PathDelim` gebruiken; de schaduwmap heeft dan alleen nog de
hoofdletter-variant-links nodig.

## Omgevingsvariabelen

| Variabele | Betekenis |
|---|---|
| `ZM_DATA`, `--data=` | gegevensmap (images/, *.Ini, Objecten.csv, wijken.dat) |
| `ZM_EXE`, `--exe=` | het originele ROS.exe (v1.1) voor de formulierresources |
| `ZM_HEADLESS=1` | geen venster (null-backend); tijd loopt mee met de klok van de computer |
| `ZM_SCALE=n`, `ZM_FULLSCREEN=1` | SDL-vensterschaal / volledig scherm |
| `ZM_SDL3_LIB` | pad van libSDL3 (anders standaardnamen, daarna de libdirs van `sdl3.pc` op `PKG_CONFIG_PATH`) |
| `ZM_SCREENSHOT=f.png`, `ZM_SCREENSHOT_AT=ms` | sla het scherm als PNG op na ms (standaard 3000) |
| `ZM_EXIT_AT=ms` | sluit af na ms |
| `ZM_SCRIPT="ms:cmd;..."` | gescripte invoer: `click:x,y`, `rclick:x,y`, `move:x,y`, `key:vk`, `char:c`, `shot:file`, `exit`; coördinaten relatief aan het clientgebied van het hoofdformulier |
| `ZM_DEBUG=1` | logt onbekende DFM-eigenschappen, berichtvensters, exception-backtraces, vensterboom bij screenshot |
| `ZM_SHADOW` | locatie van de schaduwmap (exact, niet per proces) |
| `ZM_SAVE` | schrijfbare overlay (standaard `$XDG_DATA_HOME/zoetermeer`) |
| `ZM_NO_AA=1` | geen anti-aliasing van tekst |

SDL's eigen variabelen werken ook (`SDL_VIDEODRIVER=offscreen`).

## Haken voor het differentiële-testharnas

* `ZMPlatform.ZMInactiefHaak: procedure`: wordt één keer per iteratie van de berichtenpomp aangeroepen
  (elke PeekMessage/GetMessage/WaitMessage, dus ook binnen `ShowModal` en `MessageBox`).
* `ZMWin.ZMInjecteerMuis(X, Y, Button {0 move, 1 left, 2 right}, Down)`,
  `ZMWin.ZMInjecteerToets(VK, Down)`, `ZMWin.ZMInjecteerKarakter(C)`: zetten synthetische invoer in de wachtrij precies
  zoals backend-events (ook headless). Coördinaten zijn relatief aan het clientgebied van
  `ZMWin.ZMHoofdVenster` (ingesteld door `Application.CreateForm` voor het hoofdformulier).
* `ZMWin.ZMBewaarSchermafdruk(FileName)`, `ZMWin.ZMDumpVensters`.

## Tests

`src/compat/tests/` bevat `test_controls` (standaardbesturingselementen, geïnjecteerde klik),
`test_bitmap` (8-bit DIB, StretchBlt, mono-maskerblit met SRCINVERT/SRCAND, ScanLine,
formaatconversie), `test_dfm` (streamt TFRMBLACK uit ROS.exe) en `test_ini`
(leesregels van GetPrivateProfileString, schrijven ter plekke, de overlay; met een eigen
synthetische, schrijfbeveiligde datamap).
`nix develop --command tools/compat-test.sh` bouwt en draait ze headless en schrijft
screenshots naar `build/compat-tests/`.

## Niet geïmplementeerd / stubs

* Geluid (`PlaySound`, `sndPlaySound`) geeft stilzwijgend succes terug (het spel heeft geen geluid).
* DirectDraw-oppervlakken (`CreateSurface` enz.) geven `DDERR_UNSUPPORTED` terug; het spel schakelt alleen
  schermmodi om.
* `LoadLibrary`/`GetProcAddress` falen (aanroepers gebruiken hun terugvalmogelijkheden).
* Eigen cursors uit ROS.exe worden niet geladen: benoemde `LoadCursor`-resources koppelen aan de
  systeemhandcursor (de enige eigen cursor van het spel is een hand); `Screen.Cursor` koppelt aan
  SDL-systeemcursors.
* Menu's zijn alleen gegevens (`TPopupMenu.Popup` toont niets); slepen en neerzetten, hints, docking,
  klembord, afdrukken, metafiles, pictogrammen (bewaard als gegevens, niet getekend) zijn stubs.
* De HALFTONE-modus van `StretchBlt` gebruikt bemonstering op de dichtstbijzijnde pixel.
* Bogen/taartstukken/koorden worden als volledige ellipsen getekend.

# Compat layer (`src/compat/`)

The decompiled game units in `src/game/` are written against the Delphi 5 RTL/VCL,
Win32 and DirectDraw. `src/compat/` provides units with the **same names and API**,
implemented portably, so the unmodified game source builds with Free Pascal and runs on
Linux, macOS (aarch64-darwin, SDL3) and later WebAssembly. FPC's own RTL supplies
`System`, `SysUtils`, `Classes` (TReader/TWriter for the DFM streams), `Math`,
`Contnrs` and `TypInfo`; compat does not shadow them. `IniFiles` is the exception: see
"INI-bestanden" below.

## Layers

```
 game units (src/game)
   |  Delphi API
 Windows Messages MMSystem ddraw | Graphics Controls Forms StdCtrls ExtCtrls Buttons
                                 | ComCtrls Dialogs FileCtrl Menus Grids ImgList
   |
 ZMWin    window manager + message queue + timers + input + painting   (portable)
 ZMGdi    software GDI: DIBs, palettes, DCs, regions, ROP blits, text   (portable)
 ZMFonts  bitmap fonts (fonts/zmfontdata.inc, generated)               (portable)
 ZMData   data directory, ROS.exe PE resources, path resolution        (portable, Unix/other)
 ZMHandles handle table (HWND/HDC/HBITMAP... are small integers)       (portable)
   |
 ZMPlatform   backend interface (TZMBackend) + null backend + PNG writer
 sdl3/ZMSdl3Backend, sdl3/SDL3   SDL3 backend (dynamically loaded libSDL3)
```

`ZMDraw` holds the classic Windows 9x drawing helpers used by the controls.

### Platform boundary (`ZMPlatform.TZMBackend`)

A backend opens one window showing the emulated screen, presents a 32-bit XRGB
framebuffer, delivers input events (mouse in screen coordinates, Windows VK codes,
Windows-1252 text), time (`Ticks`, `PerfCounter`), `Delay`, `WaitEvent(timeout)` and a
cursor shape. Nothing else touches SDL. A browser backend implements the same class.

The **only blocking point** is `ZMWin.ZMWaitMessage` (used by `WaitMessage`,
`GetMessage`, `Application.HandleMessage`/`Idle`, `ShowModal`, `MessageBox`, the file
dialogs). For WebAssembly this is where the program has to yield to the browser
(Asyncify or an equivalent); everything else is non-blocking.

### Screen and windows

There is one emulated screen, a 1024x768 32-bit bitmap (`ZMScreen`). Top-level windows
(forms, message boxes, popups) are placed on it; child windows (TWinControls) inside
their parents. All windows draw **directly into the screen** through window DCs whose
visible region is the window's client area minus overlapping siblings above it and minus
its child windows (WS_CLIPSIBLINGS | WS_CLIPCHILDREN semantics), like non-composited
Windows. The game's sprite engine does exactly what it did on Windows: `GetDC(Handle)`,
`BitBlt`, `ReleaseDC`. Moving/hiding a window invalidates what it uncovers; WM_PAINT and
WM_TIMER are synthesized when the posted-message queue is empty; non-client frames
(caption, borders, client edges) are painted by the window manager in Win9x style.
`ChangeDisplaySettings` and `IDirectDraw.SetDisplayMode` succeed without changing the
screen size; `GetDeviceCaps(BITSPIXEL)` reports 32 (true colour, no palette device).

### GDI

`ZMGdi` implements bitmaps of 1/4/8/16/24/32 bpp (top-down rows, `ScanLine[]` works),
colour tables, logical palettes, DCs with state stack, window/viewport origins, clip
regions (rectangle lists), brushes (solid/hatch/pattern), pens, fonts, `BitBlt`/
`StretchBlt`/`PatBlt` with **all 256 ternary ROPs** and the Windows colour conversion
rules (mono to colour uses the destination DC's text/background colour, colour to mono
compares with the source DC's background colour, 8-bit to 8-bit with different colour
tables maps through RGB, ...), lines, rectangles, ellipses, polygons, flood fill,
`TextOut`/`ExtTextOut`/`DrawText`/`GetTextExtentPoint`/`GetTextMetrics`.

### Fonts

`tools/gen-fonts.py` renders Liberation Sans/Serif/Mono (SIL OFL; metric clones of
Arial, Times New Roman, Courier New; package `liberation_ttf`) without anti-aliasing at a
range of pixel sizes into `src/compat/fonts/zmfontdata.inc` (committed, regenerate with
`nix develop --command python tools/gen-fonts.py`). Font mapping: Arial / MS Sans Serif
/ unknown -> sans, Courier* -> mono, Times* -> serif, `System` -> a 16 px bold face whose
widths match the DFM label sizes of the original exactly.

### VCL

`Controls`/`Forms` follow the Delphi 5 structure closely (WndProc, message handlers,
`Perform`, `PaintHandler`/`PaintControls`, `AlignControls`, KeyPreview, CM_DIALOGKEY for
default/cancel buttons, CM_MOUSEENTER/LEAVE, mouse capture, graphic controls painted by
their parent, `TControlCanvas` DCs freed at idle). Standard controls are drawn by Pascal
code (TButton, TBitBtn with stock glyphs, TLabel, TEdit, TMemo with scroll bar and
word-wrapped `Lines` like Windows' edit control, TCheckBox, TRadioButton, TListBox,
TComboBox with drop-down list, TScrollBar, TGroupBox, TPanel, TImage, TPaintBox, TBevel,
TShape, TTimer, TTabControl (owner-draw, multi-line), TPageControl, TProgressBar,
TStatusBar, TTrackBar, TStringGrid/TDrawGrid, TDirectoryListBox etc.). `MessageBox`,
`ShowMessage`, `MessageDlg`, `InputQuery` and `TOpenDialog`/`TSaveDialog` are modal forms
inside the emulated screen.

TMemo breekt regels af zoals de edit-control van Wine (`EDIT_BuildLineDefs_ML`): het
opmaakrechthoek is het clientgebied min de scrollbalk, 1 pixel per kant voor
WS_EX_CLIENTEDGE en voor TrueType-fonts een marge van een halve gemiddelde tekenbreedte;
een te brede regel krijgt een geschat breekpunt (breedte/opmaakbreedte, min 0,2 boven
1,2) en zoekt van daaruit naar links de eerste woordgrens die past. Daardoor zijn regels
vaak korter dan nodig; de originele schermen (intro- en leveltekst) laten precies die
afbrekingen zien, en het spel tekent de memoregels zelf (TBehavMemo).

### Forms from ROS.exe

`TCustomForm.Create` loads the RCDATA resource named after the form class (and its
ancestors, like `InitInheritedComponent`) **from the user's original ROS.exe** (PE
resource reader in `ZMData`) and streams it with FPC's `TReader`. Unknown properties are
skipped (listed with `ZM_DEBUG=1`), missing event handlers are reported. No game data
is in the repository; `{$R *.dfm}` in the game units is Delphi-only.

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
  tekstkleur, daartussen mengt `ZMGdi.AAComp` met de gammacurve van Wine
  (`dibdrv/primitives.c`). Hiermee zijn de teksten pixel-gelijk aan de referentie.

### Data files and paths

`ZMData` finds the data directory from `--data=<dir>`, `$ZM_DATA`, the current
directory or the executable's directory, and ROS.exe from `--exe=<file>`, `$ZM_EXE` or
the data directory. The game builds paths as `ExtractFilePath(ParamStr(0)) + '\'` +
`images\8bits\x.bmp` and opens them through the plain RTL (`TIniFile`, `AssignFile`,
`FindFirst`, `TStrings.LoadFromFile`). To make that work unchanged on Unix:

* `Windows.ParamStr(0)` (shadows `System.ParamStr` in units that use `Windows`) returns
  `<shadow>/ROS.exe`.
* The shadow directory `$XDG_CACHE_HOME/zoetermeer/root-<hash>/` (override `ZM_SHADOW`)
  holds symlinks whose *names* are the game's Windows-style relative paths
  (`\ZoetermeerGame.ini`, `\images\8bits\Achterg.bmp`; backslashes are ordinary file
  name characters on Unix). Root files get links in several letter cases (the game asks
  for `ZoetermeerGame.ini`, the file is `ZoetermeerGame.Ini`); files in subdirectories get
  one link each, so `FindFirst('<shadow>/\images\8bits\*.bmp')` returns every file once
  (FPC's FindFirst lists `<shadow>/` and strips the `\...\` prefix from the names).
  About 660 links; built in ~60 ms at start. Elk proces heeft een eigen schaduwmap
  (`root-<hash>/<pid>/`, opgeruimd bij afsluiten; mappen van beëindigde processen
  ruimt de volgende start op), zodat twee gelijktijdige runs elkaar niet storen.
* Compat's own file access (`TGraphic.LoadFromFile`, dialogs, `FileCtrl`) goes through
  `ZMData.ZMResolvePath` (backslashes and letter case resolved against the real tree).

**Schrijfbare overlay.** Het spel schrijft nooit in de datamap (bij `nix build
.#zoetermeer` is dat een alleen-lezen store-pad). `ZMData.ZMWritePath` stuurt elke
schrijfactie op een bestand uit de data- of schaduwmap naar een map per gebruiker:
`$ZM_SAVE`, anders `$XDG_DATA_HOME/zoetermeer` (`~/.local/share/zoetermeer`), op macOS
`~/Library/Application Support/Virtueel Zoetermeer`. Een bestaand origineel wordt eerst
gekopieerd (copy-on-write). De schaduwlinks wijzen naar de overlaykopie zodra die bestaat
(ook bij een volgende start), en `ZMResolvePath` geeft voor een pad in de datamap de
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

A cleaner alternative, if the game units may get FPC-only seams: make `uString.AddPath`
and the `AppPath` initialisation in `uTool` use `PathDelim`; the shadow directory then only
needs the case-variant links.

## Environment variables

| Variable | Meaning |
|---|---|
| `ZM_DATA`, `--data=` | data directory (images/, *.Ini, Objecten.csv, wijken.dat) |
| `ZM_EXE`, `--exe=` | the original ROS.exe (v1.1) for the form resources |
| `ZM_HEADLESS=1` | no window (null backend); time runs from the wall clock |
| `ZM_SCALE=n`, `ZM_FULLSCREEN=1` | SDL window scale / fullscreen |
| `ZM_SDL3_LIB` | path of libSDL3 (else default names, then `sdl3.pc` libdirs on `PKG_CONFIG_PATH`) |
| `ZM_SCREENSHOT=f.png`, `ZM_SCREENSHOT_AT=ms` | save the screen as PNG after ms (default 3000) |
| `ZM_EXIT_AT=ms` | exit after ms |
| `ZM_SCRIPT="ms:cmd;..."` | scripted input: `click:x,y`, `rclick:x,y`, `move:x,y`, `key:vk`, `char:c`, `shot:file`, `exit`; coordinates relative to the main form's client area |
| `ZM_DEBUG=1` | log unknown DFM properties, message boxes, exception backtraces, window tree at screenshot |
| `ZM_SHADOW` | location of the shadow directory (exact, niet per proces) |
| `ZM_SAVE` | schrijfbare overlay (standaard `$XDG_DATA_HOME/zoetermeer`) |
| `ZM_NO_AA=1` | geen anti-aliasing van tekst |

SDL's own variables work too (`SDL_VIDEODRIVER=offscreen`).

## Hooks for the differential-test harness

* `ZMPlatform.ZMIdleHook: procedure` - called once per message-pump iteration
  (every PeekMessage/GetMessage/WaitMessage, so also inside `ShowModal` and `MessageBox`).
* `ZMWin.ZMInjectMouse(X, Y, Button {0 move, 1 left, 2 right}, Down)`,
  `ZMWin.ZMInjectKey(VK, Down)`, `ZMWin.ZMInjectChar(C)` - queue synthetic input exactly
  like backend events (also headless). Coordinates are relative to the client area of
  `ZMWin.ZMMainWindow` (set by `Application.CreateForm` for the main form).
* `ZMWin.ZMSaveScreenshot(FileName)`, `ZMWin.ZMDumpWindows`.

## Tests

`src/compat/tests/` has `test_controls` (standard controls, injected click),
`test_bitmap` (8-bit DIB, StretchBlt, mono mask blit with SRCINVERT/SRCAND, ScanLine,
format conversion), `test_dfm` (streams TFRMBLACK from ROS.exe) en `test_ini`
(leesregels van GetPrivateProfileString, schrijven ter plekke, de overlay; met een eigen
synthetische, schrijfbeveiligde datamap).
`nix develop --command tools/compat-test.sh` builds and runs them headless and writes
screenshots to `build/compat-tests/`.

## Not implemented / stubs

* Sound (`PlaySound`, `sndPlaySound`) returns success silently (the game has no sound).
* DirectDraw surfaces (`CreateSurface` etc.) return `DDERR_UNSUPPORTED`; the game only
  switches display modes.
* `LoadLibrary`/`GetProcAddress` fail (callers use their fallbacks).
* Custom cursors from ROS.exe are not loaded: named `LoadCursor` resources map to the
  system hand cursor (the game's only custom cursor is a hand); `Screen.Cursor` maps to SDL system cursors.
* Menus are data only (`TPopupMenu.Popup` shows nothing); drag and drop, hints, docking,
  clipboard, printing, metafiles, icons (kept as data, not drawn) are stubs.
* `StretchBlt` HALFTONE mode uses nearest-pixel sampling.
* Arcs/pies/chords are drawn as full ellipses.

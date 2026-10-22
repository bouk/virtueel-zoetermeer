# Compat layer (`src/compat/`)

The decompiled game units in `src/game/` are written against the Delphi 5 RTL/VCL,
Win32 and DirectDraw. `src/compat/` provides units with the **same names and API**,
implemented portably, so the unmodified game source builds with Free Pascal and runs on
Linux, macOS (aarch64-darwin, SDL3) and later WebAssembly. FPC's own RTL supplies
`System`, `SysUtils`, `Classes` (TReader/TWriter for the DFM streams), `Math`,
`IniFiles`, `Contnrs` and `TypInfo`; compat does not shadow them.

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

### Forms from ROS.exe

`TCustomForm.Create` loads the RCDATA resource named after the form class (and its
ancestors, like `InitInheritedComponent`) **from the user's original ROS.exe** (PE
resource reader in `ZMData`) and streams it with FPC's `TReader`. Unknown properties are
skipped (listed with `ZM_DEBUG=1`), missing event handlers are reported. No game data
is in the repository; `{$R *.dfm}` in the game units is Delphi-only.

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
  About 660 links; rebuilt in ~60 ms at start. Files the game writes into its own
  directory stay in the shadow directory.
* Compat's own file access (`TGraphic.LoadFromFile`, dialogs, `FileCtrl`) goes through
  `ZMData.ZMResolvePath` (backslashes and letter case resolved against the real tree).

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
| `ZM_SHADOW` | location of the shadow directory |

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
format conversion) and `test_dfm` (streams TFRMBLACK from ROS.exe).
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

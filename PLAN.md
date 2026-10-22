# Virtueel Zoetermeer: matching decompilation plan

## Goals

1. **Matching decomp.** Object Pascal source that, built with the original compiler, produces an executable that is byte-for-byte identical to the shipped `ROS.exe`.
2. **Native port.** The same source, built with Free Pascal, runs natively on Apple Silicon macOS (aarch64-darwin).
3. **Web port.** The same source, built for WebAssembly, runs in a browser.

Goal 1 comes first. It gives us source that is faithful by construction. Goals 2 and 3 are a portability layer on top of that source, and they must never break the matching build.

## Decisions (confirmed 2026-10-22)

- The plan below is confirmed as written, with one exception.
- **We don't have a Delphi 5 compiler.** Byte-matching the project units needs Borland's exact dcc32. Until we have one (a legitimately bought second-hand Delphi 5 license is the realistic route), we work in **equivalence mode**:
  - **Oracle.** The original `ROS.exe` stays the reference. Byte-matching is still the target for the data that does not depend on the compiler: VMT/RTTI layout, DFM resources, string tables and `Objecten.csv` parsing.
  - **Compiler.** The decompiled Pascal is built with **Free Pascal** in `{$mode delphi}`, first for `i386-win32`, run under Wine. This is the same compiler we need for the ports anyway.
  - **Correctness.** It is proven by **differential testing**. We run the original and the rebuild under Wine with the same scripted input, plus a fixed timer and RNG seed, then compare world-state dumps (money, inhabitants, house prices, overlast/reistijd scores) and screenshots per frame.
  - **Per function.** Routines are checked by reviewing them against Ghidra/IDR output. Leaf routines are also unit-tested against the original. Possible approach: call the original code inside an emulator (unicorn) on the same inputs.
  - **Later.** If Delphi 5 turns up, Phase 2's matching pipeline is switched on, and the source is tightened until it is byte-identical.
- **Port UI:** a mini-VCL shim rendering into a software framebuffer. It uses SDL3 on macOS and `<canvas>` on the web.

## What we are dealing with (findings so far)

`Virtueel Zoetermeer.zip` contains:

| File | What it is |
|---|---|
| `installatie.exe` | NSIS installer, repackaged in 2021. It unpacks into the files below. |
| `ROS.exe` | **The game.** Delphi 5 PE32 GUI executable, file date 2003-07-14, 3.7 MB. sha256 `5b76da9044bddcd14597e80b60e18c60bccad47159e5ab03c4a07429b747f041` |
| `Stub.exe` | Delphi 7 launcher added in 2011. It shows a "more games on zoetermeer.nl/games" prompt. sha256 `7f946e1e…0001` |
| `update.exe` | 2003 Wise Installer, a 16-bit NE stub. It may contain an older or different build of the game. |
| `images/8bits/*.bmp` (620 files), `*.Ini`, `Objecten.csv`, `wijken.dat` | Game data: 8-bit sprites, level rules (Dutch), object table, district map. |
| `Lespakket Ben jij een goede burgemeester.pdf` | 2015 classroom lesson pack (documentation only). |

### ROS.exe in detail

- **Compiler: Borland Delphi 5.** Evidence:
  - Linker 2.25 and the fixed Delphi timestamp `1992-06-20`.
  - `CODE/DATA/BSS` sections.
  - "Portions Copyright (c) 1983,99 Borland".
  - The units `TFrame` and `DsgnIntf` are present.
  - There is no `Variants`, `Types` or `RTLConsts` unit, so it predates Delphi 6.
- **Layout:**
  - `CODE` is 0x87B84 bytes (about 543 KB).
  - `DATA` is 0x174C bytes.
  - `.rsrc` is about 3.1 MB, mostly 5 DFM forms with embedded bitmaps: `TFRMMAIN` (2.6 MB), `TFRMBLACK`, `TFRMREPORT`, `TFRMSELECTDIR`, `TFORMDEBUGSHOW`.
- **Imports:** kernel32, user32, gdi32, advapi32, ole32, oleaut32, comctl32, shell32, comdlg32, winmm, **DDRAW** (DirectDraw rendering).
- **Units, in link order from `PACKAGEINFO`.** There are 88 units in total. Borland RTL/VCL units are omitted here. The ~40 project units are:
  - **Game:** `Ros` (program), `Fmain`, `fReport`, `fBack`, `Uworld`, `Uview`, `Usett`, `Uconst`, `uAutos`, `uTrein`, `Uctrl`.
  - **In-house sprite/GUI engine:**
    - `SprCtrl`, `SprBmp`, `Sprframe`, `Sprsqlst`, `Sprfrmed`, `Sprbehav`
    - `uSprite`, `uSpritebox`, `uPixie`, `uGoblin`, `uSurface`
    - `uSequence`, `uTransition`, `uTextBalloon`, `uTiming`, `uMessage`, `uResizeScreen`
    - `uQuickDirectX`, plus the `ddraw` header unit
  - **Utilities / misc:** `uTool`, `uString`, `uLog`, `uDebug`, `fShow`, `Seldir`, `ExtLbox`, `cEditCtr`.
- **RTTI.** Delphi RTTI, VMTs and the DFMs give us class names, published fields, event-handler names and form layouts for free. Only private and local names have to be invented.

### What "matching" means for Delphi

- We write source only for the **project units**.
- The RTL/VCL code (`System`, `SysUtils`, `Classes`, `Forms`, …) is linked from Borland's precompiled Delphi 5 `.dcu` files, exactly as the original was. That only matches if we use **the same Delphi 5 build** (base, or Update Pack 1). One of the first tasks is to determine which, by diffing RTL code against each candidate.
- Delphi's compiler and linker are deterministic. Code is laid out unit by unit in a fixed order, and routines within a unit follow implementation order. So we can match one unit at a time and verify progress continuously.

## Phase 0: Project setup

- [x] `flake.nix` dev shell: 7z/unzip, binutils, icoutils, rizin, Ghidra, Wine (wow64), Python with pefile/capstone/lief.
- [x] git repo. The original binaries are git-ignored and never committed.
- [ ] `orig/`: a script that extracts the zip into `orig/` and verifies the sha256 sums above.
- [ ] *(Deferred: not available.)* Obtain Delphi 5 (dcc32.exe plus `lib/*.dcu`, `*.res`). It is proprietary, so it would be a git-ignored `toolchain/`. Until then, follow equivalence mode (see Decisions).
- [ ] Add Free Pascal (with the i386-win32 cross target) and unicorn to the flake. Check that an FPC `{$mode delphi}` VCL-free hello world builds and runs under Wine.
- [ ] Differential-test harness: launch the original `ROS.exe` under Wine with input injection, and dump state through a small hooking DLL or memory reads.
- [ ] Extract `update.exe` (Wise) and compare any game binary inside it with `ROS.exe`.

## Phase 1: Analysis and symbol recovery

- [ ] Run **IDR (Interactive Delphi Reconstructor)** under Wine with its Delphi 5 knowledge base. It identifies:
  - RTL/VCL routines
  - class VMTs, RTTI and published methods
  - the start of every unit's code
- [ ] Export the results to a symbol map: `symbols/ros.sym` (address, size, unit, name).
- [ ] Import the symbols into Ghidra (a script in `tools/`) for decompilation.
- [ ] Build `tools/units.py`. It produces the address range of each project unit from the IDR map and the PACKAGEINFO order. This also measures how much code is the project's own versus Borland's (expected: on the order of 100–200 KB).
- [ ] Pin down the exact compiler build and switches. Candidates:
  - Delphi 5 base or Update Pack 1
  - `$O` optimization, `$W` stack frames, `$R/$Q` range/overflow checks, `$A` alignment, `$D/$L` debug info (affects nothing in the exe, but affects `.map`)
  - `$I` I/O checks, `$H` long strings

  We confirm these by compiling probe units and comparing code patterns, plus the RTL bytes.
- [ ] Convert the binary DFM resources to text `.dfm` for reading. We keep the original binary form streams as the build input so they match exactly.
- [ ] Identify the `ddraw` header unit. It is likely a public DirectX header translation (Erik Unger / JEDI / Hori). If we find it, use the original source instead of decompiling it.
- [ ] Check whether `ExtLbox`, `Seldir` and `cEditCtr` are publicly available sample or third-party units.

## Phase 2: Build and verify pipeline

Repo layout:

```
src/            project .pas/.dpr/.dfm files (decompiled)
src/stubs/      not-yet-decompiled units (see below)
res/            .res inputs: icon, version info, bitmaps, binary DFMs
tools/          python: extract, symbol map, diff, progress, Ghidra scripts
symbols/        ros.sym (original addresses → names)
orig/           (ignored) original files
build/          (ignored) output
```

- [ ] `make` (or `just`) runs `wine dcc32 -B -GD src/Ros.dpr` with the pinned switches. That produces `build/ROS.exe` and a detailed `.map`.
- [ ] `tools/diff.py` compares whole-file sha256 and section by section. It also compares each function: it maps routines through `build/ROS.map` and `symbols/ros.sym`, then disassembles both with capstone. Relocated operands are normalized so that one wrong function doesn't cascade into address noise everywhere.
- [ ] `tools/progress.py` reports % of project-unit bytes matching, per unit, and writes a progress badge or JSON.
- [ ] **Bootstrapping strategy.** We can't link a working exe until every unit exists, so:
  1. Each not-yet-decompiled routine starts as an `asm … end` block containing the original bytes (`db` directives). Delphi's built-in assembler accepts this.
  2. Relocations become symbolic references, which are recovered from `.reloc`.
  3. This gives a matching build from day one.
  4. Routines are replaced by real Pascal one at a time, and must keep the build matching.

  This is the standard "split + incremental decomp" approach, adapted to Delphi.
- [ ] CI: a GitHub Actions or Nix check that builds and asserts the hash. This depends on the toolchain being available to CI, which may only be possible locally because of Delphi licensing.

## Phase 3: Decompile, unit by unit

Order: leaves first, so later units can rely on decompiled types.

1. `Uconst`, `uString`, `uTool`, `uLog`, `uDebug`, `uTiming`. These are small and they teach us the compiler's idioms.
2. Engine core: `uQuickDirectX`, `uSurface`, `SprBmp`, `uSprite`, `uPixie`, `uGoblin`, `uSpritebox`, `Sprframe`, `Sprsqlst`, `Sprbehav`, `SprCtrl`, `uSequence`, `uTransition`, `uTextBalloon`, `uMessage`, `uResizeScreen`.
3. Game model: `Uworld`, `Usett`, `uAutos`, `uTrein`, `Uview`, `Uctrl`.
4. Forms: `Fmain`, `fBack`, `fReport`, `fShow`, `Seldir`, and the editor units (`Sprfrmed`, `cEditCtr`, `ExtLbox`).

Rules:
- Every commit keeps `build/ROS.exe` byte-identical.
- Match the declaration order of classes, fields and virtual methods exactly, because it determines VMT and RTTI layout.
- Use the RTTI and DFM names where they exist. Invented names follow Delphi conventions (`F` prefix for fields, `T` for types).

Done when no `asm db` blobs remain in the project units and the hash still matches.

## Phase 4: Portable build with Free Pascal (Apple Silicon macOS)

Free Pascal (FPC) compiles Delphi-dialect code (`{$mode delphi}`) and targets both **aarch64-darwin** and **wasm32**. That makes it the natural route to both ports without rewriting the game in another language.

Portability issues to resolve:
- **Rendering.** `uQuickDirectX` is DirectDraw over 8-bit palettized surfaces. It is replaced by a backend-neutral software framebuffer (palette plus 8-bit surfaces, blits done in Pascal), presented by a small platform layer.
- **VCL.** The game uses Forms, StdCtrls, ExtCtrls, Grids, Dialogs and Buttons, but most of the UI is bitmap-based (TFRMMAIN embeds 2.6 MB of images). Recommended approach: a **mini-VCL shim**. It reimplements only the classes and properties actually used, with the same names, renders them into the framebuffer, and loads the original DFM streams with a small DFM reader. Game code then stays nearly unchanged. Alternative: Lazarus LCL, which supports Cocoa but has no usable wasm target.
- **Win32 API calls** (registry, INI files, `timeGetTime`, `ShellExecute`, message boxes) go behind `uPlatform`.
- **Data files.** Paths become case-sensitive and the INI files are Windows-1252. Handle both explicitly.
- **Pascal semantics that differ between Delphi 5 and FPC.** These are 32-bit `Integer`/pointer size assumptions, `string` = AnsiString, record packing and set sizes. Audit them on 64-bit aarch64.

Steps:
- [ ] Add FPC (and possibly SDL3) to the flake. Make a cross-target `nix build .#ros-macos` (aarch64-darwin).
- [ ] `{$IFDEF FPC}` / `{$IFDEF PORTABLE}` seams. The Delphi 5 matching build must keep compiling unchanged.
- [ ] macOS platform layer: SDL3 (window, input, audio via winmm replacement, timer), or a native Cocoa layer if preferred.
- [ ] Package as an `.app` bundle with the data files.

## Phase 5: WebAssembly port

- [ ] Build with FPC's `wasm32-wasi` target (or `wasm32-embedded`) with a thin JS host that provides:
  - a framebuffer blit to `<canvas>`
  - keyboard/mouse events
  - a frame timer (requestAnimationFrame-driven main loop, so the VCL-style message loop has to become re-entrant/callback-driven)
  - a virtual filesystem preloaded with the BMP/INI/CSV data
  - `localStorage` for high scores and settings
- [ ] Fallback if FPC's wasm target is too immature: SDL3 via Emscripten with a small C bridge to the FPC-compiled game core. Decide after Phase 4, based on how the platform layer turned out.
- [ ] Deploy as a static site.

## Fase 6: Verificatie door een volledige playthrough (Haiku-agent)

Naast de differentiële tests (`docs/DIFFTEST.md`), die korte scenario's byte voor byte met het
origineel vergelijken, speelt een Haiku-agent het hele spel uit om te controleren dat de
herbouw nergens crasht of vastloopt.

- [ ] Interactieve bediening van het draaiende spel voor een agent: `tools/speel.py` start de
  portable build (`RosTest`) headless en geeft subcommando's voor één stap tegelijk: `klik x y`,
  `toets naam`, `wacht ms`, `foto` (screenshot om te bekijken), `toestand` (state dump: level,
  geld, score, wijken) en `stop`. ZMHarness leest daarvoor commando's live uit een
  controlebestand in plaats van uit een vooraf geschreven script.
- [ ] Crash- en hangdetectie: het proces loopt nog, er komen frames, er zijn geen exceptions in
  de log (`ZM_DEBUG`). Bij een crash worden het commandolog en de laatste screenshots bewaard,
  zodat het precies na te spelen is als `.zms`-script.
- [ ] Een Haiku-agent (model `haiku`) speelt alle levels door: wijken openen, wegen, spoor,
  huizen, kantoren, voorzieningen en stations bouwen, rondes afsluiten, rapporten lezen, de stad
  bewaren en weer openen, en het spel afsluiten. Hij houdt een logboek bij en rapporteert elke
  crash, hang of zichtbare fout met het commandolog.
- [ ] Gevonden fouten worden nagespeeld tegen het origineel onder Wine (zelfde script) om te
  bepalen of het een fout van de herbouw is of oorspronkelijk gedrag.
- [ ] Hetzelfde voor de webversie (`tools/test-web.py`), minstens tot en met level 2.

## Out of scope (for now)

- `Stub.exe` (a 2011 Delphi 7 launcher, trivial) and `update.exe` (unless it holds a different game build worth matching).
- Distributing game assets. The repo contains code and tools only; users supply their own copy of the original files.

## Open questions for the user

1. Do you have a **Delphi 5** install, and do you know which edition or Update Pack? Byte-matching is impossible without it.
2. For the ports, which UI approach: the **mini-VCL shim over SDL3 / canvas** (recommended), or Lazarus LCL?
3. Is matching `ROS.exe` alone the target, or should `Stub.exe` be in scope too?

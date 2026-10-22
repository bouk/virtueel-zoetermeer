# Decompilation conventions

These rules apply to every unit in `src/game/`. They exist so that units written by different
people (or agents) fit together, and so that the source stays traceable to the original binary.

Target binary: **v1.1 `ROS.exe`** (sha256 `6bbd1f71c719…`, see `orig.sha256`), built with Delphi 5.

## Reference material

| What | Where |
|---|---|
| Unit code ranges, init order | `symbols/units-1.1.json`, `symbols/project-ranges-1.1.txt` |
| Symbols (functions, VMTs, globals, string literals) | `symbols/ros-1.1.tsv` |
| Class catalog (VMT slots, RTTI fields/properties/methods) | `symbols/classes-1.1.md` |
| Ghidra C and symbolized disassembly per unit | `build/decomp-1.1/<Unit>.c`, `.s` (`tools/ghidra/analyze.sh 1.1`) |
| Form layouts (DFM as text) | `build/dfm-1.1/*.txt` (`python tools/dfm.py orig/game-1.1/ROS.exe build/dfm-1.1`) |
| Inter-unit references | `symbols/unit-deps-1.1.json` |

Delphi 5 `register` calling convention: the first three ordinal/pointer arguments are in EAX, EDX,
ECX (for methods `Self` is EAX); the rest are pushed left to right; the result is in EAX (Int64 in
EDX:EAX, floating point in ST0). Strings are reference-counted `AnsiString`; a hidden result
pointer is passed as the last parameter for string/record results. `Ghidra` is told about this
convention, but its output for exception frames (`FS:[0]`), string temporaries (`@LStrClr`,
`@LStrAsg`, `@LStrCatN`) and `try/finally` blocks still needs to be read back into Pascal.

## Dialect

* Write **Delphi 5 Object Pascal**. Every unit must also compile with **Free Pascal 3.2**:
  start each unit with `{$I zm.inc}` (sets `{$MODE DELPHI}` etc. under FPC).
* Use the Delphi 5 RTL/VCL API exactly as the original did (`Windows`, `Messages`, `Classes`,
  `Graphics`, `Controls`, `Forms`, `StdCtrls`, `ExtCtrls`, `ddraw`, `MMSystem`, …).
  **Do not port anything.** The portable rebuild provides those units in `src/compat/`; the game
  code calls DirectDraw and Win32 exactly like the original.
* Keep the original `uses` lists as far as they can be inferred (interface vs implementation).

## Faithfulness

* Reproduce the logic exactly, including odd constructs and bugs. Do not "improve" code.
  If something looks like a bug, keep it and add a `{ NOTE: … }` comment.
* Keep **routines in address order** within a unit, and put the address in a comment directly above
  each routine: `{ @0047A904 }`. Nested procedures appear before their parent in the binary; keep
  them nested in the source.
* String literals must be byte-identical (they are Windows-1252; write non-ASCII characters as
  `#233` etc.).
* Numeric constants: write them the way the source most likely had them (`$FF`, `1024`, `clBlack`,
  `mrOk`, `VK_LEFT`), not as raw hex where a named constant obviously fits.
* Floating point: Delphi evaluates in 80-bit extended. Keep `Real`/`Double`/`Single`/`Extended`
  types as the code's loads/stores show (`FLD qword` = Double, `dword` = Single, `tword` = Extended).

## Classes

* Field declaration order must reproduce the original **field offsets** (Delphi 5 aligns fields
  to their natural size, max 4, inside classes; records follow `{$A+}`). Put the offset in a
  comment: `FWorld: TWorld; { +0x1A4 }`.
* Virtual methods must be declared in **VMT slot order**. A slot marked `NEW` in
  `symbols/classes-1.1.md` gets `virtual;` (or `virtual; abstract;`), an override gets `override;`.
  Message handlers (dynamic table entries with Windows message ids) get `message WM_xxx;`.
* Published sections must list fields/methods/properties in RTTI order (as in the catalog).
* Names: use the RTTI/published names wherever they exist. Name everything else in the style of
  the original: engine code is English (`FFrameList`, `SetPriority`), game code mixes in Dutch
  domain terms (`Wijk`, `Huisprijs`, `Overlast`, `Reistijd`). Getter/setter names follow
  `Get<Prop>`/`Set<Prop>`; private fields `F<Prop>`.

## Portability rules (so the same source builds for macOS arm64 and WebAssembly)

* Never assume `SizeOf(Pointer) = 4`. Where the original casts pointers to `Integer` (e.g. storing
  objects in `Tag` or in a `TList` of integers), use `PtrInt`/`PtrUInt` (declared for Delphi 5 in
  `zm.inc`).
* Anything written to or read from **files** (save games, data files) must use fixed-size types
  (`Longint`, `SmallInt`, `Byte`, `Single`, `Double`, `ShortString[N]`) and `packed record`s
  whose layout reproduces Delphi 5's on-disk bytes exactly. Comment the expected record size.
* `Integer` is 32-bit in both compilers (`{$MODE DELPHI}`); `Cardinal`/`Longword` likewise.

## Output per unit

1. `src/game/<Unit>.pas` (or `.dpr` for the program).
2. `symbols/names/<Unit>.json` — names you assigned, so the next Ghidra export shows them:

   ```json
   {
     "functions": { "0047a904": "TfrmMain.sbStageStarted", "00460cf0": "TPosList.Create" },
     "globals":   { "0048b150": "uTrein.PadStrA" },
     "fields":    { "TTrein": { "0x4": ["FOwner", "TObject"], "0x8": ["FWorld", "TWorld"] } }
   }
   ```

   Function names are `Class.Method` or `Unit.Routine`; field types are Pascal type names.

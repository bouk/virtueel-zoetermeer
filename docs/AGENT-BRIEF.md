# Brief for decompilation agents

You are part of a team decompiling **Virtueel Zoetermeer** (`ROS.exe` v1.1, Delphi 5, 2003), a
Dutch educational city-building game, into Object Pascal source. The source is later built with
Free Pascal for Apple Silicon macOS and WebAssembly, so it must be faithful *and* portable.

Repository: `/home/bouke/zoetermeer`. Run every tool through the Nix dev shell from the repo root:
`nix develop --command <cmd>` (fpc, python with pefile/capstone, ghidra, wine are all there).

## Read first

1. `docs/DECOMP.md` — conventions (dialect, faithfulness, class layout, naming, portability,
   the `symbols/names/<Unit>.json` you must write). Follow it exactly.
2. `src/game/uString.pas` + `symbols/names/uString.json` — a finished unit, use as the style
   reference.

## Material per unit

* `build/decomp-1.1/<Unit>.s` — symbolized disassembly, every routine of the unit in address
  order, including try/except/finally handler blocks. **Primary source of truth.**
* `build/decomp-1.1/<Unit>.c` — Ghidra decompilation of the same routines (good for structure;
  wrong about Delphi strings/exceptions/register calling convention details; verify with `.s`).
* `symbols/classes-1.1.md` — every project class: VMT slots (NEW/override, with the ancestor
  that introduced each slot), published fields/methods/properties with offsets/accessors,
  dynamic (message) methods, instance sizes.
* `symbols/vcl-vmt-slots.md` — slot → method names for VCL classes (`call [reg+0x34]` on a
  `TStrings` is `Add`, etc.). Field names of VCL classes already appear in the Ghidra C.
* `symbols/ros-1.1.tsv` — all known symbols (`address kind unit name`); `s` rows are string
  literals (address of the characters, name = length).
* `build/dfm-1.1/*.txt` — form resources as text (component names/types/events).
* `symbols/unit-deps-1.1.json`, `symbols/units-1.1.json` — unit ranges and cross-references.
* To look at raw bytes or data (typed constants, sets, tables in DATA/BSS), use python with
  `tools/delphi.py`: `im = delphi.Image('orig/game-1.1/ROS.exe'); im.bytes(va, n)`.

## Coordination

* Several agents work in parallel on different units. Only write the files assigned to you.
* **Write the `interface` section of each of your units first** (types, class declarations with
  all fields and methods, globals, routine headers) and save it early, with implementation
  stubs if needed, so others can build on it. Then fill in implementations.
* When you use a unit owned by someone else, read `src/game/<ThatUnit>.pas` if it exists and use
  its names. If it does not exist yet, use the names from `symbols/classes-1.1.md` /
  `symbols/ros-1.1.tsv`, and for anything unnamed pick a sensible name and list it in the
  `"assumes"` section of your names JSON (`{"assumes": {"TWorld": ["FCells: TCellList (+0x8)"]}}`)
  so integration can reconcile.
* The platform layer (`src/compat/`: `Windows`, `Messages`, `Graphics`, `Controls`, `Forms`,
  `StdCtrls`, `ExtCtrls`, `ddraw`, `MMSystem`, …) is written by another agent. Write game code
  against the normal Delphi 5 API; never work around missing compat pieces in game code.
* **Do not** commit to git, run `tools/refresh.sh`, or run Ghidra (shared state; the coordinator
  does that). Do not edit files outside your assignment, except new notes under `docs/notes/`.

## Checking your work

* `nix develop --command tools/build.sh src/game/<Unit>.pas` compiles a unit with FPC. It needs
  the compat units your unit uses; if they do not exist yet, the compile fails on the `uses`
  clause — that is expected early on. Re-try near the end of your work; fix every error that is
  in *your* code. Report compat gaps instead of patching around them.
* Re-read each routine against the `.s` once more before you finish: every branch, every call,
  every constant, every string.

## Final report (your last message)

Short: units done, any routines you could not decompile confidently (address + why), names you
assumed for other units' members, compat API you needed that looked unusual.

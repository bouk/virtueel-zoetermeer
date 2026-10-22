# WebAssembly build notes

## Toolchain

* `fpc-wasm` (flake package `.#fpc-wasm`, `nix/fpc-wasm.nix`): FPC trunk pinned to a known-good
  snapshot commit, cross compiler `ppcrosswasm32` for **wasm32-wasip1**, RTL built with
  `-CTbfexceptions` (branchful exceptions: Delphi `try/except/finally` work without the wasm
  exception-handling proposal). The wrapper presets `-Twasip1 -CTbfexceptions` and the RTL unit
  paths; `wasm-ld` comes from lld.
* `wasm-opt` (binaryen) for Asyncify.

## Blocking calls: Asyncify

The game is written around blocking loops (`Application.Run`, `ShowModal`, `MessageBox`, sleeps).
A browser cannot block, so the platform layer funnels every wait into a few imported host
functions (e.g. "wait for next event / frame"), and the module is post-processed with Asyncify so
those imports can suspend the whole call stack and resume it from a JS callback:

```
fpc-wasm -Mdelphi prog.pas
wasm-opt --enable-reference-types --enable-bulk-memory --enable-bulk-memory-opt \
         --enable-mutable-globals --enable-sign-ext --enable-nontrapping-float-to-int \
         --enable-multivalue -O1 --asyncify \
         --pass-arg=asyncify-imports@zm.wait prog.wasm -o prog.async.wasm
```

* Do **not** use `--all-features`: binaryen then emits import kinds browsers/node reject.
* Verified with `web/proto/asyncify_test.pas` + `web/proto/run.mjs` (minimal Asyncify driver and
  WASI subset under node): three suspend/resume cycles through an imported `zm.wait`, then an
  exception raised and caught after resuming.
* FPC trunk also has JSPI support (`__fpc_wasm_suspender`); JSPI could replace Asyncify once all
  target browsers (notably Safari) support it.

## Game data

The repository never contains game data. The web build asks the player for their own copy
(the original zip / installer or an installed game folder), unpacks it in the browser and keeps it
in IndexedDB; the WASI file layer serves it to the game.

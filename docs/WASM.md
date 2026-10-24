# WebAssembly-buildnotities

## Toolchain

* `fpc-wasm` (flake-pakket `.#fpc-wasm`, `nix/fpc-wasm.nix`): FPC trunk vastgepind op een bekende goede
  snapshot-commit, cross-compiler `ppcrosswasm32` voor **wasm32-wasip1**, RTL gebouwd met
  `-CTbfexceptions` (branchful exceptions: Delphi `try/except/finally` werken zonder het
  wasm-exception-handling-voorstel). De wrapper zet `-Twasip1 -CTbfexceptions` en de RTL-unitpaden;
  `wasm-ld` komt uit lld.
* `wasm-opt` (binaryen) voor Asyncify.

## Tekstweergave

De browserbuild gebruikt grijswaarden-antialiasing voor TrueType-tekst, ook bij
kleine lettergroottes. De canvas wordt vloeiend geschaald naar het venster;
pixelated scaling maakt tekststreken bij fractionele vergrotingen ongelijk dik.
De native GDI-weergave behoudt de Windows/Wine-regels voor differentiële tests.

## Blokkerende aanroepen: Asyncify

Het spel is gebouwd rond blokkerende lussen (`Application.Run`, `ShowModal`, `MessageBox`, sleeps).
Een browser kan niet blokkeren, dus de platformlaag leidt elke wacht via een paar geïmporteerde
host-functies (bijv. "wacht op volgende event / frame"), en de module wordt nabewerkt met Asyncify
zodat die imports de hele aanroepstack kunnen opschorten en vanuit een JS-callback kunnen hervatten:

```
fpc-wasm -Mdelphi prog.pas
wasm-opt --enable-reference-types --enable-bulk-memory --enable-bulk-memory-opt \
         --enable-mutable-globals --enable-sign-ext --enable-nontrapping-float-to-int \
         --enable-multivalue -O1 --asyncify \
         --pass-arg=asyncify-imports@zm.wait prog.wasm -o prog.async.wasm
```

* Gebruik **niet** `--all-features`: binaryen zendt dan importsoorten uit die browsers/node weigeren.
* Geverifieerd met `web/proto/asyncify_test.pas` + `web/proto/run.mjs` (minimale Asyncify-driver en
  WASI-subset onder node): drie opschort-/hervatcycli via een geïmporteerde `zm.wait`, daarna een
  exception die na het hervatten wordt gegooid en gevangen.
* FPC trunk heeft ook JSPI-ondersteuning (`__fpc_wasm_suspender`); JSPI kan Asyncify vervangen zodra alle
  doelbrowsers (met name Safari) het ondersteunen.

## Spelgegevens

De repository bevat geen originele spelbestanden. De build verpakt ze in `data.json` en
`data.pack`, die de browserhost in het WASI-bestandssysteem in het geheugen laadt.

## Toetsenbord en bewaarde steden

Het invoercanvas krijgt bij een muisklik expliciet toetsenbordfocus, ook in een iframe.
Dat is nodig omdat `preventDefault` op de klik de normale focusoverdracht verhindert.

Bij het sluiten van een beschreven bestand bewaart de browserhost de inhoud in
`localStorage` onder `zoetermeer:file:<pad>`. Bij het starten worden die bestanden
hersteld voordat het spel begint. Bewaarde steden blijven dus na herladen beschikbaar
in dezelfde browser en opslagcontext. Ze worden niet naar een server gestuurd en niet
als download op de computer gezet. Wissen van sitegegevens verwijdert ook de steden.
Een iframe kan een andere opslagcontext hebben dan het rechtstreeks geopende spel;
als de browser opslag blokkeert, is bewaren over herladen heen niet mogelijk.
Opslag in een iframe op een andere site kan tijdelijk zijn en verdwijnen bij het
afsluiten van de browser, ook als bewaren en herladen binnen die sessie werken.

Controles voor toetsenbordfocus, tekstinvoer en opslag na herladen:

```sh
node --test web/test/host.test.mjs
```

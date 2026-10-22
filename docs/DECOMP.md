# Decompilatieconventies

Deze regels gelden voor elke unit in `src/game/`. Ze bestaan zodat units die door verschillende
mensen (of agenten) geschreven zijn goed op elkaar aansluiten, en zodat de broncode herleidbaar
blijft tot het oorspronkelijke binaire bestand.

Doelbinaire: **v1.1 `ROS.exe`** (sha256 `6bbd1f71c719…`, zie `orig.sha256`), gebouwd met Delphi 5.

## Referentiemateriaal

| Wat | Waar |
|---|---|
| Codebereiken van units, initialisatievolgorde | `symbols/units-1.1.json`, `symbols/project-ranges-1.1.txt` |
| Symbolen (functies, VMT's, globals, stringliterals) | `symbols/ros-1.1.tsv` |
| Klassencatalogus (VMT-slots, RTTI-velden/eigenschappen/methoden) | `symbols/classes-1.1.md` |
| Ghidra-C en gesymboliseerde disassemblage per unit | `build/decomp-1.1/<Unit>.c`, `.s` (`tools/ghidra/analyze.sh 1.1`) |
| Formulierlay-outs (DFM als tekst) | `build/dfm-1.1/*.txt` (`python tools/dfm.py orig/game-1.1/ROS.exe build/dfm-1.1`) |
| Verwijzingen tussen units | `symbols/unit-deps-1.1.json` |

Delphi 5-aanroepconventie `register`: de eerste drie ordinale/pointer-argumenten staan in EAX, EDX,
ECX (bij methoden is `Self` in EAX); de rest wordt van links naar rechts op de stack gezet; het
resultaat staat in EAX (Int64 in EDX:EAX, floating point in ST0). Strings zijn referentie-geteld
`AnsiString`; een verborgen resultaat-pointer wordt als laatste parameter meegegeven bij string- en
record-resultaten. `Ghidra` is op deze conventie ingesteld, maar de uitvoer voor exception-frames
(`FS:[0]`), stringtijdelijke waarden (`@LStrClr`, `@LStrAsg`, `@LStrCatN`) en `try/finally`-blokken
moet nog steeds handmatig naar Pascal worden teruggelezen.

## Dialect

* Schrijf **Delphi 5 Object Pascal**. Elke unit moet ook met **Free Pascal 3.2** compileren:
  begin elke unit met `{$I zm.inc}` (zet `{$MODE DELPHI}` e.d. onder FPC).
* Gebruik de Delphi 5 RTL/VCL-API precies zoals het origineel dat deed (`Windows`, `Messages`, `Classes`,
  `Graphics`, `Controls`, `Forms`, `StdCtrls`, `ExtCtrls`, `ddraw`, `MMSystem`, …).
  **Port niets.** De portable herbouw levert die units in `src/compat/`; de spelcode roept DirectDraw
  en Win32 aan precies zoals het origineel.
* Houd de oorspronkelijke `uses`-lijsten aan voor zover die afgeleid kunnen worden (interface versus implementatie).

## Getrouwheid

* Reproduceer de logica exact, inclusief vreemde constructies en bugs. Verbeter de code niet.
  Lijkt iets op een bug, laat het staan en voeg een `{ NOTE: … }`-commentaar toe.
* Houd **routines in adresvolgorde** binnen een unit, en zet het adres in een commentaar direct boven
  elke routine: `{ @0047A904 }`. Geneste procedures staan in het binaire bestand vóór hun ouder; houd ze
  in de broncode genest.
* Stringliterals moeten byte-identiek zijn (ze zijn Windows-1252; schrijf niet-ASCII-tekens als
  `#233` e.d.).
* Numerieke constanten: schrijf ze zoals de broncode waarschijnlijk had (`$FF`, `1024`, `clBlack`,
  `mrOk`, `VK_LEFT`), niet als ruwe hex waar een benoemde constante duidelijk past.
* Floating point: Delphi rekent in 80-bit extended. Houd de typen `Real`/`Double`/`Single`/`Extended`
  zoals de loads/stores van de code laten zien (`FLD qword` = Double, `dword` = Single, `tword` = Extended).

## Klassen

* De volgorde van velddeclaraties moet de originele **veldoffsets** reproduceren (Delphi 5 lijnt velden
  in klassen uit op hun natuurlijke grootte, max 8 (`Double` op 8, zie `docs/SCHAKELAARS.md`); records volgen `{$A+}`). Zet de offset in een commentaar:
  `FWorld: TWorld; { +0x1A4 }`.
* Virtuele methoden moeten in **VMT-slotvolgorde** worden gedeclareerd. Een slot dat in
  `symbols/classes-1.1.md` als `NEW` is gemarkeerd krijgt `virtual;` (of `virtual; abstract;`), een override
  krijgt `override;`. Berichtafhandelaars (dynamische tabelingangen met Windows-berichtid's) krijgen
  `message WM_xxx;`.
* Published-secties moeten velden/methoden/eigenschappen in RTTI-volgorde bevatten (zoals in de catalogus).
* Namen: gebruik de RTTI/published-namen waar die bestaan. Benoem al het overige in de stijl van het
  origineel: enginecode is Engels (`FFrameList`, `SetPriority`), spelcode mengt Nederlandse domeintermen
  (`Wijk`, `Huisprijs`, `Overlast`, `Reistijd`). Getter- en setternamen volgen `Get<Prop>`/`Set<Prop>`;
  privévelden `F<Prop>`.

## Portabiliteitsregels (zodat dezelfde broncode bouwt voor macOS arm64 en WebAssembly)

* Ga nooit uit van `SizeOf(Pointer) = 4`. Waar het origineel pointers naar `Integer` casts (bijv. objecten
  opslaan in `Tag` of in een `TList` van integers), gebruik `PtrInt`/`PtrUInt` (voor Delphi 5 gedeclareerd in
  `zm.inc`).
* Alles dat naar of uit **bestanden** wordt geschreven of gelezen (savegames, datafiles) moet vaste-grootte-typen
  gebruiken (`Longint`, `SmallInt`, `Byte`, `Single`, `Double`, `ShortString[N]`) en `packed record`s
  waarvan de lay-out de on-disk-bytes van Delphi 5 exact reproduceert. Becommentarieer de verwachte recordgrootte.
* `Integer` is in beide compilers 32-bit (`{$MODE DELPHI}`); `Cardinal`/`Longword` eveneens.

## Uitvoer per unit

1. `src/game/<Unit>.pas` (of `.dpr` voor het programma).
2. `symbols/names/<Unit>.json`: de namen die je hebt toegekend, zodat de volgende Ghidra-export ze toont:

   ```json
   {
     "functions": { "0047a904": "TfrmMain.sbStageStarted", "00460cf0": "TPosList.Create" },
     "globals":   { "0048b150": "uTrein.PadStrA" },
     "fields":    { "TTrein": { "0x4": ["FOwner", "TObject"], "0x8": ["FWorld", "TWorld"] } }
   }
   ```

   Functienamen zijn `Klasse.Methode` of `Unit.Routine`; veldtypen zijn Pascal-typenamen.

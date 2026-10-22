# Compilerbuild en schakelaars van ROS.exe

Dit document legt vast met welke Delphi-build en welke compilerschakelaars `ROS.exe` v1.1 is gebouwd
(PLAN.md, fase 1). We hebben geen Delphi 5-compiler, dus we hebben geen probe-units gecompileerd.
Alles hieronder is afgeleid uit **statisch bewijs** in het binaire bestand. Het bewijs wordt opnieuw
berekend door:

```
nix develop --command python tools/schakelaars.py            # volledig, met kb5.bin (~12 s)
nix develop --command python tools/schakelaars.py --zonder-kb  # zonder de vergelijking met de KB (~5 s)
```

Het hulpmiddel ontleedt de 754 routines van de 44 projectunits (`uString` t/m `Ros`,
`$0045F98C`-`$004872CC`) recursief vanaf de functies in `symbols/ros-1.1.tsv`. Het volgt daarbij sprongen,
case-tabellen en exceptiehandlers. Daarna telt het per schakelaar de codepatronen. Ook vergelijkt het de
gelinkte RTL/VCL met de IDR-kennisbank `orig/kb/kb5.bin`.

Zekerheid: **zeker** = het binaire bestand laat geen andere instelling toe; **waarschijnlijk** = sterk
indirect bewijs; **onbekend** = niet waarneembaar in het exe, dus kiezen we de Delphi 5-standaard.

## Vastgelegde schakelaars

Projectbrede instelling (dcc32-opdrachtregel; `tools/bouw-delphi.sh` leest dit blok):

```dcc32
-$A+ -$B- -$C+ -$D+ -$G+ -$H+ -$I+ -$J+ -$L+ -$M- -$O+ -$P+ -$Q- -$R- -$T- -$U- -$V+ -$W- -$X+ -$Y- -$Z1
```

Let op: in een shell moet `$` gequote worden (`'-$A+'`).

Dezelfde instelling als directieven:

```pascal
{$A+,B-,C+,D+,G+,H+,I+,J+,L+,M-,O+,P+,Q-,R-,T-,U-,V+,W-,X+,Y-,Z1}
{$M 16384,1048576}   { standaard; imagebase $00400000 ook standaard }
```

Afwijkingen per unit (staan al in `src/game`): **`{$R+}` bovenaan `uSprite.pas` en `Sprbehav.pas`**.
Alle andere instellingen zijn in elke unit gelijk.

Stackgrootte en imagebase zijn de standaardwaarden (PE-kop: commit 16384, reserve 1048576, base
`$400000`). Daarom staan ze niet op de dcc32-regel. Het programma is zonder runtimepackages gelinkt
(PACKAGEINFO: 0 vereiste packages) en zonder TD32-debuginfo (geen `-V`; er staat niets na de laatste sectie).

| Schakelaar | Waarde | Zekerheid | Kern van het bewijs |
|---|---|---|---|
| `$R` | `-`, maar `+` in uSprite en Sprbehav | zeker (per unit met bewijs) | 20 × `@BoundErr` alleen in die twee units; 114 × `Round`/`Trunc` zonder controle in 10 andere units |
| `$Q` | `-` | zeker | `@IntOver` is niet gelinkt; 0 × `jo`/`jno`/`into` |
| `$I` | `+` | zeker | 10 van de 10 I/O-aanroepen worden gevolgd door `@_IOTest` |
| `$O` | `+` | zeker | registervariabelen, verborgen aflopende lustellers, in elke unit |
| `$W` | `-` | zeker | 434 van de 754 routines hebben geen `push ebp; mov ebp,esp` |
| `$A` | `+` (natuurlijk, tot 8) | zeker | 27 uitlijningsgaten, 0 packed; `Double` uitgelijnd op 8 |
| `$H` | `+` | zeker | 906 × `@LStr*`; gepubliceerde `string`-properties zijn `tkLString` |
| `$B` | `-` | zeker | 0 gecombineerde setcc-paren bij ~115 samengestelde voorwaarden in de bron |
| `$U` | `-` | zeker | 115 × `fdiv` inline; geen `@FSafeDivide` gelinkt |
| `$Z` | `1` | zeker | project-enums hebben `otUByte` in de RTTI en worden met byte-toegangen gelezen |
| `$M` | `-` | zeker | 33 projectklassen zonder RTTI; alleen TPersistent-afstammelingen hebben RTTI |
| `$X` | `+` | zeker | 18 functieresultaten worden weggegooid (bijv. `TList.Add`, `ShowModal`) |
| `$J` | `+` (standaard) | onbekend | er wordt naar 9 geïnitialiseerde globals geschreven; const of var is niet te onderscheiden |
| `$C` | `+` (standaard) | onbekend | `@Assert` is niet gelinkt, dus er zijn geen asserties in de bron |
| `$T`, `$V`, `$P` | standaard | onbekend | alleen typecontrole; geen codeverschil |
| `$G` | `+` (standaard) | onbekend | heeft alleen effect met packages |
| `$D`, `$L`, `$Y` | vrij te kiezen | niet waarneembaar | staan alleen in `.dcu`/`.map`/TD32; het exe bevat geen debuginfo |

## Bewijs per schakelaar

### `$R` bereikcontrole: `-`, met `{$R+}` in uSprite en Sprbehav (zeker)

`@BoundErr` (`$00402E2C`, `mov al,4; jmp Error`) is gelinkt. In de hele bibliotheekcode wordt het
**nergens** aangeroepen (bytescan: 0 aanroepen). In de projectcode wordt het precies 20 keer aangeroepen:

* **uSprite**: alle 16 aanroepen van `@ROUND` worden gevolgd door de Int64→Integer-controle. Er is geen
  enkele ongecontroleerde aanroep. Voorbeeld uit `TSprite.SpeelReeksVanaf`:
  ```
  0046A574  call @ROUND
  0046A579  push eax
  0046A57A  sar eax, 0x1f
  0046A57D  cmp eax, edx
  0046A57F  pop eax
  0046A580  je 0x46a587
  0046A582  call @BoundErr
  ```
* **Sprbehav**: vier soorten controle. Een gecontroleerde Round (`$00471781`), een indexcontrole op een
  open array in `TBehavControl.Create` (`test edi,edi; jl; cmp edi,[ebp+8]; jle; call @BoundErr`), een
  subbereikcontrole voordat `word ptr [ebx+0x20A]` wordt geschreven (`cmp eax,0x7ffe; jbe; call
  @BoundErr`) en een indexcontrole op een lange string na `UniqueString` (`cmp edx,[eax-4]; jc; call
  @BoundErr`, `$00471951`).
* **Alle andere units** met `Round`/`Trunc` (uTool 1, uTextBalloon 39, uSpritebox 15, uTiming 3,
  Uview 12, uAutos 8, uTrein 9, Fmain 12, Uworld 9, Uconst 6) hebben **0** controles. Hun geïndexeerde
  geheugentoegangen (Uworld 98, Fmain 49, uAutos 48, uTextBalloon 37, …) hebben ook geen controles.

`$R` is een lokale schakelaar. Projectbreed staat hij uit; de twee sprite-engine-units hebben `{$R+}` in
de bron. uSprite heeft eigen versiestrings (`'2.5c'`, `'odi et amo'`); het is waarschijnlijk een
third-party-unit met eigen directieven. Units zonder Round, Trunc of arrayindexering (uString, SprBmp,
Sprframe, uSequence, …) leveren geen bewijs. Voor die units nemen we de projectinstelling `$R-` aan.
De enige ongecontroleerde geïndexeerde toegang in Sprbehav (`$004704A9`) is de door de compiler
gegenereerde kopieerlus voor een open-array-waardeparameter. Die is nooit gecontroleerd.

### `$Q` overloopcontrole: `-` (zeker)

`@IntOver` (`mov al,5; jmp Error`) komt nergens in CODE voor; de smart linker heeft het weggelaten
omdat niemand het aanroept. Er staan ook geen `jo`/`jno`/`into`-instructies in de projectcode. Daaruit
volgt: geen enkele gelinkte unit (ook RTL/VCL) is met `{$Q+}` gecompileerd op een plek waar rekenwerk
staat.

### `$I` I/O-controle: `+` (zeker)

Het project gebruikt bestands-I/O in SprBmp (`BewaarPalet`: `@RewritFile`, `@BlockWrite`, `@Close`) en
Uconst (tekstbestand `Objecten.csv`: `@ResetText`, `@ReadLString`, `@ReadLn`, `@EofText`, `@Close`).
Elk van de 10 aanroepen wordt gevolgd door `call @_IOTest` (`$004027BC`):

```
00462664  call @RewritFile
00462669  call @_IOTest
```

`IOResult` wordt nergens aangeroepen. Er is dus ook geen lokale `{$I-}`.

### `$O` optimalisatie: `+` (zeker)

* 492 van de 754 routines bewaren `ebx`/`esi`/`edi` en gebruiken die als registervariabelen. Bij het begin
  van een routine worden parameters 304 keer naar een register gekopieerd (`mov ebx, eax`) en maar 93 keer
  naar de stack. Die 93 gevallen zijn nodig door try/finally, door adresname of door geneste procedures.
  Met `$O-` gebruikt Delphi 5 geen registervariabelen. Elke unit met niet-triviale routines gebruikt ze.
* 109 + 31 for-lussen hebben de verborgen, aflopende teller van de optimizer (`dec esi; jne terug`, of
  `dec dword ptr [ebp-x]` bij registerdruk), naast een oplopende indexvariabele. Een voorbeeld is
  `TBehavControl.Create`: `inc esi; xor edi,edi; … inc edi; dec esi; jne`.
* Frameloze routines met aanroepen (323, zie `$W`) zijn alleen mogelijk met `$O+`.

### `$W` stackframes: `-` (zeker)

434 van de 754 routines beginnen niet met `push ebp; mov ebp,esp`. 323 daarvan roepen zelf andere routines
aan. Met `$W+` zou elke routine een frame hebben. Voorbeelden:

```
uTool.IMaximum   00460B34  cmp edx, eax / jl / mov eax, edx / ret
uString.IsCijfer           cmp al, 0x30 / jb / cmp al, 0x39 / jbe / xor eax, eax / ret
```

### `$A` uitlijning: `+` (zeker)

`tools/schakelaars.py` leest de record- en klassedeclaraties in `src/game` met offsetcommentaren
(`{ +0x.. }`). Die offsets zijn uit de geheugentoegangen van de code afgeleid. Het hulpmiddel zoekt alle
paren van opeenvolgende velden waar een packed lay-out en een uitgelijnde lay-out verschillen:
**27 volgen `{$A+}`, 0 volgen packed**. Elk tweede veld wordt in de code aangesproken op de uitgelijnde
offset. Voorbeelden:

* record `TOvergang` (uTrein): `NieuwNr: Byte @+2`, `DX: Integer @+4` (packed: +3), 319 toegangen `[reg+4]`.
* record `TInhoudInfo` (Uconst): `Uniek: Boolean @+0xC`, `Page: string @+0x10`.
* klasse `TPixie`: `FVisible: Boolean @+0x24`, `FLeft: SmallInt @+0x26` (uitgelijnd op 2).

8-byte-velden worden op **8** uitgelijnd, niet op 4. Dat geldt in records én in klassen (4 van de 4
gevallen):

* record `TNiveau` (Usett): `OpenWijk: Integer @+0x20`, `TevredenDrempel: Double @+0x28`.
* klasse `TCell` (Uworld): `Vorige @+0x40`, `Afstand: Double @+0x48`.
* klasse `TSprite`: `FGestopt: Boolean @+0xA0`, `FSchaal: Double @+0xA8`.
* klasse `TWorld`: `Bestemmingen @+0x1FC0`, `Reistijd: Double @+0x1FC8`.

Dit is het gedrag van Delphi 5 `{$A+}`. `docs/DECOMP.md` zegt "lijnt velden in klassen uit op hun
natuurlijke grootte, max 4". Voor `Double`-velden klopt dat niet: die gaan op 8.

### `$H` lange strings: `+` (zeker)

De projectcode roept 906 keer een `@LStr*`-helper aan en maar 19 keer een `@PStr*`-helper. Die 19 horen
bij expliciete `ShortString`/`string[N]`-typen, zoals de gepubliceerde property `TSprite.CurrentFrame:
TName`, die `tkString` is. De 5 gepubliceerde properties van type `string` (`TSprite.About`,
`TFastTimer.About`, `TComment.Caption`, `TTextBalloon.BalloonText`, `TSpriteBox.Reload`) hebben RTTI-soort
`tkLString`. `string`-velden in records nemen 4 bytes in (`TInhoudInfo`: `Name @+0`, `Beschrijving @+4`).

### `$B` booleaanse evaluatie: `-` (zeker)

De gedecompileerde bron bevat ongeveer 115 samengestelde voorwaarden (`if (…) and (…)`). In de code staan
2070 voorwaardelijke sprongen en 24 setcc-instructies. **Geen enkel** setcc-paar wordt met `and`/`or`
gecombineerd. Met `$B+` zou elke `A and B` als `setcc al; setcc dl; and al, dl` gecompileerd worden.

### `$U` Pentium-veilige FDIV: `-` (zeker)

De projectcode bevat 115 inline `fdiv`-instructies (`fdiv`/`fdivr`/`fidiv`/…). `@FSafeDivide` en
`@FSafeDivideR` zijn niet gelinkt.

### `$Z` grootte van opsommingen: `1` (zeker)

De RTTI van de enumtypen uit de projectunits heeft `OrdType = otUByte`: `THitTest` (`$004695E4`),
`THandleBackGround` (`$0046C9D0`) en `TPlot` (het basistype van de set `TPlotMode`, `$00463C78`). Velden
van zo'n type worden alleen met byte-toegangen gelezen en geschreven: `TSprite.FTreffertest @+0x96`
(4×), `TSpriteBox.FAchtergrondModus @+0x270`, `TformDebugShow.FKind @+0x2E0`.

### `$M` RTTI: `-` (zeker)

28 projectklassen hebben RTTI. Ze stammen allemaal af van `TPersistent`, dat zelf met `{$M+}` is
gedeclareerd. De 33 klassen die direct van `TObject`/`TList` afstammen (`TPos`, `TWorld`, `TCell`, `TTrein`,
`TSettings`, …) hebben geen RTTI-pointer in de VMT. Met `$M+` zouden ze die hebben.

### `$X` uitgebreide syntaxis: `+` (zeker)

Op 18 plaatsen wordt een functie aangeroepen en wordt EAX daarna meteen overschreven. Het resultaat wordt
dus weggegooid. Met `$X-` mag dat niet. Voorbeelden:

```
TFrameList.Add          00464B95  call TList.Add          (: Integer)  ; 00464B9A mov eax, esi
TformDebugShow.ToonAfbeelding  004618ED  call TCustomForm.ShowModal ; 004618F2 xor eax, eax
```

### `$J` schrijfbare getypeerde constanten: `+` aangenomen (onbekend)

Projectcode schrijft direct naar 9 adressen in DATA (geïnitialiseerde data), zoals
`uSpritebox.TekenDiepte`, `uTiming.InTimerLus` en `uQuickDirectX.DirectXActief`. Getypeerde constanten en
geïnitialiseerde globale variabelen (`var X: Integer = 0;`) komen allebei in DATA terecht en zijn in het
exe niet van elkaar te onderscheiden. De Delphi 5-standaard is `$J+`. Die is compatibel met beide
lezingen. De lokale `{$J+}…{$J-}`-blokken in `src/game` zijn daarmee overbodig maar onschadelijk.

### `$C`, `$T`, `$V`, `$P`, `$G` (onbekend, standaard)

`@Assert` is niet gelinkt. De bron bevat dus geen `Assert`-aanroepen, en `$C` maakt niets uit. `$T`
(getypeerde `@`), `$V` (var-strings) en `$P` (open strings) veranderen alleen de typecontrole. `$G`
werkt alleen met packages. We nemen de Delphi 5-standaard: `C+ T- V+ P+ G+`.

### `$D`, `$L`, `$Y` (niet waarneembaar)

Debug-, lokale-symbool- en referentie-informatie staat alleen in `.dcu`, `.map` en TD32-debuginfo. Het exe
heeft geen TD32-blok. De regel hierboven kiest `D+ L+ Y-`, zodat een `.map` met `-GD` regelnummers bevat.
Dit verandert geen enkele byte in CODE of DATA.

## Compilerbuild

**Delphi 5 (zeker), Professional-editie (zeker), waarschijnlijk met Update Pack 1.**

* **Delphi 5.** Linkerversie 2.25 en tijdstempel `0x2A425E19` horen bij alle Borland-linkers van Delphi
  2-7. Het tijdstempel is een vaste waarde (19-6-1992), dus er is geen builddatum. Het exe heeft geen
  versieresource. Wat de versie vastlegt is de vergelijking met de Delphi 5-kennisbank van IDR: van de
  3090 benoemde bibliotheekroutines zijn er **3087 (99,9%) byte-identiek** (2938 via de scan en 149 korte
  of onuitgelijnde). Eén routine (`Unit41.Finalization`) staat niet in de KB. De RTL/VCL van Delphi 6/7
  wijkt overal af.
* **Professional.** De `DVCLAL`-resource is `A28CDF98 7B3C3A79 26713F09 0F2A2517`. Dat is de bekende
  waarde voor de Professional-editie (Standard: `23785D23…`, Enterprise: `263D4F38…`).
* **Update Pack 1 (waarschijnlijk).** Zes bibliotheekroutines bestaan in de KB, maar verschillen buiten
  de relocaties van de gelinkte code:

  | Routine | Verschil (KB → exe) |
  |---|---|
  | `Classes.TList.Put` (`$0040FFFC`) | `Notify(Item, lnDeleted)` → `Notify(Temp, lnDeleted)`: de KB meldt het nieuwe item als verwijderd (bug), het exe het oude (correct). Eén byte: `mov edx, edi` → `mov edx, eax`. |
  | `Menus.TPopupMenu.Popup` (`$0043E65C`) | het exe zet de menu-animatievlaggen (`TPM_*ANIMATION`, `shl 0xA`) alleen als `Win32MajorVersion > 4` of `(= 4) and Win32MinorVersion > 0`: een besturingssysteemcontrole die in de KB ontbreekt |
  | `SysUtils.GetExceptionObject` (`$0040BBC4`) | het exe herkent extra C++-excepties (`cmp [eax], 0x0EEFFACE`) |
  | `SysInit.InitThreadTLS` (`$004068C4`) | `if TlsIndex < 0` (`cmp …,0; jge`) → `if TlsIndex = -1` (`cmp …,-1; jne`) |
  | `Forms.TApplication.Idle` (`$0043641C`) | except-blok met `on`-tabel (`@HandleOnException`) → kaal `except` (`@HandleAnyException`) |
  | `Menus.TMenu.DispatchPopup` (`$0043D3DC`) | andere evaluatie van het `Handled`-resultaat (`mov ebx,eax; or bl,al`) |

  Alle afwijkingen zitten in units die Borland als `.dcu` leverde (SysInit, SysUtils, Classes, Forms,
  Menus). Ze zijn klein en zien eruit als bugfixes. De eerste drie gaan duidelijk van "fout/minder" naar
  "correct/meer". De enige algemene RTL/VCL-update voor Delphi 5 was Update Pack 1. Als kb5.bin uit de
  originele Delphi 5-dcu's (build 5.62) is opgebouwd, is ROS.exe met **Delphi 5 + Update Pack 1** gebouwd.
  Uit welke build kb5.bin precies komt, kunnen we niet controleren zonder de originele dcu's. Daarom is
  dit "waarschijnlijk" en niet "zeker". Het omgekeerde (KB = UP1, exe = basisversie) zou betekenen dat UP1
  deze fixes heeft teruggedraaid. Dat is niet aannemelijk.

## Wat een probe-unit toevoegt zodra Delphi 5 beschikbaar is

1. **Build bevestigen.** Link een leeg programma dat `TList.Put`, `TPopupMenu.Popup`,
   `GetExceptionObject`, `TApplication.Idle` en `TMenu.DispatchPopup` gebruikt, met Delphi 5 zonder UP1
   en met UP1. Vergelijk de bytes met de zes afwijkingen hierboven. Pas dan worden "Update Pack 1" en de
   herkomst van kb5.bin zeker. Controleer ook `dcc32` zonder argumenten: de banner geeft de build.
2. **Schakelaars per patroon.** Een unit met één routine per patroon (`Round` naar `Integer`, een
   indexering in een statische en een open array, `A and B`, een functieresultaat dat wordt weggegooid,
   een bladroutine, een for-lus, een record met `Byte`/`Integer`/`Double`, een enum-veld, een
   tekstbestand met `ReadLn`), gecompileerd met de regel hierboven. Die moet exact dezelfde instructies
   geven als de voorbeelden in dit document. Compileer daarna met één omgezette schakelaar om te zien dat
   het patroon verandert.
3. **Onbekende schakelaars.** `$J` blijft ook met een probe-unit onbeslist, omdat het exe geen verschil
   bevat. `$C`, `$T`, `$V` en `$P` maken alleen uit als de bron ze nodig heeft: een bron die met de
   standaardwaarden compileert en byte-identiek uitkomt, is dan voldoende.
4. **Regressie.** Draai `tools/schakelaars.py` ook op het zelfgebouwde exe (met een eigen symbooltabel).
   Elke tabel moet dezelfde tellingen geven als het origineel.

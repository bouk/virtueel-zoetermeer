unit ZMPlatform;

{ De smalle platformgrens van de compatlaag.

  Alles daarboven (vensterbeheer, GDI, VCL) is draagbare Pascal. Een backend levert: een
  venster dat het geëmuleerde scherm toont (een 32-bits XRGB-framebuffer), invoer-
  gebeurtenissen in schermcoördinaten met Windows-virtual-keycodes, tijd, slapen en een
  cursorvorm. De SDL3-backend staat in sdl3/ZMSdl3Backend.pas; een WebAssembly/JS-backend
  kan later dezelfde klasse implementeren.

  Een null-backend (geen venster, kloktijd) wordt gebruikt wanneer geen andere backend is
  geregistreerd of wanneer ZM_HEADLESS=1 is gezet; tests gebruiken hem samen met
  schermafbeeldingen. }

{$MODE DELPHI}{$H+}

interface

type
  TZMEventKind = (zeNone, zeQuit, zeMouseMove, zeMouseDown, zeMouseUp, zeMouseWheel,
    zeKeyDown, zeKeyUp, zeText, zeActivate, zeDeactivate, zeExpose, zeMouseLeave);

  TZMEvent = record
    Kind: TZMEventKind;
    X, Y: Integer;        { muispositie in schermcoördinaten }
    Button: Integer;      { 1 = links, 2 = rechts, 3 = midden }
    Key: Word;            { Windows-virtual-keycode }
    ScanCode: Word;
    Repeated: Boolean;
    Text: string[15];     { getypte Windows-1252-tekens (zeText) }
    Wheel: Integer;       { +120 = één klik van de gebruiker af }
    Shift, Ctrl, Alt: Boolean;
  end;

  TZMCursorShape = (zcArrow, zcIBeam, zcWait, zcCross, zcHand, zcSizeAll, zcSizeNS,
    zcSizeWE, zcSizeNWSE, zcSizeNESW, zcNo, zcAppStart, zcNone);

  TZMBackend = class
  public
    function Name: string; virtual;
    { open het uitvoervenster; W x H is de grootte van het geëmuleerde scherm }
    function Open(const Titel: string; Breedte, Hoogte: Integer): Boolean; virtual;
    procedure Close; virtual;
    procedure Resize(Breedte, Hoogte: Integer); virtual;
    { toon een beeld: Pixels zijn W x H 32-bits $00RRGGBB-waarden, Stride bytes per regel }
    procedure Present(Pixels: Pointer; Breedte, Hoogte, Regellengte: Integer); virtual;
    function PollEvent(out Gebeurtenis: TZMEvent): Boolean; virtual;
    { blokkeer tot een gebeurtenis binnenkomt of TimeoutMs verstreken is (-1 = oneindig) }
    procedure WaitEvent(TijdslimietMs: Integer); virtual;
    function Ticks: LongWord; virtual;             { milliseconden }
    function PerfCounter: Int64; virtual;
    function PerfFrequency: Int64; virtual;
    procedure Delay(Milliseconden: Integer); virtual;
    procedure SetTitle(const Tekst: string); virtual;
    procedure SetCursor(Vorm: TZMCursorShape); virtual;
    procedure Beep; virtual;
  end;

var
  { Wordt eenmaal per iteratie van de berichtenpomp aangeroepen (bij elke PeekMessage/
    GetMessage/WaitMessage, inclusief de modale lussen van ShowModal en MessageBox).
    Gebruikt door het differentiële-testharnas. }
  ZMIdleHook: procedure = nil;

procedure ZMRegisterBackend(Achterkant: TZMBackend; Prioriteit: Integer);
function ZMBackend: TZMBackend;
{ vervang de huidige backend door de null-backend (bijv. wanneer geen beeldscherm beschikbaar is) }
procedure ZMFallbackToNull;

{ Hulpfuncties die door backends en tests gedeeld worden }
function ZMUtf8ToCp1252(const Tekst: AnsiString): AnsiString;
function ZMSavePNG(const Bestandsnaam: string; Pixels: Pointer; Breedte, Hoogte, Regellengte: Integer): Boolean;

implementation

uses SysUtils
{$IFDEF UNIX}, BaseUnix, Unix{$ENDIF};

var
  GBackend: TZMBackend = nil;
  GPriority: Integer = -1;

procedure ZMRegisterBackend(Achterkant: TZMBackend; Prioriteit: Integer);
begin
  if GetEnvironmentVariable('ZM_HEADLESS') = '1' then
  begin
    Achterkant.Free;
    Exit;
  end;
  if Prioriteit > GPriority then
  begin
    if GBackend <> nil then GBackend.Free;
    GBackend := Achterkant;
    GPriority := Prioriteit;
  end
  else
    Achterkant.Free;
end;

function ZMBackend: TZMBackend;
begin
  if GBackend = nil then
  begin
    GBackend := TZMBackend.Create;
    GPriority := 0;
  end;
  Result := GBackend;
end;

procedure ZMFallbackToNull;
begin
  FreeAndNil(GBackend);
  GBackend := TZMBackend.Create;
  GPriority := 0;
end;

{ ---------------------------------------------------------------- null-backend }

function TZMBackend.Name: string;
begin
  Result := 'null';
end;

function TZMBackend.Open(const Titel: string; Breedte, Hoogte: Integer): Boolean;
begin
  Result := True;
end;

procedure TZMBackend.Close;
begin
end;

procedure TZMBackend.Resize(Breedte, Hoogte: Integer);
begin
end;

procedure TZMBackend.Present(Pixels: Pointer; Breedte, Hoogte, Regellengte: Integer);
begin
end;

function TZMBackend.PollEvent(out Gebeurtenis: TZMEvent): Boolean;
begin
  FillChar(Gebeurtenis, SizeOf(Gebeurtenis), 0);
  Result := False;
end;

procedure TZMBackend.WaitEvent(TijdslimietMs: Integer);
begin
  if TijdslimietMs < 0 then TijdslimietMs := 10;
  if TijdslimietMs > 0 then Delay(TijdslimietMs);
end;

function TZMBackend.PerfFrequency: Int64;
begin
  Result := 1000000;
end;

function TZMBackend.PerfCounter: Int64;
{$IFDEF UNIX}
var
  Tijdwaarde: TTimeVal;
begin
  fpgettimeofday(@Tijdwaarde, nil);
  Result := Int64(Tijdwaarde.tv_sec) * 1000000 + Tijdwaarde.tv_usec;
end;
{$ELSE}
begin
  Result := Int64(GetTickCount64) * 1000;
end;
{$ENDIF}

var
  StartCounter: Int64 = 0;

function TZMBackend.Ticks: LongWord;
begin
  if StartCounter = 0 then StartCounter := PerfCounter - 1000000;
  Result := LongWord((PerfCounter - StartCounter) * 1000 div PerfFrequency);
end;

procedure TZMBackend.Delay(Milliseconden: Integer);
begin
  if Milliseconden > 0 then SysUtils.Sleep(Milliseconden);
end;

procedure TZMBackend.SetTitle(const Tekst: string);
begin
end;

procedure TZMBackend.SetCursor(Vorm: TZMCursorShape);
begin
end;

procedure TZMBackend.Beep;
begin
end;

{ ---------------------------------------------------------------- hulpfuncties }

function ZMUtf8ToCp1252(const Tekst: AnsiString): AnsiString;
const
  Hoogtabel: array[$80..$9F] of Word = (
    $20AC, $0081, $201A, $0192, $201E, $2026, $2020, $2021, $02C6, $2030, $0160, $2039, $0152, $008D, $017D, $008F,
    $0090, $2018, $2019, $201C, $201D, $2022, $2013, $2014, $02DC, $2122, $0161, $203A, $0153, $009D, $017E, $0178);
var
  Positie, Resterend, Codepunt, Teller: Integer;
  Bytewaarde: Byte;
  Teken: AnsiChar;
begin
  Result := '';
  Positie := 1;
  while Positie <= Length(Tekst) do
  begin
    Bytewaarde := Byte(Tekst[Positie]);
    if Bytewaarde < $80 then begin Codepunt := Bytewaarde; Resterend := 0; end
    else if Bytewaarde and $E0 = $C0 then begin Codepunt := Bytewaarde and $1F; Resterend := 1; end
    else if Bytewaarde and $F0 = $E0 then begin Codepunt := Bytewaarde and $0F; Resterend := 2; end
    else if Bytewaarde and $F8 = $F0 then begin Codepunt := Bytewaarde and $07; Resterend := 3; end
    else begin Codepunt := Ord('?'); Resterend := 0; end;
    Inc(Positie);
    while (Resterend > 0) and (Positie <= Length(Tekst)) do
    begin
      Codepunt := (Codepunt shl 6) or (Byte(Tekst[Positie]) and $3F);
      Inc(Positie);
      Dec(Resterend);
    end;
    Teken := '?';
    if (Codepunt < $80) or ((Codepunt >= $A0) and (Codepunt <= $FF)) then Teken := AnsiChar(Codepunt)
    else
      for Teller := $80 to $9F do
        if Hoogtabel[Teller] = Codepunt then begin Teken := AnsiChar(Teller); Break; end;
    Result := Result + Teken;
  end;
end;

{ minimale PNG-schrijver (opgeslagen deflate-blokken) }

var
  CrcTable: array[0..255] of LongWord;
  CrcReady: Boolean = False;

function Crc32(Startwaarde: LongWord; Gegevens: PByte; Aantal: Integer): LongWord;
var
  Index, Bit: Integer;
  Waarde: LongWord;
begin
  if not CrcReady then
  begin
    for Index := 0 to 255 do
    begin
      Waarde := Index;
      for Bit := 0 to 7 do
        if Waarde and 1 <> 0 then Waarde := $EDB88320 xor (Waarde shr 1) else Waarde := Waarde shr 1;
      CrcTable[Index] := Waarde;
    end;
    CrcReady := True;
  end;
  Waarde := Startwaarde xor $FFFFFFFF;
  for Index := 0 to Aantal - 1 do
    Waarde := CrcTable[(Waarde xor Gegevens[Index]) and $FF] xor (Waarde shr 8);
  Result := Waarde xor $FFFFFFFF;
end;

function ZMSavePNG(const Bestandsnaam: string; Pixels: Pointer; Breedte, Hoogte, Regellengte: Integer): Boolean;
var
  Ruw, Zlibstroom: array of Byte;
  Bestand: File;
  Kolom, Rij, RuwLengte, Positie, Blok, ZPositie: Integer;
  Bron: PLongWord;
  Som1, Som2: LongWord;
  procedure Stuk(const Soort: AnsiString; Gegevens: PByte; Lengte: Integer);
  var
    Kop: array[0..7] of Byte;
    Buffer: array of Byte;
    Controlesom: LongWord;
    Controlebytes: array[0..3] of Byte;
  begin
    Kop[0] := Lengte shr 24; Kop[1] := Lengte shr 16; Kop[2] := Lengte shr 8; Kop[3] := Lengte;
    Move(Soort[1], Kop[4], 4);
    BlockWrite(Bestand, Kop, 8);
    if Lengte > 0 then BlockWrite(Bestand, Gegevens^, Lengte);
    SetLength(Buffer, Lengte + 4);
    Move(Soort[1], Buffer[0], 4);
    if Lengte > 0 then Move(Gegevens^, Buffer[4], Lengte);
    Controlesom := Crc32(0, @Buffer[0], Lengte + 4);
    Controlebytes[0] := Controlesom shr 24; Controlebytes[1] := Controlesom shr 16; Controlebytes[2] := Controlesom shr 8; Controlebytes[3] := Controlesom;
    BlockWrite(Bestand, Controlebytes, 4);
  end;
const
  Signatuur: array[0..7] of Byte = (137, 80, 78, 71, 13, 10, 26, 10);
var
  Kopgegevens: array[0..12] of Byte;
begin
  Result := False;
  RuwLengte := Hoogte * (1 + Breedte * 3);
  SetLength(Ruw, RuwLengte);
  Positie := 0;
  for Rij := 0 to Hoogte - 1 do
  begin
    Ruw[Positie] := 0; Inc(Positie);
    Bron := PLongWord(PByte(Pixels) + PtrInt(Rij) * Regellengte);
    for Kolom := 0 to Breedte - 1 do
    begin
      Ruw[Positie] := (Bron^ shr 16) and $FF;
      Ruw[Positie + 1] := (Bron^ shr 8) and $FF;
      Ruw[Positie + 2] := Bron^ and $FF;
      Inc(Positie, 3);
      Inc(Bron);
    end;
  end;
  { zlib-stroom met opgeslagen blokken }
  SetLength(Zlibstroom, 2 + RuwLengte + (RuwLengte div 65535 + 1) * 5 + 4);
  Zlibstroom[0] := $78; Zlibstroom[1] := $01;
  ZPositie := 2;
  Positie := 0;
  repeat
    Blok := RuwLengte - Positie;
    if Blok > 65535 then Blok := 65535;
    if Positie + Blok >= RuwLengte then Zlibstroom[ZPositie] := 1 else Zlibstroom[ZPositie] := 0;
    Zlibstroom[ZPositie + 1] := Blok and $FF; Zlibstroom[ZPositie + 2] := Blok shr 8;
    Zlibstroom[ZPositie + 3] := not Blok and $FF; Zlibstroom[ZPositie + 4] := (not Blok shr 8) and $FF;
    Inc(ZPositie, 5);
    if Blok > 0 then Move(Ruw[Positie], Zlibstroom[ZPositie], Blok);
    Inc(ZPositie, Blok);
    Inc(Positie, Blok);
  until Positie >= RuwLengte;
  Som1 := 1; Som2 := 0;
  for Positie := 0 to RuwLengte - 1 do
  begin
    Som1 := (Som1 + Ruw[Positie]) mod 65521;
    Som2 := (Som2 + Som1) mod 65521;
  end;
  Som1 := (Som2 shl 16) or Som1;
  Zlibstroom[ZPositie] := Som1 shr 24; Zlibstroom[ZPositie + 1] := Som1 shr 16; Zlibstroom[ZPositie + 2] := Som1 shr 8; Zlibstroom[ZPositie + 3] := Som1;
  Inc(ZPositie, 4);
  AssignFile(Bestand, Bestandsnaam);
  {$I-} Rewrite(Bestand, 1); {$I+}
  if IOResult <> 0 then Exit;
  BlockWrite(Bestand, Signatuur, 8);
  Kopgegevens[0] := Breedte shr 24; Kopgegevens[1] := Breedte shr 16; Kopgegevens[2] := Breedte shr 8; Kopgegevens[3] := Breedte;
  Kopgegevens[4] := Hoogte shr 24; Kopgegevens[5] := Hoogte shr 16; Kopgegevens[6] := Hoogte shr 8; Kopgegevens[7] := Hoogte;
  Kopgegevens[8] := 8; Kopgegevens[9] := 2; Kopgegevens[10] := 0; Kopgegevens[11] := 0; Kopgegevens[12] := 0;
  Stuk('IHDR', @Kopgegevens[0], 13);
  Stuk('IDAT', @Zlibstroom[0], ZPositie);
  Stuk('IEND', nil, 0);
  CloseFile(Bestand);
  Result := True;
end;

finalization
  FreeAndNil(GBackend);
end.

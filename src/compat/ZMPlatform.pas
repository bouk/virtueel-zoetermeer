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
    function Open(const Title: string; W, H: Integer): Boolean; virtual;
    procedure Close; virtual;
    procedure Resize(W, H: Integer); virtual;
    { toon een beeld: Pixels zijn W x H 32-bits $00RRGGBB-waarden, Stride bytes per regel }
    procedure Present(Pixels: Pointer; W, H, Stride: Integer); virtual;
    function PollEvent(out E: TZMEvent): Boolean; virtual;
    { blokkeer tot een gebeurtenis binnenkomt of TimeoutMs verstreken is (-1 = oneindig) }
    procedure WaitEvent(TimeoutMs: Integer); virtual;
    function Ticks: LongWord; virtual;             { milliseconden }
    function PerfCounter: Int64; virtual;
    function PerfFrequency: Int64; virtual;
    procedure Delay(Ms: Integer); virtual;
    procedure SetTitle(const S: string); virtual;
    procedure SetCursor(Shape: TZMCursorShape); virtual;
    procedure Beep; virtual;
  end;

var
  { Wordt eenmaal per iteratie van de berichtenpomp aangeroepen (bij elke PeekMessage/
    GetMessage/WaitMessage, inclusief de modale lussen van ShowModal en MessageBox).
    Gebruikt door het differentiële-testharnas. }
  ZMIdleHook: procedure = nil;

procedure ZMRegisterBackend(B: TZMBackend; Priority: Integer);
function ZMBackend: TZMBackend;
{ vervang de huidige backend door de null-backend (bijv. wanneer geen beeldscherm beschikbaar is) }
procedure ZMFallbackToNull;

{ Hulpfuncties die door backends en tests gedeeld worden }
function ZMUtf8ToCp1252(const S: AnsiString): AnsiString;
function ZMSavePNG(const FileName: string; Pixels: Pointer; W, H, Stride: Integer): Boolean;

implementation

uses SysUtils
{$IFDEF UNIX}, BaseUnix, Unix{$ENDIF};

var
  GBackend: TZMBackend = nil;
  GPriority: Integer = -1;

procedure ZMRegisterBackend(B: TZMBackend; Priority: Integer);
begin
  if GetEnvironmentVariable('ZM_HEADLESS') = '1' then
  begin
    B.Free;
    Exit;
  end;
  if Priority > GPriority then
  begin
    if GBackend <> nil then GBackend.Free;
    GBackend := B;
    GPriority := Priority;
  end
  else
    B.Free;
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

function TZMBackend.Open(const Title: string; W, H: Integer): Boolean;
begin
  Result := True;
end;

procedure TZMBackend.Close;
begin
end;

procedure TZMBackend.Resize(W, H: Integer);
begin
end;

procedure TZMBackend.Present(Pixels: Pointer; W, H, Stride: Integer);
begin
end;

function TZMBackend.PollEvent(out E: TZMEvent): Boolean;
begin
  FillChar(E, SizeOf(E), 0);
  Result := False;
end;

procedure TZMBackend.WaitEvent(TimeoutMs: Integer);
begin
  if TimeoutMs < 0 then TimeoutMs := 10;
  if TimeoutMs > 0 then Delay(TimeoutMs);
end;

function TZMBackend.PerfFrequency: Int64;
begin
  Result := 1000000;
end;

function TZMBackend.PerfCounter: Int64;
{$IFDEF UNIX}
var
  TV: TTimeVal;
begin
  fpgettimeofday(@TV, nil);
  Result := Int64(TV.tv_sec) * 1000000 + TV.tv_usec;
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

procedure TZMBackend.Delay(Ms: Integer);
begin
  if Ms > 0 then SysUtils.Sleep(Ms);
end;

procedure TZMBackend.SetTitle(const S: string);
begin
end;

procedure TZMBackend.SetCursor(Shape: TZMCursorShape);
begin
end;

procedure TZMBackend.Beep;
begin
end;

{ ---------------------------------------------------------------- hulpfuncties }

function ZMUtf8ToCp1252(const S: AnsiString): AnsiString;
const
  Hi: array[$80..$9F] of Word = (
    $20AC, $0081, $201A, $0192, $201E, $2026, $2020, $2021, $02C6, $2030, $0160, $2039, $0152, $008D, $017D, $008F,
    $0090, $2018, $2019, $201C, $201D, $2022, $2013, $2014, $02DC, $2122, $0161, $203A, $0153, $009D, $017E, $0178);
var
  I, N, CP, K: Integer;
  C: Byte;
  Ch: AnsiChar;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    C := Byte(S[I]);
    if C < $80 then begin CP := C; N := 0; end
    else if C and $E0 = $C0 then begin CP := C and $1F; N := 1; end
    else if C and $F0 = $E0 then begin CP := C and $0F; N := 2; end
    else if C and $F8 = $F0 then begin CP := C and $07; N := 3; end
    else begin CP := Ord('?'); N := 0; end;
    Inc(I);
    while (N > 0) and (I <= Length(S)) do
    begin
      CP := (CP shl 6) or (Byte(S[I]) and $3F);
      Inc(I);
      Dec(N);
    end;
    Ch := '?';
    if (CP < $80) or ((CP >= $A0) and (CP <= $FF)) then Ch := AnsiChar(CP)
    else
      for K := $80 to $9F do
        if Hi[K] = CP then begin Ch := AnsiChar(K); Break; end;
    Result := Result + Ch;
  end;
end;

{ minimale PNG-schrijver (opgeslagen deflate-blokken) }

var
  CrcTable: array[0..255] of LongWord;
  CrcReady: Boolean = False;

function Crc32(Crc: LongWord; P: PByte; N: Integer): LongWord;
var
  I, K: Integer;
  C: LongWord;
begin
  if not CrcReady then
  begin
    for I := 0 to 255 do
    begin
      C := I;
      for K := 0 to 7 do
        if C and 1 <> 0 then C := $EDB88320 xor (C shr 1) else C := C shr 1;
      CrcTable[I] := C;
    end;
    CrcReady := True;
  end;
  C := Crc xor $FFFFFFFF;
  for I := 0 to N - 1 do
    C := CrcTable[(C xor P[I]) and $FF] xor (C shr 8);
  Result := C xor $FFFFFFFF;
end;

function ZMSavePNG(const FileName: string; Pixels: Pointer; W, H, Stride: Integer): Boolean;
var
  Raw, Z: array of Byte;
  F: File;
  X, Y, RawLen, Pos, Blk, ZP: Integer;
  Src: PLongWord;
  A, B: LongWord;
  procedure Chunk(const Typ: AnsiString; Data: PByte; Len: Integer);
  var
    Hdr: array[0..7] of Byte;
    Buf: array of Byte;
    Crc: LongWord;
    T: array[0..3] of Byte;
  begin
    Hdr[0] := Len shr 24; Hdr[1] := Len shr 16; Hdr[2] := Len shr 8; Hdr[3] := Len;
    Move(Typ[1], Hdr[4], 4);
    BlockWrite(F, Hdr, 8);
    if Len > 0 then BlockWrite(F, Data^, Len);
    SetLength(Buf, Len + 4);
    Move(Typ[1], Buf[0], 4);
    if Len > 0 then Move(Data^, Buf[4], Len);
    Crc := Crc32(0, @Buf[0], Len + 4);
    T[0] := Crc shr 24; T[1] := Crc shr 16; T[2] := Crc shr 8; T[3] := Crc;
    BlockWrite(F, T, 4);
  end;
const
  Sig: array[0..7] of Byte = (137, 80, 78, 71, 13, 10, 26, 10);
var
  IHDR: array[0..12] of Byte;
begin
  Result := False;
  RawLen := H * (1 + W * 3);
  SetLength(Raw, RawLen);
  Pos := 0;
  for Y := 0 to H - 1 do
  begin
    Raw[Pos] := 0; Inc(Pos);
    Src := PLongWord(PByte(Pixels) + PtrInt(Y) * Stride);
    for X := 0 to W - 1 do
    begin
      Raw[Pos] := (Src^ shr 16) and $FF;
      Raw[Pos + 1] := (Src^ shr 8) and $FF;
      Raw[Pos + 2] := Src^ and $FF;
      Inc(Pos, 3);
      Inc(Src);
    end;
  end;
  { zlib-stroom met opgeslagen blokken }
  SetLength(Z, 2 + RawLen + (RawLen div 65535 + 1) * 5 + 4);
  Z[0] := $78; Z[1] := $01;
  ZP := 2;
  Pos := 0;
  repeat
    Blk := RawLen - Pos;
    if Blk > 65535 then Blk := 65535;
    if Pos + Blk >= RawLen then Z[ZP] := 1 else Z[ZP] := 0;
    Z[ZP + 1] := Blk and $FF; Z[ZP + 2] := Blk shr 8;
    Z[ZP + 3] := not Blk and $FF; Z[ZP + 4] := (not Blk shr 8) and $FF;
    Inc(ZP, 5);
    if Blk > 0 then Move(Raw[Pos], Z[ZP], Blk);
    Inc(ZP, Blk);
    Inc(Pos, Blk);
  until Pos >= RawLen;
  A := 1; B := 0;
  for Pos := 0 to RawLen - 1 do
  begin
    A := (A + Raw[Pos]) mod 65521;
    B := (B + A) mod 65521;
  end;
  A := (B shl 16) or A;
  Z[ZP] := A shr 24; Z[ZP + 1] := A shr 16; Z[ZP + 2] := A shr 8; Z[ZP + 3] := A;
  Inc(ZP, 4);
  AssignFile(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  if IOResult <> 0 then Exit;
  BlockWrite(F, Sig, 8);
  IHDR[0] := W shr 24; IHDR[1] := W shr 16; IHDR[2] := W shr 8; IHDR[3] := W;
  IHDR[4] := H shr 24; IHDR[5] := H shr 16; IHDR[6] := H shr 8; IHDR[7] := H;
  IHDR[8] := 8; IHDR[9] := 2; IHDR[10] := 0; IHDR[11] := 0; IHDR[12] := 0;
  Chunk('IHDR', @IHDR[0], 13);
  Chunk('IDAT', @Z[0], ZP);
  Chunk('IEND', nil, 0);
  CloseFile(F);
  Result := True;
end;

finalization
  FreeAndNil(GBackend);
end.

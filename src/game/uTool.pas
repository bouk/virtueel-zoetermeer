unit uTool;

{ Algemene hulpfuncties van de sprite-engine: positielijsten, min/max/interpolatie,
  bestandszoeken, programmapad.
  Gedecompileerd uit ROS.exe v1.1, code 004609B4-004615D3. }

{$I zm.inc}

interface

uses
  Windows, Classes;

type
  TPos = class(TObject)
  private
    FX: Integer;         { +0x04 }
    FY: Integer;         { +0x08 }
  public
    constructor Create(AX, AY: Integer);
    property X: Integer read FX write FX;
    property Y: Integer read FY write FY;
  end;

  TRectPos = class(TPos)
  private
    FWidth: Integer;     { +0x0C }
    FHeight: Integer;    { +0x10 }
  public
    constructor Create(AX, AY, AWidth, AHeight: Integer);
    constructor CreateRect(R: TRect);
    function GetRect: TRect;
    procedure SetRect(R: TRect);
    function Intersects(ARect: TRectPos): Boolean;
    procedure Union(ARect: TRectPos);
    property Width: Integer read FWidth write FWidth;
    property Height: Integer read FHeight write FHeight;
    property Rect: TRect read GetRect write SetRect;
  end;

  { Lijst van TPos, optioneel gesorteerd op (X, Y) voor binair zoeken }
  TPosList = class(TList)
  private
    FSorted: Boolean;      { +0x10  lijst is momenteel gesorteerd }
    FKeepSorted: Boolean;  { +0x11  invoegen in sorteervolgorde / opnieuw sorteren na Insert }
  public
    constructor Create;
    procedure Sort;
    function Add(Item: TPos): TPos;
    function GetItem(Index: Integer): TPos;
    function Find(X, Y: Integer): Integer;
    procedure Insert(Index: Integer; Item: TPos);
    function IndexOf(X, Y: Integer): Integer;
    property Items[Index: Integer]: TPos read GetItem; default;
    property Sorted: Boolean read FSorted write FSorted;
    property KeepSorted: Boolean read FKeepSorted write FKeepSorted;
  end;

  TRectPosList = class(TPosList)
  public
    function GetItem(Index: Integer): TRectPos;
    function Add(Item: TRectPos): TRectPos;
    function AddRect(R: TRect): TRectPos;
    property Items[Index: Integer]: TRectPos read GetItem; default;
  end;

  TWinVersion = record
    Major: Integer;
    Minor: Integer;
    Valid: Boolean;
    IsNT: Boolean;
  end;

const
  DayNames: array[0..6] of string = (            { 00488D04 }
    'zondag', 'maandag', 'dinsdag', 'woensdag', 'donderdag', 'vrijdag', 'zaterdag');

var
  AppPath: string;   { 0048A8A0: map van het programma, met een afsluitende '\' }
  AppName: string;   { 0048A8A4: bestandsnaam van het programma }

function IMax(A, B: Integer): Integer;
function IMin(A, B: Integer): Integer;
function FMax(A, B: Double): Double;
function FMin(A, B: Double): Double;
function Interpolate(F, A, B: Double): Double;
procedure FreeList(List: TList);
function RandomString(List: TStrings): string;
function IsEven(N: Integer): Boolean;
function RectWidth(R: TRect): Integer;
function RectHeight(R: TRect): Integer;
function RoundUp(X: Double): Integer;
function InPort(Port: Word): Byte;
procedure GetWinVersion(var V: TWinVersion);
procedure FindFiles(Path: string; Attr: Integer; List: TStrings);

implementation

uses
  SysUtils
  {$IFDEF FPC}, ZMRandom{$ENDIF}  { PORT: Delphi's Random };

{ @00460B34 }
function IMax(A, B: Integer): Integer;
begin
  if B < A then
    Result := A
  else
    Result := B;
end;

{ @00460B3C }
function IMin(A, B: Integer): Integer;
begin
  if B > A then
    Result := A
  else
    Result := B;
end;

{ @00460B44 }
function FMax(A, B: Double): Double;
begin
  if A > B then
    Result := A
  else
    Result := B;
end;

{ @00460B78 }
function FMin(A, B: Double): Double;
begin
  if A < B then
    Result := A
  else
    Result := B;
end;

{ @00460BAC }
function Interpolate(F, A, B: Double): Double;
begin
  Result := F * A + (1 - F) * B;
end;

{ @00460C54  Geeft alle objecten van een lijst vrij (elk verschillend object een keer) en leegt hem. }
procedure FreeList(List: TList);
var
  I, J: Integer;
  P: TObject;
begin
  for I := 0 to List.Count - 1 do
    for J := 0 to I - 1 do
      if List[I] = List[J] then
        List[I] := nil;
  while List.Count <> 0 do
  begin
    P := TObject(List[0]);
    List.Delete(0);
    if P <> nil then
      P.Free;
  end;
end;

{ @00460CD0 }
function RandomString(List: TStrings): string;
begin
  Result := List[Random(List.Count)];
end;

{ @00460CF0 }
constructor TPos.Create(AX, AY: Integer);
begin
  { LET OP: roept geen inherited Create aan }
  FX := AX;
  FY := AY;
end;

{ @00460D20 }
constructor TRectPos.Create(AX, AY, AWidth, AHeight: Integer);
begin
  inherited Create(AX, AY);
  FWidth := AWidth;
  FHeight := AHeight;
end;

{ @00460D6C }
constructor TRectPos.CreateRect(R: TRect);
begin
  Create(R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top);
end;

{ @00460DD0 }
function TRectPos.GetRect: TRect;
begin
  Result := Bounds(FX, FY, FWidth, FHeight);
end;

{ @00460DEC }
procedure TRectPos.SetRect(R: TRect);
begin
  FX := R.Left;
  FY := R.Top;
  FWidth := R.Right - R.Left;
  FHeight := R.Bottom - R.Top;
end;

{ @00460E28 }
function TRectPos.Intersects(ARect: TRectPos): Boolean;
var
  Doel: TRect;
begin
  Result := IntersectRect(Doel, ARect.GetRect, GetRect);
end;

{ @00460E64 }
procedure TRectPos.Union(ARect: TRectPos);
var
  R: TRect;
begin
  UnionRect(R, ARect.GetRect, GetRect);
  SetRect(R);
end;

{ @00460EA4 }
constructor TPosList.Create;
begin
  inherited Create;
  FKeepSorted := False;
  FSorted := False;
end;

{ @00461024 }
procedure TPosList.Sort;

  { @00460EE4 }
  function Sleutel(I: Integer): Integer;
  begin
    Result := (Items[I].FX shl 16) + Items[I].FY;
  end;

  { @00460F18 }
  procedure ZetSleutel(I, K: Integer);
  begin
    Items[I].FX := K div $10000;
    Items[I].FY := K and $FFFF;
  end;

  { @00460F5C }
  procedure SnelSorteren(L, R: Integer);
  var
    I, J, P, Tijdelijk: Integer;
  begin
    I := L;
    J := R;
    P := Sleutel((L + R) div 2);
    repeat
      while P > Sleutel(I) do
        Inc(I);
      while P < Sleutel(J) do
        Dec(J);
      if I <= J then
      begin
        Tijdelijk := Sleutel(I);
        ZetSleutel(I, Sleutel(J));
        ZetSleutel(J, Tijdelijk);
        Inc(I);
        Dec(J);
      end;
    until I > J;
    if L < J then
      SnelSorteren(L, J);
    if I < R then
      SnelSorteren(I, R);
  end;

begin
  if not FSorted then
  begin
    if Count > 0 then
      SnelSorteren(0, Count - 1);
    FSorted := True;
  end;
end;

{ @00461054 }
function TPosList.Add(Item: TPos): TPos;
var
  I: Integer;
begin
  if FKeepSorted and (Count > 0) then
  begin
    I := Find(Item.FX, Item.FY);
    if I < Count then
    begin
      if I >= 0 then
      begin
        FKeepSorted := False;
        Insert(I, Item);
        FKeepSorted := True;
        FSorted := True;
      end
      else
      begin
        inherited Add(Item);
        FSorted := False;
      end;
    end
    else
      inherited Add(Item);
  end
  else
  begin
    inherited Add(Item);
    FSorted := False;
  end;
  if Count = 1 then
    FSorted := True;
  Result := Item;
end;

{ @004610CC }
function TPosList.GetItem(Index: Integer): TPos;
begin
  Result := TObject(Get(Index)) as TPos;
end;

{ @004610EC }
function IsEven(N: Integer): Boolean;
begin
  if N mod 2 = 1 then
    Result := False
  else
    Result := True;
end;

{ @00461104  Binair zoeken in de gesorteerde lijst: index van (X, Y), of de index waar het
  ingevoegd moet worden; -1 als de lijst leeg is of niet gesorteerd. }
function TPosList.Find(X, Y: Integer): Integer;
var
  Stap, I: Integer;
  Laatste: Boolean;
begin
  Result := -1;
  if (Count = 0) or not FSorted then
    Exit;
  Stap := Count div 2;
  I := Stap;
  Laatste := False;
  while True do
  begin
    if (X = Items[I].FX) and (Items[I].FY = Y) then
    begin
      Result := I;
      Exit;
    end;
    if Laatste or (Stap = 0) then
    begin
      if (X > Items[I].FX) or ((X = Items[I].FX) and (Items[I].FY < Y)) then
        Result := I + 1
      else
        Result := I;
      Exit;
    end;
    if X = Items[I].FX then
    begin
      if Items[I].FY < Y then
        Inc(I, Stap)
      else
        Dec(I, Stap);
    end
    else if X > Items[I].FX then
      Inc(I, Stap)
    else
      Dec(I, Stap);
    if I < 0 then
      I := 0;
    if I >= Count then
      I := Count - 1;
    if IsEven(Stap) then
      Stap := Stap div 2
    else if Stap = 1 then
      Laatste := True
    else
      Stap := (Stap + 1) div 2;
  end;
end;

{ @00461234 }
procedure TPosList.Insert(Index: Integer; Item: TPos);
begin
  inherited Insert(Index, Item);
  if FKeepSorted then
    Sort
  else
    FSorted := False;
end;

{ @00461254 }
function TPosList.IndexOf(X, Y: Integer): Integer;
var
  I: Integer;
begin
  if FSorted then
  begin
    I := Find(X, Y);
    if (I < Count) and (I > -1) and (X = Items[I].FX) and (Items[I].FY = Y) then
      Result := I
    else
      Result := -1;
  end
  else
  begin
    for I := 0 to Count - 1 do
      if (X = Items[I].FX) and (Items[I].FY = Y) then
      begin
        Result := I;
        Exit;
      end;
    Result := -1;
  end;
end;

{ @004612E4 }
function TRectPosList.GetItem(Index: Integer): TRectPos;
begin
  Result := inherited GetItem(Index) as TRectPos;
end;

{ @00461304 }
function TRectPosList.Add(Item: TRectPos): TRectPos;
begin
  Result := inherited Add(Item) as TRectPos;
end;

{ @00461324 }
function TRectPosList.AddRect(R: TRect): TRectPos;
begin
  Result := Add(TRectPos.CreateRect(R));
end;

{ @00461358 }
function RectWidth(R: TRect): Integer;
begin
  Result := R.Right - R.Left;
end;

{ @00461378 }
function RectHeight(R: TRect): Integer;
begin
  Result := R.Bottom - R.Top;
end;

{ @00461398 }
function RoundUp(X: Double): Integer;
begin
  { LET OP: Round(X + 1) is geen afronding naar boven voor breuken >= 0.5 (2.7 -> 4); behouden zoals in het origineel }
  Result := Round(X + 1);
  if Frac(X) = 0 then
    Dec(Result);
end;

{ @004613D0 }
function InPort(Port: Word): Byte;
var
  B: Byte;
begin
  B := 0;
{$IFNDEF FPC}
  asm
    MOV DX, Port
    IN AL, DX
    MOV B, AL
  end;
{$ELSE}
  { PORT: geen poort-I/O op de draagbare doelplatforms. De enige poort die het spel leest is het
    VGA-invoerstatusregister $3DA (de retrace-wachtlus van uTiming); emuleer de verticale-
    retracebit (bit 3) op 60 Hz zodat de wachtlussen eindigen. }
  if (Port = $3DA) and (GetTickCount64 mod 17 = 0) then
    B := 8;
{$ENDIF}
  Result := B;
end;

{ @004613EC }
procedure GetWinVersion(var V: TWinVersion);
var
  VersieInfo: TOSVersionInfo;
begin
  VersieInfo.dwOSVersionInfoSize := SizeOf(VersieInfo);
  GetVersionEx(VersieInfo);
  V.Major := VersieInfo.dwMajorVersion;
  V.Minor := VersieInfo.dwMinorVersion;
  V.Valid := True;
  V.IsNT := VersieInfo.dwPlatformId = VER_PLATFORM_WIN32_NT;
end;

{ @00461428 }
procedure FindFiles(Path: string; Attr: Integer; List: TStrings);
var
  Zoekrecord: TSearchRec;
begin
  if FindFirst(Path, Attr, Zoekrecord) = 0 then
    repeat
      List.Add(Zoekrecord.Name);
    until FindNext(Zoekrecord) <> 0;
  FindClose(Zoekrecord);
end;

{ @0046152C }
initialization
  AppPath := ExtractFilePath(ParamStr(0));
  if AppPath[Length(AppPath)] <> '\' then
    AppPath := AppPath + '\';
  AppName := ExtractFileName(ParamStr(0));

end.

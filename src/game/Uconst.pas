unit Uconst;

{ Spelconstanten en hulpfuncties: de objecttypetabel die uit Objecten.csv wordt geladen
  (TContentsInfo), namen van criteria/waarderingen, tests voor weg-, spoor- en stationsnamen,
  de coordinaatomzettingen van het isometrische raster <-> wereld <-> scherm,
  profileringstellers en de fatale foutbox.
  Gedecompileerd uit ROS.exe v1.1, code 00485A34-00486C6B. }

{$I zm.inc}

interface

uses
  Windows;

const
  TileW = 88;        { breedte van een rastercel in wereldpixels }
  OriginX = 2024;    { wereld-X van raster (0,0) }
  OriginY = -880;    { wereld-Y van raster (0,0) }

type
  { RTTI 00485A38 'TContentsInfo', grootte $48. Een regel uit Objecten.csv. }
  TContentsInfo = record
    Name: string;          { +0x00 Name }
    Description: string;   { +0x04 Description }
    IsGround: Integer;     { +0x08 IsGround }
    Singleton: Boolean;    { +0x0C Singleton = '1' }
    Page: string;          { +0x10 Page }
    Level: Integer;        { +0x14 Level }
    Prijs: Integer;        { +0x18 Prijs }
    Onderhoud: Integer;    { +0x1C Onderhoud }
    Capaciteit: Integer;   { +0x20 Capaciteit }
    MaxSpeed: Integer;     { +0x24 MaxSpeed }
    GrondvlakX: Integer;   { +0x28 GrondvlakX (>= 1) }
    GrondvlakY: Integer;   { +0x2C GrondvlakY (>= 1) }
    Hoofdrubriek: string;  { +0x30 Hoofdrubriek }
    BaseScore: Integer;    { +0x34 BaseScore }
    Value: Integer;        { +0x38 Value }
    Afstand: Integer;      { +0x3C Afstand }
    Wens: string;          { +0x40 Wens }
    SpritesLoaded: Boolean;   { +0x44 ingesteld door TfrmMain.ReadSprites zodra de sprites zijn geladen }
    KnopGemaakt: Boolean;     { +0x45 ingesteld door TfrmMain zodra de bouwknop is gemaakt }
  end;

  { RTTI 00485BAC '.4' }
  TContentsInfoArray = array of TContentsInfo;

const
  { 004892A0 }
  Criteria: array[0..6] of string =
    ('Vrijetijd', 'Groen', 'Veiligheid', 'Cultuur', 'Mobiliteit', 'Werk', 'Overlast');
  { 004892BC: het deel van het scherm waarin de stad wordt getekend }
  ViewRect: TRect = (Left: 30; Top: 81; Right: 822; Bottom: 686);
  { 004892CC (niet gebruikt) }
  Waarderingen: array[0..4] of string =
    ('Zeer slecht', 'Onvoldoende', 'Matig', 'Redelijk', 'Goed');
  { 004892E0 (niet gebruikt) }
  Hoeveelheden: array[0..4] of string =
    ('Enorm', 'Veel', 'Matig', 'Acceptabel', 'Geen');
  { 004892F4: schaal wereld -> scherm, ingesteld door Uview }
  Zoom: Double = 1;
  { 004892FC, 00489300: scrollverschuiving van de wereld, ingesteld door Uview }
  ScrollX: Integer = 0;
  ScrollY: Integer = 0;

var
  Contents: TContentsInfoArray;   { 0048B178 }
  ContentsCount: Integer;         { 0048B17C }
  { Profileringstellers (GetTickCount), gerapporteerd door Fmain. }
  PerfStart: Longint;             { 0048B180 }
  PerfView: Longint;              { 0048B184 }
  PerfAutos: Longint;             { 0048B188 }
  PerfSprites: Longint;           { 0048B18C }
  PerfOther: Longint;             { 0048B190 }

procedure LoadContents;
function IsSnelweg(Naam, Onder: string): Boolean;
function IsGewoneWeg(Naam, Onder: string): Boolean;
function IsWeg(Naam, Onder: string): Boolean;
function IsSpoor(Naam: string; var Nr: Byte): Boolean;
function IsRechtSpoor(Naam: string): Boolean;
function IsBochtSpoor(Naam: string; var Nr: Byte): Boolean;
function IsStation(Naam: string; var Nr: Byte): Boolean;
function IsTreinBestemming(Naam: string): Boolean;
function IsBebouwing(Naam: string): Boolean;
function GridToWorld(P: TPoint): TPoint;
function WorldToScreen(P: TPoint): TPoint;
function GridToScreen(P: TPoint): TPoint;
function ScreenToWorld(P: TPoint): TPoint;
function WorldToGrid(P: TPoint): TPoint;
function ScreenToGrid(P: TPoint): TPoint;
function ContentsInfoByContents(Naam: string): TContentsInfo;
function ContentsDescription(Naam: string): string;
function IsOutOfView(X, Y: Integer): Boolean;
function InMap(X, Y: Integer): Boolean;
procedure Fout(Melding: string);

implementation

uses
  SysUtils, Forms, uString, uTool, Fmain;

{ @00485BBC }
procedure AddContents(Naam, Omschrijving: string);
var
  Gegevens: TContentsInfo;
begin
  Gegevens.Name := Naam;
  Gegevens.Description := Omschrijving;
  Gegevens.IsGround := 1;
  Gegevens.Singleton := False;
  Gegevens.Page := '';
  Gegevens.Level := 0;
  Gegevens.Prijs := 0;
  Gegevens.Onderhoud := 0;
  Gegevens.Afstand := 0;
  Gegevens.GrondvlakX := 1;
  Gegevens.GrondvlakY := 1;
  Gegevens.BaseScore := 0;
  Gegevens.Value := 0;
  Gegevens.Afstand := 0;
  Gegevens.Wens := '';
  Gegevens.SpritesLoaded := False;
  Gegevens.KnopGemaakt := False;
  { LET OP: Capaciteit, MaxSpeed en Hoofdrubriek worden niet ingesteld. }
  Inc(ContentsCount);
  SetLength(Contents, ContentsCount);
  Contents[ContentsCount - 1] := Gegevens;
end;

{ @00485CD8 }
procedure LoadContents;
var
  Kop, Regel, GrondX, GrondY: string;
  Bestand: TextFile;
  Gegevens: TContentsInfo;
  S: string;
begin
  { LET OP: het stackframe van het origineel wordt bij binnenkomst op nul gezet, dus de
    velden die niet uit het bestand worden gelezen (SpritesLoaded/KnopGemaakt) beginnen als
    False en behouden hun waarde van regel tot regel. }
{$IFDEF FPC}
  Gegevens := Default(TContentsInfo);   { PORT: FPC zet het frame niet op nul }
{$ENDIF}
  ContentsCount := 0;
  AssignFile(Bestand, AddPath(AppPath, 'Objecten.csv'));
  Reset(Bestand);
  ReadLn(Bestand, Kop);
  while not Eof(Bestand) do
  begin
    ReadLn(Bestand, Regel);
    if TrimStr(Regel) <> '' then
    begin
      S := SplitFirst(Regel, ';');
      Gegevens.Name := S;
      if TrimStr(Gegevens.Name) <> '' then
      begin
        S := SplitFirst(Regel, ';');
        Gegevens.Page := S;
        S := SplitFirst(Regel, ';');
        Gegevens.Description := S;
        S := SplitFirst(Regel, ';');
        Gegevens.Level := StrToIntDef0(S);
        S := SplitFirst(Regel, ';');
        Gegevens.IsGround := StrToIntDef0(S);
        S := SplitFirst(Regel, ';');
        Gegevens.Singleton := S = '1';
        S := SplitFirst(Regel, ';');
        Gegevens.Prijs := StrToIntDef0(S);
        S := SplitFirst(Regel, ';');
        Gegevens.Onderhoud := StrToIntDef0(S);
        S := SplitFirst(Regel, ';');
        Gegevens.Capaciteit := StrToIntDef0(S);
        S := SplitFirst(Regel, ';');
        Gegevens.MaxSpeed := StrToIntDef0(S);
        GrondX := SplitFirst(Regel, ';');
        GrondY := SplitFirst(Regel, ';');
        if GrondX = '' then
          Gegevens.GrondvlakX := 1
        else
          Gegevens.GrondvlakX := IMax(1, StrToIntDef0(GrondX));
        if GrondY = '' then
          Gegevens.GrondvlakY := 1
        else
          Gegevens.GrondvlakY := IMax(1, StrToIntDef0(GrondY));
        S := SplitFirst(Regel, ';');
        Gegevens.Hoofdrubriek := S;
        S := SplitFirst(Regel, ';');
        Gegevens.BaseScore := StrToIntDef0(S);
        S := SplitFirst(Regel, ';');
        Gegevens.Value := StrToIntDef0(S);
        S := SplitFirst(Regel, ';');
        Gegevens.Afstand := StrToIntDef0(S);
        S := SplitFirst(Regel, ';');
        Gegevens.Wens := S;
        Inc(ContentsCount);
        SetLength(Contents, ContentsCount);
        Contents[ContentsCount - 1] := Gegevens;
      end;
    end;
  end;
  CloseFile(Bestand);
  AddContents('AndereStad', 'Andere stad');
  AddContents('Onbereikbaar', 'Buiten de stad');
end;

{ @0048619C }
function IsSnelweg(Naam, Onder: string): Boolean;
begin
  Result := (Naam = 'Snel') or
    (((Naam = 'Rails05') or (Naam = 'Rails10')) and IsSnelweg(Onder, 'X'));
end;

{ @00486270 }
function IsGewoneWeg(Naam, Onder: string): Boolean;
begin
  { LET OP: wist Onder als het al leeg is; heeft geen effect. }
  if ((Naam = 'Rails05') or (Naam = 'Rails10')) and (Onder = '') then
    Onder := '';
  Result := (Naam = 'Bakst') or (Naam = 'Weg') or
    (((Naam = 'Rails05') or (Naam = 'Rails10')) and IsGewoneWeg(Onder, 'X'));
end;

{ @0048638C }
function IsWeg(Naam, Onder: string): Boolean;
begin
  Result := IsGewoneWeg(Naam, Onder) or IsSnelweg(Naam, Onder);
end;

{ @00486404 }
function IsSpoor(Naam: string; var Nr: Byte): Boolean;
begin
  if IsStation(Naam, Nr) then
    Result := True
  else
  begin
    Nr := StrToIntDef0(Copy(Naam, 6, 2));
    Result := LeftStr(Naam, 5) = 'Rails';
  end;
end;

{ @004864B4 }
function IsRechtSpoor(Naam: string): Boolean;
var
  Nr: Byte;
begin
  Result := IsSpoor(Naam, Nr) and (Nr in [5, 10]);
end;

{ @00486518 }
function IsBochtSpoor(Naam: string; var Nr: Byte): Boolean;
begin
  Result := IsSpoor(Naam, Nr) and (Nr in [3, 6, 9, 12]);
end;

{ @00486584 }
function IsStation(Naam: string; var Nr: Byte): Boolean;
begin
  if Naam = 'Hoofdstation' then
  begin
    Nr := 10;
    Result := True;
  end
  else if StartsWith(Naam, 'Station') then
  begin
    Nr := StrToIntDef0(Copy(Naam, 8, 2));
    Result := True;
  end
  else
    Result := False;
end;

{ @0048664C }
function IsTreinBestemming(Naam: string): Boolean;
var
  Nr: Byte;
begin
  Result := (Naam = 'AndereStad') or IsStation(Naam, Nr);
end;

{ @004866C8 }
function IsBebouwing(Naam: string): Boolean;
begin
  Result := (Naam = 'Laagbouw') or (Naam = 'Middenbouw') or
    (Naam = 'Hoogbouw') or (Naam = 'Kantoor') or (Naam = 'Molen');
end;

{ @004867B8 }
function GridToWorld(P: TPoint): TPoint;
begin
  Result.X := (P.X - P.Y) * TileW + OriginX;
  Result.Y := (P.X + P.Y) * TileW div 2 + OriginY;
end;

{ @004867F4 }
function WorldToScreen(P: TPoint): TPoint;
begin
  Result.X := Round((P.X + ScrollX) * Zoom);
  Result.Y := Round((P.Y + ScrollY) * Zoom);
end;

{ @00486848 }
function GridToScreen(P: TPoint): TPoint;
begin
  Result := GridToWorld(P);
  Result := WorldToScreen(Result);
end;

{ @00486880 }
function ScreenToWorld(P: TPoint): TPoint;
begin
  Result.X := Round(P.X / Zoom) - ScrollX;
  Result.Y := Round(P.Y / Zoom) - ScrollY;
end;

{ @004868C4 }
function WorldToGrid(P: TPoint): TPoint;
var
  Getal: Double;
begin
  Getal := (P.X - OriginX) / TileW / 2 + (P.Y - OriginY) / TileW;
  Result.X := Round(Getal);
  Result.Y := Round((P.Y - OriginY) / TileW * 2 - Getal);
end;

{ @00486950 }
function ScreenToGrid(P: TPoint): TPoint;
begin
  Result := ScreenToWorld(P);
  Result := WorldToGrid(Result);
end;

{ @00486988 }
function ContentsInfoByContents(Naam: string): TContentsInfo;
var
  I: Integer;
begin
  for I := 0 to ContentsCount - 1 do
    if Contents[I].Name = Naam then
    begin
      Result := Contents[I];
      Exit;
    end;
  Fout('ContentsInfoByContents: ' + Naam + ' not found');
end;

{ @00486A78 }
function ContentsDescription(Naam: string): string;
begin
  Result := ContentsInfoByContents(Naam).Description;
end;

{ @00486AEC }
function IsOutOfView(X, Y: Integer): Boolean;
var
  P: TPoint;
begin
  P.X := X;
  P.Y := Y;
  Result := not PtInRect(ViewRect, GridToScreen(P));
end;

{ @00486B20 }
function InMap(X, Y: Integer): Boolean;
begin
  Result := (X + Y > 22) and (X + Y < 66) and (X - Y < 22) and (Y - X < 22);
end;

{ @00486B44 }
procedure Fout(Melding: string);
begin
  frmMain.Hide;
  Melding := Melding + #0;
  Application.MessageBox(@Melding[1], 'Foutmelding', MB_OK);
  raise EMathError.Create(Melding);
end;

end.

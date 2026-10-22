unit Uconst;

{ Game constants and helpers: the object type table loaded from Objecten.csv
  (TContentsInfo), criteria/rating names, road/rail/station name tests, the
  isometric grid <-> world <-> screen coordinate conversions, profiling tick
  counters and the fatal error box.
  Decompiled from ROS.exe v1.1, code 00485A34-00486C6B. }

{$I zm.inc}

interface

uses
  Windows;

const
  TileW = 88;        { width of a grid cell in world pixels }
  OriginX = 2024;    { world X of grid (0,0) }
  OriginY = -880;    { world Y of grid (0,0) }

type
  { RTTI 00485A38 'TContentsInfo', size $48. One line of Objecten.csv. }
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
    Extra1: Boolean;       { +0x44 never read; cleared only by AddContents }
    Extra2: Boolean;       { +0x45 never read; cleared only by AddContents }
  end;

  { RTTI 00485BAC '.4' }
  TContentsInfoArray = array of TContentsInfo;

const
  { 004892A0 }
  Criteria: array[0..6] of string =
    ('Vrijetijd', 'Groen', 'Veiligheid', 'Cultuur', 'Mobiliteit', 'Werk', 'Overlast');
  { 004892BC: the part of the screen in which the city is drawn }
  ViewRect: TRect = (Left: 30; Top: 81; Right: 822; Bottom: 686);
  { 004892CC (not referenced) }
  Waarderingen: array[0..4] of string =
    ('Zeer slecht', 'Onvoldoende', 'Matig', 'Redelijk', 'Goed');
  { 004892E0 (not referenced) }
  Hoeveelheden: array[0..4] of string =
    ('Enorm', 'Veel', 'Matig', 'Acceptabel', 'Geen');
  { 004892F4: world -> screen scale, set by Uview }
  Zoom: Double = 1;
  { 004892FC, 00489300: world scroll offset, set by Uview }
  ScrollX: Integer = 0;
  ScrollY: Integer = 0;

var
  Contents: TContentsInfoArray;   { 0048B178 }
  ContentsCount: Integer;         { 0048B17C }
  { Profiling tick counters (GetTickCount), reported by Fmain. }
  PerfStart: Longint;             { 0048B180 }
  PerfView: Longint;              { 0048B184 }
  PerfAutos: Longint;             { 0048B188 }
  PerfSprites: Longint;           { 0048B18C }
  PerfOther: Longint;             { 0048B190 }

procedure LoadContents;
function IsSnelweg(Name, Onder: string): Boolean;
function IsGewoneWeg(Name, Onder: string): Boolean;
function IsWeg(Name, Onder: string): Boolean;
function IsSpoor(Name: string; var Nr: Byte): Boolean;
function IsRechtSpoor(Name: string): Boolean;
function IsBochtSpoor(Name: string; var Nr: Byte): Boolean;
function IsStation(Name: string; var Nr: Byte): Boolean;
function IsTreinBestemming(Name: string): Boolean;
function IsBebouwing(Name: string): Boolean;
function GridToWorld(P: TPoint): TPoint;
function WorldToScreen(P: TPoint): TPoint;
function GridToScreen(P: TPoint): TPoint;
function ScreenToWorld(P: TPoint): TPoint;
function WorldToGrid(P: TPoint): TPoint;
function ScreenToGrid(P: TPoint): TPoint;
function ContentsInfoByContents(Name: string): TContentsInfo;
function ContentsDescription(Name: string): string;
function IsOutOfView(X, Y: Integer): Boolean;
function InMap(X, Y: Integer): Boolean;
procedure Fout(Msg: string);

implementation

uses
  SysUtils, Forms, uString, uTool, Fmain;

{ @00485BBC }
procedure AddContents(Name, Description: string);
var
  Info: TContentsInfo;
begin
  Info.Name := Name;
  Info.Description := Description;
  Info.IsGround := 1;
  Info.Singleton := False;
  Info.Page := '';
  Info.Level := 0;
  Info.Prijs := 0;
  Info.Onderhoud := 0;
  Info.Afstand := 0;
  Info.GrondvlakX := 1;
  Info.GrondvlakY := 1;
  Info.BaseScore := 0;
  Info.Value := 0;
  Info.Afstand := 0;
  Info.Wens := '';
  Info.Extra1 := False;
  Info.Extra2 := False;
  { NOTE: Capaciteit, MaxSpeed and Hoofdrubriek are not set. }
  Inc(ContentsCount);
  SetLength(Contents, ContentsCount);
  Contents[ContentsCount - 1] := Info;
end;

{ @00485CD8 }
procedure LoadContents;
var
  Header, Line, SX, SY: string;
  F: TextFile;
  Info: TContentsInfo;
  S: string;
begin
  { NOTE: the original's stack frame is zero-filled on entry, so the fields
    that are never read from the file (Extra1/Extra2) start as False and keep
    their value from line to line. }
  ContentsCount := 0;
  AssignFile(F, AddPath(AppPath, 'Objecten.csv'));
  Reset(F);
  ReadLn(F, Header);
  while not Eof(F) do
  begin
    ReadLn(F, Line);
    if TrimStr(Line) <> '' then
    begin
      S := SplitFirst(Line, ';');
      Info.Name := S;
      if TrimStr(Info.Name) <> '' then
      begin
        S := SplitFirst(Line, ';');
        Info.Page := S;
        S := SplitFirst(Line, ';');
        Info.Description := S;
        S := SplitFirst(Line, ';');
        Info.Level := StrToIntDef0(S);
        S := SplitFirst(Line, ';');
        Info.IsGround := StrToIntDef0(S);
        S := SplitFirst(Line, ';');
        Info.Singleton := S = '1';
        S := SplitFirst(Line, ';');
        Info.Prijs := StrToIntDef0(S);
        S := SplitFirst(Line, ';');
        Info.Onderhoud := StrToIntDef0(S);
        S := SplitFirst(Line, ';');
        Info.Capaciteit := StrToIntDef0(S);
        S := SplitFirst(Line, ';');
        Info.MaxSpeed := StrToIntDef0(S);
        SX := SplitFirst(Line, ';');
        SY := SplitFirst(Line, ';');
        if SX = '' then
          Info.GrondvlakX := 1
        else
          Info.GrondvlakX := IMax(1, StrToIntDef0(SX));
        if SY = '' then
          Info.GrondvlakY := 1
        else
          Info.GrondvlakY := IMax(1, StrToIntDef0(SY));
        S := SplitFirst(Line, ';');
        Info.Hoofdrubriek := S;
        S := SplitFirst(Line, ';');
        Info.BaseScore := StrToIntDef0(S);
        S := SplitFirst(Line, ';');
        Info.Value := StrToIntDef0(S);
        S := SplitFirst(Line, ';');
        Info.Afstand := StrToIntDef0(S);
        S := SplitFirst(Line, ';');
        Info.Wens := S;
        Inc(ContentsCount);
        SetLength(Contents, ContentsCount);
        Contents[ContentsCount - 1] := Info;
      end;
    end;
  end;
  CloseFile(F);
  AddContents('AndereStad', 'Andere stad');
  AddContents('Onbereikbaar', 'Buiten de stad');
end;

{ @0048619C }
function IsSnelweg(Name, Onder: string): Boolean;
begin
  Result := (Name = 'Snel') or
    (((Name = 'Rails05') or (Name = 'Rails10')) and IsSnelweg(Onder, 'X'));
end;

{ @00486270 }
function IsGewoneWeg(Name, Onder: string): Boolean;
begin
  { NOTE: clears Onder when it is already empty; has no effect. }
  if ((Name = 'Rails05') or (Name = 'Rails10')) and (Onder = '') then
    Onder := '';
  Result := (Name = 'Bakst') or (Name = 'Weg') or
    (((Name = 'Rails05') or (Name = 'Rails10')) and IsGewoneWeg(Onder, 'X'));
end;

{ @0048638C }
function IsWeg(Name, Onder: string): Boolean;
begin
  Result := IsGewoneWeg(Name, Onder) or IsSnelweg(Name, Onder);
end;

{ @00486404 }
function IsSpoor(Name: string; var Nr: Byte): Boolean;
begin
  if IsStation(Name, Nr) then
    Result := True
  else
  begin
    Nr := StrToIntDef0(Copy(Name, 6, 2));
    Result := LeftStr(Name, 5) = 'Rails';
  end;
end;

{ @004864B4 }
function IsRechtSpoor(Name: string): Boolean;
var
  Nr: Byte;
begin
  Result := IsSpoor(Name, Nr) and (Nr in [5, 10]);
end;

{ @00486518 }
function IsBochtSpoor(Name: string; var Nr: Byte): Boolean;
begin
  Result := IsSpoor(Name, Nr) and (Nr in [3, 6, 9, 12]);
end;

{ @00486584 }
function IsStation(Name: string; var Nr: Byte): Boolean;
begin
  if Name = 'Hoofdstation' then
  begin
    Nr := 10;
    Result := True;
  end
  else if StartsWith(Name, 'Station') then
  begin
    Nr := StrToIntDef0(Copy(Name, 8, 2));
    Result := True;
  end
  else
    Result := False;
end;

{ @0048664C }
function IsTreinBestemming(Name: string): Boolean;
var
  Nr: Byte;
begin
  Result := (Name = 'AndereStad') or IsStation(Name, Nr);
end;

{ @004866C8 }
function IsBebouwing(Name: string): Boolean;
begin
  Result := (Name = 'Laagbouw') or (Name = 'Middenbouw') or
    (Name = 'Hoogbouw') or (Name = 'Kantoor') or (Name = 'Molen');
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
  D: Double;
begin
  D := (P.X - OriginX) / TileW / 2 + (P.Y - OriginY) / TileW;
  Result.X := Round(D);
  Result.Y := Round((P.Y - OriginY) / TileW * 2 - D);
end;

{ @00486950 }
function ScreenToGrid(P: TPoint): TPoint;
begin
  Result := ScreenToWorld(P);
  Result := WorldToGrid(Result);
end;

{ @00486988 }
function ContentsInfoByContents(Name: string): TContentsInfo;
var
  I: Integer;
begin
  for I := 0 to ContentsCount - 1 do
    if Contents[I].Name = Name then
    begin
      Result := Contents[I];
      Exit;
    end;
  Fout('ContentsInfoByContents: ' + Name + ' not found');
end;

{ @00486A78 }
function ContentsDescription(Name: string): string;
begin
  Result := ContentsInfoByContents(Name).Description;
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
procedure Fout(Msg: string);
begin
  frmMain.Hide;
  Msg := Msg + #0;
  Application.MessageBox(@Msg[1], 'Foutmelding', MB_OK);
  raise EMathError.Create(Msg);
end;

end.

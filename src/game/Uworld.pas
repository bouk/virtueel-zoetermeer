unit Uworld;

{ The city model: the 45x45 isometric grid of cells (TCell), the ten districts
  (TWijk, laid out by wijken.dat), road/rail connectivity, the traffic and
  travel time simulation, the per-district appreciation scores, the yearly
  report and saving/loading the city as text lines.
  Decompiled from ROS.exe v1.1, code 00480258-00485A33. }

{$I zm.inc}

interface

uses
  Windows, Classes, Usett, uTool;

const
  WorldSize = 45;     { cells per side; coordinates 0..44 }
  WijkCount = 10;     { districts 'A'..'J' in wijken.dat }
  GeenWijk = 10;      { TCell.Wijk for cells outside every district ('.') }

type
  TWorld = class;

  { VMT 004802A4, instance size $58. One grid cell. }
  TCell = class(TObject)
  public
    Contents: string;              { +0x04 object name (Objecten.csv), default 'Onbereikbaar' }
    Param: string;                 { +0x08 variant: house image, road bitmask '05', rail/klaver piece, district name for 'Sloop' }
    Wijk: Integer;                 { +0x0C district index 0..9, GeenWijk = none }
    X: Integer;                    { +0x10 }
    Y: Integer;                    { +0x14 }
    World: TWorld;                 { +0x18 }
    Wegen: Integer;                { +0x1C bitmask of connected road neighbours (bit i = Dirs[i]) }
    Bebouwing: Integer;            { +0x20 bitmask of neighbouring buildings (Bakst only) }
    Gelijk: Integer;               { +0x24 bitmask of the 8 neighbours with the same contents }
    Links: array[0..3] of TCell;   { +0x28 connected neighbour per direction (or nil) }
    Drukte: Double;                { +0x38 traffic load }
    Vorige: TCell;                 { +0x40 previous cell on the route (ZoekRoute) }
                                   { +0x44 (alignment) }
    Afstand: Double;               { +0x48 route distance (ZoekRoute), -1 = not visited }
    Hoofd: TCell;                  { +0x50 main cell of a multi-cell object, nil for the main cell itself }
    Bereikbaar: Boolean;           { +0x54 connected to a station / the outside world }
    constructor Create(AWorld: TWorld; AX, AY: Integer);
    destructor Destroy; override;
    procedure Init;
    procedure SetParam(S: string);
    function IsKlaverSnel: Boolean;
    function Buur(DX, DY: Integer): TCell;
    function WegContents: string;
    function IsBestemming: Boolean;
    procedure Update;
    function Reistijd: Double;
    function DrukteFactor: Double;
    function Pos: TPoint;
    procedure SetContents(S: string);
    procedure Bouw(NewContents: string);
    function HeeftWeg(Mask: Integer; Aanpassen: Boolean): Boolean;
    procedure KanBouwen(NewContents: string; var Msg: string);
  end;

  { VMT 00480310, instance size $10. }
  TCellList = class(TList)
  public
    function Add(Cell: TCell): TCell;
    function GetCell(Index: Integer): TCell;
    function IndexOf(Cell: TCell): Integer;
    property Cells[Index: Integer]: TCell read GetCell; default;
  end;

  { VMT 00480378, instance size $18. A district. }
  TWijk = class(TObject)
  public
    Naam: string;                  { +0x04 }
    X: Integer;                    { +0x08 centre (grid) }
    Y: Integer;                    { +0x0C }
    Inwoners: Integer;             { +0x10 number of house cells (Laag/Midden/Hoogbouw) }
    Waarden: TStringList;          { +0x14 contents name -> Integer (in Objects[]) }
    constructor Create(AName: string; AX, AY: Integer);
    destructor Destroy; override;
    function GetWaarde(Key: string): Integer;
    procedure SetWaarde(Key: string; Value: Integer);
    procedure ClearWaarden;
  end;

  { VMT 004803DC, instance size $2000. }
  TWorld = class(TObject)
  public
    Woningen: Integer;             { +0x0004 house cells + 10 }
    Settings: TSettings;           { +0x0008 }
    Status: TStatus;               { +0x000C }
    Cells: array[0..WorldSize - 1, 0..WorldSize - 1] of TCell;  { +0x0010 [X, Y] }
    Changes: TPosList;             { +0x1FB4 cells that must be redrawn (TPos X,Y) }
    Aantallen: TStringList;        { +0x1FB8 contents name -> count (in Objects[]) }
    Bebouwing: TCellList;          { +0x1FBC houses, offices and mills }
    Bestemmingen: TCellList;       { +0x1FC0 stations and 'AndereStad' }
                                   { +0x1FC4 (alignment) }
    Reistijd: Double;              { +0x1FC8 mean travel time, -1 = not everything reachable }
    Banen: Integer;                { +0x1FD0 offices + mills + 4 }
    OpenWijken: Integer;           { +0x1FD4 number of districts opened so far }
    Wijken: array[0..WijkCount - 1] of TWijk;  { +0x1FD8 }
    constructor Create(ASettings: TSettings; AStatus: TStatus);
    destructor Destroy; override;
    function ZoekRoute(Van, Naar: TCell; Route: TCellList): Double;
    procedure OpenWijk(Index: Integer);
    function GetCell(AX, AY: Integer): TCell;
    function GetAantal(Name: string): Integer;
    procedure SetAantal(Name: string; Value: Integer);
    procedure Clear;
    procedure Changed(AX, AY: Integer);
    procedure PopChanged(var AX, AY: Integer);
    function Score(Criterium: Byte): Double;
    procedure Herbereken(Timer: Boolean);
    procedure BerekenReistijd;
    function Bereikbaar(var Msg: string): Boolean;
    function Level: TLevel;
    function Waardering(Criterium: Byte; WijkIndex: Integer): Double;
    function Werkgelegenheid(var Msg: string): Double;
    procedure Rapport(Lists: array of TStrings; var Totaal, Opbrengst, Kosten: Integer;
      Detail: Boolean);
    procedure Advies(var Msg: string);
    function SaveToStrings: TStringList;
    procedure LoadFromStrings(List: TStrings);
  end;

const
  { 004891C0: the four road directions (bit i of TCell.Wegen) }
  Dirs: array[0..3] of TPoint = ((X: 0; Y: -1), (X: 1; Y: 0), (X: 0; Y: 1), (X: -1; Y: 0));

implementation

uses
  SysUtils, Uconst, uString, Fmain, Uview;

type
  TNeighbour = record
    DX, DY: Integer;
    Mask: Integer;
  end;

const
  { 004891E0: probe offsets around a 3x3 klaverblad (cloverleaf) }
  KlaverDirs: array[0..3] of TPoint = ((X: -1; Y: -3), (X: 1; Y: -1), (X: -1; Y: 1), (X: -3; Y: -1));
  { 00489200: road bit of the opposite direction, per Dirs[] }
  OppositeMask: array[0..3] of Integer = (4, 8, 1, 2);
  { 00489210: TCell.Bebouwing bits set by a building in direction Dirs[i] }
  BebouwingMask: array[0..3] of Integer = ($31, $62, $C4, $98);
  { 00489220: the 8 neighbours and their TCell.Gelijk bit }
  Neighbours: array[0..7] of TNeighbour = (
    (DX: -1; DY: -1; Mask: 16), (DX: 0; DY: -1; Mask: 1), (DX: 1; DY: -1; Mask: 32),
    (DX: -1; DY: 0; Mask: 8),                              (DX: 1; DY: 0; Mask: 2),
    (DX: -1; DY: 1; Mask: 128), (DX: 0; DY: 1; Mask: 4), (DX: 1; DY: 1; Mask: 64));
  { 00489280: the diagonal neighbours (TCell.Bebouwing bits 16 shl i) }
  Diagonals: array[0..3] of TPoint = ((X: -1; Y: -1), (X: 1; Y: -1), (X: 1; Y: 1), (X: -1; Y: 1));

{ @004803E4 }
constructor TCell.Create(AWorld: TWorld; AX, AY: Integer);
begin
  inherited Create;
  X := AX;
  Y := AY;
  World := AWorld;
  Init;
end;

{ @0048043C }
destructor TCell.Destroy;
begin
  inherited Destroy;
end;

{ @00480464 }
procedure TCell.Init;
begin
  Contents := 'Onbereikbaar';
  Param := '';
  Bebouwing := 0;
  Wegen := 0;
  Gelijk := 0;
  Bereikbaar := True;
end;

{ @004804AC }
procedure TCell.SetParam(S: string);
begin
  { NOTE: both branches are identical in the original. }
  if Contents = 'kContKlaverblad' then
    Param := S
  else
    Param := S;
end;

{ @0048052C }
function TCell.IsKlaverSnel: Boolean;
begin
  Result := False;
  if (Contents = 'Klaver') and (Length(Param) >= 2) then
    case StrToInt(DelLeft(Param, 1)) of
      1, 3..5, 7: Result := True;
    end;
end;

{ @004805C0 }
function TCell.Buur(DX, DY: Integer): TCell;
begin
  Result := World.GetCell(X + DX, Y + DY);
end;

{ @004805D0 }
function TCell.WegContents: string;
begin
  Result := Contents;
  if Result = 'Klaver' then
    case StrToIntDef0(Copy(Param, 2, Length(Param))) of
      1, 3..5, 7: Result := 'Snel';
    end;
end;

{ @00480684 }
function TCell.IsBestemming: Boolean;
begin
  if Self = nil then
    Result := False
  else
    Result := (Contents = 'Laagbouw') or (Contents = 'Middenbouw') or
      (Contents = 'Hoogbouw') or (Contents = 'Kantoor') or (Contents = 'Molen') or
      (Contents = 'AndereStad');
end;

{ @00480C20 }
procedure TCell.Update;

  { @00480764 }
  function IsGelijk(Cell: TCell): Boolean;
  begin
    if Cell = nil then
      Result := False
    else
      Result := Cell.Contents = Contents;
  end;

  { @0048078C }
  function SluitAan(Cell, Other: TCell): Boolean;
  var
    A, B: string;
    Overgang: Boolean;
    C1, C2, T: TCell;
    I: Integer;
  begin
    if (Cell = nil) or (Other = nil) then
      Result := False
    else if Cell.IsKlaverSnel and Other.IsKlaverSnel then
      Result := True
    else
    begin
      A := Cell.WegContents;
      B := Other.WegContents;
      { NOTE: the second half tests A/Cell.Param twice; Other is not used there. }
      Overgang := (IsSnelweg(A, Cell.Param) and IsGewoneWeg(B, Other.Param)) or
        (IsGewoneWeg(A, Cell.Param) and IsSnelweg(A, Cell.Param));
      Result := IsWeg(A, Cell.Param) and IsWeg(B, Other.Param) and not Overgang;
      if Overgang then
      begin
        C1 := Cell;
        C2 := Other;
        if IsSnelweg(A, Cell.Param) then
        begin
          T := C2;
          C2 := C1;
          C1 := T;
        end;
        for I := 0 to 3 do
          if (C2.X + Dirs[I].X = C1.X) and (C2.Y + Dirs[I].Y = C1.Y) and
            C2.HeeftWeg(1 shl I, True) then
            Result := True;
      end;
    end;
  end;

  { @004808F0 }
  function IsVerbonden(Cell, Other: TCell): Boolean;
  var
    Nr: Byte;
    C1, C2, T: TCell;
    I: Integer;
  begin
    if (Cell = nil) or (Other = nil) or (Cell.Contents = 'Sloop') or
      (Other.Contents = 'Sloop') or (Cell.Contents = 'Onbereikbaar') or
      (Other.Contents = 'Onbereikbaar') then
    begin
      Result := False;
      Exit;
    end;
    if IsWeg(Cell.Contents, Cell.Param) and IsWeg(Other.Contents, Other.Param) and
      ((Cell.Param = 'Snel') or (Other.Param = 'Snel')) then
    begin
      Result := True;
      Exit;
    end;
    if (IsWeg(Cell.Contents, Cell.Param) and IsStation(Other.Contents, Nr)) or
      (IsWeg(Other.Contents, Other.Param) and IsStation(Cell.Contents, Nr)) or
      (IsStation(Cell.Contents, Nr) and IsStation(Other.Contents, Nr)) then
    begin
      Result := True;
      Exit;
    end;
    C1 := Cell;
    C2 := Other;
    if (IsSnelweg(C1.Contents, C1.Param) and (C2.Contents = 'Klaver')) or
      (IsSnelweg(C2.Contents, C2.Param) and (C1.Contents = 'Klaver')) then
    begin
      { make C1 the klaverblad }
      if C2.Contents = 'Klaver' then
      begin
        T := C2;
        C2 := C1;
        C1 := T;
      end;
      if C1.Hoofd <> nil then
        C1 := C1.Hoofd;
      if (C2 = C1.Buur(1, -1)) or (C2 = C1.Buur(-1, -3)) or
        (C2 = C1.Buur(-1, 1)) or (C2 = C1.Buur(-3, -1)) then
      begin
        Result := True;
        Exit;
      end;
    end;
    if SluitAan(C1, C2) then
      Result := True
    else
      Result := (C1.IsBestemming and IsWeg(C2.Contents, 'X')) or
        (C2.IsBestemming and IsWeg(C1.Contents, 'X'));
    { NOTE: the second test pairs C2.Contents with C1.Param. }
    if IsSnelweg(C1.Contents, C1.Param) or IsSnelweg(C2.Contents, C1.Param) then
      if IsWeg(C1.Contents, C1.Param) and IsWeg(C2.Contents, C2.Param) then
      begin
        if IsSnelweg(C2.Contents, C2.Param) and (C2.Param <> 'Snel') then
        begin
          T := C2;
          C2 := C1;
          C1 := T;
        end;
        if C2.Param = 'Snel' then
          Result := True
        else
          for I := 0 to 3 do
            if (Dirs[I].X + C1.X = C2.X) and (Dirs[I].Y + C1.Y = C2.Y) and
              ((StrToIntDef0(C1.Param) and (1 shl I)) = 0) then
              Result := False;
      end;
  end;


var
  I: Integer;
  C: TCell;
begin
  Bebouwing := 0;
  Wegen := 0;
  Gelijk := 0;
  for I := 0 to 7 do
    if IsGelijk(Buur(Neighbours[I].DX, Neighbours[I].DY)) then
      Inc(Gelijk, Neighbours[I].Mask);
  for I := 0 to 3 do
  begin
    C := Buur(Dirs[I].X, Dirs[I].Y);
    if IsVerbonden(C, Self) then
      Links[I] := C
    else
      Links[I] := nil;
  end;
  if IsWeg(Contents, Param) and (Contents <> 'Klaver') then
  begin
    if Contents = 'Bakst' then
    begin
      for I := 0 to 3 do
        if Buur(Dirs[I].X, Dirs[I].Y).IsBestemming then
          Bebouwing := Bebouwing or BebouwingMask[I];
      for I := 0 to 3 do
        if Buur(Diagonals[I].X, Diagonals[I].Y).IsBestemming then
          Bebouwing := Bebouwing or (16 shl I);
    end;
    for I := 0 to 3 do
    begin
      C := Buur(Dirs[I].X, Dirs[I].Y);
      if SluitAan(C, Self) then
        if IsSnelweg(Contents, Param) then
        begin
          { NOTE: C.Contents is tested with Self's Param. }
          if not IsSnelweg(C.Contents, Param) or C.HeeftWeg(OppositeMask[I], False) then
            Inc(Wegen, 1 shl I);
        end
        else
          Inc(Wegen, 1 shl I);
    end;
    if IsSnelweg(Contents, 'X') then
      case Wegen of
        7, 11, 13..15: ;
      else
        SetParam(ZeroPad(IntToStr(Wegen), 2));
      end;
    for I := 0 to 3 do
    begin
      C := Buur(Dirs[I].X, Dirs[I].Y);
      if IsVerbonden(C, Self) then
        Links[I] := C
      else
        Links[I] := nil;
    end;
    World.Changed(X, Y);
  end;
end;

{ @00480F14 }
function TCell.Reistijd: Double;
var
  Info: TContentsInfo;
  Cap, MaxSpeed, Speed: Double;
begin
  if IsWeg(Contents, Param) or (Contents = 'Klaver') then
  begin
    Info := ContentsInfoByContents(Contents);
    Cap := Info.Capaciteit;
    MaxSpeed := Info.MaxSpeed;
    if Cap = 0 then
      Result := 80
    else
    begin
      if Drukte > Cap then
        Speed := MaxSpeed / Sqr(Drukte / Cap)
      else
        Speed := MaxSpeed / Exp(Drukte / (4 * Cap));
      Result := 80 / Speed;
    end;
  end
  else
    Result := 0.5;
end;

{ @00481024 }
function TCell.DrukteFactor: Double;
var
  Info: TContentsInfo;
  Cap: Double;
begin
  Result := 0;
  if IsWeg(Contents, Param) or (Contents = 'Klaver') then
  begin
    Info := ContentsInfoByContents(Contents);
    Cap := Info.Capaciteit;
    Result := Drukte;
    if Drukte > Cap then
      Result := Drukte / Cap + Drukte - 1;
    if IsSnelweg(Contents, Param) and (Result > 1) then
      Result := Result - 1;
  end;
end;

{ @00481110 }
function TCell.Pos: TPoint;
begin
  Result.X := X;
  Result.Y := Y;
end;

{ @0048111C }
procedure TCell.SetContents(S: string);
begin
  Contents := S;
end;

{ @00481168 }
function RandomItem(List: TStrings): string;
begin
  if List.Count = 0 then
    Result := ''
  else
    Result := RandomString(List);
end;

{ @00481190 }
procedure TCell.Bouw(NewContents: string);
var
  Old, OldParam: string;
  OldInfo, Info: TContentsInfo;
  Kosten: Integer;
  Nr, Nr2: Byte;
  Grondvlak: TPosList;
  I, J, K: Integer;
  C: TCell;
  Mask, Prev: Integer;
  DX, DY: Integer;
  W: TWorld;
begin
  if NewContents = Contents then
    Exit;
  Old := Contents;
  OldParam := Param;
  OldInfo := ContentsInfoByContents(Old);
  if World.Status.Level = 1 then
    Kosten := -OldInfo.Prijs   { slopen levert in level 1 geld op }
  else
    Kosten := 0;
  Info := ContentsInfoByContents(NewContents);
  Inc(Kosten, Info.Prijs);
  if Kosten > World.Status.Geld then
  begin
    MessageBeep(10);
    Exit;
  end;
  World.Status.Geld := World.Status.Geld - Kosten;

  if IsBebouwing(Old) then
    World.Bebouwing.Remove(Self);
  if IsBebouwing(NewContents) then
    World.Bebouwing.Add(Self);
  if IsTreinBestemming(Old) then
    World.Bestemmingen.Remove(Self);
  if IsTreinBestemming(NewContents) then
    World.Bestemmingen.Add(Self);

  Param := '';
  if NewContents <> 'Sloop' then
  begin
    { a straight rail laid over a road keeps the road as its Param }
    if IsWeg(Contents, 'X') and IsSpoor(NewContents, Nr) and (Nr in [5, 10]) then
    begin
      SetParam(Contents);
      Contents := NewContents;
    end
    else
      Contents := NewContents;
  end;

  { the other cells of the ground plan, relative to this (main) cell }
  Grondvlak := TPosList.Create;
  for I := 0 to Info.GrondvlakX - 1 do
    for J := 0 to Info.GrondvlakY - 1 do
      if I + J <> 0 then
        Grondvlak.Add(TPos.Create(-I, -J));

  if NewContents = 'Sloop' then
  begin
    if Hoofd <> nil then
    begin
      { NOTE: Grondvlak is leaked on this path. }
      Hoofd.Bouw(NewContents);
      Exit;
    end;
    OldInfo := ContentsInfoByContents(Contents);
    for I := 0 to OldInfo.GrondvlakX - 1 do
      for J := 0 to OldInfo.GrondvlakY - 1 do
      begin
        C := Buur(-I, -J);
        C.Contents := NewContents;
        C.SetParam(World.Wijken[C.Wijk].Naam);
        C.Hoofd := nil;
        World.Changed(C.X, C.Y);
      end;
  end;

  if Contents = 'Laagbouw' then
    Param := RandomItem(World.Level.Laag)
  else if Contents = 'Middenbouw' then
    Param := RandomItem(World.Level.Midden)
  else if Contents = 'Hoogbouw' then
    Param := RandomItem(World.Level.Hoog)
  else if Contents = 'Kantoor' then
    Param := RandomItem(World.Level.Kantoor)
  else if Contents = 'Park' then
    Param := IntToStr(Random(5) + 1)
  else if Contents = 'Station' then
  begin
    if (IsSpoor(Buur(0, 1).Contents + Buur(0, 1).Param, Nr) and (Nr = 5)) or
       (IsSpoor(Buur(0, -1).Contents + Buur(0, -1).Param, Nr2) and (Nr2 = 5)) then
      SetParam('05')
    else
      SetParam('10');
  end;

  for K := 0 to Grondvlak.Count - 1 do
  begin
    C := Buur(Grondvlak.GetItem(K).X, Grondvlak.GetItem(K).Y);
    if C <> nil then
    begin
      C.Contents := Contents;
      C.Hoofd := Self;
      if Contents = 'Klaver' then
        C.SetParam('-' + IntToStr(K + 1))
      else
        C.SetParam(Param);
    end;
  end;
  FreeList(Grondvlak);
  Grondvlak.Free;

  { highway / cloverleaf: Param = bitmask of the connected directions }
  if IsSnelweg(Contents, 'X') or (Contents = 'Klaver') then
  begin
    Mask := 0;
    for I := 0 to 3 do
    begin
      if Contents = 'Klaver' then
        C := Buur(KlaverDirs[I].X, KlaverDirs[I].Y)
      else
        C := Buur(Dirs[I].X, Dirs[I].Y);
      if C <> nil then
      begin
        Prev := Mask;
        if C.HeeftWeg(OppositeMask[I], True) then
          Inc(Mask, 1 shl I);
        case Mask of
          7, 11, 13..15: Mask := Prev;   { no T-junctions or crossings }
        end;
      end;
    end;
    SetParam(ZeroPad(IntToStr(Mask), 2));
  end;

  if Contents = 'Klaver' then
  begin
    for DX := -3 to 1 do
      for DY := -3 to 1 do
      begin
        C := Buur(DX, DY);
        if C <> nil then
          C.Update;
      end;
  end
  else
  begin
    for I := 1 to 2 do
      for DX := -2 to 2 do
        for DY := -2 to 2 do
        begin
          C := Buur(DX, DY);
          if C <> nil then
            C.Update;
        end;
  end;

  W := World;
  W.Changed(X, Y);
  W.SetAantal(Old, W.GetAantal(Old) - 1);
  W.SetAantal(Contents, W.GetAantal(Contents) + 1);
  W.Herbereken(IsTreinBestemming(Old) or IsTreinBestemming(Contents) or
    IsBebouwing(Old) or IsBebouwing(Contents) or
    IsWeg(Contents, Param) or IsWeg(Old, OldParam) or
    (Contents = 'Klaver') or (Old = 'Klaver'));
end;

{ @00481AC0 }
function TCell.HeeftWeg(Mask: Integer; Aanpassen: Boolean): Boolean;
var
  V: Integer;
begin
  if Param = 'Snel' then
    Result := True
  else
  begin
    Result := IsGewoneWeg(Contents, Param);
    if IsSnelweg(Contents, Param) then
    begin
      V := StrToInt(Param) or Mask;
      case V of
        1..6, 8..10, 12:
          begin
            Result := True;
            if Aanpassen then
              SetParam(ZeroPad(IntToStr(V), 2));
          end;
      end;
    end
    else if Contents = 'Klaver' then
    begin
      V := 0;
      if Param <> '' then
        V := StrToInt(Param);
      Result := ((V = -7) and (Mask = 1)) or ((V = -3) and (Mask = 2)) or
        ((V = -1) and (Mask = 4)) or ((V = -5) and (Mask = 8));
    end;
  end;
end;

{ @00481EEC }
procedure TCell.KanBouwen(NewContents: string; var Msg: string);
var
  Onder: string;   { EBP-0xC: NOTE: never assigned, always '' }

  { @00481C0C }
  procedure CheckCell(S: string);
  begin
    if S = 'Onbereikbaar' then
      Msg := 'Nog geen onderdeel van Zoetermeer'
    else if S <> 'Sloop' then
    begin
      if not (IsRechtSpoor(NewContents) and IsWeg(S, 'X')) then
      begin
        if ContentsDescription(S) = 'Spoorrails' then
          Msg := 'Er ligt al ' + ContentsDescription(S)
        else
          Msg := 'Er staat al een ' + ContentsDescription(S);
        if IsRechtSpoor(S) and IsWeg(NewContents, Onder) then
          Msg := Msg + '\nWil je een spoorwegovergang, breek dan het spoor af,\nbouw de weg en leg dan het spoor erover.';
      end;
    end;
  end;

  { @00481E50 }
  function IsAt(DX, DY: Integer; C, P: string): Boolean;
  var
    Cell: TCell;
  begin
    Cell := Buur(DX, DY);
    Result := (Cell <> nil) and (Cell.Contents = C) and (Cell.Hoofd = nil) and
      ((P = '') or (Cell.Param = P));
  end;

var
  Mask, I, J, Kosten: Integer;
  C: TCell;
  Nr, Nr2: Byte;
  Ok: Boolean;
begin
  if (X = 15) and (Y = 27) then
    Msg := '';   { NOTE: debugging leftover }
  Msg := '';
  if NewContents = '' then
    Exit;
  if not InMap(X, Y) then
  begin
    Msg := 'Buiten het speelveld';
    Exit;
  end;
  if World.Level.OpenWijk < Wijk then
  begin
    Msg := '(Nog) geen onderdeel van Zoetermeer';
    Exit;
  end;
  if ContentsInfoByContents(NewContents).Prijs > World.Status.Geld then
  begin
    Msg := 'Te duur.';
    if World.Status.Level = 1 then
      Msg := 'Te duur. Sloop iets om geld te krijgen (alleen in dit level).';
    Exit;
  end;

  if NewContents = 'Sloop' then
  begin
    if World.Status.Level = 1 then
      Kosten := -ContentsInfoByContents(Contents).Prijs
    else
      Kosten := 0;
    if Kosten > World.Status.Geld then
      Msg := 'Te duur.'
    else if Contents = 'Onbereikbaar' then
      Msg := 'Nog geen onderdeel van Zoetermeer';
    Exit;
  end;

  CheckCell(Contents);
  if Msg <> '' then
    Exit;

  if IsSnelweg(NewContents, '') then
  begin
    Mask := 0;
    for I := 0 to 3 do
    begin
      C := Buur(Dirs[I].X, Dirs[I].Y);
      if (C <> nil) and C.HeeftWeg(OppositeMask[I], False) then
        Inc(Mask, 1 shl I);
    end;
    case Mask of
      7, 11, 13..15:
        begin
          Msg := 'Hier kan geen ' + ContentsDescription(NewContents) + ' worden geplaatst.';
          Exit;
        end;
    end;
  end
  else if IsSpoor(NewContents, Nr) then
  begin
    Ok := False;
    if NewContents = 'Hoofdstation' then
    begin
      { NOTE: Buur may return nil here (no check in the original). }
      for I := -2 to 0 do
      begin
        C := Buur(1, I);
        if IsSpoor(C.Contents, Nr2) and (Nr2 = 10) then
          Ok := True;
        C := Buur(-2, I);
        if IsSpoor(C.Contents, Nr2) and (Nr2 = 10) then
          Ok := True;
      end;
    end
    else
    begin
      if not Ok and (NewContents = 'Rails03') then
        Ok := (IsAt(-1, -2, 'Rails05', '') or IsAt(-1, -2, 'Station', '05')) and
              (IsAt(-1, -3, 'Rails05', '') or IsAt(-1, -3, 'Station', '05')) or
              (IsAt(1, 0, 'Rails10', '') or IsAt(1, 0, 'Station', '10')) and
              (IsAt(2, 0, 'Rails10', '') or IsAt(2, 0, 'Station', '10'));
      if not Ok and (NewContents = 'Rails06') then
        Ok := (IsAt(-1, 1, 'Rails05', '') or IsAt(-1, 1, 'Station', '05')) and
              (IsAt(-1, 2, 'Rails05', '') or IsAt(-1, 2, 'Station', '05')) or
              (IsAt(1, -1, 'Rails10', '') or IsAt(1, -1, 'Station', '10')) and
              (IsAt(2, -1, 'Rails10', '') or IsAt(2, -1, 'Station', '10'));
      if not Ok and (NewContents = 'Rails09') then
        Ok := (IsAt(0, -2, 'Rails05', '') or IsAt(0, -2, 'Station', '05')) and
              (IsAt(0, -3, 'Rails05', '') or IsAt(0, -3, 'Station', '05')) or
              (IsAt(-2, 0, 'Rails10', '') or IsAt(-2, 0, 'Station', '10')) and
              (IsAt(-3, 0, 'Rails10', '') or IsAt(-3, 0, 'Station', '10'));
      if not Ok and (NewContents = 'Rails12') then
        Ok := (IsAt(0, 1, 'Rails05', '') or IsAt(0, 1, 'Station', '05')) and
              (IsAt(0, 2, 'Rails05', '') or IsAt(0, 2, 'Station', '05')) or
              (IsAt(-2, -1, 'Rails10', '') or IsAt(-2, -1, 'Station', '10')) and
              (IsAt(-3, -1, 'Rails10', '') or IsAt(-3, -1, 'Station', '10'));
      { NOTE: unlike the other tests, a 'Station' is re-tested even when Ok is
        already True. }
      if (not Ok and (NewContents = 'Rails05')) or (NewContents = 'Station') then
        Ok := IsAt(0, -1, 'Rails12', '') or IsAt(0, 2, 'Rails09', '') or
              IsAt(1, -1, 'Rails06', '') or IsAt(1, 2, 'Rails03', '') or
              IsAt(0, -1, 'Rails05', '') or IsAt(0, 1, 'Rails05', '') or
              IsAt(0, -1, 'Station', '05') or IsAt(0, 1, 'Station', '05');
      if not Ok and ((NewContents = 'Rails10') or (NewContents = 'Station')) then
        Ok := IsAt(-1, 0, 'Rails03', '') or IsAt(-1, 1, 'Rails06', '') or
              IsAt(2, 0, 'Rails09', '') or IsAt(2, 1, 'Rails12', '') or
              IsAt(-1, 0, 'Rails10', '') or IsAt(1, 0, 'Rails10', '') or
              IsAt(-1, 0, 'Hoofdstation', '') or IsAt(-1, 1, 'Hoofdstation', '') or
              IsAt(-1, 2, 'Hoofdstation', '') or IsAt(2, 0, 'Hoofdstation', '') or
              IsAt(2, 1, 'Hoofdstation', '') or IsAt(2, 2, 'Hoofdstation', '') or
              IsAt(-1, 0, 'Station', '10') or IsAt(1, 0, 'Station', '10');
    end;
    if not Ok then
    begin
      if IsStation(NewContents, Nr) then
        Msg := 'Stations moeten aansluiten aan bestaand spoor.\nSloop desnoods een stuk spoor om ruimte te maken voor het station.'
      else
        Msg := 'Spoorwegen moeten aan bestaande spoorwegen\naansluiten. Bouw nooit twee bochten vlak bij elkaar of\neen bocht vlak bij een station';
      Exit;
    end;
  end;

  { the whole ground plan must be free }
  for I := 0 to ContentsInfoByContents(NewContents).GrondvlakX - 1 do
    for J := 0 to ContentsInfoByContents(NewContents).GrondvlakY - 1 do
      if I + J <> 0 then
      begin
        C := Buur(-I, -J);
        if C = nil then
        begin
          Msg := 'Dit valt buiten het scherm.';
          Exit;
        end;
        CheckCell(C.Contents);
        if Msg <> '' then
          Exit;
      end;
end;

{ ---- TCellList ---- }

{ @00482CCC }
function TCellList.Add(Cell: TCell): TCell;
begin
  inherited Add(Cell);
  Result := Cell;
end;

{ @00482CDC }
function TCellList.GetCell(Index: Integer): TCell;
begin
  Result := TObject(Get(Index)) as TCell;
end;

{ @00482CFC }
function TCellList.IndexOf(Cell: TCell): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Cell = GetCell(I) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

{ ---- TWijk ---- }

{ @00482D2C }
constructor TWijk.Create(AName: string; AX, AY: Integer);
begin
  { NOTE: no inherited Create in the original. }
  Naam := AName;
  X := AX;
  Y := AY;
  Waarden := TStringList.Create;
end;

{ @00482DBC }
destructor TWijk.Destroy;
begin
  Waarden.Free;
  inherited Destroy;
end;

{ @00482DEC }
function TWijk.GetWaarde(Key: string): Integer;
var
  I: Integer;
begin
  I := Waarden.IndexOf(Key);
  if I = -1 then
    Result := 0
  else
    Result := PtrInt(Waarden.Objects[I]);
end;

{ @00482E54 }
procedure TWijk.SetWaarde(Key: string; Value: Integer);
var
  I: Integer;
begin
  I := Waarden.IndexOf(Key);
  if I = -1 then
    Waarden.AddObject(Key, TObject(PtrInt(Value)))
  else
    Waarden.Objects[I] := TObject(PtrInt(Value));
end;

{ @00482EC4 }
procedure TWijk.ClearWaarden;
var
  I: Integer;
begin
  for I := 0 to Waarden.Count - 1 do
    Waarden.Objects[I] := nil;
end;

{ @00482EF4 }
function NewWijk(Name: string; FX, FY: Double): TWijk;
begin
  Result := TWijk.Create(Name, Round(FX * 44), Round(FY * 44));
end;

{ ---- TWorld ---- }

{ @00482F6C }
constructor TWorld.Create(ASettings: TSettings; AStatus: TStatus);
var
  SumX: array[0..WijkCount - 1] of Integer;    { EBP-0x64 }
  Count: array[0..WijkCount - 1] of Integer;   { EBP-0x3C }
  SumY: array[0..WijkCount - 1] of Integer;    { EBP-0x8C }
  Lines: TStringList;
  I, AX, AY: Integer;
  S: string;
  C: Char;
begin
  inherited Create;
  Status := AStatus;
  Settings := ASettings;
  Bebouwing := TCellList.Create;
  Bestemmingen := TCellList.Create;
  Wijken[0] := NewWijk('Dorp', 0.5, 0.55);
  Wijken[1] := NewWijk('Palenstein', 0.65, 0.48);
  Wijken[2] := NewWijk('Driemanspolder', 0.37, 0.55);
  Wijken[3] := NewWijk('Meerzicht', 0.12, 0.55);
  Wijken[4] := NewWijk('Buytenwegh De Leyens', 0.36, 0.2);
  Wijken[5] := NewWijk('Seghwaert', 0.67, 0.12);
  Wijken[6] := NewWijk('Stadshart', 0.5, 0.43);
  Wijken[7] := NewWijk('Noordhove', 0.87, 0.3);
  Wijken[8] := NewWijk('Rokkeveen', 0.5, 0.88);
  Wijken[9] := NewWijk('Oosterheem', 0.87, 0.49);
  for I := 0 to WijkCount - 1 do
  begin
    SumX[I] := 0;
    SumY[I] := 0;
    Count[I] := 0;
  end;
  Lines := TStringList.Create;
  Lines.LoadFromFile(AddPath(AppPath, 'wijken.dat'));
  for AX := 0 to WorldSize - 1 do
    for AY := 0 to WorldSize - 1 do
    begin
      S := Lines[AY];
      C := S[AX + 1];
      Cells[AX, AY] := TCell.Create(Self, AX, AY);
      case C of
        'A': Cells[AX, AY].Wijk := 0;
        'B': Cells[AX, AY].Wijk := 1;
        'C': Cells[AX, AY].Wijk := 2;
        'D': Cells[AX, AY].Wijk := 3;
        'E': Cells[AX, AY].Wijk := 4;
        'F': Cells[AX, AY].Wijk := 5;
        'G': Cells[AX, AY].Wijk := 6;
        'H': Cells[AX, AY].Wijk := 7;
        'I': Cells[AX, AY].Wijk := 8;
        'J': Cells[AX, AY].Wijk := 9;
        '.': Cells[AX, AY].Wijk := GeenWijk;
      end;
      { NOTE: any other character leaves Wijk at 0 (instance memory is zeroed). }
      if Cells[AX, AY].Wijk <> GeenWijk then
      begin
        Inc(Count[Cells[AX, AY].Wijk]);
        Inc(SumX[Cells[AX, AY].Wijk], AX);
        Inc(SumY[Cells[AX, AY].Wijk], AY);
      end;
    end;
  Lines.Free;
  for I := 0 to WijkCount - 1 do
  begin
    Wijken[I].X := Round(SumX[I] / Count[I]);
    Wijken[I].Y := Round(SumY[I] / Count[I]);
  end;
  Aantallen := TStringList.Create;
  Changes := TPosList.Create;
end;

{ @004835B4 }
destructor TWorld.Destroy;
begin
  { NOTE: the cells and districts are never freed. }
  Aantallen.Free;
  if Changes <> nil then
  begin
    FreeList(Changes);
    Changes.Free;
  end;
  Bebouwing.Free;
  Bestemmingen.Free;
  inherited Destroy;
end;

{ @00483614 }
function TWorld.ZoekRoute(Van, Naar: TCell; Route: TCellList): Double;
var
  Open: TCellList;          { EBP-0x18 }
  Doelen: TCellList;        { EBP-0x14 }
  L: TCellList;
  AX, AY, I, D: Integer;
  C, N: TCell;
  Best: TCell;              { EBP-0x34 }
  BestNaar: TCell;          { EBP-0x38 }
  BestVan: TCell;           { EBP-0x3C }
  BestAfstand: Double;      { EBP-0x30 }
  A: Double;                { EBP-0x28 }
  Dood: Boolean;            { EBP-0x3E }
  Nr: Byte;                 { EBP-0x3D }
begin
  Open := TCellList.Create;
  Open.Add(Van);
  Doelen := TCellList.Create;
  Doelen.Add(Naar);
  for AX := 0 to WorldSize - 1 do
    for AY := 0 to WorldSize - 1 do
      if GetCell(AX, AY) <> nil then
      begin
        GetCell(AX, AY).Vorige := nil;
        GetCell(AX, AY).Afstand := -1;
      end;
  Van.Afstand := 0;
  Best := Naar;
  repeat
    BestNaar := nil;
    BestAfstand := -1;
    BestVan := nil;
    for I := Open.Count - 1 downto 0 do
    begin
      C := Open[I];
      Dood := True;
      for D := 0 to 3 do
      begin
        N := C.Links[D];
        if (N <> nil) and (N.Afstand = -1) then
        begin
          if Doelen.IndexOf(N) >= 0 then
          begin
            BestAfstand := C.Afstand;
            Best := N;
            BestNaar := N;
            BestVan := C;
            Dood := False;
            Break;
          end;
          if IsWeg(N.Contents, N.Param) or IsStation(N.Contents, Nr) or
            (N.Contents = 'Klaver') then
            if (C = Van) or not IsBebouwing(C.Contents) then
            begin
              A := N.Reistijd + C.Afstand;
              Dood := False;
              if (A < BestAfstand) or (BestNaar = nil) then
              begin
                BestAfstand := A;
                BestNaar := N;
                BestVan := C;
              end;
            end;
        end;
      end;
      if Dood then
        Open.Remove(C);
    end;
    if BestVan <> nil then
    begin
      Open.Add(BestNaar);
      BestNaar.Vorige := BestVan;
      BestNaar.Afstand := BestAfstand;
    end;
  until (BestVan = nil) or (Doelen.IndexOf(BestNaar) >= 0);
  if BestVan = nil then
    Result := -1
  else
  begin
    C := Best;
    Result := Best.Afstand;
    L := TCellList.Create;
    L.Add(C);
    repeat
      C := C.Vorige;
      L.Add(C);
    until C = Van;
    while L.Count > 0 do
    begin
      Route.Add(L[L.Count - 1]);
      L.Delete(L.Count - 1);
    end;
    L.Free;
  end;
  Open.Free;
  Doelen.Free;
end;

{ @004838BC }
procedure TWorld.OpenWijk(Index: Integer);
var
  AX, AY: Integer;
  MaxX, MaxY, MinX, MinY: Integer;
  P: TPoint;
begin
  { NOTE: the bounding box of the new district is computed but never used. }
  MaxX := 0;
  MaxY := 0;
  MinX := 44;
  MinY := 44;
  OpenWijken := Index + 1;
  for AX := 0 to WorldSize - 1 do
    for AY := 0 to WorldSize - 1 do
      if InMap(AX, AY) and (GetCell(AX, AY) <> nil) and
        (Index >= GetCell(AX, AY).Wijk) and
        (GetCell(AX, AY).Contents = 'Onbereikbaar') then
      begin
        Changed(AX, AY);
        GetCell(AX, AY).Contents := 'Sloop';
        GetCell(AX, AY).SetParam(Wijken[GetCell(AX, AY).Wijk].Naam);
        if Index = GetCell(AX, AY).Wijk then
        begin
          MaxX := IMax(MaxX, AX);
          MaxY := IMax(MaxY, AY);
          MinX := IMin(MinX, AX);
          MinY := IMin(MinY, AY);
        end;
      end;
  P.X := Wijken[Index].X;
  P.Y := Wijken[Index].Y;
  P := GridToWorld(P);
  frmMain.View.ScrollTo(-P.X, -P.Y, Zoom);
end;

{ @00483A7C }
function TWorld.GetCell(AX, AY: Integer): TCell;
begin
  if (AX < 0) or (AX > 44) or (AY < 0) or (AY > 44) then
    Result := nil
  else
    Result := Cells[AX, AY];
end;

{ @00483AA0 }
function TWorld.GetAantal(Name: string): Integer;
var
  I: Integer;
begin
  I := Aantallen.IndexOf(Name);
  if I = -1 then
    Result := 0
  else
    Result := PtrInt(Aantallen.Objects[I]);
end;

{ @00483B10 }
procedure TWorld.SetAantal(Name: string; Value: Integer);
var
  I: Integer;
begin
  I := Aantallen.IndexOf(Name);
  if I = -1 then
    Aantallen.AddObject(Name, TObject(PtrInt(Value)))
  else
    Aantallen.Objects[I] := TObject(PtrInt(Value));
end;

{ @00483B8C }
procedure TWorld.Clear;
var
  AX, AY: Integer;
begin
  Aantallen.Clear;
  Bebouwing.Clear;
  Bestemmingen.Clear;
  for AY := 0 to WorldSize - 1 do
    for AX := 0 to WorldSize - 1 do
    begin
      Cells[AX, AY].Init;
      Changed(AX, AY);
    end;
end;

{ @00483BE4 }
procedure TWorld.Changed(AX, AY: Integer);
begin
  if Changes.IndexOf(AX, AY) = -1 then
    Changes.Add(TPos.Create(AX, AY));
end;

{ @00483C20 }
procedure TWorld.PopChanged(var AX, AY: Integer);
var
  P: TPos;
begin
  P := Changes.GetItem(Changes.Count - 1);
  Changes.Delete(Changes.Count - 1);
  AX := P.X;
  AY := P.Y;
  P.Free;
end;

{ @00483C64 }
function TWorld.Score(Criterium: Byte): Double;
var
  Msg: string;
begin
  if Criterium = 4 then          { Mobiliteit }
  begin
    Result := 100 - ((100 - Reistijd) * Reistijd / (100 + Reistijd) + Reistijd);
    if Reistijd = -1 then
      Result := -100;
  end
  else if Criterium = 5 then     { Werk }
    Result := Werkgelegenheid(Msg) * 100 - 100
  else
    Result := Waardering(Criterium, -1);
end;

{ @00483D30 }
procedure TWorld.Herbereken(Timer: Boolean);
var
  I, J, AX, AY: Integer;
  C: TCell;                      { EBP-0x24 }
  DX, DY: Integer;               { EBP-0x10, EBP-0x14 }
  D: Double;                     { EBP-0x20 }
begin
  for I := 0 to WijkCount - 1 do
  begin
    Wijken[I].ClearWaarden;
    Wijken[I].Inwoners := 0;
    for J := 0 to High(Contents) do
      if System.Pos(Contents[J].Hoofdrubriek, 'CultuurGroenVrijetijdVeiligheidOverlast') > 0 then
        Wijken[I].SetWaarde(Contents[J].Name, Contents[J].BaseScore);
  end;
  Banen := 4;
  Woningen := 10;
  for AY := 0 to WorldSize - 1 do
    for AX := 0 to WorldSize - 1 do
    begin
      C := GetCell(AX, AY);
      if (C.WegContents = 'Laagbouw') or (C.WegContents = 'Middenbouw') or
        (C.WegContents = 'Hoogbouw') then
      begin
        Inc(Woningen);
        Inc(Wijken[C.Wijk].Inwoners);
      end;
      if (C.WegContents = 'Kantoor') or (C.Contents = 'Molen') then
        Inc(Banen);
      for J := 0 to High(Contents) do
        if (C.Contents = Contents[J].Name) and (Contents[J].Afstand <> 0) then
          for I := 0 to WijkCount - 1 do
          begin
            DX := Abs(AX - Wijken[I].X);
            DY := Abs(AY - Wijken[I].Y);
            D := Sqrt(DX * DX + DY * DY);
            D := D / Contents[J].Afstand;
            if D < 1 then
              D := 1;
            Wijken[I].SetWaarde(Contents[J].Name,
              Wijken[I].GetWaarde(Contents[J].Name) + Round(Contents[J].Value / D));
          end;
    end;
  if Timer then
    frmMain.timerRecalc.Tag := 3;
end;

{ @004840B4 }
procedure TWorld.BerekenReistijd;
var
  X, Y: Integer;
  I, J, K, Pass: Integer;
  BestIdx: Integer;
  Best, Dist: Integer;
  D, F: Double;
  Route: TCellList;
  C: TCell;
begin
  for X := 0 to WorldSize - 1 do
    for Y := 0 to WorldSize - 1 do
      if GetCell(X, Y) <> nil then
        GetCell(X, Y).Drukte := 0;
  Route := TCellList.Create;
  Reistijd := 0;
  for I := 0 to Bebouwing.Count - 1 do
    Bebouwing[I].Bereikbaar := True;
  for J := 0 to Bestemmingen.Count - 1 do
    Bestemmingen[J].Bereikbaar := True;
  { NOTE: D is read uninitialised when Bebouwing is empty (as in the original). }
  for Pass := 1 to 2 do
  begin
    for I := 0 to Bebouwing.Count - 1 do
    begin
      { the first two destinations (the outside world) }
      for J := 0 to 1 do
      begin
        Route.Clear;
        D := ZoekRoute(Bebouwing[I], Bestemmingen[J], Route);
        if D = -1 then
        begin
          Bebouwing[I].Bereikbaar := False;
          Bestemmingen[J].Bereikbaar := False;
          Break;
        end;
        F := 1 / Bebouwing.Count;
        Reistijd := D * F + Reistijd;
        for K := 0 to Route.Count - 1 do
        begin
          C := Route[K];
          GetCell(C.X, C.Y).Drukte :=
            GetCell(C.X, C.Y).Drukte + 1 / (IMin(3, Bestemmingen.Count) * 2);
        end;
      end;
      if D = -1 then
        Break;
      { the nearest station }
      if Bestemmingen.Count > 2 then
      begin
        Best := (Bebouwing[I].X - Bestemmingen[2].X) * (Bebouwing[I].X - Bestemmingen[2].X) +
          (Bebouwing[I].Y - Bestemmingen[2].Y) * (Bebouwing[I].Y - Bestemmingen[2].Y);
        BestIdx := 2;
        for K := 3 to Bestemmingen.Count - 1 do
        begin
          Dist := (Bebouwing[I].X - Bestemmingen[K].X) * (Bebouwing[I].X - Bestemmingen[K].X) +
            (Bebouwing[I].Y - Bestemmingen[K].Y) * (Bebouwing[I].Y - Bestemmingen[K].Y);
          if Best > Dist then
          begin
            Best := Dist;
            BestIdx := K;
          end;
        end;
        Route.Clear;
        D := ZoekRoute(Bebouwing[I], Bestemmingen[BestIdx], Route);
        if D = -1 then
        begin
          Bebouwing[I].Bereikbaar := False;
          Bestemmingen[BestIdx].Bereikbaar := False;
          Break;
        end;
        F := 1 / Bebouwing.Count;
        Reistijd := D * F + Reistijd;
        for K := 0 to Route.Count - 1 do
        begin
          C := Route[K];
          GetCell(C.X, C.Y).Drukte := GetCell(C.X, C.Y).Drukte + 1 / 6;
        end;
      end;
      if D = -1 then
        Break;
    end;
    if D = -1 then
      Break;
  end;
  Route.Free;
  if D = -1 then
    Reistijd := -1;
end;

{ @004845BC }
function TWorld.Bereikbaar(var Msg: string): Boolean;
begin
  Msg := '';
  Result := False;
  Result := Reistijd <> -1;
  if not Result then
    Msg := 'Niet alle bewoners kunnen van en naar de stad reizen.';
end;

{ @00484644 }
function TWorld.Level: TLevel;
begin
  Result := Settings.Levels[Status.Level];
end;

{ @0048466C }
function TWorld.Waardering(Criterium: Byte; WijkIndex: Integer): Double;
var
  I, W: Integer;
  R: Double;
begin
  R := 666;
  for I := 0 to High(Contents) do
    if Contents[I].Hoofdrubriek = Criteria[Criterium] then
    begin
      if WijkIndex = -1 then
      begin
        for W := 0 to OpenWijken - 1 do
          if Contents[I].Level <= Status.Level then
          begin
            if R = 666 then
              R := 0;
            R := Wijken[W].GetWaarde(Contents[I].Name) / OpenWijken + R;
          end;
      end
      else
        R := Wijken[WijkIndex].GetWaarde(Contents[I].Name) + R;
    end;
  if (R <> 666) and (R > 0) then
    R := R / 3;
  Result := R;
end;

{ @004847DC }
function TWorld.Werkgelegenheid(var Msg: string): Double;
var
  L: TLevel;
  Nodig, Beschikbaar: Integer;
begin
  L := Level;
  Nodig := Round(L.PercKantoren * Woningen / 100);
  Beschikbaar := Banen;
  if Nodig < Beschikbaar then
    Beschikbaar := Nodig;
  if Nodig = 0 then
    Result := 1
  else
    Result := Beschikbaar / Nodig;
  if Beschikbaar < Nodig then
    Msg := 'te weinig werkgelegenheid'
  else
    Msg := 'genoeg werkgelegenheid';
end;

{ @004848E0 }
function PercentStr(Criterium: Byte; Value: Integer): string;
begin
  Value := IMax(Value + 90, 0);
  Value := IMin(Value, 100);
  if Criterium = 6 then
    Value := 100 - Value;
  Result := IntToStr(Value) + '%';
end;

{ @00484A3C }
procedure TWorld.Rapport(Lists: array of TStrings; var Totaal, Opbrengst, Kosten: Integer;
  Detail: Boolean);
var
  I, J, X, Y: Integer;
  K: Byte;
  V, Total, Mob, Belasting, Waarde: Integer;
  S: string;
  W, F, Prijs: Double;
  Sums: array[0..6] of Integer;
  Has: array[0..6] of Boolean;
  L: TLevel;

  { @00484970 }
  procedure AddLine(Caption, Value: string);
  begin
    Lists[I + 1].Add('  ' + PadRight(Caption + ' : ', 30) + PadLeft(Value, 15));
  end;

begin
  Herbereken(True);
  Opbrengst := 0;
  W := Werkgelegenheid(S);
  Mob := IMax(0, IMin(100, Round(Score(4)) + 100));
  for I := 0 to OpenWijken - 1 do
  begin
    Lists[I + 1].Clear;
    Lists[I + 1].Add(Wijken[I].Naam);
    AddLine('Inwonertal', IntToStr(Wijken[I].Inwoners * 1200));
    for K := 0 to 6 do
    begin
      Sums[K] := 0;
      Has[K] := False;
    end;
    for J := 0 to ContentsCount - 3 do
      if Contents[J].Level <= Status.Level then
      begin
        V := Wijken[I].GetWaarde(Contents[J].Name);
        if V > 0 then
          V := V div 10;
        for K := 0 to 6 do
          if Contents[J].Hoofdrubriek = Criteria[K] then
          begin
            Inc(Sums[K], V);
            Has[K] := True;
            if Detail then
              AddLine('   ' + Contents[J].Name, IntStr(V));
          end;
      end;
    Total := 0;
    for K := 0 to 6 do
    begin
      if Sums[K] > 0 then
        Sums[K] := Sums[K] div 3;
      if Has[K] then
        AddLine(Criteria[K], PercentStr(K, Sums[K]));
      Inc(Total, Sums[K]);
    end;
    F := (Total + 100) * W / 100;
    if 0.05 > F then
      F := 0.05;
    L := Level;
    Prijs := L.Huisprijs * (Mob / 100 * F);
    AddLine('Huizenprijs', IntToStr(Round(Prijs)));
    Belasting := Round((Prijs - 2000) * Wijken[I].Inwoners * 1);
    AddLine('Belastingopbrengst', IntToStr(Belasting));
    Inc(Opbrengst, Belasting);
    Lists[I + 1].Add('');
  end;

  I := -1;
  Lists[I + 1].Add('Algemeen');
  AddLine('Inwonertal', IntToStr((Woningen - 10) * 1200));
  Kosten := 0;
  for X := 0 to WorldSize - 1 do
    for Y := 0 to WorldSize - 1 do
      Inc(Kosten, ContentsInfoByContents(GetCell(X, Y).Contents).Onderhoud);
  Lists[I + 1].Add('  Werkvoorzieningen : ' + PadLeft(S, 25));
  AddLine('Mobiliteit', IntStr(Mob) + '%');
  AddLine('Belastingopbrengst', IntToStr(Opbrengst));
  { NOTE: the original subtracts the per-house income from the maintenance costs. }
  Dec(Kosten, (Woningen - 10) * 2000);
  AddLine('Kosten ivm onderhoud', IntToStr(Kosten));
  AddLine('Saldo', IntToStr(Opbrengst - Kosten));
  Totaal := Opbrengst + (Woningen - 10) * 2000;
  Waarde := Totaal;
  for J := 0 to ContentsCount - 3 do
    if Contents[J].Hoofdrubriek = 'Bonus' then
      if GetAantal(Contents[J].Name) > 0 then
        Inc(Totaal, Contents[J].Afstand);
  Lists[I + 1].Add('');
  Lists[I + 1].Add('Totale score van je stad:');
  AddLine('Huizen waarde stad', IntToStr(Waarde));
  AddLine('Bonus gebouwen', IntToStr(Totaal - Waarde));
  Lists[I + 1].Add(PadLeft('__________', 47));
  AddLine('Totaal', LongToStr(Totaal));
end;

{ @0048523C }
procedure TWorld.Advies(var Msg: string);
var
  W, J, V: Integer;
  Tekort: Integer;
  Werk: Double;
  T: Extended;
begin
  if Reistijd = -1 then
  begin
    Msg := 'Alle huizen, kantoren, molens en stations moeten aan de weg liggen.';
    Exit;
  end;
  Tekort := 0;
  for W := 0 to OpenWijken - 1 do
    for J := 0 to High(Contents) do
      if Contents[J].Level <= Status.Level then
      begin
        V := Wijken[W].GetWaarde(Contents[J].Name);
        if V < 0 then
          Dec(Tekort, V);
      end;
  Werk := Werkgelegenheid(Msg);
  Msg := 'De zoetermeerders zijn tevreden';
  if Tekort = 0 then
  begin
    if Werk < 1 then
      Msg := 'Er is niet genoeg werkgelegenheid'
    else if Score(4) < -20 then
      Msg := 'De Zoetermeerders willen een betere infrastructuur';
  end
  else
  begin
    if Random(100) / 100 > Werk then
      Msg := 'Er is niet genoeg werkgelegenheid'
    else
    begin
      T := Score(4) + 100;
      if T < Random(80) then
        Msg := 'De Zoetermeerders willen een betere infrastructuur'
      else
      begin
        Tekort := Random(Tekort) + 1;
        for W := 0 to OpenWijken - 1 do
          for J := 0 to High(Contents) do
            if Contents[J].Level <= Status.Level then
            begin
              V := Wijken[W].GetWaarde(Contents[J].Name);
              if V < 0 then
                Inc(Tekort, V);
              if (Tekort <= 0) and (Contents[J].Wens <> '') then
              begin
                Msg := 'Bewoners van ' + Wijken[W].Naam + ' ' + Contents[J].Wens;
                Exit;
              end;
            end;
      end;
    end;
  end;
end;

{ @004855AC }
function TWorld.SaveToStrings: TStringList;
{ One line per main cell: "X Y Contents" or "X Y Contents Param". }
var
  X, Y: Integer;
  S: string;
  List: TStringList;
begin
  List := TStringList.Create;
  for X := WorldSize - 1 downto 0 do
    for Y := WorldSize - 1 downto 0 do
      if (Cells[X, Y].Contents <> 'Sloop') and (Cells[X, Y].Contents <> 'Onbereikbaar') and
        (Cells[X, Y].Hoofd = nil) then
      begin
        S := IntStr(X) + ' ' + IntStr(Y) + ' ' + Cells[X, Y].Contents;
        if Cells[X, Y].Param <> '' then
          S := S + ' ' + Cells[X, Y].Param;
        List.Add(S);
      end;
  Result := List;
end;

{ @00485734 }
procedure TWorld.LoadFromStrings(List: TStrings);
var
  I, X, Y, XX, YY: Integer;
  Line, S, C: string;
  Info: TContentsInfo;
begin
  for I := 0 to List.Count - 1 do
  begin
    Line := List[I];
    SplitFirst(Line, ' ', S);
    X := StrToIntDef0(S);
    SplitFirst(Line, ' ', S);
    Y := StrToIntDef0(S);
    SplitFirst(Line, ' ', C);
    { what is left of Line is the cell's Param }
    if IsWeg(C, Line) or (C = 'Klaver') or IsBebouwing(C) or IsTreinBestemming(C) then
      Cells[X, Y].Bouw(C)
    else
      Cells[X, Y].SetContents(C);
    if C <> 'Klaver' then
      Cells[X, Y].SetParam(Line);
    Cells[X, Y].Hoofd := nil;
    Info := ContentsInfoByContents(C);
    if Info.GrondvlakX * Info.GrondvlakY > 0 then
      for XX := X downto X - Info.GrondvlakX + 1 do
        for YY := Y downto Y - Info.GrondvlakY + 1 do
          if (XX <> X) or (YY <> Y) then
          begin
            Cells[XX, YY].SetContents(C);
            if C <> 'Klaver' then
              Cells[XX, YY].SetParam(Line);
            Cells[XX, YY].Hoofd := Cells[X, Y];
          end;
    if IsWeg(C, Line) then
      Cells[X, Y].Update;
  end;
  Herbereken(True);
end;

end.

unit Uworld;

{ Het stadsmodel: het 45x45 isometrische raster van cellen (TCell), de tien wijken
  (TWijk, ingedeeld via wijken.dat), weg- en spoorverbindingen, de simulatie van
  verkeer en reistijd, de waarderingen per wijk, het jaarlijkse rapport en het
  opslaan/laden van de stad als tekstregels.
  Gedecompileerd uit ROS.exe v1.1, code 00480258-00485A33. }

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

  { VMT 004802A4, instantiegrootte $58. Een rastercel. }
  TCell = class(TObject)
  public
    Contents: string;              { +0x04 objectnaam (Objecten.csv), standaard 'Onbereikbaar' }
    Param: string;                 { +0x08 variant: huisafbeelding, wegmasker '05', spoor-/klaverbladstuk, wijknaam voor 'Sloop' }
    Wijk: Integer;                 { +0x0C wijkindex 0..9, GeenWijk = geen }
    X: Integer;                    { +0x10 }
    Y: Integer;                    { +0x14 }
    World: TWorld;                 { +0x18 }
    Wegen: Integer;                { +0x1C bitmasker van verbonden buurwegen (bit i = Dirs[i]) }
    Bebouwing: Integer;            { +0x20 bitmasker van naburige bebouwing (alleen Bakst) }
    Gelijk: Integer;               { +0x24 bitmasker van de 8 buren met dezelfde inhoud }
    Links: array[0..3] of TCell;   { +0x28 verbonden buur per richting (of nil) }
    Drukte: Double;                { +0x38 verkeersbelasting }
    Vorige: TCell;                 { +0x40 vorige cel op de route (ZoekRoute) }
                                   { +0x44 (uitlijning) }
    Afstand: Double;               { +0x48 routeafstand (ZoekRoute), -1 = niet bezocht }
    Hoofd: TCell;                  { +0x50 hoofdcel van een object uit meerdere cellen, nil voor de hoofdcel zelf }
    Bereikbaar: Boolean;           { +0x54 verbonden met een station / de buitenwereld }
    constructor Create(AWereld: TWorld; AX, AY: Integer);
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
    procedure Bouw(NieuweInhoud: string);
    function HeeftWeg(Masker: Integer; Aanpassen: Boolean): Boolean;
    function KanBouwen(NieuweInhoud: string): string;
  end;

  { VMT 00480310, instantiegrootte $10. }
  TCellList = class(TList)
  public
    function Add(Cel: TCell): TCell;
    function GetCell(Nr: Integer): TCell;
    function IndexOf(Cel: TCell): Integer;
    property Cells[Nr: Integer]: TCell read GetCell; default;
  end;

  { VMT 00480378, instantiegrootte $18. Een wijk. }
  TWijk = class(TObject)
  public
    Naam: string;                  { +0x04 }
    X: Integer;                    { +0x08 middelpunt (raster) }
    Y: Integer;                    { +0x0C }
    Inwoners: Integer;             { +0x10 aantal woningcellen (Laag/Midden/Hoogbouw) }
    Waarden: TStringList;          { +0x14 inhoudsnaam -> Integer (in Objects[]) }
    constructor Create(ANaam: string; AX, AY: Integer);
    destructor Destroy; override;
    function GetWaarde(Sleutel: string): Integer;
    procedure SetWaarde(Sleutel: string; Waarde: Integer);
    procedure ClearWaarden;
  end;

  { VMT 004803DC, instantiegrootte $2000. }
  TWorld = class(TObject)
  public
    Woningen: Integer;             { +0x0004 woningcellen + 10 }
    Settings: TSettings;           { +0x0008 }
    Status: TStatus;               { +0x000C }
    Cells: array[0..WorldSize - 1, 0..WorldSize - 1] of TCell;  { +0x0010 [X, Y] }
    Changes: TPosList;             { +0x1FB4 cellen die opnieuw getekend moeten worden (TPos X,Y) }
    Aantallen: TStringList;        { +0x1FB8 inhoudsnaam -> aantal (in Objects[]) }
    Bebouwing: TCellList;          { +0x1FBC huizen, kantoren en molens }
    Bestemmingen: TCellList;       { +0x1FC0 stations en 'AndereStad' }
                                   { +0x1FC4 (uitlijning) }
    Reistijd: Double;              { +0x1FC8 gemiddelde reistijd, -1 = niet alles is bereikbaar }
    Banen: Integer;                { +0x1FD0 kantoren + molens + 4 }
    OpenWijken: Integer;           { +0x1FD4 aantal tot nu toe geopende wijken }
    Wijken: array[0..WijkCount - 1] of TWijk;  { +0x1FD8 }
    constructor Create(AInstellingen: TSettings; AStatus: TStatus);
    destructor Destroy; override;
    function ZoekRoute(Van, Naar: TCell; Route: TCellList): Double;
    procedure OpenWijk(Nr: Integer);
    function GetCell(AX, AY: Integer): TCell;
    function GetAantal(Naam: string): Integer;
    procedure SetAantal(Naam: string; Waarde: Integer);
    procedure Clear;
    procedure Changed(AX, AY: Integer);
    procedure PopChanged(var AX, AY: Integer);
    function Score(Criterium: Byte): Double;
    procedure Herbereken(MetTimer: Boolean);
    procedure BerekenReistijd;
    function Bereikbaar(var Melding: string): Boolean;
    function Level: TLevel;
    function Waardering(Criterium: Byte; WijkIndex: Integer): Double;
    function Werkgelegenheid(var Melding: string): Double;
    procedure Rapport(Lijsten: array of TStrings; var Totaal, Opbrengst, Kosten: Integer;
      Detail: Boolean);
    procedure Advies(var Melding: string);
    function SaveToStrings: TStringList;
    procedure LoadFromStrings(Lijst: TStrings);
  end;

const
  { 004891C0: de vier wegrichtingen (bit i van TCell.Wegen) }
  Dirs: array[0..3] of TPoint = ((X: 0; Y: -1), (X: 1; Y: 0), (X: 0; Y: 1), (X: -1; Y: 0));

implementation

uses
  SysUtils, Uconst, uString, Fmain, Uview
  {$IFDEF FPC}, ZMRandom{$ENDIF}  { PORT: Delphi's Random };

type
  TNeighbour = record
    DX, DY: Integer;
    Mask: Integer;
  end;

const
  { 004891E0: tastafstanden rond een 3x3 klaverblad }
  KlaverDirs: array[0..3] of TPoint = ((X: -1; Y: -3), (X: 1; Y: -1), (X: -1; Y: 1), (X: -3; Y: -1));
  { 00489200: wegbit van de tegenovergestelde richting, per Dirs[] }
  OppositeMask: array[0..3] of Integer = (4, 8, 1, 2);
  { 00489210: TCell.Bebouwing-bits die door een gebouw in richting Dirs[i] worden gezet }
  BebouwingMask: array[0..3] of Integer = ($31, $62, $C4, $98);
  { 00489220: de 8 buren en hun TCell.Gelijk-bit }
  Neighbours: array[0..7] of TNeighbour = (
    (DX: -1; DY: -1; Mask: 16), (DX: 0; DY: -1; Mask: 1), (DX: 1; DY: -1; Mask: 32),
    (DX: -1; DY: 0; Mask: 8),                              (DX: 1; DY: 0; Mask: 2),
    (DX: -1; DY: 1; Mask: 128), (DX: 0; DY: 1; Mask: 4), (DX: 1; DY: 1; Mask: 64));
  { 00489280: de diagonale buren (TCell.Bebouwing-bits 16 shl i) }
  Diagonals: array[0..3] of TPoint = ((X: -1; Y: -1), (X: 1; Y: -1), (X: 1; Y: 1), (X: -1; Y: 1));

{ @004803E4 }
constructor TCell.Create(AWereld: TWorld; AX, AY: Integer);
begin
  inherited Create;
  X := AX;
  Y := AY;
  World := AWereld;
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
  { LET OP: beide takken zijn in het origineel identiek. }
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
  function IsGelijk(Cel: TCell): Boolean;
  begin
    if Cel = nil then
      Result := False
    else
      Result := Cel.Contents = Contents;
  end;

  { @0048078C }
  function SluitAan(Cel, Ander: TCell): Boolean;
  var
    A, B: string;
    Overgang: Boolean;
    C1, C2, T: TCell;
    I: Integer;
  begin
    if (Cel = nil) or (Ander = nil) then
      Result := False
    else if Cel.IsKlaverSnel and Ander.IsKlaverSnel then
      Result := True
    else
    begin
      A := Cel.WegContents;
      B := Ander.WegContents;
      { LET OP: de tweede helft test A/Cell.Param twee keer; Other wordt daar niet gebruikt. }
      Overgang := (IsSnelweg(A, Cel.Param) and IsGewoneWeg(B, Ander.Param)) or
        (IsGewoneWeg(A, Cel.Param) and IsSnelweg(A, Cel.Param));
      Result := IsWeg(A, Cel.Param) and IsWeg(B, Ander.Param) and not Overgang;
      if Overgang then
      begin
        C1 := Cel;
        C2 := Ander;
        if IsSnelweg(A, Cel.Param) then
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
  function IsVerbonden(Cel, Ander: TCell): Boolean;
  var
    Nr: Byte;
    C1, C2, T: TCell;
    I: Integer;
  begin
    if (Cel = nil) or (Ander = nil) or (Cel.Contents = 'Sloop') or
      (Ander.Contents = 'Sloop') or (Cel.Contents = 'Onbereikbaar') or
      (Ander.Contents = 'Onbereikbaar') then
    begin
      Result := False;
      Exit;
    end;
    if IsWeg(Cel.Contents, Cel.Param) and IsWeg(Ander.Contents, Ander.Param) and
      ((Cel.Param = 'Snel') or (Ander.Param = 'Snel')) then
    begin
      Result := True;
      Exit;
    end;
    if (IsWeg(Cel.Contents, Cel.Param) and IsStation(Ander.Contents, Nr)) or
      (IsWeg(Ander.Contents, Ander.Param) and IsStation(Cel.Contents, Nr)) or
      (IsStation(Cel.Contents, Nr) and IsStation(Ander.Contents, Nr)) then
    begin
      Result := True;
      Exit;
    end;
    C1 := Cel;
    C2 := Ander;
    if (IsSnelweg(C1.Contents, C1.Param) and (C2.Contents = 'Klaver')) or
      (IsSnelweg(C2.Contents, C2.Param) and (C1.Contents = 'Klaver')) then
    begin
      { maak C1 het klaverblad }
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
    { LET OP: de tweede test koppelt C2.Contents aan C1.Param. }
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
          { LET OP: C.Contents wordt getest met Self's Param. }
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
  Gegevens: TContentsInfo;
  Capaciteit, MaxSnelheid, Snelheid: Double;
begin
  if IsWeg(Contents, Param) or (Contents = 'Klaver') then
  begin
    Gegevens := ContentsInfoByContents(Contents);
    Capaciteit := Gegevens.Capaciteit;
    MaxSnelheid := Gegevens.MaxSpeed;
    if Capaciteit = 0 then
      Result := 80
    else
    begin
      if Drukte > Capaciteit then
        Snelheid := MaxSnelheid / Sqr(Drukte / Capaciteit)
      else
        Snelheid := MaxSnelheid / Exp(Drukte / (4 * Capaciteit));
      Result := 80 / Snelheid;
    end;
  end
  else
    Result := 0.5;
end;

{ @00481024 }
function TCell.DrukteFactor: Double;
var
  Gegevens: TContentsInfo;
  Capaciteit: Double;
begin
  Result := 0;
  if IsWeg(Contents, Param) or (Contents = 'Klaver') then
  begin
    Gegevens := ContentsInfoByContents(Contents);
    Capaciteit := Gegevens.Capaciteit;
    Result := Drukte;
    if Drukte > Capaciteit then
      Result := Drukte / Capaciteit + Drukte - 1;
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
function RandomItem(Lijst: TStrings): string;
begin
  if Lijst.Count = 0 then
    Result := ''
  else
    Result := RandomString(Lijst);
end;

{ @00481190 }
procedure TCell.Bouw(NieuweInhoud: string);
var
  Oud, OudParam: string;
  OudGegevens, Gegevens: TContentsInfo;
  Kosten: Integer;
  Nr, Nr2: Byte;
  Grondvlak: TPosList;
  I, J, K: Integer;
  C: TCell;
  Masker, Vorig: Integer;
  DX, DY: Integer;
  W: TWorld;
begin
  if NieuweInhoud = Contents then
    Exit;
  Oud := Contents;
  OudParam := Param;
  OudGegevens := ContentsInfoByContents(Oud);
  if World.Status.Level = 1 then
    Kosten := -OudGegevens.Prijs   { slopen levert in level 1 geld op }
  else
    Kosten := 0;
  Gegevens := ContentsInfoByContents(NieuweInhoud);
  Inc(Kosten, Gegevens.Prijs);
  if Kosten > World.Status.Geld then
  begin
    MessageBeep(10);
    Exit;
  end;
  World.Status.Geld := World.Status.Geld - Kosten;

  if IsBebouwing(Oud) then
    World.Bebouwing.Remove(Self);
  if IsBebouwing(NieuweInhoud) then
    World.Bebouwing.Add(Self);
  if IsTreinBestemming(Oud) then
    World.Bestemmingen.Remove(Self);
  if IsTreinBestemming(NieuweInhoud) then
    World.Bestemmingen.Add(Self);

  Param := '';
  if NieuweInhoud <> 'Sloop' then
  begin
    { een recht spoor dat over een weg wordt gelegd, bewaart de weg als Param }
    if IsWeg(Contents, 'X') and IsSpoor(NieuweInhoud, Nr) and (Nr in [5, 10]) then
    begin
      SetParam(Contents);
      Contents := NieuweInhoud;
    end
    else
      Contents := NieuweInhoud;
  end;

  { de overige cellen van het grondvlak, ten opzichte van deze (hoofd)cel }
  Grondvlak := TPosList.Create;
  for I := 0 to Gegevens.GrondvlakX - 1 do
    for J := 0 to Gegevens.GrondvlakY - 1 do
      if I + J <> 0 then
        Grondvlak.Add(TPos.Create(-I, -J));

  if NieuweInhoud = 'Sloop' then
  begin
    if Hoofd <> nil then
    begin
      { LET OP: Grondvlak lekt op dit pad (wordt niet vrijgegeven). }
      Hoofd.Bouw(NieuweInhoud);
      Exit;
    end;
    OudGegevens := ContentsInfoByContents(Contents);
    for I := 0 to OudGegevens.GrondvlakX - 1 do
      for J := 0 to OudGegevens.GrondvlakY - 1 do
      begin
        C := Buur(-I, -J);
        C.Contents := NieuweInhoud;
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

  { snelweg / klaverblad: Param = bitmasker van de verbonden richtingen }
  if IsSnelweg(Contents, 'X') or (Contents = 'Klaver') then
  begin
    Masker := 0;
    for I := 0 to 3 do
    begin
      if Contents = 'Klaver' then
        C := Buur(KlaverDirs[I].X, KlaverDirs[I].Y)
      else
        C := Buur(Dirs[I].X, Dirs[I].Y);
      if C <> nil then
      begin
        Vorig := Masker;
        if C.HeeftWeg(OppositeMask[I], True) then
          Inc(Masker, 1 shl I);
        case Masker of
          7, 11, 13..15: Masker := Vorig;   { geen T-splitsingen of kruisingen }
        end;
      end;
    end;
    SetParam(ZeroPad(IntToStr(Masker), 2));
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
  W.SetAantal(Oud, W.GetAantal(Oud) - 1);
  W.SetAantal(Contents, W.GetAantal(Contents) + 1);
  W.Herbereken(IsTreinBestemming(Oud) or IsTreinBestemming(Contents) or
    IsBebouwing(Oud) or IsBebouwing(Contents) or
    IsWeg(Contents, Param) or IsWeg(Oud, OudParam) or
    (Contents = 'Klaver') or (Oud = 'Klaver'));
end;

{ @00481AC0 }
function TCell.HeeftWeg(Masker: Integer; Aanpassen: Boolean): Boolean;
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
      V := StrToInt(Param) or Masker;
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
      Result := ((V = -7) and (Masker = 1)) or ((V = -3) and (Masker = 2)) or
        ((V = -1) and (Masker = 4)) or ((V = -5) and (Masker = 8));
    end;
  end;
end;

{ @00481EEC }
function TCell.KanBouwen(NieuweInhoud: string): string;
var
  Onder: string;   { EBP-0xC: LET OP: wordt nooit toegekend, is altijd '' }

  { @00481C0C }
  procedure ControleerCel(S: string);
  begin
    if S = 'Onbereikbaar' then
      Result := 'Nog geen onderdeel van Zoetermeer'
    else if S <> 'Sloop' then
    begin
      if not (IsRechtSpoor(NieuweInhoud) and IsWeg(S, 'X')) then
      begin
        if ContentsDescription(S) = 'Spoorrails' then
          Result := 'Er ligt al ' + ContentsDescription(S)
        else
          Result := 'Er staat al een ' + ContentsDescription(S);
        if IsRechtSpoor(S) and IsWeg(NieuweInhoud, Onder) then
          Result := Result + '\nWil je een spoorwegovergang, breek dan het spoor af,\nbouw de weg en leg dan het spoor erover.';
      end;
    end;
  end;

  { @00481E50 }
  function IsOp(DX, DY: Integer; C, P: string): Boolean;
  var
    Cel: TCell;
  begin
    Cel := Buur(DX, DY);
    Result := (Cel <> nil) and (Cel.Contents = C) and (Cel.Hoofd = nil) and
      ((P = '') or (Cel.Param = P));
  end;

var
  Masker, I, J, Kosten: Integer;
  C: TCell;
  Nr, Nr2: Byte;
  Ok: Boolean;
begin
  if (X = 15) and (Y = 27) then
    Result := '';   { LET OP: restant van debuggen }
  Result := '';
  if NieuweInhoud = '' then
    Exit;
  if not InMap(X, Y) then
  begin
    Result := 'Buiten het speelveld';
    Exit;
  end;
  if World.Level.OpenWijk < Wijk then
  begin
    Result := '(Nog) geen onderdeel van Zoetermeer';
    Exit;
  end;
  if ContentsInfoByContents(NieuweInhoud).Prijs > World.Status.Geld then
  begin
    Result := 'Te duur.';
    if World.Status.Level = 1 then
      Result := 'Te duur. Sloop iets om geld te krijgen (alleen in dit level).';
    Exit;
  end;

  if NieuweInhoud = 'Sloop' then
  begin
    if World.Status.Level = 1 then
      Kosten := -ContentsInfoByContents(Contents).Prijs
    else
      Kosten := 0;
    if Kosten > World.Status.Geld then
      Result := 'Te duur.'
    else if Contents = 'Onbereikbaar' then
      Result := 'Nog geen onderdeel van Zoetermeer';
    Exit;
  end;

  ControleerCel(Contents);
  if Result <> '' then
    Exit;

  if IsSnelweg(NieuweInhoud, '') then
  begin
    Masker := 0;
    for I := 0 to 3 do
    begin
      C := Buur(Dirs[I].X, Dirs[I].Y);
      if (C <> nil) and C.HeeftWeg(OppositeMask[I], False) then
        Inc(Masker, 1 shl I);
    end;
    case Masker of
      7, 11, 13..15:
        begin
          Result := 'Hier kan geen ' + ContentsDescription(NieuweInhoud) + ' worden geplaatst.';
          Exit;
        end;
    end;
  end
  else if IsSpoor(NieuweInhoud, Nr) then
  begin
    Ok := False;
    if NieuweInhoud = 'Hoofdstation' then
    begin
      { LET OP: Buur kan hier nil teruggeven (het origineel controleert dat niet). }
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
      if not Ok and (NieuweInhoud = 'Rails03') then
        Ok := (IsOp(-1, -2, 'Rails05', '') or IsOp(-1, -2, 'Station', '05')) and
              (IsOp(-1, -3, 'Rails05', '') or IsOp(-1, -3, 'Station', '05')) or
              (IsOp(1, 0, 'Rails10', '') or IsOp(1, 0, 'Station', '10')) and
              (IsOp(2, 0, 'Rails10', '') or IsOp(2, 0, 'Station', '10'));
      if not Ok and (NieuweInhoud = 'Rails06') then
        Ok := (IsOp(-1, 1, 'Rails05', '') or IsOp(-1, 1, 'Station', '05')) and
              (IsOp(-1, 2, 'Rails05', '') or IsOp(-1, 2, 'Station', '05')) or
              (IsOp(1, -1, 'Rails10', '') or IsOp(1, -1, 'Station', '10')) and
              (IsOp(2, -1, 'Rails10', '') or IsOp(2, -1, 'Station', '10'));
      if not Ok and (NieuweInhoud = 'Rails09') then
        Ok := (IsOp(0, -2, 'Rails05', '') or IsOp(0, -2, 'Station', '05')) and
              (IsOp(0, -3, 'Rails05', '') or IsOp(0, -3, 'Station', '05')) or
              (IsOp(-2, 0, 'Rails10', '') or IsOp(-2, 0, 'Station', '10')) and
              (IsOp(-3, 0, 'Rails10', '') or IsOp(-3, 0, 'Station', '10'));
      if not Ok and (NieuweInhoud = 'Rails12') then
        Ok := (IsOp(0, 1, 'Rails05', '') or IsOp(0, 1, 'Station', '05')) and
              (IsOp(0, 2, 'Rails05', '') or IsOp(0, 2, 'Station', '05')) or
              (IsOp(-2, -1, 'Rails10', '') or IsOp(-2, -1, 'Station', '10')) and
              (IsOp(-3, -1, 'Rails10', '') or IsOp(-3, -1, 'Station', '10'));
      { LET OP: anders dan de andere tests wordt een 'Station' opnieuw getest, ook als Ok al True is. }
      if (not Ok and (NieuweInhoud = 'Rails05')) or (NieuweInhoud = 'Station') then
        Ok := IsOp(0, -1, 'Rails12', '') or IsOp(0, 2, 'Rails09', '') or
              IsOp(1, -1, 'Rails06', '') or IsOp(1, 2, 'Rails03', '') or
              IsOp(0, -1, 'Rails05', '') or IsOp(0, 1, 'Rails05', '') or
              IsOp(0, -1, 'Station', '05') or IsOp(0, 1, 'Station', '05');
      if not Ok and ((NieuweInhoud = 'Rails10') or (NieuweInhoud = 'Station')) then
        Ok := IsOp(-1, 0, 'Rails03', '') or IsOp(-1, 1, 'Rails06', '') or
              IsOp(2, 0, 'Rails09', '') or IsOp(2, 1, 'Rails12', '') or
              IsOp(-1, 0, 'Rails10', '') or IsOp(1, 0, 'Rails10', '') or
              IsOp(-1, 0, 'Hoofdstation', '') or IsOp(-1, 1, 'Hoofdstation', '') or
              IsOp(-1, 2, 'Hoofdstation', '') or IsOp(2, 0, 'Hoofdstation', '') or
              IsOp(2, 1, 'Hoofdstation', '') or IsOp(2, 2, 'Hoofdstation', '') or
              IsOp(-1, 0, 'Station', '10') or IsOp(1, 0, 'Station', '10');
    end;
    if not Ok then
    begin
      if IsStation(NieuweInhoud, Nr) then
        Result := 'Stations moeten aansluiten aan bestaand spoor.\nSloop desnoods een stuk spoor om ruimte te maken voor het station.'
      else
        Result := 'Spoorwegen moeten aan bestaande spoorwegen\naansluiten. Bouw nooit twee bochten vlak bij elkaar of\neen bocht vlak bij een station';
      Exit;
    end;
  end;

  { het hele grondvlak moet vrij zijn }
  for I := 0 to ContentsInfoByContents(NieuweInhoud).GrondvlakX - 1 do
    for J := 0 to ContentsInfoByContents(NieuweInhoud).GrondvlakY - 1 do
      if I + J <> 0 then
      begin
        C := Buur(-I, -J);
        if C = nil then
        begin
          Result := 'Dit valt buiten het scherm.';
          Exit;
        end;
        ControleerCel(C.Contents);
        if Result <> '' then
          Exit;
      end;
end;

{ ---- TCellList ---- }

{ @00482CCC }
function TCellList.Add(Cel: TCell): TCell;
begin
  inherited Add(Cel);
  Result := Cel;
end;

{ @00482CDC }
function TCellList.GetCell(Nr: Integer): TCell;
begin
  Result := TObject(Get(Nr)) as TCell;
end;

{ @00482CFC }
function TCellList.IndexOf(Cel: TCell): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Cel = GetCell(I) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

{ ---- TWijk ---- }

{ @00482D2C }
constructor TWijk.Create(ANaam: string; AX, AY: Integer);
begin
  { LET OP: geen inherited Create in het origineel. }
  Naam := ANaam;
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
function TWijk.GetWaarde(Sleutel: string): Integer;
var
  I: Integer;
begin
  I := Waarden.IndexOf(Sleutel);
  if I = -1 then
    Result := 0
  else
    Result := PtrInt(Waarden.Objects[I]);
end;

{ @00482E54 }
procedure TWijk.SetWaarde(Sleutel: string; Waarde: Integer);
var
  I: Integer;
begin
  I := Waarden.IndexOf(Sleutel);
  if I = -1 then
    Waarden.AddObject(Sleutel, TObject(PtrInt(Waarde)))
  else
    Waarden.Objects[I] := TObject(PtrInt(Waarde));
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
function NewWijk(Naam: string; FX, FY: Double): TWijk;
begin
  Result := TWijk.Create(Naam, Round(FX * 44), Round(FY * 44));
end;

{ ---- TWorld ---- }

{ @00482F6C }
constructor TWorld.Create(AInstellingen: TSettings; AStatus: TStatus);
var
  SomX: array[0..WijkCount - 1] of Integer;    { EBP-0x64 }
  Telling: array[0..WijkCount - 1] of Integer;   { EBP-0x3C }
  SomY: array[0..WijkCount - 1] of Integer;    { EBP-0x8C }
  Regels: TStringList;
  I, AX, AY: Integer;
  S: string;
  C: Char;
begin
  inherited Create;
  Status := AStatus;
  Settings := AInstellingen;
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
    SomX[I] := 0;
    SomY[I] := 0;
    Telling[I] := 0;
  end;
  Regels := TStringList.Create;
  Regels.LoadFromFile(AddPath(AppPath, 'wijken.dat'));
  for AX := 0 to WorldSize - 1 do
    for AY := 0 to WorldSize - 1 do
    begin
      S := Regels[AY];
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
      { LET OP: elk ander teken laat Wijk op 0 staan (instantiegeheugen is op nul gezet). }
      if Cells[AX, AY].Wijk <> GeenWijk then
      begin
        Inc(Telling[Cells[AX, AY].Wijk]);
        Inc(SomX[Cells[AX, AY].Wijk], AX);
        Inc(SomY[Cells[AX, AY].Wijk], AY);
      end;
    end;
  Regels.Free;
  for I := 0 to WijkCount - 1 do
  begin
    Wijken[I].X := Round(SomX[I] / Telling[I]);
    Wijken[I].Y := Round(SomY[I] / Telling[I]);
  end;
  Aantallen := TStringList.Create;
  Changes := TPosList.Create;
end;

{ @004835B4 }
destructor TWorld.Destroy;
begin
  { LET OP: de cellen en wijken worden nooit vrijgegeven. }
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
  Wachtrij: TCellList;          { EBP-0x18 }
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
  Wachtrij := TCellList.Create;
  Wachtrij.Add(Van);
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
    for I := Wachtrij.Count - 1 downto 0 do
    begin
      C := Wachtrij[I];
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
        Wachtrij.Remove(C);
    end;
    if BestVan <> nil then
    begin
      Wachtrij.Add(BestNaar);
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
  Wachtrij.Free;
  Doelen.Free;
end;

{ @004838BC }
procedure TWorld.OpenWijk(Nr: Integer);
var
  AX, AY: Integer;
  MaxX, MaxY, MinX, MinY: Integer;
  P: TPoint;
begin
  { LET OP: de begrenzingsdoos van de nieuwe wijk wordt berekend maar nooit gebruikt. }
  MaxX := 0;
  MaxY := 0;
  MinX := 44;
  MinY := 44;
  OpenWijken := Nr + 1;
  for AX := 0 to WorldSize - 1 do
    for AY := 0 to WorldSize - 1 do
      if InMap(AX, AY) and (GetCell(AX, AY) <> nil) and
        (Nr >= GetCell(AX, AY).Wijk) and
        (GetCell(AX, AY).Contents = 'Onbereikbaar') then
      begin
        Changed(AX, AY);
        GetCell(AX, AY).Contents := 'Sloop';
        GetCell(AX, AY).SetParam(Wijken[GetCell(AX, AY).Wijk].Naam);
        if Nr = GetCell(AX, AY).Wijk then
        begin
          MaxX := IMax(MaxX, AX);
          MaxY := IMax(MaxY, AY);
          MinX := IMin(MinX, AX);
          MinY := IMin(MinY, AY);
        end;
      end;
  P.X := Wijken[Nr].X;
  P.Y := Wijken[Nr].Y;
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
function TWorld.GetAantal(Naam: string): Integer;
var
  I: Integer;
begin
  I := Aantallen.IndexOf(Naam);
  if I = -1 then
    Result := 0
  else
    Result := PtrInt(Aantallen.Objects[I]);
end;

{ @00483B10 }
procedure TWorld.SetAantal(Naam: string; Waarde: Integer);
var
  I: Integer;
begin
  I := Aantallen.IndexOf(Naam);
  if I = -1 then
    Aantallen.AddObject(Naam, TObject(PtrInt(Waarde)))
  else
    Aantallen.Objects[I] := TObject(PtrInt(Waarde));
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
  Melding: string;
begin
  if Criterium = 4 then          { Mobiliteit }
  begin
    Result := 100 - ((100 - Reistijd) * Reistijd / (100 + Reistijd) + Reistijd);
    if Reistijd = -1 then
      Result := -100;
  end
  else if Criterium = 5 then     { Werk }
    Result := Werkgelegenheid(Melding) * 100 - 100
  else
    Result := Waardering(Criterium, -1);
end;

{ @00483D30 }
procedure TWorld.Herbereken(MetTimer: Boolean);
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
  if MetTimer then
    frmMain.timerRecalc.Tag := 3;
end;

{ @004840B4 }
procedure TWorld.BerekenReistijd;
var
  X, Y: Integer;
  I, J, K, Ronde: Integer;
  BesteNr: Integer;
  Best, AfstKw: Integer;
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
  { LET OP: D wordt niet-geinitialiseerd gelezen als Bebouwing leeg is (zoals in het origineel). }
  for Ronde := 1 to 2 do
  begin
    for I := 0 to Bebouwing.Count - 1 do
    begin
      { de eerste twee bestemmingen (de buitenwereld) }
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
      { het dichtstbijzijnde station }
      if Bestemmingen.Count > 2 then
      begin
        Best := (Bebouwing[I].X - Bestemmingen[2].X) * (Bebouwing[I].X - Bestemmingen[2].X) +
          (Bebouwing[I].Y - Bestemmingen[2].Y) * (Bebouwing[I].Y - Bestemmingen[2].Y);
        BesteNr := 2;
        for K := 3 to Bestemmingen.Count - 1 do
        begin
          AfstKw := (Bebouwing[I].X - Bestemmingen[K].X) * (Bebouwing[I].X - Bestemmingen[K].X) +
            (Bebouwing[I].Y - Bestemmingen[K].Y) * (Bebouwing[I].Y - Bestemmingen[K].Y);
          if Best > AfstKw then
          begin
            Best := AfstKw;
            BesteNr := K;
          end;
        end;
        Route.Clear;
        D := ZoekRoute(Bebouwing[I], Bestemmingen[BesteNr], Route);
        if D = -1 then
        begin
          Bebouwing[I].Bereikbaar := False;
          Bestemmingen[BesteNr].Bereikbaar := False;
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
function TWorld.Bereikbaar(var Melding: string): Boolean;
begin
  Melding := '';
  Result := False;
  Result := Reistijd <> -1;
  if not Result then
    Melding := 'Niet alle bewoners kunnen van en naar de stad reizen.';
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
function TWorld.Werkgelegenheid(var Melding: string): Double;
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
    Melding := 'te weinig werkgelegenheid'
  else
    Melding := 'genoeg werkgelegenheid';
end;

{ @004848E0 }
function PercentStr(Criterium: Byte; Waarde: Integer): string;
begin
  Waarde := IMax(Waarde + 90, 0);
  Waarde := IMin(Waarde, 100);
  if Criterium = 6 then
    Waarde := 100 - Waarde;
  Result := IntToStr(Waarde) + '%';
end;

{ @00484A3C }
procedure TWorld.Rapport(Lijsten: array of TStrings; var Totaal, Opbrengst, Kosten: Integer;
  Detail: Boolean);
var
  I, J, X, Y: Integer;
  K: Byte;
  V, SomCriteria, Mob, Belasting, Waarde: Integer;
  S: string;
  W, F, Prijs: Double;
  Sommen: array[0..6] of Integer;
  Heeft: array[0..6] of Boolean;
  L: TLevel;

  { @00484970 }
  procedure VoegRegelToe(Titel, Tekst: string);
  begin
    Lijsten[I + 1].Add('  ' + PadRight(Titel + ' : ', 30) + PadLeft(Tekst, 15));
  end;

begin
  Herbereken(True);
  Opbrengst := 0;
  W := Werkgelegenheid(S);
  Mob := IMax(0, IMin(100, Round(Score(4)) + 100));
  for I := 0 to OpenWijken - 1 do
  begin
    Lijsten[I + 1].Clear;
    Lijsten[I + 1].Add(Wijken[I].Naam);
    VoegRegelToe('Inwonertal', IntToStr(Wijken[I].Inwoners * 1200));
    for K := 0 to 6 do
    begin
      Sommen[K] := 0;
      Heeft[K] := False;
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
            Inc(Sommen[K], V);
            Heeft[K] := True;
            if Detail then
              VoegRegelToe('   ' + Contents[J].Name, IntStr(V));
          end;
      end;
    SomCriteria := 0;
    for K := 0 to 6 do
    begin
      if Sommen[K] > 0 then
        Sommen[K] := Sommen[K] div 3;
      if Heeft[K] then
        VoegRegelToe(Criteria[K], PercentStr(K, Sommen[K]));
      Inc(SomCriteria, Sommen[K]);
    end;
    F := (SomCriteria + 100) * W / 100;
    if 0.05 > F then
      F := 0.05;
    L := Level;
    Prijs := L.Huisprijs * (Mob / 100 * F);
    VoegRegelToe('Huizenprijs', IntToStr(Round(Prijs)));
    Belasting := Round((Prijs - 2000) * Wijken[I].Inwoners * 1);
    VoegRegelToe('Belastingopbrengst', IntToStr(Belasting));
    Inc(Opbrengst, Belasting);
    Lijsten[I + 1].Add('');
  end;

  I := -1;
  Lijsten[I + 1].Add('Algemeen');
  VoegRegelToe('Inwonertal', IntToStr((Woningen - 10) * 1200));
  Kosten := 0;
  for X := 0 to WorldSize - 1 do
    for Y := 0 to WorldSize - 1 do
      Inc(Kosten, ContentsInfoByContents(GetCell(X, Y).Contents).Onderhoud);
  Lijsten[I + 1].Add('  Werkvoorzieningen : ' + PadLeft(S, 25));
  VoegRegelToe('Mobiliteit', IntStr(Mob) + '%');
  VoegRegelToe('Belastingopbrengst', IntToStr(Opbrengst));
  { LET OP: het origineel trekt het inkomen per woning af van de onderhoudskosten. }
  Dec(Kosten, (Woningen - 10) * 2000);
  VoegRegelToe('Kosten ivm onderhoud', IntToStr(Kosten));
  VoegRegelToe('Saldo', IntToStr(Opbrengst - Kosten));
  Totaal := Opbrengst + (Woningen - 10) * 2000;
  Waarde := Totaal;
  for J := 0 to ContentsCount - 3 do
    if Contents[J].Hoofdrubriek = 'Bonus' then
      if GetAantal(Contents[J].Name) > 0 then
        Inc(Totaal, Contents[J].Afstand);
  Lijsten[I + 1].Add('');
  Lijsten[I + 1].Add('Totale score van je stad:');
  VoegRegelToe('Huizen waarde stad', IntToStr(Waarde));
  VoegRegelToe('Bonus gebouwen', IntToStr(Totaal - Waarde));
  Lijsten[I + 1].Add(PadLeft('__________', 47));
  VoegRegelToe('Totaal', LongToStr(Totaal));
end;

{ @0048523C }
procedure TWorld.Advies(var Melding: string);
var
  W, J, V: Integer;
  Tekort: Integer;
  Werk: Double;
  T: Extended;
begin
  if Reistijd = -1 then
  begin
    Melding := 'Alle huizen, kantoren, molens en stations moeten aan de weg liggen.';
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
  Werk := Werkgelegenheid(Melding);
  Melding := 'De zoetermeerders zijn tevreden';
  if Tekort = 0 then
  begin
    if Werk < 1 then
      Melding := 'Er is niet genoeg werkgelegenheid'
    else if Score(4) < -20 then
      Melding := 'De Zoetermeerders willen een betere infrastructuur';
  end
  else
  begin
    if Random(100) / 100 > Werk then
      Melding := 'Er is niet genoeg werkgelegenheid'
    else
    begin
      T := Score(4) + 100;
      if T < Random(80) then
        Melding := 'De Zoetermeerders willen een betere infrastructuur'
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
                Melding := 'Bewoners van ' + Wijken[W].Naam + ' ' + Contents[J].Wens;
                Exit;
              end;
            end;
      end;
    end;
  end;
end;

{ @004855AC }
function TWorld.SaveToStrings: TStringList;
{ Een regel per hoofdcel: "X Y Contents" of "X Y Contents Param". }
var
  X, Y: Integer;
  S: string;
  Lijst: TStringList;
begin
  Lijst := TStringList.Create;
  for X := WorldSize - 1 downto 0 do
    for Y := WorldSize - 1 downto 0 do
      if (Cells[X, Y].Contents <> 'Sloop') and (Cells[X, Y].Contents <> 'Onbereikbaar') and
        (Cells[X, Y].Hoofd = nil) then
      begin
        S := IntStr(X) + ' ' + IntStr(Y) + ' ' + Cells[X, Y].Contents;
        if Cells[X, Y].Param <> '' then
          S := S + ' ' + Cells[X, Y].Param;
        Lijst.Add(S);
      end;
  Result := Lijst;
end;

{ @00485734 }
procedure TWorld.LoadFromStrings(Lijst: TStrings);
var
  I, X, Y, XX, YY: Integer;
  Regel, S, C: string;
  Gegevens: TContentsInfo;
begin
  for I := 0 to Lijst.Count - 1 do
  begin
    Regel := Lijst[I];
    S := SplitFirst(Regel, ' ');
    X := StrToIntDef0(S);
    S := SplitFirst(Regel, ' ');
    Y := StrToIntDef0(S);
    C := SplitFirst(Regel, ' ');
    { wat er van Line overblijft is de Param van de cel }
    if IsWeg(C, Regel) or (C = 'Klaver') or IsBebouwing(C) or IsTreinBestemming(C) then
      Cells[X, Y].Bouw(C)
    else
      Cells[X, Y].SetContents(C);
    if C <> 'Klaver' then
      Cells[X, Y].SetParam(Regel);
    Cells[X, Y].Hoofd := nil;
    Gegevens := ContentsInfoByContents(C);
    if Gegevens.GrondvlakX * Gegevens.GrondvlakY > 0 then
      for XX := X downto X - Gegevens.GrondvlakX + 1 do
        for YY := Y downto Y - Gegevens.GrondvlakY + 1 do
          if (XX <> X) or (YY <> Y) then
          begin
            Cells[XX, YY].SetContents(C);
            if C <> 'Klaver' then
              Cells[XX, YY].SetParam(Regel);
            Cells[XX, YY].Hoofd := Cells[X, Y];
          end;
    if IsWeg(C, Regel) then
      Cells[X, Y].Update;
  end;
  Herbereken(True);
end;

end.

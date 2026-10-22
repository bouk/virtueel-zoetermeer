unit Uconst;

{ Spelconstanten en hulpfuncties: de objecttypetabel die uit Objecten.csv wordt geladen
  (TInhoudInfo), namen van criteria/waarderingen, tests voor weg-, spoor- en stationsnamen,
  de coordinaatomzettingen van het isometrische raster <-> wereld <-> scherm,
  profileringstellers en de fatale foutbox.
  Gedecompileerd uit ROS.exe v1.1, code 00485A34-00486C6B. }

{$I zm.inc}

interface

uses
  Windows;

const
  TegelBreedte = 88;        { breedte van een rastercel in wereldpixels }
  OorsprongX = 2024;    { wereld-X van raster (0,0) }
  OorsprongY = -880;    { wereld-Y van raster (0,0) }

type
  { RTTI 00485A38 'TInhoudInfo', grootte $48. Een regel uit Objecten.csv. }
  TInhoudInfo = record
    Name: string;          { +0x00 Name }
    Beschrijving: string;   { +0x04 Beschrijving }
    IsGrond: Integer;     { +0x08 IsGrond }
    Uniek: Boolean;    { +0x0C Uniek = '1' }
    Page: string;          { +0x10 Page }
    Speelniveau: Integer;        { +0x14 Speelniveau }
    Prijs: Integer;        { +0x18 Prijs }
    Onderhoud: Integer;    { +0x1C Onderhoud }
    Capaciteit: Integer;   { +0x20 Capaciteit }
    Topsnelheid: Integer;     { +0x24 Topsnelheid }
    GrondvlakX: Integer;   { +0x28 GrondvlakX (>= 1) }
    GrondvlakY: Integer;   { +0x2C GrondvlakY (>= 1) }
    Hoofdrubriek: string;  { +0x30 Hoofdrubriek }
    Basisscore: Integer;    { +0x34 Basisscore }
    Value: Integer;        { +0x38 Value }
    Afstand: Integer;      { +0x3C Afstand }
    Wens: string;          { +0x40 Wens }
    SpritesGeladen: Boolean;   { +0x44 ingesteld door TfrmMain.LeesSprites zodra de sprites zijn geladen }
    KnopGemaakt: Boolean;     { +0x45 ingesteld door TfrmMain zodra de bouwknop is gemaakt }
  end;

  { RTTI 00485BAC '.4' }
  TInhoudInfoArray = array of TInhoudInfo;

const
  { 004892A0 }
  Criteria: array[0..6] of string =
    ('Vrijetijd', 'Groen', 'Veiligheid', 'Cultuur', 'Mobiliteit', 'Werk', 'Overlast');
  { 004892BC: het deel van het scherm waarin de stad wordt getekend }
  BeeldRect: TRect = (Left: 30; Top: 81; Right: 822; Bottom: 686);
  { 004892CC (niet gebruikt) }
  Waarderingen: array[0..4] of string =
    ('Zeer slecht', 'Onvoldoende', 'Matig', 'Redelijk', 'Goed');
  { 004892E0 (niet gebruikt) }
  Hoeveelheden: array[0..4] of string =
    ('Enorm', 'Veel', 'Matig', 'Acceptabel', 'Geen');
  { 004892F4: schaal wereld -> scherm, ingesteld door Uview }
  Zoom: Double = 1;
  { 004892FC, 00489300: scrollverschuiving van de wereld, ingesteld door Uview }
  VerschuivingX: Integer = 0;
  VerschuivingY: Integer = 0;

var
  Inhoud: TInhoudInfoArray;   { 0048B178 }
  AantalInhoud: Integer;         { 0048B17C }
  { Profileringstellers (GetTickCount), gerapporteerd door Fmain. }
  ProfStart: Longint;             { 0048B180 }
  ProfBeeld: Longint;              { 0048B184 }
  ProfAutos: Longint;             { 0048B188 }
  ProfSprites: Longint;           { 0048B18C }
  ProfOverig: Longint;             { 0048B190 }

procedure LaadInhoud;
function IsSnelweg(Naam, Onder: string): Boolean;
function IsGewoneWeg(Naam, Onder: string): Boolean;
function IsWeg(Naam, Onder: string): Boolean;
function IsSpoor(Naam: string; var Nr: Byte): Boolean;
function IsRechtSpoor(Naam: string): Boolean;
function IsBochtSpoor(Naam: string; var Nr: Byte): Boolean;
function IsStation(Naam: string; var Nr: Byte): Boolean;
function IsTreinBestemming(Naam: string): Boolean;
function IsBebouwing(Naam: string): Boolean;
function RasterNaarWereld(P: TPoint): TPoint;
function WereldNaarScherm(P: TPoint): TPoint;
function RasterNaarScherm(P: TPoint): TPoint;
function SchermNaarWereld(P: TPoint): TPoint;
function WereldNaarRaster(P: TPoint): TPoint;
function SchermNaarRaster(P: TPoint): TPoint;
function InhoudInfoOpNaam(Naam: string): TInhoudInfo;
function InhoudOmschrijving(Naam: string): string;
function IsBuitenBeeld(X, Y: Integer): Boolean;
function InKaart(X, Y: Integer): Boolean;
procedure Fout(Melding: string);

implementation

uses
  SysUtils, Forms, uString, uTool, Fmain;

{ @00485BBC }
procedure VoegInhoudToe(Naam, Omschrijving: string);
var
  Gegevens: TInhoudInfo;
begin
  Gegevens.Name := Naam;
  Gegevens.Beschrijving := Omschrijving;
  Gegevens.IsGrond := 1;
  Gegevens.Uniek := False;
  Gegevens.Page := '';
  Gegevens.Speelniveau := 0;
  Gegevens.Prijs := 0;
  Gegevens.Onderhoud := 0;
  Gegevens.Afstand := 0;
  Gegevens.GrondvlakX := 1;
  Gegevens.GrondvlakY := 1;
  Gegevens.Basisscore := 0;
  Gegevens.Value := 0;
  Gegevens.Afstand := 0;
  Gegevens.Wens := '';
  Gegevens.SpritesGeladen := False;
  Gegevens.KnopGemaakt := False;
  { LET OP: Capaciteit, Topsnelheid en Hoofdrubriek worden niet ingesteld. }
  Inc(AantalInhoud);
  SetLength(Inhoud, AantalInhoud);
  Inhoud[AantalInhoud - 1] := Gegevens;
end;

{ @00485CD8 }
procedure LaadInhoud;
var
  Kop, Regel, GrondX, GrondY: string;
  Bestand: TextFile;
  Gegevens: TInhoudInfo;
  S: string;
begin
  { LET OP: het stackframe van het origineel wordt bij binnenkomst op nul gezet, dus de
    velden die niet uit het bestand worden gelezen (SpritesGeladen/KnopGemaakt) beginnen als
    False en behouden hun waarde van regel tot regel. }
{$IFDEF FPC}
  Gegevens := Default(TInhoudInfo);   { PORT: FPC zet het frame niet op nul }
{$ENDIF}
  AantalInhoud := 0;
  AssignFile(Bestand, VoegPadToe(AppPad, 'Objecten.csv'));
  Reset(Bestand);
  ReadLn(Bestand, Kop);
  while not Eof(Bestand) do
  begin
    ReadLn(Bestand, Regel);
    if SnijStr(Regel) <> '' then
    begin
      S := SplitsEerste(Regel, ';');
      Gegevens.Name := S;
      if SnijStr(Gegevens.Name) <> '' then
      begin
        S := SplitsEerste(Regel, ';');
        Gegevens.Page := S;
        S := SplitsEerste(Regel, ';');
        Gegevens.Beschrijving := S;
        S := SplitsEerste(Regel, ';');
        Gegevens.Speelniveau := StrNaarIntDef0(S);
        S := SplitsEerste(Regel, ';');
        Gegevens.IsGrond := StrNaarIntDef0(S);
        S := SplitsEerste(Regel, ';');
        Gegevens.Uniek := S = '1';
        S := SplitsEerste(Regel, ';');
        Gegevens.Prijs := StrNaarIntDef0(S);
        S := SplitsEerste(Regel, ';');
        Gegevens.Onderhoud := StrNaarIntDef0(S);
        S := SplitsEerste(Regel, ';');
        Gegevens.Capaciteit := StrNaarIntDef0(S);
        S := SplitsEerste(Regel, ';');
        Gegevens.Topsnelheid := StrNaarIntDef0(S);
        GrondX := SplitsEerste(Regel, ';');
        GrondY := SplitsEerste(Regel, ';');
        if GrondX = '' then
          Gegevens.GrondvlakX := 1
        else
          Gegevens.GrondvlakX := IMaximum(1, StrNaarIntDef0(GrondX));
        if GrondY = '' then
          Gegevens.GrondvlakY := 1
        else
          Gegevens.GrondvlakY := IMaximum(1, StrNaarIntDef0(GrondY));
        S := SplitsEerste(Regel, ';');
        Gegevens.Hoofdrubriek := S;
        S := SplitsEerste(Regel, ';');
        Gegevens.Basisscore := StrNaarIntDef0(S);
        S := SplitsEerste(Regel, ';');
        Gegevens.Value := StrNaarIntDef0(S);
        S := SplitsEerste(Regel, ';');
        Gegevens.Afstand := StrNaarIntDef0(S);
        S := SplitsEerste(Regel, ';');
        Gegevens.Wens := S;
        Inc(AantalInhoud);
        SetLength(Inhoud, AantalInhoud);
        Inhoud[AantalInhoud - 1] := Gegevens;
      end;
    end;
  end;
  CloseFile(Bestand);
  VoegInhoudToe('AndereStad', 'Andere stad');
  VoegInhoudToe('Onbereikbaar', 'Buiten de stad');
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
    Nr := StrNaarIntDef0(Copy(Naam, 6, 2));
    Result := LinksStr(Naam, 5) = 'Rails';
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
  else if BegintMet(Naam, 'Station') then
  begin
    Nr := StrNaarIntDef0(Copy(Naam, 8, 2));
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
function RasterNaarWereld(P: TPoint): TPoint;
begin
  Result.X := (P.X - P.Y) * TegelBreedte + OorsprongX;
  Result.Y := (P.X + P.Y) * TegelBreedte div 2 + OorsprongY;
end;

{ @004867F4 }
function WereldNaarScherm(P: TPoint): TPoint;
begin
  Result.X := Round((P.X + VerschuivingX) * Zoom);
  Result.Y := Round((P.Y + VerschuivingY) * Zoom);
end;

{ @00486848 }
function RasterNaarScherm(P: TPoint): TPoint;
begin
  Result := RasterNaarWereld(P);
  Result := WereldNaarScherm(Result);
end;

{ @00486880 }
function SchermNaarWereld(P: TPoint): TPoint;
begin
  Result.X := Round(P.X / Zoom) - VerschuivingX;
  Result.Y := Round(P.Y / Zoom) - VerschuivingY;
end;

{ @004868C4 }
function WereldNaarRaster(P: TPoint): TPoint;
var
  Getal: Double;
begin
  Getal := (P.X - OorsprongX) / TegelBreedte / 2 + (P.Y - OorsprongY) / TegelBreedte;
  Result.X := Round(Getal);
  Result.Y := Round((P.Y - OorsprongY) / TegelBreedte * 2 - Getal);
end;

{ @00486950 }
function SchermNaarRaster(P: TPoint): TPoint;
begin
  Result := SchermNaarWereld(P);
  Result := WereldNaarRaster(Result);
end;

{ @00486988 }
function InhoudInfoOpNaam(Naam: string): TInhoudInfo;
var
  I: Integer;
begin
  for I := 0 to AantalInhoud - 1 do
    if Inhoud[I].Name = Naam then
    begin
      Result := Inhoud[I];
      Exit;
    end;
  Fout('ContentsInfoByContents: ' + Naam + ' not found');
end;

{ @00486A78 }
function InhoudOmschrijving(Naam: string): string;
begin
  Result := InhoudInfoOpNaam(Naam).Beschrijving;
end;

{ @00486AEC }
function IsBuitenBeeld(X, Y: Integer): Boolean;
var
  P: TPoint;
begin
  P.X := X;
  P.Y := Y;
  Result := not PtInRect(BeeldRect, RasterNaarScherm(P));
end;

{ @00486B20 }
function InKaart(X, Y: Integer): Boolean;
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

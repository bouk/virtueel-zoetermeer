unit uAutos;

{ De auto's: TAutoSprite verzorgt het stadszicht en tekent elke auto als een klein wit
  vierkantje op het zichtoppervlak, rijdend langs vaste paden (TSegmentList van
  TSegment) per wegstuk: gewone wegen, snelwegen en de negen cellen van een
  'Klaver' (klaverbladkruising). Het aantal auto's per weg volgt de
  verkeerssimulatie van Uworld.
  Gedecompileerd uit ROS.exe v1.1, code 00474EF0-004775DB (de literal pool van de
  initialisatiesectie loopt door tot 004777F7, in het bereik dat de unitkaart
  toekent aan uTransition). }

{$I zm.inc}

interface

uses
  Windows, Classes, uSurface, uSprite, uSpritebox, Usett, Uworld, Uview;

type
  { VMT 00474F3C, instantiegrootte $158. }
  TAutoSprite = class(TSprite)
  private
    FGereserveerd13C: Integer;           { +0x13C  niet gebruikt }
    FWereld: TWorld;                  { +0x140 }
    FWeergave: TView;                    { +0x144 }
    FInstellingen: TSettings;            { +0x148 }
    FGetekend: Boolean;                 { +0x14C  ingesteld na de eerste Draw, nooit gelezen }
    FStartTik: Integer;             { +0x150  GetTickCount aan het begin van de huidige periode }
    FFase: Integer;                  { +0x154  periodeteller 0..77, kiest de auto's van een kruispunt }
  public
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); override;                                        { +0x64 }
    property Wereld: TWorld read FWereld;
    property Weergave: TView read FWeergave;
    property Instellingen: TSettings read FInstellingen;
  end;

  { VMT 00475070, instantiegrootte $18. Eén recht stuk van een autopad, in wereld-
    pixels ten opzichte van de cel. }
  TSegment = class(TObject)
  private
    FVan: TPoint;                    { +0x04 }
    FNaar: TPoint;                   { +0x0C }
    FRichting: Char;                 { +0x14  index in AutoFrame }
  public
    constructor Create(P1, P2: TPoint; ARichting: Char);
    property Van: TPoint read FVan;
    property Naar: TPoint read FNaar;
    property Richting: Char read FRichting;
  end;

  { VMT 004750C8, instantiegrootte $10. }
  TSegmentList = class(TList)
  public
    function Add(Segment: TSegment): TSegment;
    function GetItem(Nr: Integer): TSegment;
    property Items[Nr: Integer]: TSegment read GetItem; default;
  end;

function MaakAutos(SpriteBox: TSpriteBox; Sjabloon: TSprite; AWorld: TWorld;
  AView: TView; AOpties: TSettings): TAutoSprite;

implementation

uses
  SysUtils, Graphics, uTool, Uconst, SprBmp;

const
  { 00488EDC: aantal gezette bits in 0..15 (aantal aangesloten wegrichtingen) }
  BitCount: array[0..15] of Integer = (0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4);

var
  { 0048A990: autopaden van een gewone weg, per TCell.Wegen-bitmasker }
  Heen: array[0..15] of TSegmentList;
  { 0048A9D0 }
  Terug: array[0..15] of TSegmentList;
  { 0048AA10: autopaden van een snelweg }
  SnelHeen: array[0..15] of TSegmentList;
  { 0048AA50 }
  SnelTerug: array[0..15] of TSegmentList;
  { 0048AA90: autopaden op het klaverblad: [rijstrook 1..2, stuk 1..9] }
  KlaverHeen: array[0..8, 0..15] of TSegmentList;
  { 0048ACD0: alleen stukken 1..4 }
  KlaverTerug: array[0..8, 0..15] of TSegmentList;
  { 0048AF10: autoframe ('auto<n>') per segmentrichting }
  AutoFrame: array['A'..'R'] of Integer;
  { 0048AF58 }
  I: Integer;
  { 0048AF5C: padpunten; 'A'..'L' voor wegen, 'a'..'l' hergebruikt voor elk klaverbladstuk }
  Punten: array['A'..'z'] of TPoint;
  { LET OP: X1, Y1 en X2 werden door de compiler in registers gehouden (EDI, EBX, ESI);
    alleen Y2 heeft een geheugenlocatie (0048B12C). }
  X1, Y1, X2, Y2: Integer;
  J: Integer;

{ @004750E8 }
function MaakAutos(SpriteBox: TSpriteBox; Sjabloon: TSprite; AWorld: TWorld;
  AView: TView; AOpties: TSettings): TAutoSprite;
begin
  Result := TAutoSprite.MaakKopie(Sjabloon);
  Result.FWereld := AWorld;
  AView.Autos := Result;
  Result.MargeRechts := 792;
  Result.MargeOnder := 605;
  Result.VerplaatsNaar3D(30, 81, 1000);
  Result.Visible := True;
  Result.FWeergave := AView;
  Result.FFase := 0;
  Result.FStartTik := GetTickCount;
  Result.FInstellingen := AOpties;
end;

{ @00475178 }
function Verkeer(Cell: TCell): Integer;
begin
  Result := 0;
  if (Cell <> nil) and (Cell.Drukte > 0) then
    Result := 1;
end;

{ @0047519C  Positie (X, Y) op breukdeel F van het pad; geeft de autoframenaam terug,
  of '' als er geen pad is. }
function SegmentPositie(Lijst: TSegmentList; var X, Y: Integer; F: Double): string;
var
  N, Nr, AX1, AY1, AX2, AY2: Integer;
begin
  Result := '';
  if (Lijst <> nil) and (Lijst.Count <> 0) then
  begin
    N := Lijst.Count;
    Nr := Trunc(N * F);
    if Nr >= N then
      Nr := N - 1;
    Dec(N);
    if N > 0 then
      F := 1 - (1 - F);
    AX1 := Lijst[Nr].FVan.X;
    AY1 := Lijst[Nr].FVan.Y;
    AX2 := Lijst[Nr].FNaar.X;
    AY2 := Lijst[Nr].FNaar.Y;
    F := (F - Nr / Lijst.Count) * Lijst.Count;
    X := Round(Interpoleer(F, AX2, AX1));
    Y := Round(Interpoleer(F, AY2, AY1));
    { LET OP: de klaverbladpaden gebruiken de richtingen 'a'..'l', die buiten
      AutoFrame vallen (het origineel leest het Punten-geheugen); de naam wordt alleen op '' getest }
    Result := 'auto' + IntToStr(AutoFrame[Lijst[Nr].FRichting]);
  end;
end;

{ @00475934 }
procedure TAutoSprite.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Schaalfactor: Double);
var
  CurDX, CurDY: Integer;
  K: array[1..7] of Integer;
  L, X, Y, Lane: Integer;
  Buur, Buur2: TCell;
  P: TPoint;
  Tijd: Double;
  Aantal: Integer;
  Fase: Double;
  Bits, Mask: Integer;
  Som: Double;
  Cell: TCell;
  I, Periode: Integer;

  { @00475314  Tekent één auto (een wit vierkantje) op (AX, AY) op Surface. }
  procedure PlotAuto(AX, AY: Integer);
  var
    Grootte, I, J, SX, SY: Integer;
  begin
    Grootte := Round(Zoom * 2);
    for I := (-Grootte) div 2 to Grootte div 2 + Grootte mod 2 - 1 do
      for J := (-Grootte) div 2 to Grootte div 2 + Grootte mod 2 - 1 do
      begin
        SX := Left + AX + I - CurDX;
        SY := Top + AY + J - CurDY;
        if CurDX <> 0 then
          CurDX := CurDX;
        if PtInRect(BeeldRect, Point(SX, SY)) then
          TBmpSurface(Surface).Bitmap.Canvas.Pixels[AX + I, AY + J] := clWhite;
      end;
  end;

  { @00475440  Tekent de N auto's van één pad (beide richtingen) van een cel. }
  procedure DrawAutos(P: TPoint; N, Idx: Integer; F: Double; Soort, Lane, Mask: Integer;
    Cell: TCell; OfsX, OfsY, Piece: Integer);
  var
    T, I, X, Y: Integer;
    G: Double;
    S: string;
  begin
    if N > 0 then
    begin
      CurDX := DX;
      CurDY := DY;
      T := N * 2000;
      F := (GetTickCount - FStartTik) / T;
      while F >= 1 do
      begin
        F := F - 1;
        Inc(FStartTik, T);
        FFase := (FFase + 1) mod 78;
      end;
      if Mask = 7 then
        Lane := Lane mod 3 + 1;
      for I := 0 to N - 1 do
      begin
        G := I / N + F;
        while G > 1 do
          G := G - 1;

        if IsSnelweg(Cell.Inhoud, 'X') then
          S := SegmentPositie(SnelHeen[Idx], X, Y, G)
        else if Cell.Inhoud = 'Klaver' then
        begin
          { LET OP: beide takken zijn gelijk }
          if Piece < 5 then
            S := SegmentPositie(KlaverHeen[Idx, Piece], X, Y, G)
          else
            S := SegmentPositie(KlaverHeen[Idx, Piece], X, Y, G);
        end
        else
          S := SegmentPositie(Heen[Idx], X, Y, G);
        if S > '' then
          if (Soort < 3) or
             ((Soort = 3) and (((Lane in [1, 2]) and (FFase mod 2 = 0)) or
                              ((Lane = 3) and (FFase mod 2 = 1)))) or
             ((Soort = 4) and (((Lane in [4, 5]) and (FFase mod 3 = 0)) or
                              ((Lane in [2, 3]) and (FFase mod 3 = 1)) or
                              ((Lane in [1, 6]) and (FFase mod 3 = 2)))) then
            PlotAuto(P.X + Round((X + OfsX) * Zoom), P.Y + Round((Y + OfsY) * Zoom));

        if IsSnelweg(Cell.Inhoud, 'X') then
          S := SegmentPositie(SnelTerug[Idx], X, Y, G)
        else if Cell.Inhoud = 'Klaver' then
        begin
          { LET OP: voor stukken 5..9 behoudt S de waarde van de eerste richting }
          if Piece < 5 then
            S := SegmentPositie(KlaverTerug[Idx, Piece], X, Y, G);
        end
        else
          S := SegmentPositie(Terug[Idx], X, Y, G);
        if S > '' then
          if (Soort < 3) or
             ((Soort = 3) and (((Lane = 3) and (FFase mod 2 = 0)) or
                              ((Lane in [1, 2]) and (FFase mod 2 = 1)))) or
             ((Soort = 4) and (((Lane in [2, 3]) and (FFase mod 3 = 0)) or
                              ((Lane in [4, 5]) and (FFase mod 3 = 1)) or
                              ((Lane in [1, 6]) and (FFase mod 3 = 2)))) then
            PlotAuto(P.X + Round((X + OfsX) * Zoom), P.Y + Round((Y + OfsY) * Zoom));
      end;
    end;
  end;

  { @00475914 }
  function Beide(A, B: Integer): Boolean;
  begin
    Result := (K[A] > 0) and (K[B] > 0);
  end;

begin
  if FWereld.Reistijd <> -1 then
  begin
    Dec(ProfAutos, GetTickCount);
    for X := 0 to 44 do
      for Y := 0 to 44 do
      begin
        Cell := FWereld.LeesCel(X, Y);
        if Cell <> nil then
        begin
          P := RasterNaarScherm(Point(X, Y));
          P.X := P.X - (30 - DX);
          P.Y := P.Y - (81 - DY);
          if IsWeg(Cell.Inhoud, 'X') then
          begin
            Mask := Cell.Wegen;
            for I := 0 to 3 do
            begin
              Buur := Cell.Buur(Richtingen[I].X, Richtingen[I].Y);
              if (Buur <> nil) and (Buur.Drukte = 0) then
                Mask := Mask and (15 - (1 shl I));
            end;
            Tijd := Cell.Reistijd / 1.5;
            Periode := 3000;
            Fase := (GetTickCount mod Periode) / Periode;
            { een doodlopend stuk naast een gebouw: de auto's draaien het gebouw in }
            if BitCount[Mask] = 1 then
              for I := 0 to 3 do
              begin
                Buur := Cell.Buur(Richtingen[I].X, Richtingen[I].Y);
                if (Buur <> nil) and IsBebouwing(Buur.Inhoud) and
                   ((Mask in [0, 1, 2, 4, 8]) or not IsSnelweg(Cell.Inhoud, 'X')) then
                  Mask := Mask or (1 shl I);
              end;
            if BitCount[Mask] = 2 then
            begin
              Aantal := IMinimum(RondOmhoog(Tijd), 5);
              if (Aantal = 0) and (Cell.DrukteFactor <> 0) then
                Aantal := 1;
              DrawAutos(P, Aantal, Mask, Fase, 2, 0, Mask, Cell, 0, 0, 0);
            end
            else if BitCount[Mask] > 2 then
            begin
              { kruispunt: één pad per paar aangesloten richtingen }
              Som := 0;
              for I := 0 to 3 do
              begin
                Buur := Cell.Buur(Richtingen[I].X, Richtingen[I].Y);
                if Buur <> nil then
                  Som := Som + RondOmhoog(Buur.DrukteFactor);
              end;
              { LET OP: verlaat de Y-lus en slaat de rest van de kolom over }
              if Som = 0 then
                Break;
              Lane := 0;
              for I := 0 to 3 do
                for L := I + 1 to 3 do
                begin
                  Bits := (1 shl I) + (1 shl L);
                  Buur := Cell.Buur(Richtingen[I].X, Richtingen[I].Y);
                  Buur2 := Cell.Buur(Richtingen[L].X, Richtingen[L].Y);
                  if (Buur <> nil) and (Buur2 <> nil) and (Bits and Mask = Bits) then
                  begin
                    Aantal := RondOmhoog(Cell.Reistijd);
                    if (Buur.Drukte = 0) or (Buur2.Drukte = 0) then
                      Aantal := 0
                    else if (Aantal = 0) and (Buur.Drukte <> 0) and (Buur2.Drukte <> 0) then
                      Aantal := 1
                    else if Tijd > 2 then
                      Aantal := 4;
                    if Aantal <> 0 then
                    begin
                      Inc(Lane);
                      DrawAutos(P, Aantal, Bits, Fase, BitCount[Mask], Lane, Mask, Cell,
                        0, 0, 0);
                    end;
                  end;
                end;
            end;
          end
          else if (Cell.Inhoud = 'Klaver') and (Cell.Hoofd = nil) and
            FInstellingen.KlaverbladAutosZichtbaar then
          begin
            { de hoofdcel van een klaverblad is de onderste hoek; ze beslaat 3x3 cellen }
            K[1] := Verkeer(Cell.Buur(-1, 1));
            K[3] := Verkeer(Cell.Buur(1, -1));
            K[5] := Verkeer(Cell.Buur(-3, -1));
            K[7] := Verkeer(Cell.Buur(-1, -3));
            if Cell.Buur(-1, -1).Drukte > 0 then
            begin
              if Beide(1, 1) then
                DrawAutos(P, 1, 1, Fase, 2, 1, 1, Cell.Buur(-1, 0), -88, -44, 3);
              if Beide(7, 7) then
                DrawAutos(P, 1, 1, Fase, 2, 1, 1, Cell.Buur(-1, -2), 88, -132, 2);
              for I := 1 to 2 do
              begin
                if Beide(3, 3) then
                  DrawAutos(P, 1, I, Fase, 2, 1, I, Cell.Buur(0, -1), 88, -44, 4);
                if Beide(5, 5) then
                  DrawAutos(P, 1, I, Fase, 2, 1, I, Cell.Buur(-2, -1), -88, -132, 1);
                DrawAutos(P, 1, I, Fase, 2, 1, I, Cell.Buur(-2, -2), 0, -176, 5);
                DrawAutos(P, 1, I, Fase, 2, 1, I, Cell.Buur(-2, 0), -176, -88, 6);
                DrawAutos(P, 1, I, Fase, 2, 1, I, Cell.Buur(0, -2), 176, -88, 7);
                DrawAutos(P, 1, I, Fase, 2, 1, I, Cell.Buur(0, 0), 0, 0, 8);
                DrawAutos(P, 1, I, Fase, 2, 1, I, Cell.Buur(-1, -1), 0, -88, 9);
              end;
            end;
          end;
        end;
      end;
    FGetekend := True;
    Inc(ProfAutos, GetTickCount);
  end;
end;

{ @00476098 }
constructor TSegment.Create(P1, P2: TPoint; ARichting: Char);
begin
  FVan := P1;
  FNaar := P2;
  FRichting := ARichting;
end;

{ @004760F4 }
function TSegmentList.Add(Segment: TSegment): TSegment;
begin
  inherited Add(Segment);
  Result := Segment;
end;

{ @00476104 }
function TSegmentList.GetItem(Nr: Integer): TSegment;
begin
  Result := TObject(Get(Nr)) as TSegment;
end;

{ @00476124  Gewoon wegstuk: Wegen-bitmasker Nr, paden als puntletters,
  RHeen/RTerug geven de richting van elk segment. }
procedure MaakWeg(Nr: Integer; SHeen, STerug, RHeen, RTerug: string);
var
  I: Integer;
begin
  Heen[Nr] := TSegmentList.Create;
  for I := 1 to Length(SHeen) - 1 do
    Heen[Nr].Add(TSegment.Create(Punten[SHeen[I]], Punten[SHeen[I + 1]], RHeen[I]));
  Terug[Nr] := TSegmentList.Create;
  for I := 1 to Length(STerug) - 1 do
    Terug[Nr].Add(TSegment.Create(Punten[STerug[I]], Punten[STerug[I + 1]], RTerug[I]));
end;

{ @00476274  Snelwegstuk. }
procedure MaakSnelweg(Nr: Integer; SHeen, STerug, RHeen, RTerug: string);
var
  I: Integer;
begin
  SnelHeen[Nr] := TSegmentList.Create;
  for I := 1 to Length(SHeen) - 1 do
    SnelHeen[Nr].Add(TSegment.Create(Punten[SHeen[I]], Punten[SHeen[I + 1]], RHeen[I]));
  SnelTerug[Nr] := TSegmentList.Create;
  for I := 1 to Length(STerug) - 1 do
    SnelTerug[Nr].Add(TSegment.Create(Punten[STerug[I]], Punten[STerug[I + 1]], RTerug[I]));
end;

{ @004763C4  Klaverbladstuk, één richting. }
procedure MaakKlaver(Nr, Piece: Integer; S, R: string);
var
  I: Integer;
begin
  KlaverHeen[Nr, Piece] := TSegmentList.Create;
  for I := 1 to Length(S) - 1 do
    KlaverHeen[Nr, Piece].Add(TSegment.Create(Punten[S[I]], Punten[S[I + 1]], R[I]));
end;

{ @004764A4  Klaverbladstuk, beide richtingen. }
procedure MaakKlaver2(Nr, Piece: Integer; SHeen, STerug: string);
var
  I: Integer;
begin
  KlaverHeen[Nr, Piece] := TSegmentList.Create;
  for I := 1 to Length(SHeen) - 1 do
    KlaverHeen[Nr, Piece].Add(TSegment.Create(Punten[SHeen[I]], Punten[SHeen[I + 1]],
      SHeen[I]));
  KlaverTerug[Nr, Piece] := TSegmentList.Create;
  for I := 1 to Length(STerug) - 1 do
    KlaverTerug[Nr, Piece].Add(TSegment.Create(Punten[STerug[I]], Punten[STerug[I + 1]],
      STerug[I]));
end;

{ @00476634 }
initialization
  for I := 0 to 15 do
  begin
    Heen[I] := nil;
    Terug[I] := nil;
    SnelHeen[I] := nil;
    SnelTerug[I] := nil;
    for J := 0 to 8 do
    begin
      KlaverHeen[J, I] := nil;
      KlaverTerug[J, I] := nil;
    end;
  end;

  { de hoekpunten van een wegcel }
  X1 := -58;
  Y1 := -15;
  X2 := -30;
  Y2 := -29;
  Punten['A'] := Point(X1, Y1);
  Punten['B'] := Point(X2, Y2);
  Punten['C'] := Point(X1, -Y1);
  Punten['D'] := Point(X2, 0);
  Punten['E'] := Point(0, Y1);
  Punten['F'] := Point(-X2, Y2);
  Punten['G'] := Point(X2, -Y2);
  Punten['H'] := Point(0, -Y1);
  Punten['I'] := Point(-X2, 0);
  Punten['J'] := Point(-X1, Y1);
  Punten['K'] := Point(-X2, -Y2);
  Punten['L'] := Point(-X1, -Y1);

  AutoFrame['A'] := 2;
  AutoFrame['B'] := 8;
  AutoFrame['C'] := 4;
  AutoFrame['D'] := 64;
  AutoFrame['E'] := 128;
  AutoFrame['F'] := 4;
  AutoFrame['G'] := 1;
  AutoFrame['H'] := 32;
  AutoFrame['I'] := 16;
  AutoFrame['J'] := 1;
  AutoFrame['K'] := 2;
  AutoFrame['L'] := 8;
  AutoFrame['M'] := 4;
  AutoFrame['N'] := 1;
  AutoFrame['O'] := 2;
  AutoFrame['P'] := 8;
  AutoFrame['Q'] := 2;
  AutoFrame['R'] := 8;

  MaakWeg(9, 'FEB', 'ADIJ', 'AAJJ', 'FBB');
  MaakWeg(3, 'LIJ', 'FEHK', 'FFKK', 'LJJ');
  MaakWeg(12, 'ADC', 'GHEB', 'ACC', 'GGBB');
  MaakWeg(6, 'GHK', 'LIDC', 'LLCC', 'GKK');
  MaakWeg(10, 'AK', 'LB', 'AK', 'LB');
  MaakWeg(5, 'FC', 'GJ', 'FC', 'GJ');
  MaakSnelweg(9, 'ADIJ', 'FB', 'AHHJ', 'EE');
  MaakSnelweg(10, 'AK', 'LB', 'AK', 'LB');
  MaakSnelweg(3, 'FEHK', 'LJ', 'FDDK', 'II');
  MaakSnelweg(12, 'AC', 'GHEB', 'DD', 'GIIB');
  MaakSnelweg(5, 'FC', 'GJ', 'FC', 'GJ');
  MaakSnelweg(6, 'LIDC', 'GK', 'LEEC', 'HH');

  { het klaverblad, stuk voor stuk }
  Punten['a'] := Point(-58, -15);
  Punten['b'] := Point(5, 6);
  Punten['c'] := Point(67, 35);
  Punten['d'] := Point(88, 22);
  Punten['e'] := Point(26, -6);
  Punten['f'] := Point(-30, -29);
  MaakKlaver2(1, 1, 'ab', 'ef');
  MaakKlaver2(2, 1, 'bc', 'de');
  Punten['a'] := Point(30, -29);
  Punten['b'] := Point(-49, 9);
  Punten['c'] := Point(-23, 22);
  Punten['d'] := Point(58, -15);
  MaakKlaver2(1, 2, 'ab', 'cd');
  Punten['a'] := Point(-30, 29);
  Punten['b'] := Point(58, -15);
  Punten['c'] := Point(30, -29);
  Punten['d'] := Point(-58, 15);
  MaakKlaver2(1, 3, 'ab', 'cd');
  Punten['a'] := Point(58, 15);
  Punten['b'] := Point(-17, -30);
  Punten['c'] := Point(-90, -69);
  Punten['d'] := Point(-111, -54);
  Punten['e'] := Point(-36, -16);
  Punten['f'] := Point(30, 29);
  MaakKlaver2(1, 4, 'ab', 'ef');
  MaakKlaver2(2, 4, 'bc', 'de');
  Punten['a'] := Point(-9, 39);
  Punten['b'] := Point(-36, 27);
  Punten['c'] := Point(-60, 10);
  Punten['d'] := Point(-52, -8);
  Punten['e'] := Point(-30, -18);
  Punten['f'] := Point(5, -22);
  Punten['g'] := Point(34, -16);
  Punten['h'] := Point(59, 0);
  Punten['i'] := Point(59, 20);
  Punten['j'] := Point(42, 34);
  Punten['k'] := Point(22, 43);
  MaakKlaver(1, 5, 'abcdef', 'abcdef');
  MaakKlaver(2, 5, 'fghijk', 'fghijk');
  Punten['a'] := Point(98, 4);
  Punten['b'] := Point(71, 19);
  Punten['c'] := Point(40, 31);
  Punten['d'] := Point(-5, 27);
  Punten['e'] := Point(-35, 12);
  Punten['f'] := Point(-35, -16);
  Punten['g'] := Point(-5, -29);
  Punten['h'] := Point(30, -35);
  Punten['i'] := Point(58, -30);
  Punten['j'] := Point(78, -23);
  Punten['k'] := Point(103, -12);
  MaakKlaver(1, 6, 'abcdef', 'abcdef');
  MaakKlaver(2, 6, 'fghijk', 'fghijk');
  Punten['a'] := Point(-91, -11);
  Punten['b'] := Point(-67, -23);
  Punten['c'] := Point(-38, -32);
  Punten['d'] := Point(-5, -32);
  Punten['e'] := Point(20, -23);
  Punten['f'] := Point(36, -7);
  Punten['g'] := Point(29, 17);
  Punten['h'] := Point(7, 27);
  Punten['i'] := Point(-30, 29);
  Punten['j'] := Point(-60, 18);
  Punten['k'] := Point(-81, 4);
  Punten['l'] := Point(-96, -7);
  MaakKlaver(1, 7, 'abcdef', 'abcdef');
  MaakKlaver(2, 7, 'fghijkl', 'fghijkl');
  Punten['a'] := Point(11, -62);
  Punten['b'] := Point(28, -51);
  Punten['c'] := Point(52, -32);
  Punten['d'] := Point(59, -2);
  Punten['e'] := Point(39, 15);
  Punten['f'] := Point(7, 20);
  Punten['g'] := Point(-33, 14);
  Punten['h'] := Point(-56, -6);
  Punten['i'] := Point(-53, -30);
  Punten['j'] := Point(-32, -45);
  Punten['k'] := Point(-12, -53);
  MaakKlaver(1, 8, 'abcdef', 'abcdef');
  MaakKlaver(2, 8, 'fghijk', 'fghijk');
  Punten['a'] := Point(-74, -16);
  Punten['b'] := Point(13, 28);
  MaakKlaver(1, 9, 'ab', 'ab');
  Punten['a'] := Point(74, -9);
  Punten['b'] := Point(-13, -51);
  MaakKlaver(2, 9, 'ab', 'ab');
end.

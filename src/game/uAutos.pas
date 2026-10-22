unit uAutos;

{ The cars: TAutoSprite covers the city view and draws every car as a small white
  square onto the view surface, moving along fixed paths (TSegmentList of
  TSegment) per road piece: ordinary roads, motorways and the nine cells of a
  'Klaver' (cloverleaf interchange). The number of cars per road follows the
  traffic simulation of Uworld.
  Decompiled from ROS.exe v1.1, code 00474EF0-004775DB (the literal pool of the
  initialization section continues up to 004777F7, in the range that the unit map
  attributes to uTransition). }

{$I zm.inc}

interface

uses
  Windows, Classes, uSurface, uSprite, uSpritebox, Usett, Uworld, Uview;

type
  { VMT 00474F3C, instance size $158. }
  TAutoSprite = class(TSprite)
  private
    FReserved13C: Integer;           { +0x13C  not used }
    FWorld: TWorld;                  { +0x140 }
    FView: TView;                    { +0x144 }
    FSettings: TSettings;            { +0x148 }
    FDrawn: Boolean;                 { +0x14C  set after the first Draw, never read }
    FStartTick: Integer;             { +0x150  GetTickCount at the start of the current period }
    FFase: Integer;                  { +0x154  period counter 0..77, selects the cars of a junction }
  public
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;                                        { +0x64 }
    property World: TWorld read FWorld;
    property View: TView read FView;
    property Settings: TSettings read FSettings;
  end;

  { VMT 00475070, instance size $18. One straight piece of a car path, in world
    pixels relative to the cell. }
  TSegment = class(TObject)
  private
    FVan: TPoint;                    { +0x04 }
    FNaar: TPoint;                   { +0x0C }
    FRichting: Char;                 { +0x14  index into AutoFrame }
  public
    constructor Create(P1, P2: TPoint; ARichting: Char);
    property Van: TPoint read FVan;
    property Naar: TPoint read FNaar;
    property Richting: Char read FRichting;
  end;

  { VMT 004750C8, instance size $10. }
  TSegmentList = class(TList)
  public
    function Add(Segment: TSegment): TSegment;
    function GetItem(Index: Integer): TSegment;
    property Items[Index: Integer]: TSegment read GetItem; default;
  end;

function CreateAutos(SpriteBox: TSpriteBox; Template: TSprite; AWorld: TWorld;
  AView: TView; ASettings: TSettings): TAutoSprite;

implementation

uses
  SysUtils, Graphics, uTool, Uconst, SprBmp;

const
  { 00488EDC: number of bits set in 0..15 (number of connected road directions) }
  BitCount: array[0..15] of Integer = (0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4);

var
  { 0048A990: car paths of an ordinary road, per TCell.Wegen bitmask }
  Heen: array[0..15] of TSegmentList;
  { 0048A9D0 }
  Terug: array[0..15] of TSegmentList;
  { 0048AA10: car paths of a motorway }
  SnelHeen: array[0..15] of TSegmentList;
  { 0048AA50 }
  SnelTerug: array[0..15] of TSegmentList;
  { 0048AA90: car paths on the cloverleaf: [lane 1..2, piece 1..9] }
  KlaverHeen: array[0..8, 0..15] of TSegmentList;
  { 0048ACD0: only pieces 1..4 }
  KlaverTerug: array[0..8, 0..15] of TSegmentList;
  { 0048AF10: car frame ('auto<n>') per segment direction }
  AutoFrame: array['A'..'R'] of Integer;
  { 0048AF58 }
  I: Integer;
  { 0048AF5C: path points; 'A'..'L' for roads, 'a'..'l' reused for each cloverleaf piece }
  Punten: array['A'..'z'] of TPoint;
  { NOTE: X1, Y1 and X2 were kept in registers (EDI, EBX, ESI) by the compiler;
    only Y2 has a memory location (0048B12C). }
  X1, Y1, X2, Y2: Integer;
  J: Integer;

{ @004750E8 }
function CreateAutos(SpriteBox: TSpriteBox; Template: TSprite; AWorld: TWorld;
  AView: TView; ASettings: TSettings): TAutoSprite;
begin
  Result := TAutoSprite.CreateCopy(Template);
  Result.FWorld := AWorld;
  AView.Autos := Result;
  Result.MarginRight := 792;
  Result.MarginBottom := 605;
  Result.MoveTo3D(30, 81, 1000);
  Result.Visible := True;
  Result.FView := AView;
  Result.FFase := 0;
  Result.FStartTick := GetTickCount;
  Result.FSettings := ASettings;
end;

{ @00475178 }
function Verkeer(Cell: TCell): Integer;
begin
  Result := 0;
  if (Cell <> nil) and (Cell.Drukte > 0) then
    Result := 1;
end;

{ @0047519C  Position (X, Y) at fraction F of the path; returns the car frame name,
  or '' when there is no path. }
function SegmentPos(List: TSegmentList; var X, Y: Integer; F: Double): string;
var
  N, Index, AX1, AY1, AX2, AY2: Integer;
begin
  Result := '';
  if (List <> nil) and (List.Count <> 0) then
  begin
    N := List.Count;
    Index := Trunc(N * F);
    if Index >= N then
      Index := N - 1;
    Dec(N);
    if N > 0 then
      F := 1 - (1 - F);
    AX1 := List[Index].FVan.X;
    AY1 := List[Index].FVan.Y;
    AX2 := List[Index].FNaar.X;
    AY2 := List[Index].FNaar.Y;
    F := (F - Index / List.Count) * List.Count;
    X := Round(Interpolate(F, AX2, AX1));
    Y := Round(Interpolate(F, AY2, AY1));
    { NOTE: the cloverleaf paths use the directions 'a'..'l', which lie outside
      AutoFrame (the original reads Punten memory); the name is only tested for '' }
    Result := 'auto' + IntToStr(AutoFrame[List[Index].FRichting]);
  end;
end;

{ @00475934 }
procedure TAutoSprite.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Scale: Double);
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

  { @00475314  Plots one car (a white square) at (AX, AY) on Surface. }
  procedure PlotAuto(AX, AY: Integer);
  var
    Size, I, J, SX, SY: Integer;
  begin
    Size := Round(Zoom * 2);
    for I := (-Size) div 2 to Size div 2 + Size mod 2 - 1 do
      for J := (-Size) div 2 to Size div 2 + Size mod 2 - 1 do
      begin
        SX := Left + AX + I - CurDX;
        SY := Top + AY + J - CurDY;
        if CurDX <> 0 then
          CurDX := CurDX;
        if PtInRect(ViewRect, Point(SX, SY)) then
          TBmpSurface(Surface).Bitmap.Canvas.Pixels[AX + I, AY + J] := clWhite;
      end;
  end;

  { @00475440  Draws the N cars of one path (both directions) of a cell. }
  procedure DrawAutos(P: TPoint; N, Idx: Integer; F: Double; Kind, Lane, Mask: Integer;
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
      F := (GetTickCount - FStartTick) / T;
      while F >= 1 do
      begin
        F := F - 1;
        Inc(FStartTick, T);
        FFase := (FFase + 1) mod 78;
      end;
      if Mask = 7 then
        Lane := Lane mod 3 + 1;
      for I := 0 to N - 1 do
      begin
        G := I / N + F;
        while G > 1 do
          G := G - 1;

        if IsSnelweg(Cell.Contents, 'X') then
          S := SegmentPos(SnelHeen[Idx], X, Y, G)
        else if Cell.Contents = 'Klaver' then
        begin
          { NOTE: both branches are the same }
          if Piece < 5 then
            S := SegmentPos(KlaverHeen[Idx, Piece], X, Y, G)
          else
            S := SegmentPos(KlaverHeen[Idx, Piece], X, Y, G);
        end
        else
          S := SegmentPos(Heen[Idx], X, Y, G);
        if S > '' then
          if (Kind < 3) or
             ((Kind = 3) and (((Lane in [1, 2]) and (FFase mod 2 = 0)) or
                              ((Lane = 3) and (FFase mod 2 = 1)))) or
             ((Kind = 4) and (((Lane in [4, 5]) and (FFase mod 3 = 0)) or
                              ((Lane in [2, 3]) and (FFase mod 3 = 1)) or
                              ((Lane in [1, 6]) and (FFase mod 3 = 2)))) then
            PlotAuto(P.X + Round((X + OfsX) * Zoom), P.Y + Round((Y + OfsY) * Zoom));

        if IsSnelweg(Cell.Contents, 'X') then
          S := SegmentPos(SnelTerug[Idx], X, Y, G)
        else if Cell.Contents = 'Klaver' then
        begin
          { NOTE: for pieces 5..9 S keeps the value of the first direction }
          if Piece < 5 then
            S := SegmentPos(KlaverTerug[Idx, Piece], X, Y, G);
        end
        else
          S := SegmentPos(Terug[Idx], X, Y, G);
        if S > '' then
          if (Kind < 3) or
             ((Kind = 3) and (((Lane = 3) and (FFase mod 2 = 0)) or
                              ((Lane in [1, 2]) and (FFase mod 2 = 1)))) or
             ((Kind = 4) and (((Lane in [2, 3]) and (FFase mod 3 = 0)) or
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
  if FWorld.Reistijd <> -1 then
  begin
    Dec(PerfAutos, GetTickCount);
    for X := 0 to 44 do
      for Y := 0 to 44 do
      begin
        Cell := FWorld.GetCell(X, Y);
        if Cell <> nil then
        begin
          P := GridToScreen(Point(X, Y));
          P.X := P.X - (30 - DX);
          P.Y := P.Y - (81 - DY);
          if IsWeg(Cell.Contents, 'X') then
          begin
            Mask := Cell.Wegen;
            for I := 0 to 3 do
            begin
              Buur := Cell.Buur(Dirs[I].X, Dirs[I].Y);
              if (Buur <> nil) and (Buur.Drukte = 0) then
                Mask := Mask and (15 - (1 shl I));
            end;
            Tijd := Cell.Reistijd / 1.5;
            Periode := 3000;
            Fase := (GetTickCount mod Periode) / Periode;
            { a dead end next to a building: the cars turn into the building }
            if BitCount[Mask] = 1 then
              for I := 0 to 3 do
              begin
                Buur := Cell.Buur(Dirs[I].X, Dirs[I].Y);
                if (Buur <> nil) and IsBebouwing(Buur.Contents) and
                   ((Mask in [0, 1, 2, 4, 8]) or not IsSnelweg(Cell.Contents, 'X')) then
                  Mask := Mask or (1 shl I);
              end;
            if BitCount[Mask] = 2 then
            begin
              Aantal := IMin(RoundUp(Tijd), 5);
              if (Aantal = 0) and (Cell.DrukteFactor <> 0) then
                Aantal := 1;
              DrawAutos(P, Aantal, Mask, Fase, 2, 0, Mask, Cell, 0, 0, 0);
            end
            else if BitCount[Mask] > 2 then
            begin
              { junction: one path per pair of connected directions }
              Som := 0;
              for I := 0 to 3 do
              begin
                Buur := Cell.Buur(Dirs[I].X, Dirs[I].Y);
                if Buur <> nil then
                  Som := Som + RoundUp(Buur.DrukteFactor);
              end;
              { NOTE: leaves the Y loop, skipping the rest of the column }
              if Som = 0 then
                Break;
              Lane := 0;
              for I := 0 to 3 do
                for L := I + 1 to 3 do
                begin
                  Bits := (1 shl I) + (1 shl L);
                  Buur := Cell.Buur(Dirs[I].X, Dirs[I].Y);
                  Buur2 := Cell.Buur(Dirs[L].X, Dirs[L].Y);
                  if (Buur <> nil) and (Buur2 <> nil) and (Bits and Mask = Bits) then
                  begin
                    Aantal := RoundUp(Cell.Reistijd);
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
          else if (Cell.Contents = 'Klaver') and (Cell.Hoofd = nil) and
            FSettings.KlaverbladAutosVisible then
          begin
            { the main cell of a cloverleaf is its bottom corner; it covers 3x3 cells }
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
    FDrawn := True;
    Inc(PerfAutos, GetTickCount);
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
function TSegmentList.GetItem(Index: Integer): TSegment;
begin
  Result := TObject(Get(Index)) as TSegment;
end;

{ @00476124  Ordinary road piece: Wegen bitmask Index, paths as point letters,
  RHeen/RTerug give the direction of each segment. }
procedure MaakWeg(Index: Integer; SHeen, STerug, RHeen, RTerug: string);
var
  I: Integer;
begin
  Heen[Index] := TSegmentList.Create;
  for I := 1 to Length(SHeen) - 1 do
    Heen[Index].Add(TSegment.Create(Punten[SHeen[I]], Punten[SHeen[I + 1]], RHeen[I]));
  Terug[Index] := TSegmentList.Create;
  for I := 1 to Length(STerug) - 1 do
    Terug[Index].Add(TSegment.Create(Punten[STerug[I]], Punten[STerug[I + 1]], RTerug[I]));
end;

{ @00476274  Motorway piece. }
procedure MaakSnelweg(Index: Integer; SHeen, STerug, RHeen, RTerug: string);
var
  I: Integer;
begin
  SnelHeen[Index] := TSegmentList.Create;
  for I := 1 to Length(SHeen) - 1 do
    SnelHeen[Index].Add(TSegment.Create(Punten[SHeen[I]], Punten[SHeen[I + 1]], RHeen[I]));
  SnelTerug[Index] := TSegmentList.Create;
  for I := 1 to Length(STerug) - 1 do
    SnelTerug[Index].Add(TSegment.Create(Punten[STerug[I]], Punten[STerug[I + 1]], RTerug[I]));
end;

{ @004763C4  Cloverleaf piece, one direction. }
procedure MaakKlaver(Index, Piece: Integer; S, R: string);
var
  I: Integer;
begin
  KlaverHeen[Index, Piece] := TSegmentList.Create;
  for I := 1 to Length(S) - 1 do
    KlaverHeen[Index, Piece].Add(TSegment.Create(Punten[S[I]], Punten[S[I + 1]], R[I]));
end;

{ @004764A4  Cloverleaf piece, both directions. }
procedure MaakKlaver2(Index, Piece: Integer; SHeen, STerug: string);
var
  I: Integer;
begin
  KlaverHeen[Index, Piece] := TSegmentList.Create;
  for I := 1 to Length(SHeen) - 1 do
    KlaverHeen[Index, Piece].Add(TSegment.Create(Punten[SHeen[I]], Punten[SHeen[I + 1]],
      SHeen[I]));
  KlaverTerug[Index, Piece] := TSegmentList.Create;
  for I := 1 to Length(STerug) - 1 do
    KlaverTerug[Index, Piece].Add(TSegment.Create(Punten[STerug[I]], Punten[STerug[I + 1]],
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

  { the corner points of a road cell }
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

  { the cloverleaf, piece by piece }
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

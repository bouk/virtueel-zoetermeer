unit uTrein;

{ TTrein: the train. It appears on a random rail cell outside the view, then
  rides from cell to cell along the rails ('Rails05'/'Rails10' straight,
  'Rails03/06/09/12' curves of 3x3 cells), stopping at stations. Its sprite is
  the TView's train sprite; the positions within a cell come from the path
  strings below ('<frame>=<x>,<y>;' per step, a leading '-' mirrors the frame).
  Decompiled from ROS.exe v1.1, code 0047841C-0047950F. }

{$I zm.inc}

interface

uses
  Windows, Classes, uSprite, Uworld;

type
  { VMT 0047886C, instance size $30. }
  TTrein = class(TObject)
  private
    FSprite: TSprite;              { +0x04  TView.TreinSprite; Data is a TPos with the cell }
    FWorld: TWorld;                { +0x08 }
    FCell: TCell;                  { +0x0C  current cell (the main cell of a curve) }
    FNr: Byte;                     { +0x10  rail piece (IsSpoor): 5/10 straight, 3/6/9/12 curve }
    FRichting: Boolean;            { +0x11  direction of travel }
    FActief: Boolean;              { +0x12  riding (False: look for a new start) }
    FStap: Integer;                { +0x14  step within the path of the current cell }
    FReserved18: Integer;          { +0x18  set to 0 / -1, never read }
    FX: Integer;                   { +0x1C  world position }
    FY: Integer;                   { +0x20 }
    FWacht: Integer;               { +0x24  steps before the train may stop at a station again }
    FInterval: Integer;            { +0x28  ticks per step }
    FTeller: Integer;              { +0x2C  ticks since the last step }
    procedure Start;
    procedure Step;
    procedure Volgende;
    procedure Stop;
  public
    constructor Create(ASprite: TSprite; AWorld: TWorld);
    procedure Tick;
    property Sprite: TSprite read FSprite;
    property World: TWorld read FWorld;
  end;

  { Transition from one rail piece to the next (16 bytes) }
  TOvergang = record
    Nr: Byte;                      { +0x0 current piece }
    Richting: Boolean;             { +0x1 current direction }
    NieuwNr: Byte;                 { +0x2 next piece }
    DX: Integer;                   { +0x4 offset of the next cell }
    DY: Integer;                   { +0x8 }
    NieuwRichting: Boolean;        { +0xC next direction }
  end;

const
  { 00488F78: from a straight piece onto a curve }
  RechtNaarBocht: array[0..7] of TOvergang = (
    (Nr: 5; Richting: True; NieuwNr: 6; DX: 1; DY: -1; NieuwRichting: False),
    (Nr: 5; Richting: True; NieuwNr: 12; DX: 0; DY: -1; NieuwRichting: True),
    (Nr: 5; Richting: False; NieuwNr: 3; DX: 1; DY: 2; NieuwRichting: True),
    (Nr: 5; Richting: False; NieuwNr: 9; DX: 0; DY: 2; NieuwRichting: False),
    (Nr: 10; Richting: True; NieuwNr: 3; DX: -1; DY: 0; NieuwRichting: False),
    (Nr: 10; Richting: True; NieuwNr: 6; DX: -1; DY: 1; NieuwRichting: True),
    (Nr: 10; Richting: False; NieuwNr: 9; DX: 2; DY: 0; NieuwRichting: True),
    (Nr: 10; Richting: False; NieuwNr: 12; DX: 2; DY: 1; NieuwRichting: False));
  { 00488FF8: from a curve onto a straight piece }
  BochtNaarRecht: array[0..7] of TOvergang = (
    (Nr: 3; Richting: False; NieuwNr: 5; DX: -1; DY: -3; NieuwRichting: True),
    (Nr: 3; Richting: True; NieuwNr: 10; DX: 2; DY: 0; NieuwRichting: False),
    (Nr: 6; Richting: False; NieuwNr: 10; DX: 2; DY: -1; NieuwRichting: False),
    (Nr: 6; Richting: True; NieuwNr: 5; DX: -1; DY: 2; NieuwRichting: False),
    (Nr: 9; Richting: False; NieuwNr: 10; DX: -3; DY: 0; NieuwRichting: True),
    (Nr: 9; Richting: True; NieuwNr: 5; DX: 0; DY: -3; NieuwRichting: True),
    (Nr: 12; Richting: False; NieuwNr: 5; DX: 0; DY: 2; NieuwRichting: False),
    (Nr: 12; Richting: True; NieuwNr: 10; DX: -3; DY: -1; NieuwRichting: True));
  { 00489078: from a curve onto the next curve }
  BochtNaarBocht: array[0..15] of TOvergang = (
    (Nr: 3; Richting: False; NieuwNr: 6; DX: 0; DY: -4; NieuwRichting: False),
    (Nr: 3; Richting: False; NieuwNr: 12; DX: -1; DY: -4; NieuwRichting: True),
    (Nr: 3; Richting: True; NieuwNr: 9; DX: 4; DY: 0; NieuwRichting: True),
    (Nr: 3; Richting: True; NieuwNr: 12; DX: 4; DY: 1; NieuwRichting: False),
    (Nr: 6; Richting: False; NieuwNr: 12; DX: 4; DY: 0; NieuwRichting: False),
    (Nr: 6; Richting: False; NieuwNr: 9; DX: 4; DY: -1; NieuwRichting: True),
    (Nr: 6; Richting: True; NieuwNr: 3; DX: 0; DY: 4; NieuwRichting: True),
    (Nr: 6; Richting: True; NieuwNr: 9; DX: -1; DY: 4; NieuwRichting: False),
    (Nr: 9; Richting: False; NieuwNr: 3; DX: -4; DY: 0; NieuwRichting: False),
    (Nr: 9; Richting: False; NieuwNr: 6; DX: -4; DY: 1; NieuwRichting: True),
    (Nr: 9; Richting: True; NieuwNr: 12; DX: 0; DY: -4; NieuwRichting: True),
    (Nr: 9; Richting: True; NieuwNr: 6; DX: 1; DY: -4; NieuwRichting: False),
    (Nr: 12; Richting: False; NieuwNr: 9; DX: 0; DY: 4; NieuwRichting: False),
    (Nr: 12; Richting: False; NieuwNr: 3; DX: 1; DY: 4; NieuwRichting: True),
    (Nr: 12; Richting: True; NieuwNr: 6; DX: -4; DY: 0; NieuwRichting: True),
    (Nr: 12; Richting: True; NieuwNr: 3; DX: -4; DY: -1; NieuwRichting: False));
  { 00489178: paths through the curves 3, 6, 9, 12 (FRichting = False) }
  BochtA: array[1..4] of string = (
    ' 0505=206,151; 0606=175,111; 0707=183,84; 0808=199,59; 0900=181,55;  1000=175,36;  1100=198,10; 1312=175,-4;1413=175,-4;1413=172,-24;15,14=202,49',
    ' 1615=-10,71;  1716=25,73;   1800=55,79;  1900=105,70;-1900=144,70; -1800=192,79; -1716=232,73;-1615=278,71',
    '-0404=269,-38;-0303=222,-19;-0200=184,-5;-0100=138,17; 0100=108,17;  0200=71,-5;   0303=43,-19; 0404=5,-38',
    '-1514=-98,-49;-1413=-46,-24;-1312=-7,-4, -1211=20,10; -1100=44,21;  -1000=67,36;  -0900=36,55; -0808=15,59; -0707=-17,84; -0606=-49,11');
  { 00489188: paths through the curves 3, 6, 9, 12 (FRichting = True) }
  BochtB: array[1..4] of string = (
    ' 1514=159,-69; 1413=121,-38; 1312=115,-14;1211=130,2;  0010=117,17; 0009=124,42; 0808=137,67;  0707=122,95; 0606=118,123; 0505=167,172',
    '-1615=310,46; -1716=256,44; -0017=173,50;  0018=121,43; 0017=59,50;  1716=1,44;   1615=-41,46',
    ' 0404=-26,-13; 0303=20,10;   0002=71,40;  0001=119,65;-0002=172,40;-0303=245,10;-0404=301,-13',
    '-0505=-63,172;-0606=8,123;  -0707=44,95;  -0808=77,67;-0009=116,42;-0010=124,17;-1211=88,2;   -1312=53,-14;-1413=5,-37;   -1514=-55,-69');

var
  { 0048B150: paths along the straight pieces 5 and 10 (FRichting = True), built by TTrein.Create }
  RechtA: array[1..2] of string;
  { 0048B158: (FRichting = False) }
  RechtB: array[1..2] of string;
  { 0048B160 }
  Trein: TTrein;

implementation

uses
  Math, Uconst, uString, uTool
  {$IFDEF FPC}, ZMRandom{$ENDIF}  { PORT: Delphi's Random };

{ @00478874 }
constructor TTrein.Create(ASprite: TSprite; AWorld: TWorld);
var
  I: Integer;
begin
  FSprite := ASprite;
  FSprite.Visible := False;
  FWorld := AWorld;
  FReserved18 := 0;
  FWacht := 0;
  FSprite.Data := TPos.Create(0, 0);
  RechtA[1] := '';
  RechtA[2] := '';
  RechtB[1] := '';
  RechtB[2] := '';
  for I := 0 to 6 do
  begin
    RechtA[1] := RechtA[1] + IntStr(Round(-153 + I * 88 / 6)) + ',' +
      IntStr(Round(-45 - I * 44 / 6)) + ';';
    RechtA[2] := RechtA[2] + IntStr(Round(-57 - I * 88 / 6)) + ',' +
      IntStr(Round(-59 - I * 44 / 6)) + ';';
    RechtB[1] := RechtB[1] + IntStr(Round(-105 - I * 88 / 6)) + ',' +
      IntStr(Round(-108 + I * 44 / 6)) + ';';
    RechtB[2] := RechtB[2] + IntStr(Round(-175 + I * 88 / 6)) + ',' +
      IntStr(Round(-87 + I * 44 / 6)) + ';';
  end;
  FTeller := 0;
  FInterval := 40;
end;

{ @00478B44 }
procedure TTrein.Tick;
begin
  Inc(FTeller);
  if FTeller >= FInterval then
  begin
    FTeller := 0;
    if not FActief then
      Start
    else
      Step;
  end;
end;

{ @00478B68  Looks for a rail cell outside the view to start from (400 tries). }
procedure TTrein.Start;
var
  I, X, Y: Integer;
  Voor, Achter: TCell;
  Nr1, Nr2: Byte;
begin
  for I := 1 to 400 do
  begin
    X := Random(44);
    Y := Random(44);
    if IsOutOfView(X, Y) then
    begin
      FCell := FWorld.GetCell(X, Y);
      if IsSpoor(FCell.Contents, FNr) then
      begin
        if FNr in [5, 10] then
        begin
          if FNr = 5 then
          begin
            Voor := FCell.Buur(0, 1);
            Achter := FCell.Buur(0, -1);
          end
          else
          begin
            Voor := FCell.Buur(1, 0);
            Achter := FCell.Buur(-1, 0);
          end;
          if IsSpoor(Voor.Contents, Nr1) and (Nr1 = FNr) and
             IsSpoor(Achter.Contents, Nr2) and (Nr2 = FNr) then
          begin
            FRichting := Random(2) = 0;
            FStap := 0;
            FActief := True;
            Break;
          end;
        end
        else if (FNr in [3, 6, 9, 12]) and (FCell.Hoofd = nil) then
        begin
          FRichting := Random(2) = 0;
          FStap := 0;
          FActief := True;
          Break;
        end;
      end;
    end;
  end;
  FReserved18 := -1;
  (FSprite.Data as TPos).X := FCell.X;
  (FSprite.Data as TPos).Y := FCell.Y;
end;

{ @00478CF0  Moves the train one step along the path of the current cell. }
procedure TTrein.Step;
var
  Pad, Item, Key, Vorige, S: string;
  P: TPoint;
  I, X, Y: Integer;
begin
  Inc(FStap);
  if FWacht > 0 then
    Dec(FWacht);
  if FNr in [5, 10] then
  begin
    if FRichting then
      Pad := RechtA[FNr div 5]
    else
      Pad := RechtB[FNr div 5];
  end
  else
  begin
    if FRichting then
      Pad := BochtB[FNr div 3]
    else
      Pad := BochtA[FNr div 3];
  end;
  for I := 1 to FStap do
    Item := SplitFirst(Pad, ';');
  if Pad = '' then
  begin
    Vorige := FCell.Contents;
    Volgende;
  end
  else
  begin
    if FNr = 5 then
    begin
      FSprite.MirrorX := False;
      FSprite.CurrentFrame := 'Trein_15-14';
    end
    else if FNr = 10 then
    begin
      FSprite.MirrorX := False;
      FSprite.CurrentFrame := 'Trein_05-05';
    end
    else
    begin
      S := SplitFirst(Item, '=');
      Key := TrimStr(S);
      if Key[1] = '-' then
      begin
        FSprite.MirrorX := True;
        Key := DelLeft(Key, 1);
      end
      else
        FSprite.MirrorX := False;
      FSprite.CurrentFrame := 'Trein_' + Copy(Key, 1, 2) + '-' + Copy(Key, 3, 4);
    end;
    Item := TrimStr(Item);
    S := SplitFirst(Item, ',');
    X := StrToIntDef0(S);
    Y := StrToIntDef0(Item);
    case FNr of
      3:
        begin
          X := X - 176;
          Y := Y - 175;
        end;
      6:
        begin
          X := X - 264;
          Y := Y - 131;
        end;
      9:
        begin
          X := X - 264;
          Y := Y - 131;
        end;
      12:
        begin
          X := X - 176;
          Y := Y - 175;
        end;
    end;
    P := GridToWorld(FCell.Pos);
    FX := X + P.X;
    FY := P.Y + Y;
    FSprite.MoveTo3D(FX, FY, -2900);
  end;
  if (((FCell.Contents = 'Station') and (Vorige = 'Hoofdstation')) or
      ((FCell.Contents = 'Hoofdstation') and (Vorige = 'Hoofdstation'))) and
     (FWacht = 0) then
  begin
    FInterval := 20;
    FWacht := 5;
  end
  else if FNr in [5, 10] then
    FInterval := 1
  else
    FInterval := 2;
end;

{ @00479168  Moves the train onto the next rail piece, or stops it. }
procedure TTrein.Volgende;
var
  D: TPoint;
  Bits, Nr1, Nr2: Byte;
  O: TOvergang;
  Buur1, Buur2: TCell;
  I: Integer;

  { @00479104 }
  procedure GaNaar(Cell: TCell);
  begin
    FCell := Cell;
    FStap := 0;
    (FSprite.Data as TPos).X := FCell.X;
    (FSprite.Data as TPos).Y := FCell.Y;
    Step;
  end;

begin
  if FNr in [5, 10] then
  begin
    if FRichting then
      Bits := FNr and 9
    else
      Bits := FNr and 6;
    D := Dirs[Round(Log2(Bits))];
    Buur1 := FCell.Buur(D.X, D.Y);
    Buur2 := Buur1.Buur(D.X, D.Y);
    if (Buur1 = nil) or (Buur2 = nil) or
       not IsSpoor(Buur1.Contents + Buur1.Param, Nr1) or
       not IsSpoor(Buur2.Contents + Buur2.Param, Nr2) then
      Stop
    else if Nr2 in [3, 6, 9, 12] then
    begin
      for I := 0 to 7 do
      begin
        O := RechtNaarBocht[I];
        if (FNr = O.Nr) and (FRichting = O.Richting) and (O.NieuwNr = Nr2) and
           (Buur1.Buur(O.DX, O.DY) <> nil) then
        begin
          FNr := O.NieuwNr;
          FRichting := O.NieuwRichting;
          GaNaar(Buur1.Buur(O.DX, O.DY));
          Exit;
        end;
      end;
      Stop;
    end
    else if FNr = Nr1 then
      GaNaar(Buur1)
    else
      Stop;
  end
  else
  begin
    for I := 0 to 15 do
    begin
      O := BochtNaarBocht[I];
      Buur1 := FCell.Buur(O.DX, O.DY);
      if (Buur1 <> nil) and (FNr = O.Nr) and (FRichting = O.Richting) and
         IsBochtSpoor(Buur1.Contents, Nr1) and (Buur1.Hoofd = nil) and (O.NieuwNr = Nr1) then
      begin
        FNr := O.NieuwNr;
        FRichting := O.NieuwRichting;
        GaNaar(FCell.Buur(O.DX, O.DY));
        Exit;
      end;
    end;
    for I := 0 to 7 do
    begin
      O := BochtNaarRecht[I];
      if (FNr = O.Nr) and (FRichting = O.Richting) then
      begin
        Buur1 := FCell.Buur(O.DX, O.DY);
        if Buur1 <> nil then
        begin
          if IsSpoor(Buur1.Contents + Buur1.Param, Nr1) and (Nr1 = O.NieuwNr) then
          begin
            FNr := Nr1;
            FRichting := O.NieuwRichting;
            GaNaar(Buur1);
          end
          else
            Stop;
          Exit;
        end;
      end;
    end;
    Stop;
  end;
end;

{ @0047947C }
procedure TTrein.Stop;
begin
  FActief := False;
end;

end.

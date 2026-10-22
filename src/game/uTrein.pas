unit uTrein;

{ TTrein: de trein. Hij verschijnt op een willekeurige spoorcel buiten het zicht, daarna
  rijdt van cel naar cel langs de sporen ('Rails05'/'Rails10' recht,
  'Rails03/06/09/12' bochten van 3x3 cellen), en stopt bij stations. Zijn sprite is
  de treinsprite van de TView; de posities binnen een cel komen uit de padstrings
  hieronder ('<frame>=<x>,<y>;' per stap, een voorloopse '-' spiegelt het frame).
  Gedecompileerd uit ROS.exe v1.1, code 0047841C-0047950F. }

{$I zm.inc}

interface

uses
  Windows, Classes, uSprite, Uworld;

type
  { VMT 0047886C, instantiegrootte $30. }
  TTrein = class(TObject)
  private
    FSprite: TSprite;              { +0x04  TView.TreinSprite; Data is een TPos met de cel }
    FWereld: TWorld;                { +0x08 }
    FCel: TCell;                  { +0x0C  huidige cel (de hoofdcel van een bocht) }
    FNr: Byte;                     { +0x10  spoorstuk (IsSpoor): 5/10 recht, 3/6/9/12 bocht }
    FRichting: Boolean;            { +0x11  rijrichting }
    FActief: Boolean;              { +0x12  rijdt (False: zoek een nieuw startpunt) }
    FStap: Integer;                { +0x14  stap binnen het pad van de huidige cel }
    FGereserveerd18: Integer;          { +0x18  ingesteld op 0 / -1, nooit gelezen }
    FX: Integer;                   { +0x1C  wereldpositie }
    FY: Integer;                   { +0x20 }
    FWacht: Integer;               { +0x24  stappen voordat de trein weer bij een station mag stoppen }
    FInterval: Integer;            { +0x28  ticks per stap }
    FTeller: Integer;              { +0x2C  ticks sinds de laatste stap }
    procedure Start;
    procedure Step;
    procedure Volgende;
    procedure Stop;
  public
    constructor Create(ASprite: TSprite; AWorld: TWorld);
    procedure Tik;
    property Sprite: TSprite read FSprite;
    property Wereld: TWorld read FWereld;
  end;

  { Overgang van het ene spoorstuk naar het volgende (16 bytes) }
  TOvergang = record
    Nr: Byte;                      { +0x0 huidig stuk }
    Richting: Boolean;             { +0x1 huidige richting }
    NieuwNr: Byte;                 { +0x2 volgend stuk }
    DX: Integer;                   { +0x4 verschuiving van de volgende cel }
    DY: Integer;                   { +0x8 }
    NieuwRichting: Boolean;        { +0xC volgende richting }
  end;

const
  { 00488F78: van een recht stuk naar een bocht }
  RechtNaarBocht: array[0..7] of TOvergang = (
    (Nr: 5; Richting: True; NieuwNr: 6; DX: 1; DY: -1; NieuwRichting: False),
    (Nr: 5; Richting: True; NieuwNr: 12; DX: 0; DY: -1; NieuwRichting: True),
    (Nr: 5; Richting: False; NieuwNr: 3; DX: 1; DY: 2; NieuwRichting: True),
    (Nr: 5; Richting: False; NieuwNr: 9; DX: 0; DY: 2; NieuwRichting: False),
    (Nr: 10; Richting: True; NieuwNr: 3; DX: -1; DY: 0; NieuwRichting: False),
    (Nr: 10; Richting: True; NieuwNr: 6; DX: -1; DY: 1; NieuwRichting: True),
    (Nr: 10; Richting: False; NieuwNr: 9; DX: 2; DY: 0; NieuwRichting: True),
    (Nr: 10; Richting: False; NieuwNr: 12; DX: 2; DY: 1; NieuwRichting: False));
  { 00488FF8: van een bocht naar een recht stuk }
  BochtNaarRecht: array[0..7] of TOvergang = (
    (Nr: 3; Richting: False; NieuwNr: 5; DX: -1; DY: -3; NieuwRichting: True),
    (Nr: 3; Richting: True; NieuwNr: 10; DX: 2; DY: 0; NieuwRichting: False),
    (Nr: 6; Richting: False; NieuwNr: 10; DX: 2; DY: -1; NieuwRichting: False),
    (Nr: 6; Richting: True; NieuwNr: 5; DX: -1; DY: 2; NieuwRichting: False),
    (Nr: 9; Richting: False; NieuwNr: 10; DX: -3; DY: 0; NieuwRichting: True),
    (Nr: 9; Richting: True; NieuwNr: 5; DX: 0; DY: -3; NieuwRichting: True),
    (Nr: 12; Richting: False; NieuwNr: 5; DX: 0; DY: 2; NieuwRichting: False),
    (Nr: 12; Richting: True; NieuwNr: 10; DX: -3; DY: -1; NieuwRichting: True));
  { 00489078: van een bocht naar de volgende bocht }
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
  { 00489178: paden door de bochten 3, 6, 9, 12 (FRichting = False) }
  BochtA: array[1..4] of string = (
    ' 0505=206,151; 0606=175,111; 0707=183,84; 0808=199,59; 0900=181,55;  1000=175,36;  1100=198,10; 1312=175,-4;1413=175,-4;1413=172,-24;15,14=202,49',
    ' 1615=-10,71;  1716=25,73;   1800=55,79;  1900=105,70;-1900=144,70; -1800=192,79; -1716=232,73;-1615=278,71',
    '-0404=269,-38;-0303=222,-19;-0200=184,-5;-0100=138,17; 0100=108,17;  0200=71,-5;   0303=43,-19; 0404=5,-38',
    '-1514=-98,-49;-1413=-46,-24;-1312=-7,-4, -1211=20,10; -1100=44,21;  -1000=67,36;  -0900=36,55; -0808=15,59; -0707=-17,84; -0606=-49,11');
  { 00489188: paden door de bochten 3, 6, 9, 12 (FRichting = True) }
  BochtB: array[1..4] of string = (
    ' 1514=159,-69; 1413=121,-38; 1312=115,-14;1211=130,2;  0010=117,17; 0009=124,42; 0808=137,67;  0707=122,95; 0606=118,123; 0505=167,172',
    '-1615=310,46; -1716=256,44; -0017=173,50;  0018=121,43; 0017=59,50;  1716=1,44;   1615=-41,46',
    ' 0404=-26,-13; 0303=20,10;   0002=71,40;  0001=119,65;-0002=172,40;-0303=245,10;-0404=301,-13',
    '-0505=-63,172;-0606=8,123;  -0707=44,95;  -0808=77,67;-0009=116,42;-0010=124,17;-1211=88,2;   -1312=53,-14;-1413=5,-37;   -1514=-55,-69');

var
  { 0048B150: paden langs de rechte stukken 5 en 10 (FRichting = True), opgebouwd door TTrein.Create }
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
  FWereld := AWorld;
  FGereserveerd18 := 0;
  FWacht := 0;
  FSprite.Data := TPos.Create(0, 0);
  RechtA[1] := '';
  RechtA[2] := '';
  RechtB[1] := '';
  RechtB[2] := '';
  for I := 0 to 6 do
  begin
    RechtA[1] := RechtA[1] + IntTekst(Round(-153 + I * 88 / 6)) + ',' +
      IntTekst(Round(-45 - I * 44 / 6)) + ';';
    RechtA[2] := RechtA[2] + IntTekst(Round(-57 - I * 88 / 6)) + ',' +
      IntTekst(Round(-59 - I * 44 / 6)) + ';';
    RechtB[1] := RechtB[1] + IntTekst(Round(-105 - I * 88 / 6)) + ',' +
      IntTekst(Round(-108 + I * 44 / 6)) + ';';
    RechtB[2] := RechtB[2] + IntTekst(Round(-175 + I * 88 / 6)) + ',' +
      IntTekst(Round(-87 + I * 44 / 6)) + ';';
  end;
  FTeller := 0;
  FInterval := 40;
end;

{ @00478B44 }
procedure TTrein.Tik;
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

{ @00478B68  Zoekt een spoorcel buiten het zicht om vanaf te starten (400 pogingen). }
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
    if IsBuitenBeeld(X, Y) then
    begin
      FCel := FWereld.LeesCel(X, Y);
      if IsSpoor(FCel.Inhoud, FNr) then
      begin
        if FNr in [5, 10] then
        begin
          if FNr = 5 then
          begin
            Voor := FCel.Buur(0, 1);
            Achter := FCel.Buur(0, -1);
          end
          else
          begin
            Voor := FCel.Buur(1, 0);
            Achter := FCel.Buur(-1, 0);
          end;
          if IsSpoor(Voor.Inhoud, Nr1) and (Nr1 = FNr) and
             IsSpoor(Achter.Inhoud, Nr2) and (Nr2 = FNr) then
          begin
            FRichting := Random(2) = 0;
            FStap := 0;
            FActief := True;
            Break;
          end;
        end
        else if (FNr in [3, 6, 9, 12]) and (FCel.Hoofd = nil) then
        begin
          FRichting := Random(2) = 0;
          FStap := 0;
          FActief := True;
          Break;
        end;
      end;
    end;
  end;
  FGereserveerd18 := -1;
  (FSprite.Data as TPos).X := FCel.X;
  (FSprite.Data as TPos).Y := FCel.Y;
end;

{ @00478CF0  Verplaatst de trein één stap langs het pad van de huidige cel. }
procedure TTrein.Step;
var
  Pad, Item, Sleutel, Vorige, S: string;
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
    Item := SplitsEerste(Pad, ';');
  if Pad = '' then
  begin
    Vorige := FCel.Inhoud;
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
      S := SplitsEerste(Item, '=');
      Sleutel := SnijStr(S);
      if Sleutel[1] = '-' then
      begin
        FSprite.MirrorX := True;
        Sleutel := VerwijderLinks(Sleutel, 1);
      end
      else
        FSprite.MirrorX := False;
      FSprite.CurrentFrame := 'Trein_' + Copy(Sleutel, 1, 2) + '-' + Copy(Sleutel, 3, 4);
    end;
    Item := SnijStr(Item);
    S := SplitsEerste(Item, ',');
    X := StrNaarIntDef0(S);
    Y := StrNaarIntDef0(Item);
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
    P := RasterNaarWereld(FCel.Pos);
    FX := X + P.X;
    FY := P.Y + Y;
    FSprite.VerplaatsNaar3D(FX, FY, -2900);
  end;
  if (((FCel.Inhoud = 'Station') and (Vorige = 'Hoofdstation')) or
      ((FCel.Inhoud = 'Hoofdstation') and (Vorige = 'Hoofdstation'))) and
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

{ @00479168  Zet de trein op het volgende spoorstuk, of stopt hem. }
procedure TTrein.Volgende;
var
  D: TPoint;
  Bits, Nr1, Nr2: Byte;
  O: TOvergang;
  Buur1, Buur2: TCell;
  I: Integer;

  { @00479104 }
  procedure GaNaar(Cel: TCell);
  begin
    FCel := Cel;
    FStap := 0;
    (FSprite.Data as TPos).X := FCel.X;
    (FSprite.Data as TPos).Y := FCel.Y;
    Step;
  end;

begin
  if FNr in [5, 10] then
  begin
    if FRichting then
      Bits := FNr and 9
    else
      Bits := FNr and 6;
    D := Richtingen[Round(Log2(Bits))];
    Buur1 := FCel.Buur(D.X, D.Y);
    Buur2 := Buur1.Buur(D.X, D.Y);
    if (Buur1 = nil) or (Buur2 = nil) or
       not IsSpoor(Buur1.Inhoud + Buur1.Param, Nr1) or
       not IsSpoor(Buur2.Inhoud + Buur2.Param, Nr2) then
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
      Buur1 := FCel.Buur(O.DX, O.DY);
      if (Buur1 <> nil) and (FNr = O.Nr) and (FRichting = O.Richting) and
         IsBochtSpoor(Buur1.Inhoud, Nr1) and (Buur1.Hoofd = nil) and (O.NieuwNr = Nr1) then
      begin
        FNr := O.NieuwNr;
        FRichting := O.NieuwRichting;
        GaNaar(FCel.Buur(O.DX, O.DY));
        Exit;
      end;
    end;
    for I := 0 to 7 do
    begin
      O := BochtNaarRecht[I];
      if (FNr = O.Nr) and (FRichting = O.Richting) then
      begin
        Buur1 := FCel.Buur(O.DX, O.DY);
        if Buur1 <> nil then
        begin
          if IsSpoor(Buur1.Inhoud + Buur1.Param, Nr1) and (Nr1 = O.NieuwNr) then
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

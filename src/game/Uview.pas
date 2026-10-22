unit Uview;

{ TView: de pixie die de stad tekent. De grondlaag (wegen, sporen, gras,
  stoepen) wordt per gewijzigde cel op een groot oppervlak ter grootte van de wereld geschilderd
  (FTegel, opgebouwd uit images\8bits\Tile.bmp); gebouwen en stations zijn
  TViewSprite-kopieën van de sjabloon-sprites, van achter naar voren getekend door Draw.
  Bevat ook de scroll/zoom-status (Uconst.VerschuivingX/VerschuivingY/Zoom).
  Gedecompileerd uit ROS.exe v1.1, code 00472F7C-00474EEF. }

{$I zm.inc}

interface

uses
  Windows, Classes, uSurface, uPixie, uSprite, uSpritebox, uTool, Usett, Uworld;

type
  { VMT 00472FC8, instantiegrootte $150. Een gebouw- of stationssprite op de kaart. }
  TViewSprite = class(TSprite)
  private
    FGereserveerd13C: Integer;           { +0x13C  niet gebruikt }
    FPositie: TPos;                      { +0x140  linkerbovencel van het grondvlak; X = -1: de trein }
    FGeanimeerd: Boolean;              { +0x144  frames <FAnimatieNaam>_0, _1, ... worden doorlopen (Molen, Siemens2) }
    FAnimatieFrame: Integer;             { +0x148 }
    FAnimatieNaam: string;               { +0x14C }
  public
    property Pos: TPos read FPositie write FPositie;
    property Geanimeerd: Boolean read FGeanimeerd write FGeanimeerd;
    property AnimatieFrame: Integer read FAnimatieFrame write FAnimatieFrame;
    property AnimatieNaam: string read FAnimatieNaam write FAnimatieNaam;
  end;

  { VMT 00473110, instantiegrootte $10. }
  TViewSpriteList = class(TList)
  public
    function Add(Sprite: TViewSprite): TViewSprite;
    function GetItem(Nr: Integer): TViewSprite;
    property Items[Index: Integer]: TViewSprite read GetItem; default;
  end;

  { VMT 0047317C, instantiegrootte $90. }
  TView = class(TPixie)
  private
    FInstellingen: TSettings;            { +0x68 }
    FStatus: TStatus;                { +0x6C }
    FTegel: TSurface;                 { +0x70  de grondlaag van de hele kaart (4048 x 2112) }
    FSchoonTegel: TSurface;            { +0x74  kopie van de lege geteegelde kaart, daarna niet meer gebruikt }
    FSpriteVak: TSpriteBox;          { +0x78 }
    FSprites: TSpriteList;           { +0x7C  sjabloon-sprites, één per objecttype }
    FWereld: TWorld;                  { +0x80 }
    FZichtSprites: TSpriteList;       { +0x84  TViewSprite per gebouw (Data = TPos van de cel) }
    FAutos: TSprite;                 { +0x88  de auto's (TAutoSprite), ingesteld door uAutos }
    FTreinSprite: TViewSprite;       { +0x8C  de trein, altijd bovenop getekend }
    procedure PlaatsSprite(Sprite: TSprite; AX, AY: Integer);
    procedure Redraw;
    procedure SchilderCel(AX, AY: Integer);
    procedure VerversSprite(AX, AY: Integer);
  public
    constructor Create(ASprites: TSpriteList; ASpriteBox: TSpriteBox; AWorld: TWorld;
      AOpties: TSettings; AStatus: TStatus);
    destructor Destroy; override;
    function LeesX: Integer; override;                                  { +0x40 }
    function LeesY: Integer; override;                                  { +0x44 }
    function LeesLinks: Integer; override;                               { +0x4C }
    function LeesBoven: Integer; override;                                { +0x54 }
    function GetWidth: Integer; override;                              { +0x5C }
    function GetHeight: Integer; override;                             { +0x60 }
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); override;                                        { +0x64 }
    procedure TekenDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); override;                                        { +0x68 }
    procedure VerwerkWijzigingen;
    function LeesMidden: TPoint;
    procedure ScrollTo(AX, AY: Integer; AZoom: Double);
    property Instellingen: TSettings read FInstellingen;
    property Status: TStatus read FStatus;
    property Tile: TSurface read FTegel;
    property SpriteBox: TSpriteBox read FSpriteVak;
    property Sprites: TSpriteList read FSprites;
    property Wereld: TWorld read FWereld;
    property ZichtSprites: TSpriteList read FZichtSprites;
    property Autos: TSprite read FAutos write FAutos;
    property TreinSprite: TViewSprite read FTreinSprite;
  end;

implementation

uses
  Graphics, Sprframe, Uconst, uString;

const
  { 00488EBC: TCell.Bebouwing-bits, in wijzerzin rond de cel; een reeks
    aangrenzende bits kiest één stoep-frame (Stoep_nnn) }
  StoepBits: array[0..7] of Integer = (1, 32, 2, 64, 4, 128, 8, 16);

{ @0047322C }
constructor TView.Create(ASprites: TSpriteList; ASpriteBox: TSpriteBox; AWorld: TWorld;
  AOpties: TSettings; AStatus: TStatus);
var
  I, J, TW, TH, W, H: Integer;
  Map: string;
begin
  { LET OP: er wordt geen inherited constructor aangeroepen }
  Name := 'ZoetermeerViewer';
  Map := VoegPadToe(VoegPadToe(AppPad, 'images'), '8bits');
  FInstellingen := AOpties;
  FStatus := AStatus;
  FSprites := ASprites;
  FSpriteVak := ASpriteBox;
  FSpriteVak.VoegPixieToe(Self);
  FTreinSprite := TViewSprite.Create(Self);
  FTreinSprite.SpriteBox := FSpriteVak;
  FTreinSprite.FPositie := TPos.Create(-1, 0);
  Visible := True;
  FZichtSprites := TSpriteList.Create;
  FWereld := AWorld;
  W := 4048;
  H := 2112;
  FTegel := NieuwOppervlak;
  FSchoonTegel := NieuwOppervlak;
  FTegel.LoadFromFile(VoegPadToe(Map, 'Tile.bmp'));
  TW := FTegel.Width;
  TH := FTegel.Height;
  FTegel.Width := W;
  FTegel.Height := H;
  for J := 0 to FTegel.Height div TH do
    for I := 0 to FTegel.Width div TW do
      BitBlt(FTegel.Canvas.Handle, I * TW, J * TH, TW, TH, FTegel.Canvas.Handle, 0, 0, SRCCOPY);
  FSchoonTegel.Assign(FTegel);
end;

{ @00473498 }
destructor TView.Destroy;
begin
  FSpriteVak.VerwijderPixie(Self);
  LijstVrijgeven(FZichtSprites);
  FZichtSprites.Free;
  inherited Destroy;
end;

{ @004734E0  Tekent elke cel in FWereld.Wijzigingen opnieuw. }
procedure TView.VerwerkWijzigingen;
var
  X, Y: Integer;
begin
  while FWereld.Wijzigingen.Count <> 0 do
  begin
    FWereld.NeemWijziging(X, Y);
    SchilderCel(X, Y);
    VerversSprite(X, Y);
  end;
  Redraw;
end;

{ @00473530  Knipt de schermrechthoek Doel bij tot het zichtgebied en verkleint de
  wereldrechthoek Bron dienovereenkomstig. }
procedure KnipNaarZicht(var Bron, Doel: TRect);
begin
  if Doel.Left < 30 then
  begin
    Inc(Bron.Left, Round((30 - Doel.Left) / Zoom));
    Doel.Left := 30;
  end;
  if Doel.Top < 81 then
  begin
    Inc(Bron.Top, Round((81 - Doel.Top) / Zoom));
    Doel.Top := 81;
  end;
  if Doel.Right > 822 then
  begin
    Inc(Bron.Right, Round((822 - Doel.Right) / Zoom));
    Doel.Right := 822;
  end;
  if Doel.Bottom > 686 then
  begin
    Inc(Bron.Bottom, Round((686 - Doel.Bottom) / Zoom));
    Doel.Bottom := 686;
  end;
end;

{ @004735EC }
procedure TView.PlaatsSprite(Sprite: TSprite; AX, AY: Integer);
var
  P: TPoint;
begin
  P := RasterNaarWereld(Point(AX, AY));
  Sprite.VerplaatsNaar3D(P.X, P.Y, -P.Y - Sprite.Height + TegelBreedte);
end;

{ @00473638 }
procedure TView.Redraw;
var
  Bron, Doel, R: TRect;
  I: Integer;
  Pos: TPos;
begin
  R := Rect(30, 81, 822, 686);
  FSpriteVak.InvalidateRect(R);
  Exit;
  { LET OP: de rest is dode code in het origineel (blijft staan na de Exit) }
  FWereld.Wijzigingen.Clear;
  Bron := Bounds(0, 0, FTegel.Width, FTegel.Height);
  Doel.TopLeft := WereldNaarScherm(Bron.TopLeft);
  Doel.BottomRight := WereldNaarScherm(Bron.BottomRight);
  KnipNaarZicht(Bron, Doel);
  FSpriteVak.Picture.KopieerVan(FTegel, Bron, Doel, False, False);
  FSpriteVak.InvalidateRect(Doel);
  for I := 0 to FZichtSprites.Count - 1 do
  begin
    Pos := FZichtSprites[I].Data as TPos;
    PlaatsSprite(FZichtSprites[I], Pos.X, Pos.Y);
  end;
end;

{ @0047376C  Wereldpositie van het midden van het zicht (omgekeerd, zoals VerschuivingX/VerschuivingY). }
function TView.LeesMidden: TPoint;
begin
  Result.X := VerschuivingX - Round(396 / Zoom);      { 396 = (822 - 30) / 2 }
  Result.Y := VerschuivingY - Round(302.5 / Zoom);    { 302.5 = (686 - 81) / 2 }
end;

{ @004737B8  Centreert het zicht op (-AX, -AY) bij de gegeven zoom, binnen de kaart gehouden. }
procedure TView.ScrollTo(AX, AY: Integer; AZoom: Double);
begin
  AZoom := FMax(AZoom, 0.32);
  AZoom := FMin(AZoom, 1);
  AX := AX + Round(396 / AZoom);
  AY := AY + Round(302.5 / AZoom);
  AX := IMinimum(AX, Round(30 / AZoom));
  AY := IMinimum(AY, Round(81 / AZoom));
  AX := IMaximum(AX, -Round(FTegel.Width - 822 / AZoom));
  AY := IMaximum(AY, -Round(FTegel.Height - 686 / AZoom));
  VerschuivingX := AX;
  VerschuivingY := AY;
  Zoom := AZoom;
  Redraw;
end;

{ @004738E4  Framenaam van het stoepstuk voor een reeks Bebouwing-bits. }
function StoepFrame(Masker: Integer): string;
begin
  if Masker and 8 <> 0 then
    Masker := Masker or $98;
  if Masker and 1 <> 0 then
    Masker := Masker or $31;
  if Masker and 2 <> 0 then
    Masker := Masker or $62;
  if Masker and 4 <> 0 then
    Masker := Masker or $C4;
  Result := 'Stoep_' + NulVul(IntTekst(Masker), 3);
end;

{ @00473988  Schildert het grondbeeld van een cel (en de stoepen) op FTegel. }
procedure TView.SchilderCel(AX, AY: Integer);
var
  Cell: TCell;
  P: TPoint;
  Info: TInhoudInfo;
  SpriteName, FrameNaam: string;
  Sprite, StoepSprite: TSprite;
  Frame: TFrame;
  Nr, X1, Y1, Masker, N, Vanaf, I, Bits: Integer;
  R, R2: TRect;
begin
  Cell := FWereld.LeesCel(AX, AY);
  if (Cell <> nil) and (Cell.Inhoud <> 'AndereStad') then
  begin
    P := RasterNaarWereld(Point(AX, AY));
    Info := InhoudInfoOpNaam(Cell.Inhoud);
    if (Info.IsGrond <> 0) or (Info.Name = 'Hoofdstation') then
    begin
      SpriteName := Info.Name;
      FrameNaam := SpriteName;
      if (SpriteName <> '') and ((Cell.Hoofd = nil) or (Info.Name = 'Sloop')) then
      begin
        if IsSnelweg(Cell.Inhoud, 'X') then
        begin
          if Cell.Param = '00' then
            FrameNaam := FrameNaam + '_05'
          else
          begin
            Nr := StrNaarIntDef0(Cell.Param);
            if Nr in [1, 2, 4, 8] then
              Nr := ((Nr shl 2) or Nr or (Nr shr 2)) and $F;
            if Nr in [3, 6, 9, 12] then
              FrameNaam := InhoudInfoOpNaam('Snel').Name;
            FrameNaam := FrameNaam + '_' + NulVul(IntTekst(Nr), 2);
          end;
        end
        else if IsWeg(Cell.Inhoud, 'X') then
          FrameNaam := FrameNaam + '_' + NulVul(IntTekst(Cell.Wegen), 2)
        else if Cell.Inhoud = 'Hoofdstation' then
          FrameNaam := FrameNaam + '_grondvlak'
        else if Cell.Inhoud = 'Station' then
          FrameNaam := FrameNaam + '_' + Cell.Param + '_grondvlak'
        else if (Cell.Param <> '') and (Cell.Inhoud <> 'Klaver') then
          FrameNaam := FrameNaam + '_' + Cell.Param;

        Sprite := FSprites.SpriteOpNaam(SpriteName);
        if Sprite = nil then
          Fout('Sprite niet gevonden: ' + SpriteName);
        if Sprite.FrameList.IndexOf(FrameNaam) = -1 then
          Fout('PaintCell: could not find frame ' + FrameNaam + ' in sprite ' + SpriteName);
        Frame := Sprite.FrameList.FrameOpNaam(FrameNaam);
        X1 := P.X - Frame.HotSpotX;
        Y1 := P.Y - Frame.HotSpotY;
        R := Bounds(X1, Y1, Frame.Width, Frame.Height);
        Frame.Draw(FTegel, R, False, False, True);

        Masker := Cell.Bebouwing;
        if Masker <> 0 then
          for N := 8 downto 1 do
            for Vanaf := 0 to 7 do
            begin
              Bits := 0;
              for I := 1 to N do
                Bits := Bits or StoepBits[(Vanaf + I) and 7];
              if Masker and Bits = Bits then
              begin
                { LET OP: loopt één voorbij de laatste pixie }
                for I := 0 to FSpriteVak.PixieAantal do
                  if FSpriteVak.LeesPixie(I).Name = 'spriteStoep' then
                  begin
                    StoepSprite := TSprite(FSpriteVak.LeesPixie(I));
                    Break;
                  end;
                if StoepSprite.FrameList.IndexOf(StoepFrame(Bits)) = -1 then
                  Fout('PaintCell: could not find frame ' + StoepFrame(Bits) + ' in spriteStoep');
                Frame := StoepSprite.FrameList.FrameOpNaam(StoepFrame(Bits));
                R := Bounds(X1, Y1, Frame.Width, Frame.Height);
                Frame.Draw(FTegel, R, False, False, True);
                Masker := Masker xor Bits;
              end;
            end;

        R2 := R;
        R.TopLeft := WereldNaarScherm(R2.TopLeft);
        R.BottomRight := WereldNaarScherm(R2.BottomRight);
        KnipNaarZicht(R2, R);
        FSpriteVak.InvalidateRect(R);
      end;
    end;
  end;
end;

{ @004740A8 }
procedure TView.TekenDC(DC: HDC; DX, DY: Integer; ClipRect: TRect; Schaalfactor: Double);
begin
end;

{ @00474420  Tekent het zichtbare deel van de kaart, de auto's en de gebouwen. }
procedure TView.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Schaalfactor: Double);
var
  Lijst: TViewSpriteList;
  P: TPoint;
  DC: HDC;
  Rgn: HRGN;
  Pos: TPos;
  Laatste: TViewSprite;
  Gevonden: Boolean;
  I, J: Integer;
  R, Bron: TRect;

  { @004740C8  Tekent Sprite na (recursief) elke sprite die erachter ligt. }
  procedure DrawSprite(Sprite: TViewSprite; X1, Y1, X2, Y2: Integer);
  var
    MijnX, MijnY, I, N: Integer;
  begin
    { LET OP: de parameters worden alleen getest, nooit gebruikt }
    if (X1 <> 0) or (Y1 <> 0) then
      ;
    MijnX := (Sprite.Data as TPos).X;
    MijnY := (Sprite.Data as TPos).Y;
    I := -1;
    N := Lijst.Count;
    while I < Lijst.Count - 1 do
    begin
      Inc(I);
      if (Lijst[I] <> Sprite) and (Lijst[I].FPositie.X <= MijnX) and (Lijst[I].FPositie.Y <= MijnY) then
      begin
        DrawSprite(Lijst[I], Lijst[I].FPositie.X, Lijst[I].FPositie.Y,
          (Lijst[I].Data as TPos).X, (Lijst[I].Data as TPos).Y);
        I := IMaximum(0, I - N + Lijst.Count);
      end;
    end;
    P := WereldNaarScherm(Point(Sprite.Left, Sprite.Top));
    Inc(ProfBeeld, GetTickCount);
    Dec(ProfSprites, GetTickCount);
    if Sprite.FGeanimeerd then
    begin
      Inc(Sprite.FAnimatieFrame);
      if Sprite.FrameList.IndexOf(Sprite.FAnimatieNaam + '_' + LongNaarStr(Sprite.FAnimatieFrame)) = -1 then
        Sprite.FAnimatieFrame := 0;
      Sprite.FrameIndex :=
        Sprite.FrameList.IndexOf(Sprite.FAnimatieNaam + '_' + LongNaarStr(Sprite.FAnimatieFrame));
    end;
    Sprite.TekenDC(DC, P.X + DX - 30, P.Y + DY - 81, Bounds(0, 0, 1, 1), Zoom);
    Inc(ProfSprites, GetTickCount);
    Dec(ProfBeeld, GetTickCount);
    Lijst.Remove(Sprite);
  end;

begin
  if ProfStart = 0 then
    ProfStart := GetTickCount;
  Dec(ProfBeeld, GetTickCount);
  R := ClipRect;
  OffsetRect(R, 30 - DX, 81 - DY);
  IntersectRect(R, R, Rect(30, 81, 822, 686));
  Bron.TopLeft := SchermNaarWereld(R.TopLeft);
  Bron.BottomRight := SchermNaarWereld(R.BottomRight);
  ClipRect := R;
  OffsetRect(ClipRect, DX - 30, DY - 81);
  FTegel.KopieerNaar(Surface, Bron, ClipRect, False, False);
  P := WereldNaarScherm(Point(FAutos.Left, FAutos.Top));
  FAutos.Draw(Surface, DX, DY, ClipRect, 1);
  DC := Surface.Canvas.Handle;
  Rgn := CreateRectRgn(ClipRect.Left, ClipRect.Top, ClipRect.Right, ClipRect.Bottom);
  SelectClipRgn(DC, Rgn);
  Lijst := TViewSpriteList.Create;
  Laatste := nil;
  if ((GetTickCount div 500) mod 2 = 0) and (FWereld.Reistijd < 0) then
  begin
    { knipperen: verberg de gebouwen en stations die niet bereikbaar zijn }
    for I := 0 to FSpriteVak.PixieAantal - 1 do
      if FSpriteVak.LeesPixie(I) is TViewSprite then
      begin
        if (FSpriteVak.LeesPixie(I) as TViewSprite).FPositie.X <> -1 then
        begin
          Pos := (FSpriteVak.LeesPixie(I) as TSprite).Data as TPos;
          Gevonden := False;
          for J := 0 to FWereld.Bestemmingen.Count - 1 do
            if (FWereld.Bestemmingen[J].X = Pos.X) and (FWereld.Bestemmingen[J].Y = Pos.Y) then
            begin
              Gevonden := True;
              if FWereld.Bestemmingen[J].Bereikbaar then
                Lijst.Add(FSpriteVak.LeesPixie(I) as TViewSprite);
            end;
          for J := 0 to FWereld.Bebouwing.Count - 1 do
            if (FWereld.Bebouwing[J].X = Pos.X) and (FWereld.Bebouwing[J].Y = Pos.Y) then
            begin
              Gevonden := True;
              if FWereld.Bebouwing[J].Bereikbaar then
                Lijst.Add(FSpriteVak.LeesPixie(I) as TViewSprite);
            end;
          if not Gevonden then
            Lijst.Add(FSpriteVak.LeesPixie(I) as TViewSprite);
        end
        else
          Laatste := FSpriteVak.LeesPixie(I) as TViewSprite;
      end;
  end
  else
  begin
    for I := 0 to FSpriteVak.PixieAantal - 1 do
      if FSpriteVak.LeesPixie(I) is TViewSprite then
      begin
        if (FSpriteVak.LeesPixie(I) as TViewSprite).FPositie.X <> -1 then
          Lijst.Add(FSpriteVak.LeesPixie(I) as TViewSprite)
        else
          Laatste := FSpriteVak.LeesPixie(I) as TViewSprite;
      end;
  end;
  if Laatste <> nil then
  begin
    P := WereldNaarScherm(Point(Laatste.Left, Laatste.Top));
    Laatste.TekenDC(DC, P.X + DX - 30, P.Y + DY - 81, Bounds(0, 0, 1, 1), Zoom);
  end;
  while Lijst.Count <> 0 do
    DrawSprite(Lijst[0], Lijst[0].FPositie.X, Lijst[0].FPositie.Y,
      (Lijst[0].Data as TPos).X, (Lijst[0].Data as TPos).Y);
  Lijst.Free;
  SelectClipRgn(Surface.Canvas.Handle, 0);
  DeleteObject(Rgn);
  Inc(ProfBeeld, GetTickCount);
end;

{ @004749BC }
function TView.GetHeight: Integer;
begin
  Result := 605;
end;

{ @004749C4 }
function TView.GetWidth: Integer;
begin
  Result := 792;
end;

{ @004749CC }
function TView.LeesX: Integer;
begin
  Result := 30;
end;

{ @004749D4 }
function TView.LeesY: Integer;
begin
  Result := 81;
end;

{ @004749DC  Maakt de gebouwsprite van een cel opnieuw aan. }
procedure TView.VerversSprite(AX, AY: Integer);
var
  Cell: TCell;
  Info: TInhoudInfo;
  SpriteName, FrameNaam: string;
  Sprite: TSprite;
  Pos: TPos;
  I: Integer;
begin
  Cell := FWereld.LeesCel(AX, AY);
  if (Cell <> nil) and (Cell.Hoofd = nil) then
  begin
    for I := 0 to FZichtSprites.Count - 1 do
    begin
      Pos := FZichtSprites[I].Data as TPos;
      if (Pos <> nil) and (Pos.X = AX) and (Pos.Y = AY) then
      begin
        FZichtSprites[I].Verwijder;
        FZichtSprites.Delete(I);
        Break;
      end;
    end;
    Info := InhoudInfoOpNaam(Cell.Inhoud);
    if (Info.IsGrond <> 1) or (Info.Name = 'Hoofdstation') or (Info.Name = 'Station') then
    begin
      SpriteName := Info.Name;
      if SpriteName = '' then
        Fout('UpdateSprite: FrameName is empty');
      Sprite := FSprites.SpriteOpNaam(SpriteName);
      if Sprite = nil then
        Fout('UpdateSprite: Sprite niet gevonden: ' + SpriteName)
      else
      begin
        if Cell.Inhoud = 'Hoofdstation' then
          FrameNaam := SpriteName + '_kap'
        else if Cell.Inhoud = 'Station' then
          FrameNaam := SpriteName + '_' + Cell.Param + '_kap'
        else if Cell.Param <> '' then
          FrameNaam := SpriteName + '_' + Cell.Param
        else
          FrameNaam := SpriteName;
        Sprite := TViewSprite.MaakKopie(Sprite);
        if (Cell.Inhoud = 'Molen') or (Cell.Inhoud = 'Siemens2') then
        begin
          (Sprite as TViewSprite).FGeanimeerd := True;
          (Sprite as TViewSprite).FAnimatieFrame := 0;
          (Sprite as TViewSprite).FAnimatieNaam := FrameNaam;
          FrameNaam := FrameNaam + '_0';
        end;
        if Sprite.FrameList.IndexOf(FrameNaam) = -1 then
          Fout('PaintCell: could not find frame ' + FrameNaam + ' in sprite ' + SpriteName);
        Sprite.CurrentFrame := FrameNaam;
        PlaatsSprite(Sprite, AX, AY);
        Sprite.Data := TPos.Create(AX, AY);
        (Sprite as TViewSprite).FPositie := TPos.Create(AX - Info.GrondvlakX + 1,
          AY - Info.GrondvlakY + 1);
        FZichtSprites.Add(Sprite);
        Sprite.Visible := False;
      end;
    end;
  end;
end;

{ @00474E78 }
function TView.LeesLinks: Integer;
begin
  Result := LeesX;
end;

{ @00474E80 }
function TView.LeesBoven: Integer;
begin
  Result := LeesY;
end;

{ @00474E88 }
function TViewSpriteList.Add(Sprite: TViewSprite): TViewSprite;
begin
  inherited Add(Sprite);
  Result := Sprite;
end;

{ @00474E98 }
function TViewSpriteList.GetItem(Nr: Integer): TViewSprite;
begin
  Result := TObject(Get(Nr)) as TViewSprite;
end;

end.

unit Uview;

{ TView: de pixie die de stad tekent. De grondlaag (wegen, sporen, gras,
  stoepen) wordt per gewijzigde cel op een groot oppervlak ter grootte van de wereld geschilderd
  (FTile, opgebouwd uit images\8bits\Tile.bmp); gebouwen en stations zijn
  TViewSprite-kopieën van de sjabloon-sprites, van achter naar voren getekend door Draw.
  Bevat ook de scroll/zoom-status (Uconst.ScrollX/ScrollY/Zoom).
  Gedecompileerd uit ROS.exe v1.1, code 00472F7C-00474EEF. }

{$I zm.inc}

interface

uses
  Windows, Classes, uSurface, uPixie, uSprite, uSpritebox, uTool, Usett, Uworld;

type
  { VMT 00472FC8, instantiegrootte $150. Een gebouw- of stationssprite op de kaart. }
  TViewSprite = class(TSprite)
  private
    FReserved13C: Integer;           { +0x13C  niet gebruikt }
    FPos: TPos;                      { +0x140  linkerbovencel van het grondvlak; X = -1: de trein }
    FAnimated: Boolean;              { +0x144  frames <FAnimName>_0, _1, ... worden doorlopen (Molen, Siemens2) }
    FAnimFrame: Integer;             { +0x148 }
    FAnimName: string;               { +0x14C }
  public
    property Pos: TPos read FPos write FPos;
    property Animated: Boolean read FAnimated write FAnimated;
    property AnimFrame: Integer read FAnimFrame write FAnimFrame;
    property AnimName: string read FAnimName write FAnimName;
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
    FSettings: TSettings;            { +0x68 }
    FStatus: TStatus;                { +0x6C }
    FTile: TSurface;                 { +0x70  de grondlaag van de hele kaart (4048 x 2112) }
    FCleanTile: TSurface;            { +0x74  kopie van de lege geteegelde kaart, daarna niet meer gebruikt }
    FSpriteBox: TSpriteBox;          { +0x78 }
    FSprites: TSpriteList;           { +0x7C  sjabloon-sprites, één per objecttype }
    FWorld: TWorld;                  { +0x80 }
    FViewSprites: TSpriteList;       { +0x84  TViewSprite per gebouw (Data = TPos van de cel) }
    FAutos: TSprite;                 { +0x88  de auto's (TAutoSprite), ingesteld door uAutos }
    FTreinSprite: TViewSprite;       { +0x8C  de trein, altijd bovenop getekend }
    procedure PlaceSprite(Sprite: TSprite; AX, AY: Integer);
    procedure Redraw;
    procedure PaintCell(AX, AY: Integer);
    procedure UpdateSprite(AX, AY: Integer);
  public
    constructor Create(ASprites: TSpriteList; ASpriteBox: TSpriteBox; AWorld: TWorld;
      ASettings: TSettings; AStatus: TStatus);
    destructor Destroy; override;
    function GetX: Integer; override;                                  { +0x40 }
    function GetY: Integer; override;                                  { +0x44 }
    function GetLeft: Integer; override;                               { +0x4C }
    function GetTop: Integer; override;                                { +0x54 }
    function GetWidth: Integer; override;                              { +0x5C }
    function GetHeight: Integer; override;                             { +0x60 }
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;                                        { +0x64 }
    procedure DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;                                        { +0x68 }
    procedure ProcessChanges;
    function GetCenter: TPoint;
    procedure ScrollTo(AX, AY: Integer; AZoom: Double);
    property Settings: TSettings read FSettings;
    property Status: TStatus read FStatus;
    property Tile: TSurface read FTile;
    property SpriteBox: TSpriteBox read FSpriteBox;
    property Sprites: TSpriteList read FSprites;
    property World: TWorld read FWorld;
    property ViewSprites: TSpriteList read FViewSprites;
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
  ASettings: TSettings; AStatus: TStatus);
var
  I, J, TW, TH, W, H: Integer;
  Map: string;
begin
  { LET OP: er wordt geen inherited constructor aangeroepen }
  Name := 'ZoetermeerViewer';
  Map := AddPath(AddPath(AppPath, 'images'), '8bits');
  FSettings := ASettings;
  FStatus := AStatus;
  FSprites := ASprites;
  FSpriteBox := ASpriteBox;
  FSpriteBox.AddPixie(Self);
  FTreinSprite := TViewSprite.Create(Self);
  FTreinSprite.SpriteBox := FSpriteBox;
  FTreinSprite.FPos := TPos.Create(-1, 0);
  Visible := True;
  FViewSprites := TSpriteList.Create;
  FWorld := AWorld;
  W := 4048;
  H := 2112;
  FTile := NewSurface;
  FCleanTile := NewSurface;
  FTile.LoadFromFile(AddPath(Map, 'Tile.bmp'));
  TW := FTile.Width;
  TH := FTile.Height;
  FTile.Width := W;
  FTile.Height := H;
  for J := 0 to FTile.Height div TH do
    for I := 0 to FTile.Width div TW do
      BitBlt(FTile.Canvas.Handle, I * TW, J * TH, TW, TH, FTile.Canvas.Handle, 0, 0, SRCCOPY);
  FCleanTile.Assign(FTile);
end;

{ @00473498 }
destructor TView.Destroy;
begin
  FSpriteBox.RemovePixie(Self);
  FreeList(FViewSprites);
  FViewSprites.Free;
  inherited Destroy;
end;

{ @004734E0  Tekent elke cel in FWorld.Changes opnieuw. }
procedure TView.ProcessChanges;
var
  X, Y: Integer;
begin
  while FWorld.Changes.Count <> 0 do
  begin
    FWorld.PopChanged(X, Y);
    PaintCell(X, Y);
    UpdateSprite(X, Y);
  end;
  Redraw;
end;

{ @00473530  Knipt de schermrechthoek Doel bij tot het zichtgebied en verkleint de
  wereldrechthoek Bron dienovereenkomstig. }
procedure ClipToView(var Bron, Doel: TRect);
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
procedure TView.PlaceSprite(Sprite: TSprite; AX, AY: Integer);
var
  P: TPoint;
begin
  P := GridToWorld(Point(AX, AY));
  Sprite.MoveTo3D(P.X, P.Y, -P.Y - Sprite.Height + TileW);
end;

{ @00473638 }
procedure TView.Redraw;
var
  Bron, Doel, R: TRect;
  I: Integer;
  Pos: TPos;
begin
  R := Rect(30, 81, 822, 686);
  FSpriteBox.InvalidateRect(R);
  Exit;
  { LET OP: de rest is dode code in het origineel (blijft staan na de Exit) }
  FWorld.Changes.Clear;
  Bron := Bounds(0, 0, FTile.Width, FTile.Height);
  Doel.TopLeft := WorldToScreen(Bron.TopLeft);
  Doel.BottomRight := WorldToScreen(Bron.BottomRight);
  ClipToView(Bron, Doel);
  FSpriteBox.Picture.CopyFrom(FTile, Bron, Doel, False, False);
  FSpriteBox.InvalidateRect(Doel);
  for I := 0 to FViewSprites.Count - 1 do
  begin
    Pos := FViewSprites[I].Data as TPos;
    PlaceSprite(FViewSprites[I], Pos.X, Pos.Y);
  end;
end;

{ @0047376C  Wereldpositie van het midden van het zicht (omgekeerd, zoals ScrollX/ScrollY). }
function TView.GetCenter: TPoint;
begin
  Result.X := ScrollX - Round(396 / Zoom);      { 396 = (822 - 30) / 2 }
  Result.Y := ScrollY - Round(302.5 / Zoom);    { 302.5 = (686 - 81) / 2 }
end;

{ @004737B8  Centreert het zicht op (-AX, -AY) bij de gegeven zoom, binnen de kaart gehouden. }
procedure TView.ScrollTo(AX, AY: Integer; AZoom: Double);
begin
  AZoom := FMax(AZoom, 0.32);
  AZoom := FMin(AZoom, 1);
  AX := AX + Round(396 / AZoom);
  AY := AY + Round(302.5 / AZoom);
  AX := IMin(AX, Round(30 / AZoom));
  AY := IMin(AY, Round(81 / AZoom));
  AX := IMax(AX, -Round(FTile.Width - 822 / AZoom));
  AY := IMax(AY, -Round(FTile.Height - 686 / AZoom));
  ScrollX := AX;
  ScrollY := AY;
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
  Result := 'Stoep_' + ZeroPad(IntStr(Masker), 3);
end;

{ @00473988  Schildert het grondbeeld van een cel (en de stoepen) op FTile. }
procedure TView.PaintCell(AX, AY: Integer);
var
  Cell: TCell;
  P: TPoint;
  Info: TContentsInfo;
  SpriteName, FrameName: string;
  Sprite, StoepSprite: TSprite;
  Frame: TFrame;
  Nr, X1, Y1, Masker, N, Vanaf, I, Bits: Integer;
  R, R2: TRect;
begin
  Cell := FWorld.GetCell(AX, AY);
  if (Cell <> nil) and (Cell.Contents <> 'AndereStad') then
  begin
    P := GridToWorld(Point(AX, AY));
    Info := ContentsInfoByContents(Cell.Contents);
    if (Info.IsGround <> 0) or (Info.Name = 'Hoofdstation') then
    begin
      SpriteName := Info.Name;
      FrameName := SpriteName;
      if (SpriteName <> '') and ((Cell.Hoofd = nil) or (Info.Name = 'Sloop')) then
      begin
        if IsSnelweg(Cell.Contents, 'X') then
        begin
          if Cell.Param = '00' then
            FrameName := FrameName + '_05'
          else
          begin
            Nr := StrToIntDef0(Cell.Param);
            if Nr in [1, 2, 4, 8] then
              Nr := ((Nr shl 2) or Nr or (Nr shr 2)) and $F;
            if Nr in [3, 6, 9, 12] then
              FrameName := ContentsInfoByContents('Snel').Name;
            FrameName := FrameName + '_' + ZeroPad(IntStr(Nr), 2);
          end;
        end
        else if IsWeg(Cell.Contents, 'X') then
          FrameName := FrameName + '_' + ZeroPad(IntStr(Cell.Wegen), 2)
        else if Cell.Contents = 'Hoofdstation' then
          FrameName := FrameName + '_grondvlak'
        else if Cell.Contents = 'Station' then
          FrameName := FrameName + '_' + Cell.Param + '_grondvlak'
        else if (Cell.Param <> '') and (Cell.Contents <> 'Klaver') then
          FrameName := FrameName + '_' + Cell.Param;

        Sprite := FSprites.SpriteByName(SpriteName);
        if Sprite = nil then
          Fout('Sprite niet gevonden: ' + SpriteName);
        if Sprite.FrameList.IndexOf(FrameName) = -1 then
          Fout('PaintCell: could not find frame ' + FrameName + ' in sprite ' + SpriteName);
        Frame := Sprite.FrameList.FrameByName(FrameName);
        X1 := P.X - Frame.HotSpotX;
        Y1 := P.Y - Frame.HotSpotY;
        R := Bounds(X1, Y1, Frame.Width, Frame.Height);
        Frame.Draw(FTile, R, False, False, True);

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
                for I := 0 to FSpriteBox.PixieCount do
                  if FSpriteBox.GetPixie(I).Name = 'spriteStoep' then
                  begin
                    StoepSprite := TSprite(FSpriteBox.GetPixie(I));
                    Break;
                  end;
                if StoepSprite.FrameList.IndexOf(StoepFrame(Bits)) = -1 then
                  Fout('PaintCell: could not find frame ' + StoepFrame(Bits) + ' in spriteStoep');
                Frame := StoepSprite.FrameList.FrameByName(StoepFrame(Bits));
                R := Bounds(X1, Y1, Frame.Width, Frame.Height);
                Frame.Draw(FTile, R, False, False, True);
                Masker := Masker xor Bits;
              end;
            end;

        R2 := R;
        R.TopLeft := WorldToScreen(R2.TopLeft);
        R.BottomRight := WorldToScreen(R2.BottomRight);
        ClipToView(R2, R);
        FSpriteBox.InvalidateRect(R);
      end;
    end;
  end;
end;

{ @004740A8 }
procedure TView.DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect; Scale: Double);
begin
end;

{ @00474420  Tekent het zichtbare deel van de kaart, de auto's en de gebouwen. }
procedure TView.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Scale: Double);
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
      if (Lijst[I] <> Sprite) and (Lijst[I].FPos.X <= MijnX) and (Lijst[I].FPos.Y <= MijnY) then
      begin
        DrawSprite(Lijst[I], Lijst[I].FPos.X, Lijst[I].FPos.Y,
          (Lijst[I].Data as TPos).X, (Lijst[I].Data as TPos).Y);
        I := IMax(0, I - N + Lijst.Count);
      end;
    end;
    P := WorldToScreen(Point(Sprite.Left, Sprite.Top));
    Inc(PerfView, GetTickCount);
    Dec(PerfSprites, GetTickCount);
    if Sprite.FAnimated then
    begin
      Inc(Sprite.FAnimFrame);
      if Sprite.FrameList.IndexOf(Sprite.FAnimName + '_' + LongToStr(Sprite.FAnimFrame)) = -1 then
        Sprite.FAnimFrame := 0;
      Sprite.FrameIndex :=
        Sprite.FrameList.IndexOf(Sprite.FAnimName + '_' + LongToStr(Sprite.FAnimFrame));
    end;
    Sprite.DrawDC(DC, P.X + DX - 30, P.Y + DY - 81, Bounds(0, 0, 1, 1), Zoom);
    Inc(PerfSprites, GetTickCount);
    Dec(PerfView, GetTickCount);
    Lijst.Remove(Sprite);
  end;

begin
  if PerfStart = 0 then
    PerfStart := GetTickCount;
  Dec(PerfView, GetTickCount);
  R := ClipRect;
  OffsetRect(R, 30 - DX, 81 - DY);
  IntersectRect(R, R, Rect(30, 81, 822, 686));
  Bron.TopLeft := ScreenToWorld(R.TopLeft);
  Bron.BottomRight := ScreenToWorld(R.BottomRight);
  ClipRect := R;
  OffsetRect(ClipRect, DX - 30, DY - 81);
  FTile.CopyTo(Surface, Bron, ClipRect, False, False);
  P := WorldToScreen(Point(FAutos.Left, FAutos.Top));
  FAutos.Draw(Surface, DX, DY, ClipRect, 1);
  DC := Surface.Canvas.Handle;
  Rgn := CreateRectRgn(ClipRect.Left, ClipRect.Top, ClipRect.Right, ClipRect.Bottom);
  SelectClipRgn(DC, Rgn);
  Lijst := TViewSpriteList.Create;
  Laatste := nil;
  if ((GetTickCount div 500) mod 2 = 0) and (FWorld.Reistijd < 0) then
  begin
    { knipperen: verberg de gebouwen en stations die niet bereikbaar zijn }
    for I := 0 to FSpriteBox.PixieCount - 1 do
      if FSpriteBox.GetPixie(I) is TViewSprite then
      begin
        if (FSpriteBox.GetPixie(I) as TViewSprite).FPos.X <> -1 then
        begin
          Pos := (FSpriteBox.GetPixie(I) as TSprite).Data as TPos;
          Gevonden := False;
          for J := 0 to FWorld.Bestemmingen.Count - 1 do
            if (FWorld.Bestemmingen[J].X = Pos.X) and (FWorld.Bestemmingen[J].Y = Pos.Y) then
            begin
              Gevonden := True;
              if FWorld.Bestemmingen[J].Bereikbaar then
                Lijst.Add(FSpriteBox.GetPixie(I) as TViewSprite);
            end;
          for J := 0 to FWorld.Bebouwing.Count - 1 do
            if (FWorld.Bebouwing[J].X = Pos.X) and (FWorld.Bebouwing[J].Y = Pos.Y) then
            begin
              Gevonden := True;
              if FWorld.Bebouwing[J].Bereikbaar then
                Lijst.Add(FSpriteBox.GetPixie(I) as TViewSprite);
            end;
          if not Gevonden then
            Lijst.Add(FSpriteBox.GetPixie(I) as TViewSprite);
        end
        else
          Laatste := FSpriteBox.GetPixie(I) as TViewSprite;
      end;
  end
  else
  begin
    for I := 0 to FSpriteBox.PixieCount - 1 do
      if FSpriteBox.GetPixie(I) is TViewSprite then
      begin
        if (FSpriteBox.GetPixie(I) as TViewSprite).FPos.X <> -1 then
          Lijst.Add(FSpriteBox.GetPixie(I) as TViewSprite)
        else
          Laatste := FSpriteBox.GetPixie(I) as TViewSprite;
      end;
  end;
  if Laatste <> nil then
  begin
    P := WorldToScreen(Point(Laatste.Left, Laatste.Top));
    Laatste.DrawDC(DC, P.X + DX - 30, P.Y + DY - 81, Bounds(0, 0, 1, 1), Zoom);
  end;
  while Lijst.Count <> 0 do
    DrawSprite(Lijst[0], Lijst[0].FPos.X, Lijst[0].FPos.Y,
      (Lijst[0].Data as TPos).X, (Lijst[0].Data as TPos).Y);
  Lijst.Free;
  SelectClipRgn(Surface.Canvas.Handle, 0);
  DeleteObject(Rgn);
  Inc(PerfView, GetTickCount);
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
function TView.GetX: Integer;
begin
  Result := 30;
end;

{ @004749D4 }
function TView.GetY: Integer;
begin
  Result := 81;
end;

{ @004749DC  Maakt de gebouwsprite van een cel opnieuw aan. }
procedure TView.UpdateSprite(AX, AY: Integer);
var
  Cell: TCell;
  Info: TContentsInfo;
  SpriteName, FrameName: string;
  Sprite: TSprite;
  Pos: TPos;
  I: Integer;
begin
  Cell := FWorld.GetCell(AX, AY);
  if (Cell <> nil) and (Cell.Hoofd = nil) then
  begin
    for I := 0 to FViewSprites.Count - 1 do
    begin
      Pos := FViewSprites[I].Data as TPos;
      if (Pos <> nil) and (Pos.X = AX) and (Pos.Y = AY) then
      begin
        FViewSprites[I].Kill;
        FViewSprites.Delete(I);
        Break;
      end;
    end;
    Info := ContentsInfoByContents(Cell.Contents);
    if (Info.IsGround <> 1) or (Info.Name = 'Hoofdstation') or (Info.Name = 'Station') then
    begin
      SpriteName := Info.Name;
      if SpriteName = '' then
        Fout('UpdateSprite: FrameName is empty');
      Sprite := FSprites.SpriteByName(SpriteName);
      if Sprite = nil then
        Fout('UpdateSprite: Sprite niet gevonden: ' + SpriteName)
      else
      begin
        if Cell.Contents = 'Hoofdstation' then
          FrameName := SpriteName + '_kap'
        else if Cell.Contents = 'Station' then
          FrameName := SpriteName + '_' + Cell.Param + '_kap'
        else if Cell.Param <> '' then
          FrameName := SpriteName + '_' + Cell.Param
        else
          FrameName := SpriteName;
        Sprite := TViewSprite.CreateCopy(Sprite);
        if (Cell.Contents = 'Molen') or (Cell.Contents = 'Siemens2') then
        begin
          (Sprite as TViewSprite).FAnimated := True;
          (Sprite as TViewSprite).FAnimFrame := 0;
          (Sprite as TViewSprite).FAnimName := FrameName;
          FrameName := FrameName + '_0';
        end;
        if Sprite.FrameList.IndexOf(FrameName) = -1 then
          Fout('PaintCell: could not find frame ' + FrameName + ' in sprite ' + SpriteName);
        Sprite.CurrentFrame := FrameName;
        PlaceSprite(Sprite, AX, AY);
        Sprite.Data := TPos.Create(AX, AY);
        (Sprite as TViewSprite).FPos := TPos.Create(AX - Info.GrondvlakX + 1,
          AY - Info.GrondvlakY + 1);
        FViewSprites.Add(Sprite);
        Sprite.Visible := False;
      end;
    end;
  end;
end;

{ @00474E78 }
function TView.GetLeft: Integer;
begin
  Result := GetX;
end;

{ @00474E80 }
function TView.GetTop: Integer;
begin
  Result := GetY;
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

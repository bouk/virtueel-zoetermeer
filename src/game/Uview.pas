unit Uview;

{ TView: the pixie that draws the city. The ground layer (roads, rails, grass,
  pavements) is painted once per changed cell onto a big world-sized surface
  (FTile, built from images\8bits\Tile.bmp); buildings and stations are
  TViewSprite copies of the template sprites, drawn back to front by Draw.
  Also holds the scroll/zoom state (Uconst.ScrollX/ScrollY/Zoom).
  Decompiled from ROS.exe v1.1, code 00472F7C-00474EEF. }

{$I zm.inc}

interface

uses
  Windows, Classes, uSurface, uPixie, uSprite, uSpritebox, uTool, Usett, Uworld;

type
  { VMT 00472FC8, instance size $150. A building/station sprite on the map. }
  TViewSprite = class(TSprite)
  private
    FReserved13C: Integer;           { +0x13C  not used }
    FPos: TPos;                      { +0x140  top-left cell of the ground plane; X = -1: the train }
    FAnimated: Boolean;              { +0x144  frames <FAnimName>_0, _1, ... are cycled (Molen, Siemens2) }
    FAnimFrame: Integer;             { +0x148 }
    FAnimName: string;               { +0x14C }
  public
    property Pos: TPos read FPos write FPos;
    property Animated: Boolean read FAnimated write FAnimated;
    property AnimFrame: Integer read FAnimFrame write FAnimFrame;
    property AnimName: string read FAnimName write FAnimName;
  end;

  { VMT 00473110, instance size $10. }
  TViewSpriteList = class(TList)
  public
    function Add(Sprite: TViewSprite): TViewSprite;
    function GetItem(Index: Integer): TViewSprite;
    property Items[Index: Integer]: TViewSprite read GetItem; default;
  end;

  { VMT 0047317C, instance size $90. }
  TView = class(TPixie)
  private
    FSettings: TSettings;            { +0x68 }
    FStatus: TStatus;                { +0x6C }
    FTile: TSurface;                 { +0x70  the ground layer of the whole map (4048 x 2112) }
    FCleanTile: TSurface;            { +0x74  copy of the empty tiled map, not used afterwards }
    FSpriteBox: TSpriteBox;          { +0x78 }
    FSprites: TSpriteList;           { +0x7C  template sprites, one per object type }
    FWorld: TWorld;                  { +0x80 }
    FViewSprites: TSpriteList;       { +0x84  TViewSprite per building (Data = TPos of its cell) }
    FAutos: TSprite;                 { +0x88  the cars (TAutoSprite), set by uAutos }
    FTreinSprite: TViewSprite;       { +0x8C  the train, always drawn on top }
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
  { 00488EBC: TCell.Bebouwing bits, in clockwise order around the cell; a run of
    neighbouring bits selects one pavement (Stoep_nnn) frame }
  StoepBits: array[0..7] of Integer = (1, 32, 2, 64, 4, 128, 8, 16);

{ @0047322C }
constructor TView.Create(ASprites: TSpriteList; ASpriteBox: TSpriteBox; AWorld: TWorld;
  ASettings: TSettings; AStatus: TStatus);
var
  I, J, TW, TH, W, H: Integer;
  Dir: string;
begin
  { NOTE: no inherited constructor is called }
  Name := 'ZoetermeerViewer';
  Dir := AddPath(AddPath(AppPath, 'images'), '8bits');
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
  FTile.LoadFromFile(AddPath(Dir, 'Tile.bmp'));
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

{ @004734E0  Repaints every cell in FWorld.Changes. }
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

{ @00473530  Clips the screen rectangle Dest to the view area and shrinks the
  world rectangle Src accordingly. }
procedure ClipToView(var Src, Dest: TRect);
begin
  if Dest.Left < 30 then
  begin
    Inc(Src.Left, Round((30 - Dest.Left) / Zoom));
    Dest.Left := 30;
  end;
  if Dest.Top < 81 then
  begin
    Inc(Src.Top, Round((81 - Dest.Top) / Zoom));
    Dest.Top := 81;
  end;
  if Dest.Right > 822 then
  begin
    Inc(Src.Right, Round((822 - Dest.Right) / Zoom));
    Dest.Right := 822;
  end;
  if Dest.Bottom > 686 then
  begin
    Inc(Src.Bottom, Round((686 - Dest.Bottom) / Zoom));
    Dest.Bottom := 686;
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
  Src, Dest, R: TRect;
  I: Integer;
  Pos: TPos;
begin
  R := Rect(30, 81, 822, 686);
  FSpriteBox.InvalidateRect(R);
  Exit;
  { NOTE: the rest is dead code in the original (left behind by the Exit) }
  FWorld.Changes.Clear;
  Src := Bounds(0, 0, FTile.Width, FTile.Height);
  Dest.TopLeft := WorldToScreen(Src.TopLeft);
  Dest.BottomRight := WorldToScreen(Src.BottomRight);
  ClipToView(Src, Dest);
  FSpriteBox.Picture.CopyFrom(FTile, Src, Dest, False, False);
  FSpriteBox.InvalidateRect(Dest);
  for I := 0 to FViewSprites.Count - 1 do
  begin
    Pos := FViewSprites[I].Data as TPos;
    PlaceSprite(FViewSprites[I], Pos.X, Pos.Y);
  end;
end;

{ @0047376C  World position of the centre of the view (negated, like ScrollX/ScrollY). }
function TView.GetCenter: TPoint;
begin
  Result.X := ScrollX - Round(396 / Zoom);      { 396 = (822 - 30) / 2 }
  Result.Y := ScrollY - Round(302.5 / Zoom);    { 302.5 = (686 - 81) / 2 }
end;

{ @004737B8  Centres the view on (-AX, -AY) at the given zoom, kept inside the map. }
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

{ @004738E4  Frame name of the pavement piece for a run of Bebouwing bits. }
function StoepFrame(Mask: Integer): string;
begin
  if Mask and 8 <> 0 then
    Mask := Mask or $98;
  if Mask and 1 <> 0 then
    Mask := Mask or $31;
  if Mask and 2 <> 0 then
    Mask := Mask or $62;
  if Mask and 4 <> 0 then
    Mask := Mask or $C4;
  Result := 'Stoep_' + ZeroPad(IntStr(Mask), 3);
end;

{ @00473988  Paints the ground image of a cell (and its pavements) onto FTile. }
procedure TView.PaintCell(AX, AY: Integer);
var
  Cell: TCell;
  P: TPoint;
  Info: TContentsInfo;
  SpriteName, FrameName: string;
  Sprite, StoepSprite: TSprite;
  Frame: TFrame;
  Nr, X1, Y1, Mask, N, Start, I, Bits: Integer;
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

        Mask := Cell.Bebouwing;
        if Mask <> 0 then
          for N := 8 downto 1 do
            for Start := 0 to 7 do
            begin
              Bits := 0;
              for I := 1 to N do
                Bits := Bits or StoepBits[(Start + I) and 7];
              if Mask and Bits = Bits then
              begin
                { NOTE: runs one past the last pixie }
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
                Mask := Mask xor Bits;
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

{ @00474420  Draws the visible part of the map, the cars and the buildings. }
procedure TView.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Scale: Double);
var
  List: TViewSpriteList;
  P: TPoint;
  DC: HDC;
  Rgn: HRGN;
  Pos: TPos;
  Last: TViewSprite;
  Found: Boolean;
  I, J: Integer;
  R, Src: TRect;

  { @004740C8  Draws Sprite after (recursively) every sprite that lies behind it. }
  procedure DrawSprite(Sprite: TViewSprite; X1, Y1, X2, Y2: Integer);
  var
    MyX, MyY, I, N: Integer;
  begin
    { NOTE: the parameters are only tested, never used }
    if (X1 <> 0) or (Y1 <> 0) then
      ;
    MyX := (Sprite.Data as TPos).X;
    MyY := (Sprite.Data as TPos).Y;
    I := -1;
    N := List.Count;
    while I < List.Count - 1 do
    begin
      Inc(I);
      if (List[I] <> Sprite) and (List[I].FPos.X <= MyX) and (List[I].FPos.Y <= MyY) then
      begin
        DrawSprite(List[I], List[I].FPos.X, List[I].FPos.Y,
          (List[I].Data as TPos).X, (List[I].Data as TPos).Y);
        I := IMax(0, I - N + List.Count);
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
    List.Remove(Sprite);
  end;

begin
  if PerfStart = 0 then
    PerfStart := GetTickCount;
  Dec(PerfView, GetTickCount);
  R := ClipRect;
  OffsetRect(R, 30 - DX, 81 - DY);
  IntersectRect(R, R, Rect(30, 81, 822, 686));
  Src.TopLeft := ScreenToWorld(R.TopLeft);
  Src.BottomRight := ScreenToWorld(R.BottomRight);
  ClipRect := R;
  OffsetRect(ClipRect, DX - 30, DY - 81);
  FTile.CopyTo(Surface, Src, ClipRect, False, False);
  P := WorldToScreen(Point(FAutos.Left, FAutos.Top));
  FAutos.Draw(Surface, DX, DY, ClipRect, 1);
  DC := Surface.Canvas.Handle;
  Rgn := CreateRectRgn(ClipRect.Left, ClipRect.Top, ClipRect.Right, ClipRect.Bottom);
  SelectClipRgn(DC, Rgn);
  List := TViewSpriteList.Create;
  Last := nil;
  if ((GetTickCount div 500) mod 2 = 0) and (FWorld.Reistijd < 0) then
  begin
    { blink: hide the buildings and stations that cannot be reached }
    for I := 0 to FSpriteBox.PixieCount - 1 do
      if FSpriteBox.GetPixie(I) is TViewSprite then
      begin
        if (FSpriteBox.GetPixie(I) as TViewSprite).FPos.X <> -1 then
        begin
          Pos := (FSpriteBox.GetPixie(I) as TSprite).Data as TPos;
          Found := False;
          for J := 0 to FWorld.Bestemmingen.Count - 1 do
            if (FWorld.Bestemmingen[J].X = Pos.X) and (FWorld.Bestemmingen[J].Y = Pos.Y) then
            begin
              Found := True;
              if FWorld.Bestemmingen[J].Bereikbaar then
                List.Add(FSpriteBox.GetPixie(I) as TViewSprite);
            end;
          for J := 0 to FWorld.Bebouwing.Count - 1 do
            if (FWorld.Bebouwing[J].X = Pos.X) and (FWorld.Bebouwing[J].Y = Pos.Y) then
            begin
              Found := True;
              if FWorld.Bebouwing[J].Bereikbaar then
                List.Add(FSpriteBox.GetPixie(I) as TViewSprite);
            end;
          if not Found then
            List.Add(FSpriteBox.GetPixie(I) as TViewSprite);
        end
        else
          Last := FSpriteBox.GetPixie(I) as TViewSprite;
      end;
  end
  else
  begin
    for I := 0 to FSpriteBox.PixieCount - 1 do
      if FSpriteBox.GetPixie(I) is TViewSprite then
      begin
        if (FSpriteBox.GetPixie(I) as TViewSprite).FPos.X <> -1 then
          List.Add(FSpriteBox.GetPixie(I) as TViewSprite)
        else
          Last := FSpriteBox.GetPixie(I) as TViewSprite;
      end;
  end;
  if Last <> nil then
  begin
    P := WorldToScreen(Point(Last.Left, Last.Top));
    Last.DrawDC(DC, P.X + DX - 30, P.Y + DY - 81, Bounds(0, 0, 1, 1), Zoom);
  end;
  while List.Count <> 0 do
    DrawSprite(List[0], List[0].FPos.X, List[0].FPos.Y,
      (List[0].Data as TPos).X, (List[0].Data as TPos).Y);
  List.Free;
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

{ @004749DC  (Re)creates the building sprite of a cell. }
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
function TViewSpriteList.GetItem(Index: Integer): TViewSprite;
begin
  Result := TObject(Get(Index)) as TViewSprite;
end;

end.

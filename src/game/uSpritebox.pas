unit uSpritebox;

{ TSpriteBox: het besturingselement waarop alle pixies (sprites, goblins,
  tekstballonnen) over een achtergrondafbeelding worden getekend. Elke Flip verzamelt de
  gewijzigde gebieden van alle pixies en tekent alleen die opnieuw, hetzij op een
  DirectDraw-scherm (FullFlip/DirtyFlip, niet beschikbaar in deze build) of direct met
  GDI (GDIFlip/DrawRegion). TThreeD voegt een eenvoudige perspectiefprojectie toe.
  Gedecompileerd uit ROS.exe v1.1, code 0046C9CC-0046EA44. }

{$I zm.inc}

interface

uses
  Windows, Messages, Classes, Graphics, Controls, Menus,
  uTool, uSurface, uPixie;

type
  { Perspectief: een punt (X, Y, Z) wordt geprojecteerd naar (XDis, YDis) met
    factor DiaF / (ZDis + Z). }
  TThreeD = class(TPersistent)
  private
    FEnabled: Boolean;              { +0x04 }
    FXDis: Integer;                 { +0x08 }
    FYDis: Integer;                 { +0x0C }
    FZDis: Integer;                 { +0x10 }
    FDiaF: Integer;                 { +0x14 }
  public
    procedure Project(X, Y, Z: Integer; var PX, PY: Integer; var Factor: Double);
    procedure Assign(Source: TPersistent); override;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
    property XDis: Integer read FXDis write FXDis;
    property YDis: Integer read FYDis write FYDis;
    property ZDis: Integer read FZDis write FZDis;
    property DiaF: Integer read FDiaF write FDiaF;
  end;

  THandleBackGround = (hbUsePicture, hbUseColor, hbDontPaint);

  TSpriteBox = class(TCustomControl)
  private
    FReserved1F4: Integer;          { +0x1F4  niet gebruikt }
    FBackRects: TRectPosList;       { +0x1F8  gewijzigde gebieden, bewaard voor een schermoppervlak }
    FDirtyRects: TRectPosList;      { +0x1FC  gewijzigde gebieden sinds de laatste flip }
    FAutoFlip: Boolean;             { +0x200 }
    FFrozen: Boolean;               { +0x201  Flip doet niets (wordt nooit gezet) }
    FCenter: Boolean;               { +0x202 }
    FAutoSize: Boolean;             { +0x203 }
    FStretch: Boolean;              { +0x204 }
    FPicture: TSurface;             { +0x208  achtergrond }
    FPaletteImage: TSurface;        { +0x20C }
    FPalette: HPALETTE;             { +0x210  halftone-palet }
    FReserved214: Boolean;          { +0x214  op False gezet, nooit gelezen }
    FPixies: TList;                 { +0x218  gesorteerd op Z, hoogste eerst }
    FReserved21C: TRect;            { +0x21C  niet gebruikt }
    FFlipMode: Byte;                { +0x22C  0: FullFlip, 1: DirtyFlip (wordt nooit gezet) }
    FDrawWindow: HWND;              { +0x230  venster om op te tekenen in plaats van Handle (wordt nooit gezet) }
    FThreeD: TThreeD;               { +0x234 }
    FReload: string;                { +0x238 }
    FStarted: Boolean;              { +0x23C  eerste Paint uitgevoerd }
    FOnFlip: TNotifyEvent;          { +0x240 }
    FOnStarted: TNotifyEvent;       { +0x248 }
    FOnShow: TNotifyEvent;          { +0x250 }
    FScale: Double;                 { +0x258 }
    FCapturePixie: TPixie;          { +0x260  pixie die de muis heeft vastgelegd }
    FMousePixie: TPixie;            { +0x264  pixie onder de muis }
    FFrameTime: Integer;            { +0x268  gladgestreken ms per flip }
    FLastTick: Integer;             { +0x26C }
    FHandleBackGround: THandleBackGround; { +0x270 }
    FBackGroundColor: TColor;       { +0x274 }
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMStarted(var Message: TMessage); message WM_USER + 2;
    procedure SetAutoSize(Value: Boolean);
    procedure SetAutoFlip(Value: Boolean);
    procedure SetPicture(Value: TSurface);
    procedure SetPaletteImage(Value: TSurface);
    procedure AddUpdateRect(R: TRect);
    procedure MergeRects(Lijst: TRectPosList);
    procedure DrawRegion(DC: HDC; R: TRect; VersX, VersY: Integer);
    function ZOrderDirection(Nr: Integer): Integer;
    procedure UpdateZOrderAt(Nr: Integer);
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Paint; override;
    procedure InvalidateState(State: TPixieState); virtual;              { +0xB8 }
    procedure PaintBackground(Source: TSurface; DC: HDC;
      SrcRect, DestRect: TRect); virtual;                                { +0xBC }
    procedure FullFlip; virtual;                                         { +0xC0 }
    procedure DirtyFlip; virtual;                                        { +0xC4 }
    procedure GDIFlip; virtual;                                          { +0xC8 }
    procedure Flip; virtual;                                             { +0xCC }
    procedure InvalidateArea(R: TRect; Z: Integer); virtual;             { +0xD0 }
    function NoPicture: Boolean;
    function GetPixie(Nr: Integer): TPixie;
    function PixieCount: Integer;
    function GetDrawWindow: HWND;
    procedure InvalidateRect(R: TRect);
    function FindPixie(X, Y: Integer): TPixie;
    function PixieAt(X, Y: Integer): TPixie;
    procedure AddPixie(Pixie: TPixie);
    procedure RemovePixie(Pixie: TPixie);
    procedure UpdateZOrder(Pixie: TPixie);
    procedure UpdatePalette(Achtergrond: Boolean);
    procedure SetCapturePixie(Pixie: TPixie);
    property Count: Integer read PixieCount;
    property Items[Nr: Integer]: TPixie read GetPixie;
    property Canvas;
    property Scale: Double read FScale write FScale;
    property FrameTime: Integer read FFrameTime;
    property CapturePixie: TPixie read FCapturePixie write SetCapturePixie;
    property MousePixie: TPixie read FMousePixie;
    property DrawWindow: HWND read FDrawWindow write FDrawWindow;
    property FlipMode: Byte read FFlipMode write FFlipMode;
    property Frozen: Boolean read FFrozen write FFrozen;
  published
    property ThreeD: TThreeD read FThreeD write FThreeD;
    property Align default alNone;
    property AutoFlip: Boolean read FAutoFlip write SetAutoFlip;
    property AutoSize: Boolean read FAutoSize write SetAutoSize default False;
    property Center: Boolean read FCenter write FCenter default False;
    property DragCursor;
    property DragMode;
    property Enabled;
    property ParentShowHint;
    property Picture: TSurface read FPicture write SetPicture;
    property PaletteImage: TSurface read FPaletteImage write SetPaletteImage;
    property Reload: string read FReload write FReload;
    property PopupMenu;
    property ShowHint;
    property Stretch: Boolean read FStretch write FStretch default False;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnFlip: TNotifyEvent read FOnFlip write FOnFlip;
    property OnStarted: TNotifyEvent read FOnStarted write FOnStarted;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
    property HandleBackGround: THandleBackGround read FHandleBackGround write FHandleBackGround;
    property BackGroundColor: TColor read FBackGroundColor write FBackGroundColor;
  end;

  TSpriteBoxList = class(TList)
  public
    function Add(Box: TSpriteBox): TSpriteBox;
    function GetSpriteBox(Nr: Integer): TSpriteBox;
    procedure FlipAll;
    property SpriteBoxes[Nr: Integer]: TSpriteBox read GetSpriteBox; default;
  end;

var
  TempSurface: TSurface;            { 0048A934  werkoppervlak van DrawRegion }
  SpriteBoxes: TSpriteBoxList;      { 0048A938 }
  OldExitProc: Pointer;             { 0048A940 }

implementation

uses
  SysUtils, Forms, MMSystem, uTiming, uSprite, uTextBalloon, uGoblin;

{$J+}
const
  DrawDepth: Integer = 0;           { 00488E78  nesting van DrawRegion, begrensd op 5 }
{$J-}

{ ----------------------------------------------------------------- TSpriteBox }

{ @0046D1A8 }
constructor TSpriteBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csAcceptsControls];
  FScale := 1.0;
  Width := 320;
  Height := 240;
  FReserved214 := False;
  FBackRects := TRectPosList.Create;
  FDirtyRects := TRectPosList.Create;
  FPixies := TList.Create;
  FLastTick := GetTickCount;
  FThreeD := TThreeD.Create;
  FPicture := NewSurface;
  FPalette := 0;
  if FPicture = nil then
    raise Exception.Create('Could not create surface');
  SpriteBoxes.Add(Self);
end;

{ @0046D2D4 }
destructor TSpriteBox.Destroy;
var
  I: Integer;
begin
  for I := PixieCount - 1 downto 0 do
    if GetPixie(I) is TSprite then
      (GetPixie(I) as TSprite).SpriteBox := nil
    else if GetPixie(I) is TTextBalloon then
      (GetPixie(I) as TTextBalloon).SpriteBox := nil
    else if GetPixie(I) is TGoblin then
      (GetPixie(I) as TGoblin).SpriteBox := nil;
  FPixies.Free;
  FBackRects.Free;
  FDirtyRects.Free;
  FThreeD.Free;
  FPicture.Free;
  SpriteBoxes.Remove(Self);
  if FPalette <> 0 then
  begin
    DeleteObject(FPalette);
    FPalette := 0;
  end;
  inherited Destroy;
end;

{ @0046D410 }
function TSpriteBox.NoPicture: Boolean;
begin
  Result := FPicture = nil;
end;

{ @0046D41C }
function TSpriteBox.GetPixie(Nr: Integer): TPixie;
begin
  Result := TObject(FPixies[Nr]) as TPixie;
end;

{ @0046D440 }
function TSpriteBox.PixieCount: Integer;
begin
  Result := FPixies.Count;
end;

{ @0046D44C }
procedure TSpriteBox.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  if csDesigning in ComponentState then
  begin
    Message.Result := 0;
    inherited;
  end;
end;

{ @0046D460  gepost door de eerste Paint: start de timerlus }
procedure TSpriteBox.WMStarted(var Message: TMessage);
begin
  if not (csDesigning in ComponentState) then
  begin
    if Assigned(FOnStarted) then
      FOnStarted(Self);
    Flip;
    InvalidateRect(Rect(0, 0, Width, Height));
    FastTimerLoop(nil);
  end;
end;

{ @0046D4BC }
procedure TSpriteBox.SetAutoSize(Value: Boolean);
begin
  FAutoSize := Value;
  if (csDesigning in ComponentState) and not (csLoading in ComponentState) and
    FAutoSize then
  begin
    Width := FPicture.Width;
    Height := FPicture.Height;
  end;
end;

{ ------------------------------------------------------------------- TThreeD }

{ @0046D504 }
procedure TThreeD.Project(X, Y, Z: Integer; var PX, PY: Integer; var Factor: Double);
begin
  PX := (X - FXDis) * FDiaF div (FZDis + Z) + FXDis;
  PY := (Y - FYDis) * FDiaF div (FZDis + Z) + FYDis;
  Factor := FDiaF / (FZDis + Z);
end;

{ @0046D564 }
procedure TThreeD.Assign(Source: TPersistent);
begin
  if not (Source is TThreeD) then
    inherited Assign(Source)
  else
    with Source as TThreeD do
    begin
      Self.FEnabled := FEnabled;
      Self.FXDis := FXDis;
      Self.FYDis := FYDis;
      Self.FZDis := FZDis;
      Self.FDiaF := FDiaF;
    end;
end;

{ ----------------------------------------------------------------- TSpriteBox }

{ @0046D5B8 }
procedure TSpriteBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPixie;
begin
  P := PixieAt(X, Y);
  if P <> nil then
    P.MouseDown(P, Button, Shift, X - P.GetLeft, Y - P.GetTop);
  inherited MouseDown(Button, Shift, X, Y);
end;

{ @0046D620 }
procedure TSpriteBox.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  P: TPixie;
begin
  P := PixieAt(X, Y);
  if P <> nil then
    P.MouseMove(P, Shift, X - P.GetLeft, Y - P.GetTop);
  if (P <> FMousePixie) and (FMousePixie <> nil) then
    FMousePixie.MouseLeave;
  FMousePixie := P;
  inherited MouseMove(Shift, X, Y);
end;

{ @0046D6A8 }
procedure TSpriteBox.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPixie;
begin
  P := PixieAt(X, Y);
  if P <> nil then
    if P <> nil then   { LET OP: in het origineel tweemaal getest }
      P.MouseUp(P, Button, Shift, X - P.GetLeft, Y - P.GetTop);
  inherited MouseUp(Button, Shift, X, Y);
end;

{ @0046D714 }
procedure TSpriteBox.Paint;
begin
  if not FStarted then
  begin
    FStarted := True;
    if Assigned(FOnShow) then
      FOnShow(Self);
    PostMessage(Handle, WM_USER + 2, 0, 0);
  end;
  if csDesigning in ComponentState then
  begin
    Canvas.Pen.Style := psDash;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(0, 0, Width, Height);
  end;
  if not (csDesigning in ComponentState) or not FPicture.Empty then
    if csDesigning in ComponentState then
      DrawRegion(Canvas.Handle, Rect(0, 0, Width, Height), 0, 0)
    else
      InvalidateRect(Rect(0, 0, Width, Height));
end;

{ @0046D800 }
procedure TSpriteBox.AddUpdateRect(R: TRect);
begin
  if (R.Right - R.Left > 0) and (R.Bottom - R.Top > 0) then
  begin
    if SurfaceScreen <> nil then
      FBackRects.AddRect(R);
    FDirtyRects.AddRect(R);
  end;
end;

{ @0046D858 }
procedure TSpriteBox.SetAutoFlip(Value: Boolean);
begin
  if Value <> FAutoFlip then
  begin
    if not Value then
      Flip;
    FAutoFlip := Value;
  end;
end;

{ @0046D880  voegt overlappende rechthoeken samen; samengevoegde krijgen X = -9999 }
procedure TSpriteBox.MergeRects(Lijst: TRectPosList);
var
  I, J: Integer;
  A, B: TRectPos;
  T: DWORD;
begin
  T := timeGetTime;   { LET OP: overblijfsel van timing, niet gebruikt }
  for I := Lijst.Count - 1 downto 1 do
    for J := I - 1 downto 0 do
    begin
      A := TRectPos(TList(Lijst)[I]);
      if A.X <> -9999 then
      begin
        B := TRectPos(TList(Lijst)[J]);
        if B.Intersects(A) then
        begin
          B.Union(A);
          A.X := -9999;
          Break;
        end;
      end;
    end;
  T := timeGetTime;
end;

{ @0046D900 }
function TSpriteBox.GetDrawWindow: HWND;
begin
  if FDrawWindow <> 0 then
    Result := FDrawWindow
  else
    Result := Handle;
end;

{ @0046D914  tekent alles opnieuw op het schermoppervlak }
procedure TSpriteBox.FullFlip;
var
  RP: TRectPos;
  I: Integer;
  P: TPixie;
  PX, PY: Integer;
  Schaal: Double;
begin
  if FBackRects.Count <> 0 then
  begin
    FreeList(FDirtyRects);
    FreeList(FBackRects);
    FPicture.SetTransparentColor(clNoTransparent);
    SurfaceScreen.GetBackSurface.CopyFrom(FPicture, Rect(0, 0, Width - 1, Height - 1),
      Rect(0, 0, Width - 1, Height - 1), False, False);
    RP := TRectPos.Create(0, 0, 0, 0);   { LET OP: wordt nooit vrijgegeven }
    for I := 0 to FPixies.Count - 1 do
    begin
      P := GetPixie(I);
      if P.Visible then
      begin
        if not FThreeD.Enabled then
        begin
          RP.SetRect(GetPixie(I).GetBoundsRect);
          Schaal := 1.0;
        end
        else
        begin
          FThreeD.Project(P.GetLeft, P.GetTop, P.GetZ, PX, PY, Schaal);
          RP.SetRect(Bounds(PX, PY, Round(GetPixie(I).GetWidth * Schaal),
            Round(GetPixie(I).GetHeight * Schaal)));
        end;
        P.Draw(SurfaceScreen.GetBackSurface, 0, 0, RP.GetRect, Schaal);
      end;
    end;
    SurfaceScreen.Flip;
  end;
end;

{ @0046DB0C  tekent de gewijzigde gebieden opnieuw op het schermoppervlak }
procedure TSpriteBox.DirtyFlip;
var
  RP: TRectPos;
  I, J: Integer;
  P: TPixie;
  PX, PY: Integer;
  Schaal: Double;
  Geraakt: Boolean;
  Tijdelijk: TRectPosList;
begin
  if FBackRects.Count <> 0 then
  begin
    MergeRects(FDirtyRects);
    FPicture.SetTransparentColor(clNoTransparent);
    for I := 0 to FDirtyRects.Count - 1 do
      if FDirtyRects[I].X <> -9999 then
        if NoPicture then
          SurfaceScreen.GetBackSurface.FillRect(FDirtyRects[I].GetRect, 0)
        else
          SurfaceScreen.GetBackSurface.CopyFrom(FPicture, FDirtyRects[I].GetRect,
            FDirtyRects[I].GetRect, False, False);
    RP := TRectPos.Create(0, 0, 0, 0);   { LET OP: wordt nooit vrijgegeven }
    for I := 0 to FPixies.Count - 1 do
    begin
      P := GetPixie(I);
      if P.Visible then
      begin
        if not FThreeD.Enabled then
        begin
          RP.SetRect(GetPixie(I).GetBoundsRect);
          Schaal := 1.0;
        end
        else
        begin
          FThreeD.Project(P.GetLeft, P.GetTop, P.GetZ, PX, PY, Schaal);
          RP.SetRect(Bounds(PX, PY, Round(GetPixie(I).GetWidth * Schaal),
            Round(GetPixie(I).GetHeight * Schaal)));
        end;
        Geraakt := False;
        for J := 0 to FDirtyRects.Count - 1 do
          if FDirtyRects[J].X <> -9999 then
            if RP.Intersects(TRectPos(TList(FDirtyRects)[J])) then
            begin
              Geraakt := True;
              Break;
            end;
        if Geraakt then
          P.Draw(SurfaceScreen.GetBackSurface, 0, 0, RP.GetRect, Schaal);
      end;
    end;
    SurfaceScreen.Flip;
    FreeList(FDirtyRects);
    Tijdelijk := FDirtyRects;
    FDirtyRects := FBackRects;
    FBackRects := Tijdelijk;
  end;
end;

{ @0046DE00  tekent de gewijzigde gebieden direct opnieuw op het venster }
procedure TSpriteBox.GDIFlip;
var
  Venster: HWND;
  DC: HDC;
  I: Integer;
begin
  if FDirtyRects.Count <> 0 then
  begin
    MergeRects(FDirtyRects);
    Venster := GetDrawWindow;
    DC := GetDC(Venster);
    for I := 0 to FDirtyRects.Count - 1 do
      if FDirtyRects[I].X <> -9999 then
        DrawRegion(DC, FDirtyRects[I].GetRect, 0, 0);
    ReleaseDC(Venster, DC);
    FreeList(FDirtyRects);
  end;
end;

{ @0046DEA8 }
procedure TSpriteBox.InvalidateState(State: TPixieState);
var
  PX, PY: Integer;
  Factor: Double;
begin
  if State.Visible then
    if not FThreeD.Enabled then
      InvalidateRect(Bounds(State.Left, State.Top, State.Width, State.Height))
    else
    begin
      FThreeD.Project(State.Left, State.Top, State.Z, PX, PY, Factor);
      InvalidateRect(Bounds(PX, PY, Round(State.Width * Factor),
        Round(State.Height * Factor)));
    end;
end;

{ @0046DF60  verzamelt de wijzigingen van alle pixies en tekent ze opnieuw }
procedure TSpriteBox.Flip;
var
  P: TPoint;
  Venster: HWND;
  I: Integer;
  OudeStaat, NieuweStaat: TPixieState;
  T: Integer;
begin
  GetCursorPos(P);
  Venster := WindowFromPoint(P);
  if (Venster <> GetDrawWindow) and (FMousePixie <> nil) then
  begin
    FMousePixie.MouseLeave;
    FMousePixie := nil;
  end;
  if not FFrozen then
  begin
    for I := FPixies.Count - 1 downto 0 do
    begin
      GetPixie(I).GetChange(OudeStaat, NieuweStaat);
      InvalidateState(OudeStaat);
      InvalidateState(NieuweStaat);
    end;
    T := GetTickCount;
    FFrameTime := Round(FFrameTime * 0.8 + (T - FLastTick) * 0.2);
    FLastTick := T;
    if Assigned(FOnFlip) then
      FOnFlip(Self);
    if SurfaceScreen = nil then
      GDIFlip
    else
      case FFlipMode of
        0: FullFlip;
        1: DirtyFlip;
      end;
  end;
end;

{ @0046E0B0 }
procedure TSpriteBox.InvalidateRect(R: TRect);
begin
  if (R.Left = 0) and (R.Right = 0) then   { LET OP: Right, niet Top }
    R.Left := 1;
  InvalidateArea(R, -9999);
end;

{ @0046E0F0  Z = -9999: R staat al in schermcoordinaten }
procedure TSpriteBox.InvalidateArea(R: TRect; Z: Integer);
var
  PX, PY, W, H: Integer;
  Factor: Double;
begin
  if FThreeD.Enabled and (Z <> -9999) then
  begin
    FThreeD.Project(R.Left, R.Top, Z, PX, PY, Factor);
    W := Round((R.Right - R.Left) * Factor);
    H := Round((R.Bottom - R.Top) * Factor) + PY;
    R := Rect(PX, PY, PX + W, H);
  end;
  if R.Left < 0 then
    R.Left := 0;
  if R.Top < 0 then
    R.Top := 0;
  if Width < R.Right then
    R.Right := Width;
  if Height < R.Bottom then
    R.Bottom := Height;
  AddUpdateRect(R);
  if FAutoFlip then
    Flip;
end;

{ @0046E1E4 }
procedure TSpriteBox.PaintBackground(Source: TSurface; DC: HDC;
  SrcRect, DestRect: TRect);
begin
  if FScale <> 1 then
  begin
    DestRect.Left := Round(DestRect.Left * FScale);
    DestRect.Right := Round(DestRect.Right * FScale);
    DestRect.Top := Round(DestRect.Top * FScale);
    DestRect.Bottom := Round(DestRect.Bottom * FScale);
  end;
  UpdatePalette(False);
  Source.DrawTo(DC, SrcRect, DestRect, False, False);
end;

{ @0046E294  tekent achtergrond en pixies van R (venstercoordinaten + verschuiving)
  via TempSurface, of recursief per pixie als TempSurface te klein is }
procedure TSpriteBox.DrawRegion(DC: HDC; R: TRect; VersX, VersY: Integer);
var
  GebruikTemp: Boolean;
  BronR, DoelR, PR, Tijdelijk: TRect;
  Vlak: TSurface;
  I: Integer;
  P: TPixie;
  PX, PY, W, H: Integer;
  Schaal: Double;
begin
  Inc(DrawDepth);
  if DrawDepth > 5 then
    DrawDepth := 5;
  R.Right := IMin(R.Right, Width);
  R.Bottom := IMin(R.Bottom, Height);
  R.Top := IMax(0, R.Top);
  R.Left := IMax(0, R.Left);
  if TempSurface = nil then
    TempSurface := NewSurface;
  if (TempSurface.Height < Screen.Height) or (TempSurface.Width < Screen.Width) then
  begin
    TempSurface.Width := Screen.Width;
    TempSurface.Height := Screen.Height;
  end;
  GebruikTemp := (TempSurface.Width >= R.Right - R.Left) and
    (TempSurface.Height >= R.Bottom - R.Top);
  if RectWidth(R) > TempSurface.Width then
    GebruikTemp := True;
  if RectHeight(R) > TempSurface.Height then
    GebruikTemp := True;
  BronR := Rect(R.Left - VersX, R.Top - VersY, R.Right - VersX, R.Bottom - VersY);
  if GebruikTemp then
    DoelR := Rect(0, 0, R.Right - R.Left, R.Bottom - R.Top)
  else
    DoelR := Rect(R.Left - VersX, R.Top - VersY, R.Right - VersX, R.Bottom - VersY);
  Vlak := TempSurface;
  if NoPicture then
  begin
    if GebruikTemp then
      Vlak.FillRect(DoelR, 0)
    else
      { LET OP: de doel-Y is in het origineel R.Right }
      BitBlt(DC, R.Left, R.Right, R.Right - R.Left, R.Bottom - R.Top, DC, 0, 0, BLACKNESS);
  end
  else if GebruikTemp then
    case FHandleBackGround of
      hbUsePicture:
        begin
          Vlak.SetTransparentColor(clNoTransparent);
          Vlak.CopyFrom(FPicture, BronR, DoelR, False, False);
        end;
      hbUseColor: ;
      hbDontPaint: ;
    end
  else
    PaintBackground(FPicture, DC, DoelR, R);
  for I := 0 to FPixies.Count - 1 do
  begin
    P := GetPixie(I);
    if P.Visible then
    begin
      if not FThreeD.Enabled then
      begin
        PR := GetPixie(I).GetBoundsRect;
        Schaal := 1.0;
        PX := P.GetLeft;
        PY := P.GetTop;
        W := GetPixie(I).GetWidth;    { LET OP: W en H worden hier niet gebruikt }
        H := GetPixie(I).GetHeight;
      end
      else
      begin
        FThreeD.Project(P.GetLeft, P.GetTop, P.GetZ, PX, PY, Schaal);
        W := Round(GetPixie(I).GetWidth * Schaal);
        H := Round(GetPixie(I).GetHeight * Schaal);
        PR := Rect(PX, PY, PX + W, PY + H);
      end;
      if IntersectRect(Tijdelijk, PR, BronR) then
        if GebruikTemp then
          P.Draw(Vlak, PX + VersX - R.Left, PY + VersY - R.Top, DoelR, Schaal)
        else
          DrawRegion(DC, PR, VersX, VersY);
    end;
  end;
  if GebruikTemp then
  begin
    Vlak.SetTransparentColor(clNoTransparent);
    PaintBackground(Vlak, DC, DoelR, R);
  end;
  Dec(DrawDepth);
end;

{ @0046E690  bovenste zichtbare pixie op (X, Y) }
function TSpriteBox.FindPixie(X, Y: Integer): TPixie;
var
  I: Integer;
  R: TRect;
begin
  for I := PixieCount - 1 downto 0 do
  begin
    R := GetPixie(I).GetBoundsRect;
    if GetPixie(I).Visible and (X >= R.Left) and (X <= R.Right) and
      (Y >= R.Top) and (Y <= R.Bottom) then
    begin
      Result := GetPixie(I);
      Exit;
    end;
  end;
  Result := nil;
end;

{ @0046E700 }
function TSpriteBox.PixieAt(X, Y: Integer): TPixie;
begin
  if FCapturePixie = nil then
    Result := FindPixie(X, Y)
  else
    Result := FCapturePixie;
end;

{ @0046E718 }
procedure TSpriteBox.AddPixie(Pixie: TPixie);
begin
  UpdateZOrderAt(FPixies.Add(Pixie));
end;

{ @0046E734 }
procedure TSpriteBox.RemovePixie(Pixie: TPixie);
var
  OudeStaat, NieuweStaat: TPixieState;
begin
  Pixie.GetChange(OudeStaat, NieuweStaat);
  if Pixie = FMousePixie then
  begin
    FMousePixie.MouseLeave;
    FMousePixie := nil;
  end;
  OudeStaat.Visible := True;
  InvalidateState(OudeStaat);
  FPixies.Remove(Pixie);
end;

{ @0046E78C }
procedure TSpriteBox.SetPicture(Value: TSurface);
begin
  FPicture := Value;
  Paint;
end;

{ @0046E7A4 }
procedure TSpriteBox.SetPaletteImage(Value: TSurface);
begin
  if FPaletteImage = nil then
    FPaletteImage := NewSurface;
  FPaletteImage.Assign(Value);
end;

{ @0046E7D0 }
procedure TSpriteBox.UpdateZOrder(Pixie: TPixie);
var
  Nr: Integer;
begin
  Nr := FPixies.IndexOf(Pixie);
  if Nr <> -1 then
    UpdateZOrderAt(Nr);
end;

{ @0046E7F0  -1/1: de pixie op Index moet omhoog/omlaag om Z aflopend te houden }
function TSpriteBox.ZOrderDirection(Nr: Integer): Integer;
begin
  Result := 0;
  if FPixies.Count <> 1 then
    if (Nr > 0) and (GetPixie(Nr - 1).GetZ < GetPixie(Nr).GetZ) then
      Result := -1
    else if (Nr < FPixies.Count - 1) and
      (GetPixie(Nr + 1).GetZ > GetPixie(Nr).GetZ) then
      Result := 1;
end;

{ @0046E870 }
procedure TSpriteBox.UpdateZOrderAt(Nr: Integer);
var
  D: Integer;
begin
  repeat
    D := ZOrderDirection(Nr);
    if D <> 0 then
    begin
      FPixies.Exchange(Nr, D + Nr);
      Inc(Nr, D);
    end;
  until D = 0;
end;

{ @0046E8A0 }
procedure TSpriteBox.UpdatePalette(Achtergrond: Boolean);
var
  Venster: HWND;
  DC: HDC;
  Palet, OudPalet: HPALETTE;
begin
  Venster := GetDrawWindow;
  DC := GetDC(Venster);
  if GetDeviceCaps(DC, RASTERCAPS) and RC_PALETTE = RC_PALETTE then
  begin
    if FPaletteImage <> nil then
      Palet := FPaletteImage.GetPaletteHandle
    else
    begin
      if FPalette = 0 then
        FPalette := CreateHalftonePalette(DC);
      Palet := FPalette;
    end;
    OudPalet := SelectPalette(DC, Palet, Achtergrond);
    RealizePalette(DC);
    SelectPalette(DC, OudPalet, False);
  end;
  ReleaseDC(Venster, DC);
end;

{ @0046E928 }
procedure TSpriteBox.SetCapturePixie(Pixie: TPixie);
begin
  if Pixie <> FCapturePixie then
  begin
    FCapturePixie := Pixie;
    if Pixie = nil then
      MouseCapture := False
    else
      MouseCapture := True;
  end;
end;

{ ------------------------------------------------------------- TSpriteBoxList }

{ @0046E94C }
function TSpriteBoxList.Add(Box: TSpriteBox): TSpriteBox;
begin
  inherited Add(Box);
  Result := Box;
end;

{ @0046E95C }
function TSpriteBoxList.GetSpriteBox(Nr: Integer): TSpriteBox;
begin
  Result := TObject(Get(Nr)) as TSpriteBox;
end;

{ @0046E97C }
procedure TSpriteBoxList.FlipAll;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if GetSpriteBox(I).Visible then
      GetSpriteBox(I).Flip;
end;

{ @0046E9B4  afsluitprocedure }
procedure SpriteBoxExit;
begin
  if TempSurface <> nil then
    TempSurface.Free;
  ExitProc := OldExitProc;
end;

initialization
  { @0046EA08 }
  TempSurface := nil;
  OldExitProc := ExitProc;
  ExitProc := @SpriteBoxExit;
  SpriteBoxes := TSpriteBoxList.Create;

{ De finalization op @0046E9D8 is de lege, door de compiler gegenereerde stub. }

end.

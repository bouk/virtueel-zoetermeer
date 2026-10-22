unit uSpritebox;

{ TSpriteBox: the control on which all pixies (sprites, goblins, text
  balloons) are drawn over a background picture. Each Flip collects the
  changed areas of all pixies and redraws only those, either on a DirectDraw
  screen (FullFlip/DirtyFlip, not available in this build) or directly with
  GDI (GDIFlip/DrawRegion). TThreeD adds a simple perspective projection.
  Decompiled from ROS.exe v1.1, code 0046C9CC-0046EA44. }

{$I zm.inc}

interface

uses
  Windows, Messages, Classes, Graphics, Controls, Menus,
  uTool, uSurface, uPixie;

type
  { Perspective: a point (X, Y, Z) is projected towards (XDis, YDis) with
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
    FReserved1F4: Integer;          { +0x1F4  not used }
    FBackRects: TRectPosList;       { +0x1F8  changed areas, kept for a screen surface }
    FDirtyRects: TRectPosList;      { +0x1FC  changed areas since the last flip }
    FAutoFlip: Boolean;             { +0x200 }
    FFrozen: Boolean;               { +0x201  Flip does nothing (never set) }
    FCenter: Boolean;               { +0x202 }
    FAutoSize: Boolean;             { +0x203 }
    FStretch: Boolean;              { +0x204 }
    FPicture: TSurface;             { +0x208  background }
    FPaletteImage: TSurface;        { +0x20C }
    FPalette: HPALETTE;             { +0x210  halftone palette }
    FReserved214: Boolean;          { +0x214  set to False, never read }
    FPixies: TList;                 { +0x218  sorted on Z, highest first }
    FReserved21C: TRect;            { +0x21C  not used }
    FFlipMode: Byte;                { +0x22C  0: FullFlip, 1: DirtyFlip (never set) }
    FDrawWindow: HWND;              { +0x230  window to draw on instead of Handle (never set) }
    FThreeD: TThreeD;               { +0x234 }
    FReload: string;                { +0x238 }
    FStarted: Boolean;              { +0x23C  first Paint done }
    FOnFlip: TNotifyEvent;          { +0x240 }
    FOnStarted: TNotifyEvent;       { +0x248 }
    FOnShow: TNotifyEvent;          { +0x250 }
    FScale: Double;                 { +0x258 }
    FCapturePixie: TPixie;          { +0x260  pixie that captured the mouse }
    FMousePixie: TPixie;            { +0x264  pixie under the mouse }
    FFrameTime: Integer;            { +0x268  smoothed ms per flip }
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
    procedure MergeRects(List: TRectPosList);
    procedure DrawRegion(DC: HDC; R: TRect; OffsX, OffsY: Integer);
    function ZOrderDirection(Index: Integer): Integer;
    procedure UpdateZOrderAt(Index: Integer);
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
    function GetPixie(Index: Integer): TPixie;
    function PixieCount: Integer;
    function GetDrawWindow: HWND;
    procedure InvalidateRect(R: TRect);
    function FindPixie(X, Y: Integer): TPixie;
    function PixieAt(X, Y: Integer): TPixie;
    procedure AddPixie(Pixie: TPixie);
    procedure RemovePixie(Pixie: TPixie);
    procedure UpdateZOrder(Pixie: TPixie);
    procedure UpdatePalette(Background: Boolean);
    procedure SetCapturePixie(Pixie: TPixie);
    property Count: Integer read PixieCount;
    property Items[Index: Integer]: TPixie read GetPixie;
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
    function GetSpriteBox(Index: Integer): TSpriteBox;
    procedure FlipAll;
    property SpriteBoxes[Index: Integer]: TSpriteBox read GetSpriteBox; default;
  end;

var
  TempSurface: TSurface;            { 0048A934  scratch surface of DrawRegion }
  SpriteBoxes: TSpriteBoxList;      { 0048A938 }
  OldExitProc: Pointer;             { 0048A940 }

implementation

uses
  SysUtils, Forms, MMSystem, uTiming, uSprite, uTextBalloon, uGoblin;

{$J+}
const
  DrawDepth: Integer = 0;           { 00488E78  nesting of DrawRegion, clipped at 5 }
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
function TSpriteBox.GetPixie(Index: Integer): TPixie;
begin
  Result := TObject(FPixies[Index]) as TPixie;
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

{ @0046D460  posted by the first Paint: starts the timer loop }
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
    if P <> nil then   { NOTE: tested twice in the original }
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

{ @0046D880  joins overlapping rectangles; joined ones get X = -9999 }
procedure TSpriteBox.MergeRects(List: TRectPosList);
var
  I, J: Integer;
  A, B: TRectPos;
  T: DWORD;
begin
  T := timeGetTime;   { NOTE: timing leftover, not used }
  for I := List.Count - 1 downto 1 do
    for J := I - 1 downto 0 do
    begin
      A := TRectPos(TList(List)[I]);
      if A.X <> -9999 then
      begin
        B := TRectPos(TList(List)[J]);
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

{ @0046D914  redraws everything on the screen surface }
procedure TSpriteBox.FullFlip;
var
  RP: TRectPos;
  I: Integer;
  P: TPixie;
  PX, PY: Integer;
  Size: Double;
begin
  if FBackRects.Count <> 0 then
  begin
    FreeList(FDirtyRects);
    FreeList(FBackRects);
    FPicture.SetTransparentColor(clNoTransparent);
    SurfaceScreen.GetBackSurface.CopyFrom(FPicture, Rect(0, 0, Width - 1, Height - 1),
      Rect(0, 0, Width - 1, Height - 1), False, False);
    RP := TRectPos.Create(0, 0, 0, 0);   { NOTE: never freed }
    for I := 0 to FPixies.Count - 1 do
    begin
      P := GetPixie(I);
      if P.Visible then
      begin
        if not FThreeD.Enabled then
        begin
          RP.SetRect(GetPixie(I).GetBoundsRect);
          Size := 1.0;
        end
        else
        begin
          FThreeD.Project(P.GetLeft, P.GetTop, P.GetZ, PX, PY, Size);
          RP.SetRect(Bounds(PX, PY, Round(GetPixie(I).GetWidth * Size),
            Round(GetPixie(I).GetHeight * Size)));
        end;
        P.Draw(SurfaceScreen.GetBackSurface, 0, 0, RP.GetRect, Size);
      end;
    end;
    SurfaceScreen.Flip;
  end;
end;

{ @0046DB0C  redraws the changed areas on the screen surface }
procedure TSpriteBox.DirtyFlip;
var
  RP: TRectPos;
  I, J: Integer;
  P: TPixie;
  PX, PY: Integer;
  Size: Double;
  Hit: Boolean;
  Tmp: TRectPosList;
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
    RP := TRectPos.Create(0, 0, 0, 0);   { NOTE: never freed }
    for I := 0 to FPixies.Count - 1 do
    begin
      P := GetPixie(I);
      if P.Visible then
      begin
        if not FThreeD.Enabled then
        begin
          RP.SetRect(GetPixie(I).GetBoundsRect);
          Size := 1.0;
        end
        else
        begin
          FThreeD.Project(P.GetLeft, P.GetTop, P.GetZ, PX, PY, Size);
          RP.SetRect(Bounds(PX, PY, Round(GetPixie(I).GetWidth * Size),
            Round(GetPixie(I).GetHeight * Size)));
        end;
        Hit := False;
        for J := 0 to FDirtyRects.Count - 1 do
          if FDirtyRects[J].X <> -9999 then
            if RP.Intersects(TRectPos(TList(FDirtyRects)[J])) then
            begin
              Hit := True;
              Break;
            end;
        if Hit then
          P.Draw(SurfaceScreen.GetBackSurface, 0, 0, RP.GetRect, Size);
      end;
    end;
    SurfaceScreen.Flip;
    FreeList(FDirtyRects);
    Tmp := FDirtyRects;
    FDirtyRects := FBackRects;
    FBackRects := Tmp;
  end;
end;

{ @0046DE00  redraws the changed areas directly on the window }
procedure TSpriteBox.GDIFlip;
var
  Wnd: HWND;
  DC: HDC;
  I: Integer;
begin
  if FDirtyRects.Count <> 0 then
  begin
    MergeRects(FDirtyRects);
    Wnd := GetDrawWindow;
    DC := GetDC(Wnd);
    for I := 0 to FDirtyRects.Count - 1 do
      if FDirtyRects[I].X <> -9999 then
        DrawRegion(DC, FDirtyRects[I].GetRect, 0, 0);
    ReleaseDC(Wnd, DC);
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

{ @0046DF60  collects the changes of all pixies and redraws them }
procedure TSpriteBox.Flip;
var
  P: TPoint;
  Wnd: HWND;
  I: Integer;
  OldState, NewState: TPixieState;
  T: Integer;
begin
  GetCursorPos(P);
  Wnd := WindowFromPoint(P);
  if (Wnd <> GetDrawWindow) and (FMousePixie <> nil) then
  begin
    FMousePixie.MouseLeave;
    FMousePixie := nil;
  end;
  if not FFrozen then
  begin
    for I := FPixies.Count - 1 downto 0 do
    begin
      GetPixie(I).GetChange(OldState, NewState);
      InvalidateState(OldState);
      InvalidateState(NewState);
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
  if (R.Left = 0) and (R.Right = 0) then   { NOTE: Right, not Top }
    R.Left := 1;
  InvalidateArea(R, -9999);
end;

{ @0046E0F0  Z = -9999: R is already in screen coordinates }
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

{ @0046E294  draws background and pixies of R (window coordinates + offset)
  through TempSurface, or recursively per pixie if TempSurface is too small }
procedure TSpriteBox.DrawRegion(DC: HDC; R: TRect; OffsX, OffsY: Integer);
var
  UseTemp: Boolean;
  SrcR, DestR, PR, Tmp: TRect;
  Surf: TSurface;
  I: Integer;
  P: TPixie;
  PX, PY, W, H: Integer;
  Size: Double;
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
  UseTemp := (TempSurface.Width >= R.Right - R.Left) and
    (TempSurface.Height >= R.Bottom - R.Top);
  if RectWidth(R) > TempSurface.Width then
    UseTemp := True;
  if RectHeight(R) > TempSurface.Height then
    UseTemp := True;
  SrcR := Rect(R.Left - OffsX, R.Top - OffsY, R.Right - OffsX, R.Bottom - OffsY);
  if UseTemp then
    DestR := Rect(0, 0, R.Right - R.Left, R.Bottom - R.Top)
  else
    DestR := Rect(R.Left - OffsX, R.Top - OffsY, R.Right - OffsX, R.Bottom - OffsY);
  Surf := TempSurface;
  if NoPicture then
  begin
    if UseTemp then
      Surf.FillRect(DestR, 0)
    else
      { NOTE: the destination Y is R.Right in the original }
      BitBlt(DC, R.Left, R.Right, R.Right - R.Left, R.Bottom - R.Top, DC, 0, 0, BLACKNESS);
  end
  else if UseTemp then
    case FHandleBackGround of
      hbUsePicture:
        begin
          Surf.SetTransparentColor(clNoTransparent);
          Surf.CopyFrom(FPicture, SrcR, DestR, False, False);
        end;
      hbUseColor: ;
      hbDontPaint: ;
    end
  else
    PaintBackground(FPicture, DC, DestR, R);
  for I := 0 to FPixies.Count - 1 do
  begin
    P := GetPixie(I);
    if P.Visible then
    begin
      if not FThreeD.Enabled then
      begin
        PR := GetPixie(I).GetBoundsRect;
        Size := 1.0;
        PX := P.GetLeft;
        PY := P.GetTop;
        W := GetPixie(I).GetWidth;    { NOTE: W and H are not used here }
        H := GetPixie(I).GetHeight;
      end
      else
      begin
        FThreeD.Project(P.GetLeft, P.GetTop, P.GetZ, PX, PY, Size);
        W := Round(GetPixie(I).GetWidth * Size);
        H := Round(GetPixie(I).GetHeight * Size);
        PR := Rect(PX, PY, PX + W, PY + H);
      end;
      if IntersectRect(Tmp, PR, SrcR) then
        if UseTemp then
          P.Draw(Surf, PX + OffsX - R.Left, PY + OffsY - R.Top, DestR, Size)
        else
          DrawRegion(DC, PR, OffsX, OffsY);
    end;
  end;
  if UseTemp then
  begin
    Surf.SetTransparentColor(clNoTransparent);
    PaintBackground(Surf, DC, DestR, R);
  end;
  Dec(DrawDepth);
end;

{ @0046E690  topmost visible pixie at (X, Y) }
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
  OldState, NewState: TPixieState;
begin
  Pixie.GetChange(OldState, NewState);
  if Pixie = FMousePixie then
  begin
    FMousePixie.MouseLeave;
    FMousePixie := nil;
  end;
  OldState.Visible := True;
  InvalidateState(OldState);
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
  Index: Integer;
begin
  Index := FPixies.IndexOf(Pixie);
  if Index <> -1 then
    UpdateZOrderAt(Index);
end;

{ @0046E7F0  -1/1: the pixie at Index must move up/down to keep Z descending }
function TSpriteBox.ZOrderDirection(Index: Integer): Integer;
begin
  Result := 0;
  if FPixies.Count <> 1 then
    if (Index > 0) and (GetPixie(Index - 1).GetZ < GetPixie(Index).GetZ) then
      Result := -1
    else if (Index < FPixies.Count - 1) and
      (GetPixie(Index + 1).GetZ > GetPixie(Index).GetZ) then
      Result := 1;
end;

{ @0046E870 }
procedure TSpriteBox.UpdateZOrderAt(Index: Integer);
var
  D: Integer;
begin
  repeat
    D := ZOrderDirection(Index);
    if D <> 0 then
    begin
      FPixies.Exchange(Index, D + Index);
      Inc(Index, D);
    end;
  until D = 0;
end;

{ @0046E8A0 }
procedure TSpriteBox.UpdatePalette(Background: Boolean);
var
  Wnd: HWND;
  DC: HDC;
  Pal, OldPal: HPALETTE;
begin
  Wnd := GetDrawWindow;
  DC := GetDC(Wnd);
  if GetDeviceCaps(DC, RASTERCAPS) and RC_PALETTE = RC_PALETTE then
  begin
    if FPaletteImage <> nil then
      Pal := FPaletteImage.GetPaletteHandle
    else
    begin
      if FPalette = 0 then
        FPalette := CreateHalftonePalette(DC);
      Pal := FPalette;
    end;
    OldPal := SelectPalette(DC, Pal, Background);
    RealizePalette(DC);
    SelectPalette(DC, OldPal, False);
  end;
  ReleaseDC(Wnd, DC);
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
function TSpriteBoxList.GetSpriteBox(Index: Integer): TSpriteBox;
begin
  Result := TObject(Get(Index)) as TSpriteBox;
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

{ @0046E9B4  exit procedure }
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

{ The finalization at @0046E9D8 is the empty compiler-generated stub. }

end.

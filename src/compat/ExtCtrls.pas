unit ExtCtrls;

{ Delphi 5 ExtCtrls subset: TShape, TPaintBox, TImage, TBevel, TTimer, TPanel,
  TSplitter (inert), TNotebook-free. }

{$MODE DELPHI}{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ZMDraw;

type
  TShapeType = (stRectangle, stSquare, stRoundRect, stRoundSquare, stEllipse, stCircle);
  TBevelStyle = (bsLowered, bsRaised);
  TBevelShape = (bsBox, bsFrame, bsTopLine, bsBottomLine, bsLeftLine, bsRightLine, bsSpacer);
  TPanelBevel = TBevelCut;

  TShape = class(TGraphicControl)
  private
    FPen: TPen;
    FBrush: TBrush;
    FShape: TShapeType;
    procedure SetBrush(Value: TBrush);
    procedure SetPen(Value: TPen);
    procedure SetShape(Value: TShapeType);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    procedure StyleChanged(Sender: TObject);
    property Align;
    property Anchors;
    property Brush: TBrush read FBrush write SetBrush;
    property DragCursor;
    property DragMode;
    property Enabled;
    property ParentShowHint;
    property Pen: TPen read FPen write SetPen;
    property Shape: TShapeType read FShape write SetShape default stRectangle;
    property ShowHint;
    property Visible;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
  end;

  TPaintBox = class(TGraphicControl)
  private
    FOnPaint: TNotifyEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    property Canvas;
  published
    property Align;
    property Anchors;
    property Color;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnPaint: TNotifyEvent read FOnPaint write FOnPaint;
    property OnStartDrag;
  end;

  TImage = class(TGraphicControl)
  private
    FPicture: TPicture;
    FOnProgress: TProgressEvent;
    FStretch: Boolean;
    FCenter: Boolean;
    FIncrementalDisplay: Boolean;
    FTransparent: Boolean;
    FDrawing: Boolean;
    function GetCanvas: TCanvas;
    procedure PictureChanged(Sender: TObject);
    procedure SetCenter(Value: Boolean);
    procedure SetPicture(Value: TPicture);
    procedure SetStretch(Value: Boolean);
    procedure SetTransparent(Value: Boolean);
  protected
    function CanAutoSize(var NewWidth, NewHeight: Integer): Boolean; override;
    function DestRect: TRect;
    function DoPaletteChange: Boolean;
    function GetPalette: HPALETTE; override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Canvas: TCanvas read GetCanvas;
  published
    property Align;
    property Anchors;
    property AutoSize;
    property Center: Boolean read FCenter write SetCenter default False;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property IncrementalDisplay: Boolean read FIncrementalDisplay write FIncrementalDisplay default False;
    property ParentShowHint;
    property Picture: TPicture read FPicture write SetPicture;
    property PopupMenu;
    property ShowHint;
    property Stretch: Boolean read FStretch write SetStretch default False;
    property Transparent: Boolean read FTransparent write SetTransparent default False;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnProgress: TProgressEvent read FOnProgress write FOnProgress;
    property OnStartDrag;
  end;

  TBevel = class(TGraphicControl)
  private
    FStyle: TBevelStyle;
    FShape: TBevelShape;
    procedure SetStyle(Value: TBevelStyle);
    procedure SetShape(Value: TBevelShape);
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Anchors;
    property Constraints;
    property ParentShowHint;
    property Shape: TBevelShape read FShape write SetShape default bsBox;
    property ShowHint;
    property Style: TBevelStyle read FStyle write SetStyle default bsLowered;
    property Visible;
  end;

  TTimer = class(TComponent)
  private
    FInterval: Cardinal;
    FWindowHandle: HWND;
    FOnTimer: TNotifyEvent;
    FEnabled: Boolean;
    procedure UpdateTimer;
    procedure SetEnabled(Value: Boolean);
    procedure SetInterval(Value: Cardinal);
    procedure SetOnTimer(Value: TNotifyEvent);
    procedure WndProc(var Msg: TMessage);
  protected
    procedure Timer; dynamic;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property Enabled: Boolean read FEnabled write SetEnabled default True;
    property Interval: Cardinal read FInterval write SetInterval default 1000;
    property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;
  end;

  TCustomPanel = class(TCustomControl)
  private
    FBevelInner: TPanelBevel;
    FBevelOuter: TPanelBevel;
    FBevelWidth: TBevelWidth;
    FBorderStyle: TBorderStyle;
    FFullRepaint: Boolean;
    FLocked: Boolean;
    FAlignment: TAlignment;
    procedure SetAlignment(Value: TAlignment);
    procedure SetBevelInner(Value: TPanelBevel);
    procedure SetBevelOuter(Value: TPanelBevel);
    procedure SetBevelWidth(Value: TBevelWidth);
    procedure SetBorderStyle(Value: TBorderStyle);
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;
  protected
    procedure AdjustClientRect(var Rect: TRect); override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
    property Alignment: TAlignment read FAlignment write SetAlignment default taCenter;
    property BevelInner: TPanelBevel read FBevelInner write SetBevelInner default bvNone;
    property BevelOuter: TPanelBevel read FBevelOuter write SetBevelOuter default bvRaised;
    property BevelWidth: TBevelWidth read FBevelWidth write SetBevelWidth default 1;
    property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsNone;
    property Color default clBtnFace;
    property FullRepaint: Boolean read FFullRepaint write FFullRepaint default True;
    property Locked: Boolean read FLocked write FLocked default False;
    property ParentColor default False;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TPanel = class(TCustomPanel)
  published
    property Align;
    property Alignment;
    property Anchors;
    property AutoSize;
    property BevelInner;
    property BevelOuter;
    property BevelWidth;
    property BiDiMode;
    property BorderWidth;
    property BorderStyle;
    property Caption;
    property Color;
    property Constraints;
    property Ctl3D;
    property UseDockManager default True;
    property DockSite;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property FullRepaint;
    property Font;
    property Locked;
    property ParentBiDiMode;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnCanResize;
    property OnClick;
    property OnConstrainedResize;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnStartDrag;
  end;

  TSplitter = class(TGraphicControl)
  private
    FMinSize: Integer;
    FOnMoved: TNotifyEvent;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align default alLeft;
    property Color;
    property MinSize: Integer read FMinSize write FMinSize default 30;
    property Visible;
    property OnMoved: TNotifyEvent read FOnMoved write FOnMoved;
  end;

procedure Frame3D(Canvas: TCanvas; var Rect: TRect; TopColor, BottomColor: TColor; Width: Integer);

implementation

uses Math;

procedure Frame3D(Canvas: TCanvas; var Rect: TRect; TopColor, BottomColor: TColor; Width: Integer);

  procedure DoRect;
  var
    TopRight, BottomLeft: TPoint;
  begin
    with Canvas, Rect do
    begin
      TopRight.X := Right;
      TopRight.Y := Top;
      BottomLeft.X := Left;
      BottomLeft.Y := Bottom;
      Pen.Color := TopColor;
      PolyLine([BottomLeft, TopLeft, TopRight]);
      Pen.Color := BottomColor;
      Dec(BottomLeft.X);
      PolyLine([TopRight, BottomRight, BottomLeft]);
    end;
  end;

begin
  Canvas.Pen.Width := 1;
  Dec(Rect.Bottom);
  Dec(Rect.Right);
  while Width > 0 do
  begin
    Dec(Width);
    DoRect;
    InflateRect(Rect, -1, -1);
  end;
  Inc(Rect.Bottom);
  Inc(Rect.Right);
end;

{ ---------------------------------------------------------------- TShape }

constructor TShape.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csReplicatable];
  Width := 65;
  Height := 65;
  FPen := TPen.Create;
  FPen.OnChange := StyleChanged;
  FBrush := TBrush.Create;
  FBrush.OnChange := StyleChanged;
end;

destructor TShape.Destroy;
begin
  FPen.Free;
  FBrush.Free;
  inherited Destroy;
end;

procedure TShape.Paint;
var
  X, Y, W, H, S: Integer;
begin
  with Canvas do
  begin
    Pen := FPen;
    Brush := FBrush;
    X := Pen.Width div 2;
    Y := X;
    W := Width - Pen.Width + 1;
    H := Height - Pen.Width + 1;
    if Pen.Width = 0 then
    begin
      Dec(W);
      Dec(H);
    end;
    if W < H then S := W else S := H;
    if FShape in [stSquare, stRoundSquare, stCircle] then
    begin
      Inc(X, (W - S) div 2);
      Inc(Y, (H - S) div 2);
      W := S;
      H := S;
    end;
    case FShape of
      stRectangle, stSquare: Rectangle(X, Y, X + W, Y + H);
      stRoundRect, stRoundSquare: RoundRect(X, Y, X + W, Y + H, S div 4, S div 4);
      stCircle, stEllipse: Ellipse(X, Y, X + W, Y + H);
    end;
  end;
end;

procedure TShape.StyleChanged(Sender: TObject);
begin
  Invalidate;
end;

procedure TShape.SetBrush(Value: TBrush);
begin
  FBrush.Assign(Value);
end;

procedure TShape.SetPen(Value: TPen);
begin
  FPen.Assign(Value);
end;

procedure TShape.SetShape(Value: TShapeType);
begin
  if FShape <> Value then
  begin
    FShape := Value;
    Invalidate;
  end;
end;

{ ---------------------------------------------------------------- TPaintBox }

constructor TPaintBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csReplicatable];
  Width := 105;
  Height := 105;
end;

procedure TPaintBox.Paint;
begin
  Canvas.Font := Font;
  Canvas.Brush.Color := Color;
  if csDesigning in ComponentState then
    with Canvas do
    begin
      Pen.Style := psDash;
      Brush.Style := bsClear;
      Rectangle(0, 0, Width, Height);
    end;
  if Assigned(FOnPaint) then FOnPaint(Self);
end;

{ ---------------------------------------------------------------- TImage }

constructor TImage.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csReplicatable];
  FPicture := TPicture.Create;
  FPicture.OnChange := PictureChanged;
  Height := 105;
  Width := 105;
end;

destructor TImage.Destroy;
begin
  FPicture.Free;
  inherited Destroy;
end;

function TImage.GetPalette: HPALETTE;
begin
  Result := 0;
  if FPicture.Graphic <> nil then Result := FPicture.Graphic.Palette;
end;

function TImage.DestRect: TRect;
begin
  if Stretch then
    Result := ClientRect
  else if Center then
    Result := Bounds((Width - Picture.Width) div 2, (Height - Picture.Height) div 2,
      Picture.Width, Picture.Height)
  else
    Result := Rect(0, 0, Picture.Width, Picture.Height);
end;

procedure TImage.Paint;
begin
  if csDesigning in ComponentState then
    with inherited Canvas do
    begin
      Pen.Style := psDash;
      Brush.Style := bsClear;
      Rectangle(0, 0, Width, Height);
    end;
  FDrawing := True;
  try
    with inherited Canvas do
      StretchDraw(DestRect, Picture.Graphic);
  finally
    FDrawing := False;
  end;
end;

function TImage.DoPaletteChange: Boolean;
begin
  Result := False;
end;

function TImage.GetCanvas: TCanvas;
var
  Bitmap: TBitmap;
begin
  if Picture.Graphic = nil then
  begin
    Bitmap := TBitmap.Create;
    try
      Bitmap.Width := Width;
      Bitmap.Height := Height;
      Picture.Graphic := Bitmap;
    finally
      Bitmap.Free;
    end;
  end;
  if Picture.Graphic is TBitmap then
    Result := TBitmap(Picture.Graphic).Canvas
  else
    raise EInvalidOperation.Create('Can only modify an image if it contains a bitmap');
end;

procedure TImage.SetCenter(Value: Boolean);
begin
  if FCenter <> Value then
  begin
    FCenter := Value;
    PictureChanged(Self);
  end;
end;

procedure TImage.SetPicture(Value: TPicture);
begin
  FPicture.Assign(Value);
end;

procedure TImage.SetStretch(Value: Boolean);
begin
  if Value <> FStretch then
  begin
    FStretch := Value;
    PictureChanged(Self);
  end;
end;

procedure TImage.SetTransparent(Value: Boolean);
begin
  if Value <> FTransparent then
  begin
    FTransparent := Value;
    PictureChanged(Self);
  end;
end;

procedure TImage.PictureChanged(Sender: TObject);
var
  G: TGraphic;
begin
  if AutoSize and (Picture.Width > 0) and (Picture.Height > 0) then
    SetBounds(Left, Top, Picture.Width, Picture.Height);
  G := Picture.Graphic;
  if G <> nil then
  begin
    if not ((G is TMetaFile) or (G is TIcon)) then G.Transparent := FTransparent;
    if (not G.Transparent) and (Stretch or (G.Width >= Width) and (G.Height >= Height)) then
      ControlStyle := ControlStyle + [csOpaque]
    else
      ControlStyle := ControlStyle - [csOpaque];
  end
  else
    ControlStyle := ControlStyle - [csOpaque];
  if not FDrawing then Invalidate;
end;

function TImage.CanAutoSize(var NewWidth, NewHeight: Integer): Boolean;
begin
  Result := True;
  if not (csDesigning in ComponentState) or (Picture.Width > 0) and (Picture.Height > 0) then
  begin
    if Align in [alNone, alLeft, alRight] then NewWidth := Picture.Width;
    if Align in [alNone, alTop, alBottom] then NewHeight := Picture.Height;
  end;
end;

{ ---------------------------------------------------------------- TBevel }

constructor TBevel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csReplicatable];
  FStyle := bsLowered;
  FShape := bsBox;
  Width := 50;
  Height := 50;
end;

procedure TBevel.SetStyle(Value: TBevelStyle);
begin
  if Value <> FStyle then
  begin
    FStyle := Value;
    Invalidate;
  end;
end;

procedure TBevel.SetShape(Value: TBevelShape);
begin
  if Value <> FShape then
  begin
    FShape := Value;
    Invalidate;
  end;
end;

procedure TBevel.Paint;
var
  Color1, Color2: TColor;
  Temp: TColor;

  procedure BevelRect(const R: TRect);
  begin
    with Canvas do
    begin
      Pen.Color := Color1;
      PolyLine([Point(R.Left, R.Bottom), Point(R.Left, R.Top), Point(R.Right, R.Top)]);
      Pen.Color := Color2;
      PolyLine([Point(R.Right, R.Top), Point(R.Right, R.Bottom), Point(R.Left, R.Bottom)]);
    end;
  end;

  procedure BevelLine(C: TColor; X1, Y1, X2, Y2: Integer);
  begin
    with Canvas do
    begin
      Pen.Color := C;
      MoveTo(X1, Y1);
      LineTo(X2, Y2);
    end;
  end;

begin
  with Canvas do
  begin
    Pen.Width := 1;
    if FStyle = bsLowered then
    begin
      Color1 := clBtnShadow;
      Color2 := clBtnHighlight;
    end
    else
    begin
      Color1 := clBtnHighlight;
      Color2 := clBtnShadow;
    end;
    case FShape of
      bsBox: BevelRect(Rect(0, 0, Width - 1, Height - 1));
      bsFrame:
        begin
          Temp := Color1;
          Color1 := Color2;
          BevelRect(Rect(1, 1, Width - 1, Height - 1));
          Color2 := Temp;
          Color1 := Temp;
          BevelRect(Rect(0, 0, Width - 2, Height - 2));
        end;
      bsTopLine:
        begin
          BevelLine(Color1, 0, 0, Width, 0);
          BevelLine(Color2, 0, 1, Width, 1);
        end;
      bsBottomLine:
        begin
          BevelLine(Color1, 0, Height - 2, Width, Height - 2);
          BevelLine(Color2, 0, Height - 1, Width, Height - 1);
        end;
      bsLeftLine:
        begin
          BevelLine(Color1, 0, 0, 0, Height);
          BevelLine(Color2, 1, 0, 1, Height);
        end;
      bsRightLine:
        begin
          BevelLine(Color1, Width - 2, 0, Width - 2, Height);
          BevelLine(Color2, Width - 1, 0, Width - 1, Height);
        end;
    end;
  end;
end;

{ ---------------------------------------------------------------- TTimer }

constructor TTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FEnabled := True;
  FInterval := 1000;
  FWindowHandle := AllocateHWnd(WndProc);
end;

destructor TTimer.Destroy;
begin
  FEnabled := False;
  UpdateTimer;
  DeallocateHWnd(FWindowHandle);
  inherited Destroy;
end;

procedure TTimer.WndProc(var Msg: TMessage);
begin
  with Msg do
    if Msg = WM_TIMER then
      try
        Timer;
      except
        Application.HandleException(Self);
      end
    else
      Result := DefWindowProc(FWindowHandle, Msg, wParam, lParam);
end;

procedure TTimer.UpdateTimer;
begin
  KillTimer(FWindowHandle, 1);
  if (FInterval <> 0) and FEnabled and Assigned(FOnTimer) then
    if SetTimer(FWindowHandle, 1, FInterval, nil) = 0 then
      raise EOutOfResources.Create('Not enough timers available');
end;

procedure TTimer.SetEnabled(Value: Boolean);
begin
  if Value <> FEnabled then
  begin
    FEnabled := Value;
    UpdateTimer;
  end;
end;

procedure TTimer.SetInterval(Value: Cardinal);
begin
  if Value <> FInterval then
  begin
    FInterval := Value;
    UpdateTimer;
  end;
end;

procedure TTimer.SetOnTimer(Value: TNotifyEvent);
begin
  FOnTimer := Value;
  UpdateTimer;
end;

procedure TTimer.Timer;
begin
  if Assigned(FOnTimer) then FOnTimer(Self);
end;

{ ---------------------------------------------------------------- TCustomPanel }

constructor TCustomPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := [csAcceptsControls, csCaptureMouse, csClickEvents, csSetCaption, csOpaque,
    csDoubleClicks, csReplicatable];
  Width := 185;
  Height := 41;
  FAlignment := taCenter;
  BevelOuter := bvRaised;
  BevelWidth := 1;
  FBorderStyle := bsNone;
  Color := clBtnFace;
  FFullRepaint := True;
  UseDockManager := True;
end;

procedure TCustomPanel.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  with Params do
  begin
    Style := Style and not WS_BORDER;
    if FBorderStyle = bsSingle then
      if NewStyleControls and Ctl3D then
        ExStyle := ExStyle or WS_EX_CLIENTEDGE
      else
        Style := Style or WS_BORDER;
  end;
end;

procedure TCustomPanel.CMTextChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;

procedure TCustomPanel.AdjustClientRect(var Rect: TRect);
var
  BevelSize: Integer;
begin
  inherited AdjustClientRect(Rect);
  BevelSize := BorderWidth;
  if BevelOuter <> bvNone then Inc(BevelSize, BevelWidth);
  if BevelInner <> bvNone then Inc(BevelSize, BevelWidth);
  InflateRect(Rect, -BevelSize, -BevelSize);
end;

procedure TCustomPanel.Paint;
const
  Alignments: array[TAlignment] of Longint = (DT_LEFT, DT_RIGHT, DT_CENTER);
var
  Rect: TRect;
  TopColor, BottomColor: TColor;
  FontHeight: Integer;
  Flags: Longint;

  procedure AdjustColors(Bevel: TPanelBevel);
  begin
    TopColor := clBtnHighlight;
    if Bevel = bvLowered then TopColor := clBtnShadow;
    BottomColor := clBtnShadow;
    if Bevel = bvLowered then BottomColor := clBtnHighlight;
  end;

begin
  Rect := GetClientRect;
  if BevelOuter <> bvNone then
  begin
    AdjustColors(BevelOuter);
    Frame3D(Canvas, Rect, TopColor, BottomColor, BevelWidth);
  end;
  Frame3D(Canvas, Rect, Color, Color, BorderWidth);
  if BevelInner <> bvNone then
  begin
    AdjustColors(BevelInner);
    Frame3D(Canvas, Rect, TopColor, BottomColor, BevelWidth);
  end;
  with Canvas do
  begin
    Brush.Color := Color;
    Brush.Style := bsSolid;
    FillRect(Rect);
    Brush.Style := bsClear;
    Font := Self.Font;
    FontHeight := TextHeight('W');
    with Rect do
    begin
      Top := ((Bottom + Top) - FontHeight) div 2;
      Bottom := Top + FontHeight;
    end;
    Flags := DT_EXPANDTABS or DT_VCENTER or Alignments[FAlignment];
    DrawText(Handle, PChar(Caption), -1, Rect, Flags);
  end;
end;

procedure TCustomPanel.SetAlignment(Value: TAlignment);
begin
  FAlignment := Value;
  Invalidate;
end;

procedure TCustomPanel.SetBevelInner(Value: TPanelBevel);
begin
  FBevelInner := Value;
  Realign;
  Invalidate;
end;

procedure TCustomPanel.SetBevelOuter(Value: TPanelBevel);
begin
  FBevelOuter := Value;
  Realign;
  Invalidate;
end;

procedure TCustomPanel.SetBevelWidth(Value: TBevelWidth);
begin
  FBevelWidth := Value;
  Realign;
  Invalidate;
end;

procedure TCustomPanel.SetBorderStyle(Value: TBorderStyle);
begin
  if FBorderStyle <> Value then
  begin
    FBorderStyle := Value;
    if HandleAllocated then RecreateWnd;
  end;
end;

{ ---------------------------------------------------------------- TSplitter }

constructor TSplitter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Align := alLeft;
  Width := 3;
  FMinSize := 30;
end;

procedure TSplitter.Paint;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);
end;

initialization
  RegisterClasses([TShape, TPaintBox, TImage, TBevel, TTimer, TPanel, TSplitter]);
end.

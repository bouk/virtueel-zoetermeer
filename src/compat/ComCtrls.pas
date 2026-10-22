unit ComCtrls;

{ Delphi 5-subset van de ComCtrls-unit: TTabControl (met OwnerDraw/MultiLine), TPageControl/
  TTabSheet, TProgressBar, TStatusBar en TTrackBar, getekend in de klassieke stijl. }

{$MODE DELPHI}{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ZMDraw;

type
  TTabPosition = (tpTop, tpBottom, tpLeft, tpRight);
  TTabStyle = (tsTabs, tsButtons, tsFlatButtons);
  TCustomTabControl = class;
  TTabChangingEvent = procedure(Sender: TObject; var AllowChange: Boolean) of object;
  TDrawTabEvent = procedure(Control: TCustomTabControl; TabIndex: Integer;
    const Rect: TRect; Active: Boolean) of object;
  TTabGetImageEvent = procedure(Sender: TObject; TabIndex: Integer; var ImageIndex: Integer) of object;

  TCustomTabControl = class(TWinControl)
  private
    FCanvas: TCanvas;
    FTabs: TStrings;
    FTabIndex: Integer;
    FMultiLine: Boolean;
    FOwnerDraw: Boolean;
    FTabHeight: Smallint;
    FTabWidth: Smallint;
    FTabPosition: TTabPosition;
    FStyle: TTabStyle;
    FHotTrack: Boolean;
    FRaggedRight: Boolean;
    FScrollOpposite: Boolean;
    FMultiSelect: Boolean;
    FFirstTab: Integer;
    FRects: array of TRect;
    FRows: Integer;
    FRectsValid: Boolean;
    FOnChange: TNotifyEvent;
    FOnChanging: TTabChangingEvent;
    FOnDrawTab: TDrawTabEvent;
    FOnGetImageIndex: TTabGetImageEvent;
    function GetDisplayRect: TRect;
    function GetTabIndex: Integer;
    procedure SetMultiLine(Value: Boolean);
    procedure SetOwnerDraw(Value: Boolean);
    procedure SetTabHeight(Value: Smallint);
    procedure SetTabIndex(Value: Integer);
    procedure SetTabPosition(Value: TTabPosition);
    procedure SetTabs(Value: TStrings);
    procedure SetTabWidth(Value: Smallint);
    procedure TabsChanged(Sender: TObject);
    procedure LayoutTabs;
    function RowHeight: Integer;
    procedure WMSize(var Message: TWMSize); message WM_SIZE;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
  protected
    procedure AdjustClientRect(var Rect: TRect); override;
    function CanChange: Boolean; dynamic;
    function CanShowTab(TabIndex: Integer): Boolean; virtual;
    procedure Change; dynamic;
    procedure DrawTab(TabIndex: Integer; const Rect: TRect; Active: Boolean); virtual;
    function GetImageIndex(TabIndex: Integer): Integer; virtual;
    procedure PaintWindow(DC: HDC); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDownDefault(var Message: TWMKey); override;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    property DisplayRect: TRect read GetDisplayRect;
    property HotTrack: Boolean read FHotTrack write FHotTrack default False;
    property MultiLine: Boolean read FMultiLine write SetMultiLine default False;
    property MultiSelect: Boolean read FMultiSelect write FMultiSelect default False;
    property OwnerDraw: Boolean read FOwnerDraw write SetOwnerDraw default False;
    property RaggedRight: Boolean read FRaggedRight write FRaggedRight default False;
    property ScrollOpposite: Boolean read FScrollOpposite write FScrollOpposite default False;
    property Style: TTabStyle read FStyle write FStyle default tsTabs;
    property TabHeight: Smallint read FTabHeight write SetTabHeight default 0;
    property TabIndex: Integer read GetTabIndex write SetTabIndex default -1;
    property TabPosition: TTabPosition read FTabPosition write SetTabPosition default tpTop;
    property Tabs: TStrings read FTabs write SetTabs;
    property TabWidth: Smallint read FTabWidth write SetTabWidth default 0;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnChanging: TTabChangingEvent read FOnChanging write FOnChanging;
    property OnDrawTab: TDrawTabEvent read FOnDrawTab write FOnDrawTab;
    property OnGetImageIndex: TTabGetImageEvent read FOnGetImageIndex write FOnGetImageIndex;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function IndexOfTabAt(X, Y: Integer): Integer;
    function GetHitTestInfoAt(X, Y: Integer): Integer;
    function TabRect(Index: Integer): TRect;
    procedure ScrollTabs(Delta: Integer);
    property Canvas: TCanvas read FCanvas;
    property TabStop default True;
  end;

  TTabControl = class(TCustomTabControl)
  public
    property DisplayRect;
  published
    property Align;
    property Anchors;
    property BiDiMode;
    property Constraints;
    property DockSite;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property HotTrack;
    property MultiLine;
    property MultiSelect;
    property OwnerDraw;
    property ParentBiDiMode;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property RaggedRight;
    property ScrollOpposite;
    property ShowHint;
    property Style;
    property TabHeight;
    property TabOrder;
    property TabPosition;
    property Tabs;
    property TabIndex;
    property TabStop;
    property TabWidth;
    property Visible;
    property OnChange;
    property OnChanging;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnDrawTab;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnGetImageIndex;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnResize;
    property OnStartDrag;
  end;

  TPageControl = class;

  TTabSheet = class(TWinControl)
  private
    FPageControl: TPageControl;
    FTabVisible: Boolean;
    FImageIndex: Integer;
    FOnShow: TNotifyEvent;
    FOnHide: TNotifyEvent;
    function GetPageIndex: Integer;
    procedure SetPageControl(APageControl: TPageControl);
    procedure SetPageIndex(Value: Integer);
    procedure SetTabVisible(Value: Boolean);
  protected
    procedure ReadState(Reader: TReader); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property PageControl: TPageControl read FPageControl write SetPageControl;
  published
    property Caption;
    property Color;
    property Enabled;
    property Font;
    property ImageIndex: Integer read FImageIndex write FImageIndex default 0;
    property PageIndex: Integer read GetPageIndex write SetPageIndex stored False;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property ShowHint;
    property TabVisible: Boolean read FTabVisible write SetTabVisible default True;
    property Visible stored False;
    property OnHide: TNotifyEvent read FOnHide write FOnHide;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
  end;

  TPageControl = class(TCustomTabControl)
  private
    FPages: TList;
    FActivePage: TTabSheet;
    function GetActivePageIndex: Integer;
    function GetPage(Index: Integer): TTabSheet;
    function GetPageCount: Integer;
    procedure InsertPage(Page: TTabSheet);
    procedure RemovePage(Page: TTabSheet);
    procedure SetActivePage(Page: TTabSheet);
    procedure SetActivePageIndex(const Value: Integer);
    procedure UpdateTabs;
  protected
    procedure Change; override;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    procedure SetChildOrder(Child: TComponent; Order: Integer); override;
    procedure ShowControl(AControl: TControl); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function FindNextPage(CurPage: TTabSheet; GoForward, CheckTabVisible: Boolean): TTabSheet;
    procedure SelectNextPage(GoForward: Boolean);
    property ActivePageIndex: Integer read GetActivePageIndex write SetActivePageIndex;
    property PageCount: Integer read GetPageCount;
    property Pages[Index: Integer]: TTabSheet read GetPage;
  published
    property ActivePage: TTabSheet read FActivePage write SetActivePage;
    property Align;
    property Anchors;
    property Enabled;
    property Font;
    property HotTrack;
    property MultiLine;
    property OwnerDraw;
    property ParentFont;
    property ParentShowHint;
    property ShowHint;
    property TabHeight;
    property TabOrder;
    property TabPosition;
    property TabStop;
    property TabWidth;
    property Visible;
    property OnChange;
    property OnChanging;
    property OnDrawTab;
    property OnEnter;
    property OnExit;
  end;

  TProgressBarOrientation = (pbHorizontal, pbVertical);
  TProgressBar = class(TWinControl)
  private
    FMin, FMax, FPosition: Integer;
    FStep: Integer;
    FSmooth: Boolean;
    FOrientation: TProgressBarOrientation;
    procedure SetMin(Value: Integer);
    procedure SetMax(Value: Integer);
    procedure SetPosition(Value: Integer);
  protected
    procedure PaintWindow(DC: HDC); override;
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure StepIt;
    procedure StepBy(Delta: Integer);
  published
    property Align;
    property Anchors;
    property Enabled;
    property Min: Integer read FMin write SetMin default 0;
    property Max: Integer read FMax write SetMax default 100;
    property Orientation: TProgressBarOrientation read FOrientation write FOrientation default pbHorizontal;
    property Position: Integer read FPosition write SetPosition default 0;
    property Smooth: Boolean read FSmooth write FSmooth default False;
    property Step: Integer read FStep write FStep default 10;
    property Visible;
  end;

  TStatusBar = class(TWinControl)
  private
    FSimpleText: string;
    FSimplePanel: Boolean;
    procedure SetSimpleText(const Value: string);
  protected
    procedure PaintWindow(DC: HDC); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align default alBottom;
    property Font;
    property SimplePanel: Boolean read FSimplePanel write FSimplePanel default False;
    property SimpleText: string read FSimpleText write SetSimpleText;
    property Visible;
  end;

  TTrackBarOrientation = (trHorizontal, trVertical);
  TTrackBar = class(TWinControl)
  private
    FMin, FMax, FPosition, FFrequency: Integer;
    FOrientation: TTrackBarOrientation;
    FOnChange: TNotifyEvent;
    procedure SetPosition(Value: Integer);
  protected
    procedure PaintWindow(DC: HDC); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property Enabled;
    property Frequency: Integer read FFrequency write FFrequency default 1;
    property Max: Integer read FMax write FMax default 10;
    property Min: Integer read FMin write FMin default 0;
    property Orientation: TTrackBarOrientation read FOrientation write FOrientation default trHorizontal;
    property Position: Integer read FPosition write SetPosition default 0;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  end;

implementation

uses Math;

{ ---------------------------------------------------------------- TCustomTabControl }

type
  TTabStrings = class(TStringList);

constructor TCustomTabControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 289;
  Height := 193;
  TabStop := True;
  ControlStyle := [csAcceptsControls, csDoubleClicks];
  FTabs := TTabStrings.Create;
  TStringList(FTabs).OnChange := TabsChanged;
  FTabIndex := -1;
  FCanvas := TControlCanvas.Create;
  TControlCanvas(FCanvas).Control := Self;
end;

destructor TCustomTabControl.Destroy;
begin
  TStringList(FTabs).OnChange := nil;
  FTabs.Free;
  FCanvas.Free;
  inherited Destroy;
end;

procedure TCustomTabControl.TabsChanged(Sender: TObject);
begin
  if FTabIndex >= FTabs.Count then FTabIndex := FTabs.Count - 1;
  if (FTabIndex < 0) and (FTabs.Count > 0) then FTabIndex := 0;
  FRectsValid := False;
  Realign;
  Invalidate;
end;

procedure TCustomTabControl.SetTabs(Value: TStrings);
begin
  FTabs.Assign(Value);
end;

function TCustomTabControl.GetTabIndex: Integer;
begin
  Result := FTabIndex;
end;

procedure TCustomTabControl.SetTabIndex(Value: Integer);
begin
  if (Value < -1) or (Value >= FTabs.Count) then Exit;
  if FTabIndex <> Value then
  begin
    FTabIndex := Value;
    FRectsValid := False;
    Invalidate;
  end;
end;

procedure TCustomTabControl.SetMultiLine(Value: Boolean);
begin
  FMultiLine := Value;
  FRectsValid := False;
  Realign;
  Invalidate;
end;

procedure TCustomTabControl.SetOwnerDraw(Value: Boolean);
begin
  FOwnerDraw := Value;
  Invalidate;
end;

procedure TCustomTabControl.SetTabHeight(Value: Smallint);
begin
  FTabHeight := Value;
  FRectsValid := False;
  Realign;
  Invalidate;
end;

procedure TCustomTabControl.SetTabWidth(Value: Smallint);
begin
  FTabWidth := Value;
  FRectsValid := False;
  Realign;
  Invalidate;
end;

procedure TCustomTabControl.SetTabPosition(Value: TTabPosition);
begin
  FTabPosition := Value;
  Invalidate;
end;

function TCustomTabControl.RowHeight: Integer;
begin
  if FTabHeight > 0 then Exit(FTabHeight);
  FCanvas.Font := Font;
  if not FCanvas.HandleAllocated then
    Result := Abs(Font.Height) + 9
  else
    Result := FCanvas.TextHeight('Ag') + 5;
end;

procedure TCustomTabControl.LayoutTabs;
var
  I, X, Row, W, H, MaxW, DC: Integer;
  RowStart: array of Integer;
  Widths: array of Integer;
  C: TCanvas;
  Shift, ActRow, J, K, Extra, N: Integer;
  RowOf: array of Integer;
begin
  FRectsValid := True;
  SetLength(FRects, FTabs.Count);
  if FTabs.Count = 0 then
  begin
    FRows := 0;
    Exit;
  end;
  C := TCanvas.Create;
  DC := GetDC(0);
  try
    C.Handle := DC;
    C.Font := Font;
    SetLength(Widths, FTabs.Count);
    for I := 0 to FTabs.Count - 1 do
      if FTabWidth > 0 then Widths[I] := FTabWidth
      else Widths[I] := C.TextWidth(FTabs[I]) + 12;
    H := FTabHeight;
    if H <= 0 then H := C.TextHeight('Ag') + 5;
    C.Handle := 0;
  finally
    ReleaseDC(0, DC);
    C.Free;
  end;
  MaxW := Width - 4;
  SetLength(RowOf, FTabs.Count);
  Row := 0;
  X := 0;
  for I := 0 to FTabs.Count - 1 do
  begin
    W := Widths[I];
    if FMultiLine and (X > 0) and (X + W > MaxW) then
    begin
      Inc(Row);
      X := 0;
    end;
    RowOf[I] := Row;
    FRects[I] := Rect(2 + X, 0, 2 + X + W, H);
    Inc(X, W);
  end;
  FRows := Row + 1;
  { rijen over de volle breedte uitrekken (niet ongelijk) bij meerdere regels }
  if FMultiLine and (FRows > 1) and not FRaggedRight then
    for K := 0 to FRows - 1 do
    begin
      N := 0;
      X := 0;
      for I := 0 to FTabs.Count - 1 do
        if RowOf[I] = K then
        begin
          Inc(N);
          X := FRects[I].Right - 2;
        end;
      if N = 0 then Continue;
      Extra := MaxW - X;
      J := 0;
      Shift := 0;
      for I := 0 to FTabs.Count - 1 do
        if RowOf[I] = K then
        begin
          FRects[I].Left := FRects[I].Left + Shift;
          Inc(Shift, Extra div N + Ord(J < Extra mod N));
          FRects[I].Right := FRects[I].Right + Shift;
          Inc(J);
        end;
    end;
  { de rij van het geselecteerde tabblad wordt naast het clientgebied geplaatst (onderste rij) }
  ActRow := FRows - 1;
  if (FTabIndex >= 0) and (FTabIndex < FTabs.Count) then ActRow := RowOf[FTabIndex];
  for I := 0 to FTabs.Count - 1 do
  begin
    K := RowOf[I];
    if K = ActRow then K := FRows - 1
    else if K > ActRow then Dec(K);
    OffsetRect(FRects[I], 0, 2 + K * H);
  end;
  SetLength(RowStart, 0);
end;

function TCustomTabControl.TabRect(Index: Integer): TRect;
begin
  if not FRectsValid then LayoutTabs;
  if (Index >= 0) and (Index <= High(FRects)) then Result := FRects[Index]
  else Result := Rect(0, 0, 0, 0);
end;

function TCustomTabControl.GetDisplayRect: TRect;
var
  Top: Integer;
begin
  if not FRectsValid then LayoutTabs;
  if FTabs.Count > 0 then
    Top := FRects[0].Bottom + (FRows - 1) * 0
  else
    Top := 0;
  if FTabs.Count > 0 then
  begin
    Top := 0;
    if Length(FRects) > 0 then
      Top := FRects[0].Bottom;
    Top := 2 + FRows * (FRects[0].Bottom - FRects[0].Top);
  end;
  Result := Rect(4, Top + 4, Width - 4, Height - 4);
  if FTabs.Count = 0 then Result.Top := 6;
end;

procedure TCustomTabControl.AdjustClientRect(var Rect: TRect);
begin
  Rect := DisplayRect;
  inherited AdjustClientRect(Rect);
end;

procedure TCustomTabControl.WMSize(var Message: TWMSize);
begin
  FRectsValid := False;
  inherited;
end;

procedure TCustomTabControl.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TCustomTabControl.CMFontChanged(var Message: TMessage);
begin
  inherited;
  FRectsValid := False;
  Realign;
end;

function TCustomTabControl.CanChange: Boolean;
begin
  Result := True;
  if Assigned(FOnChanging) then FOnChanging(Self, Result);
end;

function TCustomTabControl.CanShowTab(TabIndex: Integer): Boolean;
begin
  Result := True;
end;

procedure TCustomTabControl.Change;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

function TCustomTabControl.GetImageIndex(TabIndex: Integer): Integer;
begin
  Result := TabIndex;
  if Assigned(FOnGetImageIndex) then FOnGetImageIndex(Self, TabIndex, Result);
end;

procedure TCustomTabControl.DrawTab(TabIndex: Integer; const Rect: TRect; Active: Boolean);
begin
  if Assigned(FOnDrawTab) then
    FOnDrawTab(Self, TabIndex, Rect, Active)
  else
    FCanvas.FillRect(Rect);
end;

procedure TCustomTabControl.PaintWindow(DC: HDC);
var
  I: Integer;
  R, DR: TRect;
  Active: Boolean;
  Order: array of Integer;
begin
  if not FRectsValid then LayoutTabs;
  FCanvas.Handle := DC;
  try
    FCanvas.Font := Font;
    FCanvas.Brush.Color := clBtnFace;
    FCanvas.Brush.Style := bsSolid;
    FCanvas.FillRect(ClientRect);
    DR := DisplayRect;
    InflateRect(DR, 2, 2);
    Dec(DR.Top, 0);
    ZMFrame3D(FCanvas, DR, clBtnHighlight, cl3DDkShadow);
    InflateRect(DR, -1, -1);
    ZMFrame3D(FCanvas, DR, cl3DLight, clBtnShadow);
    SetLength(Order, FTabs.Count);
    for I := 0 to FTabs.Count - 1 do Order[I] := I;
    for I := 0 to FTabs.Count - 1 do
    begin
      R := FRects[I];
      Active := I = FTabIndex;
      if Active then
      begin
        InflateRect(R, 2, 2);
        Inc(R.Bottom, 0);
      end;
      FCanvas.Brush.Color := clBtnFace;
      FCanvas.FillRect(R);
      FCanvas.Pen.Color := clBtnHighlight;
      FCanvas.MoveTo(R.Left, R.Bottom - 1);
      FCanvas.LineTo(R.Left, R.Top + 2);
      FCanvas.LineTo(R.Left + 2, R.Top);
      FCanvas.LineTo(R.Right - 2, R.Top);
      FCanvas.Pen.Color := cl3DDkShadow;
      FCanvas.MoveTo(R.Right - 2, R.Top + 1);
      FCanvas.LineTo(R.Right - 1, R.Top + 2);
      FCanvas.LineTo(R.Right - 1, R.Bottom);
      FCanvas.Pen.Color := clBtnShadow;
      FCanvas.MoveTo(R.Right - 2, R.Top + 2);
      FCanvas.LineTo(R.Right - 2, R.Bottom);
      if Active then
      begin
        { samenvoegen met het kaderlijn van het clientgebied }
        FCanvas.Pen.Color := clBtnFace;
        FCanvas.MoveTo(R.Left + 1, R.Bottom);
        FCanvas.LineTo(R.Right - 2, R.Bottom);
        FCanvas.MoveTo(R.Left + 1, R.Bottom + 1);
        FCanvas.LineTo(R.Right - 2, R.Bottom + 1);
      end;
      InflateRect(R, -3, -2);
      if FOwnerDraw then
      begin
        FCanvas.Brush.Color := clBtnFace;
        FCanvas.Font := Font;
        DrawTab(I, R, Active);
      end
      else
      begin
        FCanvas.Brush.Style := bsClear;
        DrawText(FCanvas.Handle, PChar(FTabs[I]), Length(FTabs[I]), R,
          DT_CENTER or DT_VCENTER or DT_SINGLELINE);
        if Active and Focused then
        begin
          FCanvas.Brush.Style := bsSolid;
          FCanvas.DrawFocusRect(R);
        end;
      end;
    end;
  finally
    FCanvas.Handle := 0;
  end;
end;

function TCustomTabControl.IndexOfTabAt(X, Y: Integer): Integer;
var
  I: Integer;
begin
  if not FRectsValid then LayoutTabs;
  for I := 0 to High(FRects) do
    if PtInRect(FRects[I], Point(X, Y)) then Exit(I);
  Result := -1;
end;

function TCustomTabControl.GetHitTestInfoAt(X, Y: Integer): Integer;
begin
  if IndexOfTabAt(X, Y) >= 0 then Result := 1 else Result := 0;
end;

procedure TCustomTabControl.ScrollTabs(Delta: Integer);
begin
end;

procedure TCustomTabControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  if Button = mbLeft then
  begin
    I := IndexOfTabAt(X, Y);
    if (I >= 0) and (I <> FTabIndex) then
    begin
      if CanFocus then SetFocus;
      if CanChange then
      begin
        FTabIndex := I;
        FRectsValid := False;
        Invalidate;
        Change;
      end;
    end;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCustomTabControl.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS;
end;

procedure TCustomTabControl.KeyDownDefault(var Message: TWMKey);
var
  N: Integer;
begin
  N := FTabIndex;
  case Message.CharCode of
    VK_LEFT, VK_UP: Dec(N);
    VK_RIGHT, VK_DOWN: Inc(N);
  else
    inherited KeyDownDefault(Message);
    Exit;
  end;
  if (N >= 0) and (N < FTabs.Count) and (N <> FTabIndex) and CanChange then
  begin
    FTabIndex := N;
    FRectsValid := False;
    Invalidate;
    Change;
  end;
end;

{ ---------------------------------------------------------------- TTabSheet / TPageControl }

constructor TTabSheet.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Align := alClient;
  ControlStyle := ControlStyle + [csAcceptsControls, csNoDesignVisible];
  Visible := False;
  FTabVisible := True;
end;

destructor TTabSheet.Destroy;
begin
  if FPageControl <> nil then FPageControl.RemovePage(Self);
  inherited Destroy;
end;

function TTabSheet.GetPageIndex: Integer;
begin
  if FPageControl <> nil then Result := FPageControl.FPages.IndexOf(Self) else Result := -1;
end;

procedure TTabSheet.ReadState(Reader: TReader);
begin
  inherited ReadState(Reader);
  if Reader.Parent is TPageControl then PageControl := TPageControl(Reader.Parent);
end;

procedure TTabSheet.SetPageControl(APageControl: TPageControl);
begin
  if FPageControl <> APageControl then
  begin
    if FPageControl <> nil then FPageControl.RemovePage(Self);
    Parent := APageControl;
    if APageControl <> nil then APageControl.InsertPage(Self);
  end;
end;

procedure TTabSheet.SetPageIndex(Value: Integer);
var
  I: Integer;
begin
  if FPageControl <> nil then
  begin
    I := FPageControl.FPages.IndexOf(Self);
    if (I >= 0) and (Value >= 0) and (Value < FPageControl.FPages.Count) then
    begin
      FPageControl.FPages.Move(I, Value);
      FPageControl.UpdateTabs;
    end;
  end;
end;

procedure TTabSheet.SetTabVisible(Value: Boolean);
begin
  FTabVisible := Value;
  if FPageControl <> nil then FPageControl.UpdateTabs;
end;

constructor TPageControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPages := TList.Create;
end;

destructor TPageControl.Destroy;
var
  I: Integer;
begin
  for I := 0 to FPages.Count - 1 do TTabSheet(FPages[I]).FPageControl := nil;
  FPages.Free;
  inherited Destroy;
end;

procedure TPageControl.Loaded;
begin
  inherited Loaded;
  UpdateTabs;
end;

procedure TPageControl.UpdateTabs;
var
  I: Integer;
begin
  Tabs.BeginUpdate;
  try
    Tabs.Clear;
    for I := 0 to FPages.Count - 1 do
      if TTabSheet(FPages[I]).TabVisible then
        Tabs.AddObject(TTabSheet(FPages[I]).Caption, TObject(FPages[I]));
  finally
    Tabs.EndUpdate;
  end;
  if FActivePage <> nil then TabIndex := Tabs.IndexOfObject(FActivePage);
end;

function TPageControl.GetPage(Index: Integer): TTabSheet;
begin
  Result := TTabSheet(FPages[Index]);
end;

function TPageControl.GetPageCount: Integer;
begin
  Result := FPages.Count;
end;

procedure TPageControl.InsertPage(Page: TTabSheet);
begin
  FPages.Add(Page);
  Page.FPageControl := Self;
  UpdateTabs;
end;

procedure TPageControl.RemovePage(Page: TTabSheet);
begin
  if FActivePage = Page then SetActivePage(nil);
  FPages.Remove(Page);
  Page.FPageControl := nil;
  UpdateTabs;
end;

procedure TPageControl.SetActivePage(Page: TTabSheet);
begin
  if (Page <> nil) and (Page.PageControl <> Self) then Exit;
  if FActivePage <> Page then
  begin
    if FActivePage <> nil then FActivePage.Visible := False;
    FActivePage := Page;
    if Page <> nil then
    begin
      Page.Visible := True;
      Page.BringToFront;
      TabIndex := Tabs.IndexOfObject(Page);
    end;
  end;
end;

function TPageControl.GetActivePageIndex: Integer;
begin
  if FActivePage <> nil then Result := FPages.IndexOf(FActivePage) else Result := -1;
end;

procedure TPageControl.SetActivePageIndex(const Value: Integer);
begin
  if (Value >= 0) and (Value < FPages.Count) then SetActivePage(TTabSheet(FPages[Value]))
  else SetActivePage(nil);
end;

procedure TPageControl.Change;
begin
  if (TabIndex >= 0) and (TabIndex < Tabs.Count) then
    SetActivePage(TTabSheet(Tabs.Objects[TabIndex]));
  inherited Change;
end;

procedure TPageControl.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I: Integer;
begin
  for I := 0 to FPages.Count - 1 do Proc(TComponent(FPages[I]));
end;

procedure TPageControl.SetChildOrder(Child: TComponent; Order: Integer);
begin
  TTabSheet(Child).PageIndex := Order;
end;

procedure TPageControl.ShowControl(AControl: TControl);
begin
  if (AControl is TTabSheet) and (TTabSheet(AControl).PageControl = Self) then
    SetActivePage(TTabSheet(AControl));
  inherited ShowControl(AControl);
end;

function TPageControl.FindNextPage(CurPage: TTabSheet; GoForward, CheckTabVisible: Boolean): TTabSheet;
var
  I: Integer;
begin
  Result := nil;
  if FPages.Count = 0 then Exit;
  I := FPages.IndexOf(CurPage);
  if GoForward then I := (I + 1) mod FPages.Count
  else if I <= 0 then I := FPages.Count - 1
  else Dec(I);
  Result := TTabSheet(FPages[I]);
end;

procedure TPageControl.SelectNextPage(GoForward: Boolean);
begin
  SetActivePage(FindNextPage(FActivePage, GoForward, True));
end;

{ ---------------------------------------------------------------- TProgressBar }

constructor TProgressBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 150;
  Height := 16;
  FMax := 100;
  FStep := 10;
end;

procedure TProgressBar.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := Params.ExStyle or WS_EX_STATICEDGE;
end;

procedure TProgressBar.SetMin(Value: Integer);
begin
  FMin := Value;
  Invalidate;
end;

procedure TProgressBar.SetMax(Value: Integer);
begin
  FMax := Value;
  Invalidate;
end;

procedure TProgressBar.SetPosition(Value: Integer);
begin
  if Value < FMin then Value := FMin;
  if Value > FMax then Value := FMax;
  FPosition := Value;
  Invalidate;
end;

procedure TProgressBar.StepIt;
begin
  SetPosition(FPosition + FStep);
end;

procedure TProgressBar.StepBy(Delta: Integer);
begin
  SetPosition(FPosition + Delta);
end;

procedure TProgressBar.PaintWindow(DC: HDC);
var
  C: TCanvas;
  R: TRect;
  W, X: Integer;
begin
  C := TCanvas.Create;
  try
    C.Handle := DC;
    R := ClientRect;
    C.Brush.Color := clBtnFace;
    C.FillRect(R);
    if FMax > FMin then W := (R.Right - 2) * (FPosition - FMin) div (FMax - FMin) else W := 0;
    C.Brush.Color := clHighlight;
    X := 1;
    while X < W do
    begin
      C.FillRect(Rect(X, 1, Math.Min(X + 8, W), R.Bottom - 1));
      Inc(X, 10);
    end;
    C.Handle := 0;
  finally
    C.Free;
  end;
end;

{ ---------------------------------------------------------------- TStatusBar }

constructor TStatusBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Height := 19;
  Align := alBottom;
  Color := clBtnFace;
end;

procedure TStatusBar.SetSimpleText(const Value: string);
begin
  FSimpleText := Value;
  Invalidate;
end;

procedure TStatusBar.PaintWindow(DC: HDC);
var
  C: TCanvas;
  R: TRect;
begin
  C := TCanvas.Create;
  try
    C.Handle := DC;
    R := ClientRect;
    C.Brush.Color := clBtnFace;
    C.FillRect(R);
    InflateRect(R, -2, -2);
    ZMFrame3D(C, R, clBtnShadow, clBtnHighlight);
    C.Font := Font;
    C.Brush.Style := bsClear;
    C.TextOut(R.Left + 2, R.Top + 1, FSimpleText);
    C.Handle := 0;
  finally
    C.Free;
  end;
end;

{ ---------------------------------------------------------------- TTrackBar }

constructor TTrackBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 150;
  Height := 45;
  FMax := 10;
  FFrequency := 1;
  TabStop := True;
end;

procedure TTrackBar.SetPosition(Value: Integer);
begin
  if Value < FMin then Value := FMin;
  if Value > FMax then Value := FMax;
  if FPosition <> Value then
  begin
    FPosition := Value;
    Invalidate;
    if Assigned(FOnChange) then FOnChange(Self);
  end;
end;

procedure TTrackBar.PaintWindow(DC: HDC);
var
  C: TCanvas;
  R, T: TRect;
  X: Integer;
begin
  C := TCanvas.Create;
  try
    C.Handle := DC;
    R := ClientRect;
    C.Brush.Color := clBtnFace;
    C.FillRect(R);
    T := Rect(8, Height div 2 - 2, Width - 8, Height div 2 + 2);
    ZMDrawSunken(C, T);
    if FMax > FMin then X := 8 + (Width - 16) * (FPosition - FMin) div (FMax - FMin) else X := 8;
    T := Rect(X - 5, Height div 2 - 10, X + 6, Height div 2 + 10);
    ZMDrawRaised(C, T);
    C.Brush.Color := clBtnFace;
    C.FillRect(T);
    C.Handle := 0;
  finally
    C.Free;
  end;
end;

procedure TTrackBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and (Width > 16) then
    SetPosition(FMin + (X - 8) * (FMax - FMin) div (Width - 16));
end;

procedure TTrackBar.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
  if (ssLeft in Shift) and (Width > 16) then
    SetPosition(FMin + (X - 8) * (FMax - FMin) div (Width - 16));
end;

initialization
  RegisterClasses([TTabControl, TPageControl, TTabSheet, TProgressBar, TStatusBar, TTrackBar]);
end.

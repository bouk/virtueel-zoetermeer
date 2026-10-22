unit Controls;

{ Delphi 5 Controls-unit, draagbaar: TControl, TWinControl, TGraphicControl,
  TCustomControl, TControlCanvas, TImageList (minimaal), muis- en toetsenbordroutering.

  TWinControls bezitten eigen vensters van de compat-vensterbeheerder (ZMWin); grafische
  besturingselementen tekenen binnen de WM_PAINT van hun bovenliggende element. De structuur
  volgt de VCL (WndProc, berichtafhandelaars, Perform, PaintHandler/PaintControls,
  AlignControls), zodat spelcode die die methoden overschrijft zich net als op Windows
  gedraagt. }

{$MODE DELPHI}{$H+}{$R-}{$Q-}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Menus;

type
  TCursorBase = -32768..32767;
  TCursor = -32768..32767;

const
  { VCL-berichten voor besturingselementen }
  CM_BASE = $B000;
  CM_ACTIVATE = CM_BASE + 0;
  CM_DEACTIVATE = CM_BASE + 1;
  CM_GOTFOCUS = CM_BASE + 2;
  CM_LOSTFOCUS = CM_BASE + 3;
  CM_CANCELMODE = CM_BASE + 4;
  CM_DIALOGKEY = CM_BASE + 5;
  CM_DIALOGCHAR = CM_BASE + 6;
  CM_FOCUSCHANGED = CM_BASE + 7;
  CM_PARENTFONTCHANGED = CM_BASE + 8;
  CM_PARENTCOLORCHANGED = CM_BASE + 9;
  CM_HITTEST = CM_BASE + 10;
  CM_VISIBLECHANGED = CM_BASE + 11;
  CM_ENABLEDCHANGED = CM_BASE + 12;
  CM_COLORCHANGED = CM_BASE + 13;
  CM_FONTCHANGED = CM_BASE + 14;
  CM_CURSORCHANGED = CM_BASE + 15;
  CM_CTL3DCHANGED = CM_BASE + 16;
  CM_PARENTCTL3DCHANGED = CM_BASE + 17;
  CM_TEXTCHANGED = CM_BASE + 18;
  CM_MOUSEENTER = CM_BASE + 19;
  CM_MOUSELEAVE = CM_BASE + 20;
  CM_MENUCHANGED = CM_BASE + 21;
  CM_APPKEYDOWN = CM_BASE + 22;
  CM_APPSYSCOMMAND = CM_BASE + 23;
  CM_BUTTONPRESSED = CM_BASE + 24;
  CM_SHOWINGCHANGED = CM_BASE + 25;
  CM_ENTER = CM_BASE + 26;
  CM_EXIT = CM_BASE + 27;
  CM_DESIGNHITTEST = CM_BASE + 28;
  CM_ICONCHANGED = CM_BASE + 29;
  CM_WANTSPECIALKEY = CM_BASE + 30;
  CM_INVOKEHELP = CM_BASE + 31;
  CM_WINDOWHOOK = CM_BASE + 32;
  CM_RELEASE = CM_BASE + 33;
  CM_SHOWHINTCHANGED = CM_BASE + 34;
  CM_PARENTSHOWHINTCHANGED = CM_BASE + 35;
  CM_SYSCOLORCHANGE = CM_BASE + 36;
  CM_WININICHANGE = CM_BASE + 37;
  CM_FONTCHANGE = CM_BASE + 38;
  CM_TIMECHANGE = CM_BASE + 39;
  CM_TABSTOPCHANGED = CM_BASE + 40;
  CM_UIACTIVATE = CM_BASE + 41;
  CM_UIDEACTIVATE = CM_BASE + 42;
  CM_DOCWINDOWACTIVATE = CM_BASE + 43;
  CM_CONTROLLISTCHANGE = CM_BASE + 44;
  CM_GETDATALINK = CM_BASE + 45;
  CM_CHILDKEY = CM_BASE + 46;
  CM_DRAG = CM_BASE + 47;
  CM_HINTSHOW = CM_BASE + 48;
  CM_DIALOGHANDLE = CM_BASE + 49;
  CM_ISTOOLCONTROL = CM_BASE + 50;
  CM_RECREATEWND = CM_BASE + 51;
  CM_INVALIDATE = CM_BASE + 52;
  CM_SYSFONTCHANGED = CM_BASE + 53;
  CM_CONTROLCHANGE = CM_BASE + 54;
  CM_CHANGED = CM_BASE + 55;
  CM_DOCKCLIENT = CM_BASE + 56;
  CM_UNDOCKCLIENT = CM_BASE + 57;
  CM_FLOAT = CM_BASE + 58;
  CM_BORDERCHANGED = CM_BASE + 59;
  CM_BIDIMODECHANGED = CM_BASE + 60;
  CM_PARENTBIDIMODECHANGED = CM_BASE + 61;
  CM_ALLCHILDRENFLIPPED = CM_BASE + 62;
  CM_ACTIONUPDATE = CM_BASE + 63;
  CM_ACTIONEXECUTE = CM_BASE + 64;
  CM_HINTSHOWPAUSE = CM_BASE + 65;
  CM_DOCKNOTIFICATION = CM_BASE + 66;
  CM_MOUSEWHEEL = CM_BASE + 67;

  CN_BASE = $BC00;
  CN_CHARTOITEM = CN_BASE + WM_CHARTOITEM;
  CN_COMMAND = CN_BASE + WM_COMMAND;
  CN_CTLCOLORBTN = CN_BASE + WM_CTLCOLORBTN;
  CN_CTLCOLOREDIT = CN_BASE + WM_CTLCOLOREDIT;
  CN_CTLCOLORLISTBOX = CN_BASE + WM_CTLCOLORLISTBOX;
  CN_CTLCOLORSTATIC = CN_BASE + WM_CTLCOLORSTATIC;
  CN_DRAWITEM = CN_BASE + WM_DRAWITEM;
  CN_HSCROLL = CN_BASE + WM_HSCROLL;
  CN_MEASUREITEM = CN_BASE + WM_MEASUREITEM;
  CN_NOTIFY = CN_BASE + WM_NOTIFY;
  CN_KEYDOWN = CN_BASE + WM_KEYDOWN;
  CN_KEYUP = CN_BASE + WM_KEYUP;
  CN_CHAR = CN_BASE + WM_CHAR;
  CN_SYSKEYDOWN = CN_BASE + WM_SYSKEYDOWN;
  CN_SYSCHAR = CN_BASE + WM_SYSCHAR;
  CN_VSCROLL = CN_BASE + WM_VSCROLL;

  { modale resultaten }
  mrNone = 0;
  mrOk = IDOK;
  mrCancel = IDCANCEL;
  mrAbort = IDABORT;
  mrRetry = IDRETRY;
  mrIgnore = IDIGNORE;
  mrYes = IDYES;
  mrNo = IDNO;
  mrAll = mrNo + 1;
  mrNoToAll = mrAll + 1;
  mrYesToAll = mrNoToAll + 1;

  { cursors }
  crDefault = TCursor(0);
  crNone = TCursor(-1);
  crArrow = TCursor(-2);
  crCross = TCursor(-3);
  crIBeam = TCursor(-4);
  crSize = TCursor(-22);
  crSizeNESW = TCursor(-6);
  crSizeNS = TCursor(-7);
  crSizeNWSE = TCursor(-8);
  crSizeWE = TCursor(-9);
  crUpArrow = TCursor(-10);
  crHourGlass = TCursor(-11);
  crDrag = TCursor(-12);
  crNoDrop = TCursor(-13);
  crHSplit = TCursor(-14);
  crVSplit = TCursor(-15);
  crMultiDrag = TCursor(-16);
  crSQLWait = TCursor(-17);
  crNo = TCursor(-18);
  crAppStart = TCursor(-19);
  crHelp = TCursor(-20);
  crHandPoint = TCursor(-21);
  crSizeAll = TCursor(-22);

type
  TWinControl = class;
  TControl = class;
  TControlClass = class of TControl;
  TWinControlClass = class of TWinControl;

  TModalResult = Low(Integer)..High(Integer);

  TAlign = (alNone, alTop, alBottom, alLeft, alRight, alClient);
  TAlignSet = set of TAlign;
  TAnchorKind = (akLeft, akTop, akRight, akBottom);
  TAnchors = set of TAnchorKind;
  TBorderWidth = 0..MaxInt;
  TBevelCut = (bvNone, bvLowered, bvRaised, bvSpace);
  TBevelEdge = (beLeft, beTop, beRight, beBottom);
  TBevelEdges = set of TBevelEdge;
  TBevelKind = (bkNone, bkTile, bkSoft, bkFlat);
  TBevelWidth = 1..MaxInt;
  TBiDiMode = (bdLeftToRight, bdRightToLeft, bdRightToLeftNoAlign, bdRightToLeftReadingOnly);
  TImeMode = (imDisable, imClose, imOpen, imDontCare, imSAlpha, imAlpha, imHira,
    imSKata, imKata, imChinese, imSHanguel, imHanguel);
  TImeName = type string;

  TFormBorderStyle = (bsNone, bsSingle, bsSizeable, bsDialog, bsToolWindow, bsSizeToolWin);
  TBorderStyle = bsNone..bsSingle;

  TControlState = set of (csLButtonDown, csClicked, csPalette, csReadingState,
    csAlignmentNeeded, csFocusing, csCreating, csPaintCopy, csCustomPaint,
    csDestroyingHandle, csDocking);
  TControlStyle = set of (csAcceptsControls, csCaptureMouse, csDesignInteractive,
    csClickEvents, csFramed, csSetCaption, csOpaque, csDoubleClicks, csFixedWidth,
    csFixedHeight, csNoDesignVisible, csReplicatable, csNoStdEvents, csDisplayDragImage,
    csReflector, csActionClient, csMenuEvents);

  TMouseButton = (mbLeft, mbRight, mbMiddle);
  TDragMode = (dmManual, dmAutomatic);
  TDragState = (dsDragEnter, dsDragLeave, dsDragMove);
  TDragKind = (dkDrag, dkDock);
  TDockOrientation = (doNoOrient, doHorizontal, doVertical);
  TTabOrder = -1..32767;
  TCaption = type string;
  TDate = type TDateTime;
  TTime = type TDateTime;
  TScalingFlags = set of (sfLeft, sfTop, sfWidth, sfHeight, sfFont);
  TMouseActivate = (maDefault, maActivate, maActivateAndEat, maNoActivate, maNoActivateAndEat);

  TCreateParams = record
    Caption: PAnsiChar;
    Style: DWORD;
    ExStyle: DWORD;
    X, Y: Integer;
    Width, Height: Integer;
    WndParent: HWND;
    Param: Pointer;
    WindowClass: TWndClass;
    WinClassName: array[0..63] of AnsiChar;
  end;

  TMouseEvent = procedure(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
    X, Y: Integer) of object;
  TMouseMoveEvent = procedure(Sender: TObject; Shift: TShiftState; X, Y: Integer) of object;
  TKeyEvent = procedure(Sender: TObject; var Key: Word; Shift: TShiftState) of object;
  TKeyPressEvent = procedure(Sender: TObject; var Key: Char) of object;
  TDragOverEvent = procedure(Sender, Source: TObject; X, Y: Integer; State: TDragState;
    var Accept: Boolean) of object;
  TDragDropEvent = procedure(Sender, Source: TObject; X, Y: Integer) of object;
  TStartDragEvent = procedure(Sender: TObject; var DragObject: TObject) of object;
  TEndDragEvent = procedure(Sender, Target: TObject; X, Y: Integer) of object;
  TCanResizeEvent = procedure(Sender: TObject; var NewWidth, NewHeight: Integer;
    var Resize: Boolean) of object;
  TConstrainedResizeEvent = procedure(Sender: TObject; var MinWidth, MinHeight,
    MaxWidth, MaxHeight: Integer) of object;
  TMouseWheelEvent = procedure(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
    MousePos: TPoint; var Handled: Boolean) of object;
  TMouseWheelUpDownEvent = procedure(Sender: TObject; Shift: TShiftState;
    MousePos: TPoint; var Handled: Boolean) of object;
  TContextPopupEvent = procedure(Sender: TObject; MousePos: TPoint; var Handled: Boolean) of object;

  { berichtrecords voor besturingselementen }
  TCMActivate = TWMNoParams;
  TCMDeactivate = TWMNoParams;
  TCMGotFocus = TWMNoParams;
  TCMLostFocus = TWMNoParams;
  TCMDialogKey = TWMKey;
  TCMDialogChar = TWMKey;
  TCMEnter = TWMNoParams;
  TCMExit = TWMNoParams;
  TCMCancelMode = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Unused: WPARAM;
    Sender: TControl;
    Result: LRESULT;
  end;
  TCMFocusChanged = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Unused: WPARAM;
    Sender: TWinControl;
    Result: LRESULT;
  end;
  TCMHitTest = TWMNCHitTest;
  TCMWantSpecialKey = TWMKey;
  TCMControlChange = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Control: TControl;
    Inserting: LongBool;
{$IFDEF CPU64}
    InsFiller: Cardinal;
{$ENDIF}
    Result: LRESULT;
  end;
  TCMChildKey = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    CharCode: Word;
    Unused: Word;
{$IFDEF CPU64}
    CharFiller: Cardinal;
{$ENDIF}
    Sender: TWinControl;
    Result: LRESULT;
  end;
  TCMChanged = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Unused: WPARAM;
    Child: TControl;
    Result: LRESULT;
  end;
  TCMMouseWheel = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    ShiftState: TShiftState;
    Unused: Byte;
    WheelDelta: SmallInt;
{$IFDEF CPU64}
    WheelFiller: Cardinal;
{$ENDIF}
    case Integer of
      0: (XPos: Smallint; YPos: Smallint);
      1: (Pos: TSmallPoint;
{$IFDEF CPU64}
          PosFiller: Cardinal;
{$ENDIF}
          Result: LRESULT);
  end;

  TSizeConstraints = class(TPersistent)
  private
    FControl: TControl;
    FMaxHeight, FMaxWidth, FMinHeight, FMinWidth: Integer;
    FOnChange: TNotifyEvent;
    procedure SetConstraints(Index: Integer; Value: Integer);
  protected
    procedure Change; virtual;
    procedure AssignTo(Dest: TPersistent); override;
    property Control: TControl read FControl;
  public
    constructor Create(Control: TControl); virtual;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property MaxHeight: Integer index 0 read FMaxHeight write SetConstraints default 0;
    property MaxWidth: Integer index 1 read FMaxWidth write SetConstraints default 0;
    property MinHeight: Integer index 2 read FMinHeight write SetConstraints default 0;
    property MinWidth: Integer index 3 read FMinWidth write SetConstraints default 0;
  end;

  TControlCanvas = class(TCanvas)
  private
    FControl: TControl;
    FDeviceContext: HDC;
    FWindowHandle: HWND;
    procedure SetControl(AControl: TControl);
  protected
    procedure CreateHandle; override;
  public
    destructor Destroy; override;
    procedure FreeHandle;
    procedure UpdateTextFlags;
    property Control: TControl read FControl write SetControl;
  end;

  TControl = class(TComponent)
  private
    FParent: TWinControl;
    FWindowProc: TWndMethod;
    FLeft: Integer;
    FTop: Integer;
    FWidth: Integer;
    FHeight: Integer;
    FControlStyle: TControlStyle;
    FControlState: TControlState;
    FDesktopFont: Boolean;
    FVisible: Boolean;
    FEnabled: Boolean;
    FParentFont: Boolean;
    FParentColor: Boolean;
    FAlign: TAlign;
    FAutoSize: Boolean;
    FDragMode: TDragMode;
    FIsControl: Boolean;
    FBiDiMode: TBiDiMode;
    FParentBiDiMode: Boolean;
    FAnchors: TAnchors;
    FText: string;
    FFont: TFont;
    FColor: TColor;
    FConstraints: TSizeConstraints;
    FCursor: TCursor;
    FDragCursor: TCursor;
    FDragKind: TDragKind;
    FHint: string;
    FFontHeight: Integer;
    FScalingFlags: TScalingFlags;
    FShowHint: Boolean;
    FParentShowHint: Boolean;
    FPopupMenu: TPopupMenu;
    FHelpContext: Integer;
    FActionDummy: TObject;
    FOnCanResize: TCanResizeEvent;
    FOnConstrainedResize: TConstrainedResizeEvent;
    FOnMouseDown: TMouseEvent;
    FOnMouseMove: TMouseMoveEvent;
    FOnMouseUp: TMouseEvent;
    FOnDragDrop: TDragDropEvent;
    FOnDragOver: TDragOverEvent;
    FOnResize: TNotifyEvent;
    FOnStartDrag: TStartDragEvent;
    FOnEndDrag: TEndDragEvent;
    FOnClick: TNotifyEvent;
    FOnDblClick: TNotifyEvent;
    FOnContextPopup: TContextPopupEvent;
    procedure FontChanged(Sender: TObject);
    function GetBoundsRect: TRect;
    function GetClientHeight: Integer;
    function GetClientWidth: Integer;
    function GetMouseCapture: Boolean;
    function GetText: TCaption;
    procedure SetAlign(Value: TAlign);
    procedure SetAnchors(Value: TAnchors);
    procedure SetBoundsRect(const Rect: TRect);
    procedure SetClientHeight(Value: Integer);
    procedure SetClientSize(Value: TPoint);
    procedure SetClientWidth(Value: Integer);
    procedure SetColor(Value: TColor);
    procedure SetConstraints(const Value: TSizeConstraints);
    procedure SetCursor(Value: TCursor);
    procedure SetFont(Value: TFont);
    procedure SetHeight(Value: Integer);
    procedure SetHint(const Value: string);
    procedure SetLeft(Value: Integer);
    procedure SetMouseCapture(Value: Boolean);
    procedure SetParentColor(Value: Boolean);
    procedure SetParentFont(Value: Boolean);
    procedure SetShowHint(Value: Boolean);
    procedure SetParentShowHint(Value: Boolean);
    procedure SetPopupMenu(Value: TPopupMenu);
    procedure SetText(const Value: TCaption);
    procedure SetTop(Value: Integer);
    procedure SetVisible(Value: Boolean);
    procedure SetWidth(Value: Integer);
    function IsFontStored: Boolean;
    function IsColorStored: Boolean;
    function IsShowHintStored: Boolean;
    procedure ReadIsControl(Reader: TReader);
    procedure WriteIsControl(Writer: TWriter);
    procedure WMLButtonDown(var Message: TWMLButtonDown); message WM_LBUTTONDOWN;
    procedure WMNCLButtonDown(var Message: TWMNCLButtonDown); message WM_NCLBUTTONDOWN;
    procedure WMRButtonDown(var Message: TWMRButtonDown); message WM_RBUTTONDOWN;
    procedure WMMButtonDown(var Message: TWMMButtonDown); message WM_MBUTTONDOWN;
    procedure WMLButtonDblClk(var Message: TWMLButtonDblClk); message WM_LBUTTONDBLCLK;
    procedure WMRButtonDblClk(var Message: TWMRButtonDblClk); message WM_RBUTTONDBLCLK;
    procedure WMMButtonDblClk(var Message: TWMMButtonDblClk); message WM_MBUTTONDBLCLK;
    procedure WMMouseMove(var Message: TWMMouseMove); message WM_MOUSEMOVE;
    procedure WMLButtonUp(var Message: TWMLButtonUp); message WM_LBUTTONUP;
    procedure WMRButtonUp(var Message: TWMRButtonUp); message WM_RBUTTONUP;
    procedure WMMButtonUp(var Message: TWMMButtonUp); message WM_MBUTTONUP;
    procedure WMCancelMode(var Message: TWMCancelMode); message WM_CANCELMODE;
    procedure WMWindowPosChanged(var Message: TWMWindowPosChanged); message WM_WINDOWPOSCHANGED;
    procedure CMVisibleChanged(var Message: TMessage); message CM_VISIBLECHANGED;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    procedure CMColorChanged(var Message: TMessage); message CM_COLORCHANGED;
    procedure CMParentFontChanged(var Message: TMessage); message CM_PARENTFONTCHANGED;
    procedure CMParentColorChanged(var Message: TMessage); message CM_PARENTCOLORCHANGED;
    procedure CMParentShowHintChanged(var Message: TMessage); message CM_PARENTSHOWHINTCHANGED;
    procedure CMHitTest(var Message: TCMHitTest); message CM_HITTEST;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    function CheckNewSize(var NewWidth, NewHeight: Integer): Boolean;
    procedure DoMouseDown(var Message: TWMMouse; Button: TMouseButton; Shift: TShiftState);
    procedure DoMouseUp(var Message: TWMMouse; Button: TMouseButton);
    procedure SendCancelMode(Sender: TControl);
    procedure SendDockNotification(Msg: Cardinal; WParam: WPARAM; LParam: LPARAM);
    procedure SetZOrderPosition(Position: Integer);
  protected
    procedure UpdateAnchorRules;
    procedure InvalidateControl(IsVisible, IsOpaque: Boolean);
    procedure AdjustSize; dynamic;
    procedure AssignTo(Dest: TPersistent); override;
    function CanAutoSize(var NewWidth, NewHeight: Integer): Boolean; virtual;
    function CanResize(var NewWidth, NewHeight: Integer): Boolean; virtual;
    procedure Changed;
    procedure ChangeScale(M, D: Integer); dynamic;
    procedure Click; dynamic;
    procedure ConstrainedResize(var MinWidth, MinHeight, MaxWidth, MaxHeight: Integer); virtual;
    procedure DblClick; dynamic;
    procedure DefineProperties(Filer: TFiler); override;
    procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); dynamic;
    procedure DoEndDrag(Target: TObject; X, Y: Integer); dynamic;
    procedure DragOver(Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean); dynamic;
    function GetClientOrigin: TPoint; virtual;
    function GetClientRect: TRect; virtual;
    function GetDeviceContext(var WindowHandle: HWnd): HDC; virtual;
    function GetEnabled: Boolean; virtual;
    function GetPalette: HPALETTE; dynamic;
    function GetPopupMenu: TPopupMenu; dynamic;
    procedure Loaded; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); dynamic;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); dynamic;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); dynamic;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    function PaletteChanged(Foreground: Boolean): Boolean; dynamic;
    procedure ReadState(Reader: TReader); override;
    procedure RequestAlign; dynamic;
    procedure Resize; dynamic;
    procedure SetDragMode(Value: TDragMode); virtual;
    procedure SetEnabled(Value: Boolean); virtual;
    procedure SetName(const Value: TComponentName); override;
    procedure SetParent(AParent: TWinControl); virtual;
    procedure SetParentComponent(Value: TComponent); override;
    procedure SetZOrder(TopMost: Boolean); dynamic;
    procedure UpdateBoundsRect(const R: TRect);
    procedure VisibleChanging; dynamic;
    procedure WndProc(var Message: TMessage); virtual;
    function GetTextBufStr: string;
    property AutoSize: Boolean read FAutoSize write FAutoSize default False;
    property Caption: TCaption read GetText write SetText stored True;
    property Color: TColor read FColor write SetColor stored IsColorStored default clWindow;
    property DesktopFont: Boolean read FDesktopFont write FDesktopFont default False;
    property DragCursor: TCursor read FDragCursor write FDragCursor default crDrag;
    property DragKind: TDragKind read FDragKind write FDragKind default dkDrag;
    property DragMode: TDragMode read FDragMode write SetDragMode default dmManual;
    property Font: TFont read FFont write SetFont stored IsFontStored;
    property IsControl: Boolean read FIsControl write FIsControl;
    property MouseCapture: Boolean read GetMouseCapture write SetMouseCapture;
    property ParentBiDiMode: Boolean read FParentBiDiMode write FParentBiDiMode default True;
    property ParentColor: Boolean read FParentColor write SetParentColor default True;
    property ParentFont: Boolean read FParentFont write SetParentFont default True;
    property ParentShowHint: Boolean read FParentShowHint write SetParentShowHint default True;
    property PopupMenu: TPopupMenu read GetPopupMenu write SetPopupMenu;
    property ScalingFlags: TScalingFlags read FScalingFlags write FScalingFlags;
    property Text: TCaption read GetText write SetText;
    property OnCanResize: TCanResizeEvent read FOnCanResize write FOnCanResize;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property OnConstrainedResize: TConstrainedResizeEvent read FOnConstrainedResize write FOnConstrainedResize;
    property OnContextPopup: TContextPopupEvent read FOnContextPopup write FOnContextPopup;
    property OnDblClick: TNotifyEvent read FOnDblClick write FOnDblClick;
    property OnDragDrop: TDragDropEvent read FOnDragDrop write FOnDragDrop;
    property OnDragOver: TDragOverEvent read FOnDragOver write FOnDragOver;
    property OnEndDrag: TEndDragEvent read FOnEndDrag write FOnEndDrag;
    property OnMouseDown: TMouseEvent read FOnMouseDown write FOnMouseDown;
    property OnMouseMove: TMouseMoveEvent read FOnMouseMove write FOnMouseMove;
    property OnMouseUp: TMouseEvent read FOnMouseUp write FOnMouseUp;
    property OnResize: TNotifyEvent read FOnResize write FOnResize;
    property OnStartDrag: TStartDragEvent read FOnStartDrag write FOnStartDrag;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure BeginDrag(Immediate: Boolean; Threshold: Integer = -1);
    procedure BringToFront;
    function ClientToScreen(const Point: TPoint): TPoint;
    procedure Dock(NewDockSite: TWinControl; ARect: TRect); dynamic;
    procedure DefaultHandler(var Message); override;
    function Dragging: Boolean;
    procedure DragDrop(Source: TObject; X, Y: Integer); dynamic;
    function DrawTextBiDiModeFlags(Flags: Longint): Longint;
    function DrawTextBiDiModeFlagsReadingOnly: Longint;
    property Enabled: Boolean read GetEnabled write SetEnabled default True;
    procedure EndDrag(Drop: Boolean);
    function GetControlsAlignment: TAlignment; dynamic;
    function GetParentComponent: TComponent; override;
    function GetTextBuf(Buffer: PChar; BufSize: Integer): Integer;
    function GetTextLen: Integer;
    function HasParent: Boolean; override;
    procedure Hide;
    procedure InitiateAction; virtual;
    procedure Invalidate; virtual;
    function IsRightToLeft: Boolean;
    function ManualDock(NewDockSite: TWinControl; DropControl: TControl = nil;
      ControlSide: TAlign = alNone): Boolean;
    function Perform(Msg: Cardinal; WParam: WPARAM; LParam: LPARAM): LRESULT;
    procedure Refresh;
    procedure Repaint; virtual;
    function ScreenToClient(const Point: TPoint): TPoint;
    procedure SendToBack;
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); virtual;
    procedure SetTextBuf(Buffer: PChar);
    procedure Show;
    procedure Update; virtual;
    function UseRightToLeftAlignment: Boolean; dynamic;
    function UseRightToLeftReading: Boolean;
    function UseRightToLeftScrollBar: Boolean;
    property Action: TObject read FActionDummy write FActionDummy;  { acties worden niet ondersteund }
    property Align: TAlign read FAlign write SetAlign default alNone;
    property Anchors: TAnchors read FAnchors write SetAnchors default [akLeft, akTop];
    property BiDiMode: TBiDiMode read FBiDiMode write FBiDiMode;
    property BoundsRect: TRect read GetBoundsRect write SetBoundsRect;
    property ClientHeight: Integer read GetClientHeight write SetClientHeight stored False;
    property ClientOrigin: TPoint read GetClientOrigin;
    property ClientRect: TRect read GetClientRect;
    property ClientWidth: Integer read GetClientWidth write SetClientWidth stored False;
    property Constraints: TSizeConstraints read FConstraints write SetConstraints;
    property ControlState: TControlState read FControlState write FControlState;
    property ControlStyle: TControlStyle read FControlStyle write FControlStyle;
    property Parent: TWinControl read FParent write SetParent;
    property ShowHint: Boolean read FShowHint write SetShowHint stored IsShowHintStored;
    property Visible: Boolean read FVisible write SetVisible default True;
    property WindowProc: TWndMethod read FWindowProc write FWindowProc;
  published
    property Left: Integer read FLeft write SetLeft;
    property Top: Integer read FTop write SetTop;
    property Width: Integer read FWidth write SetWidth;
    property Height: Integer read FHeight write SetHeight;
    property Cursor: TCursor read FCursor write SetCursor default crDefault;
    property Hint: string read FHint write SetHint;
    property HelpContext: Integer read FHelpContext write FHelpContext default 0;
  end;

  TWinControl = class(TControl)
  private
    FAlignLevel: Word;
    FBrush: TBrush;
    FDefWndProc: Pointer;
    FHandle: HWnd;
    FParentWindow: HWnd;
    FShowing: Boolean;
    FTabOrder: Integer;
    FTabStop: Boolean;
    FCtl3D: Boolean;
    FParentCtl3D: Boolean;
    FTabList: TList;
    FControls: TList;
    FWinControls: TList;
    FBorderWidth: TBorderWidth;
    FBevelEdges: TBevelEdges;
    FBevelInner: TBevelCut;
    FBevelOuter: TBevelCut;
    FBevelKind: TBevelKind;
    FBevelWidth: TBevelWidth;
    FImeMode: TImeMode;
    FImeName: TImeName;
    FDoubleBuffered: Boolean;
    FUseDockManager: Boolean;
    FDockSite: Boolean;
    FOnKeyDown: TKeyEvent;
    FOnKeyPress: TKeyPressEvent;
    FOnKeyUp: TKeyEvent;
    FOnEnter: TNotifyEvent;
    FOnExit: TNotifyEvent;
    FOnMouseWheel: TMouseWheelEvent;
    FOnMouseWheelDown: TMouseWheelUpDownEvent;
    FOnMouseWheelUp: TMouseWheelUpDownEvent;
    procedure AlignControl(AControl: TControl);
    function GetControl(Index: Integer): TControl;
    function GetControlCount: Integer;
    function GetHandle: HWnd;
    function GetParentBackground: Boolean;
    function GetTabOrder: TTabOrder;
    procedure Insert(AControl: TControl);
    procedure InvalidateFrame;
    function IsCtl3DStored: Boolean;
    procedure Remove(AControl: TControl);
    procedure RemoveFocus(Removing: Boolean);
    procedure SetBorderWidth(Value: TBorderWidth);
    procedure SetCtl3D(Value: Boolean);
    procedure SetParentCtl3D(Value: Boolean);
    procedure SetParentWindow(Value: HWnd);
    procedure SetTabOrder(Value: TTabOrder);
    procedure SetTabStop(Value: Boolean);
    procedure SetZOrderPosition(Position: Integer);
    procedure UpdateTabOrder(Value: TTabOrder);
    procedure UpdateBounds;
    procedure UpdateShowing;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
    procedure WMSetCursor(var Message: TWMSetCursor); message WM_SETCURSOR;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure WMSize(var Message: TWMSize); message WM_SIZE;
    procedure WMMove(var Message: TWMMove); message WM_MOVE;
    procedure WMWindowPosChanged(var Message: TWMWindowPosChanged); message WM_WINDOWPOSCHANGED;
    procedure WMNCDestroy(var Message: TWMNCDestroy); message WM_NCDESTROY;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure CMColorChanged(var Message: TMessage); message CM_COLORCHANGED;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    procedure CMVisibleChanged(var Message: TMessage); message CM_VISIBLECHANGED;
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;
    procedure CMDialogChar(var Message: TCMDialogChar); message CM_DIALOGCHAR;
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
    procedure CMEnter(var Message: TCMEnter); message CM_ENTER;
    procedure CMExit(var Message: TCMExit); message CM_EXIT;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    function IsTopLevelShowing: Boolean;
    procedure SetProp;
    function IsControlMouseMsg(var Message: TWMMouse): Boolean;
    procedure ValidParentForm(Control: TControl);
    function Screen_Cursor: TCursor;
  protected
    FWinCreated: Boolean;
    procedure HandleKeyMessage(var Message: TWMKey); virtual;
    procedure KeyDownDefault(var Message: TWMKey); virtual;
    procedure KeyPressDefault(var Message: TWMKey); virtual;
    procedure AddBiDiModeExStyle(var ExStyle: DWORD);
    procedure AdjustClientRect(var Rect: TRect); virtual;
    procedure AdjustSize; override;
    procedure AlignControls(AControl: TControl; var Rect: TRect); virtual;
    function CanAutoSize(var NewWidth, NewHeight: Integer): Boolean; override;
    function CanResize(var NewWidth, NewHeight: Integer): Boolean; override;
    procedure ChangeScale(M, D: Integer); override;
    procedure ConstrainedResize(var MinWidth, MinHeight, MaxWidth, MaxHeight: Integer); override;
    procedure CreateHandle; virtual;
    procedure CreateParams(var Params: TCreateParams); virtual;
    procedure CreateWindowHandle(const Params: TCreateParams); virtual;
    procedure CreateWnd; virtual;
    procedure DefineProperties(Filer: TFiler); override;
    procedure DestroyHandle;
    procedure DestroyWindowHandle; virtual;
    procedure DestroyWnd; virtual;
    procedure DoEnter; dynamic;
    procedure DoExit; dynamic;
    function DoKeyDown(var Message: TWMKey): Boolean;
    function DoKeyPress(var Message: TWMKey): Boolean;
    function DoKeyUp(var Message: TWMKey): Boolean;
    function DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean; dynamic;
    function DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean; dynamic;
    function DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean; dynamic;
    function FindNextControl(CurControl: TWinControl; GoForward, CheckTabStop, CheckParent: Boolean): TWinControl;
    procedure FixupTabList;
    function GetClientOrigin: TPoint; override;
    function GetClientRect: TRect; override;
    function GetControlExtents: TRect; virtual;
    function GetDeviceContext(var WindowHandle: HWnd): HDC; override;
    function GetParentHandle: HWnd;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    function GetTopParentHandle: HWnd;
    procedure KeyDown(var Key: Word; Shift: TShiftState); dynamic;
    procedure KeyUp(var Key: Word; Shift: TShiftState); dynamic;
    procedure KeyPress(var Key: Char); dynamic;
    procedure MainWndProc(var Message: TMessage);
    procedure NotifyControls(Msg: Word);
    procedure PaintControls(DC: HDC; First: TControl);
    procedure PaintHandler(var Message: TWMPaint);
    procedure PaintWindow(DC: HDC); virtual;
    function PaletteChanged(Foreground: Boolean): Boolean; override;
    procedure ReadState(Reader: TReader); override;
    procedure RecreateWnd;
    procedure ReloadDockedControl(const AControlName: string; var AControl: TControl); dynamic;
    procedure ResetIme;
    procedure ScaleControls(M, D: Integer);
    procedure SelectFirst;
    procedure SelectNext(CurControl: TWinControl; GoForward, CheckTabStop: Boolean);
    procedure SetChildOrder(Child: TComponent; Order: Integer); override;
    procedure SetZOrder(TopMost: Boolean); override;
    procedure ShowControl(AControl: TControl); virtual;
    procedure WndProc(var Message: TMessage); override;
    function WantKey(Key: Word): Boolean; virtual;
    property BevelEdges: TBevelEdges read FBevelEdges write FBevelEdges default [beLeft, beTop, beRight, beBottom];
    property BevelInner: TBevelCut read FBevelInner write FBevelInner default bvRaised;
    property BevelOuter: TBevelCut read FBevelOuter write FBevelOuter default bvLowered;
    property BevelKind: TBevelKind read FBevelKind write FBevelKind default bkNone;
    property BevelWidth: TBevelWidth read FBevelWidth write FBevelWidth default 1;
    property BorderWidth: TBorderWidth read FBorderWidth write SetBorderWidth default 0;
    property Ctl3D: Boolean read FCtl3D write SetCtl3D stored IsCtl3DStored;
    property DefWndProc: Pointer read FDefWndProc write FDefWndProc;
    property ImeMode: TImeMode read FImeMode write FImeMode default imDontCare;
    property ImeName: TImeName read FImeName write FImeName;
    property ParentCtl3D: Boolean read FParentCtl3D write SetParentCtl3D default True;
    property WindowHandle: HWnd read FHandle write FHandle;
    property OnEnter: TNotifyEvent read FOnEnter write FOnEnter;
    property OnExit: TNotifyEvent read FOnExit write FOnExit;
    property OnKeyDown: TKeyEvent read FOnKeyDown write FOnKeyDown;
    property OnKeyPress: TKeyPressEvent read FOnKeyPress write FOnKeyPress;
    property OnKeyUp: TKeyEvent read FOnKeyUp write FOnKeyUp;
    property OnMouseWheel: TMouseWheelEvent read FOnMouseWheel write FOnMouseWheel;
    property OnMouseWheelDown: TMouseWheelUpDownEvent read FOnMouseWheelDown write FOnMouseWheelDown;
    property OnMouseWheelUp: TMouseWheelUpDownEvent read FOnMouseWheelUp write FOnMouseWheelUp;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateParented(ParentWindow: HWnd);
    destructor Destroy; override;
    procedure Broadcast(var Message);
    function CanFocus: Boolean; dynamic;
    function ContainsControl(Control: TControl): Boolean;
    function ControlAtPos(const Pos: TPoint; AllowDisabled: Boolean; AllowWinControls: Boolean = False): TControl;
    procedure DefaultHandler(var Message); override;
    procedure DisableAlign;
    property DockSite: Boolean read FDockSite write FDockSite default False;
    property DoubleBuffered: Boolean read FDoubleBuffered write FDoubleBuffered;
    procedure EnableAlign;
    function FindChildControl(const ControlName: string): TControl;
    procedure FlipChildren(AllLevels: Boolean); dynamic;
    function Focused: Boolean; dynamic;
    procedure GetTabOrderList(List: TList); dynamic;
    function HandleAllocated: Boolean;
    procedure HandleNeeded;
    procedure InsertControl(AControl: TControl);
    procedure Invalidate; override;
    procedure PaintTo(DC: HDC; X, Y: Integer);
    procedure RemoveControl(AControl: TControl);
    procedure Realign;
    procedure Repaint; override;
    procedure ScaleBy(M, D: Integer);
    procedure ScrollBy(DeltaX, DeltaY: Integer);
    procedure SetBounds(ALeft, ATop, AWidth, AHeight: Integer); override;
    procedure SetFocus; virtual;
    procedure Update; override;
    procedure UpdateControlState;
    property Brush: TBrush read FBrush;
    property Controls[Index: Integer]: TControl read GetControl;
    property ControlCount: Integer read GetControlCount;
    property Handle: HWnd read GetHandle;
    property ParentWindow: HWnd read FParentWindow write SetParentWindow;
    property Showing: Boolean read FShowing;
    property TabOrder: TTabOrder read GetTabOrder write SetTabOrder default -1;
    property TabStop: Boolean read FTabStop write SetTabStop default False;
    property UseDockManager: Boolean read FUseDockManager write FUseDockManager default False;
  end;

  TGraphicControl = class(TControl)
  private
    FCanvas: TCanvas;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
  protected
    procedure Paint; virtual;
    property Canvas: TCanvas read FCanvas;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  TCustomControl = class(TWinControl)
  private
    FCanvas: TCanvas;
    procedure WMPaint(var Message: TWMPaint); message WM_PAINT;
  protected
    procedure Paint; virtual;
    procedure PaintWindow(DC: HDC); override;
    property Canvas: TCanvas read FCanvas;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

  THintWindow = class(TCustomControl)
  private
    FActivating: Boolean;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ActivateHint(Rect: TRect; const AHint: string); virtual;
    function CalcHintRect(MaxWidth: Integer; const AHint: string; AData: Pointer): TRect; virtual;
    function IsHintMsg(var Msg: TMsg): Boolean; virtual;
    procedure ReleaseHandle;
    property Caption;
    property Color;
    property Canvas;
  end;
  THintWindowClass = class of THintWindow;

  { minimale afbeeldingenlijst }
  TImageIndex = type Integer;
  TCustomImageList = class(TComponent)
  private
    FWidth, FHeight: Integer;
    FBitmaps: TList;
    FOnChange: TNotifyEvent;
    function GetCount: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateSize(AWidth, AHeight: Integer);
    destructor Destroy; override;
    function Add(Image, Mask: TBitmap): Integer;
    procedure Clear;
    procedure Delete(Index: Integer);
    procedure Draw(Canvas: TCanvas; X, Y, Index: Integer; Enabled: Boolean = True);
    procedure GetBitmap(Index: Integer; Image: TBitmap);
    property Count: Integer read GetCount;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property Height: Integer read FHeight write FHeight default 16;
    property Width: Integer read FWidth write FWidth default 16;
  end;
  TImageList = class(TCustomImageList);
  TDragImageList = class(TCustomImageList);

  { sleepobjecten (slepen en neerzetten is niet geimplementeerd) }
  TDragObject = class(TObject)
  public
    procedure Finished(Target: TObject; X, Y: Integer; Accepted: Boolean); virtual;
  end;
  TBaseDragControlObject = class(TDragObject)
  private
    FControl: TControl;
  public
    constructor Create(AControl: TControl); virtual;
    property Control: TControl read FControl write FControl;
  end;
  TDragControlObject = class(TBaseDragControlObject);

function FindControl(Handle: HWnd): TWinControl;
function FindVCLWindow(const Pos: TPoint): TWinControl;
function FindDragTarget(const Pos: TPoint; AllowDisabled: Boolean): TControl;
function GetCaptureControl: TControl;
procedure SetCaptureControl(Control: TControl);
procedure CancelDrag;
function IsDragObject(Sender: TObject): Boolean;
function GetShortHint(const Hint: string): string;
function GetLongHint(const Hint: string): string;
function CursorToString(Cursor: TCursor): string;
function StringToCursor(const S: string): TCursor;
procedure GetCursorValues(Proc: TGetStrProc);
function CursorToIdent(Cursor: Longint; var Ident: string): Boolean;
function IdentToCursor(const Ident: string; var Cursor: Longint): Boolean;
function KeysToShiftState(Keys: Word): TShiftState;
function KeyDataToShiftState(KeyData: Longint): TShiftState;
function KeyboardStateToShiftState: TShiftState;
procedure ChangeBiDiModeAlignment(var Alignment: TAlignment);
procedure FreeDeviceContexts;
procedure FreeDeviceContext(DC: HDC);

var
  Mouse: TObject = nil;
  NewStyleControls: Boolean = True;
  CreationControl: TControl = nil;
  DefaultDockTreeClass: TClass = nil;

  { gezet door Forms: het formulier van een besturingselement, cursorafbeelding }
  ZMGetParentFormHook: function(Control: TControl): TWinControl = nil;
  ZMCursorHook: function(Cursor: TCursor): HCURSOR = nil;
  ZMKeyPreviewHook: function(Form: TWinControl): Boolean = nil;
  ZMSetFocusedControlHook: function(Form, Control: TWinControl): Boolean = nil;
  ZMFocusControlHook: procedure(Form, Control: TWinControl) = nil;
  ZMDefocusHook: procedure(Form, Control: TWinControl; Removing: Boolean) = nil;
  ZMHandleExceptionHook: procedure(Sender: TObject) = nil;
  ZMScreenCursorHook: function: TCursor = nil;
  ZMMouseMoveHook: procedure(Control: TControl) = nil;
  ZMSetModalResultHook: procedure(Form: TWinControl; MR: Integer) = nil;

function PointToLParam(const P: TPoint): LPARAM;
function SmallPointToPoint(const P: TSmallPoint): TPoint;
procedure MoveWindowOrg(DC: HDC; DX, DY: Integer);

implementation

uses Math, ZMWin;

var
  CaptureControl: TControl = nil;
  CanvasList: TList = nil;

const
  ShiftKeyMask = [ssShift, ssAlt, ssCtrl];

{ ---------------------------------------------------------------- hulpfuncties }

function PointToLParam(const P: TPoint): LPARAM;
begin
  Result := LPARAM(LongWord(Word(SmallInt(P.X))) or (LongWord(Word(SmallInt(P.Y))) shl 16));
end;

function SmallPointToPoint(const P: TSmallPoint): TPoint;
begin
  Result.X := P.X;
  Result.Y := P.Y;
end;

procedure MoveWindowOrg(DC: HDC; DX, DY: Integer);
var
  P: TPoint;
begin
  GetWindowOrgEx(DC, P);
  SetWindowOrgEx(DC, P.X - DX, P.Y - DY, nil);
end;

function KeysToShiftState(Keys: Word): TShiftState;
begin
  Result := [];
  if Keys and MK_SHIFT <> 0 then Include(Result, ssShift);
  if Keys and MK_CONTROL <> 0 then Include(Result, ssCtrl);
  if Keys and MK_LBUTTON <> 0 then Include(Result, ssLeft);
  if Keys and MK_RBUTTON <> 0 then Include(Result, ssRight);
  if Keys and MK_MBUTTON <> 0 then Include(Result, ssMiddle);
  if GetKeyState(VK_MENU) < 0 then Include(Result, ssAlt);
end;

function KeyDataToShiftState(KeyData: Longint): TShiftState;
const
  AltMask = $20000000;
begin
  Result := [];
  if GetKeyState(VK_SHIFT) < 0 then Include(Result, ssShift);
  if GetKeyState(VK_CONTROL) < 0 then Include(Result, ssCtrl);
  if KeyData and AltMask <> 0 then Include(Result, ssAlt);
end;

function KeyboardStateToShiftState: TShiftState;
begin
  Result := [];
  if GetKeyState(VK_SHIFT) < 0 then Include(Result, ssShift);
  if GetKeyState(VK_CONTROL) < 0 then Include(Result, ssCtrl);
  if GetKeyState(VK_MENU) < 0 then Include(Result, ssAlt);
  if GetKeyState(VK_LBUTTON) < 0 then Include(Result, ssLeft);
  if GetKeyState(VK_RBUTTON) < 0 then Include(Result, ssRight);
  if GetKeyState(VK_MBUTTON) < 0 then Include(Result, ssMiddle);
end;

procedure ChangeBiDiModeAlignment(var Alignment: TAlignment);
begin
end;

function GetShortHint(const Hint: string): string;
var
  I: Integer;
begin
  I := Pos('|', Hint);
  if I = 0 then Result := Hint else Result := Copy(Hint, 1, I - 1);
end;

function GetLongHint(const Hint: string): string;
var
  I: Integer;
begin
  I := Pos('|', Hint);
  if I = 0 then Result := Hint else Result := Copy(Hint, I + 1, MaxInt);
end;

type
  TCursorEntry = record
    Value: Longint;
    Name: string;
  end;

const
  Cursors: array[0..21] of TCursorEntry = (
    (Value: crDefault; Name: 'crDefault'),
    (Value: crArrow; Name: 'crArrow'),
    (Value: crCross; Name: 'crCross'),
    (Value: crIBeam; Name: 'crIBeam'),
    (Value: crSizeNESW; Name: 'crSizeNESW'),
    (Value: crSizeNS; Name: 'crSizeNS'),
    (Value: crSizeNWSE; Name: 'crSizeNWSE'),
    (Value: crSizeWE; Name: 'crSizeWE'),
    (Value: crUpArrow; Name: 'crUpArrow'),
    (Value: crHourGlass; Name: 'crHourGlass'),
    (Value: crDrag; Name: 'crDrag'),
    (Value: crNoDrop; Name: 'crNoDrop'),
    (Value: crHSplit; Name: 'crHSplit'),
    (Value: crVSplit; Name: 'crVSplit'),
    (Value: crMultiDrag; Name: 'crMultiDrag'),
    (Value: crSQLWait; Name: 'crSQLWait'),
    (Value: crNo; Name: 'crNo'),
    (Value: crAppStart; Name: 'crAppStart'),
    (Value: crHelp; Name: 'crHelp'),
    (Value: crHandPoint; Name: 'crHandPoint'),
    (Value: crSizeAll; Name: 'crSizeAll'),
    (Value: crNone; Name: 'crNone'));

function CursorToIdent(Cursor: Longint; var Ident: string): Boolean;
var
  I: Integer;
begin
  for I := Low(Cursors) to High(Cursors) do
    if Cursors[I].Value = Cursor then
    begin
      Ident := Cursors[I].Name;
      Exit(True);
    end;
  Result := False;
end;

function IdentToCursor(const Ident: string; var Cursor: Longint): Boolean;
var
  I: Integer;
begin
  for I := Low(Cursors) to High(Cursors) do
    if SameText(Cursors[I].Name, Ident) then
    begin
      Cursor := Cursors[I].Value;
      Exit(True);
    end;
  Result := False;
end;

function CursorToString(Cursor: TCursor): string;
begin
  if not CursorToIdent(Cursor, Result) then Result := IntToStr(Cursor);
end;

function StringToCursor(const S: string): TCursor;
var
  C: Longint;
begin
  if IdentToCursor(S, C) then Result := C else Result := StrToInt(S);
end;

procedure GetCursorValues(Proc: TGetStrProc);
var
  I: Integer;
begin
  for I := Low(Cursors) to High(Cursors) do Proc(Cursors[I].Name);
end;

function ParentFormOf(C: TControl): TWinControl;
begin
  if Assigned(ZMGetParentFormHook) then
    Result := ZMGetParentFormHook(C)
  else
  begin
    while (C <> nil) and (C.Parent <> nil) do C := C.Parent;
    if C is TWinControl then Result := TWinControl(C) else Result := nil;
  end;
end;

{ ---------------------------------------------------------------- vensterzoeken }

var
  WinControls: TList = nil;   { alle TWinControls met een handle }

function FindControl(Handle: HWnd): TWinControl;
var
  I: Integer;
begin
  Result := nil;
  if (Handle = 0) or (WinControls = nil) then Exit;
  for I := 0 to WinControls.Count - 1 do
    if TWinControl(WinControls[I]).FHandle = Handle then
      Exit(TWinControl(WinControls[I]));
end;

function FindVCLWindow(const Pos: TPoint): TWinControl;
var
  H: HWND;
begin
  H := WindowFromPoint(Pos);
  Result := nil;
  while H <> 0 do
  begin
    Result := FindControl(H);
    if Result <> nil then Exit;
    H := GetParent(H);
  end;
end;

function FindDragTarget(const Pos: TPoint; AllowDisabled: Boolean): TControl;
var
  Vensterobject: TWinControl;
  Besturing: TControl;
begin
  Result := nil;
  Vensterobject := FindVCLWindow(Pos);
  if Vensterobject <> nil then
  begin
    Result := Vensterobject;
    Besturing := Vensterobject.ControlAtPos(Vensterobject.ScreenToClient(Pos), AllowDisabled);
    if Besturing <> nil then Result := Besturing;
  end;
end;

function GetCaptureControl: TControl;
begin
  Result := CaptureControl;
  if (Result <> nil) then
  begin
    if Result is TWinControl then
    begin
      if not TWinControl(Result).HandleAllocated or (GetCapture <> TWinControl(Result).FHandle) then
        Result := nil;
    end
    else if (Result.Parent = nil) or not Result.Parent.HandleAllocated or
      (GetCapture <> Result.Parent.FHandle) then
      Result := nil;
  end;
  if Result = nil then
  begin
    Result := FindControl(GetCapture);
    CaptureControl := Result;
  end;
end;

procedure SetCaptureControl(Control: TControl);
begin
  ReleaseCapture;
  CaptureControl := nil;
  if Control <> nil then
  begin
    if not (Control is TWinControl) then
    begin
      if Control.Parent = nil then Exit;
      CaptureControl := Control;
      Control := Control.Parent;
    end;
    SetCapture(TWinControl(Control).Handle);
  end;
end;

procedure CancelDrag;
begin
end;

function IsDragObject(Sender: TObject): Boolean;
begin
  Result := Sender is TDragObject;
end;

{ ---------------------------------------------------------------- apparaatcontexten }

procedure FreeDeviceContexts;
var
  I: Integer;
begin
  if CanvasList = nil then Exit;
  for I := CanvasList.Count - 1 downto 0 do
    with TControlCanvas(CanvasList[I]) do
      if LockCount = 0 then FreeHandle;
end;

procedure FreeDeviceContext(DC: HDC);
var
  I: Integer;
begin
  if CanvasList = nil then Exit;
  for I := CanvasList.Count - 1 downto 0 do
    with TControlCanvas(CanvasList[I]) do
      if FDeviceContext = DC then FreeHandle;
end;

{ ---------------------------------------------------------------- TSizeConstraints }

constructor TSizeConstraints.Create(Control: TControl);
begin
  inherited Create;
  FControl := Control;
end;

procedure TSizeConstraints.SetConstraints(Index: Integer; Value: Integer);
begin
  case Index of
    0: FMaxHeight := Value;
    1: FMaxWidth := Value;
    2: FMinHeight := Value;
    3: FMinWidth := Value;
  end;
  Change;
end;

procedure TSizeConstraints.Change;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TSizeConstraints.AssignTo(Dest: TPersistent);
begin
  if Dest is TSizeConstraints then
    with TSizeConstraints(Dest) do
    begin
      FMinHeight := Self.FMinHeight;
      FMaxHeight := Self.FMaxHeight;
      FMinWidth := Self.FMinWidth;
      FMaxWidth := Self.FMaxWidth;
      Change;
    end
  else
    inherited AssignTo(Dest);
end;

{ ---------------------------------------------------------------- TControlCanvas }

destructor TControlCanvas.Destroy;
begin
  FreeHandle;
  inherited Destroy;
end;

procedure TControlCanvas.CreateHandle;
begin
  if FControl = nil then
    inherited CreateHandle
  else
  begin
    if FDeviceContext = 0 then
    begin
      FDeviceContext := FControl.GetDeviceContext(FWindowHandle);
      if CanvasList = nil then CanvasList := TList.Create;
      CanvasList.Add(Self);
    end;
    Handle := FDeviceContext;
    UpdateTextFlags;
  end;
end;

procedure TControlCanvas.FreeHandle;
begin
  if FDeviceContext <> 0 then
  begin
    Handle := 0;
    if CanvasList <> nil then CanvasList.Remove(Self);
    ReleaseDC(FWindowHandle, FDeviceContext);
    FDeviceContext := 0;
  end;
end;

procedure TControlCanvas.SetControl(AControl: TControl);
begin
  if FControl <> AControl then
  begin
    FreeHandle;
    FControl := AControl;
  end;
end;

procedure TControlCanvas.UpdateTextFlags;
begin
end;

{ ---------------------------------------------------------------- TControl }

constructor TControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FWindowProc := WndProc;
  FControlStyle := [csCaptureMouse, csClickEvents, csSetCaption, csDoubleClicks];
  FFont := TFont.Create;
  FFont.OnChange := FontChanged;
  FAnchors := [akLeft, akTop];
  FConstraints := TSizeConstraints.Create(Self);
  FColor := clWindow;
  FVisible := True;
  FEnabled := True;
  FParentFont := True;
  FParentColor := True;
  FParentShowHint := True;
  FParentBiDiMode := True;
  FIsControl := False;
  FDragCursor := crDrag;
  FFontHeight := FFont.Height;
end;

destructor TControl.Destroy;
begin
  if (FParent <> nil) then FParent.RemoveControl(Self);
  if CaptureControl = Self then CaptureControl := nil;
  FFont.Free;
  FConstraints.Free;
  inherited Destroy;
end;

function TControl.GetDeviceContext(var WindowHandle: HWnd): HDC;
begin
  if Parent = nil then
    raise EInvalidOperation.CreateFmt('Control ''%s'' has no parent window', [Name]);
  Result := Parent.GetDeviceContext(WindowHandle);
  SetViewportOrgEx(Result, Left, Top, nil);
  IntersectClipRect(Result, 0, 0, Width, Height);
end;

function TControl.GetEnabled: Boolean;
begin
  Result := FEnabled;
end;

procedure TControl.SetEnabled(Value: Boolean);
begin
  if FEnabled <> Value then
  begin
    FEnabled := Value;
    Perform(CM_ENABLEDCHANGED, 0, 0);
  end;
end;

function TControl.GetPalette: HPALETTE;
begin
  Result := 0;
end;

function TControl.PaletteChanged(Foreground: Boolean): Boolean;
begin
  Result := False;
end;

function TControl.GetPopupMenu: TPopupMenu;
begin
  Result := FPopupMenu;
end;

procedure TControl.SetPopupMenu(Value: TPopupMenu);
begin
  FPopupMenu := Value;
  if Value <> nil then Value.FreeNotification(Self);
end;

procedure TControl.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FPopupMenu) then FPopupMenu := nil;
end;

procedure TControl.SetDragMode(Value: TDragMode);
begin
  FDragMode := Value;
end;

procedure TControl.SetName(const Value: TComponentName);
var
  Tekstwijzigen: Boolean;
begin
  Tekstwijzigen := (csSetCaption in ControlStyle) and not (csLoading in ComponentState) and
    (Name = Text) and ((Owner = nil) or not (Owner is TControl) or
    not (csLoading in TControl(Owner).ComponentState));
  inherited SetName(Value);
  if Tekstwijzigen then Text := Value;
end;

procedure TControl.SetParent(AParent: TWinControl);
begin
  if FParent <> AParent then
  begin
    if AParent = Self then
      raise EInvalidOperation.Create('A control cannot have itself as its parent');
    if FParent <> nil then FParent.RemoveControl(Self);
    if AParent <> nil then
    begin
      AParent.InsertControl(Self);
      UpdateAnchorRules;
    end;
  end;
end;

procedure TControl.SetParentComponent(Value: TComponent);
begin
  if (Parent <> Value) and (Value is TWinControl) then
    SetParent(TWinControl(Value));
end;

function TControl.GetParentComponent: TComponent;
begin
  Result := Parent;
end;

function TControl.HasParent: Boolean;
begin
  Result := True;
end;

procedure TControl.FontChanged(Sender: TObject);
begin
  FParentFont := False;
  FDesktopFont := False;
  if Font.Height <> FFontHeight then
  begin
    Include(FScalingFlags, sfFont);
    FFontHeight := Font.Height;
  end;
  Perform(CM_FONTCHANGED, 0, 0);
end;

procedure TControl.SetFont(Value: TFont);
begin
  FFont.Assign(Value);
end;

function TControl.IsFontStored: Boolean;
begin
  Result := not ParentFont and not DesktopFont;
end;

function TControl.IsColorStored: Boolean;
begin
  Result := not ParentColor;
end;

function TControl.IsShowHintStored: Boolean;
begin
  Result := not ParentShowHint;
end;

procedure TControl.SetColor(Value: TColor);
begin
  if FColor <> Value then
  begin
    FColor := Value;
    FParentColor := False;
    Perform(CM_COLORCHANGED, 0, 0);
  end;
end;

procedure TControl.SetParentColor(Value: Boolean);
begin
  if FParentColor <> Value then
  begin
    FParentColor := Value;
    if FParent <> nil then Perform(CM_PARENTCOLORCHANGED, 0, 0);
  end;
end;

procedure TControl.SetParentFont(Value: Boolean);
begin
  if FParentFont <> Value then
  begin
    FParentFont := Value;
    if FParent <> nil then Perform(CM_PARENTFONTCHANGED, 0, 0);
  end;
end;

procedure TControl.SetShowHint(Value: Boolean);
begin
  if FShowHint <> Value then
  begin
    FShowHint := Value;
    FParentShowHint := False;
  end;
end;

procedure TControl.SetParentShowHint(Value: Boolean);
begin
  if FParentShowHint <> Value then
  begin
    FParentShowHint := Value;
    if FParent <> nil then Perform(CM_PARENTSHOWHINTCHANGED, 0, 0);
  end;
end;

procedure TControl.SetCursor(Value: TCursor);
begin
  if FCursor <> Value then
  begin
    FCursor := Value;
    Perform(CM_CURSORCHANGED, 0, 0);
  end;
end;

procedure TControl.SetHint(const Value: string);
begin
  FHint := Value;
end;

procedure TControl.SetConstraints(const Value: TSizeConstraints);
begin
  FConstraints.Assign(Value);
end;

procedure TControl.SetAnchors(Value: TAnchors);
begin
  FAnchors := Value;
end;

procedure TControl.UpdateAnchorRules;
begin
end;

procedure TControl.SetAlign(Value: TAlign);
var
  Oudeuitlijning: TAlign;
begin
  if FAlign <> Value then
  begin
    Oudeuitlijning := FAlign;
    FAlign := Value;
    Anchors := [akLeft, akTop];
    if not (csLoading in ComponentState) and (Value in [alTop, alBottom, alLeft, alRight, alClient]) then
    begin
      if ((Oudeuitlijning in [alTop, alBottom]) = (Value in [alRight, alLeft])) and
        not (Oudeuitlijning in [alNone, alClient]) and not (Value in [alNone, alClient]) then
        SetBounds(Left, Top, Height, Width)
      else
        AdjustSize;
    end;
  end;
  RequestAlign;
end;

procedure TControl.RequestAlign;
begin
  if Parent <> nil then Parent.AlignControl(Self);
end;

procedure TControl.Resize;
begin
  if Assigned(FOnResize) then FOnResize(Self);
end;

procedure TControl.AdjustSize;
begin
  if not (csLoading in ComponentState) then SetBounds(Left, Top, Width, Height);
end;

function TControl.CanAutoSize(var NewWidth, NewHeight: Integer): Boolean;
begin
  Result := True;
end;

function TControl.CanResize(var NewWidth, NewHeight: Integer): Boolean;
begin
  Result := True;
  if Assigned(FOnCanResize) then FOnCanResize(Self, NewWidth, NewHeight, Result);
end;

procedure TControl.ConstrainedResize(var MinWidth, MinHeight, MaxWidth, MaxHeight: Integer);
begin
  if Assigned(FOnConstrainedResize) then
    FOnConstrainedResize(Self, MinWidth, MinHeight, MaxWidth, MaxHeight);
end;

procedure TControl.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
var
  R: TRect;
begin
  if CheckNewSize(AWidth, AHeight) and
    ((ALeft <> FLeft) or (ATop <> FTop) or (AWidth <> FWidth) or (AHeight <> FHeight)) then
  begin
    { oud gebied ongeldig maken }
    if (Parent <> nil) and Visible and Parent.HandleAllocated then
    begin
      R := BoundsRect;
      InvalidateRect(Parent.Handle, @R, True);
    end;
    FLeft := ALeft;
    FTop := ATop;
    FWidth := AWidth;
    FHeight := AHeight;
    Invalidate;
    Perform(WM_WINDOWPOSCHANGED, 0, 0);
    RequestAlign;
    if not (csLoading in ComponentState) then Resize;
  end;
end;

function TControl.CheckNewSize(var NewWidth, NewHeight: Integer): Boolean;
var
  W, H: Integer;
  Minbreedte, Minhoogte, Maxbreedte, Maxhoogte: Integer;
begin
  Result := False;
  W := NewWidth;
  H := NewHeight;
  if CanResize(W, H) then
  begin
    Minbreedte := FConstraints.MinWidth; Minhoogte := FConstraints.MinHeight;
    Maxbreedte := FConstraints.MaxWidth; Maxhoogte := FConstraints.MaxHeight;
    ConstrainedResize(Minbreedte, Minhoogte, Maxbreedte, Maxhoogte);
    if (Minbreedte > 0) and (W < Minbreedte) then W := Minbreedte;
    if (Maxbreedte > 0) and (W > Maxbreedte) then W := Maxbreedte;
    if (Minhoogte > 0) and (H < Minhoogte) then H := Minhoogte;
    if (Maxhoogte > 0) and (H > Maxhoogte) then H := Maxhoogte;
    NewWidth := W;
    NewHeight := H;
    Result := True;
  end;
end;

procedure TControl.UpdateBoundsRect(const R: TRect);
begin
  FLeft := R.Left;
  FTop := R.Top;
  FWidth := R.Right - R.Left;
  FHeight := R.Bottom - R.Top;
end;

procedure TControl.SetLeft(Value: Integer);
begin
  SetBounds(Value, FTop, FWidth, FHeight);
end;

procedure TControl.SetTop(Value: Integer);
begin
  SetBounds(FLeft, Value, FWidth, FHeight);
end;

procedure TControl.SetWidth(Value: Integer);
begin
  SetBounds(FLeft, FTop, Value, FHeight);
end;

procedure TControl.SetHeight(Value: Integer);
begin
  SetBounds(FLeft, FTop, FWidth, Value);
end;

function TControl.GetBoundsRect: TRect;
begin
  Result.Left := Left;
  Result.Top := Top;
  Result.Right := Left + Width;
  Result.Bottom := Top + Height;
end;

procedure TControl.SetBoundsRect(const Rect: TRect);
begin
  with Rect do SetBounds(Left, Top, Right - Left, Bottom - Top);
end;

function TControl.GetClientRect: TRect;
begin
  Result := Rect(0, 0, Width, Height);
end;

function TControl.GetClientWidth: Integer;
begin
  Result := ClientRect.Right;
end;

function TControl.GetClientHeight: Integer;
begin
  Result := ClientRect.Bottom;
end;

procedure TControl.SetClientSize(Value: TPoint);
var
  Clientgebied: TRect;
begin
  Clientgebied := GetClientRect;
  SetBounds(FLeft, FTop, Width - Clientgebied.Right + Value.X, Height - Clientgebied.Bottom + Value.Y);
end;

procedure TControl.SetClientWidth(Value: Integer);
begin
  SetClientSize(Point(Value, ClientHeight));
end;

procedure TControl.SetClientHeight(Value: Integer);
begin
  SetClientSize(Point(ClientWidth, Value));
end;

function TControl.GetClientOrigin: TPoint;
begin
  if Parent = nil then
    raise EInvalidOperation.CreateFmt('Control ''%s'' has no parent window', [Name]);
  Result := Parent.ClientOrigin;
  Inc(Result.X, FLeft);
  Inc(Result.Y, FTop);
end;

function TControl.ClientToScreen(const Point: TPoint): TPoint;
var
  Oorsprong: TPoint;
begin
  Oorsprong := GetClientOrigin;
  Result.X := Point.X + Oorsprong.X;
  Result.Y := Point.Y + Oorsprong.Y;
end;

function TControl.ScreenToClient(const Point: TPoint): TPoint;
var
  Oorsprong: TPoint;
begin
  Oorsprong := GetClientOrigin;
  Result.X := Point.X - Oorsprong.X;
  Result.Y := Point.Y - Oorsprong.Y;
end;

procedure TControl.SetVisible(Value: Boolean);
begin
  if FVisible <> Value then
  begin
    VisibleChanging;
    FVisible := Value;
    Perform(CM_VISIBLECHANGED, Ord(Value), 0);
    RequestAlign;
  end;
end;

procedure TControl.VisibleChanging;
begin
end;

procedure TControl.Show;
begin
  if Parent <> nil then Parent.ShowControl(Self);
  if not (csDesigning in ComponentState) or (csNoDesignVisible in ControlStyle) then
    Visible := True;
end;

procedure TControl.Hide;
begin
  Visible := False;
end;

function TControl.GetText: TCaption;
var
  Lengte: Integer;
begin
  Lengte := GetTextLen;
  SetString(Result, nil, Lengte);
  if Lengte <> 0 then GetTextBuf(PChar(Result), Lengte + 1);
end;

function TControl.GetTextBufStr: string;
begin
  Result := FText;
end;

procedure TControl.SetText(const Value: TCaption);
begin
  if GetText <> Value then SetTextBuf(PChar(Value));
end;

function TControl.GetTextLen: Integer;
begin
  Result := Perform(WM_GETTEXTLENGTH, 0, 0);
end;

function TControl.GetTextBuf(Buffer: PChar; BufSize: Integer): Integer;
begin
  Result := Perform(WM_GETTEXT, BufSize, LPARAM(Buffer));
end;

procedure TControl.SetTextBuf(Buffer: PChar);
begin
  Perform(WM_SETTEXT, 0, LPARAM(Buffer));
  Perform(CM_TEXTCHANGED, 0, 0);
end;

procedure TControl.DefaultHandler(var Message);
var
  P: PChar;
begin
  with TMessage(Message) do
    case Msg of
      WM_GETTEXT:
        begin
          if WParam > 0 then
          begin
            P := PChar(LParam);
            StrLCopy(P, PChar(FText), WParam - 1);
            Result := StrLen(P);
          end
          else
            Result := 0;
        end;
      WM_GETTEXTLENGTH:
        Result := Length(FText);
      WM_SETTEXT:
        begin
          P := PChar(LParam);
          if P = nil then FText := '' else FText := StrPas(P);
          Result := 1;
        end;
    end;
end;

function TControl.Perform(Msg: Cardinal; WParam: WPARAM; LParam: LPARAM): LRESULT;
var
  Bericht: TMessage;
begin
  FillChar(Bericht, SizeOf(Bericht), 0);
  Bericht.Msg := Msg;
  Bericht.WParam := WParam;
  Bericht.LParam := LParam;
  Bericht.Result := 0;
  if Self <> nil then WindowProc(Bericht);
  Result := Bericht.Result;
end;

procedure TControl.WndProc(var Message: TMessage);
var
  Formulier: TWinControl;
begin
  if (Message.Msg >= WM_MOUSEFIRST) and (Message.Msg <= WM_MOUSELAST) then
  begin
    if not (csDoubleClicks in ControlStyle) then
      case Message.Msg of
        WM_LBUTTONDBLCLK, WM_RBUTTONDBLCLK, WM_MBUTTONDBLCLK:
          Dec(Message.Msg, WM_LBUTTONDBLCLK - WM_LBUTTONDOWN);
      end;
    case Message.Msg of
      WM_MOUSEMOVE:
        if Assigned(ZMMouseMoveHook) then ZMMouseMoveHook(Self);
      WM_LBUTTONDOWN, WM_LBUTTONDBLCLK:
        begin
          if FDragMode = dmAutomatic then
          begin
            BeginDrag(False);
            Exit;
          end;
          Include(FControlState, csLButtonDown);
        end;
      WM_LBUTTONUP:
        Exclude(FControlState, csLButtonDown);
    end;
  end
  else if Message.Msg = CM_VISIBLECHANGED then
    with Message do
      SendDockNotification(Msg, WParam, LParam);
  Formulier := nil;
  if Formulier = nil then ;
  Dispatch(Message);
end;

procedure TControl.SendDockNotification(Msg: Cardinal; WParam: WPARAM; LParam: LPARAM);
begin
end;

procedure TControl.Changed;
begin
  Perform(CM_CHANGED, 0, LPARAM(Self));
end;

procedure TControl.ChangeScale(M, D: Integer);
begin
end;

procedure TControl.Click;
begin
  if Assigned(FOnClick) then FOnClick(Self);
end;

procedure TControl.DblClick;
begin
  if Assigned(FOnDblClick) then FOnDblClick(Self);
end;

procedure TControl.DoContextPopup(MousePos: TPoint; var Handled: Boolean);
begin
  if Assigned(FOnContextPopup) then FOnContextPopup(Self, MousePos, Handled);
end;

procedure TControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(FOnMouseDown) then FOnMouseDown(Self, Button, Shift, X, Y);
end;

procedure TControl.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(FOnMouseMove) then FOnMouseMove(Self, Shift, X, Y);
end;

procedure TControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(FOnMouseUp) then FOnMouseUp(Self, Button, Shift, X, Y);
end;

procedure TControl.DoMouseDown(var Message: TWMMouse; Button: TMouseButton; Shift: TShiftState);
begin
  if not (csNoStdEvents in ControlStyle) then
    with Message do
      MouseDown(Button, KeysToShiftState(Keys) + Shift, XPos, YPos);
end;

procedure TControl.WMLButtonDown(var Message: TWMLButtonDown);
begin
  SendCancelMode(Self);
  inherited;
  if csCaptureMouse in ControlStyle then MouseCapture := True;
  if csClickEvents in ControlStyle then Include(FControlState, csClicked);
  DoMouseDown(Message, mbLeft, []);
end;

procedure TControl.WMNCLButtonDown(var Message: TWMNCLButtonDown);
begin
  SendCancelMode(Self);
  inherited;
end;

procedure TControl.WMRButtonDown(var Message: TWMRButtonDown);
begin
  inherited;
  DoMouseDown(Message, mbRight, []);
end;

procedure TControl.WMMButtonDown(var Message: TWMMButtonDown);
begin
  inherited;
  DoMouseDown(Message, mbMiddle, []);
end;

procedure TControl.WMLButtonDblClk(var Message: TWMLButtonDblClk);
begin
  SendCancelMode(Self);
  inherited;
  if csCaptureMouse in ControlStyle then MouseCapture := True;
  if csClickEvents in ControlStyle then DblClick;
  DoMouseDown(Message, mbLeft, [ssDouble]);
end;

procedure TControl.WMRButtonDblClk(var Message: TWMRButtonDblClk);
begin
  inherited;
  DoMouseDown(Message, mbRight, [ssDouble]);
end;

procedure TControl.WMMButtonDblClk(var Message: TWMMButtonDblClk);
begin
  inherited;
  DoMouseDown(Message, mbMiddle, [ssDouble]);
end;

procedure TControl.WMMouseMove(var Message: TWMMouseMove);
begin
  inherited;
  if not (csNoStdEvents in ControlStyle) then
    with Message do
      MouseMove(KeysToShiftState(Keys), XPos, YPos);
end;

procedure TControl.DoMouseUp(var Message: TWMMouse; Button: TMouseButton);
begin
  if not (csNoStdEvents in ControlStyle) then
    with Message do MouseUp(Button, KeysToShiftState(Keys), XPos, YPos);
end;

procedure TControl.WMLButtonUp(var Message: TWMLButtonUp);
begin
  inherited;
  if csCaptureMouse in ControlStyle then MouseCapture := False;
  if csClicked in ControlState then
  begin
    Exclude(FControlState, csClicked);
    if PtInRect(ClientRect, SmallPointToPoint(Message.Pos)) then Click;
  end;
  DoMouseUp(Message, mbLeft);
end;

procedure TControl.WMRButtonUp(var Message: TWMRButtonUp);
var
  P: TPoint;
  Afgehandeld: Boolean;
begin
  inherited;
  DoMouseUp(Message, mbRight);
  if (Message.Result = 0) and (PopupMenu <> nil) then
  begin
    P := ClientToScreen(SmallPointToPoint(Message.Pos));
    Afgehandeld := False;
    DoContextPopup(SmallPointToPoint(Message.Pos), Afgehandeld);
    if not Afgehandeld then PopupMenu.Popup(P.X, P.Y);
  end;
end;

procedure TControl.WMMButtonUp(var Message: TWMMButtonUp);
begin
  inherited;
  DoMouseUp(Message, mbMiddle);
end;

procedure TControl.WMCancelMode(var Message: TWMCancelMode);
begin
  inherited;
  if MouseCapture then
  begin
    MouseCapture := False;
    if csLButtonDown in ControlState then Perform(WM_LBUTTONUP, 0, $FFFFFFFF);
  end
  else
    Exclude(FControlState, csLButtonDown);
end;

procedure TControl.WMWindowPosChanged(var Message: TWMWindowPosChanged);
begin
  inherited;
end;

procedure TControl.SendCancelMode(Sender: TControl);
begin
end;

function TControl.GetMouseCapture: Boolean;
begin
  Result := GetCaptureControl = Self;
end;

procedure TControl.SetMouseCapture(Value: Boolean);
begin
  if MouseCapture <> Value then
    if Value then SetCaptureControl(Self) else SetCaptureControl(nil);
end;

procedure TControl.CMVisibleChanged(var Message: TMessage);
begin
  if not (csDesigning in ComponentState) or (csNoDesignVisible in ControlStyle) then
    InvalidateControl(True, FVisible and (csOpaque in ControlStyle));
end;

procedure TControl.CMEnabledChanged(var Message: TMessage);
begin
  Invalidate;
end;

procedure TControl.CMFontChanged(var Message: TMessage);
begin
  Invalidate;
end;

procedure TControl.CMColorChanged(var Message: TMessage);
begin
  Invalidate;
end;

procedure TControl.CMParentColorChanged(var Message: TMessage);
begin
  if FParentColor then
  begin
    if Message.WParam <> 0 then
      SetColor(TColor(Message.LParam))
    else if FParent <> nil then
      SetColor(FParent.Color);
    FParentColor := True;
  end;
end;

procedure TControl.CMParentFontChanged(var Message: TMessage);
begin
  if FParentFont then
  begin
    if Message.WParam <> 0 then
      SetFont(TFont(Message.LParam))
    else if FParent <> nil then
      SetFont(FParent.Font);
    FParentFont := True;
  end;
end;

procedure TControl.CMParentShowHintChanged(var Message: TMessage);
begin
  if FParentShowHint and (FParent <> nil) then
  begin
    SetShowHint(FParent.ShowHint);
    FParentShowHint := True;
  end;
end;

procedure TControl.CMHitTest(var Message: TCMHitTest);
begin
  Message.Result := HTCLIENT;
end;

procedure TControl.CMMouseEnter(var Message: TMessage);
begin
  if FParent <> nil then FParent.Perform(CM_MOUSEENTER, 0, LPARAM(Self));
end;

procedure TControl.CMMouseLeave(var Message: TMessage);
begin
  if FParent <> nil then FParent.Perform(CM_MOUSELEAVE, 0, LPARAM(Self));
end;

procedure TControl.InvalidateControl(IsVisible, IsOpaque: Boolean);
var
  Rechthoek: TRect;
begin
  if (IsVisible or (csDesigning in ComponentState) and not (csNoDesignVisible in ControlStyle)) and
    (Parent <> nil) and Parent.HandleAllocated then
  begin
    Rechthoek := BoundsRect;
    InvalidateRect(Parent.Handle, @Rechthoek, not (IsOpaque or (csOpaque in Parent.ControlStyle)));
  end;
end;

procedure TControl.Invalidate;
begin
  InvalidateControl(Visible, csOpaque in ControlStyle);
end;

procedure TControl.Update;
begin
  if Parent <> nil then Parent.Update;
end;

procedure TControl.Repaint;
var
  DC: HDC;
begin
  if (Visible or (csDesigning in ComponentState) and not (csNoDesignVisible in ControlStyle)) and
    (Parent <> nil) and Parent.HandleAllocated then
    if csOpaque in ControlStyle then
    begin
      DC := GetDC(Parent.Handle);
      try
        IntersectClipRect(DC, Left, Top, Left + Width, Top + Height);
        Parent.PaintControls(DC, Self);
      finally
        ReleaseDC(Parent.Handle, DC);
      end;
    end
    else
    begin
      Invalidate;
      Update;
    end;
end;

procedure TControl.Refresh;
begin
  Repaint;
end;

procedure TControl.BringToFront;
begin
  SetZOrder(True);
end;

procedure TControl.SendToBack;
begin
  SetZOrder(False);
end;

procedure TControl.SetZOrder(TopMost: Boolean);
begin
  if FParent <> nil then
    if TopMost then
      SetZOrderPosition(FParent.FControls.Count - 1)
    else
      SetZOrderPosition(0);
end;

procedure TControl.SetZOrderPosition(Position: Integer);
var
  I, Aantal: Integer;
begin
  if FParent <> nil then
  begin
    I := FParent.FControls.IndexOf(Self);
    if I >= 0 then
    begin
      Aantal := FParent.FControls.Count;
      if Position < 0 then Position := 0;
      if Position >= Aantal then Position := Aantal - 1;
      if Position <> I then
      begin
        FParent.FControls.Delete(I);
        FParent.FControls.Insert(Position, Self);
        InvalidateControl(Visible, True);
      end;
    end;
  end;
end;

procedure TControl.Loaded;
begin
  inherited Loaded;
  if Action <> nil then ;
  if (Parent <> nil) and FParentColor then
  begin
    FColor := Parent.Color;
    FParentColor := True;
  end;
  if (Parent <> nil) and FParentFont then
  begin
    FFont.OnChange := nil;
    FFont.Assign(Parent.Font);
    FFont.OnChange := FontChanged;
    FParentFont := True;
  end;
  if (Parent <> nil) and FParentShowHint then
    FShowHint := Parent.ShowHint;
  Include(FControlState, csReadingState);
  Exclude(FControlState, csReadingState);
  RequestAlign;
end;

procedure TControl.ReadState(Reader: TReader);
begin
  Include(FControlState, csReadingState);
  if Reader.Parent is TWinControl then Parent := TWinControl(Reader.Parent);
  inherited ReadState(Reader);
  Exclude(FControlState, csReadingState);
  if Parent <> nil then
  begin
    Perform(CM_PARENTCOLORCHANGED, 0, 0);
    Perform(CM_PARENTFONTCHANGED, 0, 0);
    Perform(CM_PARENTSHOWHINTCHANGED, 0, 0);
  end;
end;

procedure TControl.ReadIsControl(Reader: TReader);
begin
  FIsControl := Reader.ReadBoolean;
end;

procedure TControl.WriteIsControl(Writer: TWriter);
begin
  Writer.WriteBoolean(FIsControl);
end;

procedure TControl.DefineProperties(Filer: TFiler);

  function SchrijfIsBesturing: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := TControl(Filer.Ancestor).IsControl <> IsControl
    else
      Result := IsControl;
  end;

begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('IsControl', ReadIsControl, WriteIsControl, SchrijfIsBesturing);
end;

procedure TControl.AssignTo(Dest: TPersistent);
begin
  inherited AssignTo(Dest);
end;

procedure TControl.BeginDrag(Immediate: Boolean; Threshold: Integer);
begin
end;

procedure TControl.EndDrag(Drop: Boolean);
begin
end;

function TControl.Dragging: Boolean;
begin
  Result := False;
end;

procedure TControl.DragDrop(Source: TObject; X, Y: Integer);
begin
  if Assigned(FOnDragDrop) then FOnDragDrop(Self, Source, X, Y);
end;

procedure TControl.DragOver(Source: TObject; X, Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept := False;
  if Assigned(FOnDragOver) then
  begin
    Accept := True;
    FOnDragOver(Self, Source, X, Y, State, Accept);
  end;
end;

procedure TControl.DoEndDrag(Target: TObject; X, Y: Integer);
begin
  if Assigned(FOnEndDrag) then FOnEndDrag(Self, Target, X, Y);
end;

procedure TControl.Dock(NewDockSite: TWinControl; ARect: TRect);
begin
end;

function TControl.ManualDock(NewDockSite: TWinControl; DropControl: TControl; ControlSide: TAlign): Boolean;
begin
  Result := False;
end;

function TControl.DrawTextBiDiModeFlags(Flags: Longint): Longint;
begin
  Result := Flags;
end;

function TControl.DrawTextBiDiModeFlagsReadingOnly: Longint;
begin
  Result := 0;
end;

function TControl.GetControlsAlignment: TAlignment;
begin
  Result := taLeftJustify;
end;

procedure TControl.InitiateAction;
begin
end;

function TControl.IsRightToLeft: Boolean;
begin
  Result := False;
end;

function TControl.UseRightToLeftAlignment: Boolean;
begin
  Result := False;
end;

function TControl.UseRightToLeftReading: Boolean;
begin
  Result := False;
end;

function TControl.UseRightToLeftScrollBar: Boolean;
begin
  Result := False;
end;

{ ---------------------------------------------------------------- TWinControl }

constructor TWinControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FBrush := TBrush.Create;
  FBrush.Color := FColor;
  FParentCtl3D := True;
  FCtl3D := True;
  FTabOrder := -1;
  FBevelEdges := [beLeft, beTop, beRight, beBottom];
  FBevelInner := bvRaised;
  FBevelOuter := bvLowered;
  FBevelWidth := 1;
  FImeMode := imDontCare;
end;

constructor TWinControl.CreateParented(ParentWindow: HWnd);
begin
  FParentWindow := ParentWindow;
  Create(nil);
end;

destructor TWinControl.Destroy;
var
  I: Integer;
  Exemplaar: TControl;
begin
  Destroying;
  if FParent <> nil then RemoveFocus(True);
  if FHandle <> 0 then DestroyWindowHandle;
  I := ControlCount;
  while I <> 0 do
  begin
    Exemplaar := Controls[I - 1];
    Remove(Exemplaar);
    Exemplaar.Destroy;
    I := ControlCount;
  end;
  FBrush.Free;
  FTabList.Free;
  FControls.Free;
  FWinControls.Free;
  inherited Destroy;
end;

procedure TWinControl.FixupTabList;
var
  Aantal, I, J: Integer;
  Lijst: TList;
  Besturing: TWinControl;
begin
  if FWinControls <> nil then
  begin
    Lijst := TList.Create;
    try
      Aantal := FWinControls.Count;
      Lijst.Count := Aantal;
      for I := 0 to Aantal - 1 do
      begin
        Besturing := TWinControl(FWinControls[I]);
        J := Besturing.FTabOrder;
        if (J >= 0) and (J < Aantal) then Lijst[J] := Besturing;
      end;
      for I := 0 to Aantal - 1 do
      begin
        Besturing := TWinControl(Lijst[I]);
        if Besturing <> nil then Besturing.UpdateTabOrder(I);
      end;
    finally
      Lijst.Free;
    end;
  end;
end;

procedure TWinControl.ReadState(Reader: TReader);
begin
  DisableAlign;
  try
    inherited ReadState(Reader);
  finally
    EnableAlign;
  end;
  FixupTabList;
  if FParent <> nil then Perform(CM_PARENTCTL3DCHANGED, 0, 0);
  UpdateControlState;
end;

procedure TWinControl.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
end;

procedure TWinControl.Insert(AControl: TControl);
begin
  if AControl <> nil then
  begin
    if AControl is TWinControl then
    begin
      if FWinControls = nil then FWinControls := TList.Create;
      FWinControls.Add(AControl);
      if FTabList = nil then FTabList := TList.Create;
      FTabList.Add(AControl);
    end;
    if FControls = nil then FControls := TList.Create;
    FControls.Add(AControl);
    if (csReading in ComponentState) and (AControl is TWinControl) and
      (TWinControl(AControl).FTabOrder >= 0) then ;
    AControl.FParent := Self;
  end;
end;

procedure TWinControl.Remove(AControl: TControl);
begin
  if AControl is TWinControl then
  begin
    FTabList.Remove(AControl);
    FWinControls.Remove(AControl);
  end;
  if FControls <> nil then FControls.Remove(AControl);
  AControl.FParent := nil;
end;

procedure TWinControl.InsertControl(AControl: TControl);
begin
  AControl.ValidateContainer(Self);
  Perform(CM_CONTROLLISTCHANGE, WPARAM(AControl), LPARAM(True));
  Insert(AControl);
  if not (csReading in AControl.ComponentState) then
  begin
    AControl.Perform(CM_PARENTCOLORCHANGED, 0, 0);
    AControl.Perform(CM_PARENTFONTCHANGED, 0, 0);
    AControl.Perform(CM_PARENTSHOWHINTCHANGED, 0, 0);
    if AControl is TWinControl then
    begin
      AControl.Perform(CM_PARENTCTL3DCHANGED, 0, 0);
      UpdateControlState;
    end
    else if HandleAllocated then
      AControl.Invalidate;
    AlignControl(AControl);
  end;
  Perform(CM_CONTROLCHANGE, WPARAM(AControl), LPARAM(True));
end;

procedure TWinControl.RemoveControl(AControl: TControl);
begin
  Perform(CM_CONTROLCHANGE, WPARAM(AControl), LPARAM(False));
  if AControl is TWinControl then
    with TWinControl(AControl) do
    begin
      RemoveFocus(True);
      DestroyHandle;
    end
  else if HandleAllocated then
    AControl.InvalidateControl(AControl.Visible, False);
  Remove(AControl);
  Perform(CM_CONTROLLISTCHANGE, WPARAM(AControl), LPARAM(False));
  Realign;
end;

procedure TWinControl.RemoveFocus(Removing: Boolean);
var
  Formulier: TWinControl;
begin
  Formulier := ParentFormOf(Self);
  if (Formulier <> nil) and Assigned(ZMDefocusHook) then ZMDefocusHook(Formulier, Self, Removing);
end;

function TWinControl.GetControl(Index: Integer): TControl;
begin
  Result := TControl(FControls[Index]);
end;

function TWinControl.GetControlCount: Integer;
begin
  if FControls <> nil then Result := FControls.Count else Result := 0;
end;

procedure TWinControl.Broadcast(var Message);
var
  I: Integer;
begin
  for I := 0 to ControlCount - 1 do
  begin
    Controls[I].WindowProc(TMessage(Message));
    if TMessage(Message).Result <> 0 then Exit;
  end;
end;

procedure TWinControl.NotifyControls(Msg: Word);
var
  Bericht: TMessage;
begin
  FillChar(Bericht, SizeOf(Bericht), 0);
  Bericht.Msg := Msg;
  Broadcast(Bericht);
end;

function TWinControl.ContainsControl(Control: TControl): Boolean;
begin
  while (Control <> nil) and (Control <> Self) do Control := Control.Parent;
  Result := Control <> nil;
end;

function TWinControl.ControlAtPos(const Pos: TPoint; AllowDisabled, AllowWinControls: Boolean): TControl;
var
  I: Integer;
  P: TPoint;
  C: TControl;
begin
  if FControls <> nil then
    for I := FControls.Count - 1 downto 0 do
    begin
      C := TControl(FControls[I]);
      if not AllowWinControls and (C is TWinControl) then Continue;
      P := Point(Pos.X - C.Left, Pos.Y - C.Top);
      if PtInRect(C.ClientRect, P) and
        ((csDesigning in ComponentState) and (C.Visible or not (csNoDesignVisible in C.ControlStyle)) or
        (C.Visible and (C.Enabled or AllowDisabled) and (C.Perform(CM_HITTEST, 0, PointToLParam(P)) <> 0))) then
      begin
        Result := C;
        Exit;
      end;
    end;
  Result := nil;
end;

function TWinControl.FindChildControl(const ControlName: string): TControl;
var
  I: Integer;
begin
  Result := nil;
  if FWinControls <> nil then
    for I := 0 to FWinControls.Count - 1 do
      if CompareText(TWinControl(FWinControls[I]).Name, ControlName) = 0 then
        Exit(TControl(FWinControls[I]));
end;

procedure TWinControl.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I: Integer;
  Besturing: TControl;
begin
  for I := 0 to ControlCount - 1 do
  begin
    Besturing := Controls[I];
    if Besturing.Owner = Root then Proc(Besturing);
  end;
end;

procedure TWinControl.SetChildOrder(Child: TComponent; Order: Integer);
begin
  if Child is TWinControl then
    TWinControl(Child).SetZOrderPosition(Order)
  else if Child is TControl then
    TControl(Child).SetZOrderPosition(Order);
end;

procedure TWinControl.FlipChildren(AllLevels: Boolean);
begin
end;

{ uitlijning }

procedure TWinControl.DisableAlign;
begin
  Inc(FAlignLevel);
end;

procedure TWinControl.EnableAlign;
begin
  Dec(FAlignLevel);
  if FAlignLevel = 0 then
  begin
    if csAlignmentNeeded in ControlState then Realign;
  end;
end;

procedure TWinControl.Realign;
begin
  AlignControl(nil);
end;

procedure TWinControl.AdjustClientRect(var Rect: TRect);
begin
  InflateRect(Rect, -FBorderWidth, -FBorderWidth);
end;

procedure TWinControl.AlignControl(AControl: TControl);
var
  Rechthoek: TRect;
begin
  if not HandleAllocated or (csDestroying in ComponentState) then
  begin
    if csLoading in ComponentState then
    begin
      Include(FControlState, csAlignmentNeeded);
      Exit;
    end;
  end;
  if FAlignLevel <> 0 then
    Include(FControlState, csAlignmentNeeded)
  else
  begin
    DisableAlign;
    try
      Rechthoek := GetClientRect;
      AlignControls(AControl, Rechthoek);
    finally
      Exclude(FControlState, csAlignmentNeeded);
      EnableAlign;
    end;
  end;
end;

procedure TWinControl.AlignControls(AControl: TControl; var Rect: TRect);
var
  Uitlijnlijst: TList;

  function Invoegvoor(C1, C2: TControl; Auitlijn: TAlign): Boolean;
  begin
    Result := False;
    case Auitlijn of
      alTop: Result := C1.Top < C2.Top;
      alBottom: Result := (C1.Top + C1.Height) >= (C2.Top + C2.Height);
      alLeft: Result := C1.Left < C2.Left;
      alRight: Result := (C1.Left + C1.Width) >= (C2.Left + C2.Width);
    end;
  end;

  procedure DoPositie(Besturing: TControl; Auitlijn: TAlign);
  var
    Nieuwlinks, Nieuwboven, Nieuwebreedte, Nieuwehoogte: Integer;
  begin
    Nieuwebreedte := Rect.Right - Rect.Left;
    if (Nieuwebreedte < 0) or (Auitlijn in [alLeft, alRight]) then Nieuwebreedte := Besturing.Width;
    Nieuwehoogte := Rect.Bottom - Rect.Top;
    if (Nieuwehoogte < 0) or (Auitlijn in [alTop, alBottom]) then Nieuwehoogte := Besturing.Height;
    Nieuwlinks := Rect.Left;
    Nieuwboven := Rect.Top;
    case Auitlijn of
      alTop: Inc(Rect.Top, Nieuwehoogte);
      alBottom:
        begin
          Dec(Rect.Bottom, Nieuwehoogte);
          Nieuwboven := Rect.Bottom;
        end;
      alLeft: Inc(Rect.Left, Nieuwebreedte);
      alRight:
        begin
          Dec(Rect.Right, Nieuwebreedte);
          Nieuwlinks := Rect.Right;
        end;
    end;
    Besturing.SetBounds(Nieuwlinks, Nieuwboven, Nieuwebreedte, Nieuwehoogte);
    { het besturingselement accepteert de grootte mogelijk niet: pas de resterende rechthoek aan }
    if (Besturing.Width <> Nieuwebreedte) or (Besturing.Height <> Nieuwehoogte) then
      case Auitlijn of
        alTop: Dec(Rect.Top, Nieuwehoogte - Besturing.Height);
        alBottom: Inc(Rect.Bottom, Nieuwehoogte - Besturing.Height);
        alLeft: Dec(Rect.Left, Nieuwebreedte - Besturing.Width);
        alRight: Inc(Rect.Right, Nieuwebreedte - Besturing.Width);
      end;
  end;

  procedure DoUitlijnen(Auitlijn: TAlign);
  var
    I, J: Integer;
    Besturing: TControl;
  begin
    Uitlijnlijst.Clear;
    if (AControl <> nil) and (AControl.Align = Auitlijn) and AControl.Visible then
      Uitlijnlijst.Add(AControl);
    for I := 0 to ControlCount - 1 do
    begin
      Besturing := Controls[I];
      if (Besturing.Align = Auitlijn) and Besturing.Visible and (Besturing <> AControl) then
      begin
        J := 0;
        while (J < Uitlijnlijst.Count) and not Invoegvoor(Besturing, TControl(Uitlijnlijst[J]), Auitlijn) do Inc(J);
        Uitlijnlijst.Insert(J, Besturing);
      end;
    end;
    for I := 0 to Uitlijnlijst.Count - 1 do
      DoPositie(TControl(Uitlijnlijst[I]), Auitlijn);
  end;

  function Uitlijnwerk: Boolean;
  var
    I: Integer;
  begin
    Result := True;
    for I := ControlCount - 1 downto 0 do
      if Controls[I].Align <> alNone then Exit;
    Result := False;
  end;

begin
  if Uitlijnwerk then
  begin
    AdjustClientRect(Rect);
    Uitlijnlijst := TList.Create;
    try
      DoUitlijnen(alTop);
      DoUitlijnen(alBottom);
      DoUitlijnen(alLeft);
      DoUitlijnen(alRight);
      DoUitlijnen(alClient);
    finally
      Uitlijnlijst.Free;
    end;
  end;
end;

procedure TWinControl.AdjustSize;
begin
  inherited AdjustSize;
end;

function TWinControl.CanAutoSize(var NewWidth, NewHeight: Integer): Boolean;
begin
  Result := True;
end;

function TWinControl.CanResize(var NewWidth, NewHeight: Integer): Boolean;
begin
  Result := inherited CanResize(NewWidth, NewHeight);
end;

procedure TWinControl.ConstrainedResize(var MinWidth, MinHeight, MaxWidth, MaxHeight: Integer);
begin
  inherited ConstrainedResize(MinWidth, MinHeight, MaxWidth, MaxHeight);
end;

procedure TWinControl.ChangeScale(M, D: Integer);
begin
end;

procedure TWinControl.ScaleControls(M, D: Integer);
begin
end;

procedure TWinControl.ScaleBy(M, D: Integer);
begin
end;

procedure TWinControl.ScrollBy(DeltaX, DeltaY: Integer);
var
  I: Integer;
begin
  for I := 0 to ControlCount - 1 do
    with Controls[I] do SetBounds(Left + DeltaX, Top + DeltaY, Width, Height);
end;

function TWinControl.GetControlExtents: TRect;
var
  I: Integer;
begin
  Result := Rect(MaxInt, MaxInt, 0, 0);
  for I := 0 to ControlCount - 1 do
    with Controls[I] do
      if Visible then
      begin
        if Left < Result.Left then Result.Left := Left;
        if Top < Result.Top then Result.Top := Top;
        if Left + Width > Result.Right then Result.Right := Left + Width;
        if Top + Height > Result.Bottom then Result.Bottom := Top + Height;
      end;
end;

{ begrenzingen }

procedure TWinControl.SetBounds(ALeft, ATop, AWidth, AHeight: Integer);
var
  R: TRect;
begin
  if CheckNewSize(AWidth, AHeight) and
    ((ALeft <> FLeft) or (ATop <> FTop) or (AWidth <> FWidth) or (AHeight <> FHeight)) then
  begin
    if HandleAllocated then
    begin
      FLeft := ALeft;
      FTop := ATop;
      FWidth := AWidth;
      FHeight := AHeight;
      SetWindowPos(FHandle, 0, ALeft, ATop, AWidth, AHeight,
        SWP_NOZORDER or SWP_NOACTIVATE);
    end
    else
    begin
      FLeft := ALeft;
      FTop := ATop;
      FWidth := AWidth;
      FHeight := AHeight;
    end;
    UpdateAnchorRules;
    RequestAlign;
    if not (csLoading in ComponentState) then Resize;
    R := GetClientRect;
    if HandleAllocated or (FAlignLevel = 0) then AlignControls(nil, R);
  end;
end;

procedure TWinControl.UpdateBounds;
var
  R: TRect;
begin
  if not HandleAllocated then Exit;
  GetWindowRect(FHandle, R);
  if FParent <> nil then
  begin
    MapWindowPoints(0, FParent.FHandle, R, 2);
  end;
  UpdateBoundsRect(R);
end;

function TWinControl.GetClientOrigin: TPoint;
begin
  Result := Point(0, 0);
  if HandleAllocated then
    Windows.ClientToScreen(Handle, Result)
  else if Parent <> nil then
  begin
    Result := Parent.ClientOrigin;
    Inc(Result.X, Left);
    Inc(Result.Y, Top);
  end
  else
  begin
    Result.X := Left;
    Result.Y := Top;
  end;
end;

function TWinControl.GetClientRect: TRect;
begin
  if HandleAllocated then
    Windows.GetClientRect(FHandle, Result)
  else
    Result := Rect(0, 0, Width, Height);
end;

{ handles }

function TWinControl.HandleAllocated: Boolean;
begin
  Result := FHandle <> 0;
end;

procedure TWinControl.HandleNeeded;
begin
  if FHandle = 0 then
  begin
    if Parent <> nil then Parent.HandleNeeded;
    CreateHandle;
  end;
end;

function TWinControl.GetHandle: HWnd;
begin
  HandleNeeded;
  Result := FHandle;
end;

function TWinControl.GetParentHandle: HWnd;
begin
  if Parent <> nil then
    Result := Parent.Handle
  else
    Result := FParentWindow;
end;

function TWinControl.GetTopParentHandle: HWnd;
var
  C: TWinControl;
begin
  C := Self;
  while C.Parent <> nil do C := C.Parent;
  Result := C.FParentWindow;
  if Result = 0 then Result := C.Handle;
end;

function TWinControl.GetDeviceContext(var WindowHandle: HWnd): HDC;
begin
  if csDesigning in ComponentState then
    Result := GetDCEx(Handle, 0, 1)
  else
    Result := GetDC(Handle);
  if Result = 0 then raise EOutOfResources.Create('Cannot get device context');
  WindowHandle := FHandle;
end;

procedure TWinControl.SetParentWindow(Value: HWnd);
begin
  if (FParent = nil) and (FParentWindow <> Value) then
  begin
    if (FHandle <> 0) and (FParentWindow <> 0) and (Value <> 0) then
    begin
      FParentWindow := Value;
      Windows.SetParent(FHandle, Value);
    end
    else
    begin
      DestroyHandle;
      FParentWindow := Value;
    end;
    UpdateControlState;
  end;
end;

procedure TWinControl.AddBiDiModeExStyle(var ExStyle: DWORD);
begin
end;

procedure TWinControl.CreateParams(var Params: TCreateParams);
begin
  FillChar(Params, SizeOf(Params), 0);
  with Params do
  begin
    Caption := PChar(FText);
    Style := WS_CHILD or WS_CLIPSIBLINGS;
    AddBiDiModeExStyle(ExStyle);
    if csAcceptsControls in ControlStyle then
    begin
      Style := Style or WS_CLIPCHILDREN;
      ExStyle := ExStyle or WS_EX_CONTROLPARENT;
    end;
    if not (csDesigning in ComponentState) and not Enabled then
      Style := Style or WS_DISABLED;
    if FTabStop then Style := Style or WS_TABSTOP;
    X := FLeft;
    Y := FTop;
    Width := FWidth;
    Height := FHeight;
    if Parent <> nil then
      WndParent := Parent.GetHandle
    else
      WndParent := FParentWindow;
    WindowClass.style := CS_VREDRAW or CS_HREDRAW or CS_DBLCLKS;
    WindowClass.hCursor := LoadCursor(0, IDC_ARROW);
    WindowClass.hbrBackground := 0;
    StrPLCopy(WinClassName, ClassName, 63);
  end;
end;

procedure TWinControl.CreateWindowHandle(const Params: TCreateParams);
var
  Tkst: string;
  W: TZMWindow;
begin
  with Params do
  begin
    if Caption <> nil then Tkst := StrPas(Caption) else Tkst := '';
    FHandle := ZMCreateWindow(ExStyle, StrPas(WinClassName), Tkst, Style and not WS_VISIBLE,
      X, Y, Width, Height, WndParent, 0, MainWndProc, nil);
    W := ZMWindowObj(FHandle);
    if W <> nil then
    begin
      W.ClsStyle := WindowClass.style;
      W.ClsCursor := WindowClass.hCursor;
    end;
  end;
end;

procedure TWinControl.CreateWnd;
var
  Parameters: TCreateParams;
  Tijdelijkeklasse: TWndClass;
  Klasseregistreerd: Boolean;
begin
  CreateParams(Parameters);
  with Parameters do
  begin
    if (WndParent = 0) and (Style and WS_CHILD <> 0) then
      if (Owner <> nil) and (csReading in Owner.ComponentState) and (Owner is TWinControl) then
        WndParent := TWinControl(Owner).Handle
      else
        raise EInvalidOperation.CreateFmt('Control ''%s'' has no parent window', [Name]);
    Klasseregistreerd := False;
    if Klasseregistreerd then Tijdelijkeklasse := WindowClass;
    CreationControl := Self;
    FWinCreated := False;
    CreateWindowHandle(Parameters);
    CreationControl := nil;
    if FHandle = 0 then
      raise EOutOfResources.Create('Error creating window');
    if WinControls = nil then WinControls := TList.Create;
    WinControls.Add(Self);
    FWinCreated := True;
  end;
  if TabStop then ;
  UpdateBounds;
  Perform(WM_SETFONT, FFont.Handle, 1);
end;

procedure TWinControl.CreateHandle;
var
  I: Integer;
begin
  if FHandle = 0 then
  begin
    CreateWnd;
    SetProp;
    if Parent <> nil then
      SetWindowPos(FHandle, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
    for I := 0 to ControlCount - 1 do
      Controls[I].UpdateAnchorRules;
  end;
end;

procedure TWinControl.SetProp;
begin
end;

procedure TWinControl.DestroyWnd;
var
  Lengte: Integer;
begin
  Lengte := GetTextLen;
  if Lengte < 1 then FText := ''
  else
  begin
    SetString(FText, nil, Lengte);
    GetTextBuf(PChar(FText), Lengte + 1);
  end;
  DestroyWindowHandle;
end;

procedure TWinControl.DestroyWindowHandle;
var
  H: HWND;
begin
  Include(FControlState, csDestroyingHandle);
  try
    H := FHandle;
    if H <> 0 then
    begin
      if WinControls <> nil then WinControls.Remove(Self);
      FHandle := 0;
      FShowing := False;
      ZMDestroyWindow(H);
    end;
  finally
    Exclude(FControlState, csDestroyingHandle);
  end;
end;

procedure TWinControl.DestroyHandle;
var
  I: Integer;
begin
  if FHandle <> 0 then
  begin
    if FWinControls <> nil then
      for I := 0 to FWinControls.Count - 1 do
        TWinControl(FWinControls[I]).DestroyHandle;
    DestroyWnd;
  end;
end;

procedure TWinControl.RecreateWnd;
begin
  if FHandle <> 0 then
  begin
    DestroyHandle;
    UpdateControlState;
  end;
end;

procedure TWinControl.WMNCDestroy(var Message: TWMNCDestroy);
begin
  inherited;
  if FHandle <> 0 then
  begin
    if WinControls <> nil then WinControls.Remove(Self);
    FHandle := 0;
    FShowing := False;
  end;
end;

{ zichtbaarheid }

procedure TWinControl.UpdateShowing;
var
  Toonbesturing: Boolean;
  I: Integer;
begin
  Toonbesturing := (FVisible or (csDesigning in ComponentState) and
    not (csNoDesignVisible in ControlStyle)) and not (csReadingState in ControlState);
  if Toonbesturing then
  begin
    if FHandle = 0 then CreateHandle;
    if FWinControls <> nil then
      for I := 0 to FWinControls.Count - 1 do
        TWinControl(FWinControls[I]).UpdateShowing;
  end;
  if FHandle <> 0 then
    if FShowing <> Toonbesturing then
    begin
      FShowing := Toonbesturing;
      try
        Perform(CM_SHOWINGCHANGED, 0, 0);
      except
        FShowing := not Toonbesturing;
        raise;
      end;
    end;
end;

procedure TWinControl.UpdateControlState;
var
  Besturing: TWinControl;
begin
  Besturing := Self;
  while Besturing.Parent <> nil do
  begin
    Besturing := Besturing.Parent;
    if not Besturing.Showing then Exit;
  end;
  { besturingselementen op het hoogste niveau (formulieren, popups) en besturingselementen in een vreemd venster }
  if (Besturing.FParentWindow <> 0) or (Besturing.Parent = nil) then
    UpdateShowing;
end;

function TWinControl.IsTopLevelShowing: Boolean;
begin
  Result := (FParentWindow <> 0) or FShowing;
end;

procedure TWinControl.CMShowingChanged(var Message: TMessage);
const
  ShowFlags: array[Boolean] of Word = (
    SWP_NOSIZE or SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE or SWP_HIDEWINDOW,
    SWP_NOSIZE or SWP_NOMOVE or SWP_NOZORDER or SWP_NOACTIVATE or SWP_SHOWWINDOW);
begin
  SetWindowPos(FHandle, 0, 0, 0, 0, 0, ShowFlags[FShowing]);
end;

procedure TWinControl.CMVisibleChanged(var Message: TMessage);
begin
  if not FVisible and (Parent <> nil) then RemoveFocus(False);
  if not (csDesigning in ComponentState) or (csNoDesignVisible in ControlStyle) then
    UpdateControlState;
end;

procedure TWinControl.ShowControl(AControl: TControl);
begin
  if Parent <> nil then Parent.ShowControl(Self);
end;

{ tekenen }

procedure TWinControl.Invalidate;
begin
  if HandleAllocated then InvalidateRect(FHandle, nil, not (csOpaque in ControlStyle));
end;

procedure TWinControl.InvalidateFrame;
begin
  Invalidate;
end;

procedure TWinControl.Update;
begin
  if HandleAllocated then UpdateWindow(FHandle);
end;

procedure TWinControl.Repaint;
begin
  Invalidate;
  Update;
end;

procedure TWinControl.PaintWindow(DC: HDC);
var
  Bericht: TMessage;
begin
  FillChar(Bericht, SizeOf(Bericht), 0);
  Bericht.Msg := WM_PAINT;
  Bericht.WParam := WPARAM(DC);
  DefaultHandler(Bericht);
end;

procedure TWinControl.PaintControls(DC: HDC; First: TControl);
var
  I, Aantal, Bewaarindex: Integer;
  Randkwast: HBRUSH;
  C: TControl;
begin
  if FControls <> nil then
  begin
    I := 0;
    if First <> nil then
    begin
      I := FControls.IndexOf(First);
      if I < 0 then I := 0;
    end;
    Aantal := FControls.Count;
    while I < Aantal do
    begin
      C := TControl(FControls[I]);
      if not (C is TWinControl) then
        with C do
          if (Visible or (csDesigning in ComponentState) and not (csNoDesignVisible in ControlStyle)) and
            RectVisible(DC, Rect(Left, Top, Left + Width, Top + Height)) then
          begin
            if csPaintCopy in Self.FControlState then Include(FControlState, csPaintCopy);
            Bewaarindex := SaveDC(DC);
            MoveWindowOrg(DC, Left, Top);
            IntersectClipRect(DC, 0, 0, Width, Height);
            Perform(WM_PAINT, WPARAM(DC), 0);
            RestoreDC(DC, Bewaarindex);
            Exclude(FControlState, csPaintCopy);
          end;
      Inc(I);
    end;
  end;
  if FWinControls <> nil then
    for I := 0 to FWinControls.Count - 1 do
      with TWinControl(FWinControls[I]) do
        if FCtl3D and (csFramed in ControlStyle) and (Visible or (csDesigning in ComponentState) and
          not (csNoDesignVisible in ControlStyle)) then
        begin
          Randkwast := CreateSolidBrush(ColorToRGB(clBtnShadow));
          FrameRect(DC, Rect(Left - 1, Top - 1, Left + Width, Top + Height), Randkwast);
          DeleteObject(Randkwast);
          Randkwast := CreateSolidBrush(ColorToRGB(clBtnHighlight));
          FrameRect(DC, Rect(Left, Top, Left + Width + 1, Top + Height + 1), Randkwast);
          DeleteObject(Randkwast);
        end;
end;

procedure TWinControl.PaintHandler(var Message: TWMPaint);
var
  DC: HDC;
  PS: TPaintStruct;
begin
  DC := Message.DC;
  if DC = 0 then DC := BeginPaint(Handle, PS);
  try
    PaintWindow(DC);
    PaintControls(DC, nil);
  finally
    if Message.DC = 0 then EndPaint(Handle, PS);
  end;
end;

procedure TWinControl.WMPaint(var Message: TWMPaint);
begin
  PaintHandler(Message);
end;

procedure TWinControl.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  FillRect(Message.DC, ClientRect, FBrush.Handle);
  Message.Result := 1;
end;

procedure TWinControl.PaintTo(DC: HDC; X, Y: Integer);
var
  Bericht: TWMPaint;
  Bewaarindex: Integer;
begin
  Bewaarindex := SaveDC(DC);
  MoveWindowOrg(DC, X, Y);
  IntersectClipRect(DC, 0, 0, Width, Height);
  FillChar(Bericht, SizeOf(Bericht), 0);
  Bericht.Msg := WM_PAINT;
  Bericht.DC := DC;
  Perform(WM_ERASEBKGND, WPARAM(DC), 0);
  PaintHandler(Bericht);
  RestoreDC(DC, Bewaarindex);
end;

function TWinControl.PaletteChanged(Foreground: Boolean): Boolean;
begin
  Result := False;
end;

{ berichten }

procedure TWinControl.MainWndProc(var Message: TMessage);
begin
  try
    try
      WindowProc(Message);
    finally
      FreeDeviceContexts;
    end;
  except
    if Assigned(ZMHandleExceptionHook) then ZMHandleExceptionHook(Self) else raise;
  end;
end;

function TWinControl.IsControlMouseMsg(var Message: TWMMouse): Boolean;
var
  Besturing: TControl;
  P: TPoint;
begin
  if GetCapture = Handle then
  begin
    Besturing := nil;
    if (CaptureControl <> nil) and (CaptureControl.Parent = Self) then
      Besturing := CaptureControl;
  end
  else
    Besturing := ControlAtPos(SmallPointToPoint(Message.Pos), False);
  Result := False;
  if Besturing <> nil then
  begin
    P.X := Message.XPos - Besturing.Left;
    P.Y := Message.YPos - Besturing.Top;
    Message.Result := Besturing.Perform(Message.Msg, Message.Keys, PointToLParam(P));
    Result := True;
  end;
end;

procedure TWinControl.WndProc(var Message: TMessage);
var
  Formulier: TWinControl;
begin
  case Message.Msg of
    WM_SETFOCUS:
      begin
        Formulier := ParentFormOf(Self);
        if (Formulier <> nil) and Assigned(ZMSetFocusedControlHook) then
          if not ZMSetFocusedControlHook(Formulier, Self) then Exit;
      end;
    WM_KILLFOCUS:
      if csFocusing in ControlState then Exit;
    WM_NCHITTEST:
      begin
        inherited WndProc(Message);
        Exit;
      end;
    WM_MOUSEFIRST..WM_MOUSELAST:
      if IsControlMouseMsg(TWMMouse(Message)) then
      begin
        { grafische onderliggende elementen krijgen het bericht; het venster niet }
        Exit;
      end;
    WM_KEYFIRST..WM_KEYLAST:
      if Dragging then Exit;
  end;
  inherited WndProc(Message);
end;

procedure TWinControl.DefaultHandler(var Message);
begin
  if FHandle <> 0 then
  begin
    with TMessage(Message) do
    begin
      case Msg of
        WM_GETTEXT, WM_GETTEXTLENGTH, WM_SETTEXT:
          begin
            inherited DefaultHandler(Message);
            if (Msg = WM_SETTEXT) and (FHandle <> 0) then
              ZMWindowObj(FHandle).Text := FText;
            Exit;
          end;
        WM_ERASEBKGND:
          begin
            WMEraseBkgnd(TWMEraseBkgnd(Message));
            Exit;
          end;
        WM_KEYDOWN, WM_KEYUP, WM_CHAR, WM_SYSKEYDOWN, WM_SYSKEYUP, WM_SYSCHAR:
          begin
            HandleKeyMessage(TWMKey(Message));
            Exit;
          end;
        WM_CTLCOLORMSGBOX..WM_CTLCOLORSTATIC:
          Result := SendMessage(LParam, CN_BASE + Msg, WParam, LParam);
      end;
      if Msg < CM_BASE then
        Result := ZMDefWindowProc(FHandle, Msg, WParam, LParam);
    end;
  end
  else
    inherited DefaultHandler(Message);
end;

{ toetsenbord }

procedure TWinControl.HandleKeyMessage(var Message: TWMKey);
var
  Formulier: TWinControl;
  Masker: Integer;
begin
  case Message.Msg of
    WM_KEYDOWN, WM_SYSKEYDOWN:
      begin
        if DoKeyDown(Message) then Exit;
        if Message.CharCode = 0 then Exit;
        { dialoogtoetsen: Tab, pijltjes, Enter, Escape }
        Masker := 0;
        case Message.CharCode of
          VK_TAB: Masker := DLGC_WANTTAB;
          VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN: Masker := DLGC_WANTARROWS;
          VK_RETURN, VK_EXECUTE, VK_ESCAPE, VK_CANCEL: Masker := DLGC_WANTALLKEYS;
        end;
        if (Masker <> 0) and (Perform(CM_WANTSPECIALKEY, Message.CharCode, Message.KeyData) = 0) and
          (Perform(WM_GETDLGCODE, 0, 0) and Masker = 0) then
        begin
          Formulier := ParentFormOf(Self);
          if (Formulier <> nil) and (Formulier.Perform(CM_DIALOGKEY, Message.CharCode, Message.KeyData) <> 0) then
          begin
            Message.Result := 1;
            Exit;
          end;
        end;
        KeyDownDefault(Message);
      end;
    WM_CHAR, WM_SYSCHAR:
      begin
        if DoKeyPress(Message) then Exit;
        if Message.Msg = WM_SYSCHAR then
        begin
          Formulier := ParentFormOf(Self);
          if (Formulier <> nil) and (Formulier.Perform(CM_DIALOGCHAR, Message.CharCode, Message.KeyData) <> 0) then Exit;
        end;
        KeyPressDefault(Message);
      end;
    WM_KEYUP, WM_SYSKEYUP:
      DoKeyUp(Message);
  end;
end;

procedure TWinControl.KeyDownDefault(var Message: TWMKey);
begin
  if Message.Msg = WM_SYSKEYDOWN then
    ZMDefWindowProc(FHandle, Message.Msg, Message.CharCode, Message.KeyData);
end;

procedure TWinControl.KeyPressDefault(var Message: TWMKey);
begin
end;

function TWinControl.DoKeyDown(var Message: TWMKey): Boolean;
var
  Schakelstaat: TShiftState;
  Formulier: TWinControl;
begin
  Result := True;
  Formulier := ParentFormOf(Self);
  if (Formulier <> nil) and (Formulier <> Self) and Assigned(ZMKeyPreviewHook) and ZMKeyPreviewHook(Formulier) and
    TWinControl(Formulier).DoKeyDown(Message) then Exit;
  with Message do
  begin
    Schakelstaat := KeyDataToShiftState(KeyData);
    if not (csNoStdEvents in ControlStyle) then
    begin
      KeyDown(CharCode, Schakelstaat);
      if CharCode = 0 then Exit;
    end;
  end;
  Result := False;
end;

function TWinControl.DoKeyPress(var Message: TWMKey): Boolean;
var
  Formulier: TWinControl;
  Ch: Char;
begin
  Result := True;
  Formulier := ParentFormOf(Self);
  if (Formulier <> nil) and (Formulier <> Self) and Assigned(ZMKeyPreviewHook) and ZMKeyPreviewHook(Formulier) and
    TWinControl(Formulier).DoKeyPress(Message) then Exit;
  if not (csNoStdEvents in ControlStyle) then
    with Message do
    begin
      Ch := Char(CharCode);
      KeyPress(Ch);
      CharCode := Word(Ch);
      if Char(CharCode) = #0 then Exit;
    end;
  Result := False;
end;

function TWinControl.DoKeyUp(var Message: TWMKey): Boolean;
var
  Schakelstaat: TShiftState;
  Formulier: TWinControl;
begin
  Result := True;
  Formulier := ParentFormOf(Self);
  if (Formulier <> nil) and (Formulier <> Self) and Assigned(ZMKeyPreviewHook) and ZMKeyPreviewHook(Formulier) and
    TWinControl(Formulier).DoKeyUp(Message) then Exit;
  with Message do
  begin
    Schakelstaat := KeyDataToShiftState(KeyData);
    if not (csNoStdEvents in ControlStyle) then
    begin
      KeyUp(CharCode, Schakelstaat);
      if CharCode = 0 then Exit;
    end;
  end;
  Result := False;
end;

procedure TWinControl.KeyDown(var Key: Word; Shift: TShiftState);
begin
  if Assigned(FOnKeyDown) then FOnKeyDown(Self, Key, Shift);
end;

procedure TWinControl.KeyUp(var Key: Word; Shift: TShiftState);
begin
  if Assigned(FOnKeyUp) then FOnKeyUp(Self, Key, Shift);
end;

procedure TWinControl.KeyPress(var Key: Char);
begin
  if Assigned(FOnKeyPress) then FOnKeyPress(Self, Key);
end;

function TWinControl.WantKey(Key: Word): Boolean;
begin
  Result := False;
end;

procedure TWinControl.CMDialogKey(var Message: TCMDialogKey);
begin
  Broadcast(Message);
end;

procedure TWinControl.CMDialogChar(var Message: TCMDialogChar);
begin
  Broadcast(Message);
end;

function TWinControl.DoMouseWheel(Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint): Boolean;
begin
  Result := False;
  if Assigned(FOnMouseWheel) then FOnMouseWheel(Self, Shift, WheelDelta, MousePos, Result);
  if not Result then
    if WheelDelta < 0 then Result := DoMouseWheelDown(Shift, MousePos)
    else Result := DoMouseWheelUp(Shift, MousePos);
end;

function TWinControl.DoMouseWheelDown(Shift: TShiftState; MousePos: TPoint): Boolean;
begin
  Result := False;
  if Assigned(FOnMouseWheelDown) then FOnMouseWheelDown(Self, Shift, MousePos, Result);
end;

function TWinControl.DoMouseWheelUp(Shift: TShiftState; MousePos: TPoint): Boolean;
begin
  Result := False;
  if Assigned(FOnMouseWheelUp) then FOnMouseWheelUp(Self, Shift, MousePos, Result);
end;

procedure TWinControl.WMMouseWheel(var Message: TWMMouseWheel);
begin
  if DoMouseWheel(KeysToShiftState(Message.Keys), Message.WheelDelta,
    SmallPointToPoint(Message.Pos)) then
    Message.Result := 1
  else if Parent <> nil then
    with TMessage(Message) do
      Result := Parent.Perform(Msg, WParam, LParam);
end;

{ focus }

function TWinControl.CanFocus: Boolean;
var
  Besturing: TWinControl;
begin
  { zoals de VCL: elk besturingselement tot (exclusief) het formulier op het hoogste niveau moet
    zichtbaar en ingeschakeld zijn }
  Result := False;
  Besturing := Self;
  while Besturing.Parent <> nil do
  begin
    if not (Besturing.FVisible and Besturing.Enabled) then Exit;
    Besturing := Besturing.Parent;
  end;
  Result := True;
end;

function TWinControl.Focused: Boolean;
begin
  Result := (FHandle <> 0) and (GetFocus = FHandle);
end;

procedure TWinControl.SetFocus;
var
  Ouder: TWinControl;
begin
  Ouder := ParentFormOf(Self);
  if (Ouder <> nil) and Assigned(ZMFocusControlHook) then
    ZMFocusControlHook(Ouder, Self)
  else if FParentWindow <> 0 then
    Windows.SetFocus(Handle)
  else
    ValidParentForm(Self);
end;

procedure TWinControl.ValidParentForm(Control: TControl);
begin
  Windows.SetFocus(Handle);
end;

procedure TWinControl.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
end;

procedure TWinControl.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
end;

procedure TWinControl.CMEnter(var Message: TCMEnter);
begin
  DoEnter;
end;

procedure TWinControl.CMExit(var Message: TCMExit);
begin
  DoExit;
end;

procedure TWinControl.DoEnter;
begin
  if Assigned(FOnEnter) then FOnEnter(Self);
end;

procedure TWinControl.DoExit;
begin
  if Assigned(FOnExit) then FOnExit(Self);
end;

procedure TWinControl.GetTabOrderList(List: TList);
var
  I: Integer;
  Besturing: TWinControl;
begin
  if FTabList <> nil then
    for I := 0 to FTabList.Count - 1 do
    begin
      Besturing := TWinControl(FTabList[I]);
      List.Add(Besturing);
      Besturing.GetTabOrderList(List);
    end;
end;

function TWinControl.FindNextControl(CurControl: TWinControl; GoForward, CheckTabStop, CheckParent: Boolean): TWinControl;
var
  I, Startindex: Integer;
  Lijst: TList;
begin
  Result := nil;
  Lijst := TList.Create;
  try
    GetTabOrderList(Lijst);
    if Lijst.Count > 0 then
    begin
      Startindex := Lijst.IndexOf(CurControl);
      if Startindex = -1 then
        if GoForward then Startindex := Lijst.Count - 1 else Startindex := 0;
      I := Startindex;
      repeat
        if GoForward then
        begin
          Inc(I);
          if I = Lijst.Count then I := 0;
        end
        else
        begin
          if I = 0 then I := Lijst.Count;
          Dec(I);
        end;
        CurControl := TWinControl(Lijst[I]);
        if CurControl.CanFocus and (not CheckTabStop or CurControl.TabStop) and
          (not CheckParent or (CurControl.Parent = Self)) then
          Result := CurControl;
      until (Result <> nil) or (I = Startindex);
    end;
  finally
    Lijst.Free;
  end;
end;

procedure TWinControl.SelectNext(CurControl: TWinControl; GoForward, CheckTabStop: Boolean);
begin
  CurControl := FindNextControl(CurControl, GoForward, CheckTabStop, not CheckTabStop);
  if CurControl <> nil then CurControl.SetFocus;
end;

procedure TWinControl.SelectFirst;
var
  Besturing: TWinControl;
begin
  Besturing := FindNextControl(nil, True, True, False);
  if Besturing = nil then Besturing := FindNextControl(nil, True, False, False);
  if Besturing <> nil then Besturing.SetFocus;
end;

function TWinControl.GetTabOrder: TTabOrder;
begin
  if FParent <> nil then
    Result := FParent.FTabList.IndexOf(Self)
  else
    Result := -1;
end;

procedure TWinControl.UpdateTabOrder(Value: TTabOrder);
var
  Huidigindex, Aantal: Integer;
begin
  Huidigindex := GetTabOrder;
  if Huidigindex >= 0 then
  begin
    Aantal := FParent.FTabList.Count;
    if Value < 0 then Value := 0;
    if Value >= Aantal then Value := Aantal - 1;
    if Value <> Huidigindex then
    begin
      FParent.FTabList.Delete(Huidigindex);
      FParent.FTabList.Insert(Value, Self);
    end;
  end;
end;

procedure TWinControl.SetTabOrder(Value: TTabOrder);
begin
  if csReadingState in ControlState then
    FTabOrder := Value
  else
    UpdateTabOrder(Value);
end;

procedure TWinControl.SetTabStop(Value: Boolean);
begin
  FTabStop := Value;
end;

procedure TWinControl.SetZOrderPosition(Position: Integer);
var
  I, Aantal: Integer;
  Positie: HWND;
begin
  if FParent <> nil then
  begin
    I := FParent.FControls.IndexOf(Self);
    if I >= 0 then
    begin
      Aantal := FParent.FControls.Count;
      if Position < 0 then Position := 0;
      if Position >= Aantal then Position := Aantal - 1;
      if Position <> I then
      begin
        FParent.FControls.Delete(I);
        FParent.FControls.Insert(Position, Self);
      end;
    end;
    if FHandle <> 0 then
    begin
      if Position = 0 then Positie := HWND_BOTTOM
      else if Position = FParent.FControls.Count - 1 then Positie := HWND_TOP
      else Positie := HWND_TOP;
      SetWindowPos(FHandle, Positie, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
    end;
  end;
end;

procedure TWinControl.SetZOrder(TopMost: Boolean);
const
  WindowPos: array[Boolean] of HWND = (HWND_BOTTOM, HWND_TOP);
var
  N, M: Integer;
begin
  if FParent <> nil then
  begin
    if TopMost then N := FParent.FControls.Count - 1 else N := 0;
    M := 0;
    if FParent.FWinControls <> nil then M := FParent.FWinControls.Count;
    if M = 0 then ;
    SetZOrderPosition(N);
  end
  else if FHandle <> 0 then
    SetWindowPos(FHandle, WindowPos[TopMost], 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
end;

{ diversen }

procedure TWinControl.SetBorderWidth(Value: TBorderWidth);
begin
  if FBorderWidth <> Value then
  begin
    FBorderWidth := Value;
    Realign;
    Invalidate;
  end;
end;

procedure TWinControl.SetCtl3D(Value: Boolean);
begin
  if FCtl3D <> Value then
  begin
    FCtl3D := Value;
    FParentCtl3D := False;
    Perform(CM_CTL3DCHANGED, 0, 0);
  end;
end;

procedure TWinControl.SetParentCtl3D(Value: Boolean);
begin
  if FParentCtl3D <> Value then
  begin
    FParentCtl3D := Value;
    if FParent <> nil then Perform(CM_PARENTCTL3DCHANGED, 0, 0);
  end;
end;

function TWinControl.IsCtl3DStored: Boolean;
begin
  Result := not ParentCtl3D;
end;

function TWinControl.GetParentBackground: Boolean;
begin
  Result := False;
end;

procedure TWinControl.ReloadDockedControl(const AControlName: string; var AControl: TControl);
begin
  AControl := nil;
end;

procedure TWinControl.ResetIme;
begin
end;

procedure TWinControl.WMSetCursor(var Message: TWMSetCursor);
var
  Cursor: TCursor;
  Besturing: TControl;
  P: TPoint;
begin
  with Message do
    if CursorWnd = FHandle then
    begin
      Cursor := Screen_Cursor;
      if Cursor = crDefault then
      begin
        GetCursorPos(P);
        Besturing := ControlAtPos(ScreenToClient(P), False);
        if (Besturing <> nil) and (Besturing.Cursor <> crDefault) then
          Cursor := Besturing.Cursor
        else
          Cursor := FCursor;
      end;
      if Cursor <> crDefault then
      begin
        if Assigned(ZMCursorHook) then Windows.SetCursor(ZMCursorHook(Cursor));
        Result := 1;
        Exit;
      end;
    end;
  inherited;
end;

function TWinControl.Screen_Cursor: TCursor;
begin
  if Assigned(ZMScreenCursorHook) then Result := ZMScreenCursorHook() else Result := crDefault;
end;

procedure TWinControl.WMSize(var Message: TWMSize);
begin
  UpdateBounds;
  inherited;
  Realign;
end;

procedure TWinControl.WMMove(var Message: TWMMove);
begin
  inherited;
  UpdateBounds;
end;

procedure TWinControl.WMWindowPosChanged(var Message: TWMWindowPosChanged);
var
  Omlijnd, Verplaatst, Gedimensioneerd: Boolean;
begin
  Omlijnd := FCtl3D and (csFramed in ControlStyle) and (Parent <> nil) and
    (Message.WindowPos <> nil) and (Message.WindowPos^.flags and SWP_NOREDRAW = 0);
  Verplaatst := (Message.WindowPos <> nil) and (Message.WindowPos^.flags and SWP_NOMOVE = 0) and IsWindowVisible(FHandle);
  Gedimensioneerd := (Message.WindowPos <> nil) and (Message.WindowPos^.flags and SWP_NOSIZE = 0) and IsWindowVisible(FHandle);
  if Omlijnd and (Verplaatst or Gedimensioneerd) then InvalidateFrame;
  if not (csDestroyingHandle in ControlState) then UpdateBounds;
  inherited;
end;

procedure TWinControl.CMEnabledChanged(var Message: TMessage);
begin
  if not Enabled and (Parent <> nil) then RemoveFocus(False);
  if HandleAllocated and not (csDesigning in ComponentState) then
    EnableWindow(FHandle, Enabled);
  Invalidate;
end;

procedure TWinControl.CMColorChanged(var Message: TMessage);
begin
  inherited;
  FBrush.Color := FColor;
  NotifyControls(CM_PARENTCOLORCHANGED);
end;

procedure TWinControl.CMFontChanged(var Message: TMessage);
begin
  inherited;
  if HandleAllocated then Perform(WM_SETFONT, FFont.Handle, 0);
  NotifyControls(CM_PARENTFONTCHANGED);
end;

procedure TWinControl.CMTextChanged(var Message: TMessage);
begin
  inherited;
end;

{ ---------------------------------------------------------------- TGraphicControl }

constructor TGraphicControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCanvas := TControlCanvas.Create;
  TControlCanvas(FCanvas).Control := Self;
end;

destructor TGraphicControl.Destroy;
begin
  if CaptureControl = Self then SetCaptureControl(nil);
  FCanvas.Free;
  inherited Destroy;
end;

procedure TGraphicControl.WMPaint(var Message: TWMPaint);
begin
  if Message.DC <> 0 then
  begin
    Canvas.Lock;
    try
      Canvas.Handle := Message.DC;
      try
        Paint;
      finally
        Canvas.Handle := 0;
      end;
    finally
      Canvas.Unlock;
    end;
  end;
end;

procedure TGraphicControl.Paint;
begin
end;

{ ---------------------------------------------------------------- TCustomControl }

constructor TCustomControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCanvas := TControlCanvas.Create;
  TControlCanvas(FCanvas).Control := Self;
end;

destructor TCustomControl.Destroy;
begin
  FCanvas.Free;
  inherited Destroy;
end;

procedure TCustomControl.WMPaint(var Message: TWMPaint);
begin
  Include(FControlState, csCustomPaint);
  inherited;
  Exclude(FControlState, csCustomPaint);
end;

procedure TCustomControl.PaintWindow(DC: HDC);
begin
  FCanvas.Lock;
  try
    FCanvas.Handle := DC;
    try
      TControlCanvas(FCanvas).UpdateTextFlags;
      Paint;
    finally
      FCanvas.Handle := 0;
    end;
  finally
    FCanvas.Unlock;
  end;
end;

procedure TCustomControl.Paint;
begin
end;

{ ---------------------------------------------------------------- THintWindow }

constructor THintWindow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Color := clInfoBk;
  Canvas.Font := Font;
  Canvas.Brush.Style := bsClear;
end;

procedure THintWindow.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  with Params do
  begin
    Style := WS_POPUP or WS_BORDER;
    ExStyle := WS_EX_TOOLWINDOW or WS_EX_TOPMOST;
  end;
end;

procedure THintWindow.Paint;
var
  R: TRect;
begin
  R := ClientRect;
  Inc(R.Left, 2);
  Inc(R.Top, 2);
  Canvas.Font.Color := clInfoText;
  DrawText(Canvas.Handle, PChar(Caption), -1, R, DT_LEFT or DT_NOPREFIX or DT_WORDBREAK);
end;

procedure THintWindow.ActivateHint(Rect: TRect; const AHint: string);
begin
  FActivating := True;
  try
    Caption := AHint;
    SetBounds(Rect.Left, Rect.Top, Rect.Right - Rect.Left, Rect.Bottom - Rect.Top);
    SetWindowPos(Handle, HWND_TOPMOST, Rect.Left, Rect.Top, Width, Height,
      SWP_SHOWWINDOW or SWP_NOACTIVATE);
    Invalidate;
  finally
    FActivating := False;
  end;
end;

function THintWindow.CalcHintRect(MaxWidth: Integer; const AHint: string; AData: Pointer): TRect;
begin
  Result := Rect(0, 0, MaxWidth, 0);
  DrawText(Canvas.Handle, PChar(AHint), -1, Result, DT_CALCRECT or DT_LEFT or DT_WORDBREAK or DT_NOPREFIX);
  Inc(Result.Right, 6);
  Inc(Result.Bottom, 2);
end;

function THintWindow.IsHintMsg(var Msg: TMsg): Boolean;
begin
  Result := (Msg.message = WM_KEYDOWN) or ((Msg.message >= WM_LBUTTONDOWN) and (Msg.message <= WM_MOUSELAST));
end;

procedure THintWindow.ReleaseHandle;
begin
  DestroyHandle;
end;

{ ---------------------------------------------------------------- TCustomImageList }

constructor TCustomImageList.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FWidth := 16;
  FHeight := 16;
  FBitmaps := TList.Create;
end;

constructor TCustomImageList.CreateSize(AWidth, AHeight: Integer);
begin
  Create(nil);
  FWidth := AWidth;
  FHeight := AHeight;
end;

destructor TCustomImageList.Destroy;
begin
  Clear;
  FBitmaps.Free;
  inherited Destroy;
end;

function TCustomImageList.GetCount: Integer;
begin
  Result := FBitmaps.Count;
end;

function TCustomImageList.Add(Image, Mask: TBitmap): Integer;
var
  B: TBitmap;
begin
  B := TBitmap.Create;
  B.Assign(Image);
  Result := FBitmaps.Add(B);
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TCustomImageList.Clear;
var
  I: Integer;
begin
  for I := 0 to FBitmaps.Count - 1 do TBitmap(FBitmaps[I]).Free;
  FBitmaps.Clear;
end;

procedure TCustomImageList.Delete(Index: Integer);
begin
  TBitmap(FBitmaps[Index]).Free;
  FBitmaps.Delete(Index);
end;

procedure TCustomImageList.Draw(Canvas: TCanvas; X, Y, Index: Integer; Enabled: Boolean);
begin
  if (Index >= 0) and (Index < FBitmaps.Count) then
    Canvas.Draw(X, Y, TBitmap(FBitmaps[Index]));
end;

procedure TCustomImageList.GetBitmap(Index: Integer; Image: TBitmap);
begin
  if (Index >= 0) and (Index < FBitmaps.Count) then Image.Assign(TBitmap(FBitmaps[Index]));
end;

{ ---------------------------------------------------------------- drag objects }

procedure TDragObject.Finished(Target: TObject; X, Y: Integer; Accepted: Boolean);
begin
end;

constructor TBaseDragControlObject.Create(AControl: TControl);
begin
  inherited Create;
  FControl := AControl;
end;

initialization
  RegisterIntegerConsts(TypeInfo(TCursor), IdentToCursor, CursorToIdent);
finalization
  FreeAndNil(WinControls);
  FreeAndNil(CanvasList);
end.

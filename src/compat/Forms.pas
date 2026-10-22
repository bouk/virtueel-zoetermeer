unit Forms;

{ Delphi 5-subset van de Forms-unit, draagbaar: TCustomForm/TForm (met DFM-streaming uit de
  originele ROS.exe-resources), TScreen, TApplication, AllocateHWnd.

  TCustomForm.Create laadt de RCDATA-resource met de naam van de formulierklasse (en
  zijn voorouders, zoals InitInheritedComponent) uit ROS.exe met een TReader. De
  applicatie-berichtenlus loopt op de compat-berichtenwachtrij; al het blokkerende
  wachten verloopt via Application.HandleMessage -> Idle -> WaitMessage. }

{$MODE DELPHI}{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Menus, Controls;

type
  TScrollBarKind = (sbHorizontal, sbVertical);
  TScrollBarInc = 1..32767;
  TScrollBarStyle = (ssRegular, ssFlat, ssHotTrack);
  TWindowState = (wsNormal, wsMinimized, wsMaximized);
  TFormStyle = (fsNormal, fsMDIChild, fsMDIForm, fsStayOnTop);
  TBorderIcon = (biSystemMenu, biMinimize, biMaximize, biHelp);
  TBorderIcons = set of TBorderIcon;
  TPosition = (poDesigned, poDefault, poDefaultPosOnly, poDefaultSizeOnly, poScreenCenter,
    poDesktopCenter, poMainFormCenter, poOwnerFormCenter);
  TDefaultMonitor = (dmDesktop, dmPrimary, dmMainForm, dmActiveForm);
  TPrintScale = (poNone, poProportional, poPrintToFit);
  TShowAction = (saIgnore, saRestore, saMinimize, saMaximize);
  TTileMode = (tbHorizontal, tbVertical);
  TCloseAction = (caNone, caHide, caFree, caMinimize);
  TFormState = set of (fsCreating, fsVisible, fsShowing, fsModal, fsCreatedMDIChild, fsActivated);
  TCloseEvent = procedure(Sender: TObject; var Action: TCloseAction) of object;
  TCloseQueryEvent = procedure(Sender: TObject; var CanClose: Boolean) of object;
  TShortCutEvent = procedure(var Msg: TWMKey; var Handled: Boolean) of object;
  THelpEvent = function(Command: Word; Data: Longint; var CallHelp: Boolean): Boolean of object;
  TMessageEvent = procedure(var Msg: TMsg; var Handled: Boolean) of object;
  TExceptionEvent = procedure(Sender: TObject; E: Exception) of object;
  TIdleEvent = procedure(Sender: TObject; var Done: Boolean) of object;
  TShowHintEvent = procedure(var HintStr: string; var CanShow: Boolean; var HintInfo: Pointer) of object;
  TWindowHook = function(var Message: TMessage): Boolean of object;

  TForm = class;

  TControlScrollBar = class(TPersistent)
  private
    FControl: TWinControl;
    FIncrement: TScrollBarInc;
    FKind: TScrollBarKind;
    FMargin: Word;
    FPosition: Integer;
    FRange: Integer;
    FSize: Integer;
    FStyle: TScrollBarStyle;
    FThumbSize: Integer;
    FTracking: Boolean;
    FVisible: Boolean;
    FButtonSize: Integer;
    FColor: TColor;
    FParentColor: Boolean;
    FSmooth: Boolean;
    procedure SetPosition(Value: Integer);
    procedure SetRange(Value: Integer);
    procedure SetVisible(Value: Boolean);
  public
    constructor Create(AControl: TWinControl; AKind: TScrollBarKind);
    procedure Assign(Source: TPersistent); override;
    procedure ChangeBiDiPosition;
    property Kind: TScrollBarKind read FKind;
    function IsScrollBarVisible: Boolean;
    property ScrollPos: Integer read FPosition;
  published
    property ButtonSize: Integer read FButtonSize write FButtonSize default 0;
    property Color: TColor read FColor write FColor default clBtnHighlight;
    property Increment: TScrollBarInc read FIncrement write FIncrement default 8;
    property Margin: Word read FMargin write FMargin default 0;
    property ParentColor: Boolean read FParentColor write FParentColor default True;
    property Position: Integer read FPosition write SetPosition default 0;
    property Range: Integer read FRange write SetRange default 0;
    property Smooth: Boolean read FSmooth write FSmooth default False;
    property Size: Integer read FSize write FSize default 0;
    property Style: TScrollBarStyle read FStyle write FStyle default ssRegular;
    property ThumbSize: Integer read FThumbSize write FThumbSize default 0;
    property Tracking: Boolean read FTracking write FTracking default False;
    property Visible: Boolean read FVisible write SetVisible default True;
  end;

  TScrollingWinControl = class(TWinControl)
  private
    FHorzScrollBar: TControlScrollBar;
    FVertScrollBar: TControlScrollBar;
    FAutoScroll: Boolean;
    procedure SetHorzScrollBar(Value: TControlScrollBar);
    procedure SetVertScrollBar(Value: TControlScrollBar);
  protected
    procedure AdjustClientRect(var Rect: TRect); override;
    procedure AlignControls(AControl: TControl; var ARect: TRect); override;
    function AutoScrollEnabled: Boolean; virtual;
    procedure AutoScrollInView(AControl: TControl); virtual;
    procedure ChangeScale(M, D: Integer); override;
    procedure CreateWnd; override;
    property AutoScroll: Boolean read FAutoScroll write FAutoScroll default True;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DisableAutoRange;
    procedure EnableAutoRange;
    procedure ScrollInView(AControl: TControl);
  published
    property HorzScrollBar: TControlScrollBar read FHorzScrollBar write SetHorzScrollBar;
    property VertScrollBar: TControlScrollBar read FVertScrollBar write SetVertScrollBar;
  end;

  TScrollBox = class(TScrollingWinControl)
  private
    FBorderStyle: TBorderStyle;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Align;
    property AutoScroll;
    property BorderStyle: TBorderStyle read FBorderStyle write FBorderStyle default bsSingle;
    property Color nodefault;
    property Ctl3D;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnResize;
  end;

  TCustomFrame = class(TScrollingWinControl)
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TFrame = class(TCustomFrame)
  published
    property Align;
    property Color nodefault;
    property Ctl3D;
    property Font;
    property ParentColor;
    property ParentFont;
    property TabOrder;
    property TabStop;
    property Visible;
  end;

  TCustomForm = class(TScrollingWinControl)
  private
    FActiveControl: TWinControl;
    FFocusedControl: TWinControl;
    FBorderIcons: TBorderIcons;
    FBorderStyle: TFormBorderStyle;
    FSizeChanging: Boolean;
    FWindowState: TWindowState;
    FShowAction: TShowAction;
    FKeyPreview: Boolean;
    FActive: Boolean;
    FFormStyle: TFormStyle;
    FPosition: TPosition;
    FDefaultMonitor: TDefaultMonitor;
    FTileMode: TTileMode;
    FDropTarget: Boolean;
    FOldCreateOrder: Boolean;
    FPrintScale: TPrintScale;
    FCanvas: TControlCanvas;
    FHelpFile: string;
    FIcon: TIcon;
    FMenu: TMainMenu;
    FModalResult: TModalResult;
    FDesigner: TObject;
    FClientHandle: HWND;
    FWindowMenu: TMenuItem;
    FPixelsPerInch: Integer;
    FObjectMenuItem: TMenuItem;
    FTextHeight: Integer;
    FScaled: Boolean;
    FPositioned: Boolean;
    FOnActivate: TNotifyEvent;
    FOnClose: TCloseEvent;
    FOnCloseQuery: TCloseQueryEvent;
    FOnDeactivate: TNotifyEvent;
    FOnHelp: THelpEvent;
    FOnHide: TNotifyEvent;
    FOnPaint: TNotifyEvent;
    FOnShortCut: TShortCutEvent;
    FOnShow: TNotifyEvent;
    FOnCreate: TNotifyEvent;
    FOnDestroy: TNotifyEvent;
    procedure DoClose(var Action: TCloseAction);
    function GetActiveMDIChild: TForm;
    function GetCanvas: TCanvas;
    function GetMDIChildCount: Integer;
    function GetMDIChildren(I: Integer): TForm;
    function GetPixelsPerInch: Integer;
    function GetScaled: Boolean;
    function GetTextHeight: Integer;
    function IsAutoScrollStored: Boolean;
    function IsForm: Boolean;
    function IsIconStored: Boolean;
    procedure ReadIgnoreFontProperty(Reader: TReader);
    procedure ReadTextHeight(Reader: TReader);
    procedure SetActive(Value: Boolean);
    procedure SetActiveControl(Control: TWinControl);
    procedure SetBorderIcons(Value: TBorderIcons);
    procedure SetBorderStyle(Value: TFormBorderStyle);
    procedure SetFormStyle(Value: TFormStyle);
    procedure SetIcon(Value: TIcon);
    procedure SetMenu(Value: TMainMenu);
    procedure SetPixelsPerInch(Value: Integer);
    procedure SetPosition(Value: TPosition);
    procedure SetScaled(Value: Boolean);
    procedure SetVisible(Value: Boolean);
    procedure SetWindowFocus;
    procedure SetWindowMenu(Value: TMenuItem);
    procedure SetObjectMenuItem(Value: TMenuItem);
    procedure SetWindowState(Value: TWindowState);
    procedure WriteTextHeight(Writer: TWriter);
    procedure ApplyPosition;
    function NCInsets: TRect;
    procedure WMClose(var Message: TWMClose); message WM_CLOSE;
    procedure WMActivate(var Message: TWMActivate); message WM_ACTIVATE;
    procedure WMQueryEndSession(var Message: TWMQueryEndSession); message WM_QUERYENDSESSION;
    procedure CMActivate(var Message: TCMActivate); message CM_ACTIVATE;
    procedure CMDeactivate(var Message: TCMDeactivate); message CM_DEACTIVATE;
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;
    procedure CMRelease(var Message: TMessage); message CM_RELEASE;
  protected
    FFormState: TFormState;
    procedure Activate; dynamic;
    procedure ActiveChanged; dynamic;
    procedure AlignControls(AControl: TControl; var Rect: TRect); override;
    procedure BeginAutoDrag; dynamic;
    procedure ChangeScale(M, D: Integer); override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWindowHandle(const Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure Deactivate; dynamic;
    procedure DefineProperties(Filer: TFiler); override;
    procedure DestroyWindowHandle; override;
    procedure DoCreate; virtual;
    procedure DoDestroy; virtual;
    procedure DoHide; dynamic;
    procedure DoShow; dynamic;
    function GetClientRect: TRect; override;
    function GetFloating: Boolean;
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    function HandleCreateException: Boolean; dynamic;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Paint; dynamic;
    procedure PaintWindow(DC: HDC); override;
    function PaletteChanged(Foreground: Boolean): Boolean; override;
    procedure ReadState(Reader: TReader); override;
    procedure Resizing(State: TWindowState); virtual;
    procedure SetChildOrder(Child: TComponent; Order: Integer); override;
    procedure SetParent(AParent: TWinControl); override;
    procedure UpdateActions; virtual;
    procedure UpdateWindowState;
    procedure ValidateRename(AComponent: TComponent; const CurName, NewName: string); override;
    procedure VisibleChanging; override;
    procedure WndProc(var Message: TMessage); override;
    property ActiveMDIChild: TForm read GetActiveMDIChild;
    property BorderIcons: TBorderIcons read FBorderIcons write SetBorderIcons stored IsForm
      default [biSystemMenu, biMinimize, biMaximize];
    property AutoScroll stored IsAutoScrollStored;
    property ClientHandle: HWND read FClientHandle;
    property ClientHeight stored IsForm;
    property ClientWidth stored IsForm;
    property DefaultMonitor: TDefaultMonitor read FDefaultMonitor write FDefaultMonitor default dmActiveForm;
    property FormStyle: TFormStyle read FFormStyle write SetFormStyle stored IsForm default fsNormal;
    property Height stored IsForm;
    property HorzScrollBar stored IsForm;
    property Icon: TIcon read FIcon write SetIcon stored IsIconStored;
    property MDIChildCount: Integer read GetMDIChildCount;
    property MDIChildren[I: Integer]: TForm read GetMDIChildren;
    property ObjectMenuItem: TMenuItem read FObjectMenuItem write SetObjectMenuItem stored IsForm;
    property OldCreateOrder: Boolean read FOldCreateOrder write FOldCreateOrder;
    property PixelsPerInch: Integer read GetPixelsPerInch write SetPixelsPerInch stored False;
    property Position: TPosition read FPosition write SetPosition stored IsForm default poDesigned;
    property PrintScale: TPrintScale read FPrintScale write FPrintScale stored IsForm default poProportional;
    property Scaled: Boolean read GetScaled write SetScaled stored IsForm default True;
    property TileMode: TTileMode read FTileMode write FTileMode default tbHorizontal;
    property VertScrollBar stored IsForm;
    property Visible write SetVisible default False;
    property Width stored IsForm;
    property WindowMenu: TMenuItem read FWindowMenu write SetWindowMenu stored IsForm;
    property OnActivate: TNotifyEvent read FOnActivate write FOnActivate stored IsForm;
    property OnCanResize stored IsForm;
    property OnClick stored IsForm;
    property OnClose: TCloseEvent read FOnClose write FOnClose stored IsForm;
    property OnCloseQuery: TCloseQueryEvent read FOnCloseQuery write FOnCloseQuery stored IsForm;
    property OnCreate: TNotifyEvent read FOnCreate write FOnCreate stored IsForm;
    property OnDblClick stored IsForm;
    property OnDestroy: TNotifyEvent read FOnDestroy write FOnDestroy stored IsForm;
    property OnDeactivate: TNotifyEvent read FOnDeactivate write FOnDeactivate stored IsForm;
    property OnDragDrop stored IsForm;
    property OnDragOver stored IsForm;
    property OnHelp: THelpEvent read FOnHelp write FOnHelp;
    property OnHide: TNotifyEvent read FOnHide write FOnHide stored IsForm;
    property OnKeyDown stored IsForm;
    property OnKeyPress stored IsForm;
    property OnKeyUp stored IsForm;
    property OnMouseDown stored IsForm;
    property OnMouseMove stored IsForm;
    property OnMouseUp stored IsForm;
    property OnPaint: TNotifyEvent read FOnPaint write FOnPaint stored IsForm;
    property OnResize stored IsForm;
    property OnShortCut: TShortCutEvent read FOnShortCut write FOnShortCut;
    property OnShow: TNotifyEvent read FOnShow write FOnShow stored IsForm;
  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateNew(AOwner: TComponent; Dummy: Integer = 0); virtual;
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;
    procedure Close;
    function CloseQuery: Boolean; virtual;
    procedure DefaultHandler(var Message); override;
    procedure DefocusControl(Control: TWinControl; Removing: Boolean);
    procedure FocusControl(Control: TWinControl);
    function GetFormImage: TBitmap;
    procedure Hide;
    function IsShortCut(var Message: TWMKey): Boolean; dynamic;
    procedure Print;
    procedure Release;
    procedure SendCancelMode(Sender: TControl);
    procedure SetFocus; override;
    function SetFocusedControl(Control: TWinControl): Boolean; virtual;
    procedure Show;
    function ShowModal: Integer; virtual;
    function WantChildKey(Child: TControl; var Message: TMessage): Boolean; virtual;
    property Active: Boolean read FActive;
    property ActiveControl: TWinControl read FActiveControl write SetActiveControl stored IsForm;
    property ActiveOleControl: TWinControl read FActiveControl write FActiveControl;
    property BorderStyle: TFormBorderStyle read FBorderStyle write SetBorderStyle stored IsForm default bsSizeable;
    property Canvas: TCanvas read GetCanvas;
    property Caption stored IsForm;
    property Color nodefault;
    property Designer: TObject read FDesigner write FDesigner;
    property DropTarget: Boolean read FDropTarget write FDropTarget;
    property Font;
    property FormState: TFormState read FFormState;
    property HelpFile: string read FHelpFile write FHelpFile;
    property KeyPreview: Boolean read FKeyPreview write FKeyPreview stored IsForm default False;
    property Menu: TMainMenu read FMenu write SetMenu stored IsForm;
    property ModalResult: TModalResult read FModalResult write FModalResult;
    property WindowState: TWindowState read FWindowState write SetWindowState stored IsForm default wsNormal;
  end;

  TForm = class(TCustomForm)
  public
    procedure ArrangeIcons;
    procedure Cascade;
    procedure Next;
    procedure Previous;
    procedure Tile;
    property ClientHandle;
    property DockManager: TObject read FDesigner;
  published
    property ActiveControl;
    property Align;
    property Anchors;
    property AutoScroll;
    property AutoSize;
    property BiDiMode;
    property BorderIcons;
    property BorderStyle;
    property BorderWidth;
    property Caption;
    property ClientHeight;
    property ClientWidth;
    property Color;
    property Constraints;
    property Ctl3D;
    property UseDockManager;
    property DefaultMonitor;
    property DockSite;
    property DragKind;
    property DragMode;
    property Enabled;
    property ParentFont default False;
    property Font;
    property FormStyle;
    property Height;
    property HelpFile;
    property HorzScrollBar;
    property Icon;
    property KeyPreview;
    property Menu;
    property OldCreateOrder;
    property ObjectMenuItem;
    property ParentBiDiMode;
    property PixelsPerInch;
    property PopupMenu;
    property Position;
    property PrintScale;
    property Scaled;
    property ShowHint;
    property VertScrollBar;
    property Visible;
    property Width;
    property WindowState;
    property WindowMenu;
    property OnActivate;
    property OnCanResize;
    property OnClick;
    property OnClose;
    property OnCloseQuery;
    property OnConstrainedResize;
    property OnContextPopup;
    property OnCreate;
    property OnDblClick;
    property OnDestroy;
    property OnDeactivate;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnHide;
    property OnHelp;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnMouseWheel;
    property OnMouseWheelDown;
    property OnMouseWheelUp;
    property OnPaint;
    property OnResize;
    property OnShortCut;
    property OnShow;
    property OnStartDrag;
  end;

  TFormClass = class of TForm;
  TCustomFormClass = class of TCustomForm;

  TCursorRec = record
    Index: Integer;
    Handle: HCURSOR;
  end;

  TScreen = class(TComponent)
  private
    FFonts: TStrings;
    FPixelsPerInch: Integer;
    FCursor: TCursor;
    FCursorCount: Integer;
    FForms: TList;
    FCustomForms: TList;
    FDataModules: TList;
    FCursors: array of TCursorRec;
    FDefaultCursor: HCURSOR;
    FActiveControl: TWinControl;
    FActiveCustomForm: TCustomForm;
    FActiveForm: TForm;
    FLastActiveControl: TWinControl;
    FLastActiveCustomForm: TCustomForm;
    FFocusedForm: TCustomForm;
    FSaveFocusedList: TList;
    FHintFont: TFont;
    FIconFont: TFont;
    FMenuFont: TFont;
    FOnActiveControlChange: TNotifyEvent;
    FOnActiveFormChange: TNotifyEvent;
    procedure AddForm(AForm: TCustomForm);
    function GetCursors(Index: Integer): HCURSOR;
    function GetCustomFormCount: Integer;
    function GetCustomForms(Index: Integer): TCustomForm;
    function GetDataModule(Index: Integer): TDataModule;
    function GetDataModuleCount: Integer;
    function GetDesktopHeight: Integer;
    function GetDesktopLeft: Integer;
    function GetDesktopTop: Integer;
    function GetDesktopWidth: Integer;
    function GetFonts: TStrings;
    function GetForm(Index: Integer): TForm;
    function GetFormCount: Integer;
    function GetHeight: Integer;
    function GetWidth: Integer;
    function GetWorkAreaRect: TRect;
    procedure RemoveForm(AForm: TCustomForm);
    procedure SetCursors(Index: Integer; Handle: HCURSOR);
    procedure SetCursor(Value: TCursor);
    procedure UpdateLastActive;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DisableAlign;
    procedure EnableAlign;
    procedure Realign;
    procedure ResetFonts;
    property ActiveControl: TWinControl read FActiveControl;
    property ActiveCustomForm: TCustomForm read FActiveCustomForm;
    property ActiveForm: TForm read FActiveForm;
    property CustomFormCount: Integer read GetCustomFormCount;
    property CustomForms[Index: Integer]: TCustomForm read GetCustomForms;
    property Cursor: TCursor read FCursor write SetCursor;
    property Cursors[Index: Integer]: HCURSOR read GetCursors write SetCursors;
    property DataModules[Index: Integer]: TDataModule read GetDataModule;
    property DataModuleCount: Integer read GetDataModuleCount;
    property DesktopHeight: Integer read GetDesktopHeight;
    property DesktopLeft: Integer read GetDesktopLeft;
    property DesktopTop: Integer read GetDesktopTop;
    property DesktopWidth: Integer read GetDesktopWidth;
    property WorkAreaRect: TRect read GetWorkAreaRect;
    property WorkAreaHeight: Integer read GetHeight;
    property WorkAreaLeft: Integer read GetDesktopLeft;
    property WorkAreaTop: Integer read GetDesktopTop;
    property WorkAreaWidth: Integer read GetWidth;
    property HintFont: TFont read FHintFont;
    property IconFont: TFont read FIconFont;
    property MenuFont: TFont read FMenuFont;
    property Fonts: TStrings read GetFonts;
    property FormCount: Integer read GetFormCount;
    property Forms[Index: Integer]: TForm read GetForm;
    property Height: Integer read GetHeight;
    property PixelsPerInch: Integer read FPixelsPerInch;
    property Width: Integer read GetWidth;
    property OnActiveControlChange: TNotifyEvent read FOnActiveControlChange write FOnActiveControlChange;
    property OnActiveFormChange: TNotifyEvent read FOnActiveFormChange write FOnActiveFormChange;
  end;

  TApplication = class(TComponent)
  private
    FHandle: HWnd;
    FBiDiMode: TBiDiMode;
    FObjectInstance: Pointer;
    FMainForm: TForm;
    FMouseControl: TControl;
    FHelpFile: string;
    FHint: string;
    FHintActive: Boolean;
    FUpdateFormatSettings: Boolean;
    FUpdateMetricSettings: Boolean;
    FShowMainForm: Boolean;
    FHintColor: TColor;
    FHintControl: TControl;
    FHintCursorRect: TRect;
    FHintHidePause: Integer;
    FHintPause: Integer;
    FHintShortCuts: Boolean;
    FHintShortPause: Integer;
    FHintWindow: THintWindow;
    FShowHint: Boolean;
    FTimerMode: Integer;
    FTitle: string;
    FTopMostList: TList;
    FTopMostLevel: Integer;
    FIcon: TIcon;
    FTerminate: Boolean;
    FActive: Boolean;
    FAllowTesting: Boolean;
    FHandleCreated: Boolean;
    FRunning: Boolean;
    FWindowHooks: TList;
    FDialogHandle: HWnd;
    FAutoDragDocking: Boolean;
    FOnActionExecute: TNotifyEvent;
    FOnException: TExceptionEvent;
    FOnMessage: TMessageEvent;
    FOnHelp: THelpEvent;
    FOnHint: TNotifyEvent;
    FOnIdle: TIdleEvent;
    FOnDeactivate: TNotifyEvent;
    FOnActivate: TNotifyEvent;
    FOnMinimize: TNotifyEvent;
    FOnRestore: TNotifyEvent;
    FOnShortCut: TShortCutEvent;
    FOnShowHint: TShowHintEvent;
    function GetExeName: string;
    function GetTitle: string;
    procedure SetHint(const Value: string);
    procedure SetIcon(Value: TIcon);
    procedure SetShowHint(Value: Boolean);
    procedure SetTitle(const Value: string);
    procedure WndProc(var Message: TMessage);
    procedure DoMouseIdle;
    procedure Idle(const Msg: TMsg);
    function IsKeyMsg(var Msg: TMsg): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ActivateHint(CursorPos: TPoint);
    procedure BringToFront;
    procedure CancelHint;
    procedure ControlDestroyed(Control: TControl);
    procedure CreateForm(InstanceClass: TComponentClass; var Reference);
    procedure CreateHandle;
    function ExecuteAction(Action: TObject): Boolean; reintroduce;
    procedure HandleException(Sender: TObject);
    procedure HandleMessage;
    function HelpCommand(Command: Integer; Data: Longint): Boolean;
    function HelpContext(Context: THelpContext): Boolean;
    function HelpJump(const JumpID: string): Boolean;
    procedure HideHint;
    procedure HintMouseMessage(Control: TControl; var Message: TMessage);
    procedure HookMainWindow(Hook: TWindowHook);
    procedure Initialize;
    function MessageBox(const Text, Caption: PChar; Flags: Longint = MB_OK): Integer;
    procedure Minimize;
    procedure NormalizeAllTopMosts;
    procedure NormalizeTopMosts;
    procedure ProcessMessages;
    function ProcessMessage(var Msg: TMsg): Boolean;
    procedure Restore;
    procedure RestoreTopMosts;
    procedure Run;
    procedure ShowException(E: Exception);
    procedure Terminate;
    procedure UnhookMainWindow(Hook: TWindowHook);
    function UpdateAction(Action: TObject): Boolean; reintroduce;
    property Active: Boolean read FActive;
    property AllowTesting: Boolean read FAllowTesting write FAllowTesting;
    property AutoDragDocking: Boolean read FAutoDragDocking write FAutoDragDocking default True;
    property BiDiMode: TBiDiMode read FBiDiMode write FBiDiMode default bdLeftToRight;
    property CurrentHelpFile: string read FHelpFile;
    property DialogHandle: HWnd read FDialogHandle write FDialogHandle;
    property ExeName: string read GetExeName;
    property Handle: HWnd read FHandle write FHandle;
    property HelpFile: string read FHelpFile write FHelpFile;
    property Hint: string read FHint write SetHint;
    property HintColor: TColor read FHintColor write FHintColor;
    property HintHidePause: Integer read FHintHidePause write FHintHidePause;
    property HintPause: Integer read FHintPause write FHintPause;
    property HintShortCuts: Boolean read FHintShortCuts write FHintShortCuts;
    property HintShortPause: Integer read FHintShortPause write FHintShortPause;
    property Icon: TIcon read FIcon write SetIcon;
    property MainForm: TForm read FMainForm;
    property ShowHint: Boolean read FShowHint write SetShowHint;
    property ShowMainForm: Boolean read FShowMainForm write FShowMainForm;
    property Terminated: Boolean read FTerminate;
    property Title: string read GetTitle write SetTitle;
    property UpdateFormatSettings: Boolean read FUpdateFormatSettings write FUpdateFormatSettings;
    property UpdateMetricSettings: Boolean read FUpdateMetricSettings write FUpdateMetricSettings;
    property OnActionExecute: TNotifyEvent read FOnActionExecute write FOnActionExecute;
    property OnActivate: TNotifyEvent read FOnActivate write FOnActivate;
    property OnDeactivate: TNotifyEvent read FOnDeactivate write FOnDeactivate;
    property OnException: TExceptionEvent read FOnException write FOnException;
    property OnIdle: TIdleEvent read FOnIdle write FOnIdle;
    property OnHelp: THelpEvent read FOnHelp write FOnHelp;
    property OnHint: TNotifyEvent read FOnHint write FOnHint;
    property OnMessage: TMessageEvent read FOnMessage write FOnMessage;
    property OnMinimize: TNotifyEvent read FOnMinimize write FOnMinimize;
    property OnRestore: TNotifyEvent read FOnRestore write FOnRestore;
    property OnShowHint: TShowHintEvent read FOnShowHint write FOnShowHint;
    property OnShortCut: TShortCutEvent read FOnShortCut write FOnShortCut;
  end;

var
  Application: TApplication;
  Screen: TScreen;
  Ctl3DBtnWndProc: Pointer = nil;
  HintWindowClass: THintWindowClass = THintWindow;

function GetParentForm(Control: TControl): TCustomForm;
function ValidParentForm(Control: TControl): TCustomForm;
function DisableTaskWindows(ActiveWindow: HWnd): Pointer;
procedure EnableTaskWindows(WindowList: Pointer);
function MakeObjectInstance(Method: TWndMethod): Pointer;
procedure FreeObjectInstance(ObjectInstance: Pointer);
function AllocateHWnd(Method: TWndMethod): HWND;
procedure DeallocateHWnd(Wnd: HWND);
function IsAccel(VK: Word; const Str: string): Boolean;
function KeysToShiftState(Keys: Word): TShiftState;
function KeyDataToShiftState(KeyData: Longint): TShiftState;
function ForegroundTask: Boolean;

{ compat: de resources van een formulier laden uit het originele ROS.exe }
function ZMInitInheritedComponent(Instance: TComponent; RootAncestor: TClass): Boolean;

implementation

uses Math, TypInfo, StdCtrls, ZMWin, ZMData, ZMPlatform;

type
  TWinControlAccess = class(TWinControl);

var
  FocusCount: Integer = 0;
  SetWindowToTop: Boolean = False;

{ ---------------------------------------------------------------- hulpfuncties }

function KeysToShiftState(Keys: Word): TShiftState;
begin
  Result := Controls.KeysToShiftState(Keys);
end;

function KeyDataToShiftState(KeyData: Longint): TShiftState;
begin
  Result := Controls.KeyDataToShiftState(KeyData);
end;

function IsAccel(VK: Word; const Str: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  I := Pos('&', Str);
  if (I > 0) and (I < Length(Str)) then
    Result := UpCase(Str[I + 1]) = UpCase(Char(VK));
end;

function ForegroundTask: Boolean;
begin
  Result := True;
end;

function GetParentForm(Control: TControl): TCustomForm;
begin
  while Control.Parent <> nil do Control := Control.Parent;
  if Control is TCustomForm then
    Result := TCustomForm(Control)
  else
    Result := nil;
end;

function ValidParentForm(Control: TControl): TCustomForm;
begin
  Result := GetParentForm(Control);
  if Result = nil then
    raise EInvalidOperation.CreateFmt('Control ''%s'' has no parent form', [Control.Name]);
end;

function MakeObjectInstance(Method: TWndMethod): Pointer;
begin
  Result := nil;
end;

procedure FreeObjectInstance(ObjectInstance: Pointer);
begin
end;

function AllocateHWnd(Method: TWndMethod): HWND;
begin
  Result := ZMMaakVenster(WS_EX_TOOLWINDOW, 'TPUtilWindow', '', WS_POPUP, 0, 0, 0, 0, 0, 0, Method, nil);
end;

procedure DeallocateHWnd(Wnd: HWND);
begin
  DestroyWindow(Wnd);
end;

type
  PTaakVenster = ^TTaakVenster;
  TTaakVenster = record
    Next: PTaakVenster;
    Window: HWnd;
  end;

var
  TaakActiefVenster: HWnd = 0;
  TaakEersteVenster: HWnd = 0;
  TaakVensterlijst: PTaakVenster = nil;

function DoUitschakelVenster(Vensterobject: HWnd; Gegevens: Pointer): Boolean;
var
  P: PTaakVenster;
begin
  if (Vensterobject <> TaakActiefVenster) and IsWindowVisible(Vensterobject) and IsWindowEnabled(Vensterobject) then
  begin
    New(P);
    P^.Next := TaakVensterlijst;
    P^.Window := Vensterobject;
    TaakVensterlijst := P;
    EnableWindow(Vensterobject, False);
  end;
  Result := True;
end;

function DisableTaskWindows(ActiveWindow: HWnd): Pointer;
var
  Bewaaractievenster: HWND;
  Bewaarvensterlijst: Pointer;
begin
  Result := nil;
  Bewaaractievenster := TaakActiefVenster;
  Bewaarvensterlijst := TaakVensterlijst;
  TaakActiefVenster := ActiveWindow;
  TaakVensterlijst := nil;
  try
    ZMOpsommenTopniveau(DoUitschakelVenster, nil);
    Result := TaakVensterlijst;
  except
    EnableTaskWindows(TaakVensterlijst);
    raise;
  end;
  TaakVensterlijst := Bewaarvensterlijst;
  TaakActiefVenster := Bewaaractievenster;
end;

procedure EnableTaskWindows(WindowList: Pointer);
var
  P: PTaakVenster;
begin
  while WindowList <> nil do
  begin
    P := WindowList;
    if IsWindow(P^.Window) then EnableWindow(P^.Window, True);
    WindowList := P^.Next;
    Dispose(P);
  end;
end;

{ ---------------------------------------------------------------- DFM laden }

type
  TLezerHulp = class
    procedure EigenschapNietGevonden(Lezer: TReader; Exemplaar: TPersistent; var Eigenschapsnaam: string;
      IsPad: Boolean; var Afgehandeld, Overslaan: Boolean);
    procedure ZoekMethode(Lezer: TReader; const Methodenaam: string; var Adres: Pointer;
      var Fout: Boolean);
    procedure LezerFout(Lezer: TReader; const Bericht: string; var Afgehandeld: Boolean);
  end;

var
  LezerHulp: TLezerHulp;

function DebugAan: Boolean;
begin
  Result := GetEnvironmentVariable('ZM_DEBUG') <> '';
end;

procedure TLezerHulp.EigenschapNietGevonden(Lezer: TReader; Exemplaar: TPersistent; var Eigenschapsnaam: string;
  IsPad: Boolean; var Afgehandeld, Overslaan: Boolean);
begin
  if DebugAan then
    WriteLn(StdErr, 'DFM: onbekende eigenschap ', Exemplaar.ClassName, '.', Eigenschapsnaam, ' (overgeslagen)');
  Overslaan := True;
  Afgehandeld := True;
end;

procedure TLezerHulp.ZoekMethode(Lezer: TReader; const Methodenaam: string; var Adres: Pointer;
  var Fout: Boolean);
begin
  if Fout then
  begin
    WriteLn(StdErr, 'DFM: gebeurtenishandler ', Methodenaam, ' niet gevonden (gepubliceerde methode ontbreekt)');
    Fout := False;
  end;
end;

procedure TLezerHulp.LezerFout(Lezer: TReader; const Bericht: string; var Afgehandeld: Boolean);
begin
  WriteLn(StdErr, 'DFM: ', Bericht);
  Afgehandeld := True;
end;

function LaadFormulierResource(Exemplaar: TComponent; Aklasse: TClass): Boolean;
var
  Gegevens: Pointer;
  Grootte: Integer;
  MS: TMemoryStream;
  R: TReader;
begin
  Result := False;
  if not ZMLaadExeHulpbron(UpperCase(Aklasse.ClassName), 10, Gegevens, Grootte) then Exit;
  MS := TMemoryStream.Create;
  try
    MS.WriteBuffer(Gegevens^, Grootte);
    MS.Position := 0;
    R := TReader.Create(MS, 4096);
    try
      R.OnPropertyNotFound := LezerHulp.EigenschapNietGevonden;
      R.OnFindMethod := LezerHulp.ZoekMethode;
      R.OnError := LezerHulp.LezerFout;
      R.ReadRootComponent(Exemplaar);
    finally
      R.Free;
    end;
  finally
    MS.Free;
  end;
  Result := True;
end;

function ZMInitInheritedComponent(Instance: TComponent; RootAncestor: TClass): Boolean;

  function DoInit(C: TClass): Boolean;
  begin
    Result := False;
    if (C = TComponent) or (C = RootAncestor) or (C = nil) then Exit;
    Result := DoInit(C.ClassParent);
    Result := LaadFormulierResource(Instance, C) or Result;
  end;

begin
  Result := DoInit(Instance.ClassType);
end;

{ ---------------------------------------------------------------- TControlScrollBar }

constructor TControlScrollBar.Create(AControl: TWinControl; AKind: TScrollBarKind);
begin
  inherited Create;
  FControl := AControl;
  FKind := AKind;
  FIncrement := 8;
  FVisible := True;
  FColor := clBtnHighlight;
  FParentColor := True;
end;

procedure TControlScrollBar.Assign(Source: TPersistent);
begin
  if Source is TControlScrollBar then
  begin
    FVisible := TControlScrollBar(Source).FVisible;
    FRange := TControlScrollBar(Source).FRange;
    FPosition := TControlScrollBar(Source).FPosition;
    FIncrement := TControlScrollBar(Source).FIncrement;
    Exit;
  end;
  inherited Assign(Source);
end;

procedure TControlScrollBar.ChangeBiDiPosition;
begin
end;

function TControlScrollBar.IsScrollBarVisible: Boolean;
begin
  Result := False;
end;

procedure TControlScrollBar.SetPosition(Value: Integer);
begin
  FPosition := Value;
end;

procedure TControlScrollBar.SetRange(Value: Integer);
begin
  FRange := Value;
end;

procedure TControlScrollBar.SetVisible(Value: Boolean);
begin
  FVisible := Value;
end;

{ ---------------------------------------------------------------- TScrollingWinControl }

constructor TScrollingWinControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHorzScrollBar := TControlScrollBar.Create(Self, sbHorizontal);
  FVertScrollBar := TControlScrollBar.Create(Self, sbVertical);
  FAutoScroll := True;
end;

destructor TScrollingWinControl.Destroy;
begin
  FHorzScrollBar.Free;
  FVertScrollBar.Free;
  inherited Destroy;
end;

procedure TScrollingWinControl.SetHorzScrollBar(Value: TControlScrollBar);
begin
  FHorzScrollBar.Assign(Value);
end;

procedure TScrollingWinControl.SetVertScrollBar(Value: TControlScrollBar);
begin
  FVertScrollBar.Assign(Value);
end;

procedure TScrollingWinControl.AdjustClientRect(var Rect: TRect);
begin
  inherited AdjustClientRect(Rect);
end;

procedure TScrollingWinControl.AlignControls(AControl: TControl; var ARect: TRect);
begin
  inherited AlignControls(AControl, ARect);
end;

function TScrollingWinControl.AutoScrollEnabled: Boolean;
begin
  Result := False;
end;

procedure TScrollingWinControl.AutoScrollInView(AControl: TControl);
begin
end;

procedure TScrollingWinControl.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
end;

procedure TScrollingWinControl.CreateWnd;
begin
  inherited CreateWnd;
end;

procedure TScrollingWinControl.DisableAutoRange;
begin
end;

procedure TScrollingWinControl.EnableAutoRange;
begin
end;

procedure TScrollingWinControl.ScrollInView(AControl: TControl);
begin
end;

constructor TScrollBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := [csAcceptsControls, csCaptureMouse, csClickEvents, csSetCaption, csDoubleClicks];
  Width := 185;
  Height := 41;
  FBorderStyle := bsSingle;
end;

constructor TCustomFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := [csAcceptsControls, csCaptureMouse, csClickEvents, csSetCaption, csDoubleClicks];
  Width := 320;
  Height := 240;
  if (ClassType <> TFrame) and not (csDesignInstance in ComponentState) then
    ZMInitInheritedComponent(Self, TFrame);
end;

{ ---------------------------------------------------------------- TCustomForm }

constructor TCustomForm.Create(AOwner: TComponent);
begin
  CreateNew(AOwner);
  if (ClassType <> TForm) and not (csDesigning in ComponentState) then
  begin
    Include(FFormState, fsCreating);
    try
      if not ZMInitInheritedComponent(Self, TForm) then
        raise EResNotFound.CreateFmt('Resource %s niet gevonden (staat ROS.exe in de datamap? ' +
          'stel ZM_DATA of --data in)', [ClassName]);
    finally
      Exclude(FFormState, fsCreating);
    end;
    if OldCreateOrder then DoCreate;
  end;
end;

constructor TCustomForm.CreateNew(AOwner: TComponent; Dummy: Integer);
begin
  inherited Create(AOwner);
  ControlStyle := [csAcceptsControls, csCaptureMouse, csClickEvents, csSetCaption, csDoubleClicks];
  Left := 0;
  Top := 0;
  Width := 320;
  Height := 240;
  FIcon := TIcon.Create;
  FBorderIcons := [biSystemMenu, biMinimize, biMaximize];
  FBorderStyle := bsSizeable;
  FWindowState := wsNormal;
  FDefaultMonitor := dmActiveForm;
  FFormStyle := fsNormal;
  FPosition := poDesigned;
  FPrintScale := poProportional;
  FPixelsPerInch := 96;
  FScaled := True;
  Visible := False;
  ParentColor := False;
  ParentFont := False;
  Ctl3D := True;
  Color := clBtnFace;
  if Screen <> nil then Screen.AddForm(Self);
end;

procedure TCustomForm.AfterConstruction;
begin
  if not OldCreateOrder then DoCreate;
end;

procedure TCustomForm.BeforeDestruction;
begin
  if Assigned(ZMHandleExceptionHook) then ;
  if not OldCreateOrder then DoDestroy;
  inherited BeforeDestruction;
end;

destructor TCustomForm.Destroy;
begin
  if not (csDestroying in ComponentState) then Destroying;
  if OldCreateOrder then DoDestroy;
  if Screen <> nil then Screen.RemoveForm(Self);
  if (Application <> nil) and (Application.FMainForm = Self) then Application.FMainForm := nil;
  FCanvas.Free;
  FIcon.Free;
  inherited Destroy;
end;

procedure TCustomForm.DoCreate;
begin
  if Assigned(FOnCreate) then
  try
    FOnCreate(Self);
  except
    if not HandleCreateException then raise;
  end;
end;

procedure TCustomForm.DoDestroy;
begin
  if Assigned(FOnDestroy) then
  try
    FOnDestroy(Self);
  except
    Application.HandleException(Self);
  end;
end;

function TCustomForm.HandleCreateException: Boolean;
begin
  Application.HandleException(Self);
  Result := True;
end;

procedure TCustomForm.Loaded;
var
  Besturing: TWinControl;
begin
  inherited Loaded;
  if ActiveControl <> nil then
  begin
    Besturing := ActiveControl;
    FActiveControl := nil;
    if Besturing.CanFocus then SetActiveControl(Besturing);
  end;
end;

procedure TCustomForm.ReadState(Reader: TReader);
var
  Nieuwetekstgrootte: Integer;
  Geschaald: Boolean;
begin
  DisableAlign;
  try
    FTextHeight := 0;
    inherited ReadState(Reader);
    Nieuwetekstgrootte := GetTextHeight;
    Geschaald := FScaled;
    if (FTextHeight <> 0) and (FTextHeight <> Nieuwetekstgrootte) and Geschaald then ;
  finally
    EnableAlign;
  end;
end;

procedure TCustomForm.ReadTextHeight(Reader: TReader);
begin
  FTextHeight := Reader.ReadInteger;
end;

procedure TCustomForm.WriteTextHeight(Writer: TWriter);
begin
  Writer.WriteInteger(GetTextHeight);
end;

procedure TCustomForm.ReadIgnoreFontProperty(Reader: TReader);
begin
  Reader.ReadBoolean;
end;

procedure TCustomForm.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  Filer.DefineProperty('TextHeight', ReadTextHeight, WriteTextHeight, not IsControl);
  Filer.DefineProperty('IgnoreFontProperty', ReadIgnoreFontProperty, nil, False);
end;

function TCustomForm.GetTextHeight: Integer;
begin
  Result := Canvas.TextHeight('0');
end;

function TCustomForm.GetPixelsPerInch: Integer;
begin
  Result := FPixelsPerInch;
end;

procedure TCustomForm.SetPixelsPerInch(Value: Integer);
begin
  FPixelsPerInch := Value;
end;

function TCustomForm.GetScaled: Boolean;
begin
  Result := FScaled;
end;

procedure TCustomForm.SetScaled(Value: Boolean);
begin
  FScaled := Value;
end;

function TCustomForm.IsForm: Boolean;
begin
  Result := not IsControl;
end;

function TCustomForm.IsIconStored: Boolean;
begin
  Result := IsForm and (Icon.Handle <> 0);
end;

function TCustomForm.IsAutoScrollStored: Boolean;
begin
  Result := IsForm;
end;

function TCustomForm.GetFloating: Boolean;
begin
  Result := False;
end;

procedure TCustomForm.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I: Integer;
begin
  inherited GetChildren(Proc, Root);
  if Root = Self then
    for I := 0 to ComponentCount - 1 do
      if not Components[I].HasParent then Proc(Components[I]);
end;

procedure TCustomForm.SetChildOrder(Child: TComponent; Order: Integer);
begin
  inherited SetChildOrder(Child, Order);
end;

procedure TCustomForm.SetParent(AParent: TWinControl);
begin
  inherited SetParent(AParent);
end;

procedure TCustomForm.ValidateRename(AComponent: TComponent; const CurName, NewName: string);
begin
  inherited ValidateRename(AComponent, CurName, NewName);
end;

procedure TCustomForm.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FMenu then FMenu := nil;
    if AComponent = FActiveControl then FActiveControl := nil;
    if AComponent = FFocusedControl then FFocusedControl := nil;
  end;
end;

function TCustomForm.GetCanvas: TCanvas;
begin
  if FCanvas = nil then
  begin
    FCanvas := TControlCanvas.Create;
    FCanvas.Control := Self;
    FCanvas.Font := Font;
  end;
  Result := FCanvas;
end;

procedure TCustomForm.SetIcon(Value: TIcon);
begin
  FIcon.Assign(Value);
end;

procedure TCustomForm.SetMenu(Value: TMainMenu);
begin
  FMenu := Value;
end;

procedure TCustomForm.SetWindowMenu(Value: TMenuItem);
begin
  FWindowMenu := Value;
end;

procedure TCustomForm.SetObjectMenuItem(Value: TMenuItem);
begin
  FObjectMenuItem := Value;
end;

procedure TCustomForm.SetFormStyle(Value: TFormStyle);
begin
  if FFormStyle <> Value then
  begin
    FFormStyle := Value;
    if HandleAllocated then
      if Value = fsStayOnTop then
        SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE)
      else
        SetWindowPos(Handle, HWND_NOTOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);
  end;
end;

procedure TCustomForm.SetBorderIcons(Value: TBorderIcons);
begin
  if FBorderIcons <> Value then
  begin
    FBorderIcons := Value;
    if HandleAllocated then RecreateWnd;
  end;
end;

procedure TCustomForm.SetBorderStyle(Value: TFormBorderStyle);
begin
  if FBorderStyle <> Value then
  begin
    FBorderStyle := Value;
    if HandleAllocated then RecreateWnd;
  end;
end;

procedure TCustomForm.SetPosition(Value: TPosition);
begin
  FPosition := Value;
end;

function TCustomForm.NCInsets: TRect;
var
  Parameters: TCreateParams;
  B: Integer;
begin
  CreateParams(Parameters);
  B := 0;
  if Parameters.Style and WS_THICKFRAME <> 0 then B := 4
  else if (Parameters.Style and WS_DLGFRAME <> 0) or (Parameters.ExStyle and WS_EX_DLGMODALFRAME <> 0) then B := 3
  else if Parameters.Style and WS_BORDER <> 0 then B := 1;
  if Parameters.ExStyle and WS_EX_CLIENTEDGE <> 0 then Inc(B, 2);
  Result := Rect(B, B, B, B);
  if Parameters.Style and WS_CAPTION = WS_CAPTION then Inc(Result.Top, 19);
end;

function TCustomForm.GetClientRect: TRect;
var
  N: TRect;
begin
  if HandleAllocated then
    Result := inherited GetClientRect
  else
  begin
    N := NCInsets;
    Result := Rect(0, 0, Max(0, Width - N.Left - N.Right), Max(0, Height - N.Top - N.Bottom));
  end;
end;

procedure TCustomForm.CreateParams(var Params: TCreateParams);
var
  Pictogrammen: TBorderIcons;
  Maakstijl: TFormBorderStyle;
begin
  inherited CreateParams(Params);
  with Params do
  begin
    if (Parent = nil) and (ParentWindow = 0) then
    begin
      WndParent := 0;
      if (Application <> nil) and (Application.FHandle <> 0) then WndParent := Application.FHandle;
      Style := Style and not (WS_CHILD or WS_GROUP or WS_TABSTOP);
    end;
    WindowClass.style := CS_DBLCLKS;
    if FFormStyle = fsStayOnTop then ExStyle := ExStyle or WS_EX_TOPMOST;
    Maakstijl := FBorderStyle;
    Style := Style or WS_CLIPCHILDREN;
    if Parent = nil then
      case Maakstijl of
        bsNone:
          Style := Style or WS_POPUP;
        bsSingle, bsToolWindow:
          Style := Style or (WS_CAPTION or WS_BORDER);
        bsSizeable, bsSizeToolWin:
          Style := Style or (WS_CAPTION or WS_THICKFRAME);
        bsDialog:
          begin
            Style := Style or WS_POPUP or WS_CAPTION;
            ExStyle := ExStyle or WS_EX_DLGMODALFRAME or WS_EX_WINDOWEDGE;
          end;
      end;
    if Maakstijl in [bsToolWindow, bsSizeToolWin] then ExStyle := ExStyle or WS_EX_TOOLWINDOW;
    Pictogrammen := FBorderIcons;
    case Maakstijl of
      bsNone: Pictogrammen := [];
      bsDialog: Pictogrammen := Pictogrammen * [biSystemMenu, biHelp];
      bsToolWindow, bsSizeToolWin: Pictogrammen := Pictogrammen * [biSystemMenu];
    end;
    if Maakstijl in [bsSingle, bsSizeable, bsNone] then
    begin
      if (FormStyle <> fsMDIChild) or (biSystemMenu in Pictogrammen) then
      begin
        if biMinimize in Pictogrammen then Style := Style or WS_MINIMIZEBOX;
        if biMaximize in Pictogrammen then Style := Style or WS_MAXIMIZEBOX;
      end;
      if FWindowState = wsMaximized then Style := Style or WS_MAXIMIZE;
    end
    else
      FWindowState := wsNormal;
    if biSystemMenu in Pictogrammen then Style := Style or WS_SYSMENU;
  end;
end;

procedure TCustomForm.CreateWindowHandle(const Params: TCreateParams);
begin
  inherited CreateWindowHandle(Params);
end;

procedure TCustomForm.CreateWnd;
begin
  inherited CreateWnd;
  if (FWindowState = wsMaximized) then ;
end;

procedure TCustomForm.DestroyWindowHandle;
begin
  inherited DestroyWindowHandle;
end;

procedure TCustomForm.ApplyPosition;
var
  X, Y: Integer;
begin
  if FPositioned then Exit;
  FPositioned := True;
  if FWindowState = wsMaximized then
  begin
    SetBounds(0, 0, Screen.Width, Screen.Height);
    Exit;
  end;
  case FPosition of
    poScreenCenter, poDesktopCenter:
      begin
        X := (Screen.Width - Width) div 2;
        Y := (Screen.Height - Height) div 2;
        SetBounds(X, Y, Width, Height);
      end;
    poMainFormCenter, poOwnerFormCenter:
      if (Application.MainForm <> nil) and (Application.MainForm <> Self) then
        with Application.MainForm do
          Self.SetBounds(Left + (Width - Self.Width) div 2, Top + (Height - Self.Height) div 2,
            Self.Width, Self.Height)
      else
        SetBounds((Screen.Width - Width) div 2, (Screen.Height - Height) div 2, Width, Height);
  end;
end;

procedure TCustomForm.SetVisible(Value: Boolean);
begin
  if fsCreating in FFormState then
  begin
    if Value then Include(FFormState, fsVisible) else Exclude(FFormState, fsVisible);
  end
  else
  begin
    if Value and (Visible <> Value) then SetWindowToTop := True;
    inherited Visible := Value;
  end;
end;

procedure TCustomForm.VisibleChanging;
begin
  if (FFormStyle = fsMDIChild) and Visible then
    raise EInvalidOperation.Create('Cannot hide an MDI Child Form');
end;

procedure TCustomForm.CMShowingChanged(var Message: TMessage);
begin
  if Showing then
  begin
    try
      DoShow;
    except
      Application.HandleException(Self);
    end;
    ApplyPosition;
    if FWindowState = wsMaximized then
      ShowWindow(Handle, SW_SHOWMAXIMIZED)
    else
      ShowWindow(Handle, SW_SHOWNORMAL);
    if FFormStyle = fsStayOnTop then
      SetWindowPos(Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
    SetActiveWindow(Handle);
  end
  else
  begin
    try
      DoHide;
    except
      Application.HandleException(Self);
    end;
    ShowWindow(Handle, SW_HIDE);
    { activeer een ander zichtbaar formulier }
    if (Screen <> nil) and (GetActiveWindow = 0) then
      if (Application.MainForm <> nil) and (Application.MainForm <> Self) and
        Application.MainForm.Visible then
        SetActiveWindow(Application.MainForm.Handle);
  end;
end;

procedure TCustomForm.CMTextChanged(var Message: TMessage);
begin
  inherited;
  if HandleAllocated then SetWindowText(Handle, PChar(Caption));
end;

procedure TCustomForm.DoShow;
begin
  if Assigned(FOnShow) then FOnShow(Self);
end;

procedure TCustomForm.DoHide;
begin
  if Assigned(FOnHide) then FOnHide(Self);
end;

procedure TCustomForm.Show;
begin
  Visible := True;
  BringToFront;
end;

procedure TCustomForm.Hide;
begin
  Visible := False;
end;

procedure TCustomForm.SetWindowState(Value: TWindowState);
begin
  if FWindowState <> Value then
  begin
    FWindowState := Value;
    if not (csDesigning in ComponentState) and Showing then
    begin
      if Value = wsMaximized then
      begin
        SetBounds(0, 0, Screen.Width, Screen.Height);
        ShowWindow(Handle, SW_SHOWMAXIMIZED);
      end
      else
        ShowWindow(Handle, SW_SHOWNORMAL);
    end;
  end;
end;

procedure TCustomForm.UpdateWindowState;
begin
end;

procedure TCustomForm.Resizing(State: TWindowState);
begin
end;

procedure TCustomForm.AlignControls(AControl: TControl; var Rect: TRect);
begin
  inherited AlignControls(AControl, Rect);
end;

procedure TCustomForm.ChangeScale(M, D: Integer);
begin
  inherited ChangeScale(M, D);
end;

procedure TCustomForm.Paint;
begin
  if Assigned(FOnPaint) then FOnPaint(Self);
end;

procedure TCustomForm.PaintWindow(DC: HDC);
begin
  Canvas.Lock;
  try
    Canvas.Handle := DC;
    try
      Paint;
    finally
      Canvas.Handle := 0;
    end;
  finally
    Canvas.Unlock;
  end;
end;

function TCustomForm.PaletteChanged(Foreground: Boolean): Boolean;
begin
  Result := False;
end;

procedure TCustomForm.BeginAutoDrag;
begin
end;

procedure TCustomForm.Activate;
begin
  if Assigned(FOnActivate) then FOnActivate(Self);
end;

procedure TCustomForm.Deactivate;
begin
  if Assigned(FOnDeactivate) then FOnDeactivate(Self);
end;

procedure TCustomForm.ActiveChanged;
begin
end;

procedure TCustomForm.SetActive(Value: Boolean);
begin
  FActive := Value;
  if Value then
  begin
    if (ActiveControl = nil) and not (csDesigning in ComponentState) then
      ActiveControl := FindNextControl(nil, True, True, False);
    SetWindowFocus;
  end;
end;

procedure TCustomForm.SetWindowFocus;
var
  Focusvenster: HWnd;
begin
  if (FActiveControl <> nil) and FActiveControl.HandleAllocated and FActiveControl.CanFocus then
    Focusvenster := FActiveControl.Handle
  else
    Focusvenster := Handle;
  if Focusvenster <> 0 then Windows.SetFocus(Focusvenster);
end;

procedure TCustomForm.SetActiveControl(Control: TWinControl);
begin
  if FActiveControl <> Control then
  begin
    if not ((csLoading in ComponentState) or (Control = nil) or
      ((Control <> Self) and (GetParentForm(Control) = Self) and
      ((csLoading in ComponentState) or Control.CanFocus))) then
      raise EInvalidOperation.Create('Cannot focus a disabled or invisible window');
    FActiveControl := Control;
    if not (csLoading in ComponentState) then
    begin
      if FActive then SetWindowFocus;
      ActiveChanged;
    end;
  end;
end;

procedure TCustomForm.DefocusControl(Control: TWinControl; Removing: Boolean);
begin
  if Removing and Control.ContainsControl(FFocusedControl) then
    FFocusedControl := Control.Parent;
  if Control.ContainsControl(FActiveControl) then SetActiveControl(nil);
end;

procedure TCustomForm.FocusControl(Control: TWinControl);
var
  Wasactief: Boolean;
begin
  Wasactief := FActive;
  ActiveControl := Control;
  if not Wasactief then SetFocus;
end;

function TCustomForm.SetFocusedControl(Control: TWinControl): Boolean;
var
  Focusvenster: HWnd;
  Tijdelijkbesturing: TWinControl;
begin
  Result := False;
  Inc(FocusCount);
  if FDesigner = nil then
    if Control <> Self then
      FActiveControl := Control
    else
      FActiveControl := nil;
  if Screen <> nil then
  begin
    Screen.FActiveControl := Control;
    Screen.FActiveCustomForm := Self;
    if Self is TForm then Screen.FActiveForm := TForm(Self);
    if Assigned(Screen.FOnActiveControlChange) then Screen.FOnActiveControlChange(Screen);
  end;
  if FFocusedControl = nil then FFocusedControl := Self;
  if FFocusedControl <> Control then
  begin
    while (FFocusedControl <> nil) and not FFocusedControl.ContainsControl(Control) do
    begin
      Focusvenster := FFocusedControl.Handle;
      Tijdelijkbesturing := FFocusedControl;
      FFocusedControl := FFocusedControl.Parent;
      Tijdelijkbesturing.Perform(CM_EXIT, 0, 0);
      if (Focusvenster <> 0) and (GetFocus <> Focusvenster) then Exit;
    end;
    while FFocusedControl <> Control do
    begin
      Tijdelijkbesturing := Control;
      while Tijdelijkbesturing.Parent <> FFocusedControl do Tijdelijkbesturing := Tijdelijkbesturing.Parent;
      FFocusedControl := Tijdelijkbesturing;
      FFocusedControl.Perform(CM_ENTER, 0, 0);
    end;
  end;
  Result := True;
end;

procedure TCustomForm.SetFocus;
begin
  if not FActive then
  begin
    if not (Visible and Enabled) then
      raise EInvalidOperation.Create('Cannot focus a disabled or invisible window');
    SetWindowFocus;
  end;
end;

procedure TCustomForm.SendCancelMode(Sender: TControl);
begin
end;

function TCustomForm.WantChildKey(Child: TControl; var Message: TMessage): Boolean;
begin
  Result := False;
end;

function TCustomForm.IsShortCut(var Message: TWMKey): Boolean;
begin
  Result := False;
  if Assigned(FOnShortCut) then FOnShortCut(Message, Result);
  Result := Result or ((FMenu <> nil) and FMenu.IsShortCut(Message));
end;

procedure TCustomForm.CMDialogKey(var Message: TCMDialogKey);
begin
  if GetKeyState(VK_MENU) >= 0 then
    with Message do
      case CharCode of
        VK_TAB:
          if GetKeyState(VK_CONTROL) >= 0 then
          begin
            SelectNext(FActiveControl, GetKeyState(VK_SHIFT) >= 0, True);
            Result := 1;
            Exit;
          end;
        VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN:
          begin
            if FActiveControl <> nil then
            begin
              TWinControlAccess(FActiveControl.Parent).SelectNext(FActiveControl,
                (CharCode = VK_RIGHT) or (CharCode = VK_DOWN), False);
              Result := 1;
            end;
            Exit;
          end;
      end;
  inherited;
end;

procedure TCustomForm.CMActivate(var Message: TCMActivate);
begin
  Activate;
end;

procedure TCustomForm.CMDeactivate(var Message: TCMDeactivate);
begin
  Deactivate;
end;

procedure TCustomForm.WMActivate(var Message: TWMActivate);
begin
  if Message.Active <> WA_INACTIVE then
  begin
    if not FActive then
    begin
      SetActive(True);
      if Screen <> nil then
      begin
        Screen.FActiveCustomForm := Self;
        if Self is TForm then Screen.FActiveForm := TForm(Self);
      end;
      Activate;
    end;
  end
  else if FActive then
  begin
    FActive := False;
    Deactivate;
  end;
end;

procedure TCustomForm.WMClose(var Message: TWMClose);
begin
  Close;
end;

procedure TCustomForm.WMQueryEndSession(var Message: TWMQueryEndSession);
begin
  Message.Result := Ord(CloseQuery);
end;

procedure TCustomForm.CMRelease(var Message: TMessage);
begin
  Free;
end;

procedure TCustomForm.Release;
begin
  PostMessage(Handle, CM_RELEASE, 0, 0);
end;

function TCustomForm.CloseQuery: Boolean;
begin
  Result := True;
  if Assigned(FOnCloseQuery) then FOnCloseQuery(Self, Result);
end;

procedure TCustomForm.DoClose(var Action: TCloseAction);
begin
  if Assigned(FOnClose) then FOnClose(Self, Action);
end;

procedure TCustomForm.Close;
var
  Sluitactie: TCloseAction;
begin
  if fsModal in FFormState then
    ModalResult := mrCancel
  else if CloseQuery then
  begin
    if FormStyle = fsMDIChild then
      Sluitactie := caMinimize
    else
      Sluitactie := caHide;
    DoClose(Sluitactie);
    if Sluitactie <> caNone then
      if Application.MainForm = Self then
        Application.Terminate
      else if Sluitactie = caHide then
        Hide
      else if Sluitactie = caMinimize then
        Hide
      else
        Release;
  end;
end;

function TCustomForm.ShowModal: Integer;
var
  Vensterlijst: Pointer;
  Bewaarfocusaantal: Integer;
  Bewaarcursor: TCursor;
  Actievenster: HWnd;
  Sluitactie: TCloseAction;
begin
  if Visible or not Enabled or (fsModal in FFormState) or (FormStyle = fsMDIChild) then
    raise EInvalidOperation.Create('Cannot make a visible window modal');
  if GetCapture <> 0 then SendMessage(GetCapture, WM_CANCELMODE, 0, 0);
  ReleaseCapture;
  Include(FFormState, fsModal);
  Actievenster := GetActiveWindow;
  Bewaarfocusaantal := FocusCount;
  Bewaarcursor := Screen.Cursor;
  Screen.Cursor := crDefault;
  Vensterlijst := DisableTaskWindows(0);
  try
    Show;
    try
      SendMessage(Handle, CM_ACTIVATE, 0, 0);
      ModalResult := 0;
      repeat
        Application.HandleMessage;
        if Application.FTerminate then
          ModalResult := mrCancel
        else if ModalResult <> 0 then
        begin
          { CloseModal }
          Sluitactie := caNone;
          if CloseQuery then
          begin
            Sluitactie := caHide;
            DoClose(Sluitactie);
          end;
          case Sluitactie of
            caNone: ModalResult := 0;
            caFree: Release;
          end;
        end;
      until ModalResult <> 0;
      Result := ModalResult;
      SendMessage(Handle, CM_DEACTIVATE, 0, 0);
      if GetActiveWindow <> Handle then Actievenster := 0;
    finally
      Hide;
    end;
  finally
    EnableTaskWindows(Vensterlijst);
    if Actievenster <> 0 then SetActiveWindow(Actievenster);
    FocusCount := Bewaarfocusaantal;
    Screen.Cursor := Bewaarcursor;
    Exclude(FFormState, fsModal);
  end;
end;

function TCustomForm.GetFormImage: TBitmap;
begin
  Result := TBitmap.Create;
  Result.Width := ClientWidth;
  Result.Height := ClientHeight;
  PaintTo(Result.Canvas.Handle, 0, 0);
end;

procedure TCustomForm.Print;
begin
end;

function TCustomForm.GetActiveMDIChild: TForm;
begin
  Result := nil;
end;

function TCustomForm.GetMDIChildCount: Integer;
begin
  Result := 0;
end;

function TCustomForm.GetMDIChildren(I: Integer): TForm;
begin
  Result := nil;
end;

procedure TCustomForm.UpdateActions;
begin
end;

procedure TCustomForm.WndProc(var Message: TMessage);
begin
  inherited WndProc(Message);
end;

procedure TCustomForm.DefaultHandler(var Message);
begin
  inherited DefaultHandler(Message);
end;

procedure TForm.ArrangeIcons;
begin
end;

procedure TForm.Cascade;
begin
end;

procedure TForm.Next;
begin
end;

procedure TForm.Previous;
begin
end;

procedure TForm.Tile;
begin
end;

{ ---------------------------------------------------------------- TScreen }

constructor TScreen.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FForms := TList.Create;
  FCustomForms := TList.Create;
  FDataModules := TList.Create;
  FSaveFocusedList := TList.Create;
  FPixelsPerInch := 96;
  FHintFont := TFont.Create;
  FIconFont := TFont.Create;
  FMenuFont := TFont.Create;
  FDefaultCursor := LoadCursor(0, IDC_ARROW);
end;

destructor TScreen.Destroy;
begin
  FFonts.Free;
  FHintFont.Free;
  FIconFont.Free;
  FMenuFont.Free;
  FSaveFocusedList.Free;
  FDataModules.Free;
  FCustomForms.Free;
  FForms.Free;
  inherited Destroy;
end;

procedure TScreen.AddForm(AForm: TCustomForm);
begin
  FCustomForms.Add(AForm);
  if AForm is TForm then FForms.Add(AForm);
end;

procedure TScreen.RemoveForm(AForm: TCustomForm);
begin
  FCustomForms.Remove(AForm);
  FForms.Remove(AForm);
  if FActiveCustomForm = AForm then FActiveCustomForm := nil;
  if FActiveForm = AForm then FActiveForm := nil;
  if FFocusedForm = AForm then FFocusedForm := nil;
  if FLastActiveCustomForm = AForm then FLastActiveCustomForm := nil;
  if (FActiveControl <> nil) and (GetParentForm(FActiveControl) = AForm) then FActiveControl := nil;
end;

function TScreen.GetCustomFormCount: Integer;
begin
  Result := FCustomForms.Count;
end;

function TScreen.GetCustomForms(Index: Integer): TCustomForm;
begin
  Result := TCustomForm(FCustomForms[Index]);
end;

function TScreen.GetFormCount: Integer;
begin
  Result := FForms.Count;
end;

function TScreen.GetForm(Index: Integer): TForm;
begin
  Result := TForm(FForms[Index]);
end;

function TScreen.GetDataModule(Index: Integer): TDataModule;
begin
  Result := TDataModule(FDataModules[Index]);
end;

function TScreen.GetDataModuleCount: Integer;
begin
  Result := FDataModules.Count;
end;

function TScreen.GetWidth: Integer;
begin
  Result := GetSystemMetrics(SM_CXSCREEN);
end;

function TScreen.GetHeight: Integer;
begin
  Result := GetSystemMetrics(SM_CYSCREEN);
end;

function TScreen.GetDesktopLeft: Integer;
begin
  Result := 0;
end;

function TScreen.GetDesktopTop: Integer;
begin
  Result := 0;
end;

function TScreen.GetDesktopWidth: Integer;
begin
  Result := GetWidth;
end;

function TScreen.GetDesktopHeight: Integer;
begin
  Result := GetHeight;
end;

function TScreen.GetWorkAreaRect: TRect;
begin
  Result := Rect(0, 0, GetWidth, GetHeight);
end;

function TScreen.GetFonts: TStrings;
begin
  if FFonts = nil then
  begin
    FFonts := TStringList.Create;
    FFonts.Add('Arial');
    FFonts.Add('Courier New');
    FFonts.Add('MS Sans Serif');
    FFonts.Add('System');
    FFonts.Add('Times New Roman');
  end;
  Result := FFonts;
end;

function StandaardCursorHandvat(Index: Integer): HCURSOR;
begin
  case Index of
    crArrow, crDefault: Result := 32512;
    crCross: Result := 32515;
    crIBeam: Result := 32513;
    crSizeNESW: Result := 32643;
    crSizeNS, crVSplit: Result := 32645;
    crSizeNWSE: Result := 32642;
    crSizeWE, crHSplit: Result := 32644;
    crUpArrow: Result := 32516;
    crHourGlass, crSQLWait: Result := 32514;
    crNo, crNoDrop: Result := 32648;
    crAppStart: Result := 32650;
    crHelp: Result := 32651;
    crHandPoint: Result := 32649;
    crSizeAll: Result := 32646;
    crNone: Result := 0;
  else
    Result := 32512;
  end;
end;

function TScreen.GetCursors(Index: Integer): HCURSOR;
var
  I: Integer;
begin
  for I := 0 to High(FCursors) do
    if FCursors[I].Index = Index then Exit(FCursors[I].Handle);
  Result := StandaardCursorHandvat(Index);
end;

procedure TScreen.SetCursors(Index: Integer; Handle: HCURSOR);
var
  I: Integer;
begin
  for I := 0 to High(FCursors) do
    if FCursors[I].Index = Index then
    begin
      FCursors[I].Handle := Handle;
      Exit;
    end;
  SetLength(FCursors, Length(FCursors) + 1);
  FCursors[High(FCursors)].Index := Index;
  FCursors[High(FCursors)].Handle := Handle;
end;

procedure TScreen.SetCursor(Value: TCursor);
var
  P: TPoint;
  Handvat: HWND;
begin
  if Value <> FCursor then
  begin
    FCursor := Value;
    if Value = crDefault then
    begin
      GetCursorPos(P);
      Handvat := WindowFromPoint(P);
      if Handvat <> 0 then
        SendMessage(Handvat, WM_SETCURSOR, Handvat, MakeLong(HTCLIENT, WM_MOUSEMOVE))
      else
        Windows.SetCursor(Cursors[crDefault]);
    end
    else
      Windows.SetCursor(Cursors[Value]);
  end;
end;

procedure TScreen.UpdateLastActive;
begin
end;

procedure TScreen.DisableAlign;
begin
end;

procedure TScreen.EnableAlign;
begin
end;

procedure TScreen.Realign;
begin
end;

procedure TScreen.ResetFonts;
begin
end;

{ ---------------------------------------------------------------- TApplication }

constructor TApplication.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTopMostList := TList.Create;
  FWindowHooks := TList.Create;
  FIcon := TIcon.Create;
  FShowHint := True;
  FHintColor := clInfoBk;
  FHintPause := 500;
  FHintShortCuts := True;
  FHintShortPause := 50;
  FHintHidePause := 2500;
  FShowMainForm := True;
  FAllowTesting := True;
  FTitle := ChangeFileExt(ExtractFileName(ExeName), '');
  CreateHandle;
end;

destructor TApplication.Destroy;
begin
  FActive := False;
  CancelHint;
  if FHandle <> 0 then
  begin
    DestroyWindow(FHandle);
    FHandle := 0;
  end;
  inherited Destroy;
  FIcon.Free;
  FTopMostList.Free;
  FWindowHooks.Free;
end;

procedure TApplication.CreateHandle;
begin
  if FHandleCreated then Exit;
  FHandleCreated := True;
  FHandle := ZMMaakVenster(0, 'TApplication', FTitle, WS_POPUP or WS_CAPTION or
    WS_CLIPSIBLINGS or WS_SYSMENU or WS_MINIMIZEBOX, ZMSchermBreedte div 2, ZMSchermHoogte div 2, 0, 0,
    0, 0, WndProc, nil);
end;

procedure TApplication.WndProc(var Message: TMessage);
begin
  with Message do
    case Msg of
      WM_CLOSE:
        if MainForm <> nil then MainForm.Close;
      WM_ACTIVATEAPP:
        FActive := WParam <> 0;
    else
      Result := ZMStandaardVensterProc(FHandle, Msg, WParam, LParam);
    end;
end;

function TApplication.GetExeName: string;
begin
  Result := ZMExeNaam;
end;

function TApplication.GetTitle: string;
begin
  Result := FTitle;
end;

procedure TApplication.SetTitle(const Value: string);
begin
  if FTitle <> Value then
  begin
    FTitle := Value;
    ZMBackend.SetTitle(Value);
  end;
end;

procedure TApplication.SetHint(const Value: string);
begin
  if FHint <> Value then
  begin
    FHint := Value;
    if Assigned(FOnHint) then FOnHint(Self);
  end;
end;

procedure TApplication.SetIcon(Value: TIcon);
begin
  FIcon.Assign(Value);
end;

procedure TApplication.SetShowHint(Value: Boolean);
begin
  FShowHint := Value;
end;

procedure TApplication.Initialize;
begin
end;

procedure TApplication.CreateForm(InstanceClass: TComponentClass; var Reference);
var
  Exemplaar: TComponent;
begin
  Exemplaar := TComponent(InstanceClass.NewInstance);
  TComponent(Reference) := Exemplaar;
  try
    Exemplaar.Create(Self);
  except
    TComponent(Reference) := nil;
    raise;
  end;
  if (FMainForm = nil) and (Exemplaar is TForm) then
  begin
    TForm(Exemplaar).HandleNeeded;
    FMainForm := TForm(Exemplaar);
    ZMHoofdVenster := FMainForm.Handle;
  end;
end;

function TApplication.IsKeyMsg(var Msg: TMsg): Boolean;
var
  Venster: HWND;
  Formulier: TCustomForm;
  Besturing: TWinControl;
  Toets: TWMKey;
begin
  Result := False;
  if (Msg.message = WM_KEYDOWN) or (Msg.message = WM_SYSKEYDOWN) then
  begin
    { menu- / formuliersneltoetsen }
    Venster := Msg.hwnd;
    Besturing := FindControl(Venster);
    if Besturing = nil then Exit;
    Formulier := GetParentForm(Besturing);
    if Formulier = nil then Exit;
    FillChar(Toets, SizeOf(Toets), 0);
    Toets.Msg := Msg.message;
    Toets.CharCode := Msg.wParam;
    Toets.KeyData := Msg.lParam;
    if Formulier.IsShortCut(Toets) then Result := True;
  end;
end;

function TApplication.ProcessMessage(var Msg: TMsg): Boolean;
var
  Afgehandeld: Boolean;
begin
  Result := False;
  if PeekMessage(Msg, 0, 0, 0, PM_REMOVE) then
  begin
    Result := True;
    if Msg.message <> WM_QUIT then
    begin
      Afgehandeld := False;
      if Assigned(FOnMessage) then FOnMessage(Msg, Afgehandeld);
      if not Afgehandeld and not IsKeyMsg(Msg) then
      begin
        TranslateMessage(Msg);
        DispatchMessage(Msg);
      end;
    end
    else
      FTerminate := True;
  end;
end;

procedure TApplication.ProcessMessages;
var
  Bericht: TMsg;
begin
  while ProcessMessage(Bericht) do {lus};
end;

procedure TApplication.DoMouseIdle;
var
  Vangbesturing: TControl;
  P: TPoint;
  Doel: TControl;
begin
  GetCursorPos(P);
  Doel := FindDragTarget(P, True);
  Vangbesturing := GetCaptureControl;
  if FMouseControl <> Doel then
  begin
    if ((FMouseControl <> nil) and (Vangbesturing = nil)) or
      ((Vangbesturing <> nil) and (FMouseControl = Vangbesturing)) then
      FMouseControl.Perform(CM_MOUSELEAVE, 0, 0);
    FMouseControl := Doel;
    if ((FMouseControl <> nil) and (Vangbesturing = nil)) or
      ((Vangbesturing <> nil) and (FMouseControl = Vangbesturing)) then
      FMouseControl.Perform(CM_MOUSEENTER, 0, 0);
  end;
end;

procedure TApplication.Idle(const Msg: TMsg);
var
  Klaar: Boolean;
begin
  DoMouseIdle;
  FreeDeviceContexts;
  Klaar := True;
  try
    if Assigned(FOnIdle) then FOnIdle(Self, Klaar);
  except
    HandleException(Self);
  end;
  if Klaar then WaitMessage;
end;

procedure TApplication.HandleMessage;
var
  Bericht: TMsg;
begin
  if not ProcessMessage(Bericht) then Idle(Bericht);
end;

procedure TApplication.Run;
begin
  FRunning := True;
  try
    if FMainForm <> nil then
    begin
      if FShowMainForm then FMainForm.Visible := True;
      repeat
        try
          HandleMessage;
        except
          HandleException(Self);
        end;
      until Terminated;
    end;
  finally
    FRunning := False;
  end;
end;

procedure TApplication.Terminate;
begin
  PostQuitMessage(0);
end;

procedure TApplication.HandleException(Sender: TObject);
begin
  if GetCapture <> 0 then SendMessage(GetCapture, WM_CANCELMODE, 0, 0);
  if ExceptObject is Exception then
  begin
    if not (ExceptObject is EAbort) then
      if Assigned(FOnException) then
        FOnException(Sender, Exception(ExceptObject))
      else
        ShowException(Exception(ExceptObject));
  end
  else
    SysUtils.ShowException(ExceptObject, ExceptAddr);
end;

procedure TApplication.ShowException(E: Exception);
var
  Bericht: string;
begin
  Bericht := E.Message;
  if (Bericht <> '') and (AnsiLastChar(Bericht) > '.') then Bericht := Bericht + '.';
  WriteLn(StdErr, 'Exception ', E.ClassName, ': ', Bericht);
  if GetEnvironmentVariable('ZM_DEBUG') <> '' then
    DumpExceptionBacktrace(StdErr);
  MessageBox(PChar(Bericht), PChar(GetTitle), MB_OK + MB_ICONSTOP);
end;

function TApplication.MessageBox(const Text, Caption: PChar; Flags: Longint): Integer;
begin
  Result := Windows.MessageBox(FHandle, Text, Caption, Flags);
end;

procedure TApplication.ActivateHint(CursorPos: TPoint);
begin
end;

procedure TApplication.BringToFront;
begin
  if (FMainForm <> nil) and FMainForm.HandleAllocated then SetActiveWindow(FMainForm.Handle);
end;

procedure TApplication.CancelHint;
begin
end;

procedure TApplication.HideHint;
begin
end;

procedure TApplication.ControlDestroyed(Control: TControl);
begin
  if FMainForm = Control then FMainForm := nil;
  if FMouseControl = Control then FMouseControl := nil;
end;

function TApplication.ExecuteAction(Action: TObject): Boolean;
begin
  Result := False;
end;

function TApplication.UpdateAction(Action: TObject): Boolean;
begin
  Result := False;
end;

function TApplication.HelpCommand(Command: Integer; Data: Longint): Boolean;
begin
  Result := False;
end;

function TApplication.HelpContext(Context: THelpContext): Boolean;
begin
  Result := False;
end;

function TApplication.HelpJump(const JumpID: string): Boolean;
begin
  Result := False;
end;

procedure TApplication.HintMouseMessage(Control: TControl; var Message: TMessage);
begin
end;

procedure TApplication.HookMainWindow(Hook: TWindowHook);
begin
end;

procedure TApplication.UnhookMainWindow(Hook: TWindowHook);
begin
end;

procedure TApplication.Minimize;
begin
  if Assigned(FOnMinimize) then FOnMinimize(Self);
end;

procedure TApplication.Restore;
begin
  if Assigned(FOnRestore) then FOnRestore(Self);
end;

procedure TApplication.NormalizeAllTopMosts;
begin
end;

procedure TApplication.NormalizeTopMosts;
begin
end;

procedure TApplication.RestoreTopMosts;
begin
end;

{ ---------------------------------------------------------------- berichtvenster }

function ZMMeldingsvenster(Venster: HWND; const Tekst, Titel: string; Vlaggen: UINT): Integer;
const
  BtnCaptions: array[1..7] of string = ('OK', 'Annuleren', 'Afbreken', 'Opnieuw', 'Negeren', 'Ja', 'Nee');
var
  Formulier: TForm;
  Lbl: TLabel;
  Knoppen: array of Integer;
  I, BW, BH, Totaalbreedte, X, Tekstbreedte, Teksthoogte: Integer;
  B: TButton;
  R: TRect;
  Standaardidx: Integer;
begin
  case Vlaggen and $F of
    MB_OKCANCEL: Knoppen := [IDOK, IDCANCEL];
    MB_ABORTRETRYIGNORE: Knoppen := [IDABORT, IDRETRY, IDIGNORE];
    MB_YESNOCANCEL: Knoppen := [IDYES, IDNO, IDCANCEL];
    MB_YESNO: Knoppen := [IDYES, IDNO];
    MB_RETRYCANCEL: Knoppen := [IDRETRY, IDCANCEL];
  else
    Knoppen := [IDOK];
  end;
  if GetEnvironmentVariable('ZM_DEBUG') <> '' then
    WriteLn(StdErr, 'Berichtvenster [', Titel, ']: ', Tekst);
  Standaardidx := (Vlaggen shr 8) and $F;
  if Standaardidx > High(Knoppen) then Standaardidx := 0;
  Formulier := TForm.CreateNew(Application);
  try
    Formulier.BorderStyle := bsDialog;
    Formulier.Caption := Titel;
    Formulier.Position := poScreenCenter;
    Formulier.Font.Name := 'MS Sans Serif';
    Formulier.Font.Height := -11;
    Lbl := TLabel.Create(Formulier);
    Lbl.Parent := Formulier;
    Lbl.Caption := Tekst;
    Lbl.AutoSize := False;
    R := Rect(0, 0, 400, 0);
    Formulier.Canvas.Font := Formulier.Font;
    DrawText(Formulier.Canvas.Handle, PChar(Tekst), Length(Tekst), R, DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
    Tekstbreedte := Max(R.Right, 120);
    Teksthoogte := R.Bottom;
    Lbl.SetBounds(16, 16, Tekstbreedte, Teksthoogte);
    Lbl.WordWrap := True;
    BW := 75;
    BH := 23;
    Totaalbreedte := Length(Knoppen) * BW + (Length(Knoppen) - 1) * 8;
    Formulier.ClientWidth := Max(Tekstbreedte + 32, Totaalbreedte + 32);
    Formulier.ClientHeight := Teksthoogte + 16 + 16 + BH + 12;
    X := (Formulier.ClientWidth - Totaalbreedte) div 2;
    for I := 0 to High(Knoppen) do
    begin
      B := TButton.Create(Formulier);
      B.Parent := Formulier;
      B.Caption := BtnCaptions[Knoppen[I]];
      if Knoppen[I] = IDOK then B.Caption := 'OK';
      B.ModalResult := Knoppen[I];
      B.SetBounds(X, Teksthoogte + 32, BW, BH);
      B.Default := I = Standaardidx;
      B.Cancel := (Knoppen[I] = IDCANCEL) or ((Length(Knoppen) = 1));
      if I = Standaardidx then Formulier.ActiveControl := B;
      Inc(X, BW + 8);
    end;
    Result := Formulier.ShowModal;
    if Result = mrCancel then
      if (Length(Knoppen) = 1) then Result := Knoppen[0];
  finally
    Formulier.Free;
  end;
end;

{ ---------------------------------------------------------------- hooks voor Controls }

function HaakKrijgOuderFormulier(Besturing: TControl): TWinControl;
begin
  Result := GetParentForm(Besturing);
end;

function HaakCursor(Cursor: TCursor): HCURSOR;
begin
  Result := Screen.Cursors[Cursor];
end;

function HaakToetsPreview(Formulier: TWinControl): Boolean;
begin
  Result := (Formulier is TCustomForm) and TCustomForm(Formulier).KeyPreview;
end;

function HaakZetFocusBesturing(Formulier, Besturing: TWinControl): Boolean;
begin
  if Formulier is TCustomForm then
    Result := TCustomForm(Formulier).SetFocusedControl(Besturing)
  else
    Result := True;
end;

procedure HaakFocusBesturing(Formulier, Besturing: TWinControl);
begin
  if Formulier is TCustomForm then
    TCustomForm(Formulier).FocusControl(Besturing)
  else
    Windows.SetFocus(Besturing.Handle);
end;

procedure HaakDefocus(Formulier, Besturing: TWinControl; Verwijderen: Boolean);
begin
  if Formulier is TCustomForm then TCustomForm(Formulier).DefocusControl(Besturing, Verwijderen);
end;

procedure HaakZetModaalResultaat(Formulier: TWinControl; MR: Integer);
begin
  if Formulier is TCustomForm then TCustomForm(Formulier).ModalResult := MR;
end;

procedure HaakAfhandelFout(Sender: TObject);
begin
  if Application <> nil then Application.HandleException(Sender);
end;

function HaakSchermCursor: TCursor;
begin
  if Screen <> nil then Result := Screen.Cursor else Result := crDefault;
end;

initialization
  LezerHulp := TLezerHulp.Create;
  ZMGetParentFormHook := HaakKrijgOuderFormulier;
  ZMCursorHook := HaakCursor;
  ZMKeyPreviewHook := HaakToetsPreview;
  ZMSetFocusedControlHook := HaakZetFocusBesturing;
  ZMFocusControlHook := HaakFocusBesturing;
  ZMDefocusHook := HaakDefocus;
  ZMHandleExceptionHook := HaakAfhandelFout;
  ZMSetModalResultHook := HaakZetModaalResultaat;
  ZMScreenCursorHook := HaakSchermCursor;
  ZMBerichtvensterHaak := ZMMeldingsvenster;
  ZMInitialiseer;
  Screen := TScreen.Create(nil);
  Application := TApplication.Create(nil);
  RegisterClasses([TForm, TFrame, TScrollBox]);
finalization
  FreeAndNil(Application);
  FreeAndNil(Screen);
  ZMAfsluiten;
  FreeAndNil(LezerHulp);
end.

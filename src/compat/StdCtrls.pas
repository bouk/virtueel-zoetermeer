unit StdCtrls;

{ Delphi 5-unit StdCtrls, draagbaar: labels, bewerkingsvelden, memo's, knoppen, keuzevakjes,
  keuzerondjes, lijstvakken, keuzelijsten, schuifbalken en groepsvakken, getekend in de
  klassieke Windows 9x-stijl door Pascal-code in plaats van de vensterklassen van Windows. }

{$MODE DELPHI}{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Menus, ZMDraw;

type
  TTextLayout = (tlTop, tlCenter, tlBottom);
  TEditCharCase = (ecNormal, ecUpperCase, ecLowerCase);
  TScrollStyle = (ssNone, ssHorizontal, ssVertical, ssBoth);
  TCheckBoxState = (cbUnchecked, cbChecked, cbGrayed);
  TComboBoxStyle = (csDropDown, csSimple, csDropDownList, csOwnerDrawFixed, csOwnerDrawVariable);
  TListBoxStyle = (lbStandard, lbOwnerDrawFixed, lbOwnerDrawVariable);
  TOwnerDrawState = set of (odSelected, odGrayed, odDisabled, odChecked, odFocused,
    odDefault, odHotLight, odInactive, odNoAccel, odNoFocusRect, odReserved1,
    odReserved2, odComboBoxEdit);
  TDrawItemEvent = procedure(Control: TWinControl; Index: Integer; Rect: TRect;
    State: TOwnerDrawState) of object;
  TMeasureItemEvent = procedure(Control: TWinControl; Index: Integer; var Height: Integer) of object;
  TScrollCode = (scLineUp, scLineDown, scPageUp, scPageDown, scPosition, scTrack, scTop,
    scBottom, scEndScroll);
  TScrollEvent = procedure(Sender: TObject; ScrollCode: TScrollCode; var ScrollPos: Integer) of object;

  TCustomGroupBox = class(TCustomControl)
  protected
    procedure Paint; override;
    procedure AdjustClientRect(var Rect: TRect); override;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TGroupBox = class(TCustomGroupBox)
  published
    property Align;
    property Anchors;
    property Caption;
    property Color;
    property Ctl3D;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

  TCustomLabel = class(TGraphicControl)
  private
    FFocusControl: TWinControl;
    FAlignment: TAlignment;
    FAutoSize: Boolean;
    FLayout: TTextLayout;
    FWordWrap: Boolean;
    FShowAccelChar: Boolean;
    function GetTransparent: Boolean;
    procedure SetAlignment(Value: TAlignment);
    procedure SetFocusControl(Value: TWinControl);
    procedure SetShowAccelChar(Value: Boolean);
    procedure SetTransparent(Value: Boolean);
    procedure SetLayout(Value: TTextLayout);
    procedure SetWordWrap(Value: Boolean);
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
    procedure CMDialogChar(var Message: TCMDialogChar); message CM_DIALOGCHAR;
  protected
    procedure AdjustBounds; dynamic;
    procedure DoDrawText(var Rect: TRect; Flags: Longint); dynamic;
    function GetLabelText: string; virtual;
    procedure Loaded; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure Paint; override;
    procedure SetAutoSize(Value: Boolean); virtual;
    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
    property AutoSize: Boolean read FAutoSize write SetAutoSize default True;
    property FocusControl: TWinControl read FFocusControl write SetFocusControl;
    property ShowAccelChar: Boolean read FShowAccelChar write SetShowAccelChar default True;
    property Transparent: Boolean read GetTransparent write SetTransparent default False;
    property Layout: TTextLayout read FLayout write SetLayout default tlTop;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default False;
  public
    constructor Create(AOwner: TComponent); override;
    property Caption;
    property Canvas;
  end;

  TLabel = class(TCustomLabel)
  published
    property Align;
    property Alignment;
    property Anchors;
    property AutoSize;
    property BiDiMode;
    property Caption;
    property Color;
    property Constraints;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property FocusControl;
    property Font;
    property ParentBiDiMode;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowAccelChar;
    property ShowHint;
    property Transparent;
    property Layout;
    property Visible;
    property WordWrap;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
  end;

  TCustomEdit = class(TWinControl)
  private
    FMaxLength: Integer;
    FBorderStyle: TBorderStyle;
    FPasswordChar: Char;
    FReadOnly: Boolean;
    FAutoSize: Boolean;
    FAutoSelect: Boolean;
    FHideSelection: Boolean;
    FOEMConvert: Boolean;
    FCharCase: TEditCharCase;
    FCreating: Boolean;
    FModified: Boolean;
    FOnChange: TNotifyEvent;
    procedure SetBorderStyle(Value: TBorderStyle);
    procedure SetCharCase(Value: TEditCharCase);
    procedure SetMaxLength(Value: Integer);
    procedure SetPasswordChar(Value: Char);
    procedure SetReadOnly(Value: Boolean);
    function GetModified: Boolean;
    procedure SetModified(Value: Boolean);
    procedure WMSetText(var Message: TWMSetText); message WM_SETTEXT;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure CMEnter(var Message: TCMEnter); message CM_ENTER;
    procedure CMFontChanged(var Message: TMessage); message CM_FONTCHANGED;
  protected
    FSelStart: Integer;
    FSelLength: Integer;
    FScrollX: Integer;
    FMouseSel: Boolean;
    procedure Change; dynamic;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
    procedure DoSetMaxLength(Value: Integer); virtual;
    function GetSelLength: Integer; virtual;
    function GetSelStart: Integer; virtual;
    function GetSelText: string; virtual;
    procedure SetAutoSize(Value: Boolean); virtual;
    procedure SetSelLength(Value: Integer); virtual;
    procedure SetSelStart(Value: Integer); virtual;
    procedure SetSelText(const Value: string);
    procedure Paint; virtual;
    procedure PaintWindow(DC: HDC); override;
    procedure KeyDownDefault(var Message: TWMKey); override;
    procedure KeyPressDefault(var Message: TWMKey); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure InsertText(const S: string); virtual;
    procedure DeleteSelection; virtual;
    function CharFromX(X: Integer): Integer;
    procedure Canvas_Font;
    property AutoSelect: Boolean read FAutoSelect write FAutoSelect default True;
    property AutoSize: Boolean read FAutoSize write SetAutoSize default True;
    property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;
    property CharCase: TEditCharCase read FCharCase write SetCharCase default ecNormal;
    property HideSelection: Boolean read FHideSelection write FHideSelection default True;
    property MaxLength: Integer read FMaxLength write SetMaxLength default 0;
    property OEMConvert: Boolean read FOEMConvert write FOEMConvert default False;
    property PasswordChar: Char read FPasswordChar write SetPasswordChar default #0;
    property ParentColor default False;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Clear; virtual;
    procedure ClearSelection;
    procedure CopyToClipboard;
    procedure CutToClipboard;
    procedure DefaultHandler(var Message); override;
    procedure PasteFromClipboard;
    procedure Undo;
    procedure ClearUndo;
    function GetSelTextBuf(Buffer: PChar; BufSize: Integer): Integer; virtual;
    procedure SelectAll;
    procedure SetSelTextBuf(Buffer: PChar);
    property CanUndo: Boolean read FModified;
    property Modified: Boolean read GetModified write SetModified;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property SelLength: Integer read GetSelLength write SetSelLength;
    property SelStart: Integer read GetSelStart write SetSelStart;
    property SelText: string read GetSelText write SetSelText;
    property Text;
    property TabStop default True;
  end;

  TEdit = class(TCustomEdit)
  published
    property Anchors;
    property AutoSelect;
    property AutoSize;
    property BiDiMode;
    property BorderStyle;
    property CharCase;
    property Color;
    property Constraints;
    property Ctl3D;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property HideSelection;
    property ImeMode;
    property ImeName;
    property MaxLength;
    property OEMConvert;
    property ParentBiDiMode;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PasswordChar;
    property PopupMenu;
    property ReadOnly;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Text;
    property Visible;
    property OnChange;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
  end;

  TCustomMemo = class(TCustomEdit)
  private
    FLines: TStrings;
    FAlignment: TAlignment;
    FScrollBars: TScrollStyle;
    FWordWrap: Boolean;
    FWantReturns: Boolean;
    FWantTabs: Boolean;
    FTopLine: Integer;
    FDisp: array of record Line, Start, Len: Integer; end;
    FDispValid: Boolean;
    FSBPressed: TZMScrollPart;
    FSBDragOffset: Integer;
    FSBTimerActive: Boolean;
    procedure SetAlignment(Value: TAlignment);
    procedure SetLines(Value: TStrings);
    procedure SetScrollBars(Value: TScrollStyle);
    procedure SetWordWrap(Value: Boolean);
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
    procedure WMTimer(var Message: TWMTimer); message WM_TIMER;
    procedure WMSize(var Message: TWMSize); message WM_SIZE;
    procedure LinesChanged(Sender: TObject);
  protected
    procedure BuildDisplay;
  private
    function TextRectM: TRect;
    function VisibleLines: Integer;
    function SBRect: TRect;
    procedure ScrollTo(Line: Integer);
    procedure DoSBPart(Part: TZMScrollPart);
    procedure PosToLineCol(Pos: Integer; out L, C: Integer);
    function LineColToPos(L, C: Integer): Integer;
    function DispIndexOfPos(Pos: Integer): Integer;
  protected
    function GetCaretPos: TPoint; virtual;
    procedure Loaded; override;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
    procedure KeyDownDefault(var Message: TWMKey); override;
    procedure KeyPressDefault(var Message: TWMKey); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure InsertText(const S: string); override;
    procedure DeleteSelection; override;
    property Alignment: TAlignment read FAlignment write SetAlignment default taLeftJustify;
    property ScrollBars: TScrollStyle read FScrollBars write SetScrollBars default ssNone;
    property WantReturns: Boolean read FWantReturns write FWantReturns default True;
    property WantTabs: Boolean read FWantTabs write FWantTabs default False;
    property WordWrap: Boolean read FWordWrap write SetWordWrap default True;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure DefaultHandler(var Message); override;
    property CaretPos: TPoint read GetCaretPos;
    property Lines: TStrings read FLines write SetLines;
  end;

  TMemo = class(TCustomMemo)
  published
    property Align;
    property Alignment;
    property Anchors;
    property BiDiMode;
    property BorderStyle;
    property Color;
    property Constraints;
    property Ctl3D;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property HideSelection;
    property ImeMode;
    property ImeName;
    property Lines;
    property MaxLength;
    property OEMConvert;
    property ParentBiDiMode;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ReadOnly;
    property ScrollBars;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property WantReturns;
    property WantTabs;
    property WordWrap;
    property OnChange;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
  end;

  TButtonControl = class(TWinControl)
  private
    FClicksDisabled: Boolean;
    FWordWrap: Boolean;
    procedure CNCommand(var Message: TWMCommand); message CN_COMMAND;
  protected
    FPressed: Boolean;
    FMouseInside: Boolean;
    function GetChecked: Boolean; virtual;
    procedure SetChecked(Value: Boolean); virtual;
    procedure WndProc(var Message: TMessage); override;
    procedure PaintWindow(DC: HDC); override;
    procedure Paint; virtual;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDownDefault(var Message: TWMKey); override;
    procedure ButtonClicked; virtual;
    function PaintCanvas: TCanvas;
    property Checked: Boolean read GetChecked write SetChecked stored False;
    property ClicksDisabled: Boolean read FClicksDisabled write FClicksDisabled;
    property WordWrap: Boolean read FWordWrap write FWordWrap default False;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TButton = class(TButtonControl)
  private
    FDefault: Boolean;
    FCancel: Boolean;
    FActive: Boolean;
    FModalResult: TModalResult;
    procedure SetDefault(Value: Boolean);
    procedure CMDialogKey(var Message: TCMDialogKey); message CM_DIALOGKEY;
    procedure CMDialogChar(var Message: TCMDialogChar); message CM_DIALOGCHAR;
    procedure CMFocusChanged(var Message: TCMFocusChanged); message CM_FOCUSCHANGED;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Paint; override;
    procedure ButtonClicked; override;
    procedure KeyPressDefault(var Message: TWMKey); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Click; override;
    function UseRightToLeftAlignment: Boolean; override;
  published
    property Anchors;
    property BiDiMode;
    property Cancel: Boolean read FCancel write FCancel default False;
    property Caption;
    property Constraints;
    property Default: Boolean read FDefault write SetDefault default False;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property ModalResult: TModalResult read FModalResult write FModalResult default 0;
    property ParentBiDiMode;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnClick;
    property OnContextPopup;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
  end;

  TCustomCheckBox = class(TButtonControl)
  private
    FAlignment: TLeftRight;
    FAllowGrayed: Boolean;
    FState: TCheckBoxState;
    procedure SetAlignment(Value: TLeftRight);
    procedure SetState(Value: TCheckBoxState);
    procedure CMDialogChar(var Message: TCMDialogChar); message CM_DIALOGCHAR;
  protected
    procedure Toggle; virtual;
    procedure Click; override;
    procedure Paint; override;
    procedure ButtonClicked; override;
    procedure KeyPressDefault(var Message: TWMKey); override;
    function GetChecked: Boolean; override;
    procedure SetChecked(Value: Boolean); override;
    property Alignment: TLeftRight read FAlignment write SetAlignment default taRightJustify;
    property AllowGrayed: Boolean read FAllowGrayed write FAllowGrayed default False;
    property State: TCheckBoxState read FState write SetState default cbUnchecked;
  public
    constructor Create(AOwner: TComponent); override;
    function GetControlsAlignment: TAlignment; override;
  end;

  TCheckBox = class(TCustomCheckBox)
  published
    property Action;
    property Alignment;
    property AllowGrayed;
    property Anchors;
    property BiDiMode;
    property Caption;
    property Checked;
    property Color;
    property Constraints;
    property Ctl3D;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
    property ParentBiDiMode;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property State;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

  TRadioButton = class(TButtonControl)
  private
    FAlignment: TLeftRight;
    FChecked: Boolean;
    procedure SetAlignment(Value: TLeftRight);
    procedure CMDialogChar(var Message: TCMDialogChar); message CM_DIALOGCHAR;
  protected
    function GetChecked: Boolean; override;
    procedure SetChecked(Value: Boolean); override;
    procedure Paint; override;
    procedure ButtonClicked; override;
  public
    constructor Create(AOwner: TComponent); override;
    function GetControlsAlignment: TAlignment; override;
  published
    property Action;
    property Alignment: TLeftRight read FAlignment write SetAlignment default taRightJustify;
    property Anchors;
    property BiDiMode;
    property Caption;
    property Checked;
    property Color;
    property Constraints;
    property Ctl3D;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Font;
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
    property OnClick;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

  TCustomListBox = class(TWinControl)
  private
    FItems: TStrings;
    FItemIndex: Integer;
    FTopIndex: Integer;
    FItemHeight: Integer;
    FBorderStyle: TBorderStyle;
    FColumns: Integer;
    FExtendedSelect: Boolean;
    FIntegralHeight: Boolean;
    FMultiSelect: Boolean;
    FSorted: Boolean;
    FStyle: TListBoxStyle;
    FTabWidth: Integer;
    FSelected: TList;
    FSBPressed: TZMScrollPart;
    FOnDrawItem: TDrawItemEvent;
    FOnMeasureItem: TMeasureItemEvent;
    function GetItemHeight: Integer;
    function GetItemIndex: Integer;
    function GetSelCount: Integer;
    function GetSelected(Index: Integer): Boolean;
    function GetTopIndex: Integer;
    procedure SetBorderStyle(Value: TBorderStyle);
    procedure SetColumnWidth;
    procedure SetColumns(Value: Integer);
    procedure SetExtendedSelect(Value: Boolean);
    procedure SetIntegralHeight(Value: Boolean);
    procedure SetItemHeight(Value: Integer);
    procedure SetItemIndex(Value: Integer);
    procedure SetItems(Value: TStrings);
    procedure SetMultiSelect(Value: Boolean);
    procedure SetSelected(Index: Integer; Value: Boolean);
    procedure SetSorted(Value: Boolean);
    procedure SetStyle(Value: TListBoxStyle);
    procedure SetTabWidth(Value: Integer);
    procedure SetTopIndex(Value: Integer);
    procedure ItemsChanged(Sender: TObject);
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
    function VisibleCount: Integer;
    function HasScrollBar: Boolean;
    function SBRect: TRect;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); virtual;
    procedure MeasureItem(Index: Integer; var Height: Integer); virtual;
    procedure PaintWindow(DC: HDC); override;
    procedure KeyDownDefault(var Message: TWMKey); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    property BorderStyle: TBorderStyle read FBorderStyle write SetBorderStyle default bsSingle;
    property Columns: Integer read FColumns write SetColumns default 0;
    property ExtendedSelect: Boolean read FExtendedSelect write SetExtendedSelect default True;
    property IntegralHeight: Boolean read FIntegralHeight write SetIntegralHeight default False;
    property ItemHeight: Integer read GetItemHeight write SetItemHeight;
    property MultiSelect: Boolean read FMultiSelect write SetMultiSelect default False;
    property ParentColor default False;
    property Sorted: Boolean read FSorted write SetSorted default False;
    property Style: TListBoxStyle read FStyle write SetStyle default lbStandard;
    property TabWidth: Integer read FTabWidth write SetTabWidth default 0;
    property OnDrawItem: TDrawItemEvent read FOnDrawItem write FOnDrawItem;
    property OnMeasureItem: TMeasureItemEvent read FOnMeasureItem write FOnMeasureItem;
  public
    Canvas: TCanvas;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear;
    function ItemAtPos(Pos: TPoint; Existing: Boolean): Integer;
    function ItemRect(Index: Integer): TRect;
    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property Items: TStrings read FItems write SetItems;
    property SelCount: Integer read GetSelCount;
    property Selected[Index: Integer]: Boolean read GetSelected write SetSelected;
    property TopIndex: Integer read GetTopIndex write SetTopIndex;
  end;

  TListBox = class(TCustomListBox)
  published
    property Align;
    property Anchors;
    property BiDiMode;
    property BorderStyle;
    property Color;
    property Columns;
    property Constraints;
    property Ctl3D;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property ExtendedSelect;
    property Font;
    property ImeMode;
    property ImeName;
    property IntegralHeight;
    property ItemHeight;
    property Items;
    property MultiSelect;
    property ParentBiDiMode;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Sorted;
    property Style;
    property TabOrder;
    property TabStop;
    property TabWidth;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDrawItem;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMeasureItem;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnStartDrag;
  end;

  TCustomComboBox = class(TWinControl)
  private
    FItems: TStrings;
    FItemIndex: Integer;
    FStyle: TComboBoxStyle;
    FDropDownCount: Integer;
    FItemHeight: Integer;
    FMaxLength: Integer;
    FSorted: Boolean;
    FDroppedDown: Boolean;
    FDropList: TWinControl;
    FCanvas: TCanvas;
    FOnChange: TNotifyEvent;
    FOnDropDown: TNotifyEvent;
    FOnDrawItem: TDrawItemEvent;
    FOnMeasureItem: TMeasureItemEvent;
    function GetItemIndex: Integer;
    procedure SetItemIndex(Value: Integer);
    procedure SetItems(Value: TStrings);
    procedure SetSorted(Value: Boolean);
    procedure SetDroppedDown(Value: Boolean);
    function GetItemHeight: Integer;
    procedure SetItemHeight(Value: Integer);
    procedure SetStyle(Value: TComboBoxStyle);
    procedure ItemsChanged(Sender: TObject);
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
  protected
    procedure Change; dynamic;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState); virtual;
    procedure DropDown; dynamic;
    procedure PaintWindow(DC: HDC); override;
    procedure KeyDownDefault(var Message: TWMKey); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure ListSelected(Index: Integer);
    property DropDownCount: Integer read FDropDownCount write FDropDownCount default 8;
    property ItemHeight: Integer read GetItemHeight write SetItemHeight;
    property MaxLength: Integer read FMaxLength write FMaxLength default 0;
    property ParentColor default False;
    property Sorted: Boolean read FSorted write SetSorted default False;
    property Style: TComboBoxStyle read FStyle write SetStyle default csDropDown;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnDrawItem: TDrawItemEvent read FOnDrawItem write FOnDrawItem;
    property OnDropDown: TNotifyEvent read FOnDropDown write FOnDropDown;
    property OnMeasureItem: TMeasureItemEvent read FOnMeasureItem write FOnMeasureItem;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Clear; virtual;
    procedure SelectAll;
    property Canvas: TCanvas read FCanvas;
    property DroppedDown: Boolean read FDroppedDown write SetDroppedDown;
    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property Items: TStrings read FItems write SetItems;
    property Text;
  end;

  TComboBox = class(TCustomComboBox)
  published
    property Style;
    property Anchors;
    property BiDiMode;
    property Color;
    property Constraints;
    property Ctl3D;
    property DragCursor;
    property DragKind;
    property DragMode;
    property DropDownCount;
    property Enabled;
    property Font;
    property ImeMode;
    property ImeName;
    property ItemHeight;
    property MaxLength;
    property ParentBiDiMode;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Sorted;
    property TabOrder;
    property TabStop;
    property Text;
    property Visible;
    property OnChange;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnDrawItem;
    property OnDropDown;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMeasureItem;
    property OnStartDrag;
    property Items;
  end;

  TScrollBar = class(TWinControl)
  private
    FKind: TScrollBarKind;
    FPosition: Integer;
    FMin: Integer;
    FMax: Integer;
    FPageSize: Integer;
    FSmallChange: TScrollBarInc;
    FLargeChange: TScrollBarInc;
    FPressed: TZMScrollPart;
    FDragOffset: Integer;
    FOnChange: TNotifyEvent;
    FOnScroll: TScrollEvent;
    procedure SetKind(Value: TScrollBarKind);
    procedure SetMax(Value: Integer);
    procedure SetMin(Value: Integer);
    procedure SetPosition(Value: Integer);
    procedure SetPageSize(Value: Integer);
    procedure DoPart(Part: TZMScrollPart);
    procedure WMTimer(var Message: TWMTimer); message WM_TIMER;
  protected
    procedure Change; dynamic;
    procedure CreateParams(var Params: TCreateParams); override;
    procedure Scroll(ScrollCode: TScrollCode; var ScrollPos: Integer); dynamic;
    procedure PaintWindow(DC: HDC); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure KeyDownDefault(var Message: TWMKey); override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetParams(APosition, AMin, AMax: Integer);
  published
    property Align;
    property Anchors;
    property BiDiMode;
    property Constraints;
    property Ctl3D;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Enabled;
    property Kind: TScrollBarKind read FKind write SetKind default sbHorizontal;
    property LargeChange: TScrollBarInc read FLargeChange write FLargeChange default 1;
    property Max: Integer read FMax write SetMax default 100;
    property Min: Integer read FMin write SetMin default 0;
    property PageSize: Integer read FPageSize write SetPageSize;
    property ParentBiDiMode;
    property ParentCtl3D;
    property ParentShowHint;
    property PopupMenu;
    property Position: Integer read FPosition write SetPosition default 0;
    property ShowHint;
    property SmallChange: TScrollBarInc read FSmallChange write FSmallChange default 1;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnScroll: TScrollEvent read FOnScroll write FOnScroll;
    property OnStartDrag;
  end;

  TStaticBorderStyle = (sbsNone, sbsSingle, sbsSunken);

  TCustomStaticText = class(TCustomControl)
  private
    FAlignment: TAlignment;
    FBorderStyle: TStaticBorderStyle;
    FShowAccelChar: Boolean;
  protected
    procedure Paint; override;
    procedure CMTextChanged(var Message: TMessage); message CM_TEXTCHANGED;
    property Alignment: TAlignment read FAlignment write FAlignment default taLeftJustify;
    property BorderStyle: TStaticBorderStyle read FBorderStyle write FBorderStyle default sbsNone;
    property ShowAccelChar: Boolean read FShowAccelChar write FShowAccelChar default True;
  public
    constructor Create(AOwner: TComponent); override;
  end;

  TStaticText = class(TCustomStaticText)
  published
    property Align;
    property Alignment;
    property Anchors;
    property BorderStyle;
    property Caption;
    property Color;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentFont;
    property ShowAccelChar;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

implementation

uses Math, ZMWin, ZMGdi;

const
  SB_TIMER_ID = 77;

{ ---------------------------------------------------------------- hulproutines }

procedure PrepareCanvasFont(C: TCanvas; Besturing: TControl; Alettertype: TFont);
begin
  C.Font := Alettertype;
end;

function ParentFormOf(C: TControl): TWinControl;
begin
  while (C <> nil) and (C.Parent <> nil) do C := C.Parent;
  if C is TWinControl then Result := TWinControl(C) else Result := nil;
end;

function IsAccelChar(VK: Word; const Tekenreeks: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  I := Pos('&', Tekenreeks);
  if (I > 0) and (I < Length(Tekenreeks)) then
    Result := UpCase(Tekenreeks[I + 1]) = UpCase(Char(VK));
end;

var
  GEditCanvas: TCanvas = nil;
  GEditDC: HDC = 0;

function EditCanvas: TCanvas;
begin
  if GEditCanvas = nil then GEditCanvas := TCanvas.Create;
  Result := GEditCanvas;
end;

{ ---------------------------------------------------------------- TCustomGroupBox }

constructor TCustomGroupBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := [csAcceptsControls, csCaptureMouse, csClickEvents, csSetCaption, csDoubleClicks, csReplicatable];
  Width := 185;
  Height := 105;
end;

procedure TCustomGroupBox.AdjustClientRect(var Rect: TRect);
begin
  inherited AdjustClientRect(Rect);
  Canvas.Font := Font;
  Inc(Rect.Top, Canvas.TextHeight('0'));
  InflateRect(Rect, -1, -1);
  if Ctl3d then InflateRect(Rect, -1, -1);
end;

procedure TCustomGroupBox.Paint;
var
  H: Integer;
  R: TRect;
begin
  with Canvas do
  begin
    Font := Self.Font;
    H := TextHeight('0');
    R := Rect(0, H div 2 - 1, Width, Height);
    Brush.Style := bsClear;
    Pen.Color := clBtnHighlight;
    OffsetRect(R, 1, 1);
    Brush.Color := clBtnHighlight;
    FrameRect(R);
    OffsetRect(R, -1, -1);
    Brush.Color := clBtnShadow;
    FrameRect(R);
    if Text <> '' then
    begin
      R := Rect(8, 0, 0, H);
      DrawText(Handle, PChar(Text), Length(Text), R, DT_LEFT or DT_SINGLELINE or DT_CALCRECT);
      Brush.Color := Color;
      Brush.Style := bsSolid;
      DrawText(Handle, PChar(Text), Length(Text), R, DT_LEFT or DT_SINGLELINE);
    end;
  end;
end;

{ ---------------------------------------------------------------- TCustomLabel }

constructor TCustomLabel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csReplicatable];
  Width := 65;
  Height := 17;
  FAutoSize := True;
  FShowAccelChar := True;
end;

function TCustomLabel.GetLabelText: string;
begin
  Result := Caption;
end;

procedure TCustomLabel.DoDrawText(var Rect: TRect; Flags: Longint);
var
  Tekst: string;
begin
  Tekst := GetLabelText;
  if (Flags and DT_CALCRECT <> 0) and ((Tekst = '') or FShowAccelChar and
    (Tekst[1] = '&') and (Tekst[2] = #0)) then Tekst := Tekst + ' ';
  if not FShowAccelChar then Flags := Flags or DT_NOPREFIX;
  Canvas.Font := Font;
  if not Enabled then
  begin
    OffsetRect(Rect, 1, 1);
    Canvas.Font.Color := clBtnHighlight;
    DrawText(Canvas.Handle, PChar(Tekst), Length(Tekst), Rect, Flags);
    OffsetRect(Rect, -1, -1);
    Canvas.Font.Color := clBtnShadow;
    DrawText(Canvas.Handle, PChar(Tekst), Length(Tekst), Rect, Flags);
  end
  else
    DrawText(Canvas.Handle, PChar(Tekst), Length(Tekst), Rect, Flags);
end;

procedure TCustomLabel.Paint;
const
  Alignments: array[TAlignment] of Word = (DT_LEFT, DT_RIGHT, DT_CENTER);
  WordWraps: array[Boolean] of Word = (0, DT_WORDBREAK);
var
  Rechthoek, Berekenrect: TRect;
  Tekenstijl: Longint;
begin
  with Canvas do
  begin
    if not Transparent then
    begin
      Brush.Color := Self.Color;
      Brush.Style := bsSolid;
      FillRect(ClientRect);
    end;
    Brush.Style := bsClear;
    Rechthoek := ClientRect;
    Tekenstijl := DT_EXPANDTABS or WordWraps[FWordWrap] or Alignments[FAlignment];
    if FLayout <> tlTop then
    begin
      Berekenrect := Rechthoek;
      DoDrawText(Berekenrect, Tekenstijl or DT_CALCRECT);
      if FLayout = tlBottom then OffsetRect(Rechthoek, 0, Height - Berekenrect.Bottom)
      else OffsetRect(Rechthoek, 0, (Height - Berekenrect.Bottom) div 2);
    end;
    DoDrawText(Rechthoek, Tekenstijl);
  end;
end;

procedure TCustomLabel.Loaded;
begin
  inherited Loaded;
  AdjustBounds;
end;

procedure TCustomLabel.AdjustBounds;
const
  WordWraps: array[Boolean] of Word = (0, DT_WORDBREAK);
var
  DC: HDC;
  X: Integer;
  Rechthoek: TRect;
  Auitlijning: TAlignment;
begin
  if not (csReading in ComponentState) and FAutoSize then
  begin
    Rechthoek := ClientRect;
    DC := GetDC(0);
    Canvas.Handle := DC;
    DoDrawText(Rechthoek, (DT_EXPANDTABS or DT_CALCRECT) or WordWraps[FWordWrap]);
    Canvas.Handle := 0;
    ReleaseDC(0, DC);
    X := Left;
    Auitlijning := FAlignment;
    if Auitlijning = taRightJustify then Inc(X, Width - Rechthoek.Right);
    SetBounds(X, Top, Rechthoek.Right, Rechthoek.Bottom);
  end;
end;

procedure TCustomLabel.SetAlignment(Value: TAlignment);
begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    Invalidate;
  end;
end;

procedure TCustomLabel.SetAutoSize(Value: Boolean);
begin
  if FAutoSize <> Value then
  begin
    FAutoSize := Value;
    AdjustBounds;
  end;
end;

function TCustomLabel.GetTransparent: Boolean;
begin
  Result := not (csOpaque in ControlStyle);
end;

procedure TCustomLabel.SetFocusControl(Value: TWinControl);
begin
  FFocusControl := Value;
  if Value <> nil then Value.FreeNotification(Self);
end;

procedure TCustomLabel.SetShowAccelChar(Value: Boolean);
begin
  if FShowAccelChar <> Value then
  begin
    FShowAccelChar := Value;
    Invalidate;
  end;
end;

procedure TCustomLabel.SetTransparent(Value: Boolean);
begin
  if Transparent <> Value then
  begin
    if Value then
      ControlStyle := ControlStyle - [csOpaque]
    else
      ControlStyle := ControlStyle + [csOpaque];
    Invalidate;
  end;
end;

procedure TCustomLabel.SetLayout(Value: TTextLayout);
begin
  if FLayout <> Value then
  begin
    FLayout := Value;
    Invalidate;
  end;
end;

procedure TCustomLabel.SetWordWrap(Value: Boolean);
begin
  if FWordWrap <> Value then
  begin
    FWordWrap := Value;
    AdjustBounds;
    Invalidate;
  end;
end;

procedure TCustomLabel.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FFocusControl) then FFocusControl := nil;
end;

procedure TCustomLabel.CMTextChanged(var Message: TMessage);
begin
  Invalidate;
  AdjustBounds;
end;

procedure TCustomLabel.CMFontChanged(var Message: TMessage);
begin
  inherited;
  AdjustBounds;
end;

procedure TCustomLabel.CMDialogChar(var Message: TCMDialogChar);
begin
  if (FFocusControl <> nil) and Enabled and ShowAccelChar and
    IsAccelChar(Message.CharCode, Caption) then
    with FFocusControl do
      if CanFocus then
      begin
        SetFocus;
        Message.Result := 1;
      end;
end;

{ ---------------------------------------------------------------- TCustomEdit }

constructor TCustomEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := [csClickEvents, csSetCaption, csDoubleClicks, csFixedHeight];
  Width := 121;
  Height := 25;
  TabStop := True;
  ParentColor := False;
  Color := clWindow;
  FBorderStyle := bsSingle;
  FAutoSize := True;
  FAutoSelect := True;
  FHideSelection := True;
  Cursor := crIBeam;
end;

procedure TCustomEdit.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  with Params do
  begin
    Style := Style or ES_AUTOHSCROLL or ES_AUTOVSCROLL;
    if FBorderStyle = bsSingle then
      if NewStyleControls and Ctl3D then
        ExStyle := ExStyle or WS_EX_CLIENTEDGE
      else
        Style := Style or WS_BORDER;
    WindowClass.hCursor := LoadCursor(0, IDC_IBEAM);
  end;
end;

procedure TCustomEdit.CreateWnd;
begin
  FCreating := True;
  try
    inherited CreateWnd;
  finally
    FCreating := False;
  end;
end;

procedure TCustomEdit.DestroyWnd;
begin
  inherited DestroyWnd;
end;

procedure TCustomEdit.SetBorderStyle(Value: TBorderStyle);
begin
  if FBorderStyle <> Value then
  begin
    FBorderStyle := Value;
    if HandleAllocated then RecreateWnd;
  end;
end;

procedure TCustomEdit.SetCharCase(Value: TEditCharCase);
begin
  FCharCase := Value;
end;

procedure TCustomEdit.SetMaxLength(Value: Integer);
begin
  if FMaxLength <> Value then
  begin
    FMaxLength := Value;
    DoSetMaxLength(Value);
  end;
end;

procedure TCustomEdit.DoSetMaxLength(Value: Integer);
begin
end;

procedure TCustomEdit.SetPasswordChar(Value: Char);
begin
  if FPasswordChar <> Value then
  begin
    FPasswordChar := Value;
    Invalidate;
  end;
end;

procedure TCustomEdit.SetReadOnly(Value: Boolean);
begin
  FReadOnly := Value;
end;

function TCustomEdit.GetModified: Boolean;
begin
  Result := FModified;
end;

procedure TCustomEdit.SetModified(Value: Boolean);
begin
  FModified := Value;
end;

procedure TCustomEdit.SetAutoSize(Value: Boolean);
begin
  FAutoSize := Value;
end;

procedure TCustomEdit.Change;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TCustomEdit.DefaultHandler(var Message);
begin
  inherited DefaultHandler(Message);
end;

procedure TCustomEdit.WMSetText(var Message: TWMSetText);
begin
  inherited;
  FSelStart := 0;
  FSelLength := 0;
  FScrollX := 0;
  Invalidate;
  if not FCreating then Change;
end;

procedure TCustomEdit.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS or DLGC_WANTCHARS or DLGC_HASSETSEL;
end;

procedure TCustomEdit.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

procedure TCustomEdit.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  Invalidate;
end;

procedure TCustomEdit.CMEnter(var Message: TCMEnter);
begin
  if FAutoSelect and not (csLButtonDown in ControlState) then SelectAll;
  inherited;
end;

procedure TCustomEdit.CMFontChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;

function TCustomEdit.GetSelStart: Integer;
begin
  Result := FSelStart;
end;

function TCustomEdit.GetSelLength: Integer;
begin
  Result := FSelLength;
end;

function TCustomEdit.GetSelText: string;
var
  S: Integer;
begin
  S := FSelStart;
  if FSelLength < 0 then S := FSelStart + FSelLength;
  Result := Copy(Text, S + 1, Abs(FSelLength));
end;

procedure TCustomEdit.SetSelStart(Value: Integer);
begin
  FSelStart := Max(0, Min(Value, Length(Text)));
  FSelLength := 0;
  Invalidate;
end;

procedure TCustomEdit.SetSelLength(Value: Integer);
begin
  FSelLength := Max(-FSelStart, Min(Value, Length(Text) - FSelStart));
  Invalidate;
end;

procedure TCustomEdit.SetSelText(const Value: string);
begin
  InsertText(Value);
end;

procedure TCustomEdit.SelectAll;
begin
  FSelStart := 0;
  FSelLength := Length(Text);
  Invalidate;
end;

procedure TCustomEdit.Clear;
begin
  Text := '';
end;

procedure TCustomEdit.ClearSelection;
begin
  DeleteSelection;
end;

procedure TCustomEdit.CopyToClipboard;
begin
end;

procedure TCustomEdit.CutToClipboard;
begin
  DeleteSelection;
end;

procedure TCustomEdit.PasteFromClipboard;
begin
end;

procedure TCustomEdit.Undo;
begin
end;

procedure TCustomEdit.ClearUndo;
begin
end;

function TCustomEdit.GetSelTextBuf(Buffer: PChar; BufSize: Integer): Integer;
begin
  StrPLCopy(Buffer, GetSelText, BufSize - 1);
  Result := StrLen(Buffer);
end;

procedure TCustomEdit.SetSelTextBuf(Buffer: PChar);
begin
  InsertText(StrPas(Buffer));
end;

procedure TCustomEdit.DeleteSelection;
var
  S, T: string;
  St: Integer;
begin
  if FSelLength = 0 then Exit;
  S := Text;
  St := FSelStart;
  if FSelLength < 0 then St := FSelStart + FSelLength;
  T := Copy(S, 1, St) + Copy(S, St + Abs(FSelLength) + 1, MaxInt);
  FCreating := True;
  try
    Text := T;
  finally
    FCreating := False;
  end;
  FSelStart := St;
  FSelLength := 0;
  FModified := True;
end;

procedure TCustomEdit.InsertText(const S: string);
var
  T, Ins: string;
  St: Integer;
begin
  if FReadOnly then Exit;
  DeleteSelection;
  Ins := S;
  case FCharCase of
    ecUpperCase: Ins := AnsiUpperCase(Ins);
    ecLowerCase: Ins := AnsiLowerCase(Ins);
  end;
  T := Text;
  if (FMaxLength > 0) and (Length(T) + Length(Ins) > FMaxLength) then
    Ins := Copy(Ins, 1, Max(0, FMaxLength - Length(T)));
  St := FSelStart;
  FCreating := True;
  try
    Text := Copy(T, 1, St) + Ins + Copy(T, St + 1, MaxInt);
  finally
    FCreating := False;
  end;
  FSelStart := St + Length(Ins);
  FSelLength := 0;
  FModified := True;
  Change;
end;

function TCustomEdit.CharFromX(X: Integer): Integer;
var
  S: string;
  I, W, CW: Integer;
begin
  S := Text;
  if FPasswordChar <> #0 then S := StringOfChar(FPasswordChar, Length(S));
  Canvas_Font;
  W := 1 - FScrollX;
  for I := 1 to Length(S) do
  begin
    CW := EditCanvas.TextWidth(S[I]);
    if X < W + CW div 2 then Exit(I - 1);
    Inc(W, CW);
  end;
  Result := Length(S);
end;

procedure TCustomEdit.Paint;
var
  S: string;
  R: TRect;
  X, CX, Y, St, Ln: Integer;
  Heeftfocus: Boolean;
begin
  S := Text;
  if FPasswordChar <> #0 then S := StringOfChar(FPasswordChar, Length(S));
  R := ClientRect;
  with EditCanvas do
  begin
    Brush.Style := bsSolid;
    if Enabled then Brush.Color := Color else Brush.Color := clBtnFace;
    FillRect(R);
    Font := Self.Font;
    if not Enabled then Font.Color := clGrayText;
    Heeftfocus := Focused;
    { houd de cursor zichtbaar }
    CX := TextWidth(Copy(S, 1, FSelStart));
    if CX - FScrollX > R.Right - 4 then FScrollX := CX - (R.Right - 4);
    if CX - FScrollX < 0 then FScrollX := CX;
    X := 1 - FScrollX;
    Y := 1;
    Brush.Style := bsClear;
    TextOut(X, Y, S);
    if Heeftfocus or not FHideSelection then
      if FSelLength <> 0 then
      begin
        St := FSelStart;
        Ln := FSelLength;
        if Ln < 0 then begin St := St + Ln; Ln := -Ln; end;
        R := Rect(X + TextWidth(Copy(S, 1, St)), Y, X + TextWidth(Copy(S, 1, St + Ln)), Y + TextHeight('Ag'));
        Brush.Color := clHighlight;
        Brush.Style := bsSolid;
        FillRect(R);
        Font.Color := clHighlightText;
        Brush.Style := bsClear;
        TextOut(R.Left, Y, Copy(S, St + 1, Ln));
      end;
    if Heeftfocus and not FReadOnly then
    begin
      Pen.Color := clWindowText;
      Pen.Mode := pmCopy;
      MoveTo(X + CX, Y);
      LineTo(X + CX, Y + TextHeight('Ag'));
    end;
  end;
end;

procedure TCustomEdit.Canvas_Font;
begin
  if GEditCanvas = nil then GEditCanvas := TCanvas.Create;
  if GEditCanvas.HandleAllocated then Exit;
  if GEditDC = 0 then GEditDC := CreateCompatibleDC(0);
  GEditCanvas.Handle := GEditDC;
  GEditCanvas.Font := Font;
end;

procedure TCustomEdit.PaintWindow(DC: HDC);
var
  Oud: HDC;
begin
  if GEditCanvas = nil then GEditCanvas := TCanvas.Create;
  Oud := 0;
  if GEditCanvas.HandleAllocated then Oud := GEditCanvas.Handle;
  GEditCanvas.Handle := DC;
  try
    Paint;
  finally
    GEditCanvas.Handle := Oud;
  end;
end;

procedure TCustomEdit.KeyDownDefault(var Message: TWMKey);
var
  Schakel: Boolean;
  Nieuwepositie: Integer;
begin
  Schakel := GetKeyState(VK_SHIFT) < 0;
  Nieuwepositie := -1;
  case Message.CharCode of
    VK_LEFT: Nieuwepositie := Max(0, FSelStart + FSelLength * Ord(Schakel) - 1);
    VK_RIGHT: Nieuwepositie := Min(Length(Text), FSelStart + FSelLength * Ord(Schakel) + 1);
    VK_HOME: Nieuwepositie := 0;
    VK_END: Nieuwepositie := Length(Text);
    VK_DELETE:
      if not FReadOnly then
      begin
        if FSelLength = 0 then FSelLength := Min(1, Length(Text) - FSelStart);
        DeleteSelection;
        Change;
        Invalidate;
      end;
  else
    inherited KeyDownDefault(Message);
    Exit;
  end;
  if Nieuwepositie >= 0 then
  begin
    if Schakel then
      FSelLength := Nieuwepositie - FSelStart
    else
    begin
      FSelStart := Nieuwepositie;
      FSelLength := 0;
    end;
    Invalidate;
  end;
end;

procedure TCustomEdit.KeyPressDefault(var Message: TWMKey);
var
  C: Char;
begin
  C := Char(Message.CharCode);
  if FReadOnly then Exit;
  case C of
    #8:
      begin
        if FSelLength = 0 then
          if FSelStart > 0 then
          begin
            Dec(FSelStart);
            FSelLength := 1;
          end;
        DeleteSelection;
        Change;
        Invalidate;
      end;
    #13, #10, #9, #27: ;
  else
    if C >= ' ' then
    begin
      InsertText(C);
      Invalidate;
    end;
  end;
end;

procedure TCustomEdit.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if CanFocus and not Focused then SetFocus;
  if Button = mbLeft then
  begin
    FSelStart := CharFromX(X);
    FSelLength := 0;
    FMouseSel := True;
    Invalidate;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCustomEdit.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  if FMouseSel and (ssLeft in Shift) then
  begin
    FSelLength := CharFromX(X) - FSelStart;
    Invalidate;
  end;
  inherited MouseMove(Shift, X, Y);
end;

procedure TCustomEdit.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  FMouseSel := False;
  inherited MouseUp(Button, Shift, X, Y);
end;

{ ---------------------------------------------------------------- TMemoStrings }

type
  { De regels van een memo. Net als het bewerkingsveld van Windows zijn de strings die via
    Lines[]/Lines.Count zichtbaar zijn de weergaveregels: met WordWrap aan wordt een lange
    tekstregel gesplitst waar de memo hem afbreekt. Text/SetText gebruiken de echte tekst. }
  TMemoStrings = class(TStrings)
  private
    FMemo: TCustomMemo;
    FRaw: TStringList;
    function Wrapped: Boolean;
  protected
    function Get(Index: Integer): string; override;
    function GetCount: Integer; override;
    function GetObject(Index: Integer): TObject; override;
    procedure Put(Index: Integer; const S: string); override;
    procedure PutObject(Index: Integer; AObject: TObject); override;
    function GetTextStr: string; override;
    procedure SetTextStr(const Value: string); override;
    procedure SetUpdateState(Updating: Boolean); override;
  public
    constructor Create(AMemo: TCustomMemo);
    destructor Destroy; override;
    procedure Clear; override;
    procedure Delete(Index: Integer); override;
    procedure Insert(Index: Integer; const S: string); override;
  end;

constructor TMemoStrings.Create(AMemo: TCustomMemo);
begin
  inherited Create;
  FMemo := AMemo;
  FRaw := TStringList.Create;
end;

destructor TMemoStrings.Destroy;
begin
  FRaw.Free;
  inherited Destroy;
end;

function TMemoStrings.Wrapped: Boolean;
begin
  Result := FMemo.FWordWrap and not (FMemo.FScrollBars in [ssHorizontal, ssBoth]);
end;

function TMemoStrings.GetCount: Integer;
begin
  if Wrapped then
  begin
    if not FMemo.FDispValid then FMemo.BuildDisplay;
    if FRaw.Count = 0 then Result := 0 else Result := Length(FMemo.FDisp);
  end
  else
    Result := FRaw.Count;
end;

function TMemoStrings.Get(Index: Integer): string;
begin
  if Wrapped then
  begin
    if not FMemo.FDispValid then FMemo.BuildDisplay;
    if (Index < 0) or (Index >= GetCount) then Error('Lijstindex (%d) buiten bereik', Index);
    with FMemo.FDisp[Index] do Result := Copy(FRaw[Line], Start, Len);
  end
  else
    Result := FRaw[Index];
end;

function TMemoStrings.GetObject(Index: Integer): TObject;
begin
  Result := nil;
end;

procedure TMemoStrings.PutObject(Index: Integer; AObject: TObject);
begin
end;

procedure TMemoStrings.Put(Index: Integer; const S: string);
begin
  if Wrapped then
  begin
    if not FMemo.FDispValid then FMemo.BuildDisplay;
    with FMemo.FDisp[Index] do
      FRaw[Line] := Copy(FRaw[Line], 1, Start - 1) + S + Copy(FRaw[Line], Start + Len, MaxInt);
  end
  else
    FRaw[Index] := S;
end;

procedure TMemoStrings.Insert(Index: Integer; const S: string);
begin
  if Wrapped and (Index < GetCount) then
  begin
    if not FMemo.FDispValid then FMemo.BuildDisplay;
    FRaw.Insert(FMemo.FDisp[Index].Line, S);
  end
  else
    FRaw.Insert(FRaw.Count, S);
end;

procedure TMemoStrings.Delete(Index: Integer);
begin
  if Wrapped then
  begin
    if not FMemo.FDispValid then FMemo.BuildDisplay;
    FRaw.Delete(FMemo.FDisp[Index].Line);
  end
  else
    FRaw.Delete(Index);
end;

procedure TMemoStrings.Clear;
begin
  FRaw.Clear;
end;

function TMemoStrings.GetTextStr: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FRaw.Count - 1 do
  begin
    if I > 0 then Result := Result + #13#10;
    Result := Result + FRaw[I];
  end;
end;

procedure TMemoStrings.SetTextStr(const Value: string);
begin
  FRaw.Text := Value;
end;

procedure TMemoStrings.SetUpdateState(Updating: Boolean);
begin
  if Updating then FRaw.BeginUpdate else FRaw.EndUpdate;
end;

{ ---------------------------------------------------------------- TCustomMemo }

constructor TCustomMemo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 185;
  Height := 89;
  AutoSize := False;
  FWordWrap := True;
  FWantReturns := True;
  FLines := TMemoStrings.Create(Self);
  TMemoStrings(FLines).FRaw.OnChange := LinesChanged;
  ControlStyle := ControlStyle - [csFixedHeight];
end;

destructor TCustomMemo.Destroy;
begin
  TMemoStrings(FLines).FRaw.OnChange := nil;
  FLines.Free;
  inherited Destroy;
end;

procedure TCustomMemo.Loaded;
begin
  inherited Loaded;
  FDispValid := False;
end;

procedure TCustomMemo.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  with Params do
    Style := Style and not (ES_AUTOHSCROLL) or ES_MULTILINE;
end;

procedure TCustomMemo.LinesChanged(Sender: TObject);
begin
  FDispValid := False;
  if FSelStart > Length(TMemoStrings(FLines).GetTextStr) then FSelStart := 0;
  Invalidate;
  if not FCreating then Change;
end;

procedure TCustomMemo.DefaultHandler(var Message);
var
  S: string;
  P: PChar;
begin
  with TMessage(Message) do
    case Msg of
      WM_GETTEXT:
        begin
          S := TMemoStrings(FLines).GetTextStr;
          if WParam > 0 then
          begin
            P := PChar(LParam);
            StrPLCopy(P, S, WParam - 1);
            Result := StrLen(P);
          end;
        end;
      WM_GETTEXTLENGTH:
        Result := Length(TMemoStrings(FLines).GetTextStr);
      WM_SETTEXT:
        begin
          if LParam = 0 then S := '' else S := StrPas(PChar(LParam));
          FLines.Text := S;
          Result := 1;
        end;
    else
      inherited DefaultHandler(Message);
    end;
end;

procedure TCustomMemo.SetLines(Value: TStrings);
begin
  FLines.Assign(Value);
end;

procedure TCustomMemo.SetAlignment(Value: TAlignment);
begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    Invalidate;
  end;
end;

procedure TCustomMemo.SetScrollBars(Value: TScrollStyle);
begin
  if FScrollBars <> Value then
  begin
    FScrollBars := Value;
    FDispValid := False;
    Invalidate;
  end;
end;

procedure TCustomMemo.SetWordWrap(Value: Boolean);
begin
  if FWordWrap <> Value then
  begin
    FWordWrap := Value;
    FDispValid := False;
    Invalidate;
  end;
end;

function TCustomMemo.GetCaretPos: TPoint;
var
  L, C: Integer;
begin
  PosToLineCol(FSelStart, L, C);
  Result := Point(C, L);
end;

procedure TCustomMemo.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  inherited;
  if FWantTabs then Message.Result := Message.Result or DLGC_WANTTAB
  else Message.Result := Message.Result and not DLGC_WANTTAB;
  if not FWantReturns then Message.Result := Message.Result and not DLGC_WANTALLKEYS
  else Message.Result := Message.Result or DLGC_WANTALLKEYS;
end;

procedure TCustomMemo.WMSize(var Message: TWMSize);
begin
  inherited;
  FDispValid := False;
end;

function TCustomMemo.SBRect: TRect;
var
  R: TRect;
begin
  R := ClientRect;
  if FScrollBars in [ssVertical, ssBoth] then
    Result := Rect(R.Right - ZMScrollBarSize, R.Top, R.Right, R.Bottom)
  else
    Result := Rect(0, 0, 0, 0);
end;

{ Het opmaakrechthoek van het bewerkingsveld, zoals Wine het berekent (EDIT_SetRectNP en
  EDIT_EM_SetMargins met EC_USEFONTINFO): het clientgebied zonder schuifbalk, 1 pixel
  naar binnen per kant bij WS_EX_CLIENTEDGE (2 bij WS_BORDER) en voor TrueType-fonts
  aan beide kanten een marge van een halve gemiddelde tekenbreedte
  (GdiGetCharDimensions). }
function TCustomMemo.TextRectM: TRect;
var
  Regelhoogte, Gemb, M, CW: Integer;
begin
  Result := ClientRect;
  if FScrollBars in [ssVertical, ssBoth] then Dec(Result.Right, ZMScrollBarSize);
  if FScrollBars in [ssHorizontal, ssBoth] then Dec(Result.Bottom, ZMScrollBarSize);
  CW := Result.Right - Result.Left;
  if GEditCanvas = nil then GEditCanvas := TCanvas.Create;
  GEditCanvas.Font := Font;
  Regelhoogte := GEditCanvas.TextHeight('Ag');
  if FBorderStyle = bsSingle then
    if NewStyleControls and Ctl3D then
    begin
      Inc(Result.Left); Dec(Result.Right);
      if Result.Bottom - Result.Top >= Regelhoogte + 2 then
      begin
        Inc(Result.Top); Dec(Result.Bottom);
      end;
    end
    else
    begin
      InflateRect(Result, -2, 0);
      if Result.Bottom - Result.Top >= Regelhoogte + 4 then InflateRect(Result, 0, -2);
    end;
  M := 0;
  if not IsBitmapFontName(Font.Name) then
  begin
    Gemb := (GEditCanvas.TextWidth('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ')
      div 26 + 1) div 2;
    M := Gemb div 2;
    if CW < 2 * M + 2 * Gemb then M := 0;
  end;
  Inc(Result.Left, M);
  Dec(Result.Right, M);
end;

{ Regels afbreken zoals EDIT_BuildLineDefs_ML van Wine: is de rest van de alinea breder
  dan het opmaakrechthoek, dan wordt een breekpunt geschat uit de verhouding van de
  breedtes en van daaruit naar links de eerste woordgrens gezocht die past. De schatting
  kan ruim voor het laatste passende woord liggen, dus regels zijn vaak korter dan
  nodig; de originele schermen laten precies deze afbrekingen zien. }
procedure TCustomMemo.BuildDisplay;

  function Zachteafbreking(const S: string; Idx: Integer): Boolean;   { breekmogelijkheid voor S[Idx] }
  begin
    Result := (Idx > 1) and not (S[Idx] in [' ', #9]) and
      ((S[Idx - 1] in [' ', #9]) or ((S[Idx - 1] = '-') and not (S[Idx] in ['0'..'9', '-'])));
  end;

var
  I, Regelstart, N, W, FW, Tekenbreedte, Vorige, Volgende, Idx, Lengte: Integer;
  D: Single;
  S, Rest: string;
  TM: TTextMetric;
begin
  FDispValid := True;
  SetLength(FDisp, 0);
  if GEditCanvas = nil then GEditCanvas := TCanvas.Create;
  Canvas_Font;
  FW := TextRectM.Right - TextRectM.Left;
  GEditCanvas.Font := Font;
  Tekenbreedte := 0;
  if GetTextMetrics(GEditCanvas.Handle, TM) then Tekenbreedte := TM.tmAveCharWidth;
  N := 0;
  for I := 0 to TMemoStrings(FLines).FRaw.Count - 1 do
  begin
    S := TMemoStrings(FLines).FRaw[I];
    Regelstart := 1;
    repeat
      Rest := Copy(S, Regelstart, MaxInt);
      Lengte := Length(Rest);
      if FWordWrap and (FScrollBars in [ssNone, ssVertical]) and (Lengte > 0) then
      begin
        W := GEditCanvas.TextWidth(Rest);
        if (W > FW) and (FW > Tekenbreedte) then
        begin
          Vorige := Lengte - 1;
          D := W / FW;
          if D > 1.2 then D := D - 0.2;
          Volgende := Trunc(Vorige / D);
          if Volgende >= Vorige then Volgende := Vorige - 1;
          repeat
            { WB_LEFT: een terug, dan terug naar een breekmogelijkheid (Idx telt vanaf 0) }
            Idx := Volgende;
            if Idx > 0 then Dec(Idx);
            while (Idx > 0) and not Zachteafbreking(Rest, Idx + 1) do Dec(Idx);
            if Idx < 0 then Idx := 0;
            Vorige := Idx;
            if Vorige > 0 then W := GEditCanvas.TextWidth(Copy(Rest, 1, Vorige));
            Volgende := Vorige - 1;
          until (Vorige = 0) or (W <= FW);
          if Vorige = 0 then
          begin
            { geen woordgrens: tekens van het eind afhalen tot het past }
            W := GEditCanvas.TextWidth(Rest);
            Vorige := Lengte - 1;
            repeat
              Dec(W, GEditCanvas.TextWidth(Rest[Vorige + 1]));
              Dec(Vorige);
            until (Vorige <= 0) or (W <= FW);
            if Vorige <= 0 then Vorige := 1;
          end;
          Lengte := Vorige;
        end;
      end;
      SetLength(FDisp, N + 1);
      FDisp[N].Line := I; FDisp[N].Start := Regelstart; FDisp[N].Len := Lengte;
      Inc(N);
      Inc(Regelstart, Lengte);
    until Regelstart > Length(S);
  end;
  if N = 0 then
  begin
    SetLength(FDisp, 1);
    FDisp[0].Line := 0; FDisp[0].Start := 1; FDisp[0].Len := 0;
  end;
end;

function TCustomMemo.VisibleLines: Integer;
var
  H: Integer;
begin
  if GEditCanvas = nil then GEditCanvas := TCanvas.Create;
  Canvas_Font;
  GEditCanvas.Font := Font;
  H := GEditCanvas.TextHeight('Ag');
  if H <= 0 then H := 13;
  Result := Max(1, (ClientHeight) div H);
end;

procedure TCustomMemo.ScrollTo(Line: Integer);
begin
  if not FDispValid then BuildDisplay;
  if Line > Length(FDisp) - VisibleLines then Line := Length(FDisp) - VisibleLines;
  if Line < 0 then Line := 0;
  if Line <> FTopLine then
  begin
    FTopLine := Line;
    Invalidate;
  end;
end;

procedure TCustomMemo.PosToLineCol(Pos: Integer; out L, C: Integer);
var
  I, Totaal: Integer;
begin
  Totaal := 0;
  for I := 0 to TMemoStrings(FLines).FRaw.Count - 1 do
  begin
    if Pos <= Totaal + Length(TMemoStrings(FLines).FRaw[I]) then
    begin
      L := I;
      C := Pos - Totaal;
      Exit;
    end;
    Inc(Totaal, Length(TMemoStrings(FLines).FRaw[I]) + 2);
  end;
  L := Max(0, TMemoStrings(FLines).FRaw.Count - 1);
  if TMemoStrings(FLines).FRaw.Count > 0 then C := Length(TMemoStrings(FLines).FRaw[L]) else C := 0;
end;

function TCustomMemo.LineColToPos(L, C: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Min(L, TMemoStrings(FLines).FRaw.Count) - 1 do Inc(Result, Length(TMemoStrings(FLines).FRaw[I]) + 2);
  Inc(Result, C);
end;

function TCustomMemo.DispIndexOfPos(Pos: Integer): Integer;
var
  L, C, I: Integer;
begin
  if not FDispValid then BuildDisplay;
  PosToLineCol(Pos, L, C);
  Result := 0;
  for I := 0 to High(FDisp) do
    if (FDisp[I].Line = L) and (C + 1 >= FDisp[I].Start) then Result := I;
end;

procedure TCustomMemo.Paint;
var
  R, TR: TRect;
  I, Y, H, X, CL, CC, CX: Integer;
  S: string;
  Heeftfocus: Boolean;
  Vlaggen: Integer;
begin
  if not FDispValid then BuildDisplay;
  R := ClientRect;
  with GEditCanvas do
  begin
    Font := Self.Font;
    Brush.Style := bsSolid;
    Brush.Color := Color;
    FillRect(R);
    H := TextHeight('Ag');
    if H <= 0 then H := 13;
    TR := TextRectM;
    Y := TR.Top;
    Heeftfocus := Focused;
    PosToLineCol(FSelStart, CL, CC);
    Brush.Style := bsClear;
    for I := FTopLine to High(FDisp) do
    begin
      if Y >= TR.Bottom then Break;
      S := Copy(TMemoStrings(FLines).FRaw[FDisp[I].Line], FDisp[I].Start, FDisp[I].Len);
      if FDisp[I].Line >= TMemoStrings(FLines).FRaw.Count then S := '';
      case FAlignment of
        taRightJustify: X := TR.Right - TextWidth(S);
        taCenter: X := TR.Left + (TR.Right - TR.Left - TextWidth(S)) div 2;
      else
        X := TR.Left;
      end;
      Vlaggen := 0;
      if Vlaggen = 0 then ;
      TextRect(Rect(TR.Left, Y, TR.Right, Y + H), X, Y, S);
      if Heeftfocus and not FReadOnly and (FDisp[I].Line = CL) and (CC + 1 >= FDisp[I].Start) and
        ((I = High(FDisp)) or (FDisp[I + 1].Line <> CL) or (CC + 1 < FDisp[I + 1].Start)) then
      begin
        CX := X + TextWidth(Copy(S, 1, CC + 1 - FDisp[I].Start));
        Pen.Color := clWindowText;
        MoveTo(CX, Y);
        LineTo(CX, Y + H);
      end;
      Inc(Y, H);
    end;
    if FScrollBars in [ssVertical, ssBoth] then
      ZMDrawScrollBar(GEditCanvas, SBRect, True, 0, Max(0, Length(FDisp) - 1), FTopLine,
        VisibleLines, FSBPressed, Enabled and (Length(FDisp) > VisibleLines));
  end;
end;

procedure TCustomMemo.DoSBPart(Part: TZMScrollPart);
begin
  case Part of
    spLineUp: ScrollTo(FTopLine - 1);
    spLineDown: ScrollTo(FTopLine + 1);
    spPageUp: ScrollTo(FTopLine - VisibleLines);
    spPageDown: ScrollTo(FTopLine + VisibleLines);
  end;
end;

procedure TCustomMemo.WMTimer(var Message: TWMTimer);
begin
  if (Message.TimerID = SB_TIMER_ID) and (FSBPressed in [spLineUp, spLineDown, spPageUp, spPageDown]) then
  begin
    DoSBPart(FSBPressed);
    SetTimer(Handle, SB_TIMER_ID, 50, nil);
  end;
end;

procedure TCustomMemo.WMMouseWheel(var Message: TWMMouseWheel);
begin
  if Message.WheelDelta > 0 then ScrollTo(FTopLine - 3) else ScrollTo(FTopLine + 3);
  Message.Result := 1;
end;

procedure TCustomMemo.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Deel: TZMScrollPart;
  H, DI, I, W, P: Integer;
  S: string;
begin
  if (FScrollBars in [ssVertical, ssBoth]) and PtInRect(SBRect, Point(X, Y)) then
  begin
    if not FDispValid then BuildDisplay;
    Deel := ZMScrollHit(SBRect, True, 0, Max(0, Length(FDisp) - 1), FTopLine, VisibleLines, Point(X, Y));
    FSBPressed := Deel;
    if Deel = spThumb then
      FSBDragOffset := Y - ZMScrollThumbRect(SBRect, True, 0, Max(0, Length(FDisp) - 1), FTopLine, VisibleLines).Top
    else
    begin
      DoSBPart(Deel);
      SetTimer(Handle, SB_TIMER_ID, 350, nil);
    end;
    Invalidate;
    MouseCapture := True;
    Exit;
  end;
  if CanFocus and not Focused then SetFocus;
  if Button = mbLeft then
  begin
    if not FDispValid then BuildDisplay;
    H := GEditCanvas.TextHeight('Ag');
    if H <= 0 then H := 13;
    DI := FTopLine + Y div H;
    if DI > High(FDisp) then DI := High(FDisp);
    if DI < 0 then DI := 0;
    S := Copy(TMemoStrings(FLines).FRaw[FDisp[DI].Line], FDisp[DI].Start, FDisp[DI].Len);
    if TMemoStrings(FLines).FRaw.Count = 0 then S := '';
    W := TextRectM.Left;
    P := 0;
    for I := 1 to Length(S) do
    begin
      if X < W + GEditCanvas.TextWidth(S[I]) div 2 then Break;
      Inc(W, GEditCanvas.TextWidth(S[I]));
      Inc(P);
    end;
    FSelStart := LineColToPos(FDisp[DI].Line, FDisp[DI].Start - 1 + P);
    FSelLength := 0;
    Invalidate;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCustomMemo.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  R, Th: TRect;
  Lengte, Bereik, Nieuwboven: Integer;
begin
  if FSBPressed = spThumb then
  begin
    R := SBRect;
    Th := ZMScrollThumbRect(R, True, 0, Max(0, Length(FDisp) - 1), FTopLine, VisibleLines);
    Lengte := (R.Bottom - R.Top - 2 * ZMScrollBarSize) - (Th.Bottom - Th.Top);
    Bereik := Length(FDisp) - VisibleLines;
    if (Lengte > 0) and (Bereik > 0) then
    begin
      Nieuwboven := (Y - FSBDragOffset - R.Top - ZMScrollBarSize) * Bereik div Lengte;
      ScrollTo(Nieuwboven);
    end;
    Exit;
  end;
  inherited MouseMove(Shift, X, Y);
end;

procedure TCustomMemo.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if FSBPressed <> spNone then
  begin
    FSBPressed := spNone;
    KillTimer(Handle, SB_TIMER_ID);
    MouseCapture := False;
    Invalidate;
    Exit;
  end;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TCustomMemo.InsertText(const S: string);
var
  T: string;
begin
  if FReadOnly then Exit;
  DeleteSelection;
  T := TMemoStrings(FLines).GetTextStr;
  T := Copy(T, 1, FSelStart) + S + Copy(T, FSelStart + 1, MaxInt);
  FCreating := True;
  try
    TMemoStrings(FLines).FRaw.Text := T;
  finally
    FCreating := False;
  end;
  Inc(FSelStart, Length(S));
  FModified := True;
  Change;
end;

procedure TCustomMemo.DeleteSelection;
var
  T: string;
  St: Integer;
begin
  if FSelLength = 0 then Exit;
  St := FSelStart;
  if FSelLength < 0 then St := FSelStart + FSelLength;
  T := TMemoStrings(FLines).GetTextStr;
  T := Copy(T, 1, St) + Copy(T, St + Abs(FSelLength) + 1, MaxInt);
  FCreating := True;
  try
    TMemoStrings(FLines).FRaw.Text := T;
  finally
    FCreating := False;
  end;
  FSelStart := St;
  FSelLength := 0;
end;

procedure TCustomMemo.KeyDownDefault(var Message: TWMKey);
var
  L, C, DI: Integer;
begin
  case Message.CharCode of
    VK_UP, VK_DOWN:
      begin
        PosToLineCol(FSelStart, L, C);
        if Message.CharCode = VK_UP then Dec(L) else Inc(L);
        if (L >= 0) and (L < TMemoStrings(FLines).FRaw.Count) then
          FSelStart := LineColToPos(L, Min(C, Length(TMemoStrings(FLines).FRaw[L])));
        FSelLength := 0;
        DI := DispIndexOfPos(FSelStart);
        if DI < FTopLine then ScrollTo(DI)
        else if DI >= FTopLine + VisibleLines then ScrollTo(DI - VisibleLines + 1);
        Invalidate;
      end;
    VK_PRIOR: ScrollTo(FTopLine - VisibleLines);
    VK_NEXT: ScrollTo(FTopLine + VisibleLines);
    VK_HOME, VK_END:
      begin
        PosToLineCol(FSelStart, L, C);
        if Message.CharCode = VK_HOME then C := 0
        else if L < TMemoStrings(FLines).FRaw.Count then C := Length(TMemoStrings(FLines).FRaw[L]);
        FSelStart := LineColToPos(L, C);
        FSelLength := 0;
        Invalidate;
      end;
  else
    inherited KeyDownDefault(Message);
  end;
end;

procedure TCustomMemo.KeyPressDefault(var Message: TWMKey);
begin
  if FReadOnly then Exit;
  case Char(Message.CharCode) of
    #13:
      if FWantReturns then
      begin
        InsertText(#13#10);
        Invalidate;
      end;
    #9:
      if FWantTabs then InsertText(#9);
  else
    inherited KeyPressDefault(Message);
  end;
end;

{ ---------------------------------------------------------------- TButtonControl }

constructor TButtonControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

function TButtonControl.GetChecked: Boolean;
begin
  Result := False;
end;

procedure TButtonControl.SetChecked(Value: Boolean);
begin
end;

procedure TButtonControl.CNCommand(var Message: TWMCommand);
begin
end;

procedure TButtonControl.WndProc(var Message: TMessage);
begin
  case Message.Msg of
    WM_LBUTTONDOWN, WM_LBUTTONDBLCLK:
      if not (csDesigning in ComponentState) and not Focused then
      begin
        FClicksDisabled := True;
        try
          if CanFocus then Windows.SetFocus(Handle);
        finally
          FClicksDisabled := False;
        end;
        if not Focused and (GetFocus <> Handle) then ;
      end;
  end;
  inherited WndProc(Message);
end;

procedure TButtonControl.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_BUTTON;
end;

procedure TButtonControl.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  Message.Result := 1;
end;

procedure TButtonControl.CMTextChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;

procedure TButtonControl.CMEnabledChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;

procedure TButtonControl.PaintWindow(DC: HDC);
var
  Oud: HDC;
begin
  if GEditCanvas = nil then GEditCanvas := TCanvas.Create;
  Oud := 0;
  if GEditCanvas.HandleAllocated then Oud := GEditCanvas.Handle;
  GEditCanvas.Handle := DC;
  try
    GEditCanvas.Font := Font;
    Paint;
  finally
    GEditCanvas.Handle := Oud;
  end;
end;

procedure TButtonControl.Paint;
begin
end;

function TButtonControl.PaintCanvas: TCanvas;
begin
  Result := EditCanvas;
end;

procedure TButtonControl.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    FPressed := True;
    FMouseInside := True;
    Invalidate;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TButtonControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Binnen: Boolean;
begin
  if FPressed then
  begin
    Binnen := PtInRect(ClientRect, Point(X, Y));
    if Binnen <> FMouseInside then
    begin
      FMouseInside := Binnen;
      Invalidate;
    end;
  end;
  inherited MouseMove(Shift, X, Y);
end;

procedure TButtonControl.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Wasingedrukt: Boolean;
begin
  Wasingedrukt := FPressed and FMouseInside and (Button = mbLeft);
  if Button = mbLeft then
  begin
    FPressed := False;
    Invalidate;
  end;
  { TControl.WMLButtonUp roept Click aan voor csClickEvents-besturingselementen; de
    knopbesturingselementen doen dit zelf (BN_CLICKED) }
  inherited MouseUp(Button, Shift, X, Y);
  if Wasingedrukt and PtInRect(ClientRect, Point(X, Y)) then ButtonClicked;
end;

procedure TButtonControl.ButtonClicked;
begin
  Click;
end;

procedure TButtonControl.KeyDownDefault(var Message: TWMKey);
begin
  inherited KeyDownDefault(Message);
end;

{ ---------------------------------------------------------------- TButton }

constructor TButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := [csSetCaption, csDoubleClicks];
  Width := 75;
  Height := 25;
  TabStop := True;
end;

procedure TButton.CreateParams(var Params: TCreateParams);
const
  ButtonStyles: array[Boolean] of DWORD = (BS_PUSHBUTTON, BS_DEFPUSHBUTTON);
begin
  inherited CreateParams(Params);
  Params.Style := Params.Style or ButtonStyles[FDefault];
end;

procedure TButton.Click;
var
  Formulier: TWinControl;
begin
  Formulier := ParentFormOf(Self);
  if (Formulier <> nil) and (FModalResult <> mrNone) and Assigned(ZMSetModalResultHook) then
    ZMSetModalResultHook(Formulier, FModalResult);
  inherited Click;
end;

procedure TButton.ButtonClicked;
begin
  Click;
end;

function TButton.UseRightToLeftAlignment: Boolean;
begin
  Result := False;
end;

procedure TButton.SetDefault(Value: Boolean);
begin
  FDefault := Value;
  Invalidate;
end;

procedure TButton.CMDialogKey(var Message: TCMDialogKey);
begin
  with Message do
    if (((CharCode = VK_RETURN) and (Focused or FDefault and not (FindControl(GetFocus) is TButton))) or
      ((CharCode = VK_ESCAPE) and FCancel)) and (KeyDataToShiftState(KeyData) = []) and
      CanFocus then
    begin
      Click;
      Result := 1;
    end
    else
      inherited;
end;

procedure TButton.CMDialogChar(var Message: TCMDialogChar);
begin
  with Message do
    if IsAccelChar(CharCode, Caption) and CanFocus then
    begin
      Click;
      Result := 1;
    end
    else
      inherited;
end;

procedure TButton.CMFocusChanged(var Message: TCMFocusChanged);
begin
  inherited;
end;

procedure TButton.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  FActive := True;
  Invalidate;
end;

procedure TButton.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  FActive := False;
  Invalidate;
end;

procedure TButton.KeyPressDefault(var Message: TWMKey);
begin
  if Char(Message.CharCode) = ' ' then Click;
end;

procedure TButton.Paint;
var
  R: TRect;
  C: TCanvas;
  Omlaag: Boolean;
begin
  C := GEditCanvas;
  R := ClientRect;
  Omlaag := FPressed and FMouseInside;
  ZMDrawButtonFace(C, R, Omlaag, FDefault or FActive, Focused);
  C.Font := Font;
  C.Brush.Style := bsClear;
  if Omlaag then OffsetRect(R, 1, 1);
  if Enabled then
    DrawText(C.Handle, PChar(Caption), Length(Caption), R, DT_CENTER or DT_VCENTER or DT_SINGLELINE)
  else
    ZMDrawDisabledText(C, R, Caption, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
  if Focused then
  begin
    R := ClientRect;
    InflateRect(R, -4, -4);
    C.Brush.Color := clBtnFace;
    C.DrawFocusRect(R);
  end;
end;

{ ---------------------------------------------------------------- TCustomCheckBox }

constructor TCustomCheckBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 97;
  Height := 17;
  TabStop := True;
  ControlStyle := [csSetCaption, csDoubleClicks];
  FAlignment := taRightJustify;
end;

function TCustomCheckBox.GetControlsAlignment: TAlignment;
begin
  Result := FAlignment;
end;

procedure TCustomCheckBox.SetAlignment(Value: TLeftRight);
begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    Invalidate;
  end;
end;

function TCustomCheckBox.GetChecked: Boolean;
begin
  Result := State = cbChecked;
end;

procedure TCustomCheckBox.SetChecked(Value: Boolean);
begin
  if Value then State := cbChecked else State := cbUnchecked;
end;

procedure TCustomCheckBox.SetState(Value: TCheckBoxState);
begin
  if FState <> Value then
  begin
    FState := Value;
    Invalidate;
    if not ClicksDisabled then Click;
  end;
end;

procedure TCustomCheckBox.Toggle;
begin
  case State of
    cbUnchecked: if AllowGrayed then State := cbGrayed else State := cbChecked;
    cbChecked: State := cbUnchecked;
    cbGrayed: State := cbChecked;
  end;
end;

procedure TCustomCheckBox.Click;
begin
  inherited Click;
end;

procedure TCustomCheckBox.ButtonClicked;
begin
  Toggle;
end;

procedure TCustomCheckBox.KeyPressDefault(var Message: TWMKey);
begin
  if Char(Message.CharCode) = ' ' then Toggle;
end;

procedure TCustomCheckBox.CMDialogChar(var Message: TCMDialogChar);
begin
  with Message do
    if IsAccelChar(CharCode, Caption) and CanFocus then
    begin
      SetFocus;
      if Focused then Toggle;
      Result := 1;
    end
    else
      inherited;
end;

procedure TCustomCheckBox.Paint;
var
  R, Vakr: TRect;
  C: TCanvas;
begin
  C := GEditCanvas;
  R := ClientRect;
  C.Brush.Color := Color;
  C.Brush.Style := bsSolid;
  C.FillRect(R);
  if FAlignment = taRightJustify then
  begin
    Vakr := Rect(0, (Height - 13) div 2, 13, (Height - 13) div 2 + 13);
    R.Left := 17;
  end
  else
  begin
    Vakr := Rect(Width - 13, (Height - 13) div 2, Width, (Height - 13) div 2 + 13);
    R.Right := Width - 17;
  end;
  ZMDrawCheck(C, Vakr, FState <> cbUnchecked, FState = cbGrayed, Enabled);
  C.Font := Font;
  C.Brush.Style := bsClear;
  if Enabled then
    DrawText(C.Handle, PChar(Caption), Length(Caption), R, DT_LEFT or DT_VCENTER or DT_SINGLELINE)
  else
    ZMDrawDisabledText(C, R, Caption, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
  if Focused then
  begin
    DrawText(C.Handle, PChar(Caption), Length(Caption), R, DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_CALCRECT);
    R.Top := (Height - (R.Bottom - R.Top)) div 2;
    R.Bottom := R.Top + C.TextHeight('Ag');
    InflateRect(R, 1, 1);
    C.DrawFocusRect(R);
  end;
end;

{ ---------------------------------------------------------------- TRadioButton }

constructor TRadioButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 113;
  Height := 17;
  ControlStyle := [csSetCaption, csDoubleClicks];
  FAlignment := taRightJustify;
end;

function TRadioButton.GetControlsAlignment: TAlignment;
begin
  Result := FAlignment;
end;

procedure TRadioButton.SetAlignment(Value: TLeftRight);
begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    Invalidate;
  end;
end;

function TRadioButton.GetChecked: Boolean;
begin
  Result := FChecked;
end;

procedure TRadioButton.SetChecked(Value: Boolean);

  procedure Broerenuitzetten;
  var
    I: Integer;
    Broer: TControl;
  begin
    if Parent <> nil then
      for I := 0 to Parent.ControlCount - 1 do
      begin
        Broer := Parent.Controls[I];
        if (Broer <> Self) and (Broer is TRadioButton) then
          TRadioButton(Broer).SetChecked(False);
      end;
  end;

begin
  if FChecked <> Value then
  begin
    FChecked := Value;
    TabStop := Value;
    Invalidate;
    if Value then
    begin
      Broerenuitzetten;
      if not ClicksDisabled then Click;
    end;
  end;
end;

procedure TRadioButton.ButtonClicked;
begin
  SetChecked(True);
end;

procedure TRadioButton.CMDialogChar(var Message: TCMDialogChar);
begin
  with Message do
    if IsAccelChar(CharCode, Caption) and CanFocus then
    begin
      SetFocus;
      if Focused then SetChecked(True);
      Result := 1;
    end
    else
      inherited;
end;

procedure TRadioButton.Paint;
var
  R, Vakr: TRect;
  C: TCanvas;
begin
  C := GEditCanvas;
  R := ClientRect;
  C.Brush.Color := Color;
  C.Brush.Style := bsSolid;
  C.FillRect(R);
  if FAlignment = taRightJustify then
  begin
    Vakr := Rect(0, (Height - 12) div 2, 12, (Height - 12) div 2 + 12);
    R.Left := 17;
  end
  else
  begin
    Vakr := Rect(Width - 12, (Height - 12) div 2, Width, (Height - 12) div 2 + 12);
    R.Right := Width - 17;
  end;
  ZMDrawRadio(C, Vakr, FChecked, Enabled);
  C.Font := Font;
  C.Brush.Style := bsClear;
  if Enabled then
    DrawText(C.Handle, PChar(Caption), Length(Caption), R, DT_LEFT or DT_VCENTER or DT_SINGLELINE)
  else
    ZMDrawDisabledText(C, R, Caption, DT_LEFT or DT_VCENTER or DT_SINGLELINE);
end;

{ ---------------------------------------------------------------- TCustomListBox }

type
  TListBoxStrings = class(TStringList)
  private
    FListBox: TCustomListBox;
  end;

constructor TCustomListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 121;
  Height := 97;
  TabStop := True;
  ParentColor := False;
  Color := clWindow;
  FItems := TListBoxStrings.Create;
  TListBoxStrings(FItems).FListBox := Self;
  TStringList(FItems).OnChange := ItemsChanged;
  FItemHeight := 16;
  FItemIndex := -1;
  FBorderStyle := bsSingle;
  FExtendedSelect := True;
  FSelected := TList.Create;
  Canvas := TControlCanvas.Create;
  TControlCanvas(Canvas).Control := Self;
end;

destructor TCustomListBox.Destroy;
begin
  TStringList(FItems).OnChange := nil;
  FItems.Free;
  FSelected.Free;
  Canvas.Free;
  inherited Destroy;
end;

procedure TCustomListBox.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  if FBorderStyle = bsSingle then Params.ExStyle := Params.ExStyle or WS_EX_CLIENTEDGE;
end;

procedure TCustomListBox.ItemsChanged(Sender: TObject);
begin
  if FItemIndex >= FItems.Count then FItemIndex := -1;
  TStringList(FItems).Sorted := FSorted;
  Invalidate;
end;

procedure TCustomListBox.Clear;
begin
  FItems.Clear;
  FItemIndex := -1;
end;

function TCustomListBox.GetItemHeight: Integer;
begin
  Result := FItemHeight;
end;

procedure TCustomListBox.SetItemHeight(Value: Integer);
begin
  if Value > 0 then FItemHeight := Value;
  Invalidate;
end;

function TCustomListBox.GetItemIndex: Integer;
begin
  Result := FItemIndex;
end;

procedure TCustomListBox.SetItemIndex(Value: Integer);
begin
  if Value >= FItems.Count then Value := -1;
  if FItemIndex <> Value then
  begin
    FItemIndex := Value;
    if (Value >= 0) then
    begin
      if Value < FTopIndex then FTopIndex := Value
      else if Value >= FTopIndex + VisibleCount then FTopIndex := Value - VisibleCount + 1;
    end;
    Invalidate;
  end;
end;

function TCustomListBox.GetSelCount: Integer;
begin
  if FItemIndex >= 0 then Result := 1 else Result := 0;
end;

function TCustomListBox.GetSelected(Index: Integer): Boolean;
begin
  Result := Index = FItemIndex;
end;

procedure TCustomListBox.SetSelected(Index: Integer; Value: Boolean);
begin
  if Value then ItemIndex := Index else if Index = FItemIndex then ItemIndex := -1;
end;

function TCustomListBox.GetTopIndex: Integer;
begin
  Result := FTopIndex;
end;

procedure TCustomListBox.SetTopIndex(Value: Integer);
begin
  if Value > FItems.Count - VisibleCount then Value := FItems.Count - VisibleCount;
  if Value < 0 then Value := 0;
  if FTopIndex <> Value then
  begin
    FTopIndex := Value;
    Invalidate;
  end;
end;

procedure TCustomListBox.SetItems(Value: TStrings);
begin
  FItems.Assign(Value);
end;

procedure TCustomListBox.SetBorderStyle(Value: TBorderStyle);
begin
  if FBorderStyle <> Value then
  begin
    FBorderStyle := Value;
    if HandleAllocated then RecreateWnd;
  end;
end;

procedure TCustomListBox.SetColumnWidth;
begin
end;

procedure TCustomListBox.SetColumns(Value: Integer);
begin
  FColumns := Value;
end;

procedure TCustomListBox.SetExtendedSelect(Value: Boolean);
begin
  FExtendedSelect := Value;
end;

procedure TCustomListBox.SetIntegralHeight(Value: Boolean);
begin
  FIntegralHeight := Value;
end;

procedure TCustomListBox.SetMultiSelect(Value: Boolean);
begin
  FMultiSelect := Value;
end;

procedure TCustomListBox.SetSorted(Value: Boolean);
begin
  if FSorted <> Value then
  begin
    FSorted := Value;
    TStringList(FItems).Sorted := Value;
  end;
end;

procedure TCustomListBox.SetStyle(Value: TListBoxStyle);
begin
  FStyle := Value;
  Invalidate;
end;

procedure TCustomListBox.SetTabWidth(Value: Integer);
begin
  FTabWidth := Value;
end;

function TCustomListBox.VisibleCount: Integer;
begin
  Result := Max(1, ClientHeight div Max(1, FItemHeight));
end;

function TCustomListBox.HasScrollBar: Boolean;
begin
  Result := FItems.Count > VisibleCount;
end;

function TCustomListBox.SBRect: TRect;
begin
  Result := Rect(ClientWidth - ZMScrollBarSize, 0, ClientWidth, ClientHeight);
end;

function TCustomListBox.ItemRect(Index: Integer): TRect;
var
  W: Integer;
begin
  W := ClientWidth;
  if HasScrollBar then Dec(W, ZMScrollBarSize);
  Result := Rect(0, (Index - FTopIndex) * FItemHeight, W, (Index - FTopIndex + 1) * FItemHeight);
end;

function TCustomListBox.ItemAtPos(Pos: TPoint; Existing: Boolean): Integer;
begin
  Result := FTopIndex + Pos.Y div Max(1, FItemHeight);
  if (Result >= FItems.Count) or (Pos.Y < 0) then
    if Existing then Result := -1 else Result := FItems.Count;
end;

procedure TCustomListBox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  if Assigned(FOnDrawItem) then
    FOnDrawItem(Self, Index, Rect, State)
  else
  begin
    Canvas.FillRect(Rect);
    if Index < FItems.Count then
      Canvas.TextOut(Rect.Left + 2, Rect.Top + (FItemHeight - Canvas.TextHeight('Ag')) div 2, FItems[Index]);
  end;
end;

procedure TCustomListBox.MeasureItem(Index: Integer; var Height: Integer);
begin
  if Assigned(FOnMeasureItem) then FOnMeasureItem(Self, Index, Height);
end;

procedure TCustomListBox.PaintWindow(DC: HDC);
var
  I: Integer;
  R: TRect;
  Staat: TOwnerDrawState;
begin
  Canvas.Handle := DC;
  try
    Canvas.Font := Font;
    Canvas.Brush.Color := Color;
    Canvas.Brush.Style := bsSolid;
    Canvas.FillRect(ClientRect);
    for I := FTopIndex to FItems.Count - 1 do
    begin
      R := ItemRect(I);
      if R.Top >= ClientHeight then Break;
      Staat := [];
      if I = FItemIndex then
      begin
        Include(Staat, odSelected);
        if Focused then Include(Staat, odFocused);
        Canvas.Brush.Color := clHighlight;
        Canvas.Font.Color := clHighlightText;
      end
      else
      begin
        Canvas.Brush.Color := Color;
        Canvas.Font.Color := Font.Color;
      end;
      DrawItem(I, R, Staat);
      if (odFocused in Staat) then Canvas.DrawFocusRect(R);
    end;
    if HasScrollBar then
      ZMDrawScrollBar(Canvas, SBRect, True, 0, FItems.Count - 1, FTopIndex, VisibleCount, FSBPressed, Enabled);
  finally
    Canvas.Handle := 0;
  end;
end;

procedure TCustomListBox.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS or DLGC_WANTCHARS;
end;

procedure TCustomListBox.WMMouseWheel(var Message: TWMMouseWheel);
begin
  if Message.WheelDelta > 0 then TopIndex := TopIndex - 3 else TopIndex := TopIndex + 3;
  Message.Result := 1;
end;

procedure TCustomListBox.KeyDownDefault(var Message: TWMKey);
var
  N: Integer;
begin
  N := FItemIndex;
  case Message.CharCode of
    VK_UP: Dec(N);
    VK_DOWN: Inc(N);
    VK_PRIOR: Dec(N, VisibleCount);
    VK_NEXT: Inc(N, VisibleCount);
    VK_HOME: N := 0;
    VK_END: N := FItems.Count - 1;
  else
    inherited KeyDownDefault(Message);
    Exit;
  end;
  N := Max(0, Min(N, FItems.Count - 1));
  if N <> FItemIndex then
  begin
    ItemIndex := N;
    Click;
  end;
end;

procedure TCustomListBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
  Deel: TZMScrollPart;
begin
  if CanFocus and not Focused then SetFocus;
  if HasScrollBar and PtInRect(SBRect, Point(X, Y)) then
  begin
    Deel := ZMScrollHit(SBRect, True, 0, FItems.Count - 1, FTopIndex, VisibleCount, Point(X, Y));
    case Deel of
      spLineUp: TopIndex := TopIndex - 1;
      spLineDown: TopIndex := TopIndex + 1;
      spPageUp: TopIndex := TopIndex - VisibleCount;
      spPageDown: TopIndex := TopIndex + VisibleCount;
    end;
    Exit;
  end;
  if Button = mbLeft then
  begin
    I := ItemAtPos(Point(X, Y), True);
    if (I >= 0) and (I <> FItemIndex) then
    begin
      ItemIndex := I;
      Click;
    end;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCustomListBox.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseMove(Shift, X, Y);
end;

procedure TCustomListBox.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
end;

{ ---------------------------------------------------------------- uitklaplijst van de combobox }

type
  TComboDropList = class(TCustomListBox)
  private
    FCombo: TCustomComboBox;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
  end;

procedure TComboDropList.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.Style := WS_POPUP or WS_BORDER;
  Params.ExStyle := WS_EX_TOOLWINDOW or WS_EX_TOPMOST;
  Params.WndParent := 0;
end;

procedure TComboDropList.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  I := ItemAtPos(Point(X, Y), True);
  if (I >= 0) and (I <> ItemIndex) then ItemIndex := I;
end;

procedure TComboDropList.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  I: Integer;
begin
  I := ItemAtPos(Point(X, Y), True);
  if (I >= 0) and PtInRect(ClientRect, Point(X, Y)) then
    FCombo.ListSelected(I)
  else if not PtInRect(ClientRect, Point(X, Y)) then
    FCombo.DroppedDown := False;
end;

{ ---------------------------------------------------------------- TCustomComboBox }

constructor TCustomComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 145;
  Height := 21;
  TabStop := True;
  ParentColor := False;
  Color := clWindow;
  FItems := TStringList.Create;
  TStringList(FItems).OnChange := ItemsChanged;
  FItemIndex := -1;
  FDropDownCount := 8;
  FItemHeight := 16;
  FCanvas := TControlCanvas.Create;
  TControlCanvas(FCanvas).Control := Self;
end;

destructor TCustomComboBox.Destroy;
begin
  FreeAndNil(FDropList);
  TStringList(FItems).OnChange := nil;
  FItems.Free;
  FCanvas.Free;
  inherited Destroy;
end;

procedure TCustomComboBox.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := Params.ExStyle or WS_EX_CLIENTEDGE;
end;

procedure TCustomComboBox.ItemsChanged(Sender: TObject);
begin
  if FItemIndex >= FItems.Count then FItemIndex := -1;
  Invalidate;
end;

procedure TCustomComboBox.Clear;
begin
  FItems.Clear;
  FItemIndex := -1;
  Text := '';
end;

procedure TCustomComboBox.SelectAll;
begin
end;

function TCustomComboBox.GetItemIndex: Integer;
begin
  Result := FItemIndex;
end;

procedure TCustomComboBox.SetItemIndex(Value: Integer);
begin
  if Value >= FItems.Count then Value := -1;
  FItemIndex := Value;
  if Value >= 0 then Text := FItems[Value] else Text := '';
  Invalidate;
end;

procedure TCustomComboBox.SetItems(Value: TStrings);
begin
  FItems.Assign(Value);
end;

procedure TCustomComboBox.SetSorted(Value: Boolean);
begin
  FSorted := Value;
  TStringList(FItems).Sorted := Value;
end;

function TCustomComboBox.GetItemHeight: Integer;
begin
  Result := FItemHeight;
end;

procedure TCustomComboBox.SetItemHeight(Value: Integer);
begin
  if Value > 0 then FItemHeight := Value;
end;

procedure TCustomComboBox.SetStyle(Value: TComboBoxStyle);
begin
  FStyle := Value;
  Invalidate;
end;

procedure TCustomComboBox.Change;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TCustomComboBox.DropDown;
begin
  if Assigned(FOnDropDown) then FOnDropDown(Self);
end;

procedure TCustomComboBox.DrawItem(Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin
  if Assigned(FOnDrawItem) then
    FOnDrawItem(Self, Index, Rect, State)
  else
  begin
    FCanvas.FillRect(Rect);
    if (Index >= 0) and (Index < FItems.Count) then
      FCanvas.TextOut(Rect.Left + 2, Rect.Top + 1, FItems[Index]);
  end;
end;

procedure TCustomComboBox.ListSelected(Index: Integer);
begin
  DroppedDown := False;
  if Index <> FItemIndex then
  begin
    ItemIndex := Index;
    Click;
    Change;
  end;
end;

procedure TCustomComboBox.SetDroppedDown(Value: Boolean);
var
  P: TPoint;
  N: Integer;
begin
  if FDroppedDown = Value then Exit;
  FDroppedDown := Value;
  if Value then
  begin
    DropDown;
    if FDropList = nil then
    begin
      FDropList := TComboDropList.Create(nil);
      TComboDropList(FDropList).FCombo := Self;
    end;
    with TComboDropList(FDropList) do
    begin
      Font := Self.Font;
      Items.Assign(Self.FItems);
      ItemHeight := Self.FItemHeight;
      N := Max(1, Min(Self.FDropDownCount, Self.FItems.Count));
      P := Self.ClientToScreen(Point(0, Self.Height - 2));
      SetBounds(P.X - 2, P.Y, Self.Width, N * ItemHeight + 2);
      ItemIndex := Self.FItemIndex;
      HandleNeeded;
      SetWindowPos(Handle, HWND_TOPMOST, P.X - 2, P.Y, Self.Width, N * ItemHeight + 2,
        SWP_SHOWWINDOW or SWP_NOACTIVATE);
      MouseCapture := True;
    end;
  end
  else if FDropList <> nil then
  begin
    if GetCaptureControl = FDropList then SetCaptureControl(nil);
    ShowWindow(FDropList.Handle, SW_HIDE);
  end;
  Invalidate;
end;

procedure TCustomComboBox.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  Message.Result := DLGC_WANTARROWS or DLGC_WANTCHARS;
end;

procedure TCustomComboBox.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  Invalidate;
end;

procedure TCustomComboBox.KeyDownDefault(var Message: TWMKey);
var
  N: Integer;
begin
  N := FItemIndex;
  case Message.CharCode of
    VK_UP: Dec(N);
    VK_DOWN: Inc(N);
    VK_F4: begin DroppedDown := not DroppedDown; Exit; end;
  else
    inherited KeyDownDefault(Message);
    Exit;
  end;
  N := Max(0, Min(N, FItems.Count - 1));
  if N <> FItemIndex then
  begin
    ItemIndex := N;
    Click;
    Change;
  end;
end;

procedure TCustomComboBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if CanFocus and not Focused then SetFocus;
  if Button = mbLeft then DroppedDown := not DroppedDown;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TCustomComboBox.PaintWindow(DC: HDC);
var
  R, BR: TRect;
  Staat: TOwnerDrawState;
begin
  FCanvas.Handle := DC;
  try
    FCanvas.Font := Font;
    R := ClientRect;
    BR := Rect(R.Right - ZMScrollBarSize, R.Top, R.Right, R.Bottom);
    R.Right := BR.Left;
    if Focused and not FDroppedDown then
    begin
      FCanvas.Brush.Color := clHighlight;
      FCanvas.Font.Color := clHighlightText;
      Staat := [odSelected, odFocused, odComboBoxEdit];
    end
    else
    begin
      FCanvas.Brush.Color := Color;
      Staat := [odComboBoxEdit];
    end;
    FCanvas.Brush.Style := bsSolid;
    if FStyle in [csDropDownList, csOwnerDrawFixed, csOwnerDrawVariable] then
      DrawItem(FItemIndex, R, Staat)
    else
    begin
      FCanvas.FillRect(R);
      FCanvas.TextOut(R.Left + 2, R.Top + 1, Text);
    end;
    if FDroppedDown then
    begin
      FCanvas.Brush.Color := clBtnShadow;
      FCanvas.FrameRect(BR);
      InflateRect(BR, -1, -1);
      FCanvas.Brush.Color := clBtnFace;
      FCanvas.FillRect(BR);
      OffsetRect(BR, 1, 1);
    end
    else
    begin
      ZMDrawRaised(FCanvas, BR);
      FCanvas.Brush.Color := clBtnFace;
      FCanvas.FillRect(BR);
    end;
    ZMDrawArrow(FCanvas, BR, 1, Enabled);
  finally
    FCanvas.Handle := 0;
  end;
end;

{ ---------------------------------------------------------------- TScrollBar }

constructor TScrollBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 121;
  Height := 16;
  TabStop := True;
  ControlStyle := [csFramed, csDoubleClicks, csOpaque];
  FKind := sbHorizontal;
  FPosition := 0;
  FMin := 0;
  FMax := 100;
  FSmallChange := 1;
  FLargeChange := 1;
end;

procedure TScrollBar.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
end;

procedure TScrollBar.SetKind(Value: TScrollBarKind);
begin
  if FKind <> Value then
  begin
    FKind := Value;
    if not (csLoading in ComponentState) then SetBounds(Left, Top, Height, Width);
    Invalidate;
  end;
end;

procedure TScrollBar.SetParams(APosition, AMin, AMax: Integer);
begin
  if AMax < AMin then
    raise EInvalidOperation.Create('Scroll bar property out of range');
  if APosition < AMin then APosition := AMin;
  if APosition > AMax then APosition := AMax;
  if (FMin <> AMin) or (FMax <> AMax) then
  begin
    FMin := AMin;
    FMax := AMax;
    Invalidate;
  end;
  if FPosition <> APosition then
  begin
    FPosition := APosition;
    Invalidate;
    Change;
  end;
end;

procedure TScrollBar.SetPosition(Value: Integer);
begin
  SetParams(Value, FMin, FMax);
end;

procedure TScrollBar.SetMin(Value: Integer);
begin
  if Value <= FMax then SetParams(FPosition, Value, FMax);
end;

procedure TScrollBar.SetMax(Value: Integer);
begin
  if Value >= FMin then SetParams(FPosition, FMin, Value);
end;

procedure TScrollBar.SetPageSize(Value: Integer);
begin
  FPageSize := Value;
  Invalidate;
end;

procedure TScrollBar.Change;
begin
  inherited Changed;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TScrollBar.Scroll(ScrollCode: TScrollCode; var ScrollPos: Integer);
begin
  if Assigned(FOnScroll) then FOnScroll(Self, ScrollCode, ScrollPos);
end;

procedure TScrollBar.DoPart(Part: TZMScrollPart);
var
  P: Integer;
  Code: TScrollCode;
begin
  P := FPosition;
  case Part of
    spLineUp: begin Dec(P, FSmallChange); Code := scLineUp; end;
    spLineDown: begin Inc(P, FSmallChange); Code := scLineDown; end;
    spPageUp: begin Dec(P, FLargeChange); Code := scPageUp; end;
    spPageDown: begin Inc(P, FLargeChange); Code := scPageDown; end;
  else
    Exit;
  end;
  if P < FMin then P := FMin;
  if P > FMax then P := FMax;
  Scroll(Code, P);
  SetPosition(P);
end;

procedure TScrollBar.PaintWindow(DC: HDC);
var
  C: TCanvas;
begin
  C := TCanvas.Create;
  try
    C.Handle := DC;
    ZMDrawScrollBar(C, ClientRect, FKind = sbVertical, FMin, FMax, FPosition, FPageSize, FPressed, Enabled);
    C.Handle := 0;
  finally
    C.Free;
  end;
end;

procedure TScrollBar.WMTimer(var Message: TWMTimer);
begin
  if (Message.TimerID = SB_TIMER_ID) and (FPressed in [spLineUp, spLineDown, spPageUp, spPageDown]) then
  begin
    DoPart(FPressed);
    SetTimer(Handle, SB_TIMER_ID, 50, nil);
  end;
end;

procedure TScrollBar.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Th: TRect;
begin
  if Button = mbLeft then
  begin
    FPressed := ZMScrollHit(ClientRect, FKind = sbVertical, FMin, FMax, FPosition, FPageSize, Point(X, Y));
    if FPressed = spThumb then
    begin
      Th := ZMScrollThumbRect(ClientRect, FKind = sbVertical, FMin, FMax, FPosition, FPageSize);
      if FKind = sbVertical then FDragOffset := Y - Th.Top else FDragOffset := X - Th.Left;
    end
    else
    begin
      DoPart(FPressed);
      SetTimer(Handle, SB_TIMER_ID, 350, nil);
    end;
    Invalidate;
  end;
  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TScrollBar.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  R, Th: TRect;
  Lengte, P, Uit: Integer;
begin
  if FPressed = spThumb then
  begin
    R := ClientRect;
    Th := ZMScrollThumbRect(R, FKind = sbVertical, FMin, FMax, FPosition, FPageSize);
    if FKind = sbVertical then
    begin
      Lengte := (R.Bottom - R.Top - 2 * ZMScrollBarSize) - (Th.Bottom - Th.Top);
      Uit := Y - FDragOffset - R.Top - ZMScrollBarSize;
    end
    else
    begin
      Lengte := (R.Right - R.Left - 2 * ZMScrollBarSize) - (Th.Right - Th.Left);
      Uit := X - FDragOffset - R.Left - ZMScrollBarSize;
    end;
    if Lengte > 0 then
    begin
      P := FMin + Uit * (FMax - FMin - Math.Max(FPageSize - 1, 0)) div Lengte;
      P := Math.Max(FMin, Math.Min(FMax, P));
      Scroll(scTrack, P);
      SetPosition(P);
    end;
  end;
  inherited MouseMove(Shift, X, Y);
end;

procedure TScrollBar.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: Integer;
begin
  if FPressed <> spNone then
  begin
    KillTimer(Handle, SB_TIMER_ID);
    if FPressed = spThumb then
    begin
      P := FPosition;
      Scroll(scPosition, P);
    end;
    P := FPosition;
    Scroll(scEndScroll, P);
    FPressed := spNone;
    Invalidate;
  end;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TScrollBar.KeyDownDefault(var Message: TWMKey);
begin
  case Message.CharCode of
    VK_LEFT, VK_UP: DoPart(spLineUp);
    VK_RIGHT, VK_DOWN: DoPart(spLineDown);
    VK_PRIOR: DoPart(spPageUp);
    VK_NEXT: DoPart(spPageDown);
  else
    inherited KeyDownDefault(Message);
  end;
end;

{ ---------------------------------------------------------------- TCustomStaticText }

constructor TCustomStaticText.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := [csCaptureMouse, csClickEvents, csSetCaption, csReplicatable, csDoubleClicks];
  Width := 65;
  Height := 17;
  FShowAccelChar := True;
end;

procedure TCustomStaticText.Paint;
const
  Alignments: array[TAlignment] of Word = (DT_LEFT, DT_RIGHT, DT_CENTER);
var
  R: TRect;
begin
  R := ClientRect;
  Canvas.Brush.Color := Color;
  Canvas.FillRect(R);
  Canvas.Font := Font;
  Canvas.Brush.Style := bsClear;
  DrawText(Canvas.Handle, PChar(Caption), Length(Caption), R, Alignments[FAlignment] or DT_WORDBREAK);
end;

procedure TCustomStaticText.CMTextChanged(var Message: TMessage);
begin
  inherited;
  Invalidate;
end;

initialization
  RegisterClasses([TGroupBox, TLabel, TEdit, TMemo, TButton, TCheckBox, TRadioButton,
    TListBox, TComboBox, TScrollBar, TStaticText]);
finalization
  FreeAndNil(GEditCanvas);
  if GEditDC <> 0 then DeleteDC(GEditDC);
end.

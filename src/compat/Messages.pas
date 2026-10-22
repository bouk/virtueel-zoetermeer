unit Messages;

{ Portable subset of the Delphi 5 Messages unit: WM_* constants and the
  message records used by message handlers (procedure X(var Msg: TWMxxx); message WM_xxx).

  64-bit layout: Msg is a Cardinal followed (on 64-bit CPUs) by 4 bytes of padding,
  WParam/LParam/Result are pointer sized, like FPC's own Windows/LCL headers. }

{$MODE DELPHI}{$H+}

interface

uses Windows;

const
  WM_NULL = $0000;
  WM_CREATE = $0001;
  WM_DESTROY = $0002;
  WM_MOVE = $0003;
  WM_SIZE = $0005;
  WM_ACTIVATE = $0006;
  WM_SETFOCUS = $0007;
  WM_KILLFOCUS = $0008;
  WM_ENABLE = $000A;
  WM_SETREDRAW = $000B;
  WM_SETTEXT = $000C;
  WM_GETTEXT = $000D;
  WM_GETTEXTLENGTH = $000E;
  WM_PAINT = $000F;
  WM_CLOSE = $0010;
  WM_QUERYENDSESSION = $0011;
  WM_QUIT = $0012;
  WM_QUERYOPEN = $0013;
  WM_ERASEBKGND = $0014;
  WM_SYSCOLORCHANGE = $0015;
  WM_ENDSESSION = $0016;
  WM_SHOWWINDOW = $0018;
  WM_WININICHANGE = $001A;
  WM_SETTINGCHANGE = WM_WININICHANGE;
  WM_DEVMODECHANGE = $001B;
  WM_ACTIVATEAPP = $001C;
  WM_FONTCHANGE = $001D;
  WM_TIMECHANGE = $001E;
  WM_CANCELMODE = $001F;
  WM_SETCURSOR = $0020;
  WM_MOUSEACTIVATE = $0021;
  WM_CHILDACTIVATE = $0022;
  WM_QUEUESYNC = $0023;
  WM_GETMINMAXINFO = $0024;
  WM_PAINTICON = $0026;
  WM_ICONERASEBKGND = $0027;
  WM_NEXTDLGCTL = $0028;
  WM_SPOOLERSTATUS = $002A;
  WM_DRAWITEM = $002B;
  WM_MEASUREITEM = $002C;
  WM_DELETEITEM = $002D;
  WM_VKEYTOITEM = $002E;
  WM_CHARTOITEM = $002F;
  WM_SETFONT = $0030;
  WM_GETFONT = $0031;
  WM_SETHOTKEY = $0032;
  WM_GETHOTKEY = $0033;
  WM_QUERYDRAGICON = $0037;
  WM_COMPAREITEM = $0039;
  WM_GETOBJECT = $003D;
  WM_COMPACTING = $0041;
  WM_WINDOWPOSCHANGING = $0046;
  WM_WINDOWPOSCHANGED = $0047;
  WM_POWER = $0048;
  WM_COPYDATA = $004A;
  WM_CANCELJOURNAL = $004B;
  WM_NOTIFY = $004E;
  WM_INPUTLANGCHANGEREQUEST = $0050;
  WM_INPUTLANGCHANGE = $0051;
  WM_TCARD = $0052;
  WM_HELP = $0053;
  WM_USERCHANGED = $0054;
  WM_NOTIFYFORMAT = $0055;
  WM_CONTEXTMENU = $007B;
  WM_STYLECHANGING = $007C;
  WM_STYLECHANGED = $007D;
  WM_DISPLAYCHANGE = $007E;
  WM_GETICON = $007F;
  WM_SETICON = $0080;
  WM_NCCREATE = $0081;
  WM_NCDESTROY = $0082;
  WM_NCCALCSIZE = $0083;
  WM_NCHITTEST = $0084;
  WM_NCPAINT = $0085;
  WM_NCACTIVATE = $0086;
  WM_GETDLGCODE = $0087;
  WM_NCMOUSEMOVE = $00A0;
  WM_NCLBUTTONDOWN = $00A1;
  WM_NCLBUTTONUP = $00A2;
  WM_NCLBUTTONDBLCLK = $00A3;
  WM_NCRBUTTONDOWN = $00A4;
  WM_NCRBUTTONUP = $00A5;
  WM_NCRBUTTONDBLCLK = $00A6;
  WM_NCMBUTTONDOWN = $00A7;
  WM_NCMBUTTONUP = $00A8;
  WM_NCMBUTTONDBLCLK = $00A9;
  WM_KEYFIRST = $0100;
  WM_KEYDOWN = $0100;
  WM_KEYUP = $0101;
  WM_CHAR = $0102;
  WM_DEADCHAR = $0103;
  WM_SYSKEYDOWN = $0104;
  WM_SYSKEYUP = $0105;
  WM_SYSCHAR = $0106;
  WM_SYSDEADCHAR = $0107;
  WM_KEYLAST = $0108;
  WM_INITDIALOG = $0110;
  WM_COMMAND = $0111;
  WM_SYSCOMMAND = $0112;
  WM_TIMER = $0113;
  WM_HSCROLL = $0114;
  WM_VSCROLL = $0115;
  WM_INITMENU = $0116;
  WM_INITMENUPOPUP = $0117;
  WM_MENUSELECT = $011F;
  WM_MENUCHAR = $0120;
  WM_ENTERIDLE = $0121;
  WM_CTLCOLORMSGBOX = $0132;
  WM_CTLCOLOREDIT = $0133;
  WM_CTLCOLORLISTBOX = $0134;
  WM_CTLCOLORBTN = $0135;
  WM_CTLCOLORDLG = $0136;
  WM_CTLCOLORSCROLLBAR = $0137;
  WM_CTLCOLORSTATIC = $0138;
  WM_MOUSEFIRST = $0200;
  WM_MOUSEMOVE = $0200;
  WM_LBUTTONDOWN = $0201;
  WM_LBUTTONUP = $0202;
  WM_LBUTTONDBLCLK = $0203;
  WM_RBUTTONDOWN = $0204;
  WM_RBUTTONUP = $0205;
  WM_RBUTTONDBLCLK = $0206;
  WM_MBUTTONDOWN = $0207;
  WM_MBUTTONUP = $0208;
  WM_MBUTTONDBLCLK = $0209;
  WM_MOUSEWHEEL = $020A;
  WM_MOUSELAST = $020A;
  WM_PARENTNOTIFY = $0210;
  WM_ENTERMENULOOP = $0211;
  WM_EXITMENULOOP = $0212;
  WM_NEXTMENU = $0213;
  WM_SIZING = $0214;
  WM_CAPTURECHANGED = $0215;
  WM_MOVING = $0216;
  WM_POWERBROADCAST = $0218;
  WM_DEVICECHANGE = $0219;
  WM_MDICREATE = $0220;
  WM_MDIDESTROY = $0221;
  WM_MDIACTIVATE = $0222;
  WM_ENTERSIZEMOVE = $0231;
  WM_EXITSIZEMOVE = $0232;
  WM_DROPFILES = $0233;
  WM_IME_STARTCOMPOSITION = $010D;
  WM_IME_ENDCOMPOSITION = $010E;
  WM_IME_COMPOSITION = $010F;
  WM_IME_SETCONTEXT = $0281;
  WM_IME_NOTIFY = $0282;
  WM_MOUSEHOVER = $02A1;
  WM_MOUSELEAVE = $02A3;
  WM_CUT = $0300;
  WM_COPY = $0301;
  WM_PASTE = $0302;
  WM_CLEAR = $0303;
  WM_UNDO = $0304;
  WM_RENDERFORMAT = $0305;
  WM_RENDERALLFORMATS = $0306;
  WM_DESTROYCLIPBOARD = $0307;
  WM_DRAWCLIPBOARD = $0308;
  WM_PAINTCLIPBOARD = $0309;
  WM_QUERYNEWPALETTE = $030F;
  WM_PALETTEISCHANGING = $0310;
  WM_PALETTECHANGED = $0311;
  WM_HOTKEY = $0312;
  WM_PRINT = $0317;
  WM_PRINTCLIENT = $0318;
  WM_APP = $8000;
  WM_USER = $0400;

  { Edit control messages }
  EM_GETSEL = $00B0;
  EM_SETSEL = $00B1;
  EM_GETRECT = $00B2;
  EM_SETRECT = $00B3;
  EM_SCROLL = $00B5;
  EM_LINESCROLL = $00B6;
  EM_SCROLLCARET = $00B7;
  EM_GETMODIFY = $00B8;
  EM_SETMODIFY = $00B9;
  EM_GETLINECOUNT = $00BA;
  EM_LINEINDEX = $00BB;
  EM_LINELENGTH = $00C1;
  EM_REPLACESEL = $00C2;
  EM_GETLINE = $00C4;
  EM_LIMITTEXT = $00C5;
  EM_CANUNDO = $00C6;
  EM_UNDO = $00C7;
  EM_LINEFROMCHAR = $00C9;
  EM_SETREADONLY = $00CF;
  EM_GETFIRSTVISIBLELINE = $00CE;

  { Button messages }
  BM_GETCHECK = $00F0;
  BM_SETCHECK = $00F1;
  BM_GETSTATE = $00F2;
  BM_SETSTATE = $00F3;
  BM_SETSTYLE = $00F4;
  BM_CLICK = $00F5;
  BN_CLICKED = 0;

  { Notification codes }
  EN_CHANGE = $0300;
  EN_UPDATE = $0400;
  LBN_SELCHANGE = 1;
  LBN_DBLCLK = 2;
  CBN_SELCHANGE = 1;
  CBN_DBLCLK = 2;
  CBN_EDITCHANGE = 5;
  CBN_DROPDOWN = 7;
  CBN_CLOSEUP = 8;

  { WM_ACTIVATE state values }
  WA_INACTIVE = 0;
  WA_ACTIVE = 1;
  WA_CLICKACTIVE = 2;

  { WM_SIZE values }
  SIZE_RESTORED = 0;
  SIZE_MINIMIZED = 1;
  SIZE_MAXIMIZED = 2;

type
  PMessage = ^TMessage;
  TMessage = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    case Integer of
      0: (WParam: WPARAM; LParam: LPARAM; Result: LRESULT);
      1: (WParamLo: Word; WParamHi: Word;
{$IFDEF CPU64}
          WParamFiller: Cardinal;
{$ENDIF}
          LParamLo: Word; LParamHi: Word;
{$IFDEF CPU64}
          LParamFiller: Cardinal;
{$ENDIF}
          ResultLo: Word; ResultHi: Word);
  end;

  TWndMethod = procedure(var Message: TMessage) of object;

  TWMNoParams = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Unused: array[0..1] of PtrInt;
    Result: LRESULT;
  end;

  TWMMouse = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Keys: WPARAM;
    case Integer of
      0: (XPos: Smallint; YPos: Smallint);
      1: (Pos: TSmallPoint;
{$IFDEF CPU64}
          PosFiller: Cardinal;
{$ENDIF}
          Result: LRESULT);
  end;

  TWMMouseWheel = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Keys: Smallint;
    WheelDelta: Smallint;
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

  TWMLButtonDown = TWMMouse;
  TWMLButtonUp = TWMMouse;
  TWMLButtonDblClk = TWMMouse;
  TWMRButtonDown = TWMMouse;
  TWMRButtonUp = TWMMouse;
  TWMRButtonDblClk = TWMMouse;
  TWMMButtonDown = TWMMouse;
  TWMMButtonUp = TWMMouse;
  TWMMButtonDblClk = TWMMouse;
  TWMMouseMove = TWMMouse;

  TWMNCHitMessage = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    HitTest: PtrInt;
    XCursor: Smallint;
    YCursor: Smallint;
{$IFDEF CPU64}
    CursorFiller: Cardinal;
{$ENDIF}
    Result: LRESULT;
  end;
  TWMNCLButtonDown = TWMNCHitMessage;
  TWMNCLButtonUp = TWMNCHitMessage;
  TWMNCMouseMove = TWMNCHitMessage;

  TWMNCHitTest = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Unused: PtrInt;
    case Integer of
      0: (XPos: Smallint; YPos: Smallint);
      1: (Pos: TSmallPoint;
{$IFDEF CPU64}
          PosFiller: Cardinal;
{$ENDIF}
          Result: LRESULT);
  end;

  TWMKey = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    CharCode: Word;
    Unused: Word;
{$IFDEF CPU64}
    CharCodeFiller: Cardinal;
{$ENDIF}
    KeyData: Longint;
{$IFDEF CPU64}
    KeyDataFiller: Cardinal;
{$ENDIF}
    Result: LRESULT;
  end;
  TWMChar = TWMKey;
  TWMKeyDown = TWMKey;
  TWMKeyUp = TWMKey;
  TWMSysChar = TWMKey;
  TWMSysKeyDown = TWMKey;
  TWMSysKeyUp = TWMKey;

  TWMEraseBkgnd = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    DC: HDC;
    Unused: LPARAM;
    Result: LRESULT;
  end;

  TWMPaint = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    DC: HDC;
    Unused: LPARAM;
    Result: LRESULT;
  end;

  TWMNCPaint = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    RGN: HRGN;
    Unused: LPARAM;
    Result: LRESULT;
  end;

  TWMTimer = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    TimerID: WPARAM;
    TimerProc: TFarProc;
    Result: LRESULT;
  end;

  TWMSize = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    SizeType: WPARAM;
    Width: Word;
    Height: Word;
{$IFDEF CPU64}
    SizeFiller: Cardinal;
{$ENDIF}
    Result: LRESULT;
  end;

  TWMMove = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Unused: WPARAM;
    case Integer of
      0: (XPos: Smallint; YPos: Smallint);
      1: (Pos: TSmallPoint;
{$IFDEF CPU64}
          PosFiller: Cardinal;
{$ENDIF}
          Result: LRESULT);
  end;

  TWMSetFocus = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    FocusedWnd: HWND;
    Unused: LPARAM;
    Result: LRESULT;
  end;

  TWMKillFocus = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    FocusedWnd: HWND;
    Unused: LPARAM;
    Result: LRESULT;
  end;

  TWMActivate = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Active: Word;
    Minimized: WordBool;
{$IFDEF CPU64}
    ActiveFiller: Cardinal;
{$ENDIF}
    ActiveWindow: HWND;
    Result: LRESULT;
  end;

  TWMActivateApp = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Active: LongBool;
{$IFDEF CPU64}
    ActiveFiller: Cardinal;
{$ENDIF}
    ThreadId: LPARAM;
    Result: LRESULT;
  end;

  TWMCommand = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    ItemID: Word;
    NotifyCode: Word;
{$IFDEF CPU64}
    NotifyFiller: Cardinal;
{$ENDIF}
    Ctl: HWND;
    Result: LRESULT;
  end;

  TWMSysCommand = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    case CmdType: WPARAM of
      0: (XPos: Smallint; YPos: Smallint;
{$IFDEF CPU64}
          PosFiller: Cardinal;
{$ENDIF}
          Result: LRESULT);
      1: (Key: Word);
  end;

  TWMScroll = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    ScrollCode: Smallint;
    Pos: Smallint;
{$IFDEF CPU64}
    ScrollFiller: Cardinal;
{$ENDIF}
    ScrollBar: HWND;
    Result: LRESULT;
  end;
  TWMHScroll = TWMScroll;
  TWMVScroll = TWMScroll;

  TWMSetCursor = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    CursorWnd: HWND;
    HitTest: Word;
    MouseMsg: Word;
{$IFDEF CPU64}
    HitFiller: Cardinal;
{$ENDIF}
    Result: LRESULT;
  end;

  TWMGetDlgCode = TWMNoParams;
  TWMClose = TWMNoParams;
  TWMDestroy = TWMNoParams;
  TWMQueryOpen = TWMNoParams;
  TWMCancelMode = TWMNoParams;
  TWMNCDestroy = TWMNoParams;

  TWMQueryEndSession = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Source: WPARAM;
    Unused: LPARAM;
    Result: LRESULT;
  end;

  TWMWindowPosMsg = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Unused: WPARAM;
    WindowPos: PWindowPos;
    Result: LRESULT;
  end;
  TWMWindowPosChanged = TWMWindowPosMsg;
  TWMWindowPosChanging = TWMWindowPosMsg;

  TWMGetMinMaxInfo = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Unused: WPARAM;
    MinMaxInfo: PMinMaxInfo;
    Result: LRESULT;
  end;

  TWMShowWindow = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Show: LongBool;
{$IFDEF CPU64}
    ShowFiller: Cardinal;
{$ENDIF}
    Status: LPARAM;
    Result: LRESULT;
  end;

  TWMSetText = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Unused: WPARAM;
    Text: PAnsiChar;
    Result: LRESULT;
  end;

  TWMGetText = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    TextMax: WPARAM;
    Text: PAnsiChar;
    Result: LRESULT;
  end;

  TWMGetTextLength = TWMNoParams;

  TWMSetFont = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Font: HFONT;
    Redraw: WordBool;
    Unused: Word;
{$IFDEF CPU64}
    RedrawFiller: Cardinal;
{$ENDIF}
    Result: LRESULT;
  end;

  TWMEnable = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Enabled: LongBool;
{$IFDEF CPU64}
    EnabledFiller: Cardinal;
{$ENDIF}
    Unused: LPARAM;
    Result: LRESULT;
  end;

  TWMCtlColor = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    ChildDC: HDC;
    ChildWnd: HWND;
    Result: LRESULT;
  end;

  TWMPaletteChanged = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    PalChg: HWND;
    Unused: LPARAM;
    Result: LRESULT;
  end;
  TWMQueryNewPalette = TWMNoParams;

  TWMContextMenu = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    hWnd: HWND;
    case Integer of
      0: (XPos: Smallint; YPos: Smallint);
      1: (Pos: TSmallPoint;
{$IFDEF CPU64}
          PosFiller: Cardinal;
{$ENDIF}
          Result: LRESULT);
  end;

  TWMDisplayChange = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    BitsPerPixel: WPARAM;
    Width: Word;
    Height: Word;
{$IFDEF CPU64}
    SizeFiller: Cardinal;
{$ENDIF}
    Result: LRESULT;
  end;

  TWMCopyData = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    From: HWND;
    CopyDataStruct: Pointer;
    Result: LRESULT;
  end;

  TWMDrawItem = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Ctl: HWND;
    DrawItemStruct: Pointer;
    Result: LRESULT;
  end;

  TWMNotify = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    IDCtrl: WPARAM;
    NMHdr: Pointer;
    Result: LRESULT;
  end;

  TWMMouseActivate = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    TopLevel: HWND;
    HitTestCode: Word;
    MouseMsg: Word;
{$IFDEF CPU64}
    HitFiller: Cardinal;
{$ENDIF}
    Result: LRESULT;
  end;

  TWMCaptureChanged = record
    Msg: Cardinal;
{$IFDEF CPU64}
    MsgFiller: Cardinal;
{$ENDIF}
    Unused: WPARAM;
    CaptureWnd: HWND;
    Result: LRESULT;
  end;

implementation

end.

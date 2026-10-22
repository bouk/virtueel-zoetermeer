unit Windows;

{ Portable subset of the Delphi 5 Windows unit (Win32 API).

  GDI, USER and KERNEL routines used by the game are emulated on top of the
  software GDI (ZMGdi) and the window manager (ZMWin). Handles are pointers
  to internal objects (64-bit clean: THandle = PtrUInt). }

{$MODE DELPHI}{$H+}{$POINTERMATH ON}

interface

uses Types;

type
  { Basic types }
  THandle = System.THandle;   { 32-bit on all FPC targets; handles are table indices }
  DWORD = LongWord;
  BOOL = LongBool;
  PBOOL = ^BOOL;
  UINT = LongWord;
  PUINT = ^UINT;
  ULONG = LongWord;
  LONG = Longint;
  PLONG = ^LONG;
  SHORT = Smallint;
  USHORT = Word;
  UCHAR = Byte;
  WCHAR = WideChar;
  PWCHAR = PWideChar;
  LPSTR = PAnsiChar;
  LPCSTR = PAnsiChar;
  LPWSTR = PWideChar;
  LPCWSTR = PWideChar;
  LPVOID = Pointer;
  LPCVOID = Pointer;
  PDWORD = ^DWORD;
  LPDWORD = PDWORD;
  PWORD = ^Word;
  LPWORD = PWORD;
  PSmallInt = ^Smallint;
  PInteger = ^Integer;
  PLongint = ^Longint;
  PSingle = ^Single;
  PDouble = ^Double;
  ATOM = Word;
  TAtom = Word;
  LANGID = Word;
  LCID = DWORD;
  HRESULT = Longint;
  TFarProc = Pointer;
  FARPROC = Pointer;
  PROC = Pointer;
  WPARAM = PtrUInt;
  LPARAM = PtrInt;
  LRESULT = PtrInt;
  TColorRef = DWORD;
  COLORREF = DWORD;
  PColorRef = ^TColorRef;

  HWND = THandle;
  HDC = THandle;
  HGDIOBJ = THandle;
  HBITMAP = THandle;
  HPALETTE = THandle;
  HFONT = THandle;
  HBRUSH = THandle;
  HPEN = THandle;
  HRGN = THandle;
  HICON = THandle;
  HCURSOR = THandle;
  HMENU = THandle;
  HINST = System.HMODULE;
  HMODULE = System.HMODULE;
  HGLOBAL = System.HGLOBAL;
  HLOCAL = THandle;
  HRSRC = System.TFPResourceHandle;
  HKEY = THandle;
  HACCEL = THandle;
  HHOOK = THandle;
  HMONITOR = THandle;
  HENHMETAFILE = THandle;
  HMETAFILE = THandle;
  PHandle = ^THandle;

  { Geometry: same types as FPC's Types/Classes so Rect/Point/Bounds interoperate }
  TPoint = Types.TPoint;
  PPoint = Types.PPoint;
  TRect = Types.TRect;
  PRect = Types.PRect;
  TSize = Types.TSize;
  PSize = Types.PSize;
  TSmallPoint = Types.TSmallPoint;
  PSmallPoint = Types.PSmallPoint;
  tagPOINT = TPoint;
  tagRECT = TRect;
  tagSIZE = TSize;

  TLargeInteger = Int64;
  PLargeInteger = ^TLargeInteger;
  LARGE_INTEGER = Int64;

  TMsg = record
    hwnd: HWND;
    message: UINT;
    wParam: WPARAM;
    lParam: LPARAM;
    time: DWORD;
    pt: TPoint;
  end;
  PMsg = ^TMsg;
  tagMSG = TMsg;

  TFNWndProc = Pointer;
  TFNTimerProc = Pointer;
  TFNWndEnumProc = Pointer;

  TWndClassA = record
    style: UINT;
    lpfnWndProc: TFNWndProc;
    cbClsExtra: Integer;
    cbWndExtra: Integer;
    hInstance: HINST;
    hIcon: HICON;
    hCursor: HCURSOR;
    hbrBackground: HBRUSH;
    lpszMenuName: PAnsiChar;
    lpszClassName: PAnsiChar;
  end;
  TWndClass = TWndClassA;
  PWndClass = ^TWndClass;

  TCreateStruct = record
    lpCreateParams: Pointer;
    hInstance: HINST;
    hMenu: HMENU;
    hwndParent: HWND;
    cy, cx, y, x: Integer;
    style: Longint;
    lpszName, lpszClass: PAnsiChar;
    dwExStyle: DWORD;
  end;
  PCreateStruct = ^TCreateStruct;

  TPaintStruct = record
    hdc: HDC;
    fErase: BOOL;
    rcPaint: TRect;
    fRestore: BOOL;
    fIncUpdate: BOOL;
    rgbReserved: array[0..31] of Byte;
  end;
  PPaintStruct = ^TPaintStruct;

  TWindowPos = record
    hwnd: HWND;
    hwndInsertAfter: HWND;
    x, y, cx, cy: Integer;
    flags: UINT;
  end;
  PWindowPos = ^TWindowPos;

  TWindowPlacement = record
    length: UINT;
    flags: UINT;
    showCmd: UINT;
    ptMinPosition: TPoint;
    ptMaxPosition: TPoint;
    rcNormalPosition: TRect;
  end;
  PWindowPlacement = ^TWindowPlacement;

  TMinMaxInfo = record
    ptReserved, ptMaxSize, ptMaxPosition, ptMinTrackSize, ptMaxTrackSize: TPoint;
  end;
  PMinMaxInfo = ^TMinMaxInfo;

  { GDI structures }
  TRGBQuad = packed record
    rgbBlue: Byte;
    rgbGreen: Byte;
    rgbRed: Byte;
    rgbReserved: Byte;
  end;
  PRGBQuad = ^TRGBQuad;
  TRGBTriple = packed record
    rgbtBlue: Byte;
    rgbtGreen: Byte;
    rgbtRed: Byte;
  end;
  PRGBTriple = ^TRGBTriple;

  TPaletteEntry = packed record
    peRed: Byte;
    peGreen: Byte;
    peBlue: Byte;
    peFlags: Byte;
  end;
  PPaletteEntry = ^TPaletteEntry;
  TPaletteEntries = array[0..255] of TPaletteEntry;

  TLogPalette = packed record
    palVersion: Word;
    palNumEntries: Word;
    palPalEntry: array[0..0] of TPaletteEntry;
  end;
  PLogPalette = ^TLogPalette;
  TMaxLogPalette = packed record
    palVersion: Word;
    palNumEntries: Word;
    palPalEntry: array[0..255] of TPaletteEntry;
  end;
  PMaxLogPalette = ^TMaxLogPalette;

  TBitmapFileHeader = packed record
    bfType: Word;
    bfSize: DWORD;
    bfReserved1: Word;
    bfReserved2: Word;
    bfOffBits: DWORD;
  end;
  PBitmapFileHeader = ^TBitmapFileHeader;

  TBitmapInfoHeader = packed record
    biSize: DWORD;
    biWidth: Longint;
    biHeight: Longint;
    biPlanes: Word;
    biBitCount: Word;
    biCompression: DWORD;
    biSizeImage: DWORD;
    biXPelsPerMeter: Longint;
    biYPelsPerMeter: Longint;
    biClrUsed: DWORD;
    biClrImportant: DWORD;
  end;
  PBitmapInfoHeader = ^TBitmapInfoHeader;

  TBitmapCoreHeader = packed record
    bcSize: DWORD;
    bcWidth: Word;
    bcHeight: Word;
    bcPlanes: Word;
    bcBitCount: Word;
  end;
  PBitmapCoreHeader = ^TBitmapCoreHeader;

  TBitmapInfo = packed record
    bmiHeader: TBitmapInfoHeader;
    bmiColors: array[0..0] of TRGBQuad;
  end;
  PBitmapInfo = ^TBitmapInfo;

  TBitmap = record   { Windows.TBitmap (BITMAP), as returned by GetObject }
    bmType: Longint;
    bmWidth: Longint;
    bmHeight: Longint;
    bmWidthBytes: Longint;
    bmPlanes: Word;
    bmBitsPixel: Word;
    bmBits: Pointer;
  end;
  PBitmap = ^TBitmap;

  TDIBSection = record
    dsBm: TBitmap;
    dsBmih: TBitmapInfoHeader;
    dsBitfields: array[0..2] of DWORD;
    dshSection: THandle;
    dsOffset: DWORD;
  end;
  PDIBSection = ^TDIBSection;

  TLogBrush = record
    lbStyle: UINT;
    lbColor: COLORREF;
    lbHatch: PtrInt;
  end;
  PLogBrush = ^TLogBrush;

  TLogPen = record
    lopnStyle: UINT;
    lopnWidth: TPoint;
    lopnColor: COLORREF;
  end;
  PLogPen = ^TLogPen;

  TLogFontA = record
    lfHeight: Longint;
    lfWidth: Longint;
    lfEscapement: Longint;
    lfOrientation: Longint;
    lfWeight: Longint;
    lfItalic: Byte;
    lfUnderline: Byte;
    lfStrikeOut: Byte;
    lfCharSet: Byte;
    lfOutPrecision: Byte;
    lfClipPrecision: Byte;
    lfQuality: Byte;
    lfPitchAndFamily: Byte;
    lfFaceName: array[0..31] of AnsiChar;
  end;
  TLogFont = TLogFontA;
  PLogFont = ^TLogFont;

  TTextMetricA = record
    tmHeight: Longint;
    tmAscent: Longint;
    tmDescent: Longint;
    tmInternalLeading: Longint;
    tmExternalLeading: Longint;
    tmAveCharWidth: Longint;
    tmMaxCharWidth: Longint;
    tmWeight: Longint;
    tmOverhang: Longint;
    tmDigitizedAspectX: Longint;
    tmDigitizedAspectY: Longint;
    tmFirstChar: AnsiChar;
    tmLastChar: AnsiChar;
    tmDefaultChar: AnsiChar;
    tmBreakChar: AnsiChar;
    tmItalic: Byte;
    tmUnderlined: Byte;
    tmStruckOut: Byte;
    tmPitchAndFamily: Byte;
    tmCharSet: Byte;
  end;
  TTextMetric = TTextMetricA;
  PTextMetric = ^TTextMetric;

  TIconInfo = record
    fIcon: BOOL;
    xHotspot: DWORD;
    yHotspot: DWORD;
    hbmMask: HBITMAP;
    hbmColor: HBITMAP;
  end;
  PIconInfo = ^TIconInfo;

  TDeviceModeA = record
    dmDeviceName: array[0..31] of AnsiChar;
    dmSpecVersion: Word;
    dmDriverVersion: Word;
    dmSize: Word;
    dmDriverExtra: Word;
    dmFields: DWORD;
    dmOrientation: SHORT;
    dmPaperSize: SHORT;
    dmPaperLength: SHORT;
    dmPaperWidth: SHORT;
    dmScale: SHORT;
    dmCopies: SHORT;
    dmDefaultSource: SHORT;
    dmPrintQuality: SHORT;
    dmColor: SHORT;
    dmDuplex: SHORT;
    dmYResolution: SHORT;
    dmTTOption: SHORT;
    dmCollate: SHORT;
    dmFormName: array[0..31] of AnsiChar;
    dmLogPixels: Word;
    dmBitsPerPel: DWORD;
    dmPelsWidth: DWORD;
    dmPelsHeight: DWORD;
    dmDisplayFlags: DWORD;
    dmDisplayFrequency: DWORD;
    dmICMMethod: DWORD;
    dmICMIntent: DWORD;
    dmMediaType: DWORD;
    dmDitherType: DWORD;
    dmICCManufacturer: DWORD;
    dmICCModel: DWORD;
    dmPanningWidth: DWORD;
    dmPanningHeight: DWORD;
  end;
  TDeviceMode = TDeviceModeA;
  PDeviceMode = ^TDeviceMode;
  TDevMode = TDeviceMode;
  PDevMode = PDeviceMode;
  _devicemodeA = TDeviceModeA;

  TOSVersionInfoA = record
    dwOSVersionInfoSize: DWORD;
    dwMajorVersion: DWORD;
    dwMinorVersion: DWORD;
    dwBuildNumber: DWORD;
    dwPlatformId: DWORD;
    szCSDVersion: array[0..127] of AnsiChar;
  end;
  TOSVersionInfo = TOSVersionInfoA;
  POSVersionInfo = ^TOSVersionInfo;
  _OSVERSIONINFOA = TOSVersionInfoA;

  TSystemTime = record
    wYear, wMonth, wDayOfWeek, wDay, wHour, wMinute, wSecond, wMilliseconds: Word;
  end;
  PSystemTime = ^TSystemTime;

  TFileTime = record
    dwLowDateTime: DWORD;
    dwHighDateTime: DWORD;
  end;
  PFileTime = ^TFileTime;

  TSecurityAttributes = record
    nLength: DWORD;
    lpSecurityDescriptor: Pointer;
    bInheritHandle: BOOL;
  end;
  PSecurityAttributes = ^TSecurityAttributes;

  TRTLCriticalSection = record
    Data: array[0..5] of PtrInt;
  end;
  TCriticalSection = TRTLCriticalSection;

  TMemoryStatus = record
    dwLength: DWORD;
    dwMemoryLoad: DWORD;
    dwTotalPhys: PtrUInt;
    dwAvailPhys: PtrUInt;
    dwTotalPageFile: PtrUInt;
    dwAvailPageFile: PtrUInt;
    dwTotalVirtual: PtrUInt;
    dwAvailVirtual: PtrUInt;
  end;

  UINT_PTR = PtrUInt;
  TTimerProc = procedure(hwnd: HWND; uMsg: UINT; idEvent: UINT_PTR; dwTime: DWORD); stdcall;
  TWndProcFunc = function(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;

const
  MAX_PATH = 260;
  HINSTANCE_ERROR = 32;
  INFINITE = DWORD($FFFFFFFF);
  NULL = 0;

  { Errors / HRESULT }
  S_OK = 0;
  S_FALSE = 1;
  E_FAIL = HRESULT($80004005);
  E_NOTIMPL = HRESULT($80004001);
  E_NOINTERFACE = HRESULT($80004002);
  E_OUTOFMEMORY = HRESULT($8007000E);
  E_INVALIDARG = HRESULT($80070057);
  ERROR_SUCCESS = 0;
  NO_ERROR = 0;
  ERROR_FILE_NOT_FOUND = 2;
  ERROR_INVALID_HANDLE = 6;

  { Virtual keys }
  VK_LBUTTON = 1; VK_RBUTTON = 2; VK_CANCEL = 3; VK_MBUTTON = 4;
  VK_BACK = 8; VK_TAB = 9; VK_CLEAR = 12; VK_RETURN = 13;
  VK_SHIFT = $10; VK_CONTROL = $11; VK_MENU = $12; VK_PAUSE = $13; VK_CAPITAL = $14;
  VK_ESCAPE = $1B; VK_SPACE = $20; VK_PRIOR = $21; VK_NEXT = $22; VK_END = $23;
  VK_HOME = $24; VK_LEFT = $25; VK_UP = $26; VK_RIGHT = $27; VK_DOWN = $28;
  VK_SELECT = $29; VK_PRINT = $2A; VK_EXECUTE = $2B; VK_SNAPSHOT = $2C;
  VK_INSERT = $2D; VK_DELETE = $2E; VK_HELP = $2F;
  VK_LWIN = $5B; VK_RWIN = $5C; VK_APPS = $5D;
  VK_NUMPAD0 = $60; VK_NUMPAD1 = $61; VK_NUMPAD2 = $62; VK_NUMPAD3 = $63; VK_NUMPAD4 = $64;
  VK_NUMPAD5 = $65; VK_NUMPAD6 = $66; VK_NUMPAD7 = $67; VK_NUMPAD8 = $68; VK_NUMPAD9 = $69;
  VK_MULTIPLY = $6A; VK_ADD = $6B; VK_SEPARATOR = $6C; VK_SUBTRACT = $6D;
  VK_DECIMAL = $6E; VK_DIVIDE = $6F;
  VK_F1 = $70; VK_F2 = $71; VK_F3 = $72; VK_F4 = $73; VK_F5 = $74; VK_F6 = $75;
  VK_F7 = $76; VK_F8 = $77; VK_F9 = $78; VK_F10 = $79; VK_F11 = $7A; VK_F12 = $7B;
  VK_NUMLOCK = $90; VK_SCROLL = $91;
  VK_LSHIFT = $A0; VK_RSHIFT = $A1; VK_LCONTROL = $A2; VK_RCONTROL = $A3;
  VK_LMENU = $A4; VK_RMENU = $A5;

  { Window styles }
  WS_OVERLAPPED = 0;
  WS_POPUP = DWORD($80000000);
  WS_CHILD = $40000000;
  WS_MINIMIZE = $20000000;
  WS_VISIBLE = $10000000;
  WS_DISABLED = $8000000;
  WS_CLIPSIBLINGS = $4000000;
  WS_CLIPCHILDREN = $2000000;
  WS_MAXIMIZE = $1000000;
  WS_CAPTION = $C00000;
  WS_BORDER = $800000;
  WS_DLGFRAME = $400000;
  WS_VSCROLL = $200000;
  WS_HSCROLL = $100000;
  WS_SYSMENU = $80000;
  WS_THICKFRAME = $40000;
  WS_GROUP = $20000;
  WS_TABSTOP = $10000;
  WS_MINIMIZEBOX = $20000;
  WS_MAXIMIZEBOX = $10000;
  WS_SIZEBOX = WS_THICKFRAME;
  WS_OVERLAPPEDWINDOW = WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME or WS_MINIMIZEBOX or WS_MAXIMIZEBOX;
  WS_POPUPWINDOW = WS_POPUP or WS_BORDER or WS_SYSMENU;
  WS_EX_DLGMODALFRAME = 1;
  WS_EX_TOPMOST = 8;
  WS_EX_TRANSPARENT = $20;
  WS_EX_TOOLWINDOW = $80;
  WS_EX_WINDOWEDGE = $100;
  WS_EX_CLIENTEDGE = $200;
  WS_EX_CONTROLPARENT = $10000;
  WS_EX_STATICEDGE = $20000;
  WS_EX_APPWINDOW = $40000;
  CS_VREDRAW = 1; CS_HREDRAW = 2; CS_DBLCLKS = 8; CS_OWNDC = $20; CS_CLASSDC = $40;
  CS_PARENTDC = $80; CS_SAVEBITS = $800; CS_BYTEALIGNCLIENT = $1000;
  ES_LEFT = 0; ES_CENTER = 1; ES_RIGHT = 2; ES_MULTILINE = 4; ES_UPPERCASE = 8;
  ES_LOWERCASE = $10; ES_PASSWORD = $20; ES_AUTOVSCROLL = $40; ES_AUTOHSCROLL = $80;
  ES_NOHIDESEL = $100; ES_OEMCONVERT = $400; ES_READONLY = $800; ES_WANTRETURN = $1000;
  BS_PUSHBUTTON = 0; BS_DEFPUSHBUTTON = 1; BS_CHECKBOX = 2; BS_AUTOCHECKBOX = 3;
  BS_RADIOBUTTON = 4; BS_3STATE = 5; BS_AUTO3STATE = 6; BS_GROUPBOX = 7;
  BS_AUTORADIOBUTTON = 9; BS_OWNERDRAW = $B; BS_LEFTTEXT = $20; BS_MULTILINE = $2000;

  GWL_WNDPROC = -4; GWL_HINSTANCE = -6; GWL_HWNDPARENT = -8; GWL_STYLE = -16;
  GWL_EXSTYLE = -20; GWL_USERDATA = -21; GWL_ID = -12;

  { ShowWindow }
  SW_HIDE = 0; SW_SHOWNORMAL = 1; SW_NORMAL = 1; SW_SHOWMINIMIZED = 2; SW_SHOWMAXIMIZED = 3;
  SW_MAXIMIZE = 3; SW_SHOWNOACTIVATE = 4; SW_SHOW = 5; SW_MINIMIZE = 6;
  SW_SHOWMINNOACTIVE = 7; SW_SHOWNA = 8; SW_RESTORE = 9; SW_SHOWDEFAULT = 10;

  { SetWindowPos }
  SWP_NOSIZE = 1; SWP_NOMOVE = 2; SWP_NOZORDER = 4; SWP_NOREDRAW = 8; SWP_NOACTIVATE = $10;
  SWP_FRAMECHANGED = $20; SWP_SHOWWINDOW = $40; SWP_HIDEWINDOW = $80; SWP_NOCOPYBITS = $100;
  SWP_NOOWNERZORDER = $200; SWP_NOSENDCHANGING = $400;
  HWND_TOP = 0; HWND_BOTTOM = 1; HWND_TOPMOST = HWND(-1); HWND_NOTOPMOST = HWND(-2);
  HWND_DESKTOP = 0; HWND_BROADCAST = $FFFF;

  { PeekMessage }
  PM_NOREMOVE = 0; PM_REMOVE = 1; PM_NOYIELD = 2;

  { MessageBox }
  MB_OK = 0; MB_OKCANCEL = 1; MB_ABORTRETRYIGNORE = 2; MB_YESNOCANCEL = 3; MB_YESNO = 4;
  MB_RETRYCANCEL = 5; MB_ICONHAND = $10; MB_ICONQUESTION = $20; MB_ICONEXCLAMATION = $30;
  MB_ICONASTERISK = $40; MB_ICONWARNING = MB_ICONEXCLAMATION; MB_ICONERROR = MB_ICONHAND;
  MB_ICONSTOP = MB_ICONHAND; MB_ICONINFORMATION = MB_ICONASTERISK;
  MB_DEFBUTTON1 = 0; MB_DEFBUTTON2 = $100; MB_DEFBUTTON3 = $200; MB_APPLMODAL = 0;
  MB_SYSTEMMODAL = $1000; MB_TASKMODAL = $2000; MB_SETFOREGROUND = $10000; MB_TOPMOST = $40000;
  IDOK = 1; IDCANCEL = 2; IDABORT = 3; IDRETRY = 4; IDIGNORE = 5; IDYES = 6; IDNO = 7;
  IDCLOSE = 8; IDHELP = 9;

  { MessageBeep }
  MB_ICONMASK = $F0;

  { Mouse key states }
  MK_LBUTTON = 1; MK_RBUTTON = 2; MK_SHIFT = 4; MK_CONTROL = 8; MK_MBUTTON = $10;

  { Hit test }
  HTERROR = -2; HTTRANSPARENT = -1; HTNOWHERE = 0; HTCLIENT = 1; HTCAPTION = 2;
  HTSYSMENU = 3; HTSIZE = 4; HTMENU = 5; HTHSCROLL = 6; HTVSCROLL = 7; HTMINBUTTON = 8;
  HTMAXBUTTON = 9; HTLEFT = 10; HTRIGHT = 11; HTTOP = 12; HTTOPLEFT = 13; HTTOPRIGHT = 14;
  HTBOTTOM = 15; HTBOTTOMLEFT = 16; HTBOTTOMRIGHT = 17; HTBORDER = 18; HTCLOSE = 20;

  { System commands }
  SC_SIZE = $F000; SC_MOVE = $F010; SC_MINIMIZE = $F020; SC_MAXIMIZE = $F030;
  SC_CLOSE = $F060; SC_RESTORE = $F120; SC_KEYMENU = $F100;

  { Dialog codes }
  DLGC_WANTARROWS = 1; DLGC_WANTTAB = 2; DLGC_WANTALLKEYS = 4; DLGC_WANTMESSAGE = 4;
  DLGC_HASSETSEL = 8; DLGC_DEFPUSHBUTTON = $10; DLGC_UNDEFPUSHBUTTON = $20;
  DLGC_RADIOBUTTON = $40; DLGC_WANTCHARS = $80; DLGC_STATIC = $100; DLGC_BUTTON = $2000;

  { Cursors (MAKEINTRESOURCE) }
  IDC_ARROW = PAnsiChar(32512);
  IDC_IBEAM = PAnsiChar(32513);
  IDC_WAIT = PAnsiChar(32514);
  IDC_CROSS = PAnsiChar(32515);
  IDC_UPARROW = PAnsiChar(32516);
  IDC_SIZE = PAnsiChar(32640);
  IDC_ICON = PAnsiChar(32641);
  IDC_SIZENWSE = PAnsiChar(32642);
  IDC_SIZENESW = PAnsiChar(32643);
  IDC_SIZEWE = PAnsiChar(32644);
  IDC_SIZENS = PAnsiChar(32645);
  IDC_SIZEALL = PAnsiChar(32646);
  IDC_NO = PAnsiChar(32648);
  IDC_HAND = PAnsiChar(32649);
  IDC_APPSTARTING = PAnsiChar(32650);
  IDC_HELP = PAnsiChar(32651);
  IDI_APPLICATION = PAnsiChar(32512);
  IDI_HAND = PAnsiChar(32513);
  IDI_QUESTION = PAnsiChar(32514);
  IDI_EXCLAMATION = PAnsiChar(32515);
  IDI_ASTERISK = PAnsiChar(32516);
  IDI_WINLOGO = PAnsiChar(32517);
  IDI_WARNING = IDI_EXCLAMATION;
  IDI_ERROR = IDI_HAND;
  IDI_INFORMATION = IDI_ASTERISK;

  { Resource types }
  RT_CURSOR = PAnsiChar(1);
  RT_BITMAP = PAnsiChar(2);
  RT_ICON = PAnsiChar(3);
  RT_MENU = PAnsiChar(4);
  RT_DIALOG = PAnsiChar(5);
  RT_STRING = PAnsiChar(6);
  RT_FONTDIR = PAnsiChar(7);
  RT_FONT = PAnsiChar(8);
  RT_ACCELERATOR = PAnsiChar(9);
  RT_RCDATA = PAnsiChar(10);
  RT_MESSAGETABLE = PAnsiChar(11);
  RT_GROUP_CURSOR = PAnsiChar(12);
  RT_GROUP_ICON = PAnsiChar(14);
  RT_VERSION = PAnsiChar(16);

  { GetSystemMetrics }
  SM_CXSCREEN = 0; SM_CYSCREEN = 1; SM_CXVSCROLL = 2; SM_CYHSCROLL = 3; SM_CYCAPTION = 4;
  SM_CXBORDER = 5; SM_CYBORDER = 6; SM_CXDLGFRAME = 7; SM_CYDLGFRAME = 8;
  SM_CYVTHUMB = 9; SM_CXHTHUMB = 10; SM_CXICON = 11; SM_CYICON = 12; SM_CXCURSOR = 13;
  SM_CYCURSOR = 14; SM_CYMENU = 15; SM_CXFULLSCREEN = 16; SM_CYFULLSCREEN = 17;
  SM_CYVSCROLL = 20; SM_CXHSCROLL = 21; SM_CXFRAME = 32; SM_CYFRAME = 33;
  SM_CXSMICON = 49; SM_CYSMICON = 50; SM_CXEDGE = 45; SM_CYEDGE = 46;
  SM_CXFIXEDFRAME = SM_CXDLGFRAME; SM_CYFIXEDFRAME = SM_CYDLGFRAME;
  SM_CXSIZEFRAME = SM_CXFRAME; SM_CYSIZEFRAME = SM_CYFRAME;
  SM_CXDOUBLECLK = 36; SM_CYDOUBLECLK = 37; SM_SWAPBUTTON = 23; SM_MOUSEPRESENT = 19;
  SM_CXMAXIMIZED = 61; SM_CYMAXIMIZED = 62; SM_CMONITORS = 80;

  { System colors }
  COLOR_SCROLLBAR = 0; COLOR_BACKGROUND = 1; COLOR_ACTIVECAPTION = 2;
  COLOR_INACTIVECAPTION = 3; COLOR_MENU = 4; COLOR_WINDOW = 5; COLOR_WINDOWFRAME = 6;
  COLOR_MENUTEXT = 7; COLOR_WINDOWTEXT = 8; COLOR_CAPTIONTEXT = 9; COLOR_ACTIVEBORDER = 10;
  COLOR_INACTIVEBORDER = 11; COLOR_APPWORKSPACE = 12; COLOR_HIGHLIGHT = 13;
  COLOR_HIGHLIGHTTEXT = 14; COLOR_BTNFACE = 15; COLOR_BTNSHADOW = $10; COLOR_GRAYTEXT = 17;
  COLOR_BTNTEXT = 18; COLOR_INACTIVECAPTIONTEXT = 19; COLOR_BTNHIGHLIGHT = 20;
  COLOR_3DDKSHADOW = 21; COLOR_3DLIGHT = 22; COLOR_INFOTEXT = 23; COLOR_INFOBK = 24;
  COLOR_HOTLIGHT = 26; COLOR_GRADIENTACTIVECAPTION = 27; COLOR_GRADIENTINACTIVECAPTION = 28;
  COLOR_DESKTOP = COLOR_BACKGROUND; COLOR_3DFACE = COLOR_BTNFACE;
  COLOR_3DSHADOW = COLOR_BTNSHADOW; COLOR_3DHIGHLIGHT = COLOR_BTNHIGHLIGHT;
  COLOR_3DHILIGHT = COLOR_BTNHIGHLIGHT; COLOR_BTNHILIGHT = COLOR_BTNHIGHLIGHT;

  { GetDeviceCaps }
  DRIVERVERSION = 0; TECHNOLOGY = 2; HORZSIZE = 4; VERTSIZE = 6; HORZRES = 8; VERTRES = 10;
  BITSPIXEL = 12; PLANES = 14; NUMBRUSHES = 16; NUMPENS = 18; NUMMARKERS = 20; NUMFONTS = 22;
  NUMCOLORS = 24; PDEVICESIZE = 26; CURVECAPS = 28; LINECAPS = 30; POLYGONALCAPS = 32;
  TEXTCAPS = 34; CLIPCAPS = 36; RASTERCAPS = 38; ASPECTX = 40; ASPECTY = 42; ASPECTXY = 44;
  LOGPIXELSX = 88; LOGPIXELSY = 90; SIZEPALETTE = 104; NUMRESERVED = 106; COLORRES = 108;
  VREFRESH = 116; DESKTOPVERTRES = 117; DESKTOPHORZRES = 118;
  RC_BITBLT = 1; RC_BANDING = 2; RC_SCALING = 4; RC_BITMAP64 = 8; RC_GDI20_OUTPUT = $10;
  RC_DI_BITMAP = $80; RC_PALETTE = $100; RC_DIBTODEV = $200; RC_STRETCHBLT = $800;
  RC_FLOODFILL = $1000; RC_STRETCHDIB = $2000;

  { Raster operations }
  SRCCOPY = $00CC0020;
  SRCPAINT = $00EE0086;
  SRCAND = $008800C6;
  SRCINVERT = $00660046;
  SRCERASE = $00440328;
  NOTSRCCOPY = $00330008;
  NOTSRCERASE = $001100A6;
  MERGECOPY = $00C000CA;
  MERGEPAINT = $00BB0226;
  PATCOPY = $00F00021;
  PATPAINT = $00FB0A09;
  PATINVERT = $005A0049;
  DSTINVERT = $00550009;
  BLACKNESS = $00000042;
  WHITENESS = $00FF0062;
  R2_BLACK = 1; R2_NOTMERGEPEN = 2; R2_MASKNOTPEN = 3; R2_NOTCOPYPEN = 4; R2_MASKPENNOT = 5;
  R2_NOT = 6; R2_XORPEN = 7; R2_NOTMASKPEN = 8; R2_MASKPEN = 9; R2_NOTXORPEN = 10; R2_NOP = 11;
  R2_MERGENOTPEN = 12; R2_COPYPEN = 13; R2_MERGEPENNOT = 14; R2_MERGEPEN = 15; R2_WHITE = 16;

  { Stretch modes }
  BLACKONWHITE = 1; WHITEONBLACK = 2; COLORONCOLOR = 3; HALFTONE = 4;
  STRETCH_ANDSCANS = 1; STRETCH_ORSCANS = 2; STRETCH_DELETESCANS = 3; STRETCH_HALFTONE = 4;

  { Background modes }
  TRANSPARENT = 1; OPAQUE = 2;

  { Stock objects }
  WHITE_BRUSH = 0; LTGRAY_BRUSH = 1; GRAY_BRUSH = 2; DKGRAY_BRUSH = 3; BLACK_BRUSH = 4;
  NULL_BRUSH = 5; HOLLOW_BRUSH = NULL_BRUSH; WHITE_PEN = 6; BLACK_PEN = 7; NULL_PEN = 8;
  OEM_FIXED_FONT = 10; ANSI_FIXED_FONT = 11; ANSI_VAR_FONT = 12; SYSTEM_FONT = 13;
  DEVICE_DEFAULT_FONT = 14; DEFAULT_PALETTE = 15; SYSTEM_FIXED_FONT = $10; DEFAULT_GUI_FONT = 17;

  { Brushes / pens }
  BS_SOLID = 0; BS_NULL = 1; BS_HOLLOW = BS_NULL; BS_HATCHED = 2; BS_PATTERN = 3;
  BS_DIBPATTERN = 5;
  HS_HORIZONTAL = 0; HS_VERTICAL = 1; HS_FDIAGONAL = 2; HS_BDIAGONAL = 3; HS_CROSS = 4;
  HS_DIAGCROSS = 5;
  PS_SOLID = 0; PS_DASH = 1; PS_DOT = 2; PS_DASHDOT = 3; PS_DASHDOTDOT = 4; PS_NULL = 5;
  PS_INSIDEFRAME = 6;

  { Palettes / DIBs }
  PC_RESERVED = 1; PC_EXPLICIT = 2; PC_NOCOLLAPSE = 4;
  DIB_RGB_COLORS = 0; DIB_PAL_COLORS = 1;
  BI_RGB = 0; BI_RLE8 = 1; BI_RLE4 = 2; BI_BITFIELDS = 3;
  CLR_INVALID = DWORD($FFFFFFFF);
  CLR_NONE = DWORD($FFFFFFFF);
  CLR_DEFAULT = DWORD($FF000000);
  GDI_ERROR = DWORD($FFFFFFFF);
  HGDI_ERROR = THandle(-1);
  OBJ_PEN = 1; OBJ_BRUSH = 2; OBJ_DC = 3; OBJ_PAL = 5; OBJ_FONT = 6; OBJ_BITMAP = 7;
  OBJ_REGION = 8; OBJ_MEMDC = 10;

  { Regions }
  ERROR = 0; NULLREGION = 1; SIMPLEREGION = 2; COMPLEXREGION = 3;
  RGN_AND = 1; RGN_OR = 2; RGN_XOR = 3; RGN_DIFF = 4; RGN_COPY = 5;

  { Fonts }
  FW_DONTCARE = 0; FW_THIN = 100; FW_EXTRALIGHT = 200; FW_LIGHT = 300; FW_NORMAL = 400;
  FW_MEDIUM = 500; FW_SEMIBOLD = 600; FW_BOLD = 700; FW_EXTRABOLD = 800; FW_HEAVY = 900;
  ANSI_CHARSET = 0; DEFAULT_CHARSET = 1; SYMBOL_CHARSET = 2; SHIFTJIS_CHARSET = $80;
  HANGEUL_CHARSET = 129; GB2312_CHARSET = 134; CHINESEBIG5_CHARSET = 136; OEM_CHARSET = 255;
  JOHAB_CHARSET = 130; HEBREW_CHARSET = 177; ARABIC_CHARSET = 178; GREEK_CHARSET = 161;
  TURKISH_CHARSET = 162; VIETNAMESE_CHARSET = 163; THAI_CHARSET = 222;
  EASTEUROPE_CHARSET = 238; RUSSIAN_CHARSET = 204; MAC_CHARSET = 77; BALTIC_CHARSET = 186;
  OUT_DEFAULT_PRECIS = 0; CLIP_DEFAULT_PRECIS = 0; DEFAULT_QUALITY = 0;
  DRAFT_QUALITY = 1; PROOF_QUALITY = 2; NONANTIALIASED_QUALITY = 3; ANTIALIASED_QUALITY = 4;
  DEFAULT_PITCH = 0; FIXED_PITCH = 1; VARIABLE_PITCH = 2;
  FF_DONTCARE = 0; FF_ROMAN = $10; FF_SWISS = $20; FF_MODERN = $30; FF_SCRIPT = $40;
  FF_DECORATIVE = $50;

  { Text alignment / DrawText }
  TA_NOUPDATECP = 0; TA_UPDATECP = 1; TA_LEFT = 0; TA_RIGHT = 2; TA_CENTER = 6;
  TA_TOP = 0; TA_BOTTOM = 8; TA_BASELINE = 24;
  DT_TOP = 0; DT_LEFT = 0; DT_CENTER = 1; DT_RIGHT = 2; DT_VCENTER = 4; DT_BOTTOM = 8;
  DT_WORDBREAK = $10; DT_SINGLELINE = $20; DT_EXPANDTABS = $40; DT_TABSTOP = $80;
  DT_NOCLIP = $100; DT_EXTERNALLEADING = $200; DT_CALCRECT = $400; DT_NOPREFIX = $800;
  DT_INTERNAL = $1000; DT_EDITCONTROL = $2000; DT_PATH_ELLIPSIS = $4000;
  DT_END_ELLIPSIS = $8000; DT_MODIFYSTRING = $10000; DT_RTLREADING = $20000;
  DT_WORD_ELLIPSIS = $40000;
  ETO_OPAQUE = 2; ETO_CLIPPED = 4;

  { DrawEdge / DrawFrameControl }
  BDR_RAISEDOUTER = 1; BDR_SUNKENOUTER = 2; BDR_RAISEDINNER = 4; BDR_SUNKENINNER = 8;
  BDR_OUTER = 3; BDR_INNER = 12;
  EDGE_RAISED = BDR_RAISEDOUTER or BDR_RAISEDINNER;
  EDGE_SUNKEN = BDR_SUNKENOUTER or BDR_SUNKENINNER;
  EDGE_ETCHED = BDR_SUNKENOUTER or BDR_RAISEDINNER;
  EDGE_BUMP = BDR_RAISEDOUTER or BDR_SUNKENINNER;
  BF_LEFT = 1; BF_TOP = 2; BF_RIGHT = 4; BF_BOTTOM = 8;
  BF_TOPLEFT = BF_TOP or BF_LEFT; BF_BOTTOMRIGHT = BF_BOTTOM or BF_RIGHT;
  BF_RECT = BF_LEFT or BF_TOP or BF_RIGHT or BF_BOTTOM;
  BF_MIDDLE = $800; BF_SOFT = $1000; BF_ADJUST = $2000; BF_FLAT = $4000; BF_MONO = $8000;
  DFC_CAPTION = 1; DFC_MENU = 2; DFC_SCROLL = 3; DFC_BUTTON = 4;
  DFCS_BUTTONCHECK = 0; DFCS_BUTTONRADIO = 4; DFCS_BUTTONPUSH = $10;
  DFCS_SCROLLUP = 0; DFCS_SCROLLDOWN = 1; DFCS_SCROLLLEFT = 2; DFCS_SCROLLRIGHT = 3;
  DFCS_INACTIVE = $100; DFCS_PUSHED = $200; DFCS_CHECKED = $400; DFCS_FLAT = $4000;
  DFCS_MONO = $8000;

  { Scroll bars }
  SB_HORZ = 0; SB_VERT = 1; SB_CTL = 2; SB_BOTH = 3;
  SB_LINEUP = 0; SB_LINELEFT = 0; SB_LINEDOWN = 1; SB_LINERIGHT = 1; SB_PAGEUP = 2;
  SB_PAGELEFT = 2; SB_PAGEDOWN = 3; SB_PAGERIGHT = 3; SB_THUMBPOSITION = 4;
  SB_THUMBTRACK = 5; SB_TOP = 6; SB_LEFT = 6; SB_BOTTOM = 7; SB_RIGHT = 7; SB_ENDSCROLL = 8;

  { ChangeDisplaySettings }
  DM_BITSPERPEL = $40000; DM_PELSWIDTH = $80000; DM_PELSHEIGHT = $100000;
  DM_DISPLAYFLAGS = $200000; DM_DISPLAYFREQUENCY = $400000;
  CDS_UPDATEREGISTRY = 1; CDS_TEST = 2; CDS_FULLSCREEN = 4;
  DISP_CHANGE_SUCCESSFUL = 0; DISP_CHANGE_RESTART = 1; DISP_CHANGE_FAILED = -1;
  DISP_CHANGE_BADMODE = -2;
  DISP_CHANGE_NOTUPDATED = -3;
  DISP_CHANGE_BADFLAGS = -4;
  DISP_CHANGE_BADPARAM = -5;
  ENUM_CURRENT_SETTINGS = DWORD(-1);
  ENUM_REGISTRY_SETTINGS = DWORD(-2);

  { Version info }
  VER_PLATFORM_WIN32s = 0; VER_PLATFORM_WIN32_WINDOWS = 1; VER_PLATFORM_WIN32_NT = 2;

  { Memory }
  GMEM_FIXED = 0; GMEM_MOVEABLE = 2; GMEM_ZEROINIT = $40; GHND = GMEM_MOVEABLE or GMEM_ZEROINIT;
  GPTR = GMEM_FIXED or GMEM_ZEROINIT;

  { Files }
  GENERIC_READ = DWORD($80000000); GENERIC_WRITE = $40000000;
  FILE_SHARE_READ = 1; FILE_SHARE_WRITE = 2;
  CREATE_NEW = 1; CREATE_ALWAYS = 2; OPEN_EXISTING = 3; OPEN_ALWAYS = 4;
  FILE_ATTRIBUTE_READONLY = 1; FILE_ATTRIBUTE_HIDDEN = 2; FILE_ATTRIBUTE_SYSTEM = 4;
  FILE_ATTRIBUTE_DIRECTORY = $10; FILE_ATTRIBUTE_ARCHIVE = $20; FILE_ATTRIBUTE_NORMAL = $80;
  INVALID_HANDLE_VALUE = THandle(-1);
  DRIVE_UNKNOWN = 0; DRIVE_NO_ROOT_DIR = 1; DRIVE_REMOVABLE = 2; DRIVE_FIXED = 3;
  DRIVE_REMOTE = 4; DRIVE_CDROM = 5; DRIVE_RAMDISK = 6;
  SEM_FAILCRITICALERRORS = 1; SEM_NOOPENFILEERRORBOX = $8000;

  { Window messages that some code takes from Windows instead of Messages }
  WM_USER = $0400;

  { Locale }
  LOCALE_USER_DEFAULT = $400;
  LOCALE_SYSTEM_DEFAULT = $800;

  { Clipboard formats }
  CF_TEXT = 1; CF_BITMAP = 2; CF_METAFILEPICT = 3; CF_DIB = 8; CF_PALETTE = 9;

  { Image types }
  IMAGE_BITMAP = 0; IMAGE_ICON = 1; IMAGE_CURSOR = 2;
  LR_DEFAULTCOLOR = 0; LR_LOADFROMFILE = $10; LR_CREATEDIBSECTION = $2000;

{ Macros }
function RGB(r, g, b: Byte): COLORREF;
function PaletteRGB(r, g, b: Byte): COLORREF;
function PaletteIndex(i: Word): COLORREF;
function GetRValue(rgb: DWORD): Byte;
function GetGValue(rgb: DWORD): Byte;
function GetBValue(rgb: DWORD): Byte;
function MakeLong(a, b: Word): Longint;
function MakeWord(a, b: Byte): Word;
function HiWord(l: DWORD): Word;
function LoWord(l: DWORD): Word;
function HiByte(w: Word): Byte;
function LoByte(w: Word): Byte;
function MakeWParam(l, h: Word): WPARAM;
function MakeLParam(l, h: Word): LPARAM;
function MakeLResult(l, h: Word): LRESULT;
function MakeIntResource(id: PtrUInt): PAnsiChar;
function MakeROP4(fore, back: DWORD): DWORD;

{ Rectangles }
function IntersectRect(var lprcDst: TRect; const lprcSrc1, lprcSrc2: TRect): BOOL;
function UnionRect(var lprcDst: TRect; const lprcSrc1, lprcSrc2: TRect): BOOL;
function SubtractRect(var lprcDst: TRect; const lprcSrc1, lprcSrc2: TRect): BOOL;
function OffsetRect(var lprc: TRect; dx, dy: Integer): BOOL;
function InflateRect(var lprc: TRect; dx, dy: Integer): BOOL;
function PtInRect(const lprc: TRect; pt: TPoint): BOOL;
function IsRectEmpty(const lprc: TRect): BOOL;
function EqualRect(const lprc1, lprc2: TRect): BOOL;
function SetRect(var lprc: TRect; xLeft, yTop, xRight, yBottom: Integer): BOOL;
function SetRectEmpty(var lprc: TRect): BOOL;
function CopyRect(var lprcDst: TRect; const lprcSrc: TRect): BOOL;

{ GDI: device contexts }
function GetDC(hWnd: HWND): HDC;
function GetWindowDC(hWnd: HWND): HDC;
function GetDCEx(hWnd: HWND; hrgnClip: HRGN; flags: DWORD): HDC;
function ReleaseDC(hWnd: HWND; hDC: HDC): Integer;
function CreateCompatibleDC(DC: HDC): HDC;
function CreateDC(lpszDriver, lpszDevice, lpszOutput: PAnsiChar; lpdvmInit: PDeviceMode): HDC;
function DeleteDC(DC: HDC): BOOL;
function SaveDC(DC: HDC): Integer;
function RestoreDC(DC: HDC; SavedDC: Integer): BOOL;
function GetDeviceCaps(DC: HDC; Index: Integer): Integer;
function WindowFromDC(DC: HDC): HWND;
function SelectObject(DC: HDC; p2: HGDIOBJ): HGDIOBJ;
function DeleteObject(p1: HGDIOBJ): BOOL;
function GetStockObject(Index: Integer): HGDIOBJ;
function GetCurrentObject(DC: HDC; p2: UINT): HGDIOBJ;
function GetObject(p1: HGDIOBJ; p2: Integer; p3: Pointer): Integer;
function GetObjectType(h: HGDIOBJ): DWORD;
function SetBkColor(DC: HDC; Color: COLORREF): COLORREF;
function GetBkColor(DC: HDC): COLORREF;
function SetBkMode(DC: HDC; BkMode: Integer): Integer;
function GetBkMode(DC: HDC): Integer;
function SetTextColor(DC: HDC; Color: COLORREF): COLORREF;
function GetTextColor(DC: HDC): COLORREF;
function SetTextAlign(DC: HDC; Flags: UINT): UINT;
function GetTextAlign(DC: HDC): UINT;
function SetROP2(DC: HDC; p2: Integer): Integer;
function GetROP2(DC: HDC): Integer;
function SetStretchBltMode(DC: HDC; StretchMode: Integer): Integer;
function GetStretchBltMode(DC: HDC): Integer;
function SetBrushOrgEx(DC: HDC; X, Y: Integer; PrevPt: PPoint): BOOL;
function SetWindowOrgEx(DC: HDC; X, Y: Integer; Point: PPoint): BOOL;
function GetWindowOrgEx(DC: HDC; var Point: TPoint): BOOL;
function SetViewportOrgEx(DC: HDC; X, Y: Integer; Point: PPoint): BOOL;
function GetViewportOrgEx(DC: HDC; var Point: TPoint): BOOL;
function SetMapMode(DC: HDC; p2: Integer): Integer;
function MoveToEx(DC: HDC; p2, p3: Integer; p4: PPoint): BOOL;
function LineTo(DC: HDC; X, Y: Integer): BOOL;
function GetCurrentPositionEx(DC: HDC; Point: PPoint): BOOL;
function Rectangle(DC: HDC; X1, Y1, X2, Y2: Integer): BOOL;
function RoundRect(DC: HDC; X1, Y1, X2, Y2, X3, Y3: Integer): BOOL;
function Ellipse(DC: HDC; X1, Y1, X2, Y2: Integer): BOOL;
function Polygon(DC: HDC; const Points; Count: Integer): BOOL;
function Polyline(DC: HDC; const Points; Count: Integer): BOOL;
function FillRect(hDC: HDC; const lprc: TRect; hbr: HBRUSH): Integer;
function FrameRect(hDC: HDC; const lprc: TRect; hbr: HBRUSH): Integer;
function InvertRect(hDC: HDC; const lprc: TRect): BOOL;
function DrawFocusRect(hDC: HDC; const lprc: TRect): BOOL;
function DrawEdge(hdc: HDC; var qrc: TRect; edge: UINT; grfFlags: UINT): BOOL;
function DrawFrameControl(DC: HDC; const Rect: TRect; uType, uState: UINT): BOOL;
function PatBlt(DC: HDC; X, Y, Width, Height: Integer; Rop: DWORD): BOOL;
function SetPixel(DC: HDC; X, Y: Integer; Color: COLORREF): COLORREF;
function SetPixelV(DC: HDC; X, Y: Integer; Color: COLORREF): BOOL;
function GetPixel(DC: HDC; X, Y: Integer): COLORREF;
function FloodFill(DC: HDC; XStart, YStart: Integer; Color: COLORREF): BOOL;
function ExtFloodFill(DC: HDC; XStart, YStart: Integer; Color: COLORREF; FillType: UINT): BOOL;
function BitBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC;
  XSrc, YSrc: Integer; Rop: DWORD): BOOL;
function StretchBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC;
  XSrc, YSrc, SrcWidth, SrcHeight: Integer; Rop: DWORD): BOOL;
function MaskBlt(DestDC: HDC; XDest, YDest, Width, Height: Integer; SrcDC: HDC;
  XSrc, YSrc: Integer; Mask: HBITMAP; xMask, yMask: Integer; Rop: DWORD): BOOL;
function TransparentBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC;
  XSrc, YSrc, SrcWidth, SrcHeight: Integer; Transparent: UINT): BOOL;
function GdiFlush: BOOL;

{ GDI: bitmaps }
function CreateCompatibleBitmap(DC: HDC; Width, Height: Integer): HBITMAP;
function CreateBitmap(Width, Height: Integer; Planes, BitCount: Longint; Bits: Pointer): HBITMAP;
function CreateBitmapIndirect(const p1: TBitmap): HBITMAP;
function CreateDIBSection(DC: HDC; const p2: TBitmapInfo; p3: UINT; var p4: Pointer;
  p5: THandle; p6: DWORD): HBITMAP;
function CreateDIBitmap(DC: HDC; var InfoHeader: TBitmapInfoHeader; dwUsage: DWORD;
  InitBits: Pointer; var InitInfo: TBitmapInfo; wUsage: UINT): HBITMAP;
function GetDIBits(DC: HDC; Bitmap: HBITMAP; StartScan, NumScans: UINT;
  Bits: Pointer; var BitInfo: TBitmapInfo; Usage: UINT): Integer;
function SetDIBits(DC: HDC; Bitmap: HBITMAP; StartScan, NumScans: UINT;
  Bits: Pointer; var BitsInfo: TBitmapInfo; Usage: UINT): Integer;
function StretchDIBits(DC: HDC; DestX, DestY, DestWidth, DestHeight, SrcX, SrcY,
  SrcWidth, SrcHeight: Integer; Bits: Pointer; var BitsInfo: TBitmapInfo;
  Usage: UINT; Rop: DWORD): Integer;
function SetDIBitsToDevice(DC: HDC; DestX, DestY: Integer; Width, Height: DWORD;
  SrcX, SrcY: Integer; nStartScan, NumScans: UINT; Bits: Pointer;
  var BitsInfo: TBitmapInfo; Usage: UINT): Integer;
function GetDIBColorTable(DC: HDC; p2, p3: UINT; var RGBQuadStructs): UINT;
function SetDIBColorTable(DC: HDC; p2, p3: UINT; var RGBQuadSTructs): UINT;
function GetBitmapBits(Bitmap: HBITMAP; Count: Longint; Bits: Pointer): Longint;
function SetBitmapBits(p1: HBITMAP; p2: DWORD; bits: Pointer): Longint;

{ GDI: palettes }
function CreatePalette(const LogPalette: TLogPalette): HPALETTE;
function CreateHalftonePalette(DC: HDC): HPALETTE;
function SelectPalette(DC: HDC; Palette: HPALETTE; ForceBackground: Bool): HPALETTE;
function RealizePalette(DC: HDC): UINT;
function GetPaletteEntries(Palette: HPALETTE; StartIndex, NumEntries: UINT;
  var PaletteEntries): UINT;
function SetPaletteEntries(Palette: HPALETTE; StartIndex, NumEntries: UINT;
  var PaletteEntries): UINT;
function AnimatePalette(Palette: HPALETTE; StartIndex, NumEntries: UINT; PaletteColors: Pointer): BOOL;
function ResizePalette(Palette: HPALETTE; Entries: UINT): BOOL;
function GetNearestPaletteIndex(Palette: HPALETTE; Color: COLORREF): UINT;
function GetNearestColor(DC: HDC; Color: COLORREF): COLORREF;
function GetSystemPaletteEntries(DC: HDC; StartIndex, NumEntries: UINT;
  var PaletteEntries): UINT;
function UnrealizeObject(hGDIObj: HGDIOBJ): BOOL;
function UpdateColors(DC: HDC): BOOL;

{ GDI: brushes, pens, fonts }
function CreateSolidBrush(p1: COLORREF): HBRUSH;
function CreateBrushIndirect(const p1: TLogBrush): HBRUSH;
function CreateHatchBrush(p1: Integer; p2: COLORREF): HBRUSH;
function CreatePatternBrush(Bitmap: HBITMAP): HBRUSH;
function CreatePen(Style, Width: Integer; Color: COLORREF): HPEN;
function CreatePenIndirect(const LogPen: TLogPen): HPEN;
function CreateFontIndirect(const p1: TLogFont): HFONT;
function CreateFont(nHeight, nWidth, nEscapement, nOrientaion, fnWeight: Integer;
  fdwItalic, fdwUnderline, fdwStrikeOut, fdwCharSet, fdwOutputPrecision,
  fdwClipPrecision, fdwQuality, fdwPitchAndFamily: DWORD; lpszFace: PAnsiChar): HFONT;
function GetSysColorBrush(nIndex: Integer): HBRUSH;

{ GDI: text }
function TextOut(DC: HDC; X, Y: Integer; Str: PAnsiChar; Count: Integer): BOOL;
function ExtTextOut(DC: HDC; X, Y: Integer; Options: Longint; Rect: PRect;
  Str: PAnsiChar; Count: Longint; Dx: PInteger): BOOL;
function DrawText(hDC: HDC; lpString: PAnsiChar; nCount: Integer; var lpRect: TRect;
  uFormat: UINT): Integer;
function GetTextExtentPoint(DC: HDC; Str: PAnsiChar; Count: Integer; var Size: TSize): BOOL;
function GetTextExtentPoint32(DC: HDC; Str: PAnsiChar; Count: Integer; var Size: TSize): BOOL;
function GetTextMetrics(DC: HDC; var TM: TTextMetric): BOOL;
function GetTextFace(DC: HDC; Count: Integer; Buffer: PAnsiChar): Integer;
function SetTextCharacterExtra(DC: HDC; CharExtra: Integer): Integer;

{ GDI: regions & clipping }
function CreateRectRgn(p1, p2, p3, p4: Integer): HRGN;
function CreateRectRgnIndirect(const p1: TRect): HRGN;
function CreateEllipticRgn(p1, p2, p3, p4: Integer): HRGN;
function CreatePolygonRgn(const Points; Count, FillMode: Integer): HRGN;
function SetRectRgn(Rgn: HRGN; X1, Y1, X2, Y2: Integer): BOOL;
function CombineRgn(p1, p2, p3: HRGN; p4: Integer): Integer;
function OffsetRgn(RGN: HRGN; XOffset, YOffset: Integer): Integer;
function GetRgnBox(RGN: HRGN; var p2: TRect): Integer;
function PtInRegion(RGN: HRGN; X, Y: Integer): BOOL;
function RectInRegion(RGN: HRGN; const p2: TRect): BOOL;
function SelectClipRgn(DC: HDC; Region: HRGN): Integer;
function ExtSelectClipRgn(DC: HDC; Region: HRGN; Mode: Integer): Integer;
function GetClipBox(DC: HDC; var Rect: TRect): Integer;
function GetClipRgn(DC: HDC; rgn: HRGN): Integer;
function IntersectClipRect(DC: HDC; X1, Y1, X2, Y2: Integer): Integer;
function ExcludeClipRect(DC: HDC; LeftRect, TopRect, RightRect, BottomRect: Integer): Integer;
function OffsetClipRgn(DC: HDC; XOffset, YOffset: Integer): Integer;
function RectVisible(DC: HDC; const Rect: TRect): BOOL;
function PtVisible(DC: HDC; X, Y: Integer): BOOL;

{ Icons and cursors }
function LoadCursor(hInstance: HINST; lpCursorName: PAnsiChar): HCURSOR;
function LoadIcon(hInstance: HINST; lpIconName: PAnsiChar): HICON;
function LoadBitmap(hInstance: HINST; lpBitmapName: PAnsiChar): HBITMAP;
function LoadImage(hInst: HINST; ImageName: PAnsiChar; ImageType: UINT; X, Y: Integer; Flags: UINT): THandle;
function SetCursor(hCursor: HCURSOR): HCURSOR;
function GetCursor: HCURSOR;
function ShowCursor(bShow: BOOL): Integer;
function GetCursorPos(var lpPoint: TPoint): BOOL;
function SetCursorPos(X, Y: Integer): BOOL;
function ClipCursor(lpRect: PRect): BOOL;
function DestroyCursor(hCursor: HICON): BOOL;
function DestroyIcon(hIcon: HICON): BOOL;
function CreateIconIndirect(var piconinfo: TIconInfo): HICON;
function CopyIcon(hIcon: HICON): HICON;
function DrawIcon(hDC: HDC; X, Y: Integer; hIcon: HICON): BOOL;
function DrawIconEx(hdc: HDC; xLeft, yTop: Integer; hIcon: HICON; cxWidth, cyWidth: Integer;
  istepIfAniCur: UINT; hbrFlickerFreeDraw: HBRUSH; diFlags: UINT): BOOL;
function GetIconInfo(hIcon: HICON; var piconinfo: TIconInfo): BOOL;

{ Windows }
function CreateWindowEx(dwExStyle: DWORD; lpClassName: PAnsiChar; lpWindowName: PAnsiChar;
  dwStyle: DWORD; X, Y, nWidth, nHeight: Integer; hWndParent: HWND; hMenu: HMENU;
  hInstance: HINST; lpParam: Pointer): HWND;
function CreateWindow(lpClassName: PAnsiChar; lpWindowName: PAnsiChar; dwStyle: DWORD;
  X, Y, nWidth, nHeight: Integer; hWndParent: HWND; hMenu: HMENU; hInstance: HINST;
  lpParam: Pointer): HWND;
function DestroyWindow(hWnd: HWND): BOOL;
function RegisterClass(const lpWndClass: TWndClass): ATOM;
function UnregisterClass(lpClassName: PAnsiChar; hInstance: HINST): BOOL;
function GetClassInfo(hInstance: HINST; lpClassName: PAnsiChar; var lpWndClass: TWndClass): BOOL;
function IsWindow(hWnd: HWND): BOOL;
function IsWindowVisible(hWnd: HWND): BOOL;
function IsWindowEnabled(hWnd: HWND): BOOL;
function IsIconic(hWnd: HWND): BOOL;
function IsZoomed(hWnd: HWND): BOOL;
function IsChild(hWndParent, hWnd: HWND): BOOL;
function EnableWindow(hWnd: HWND; bEnable: BOOL): BOOL;
function ShowWindow(hWnd: HWND; nCmdShow: Integer): BOOL;
function SetWindowPos(hWnd: HWND; hWndInsertAfter: HWND; X, Y, cx, cy: Integer; uFlags: UINT): BOOL;
function MoveWindow(hWnd: HWND; X, Y, nWidth, nHeight: Integer; bRepaint: BOOL): BOOL;
function BringWindowToTop(hWnd: HWND): BOOL;
function SetForegroundWindow(hWnd: HWND): BOOL;
function GetForegroundWindow: HWND;
function SetActiveWindow(hWnd: HWND): HWND;
function GetActiveWindow: HWND;
function SetFocus(hWnd: HWND): HWND;
function GetFocus: HWND;
function SetCapture(hWnd: HWND): HWND;
function GetCapture: HWND;
function ReleaseCapture: BOOL;
function GetParent(hWnd: HWND): HWND;
function SetParent(hWndChild, hWndNewParent: HWND): HWND;
function GetWindow(hWnd: HWND; uCmd: UINT): HWND;
function GetTopWindow(hWnd: HWND): HWND;
function GetDesktopWindow: HWND;
function GetWindowRect(hWnd: HWND; var lpRect: TRect): BOOL;
function GetClientRect(hWnd: HWND; var lpRect: TRect): BOOL;
function ClientToScreen(hWnd: HWND; var lpPoint: TPoint): BOOL;
function ScreenToClient(hWnd: HWND; var lpPoint: TPoint): BOOL;
function MapWindowPoints(hWndFrom, hWndTo: HWND; var lpPoints; cPoints: UINT): Integer;
function WindowFromPoint(Point: TPoint): HWND;
function ChildWindowFromPoint(hWndParent: HWND; Point: TPoint): HWND;
function InvalidateRect(hWnd: HWND; lpRect: PRect; bErase: BOOL): BOOL;
function InvalidateRgn(hWnd: HWND; hRgn: HRGN; bErase: BOOL): BOOL;
function ValidateRect(hWnd: HWND; lpRect: PRect): BOOL;
function UpdateWindow(hWnd: HWND): BOOL;
function RedrawWindow(hWnd: HWND; lprcUpdate: PRect; hrgnUpdate: HRGN; flags: UINT): BOOL;
function GetUpdateRect(hWnd: HWND; lpRect: PRect; bErase: BOOL): BOOL;
function BeginPaint(hWnd: HWND; var lpPaint: TPaintStruct): HDC;
function EndPaint(hWnd: HWND; const lpPaint: TPaintStruct): BOOL;
function ScrollWindow(hWnd: HWND; XAmount, YAmount: Integer; Rect, ClipRect: PRect): BOOL;
function SetWindowText(hWnd: HWND; lpString: PAnsiChar): BOOL;
function GetWindowText(hWnd: HWND; lpString: PAnsiChar; nMaxCount: Integer): Integer;
function GetWindowTextLength(hWnd: HWND): Integer;
function GetWindowLong(hWnd: HWND; nIndex: Integer): PtrInt;
function SetWindowLong(hWnd: HWND; nIndex: Integer; dwNewLong: PtrInt): PtrInt;
function GetWindowLongPtr(hWnd: HWND; nIndex: Integer): PtrInt;
function SetWindowLongPtr(hWnd: HWND; nIndex: Integer; dwNewLong: PtrInt): PtrInt;
function GetClassName(hWnd: HWND; lpClassName: PAnsiChar; nMaxCount: Integer): Integer;
function GetWindowPlacement(hWnd: HWND; WindowPlacement: PWindowPlacement): BOOL;
function SetWindowPlacement(hWnd: HWND; WindowPlacement: PWindowPlacement): BOOL;
function FindWindow(lpClassName, lpWindowName: PAnsiChar): HWND;
function GetSystemMetrics(nIndex: Integer): Integer;
function GetSysColor(nIndex: Integer): DWORD;
function FlashWindow(hWnd: HWND; bInvert: BOOL): BOOL;
function GetKeyState(nVirtKey: Integer): SHORT;
function GetAsyncKeyState(vKey: Integer): SHORT;
function GetKeyboardState(var KeyState): BOOL;
function MapVirtualKey(uCode, uMapType: UINT): UINT;
function GetDoubleClickTime: UINT;
function CallWindowProc(lpPrevWndFunc: TFNWndProc; hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
function DefWindowProc(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
function ChangeDisplaySettings(var lpDevMode: TDeviceMode; dwFlags: DWORD): Longint; overload;
function ChangeDisplaySettings(lpDevMode: PDeviceMode; dwFlags: DWORD): Longint; overload;
function EnumDisplaySettings(lpszDeviceName: PAnsiChar; iModeNum: DWORD; var lpDevMode: TDeviceMode): BOOL;
function SystemParametersInfo(uiAction, uiParam: UINT; pvParam: Pointer; fWinIni: UINT): BOOL;
function MessageBeep(uType: UINT): BOOL;
function Beep(dwFreq, dwDuration: DWORD): BOOL;
function MessageBox(hWnd: HWND; lpText, lpCaption: PAnsiChar; uType: UINT): Integer;

{ Messages }
function PostMessage(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): BOOL;
function SendMessage(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
function PostThreadMessage(idThread: DWORD; Msg: UINT; wParam: WPARAM; lParam: LPARAM): BOOL;
procedure PostQuitMessage(nExitCode: Integer);
function PeekMessage(var lpMsg: TMsg; hWnd: HWND; wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): BOOL;
function GetMessage(var lpMsg: TMsg; hWnd: HWND; wMsgFilterMin, wMsgFilterMax: UINT): BOOL;
function TranslateMessage(const lpMsg: TMsg): BOOL;
function DispatchMessage(const lpMsg: TMsg): Longint;
function WaitMessage: BOOL;
function GetMessageTime: Longint;
function GetMessagePos: DWORD;
function GetQueueStatus(flags: UINT): DWORD;
function InSendMessage: BOOL;
function RegisterWindowMessage(lpString: PAnsiChar): UINT;
function SetTimer(hWnd: HWND; nIDEvent, uElapse: UINT; lpTimerFunc: TFNTimerProc): UINT;
function KillTimer(hWnd: HWND; uIDEvent: UINT): BOOL;
function MsgWaitForMultipleObjects(nCount: DWORD; var pHandles; fWaitAll: BOOL;
  dwMilliseconds, dwWakeMask: DWORD): DWORD;

{ Kernel }
function GetTickCount: DWORD;
function QueryPerformanceCounter(var lpPerformanceCount: TLargeInteger): BOOL;
function QueryPerformanceFrequency(var lpFrequency: TLargeInteger): BOOL;
procedure Sleep(dwMilliseconds: DWORD);
function GetVersionEx(var lpVersionInformation: TOSVersionInfo): BOOL;
function GetVersion: DWORD;
function GetLastError: DWORD;
procedure SetLastError(dwErrCode: DWORD);
function LoadLibrary(lpLibFileName: PAnsiChar): HMODULE;
function FreeLibrary(hLibModule: HMODULE): BOOL;
function GetProcAddress(hModule: HMODULE; lpProcName: PAnsiChar): FARPROC;
function GetModuleHandle(lpModuleName: PAnsiChar): HMODULE;
function GetModuleFileName(hModule: HINST; lpFilename: PAnsiChar; nSize: DWORD): DWORD;
function GetCurrentThreadId: DWORD;
function GetCurrentProcessId: DWORD;
function GetCurrentDirectory(nBufferLength: DWORD; lpBuffer: PAnsiChar): DWORD;
function SetCurrentDirectory(lpPathName: PAnsiChar): BOOL;
function GetWindowsDirectory(lpBuffer: PAnsiChar; uSize: UINT): UINT;
function GetSystemDirectory(lpBuffer: PAnsiChar; uSize: UINT): UINT;
function GetTempPath(nBufferLength: DWORD; lpBuffer: PAnsiChar): DWORD;
function GetDriveType(lpRootPathName: PAnsiChar): UINT;
function GetLogicalDrives: DWORD;
function SetErrorMode(uMode: UINT): UINT;
function GetLocalTime(var lpSystemTime: TSystemTime): BOOL;
function GetSystemTime(var lpSystemTime: TSystemTime): BOOL;
function GlobalAlloc(uFlags: UINT; dwBytes: PtrUInt): HGLOBAL;
function GlobalFree(hMem: HGLOBAL): HGLOBAL;
function GlobalLock(hMem: HGLOBAL): Pointer;
function GlobalUnlock(hMem: HGLOBAL): BOOL;
function GlobalSize(hMem: HGLOBAL): PtrUInt;
procedure GlobalMemoryStatus(var lpBuffer: TMemoryStatus);
procedure InitializeCriticalSection(var lpCriticalSection: TRTLCriticalSection);
procedure EnterCriticalSection(var lpCriticalSection: TRTLCriticalSection);
procedure LeaveCriticalSection(var lpCriticalSection: TRTLCriticalSection);
procedure DeleteCriticalSection(var lpCriticalSection: TRTLCriticalSection);
function InterlockedIncrement(var Addend: Longint): Longint;
function InterlockedDecrement(var Addend: Longint): Longint;
function InterlockedExchange(var Target: Longint; Value: Longint): Longint;
function MulDiv(nNumber, nNumerator, nDenominator: Integer): Integer;
function lstrlen(lpString: PAnsiChar): Integer;
function lstrcpy(lpString1, lpString2: PAnsiChar): PAnsiChar;
function lstrcmp(lpString1, lpString2: PAnsiChar): Integer;
function lstrcmpi(lpString1, lpString2: PAnsiChar): Integer;
function CharUpper(lpsz: PAnsiChar): PAnsiChar;
function CharLower(lpsz: PAnsiChar): PAnsiChar;
function CharNext(lpsz: PAnsiChar): PAnsiChar;
function CharPrev(lpszStart: PAnsiChar; lpszCurrent: PAnsiChar): PAnsiChar;
function OutputDebugString(lpOutputString: PAnsiChar): BOOL;
function GetPrivateProfileString(lpAppName, lpKeyName, lpDefault: PAnsiChar;
  lpReturnedString: PAnsiChar; nSize: DWORD; lpFileName: PAnsiChar): DWORD;
function WritePrivateProfileString(lpAppName, lpKeyName, lpString, lpFileName: PAnsiChar): BOOL;

{ Resources (only the original ROS.exe and built-in resources are searched) }
function FindResource(hModule: HMODULE; lpName, lpType: PAnsiChar): HRSRC;
function LoadResource(hModule: HINST; hResInfo: HRSRC): HGLOBAL;
function LockResource(hResData: HGLOBAL): Pointer;
function SizeofResource(hModule: HINST; hResInfo: HRSRC): DWORD;
function FreeResource(hResData: HGLOBAL): BOOL;

{ ParamStr(0) reports the original game's location (see ZMData.ZMShadowDir), so the
  game's ExtractFilePath(ParamStr(0)) finds its data files. }
function ParamStr(Index: Integer): string;

var
  HInstance: HINST = 1;   { pseudo module handle of the game (resources come from ROS.exe) }

implementation

{$I windows_impl.inc}

end.

unit Graphics;

{ Delphi 5 Graphics-unit, draagbaar: TFont/TPen/TBrush/TCanvas/TGraphic/TBitmap/
  TPicture/TIcon bovenop de geëmuleerde GDI (Windows-unit). Bitmaps zijn DIB's van
  1/4/8/15-16/24/32 bpp; ScanLine[] geeft rijen van boven naar beneden terug. }

{$MODE DELPHI}{$H+}{$R-}{$Q-}{$POINTERMATH ON}

interface

uses Windows, SysUtils, Classes;

type
  TColor = -$7FFFFFFF - 1..$7FFFFFFF;
  PColor = ^TColor;

  EInvalidGraphic = class(Exception);
  EInvalidGraphicOperation = class(Exception);

const
  clSystemColor = TColor($80000000);

  clScrollBar = TColor(clSystemColor or COLOR_SCROLLBAR);
  clBackground = TColor(clSystemColor or COLOR_BACKGROUND);
  clActiveCaption = TColor(clSystemColor or COLOR_ACTIVECAPTION);
  clInactiveCaption = TColor(clSystemColor or COLOR_INACTIVECAPTION);
  clMenu = TColor(clSystemColor or COLOR_MENU);
  clWindow = TColor(clSystemColor or COLOR_WINDOW);
  clWindowFrame = TColor(clSystemColor or COLOR_WINDOWFRAME);
  clMenuText = TColor(clSystemColor or COLOR_MENUTEXT);
  clWindowText = TColor(clSystemColor or COLOR_WINDOWTEXT);
  clCaptionText = TColor(clSystemColor or COLOR_CAPTIONTEXT);
  clActiveBorder = TColor(clSystemColor or COLOR_ACTIVEBORDER);
  clInactiveBorder = TColor(clSystemColor or COLOR_INACTIVEBORDER);
  clAppWorkSpace = TColor(clSystemColor or COLOR_APPWORKSPACE);
  clHighlight = TColor(clSystemColor or COLOR_HIGHLIGHT);
  clHighlightText = TColor(clSystemColor or COLOR_HIGHLIGHTTEXT);
  clBtnFace = TColor(clSystemColor or COLOR_BTNFACE);
  clBtnShadow = TColor(clSystemColor or COLOR_BTNSHADOW);
  clGrayText = TColor(clSystemColor or COLOR_GRAYTEXT);
  clBtnText = TColor(clSystemColor or COLOR_BTNTEXT);
  clInactiveCaptionText = TColor(clSystemColor or COLOR_INACTIVECAPTIONTEXT);
  clBtnHighlight = TColor(clSystemColor or COLOR_BTNHIGHLIGHT);
  cl3DDkShadow = TColor(clSystemColor or COLOR_3DDKSHADOW);
  cl3DLight = TColor(clSystemColor or COLOR_3DLIGHT);
  clInfoText = TColor(clSystemColor or COLOR_INFOTEXT);
  clInfoBk = TColor(clSystemColor or COLOR_INFOBK);

  clBlack = TColor($000000);
  clMaroon = TColor($000080);
  clGreen = TColor($008000);
  clOlive = TColor($008080);
  clNavy = TColor($800000);
  clPurple = TColor($800080);
  clTeal = TColor($808000);
  clGray = TColor($808080);
  clSilver = TColor($C0C0C0);
  clRed = TColor($0000FF);
  clLime = TColor($00FF00);
  clYellow = TColor($00FFFF);
  clBlue = TColor($FF0000);
  clFuchsia = TColor($FF00FF);
  clAqua = TColor($FFFF00);
  clLtGray = TColor($C0C0C0);
  clDkGray = TColor($808080);
  clWhite = TColor($FFFFFF);
  clNone = TColor($1FFFFFFF);
  clDefault = TColor($20000000);

  cmBlackness = BLACKNESS;
  cmDstInvert = DSTINVERT;
  cmMergeCopy = MERGECOPY;
  cmMergePaint = MERGEPAINT;
  cmNotSrcCopy = NOTSRCCOPY;
  cmNotSrcErase = NOTSRCERASE;
  cmPatCopy = PATCOPY;
  cmPatInvert = PATINVERT;
  cmPatPaint = PATPAINT;
  cmSrcAnd = SRCAND;
  cmSrcCopy = SRCCOPY;
  cmSrcErase = SRCERASE;
  cmSrcInvert = SRCINVERT;
  cmSrcPaint = SRCPAINT;
  cmWhiteness = WHITENESS;

  rc0 = 0;

type
  TFontPitch = (fpDefault, fpVariable, fpFixed);
  TFontName = type string;
  TFontCharset = 0..255;
  TFontStyle = (fsBold, fsItalic, fsUnderline, fsStrikeOut);
  TFontStyles = set of TFontStyle;
  TFontStylesBase = set of TFontStyle;

  TPenStyle = (psSolid, psDash, psDot, psDashDot, psDashDotDot, psClear, psInsideFrame);
  TPenMode = (pmBlack, pmWhite, pmNop, pmNot, pmCopy, pmNotCopy, pmMergePenNot,
    pmMaskPenNot, pmMergeNotPen, pmMaskNotPen, pmMerge, pmNotMerge, pmMask, pmNotMask,
    pmXor, pmNotXor);
  TBrushStyle = (bsSolid, bsClear, bsHorizontal, bsVertical, bsFDiagonal, bsBDiagonal,
    bsCross, bsDiagCross);
  TCopyMode = Longint;
  TFillStyle = (fsSurface, fsBorder);
  TFillMode = (fmAlternate, fmWinding);

  TPixelFormat = (pfDevice, pf1bit, pf4bit, pf8bit, pf15bit, pf16bit, pf24bit, pf32bit, pfCustom);
  TBitmapHandleType = (bmDIB, bmDDB);
  TTransparentMode = (tmAuto, tmFixed);

  TCanvasStates = (csHandleValid, csFontValid, csPenValid, csBrushValid);
  TCanvasState = set of TCanvasStates;
  TCanvasOrientation = (coLeftToRight, coRightToLeft);

  TProgressStage = (psStarting, psRunning, psEnding);
  TProgressEvent = procedure(Sender: TObject; Stage: TProgressStage; PercentDone: Byte;
    RedrawNow: Boolean; const R: TRect; const Msg: string) of object;

  TFontData = record
    Handle: HFont;
    Height: Integer;
    Pitch: TFontPitch;
    Style: TFontStylesBase;
    Charset: TFontCharset;
    Name: string;
  end;

  TPenData = record
    Handle: HPen;
    Color: TColor;
    Width: Integer;
    Style: TPenStyle;
  end;

  TBrushData = record
    Handle: HBrush;
    Color: TColor;
    Bitmap: TObject;
    Style: TBrushStyle;
  end;

  TGraphicsObject = class(TPersistent)
  private
    FOnChange: TNotifyEvent;
    FOwnerLock: Pointer;
  protected
    procedure Changed; virtual;
  public
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OwnerCriticalSection: Pointer read FOwnerLock write FOwnerLock;
  end;

  TFont = class(TGraphicsObject)
  private
    FColor: TColor;
    FPixelsPerInch: Integer;
    FHandle: HFONT;
    FHeight: Integer;
    FPitch: TFontPitch;
    FStyle: TFontStyles;
    FCharset: TFontCharset;
    FName: string;
    procedure FreeHandle;
    function GetHandle: HFont;
    function GetHeight: Integer;
    function GetName: TFontName;
    function GetPitch: TFontPitch;
    function GetSize: Integer;
    function GetStyle: TFontStyles;
    function GetCharset: TFontCharset;
    procedure SetColor(Value: TColor);
    procedure SetHandle(Value: HFont);
    procedure SetHeight(Value: Integer);
    procedure SetName(const Value: TFontName);
    procedure SetPitch(Value: TFontPitch);
    procedure SetSize(Value: Integer);
    procedure SetStyle(Value: TFontStyles);
    procedure SetCharset(Value: TFontCharset);
  protected
    procedure Changed; override;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    property Handle: HFont read GetHandle write SetHandle;
    property PixelsPerInch: Integer read FPixelsPerInch write FPixelsPerInch;
  published
    property Charset: TFontCharset read GetCharset write SetCharset;
    property Color: TColor read FColor write SetColor;
    property Height: Integer read GetHeight write SetHeight;
    property Name: TFontName read GetName write SetName;
    property Pitch: TFontPitch read GetPitch write SetPitch default fpDefault;
    property Size: Integer read GetSize write SetSize stored False;
    property Style: TFontStyles read GetStyle write SetStyle;
  end;

  TPen = class(TGraphicsObject)
  private
    FMode: TPenMode;
    FColor: TColor;
    FWidth: Integer;
    FStyle: TPenStyle;
    FHandle: HPEN;
    procedure FreeHandle;
    function GetColor: TColor;
    procedure SetColor(Value: TColor);
    function GetHandle: HPen;
    procedure SetHandle(Value: HPen);
    procedure SetMode(Value: TPenMode);
    function GetStyle: TPenStyle;
    procedure SetStyle(Value: TPenStyle);
    function GetWidth: Integer;
    procedure SetWidth(Value: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    property Handle: HPen read GetHandle write SetHandle;
  published
    property Color: TColor read GetColor write SetColor default clBlack;
    property Mode: TPenMode read FMode write SetMode default pmCopy;
    property Style: TPenStyle read GetStyle write SetStyle default psSolid;
    property Width: Integer read GetWidth write SetWidth default 1;
  end;

  TBitmap = class;

  TBrush = class(TGraphicsObject)
  private
    FColor: TColor;
    FStyle: TBrushStyle;
    FBitmap: TBitmap;
    FHandle: HBRUSH;
    procedure FreeHandle;
    function GetBitmap: TBitmap;
    procedure SetBitmap(Value: TBitmap);
    function GetColor: TColor;
    procedure SetColor(Value: TColor);
    function GetHandle: HBrush;
    procedure SetHandle(Value: HBrush);
    function GetStyle: TBrushStyle;
    procedure SetStyle(Value: TBrushStyle);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    property Bitmap: TBitmap read GetBitmap write SetBitmap;
    property Handle: HBrush read GetHandle write SetHandle;
  published
    property Color: TColor read GetColor write SetColor default clWhite;
    property Style: TBrushStyle read GetStyle write SetStyle default bsSolid;
  end;

  TGraphic = class;

  TCanvas = class(TPersistent)
  private
    FHandle: HDC;
    State: TCanvasState;
    FFont: TFont;
    FPen: TPen;
    FBrush: TBrush;
    FPenPos: TPoint;
    FCopyMode: TCopyMode;
    FOnChange: TNotifyEvent;
    FOnChanging: TNotifyEvent;
    FLockCount: Integer;
    FTextFlags: Longint;
    procedure CreateBrush;
    procedure CreateFont;
    procedure CreatePen;
    procedure BrushChanged(ABrush: TObject);
    procedure DeselectHandles;
    function GetCanvasOrientation: TCanvasOrientation;
    function GetClipRect: TRect;
    function GetHandle: HDC;
    function GetPenPos: TPoint;
    function GetPixel(X, Y: Integer): TColor;
    procedure FontChanged(AFont: TObject);
    procedure PenChanged(APen: TObject);
    procedure SetBrush(Value: TBrush);
    procedure SetFont(Value: TFont);
    procedure SetHandle(Value: HDC);
    procedure SetPen(Value: TPen);
    procedure SetPenPos(Value: TPoint);
    procedure SetPixel(X, Y: Integer; Value: TColor);
  protected
    procedure Changed; virtual;
    procedure Changing; virtual;
    procedure CreateHandle; virtual;
    procedure RequiredState(ReqState: TCanvasState);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Arc(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer);
    procedure BrushCopy(const Dest: TRect; Bitmap: TBitmap; const Source: TRect; Color: TColor);
    procedure Chord(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer);
    procedure CopyRect(const Dest: TRect; Canvas: TCanvas; const Source: TRect);
    procedure Draw(X, Y: Integer; Graphic: TGraphic);
    procedure DrawFocusRect(const Rect: TRect);
    procedure Ellipse(X1, Y1, X2, Y2: Integer); overload;
    procedure Ellipse(const Rect: TRect); overload;
    procedure FillRect(const Rect: TRect);
    procedure FloodFill(X, Y: Integer; Color: TColor; FillStyle: TFillStyle);
    procedure FrameRect(const Rect: TRect);
    procedure LineTo(X, Y: Integer);
    procedure Lock;
    procedure MoveTo(X, Y: Integer);
    procedure Pie(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Longint);
    procedure Polygon(const Points: array of TPoint);
    procedure Polyline(const Points: array of TPoint);
    procedure PolyBezier(const Points: array of TPoint);
    procedure PolyBezierTo(const Points: array of TPoint);
    procedure Rectangle(X1, Y1, X2, Y2: Integer); overload;
    procedure Rectangle(const Rect: TRect); overload;
    procedure Refresh;
    procedure RoundRect(X1, Y1, X2, Y2, X3, Y3: Integer);
    procedure StretchDraw(const Rect: TRect; Graphic: TGraphic);
    function TextExtent(const Text: string): TSize;
    function TextHeight(const Text: string): Integer;
    procedure TextOut(X, Y: Integer; const Text: string);
    procedure TextRect(Rect: TRect; X, Y: Integer; const Text: string);
    function TextWidth(const Text: string): Integer;
    function TryLock: Boolean;
    procedure Unlock;
    function HandleAllocated: Boolean;
    property ClipRect: TRect read GetClipRect;
    property Handle: HDC read GetHandle write SetHandle;
    property LockCount: Integer read FLockCount;
    property CanvasOrientation: TCanvasOrientation read GetCanvasOrientation;
    property PenPos: TPoint read GetPenPos write SetPenPos;
    property Pixels[X, Y: Integer]: TColor read GetPixel write SetPixel;
    property TextFlags: Longint read FTextFlags write FTextFlags;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnChanging: TNotifyEvent read FOnChanging write FOnChanging;
  published
    property Brush: TBrush read FBrush write SetBrush;
    property CopyMode: TCopyMode read FCopyMode write FCopyMode default cmSrcCopy;
    property Font: TFont read FFont write SetFont;
    property Pen: TPen read FPen write SetPen;
  end;

  TGraphic = class(TPersistent)
  private
    FOnChange: TNotifyEvent;
    FOnProgress: TProgressEvent;
    FModified: Boolean;
    FTransparent: Boolean;
    FPaletteModified: Boolean;
    procedure SetModified(Value: Boolean);
  protected
    procedure Changed(Sender: TObject); virtual;
    procedure DefineProperties(Filer: TFiler); override;
    procedure Draw(ACanvas: TCanvas; const Rect: TRect); virtual; abstract;
    function Equals(Graphic: TGraphic): Boolean; reintroduce; virtual;
    function GetEmpty: Boolean; virtual; abstract;
    function GetHeight: Integer; virtual; abstract;
    function GetPalette: HPALETTE; virtual;
    function GetTransparent: Boolean; virtual;
    function GetWidth: Integer; virtual; abstract;
    procedure Progress(Sender: TObject; Stage: TProgressStage; PercentDone: Byte;
      RedrawNow: Boolean; const R: TRect; const Msg: string); dynamic;
    procedure ReadData(Stream: TStream); virtual;
    procedure SetHeight(Value: Integer); virtual; abstract;
    procedure SetPalette(Value: HPALETTE); virtual;
    procedure SetTransparent(Value: Boolean); virtual;
    procedure SetWidth(Value: Integer); virtual; abstract;
    procedure WriteData(Stream: TStream); virtual;
  public
    constructor Create; virtual;
    procedure LoadFromFile(const Filename: string); virtual;
    procedure SaveToFile(const Filename: string); virtual;
    procedure LoadFromStream(Stream: TStream); virtual; abstract;
    procedure SaveToStream(Stream: TStream); virtual; abstract;
    procedure LoadFromClipboardFormat(AFormat: Word; AData: THandle; APalette: HPALETTE); virtual; abstract;
    procedure SaveToClipboardFormat(var AFormat: Word; var AData: THandle; var APalette: HPALETTE); virtual; abstract;
    property Empty: Boolean read GetEmpty;
    property Height: Integer read GetHeight write SetHeight;
    property Modified: Boolean read FModified write SetModified;
    property Palette: HPALETTE read GetPalette write SetPalette;
    property PaletteModified: Boolean read FPaletteModified write FPaletteModified;
    property Transparent: Boolean read GetTransparent write SetTransparent;
    property Width: Integer read GetWidth write SetWidth;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnProgress: TProgressEvent read FOnProgress write FOnProgress;
  end;

  TGraphicClass = class of TGraphic;

  TIcon = class;
  TMetafile = class;

  TPicture = class(TPersistent)
  private
    FGraphic: TGraphic;
    FOnChange: TNotifyEvent;
    FOnProgress: TProgressEvent;
    procedure ForceType(GraphicType: TGraphicClass);
    function GetBitmap: TBitmap;
    function GetHeight: Integer;
    function GetIcon: TIcon;
    function GetMetafile: TMetafile;
    function GetWidth: Integer;
    procedure ReadData(Stream: TStream);
    procedure SetBitmap(Value: TBitmap);
    procedure SetGraphic(Value: TGraphic);
    procedure SetIcon(Value: TIcon);
    procedure SetMetafile(Value: TMetafile);
    procedure WriteData(Stream: TStream);
  protected
    procedure AssignTo(Dest: TPersistent); override;
    procedure Changed(Sender: TObject); dynamic;
    procedure DefineProperties(Filer: TFiler); override;
    procedure Progress(Sender: TObject; Stage: TProgressStage; PercentDone: Byte;
      RedrawNow: Boolean; const R: TRect; const Msg: string); dynamic;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromFile(const Filename: string);
    procedure SaveToFile(const Filename: string);
    procedure Assign(Source: TPersistent); override;
    class procedure RegisterFileFormat(const AExtension, ADescription: string; AGraphicClass: TGraphicClass);
    class procedure UnregisterGraphicClass(AClass: TGraphicClass);
    class function SupportsClipboardFormat(AFormat: Word): Boolean;
    property Bitmap: TBitmap read GetBitmap write SetBitmap;
    property Graphic: TGraphic read FGraphic write SetGraphic;
    property Height: Integer read GetHeight;
    property Icon: TIcon read GetIcon write SetIcon;
    property Metafile: TMetafile read GetMetafile write SetMetafile;
    property Width: Integer read GetWidth;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnProgress: TProgressEvent read FOnProgress write FOnProgress;
  end;

  TMetafile = class(TGraphic)
  private
    FWidth, FHeight: Integer;
    FData: TMemoryStream;
  protected
    procedure Draw(ACanvas: TCanvas; const Rect: TRect); override;
    function GetEmpty: Boolean; override;
    function GetHeight: Integer; override;
    function GetWidth: Integer; override;
    procedure SetHeight(Value: Integer); override;
    procedure SetWidth(Value: Integer); override;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure LoadFromStream(Stream: TStream); override;
    procedure SaveToStream(Stream: TStream); override;
    procedure LoadFromClipboardFormat(AFormat: Word; AData: THandle; APalette: HPALETTE); override;
    procedure SaveToClipboardFormat(var AFormat: Word; var AData: THandle; var APalette: HPALETTE); override;
  end;

  TBitmapCanvas = class(TCanvas)
  private
    FBitmap: TBitmap;
    FOldBitmap: HBITMAP;
    FOldPalette: HPALETTE;
    procedure FreeContext;
  protected
    procedure CreateHandle; override;
  public
    constructor Create(ABitmap: TBitmap);
    destructor Destroy; override;
  end;

  TBitmap = class(TGraphic)
  private
    FHandle: HBITMAP;
    FImg: Pointer;
    FImgHandle: HBITMAP;
    FPalette: HPALETTE;
    FPaletteStamp: LongWord;
    FCanvas: TCanvas;
    FIgnorePalette: Boolean;
    FMaskHandle: HBITMAP;
    FTransparentColor: TColor;
    FTransparentMode: TTransparentMode;
    FPixelFormat: TPixelFormat;
    FHandleType: TBitmapHandleType;
    FMonochrome: Boolean;
    procedure NewImage(AWidth, AHeight: Integer; ABPP: Integer; CopyOld: Boolean);
    function Img: Pointer;
    function GetCanvas: TCanvas;
    function GetHandle: HBITMAP; virtual;
    function GetHandleType: TBitmapHandleType;
    function GetMaskHandle: HBITMAP; virtual;
    function GetMonochrome: Boolean;
    function GetPixelFormat: TPixelFormat;
    function GetScanline(Row: Integer): Pointer;
    function GetTransparentColor: TColor;
    procedure SetHandle(Value: HBITMAP);
    procedure SetHandleType(Value: TBitmapHandleType); virtual;
    procedure SetMaskHandle(Value: HBITMAP);
    procedure SetMonochrome(Value: Boolean);
    procedure SetPixelFormat(Value: TPixelFormat);
    procedure SetTransparentColor(Value: TColor);
    procedure SetTransparentMode(Value: TTransparentMode);
    procedure ReselectInCanvas;
  protected
    procedure Changed(Sender: TObject); override;
    procedure Draw(ACanvas: TCanvas; const Rect: TRect); override;
    function GetEmpty: Boolean; override;
    function GetHeight: Integer; override;
    function GetPalette: HPALETTE; override;
    function GetWidth: Integer; override;
    procedure ReadData(Stream: TStream); override;
    procedure SetHeight(Value: Integer); override;
    procedure SetPalette(Value: HPALETTE); override;
    procedure SetWidth(Value: Integer); override;
    procedure WriteData(Stream: TStream); override;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure Dormant;
    procedure FreeImage;
    function HandleAllocated: Boolean;
    procedure LoadFromClipboardFormat(AFormat: Word; AData: THandle; APalette: HPALETTE); override;
    procedure LoadFromStream(Stream: TStream); override;
    procedure LoadFromResourceName(Instance: THandle; const ResName: string);
    procedure LoadFromResourceID(Instance: THandle; ResID: Integer);
    procedure Mask(TransparentColor: TColor);
    function ReleaseHandle: HBITMAP;
    function ReleaseMaskHandle: HBITMAP;
    function ReleasePalette: HPALETTE;
    procedure SaveToClipboardFormat(var Format: Word; var Data: THandle; var APalette: HPALETTE); override;
    procedure SaveToStream(Stream: TStream); override;
    property Canvas: TCanvas read GetCanvas;
    property Handle: HBITMAP read GetHandle write SetHandle;
    property HandleType: TBitmapHandleType read GetHandleType write SetHandleType;
    property IgnorePalette: Boolean read FIgnorePalette write FIgnorePalette;
    property MaskHandle: HBITMAP read GetMaskHandle write SetMaskHandle;
    property Monochrome: Boolean read GetMonochrome write SetMonochrome;
    property PixelFormat: TPixelFormat read GetPixelFormat write SetPixelFormat;
    property ScanLine[Row: Integer]: Pointer read GetScanLine;
    property TransparentColor: TColor read GetTransparentColor write SetTransparentColor stored False;
    property TransparentMode: TTransparentMode read FTransparentMode write SetTransparentMode default tmAuto;
  end;

  TIcon = class(TGraphic)
  private
    FData: TMemoryStream;
    FWidth, FHeight: Integer;
    FHandle: HICON;
    function GetHandle: HICON;
    procedure SetHandle(Value: HICON);
  protected
    procedure Draw(ACanvas: TCanvas; const Rect: TRect); override;
    function GetEmpty: Boolean; override;
    function GetHeight: Integer; override;
    function GetWidth: Integer; override;
    procedure SetHeight(Value: Integer); override;
    procedure SetWidth(Value: Integer); override;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    function HandleAllocated: Boolean;
    procedure LoadFromClipboardFormat(AFormat: Word; AData: THandle; APalette: HPALETTE); override;
    procedure LoadFromStream(Stream: TStream); override;
    function ReleaseHandle: HICON;
    procedure SaveToClipboardFormat(var Format: Word; var Data: THandle; var APalette: HPALETTE); override;
    procedure SaveToStream(Stream: TStream); override;
    property Handle: HICON read GetHandle write SetHandle;
  end;

var
  DefFontData: TFontData = (
    Handle: 0;
    Height: 0;
    Pitch: fpDefault;
    Style: [];
    Charset: DEFAULT_CHARSET;
    Name: 'MS Sans Serif');
  SystemPalette16: HPALETTE;
  DDBsOnly: Boolean = False;
  ScreenLogPixels: Integer = 96;

function GraphicFilter(GraphicClass: TGraphicClass): string;
function GraphicExtension(GraphicClass: TGraphicClass): string;
function GraphicFileMask(GraphicClass: TGraphicClass): string;

function ColorToRGB(Color: TColor): Longint;
function ColorToString(Color: TColor): string;
function StringToColor(const S: string): TColor;
procedure GetColorValues(Proc: TGetStrProc);
function ColorToIdent(Color: Longint; var Ident: string): Boolean;
function IdentToColor(const Ident: string; var Color: Longint): Boolean;
procedure GetCharsetValues(Proc: TGetStrProc);
function CharsetToIdent(Charset: Longint; var Ident: string): Boolean;
function IdentToCharset(const Ident: string; var Charset: Longint): Boolean;

procedure GetDIBSizes(Bitmap: HBITMAP; var InfoHeaderSize: DWORD; var ImageSize: DWORD);
function GetDIB(Bitmap: HBITMAP; Palette: HPALETTE; var BitmapInfo; var Bits): Boolean;
function CopyPalette(Palette: HPALETTE): HPALETTE;
procedure PaletteChanged;
procedure FreeMemoryContexts;
function GetDefFontCharSet: TFontCharset;
function TransparentStretchBlt(DstDC: HDC; DstX, DstY, DstW, DstH: Integer;
  SrcDC: HDC; SrcX, SrcY, SrcW, SrcH: Integer; MaskDC: HDC; MaskX, MaskY: Integer): Boolean;
function CreateMappedBmp(Handle: HBITMAP; const OldColors, NewColors: array of TColor): HBITMAP;
function CreateGrayMappedBmp(Handle: HBITMAP): HBITMAP;
function AllocPatternBitmap(BkColor, FgColor: TColor): TBitmap;

implementation

uses Math, ZMGdi, ZMData;

{ ---------------------------------------------------------------- kleuren }

type
  TIdentMapEntryG = record
    Value: Longint;
    Name: string;
  end;

const
  Colors: array[0..41] of TIdentMapEntryG = (
    (Value: clBlack; Name: 'clBlack'),
    (Value: clMaroon; Name: 'clMaroon'),
    (Value: clGreen; Name: 'clGreen'),
    (Value: clOlive; Name: 'clOlive'),
    (Value: clNavy; Name: 'clNavy'),
    (Value: clPurple; Name: 'clPurple'),
    (Value: clTeal; Name: 'clTeal'),
    (Value: clGray; Name: 'clGray'),
    (Value: clSilver; Name: 'clSilver'),
    (Value: clRed; Name: 'clRed'),
    (Value: clLime; Name: 'clLime'),
    (Value: clYellow; Name: 'clYellow'),
    (Value: clBlue; Name: 'clBlue'),
    (Value: clFuchsia; Name: 'clFuchsia'),
    (Value: clAqua; Name: 'clAqua'),
    (Value: clWhite; Name: 'clWhite'),
    (Value: Longint(clScrollBar); Name: 'clScrollBar'),
    (Value: Longint(clBackground); Name: 'clBackground'),
    (Value: Longint(clActiveCaption); Name: 'clActiveCaption'),
    (Value: Longint(clInactiveCaption); Name: 'clInactiveCaption'),
    (Value: Longint(clMenu); Name: 'clMenu'),
    (Value: Longint(clWindow); Name: 'clWindow'),
    (Value: Longint(clWindowFrame); Name: 'clWindowFrame'),
    (Value: Longint(clMenuText); Name: 'clMenuText'),
    (Value: Longint(clWindowText); Name: 'clWindowText'),
    (Value: Longint(clCaptionText); Name: 'clCaptionText'),
    (Value: Longint(clActiveBorder); Name: 'clActiveBorder'),
    (Value: Longint(clInactiveBorder); Name: 'clInactiveBorder'),
    (Value: Longint(clAppWorkSpace); Name: 'clAppWorkSpace'),
    (Value: Longint(clHighlight); Name: 'clHighlight'),
    (Value: Longint(clHighlightText); Name: 'clHighlightText'),
    (Value: Longint(clBtnFace); Name: 'clBtnFace'),
    (Value: Longint(clBtnShadow); Name: 'clBtnShadow'),
    (Value: Longint(clGrayText); Name: 'clGrayText'),
    (Value: Longint(clBtnText); Name: 'clBtnText'),
    (Value: Longint(clInactiveCaptionText); Name: 'clInactiveCaptionText'),
    (Value: Longint(clBtnHighlight); Name: 'clBtnHighlight'),
    (Value: Longint(cl3DDkShadow); Name: 'cl3DDkShadow'),
    (Value: Longint(cl3DLight); Name: 'cl3DLight'),
    (Value: Longint(clInfoText); Name: 'clInfoText'),
    (Value: Longint(clInfoBk); Name: 'clInfoBk'),
    (Value: Longint(clNone); Name: 'clNone'));

  Charsets: array[0..17] of TIdentMapEntryG = (
    (Value: ANSI_CHARSET; Name: 'ANSI_CHARSET'),
    (Value: DEFAULT_CHARSET; Name: 'DEFAULT_CHARSET'),
    (Value: SYMBOL_CHARSET; Name: 'SYMBOL_CHARSET'),
    (Value: MAC_CHARSET; Name: 'MAC_CHARSET'),
    (Value: SHIFTJIS_CHARSET; Name: 'SHIFTJIS_CHARSET'),
    (Value: HANGEUL_CHARSET; Name: 'HANGEUL_CHARSET'),
    (Value: JOHAB_CHARSET; Name: 'JOHAB_CHARSET'),
    (Value: GB2312_CHARSET; Name: 'GB2312_CHARSET'),
    (Value: CHINESEBIG5_CHARSET; Name: 'CHINESEBIG5_CHARSET'),
    (Value: GREEK_CHARSET; Name: 'GREEK_CHARSET'),
    (Value: TURKISH_CHARSET; Name: 'TURKISH_CHARSET'),
    (Value: HEBREW_CHARSET; Name: 'HEBREW_CHARSET'),
    (Value: ARABIC_CHARSET; Name: 'ARABIC_CHARSET'),
    (Value: BALTIC_CHARSET; Name: 'BALTIC_CHARSET'),
    (Value: RUSSIAN_CHARSET; Name: 'RUSSIAN_CHARSET'),
    (Value: THAI_CHARSET; Name: 'THAI_CHARSET'),
    (Value: EASTEUROPE_CHARSET; Name: 'EASTEUROPE_CHARSET'),
    (Value: OEM_CHARSET; Name: 'OEM_CHARSET'));

function ColorToRGB(Color: TColor): Longint;
begin
  if Color < 0 then
    Result := GetSysColor(Color and $000000FF)
  else
    Result := Color;
end;

function ColorToIdent(Color: Longint; var Ident: string): Boolean;
var
  I: Integer;
begin
  for I := Low(Colors) to High(Colors) do
    if Colors[I].Value = Color then
    begin
      Ident := Colors[I].Name;
      Exit(True);
    end;
  Result := False;
end;

function IdentToColor(const Ident: string; var Color: Longint): Boolean;
var
  I: Integer;
begin
  for I := Low(Colors) to High(Colors) do
    if SameText(Colors[I].Name, Ident) then
    begin
      Color := Colors[I].Value;
      Exit(True);
    end;
  Result := False;
end;

function ColorToString(Color: TColor): string;
begin
  if not ColorToIdent(Color, Result) then
    Result := Format('$%.8x', [Color]);
end;

function StringToColor(const S: string): TColor;
var
  C: Longint;
begin
  if not IdentToColor(S, C) then
    Result := TColor(StrToInt(S))
  else
    Result := TColor(C);
end;

procedure GetColorValues(Proc: TGetStrProc);
var
  I: Integer;
begin
  for I := Low(Colors) to High(Colors) do Proc(Colors[I].Name);
end;

function CharsetToIdent(Charset: Longint; var Ident: string): Boolean;
var
  I: Integer;
begin
  for I := Low(Charsets) to High(Charsets) do
    if Charsets[I].Value = Charset then
    begin
      Ident := Charsets[I].Name;
      Exit(True);
    end;
  Result := False;
end;

function IdentToCharset(const Ident: string; var Charset: Longint): Boolean;
var
  I: Integer;
begin
  for I := Low(Charsets) to High(Charsets) do
    if SameText(Charsets[I].Name, Ident) then
    begin
      Charset := Charsets[I].Value;
      Exit(True);
    end;
  Result := False;
end;

procedure GetCharsetValues(Proc: TGetStrProc);
var
  I: Integer;
begin
  for I := Low(Charsets) to High(Charsets) do Proc(Charsets[I].Name);
end;

function GetDefFontCharSet: TFontCharset;
begin
  Result := DEFAULT_CHARSET;
end;

{ ---------------------------------------------------------------- TGraphicsObject }

procedure TGraphicsObject.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

{ ---------------------------------------------------------------- TFont }

constructor TFont.Create;
begin
  inherited Create;
  FPixelsPerInch := ScreenLogPixels;
  FName := DefFontData.Name;
  FHeight := DefFontData.Height;
  if FHeight = 0 then FHeight := -MulDiv(8, FPixelsPerInch, 72);
  FPitch := DefFontData.Pitch;
  FStyle := DefFontData.Style;
  FCharset := DefFontData.Charset;
  FColor := clWindowText;
end;

destructor TFont.Destroy;
begin
  FreeHandle;
  inherited Destroy;
end;

procedure TFont.FreeHandle;
begin
  if FHandle <> 0 then DeleteObject(FHandle);
  FHandle := 0;
end;

procedure TFont.Changed;
begin
  FreeHandle;
  inherited Changed;
end;

procedure TFont.Assign(Source: TPersistent);
begin
  if Source is TFont then
  begin
    FName := TFont(Source).FName;
    FHeight := TFont(Source).FHeight;
    FPitch := TFont(Source).FPitch;
    FStyle := TFont(Source).FStyle;
    FCharset := TFont(Source).FCharset;
    FColor := TFont(Source).FColor;
    if FPixelsPerInch <> TFont(Source).FPixelsPerInch then
      FHeight := MulDiv(FHeight, FPixelsPerInch, TFont(Source).FPixelsPerInch);
    Changed;
    Exit;
  end;
  inherited Assign(Source);
end;

function TFont.GetHandle: HFont;
var
  LF: TLogFont;
begin
  if FHandle = 0 then
  begin
    FillChar(LF, SizeOf(LF), 0);
    LF.lfHeight := FHeight;
    if fsBold in FStyle then LF.lfWeight := FW_BOLD else LF.lfWeight := FW_NORMAL;
    LF.lfItalic := Ord(fsItalic in FStyle);
    LF.lfUnderline := Ord(fsUnderline in FStyle);
    LF.lfStrikeOut := Ord(fsStrikeOut in FStyle);
    LF.lfCharSet := FCharset;
    case FPitch of
      fpVariable: LF.lfPitchAndFamily := VARIABLE_PITCH;
      fpFixed: LF.lfPitchAndFamily := FIXED_PITCH;
    else
      LF.lfPitchAndFamily := DEFAULT_PITCH;
    end;
    StrPLCopy(LF.lfFaceName, FName, 31);
    FHandle := CreateFontIndirect(LF);
  end;
  Result := FHandle;
end;

procedure TFont.SetHandle(Value: HFont);
var
  LF: TLogFont;
begin
  if GetObject(Value, SizeOf(LF), @LF) = 0 then Exit;
  FHeight := LF.lfHeight;
  FName := StrPas(LF.lfFaceName);
  FStyle := [];
  if LF.lfWeight >= FW_BOLD then Include(FStyle, fsBold);
  if LF.lfItalic <> 0 then Include(FStyle, fsItalic);
  if LF.lfUnderline <> 0 then Include(FStyle, fsUnderline);
  if LF.lfStrikeOut <> 0 then Include(FStyle, fsStrikeOut);
  FCharset := LF.lfCharSet;
  Changed;
  FHandle := Value;
end;

function TFont.GetHeight: Integer;
begin
  Result := FHeight;
end;

procedure TFont.SetHeight(Value: Integer);
begin
  if FHeight <> Value then
  begin
    FHeight := Value;
    Changed;
  end;
end;

function TFont.GetName: TFontName;
begin
  Result := FName;
end;

procedure TFont.SetName(const Value: TFontName);
begin
  if (Value <> '') and (FName <> Value) then
  begin
    FName := Value;
    Changed;
  end;
end;

function TFont.GetPitch: TFontPitch;
begin
  Result := FPitch;
end;

procedure TFont.SetPitch(Value: TFontPitch);
begin
  if FPitch <> Value then
  begin
    FPitch := Value;
    Changed;
  end;
end;

function TFont.GetSize: Integer;
begin
  Result := -MulDiv(FHeight, 72, FPixelsPerInch);
end;

procedure TFont.SetSize(Value: Integer);
begin
  SetHeight(-MulDiv(Value, FPixelsPerInch, 72));
end;

function TFont.GetStyle: TFontStyles;
begin
  Result := FStyle;
end;

procedure TFont.SetStyle(Value: TFontStyles);
begin
  if FStyle <> Value then
  begin
    FStyle := Value;
    Changed;
  end;
end;

function TFont.GetCharset: TFontCharset;
begin
  Result := FCharset;
end;

procedure TFont.SetCharset(Value: TFontCharset);
begin
  if FCharset <> Value then
  begin
    FCharset := Value;
    Changed;
  end;
end;

procedure TFont.SetColor(Value: TColor);
begin
  if FColor <> Value then
  begin
    FColor := Value;
    inherited Changed;   { kleur verandert de lettertype-handle niet }
  end;
end;

{ ---------------------------------------------------------------- TPen }

constructor TPen.Create;
begin
  inherited Create;
  FColor := clBlack;
  FWidth := 1;
  FStyle := psSolid;
  FMode := pmCopy;
end;

destructor TPen.Destroy;
begin
  FreeHandle;
  inherited Destroy;
end;

procedure TPen.FreeHandle;
begin
  if FHandle <> 0 then DeleteObject(FHandle);
  FHandle := 0;
end;

procedure TPen.Assign(Source: TPersistent);
begin
  if Source is TPen then
  begin
    FColor := TPen(Source).FColor;
    FWidth := TPen(Source).FWidth;
    FStyle := TPen(Source).FStyle;
    FMode := TPen(Source).FMode;
    FreeHandle;
    Changed;
    Exit;
  end;
  inherited Assign(Source);
end;

function TPen.GetColor: TColor;
begin
  Result := FColor;
end;

procedure TPen.SetColor(Value: TColor);
begin
  if FColor <> Value then
  begin
    FColor := Value;
    FreeHandle;
    Changed;
  end;
end;

function TPen.GetHandle: HPen;
const
  PenStyles: array[TPenStyle] of Integer = (PS_SOLID, PS_DASH, PS_DOT, PS_DASHDOT,
    PS_DASHDOTDOT, PS_NULL, PS_INSIDEFRAME);
begin
  if FHandle = 0 then
    FHandle := CreatePen(PenStyles[FStyle], FWidth, ColorToRGB(FColor));
  Result := FHandle;
end;

procedure TPen.SetHandle(Value: HPen);
var
  LP: TLogPen;
begin
  if GetObject(Value, SizeOf(LP), @LP) <> 0 then
  begin
    FColor := LP.lopnColor;
    FWidth := LP.lopnWidth.X;
    FStyle := TPenStyle(Min(LP.lopnStyle, Ord(High(TPenStyle))));
  end;
  FreeHandle;
  FHandle := Value;
  Changed;
end;

procedure TPen.SetMode(Value: TPenMode);
begin
  if FMode <> Value then
  begin
    FMode := Value;
    Changed;
  end;
end;

function TPen.GetStyle: TPenStyle;
begin
  Result := FStyle;
end;

procedure TPen.SetStyle(Value: TPenStyle);
begin
  if FStyle <> Value then
  begin
    FStyle := Value;
    FreeHandle;
    Changed;
  end;
end;

function TPen.GetWidth: Integer;
begin
  Result := FWidth;
end;

procedure TPen.SetWidth(Value: Integer);
begin
  if (Value >= 0) and (FWidth <> Value) then
  begin
    FWidth := Value;
    FreeHandle;
    Changed;
  end;
end;

{ ---------------------------------------------------------------- TBrush }

constructor TBrush.Create;
begin
  inherited Create;
  FColor := clWhite;
  FStyle := bsSolid;
end;

destructor TBrush.Destroy;
begin
  FreeHandle;
  inherited Destroy;
end;

procedure TBrush.FreeHandle;
begin
  if FHandle <> 0 then DeleteObject(FHandle);
  FHandle := 0;
end;

procedure TBrush.Assign(Source: TPersistent);
begin
  if Source is TBrush then
  begin
    FColor := TBrush(Source).FColor;
    FStyle := TBrush(Source).FStyle;
    FBitmap := TBrush(Source).FBitmap;
    FreeHandle;
    Changed;
    Exit;
  end;
  inherited Assign(Source);
end;

function TBrush.GetBitmap: TBitmap;
begin
  Result := FBitmap;
end;

procedure TBrush.SetBitmap(Value: TBitmap);
begin
  FBitmap := Value;
  FreeHandle;
  Changed;
end;

function TBrush.GetColor: TColor;
begin
  Result := FColor;
end;

procedure TBrush.SetColor(Value: TColor);
begin
  if (FColor <> Value) or (FStyle = bsClear) then
  begin
    FColor := Value;
    if FStyle = bsClear then FStyle := bsSolid;
    FreeHandle;
    Changed;
  end;
end;

function TBrush.GetHandle: HBrush;
var
  LB: TLogBrush;
begin
  if FHandle = 0 then
  begin
    if FBitmap <> nil then
      FHandle := CreatePatternBrush(FBitmap.Handle)
    else
    begin
      LB.lbColor := ColorToRGB(FColor);
      LB.lbHatch := 0;
      case FStyle of
        bsSolid: LB.lbStyle := BS_SOLID;
        bsClear: LB.lbStyle := BS_HOLLOW;
      else
        LB.lbStyle := BS_HATCHED;
        LB.lbHatch := Ord(FStyle) - Ord(bsHorizontal);
      end;
      FHandle := CreateBrushIndirect(LB);
    end;
  end;
  Result := FHandle;
end;

procedure TBrush.SetHandle(Value: HBrush);
var
  LB: TLogBrush;
begin
  FreeHandle;
  if GetObject(Value, SizeOf(LB), @LB) <> 0 then
  begin
    FColor := LB.lbColor;
    case LB.lbStyle of
      BS_SOLID: FStyle := bsSolid;
      BS_HOLLOW: FStyle := bsClear;
    end;
  end;
  FHandle := Value;
  Changed;
end;

function TBrush.GetStyle: TBrushStyle;
begin
  Result := FStyle;
end;

procedure TBrush.SetStyle(Value: TBrushStyle);
begin
  if FStyle <> Value then
  begin
    FStyle := Value;
    FreeHandle;
    Changed;
  end;
end;

{ ---------------------------------------------------------------- TCanvas }

constructor TCanvas.Create;
begin
  inherited Create;
  FFont := TFont.Create;
  FFont.OnChange := FontChanged;
  FPen := TPen.Create;
  FPen.OnChange := PenChanged;
  FBrush := TBrush.Create;
  FBrush.OnChange := BrushChanged;
  FCopyMode := cmSrcCopy;
  State := [];
end;

destructor TCanvas.Destroy;
begin
  SetHandle(0);
  FFont.Free;
  FPen.Free;
  FBrush.Free;
  inherited Destroy;
end;

procedure TCanvas.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TCanvas.Changing;
begin
  if Assigned(FOnChanging) then FOnChanging(Self);
end;

procedure TCanvas.CreateHandle;
begin
end;

function TCanvas.HandleAllocated: Boolean;
begin
  Result := FHandle <> 0;
end;

procedure TCanvas.DeselectHandles;
begin
  if (FHandle <> 0) and (State - [csPenValid, csBrushValid, csFontValid] <> State) then
  begin
    SelectObject(FHandle, GetStockObject(BLACK_PEN));
    SelectObject(FHandle, GetStockObject(HOLLOW_BRUSH));
    SelectObject(FHandle, GetStockObject(SYSTEM_FONT));
    State := State - [csPenValid, csBrushValid, csFontValid];
  end;
end;

procedure TCanvas.SetHandle(Value: HDC);
begin
  if FHandle <> Value then
  begin
    if FHandle <> 0 then
    begin
      DeselectHandles;
      FPenPos := GetPenPos;
      FHandle := 0;
      Exclude(State, csHandleValid);
    end;
    if Value <> 0 then
    begin
      Include(State, csHandleValid);
      FHandle := Value;
      SetPenPos(FPenPos);
    end;
  end;
end;

function TCanvas.GetHandle: HDC;
begin
  Changing;
  RequiredState([csHandleValid, csFontValid, csPenValid, csBrushValid]);
  Result := FHandle;
end;

procedure TCanvas.RequiredState(ReqState: TCanvasState);
var
  Vereistestaat: TCanvasState;
begin
  Vereistestaat := ReqState - State;
  if Vereistestaat <> [] then
  begin
    if csHandleValid in Vereistestaat then
    begin
      CreateHandle;
      if FHandle = 0 then
        raise EInvalidOperation.Create('Canvas does not allow drawing');
    end;
    if csFontValid in Vereistestaat then CreateFont;
    if csPenValid in Vereistestaat then CreatePen;
    if csBrushValid in Vereistestaat then CreateBrush;
    State := State + Vereistestaat;
  end;
end;

procedure TCanvas.CreateFont;
begin
  SelectObject(FHandle, FFont.GetHandle);
  SetTextColor(FHandle, ColorToRGB(FFont.Color));
end;

procedure TCanvas.CreatePen;
const
  PenModes: array[TPenMode] of Word = (R2_BLACK, R2_WHITE, R2_NOP, R2_NOT, R2_COPYPEN,
    R2_NOTCOPYPEN, R2_MERGEPENNOT, R2_MASKPENNOT, R2_MERGENOTPEN, R2_MASKNOTPEN,
    R2_MERGEPEN, R2_NOTMERGEPEN, R2_MASKPEN, R2_NOTMASKPEN, R2_XORPEN, R2_NOTXORPEN);
begin
  SelectObject(FHandle, FPen.GetHandle);
  SetROP2(FHandle, PenModes[FPen.Mode]);
end;

procedure TCanvas.CreateBrush;
begin
  UnrealizeObject(FBrush.Handle);
  SelectObject(FHandle, FBrush.Handle);
  if FBrush.Style = bsSolid then
  begin
    SetBkColor(FHandle, ColorToRGB(FBrush.Color));
    SetBkMode(FHandle, OPAQUE);
  end
  else
  begin
    SetBkColor(FHandle, not ColorToRGB(FBrush.Color) and $FFFFFF);
    SetBkMode(FHandle, TRANSPARENT);
  end;
end;

procedure TCanvas.FontChanged(AFont: TObject);
begin
  if csFontValid in State then
  begin
    Exclude(State, csFontValid);
    SelectObject(FHandle, GetStockObject(SYSTEM_FONT));
  end;
end;

procedure TCanvas.PenChanged(APen: TObject);
begin
  if csPenValid in State then
  begin
    Exclude(State, csPenValid);
    SelectObject(FHandle, GetStockObject(BLACK_PEN));
  end;
end;

procedure TCanvas.BrushChanged(ABrush: TObject);
begin
  if csBrushValid in State then
  begin
    Exclude(State, csBrushValid);
    SelectObject(FHandle, GetStockObject(HOLLOW_BRUSH));
  end;
end;

procedure TCanvas.SetFont(Value: TFont);
begin
  FFont.Assign(Value);
end;

procedure TCanvas.SetPen(Value: TPen);
begin
  FPen.Assign(Value);
end;

procedure TCanvas.SetBrush(Value: TBrush);
begin
  FBrush.Assign(Value);
end;

function TCanvas.GetPenPos: TPoint;
begin
  RequiredState([csHandleValid]);
  GetCurrentPositionEx(FHandle, @Result);
end;

procedure TCanvas.SetPenPos(Value: TPoint);
begin
  MoveTo(Value.X, Value.Y);
end;

function TCanvas.GetPixel(X, Y: Integer): TColor;
begin
  RequiredState([csHandleValid]);
  Result := TColor(Windows.GetPixel(FHandle, X, Y));
end;

procedure TCanvas.SetPixel(X, Y: Integer; Value: TColor);
begin
  Changing;
  RequiredState([csHandleValid, csPenValid]);
  Windows.SetPixel(FHandle, X, Y, ColorToRGB(Value));
  Changed;
end;

function TCanvas.GetClipRect: TRect;
begin
  RequiredState([csHandleValid]);
  GetClipBox(FHandle, Result);
end;

function TCanvas.GetCanvasOrientation: TCanvasOrientation;
begin
  Result := coLeftToRight;
end;

procedure TCanvas.Arc(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer);
begin
  Changing;
  RequiredState([csHandleValid, csPenValid]);
  Windows.Ellipse(FHandle, X1, Y1, X2, Y2);   { benadering }
  Changed;
end;

procedure TCanvas.Chord(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Integer);
begin
  Changing;
  RequiredState([csHandleValid, csPenValid, csBrushValid]);
  Windows.Ellipse(FHandle, X1, Y1, X2, Y2);
  Changed;
end;

procedure TCanvas.Pie(X1, Y1, X2, Y2, X3, Y3, X4, Y4: Longint);
begin
  Changing;
  RequiredState([csHandleValid, csPenValid, csBrushValid]);
  Windows.Ellipse(FHandle, X1, Y1, X2, Y2);
  Changed;
end;

procedure TCanvas.BrushCopy(const Dest: TRect; Bitmap: TBitmap; const Source: TRect; Color: TColor);
var
  X, Y, SX, SY, W, H: Integer;
  C, T: TColor;
begin
  Changing;
  RequiredState([csHandleValid, csBrushValid]);
  T := ColorToRGB(Color);
  W := Dest.Right - Dest.Left;
  H := Dest.Bottom - Dest.Top;
  for Y := 0 to H - 1 do
    for X := 0 to W - 1 do
    begin
      SX := Source.Left + X * (Source.Right - Source.Left) div Max(W, 1);
      SY := Source.Top + Y * (Source.Bottom - Source.Top) div Max(H, 1);
      C := Bitmap.Canvas.Pixels[SX, SY];
      if C = T then C := ColorToRGB(FBrush.Color);
      Windows.SetPixel(FHandle, Dest.Left + X, Dest.Top + Y, C);
    end;
  Changed;
end;

procedure TCanvas.CopyRect(const Dest: TRect; Canvas: TCanvas; const Source: TRect);
begin
  Changing;
  RequiredState([csHandleValid, csFontValid, csBrushValid]);
  Canvas.RequiredState([csHandleValid, csBrushValid]);
  StretchBlt(FHandle, Dest.Left, Dest.Top, Dest.Right - Dest.Left, Dest.Bottom - Dest.Top,
    Canvas.FHandle, Source.Left, Source.Top, Source.Right - Source.Left,
    Source.Bottom - Source.Top, CopyMode);
  Changed;
end;

procedure TCanvas.Draw(X, Y: Integer; Graphic: TGraphic);
begin
  if (Graphic <> nil) and not Graphic.Empty then
  begin
    Changing;
    RequiredState([csHandleValid]);
    Graphic.Draw(Self, Rect(X, Y, X + Graphic.Width, Y + Graphic.Height));
    Changed;
  end;
end;

procedure TCanvas.StretchDraw(const Rect: TRect; Graphic: TGraphic);
begin
  if Graphic <> nil then
  begin
    Changing;
    RequiredState([csHandleValid]);
    Graphic.Draw(Self, Rect);
    Changed;
  end;
end;

procedure TCanvas.DrawFocusRect(const Rect: TRect);
begin
  Changing;
  RequiredState([csHandleValid, csBrushValid]);
  Windows.DrawFocusRect(FHandle, Rect);
  Changed;
end;

procedure TCanvas.Ellipse(X1, Y1, X2, Y2: Integer);
begin
  Changing;
  RequiredState([csHandleValid, csPenValid, csBrushValid]);
  Windows.Ellipse(FHandle, X1, Y1, X2, Y2);
  Changed;
end;

procedure TCanvas.Ellipse(const Rect: TRect);
begin
  Ellipse(Rect.Left, Rect.Top, Rect.Right, Rect.Bottom);
end;

procedure TCanvas.FillRect(const Rect: TRect);
begin
  Changing;
  RequiredState([csHandleValid, csBrushValid]);
  Windows.FillRect(FHandle, Rect, Brush.GetHandle);
  Changed;
end;

procedure TCanvas.FloodFill(X, Y: Integer; Color: TColor; FillStyle: TFillStyle);
const
  FillStyles: array[TFillStyle] of Word = (1, 0);  { FLOODFILLSURFACE, FLOODFILLBORDER }
begin
  Changing;
  RequiredState([csHandleValid, csBrushValid]);
  Windows.ExtFloodFill(FHandle, X, Y, ColorToRGB(Color), FillStyles[FillStyle]);
  Changed;
end;

procedure TCanvas.FrameRect(const Rect: TRect);
begin
  Changing;
  RequiredState([csHandleValid, csBrushValid]);
  Windows.FrameRect(FHandle, Rect, Brush.GetHandle);
  Changed;
end;

procedure TCanvas.LineTo(X, Y: Integer);
begin
  Changing;
  RequiredState([csHandleValid, csPenValid, csBrushValid]);
  Windows.LineTo(FHandle, X, Y);
  Changed;
end;

procedure TCanvas.Lock;
begin
  Inc(FLockCount);
end;

procedure TCanvas.Unlock;
begin
  Dec(FLockCount);
end;

function TCanvas.TryLock: Boolean;
begin
  Inc(FLockCount);
  Result := True;
end;

procedure TCanvas.MoveTo(X, Y: Integer);
begin
  RequiredState([csHandleValid]);
  Windows.MoveToEx(FHandle, X, Y, nil);
end;

procedure TCanvas.Polygon(const Points: array of TPoint);
begin
  Changing;
  RequiredState([csHandleValid, csPenValid, csBrushValid]);
  if Length(Points) > 0 then
    Windows.Polygon(FHandle, Points[0], Length(Points));
  Changed;
end;

procedure TCanvas.Polyline(const Points: array of TPoint);
begin
  Changing;
  RequiredState([csHandleValid, csPenValid, csBrushValid]);
  if Length(Points) > 0 then
    Windows.Polyline(FHandle, Points[0], Length(Points));
  Changed;
end;

procedure TCanvas.PolyBezier(const Points: array of TPoint);
begin
  Polyline(Points);
end;

procedure TCanvas.PolyBezierTo(const Points: array of TPoint);
begin
  Polyline(Points);
end;

procedure TCanvas.Rectangle(X1, Y1, X2, Y2: Integer);
begin
  Changing;
  RequiredState([csHandleValid, csBrushValid, csPenValid]);
  Windows.Rectangle(FHandle, X1, Y1, X2, Y2);
  Changed;
end;

procedure TCanvas.Rectangle(const Rect: TRect);
begin
  Rectangle(Rect.Left, Rect.Top, Rect.Right, Rect.Bottom);
end;

procedure TCanvas.Refresh;
begin
  DeselectHandles;
end;

procedure TCanvas.RoundRect(X1, Y1, X2, Y2, X3, Y3: Integer);
begin
  Changing;
  RequiredState([csHandleValid, csBrushValid, csPenValid]);
  Windows.RoundRect(FHandle, X1, Y1, X2, Y2, X3, Y3);
  Changed;
end;

function TCanvas.TextExtent(const Text: string): TSize;
begin
  RequiredState([csHandleValid, csFontValid]);
  Result.cX := 0;
  Result.cY := 0;
  Windows.GetTextExtentPoint32(FHandle, PAnsiChar(Text), Length(Text), Result);
end;

function TCanvas.TextHeight(const Text: string): Integer;
begin
  Result := TextExtent(Text).cY;
end;

function TCanvas.TextWidth(const Text: string): Integer;
begin
  Result := TextExtent(Text).cX;
end;

procedure TCanvas.TextOut(X, Y: Integer; const Text: string);
begin
  Changing;
  RequiredState([csHandleValid, csFontValid, csBrushValid]);
  Windows.ExtTextOut(FHandle, X, Y, FTextFlags, nil, PAnsiChar(Text), Length(Text), nil);
  MoveTo(X + TextWidth(Text), Y);
  Changed;
end;

procedure TCanvas.TextRect(Rect: TRect; X, Y: Integer; const Text: string);
var
  Opties: Longint;
begin
  Changing;
  RequiredState([csHandleValid, csFontValid, csBrushValid]);
  Opties := ETO_CLIPPED or FTextFlags;
  if Brush.Style <> bsClear then Opties := Opties or ETO_OPAQUE;
  Windows.ExtTextOut(FHandle, X, Y, Opties, @Rect, PAnsiChar(Text), Length(Text), nil);
  Changed;
end;

{ ---------------------------------------------------------------- TGraphic }

constructor TGraphic.Create;
begin
  inherited Create;
end;

procedure TGraphic.Changed(Sender: TObject);
begin
  FModified := True;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TGraphic.DefineProperties(Filer: TFiler);

  function DoSchrijf: Boolean;
  begin
    if Filer.Ancestor <> nil then
      Result := not (Filer.Ancestor is TGraphic) or not Equals(TGraphic(Filer.Ancestor))
    else
      Result := not Empty;
  end;

begin
  Filer.DefineBinaryProperty('Data', ReadData, WriteData, DoSchrijf);
end;

function TGraphic.Equals(Graphic: TGraphic): Boolean;
var
  A, B: TMemoryStream;
begin
  Result := (Graphic <> nil) and (ClassType = Graphic.ClassType);
  if Empty or Graphic.Empty then
  begin
    Result := Empty and Graphic.Empty;
    Exit;
  end;
  if Result then
  begin
    A := TMemoryStream.Create;
    B := TMemoryStream.Create;
    try
      WriteData(A);
      Graphic.WriteData(B);
      Result := (A.Size = B.Size) and CompareMem(A.Memory, B.Memory, A.Size);
    finally
      A.Free;
      B.Free;
    end;
  end;
end;

function TGraphic.GetPalette: HPALETTE;
begin
  Result := 0;
end;

function TGraphic.GetTransparent: Boolean;
begin
  Result := FTransparent;
end;

procedure TGraphic.SetTransparent(Value: Boolean);
begin
  if Value <> FTransparent then
  begin
    FTransparent := Value;
    Changed(Self);
  end;
end;

procedure TGraphic.SetPalette(Value: HPALETTE);
begin
end;

procedure TGraphic.SetModified(Value: Boolean);
begin
  if Value then Changed(Self) else FModified := False;
end;

procedure TGraphic.Progress(Sender: TObject; Stage: TProgressStage; PercentDone: Byte;
  RedrawNow: Boolean; const R: TRect; const Msg: string);
begin
  if Assigned(FOnProgress) then FOnProgress(Sender, Stage, PercentDone, RedrawNow, R, Msg);
end;

procedure TGraphic.ReadData(Stream: TStream);
begin
  LoadFromStream(Stream);
end;

procedure TGraphic.WriteData(Stream: TStream);
begin
  SaveToStream(Stream);
end;

procedure TGraphic.LoadFromFile(const Filename: string);
var
  Stroom: TStream;
begin
  Stroom := TFileStream.Create(ZMResolvePath(Filename), fmOpenRead or fmShareDenyWrite);
  try
    LoadFromStream(Stroom);
  finally
    Stroom.Free;
  end;
end;

procedure TGraphic.SaveToFile(const Filename: string);
var
  Stroom: TStream;
begin
  Stroom := TFileStream.Create(ZMWritePath(ZMResolvePath(Filename)), fmCreate);
  try
    SaveToStream(Stroom);
  finally
    Stroom.Free;
  end;
end;

{ ---------------------------------------------------------------- TPicture }

type
  TFileFormat = record
    Ext, Desc: string;
    Cls: TGraphicClass;
  end;

var
  FileFormats: array of TFileFormat;

class procedure TPicture.RegisterFileFormat(const AExtension, ADescription: string; AGraphicClass: TGraphicClass);
begin
  SetLength(FileFormats, Length(FileFormats) + 1);
  FileFormats[High(FileFormats)].Ext := LowerCase(AExtension);
  FileFormats[High(FileFormats)].Desc := ADescription;
  FileFormats[High(FileFormats)].Cls := AGraphicClass;
  Classes.RegisterClass(AGraphicClass);
end;

class procedure TPicture.UnregisterGraphicClass(AClass: TGraphicClass);
var
  I: Integer;
begin
  for I := 0 to High(FileFormats) do
    if FileFormats[I].Cls = AClass then FileFormats[I].Cls := nil;
end;

class function TPicture.SupportsClipboardFormat(AFormat: Word): Boolean;
begin
  Result := AFormat in [CF_BITMAP, CF_DIB];
end;

function FindGraphicClassName(const Naam: string): TGraphicClass;
var
  I: Integer;
  C: TPersistentClass;
begin
  for I := 0 to High(FileFormats) do
    if (FileFormats[I].Cls <> nil) and SameText(FileFormats[I].Cls.ClassName, Naam) then
      Exit(FileFormats[I].Cls);
  C := GetClass(Naam);
  if (C <> nil) and C.InheritsFrom(TGraphic) then
    Result := TGraphicClass(C)
  else
    Result := nil;
end;

constructor TPicture.Create;
begin
  inherited Create;
end;

destructor TPicture.Destroy;
begin
  FGraphic.Free;
  inherited Destroy;
end;

procedure TPicture.AssignTo(Dest: TPersistent);
begin
  if Graphic is Dest.ClassType then
    Dest.Assign(Graphic)
  else
    inherited AssignTo(Dest);
end;

procedure TPicture.ForceType(GraphicType: TGraphicClass);
begin
  if not (FGraphic is GraphicType) then
  begin
    FGraphic.Free;
    FGraphic := nil;
    FGraphic := GraphicType.Create;
    FGraphic.OnChange := Changed;
    FGraphic.OnProgress := Progress;
    Changed(Self);
  end;
end;

function TPicture.GetBitmap: TBitmap;
begin
  ForceType(TBitmap);
  Result := TBitmap(FGraphic);
end;

function TPicture.GetIcon: TIcon;
begin
  ForceType(TIcon);
  Result := TIcon(FGraphic);
end;

function TPicture.GetMetafile: TMetafile;
begin
  ForceType(TMetafile);
  Result := TMetafile(FGraphic);
end;

procedure TPicture.SetBitmap(Value: TBitmap);
begin
  SetGraphic(Value);
end;

procedure TPicture.SetIcon(Value: TIcon);
begin
  SetGraphic(Value);
end;

procedure TPicture.SetMetafile(Value: TMetafile);
begin
  SetGraphic(Value);
end;

procedure TPicture.SetGraphic(Value: TGraphic);
var
  Nieuwegrafiek: TGraphic;
begin
  Nieuwegrafiek := nil;
  if Value <> nil then
  begin
    Nieuwegrafiek := TGraphicClass(Value.ClassType).Create;
    Nieuwegrafiek.Assign(Value);
    Nieuwegrafiek.OnChange := Changed;
    Nieuwegrafiek.OnProgress := Progress;
  end;
  try
    FGraphic.Free;
    FGraphic := Nieuwegrafiek;
    Changed(Self);
  except
    Nieuwegrafiek.Free;
    raise;
  end;
end;

function TPicture.GetWidth: Integer;
begin
  if FGraphic <> nil then Result := FGraphic.Width else Result := 0;
end;

function TPicture.GetHeight: Integer;
begin
  if FGraphic <> nil then Result := FGraphic.Height else Result := 0;
end;

procedure TPicture.LoadFromFile(const Filename: string);
var
  Extensie: string;
  I: Integer;
  Grafischklasse: TGraphicClass;
  Nieuwegrafiek: TGraphic;
begin
  Extensie := LowerCase(ExtractFileExt(Filename));
  Delete(Extensie, 1, 1);
  Grafischklasse := nil;
  for I := 0 to High(FileFormats) do
    if FileFormats[I].Ext = Extensie then Grafischklasse := FileFormats[I].Cls;
  if Grafischklasse = nil then
    raise EInvalidGraphic.CreateFmt('Unknown picture file extension (.%s)', [Extensie]);
  Nieuwegrafiek := Grafischklasse.Create;
  try
    Nieuwegrafiek.OnProgress := Progress;
    Nieuwegrafiek.LoadFromFile(Filename);
  except
    Nieuwegrafiek.Free;
    raise;
  end;
  FGraphic.Free;
  FGraphic := Nieuwegrafiek;
  FGraphic.OnChange := Changed;
  Changed(Self);
end;

procedure TPicture.SaveToFile(const Filename: string);
begin
  if FGraphic <> nil then FGraphic.SaveToFile(Filename);
end;

procedure TPicture.Assign(Source: TPersistent);
begin
  if Source = nil then
    SetGraphic(nil)
  else if Source is TPicture then
    SetGraphic(TPicture(Source).Graphic)
  else if Source is TGraphic then
    SetGraphic(TGraphic(Source))
  else
    inherited Assign(Source);
end;

procedure TPicture.Changed(Sender: TObject);
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TPicture.Progress(Sender: TObject; Stage: TProgressStage; PercentDone: Byte;
  RedrawNow: Boolean; const R: TRect; const Msg: string);
begin
  if Assigned(FOnProgress) then FOnProgress(Sender, Stage, PercentDone, RedrawNow, R, Msg);
end;

procedure TPicture.ReadData(Stream: TStream);
var
  Klassenaam: string[63];
  Nieuwegrafiek: TGraphic;
  Grafischklasse: TGraphicClass;
begin
  Stream.Read(Klassenaam[0], 1);
  Stream.Read(Klassenaam[1], Integer(Klassenaam[0]));
  Grafischklasse := FindGraphicClassName(Klassenaam);
  Nieuwegrafiek := nil;
  if Grafischklasse <> nil then
  begin
    Nieuwegrafiek := Grafischklasse.Create;
    try
      Nieuwegrafiek.ReadData(Stream);
    except
      Nieuwegrafiek.Free;
      raise;
    end;
  end;
  FGraphic.Free;
  FGraphic := Nieuwegrafiek;
  if Nieuwegrafiek <> nil then
  begin
    Nieuwegrafiek.OnChange := Changed;
    Nieuwegrafiek.OnProgress := Progress;
  end;
  Changed(Self);
end;

procedure TPicture.WriteData(Stream: TStream);
var
  Klassenaam: string[63];
begin
  if Graphic <> nil then
    Klassenaam := Graphic.ClassName
  else
    Klassenaam := '';
  Stream.Write(Klassenaam, Length(Klassenaam) + 1);
  if Graphic <> nil then Graphic.WriteData(Stream);
end;

procedure TPicture.DefineProperties(Filer: TFiler);

  function DoSchrijf: Boolean;
  begin
    if Filer.Ancestor <> nil then
    begin
      Result := True;
      if Filer.Ancestor is TPicture then
        Result := not ((Graphic = TPicture(Filer.Ancestor).Graphic) or
          ((Graphic <> nil) and (TPicture(Filer.Ancestor).Graphic <> nil) and
          Graphic.Equals(TPicture(Filer.Ancestor).Graphic)));
    end
    else
      Result := Graphic <> nil;
  end;

begin
  Filer.DefineBinaryProperty('Data', ReadData, WriteData, DoSchrijf);
end;

{ ---------------------------------------------------------------- TMetafile (tijdelijke aanduiding) }

constructor TMetafile.Create;
begin
  inherited Create;
  FData := TMemoryStream.Create;
end;

destructor TMetafile.Destroy;
begin
  FData.Free;
  inherited Destroy;
end;

procedure TMetafile.Draw(ACanvas: TCanvas; const Rect: TRect);
begin
end;

function TMetafile.GetEmpty: Boolean;
begin
  Result := FData.Size = 0;
end;

function TMetafile.GetHeight: Integer;
begin
  Result := FHeight;
end;

function TMetafile.GetWidth: Integer;
begin
  Result := FWidth;
end;

procedure TMetafile.SetHeight(Value: Integer);
begin
  FHeight := Value;
end;

procedure TMetafile.SetWidth(Value: Integer);
begin
  FWidth := Value;
end;

procedure TMetafile.LoadFromStream(Stream: TStream);
begin
  FData.Clear;
  FData.CopyFrom(Stream, Stream.Size - Stream.Position);
end;

procedure TMetafile.SaveToStream(Stream: TStream);
begin
  FData.Position := 0;
  Stream.CopyFrom(FData, FData.Size);
end;

procedure TMetafile.LoadFromClipboardFormat(AFormat: Word; AData: THandle; APalette: HPALETTE);
begin
end;

procedure TMetafile.SaveToClipboardFormat(var AFormat: Word; var AData: THandle; var APalette: HPALETTE);
begin
end;

{ ---------------------------------------------------------------- TBitmapCanvas }

constructor TBitmapCanvas.Create(ABitmap: TBitmap);
begin
  inherited Create;
  FBitmap := ABitmap;
end;

destructor TBitmapCanvas.Destroy;
begin
  FreeContext;
  inherited Destroy;
end;

procedure TBitmapCanvas.FreeContext;
var
  H: HDC;
begin
  if FHandle <> 0 then
  begin
    H := FHandle;
    if FOldBitmap <> 0 then SelectObject(H, FOldBitmap);
    if FOldPalette <> 0 then SelectPalette(H, FOldPalette, True);
    SetHandle(0);
    DeleteDC(H);
    FOldBitmap := 0;
    FOldPalette := 0;
  end;
end;

procedure TBitmapCanvas.CreateHandle;
var
  H: HDC;
begin
  if FBitmap <> nil then
  begin
    H := CreateCompatibleDC(0);
    FOldBitmap := SelectObject(H, FBitmap.GetHandle);
    if FBitmap.FPalette <> 0 then
      FOldPalette := SelectPalette(H, FBitmap.FPalette, True);
    Handle := H;
  end;
end;

{ ---------------------------------------------------------------- TBitmap }

function BPPOf(PF: TPixelFormat): Integer;
begin
  case PF of
    pf1bit: Result := 1;
    pf4bit: Result := 4;
    pf8bit: Result := 8;
    pf15bit, pf16bit: Result := 16;
    pf24bit: Result := 24;
    pf32bit: Result := 32;
  else
    Result := 32;
  end;
end;

function PFOf(BPP: Integer): TPixelFormat;
begin
  case BPP of
    1: Result := pf1bit;
    4: Result := pf4bit;
    8: Result := pf8bit;
    16: Result := pf15bit;
    24: Result := pf24bit;
    32: Result := pf32bit;
  else
    Result := pfCustom;
  end;
end;

constructor TBitmap.Create;
begin
  inherited Create;
  FTransparentColor := clDefault;
  FPixelFormat := pfDevice;
  FHandleType := bmDDB;   { zoals Delphi: een nieuwe bitmap is een DDB totdat een pixelformaat of DIB wordt gevraagd }
end;

destructor TBitmap.Destroy;
begin
  FreeImage;
  FCanvas.Free;
  inherited Destroy;
end;

function TBitmap.Img: Pointer;
begin
  if (FImgHandle <> FHandle) or (FHandle = 0) then
  begin
    FImg := GdiBitmap(FHandle);
    FImgHandle := FHandle;
  end;
  Result := FImg;
end;

procedure TBitmap.ReselectInCanvas;
begin
  if (FCanvas <> nil) then
    TBitmapCanvas(FCanvas).FreeContext;
end;

procedure TBitmap.NewImage(AWidth, AHeight: Integer; ABPP: Integer; CopyOld: Boolean);
var
  Rijbuffer, LUT: array of LongWord;
  Oud, Nieuw: TZMBitmap;
  X, Y, W, H, I: Integer;
  Oudehoogte: HBITMAP;
begin
  Oud := TZMBitmap(Img);
  Nieuw := TZMBitmap.Create(AWidth, AHeight, ABPP);
  if (Oud <> nil) and (Oud.BPP <= 8) and (ABPP <= 8) and (Oud.NumColors > 0) then
  begin
    for I := 0 to Min(Oud.NumColors, Nieuw.NumColors) - 1 do Nieuw.Colors[I] := Oud.Colors[I];
    Nieuw.ColorsChanged;
  end
  else if (ABPP = 8) and (FPalette <> 0) then
  begin
    for I := 0 to Min(GdiPalette(FPalette).Count, 256) - 1 do
      with GdiPalette(FPalette).Entries[I] do Nieuw.Colors[I] := (peRed shl 16) or (peGreen shl 8) or peBlue;
    Nieuw.ColorsChanged;
  end;
  if ABPP > 1 then
    { nieuwe DIB's beginnen wit, zoals de TBitmap van Delphi (Canvas-kwast); dat wordt hier niet gedaan:
      Windows-DIB-secties beginnen op nul (zwart). }
  ;
  if CopyOld and (Oud <> nil) then
  begin
    W := Min(Oud.Width, AWidth);
    H := Min(Oud.Height, AHeight);
    if (W > 0) and (H > 0) then
    begin
      if Oud.BPP = ABPP then
      begin
        { zelfde formaat: kopieer de rijen (behoudt de indices van palet-bitmaps) }
        for Y := 0 to H - 1 do
          if (ABPP mod 8 = 0) then
            Move(Oud.RowPtr(Y)^, Nieuw.RowPtr(Y)^, W * (ABPP div 8))
          else
            for X := 0 to W - 1 do Nieuw.SetNative(X, Y, Oud.GetNative(X, Y));
      end
      else
      begin
        SetLength(Rijbuffer, W);
        for Y := 0 to H - 1 do
        begin
          ZMReadRow(Oud, Y, 0, W, @Rijbuffer[0]);
          if Oud.BPP <= 8 then
          begin
            if Length(LUT) = 0 then
            begin
              SetLength(LUT, 256);
              for X := 0 to 255 do LUT[X] := Nieuw.RGBToNative(Oud.NativeToRGB(X));
            end;
            for X := 0 to W - 1 do Rijbuffer[X] := LUT[Rijbuffer[X] and $FF];
          end
          else
            for X := 0 to W - 1 do Rijbuffer[X] := Nieuw.RGBToNative(Oud.NativeToRGB(Rijbuffer[X]));
          ZMWriteRow(Nieuw, Y, 0, W, @Rijbuffer[0]);
        end;
      end;
    end;
  end;
  Nieuw.IsDIB := (FHandleType = bmDIB) or (FPixelFormat <> pfDevice) or (ABPP <> 32);
  ReselectInCanvas;
  Oudehoogte := FHandle;
  FHandle := Nieuw.Handle;
  FImgHandle := 0;
  if Oudehoogte <> 0 then DeleteObject(Oudehoogte);
  if FMaskHandle <> 0 then
  begin
    DeleteObject(FMaskHandle);
    FMaskHandle := 0;
  end;
  FMonochrome := ABPP = 1;
end;

function TBitmap.GetCanvas: TCanvas;
begin
  if FCanvas = nil then
  begin
    FCanvas := TBitmapCanvas.Create(Self);
    FCanvas.OnChange := Changed;
  end;
  Result := FCanvas;
end;

function TBitmap.GetHandle: HBITMAP;
begin
  if FHandle = 0 then NewImage(0, 0, BPPOf(FPixelFormat), False);
  Result := FHandle;
end;

procedure TBitmap.SetHandle(Value: HBITMAP);
var
  B: TZMBitmap;
begin
  if FHandle = Value then Exit;
  ReselectInCanvas;
  if FHandle <> 0 then DeleteObject(FHandle);
  FHandle := Value;
  FImgHandle := 0;
  B := TZMBitmap(Img);
  if B <> nil then
  begin
    FPixelFormat := PFOf(B.BPP);
    FMonochrome := B.BPP = 1;
  end;
  Changed(Self);
end;

function TBitmap.HandleAllocated: Boolean;
begin
  Result := FHandle <> 0;
end;

function TBitmap.GetHandleType: TBitmapHandleType;
begin
  Result := FHandleType;
end;

procedure TBitmap.SetHandleType(Value: TBitmapHandleType);
begin
  { de pixels blijven zoals ze zijn; alleen de DIB/DDB-aard verandert (dat is van belang voor
    tekst-anti-aliasing, zie ZMGdi.GdiUseAA) }
  FHandleType := Value;
  if Img <> nil then
    TZMBitmap(Img).IsDIB := (Value = bmDIB) or (FPixelFormat <> pfDevice);
end;

function TBitmap.GetMaskHandle: HBITMAP;
var
  B, M: TZMBitmap;
  X, Y: Integer;
  T: LongWord;
begin
  if FMaskHandle = 0 then
  begin
    B := TZMBitmap(Img);
    if B = nil then Exit(0);
    M := TZMBitmap.Create(B.Width, B.Height, 1);
    T := ColorRefToRGB(ColorToRGB(GetTransparentColor) and $FFFFFF);
    for Y := 0 to B.Height - 1 do
      for X := 0 to B.Width - 1 do
        if B.NativeToRGB(B.GetNative(X, Y)) = T then M.SetNative(X, Y, 1);
    FMaskHandle := M.Handle;
  end;
  Result := FMaskHandle;
end;

procedure TBitmap.SetMaskHandle(Value: HBITMAP);
begin
  if FMaskHandle <> 0 then DeleteObject(FMaskHandle);
  FMaskHandle := Value;
end;

function TBitmap.ReleaseMaskHandle: HBITMAP;
begin
  Result := GetMaskHandle;
  FMaskHandle := 0;
end;

function TBitmap.GetMonochrome: Boolean;
begin
  Result := FMonochrome;
end;

procedure TBitmap.SetMonochrome(Value: Boolean);
var
  B: TZMBitmap;
begin
  if Value = FMonochrome then Exit;
  B := TZMBitmap(Img);
  if Value then
  begin
    if B <> nil then NewImage(B.Width, B.Height, 1, True) else FMonochrome := True;
    FPixelFormat := pf1bit;
  end
  else
  begin
    if B <> nil then NewImage(B.Width, B.Height, 32, True);
    FMonochrome := False;
    FPixelFormat := pfDevice;
  end;
  Changed(Self);
end;

function TBitmap.GetPixelFormat: TPixelFormat;
begin
  Result := FPixelFormat;
end;

procedure TBitmap.SetPixelFormat(Value: TPixelFormat);
var
  B: TZMBitmap;
begin
  if (Value = FPixelFormat) and (FHandle <> 0) then Exit;
  if Value = pfCustom then Exit;
  if Value <> pfDevice then FHandleType := bmDIB;
  B := TZMBitmap(Img);
  if B <> nil then
    NewImage(B.Width, B.Height, BPPOf(Value), True)
  else
    NewImage(0, 0, BPPOf(Value), False);
  FPixelFormat := Value;
  Changed(Self);
end;

function TBitmap.GetScanline(Row: Integer): Pointer;
var
  B: TZMBitmap;
begin
  B := TZMBitmap(Img);
  if (B = nil) or (Row < 0) or (Row >= B.Height) then
    raise EInvalidGraphicOperation.Create('Scan line index out of range');
  Result := B.RowPtr(Row);
end;

function TBitmap.GetTransparentColor: TColor;
var
  B: TZMBitmap;
begin
  if FTransparentColor = clDefault then
  begin
    B := TZMBitmap(Img);
    if (B = nil) or (B.Height = 0) or (B.Width = 0) then Exit(clDefault);
    Result := TColor(RGBToColorRef(B.NativeToRGB(B.GetNative(0, B.Height - 1)))) or $02000000;
  end
  else
    Result := ColorToRGB(FTransparentColor) or $02000000;
end;

procedure TBitmap.SetTransparentColor(Value: TColor);
begin
  if Value <> FTransparentColor then
  begin
    if Value = clDefault then FTransparentMode := tmAuto else FTransparentMode := tmFixed;
    FTransparentColor := Value;
    if FMaskHandle <> 0 then
    begin
      DeleteObject(FMaskHandle);
      FMaskHandle := 0;
    end;
    Changed(Self);
  end;
end;

procedure TBitmap.SetTransparentMode(Value: TTransparentMode);
begin
  if Value <> FTransparentMode then
  begin
    if Value = tmAuto then SetTransparentColor(clDefault)
    else SetTransparentColor(GetTransparentColor and $FFFFFF);
  end;
end;

procedure TBitmap.Changed(Sender: TObject);
begin
  if FMaskHandle <> 0 then
  begin
    DeleteObject(FMaskHandle);
    FMaskHandle := 0;
  end;
  inherited Changed(Sender);
end;

procedure TBitmap.Draw(ACanvas: TCanvas; const Rect: TRect);
var
  B: TZMBitmap;
  DC: HDC;
  D: TZMDC;
  X, Y, W, H, SX, SY: Integer;
  T: LongWord;
  Oudemodus: Integer;
begin
  B := TZMBitmap(Img);
  if (B = nil) or (B.Width = 0) or (B.Height = 0) then Exit;
  DC := ACanvas.Handle;
  D := GdiDC(DC);
  if D = nil then Exit;
  if Transparent then
  begin
    T := ColorRefToRGB(GetTransparentColor and $FFFFFF);
    W := Rect.Right - Rect.Left;
    H := Rect.Bottom - Rect.Top;
    if (W <= 0) or (H <= 0) then Exit;
    for Y := 0 to H - 1 do
    begin
      SY := Y * B.Height div H;
      for X := 0 to W - 1 do
      begin
        SX := X * B.Width div W;
        if B.NativeToRGB(B.GetNative(SX, SY)) <> T then
          GdiSetPixel(D, Rect.Left + X, Rect.Top + Y, RGBToColorRef(B.NativeToRGB(B.GetNative(SX, SY))));
      end;
    end;
  end
  else
  begin
    Oudemodus := SetStretchBltMode(DC, COLORONCOLOR);
    GdiBltBitmap(D, Rect.Left, Rect.Top, Rect.Right - Rect.Left, Rect.Bottom - Rect.Top, B,
      $FFFFFF, 0, 0, B.Width, B.Height, ACanvas.CopyMode, True);
    SetStretchBltMode(DC, Oudemodus);
  end;
end;

function TBitmap.GetEmpty: Boolean;
var
  B: TZMBitmap;
begin
  B := TZMBitmap(Img);
  Result := (B = nil) or (B.Width = 0) or (B.Height = 0);
end;

function TBitmap.GetHeight: Integer;
var
  B: TZMBitmap;
begin
  B := TZMBitmap(Img);
  if B = nil then Result := 0 else Result := B.Height;
end;

function TBitmap.GetWidth: Integer;
var
  B: TZMBitmap;
begin
  B := TZMBitmap(Img);
  if B = nil then Result := 0 else Result := B.Width;
end;

procedure TBitmap.SetHeight(Value: Integer);
begin
  if Value < 0 then Value := 0;
  if Value <> GetHeight then
  begin
    NewImage(GetWidth, Value, BPPOf(FPixelFormat), True);
    Changed(Self);
  end;
end;

procedure TBitmap.SetWidth(Value: Integer);
begin
  if Value < 0 then Value := 0;
  if Value <> GetWidth then
  begin
    NewImage(Value, GetHeight, BPPOf(FPixelFormat), True);
    Changed(Self);
  end;
end;

function TBitmap.GetPalette: HPALETTE;
var
  B: TZMBitmap;
  LP: TMaxLogPalette;
  I: Integer;
begin
  B := TZMBitmap(Img);
  if (B = nil) or (B.BPP > 8) then
  begin
    Result := FPalette;
    Exit;
  end;
  if (FPalette = 0) or (FPaletteStamp <> B.ColorStamp) then
  begin
    if FPalette <> 0 then
    begin
      if FCanvas <> nil then TBitmapCanvas(FCanvas).FreeContext;
      DeleteObject(FPalette);
    end;
    LP.palVersion := $300;
    LP.palNumEntries := B.NumColors;
    for I := 0 to B.NumColors - 1 do
    begin
      LP.palPalEntry[I].peRed := (B.Colors[I] shr 16) and $FF;
      LP.palPalEntry[I].peGreen := (B.Colors[I] shr 8) and $FF;
      LP.palPalEntry[I].peBlue := B.Colors[I] and $FF;
      LP.palPalEntry[I].peFlags := 0;
    end;
    FPalette := CreatePalette(PLogPalette(@LP)^);
    FPaletteStamp := B.ColorStamp;
  end;
  Result := FPalette;
end;

procedure TBitmap.SetPalette(Value: HPALETTE);
var
  B: TZMBitmap;
  P: TZMPalette;
  I: Integer;
begin
  if Value = FPalette then Exit;
  B := TZMBitmap(Img);
  P := GdiPalette(Value);
  if FCanvas <> nil then TBitmapCanvas(FCanvas).FreeContext;
  if (FPalette <> 0) and (FPalette <> Value) then DeleteObject(FPalette);
  FPalette := Value;
  if (B <> nil) and (B.BPP <= 8) and (P <> nil) then
  begin
    for I := 0 to Min(P.Count, B.NumColors) - 1 do
      with P.Entries[I] do B.Colors[I] := (peRed shl 16) or (peGreen shl 8) or peBlue;
    B.ColorsChanged;
    FPaletteStamp := B.ColorStamp;
  end;
  PaletteModified := True;
  Changed(Self);
end;

function TBitmap.ReleasePalette: HPALETTE;
begin
  Result := GetPalette;
  FPalette := 0;
end;

function TBitmap.ReleaseHandle: HBITMAP;
begin
  ReselectInCanvas;
  Result := FHandle;
  FHandle := 0;
  FImgHandle := 0;
end;

procedure TBitmap.Dormant;
begin
end;

procedure TBitmap.FreeImage;
begin
  ReselectInCanvas;
  if FHandle <> 0 then DeleteObject(FHandle);
  FHandle := 0;
  FImgHandle := 0;
  if FMaskHandle <> 0 then DeleteObject(FMaskHandle);
  FMaskHandle := 0;
  if FPalette <> 0 then DeleteObject(FPalette);
  FPalette := 0;
end;

procedure TBitmap.Assign(Source: TPersistent);
var
  S, B: TZMBitmap;
begin
  if (Source = nil) or (Source is TBitmap) then
  begin
    FreeImage;
    if Source <> nil then
    begin
      S := TZMBitmap(TBitmap(Source).Img);
      if S <> nil then
      begin
        B := TZMBitmap.Create(S.Width, S.Height, S.BPP);
        B.IsDIB := S.IsDIB;
        if (S.Bits <> nil) then Move(S.Bits^, B.Bits^, S.Stride * S.Height);
        B.NumColors := S.NumColors;
        B.Colors := S.Colors;
        B.ColorsChanged;
        FHandle := B.Handle;
        FImgHandle := 0;
      end;
      FPixelFormat := TBitmap(Source).FPixelFormat;
      FMonochrome := TBitmap(Source).FMonochrome;
      FHandleType := TBitmap(Source).FHandleType;
      FTransparentColor := TBitmap(Source).FTransparentColor;
      FTransparentMode := TBitmap(Source).FTransparentMode;
      FTransparent := TBitmap(Source).FTransparent;
    end;
    Changed(Self);
    Exit;
  end;
  inherited Assign(Source);
end;

procedure TBitmap.LoadFromClipboardFormat(AFormat: Word; AData: THandle; APalette: HPALETTE);
begin
end;

procedure TBitmap.SaveToClipboardFormat(var Format: Word; var Data: THandle; var APalette: HPALETTE);
begin
end;

procedure TBitmap.Mask(TransparentColor: TColor);
var
  B: TZMBitmap;
  X, Y: Integer;
  T: LongWord;
  M: TZMBitmap;
begin
  B := TZMBitmap(Img);
  if B = nil then Exit;
  T := ColorRefToRGB(ColorToRGB(TransparentColor) and $FFFFFF);
  M := TZMBitmap.Create(B.Width, B.Height, 1);
  for Y := 0 to B.Height - 1 do
    for X := 0 to B.Width - 1 do
      if B.NativeToRGB(B.GetNative(X, Y)) = T then M.SetNative(X, Y, 1);
  ReselectInCanvas;
  DeleteObject(FHandle);
  FHandle := M.Handle;
  FImgHandle := 0;
  FMonochrome := True;
  FPixelFormat := pf1bit;
  Changed(Self);
end;

{ BMP lezen }
procedure DecodeRLE(Bron: PByte; Bronlengte: Integer; B: TZMBitmap; Is4: Boolean);
var
  X, Y, I, N, C: Integer;
  P, E: PByte;
  procedure Plaats(V: Integer);
  begin
    if (X >= 0) and (X < B.Width) and (Y >= 0) and (Y < B.Height) then
      B.SetNative(X, B.Height - 1 - Y, V);
    Inc(X);
  end;
begin
  X := 0;
  Y := 0;
  P := Bron;
  E := Bron + Bronlengte;
  while P + 1 < E do
  begin
    N := P[0];
    C := P[1];
    Inc(P, 2);
    if N > 0 then
    begin
      for I := 0 to N - 1 do
        if Is4 then
        begin
          if I and 1 = 0 then Plaats(C shr 4) else Plaats(C and $F);
        end
        else
          Plaats(C);
    end
    else
      case C of
        0: begin X := 0; Inc(Y); end;
        1: Exit;
        2:
          begin
            if P + 1 >= E then Exit;
            Inc(X, P[0]);
            Inc(Y, P[1]);
            Inc(P, 2);
          end;
      else
        begin
          for I := 0 to C - 1 do
            if Is4 then
            begin
              if I and 1 = 0 then Plaats(P[I shr 1] shr 4) else Plaats(P[I shr 1] and $F);
            end
            else
              Plaats(P[I]);
          if Is4 then N := (C + 1) div 2 else N := C;
          Inc(P, (N + 1) and not 1);
        end;
      end;
  end;
end;

procedure TBitmap.LoadFromStream(Stream: TStream);
var
  FH: TBitmapFileHeader;
  Start: Int64;
  Kopgrootte: DWORD;
  BI: TBitmapInfoHeader;
  BC: TBitmapCoreHeader;
  W, H, BPP, Kleurenaantal, I, Y, Bronstap, SY: Integer;
  Bovenaf: Boolean;
  Pal: array[0..255] of TRGBQuad;
  Tri: array[0..255] of TRGBTriple;
  B: TZMBitmap;
  Gegevens: array of Byte;
  Gegevenslengte: Int64;
  Maskers: array[0..2] of DWORD;
  X: Integer;
  V: LongWord;
  Rij: PByte;
  Kern: Boolean;
begin
  Start := Stream.Position;
  Stream.ReadBuffer(FH, SizeOf(FH));
  if FH.bfType <> $4D42 then
    raise EInvalidGraphic.Create('Bitmap image is not valid');
  Stream.ReadBuffer(Kopgrootte, 4);
  Kern := Kopgrootte = SizeOf(TBitmapCoreHeader);
  FillChar(BI, SizeOf(BI), 0);
  if Kern then
  begin
    BC.bcSize := Kopgrootte;
    Stream.ReadBuffer(BC.bcWidth, SizeOf(BC) - 4);
    BI.biWidth := BC.bcWidth;
    BI.biHeight := BC.bcHeight;
    BI.biBitCount := BC.bcBitCount;
  end
  else
  begin
    BI.biSize := Kopgrootte;
    Stream.ReadBuffer(BI.biWidth, SizeOf(BI) - 4);
    if Kopgrootte > SizeOf(BI) then Stream.Seek(Kopgrootte - SizeOf(BI), soCurrent);
  end;
  W := BI.biWidth;
  H := Abs(BI.biHeight);
  Bovenaf := BI.biHeight < 0;
  BPP := BI.biBitCount;
  Maskers[0] := 0; Maskers[1] := 0; Maskers[2] := 0;
  if (BI.biCompression = BI_BITFIELDS) and (Kopgrootte = SizeOf(BI)) then
    Stream.ReadBuffer(Maskers, 12);
  Kleurenaantal := 0;
  if BPP <= 8 then
  begin
    Kleurenaantal := BI.biClrUsed;
    if (Kleurenaantal = 0) or (Kleurenaantal > 1 shl BPP) then Kleurenaantal := 1 shl BPP;
    if Kern then
    begin
      Stream.ReadBuffer(Tri, Kleurenaantal * 3);
      for I := 0 to Kleurenaantal - 1 do
      begin
        Pal[I].rgbBlue := Tri[I].rgbtBlue;
        Pal[I].rgbGreen := Tri[I].rgbtGreen;
        Pal[I].rgbRed := Tri[I].rgbtRed;
      end;
    end
    else
      Stream.ReadBuffer(Pal, Kleurenaantal * 4);
  end;
  if FH.bfOffBits <> 0 then Stream.Position := Start + FH.bfOffBits;
  if BPP = 4 then
    B := TZMBitmap.Create(W, H, 4)
  else if BPP in [1, 8, 16, 24, 32] then
    B := TZMBitmap.Create(W, H, BPP)
  else
    raise EInvalidGraphic.Create('Bitmap image is not valid');
  try
    if BPP <= 8 then
    begin
      B.NumColors := 1 shl BPP;
      for I := 0 to B.NumColors - 1 do
        if I < Kleurenaantal then
          B.Colors[I] := (Pal[I].rgbRed shl 16) or (Pal[I].rgbGreen shl 8) or Pal[I].rgbBlue
        else
          B.Colors[I] := 0;
      B.ColorsChanged;
    end;
    Bronstap := ((W * BPP + 31) div 32) * 4;
    if (BI.biCompression = BI_RLE8) or (BI.biCompression = BI_RLE4) then
    begin
      Gegevenslengte := BI.biSizeImage;
      if Gegevenslengte = 0 then Gegevenslengte := Stream.Size - Stream.Position;
      SetLength(Gegevens, Gegevenslengte);
      if Gegevenslengte > 0 then Stream.ReadBuffer(Gegevens[0], Gegevenslengte);
      DecodeRLE(@Gegevens[0], Gegevenslengte, B, BI.biCompression = BI_RLE4);
    end
    else
    begin
      SetLength(Gegevens, Bronstap);
      for Y := 0 to H - 1 do
      begin
        if Bronstap > 0 then Stream.ReadBuffer(Gegevens[0], Bronstap);
        if Bovenaf then SY := Y else SY := H - 1 - Y;
        Rij := B.RowPtr(SY);
        if (BPP = 16) and (BI.biCompression = BI_BITFIELDS) and (Maskers[1] = $7E0) then
        begin
          { 5-6-5 -> 5-5-5 }
          for X := 0 to W - 1 do
          begin
            V := PWord(@Gegevens[X * 2])^;
            PWord(Rij + X * 2)^ := ((V shr 11) shl 10) or (((V shr 6) and $1F) shl 5) or (V and $1F);
          end;
        end
        else
          Move(Gegevens[0], Rij^, Min(Bronstap, B.Stride));
      end;
    end;
  except
    B.Free;
    raise;
  end;
  FreeImage;
  B.IsDIB := True;
  FHandle := B.Handle;
  FImgHandle := 0;
  FHandleType := bmDIB;
  FPixelFormat := PFOf(BPP);
  FMonochrome := BPP = 1;
  Changed(Self);
end;

procedure TBitmap.SaveToStream(Stream: TStream);
var
  B: TZMBitmap;
  FH: TBitmapFileHeader;
  BI: TBitmapInfoHeader;
  NC, Y, I, Stap: Integer;
  Q: TRGBQuad;
  Pad: array[0..3] of Byte;
begin
  B := TZMBitmap(Img);
  if B = nil then
  begin
    B := TZMBitmap(TZMBitmap.Create(0, 0, 24));
    try
      FillChar(BI, SizeOf(BI), 0);
    finally
      B.Free;
    end;
    B := nil;
  end;
  FillChar(BI, SizeOf(BI), 0);
  BI.biSize := SizeOf(BI);
  if B <> nil then
  begin
    BI.biWidth := B.Width;
    BI.biHeight := B.Height;
    BI.biBitCount := B.BPP;
  end
  else
    BI.biBitCount := 24;
  BI.biPlanes := 1;
  BI.biCompression := BI_RGB;
  Stap := ((BI.biWidth * BI.biBitCount + 31) div 32) * 4;
  BI.biSizeImage := Stap * BI.biHeight;
  if BI.biBitCount <= 8 then NC := 1 shl BI.biBitCount else NC := 0;
  BI.biClrUsed := 0;
  FH.bfType := $4D42;
  FH.bfOffBits := SizeOf(FH) + SizeOf(BI) + NC * 4;
  FH.bfSize := FH.bfOffBits + BI.biSizeImage;
  FH.bfReserved1 := 0;
  FH.bfReserved2 := 0;
  Stream.WriteBuffer(FH, SizeOf(FH));
  Stream.WriteBuffer(BI, SizeOf(BI));
  for I := 0 to NC - 1 do
  begin
    Q.rgbRed := (B.Colors[I] shr 16) and $FF;
    Q.rgbGreen := (B.Colors[I] shr 8) and $FF;
    Q.rgbBlue := B.Colors[I] and $FF;
    Q.rgbReserved := 0;
    Stream.WriteBuffer(Q, 4);
  end;
  FillChar(Pad, 4, 0);
  if B <> nil then
    for Y := B.Height - 1 downto 0 do
    begin
      Stream.WriteBuffer(B.RowPtr(Y)^, Min(Stap, B.Stride));
      if Stap > B.Stride then Stream.WriteBuffer(Pad, Stap - B.Stride);
    end;
end;

procedure TBitmap.ReadData(Stream: TStream);
var
  Grootte: Longint;
  M: TMemoryStream;
begin
  Stream.Read(Grootte, SizeOf(Grootte));
  M := TMemoryStream.Create;
  try
    M.CopyFrom(Stream, Grootte);
    M.Position := 0;
    if Grootte > 0 then LoadFromStream(M);
  finally
    M.Free;
  end;
end;

procedure TBitmap.WriteData(Stream: TStream);
var
  M: TMemoryStream;
  Grootte: Longint;
begin
  M := TMemoryStream.Create;
  try
    SaveToStream(M);
    Grootte := M.Size;
    Stream.Write(Grootte, SizeOf(Grootte));
    Stream.Write(M.Memory^, Grootte);
  finally
    M.Free;
  end;
end;

procedure TBitmap.LoadFromResourceName(Instance: THandle; const ResName: string);
var
  R: HRSRC;
  P: Pointer;
  S: DWORD;
  M: TMemoryStream;
  FH: TBitmapFileHeader;
  BI: PBitmapInfoHeader;
  NC: Integer;
begin
  R := FindResource(Instance, PAnsiChar(AnsiString(ResName)), RT_BITMAP);
  if R = 0 then raise EResNotFound.CreateFmt('Resource %s not found', [ResName]);
  P := LockResource(LoadResource(Instance, R));
  S := SizeofResource(Instance, R);
  BI := P;
  NC := 0;
  if BI^.biBitCount <= 8 then
  begin
    NC := BI^.biClrUsed;
    if NC = 0 then NC := 1 shl BI^.biBitCount;
  end;
  FH.bfType := $4D42;
  FH.bfSize := SizeOf(FH) + S;
  FH.bfReserved1 := 0;
  FH.bfReserved2 := 0;
  FH.bfOffBits := SizeOf(FH) + BI^.biSize + NC * 4;
  M := TMemoryStream.Create;
  try
    M.WriteBuffer(FH, SizeOf(FH));
    M.WriteBuffer(P^, S);
    M.Position := 0;
    LoadFromStream(M);
  finally
    M.Free;
  end;
end;

procedure TBitmap.LoadFromResourceID(Instance: THandle; ResID: Integer);
begin
  LoadFromResourceName(Instance, '#' + IntToStr(ResID));
end;

{ ---------------------------------------------------------------- TIcon }

constructor TIcon.Create;
begin
  inherited Create;
  FData := TMemoryStream.Create;
  FWidth := 32;
  FHeight := 32;
end;

destructor TIcon.Destroy;
begin
  FData.Free;
  inherited Destroy;
end;

procedure TIcon.Assign(Source: TPersistent);
begin
  if Source is TIcon then
  begin
    FData.Clear;
    TIcon(Source).FData.Position := 0;
    FData.CopyFrom(TIcon(Source).FData, TIcon(Source).FData.Size);
    FHandle := TIcon(Source).FHandle;
    Changed(Self);
    Exit;
  end;
  inherited Assign(Source);
end;

procedure TIcon.Draw(ACanvas: TCanvas; const Rect: TRect);
begin
end;

function TIcon.GetEmpty: Boolean;
begin
  Result := (FData.Size = 0) and (FHandle = 0);
end;

function TIcon.GetHandle: HICON;
begin
  Result := FHandle;
end;

procedure TIcon.SetHandle(Value: HICON);
begin
  FHandle := Value;
  Changed(Self);
end;

function TIcon.HandleAllocated: Boolean;
begin
  Result := FHandle <> 0;
end;

function TIcon.ReleaseHandle: HICON;
begin
  Result := FHandle;
  FHandle := 0;
end;

function TIcon.GetHeight: Integer;
begin
  Result := FHeight;
end;

function TIcon.GetWidth: Integer;
begin
  Result := FWidth;
end;

procedure TIcon.SetHeight(Value: Integer);
begin
  FHeight := Value;
end;

procedure TIcon.SetWidth(Value: Integer);
begin
  FWidth := Value;
end;

procedure TIcon.LoadFromClipboardFormat(AFormat: Word; AData: THandle; APalette: HPALETTE);
begin
end;

procedure TIcon.SaveToClipboardFormat(var Format: Word; var Data: THandle; var APalette: HPALETTE);
begin
end;

procedure TIcon.LoadFromStream(Stream: TStream);
begin
  FData.Clear;
  FData.CopyFrom(Stream, Stream.Size - Stream.Position);
  Changed(Self);
end;

procedure TIcon.SaveToStream(Stream: TStream);
begin
  FData.Position := 0;
  Stream.CopyFrom(FData, FData.Size);
end;

{ ---------------------------------------------------------------- hulpfuncties }

function GraphicFilter(GraphicClass: TGraphicClass): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FileFormats) do
    if (FileFormats[I].Cls <> nil) and FileFormats[I].Cls.InheritsFrom(GraphicClass) then
    begin
      if Result <> '' then Result := Result + '|';
      Result := Result + FileFormats[I].Desc + ' (*.' + FileFormats[I].Ext + ')|*.' + FileFormats[I].Ext;
    end;
end;

function GraphicExtension(GraphicClass: TGraphicClass): string;
var
  I: Integer;
begin
  for I := 0 to High(FileFormats) do
    if FileFormats[I].Cls = GraphicClass then Exit(FileFormats[I].Ext);
  Result := '';
end;

function GraphicFileMask(GraphicClass: TGraphicClass): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FileFormats) do
    if (FileFormats[I].Cls <> nil) and FileFormats[I].Cls.InheritsFrom(GraphicClass) then
    begin
      if Result <> '' then Result := Result + ';';
      Result := Result + '*.' + FileFormats[I].Ext;
    end;
end;

procedure GetDIBSizes(Bitmap: HBITMAP; var InfoHeaderSize: DWORD; var ImageSize: DWORD);
var
  B: TZMBitmap;
begin
  B := GdiBitmap(Bitmap);
  InfoHeaderSize := SizeOf(TBitmapInfoHeader);
  ImageSize := 0;
  if B = nil then Exit;
  if B.BPP <= 8 then Inc(InfoHeaderSize, (1 shl B.BPP) * 4);
  ImageSize := ((B.Width * B.BPP + 31) div 32) * 4 * B.Height;
end;

function GetDIB(Bitmap: HBITMAP; Palette: HPALETTE; var BitmapInfo; var Bits): Boolean;
var
  B: TZMBitmap;
  BI: PBitmapInfo;
begin
  B := GdiBitmap(Bitmap);
  Result := B <> nil;
  if not Result then Exit;
  BI := @BitmapInfo;
  FillChar(BI^.bmiHeader, SizeOf(TBitmapInfoHeader), 0);
  BI^.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  BI^.bmiHeader.biWidth := B.Width;
  BI^.bmiHeader.biHeight := B.Height;
  BI^.bmiHeader.biPlanes := 1;
  BI^.bmiHeader.biBitCount := B.BPP;
  GetDIBits(0, Bitmap, 0, B.Height, @Bits, BI^, DIB_RGB_COLORS);
end;

function CopyPalette(Palette: HPALETTE): HPALETTE;
var
  P: TZMPalette;
  LP: TMaxLogPalette;
begin
  Result := 0;
  P := GdiPalette(Palette);
  if P = nil then Exit;
  LP.palVersion := $300;
  LP.palNumEntries := P.Count;
  Move(P.Entries, LP.palPalEntry, P.Count * SizeOf(TPaletteEntry));
  Result := CreatePalette(PLogPalette(@LP)^);
end;

procedure PaletteChanged;
begin
end;

procedure FreeMemoryContexts;
begin
end;

function TransparentStretchBlt(DstDC: HDC; DstX, DstY, DstW, DstH: Integer;
  SrcDC: HDC; SrcX, SrcY, SrcW, SrcH: Integer; MaskDC: HDC; MaskX, MaskY: Integer): Boolean;
var
  Oudachtergrond, Oudetekst: COLORREF;
begin
  Oudachtergrond := SetBkColor(DstDC, $FFFFFF);
  Oudetekst := SetTextColor(DstDC, 0);
  StretchBlt(DstDC, DstX, DstY, DstW, DstH, SrcDC, SrcX, SrcY, SrcW, SrcH, SRCINVERT);
  StretchBlt(DstDC, DstX, DstY, DstW, DstH, MaskDC, MaskX, MaskY, SrcW, SrcH, SRCAND);
  StretchBlt(DstDC, DstX, DstY, DstW, DstH, SrcDC, SrcX, SrcY, SrcW, SrcH, SRCINVERT);
  SetTextColor(DstDC, Oudetekst);
  SetBkColor(DstDC, Oudachtergrond);
  Result := True;
end;

function CreateMappedBmp(Handle: HBITMAP; const OldColors, NewColors: array of TColor): HBITMAP;
var
  S, B: TZMBitmap;
  X, Y, I: Integer;
  C: LongWord;
begin
  Result := 0;
  S := GdiBitmap(Handle);
  if S = nil then Exit;
  B := TZMBitmap.Create(S.Width, S.Height, 32);
  for Y := 0 to S.Height - 1 do
    for X := 0 to S.Width - 1 do
    begin
      C := S.NativeToRGB(S.GetNative(X, Y));
      for I := 0 to Min(High(OldColors), High(NewColors)) do
        if C = ColorRefToRGB(ColorToRGB(OldColors[I]) and $FFFFFF) then
        begin
          C := ColorRefToRGB(ColorToRGB(NewColors[I]) and $FFFFFF);
          Break;
        end;
      B.SetNative(X, Y, C);
    end;
  Result := B.Handle;
end;

function CreateGrayMappedBmp(Handle: HBITMAP): HBITMAP;
begin
  Result := CreateMappedBmp(Handle, [clBlack, clGray, clSilver, clWhite],
    [clBtnShadow, clBtnShadow, clBtnFace, clBtnHighlight]);
end;

function AllocPatternBitmap(BkColor, FgColor: TColor): TBitmap;
var
  X, Y: Integer;
begin
  Result := TBitmap.Create;
  Result.Width := 8;
  Result.Height := 8;
  for Y := 0 to 7 do
    for X := 0 to 7 do
      if (X + Y) and 1 = 0 then
        Result.Canvas.Pixels[X, Y] := FgColor
      else
        Result.Canvas.Pixels[X, Y] := BkColor;
end;

initialization
  RegisterIntegerConsts(TypeInfo(TColor), IdentToColor, ColorToIdent);
  RegisterIntegerConsts(TypeInfo(TFontCharset), IdentToCharset, CharsetToIdent);
  TPicture.RegisterFileFormat('bmp', 'Bitmaps', TBitmap);
  TPicture.RegisterFileFormat('ico', 'Icons', TIcon);
  TPicture.RegisterFileFormat('wmf', 'Metafiles', TMetafile);
  TPicture.RegisterFileFormat('emf', 'Enhanced Metafiles', TMetafile);
end.

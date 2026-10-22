unit ZMGdi;

{ Software GDI: bitmaps (DIB-like, 1/4/8/16/24/32 bpp, top-down rows), palettes,
  brushes, pens, fonts, rectangle-list regions and device contexts, plus the
  raster operations behind BitBlt/StretchBlt/PatBlt, line/shape drawing and text.

  Handles handed out by the Windows unit are the object pointers of the classes
  below (THandle = PtrUInt). Colours inside a bitmap are "native" values: palette
  indices for <= 8 bpp, $00RRGGBB for 24/32 bpp (B,G,R byte order in memory),
  5-5-5 for 16 bpp. }

{$MODE DELPHI}{$H+}{$R-}{$Q-}{$POINTERMATH ON}

interface

uses Windows, ZMFonts;

const
  ZM_GDI_MAGIC = $47444D5A;  { 'ZMDG' }

type
  TZMRects = array of TRect;

  TZMGdiObj = class
  public
    Magic: LongWord;
    Handle: THandle;
    ObjType: Integer;     { OBJ_xxx }
    IsStock: Boolean;
    constructor Create(AType: Integer);
    destructor Destroy; override;
  end;

  TZMPalette = class(TZMGdiObj)
  public
    Count: Integer;
    Entries: array[0..255] of TPaletteEntry;
    constructor Create;
  end;

  TZMBitmap = class(TZMGdiObj)
  private
    FNearCache: array of SmallInt;   { 15-bit RGB -> nearest index + 1 }
    FNearStamp: LongWord;
  public
    Width, Height, BPP, Stride: Integer;
    Bits: PByte;
    OwnsBits: Boolean;
    NumColors: Integer;
    Colors: array[0..255] of LongWord;  { $00RRGGBB }
    ColorStamp: LongWord;               { incremented when Colors change }
    Dirty: Boolean;                     { set by drawing (used for the screen) }
    IsDIB: Boolean;                     { DIB section (vs. device-dependent bitmap) }
    SelectedIn: TObject;                { DC the bitmap is selected into }
    constructor Create(AWidth, AHeight, ABPP: Integer);
    destructor Destroy; override;
    procedure SetDefaultColors;
    procedure ColorsChanged;
    function RowPtr(Y: Integer): PByte; inline;
    function GetNative(X, Y: Integer): LongWord;
    procedure SetNative(X, Y: Integer; V: LongWord);
    function NativeToRGB(V: LongWord): LongWord;
    function RGBToNative(RGB: LongWord): LongWord;
    function Nearest(RGB: LongWord): Integer;
    function NativeMask: LongWord;
  end;

  TZMBrush = class(TZMGdiObj)
  public
    Style: UINT;
    Color: COLORREF;
    Hatch: PtrInt;
    Pattern: TZMBitmap;  { owned copy for BS_PATTERN }
    constructor Create;
    destructor Destroy; override;
  end;

  TZMPen = class(TZMGdiObj)
  public
    Style: UINT;
    Width: Integer;
    Color: COLORREF;
    constructor Create;
  end;

  TZMFontObj = class(TZMGdiObj)
  public
    LF: TLogFont;
    Face: PZMFace;
    BitmapFont: Integer;   { -1 unknown, 0 TrueType, 1 bitmap font }
    constructor Create(const ALF: TLogFont);
  end;

  TZMRegion = class(TZMGdiObj)
  public
    Rects: TZMRects;
    constructor Create;
    function Box: TRect;
  end;

  TZMDCState = record
    WinOrg, VpOrg: TPoint;
    HasClip: Boolean;
    ClipRgn: TZMRects;
    Pen: TZMPen;
    Brush: TZMBrush;
    Font: TZMFontObj;
    Palette: TZMPalette;
    BkColor, TextColor: COLORREF;
    BkMode, ROP2, StretchMode: Integer;
    TextAlign: UINT;
    CurPos, BrushOrg: TPoint;
    CharExtra: Integer;
  end;

  TZMDC = class(TZMGdiObj)
  private
    FEff: TZMRects;
    FEffValid: Boolean;
  public
    Target: TZMBitmap;     { surface drawn to }
    IsMemDC: Boolean;
    DefBitmap: TZMBitmap;  { 1x1 mono bitmap of a fresh memory DC }
    Wnd: HWND;             { window of a window DC (0 = screen / memory) }
    IsPaintDC: Boolean;
    DevOrg: TPoint;        { position of device (client) origin in Target }
    HasVis: Boolean;
    VisRgn: TZMRects;      { visible area in Target coordinates }
    VisGen: Integer;       { ZMVisGeneration when VisRgn was computed (window DCs) }
    IsWindowDC: Boolean;   { GetWindowDC: origin at the window corner, not the client }
    PaintRgn: TZMRects;    { BeginPaint: update region (Target coords) }
    HasPaintRgn: Boolean;
    St: TZMDCState;
    Saved: array of TZMDCState;
    constructor Create(ATarget: TZMBitmap);
    destructor Destroy; override;
    procedure InvalidateClip;
    function Eff: TZMRects;                { effective clip in Target coords }
    function LPtoT(X, Y: Integer): TPoint; inline;   { logical -> target }
    function OffX: Integer; inline;
    function OffY: Integer; inline;
    function ColorToNative(C: COLORREF): LongWord;
    function ColorToRGB(C: COLORREF): LongWord;
    procedure SelectBitmap(B: TZMBitmap);
  end;

var
  { ZM_NO_AA=1: never anti-alias text }
  ZMNoAntialias: Boolean = False;
  { window DCs recompute their visible region when the window layout changes }
  ZMVisGeneration: Integer = 1;
  ZMVisProvider: procedure(DC: TObject) = nil;

  StockObjects: array[0..17] of TZMGdiObj;
  SysColors: array[0..30] of COLORREF;
  SysColorBrushes: array[0..30] of TZMBrush;

{ handle helpers }
function GdiObj(H: THandle): TZMGdiObj;
function GdiDC(H: THandle): TZMDC;
function GdiBitmap(H: THandle): TZMBitmap;
function GdiPalette(H: THandle): TZMPalette;
function GdiBrush(H: THandle): TZMBrush;
function GdiRegion(H: THandle): TZMRegion;
function GdiFont(H: THandle): TZMFontObj;
function H2(O: TObject): THandle;

{ colours }
function ColorRefToRGB(C: COLORREF): LongWord; inline;   { $00BBGGRR -> $00RRGGBB }
function RGBToColorRef(C: LongWord): COLORREF; inline;

{ rect lists }
function RectsIntersectRect(const A: TZMRects; const R: TRect): TZMRects;
function RectsIntersect(const A, B: TZMRects): TZMRects;
function RectsSubtractRect(const A: TZMRects; const R: TRect): TZMRects;
function RectsSubtract(const A, B: TZMRects): TZMRects;
function RectsUnion(const A, B: TZMRects): TZMRects;
function RectsOffset(const A: TZMRects; DX, DY: Integer): TZMRects;
function RectsBox(const A: TZMRects): TRect;
function RectsContain(const A: TZMRects; X, Y: Integer): Boolean;
function RectsCopy(const A: TZMRects): TZMRects;

{ drawing primitives (coordinates are logical, i.e. as passed to the API) }
procedure GdiBlt(Dst: TZMDC; X, Y, W, H: Integer; Src: TZMDC; SX, SY, SW, SH: Integer;
  Rop: DWORD; Stretch: Boolean);
procedure GdiBltBitmap(Dst: TZMDC; X, Y, W, H: Integer; Src: TZMBitmap; SrcBk: COLORREF;
  SX, SY, SW, SH: Integer; Rop: DWORD; Stretch: Boolean);
procedure GdiPatBlt(DC: TZMDC; X, Y, W, H: Integer; Rop: DWORD);
procedure GdiFillRect(DC: TZMDC; const R: TRect; Br: TZMBrush);
procedure GdiFillSolid(DC: TZMDC; const R: TRect; C: COLORREF);
procedure GdiInvertRect(DC: TZMDC; const R: TRect);
procedure GdiFocusRect(DC: TZMDC; const R: TRect);
procedure GdiLine(DC: TZMDC; X1, Y1, X2, Y2: Integer; LastPixel: Boolean);
procedure GdiRectangle(DC: TZMDC; X1, Y1, X2, Y2: Integer);
procedure GdiEllipse(DC: TZMDC; X1, Y1, X2, Y2: Integer);
procedure GdiRoundRect(DC: TZMDC; X1, Y1, X2, Y2, RW, RH: Integer);
procedure GdiPolygon(DC: TZMDC; const Pts: array of TPoint; Fill: Boolean);
procedure GdiPolyline(DC: TZMDC; const Pts: array of TPoint);
procedure GdiSetPixel(DC: TZMDC; X, Y: Integer; C: COLORREF);
function GdiGetPixel(DC: TZMDC; X, Y: Integer): COLORREF;
procedure GdiFloodFill(DC: TZMDC; X, Y: Integer; C: COLORREF; Surface: Boolean);

{ text }
function GdiFace(DC: TZMDC): PZMFace;
function GdiUseAA(DC: TZMDC): Boolean;
function GdiGlyphs(DC: TZMDC): PZMGlyphs;
function GdiTextWidth(DC: TZMDC; S: PAnsiChar; Count: Integer): Integer;
function IsBitmapFontName(const Name: string): Boolean;
procedure GdiTextOut(DC: TZMDC; X, Y: Integer; S: PAnsiChar; Count: Integer;
  DoOpaque: Boolean; ClipR: PRect; OpaqueR: PRect);
function GdiDrawText(DC: TZMDC; S: PAnsiChar; Count: Integer; var R: TRect; Format: UINT): Integer;

{ helpers }
procedure ZMReadRow(B: TZMBitmap; Y, X, N: Integer; Buf: PLongWord);
procedure ZMWriteRow(B: TZMBitmap; Y, X, N: Integer; Buf: PLongWord);
function NewBitmapFromInfo(const BI: TBitmapInfo; Usage: UINT; Pal: TZMPalette): TZMBitmap;
procedure HalftoneEntries(var E: array of TPaletteEntry);
procedure InitStockObjects;

implementation

uses SysUtils, Math, Classes, ZMHandles;

{ ---------------------------------------------------------------- objects }

constructor TZMGdiObj.Create(AType: Integer);
begin
  inherited Create;
  Magic := ZM_GDI_MAGIC;
  ObjType := AType;
  Handle := ZMAllocHandle(Self);
end;

destructor TZMGdiObj.Destroy;
begin
  Magic := 0;
  ZMFreeHandle(Handle);
  inherited Destroy;
end;

function H2(O: TObject): THandle;
begin
  if O = nil then Result := 0 else Result := TZMGdiObj(O).Handle;
end;

function GdiObj(H: THandle): TZMGdiObj;
var O: TObject;
begin
  Result := nil;
  O := ZMHandleObj(H);
  if (O <> nil) and (O is TZMGdiObj) then Result := TZMGdiObj(O);
end;

function GdiDC(H: THandle): TZMDC;
var O: TZMGdiObj;
begin
  O := GdiObj(H);
  if (O <> nil) and (O is TZMDC) then Result := TZMDC(O) else Result := nil;
end;

function GdiBitmap(H: THandle): TZMBitmap;
var O: TZMGdiObj;
begin
  O := GdiObj(H);
  if (O <> nil) and (O is TZMBitmap) then Result := TZMBitmap(O) else Result := nil;
end;

function GdiPalette(H: THandle): TZMPalette;
var O: TZMGdiObj;
begin
  O := GdiObj(H);
  if (O <> nil) and (O is TZMPalette) then Result := TZMPalette(O) else Result := nil;
end;

function GdiBrush(H: THandle): TZMBrush;
var O: TZMGdiObj;
begin
  if (H > 0) and (H <= 31) then
  begin
    { (COLOR_xxx + 1) used as a class background brush }
    Result := SysColorBrushes[H - 1];
    Exit;
  end;
  O := GdiObj(H);
  if (O <> nil) and (O is TZMBrush) then Result := TZMBrush(O) else Result := nil;
end;

function GdiRegion(H: THandle): TZMRegion;
var O: TZMGdiObj;
begin
  O := GdiObj(H);
  if (O <> nil) and (O is TZMRegion) then Result := TZMRegion(O) else Result := nil;
end;

function GdiFont(H: THandle): TZMFontObj;
var O: TZMGdiObj;
begin
  O := GdiObj(H);
  if (O <> nil) and (O is TZMFontObj) then Result := TZMFontObj(O) else Result := nil;
end;

constructor TZMPalette.Create;
begin
  inherited Create(OBJ_PAL);
end;

constructor TZMBrush.Create;
begin
  inherited Create(OBJ_BRUSH);
end;

destructor TZMBrush.Destroy;
begin
  Pattern.Free;
  inherited Destroy;
end;

constructor TZMPen.Create;
begin
  inherited Create(OBJ_PEN);
  Width := 1;
end;

constructor TZMFontObj.Create(const ALF: TLogFont);
begin
  inherited Create(OBJ_FONT);
  LF := ALF;
  Face := ZMFindFace(LF);
  BitmapFont := -1;
end;

constructor TZMRegion.Create;
begin
  inherited Create(OBJ_REGION);
end;

function TZMRegion.Box: TRect;
begin
  Result := RectsBox(Rects);
end;

{ ---------------------------------------------------------------- colours }

function ColorRefToRGB(C: COLORREF): LongWord; inline;
begin
  Result := ((C and $FF) shl 16) or (C and $FF00) or ((C shr 16) and $FF);
end;

function RGBToColorRef(C: LongWord): COLORREF; inline;
begin
  Result := ((C and $FF) shl 16) or (C and $FF00) or ((C shr 16) and $FF);
end;

{ ---------------------------------------------------------------- bitmaps }

constructor TZMBitmap.Create(AWidth, AHeight, ABPP: Integer);
begin
  inherited Create(OBJ_BITMAP);
  if AWidth < 0 then AWidth := 0;
  if AHeight < 0 then AHeight := 0;
  Width := AWidth;
  Height := AHeight;
  BPP := ABPP;
  Stride := ((Width * BPP + 31) div 32) * 4;
  if Stride * Height > 0 then
  begin
    Bits := AllocMem(Stride * Height);
    OwnsBits := True;
  end;
  SetDefaultColors;
end;

destructor TZMBitmap.Destroy;
begin
  if OwnsBits and (Bits <> nil) then FreeMem(Bits);
  inherited Destroy;
end;

procedure HalftoneEntries(var E: array of TPaletteEntry);
const
  Sys20: array[0..19] of LongWord = (
    $000000, $800000, $008000, $808000, $000080, $800080, $008080, $C0C0C0,
    $C0DCC0, $A6CAF0, $FFFBF0, $A0A0A4, $808080, $FF0000, $00FF00, $FFFF00,
    $0000FF, $FF00FF, $00FFFF, $FFFFFF);   { $RRGGBB }
var
  I, R, G, B, N: Integer;
  procedure SetE(Idx: Integer; RGB: LongWord);
  begin
    E[Idx].peRed := (RGB shr 16) and $FF;
    E[Idx].peGreen := (RGB shr 8) and $FF;
    E[Idx].peBlue := RGB and $FF;
    E[Idx].peFlags := 0;
  end;
begin
  for I := 0 to 9 do SetE(I, Sys20[I]);
  for I := 0 to 9 do SetE(246 + I, Sys20[10 + I]);
  N := 10;
  for R := 0 to 5 do
    for G := 0 to 5 do
      for B := 0 to 5 do
      begin
        if N >= 246 then Break;
        SetE(N, (LongWord(R * 51) shl 16) or (LongWord(G * 51) shl 8) or LongWord(B * 51));
        Inc(N);
      end;
  while N < 246 do
  begin
    SetE(N, $808080);
    Inc(N);
  end;
end;

procedure TZMBitmap.SetDefaultColors;
var
  E: array[0..255] of TPaletteEntry;
  I: Integer;
begin
  case BPP of
    1:
      begin
        NumColors := 2;
        Colors[0] := 0;
        Colors[1] := $FFFFFF;
      end;
    4:
      begin
        NumColors := 16;
        HalftoneEntries(E);
        for I := 0 to 7 do
          Colors[I] := (E[I].peRed shl 16) or (E[I].peGreen shl 8) or E[I].peBlue;
        for I := 8 to 15 do
          Colors[I] := (E[240 + I].peRed shl 16) or (E[240 + I].peGreen shl 8) or E[240 + I].peBlue;
        Colors[7] := $C0C0C0;
        Colors[8] := $808080;
      end;
    8:
      begin
        NumColors := 256;
        HalftoneEntries(E);
        for I := 0 to 255 do
          Colors[I] := (E[I].peRed shl 16) or (E[I].peGreen shl 8) or E[I].peBlue;
      end;
  else
    NumColors := 0;
  end;
  ColorsChanged;
end;

procedure TZMBitmap.ColorsChanged;
begin
  Inc(ColorStamp);
end;

function TZMBitmap.RowPtr(Y: Integer): PByte; inline;
begin
  Result := Bits + PtrInt(Y) * Stride;
end;

function TZMBitmap.NativeMask: LongWord;
begin
  case BPP of
    1: Result := 1;
    4: Result := $F;
    8: Result := $FF;
    16: Result := $7FFF;
  else
    Result := $FFFFFF;
  end;
end;

function TZMBitmap.GetNative(X, Y: Integer): LongWord;
var
  P: PByte;
begin
  P := Bits + PtrInt(Y) * Stride;
  case BPP of
    1: Result := (P[X shr 3] shr (7 - (X and 7))) and 1;
    4: if X and 1 = 0 then Result := P[X shr 1] shr 4 else Result := P[X shr 1] and $F;
    8: Result := P[X];
    16: Result := PWord(P + X * 2)^ and $7FFF;
    24: begin Inc(P, X * 3); Result := P[0] or (LongWord(P[1]) shl 8) or (LongWord(P[2]) shl 16); end;
    32: Result := PLongWord(P + X * 4)^ and $FFFFFF;
  else
    Result := 0;
  end;
end;

procedure TZMBitmap.SetNative(X, Y: Integer; V: LongWord);
var
  P: PByte;
  M: Byte;
begin
  P := Bits + PtrInt(Y) * Stride;
  case BPP of
    1:
      begin
        M := $80 shr (X and 7);
        if V and 1 <> 0 then P[X shr 3] := P[X shr 3] or M
        else P[X shr 3] := P[X shr 3] and not M;
      end;
    4:
      if X and 1 = 0 then P[X shr 1] := (P[X shr 1] and $0F) or ((V and $F) shl 4)
      else P[X shr 1] := (P[X shr 1] and $F0) or (V and $F);
    8: P[X] := V;
    16: PWord(P + X * 2)^ := V and $7FFF;
    24: begin Inc(P, X * 3); P[0] := V; P[1] := V shr 8; P[2] := V shr 16; end;
    32: PLongWord(P + X * 4)^ := V and $FFFFFF;
  end;
end;

function TZMBitmap.NativeToRGB(V: LongWord): LongWord;
begin
  case BPP of
    1, 4, 8:
      if Integer(V) < NumColors then Result := Colors[V] else Result := 0;
    16:
      Result := (((V shr 10) and $1F) * 255 div 31) shl 16 or
        (((V shr 5) and $1F) * 255 div 31) shl 8 or ((V and $1F) * 255 div 31);
  else
    Result := V and $FFFFFF;
  end;
end;

function TZMBitmap.Nearest(RGB: LongWord): Integer;
var
  Key, I, D, BestD, R, G, B, DR, DG, DB: Integer;
begin
  if NumColors <= 0 then Exit(0);
  Key := ((RGB shr 9) and $7C00) or ((RGB shr 6) and $3E0) or ((RGB shr 3) and $1F);
  if (Length(FNearCache) = 0) or (FNearStamp <> ColorStamp) then
  begin
    SetLength(FNearCache, 32768);
    FillChar(FNearCache[0], 32768 * SizeOf(SmallInt), 0);
    FNearStamp := ColorStamp;
  end;
  { exact colours are looked up directly (the cache is only per 5-bit cell) }
  for I := 0 to NumColors - 1 do
    if Colors[I] = RGB then Exit(I);
  if FNearCache[Key] > 0 then Exit(FNearCache[Key] - 1);
  R := (RGB shr 16) and $FF; G := (RGB shr 8) and $FF; B := RGB and $FF;
  BestD := MaxInt;
  Result := 0;
  for I := 0 to NumColors - 1 do
  begin
    DR := R - Integer((Colors[I] shr 16) and $FF);
    DG := G - Integer((Colors[I] shr 8) and $FF);
    DB := B - Integer(Colors[I] and $FF);
    D := DR * DR * 3 + DG * DG * 4 + DB * DB * 2;
    if D < BestD then
    begin
      BestD := D;
      Result := I;
    end;
  end;
  FNearCache[Key] := Result + 1;
end;

function TZMBitmap.RGBToNative(RGB: LongWord): LongWord;
begin
  case BPP of
    1:
      if NumColors = 2 then Result := Nearest(RGB)
      else if ((RGB shr 16) and $FF) + ((RGB shr 8) and $FF) + (RGB and $FF) >= 384 then Result := 1
      else Result := 0;
    4, 8: Result := Nearest(RGB);
    16: Result := (((RGB shr 19) and $1F) shl 10) or (((RGB shr 11) and $1F) shl 5) or ((RGB shr 3) and $1F);
  else
    Result := RGB and $FFFFFF;
  end;
end;

function NewBitmapFromInfo(const BI: TBitmapInfo; Usage: UINT; Pal: TZMPalette): TZMBitmap;
var
  W, H, BC, I, N: Integer;
  Q: PRGBQuad;
  Idx: PWord;
begin
  W := BI.bmiHeader.biWidth;
  H := Abs(BI.bmiHeader.biHeight);
  BC := BI.bmiHeader.biBitCount;
  if not (BC in [1, 4, 8, 16, 24, 32]) then BC := 24;
  Result := TZMBitmap.Create(W, H, BC);
  Result.IsDIB := True;
  if BC <= 8 then
  begin
    N := BI.bmiHeader.biClrUsed;
    if (N = 0) or (N > 1 shl BC) then N := 1 shl BC;
    Result.NumColors := 1 shl BC;
    if Usage = DIB_PAL_COLORS then
    begin
      Idx := @BI.bmiColors[0];
      for I := 0 to N - 1 do
      begin
        if (Pal <> nil) and (Idx[I] < Pal.Count) then
          with Pal.Entries[Idx[I]] do
            Result.Colors[I] := (peRed shl 16) or (peGreen shl 8) or peBlue
        else
          Result.Colors[I] := 0;
      end;
    end
    else
    begin
      Q := @BI.bmiColors[0];
      for I := 0 to N - 1 do
        Result.Colors[I] := (Q[I].rgbRed shl 16) or (Q[I].rgbGreen shl 8) or Q[I].rgbBlue;
    end;
    for I := N to Result.NumColors - 1 do Result.Colors[I] := 0;
    Result.ColorsChanged;
  end;
end;

{ ---------------------------------------------------------------- rect lists }

function RectsCopy(const A: TZMRects): TZMRects;
begin
  Result := Copy(A, 0, Length(A));
end;

procedure AddRect(var A: TZMRects; const R: TRect); inline;
begin
  if (R.Right > R.Left) and (R.Bottom > R.Top) then
  begin
    SetLength(A, Length(A) + 1);
    A[High(A)] := R;
  end;
end;

function RectsIntersectRect(const A: TZMRects; const R: TRect): TZMRects;
var
  I: Integer;
  T: TRect;
begin
  Result := nil;
  for I := 0 to High(A) do
  begin
    T.Left := A[I].Left; if R.Left > T.Left then T.Left := R.Left;
    T.Top := A[I].Top; if R.Top > T.Top then T.Top := R.Top;
    T.Right := A[I].Right; if R.Right < T.Right then T.Right := R.Right;
    T.Bottom := A[I].Bottom; if R.Bottom < T.Bottom then T.Bottom := R.Bottom;
    AddRect(Result, T);
  end;
end;

function RectsIntersect(const A, B: TZMRects): TZMRects;
var
  I, J: Integer;
  T: TZMRects;
begin
  Result := nil;
  for J := 0 to High(B) do
  begin
    T := RectsIntersectRect(A, B[J]);
    for I := 0 to High(T) do AddRect(Result, T[I]);
  end;
end;

function RectsSubtractRect(const A: TZMRects; const R: TRect): TZMRects;
var
  I: Integer;
  S: TRect;
begin
  Result := nil;
  for I := 0 to High(A) do
  begin
    S := A[I];
    if (R.Right <= S.Left) or (R.Left >= S.Right) or (R.Bottom <= S.Top) or (R.Top >= S.Bottom) then
    begin
      AddRect(Result, S);
      Continue;
    end;
    { top band }
    if R.Top > S.Top then AddRect(Result, Rect(S.Left, S.Top, S.Right, R.Top));
    { bottom band }
    if R.Bottom < S.Bottom then AddRect(Result, Rect(S.Left, R.Bottom, S.Right, S.Bottom));
    { middle: left and right parts }
    if R.Left > S.Left then
      AddRect(Result, Rect(S.Left, Max(S.Top, R.Top), R.Left, Min(S.Bottom, R.Bottom)));
    if R.Right < S.Right then
      AddRect(Result, Rect(R.Right, Max(S.Top, R.Top), S.Right, Min(S.Bottom, R.Bottom)));
  end;
end;

function RectsSubtract(const A, B: TZMRects): TZMRects;
var
  J: Integer;
begin
  Result := RectsCopy(A);
  for J := 0 to High(B) do
    Result := RectsSubtractRect(Result, B[J]);
end;

function RectsUnion(const A, B: TZMRects): TZMRects;
var
  I: Integer;
  T: TZMRects;
begin
  Result := RectsCopy(A);
  T := RectsSubtract(B, A);
  for I := 0 to High(T) do AddRect(Result, T[I]);
end;

function RectsOffset(const A: TZMRects; DX, DY: Integer): TZMRects;
var
  I: Integer;
begin
  SetLength(Result, Length(A));
  for I := 0 to High(A) do
  begin
    Result[I].Left := A[I].Left + DX;
    Result[I].Right := A[I].Right + DX;
    Result[I].Top := A[I].Top + DY;
    Result[I].Bottom := A[I].Bottom + DY;
  end;
end;

function RectsBox(const A: TZMRects): TRect;
var
  I: Integer;
begin
  if Length(A) = 0 then Exit(Rect(0, 0, 0, 0));
  Result := A[0];
  for I := 1 to High(A) do
  begin
    if A[I].Left < Result.Left then Result.Left := A[I].Left;
    if A[I].Top < Result.Top then Result.Top := A[I].Top;
    if A[I].Right > Result.Right then Result.Right := A[I].Right;
    if A[I].Bottom > Result.Bottom then Result.Bottom := A[I].Bottom;
  end;
end;

function RectsContain(const A: TZMRects; X, Y: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(A) do
    if (X >= A[I].Left) and (X < A[I].Right) and (Y >= A[I].Top) and (Y < A[I].Bottom) then
      Exit(True);
  Result := False;
end;

{ ---------------------------------------------------------------- DC }

constructor TZMDC.Create(ATarget: TZMBitmap);
begin
  inherited Create(OBJ_DC);
  Target := ATarget;
  St.Pen := TZMPen(StockObjects[BLACK_PEN]);
  St.Brush := TZMBrush(StockObjects[WHITE_BRUSH]);
  St.Font := TZMFontObj(StockObjects[SYSTEM_FONT]);
  St.Palette := TZMPalette(StockObjects[DEFAULT_PALETTE]);
  St.BkColor := $FFFFFF;
  St.TextColor := 0;
  St.BkMode := OPAQUE;
  St.ROP2 := R2_COPYPEN;
  St.StretchMode := BLACKONWHITE;
end;

destructor TZMDC.Destroy;
begin
  if (Target <> nil) and (Target.SelectedIn = Self) then Target.SelectedIn := nil;
  DefBitmap.Free;
  inherited Destroy;
end;

procedure TZMDC.SelectBitmap(B: TZMBitmap);
begin
  if (Target <> nil) and (Target.SelectedIn = Self) then Target.SelectedIn := nil;
  Target := B;
  if B <> nil then B.SelectedIn := Self;
  InvalidateClip;
end;

procedure TZMDC.InvalidateClip;
begin
  FEffValid := False;
end;

function TZMDC.Eff: TZMRects;
var
  Full: TZMRects;
begin
  if (Wnd <> 0) and (VisGen <> ZMVisGeneration) and Assigned(ZMVisProvider) then
  begin
    ZMVisProvider(Self);
    VisGen := ZMVisGeneration;
    FEffValid := False;
  end;
  if not FEffValid then
  begin
    SetLength(Full, 1);
    if Target <> nil then
      Full[0] := Rect(0, 0, Target.Width, Target.Height)
    else
      Full[0] := Rect(0, 0, 0, 0);
    if HasVis then Full := RectsIntersect(Full, VisRgn);
    if HasPaintRgn then Full := RectsIntersect(Full, PaintRgn);
    if St.HasClip then
      Full := RectsIntersect(Full, RectsOffset(St.ClipRgn, DevOrg.X, DevOrg.Y));
    FEff := Full;
    FEffValid := True;
  end;
  Result := FEff;
end;

function TZMDC.OffX: Integer; inline;
begin
  Result := DevOrg.X + St.VpOrg.X - St.WinOrg.X;
end;

function TZMDC.OffY: Integer; inline;
begin
  Result := DevOrg.Y + St.VpOrg.Y - St.WinOrg.Y;
end;

function TZMDC.LPtoT(X, Y: Integer): TPoint; inline;
begin
  Result.X := X + OffX;
  Result.Y := Y + OffY;
end;

function TZMDC.ColorToRGB(C: COLORREF): LongWord;
var
  I: Integer;
begin
  if (C and $FF000000) = $01000000 then
  begin
    I := C and $FFFF;
    if (Target <> nil) and (Target.BPP <= 8) and (I < Target.NumColors) then
      Result := Target.Colors[I]
    else if (St.Palette <> nil) and (I < St.Palette.Count) then
      with St.Palette.Entries[I] do Result := (peRed shl 16) or (peGreen shl 8) or peBlue
    else
      Result := 0;
  end
  else
    Result := ColorRefToRGB(C and $FFFFFF);
end;

function TZMDC.ColorToNative(C: COLORREF): LongWord;
begin
  if Target = nil then Exit(0);
  if ((C and $FF000000) = $01000000) and (Target.BPP <= 8) then
    Result := (C and $FFFF) and Target.NativeMask
  else
    Result := Target.RGBToNative(ColorToRGB(C));
end;

{ ---------------------------------------------------------------- ROPs }

function Rop3(Code: Byte; P, S, D: LongWord): LongWord; inline;
begin
  case Code of
    $CC: Result := S;
    $66: Result := S xor D;
    $88: Result := S and D;
    $EE: Result := S or D;
    $F0: Result := P;
    $55: Result := not D;
    $00: Result := 0;
    $FF: Result := $FFFFFFFF;
    $33: Result := not S;
    $BB: Result := (not S) or D;
    $44: Result := S and not D;
    $22: Result := (not S) and D;
    $5A: Result := P xor D;
    $C0: Result := P and S;
    $AA: Result := D;
    $11: Result := not (S or D);
    $99: Result := not (S xor D);
    $B8: Result := (P and not S) or (S and D);    { PSDPxax }
    $E2: Result := (D and not S) or (S and P);    { DSPDxax }
  else
    Result := 0;
    if Code and $01 <> 0 then Result := Result or (not P and not S and not D);
    if Code and $02 <> 0 then Result := Result or (not P and not S and D);
    if Code and $04 <> 0 then Result := Result or (not P and S and not D);
    if Code and $08 <> 0 then Result := Result or (not P and S and D);
    if Code and $10 <> 0 then Result := Result or (P and not S and not D);
    if Code and $20 <> 0 then Result := Result or (P and not S and D);
    if Code and $40 <> 0 then Result := Result or (P and S and not D);
    if Code and $80 <> 0 then Result := Result or (P and S and D);
  end;
end;

function RopUsesSrc(Code: Byte): Boolean; inline;
begin
  Result := ((Code shr 2) and $33) <> (Code and $33);
end;

function RopUsesDst(Code: Byte): Boolean; inline;
begin
  Result := ((Code shr 1) and $55) <> (Code and $55);
end;

function RopUsesPat(Code: Byte): Boolean; inline;
begin
  Result := ((Code shr 4) and $0F) <> (Code and $0F);
end;

{ pattern value of the DC's brush at a target pixel (native) }
type
  TPatInfo = record
    Solid: Boolean;
    Value: LongWord;
    Pat: array[0..7, 0..7] of LongWord;
  end;

procedure PreparePattern(DC: TZMDC; var PI: TPatInfo);
const
  HatchBits: array[0..5, 0..7] of Byte = (
    ($00, $00, $00, $00, $FF, $00, $00, $00),   { horizontal }
    ($08, $08, $08, $08, $08, $08, $08, $08),   { vertical }
    ($80, $40, $20, $10, $08, $04, $02, $01),   { fdiagonal }
    ($01, $02, $04, $08, $10, $20, $40, $80),   { bdiagonal }
    ($08, $08, $08, $08, $FF, $08, $08, $08),   { cross }
    ($81, $42, $24, $18, $18, $24, $42, $81));  { diagcross }
var
  B: TZMBrush;
  X, Y, H: Integer;
  Fg, Bg: LongWord;
  P: TZMBitmap;
begin
  B := DC.St.Brush;
  PI.Solid := True;
  PI.Value := 0;
  if B = nil then Exit;
  case B.Style of
    BS_SOLID: PI.Value := DC.ColorToNative(B.Color);
    BS_HATCHED:
      begin
        PI.Solid := False;
        Fg := DC.ColorToNative(B.Color);
        Bg := DC.ColorToNative(DC.St.BkColor);
        H := B.Hatch;
        if (H < 0) or (H > 5) then H := 0;
        for Y := 0 to 7 do
          for X := 0 to 7 do
            if HatchBits[H, Y] and ($80 shr X) <> 0 then PI.Pat[Y, X] := Fg else PI.Pat[Y, X] := Bg;
      end;
    BS_PATTERN, BS_DIBPATTERN:
      begin
        P := B.Pattern;
        if (P = nil) or (P.Width = 0) or (P.Height = 0) then Exit;
        PI.Solid := False;
        for Y := 0 to 7 do
          for X := 0 to 7 do
          begin
            if P.BPP = 1 then
            begin
              if P.GetNative(X mod P.Width, Y mod P.Height) = 0 then
                PI.Pat[Y, X] := DC.ColorToNative(DC.St.TextColor)
              else
                PI.Pat[Y, X] := DC.ColorToNative(DC.St.BkColor);
            end
            else
              PI.Pat[Y, X] := DC.Target.RGBToNative(P.NativeToRGB(P.GetNative(X mod P.Width, Y mod P.Height)));
          end;
      end;
  else
    PI.Value := DC.ColorToNative(B.Color);
  end;
end;

function PatAt(const PI: TPatInfo; DC: TZMDC; X, Y: Integer): LongWord; inline;
begin
  if PI.Solid then Result := PI.Value
  else Result := PI.Pat[(Y - DC.St.BrushOrg.Y) and 7, (X - DC.St.BrushOrg.X) and 7];
end;

{ ---------------------------------------------------------------- blits }

procedure ZMReadRow(B: TZMBitmap; Y, X, N: Integer; Buf: PLongWord);
var
  P: PByte;
  I: Integer;
begin
  P := B.RowPtr(Y);
  case B.BPP of
    8: for I := 0 to N - 1 do Buf[I] := P[X + I];
    32: for I := 0 to N - 1 do Buf[I] := PLongWord(P + (X + I) * 4)^ and $FFFFFF;
    24:
      begin
        Inc(P, X * 3);
        for I := 0 to N - 1 do
        begin
          Buf[I] := P[0] or (LongWord(P[1]) shl 8) or (LongWord(P[2]) shl 16);
          Inc(P, 3);
        end;
      end;
    1: for I := 0 to N - 1 do Buf[I] := (P[(X + I) shr 3] shr (7 - ((X + I) and 7))) and 1;
  else
    for I := 0 to N - 1 do Buf[I] := B.GetNative(X + I, Y);
  end;
end;

procedure ZMWriteRow(B: TZMBitmap; Y, X, N: Integer; Buf: PLongWord);
var
  P: PByte;
  I, XX: Integer;
  M: Byte;
begin
  if N <= 0 then Exit;
  P := B.RowPtr(Y);
  case B.BPP of
    8: for I := 0 to N - 1 do P[X + I] := Buf[I];
    32: for I := 0 to N - 1 do PLongWord(P + (X + I) * 4)^ := Buf[I] and $FFFFFF;
    24:
      begin
        Inc(P, X * 3);
        for I := 0 to N - 1 do
        begin
          P[0] := Buf[I]; P[1] := Buf[I] shr 8; P[2] := Buf[I] shr 16;
          Inc(P, 3);
        end;
      end;
    1:
      for I := 0 to N - 1 do
      begin
        XX := X + I;
        M := $80 shr (XX and 7);
        if Buf[I] and 1 <> 0 then P[XX shr 3] := P[XX shr 3] or M
        else P[XX shr 3] := P[XX shr 3] and not M;
      end;
  else
    for I := 0 to N - 1 do B.SetNative(X + I, Y, Buf[I]);
  end;
end;

type
  TConvKind = (ckIdentity, ckLUT, ckToMono, ckRGBToIndex, ckRGBToRGB, ckGeneric);

procedure GdiBltBitmap(Dst: TZMDC; X, Y, W, H: Integer; Src: TZMBitmap; SrcBk: COLORREF;
  SX, SY, SW, SH: Integer; Rop: DWORD; Stretch: Boolean);
var
  Code: Byte;
  UseSrc, UseDst, UsePat: Boolean;
  T: TZMBitmap;
  Clip: TZMRects;
  DR, CR: TRect;
  I, XX, YY, SXX, SYY, FlipX, FlipY: Integer;
  Conv: TConvKind;
  LUT: array[0..255] of LongWord;
  SrcBkNative: LongWord;
  Mask: LongWord;
  PI: TPatInfo;
  S, D, P, V: LongWord;
  OX, OY, DW, DH: Integer;
  SRow, DRow: PByte;
  Cnt: Integer;
  SBuf, DBuf: array of LongWord;
  Valid: array of Boolean;
  N, XA, XB, I2: Integer;
begin
  T := Dst.Target;
  if (T = nil) or (T.Bits = nil) then Exit;
  Code := (Rop shr 16) and $FF;
  UseSrc := RopUsesSrc(Code) and (Src <> nil) and (Src.Bits <> nil);
  UseDst := RopUsesDst(Code);
  UsePat := RopUsesPat(Code);
  if RopUsesSrc(Code) and not UseSrc then Exit;
  if not Stretch then
  begin
    SW := W;
    SH := H;
  end;
  { negative extents mirror }
  FlipX := 0; FlipY := 0;
  if W < 0 then begin X := X + W; W := -W; FlipX := FlipX xor 1; end;
  if H < 0 then begin Y := Y + H; H := -H; FlipY := FlipY xor 1; end;
  if SW < 0 then begin SX := SX + SW; SW := -SW; FlipX := FlipX xor 1; end;
  if SH < 0 then begin SY := SY + SH; SH := -SH; FlipY := FlipY xor 1; end;
  if (W = 0) or (H = 0) then Exit;
  if UseSrc and ((SW = 0) or (SH = 0)) then Exit;
  OX := Dst.OffX;
  OY := Dst.OffY;
  DR := Rect(X + OX, Y + OY, X + OX + W, Y + OY + H);
  Clip := RectsIntersectRect(Dst.Eff, DR);
  if Length(Clip) = 0 then Exit;
  Mask := T.NativeMask;
  if UsePat then PreparePattern(Dst, PI);

  { source -> destination colour conversion }
  Conv := ckGeneric;
  SrcBkNative := 0;
  if UseSrc then
  begin
    if Src.BPP = 1 then
    begin
      Conv := ckLUT;
      LUT[0] := Dst.ColorToNative(Dst.St.TextColor);
      LUT[1] := Dst.ColorToNative(Dst.St.BkColor);
      if T.BPP = 1 then
      begin
        { mono -> mono: straight copy }
        Conv := ckIdentity;
      end;
    end
    else if T.BPP = 1 then
    begin
      Conv := ckToMono;
      if ((SrcBk and $FF000000) = $01000000) and (Src.BPP <= 8) then
        SrcBkNative := SrcBk and $FFFF
      else
        SrcBkNative := Src.RGBToNative(ColorRefToRGB(SrcBk and $FFFFFF));
    end
    else if Src.BPP <= 8 then
    begin
      if (T.BPP = Src.BPP) and (T.NumColors = Src.NumColors) and
        CompareMem(@T.Colors[0], @Src.Colors[0], Src.NumColors * 4) then
        Conv := ckIdentity
      else
      begin
        Conv := ckLUT;
        for I := 0 to (1 shl Src.BPP) - 1 do
          LUT[I] := T.RGBToNative(Src.NativeToRGB(I));
      end;
    end
    else if T.BPP <= 8 then
      Conv := ckRGBToIndex
    else if ((Src.BPP = 24) or (Src.BPP = 32)) and ((T.BPP = 24) or (T.BPP = 32)) then
      Conv := ckRGBToRGB
    else
      Conv := ckGeneric;
  end;

  for I := 0 to High(Clip) do
  begin
    CR := Clip[I];
    { fast paths: unstretched SRCCOPY }
    if UseSrc and (Code = $CC) and (SW = W) and (SH = H) and (FlipX = 0) and (FlipY = 0) then
    begin
      for YY := CR.Top to CR.Bottom - 1 do
      begin
        SYY := SY + (YY - DR.Top);
        if (SYY < 0) or (SYY >= Src.Height) then Continue;
        SXX := SX + (CR.Left - DR.Left);
        XX := CR.Left;
        Cnt := CR.Right - CR.Left;
        { clip source columns }
        if SXX < 0 then begin Inc(XX, -SXX); Dec(Cnt, -SXX); SXX := 0; end;
        if SXX + Cnt > Src.Width then Cnt := Src.Width - SXX;
        if Cnt <= 0 then Continue;
        SRow := Src.RowPtr(SYY);
        DRow := T.RowPtr(YY);
        if (Conv = ckIdentity) and (Src.BPP = T.BPP) and (T.BPP >= 8) then
          Move(SRow[SXX * (T.BPP div 8)], DRow[XX * (T.BPP div 8)], Cnt * (T.BPP div 8))
        else if (Conv = ckLUT) and (Src.BPP = 8) and (T.BPP = 32) then
        begin
          while Cnt > 0 do
          begin
            PLongWord(DRow + XX * 4)^ := LUT[SRow[SXX]];
            Inc(XX); Inc(SXX); Dec(Cnt);
          end;
        end
        else if (Conv = ckRGBToRGB) and (Src.BPP = 24) and (T.BPP = 32) then
        begin
          while Cnt > 0 do
          begin
            PLongWord(DRow + XX * 4)^ := SRow[SXX * 3] or (LongWord(SRow[SXX * 3 + 1]) shl 8) or
              (LongWord(SRow[SXX * 3 + 2]) shl 16);
            Inc(XX); Inc(SXX); Dec(Cnt);
          end;
        end
        else
        begin
          while Cnt > 0 do
          begin
            S := Src.GetNative(SXX, SYY);
            case Conv of
              ckLUT: V := LUT[S];
              ckToMono: if S = SrcBkNative then V := 1 else V := 0;
              ckRGBToIndex: V := T.Nearest(Src.NativeToRGB(S));
              ckRGBToRGB: V := S;
              ckIdentity: V := S;
            else
              V := T.RGBToNative(Src.NativeToRGB(S));
            end;
            T.SetNative(XX, YY, V);
            Inc(XX); Inc(SXX); Dec(Cnt);
          end;
        end;
      end;
      Continue;
    end;

    { general path: row buffers }
    DW := W; DH := H;
    N := CR.Right - CR.Left;
    if Length(SBuf) < N then
    begin
      SetLength(SBuf, N);
      SetLength(DBuf, N);
      SetLength(Valid, N);
    end;
    for YY := CR.Top to CR.Bottom - 1 do
    begin
      XA := 0;
      XB := N;
      if UseSrc then
      begin
        if FlipY = 0 then
          SYY := SY + Int64(YY - DR.Top) * SH div DH
        else
          SYY := SY + SH - 1 - Int64(YY - DR.Top) * SH div DH;
        if (SYY < 0) or (SYY >= Src.Height) then Continue;
        if (SW = DW) and (FlipX = 0) then
        begin
          { unstretched: one contiguous source run }
          SXX := SX + (CR.Left - DR.Left);
          if SXX < 0 then XA := -SXX;
          if SXX + N > Src.Width then XB := Src.Width - SXX;
          if XB <= XA then Continue;
          ZMReadRow(Src, SYY, SXX + XA, XB - XA, @SBuf[XA]);
          for I2 := XA to XB - 1 do Valid[I2] := True;
        end
        else
          for I2 := 0 to N - 1 do
          begin
            if FlipX = 0 then
              SXX := SX + Int64(CR.Left + I2 - DR.Left) * SW div DW
            else
              SXX := SX + SW - 1 - Int64(CR.Left + I2 - DR.Left) * SW div DW;
            Valid[I2] := (SXX >= 0) and (SXX < Src.Width);
            if Valid[I2] then SBuf[I2] := Src.GetNative(SXX, SYY) else SBuf[I2] := 0;
          end;
        { colour conversion }
        case Conv of
          ckLUT: for I2 := XA to XB - 1 do SBuf[I2] := LUT[SBuf[I2] and $FF];
          ckToMono: for I2 := XA to XB - 1 do
              if SBuf[I2] = SrcBkNative then SBuf[I2] := 1 else SBuf[I2] := 0;
          ckRGBToIndex: for I2 := XA to XB - 1 do SBuf[I2] := T.Nearest(Src.NativeToRGB(SBuf[I2]));
          ckRGBToRGB, ckIdentity: ;
        else
          for I2 := XA to XB - 1 do SBuf[I2] := T.RGBToNative(Src.NativeToRGB(SBuf[I2]));
        end;
      end
      else
        for I2 := 0 to N - 1 do Valid[I2] := True;
      if UseDst or not ((SW = DW) and (FlipX = 0)) or not UseSrc then
        ZMReadRow(T, YY, CR.Left, N, @DBuf[0]);
      case Code of
        $CC: for I2 := XA to XB - 1 do if Valid[I2] then DBuf[I2] := SBuf[I2];
        $88: for I2 := XA to XB - 1 do if Valid[I2] then DBuf[I2] := DBuf[I2] and SBuf[I2];
        $EE: for I2 := XA to XB - 1 do if Valid[I2] then DBuf[I2] := DBuf[I2] or SBuf[I2];
        $66: for I2 := XA to XB - 1 do if Valid[I2] then DBuf[I2] := (DBuf[I2] xor SBuf[I2]) and Mask;
        $55: for I2 := XA to XB - 1 do DBuf[I2] := (not DBuf[I2]) and Mask;
        $00: for I2 := XA to XB - 1 do DBuf[I2] := 0;
        $FF: for I2 := XA to XB - 1 do DBuf[I2] := Mask;
      else
        for I2 := XA to XB - 1 do
          if Valid[I2] then
          begin
            if UsePat then P := PatAt(PI, Dst, CR.Left + I2, YY) else P := 0;
            DBuf[I2] := Rop3(Code, P, SBuf[I2], DBuf[I2]) and Mask;
          end;
      end;
      ZMWriteRow(T, YY, CR.Left + XA, XB - XA, @DBuf[XA]);
    end;
  end;
  T.Dirty := True;
end;

procedure GdiBlt(Dst: TZMDC; X, Y, W, H: Integer; Src: TZMDC; SX, SY, SW, SH: Integer;
  Rop: DWORD; Stretch: Boolean);
var
  SB: TZMBitmap;
  SOX, SOY: Integer;
begin
  if Dst = nil then Exit;
  if Src <> nil then
  begin
    SB := Src.Target;
    SOX := Src.OffX;
    SOY := Src.OffY;
    GdiBltBitmap(Dst, X, Y, W, H, SB, Src.St.BkColor, SX + SOX, SY + SOY, SW, SH, Rop, Stretch);
  end
  else
    GdiBltBitmap(Dst, X, Y, W, H, nil, 0, 0, 0, 0, 0, Rop, Stretch);
end;

procedure GdiPatBlt(DC: TZMDC; X, Y, W, H: Integer; Rop: DWORD);
begin
  GdiBltBitmap(DC, X, Y, W, H, nil, 0, 0, 0, 0, 0, Rop and $00FF0000, False);
end;

{ fill a rect (target coords) with a solid native value, clipped }
procedure FillNative(DC: TZMDC; R: TRect; V: LongWord);
var
  Clip: TZMRects;
  I, X, Y: Integer;
  T: TZMBitmap;
  P: PLongWord;
  CR: TRect;
begin
  T := DC.Target;
  if (T = nil) or (T.Bits = nil) then Exit;
  Clip := RectsIntersectRect(DC.Eff, R);
  for I := 0 to High(Clip) do
  begin
    CR := Clip[I];
    for Y := CR.Top to CR.Bottom - 1 do
      case T.BPP of
        32:
          begin
            P := PLongWord(T.RowPtr(Y)) + CR.Left;
            for X := CR.Left to CR.Right - 1 do
            begin
              P^ := V;
              Inc(P);
            end;
          end;
        8: FillChar(T.RowPtr(Y)[CR.Left], CR.Right - CR.Left, Byte(V));
      else
        for X := CR.Left to CR.Right - 1 do T.SetNative(X, Y, V);
      end;
  end;
  T.Dirty := True;
end;

procedure GdiFillRect(DC: TZMDC; const R: TRect; Br: TZMBrush);
var
  Old: TZMBrush;
begin
  if (Br = nil) or (Br.Style = BS_NULL) then Exit;
  Old := DC.St.Brush;
  DC.St.Brush := Br;
  try
    GdiPatBlt(DC, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top, PATCOPY);
  finally
    DC.St.Brush := Old;
  end;
end;

procedure GdiFillSolid(DC: TZMDC; const R: TRect; C: COLORREF);
var
  OX, OY: Integer;
begin
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  OX := DC.OffX; OY := DC.OffY;
  FillNative(DC, Rect(R.Left + OX, R.Top + OY, R.Right + OX, R.Bottom + OY), DC.ColorToNative(C));
end;

procedure GdiInvertRect(DC: TZMDC; const R: TRect);
begin
  GdiPatBlt(DC, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top, DSTINVERT);
end;

{ ---------------------------------------------------------------- pixels & lines }

procedure PlotNative(DC: TZMDC; X, Y: Integer; V: LongWord; R2: Integer); inline;
var
  T: TZMBitmap;
  D: LongWord;
begin
  T := DC.Target;
  if (X < 0) or (Y < 0) or (X >= T.Width) or (Y >= T.Height) then Exit;
  if not RectsContain(DC.Eff, X, Y) then Exit;
  if R2 = R2_COPYPEN then
    T.SetNative(X, Y, V)
  else
  begin
    D := T.GetNative(X, Y);
    case R2 of
      R2_BLACK: D := 0;
      R2_WHITE: D := T.RGBToNative($FFFFFF);
      R2_NOT: D := not D;
      R2_XORPEN: D := D xor V;
      R2_NOTXORPEN: D := not (D xor V);
      R2_MASKPEN: D := D and V;
      R2_MERGEPEN: D := D or V;
      R2_NOTCOPYPEN: D := not V;
      R2_NOP: Exit;
    else
      D := V;
    end;
    T.SetNative(X, Y, D and T.NativeMask);
  end;
  T.Dirty := True;
end;

procedure GdiSetPixel(DC: TZMDC; X, Y: Integer; C: COLORREF);
begin
  if DC.Target = nil then Exit;
  PlotNative(DC, X + DC.OffX, Y + DC.OffY, DC.ColorToNative(C), R2_COPYPEN);
end;

function GdiGetPixel(DC: TZMDC; X, Y: Integer): COLORREF;
var
  T: TZMBitmap;
begin
  T := DC.Target;
  Result := CLR_INVALID;
  if T = nil then Exit;
  Inc(X, DC.OffX); Inc(Y, DC.OffY);
  if (X < 0) or (Y < 0) or (X >= T.Width) or (Y >= T.Height) then Exit;
  Result := RGBToColorRef(T.NativeToRGB(T.GetNative(X, Y)));
end;

procedure PenPlot(DC: TZMDC; X, Y: Integer; V: LongWord; PW: Integer);
var
  I, J, H: Integer;
begin
  if PW <= 1 then
    PlotNative(DC, X, Y, V, DC.St.ROP2)
  else
  begin
    H := PW div 2;
    for J := Y - H to Y - H + PW - 1 do
      for I := X - H to X - H + PW - 1 do
        PlotNative(DC, I, J, V, DC.St.ROP2);
  end;
end;

procedure LineNative(DC: TZMDC; X1, Y1, X2, Y2: Integer; V: LongWord; PW: Integer;
  Style: UINT; LastPixel: Boolean);
var
  DX, DY, SX, SY, Err, E2, N: Integer;
  Draw: Boolean;
begin
  DX := Abs(X2 - X1); DY := -Abs(Y2 - Y1);
  if X1 < X2 then SX := 1 else SX := -1;
  if Y1 < Y2 then SY := 1 else SY := -1;
  Err := DX + DY;
  N := 0;
  while True do
  begin
    if (X1 = X2) and (Y1 = Y2) then
    begin
      if LastPixel then PenPlot(DC, X1, Y1, V, PW);
      Break;
    end;
    case Style of
      PS_DOT: Draw := (N mod 2) = 0;
      PS_DASH: Draw := (N mod 9) < 6;
      PS_DASHDOT: Draw := ((N mod 12) < 6) or ((N mod 12) in [8, 9]);
    else
      Draw := True;
    end;
    if Draw then PenPlot(DC, X1, Y1, V, PW);
    Inc(N);
    E2 := 2 * Err;
    if E2 >= DY then begin Inc(Err, DY); Inc(X1, SX); end;
    if E2 <= DX then begin Inc(Err, DX); Inc(Y1, SY); end;
  end;
end;

procedure GdiLine(DC: TZMDC; X1, Y1, X2, Y2: Integer; LastPixel: Boolean);
var
  P: TZMPen;
begin
  P := DC.St.Pen;
  if (P = nil) or (P.Style = PS_NULL) or (DC.Target = nil) then Exit;
  LineNative(DC, X1 + DC.OffX, Y1 + DC.OffY, X2 + DC.OffX, Y2 + DC.OffY,
    DC.ColorToNative(P.Color), P.Width, P.Style, LastPixel);
end;

procedure GdiRectangle(DC: TZMDC; X1, Y1, X2, Y2: Integer);
var
  P: TZMPen;
  T: Integer;
begin
  if X2 < X1 then begin T := X1; X1 := X2; X2 := T; end;
  if Y2 < Y1 then begin T := Y1; Y1 := Y2; Y2 := T; end;
  P := DC.St.Pen;
  if (DC.St.Brush <> nil) and (DC.St.Brush.Style <> BS_NULL) then
  begin
    if (P <> nil) and (P.Style <> PS_NULL) then
      GdiPatBlt(DC, X1 + 1, Y1 + 1, X2 - X1 - 2, Y2 - Y1 - 2, PATCOPY)
    else
      GdiPatBlt(DC, X1, Y1, X2 - X1 - 1, Y2 - Y1 - 1, PATCOPY);
  end;
  if (P <> nil) and (P.Style <> PS_NULL) then
  begin
    GdiLine(DC, X1, Y1, X2 - 1, Y1, False);
    GdiLine(DC, X2 - 1, Y1, X2 - 1, Y2 - 1, False);
    GdiLine(DC, X2 - 1, Y2 - 1, X1, Y2 - 1, False);
    GdiLine(DC, X1, Y2 - 1, X1, Y1, False);
  end;
end;

{ scanline polygon fill (alternate rule), target coordinates }
procedure FillPolyNative(DC: TZMDC; const Pts: array of TPoint);
var
  MinY, MaxY, Y, I, J, N, K, T: Integer;
  Xs: array of Integer;
  PI: TPatInfo;
  X, XA, XB: Integer;
  YF, X1, Y1, X2, Y2: Double;
begin
  N := Length(Pts);
  if N < 3 then Exit;
  PreparePattern(DC, PI);
  MinY := Pts[0].Y; MaxY := Pts[0].Y;
  for I := 1 to N - 1 do
  begin
    if Pts[I].Y < MinY then MinY := Pts[I].Y;
    if Pts[I].Y > MaxY then MaxY := Pts[I].Y;
  end;
  SetLength(Xs, N);
  for Y := MinY to MaxY - 1 do
  begin
    YF := Y + 0.5;
    K := 0;
    J := N - 1;
    for I := 0 to N - 1 do
    begin
      X1 := Pts[J].X; Y1 := Pts[J].Y; X2 := Pts[I].X; Y2 := Pts[I].Y;
      if ((Y1 <= YF) and (Y2 > YF)) or ((Y2 <= YF) and (Y1 > YF)) then
      begin
        Xs[K] := Round(X1 + (YF - Y1) * (X2 - X1) / (Y2 - Y1));
        Inc(K);
      end;
      J := I;
    end;
    { sort }
    for I := 1 to K - 1 do
    begin
      T := Xs[I]; J := I - 1;
      while (J >= 0) and (Xs[J] > T) do begin Xs[J + 1] := Xs[J]; Dec(J); end;
      Xs[J + 1] := T;
    end;
    I := 0;
    while I + 1 < K do
    begin
      XA := Xs[I]; XB := Xs[I + 1];
      for X := XA to XB - 1 do
        PlotNative(DC, X, Y, PatAt(PI, DC, X, Y), R2_COPYPEN);
      Inc(I, 2);
    end;
  end;
end;

procedure GdiPolygon(DC: TZMDC; const Pts: array of TPoint; Fill: Boolean);
var
  T: array of TPoint;
  I, N: Integer;
begin
  N := Length(Pts);
  if (N < 2) or (DC.Target = nil) then Exit;
  SetLength(T, N);
  for I := 0 to N - 1 do T[I] := DC.LPtoT(Pts[I].X, Pts[I].Y);
  if Fill and (DC.St.Brush <> nil) and (DC.St.Brush.Style <> BS_NULL) then
    FillPolyNative(DC, T);
  if (DC.St.Pen <> nil) and (DC.St.Pen.Style <> PS_NULL) then
    for I := 0 to N - 1 do
      LineNative(DC, T[I].X, T[I].Y, T[(I + 1) mod N].X, T[(I + 1) mod N].Y,
        DC.ColorToNative(DC.St.Pen.Color), DC.St.Pen.Width, DC.St.Pen.Style, False);
end;

procedure GdiPolyline(DC: TZMDC; const Pts: array of TPoint);
var
  I: Integer;
begin
  for I := 0 to High(Pts) - 1 do
    GdiLine(DC, Pts[I].X, Pts[I].Y, Pts[I + 1].X, Pts[I + 1].Y, False);
end;

procedure EllipsePoints(X1, Y1, X2, Y2: Integer; var Pts: TZMRects);
{ returns, per row, the horizontal span [Left, Right) of the ellipse inscribed in the
  rectangle, in Pts (Top = Bottom - 1 = row) }
var
  CX, CY, RX, RY, DYv, HW: Double;
  Y: Integer;
begin
  Pts := nil;
  RX := (X2 - X1) / 2; RY := (Y2 - Y1) / 2;
  if (RX <= 0) or (RY <= 0) then Exit;
  CX := X1 + RX; CY := Y1 + RY;
  for Y := Y1 to Y2 - 1 do
  begin
    DYv := (Y + 0.5 - CY) / RY;
    if Abs(DYv) > 1 then Continue;
    HW := RX * Sqrt(1 - DYv * DYv);
    SetLength(Pts, Length(Pts) + 1);
    Pts[High(Pts)] := Rect(Round(CX - HW), Y, Round(CX + HW), Y + 1);
  end;
end;

procedure GdiEllipse(DC: TZMDC; X1, Y1, X2, Y2: Integer);
var
  Spans: TZMRects;
  I, X: Integer;
  PI: TPatInfo;
  OX, OY: Integer;
  V: LongWord;
  PW: Integer;
  Prev: TRect;
begin
  if DC.Target = nil then Exit;
  OX := DC.OffX; OY := DC.OffY;
  EllipsePoints(X1 + OX, Y1 + OY, X2 + OX, Y2 + OY, Spans);
  if (DC.St.Brush <> nil) and (DC.St.Brush.Style <> BS_NULL) then
  begin
    PreparePattern(DC, PI);
    for I := 0 to High(Spans) do
      for X := Spans[I].Left to Spans[I].Right - 1 do
        PlotNative(DC, X, Spans[I].Top, PatAt(PI, DC, X, Spans[I].Top), R2_COPYPEN);
  end;
  if (DC.St.Pen <> nil) and (DC.St.Pen.Style <> PS_NULL) and (Length(Spans) > 0) then
  begin
    V := DC.ColorToNative(DC.St.Pen.Color);
    PW := DC.St.Pen.Width;
    for I := 0 to High(Spans) do
    begin
      if I = 0 then Prev := Spans[I] else Prev := Spans[I - 1];
      { left and right edges, connected to the previous row }
      for X := Min(Spans[I].Left, Prev.Left) to Max(Spans[I].Left, Prev.Left) do
        PenPlot(DC, X, Spans[I].Top, V, PW);
      for X := Min(Spans[I].Right, Prev.Right) - 1 to Max(Spans[I].Right, Prev.Right) - 1 do
        PenPlot(DC, X, Spans[I].Top, V, PW);
    end;
    for X := Spans[0].Left to Spans[0].Right - 1 do PenPlot(DC, X, Spans[0].Top, V, PW);
    I := High(Spans);
    for X := Spans[I].Left to Spans[I].Right - 1 do PenPlot(DC, X, Spans[I].Top, V, PW);
  end;
end;

procedure GdiRoundRect(DC: TZMDC; X1, Y1, X2, Y2, RW, RH: Integer);
var
  Pts: array of TPoint;
  N, I, Steps: Integer;
  A, RX, RY: Double;
  procedure Corner(CX, CY: Double; A0: Double);
  var J: Integer;
  begin
    for J := 0 to Steps do
    begin
      A := A0 + (Pi / 2) * J / Steps;
      Pts[N] := Point(Round(CX + RX * Cos(A)), Round(CY - RY * Sin(A)));
      Inc(N);
    end;
  end;
begin
  RX := RW / 2; RY := RH / 2;
  if (RX < 1) or (RY < 1) then
  begin
    GdiRectangle(DC, X1, Y1, X2, Y2);
    Exit;
  end;
  if RX > (X2 - X1) / 2 then RX := (X2 - X1) / 2;
  if RY > (Y2 - Y1) / 2 then RY := (Y2 - Y1) / 2;
  Steps := 6;
  SetLength(Pts, 4 * (Steps + 1));
  N := 0;
  Corner(X2 - 1 - RX, Y1 + RY, 0);
  Corner(X1 + RX, Y1 + RY, Pi / 2);
  Corner(X1 + RX, Y2 - 1 - RY, Pi);
  Corner(X2 - 1 - RX, Y2 - 1 - RY, 3 * Pi / 2);
  I := N;
  SetLength(Pts, I);
  GdiPolygon(DC, Pts, True);
end;

procedure GdiFocusRect(DC: TZMDC; const R: TRect);
var
  X, Y, OX, OY: Integer;
  T: TZMBitmap;
  procedure Inv(PX, PY: Integer);
  begin
    if (PX < 0) or (PY < 0) or (PX >= T.Width) or (PY >= T.Height) then Exit;
    if not RectsContain(DC.Eff, PX, PY) then Exit;
    T.SetNative(PX, PY, (not T.GetNative(PX, PY)) and T.NativeMask);
  end;
begin
  T := DC.Target;
  if T = nil then Exit;
  OX := DC.OffX; OY := DC.OffY;
  for X := R.Left to R.Right - 1 do
    if (X + R.Top) and 1 = 0 then
    begin
      Inv(X + OX, R.Top + OY);
      if R.Bottom - 1 > R.Top then Inv(X + OX, R.Bottom - 1 + OY);
    end;
  for Y := R.Top + 1 to R.Bottom - 2 do
    if (Y + R.Left) and 1 = 0 then
    begin
      Inv(R.Left + OX, Y + OY);
      if R.Right - 1 > R.Left then Inv(R.Right - 1 + OX, Y + OY);
    end;
  T.Dirty := True;
end;

procedure GdiFloodFill(DC: TZMDC; X, Y: Integer; C: COLORREF; Surface: Boolean);
var
  T: TZMBitmap;
  Ref, V: LongWord;
  Stack: array of TPoint;
  SP: Integer;
  P: TPoint;
  PI: TPatInfo;
  Visited: array of Boolean;
  function Match(PX, PY: Integer): Boolean;
  var N: LongWord;
  begin
    N := T.GetNative(PX, PY);
    if Surface then Result := N = Ref else Result := N <> Ref;
  end;
  procedure Push(PX, PY: Integer);
  begin
    if (PX < 0) or (PY < 0) or (PX >= T.Width) or (PY >= T.Height) then Exit;
    if Visited[PY * T.Width + PX] then Exit;
    if not RectsContain(DC.Eff, PX, PY) then Exit;
    if not Match(PX, PY) then Exit;
    Visited[PY * T.Width + PX] := True;
    if SP >= Length(Stack) then SetLength(Stack, Length(Stack) * 2 + 64);
    Stack[SP] := Point(PX, PY);
    Inc(SP);
  end;
begin
  T := DC.Target;
  if T = nil then Exit;
  Inc(X, DC.OffX); Inc(Y, DC.OffY);
  Ref := DC.ColorToNative(C);
  PreparePattern(DC, PI);
  SetLength(Visited, T.Width * T.Height);
  SP := 0;
  Push(X, Y);
  while SP > 0 do
  begin
    Dec(SP);
    P := Stack[SP];
    V := PatAt(PI, DC, P.X, P.Y);
    T.SetNative(P.X, P.Y, V);
    Push(P.X + 1, P.Y); Push(P.X - 1, P.Y); Push(P.X, P.Y + 1); Push(P.X, P.Y - 1);
  end;
  T.Dirty := True;
end;

{ ---------------------------------------------------------------- text }

function GdiFace(DC: TZMDC): PZMFace;
begin
  if (DC.St.Font <> nil) and (DC.St.Font.Face <> nil) then
    Result := DC.St.Font.Face
  else
    Result := TZMFontObj(StockObjects[SYSTEM_FONT]).Face;
end;

{ Like Wine's DIB engine: TrueType fonts are anti-aliased (GGO_GRAY4) on DIBs
  deeper than 8 bpp; bitmap fonts (MS Sans Serif, System, ...) and <= 8 bpp
  targets get 1-bit glyphs. The glyph advances differ between the two. }
function IsBitmapFontName(const Name: string): Boolean;
var
  N: string;
begin
  N := LowerCase(Trim(Name));
  Result := (N = 'ms sans serif') or (N = 'ms serif') or (N = 'system') or (N = 'fixedsys') or
    (N = 'terminal') or (N = 'small fonts') or (N = 'courier') or (N = 'modern') or
    (N = 'roman') or (N = 'script') or (N = '');
end;

function GdiUseAA(DC: TZMDC): Boolean;
var
  F: TZMFontObj;
begin
  Result := False;
  { anti-aliasing needs a > 8 bpp target and a size the font's gasp table marks
    for grey-scale rendering (as Windows/Wine do) }
  if (DC.Target = nil) or (DC.Target.BPP <= 8) then Exit;
  F := DC.St.Font;
  if (F = nil) or (F.LF.lfQuality = NONANTIALIASED_QUALITY) then Exit;
  if F.BitmapFont < 0 then
    if IsBitmapFontName(StrPas(F.LF.lfFaceName)) then F.BitmapFont := 1 else F.BitmapFont := 0;
  Result := (F.BitmapFont = 0) and not ZMNoAntialias and GdiFace(DC)^.Gray;
end;

function GdiGlyphs(DC: TZMDC): PZMGlyphs;
begin
  if GdiUseAA(DC) then Result := @GdiFace(DC)^.AAGlyphs else Result := @GdiFace(DC)^.Glyphs;
end;

{ Text extents use the normally hinted advances of TrueType fonts even where the
  glyphs are drawn 1-bit with the (narrower or wider) mono advances: Wine measures
  with GGO_METRICS (FT_LOAD_DEFAULT) and renders with FT_LOAD_TARGET_MONO. }
function GdiExtentGlyphs(DC: TZMDC): PZMGlyphs;
var
  F: TZMFontObj;
begin
  F := DC.St.Font;
  if F <> nil then
  begin
    if F.BitmapFont < 0 then
      if IsBitmapFontName(StrPas(F.LF.lfFaceName)) then F.BitmapFont := 1 else F.BitmapFont := 0;
    if (F.BitmapFont = 0) and not ZMNoAntialias then Exit(@GdiFace(DC)^.AAGlyphs);
  end;
  Result := @GdiFace(DC)^.Glyphs;
end;

function GdiTextWidth(DC: TZMDC; S: PAnsiChar; Count: Integer): Integer;
var
  I: Integer;
  G: PZMGlyphs;
begin
  Result := 0;
  if S = nil then Exit;
  G := GdiExtentGlyphs(DC);
  for I := 0 to Count - 1 do
    Inc(Result, G^[Byte(S[I])].Adv + DC.St.CharExtra);
end;

{ Wine dibdrv: anti-aliased glyph pixels blend with a gamma ramp }
const
  AARamp: array[0..16] of Byte = (0, $4d, $68, $7c, $8c, $9a, $a7, $b2, $bd, $c7, $d0, $d9,
    $e1, $e9, $f0, $f8, $ff);

function AAComp(Dst, Text, Level: Integer): Integer; inline;
var
  MinC, MaxC: Integer;
begin
  MinC := (AARamp[Level] * Text) div $FF;
  MaxC := AARamp[16 - Level] + (($FF - AARamp[16 - Level]) * Text) div $FF;
  if Dst = Text then Result := Dst
  else if Dst > Text then Result := Text + ((Dst - Text) * (MaxC - Text)) div ($FF - Text)
  else Result := Text - ((Text - Dst) * (Text - MinC)) div Text;
end;

procedure DrawGlyphAA(DC: TZMDC; const G: TZMGlyph; X, Y: Integer; RGB: LongWord; const Clip: TZMRects);
var
  I, PX, PY, L: Integer;
  GR, CR: TRect;
  Row: PByte;
  T: TZMBitmap;
  D: LongWord;
  TR, TG, TB: Integer;
begin
  if (G.W <= 0) or (G.H <= 0) or (G.Data = nil) then Exit;
  T := DC.Target;
  TR := (RGB shr 16) and $FF; TG := (RGB shr 8) and $FF; TB := RGB and $FF;
  GR := Rect(X + G.XOff, Y + G.YOff, X + G.XOff + G.W, Y + G.YOff + G.H);
  for I := 0 to High(Clip) do
  begin
    CR := Clip[I];
    if CR.Left < GR.Left then CR.Left := GR.Left;
    if CR.Top < GR.Top then CR.Top := GR.Top;
    if CR.Right > GR.Right then CR.Right := GR.Right;
    if CR.Bottom > GR.Bottom then CR.Bottom := GR.Bottom;
    if (CR.Right <= CR.Left) or (CR.Bottom <= CR.Top) then Continue;
    for PY := CR.Top to CR.Bottom - 1 do
    begin
      Row := G.Data + (PY - GR.Top) * G.W;
      for PX := CR.Left to CR.Right - 1 do
      begin
        L := Row[PX - GR.Left];
        if L <= 1 then Continue;   { zoals Wine: niveau 0 en 1 laten de pixel staan }
        if L >= 16 then
          T.SetNative(PX, PY, T.RGBToNative(RGB))
        else
        begin
          D := T.NativeToRGB(T.GetNative(PX, PY));
          D := (LongWord(AAComp((D shr 16) and $FF, TR, L)) shl 16) or
            (LongWord(AAComp((D shr 8) and $FF, TG, L)) shl 8) or LongWord(AAComp(D and $FF, TB, L));
          T.SetNative(PX, PY, T.RGBToNative(D));
        end;
      end;
    end;
  end;
end;

procedure DrawGlyph(DC: TZMDC; const G: TZMGlyph; X, Y: Integer; V: LongWord; const Clip: TZMRects);
var
  I, R, C, Stride, PX, PY: Integer;
  GR, CR: TRect;
  Row: PByte;
  T: TZMBitmap;
begin
  if (G.W <= 0) or (G.H <= 0) or (G.Data = nil) then Exit;
  T := DC.Target;
  Stride := (G.W + 7) div 8;
  GR := Rect(X + G.XOff, Y + G.YOff, X + G.XOff + G.W, Y + G.YOff + G.H);
  for I := 0 to High(Clip) do
  begin
    CR := Clip[I];
    if CR.Left < GR.Left then CR.Left := GR.Left;
    if CR.Top < GR.Top then CR.Top := GR.Top;
    if CR.Right > GR.Right then CR.Right := GR.Right;
    if CR.Bottom > GR.Bottom then CR.Bottom := GR.Bottom;
    if (CR.Right <= CR.Left) or (CR.Bottom <= CR.Top) then Continue;
    for PY := CR.Top to CR.Bottom - 1 do
    begin
      R := PY - GR.Top;
      Row := G.Data + R * Stride;
      for PX := CR.Left to CR.Right - 1 do
      begin
        C := PX - GR.Left;
        if Row[C shr 3] and ($80 shr (C and 7)) <> 0 then
          T.SetNative(PX, PY, V);
      end;
    end;
  end;
end;

procedure GdiTextOut(DC: TZMDC; X, Y: Integer; S: PAnsiChar; Count: Integer;
  DoOpaque: Boolean; ClipR: PRect; OpaqueR: PRect);
var
  Face: PZMFace;
  W, I, TX, TY, OX, OY: Integer;
  Clip: TZMRects;
  V: LongWord;
  BG: TRect;
  Align: UINT;
  LF: TLogFont;
  Glyphs: PZMGlyphs;
  AA: Boolean;
begin
  if (DC.Target = nil) or (DC.Target.Bits = nil) then Exit;
  Face := GdiFace(DC);
  Glyphs := GdiGlyphs(DC);
  AA := GdiUseAA(DC);
  W := GdiTextWidth(DC, S, Count);
  Align := DC.St.TextAlign;
  if Align and TA_UPDATECP <> 0 then
  begin
    X := DC.St.CurPos.X;
    Y := DC.St.CurPos.Y;
  end;
  case Align and (TA_CENTER) of
    TA_RIGHT: Dec(X, W);
    TA_CENTER: Dec(X, W div 2);
  end;
  if Align and TA_BASELINE = TA_BASELINE then Dec(Y, Face^.Ascent)
  else if Align and TA_BOTTOM <> 0 then Dec(Y, Face^.Height);
  if Align and TA_UPDATECP <> 0 then
    DC.St.CurPos.X := X + W;
  OX := DC.OffX; OY := DC.OffY;
  Clip := DC.Eff;
  if ClipR <> nil then
    Clip := RectsIntersectRect(Clip, Rect(ClipR^.Left + OX, ClipR^.Top + OY, ClipR^.Right + OX, ClipR^.Bottom + OY));
  if OpaqueR <> nil then
    FillNative(DC, Rect(OpaqueR^.Left + OX, OpaqueR^.Top + OY, OpaqueR^.Right + OX, OpaqueR^.Bottom + OY),
      DC.ColorToNative(DC.St.BkColor));
  if DoOpaque and (DC.St.BkMode = OPAQUE) then
  begin
    BG := Rect(X + OX, Y + OY, X + OX + W, Y + OY + Face^.Height);
    if ClipR <> nil then
      IntersectRect(BG, BG, Rect(ClipR^.Left + OX, ClipR^.Top + OY, ClipR^.Right + OX, ClipR^.Bottom + OY));
    FillNative(DC, BG, DC.ColorToNative(DC.St.BkColor));
  end;
  V := DC.ColorToNative(DC.St.TextColor);
  TX := X + OX;
  TY := Y + OY;
  for I := 0 to Count - 1 do
  begin
    if AA then
      DrawGlyphAA(DC, Glyphs^[Byte(S[I])], TX, TY, DC.ColorToRGB(DC.St.TextColor), Clip)
    else
      DrawGlyph(DC, Glyphs^[Byte(S[I])], TX, TY, V, Clip);
    Inc(TX, Glyphs^[Byte(S[I])].Adv + DC.St.CharExtra);
  end;
  if DC.St.Font <> nil then
  begin
    LF := DC.St.Font.LF;
    if LF.lfUnderline <> 0 then
      FillNative(DC, RectsBox(RectsIntersectRect(Clip,
        Rect(X + OX, Y + OY + Face^.Ascent + 1, X + OX + W, Y + OY + Face^.Ascent + 2))), V);
    if LF.lfStrikeOut <> 0 then
      FillNative(DC, RectsBox(RectsIntersectRect(Clip,
        Rect(X + OX, Y + OY + Face^.Ascent * 2 div 3, X + OX + W, Y + OY + Face^.Ascent * 2 div 3 + 1))), V);
  end;
  DC.Target.Dirty := True;
end;

function GdiDrawText(DC: TZMDC; S: PAnsiChar; Count: Integer; var R: TRect; Format: UINT): Integer;
type
  TLine = record Start, Len: Integer; end;
var
  Face: PZMFace;
  Txt: AnsiString;
  Lines: array of TLine;
  I, LineH, MaxW, W, Y, X, P, LastBreak, LineStart, CurW, TotalH: Integer;
  Wrap: Boolean;
  Buf: AnsiString;
  ULPos: Integer;
  procedure AddLine(St, L: Integer);
  begin
    SetLength(Lines, Length(Lines) + 1);
    Lines[High(Lines)].Start := St;
    Lines[High(Lines)].Len := L;
  end;
  function CW(Idx: Integer): Integer;
  begin
    Result := GdiExtentGlyphs(DC)^[Byte(Txt[Idx])].Adv + DC.St.CharExtra;
  end;
  procedure StripPrefix(var Line: AnsiString; var UL: Integer);
  var J: Integer;
  begin
    UL := -1;
    if Format and DT_NOPREFIX <> 0 then Exit;
    J := 1;
    while J <= Length(Line) do
    begin
      if Line[J] = '&' then
      begin
        Delete(Line, J, 1);
        if (J <= Length(Line)) and (Line[J] <> '&') then UL := J;
      end;
      Inc(J);
    end;
  end;
begin
  Result := 0;
  Face := GdiFace(DC);
  if Count < 0 then Count := StrLen(S);
  SetString(Txt, S, Count);
  if Format and DT_EXPANDTABS <> 0 then
    Txt := StringReplace(Txt, #9, '        ', [rfReplaceAll]);
  LineH := Face^.Height;
  if Format and DT_EXTERNALLEADING <> 0 then Inc(LineH, 0);
  MaxW := R.Right - R.Left;
  Wrap := (Format and DT_WORDBREAK <> 0) and (Format and DT_SINGLELINE = 0);
  Lines := nil;
  if Format and DT_SINGLELINE <> 0 then
  begin
    for I := 1 to Length(Txt) do
      if Txt[I] in [#13, #10] then Txt[I] := ' ';
    AddLine(1, Length(Txt));
  end
  else
  begin
    P := 1;
    LineStart := 1;
    LastBreak := 0;
    CurW := 0;
    while P <= Length(Txt) do
    begin
      if Txt[P] = #13 then
      begin
        AddLine(LineStart, P - LineStart);
        if (P < Length(Txt)) and (Txt[P + 1] = #10) then Inc(P);
        Inc(P);
        LineStart := P; LastBreak := 0; CurW := 0;
        Continue;
      end;
      if Txt[P] = #10 then
      begin
        AddLine(LineStart, P - LineStart);
        Inc(P);
        LineStart := P; LastBreak := 0; CurW := 0;
        Continue;
      end;
      if Txt[P] = ' ' then LastBreak := P;
      Inc(CurW, CW(P));
      if Wrap and (CurW > MaxW) and (P > LineStart) then
      begin
        if LastBreak >= LineStart then
        begin
          AddLine(LineStart, LastBreak - LineStart);
          P := LastBreak + 1;
        end
        else
        begin
          AddLine(LineStart, P - LineStart);
        end;
        LineStart := P; LastBreak := 0; CurW := 0;
        Continue;
      end;
      Inc(P);
    end;
    if (LineStart <= Length(Txt)) or (Length(Lines) = 0) then
      AddLine(LineStart, Length(Txt) - LineStart + 1);
  end;
  TotalH := Length(Lines) * LineH;
  if Format and DT_CALCRECT <> 0 then
  begin
    MaxW := 0;
    for I := 0 to High(Lines) do
    begin
      Buf := Copy(Txt, Lines[I].Start, Lines[I].Len);
      StripPrefix(Buf, ULPos);
      W := GdiTextWidth(DC, PAnsiChar(Buf), Length(Buf));
      if W > MaxW then MaxW := W;
    end;
    if not Wrap or (MaxW > R.Right - R.Left) or True then
      R.Right := R.Left + MaxW;
    R.Bottom := R.Top + TotalH;
    Exit(TotalH);
  end;
  if Format and DT_SINGLELINE <> 0 then
  begin
    if Format and DT_VCENTER <> 0 then Y := R.Top + (R.Bottom - R.Top - LineH) div 2
    else if Format and DT_BOTTOM <> 0 then Y := R.Bottom - LineH
    else Y := R.Top;
  end
  else
    Y := R.Top;
  for I := 0 to High(Lines) do
  begin
    Buf := Copy(Txt, Lines[I].Start, Lines[I].Len);
    StripPrefix(Buf, ULPos);
    W := GdiTextWidth(DC, PAnsiChar(Buf), Length(Buf));
    if Format and DT_CENTER <> 0 then X := R.Left + (R.Right - R.Left - W) div 2
    else if Format and DT_RIGHT <> 0 then X := R.Right - W
    else X := R.Left;
    if Format and DT_NOCLIP <> 0 then
      GdiTextOut(DC, X, Y, PAnsiChar(Buf), Length(Buf), True, nil, nil)
    else
      GdiTextOut(DC, X, Y, PAnsiChar(Buf), Length(Buf), True, @R, nil);
    if ULPos > 0 then
    begin
      P := X + GdiTextWidth(DC, PAnsiChar(Buf), ULPos - 1);
      GdiFillSolid(DC, Rect(P, Y + Face^.Ascent + 1, P + GdiExtentGlyphs(DC)^[Byte(Buf[ULPos])].Adv,
        Y + Face^.Ascent + 2), DC.St.TextColor);
    end;
    Inc(Y, LineH);
  end;
  Result := TotalH;
end;

{ ---------------------------------------------------------------- stock objects }

procedure InitStockObjects;
const
  Sys: array[0..28] of COLORREF = (
    $C8D0D4, $808000, $800000, $808080, $C0C0C0, $FFFFFF, $000000, $000000, $000000,
    $FFFFFF, $C0C0C0, $C0C0C0, $808080, $800000, $FFFFFF, $C0C0C0, $808080, $808080,
    $000000, $C0C0C0, $FFFFFF, $000000, $DFDFDF, $000000, $E1FFFF, $B5B5B5, $800000,
    $D08410, $C0C0C0);
var
  B: TZMBrush;
  P: TZMPen;
  LF: TLogFont;
  Pal: TZMPalette;
  I: Integer;
  procedure Stock(Idx: Integer; O: TZMGdiObj);
  begin
    O.IsStock := True;
    StockObjects[Idx] := O;
  end;
  function MkBrush(Style: UINT; C: COLORREF): TZMBrush;
  begin
    Result := TZMBrush.Create;
    Result.Style := Style;
    Result.Color := C;
  end;
  function MkPen(Style: UINT; C: COLORREF): TZMPen;
  begin
    Result := TZMPen.Create;
    Result.Style := Style;
    Result.Color := C;
  end;
  function MkFont(H, Weight: Integer; const Name: AnsiString; Pitch: Byte): TZMFontObj;
  begin
    FillChar(LF, SizeOf(LF), 0);
    LF.lfHeight := H;
    LF.lfWeight := Weight;
    LF.lfPitchAndFamily := Pitch;
    StrPLCopy(LF.lfFaceName, Name, 31);
    Result := TZMFontObj.Create(LF);
  end;
begin
  if StockObjects[0] <> nil then Exit;
  Stock(WHITE_BRUSH, MkBrush(BS_SOLID, $FFFFFF));
  Stock(LTGRAY_BRUSH, MkBrush(BS_SOLID, $C0C0C0));
  Stock(GRAY_BRUSH, MkBrush(BS_SOLID, $808080));
  Stock(DKGRAY_BRUSH, MkBrush(BS_SOLID, $404040));
  Stock(BLACK_BRUSH, MkBrush(BS_SOLID, $000000));
  Stock(NULL_BRUSH, MkBrush(BS_NULL, 0));
  Stock(WHITE_PEN, MkPen(PS_SOLID, $FFFFFF));
  Stock(BLACK_PEN, MkPen(PS_SOLID, 0));
  Stock(NULL_PEN, MkPen(PS_NULL, 0));
  Stock(9, MkBrush(BS_NULL, 0));
  Stock(OEM_FIXED_FONT, MkFont(-12, 400, 'Courier New', FIXED_PITCH));
  Stock(ANSI_FIXED_FONT, MkFont(-12, 400, 'Courier New', FIXED_PITCH));
  Stock(ANSI_VAR_FONT, MkFont(-11, 400, 'MS Sans Serif', VARIABLE_PITCH));
  Stock(SYSTEM_FONT, MkFont(16, 700, 'System', VARIABLE_PITCH));
  Stock(DEVICE_DEFAULT_FONT, MkFont(16, 700, 'System', VARIABLE_PITCH));
  Pal := TZMPalette.Create;
  Pal.Count := 20;
  begin
    { the 20 static system colours }
    HalftoneEntries(Pal.Entries);
    for I := 0 to 9 do Pal.Entries[10 + I] := Pal.Entries[246 + I];
  end;
  Stock(DEFAULT_PALETTE, Pal);
  Stock(SYSTEM_FIXED_FONT, MkFont(-12, 400, 'Courier New', FIXED_PITCH));
  Stock(DEFAULT_GUI_FONT, MkFont(-11, 400, 'MS Sans Serif', VARIABLE_PITCH));
  for I := 0 to High(SysColors) do
  begin
    if I <= High(Sys) then SysColors[I] := Sys[I] else SysColors[I] := 0;
    B := MkBrush(BS_SOLID, SysColors[I]);
    B.IsStock := True;
    SysColorBrushes[I] := B;
  end;
  P := nil;
  if P = nil then ;
end;

initialization
  ZMNoAntialias := GetEnvironmentVariable('ZM_NO_AA') = '1';
  InitStockObjects;
end.

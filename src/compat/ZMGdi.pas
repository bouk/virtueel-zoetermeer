unit ZMGdi;

{ Software-GDI: bitmaps (DIB-achtig, 1/4/8/16/24/32 bpp, rijen van boven naar beneden), paletten,
  kwasten, pennen, lettertypen, rechthoeklijst-regio's en apparaatcontexten, plus de
  rasterbewerkingen achter BitBlt/StretchBlt/PatBlt, lijn- en vormtekening en tekst.

  Handles die de Windows-unit uitdeelt zijn de objectaanwijzers van de klassen
  hieronder (THandle = PtrUInt). Kleuren binnen een bitmap zijn "native" waarden: palet-
  indices voor <= 8 bpp, $00RRGGBB voor 24/32 bpp (B,G,R-bytevolgorde in het geheugen),
  5-5-5 voor 16 bpp. }

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
    constructor Create(ASoort: Integer);
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
    FNearCache: array of SmallInt;   { 15-bit RGB -> dichtstbijzijnde index + 1 }
    FNearStamp: LongWord;
  public
    Width, Height, BPP, Stride: Integer;
    Bits: PByte;
    OwnsBits: Boolean;
    NumColors: Integer;
    Colors: array[0..255] of LongWord;  { $00RRGGBB }
    ColorStamp: LongWord;               { wordt verhoogd wanneer Colors wijzigt }
    Dirty: Boolean;                     { gezet door tekenen (gebruikt voor het scherm) }
    IsDIB: Boolean;                     { DIB-sectie (versus apparaatafhankelijke bitmap) }
    SelectedIn: TObject;                { DC waarin de bitmap is geselecteerd }
    constructor Create(ABreedte, AHoogte, ABPP: Integer);
    destructor Destroy; override;
    procedure SetDefaultColors;
    procedure ColorsChanged;
    function RowPtr(Y: Integer): PByte; inline;
    function GetNative(X, Y: Integer): LongWord;
    procedure SetNative(X, Y: Integer; Waarde: LongWord);
    function NativeToRGB(Waarde: LongWord): LongWord;
    function RGBToNative(RGB: LongWord): LongWord;
    function Nearest(RGB: LongWord): Integer;
    function NativeMask: LongWord;
  end;

  TZMBrush = class(TZMGdiObj)
  public
    Style: UINT;
    Color: COLORREF;
    Hatch: PtrInt;
    Pattern: TZMBitmap;  { eigen kopie voor BS_PATTERN }
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
    BitmapFont: Integer;   { -1 onbekend, 0 TrueType, 1 bitmaplettertype }
    constructor Create(const ALettertype: TLogFont);
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
    Target: TZMBitmap;     { oppervlak waarop getekend wordt }
    IsMemDC: Boolean;
    DefBitmap: TZMBitmap;  { 1x1 mono-bitmap van een nieuwe geheugen-DC }
    Wnd: HWND;             { venster van een vensterDC (0 = scherm / geheugen) }
    IsPaintDC: Boolean;
    DevOrg: TPoint;        { positie van de oorsprong van het apparaat (client) in Target }
    HasVis: Boolean;
    VisRgn: TZMRects;      { zichtbaar gebied in Target-coördinaten }
    VisGen: Integer;       { ZMVisGeneration toen VisRgn berekend werd (vensterDCs) }
    IsWindowDC: Boolean;   { GetWindowDC: oorsprong bij de vensterhoek, niet bij de client }
    PaintRgn: TZMRects;    { BeginPaint: updateregio (Target-coördinaten) }
    HasPaintRgn: Boolean;
    St: TZMDCState;
    Saved: array of TZMDCState;
    constructor Create(ADoel: TZMBitmap);
    destructor Destroy; override;
    procedure InvalidateClip;
    function Eff: TZMRects;                { effectieve knipregio in Target-coördinaten }
    function LPtoT(X, Y: Integer): TPoint; inline;   { logisch -> target }
    function OffX: Integer; inline;
    function OffY: Integer; inline;
    function ColorToNative(Kleur: COLORREF): LongWord;
    function ColorToRGB(Kleur: COLORREF): LongWord;
    procedure SelectBitmap(Bitmap: TZMBitmap);
  end;

var
  { ZM_NO_AA=1: tekst nooit anti-aliasen }
  ZMNoAntialias: Boolean = False;
  { vensterDCs berekenen hun zichtbare regio opnieuw wanneer de vensterindeling wijzigt }
  ZMVisGeneration: Integer = 1;
  ZMVisProvider: procedure(DC: TObject) = nil;

  StockObjects: array[0..17] of TZMGdiObj;
  SysColors: array[0..30] of COLORREF;
  SysColorBrushes: array[0..30] of TZMBrush;

{ handle-hulpfuncties }
function GdiObj(Handvat: THandle): TZMGdiObj;
function GdiDC(Handvat: THandle): TZMDC;
function GdiBitmap(Handvat: THandle): TZMBitmap;
function GdiPalette(Handvat: THandle): TZMPalette;
function GdiBrush(Handvat: THandle): TZMBrush;
function GdiRegion(Handvat: THandle): TZMRegion;
function GdiFont(Handvat: THandle): TZMFontObj;
function H2(Ding: TObject): THandle;

{ kleuren }
function ColorRefToRGB(Kleur: COLORREF): LongWord; inline;   { $00BBGGRR -> $00RRGGBB }
function RGBToColorRef(Kleur: LongWord): COLORREF; inline;

{ rechthoeklijsten }
function RectsIntersectRect(const Rechthoeken: TZMRects; const R: TRect): TZMRects;
function RectsIntersect(const Rechthoeken, Andere: TZMRects): TZMRects;
function RectsSubtractRect(const Rechthoeken: TZMRects; const R: TRect): TZMRects;
function RectsSubtract(const Rechthoeken, Andere: TZMRects): TZMRects;
function RectsUnion(const Rechthoeken, Andere: TZMRects): TZMRects;
function RectsOffset(const Rechthoeken: TZMRects; VerschuifX, VerschuifY: Integer): TZMRects;
function RectsBox(const Rechthoeken: TZMRects): TRect;
function RectsContain(const Rechthoeken: TZMRects; X, Y: Integer): Boolean;
function RectsCopy(const Rechthoeken: TZMRects): TZMRects;

{ tekenprimitieven (coördinaten zijn logisch, d.w.z. zoals ze aan de API worden doorgegeven) }
procedure GdiBlt(DoelDC: TZMDC; X, Y, Breedte, Hoogte: Integer; BronDC: TZMDC; BronPosX, BronPosY, BronBreedte, BronHoogte: Integer;
  Rop: DWORD; Uitrekken: Boolean);
procedure GdiBltBitmap(DoelDC: TZMDC; X, Y, Breedte, Hoogte: Integer; BronBitmap: TZMBitmap; BronAchtergrond: COLORREF;
  BronPosX, BronPosY, BronBreedte, BronHoogte: Integer; Rop: DWORD; Uitrekken: Boolean);
procedure GdiPatBlt(DC: TZMDC; X, Y, Breedte, Hoogte: Integer; Rop: DWORD);
procedure GdiFillRect(DC: TZMDC; const R: TRect; Kwast: TZMBrush);
procedure GdiFillSolid(DC: TZMDC; const R: TRect; Kleur: COLORREF);
procedure GdiInvertRect(DC: TZMDC; const R: TRect);
procedure GdiFocusRect(DC: TZMDC; const R: TRect);
procedure GdiLine(DC: TZMDC; X1, Y1, X2, Y2: Integer; LaatstePixel: Boolean);
procedure GdiRectangle(DC: TZMDC; X1, Y1, X2, Y2: Integer);
procedure GdiEllipse(DC: TZMDC; X1, Y1, X2, Y2: Integer);
procedure GdiRoundRect(DC: TZMDC; X1, Y1, X2, Y2, RondBreedte, RondHoogte: Integer);
procedure GdiPolygon(DC: TZMDC; const Punten: array of TPoint; Vullen: Boolean);
procedure GdiPolyline(DC: TZMDC; const Punten: array of TPoint);
procedure GdiSetPixel(DC: TZMDC; X, Y: Integer; Kleur: COLORREF);
function GdiGetPixel(DC: TZMDC; X, Y: Integer): COLORREF;
procedure GdiFloodFill(DC: TZMDC; X, Y: Integer; Kleur: COLORREF; Oppervlak: Boolean);

{ tekst }
function GdiFace(DC: TZMDC): PZMFace;
function GdiUseAA(DC: TZMDC): Boolean;
function GdiGlyphs(DC: TZMDC): PZMGlyphs;
function GdiTextWidth(DC: TZMDC; Tekst: PAnsiChar; Aantal: Integer): Integer;
function IsBitmapFontName(const Naam: string): Boolean;
procedure GdiTextOut(DC: TZMDC; X, Y: Integer; Tekst: PAnsiChar; Aantal: Integer;
  MetVulling: Boolean; KnipR: PRect; VulR: PRect);
function GdiDrawText(DC: TZMDC; Tekst: PAnsiChar; Aantal: Integer; var R: TRect; Opmaak: UINT): Integer;

{ hulpfuncties }
procedure ZMReadRow(Bitmap: TZMBitmap; Y, X, Aantal: Integer; Buffer: PLongWord);
procedure ZMWriteRow(Bitmap: TZMBitmap; Y, X, Aantal: Integer; Buffer: PLongWord);
function NewBitmapFromInfo(const Info: TBitmapInfo; Gebruik: UINT; Palet: TZMPalette): TZMBitmap;
procedure HalftoneEntries(var Ingangen: array of TPaletteEntry);
procedure InitStockObjects;

implementation

uses SysUtils, Math, Classes, ZMHandles;

{ ---------------------------------------------------------------- objecten }

constructor TZMGdiObj.Create(ASoort: Integer);
begin
  inherited Create;
  Magic := ZM_GDI_MAGIC;
  ObjType := ASoort;
  Handle := ZMAllocHandle(Self);
end;

destructor TZMGdiObj.Destroy;
begin
  Magic := 0;
  ZMFreeHandle(Handle);
  inherited Destroy;
end;

function H2(Ding: TObject): THandle;
begin
  if Ding = nil then Result := 0 else Result := TZMGdiObj(Ding).Handle;
end;

function GdiObj(Handvat: THandle): TZMGdiObj;
var Ding: TObject;
begin
  Result := nil;
  Ding := ZMHandleObj(Handvat);
  if (Ding <> nil) and (Ding is TZMGdiObj) then Result := TZMGdiObj(Ding);
end;

function GdiDC(Handvat: THandle): TZMDC;
var Ding: TZMGdiObj;
begin
  Ding := GdiObj(Handvat);
  if (Ding <> nil) and (Ding is TZMDC) then Result := TZMDC(Ding) else Result := nil;
end;

function GdiBitmap(Handvat: THandle): TZMBitmap;
var Ding: TZMGdiObj;
begin
  Ding := GdiObj(Handvat);
  if (Ding <> nil) and (Ding is TZMBitmap) then Result := TZMBitmap(Ding) else Result := nil;
end;

function GdiPalette(Handvat: THandle): TZMPalette;
var Ding: TZMGdiObj;
begin
  Ding := GdiObj(Handvat);
  if (Ding <> nil) and (Ding is TZMPalette) then Result := TZMPalette(Ding) else Result := nil;
end;

function GdiBrush(Handvat: THandle): TZMBrush;
var Ding: TZMGdiObj;
begin
  if (Handvat > 0) and (Handvat <= 31) then
  begin
    { (COLOR_xxx + 1) gebruikt als klasse-achtergrondkwast }
    Result := SysColorBrushes[Handvat - 1];
    Exit;
  end;
  Ding := GdiObj(Handvat);
  if (Ding <> nil) and (Ding is TZMBrush) then Result := TZMBrush(Ding) else Result := nil;
end;

function GdiRegion(Handvat: THandle): TZMRegion;
var Ding: TZMGdiObj;
begin
  Ding := GdiObj(Handvat);
  if (Ding <> nil) and (Ding is TZMRegion) then Result := TZMRegion(Ding) else Result := nil;
end;

function GdiFont(Handvat: THandle): TZMFontObj;
var Ding: TZMGdiObj;
begin
  Ding := GdiObj(Handvat);
  if (Ding <> nil) and (Ding is TZMFontObj) then Result := TZMFontObj(Ding) else Result := nil;
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

constructor TZMFontObj.Create(const ALettertype: TLogFont);
begin
  inherited Create(OBJ_FONT);
  LF := ALettertype;
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

{ ---------------------------------------------------------------- kleuren }

function ColorRefToRGB(Kleur: COLORREF): LongWord; inline;
begin
  Result := ((Kleur and $FF) shl 16) or (Kleur and $FF00) or ((Kleur shr 16) and $FF);
end;

function RGBToColorRef(Kleur: LongWord): COLORREF; inline;
begin
  Result := ((Kleur and $FF) shl 16) or (Kleur and $FF00) or ((Kleur shr 16) and $FF);
end;

{ ---------------------------------------------------------------- bitmaps }

constructor TZMBitmap.Create(ABreedte, AHoogte, ABPP: Integer);
begin
  inherited Create(OBJ_BITMAP);
  if ABreedte < 0 then ABreedte := 0;
  if AHoogte < 0 then AHoogte := 0;
  Width := ABreedte;
  Height := AHoogte;
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

procedure HalftoneEntries(var Ingangen: array of TPaletteEntry);
const
  Sys20: array[0..19] of LongWord = (
    $000000, $800000, $008000, $808000, $000080, $800080, $008080, $C0C0C0,
    $C0DCC0, $A6CAF0, $FFFBF0, $A0A0A4, $808080, $FF0000, $00FF00, $FFFF00,
    $0000FF, $FF00FF, $00FFFF, $FFFFFF);   { $RRGGBB }
var
  I, R, G, B, Volgnr: Integer;
  procedure ZetIngang(Nr: Integer; RGB: LongWord);
  begin
    Ingangen[Nr].peRed := (RGB shr 16) and $FF;
    Ingangen[Nr].peGreen := (RGB shr 8) and $FF;
    Ingangen[Nr].peBlue := RGB and $FF;
    Ingangen[Nr].peFlags := 0;
  end;
begin
  for I := 0 to 9 do ZetIngang(I, Sys20[I]);
  for I := 0 to 9 do ZetIngang(246 + I, Sys20[10 + I]);
  Volgnr := 10;
  for R := 0 to 5 do
    for G := 0 to 5 do
      for B := 0 to 5 do
      begin
        if Volgnr >= 246 then Break;
        ZetIngang(Volgnr, (LongWord(R * 51) shl 16) or (LongWord(G * 51) shl 8) or LongWord(B * 51));
        Inc(Volgnr);
      end;
  while Volgnr < 246 do
  begin
    ZetIngang(Volgnr, $808080);
    Inc(Volgnr);
  end;
end;

procedure TZMBitmap.SetDefaultColors;
var
  Ingangen: array[0..255] of TPaletteEntry;
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
        HalftoneEntries(Ingangen);
        for I := 0 to 7 do
          Colors[I] := (Ingangen[I].peRed shl 16) or (Ingangen[I].peGreen shl 8) or Ingangen[I].peBlue;
        for I := 8 to 15 do
          Colors[I] := (Ingangen[240 + I].peRed shl 16) or (Ingangen[240 + I].peGreen shl 8) or Ingangen[240 + I].peBlue;
        Colors[7] := $C0C0C0;
        Colors[8] := $808080;
      end;
    8:
      begin
        NumColors := 256;
        HalftoneEntries(Ingangen);
        for I := 0 to 255 do
          Colors[I] := (Ingangen[I].peRed shl 16) or (Ingangen[I].peGreen shl 8) or Ingangen[I].peBlue;
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
  Rij: PByte;
begin
  Rij := Bits + PtrInt(Y) * Stride;
  case BPP of
    1: Result := (Rij[X shr 3] shr (7 - (X and 7))) and 1;
    4: if X and 1 = 0 then Result := Rij[X shr 1] shr 4 else Result := Rij[X shr 1] and $F;
    8: Result := Rij[X];
    16: Result := PWord(Rij + X * 2)^ and $7FFF;
    24: begin Inc(Rij, X * 3); Result := Rij[0] or (LongWord(Rij[1]) shl 8) or (LongWord(Rij[2]) shl 16); end;
    32: Result := PLongWord(Rij + X * 4)^ and $FFFFFF;
  else
    Result := 0;
  end;
end;

procedure TZMBitmap.SetNative(X, Y: Integer; Waarde: LongWord);
var
  Rij: PByte;
  Masker: Byte;
begin
  Rij := Bits + PtrInt(Y) * Stride;
  case BPP of
    1:
      begin
        Masker := $80 shr (X and 7);
        if Waarde and 1 <> 0 then Rij[X shr 3] := Rij[X shr 3] or Masker
        else Rij[X shr 3] := Rij[X shr 3] and not Masker;
      end;
    4:
      if X and 1 = 0 then Rij[X shr 1] := (Rij[X shr 1] and $0F) or ((Waarde and $F) shl 4)
      else Rij[X shr 1] := (Rij[X shr 1] and $F0) or (Waarde and $F);
    8: Rij[X] := Waarde;
    16: PWord(Rij + X * 2)^ := Waarde and $7FFF;
    24: begin Inc(Rij, X * 3); Rij[0] := Waarde; Rij[1] := Waarde shr 8; Rij[2] := Waarde shr 16; end;
    32: PLongWord(Rij + X * 4)^ := Waarde and $FFFFFF;
  end;
end;

function TZMBitmap.NativeToRGB(Waarde: LongWord): LongWord;
begin
  case BPP of
    1, 4, 8:
      if Integer(Waarde) < NumColors then Result := Colors[Waarde] else Result := 0;
    16:
      Result := (((Waarde shr 10) and $1F) * 255 div 31) shl 16 or
        (((Waarde shr 5) and $1F) * 255 div 31) shl 8 or ((Waarde and $1F) * 255 div 31);
  else
    Result := Waarde and $FFFFFF;
  end;
end;

function TZMBitmap.Nearest(RGB: LongWord): Integer;
var
  Sleutel, I, Afstand, BesteAfstand, R, G, B, VerschilR, VerschilG, VerschilB: Integer;
begin
  if NumColors <= 0 then Exit(0);
  Sleutel := ((RGB shr 9) and $7C00) or ((RGB shr 6) and $3E0) or ((RGB shr 3) and $1F);
  if (Length(FNearCache) = 0) or (FNearStamp <> ColorStamp) then
  begin
    SetLength(FNearCache, 32768);
    FillChar(FNearCache[0], 32768 * SizeOf(SmallInt), 0);
    FNearStamp := ColorStamp;
  end;
  { exacte kleuren worden direct opgezocht (de cache geldt alleen per 5-bit cel) }
  for I := 0 to NumColors - 1 do
    if Colors[I] = RGB then Exit(I);
  if FNearCache[Sleutel] > 0 then Exit(FNearCache[Sleutel] - 1);
  R := (RGB shr 16) and $FF; G := (RGB shr 8) and $FF; B := RGB and $FF;
  BesteAfstand := MaxInt;
  Result := 0;
  for I := 0 to NumColors - 1 do
  begin
    VerschilR := R - Integer((Colors[I] shr 16) and $FF);
    VerschilG := G - Integer((Colors[I] shr 8) and $FF);
    VerschilB := B - Integer(Colors[I] and $FF);
    Afstand := VerschilR * VerschilR * 3 + VerschilG * VerschilG * 4 + VerschilB * VerschilB * 2;
    if Afstand < BesteAfstand then
    begin
      BesteAfstand := Afstand;
      Result := I;
    end;
  end;
  FNearCache[Sleutel] := Result + 1;
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

function NewBitmapFromInfo(const Info: TBitmapInfo; Gebruik: UINT; Palet: TZMPalette): TZMBitmap;
var
  Breedte, Hoogte, BitTeller, I, Aantal: Integer;
  Kwad: PRGBQuad;
  Index: PWord;
begin
  Breedte := Info.bmiHeader.biWidth;
  Hoogte := Abs(Info.bmiHeader.biHeight);
  BitTeller := Info.bmiHeader.biBitCount;
  if not (BitTeller in [1, 4, 8, 16, 24, 32]) then BitTeller := 24;
  Result := TZMBitmap.Create(Breedte, Hoogte, BitTeller);
  Result.IsDIB := True;
  if BitTeller <= 8 then
  begin
    Aantal := Info.bmiHeader.biClrUsed;
    if (Aantal = 0) or (Aantal > 1 shl BitTeller) then Aantal := 1 shl BitTeller;
    Result.NumColors := 1 shl BitTeller;
    if Gebruik = DIB_PAL_COLORS then
    begin
      Index := @Info.bmiColors[0];
      for I := 0 to Aantal - 1 do
      begin
        if (Palet <> nil) and (Index[I] < Palet.Count) then
          with Palet.Entries[Index[I]] do
            Result.Colors[I] := (peRed shl 16) or (peGreen shl 8) or peBlue
        else
          Result.Colors[I] := 0;
      end;
    end
    else
    begin
      Kwad := @Info.bmiColors[0];
      for I := 0 to Aantal - 1 do
        Result.Colors[I] := (Kwad[I].rgbRed shl 16) or (Kwad[I].rgbGreen shl 8) or Kwad[I].rgbBlue;
    end;
    for I := Aantal to Result.NumColors - 1 do Result.Colors[I] := 0;
    Result.ColorsChanged;
  end;
end;

{ ---------------------------------------------------------------- rechthoeklijsten }

function RectsCopy(const Rechthoeken: TZMRects): TZMRects;
begin
  Result := Copy(Rechthoeken, 0, Length(Rechthoeken));
end;

procedure AddRect(var Rechthoeken: TZMRects; const R: TRect); inline;
begin
  if (R.Right > R.Left) and (R.Bottom > R.Top) then
  begin
    SetLength(Rechthoeken, Length(Rechthoeken) + 1);
    Rechthoeken[High(Rechthoeken)] := R;
  end;
end;

function RectsIntersectRect(const Rechthoeken: TZMRects; const R: TRect): TZMRects;
var
  I: Integer;
  Tussen: TRect;
begin
  Result := nil;
  for I := 0 to High(Rechthoeken) do
  begin
    Tussen.Left := Rechthoeken[I].Left; if R.Left > Tussen.Left then Tussen.Left := R.Left;
    Tussen.Top := Rechthoeken[I].Top; if R.Top > Tussen.Top then Tussen.Top := R.Top;
    Tussen.Right := Rechthoeken[I].Right; if R.Right < Tussen.Right then Tussen.Right := R.Right;
    Tussen.Bottom := Rechthoeken[I].Bottom; if R.Bottom < Tussen.Bottom then Tussen.Bottom := R.Bottom;
    AddRect(Result, Tussen);
  end;
end;

function RectsIntersect(const Rechthoeken, Andere: TZMRects): TZMRects;
var
  I, J: Integer;
  Tussen: TZMRects;
begin
  Result := nil;
  for J := 0 to High(Andere) do
  begin
    Tussen := RectsIntersectRect(Rechthoeken, Andere[J]);
    for I := 0 to High(Tussen) do AddRect(Result, Tussen[I]);
  end;
end;

function RectsSubtractRect(const Rechthoeken: TZMRects; const R: TRect): TZMRects;
var
  I: Integer;
  Deel: TRect;
begin
  Result := nil;
  for I := 0 to High(Rechthoeken) do
  begin
    Deel := Rechthoeken[I];
    if (R.Right <= Deel.Left) or (R.Left >= Deel.Right) or (R.Bottom <= Deel.Top) or (R.Top >= Deel.Bottom) then
    begin
      AddRect(Result, Deel);
      Continue;
    end;
    { bovenste strook }
    if R.Top > Deel.Top then AddRect(Result, Rect(Deel.Left, Deel.Top, Deel.Right, R.Top));
    { onderste strook }
    if R.Bottom < Deel.Bottom then AddRect(Result, Rect(Deel.Left, R.Bottom, Deel.Right, Deel.Bottom));
    { midden: linker- en rechterdeel }
    if R.Left > Deel.Left then
      AddRect(Result, Rect(Deel.Left, Max(Deel.Top, R.Top), R.Left, Min(Deel.Bottom, R.Bottom)));
    if R.Right < Deel.Right then
      AddRect(Result, Rect(R.Right, Max(Deel.Top, R.Top), Deel.Right, Min(Deel.Bottom, R.Bottom)));
  end;
end;

function RectsSubtract(const Rechthoeken, Andere: TZMRects): TZMRects;
var
  J: Integer;
begin
  Result := RectsCopy(Rechthoeken);
  for J := 0 to High(Andere) do
    Result := RectsSubtractRect(Result, Andere[J]);
end;

function RectsUnion(const Rechthoeken, Andere: TZMRects): TZMRects;
var
  I: Integer;
  Tussen: TZMRects;
begin
  Result := RectsCopy(Rechthoeken);
  Tussen := RectsSubtract(Andere, Rechthoeken);
  for I := 0 to High(Tussen) do AddRect(Result, Tussen[I]);
end;

function RectsOffset(const Rechthoeken: TZMRects; VerschuifX, VerschuifY: Integer): TZMRects;
var
  I: Integer;
begin
  SetLength(Result, Length(Rechthoeken));
  for I := 0 to High(Rechthoeken) do
  begin
    Result[I].Left := Rechthoeken[I].Left + VerschuifX;
    Result[I].Right := Rechthoeken[I].Right + VerschuifX;
    Result[I].Top := Rechthoeken[I].Top + VerschuifY;
    Result[I].Bottom := Rechthoeken[I].Bottom + VerschuifY;
  end;
end;

function RectsBox(const Rechthoeken: TZMRects): TRect;
var
  I: Integer;
begin
  if Length(Rechthoeken) = 0 then Exit(Rect(0, 0, 0, 0));
  Result := Rechthoeken[0];
  for I := 1 to High(Rechthoeken) do
  begin
    if Rechthoeken[I].Left < Result.Left then Result.Left := Rechthoeken[I].Left;
    if Rechthoeken[I].Top < Result.Top then Result.Top := Rechthoeken[I].Top;
    if Rechthoeken[I].Right > Result.Right then Result.Right := Rechthoeken[I].Right;
    if Rechthoeken[I].Bottom > Result.Bottom then Result.Bottom := Rechthoeken[I].Bottom;
  end;
end;

function RectsContain(const Rechthoeken: TZMRects; X, Y: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(Rechthoeken) do
    if (X >= Rechthoeken[I].Left) and (X < Rechthoeken[I].Right) and (Y >= Rechthoeken[I].Top) and (Y < Rechthoeken[I].Bottom) then
      Exit(True);
  Result := False;
end;

{ ---------------------------------------------------------------- DC }

constructor TZMDC.Create(ADoel: TZMBitmap);
begin
  inherited Create(OBJ_DC);
  Target := ADoel;
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

procedure TZMDC.SelectBitmap(Bitmap: TZMBitmap);
begin
  if (Target <> nil) and (Target.SelectedIn = Self) then Target.SelectedIn := nil;
  Target := Bitmap;
  if Bitmap <> nil then Bitmap.SelectedIn := Self;
  InvalidateClip;
end;

procedure TZMDC.InvalidateClip;
begin
  FEffValid := False;
end;

function TZMDC.Eff: TZMRects;
var
  Volledig: TZMRects;
begin
  if (Wnd <> 0) and (VisGen <> ZMVisGeneration) and Assigned(ZMVisProvider) then
  begin
    ZMVisProvider(Self);
    VisGen := ZMVisGeneration;
    FEffValid := False;
  end;
  if not FEffValid then
  begin
    SetLength(Volledig, 1);
    if Target <> nil then
      Volledig[0] := Rect(0, 0, Target.Width, Target.Height)
    else
      Volledig[0] := Rect(0, 0, 0, 0);
    if HasVis then Volledig := RectsIntersect(Volledig, VisRgn);
    if HasPaintRgn then Volledig := RectsIntersect(Volledig, PaintRgn);
    if St.HasClip then
      Volledig := RectsIntersect(Volledig, RectsOffset(St.ClipRgn, DevOrg.X, DevOrg.Y));
    FEff := Volledig;
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

function TZMDC.ColorToRGB(Kleur: COLORREF): LongWord;
var
  I: Integer;
begin
  if (Kleur and $FF000000) = $01000000 then
  begin
    I := Kleur and $FFFF;
    if (Target <> nil) and (Target.BPP <= 8) and (I < Target.NumColors) then
      Result := Target.Colors[I]
    else if (St.Palette <> nil) and (I < St.Palette.Count) then
      with St.Palette.Entries[I] do Result := (peRed shl 16) or (peGreen shl 8) or peBlue
    else
      Result := 0;
  end
  else
    Result := ColorRefToRGB(Kleur and $FFFFFF);
end;

function TZMDC.ColorToNative(Kleur: COLORREF): LongWord;
begin
  if Target = nil then Exit(0);
  if ((Kleur and $FF000000) = $01000000) and (Target.BPP <= 8) then
    Result := (Kleur and $FFFF) and Target.NativeMask
  else
    Result := Target.RGBToNative(ColorToRGB(Kleur));
end;

{ ---------------------------------------------------------------- rasterbewerkingen }

function Rop3(Code: Byte; Patroon, Bron, Doel: LongWord): LongWord; inline;
begin
  case Code of
    $CC: Result := Bron;
    $66: Result := Bron xor Doel;
    $88: Result := Bron and Doel;
    $EE: Result := Bron or Doel;
    $F0: Result := Patroon;
    $55: Result := not Doel;
    $00: Result := 0;
    $FF: Result := $FFFFFFFF;
    $33: Result := not Bron;
    $BB: Result := (not Bron) or Doel;
    $44: Result := Bron and not Doel;
    $22: Result := (not Bron) and Doel;
    $5A: Result := Patroon xor Doel;
    $C0: Result := Patroon and Bron;
    $AA: Result := Doel;
    $11: Result := not (Bron or Doel);
    $99: Result := not (Bron xor Doel);
    $B8: Result := (Patroon and not Bron) or (Bron and Doel);    { PSDPxax }
    $E2: Result := (Doel and not Bron) or (Bron and Patroon);    { DSPDxax }
  else
    Result := 0;
    if Code and $01 <> 0 then Result := Result or (not Patroon and not Bron and not Doel);
    if Code and $02 <> 0 then Result := Result or (not Patroon and not Bron and Doel);
    if Code and $04 <> 0 then Result := Result or (not Patroon and Bron and not Doel);
    if Code and $08 <> 0 then Result := Result or (not Patroon and Bron and Doel);
    if Code and $10 <> 0 then Result := Result or (Patroon and not Bron and not Doel);
    if Code and $20 <> 0 then Result := Result or (Patroon and not Bron and Doel);
    if Code and $40 <> 0 then Result := Result or (Patroon and Bron and not Doel);
    if Code and $80 <> 0 then Result := Result or (Patroon and Bron and Doel);
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

{ patroonwaarde van het kwast van de DC op een doelpixel (native) }
type
  TPatInfo = record
    Solid: Boolean;
    Value: LongWord;
    Pat: array[0..7, 0..7] of LongWord;
  end;

procedure PreparePattern(DC: TZMDC; var Patroon: TPatInfo);
const
  HatchBits: array[0..5, 0..7] of Byte = (
    ($00, $00, $00, $00, $FF, $00, $00, $00),   { horizontaal }
    ($08, $08, $08, $08, $08, $08, $08, $08),   { verticaal }
    ($80, $40, $20, $10, $08, $04, $02, $01),   { schuin (/) }
    ($01, $02, $04, $08, $10, $20, $40, $80),   { schuin (\) }
    ($08, $08, $08, $08, $FF, $08, $08, $08),   { kruis }
    ($81, $42, $24, $18, $18, $24, $42, $81));  { diagonaal kruis }
var
  Kwast: TZMBrush;
  X, Y, Arcering: Integer;
  Voorgrond, Achtergrond: LongWord;
  Bitmap: TZMBitmap;
begin
  Kwast := DC.St.Brush;
  Patroon.Solid := True;
  Patroon.Value := 0;
  if Kwast = nil then Exit;
  case Kwast.Style of
    BS_SOLID: Patroon.Value := DC.ColorToNative(Kwast.Color);
    BS_HATCHED:
      begin
        Patroon.Solid := False;
        Voorgrond := DC.ColorToNative(Kwast.Color);
        Achtergrond := DC.ColorToNative(DC.St.BkColor);
        Arcering := Kwast.Hatch;
        if (Arcering < 0) or (Arcering > 5) then Arcering := 0;
        for Y := 0 to 7 do
          for X := 0 to 7 do
            if HatchBits[Arcering, Y] and ($80 shr X) <> 0 then Patroon.Pat[Y, X] := Voorgrond else Patroon.Pat[Y, X] := Achtergrond;
      end;
    BS_PATTERN, BS_DIBPATTERN:
      begin
        Bitmap := Kwast.Pattern;
        if (Bitmap = nil) or (Bitmap.Width = 0) or (Bitmap.Height = 0) then Exit;
        Patroon.Solid := False;
        for Y := 0 to 7 do
          for X := 0 to 7 do
          begin
            if Bitmap.BPP = 1 then
            begin
              if Bitmap.GetNative(X mod Bitmap.Width, Y mod Bitmap.Height) = 0 then
                Patroon.Pat[Y, X] := DC.ColorToNative(DC.St.TextColor)
              else
                Patroon.Pat[Y, X] := DC.ColorToNative(DC.St.BkColor);
            end
            else
              Patroon.Pat[Y, X] := DC.Target.RGBToNative(Bitmap.NativeToRGB(Bitmap.GetNative(X mod Bitmap.Width, Y mod Bitmap.Height)));
          end;
      end;
  else
    Patroon.Value := DC.ColorToNative(Kwast.Color);
  end;
end;

function PatAt(const Patroon: TPatInfo; DC: TZMDC; X, Y: Integer): LongWord; inline;
begin
  if Patroon.Solid then Result := Patroon.Value
  else Result := Patroon.Pat[(Y - DC.St.BrushOrg.Y) and 7, (X - DC.St.BrushOrg.X) and 7];
end;

{ ---------------------------------------------------------------- blits }

procedure ZMReadRow(Bitmap: TZMBitmap; Y, X, Aantal: Integer; Buffer: PLongWord);
var
  Rij: PByte;
  I: Integer;
begin
  Rij := Bitmap.RowPtr(Y);
  case Bitmap.BPP of
    8: for I := 0 to Aantal - 1 do Buffer[I] := Rij[X + I];
    32: for I := 0 to Aantal - 1 do Buffer[I] := PLongWord(Rij + (X + I) * 4)^ and $FFFFFF;
    24:
      begin
        Inc(Rij, X * 3);
        for I := 0 to Aantal - 1 do
        begin
          Buffer[I] := Rij[0] or (LongWord(Rij[1]) shl 8) or (LongWord(Rij[2]) shl 16);
          Inc(Rij, 3);
        end;
      end;
    1: for I := 0 to Aantal - 1 do Buffer[I] := (Rij[(X + I) shr 3] shr (7 - ((X + I) and 7))) and 1;
  else
    for I := 0 to Aantal - 1 do Buffer[I] := Bitmap.GetNative(X + I, Y);
  end;
end;

procedure ZMWriteRow(Bitmap: TZMBitmap; Y, X, Aantal: Integer; Buffer: PLongWord);
var
  Rij: PByte;
  I, Xpos: Integer;
  Masker: Byte;
begin
  if Aantal <= 0 then Exit;
  Rij := Bitmap.RowPtr(Y);
  case Bitmap.BPP of
    8: for I := 0 to Aantal - 1 do Rij[X + I] := Buffer[I];
    32: for I := 0 to Aantal - 1 do PLongWord(Rij + (X + I) * 4)^ := Buffer[I] and $FFFFFF;
    24:
      begin
        Inc(Rij, X * 3);
        for I := 0 to Aantal - 1 do
        begin
          Rij[0] := Buffer[I]; Rij[1] := Buffer[I] shr 8; Rij[2] := Buffer[I] shr 16;
          Inc(Rij, 3);
        end;
      end;
    1:
      for I := 0 to Aantal - 1 do
      begin
        Xpos := X + I;
        Masker := $80 shr (Xpos and 7);
        if Buffer[I] and 1 <> 0 then Rij[Xpos shr 3] := Rij[Xpos shr 3] or Masker
        else Rij[Xpos shr 3] := Rij[Xpos shr 3] and not Masker;
      end;
  else
    for I := 0 to Aantal - 1 do Bitmap.SetNative(X + I, Y, Buffer[I]);
  end;
end;

type
  TConvKind = (ckIdentity, ckLUT, ckToMono, ckRGBToIndex, ckRGBToRGB, ckGeneric);

procedure GdiBltBitmap(DoelDC: TZMDC; X, Y, Breedte, Hoogte: Integer; BronBitmap: TZMBitmap; BronAchtergrond: COLORREF;
  BronPosX, BronPosY, BronBreedte, BronHoogte: Integer; Rop: DWORD; Uitrekken: Boolean);
var
  Code: Byte;
  GebruikBron, GebruikDoel, GebruikPatroon: Boolean;
  Doel: TZMBitmap;
  Knip: TZMRects;
  DoelR, KnipR: TRect;
  I, DoelXX, DoelYY, BronXX, BronYY, SpiegelX, SpiegelY: Integer;
  Omzetting: TConvKind;
  Tabel: array[0..255] of LongWord;
  BronAchtergrondNatief: LongWord;
  Masker: LongWord;
  Patroon: TPatInfo;
  BronW, Doelwaarde, Patwaarde, Waarde: LongWord;
  OfsX, OfsY, DoelBreedte, DoelHoogte: Integer;
  BronRij, DoelRij: PByte;
  Telling: Integer;
  BronBuf, DoelBuf: array of LongWord;
  Geldig: array of Boolean;
  Aantal, XVan, XTot, K: Integer;
begin
  Doel := DoelDC.Target;
  if (Doel = nil) or (Doel.Bits = nil) then Exit;
  Code := (Rop shr 16) and $FF;
  GebruikBron := RopUsesSrc(Code) and (BronBitmap <> nil) and (BronBitmap.Bits <> nil);
  GebruikDoel := RopUsesDst(Code);
  GebruikPatroon := RopUsesPat(Code);
  if RopUsesSrc(Code) and not GebruikBron then Exit;
  if not Uitrekken then
  begin
    BronBreedte := Breedte;
    BronHoogte := Hoogte;
  end;
  { negatieve afmetingen spiegelen }
  SpiegelX := 0; SpiegelY := 0;
  if Breedte < 0 then begin X := X + Breedte; Breedte := -Breedte; SpiegelX := SpiegelX xor 1; end;
  if Hoogte < 0 then begin Y := Y + Hoogte; Hoogte := -Hoogte; SpiegelY := SpiegelY xor 1; end;
  if BronBreedte < 0 then begin BronPosX := BronPosX + BronBreedte; BronBreedte := -BronBreedte; SpiegelX := SpiegelX xor 1; end;
  if BronHoogte < 0 then begin BronPosY := BronPosY + BronHoogte; BronHoogte := -BronHoogte; SpiegelY := SpiegelY xor 1; end;
  if (Breedte = 0) or (Hoogte = 0) then Exit;
  if GebruikBron and ((BronBreedte = 0) or (BronHoogte = 0)) then Exit;
  OfsX := DoelDC.OffX;
  OfsY := DoelDC.OffY;
  DoelR := Rect(X + OfsX, Y + OfsY, X + OfsX + Breedte, Y + OfsY + Hoogte);
  Knip := RectsIntersectRect(DoelDC.Eff, DoelR);
  if Length(Knip) = 0 then Exit;
  Masker := Doel.NativeMask;
  if GebruikPatroon then PreparePattern(DoelDC, Patroon);

  { kleurconversie van bron naar doel }
  Omzetting := ckGeneric;
  BronAchtergrondNatief := 0;
  if GebruikBron then
  begin
    if BronBitmap.BPP = 1 then
    begin
      Omzetting := ckLUT;
      Tabel[0] := DoelDC.ColorToNative(DoelDC.St.TextColor);
      Tabel[1] := DoelDC.ColorToNative(DoelDC.St.BkColor);
      if Doel.BPP = 1 then
      begin
        { mono -> mono: rechtstreekse kopie }
        Omzetting := ckIdentity;
      end;
    end
    else if Doel.BPP = 1 then
    begin
      Omzetting := ckToMono;
      if ((BronAchtergrond and $FF000000) = $01000000) and (BronBitmap.BPP <= 8) then
        BronAchtergrondNatief := BronAchtergrond and $FFFF
      else
        BronAchtergrondNatief := BronBitmap.RGBToNative(ColorRefToRGB(BronAchtergrond and $FFFFFF));
    end
    else if BronBitmap.BPP <= 8 then
    begin
      if (Doel.BPP = BronBitmap.BPP) and (Doel.NumColors = BronBitmap.NumColors) and
        CompareMem(@Doel.Colors[0], @BronBitmap.Colors[0], BronBitmap.NumColors * 4) then
        Omzetting := ckIdentity
      else
      begin
        Omzetting := ckLUT;
        for I := 0 to (1 shl BronBitmap.BPP) - 1 do
          Tabel[I] := Doel.RGBToNative(BronBitmap.NativeToRGB(I));
      end;
    end
    else if Doel.BPP <= 8 then
      Omzetting := ckRGBToIndex
    else if ((BronBitmap.BPP = 24) or (BronBitmap.BPP = 32)) and ((Doel.BPP = 24) or (Doel.BPP = 32)) then
      Omzetting := ckRGBToRGB
    else
      Omzetting := ckGeneric;
  end;

  for I := 0 to High(Knip) do
  begin
    KnipR := Knip[I];
    { snelle paden: niet-uitgerekte SRCCOPY }
    if GebruikBron and (Code = $CC) and (BronBreedte = Breedte) and (BronHoogte = Hoogte) and (SpiegelX = 0) and (SpiegelY = 0) then
    begin
      for DoelYY := KnipR.Top to KnipR.Bottom - 1 do
      begin
        BronYY := BronPosY + (DoelYY - DoelR.Top);
        if (BronYY < 0) or (BronYY >= BronBitmap.Height) then Continue;
        BronXX := BronPosX + (KnipR.Left - DoelR.Left);
        DoelXX := KnipR.Left;
        Telling := KnipR.Right - KnipR.Left;
        { knip bronkolommen bij }
        if BronXX < 0 then begin Inc(DoelXX, -BronXX); Dec(Telling, -BronXX); BronXX := 0; end;
        if BronXX + Telling > BronBitmap.Width then Telling := BronBitmap.Width - BronXX;
        if Telling <= 0 then Continue;
        BronRij := BronBitmap.RowPtr(BronYY);
        DoelRij := Doel.RowPtr(DoelYY);
        if (Omzetting = ckIdentity) and (BronBitmap.BPP = Doel.BPP) and (Doel.BPP >= 8) then
          Move(BronRij[BronXX * (Doel.BPP div 8)], DoelRij[DoelXX * (Doel.BPP div 8)], Telling * (Doel.BPP div 8))
        else if (Omzetting = ckLUT) and (BronBitmap.BPP = 8) and (Doel.BPP = 32) then
        begin
          while Telling > 0 do
          begin
            PLongWord(DoelRij + DoelXX * 4)^ := Tabel[BronRij[BronXX]];
            Inc(DoelXX); Inc(BronXX); Dec(Telling);
          end;
        end
        else if (Omzetting = ckRGBToRGB) and (BronBitmap.BPP = 24) and (Doel.BPP = 32) then
        begin
          while Telling > 0 do
          begin
            PLongWord(DoelRij + DoelXX * 4)^ := BronRij[BronXX * 3] or (LongWord(BronRij[BronXX * 3 + 1]) shl 8) or
              (LongWord(BronRij[BronXX * 3 + 2]) shl 16);
            Inc(DoelXX); Inc(BronXX); Dec(Telling);
          end;
        end
        else
        begin
          while Telling > 0 do
          begin
            BronW := BronBitmap.GetNative(BronXX, BronYY);
            case Omzetting of
              ckLUT: Waarde := Tabel[BronW];
              ckToMono: if BronW = BronAchtergrondNatief then Waarde := 1 else Waarde := 0;
              ckRGBToIndex: Waarde := Doel.Nearest(BronBitmap.NativeToRGB(BronW));
              ckRGBToRGB: Waarde := BronW;
              ckIdentity: Waarde := BronW;
            else
              Waarde := Doel.RGBToNative(BronBitmap.NativeToRGB(BronW));
            end;
            Doel.SetNative(DoelXX, DoelYY, Waarde);
            Inc(DoelXX); Inc(BronXX); Dec(Telling);
          end;
        end;
      end;
      Continue;
    end;

    { algemeen pad: rijbuffers }
    DoelBreedte := Breedte; DoelHoogte := Hoogte;
    Aantal := KnipR.Right - KnipR.Left;
    if Length(BronBuf) < Aantal then
    begin
      SetLength(BronBuf, Aantal);
      SetLength(DoelBuf, Aantal);
      SetLength(Geldig, Aantal);
    end;
    for DoelYY := KnipR.Top to KnipR.Bottom - 1 do
    begin
      XVan := 0;
      XTot := Aantal;
      if GebruikBron then
      begin
        if SpiegelY = 0 then
          BronYY := BronPosY + Int64(DoelYY - DoelR.Top) * BronHoogte div DoelHoogte
        else
          BronYY := BronPosY + BronHoogte - 1 - Int64(DoelYY - DoelR.Top) * BronHoogte div DoelHoogte;
        if (BronYY < 0) or (BronYY >= BronBitmap.Height) then Continue;
        if (BronBreedte = DoelBreedte) and (SpiegelX = 0) then
        begin
          { niet uitgerekt: een doorlopend bronbereik }
          BronXX := BronPosX + (KnipR.Left - DoelR.Left);
          if BronXX < 0 then XVan := -BronXX;
          if BronXX + Aantal > BronBitmap.Width then XTot := BronBitmap.Width - BronXX;
          if XTot <= XVan then Continue;
          ZMReadRow(BronBitmap, BronYY, BronXX + XVan, XTot - XVan, @BronBuf[XVan]);
          for K := XVan to XTot - 1 do Geldig[K] := True;
        end
        else
          for K := 0 to Aantal - 1 do
          begin
            if SpiegelX = 0 then
              BronXX := BronPosX + Int64(KnipR.Left + K - DoelR.Left) * BronBreedte div DoelBreedte
            else
              BronXX := BronPosX + BronBreedte - 1 - Int64(KnipR.Left + K - DoelR.Left) * BronBreedte div DoelBreedte;
            Geldig[K] := (BronXX >= 0) and (BronXX < BronBitmap.Width);
            if Geldig[K] then BronBuf[K] := BronBitmap.GetNative(BronXX, BronYY) else BronBuf[K] := 0;
          end;
        { kleurconversie }
        case Omzetting of
          ckLUT: for K := XVan to XTot - 1 do BronBuf[K] := Tabel[BronBuf[K] and $FF];
          ckToMono: for K := XVan to XTot - 1 do
              if BronBuf[K] = BronAchtergrondNatief then BronBuf[K] := 1 else BronBuf[K] := 0;
          ckRGBToIndex: for K := XVan to XTot - 1 do BronBuf[K] := Doel.Nearest(BronBitmap.NativeToRGB(BronBuf[K]));
          ckRGBToRGB, ckIdentity: ;
        else
          for K := XVan to XTot - 1 do BronBuf[K] := Doel.RGBToNative(BronBitmap.NativeToRGB(BronBuf[K]));
        end;
      end
      else
        for K := 0 to Aantal - 1 do Geldig[K] := True;
      if GebruikDoel or not ((BronBreedte = DoelBreedte) and (SpiegelX = 0)) or not GebruikBron then
        ZMReadRow(Doel, DoelYY, KnipR.Left, Aantal, @DoelBuf[0]);
      case Code of
        $CC: for K := XVan to XTot - 1 do if Geldig[K] then DoelBuf[K] := BronBuf[K];
        $88: for K := XVan to XTot - 1 do if Geldig[K] then DoelBuf[K] := DoelBuf[K] and BronBuf[K];
        $EE: for K := XVan to XTot - 1 do if Geldig[K] then DoelBuf[K] := DoelBuf[K] or BronBuf[K];
        $66: for K := XVan to XTot - 1 do if Geldig[K] then DoelBuf[K] := (DoelBuf[K] xor BronBuf[K]) and Masker;
        $55: for K := XVan to XTot - 1 do DoelBuf[K] := (not DoelBuf[K]) and Masker;
        $00: for K := XVan to XTot - 1 do DoelBuf[K] := 0;
        $FF: for K := XVan to XTot - 1 do DoelBuf[K] := Masker;
      else
        for K := XVan to XTot - 1 do
          if Geldig[K] then
          begin
            if GebruikPatroon then Patwaarde := PatAt(Patroon, DoelDC, KnipR.Left + K, DoelYY) else Patwaarde := 0;
            DoelBuf[K] := Rop3(Code, Patwaarde, BronBuf[K], DoelBuf[K]) and Masker;
          end;
      end;
      ZMWriteRow(Doel, DoelYY, KnipR.Left + XVan, XTot - XVan, @DoelBuf[XVan]);
    end;
  end;
  Doel.Dirty := True;
end;

procedure GdiBlt(DoelDC: TZMDC; X, Y, Breedte, Hoogte: Integer; BronDC: TZMDC; BronPosX, BronPosY, BronBreedte, BronHoogte: Integer;
  Rop: DWORD; Uitrekken: Boolean);
var
  BronBitmap: TZMBitmap;
  BronOfsX, BronOfsY: Integer;
begin
  if DoelDC = nil then Exit;
  if BronDC <> nil then
  begin
    BronBitmap := BronDC.Target;
    BronOfsX := BronDC.OffX;
    BronOfsY := BronDC.OffY;
    GdiBltBitmap(DoelDC, X, Y, Breedte, Hoogte, BronBitmap, BronDC.St.BkColor, BronPosX + BronOfsX, BronPosY + BronOfsY, BronBreedte, BronHoogte, Rop, Uitrekken);
  end
  else
    GdiBltBitmap(DoelDC, X, Y, Breedte, Hoogte, nil, 0, 0, 0, 0, 0, Rop, Uitrekken);
end;

procedure GdiPatBlt(DC: TZMDC; X, Y, Breedte, Hoogte: Integer; Rop: DWORD);
begin
  GdiBltBitmap(DC, X, Y, Breedte, Hoogte, nil, 0, 0, 0, 0, 0, Rop and $00FF0000, False);
end;

{ vul een rechthoek (target-coördinaten) met een effen native waarde, geknipt }
procedure FillNative(DC: TZMDC; R: TRect; Waarde: LongWord);
var
  Knip: TZMRects;
  I, X, Y: Integer;
  Doel: TZMBitmap;
  Rij: PLongWord;
  KnipR: TRect;
begin
  Doel := DC.Target;
  if (Doel = nil) or (Doel.Bits = nil) then Exit;
  Knip := RectsIntersectRect(DC.Eff, R);
  for I := 0 to High(Knip) do
  begin
    KnipR := Knip[I];
    for Y := KnipR.Top to KnipR.Bottom - 1 do
      case Doel.BPP of
        32:
          begin
            Rij := PLongWord(Doel.RowPtr(Y)) + KnipR.Left;
            for X := KnipR.Left to KnipR.Right - 1 do
            begin
              Rij^ := Waarde;
              Inc(Rij);
            end;
          end;
        8: FillChar(Doel.RowPtr(Y)[KnipR.Left], KnipR.Right - KnipR.Left, Byte(Waarde));
      else
        for X := KnipR.Left to KnipR.Right - 1 do Doel.SetNative(X, Y, Waarde);
      end;
  end;
  Doel.Dirty := True;
end;

procedure GdiFillRect(DC: TZMDC; const R: TRect; Kwast: TZMBrush);
var
  Oud: TZMBrush;
begin
  if (Kwast = nil) or (Kwast.Style = BS_NULL) then Exit;
  Oud := DC.St.Brush;
  DC.St.Brush := Kwast;
  try
    GdiPatBlt(DC, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top, PATCOPY);
  finally
    DC.St.Brush := Oud;
  end;
end;

procedure GdiFillSolid(DC: TZMDC; const R: TRect; Kleur: COLORREF);
var
  OfsX, OfsY: Integer;
begin
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  OfsX := DC.OffX; OfsY := DC.OffY;
  FillNative(DC, Rect(R.Left + OfsX, R.Top + OfsY, R.Right + OfsX, R.Bottom + OfsY), DC.ColorToNative(Kleur));
end;

procedure GdiInvertRect(DC: TZMDC; const R: TRect);
begin
  GdiPatBlt(DC, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top, DSTINVERT);
end;

{ ---------------------------------------------------------------- pixels en lijnen }

procedure PlotNative(DC: TZMDC; X, Y: Integer; Waarde: LongWord; Modus: Integer); inline;
var
  Doel: TZMBitmap;
  Doelwaarde: LongWord;
begin
  Doel := DC.Target;
  if (X < 0) or (Y < 0) or (X >= Doel.Width) or (Y >= Doel.Height) then Exit;
  if not RectsContain(DC.Eff, X, Y) then Exit;
  if Modus = R2_COPYPEN then
    Doel.SetNative(X, Y, Waarde)
  else
  begin
    Doelwaarde := Doel.GetNative(X, Y);
    case Modus of
      R2_BLACK: Doelwaarde := 0;
      R2_WHITE: Doelwaarde := Doel.RGBToNative($FFFFFF);
      R2_NOT: Doelwaarde := not Doelwaarde;
      R2_XORPEN: Doelwaarde := Doelwaarde xor Waarde;
      R2_NOTXORPEN: Doelwaarde := not (Doelwaarde xor Waarde);
      R2_MASKPEN: Doelwaarde := Doelwaarde and Waarde;
      R2_MERGEPEN: Doelwaarde := Doelwaarde or Waarde;
      R2_NOTCOPYPEN: Doelwaarde := not Waarde;
      R2_NOP: Exit;
    else
      Doelwaarde := Waarde;
    end;
    Doel.SetNative(X, Y, Doelwaarde and Doel.NativeMask);
  end;
  Doel.Dirty := True;
end;

procedure GdiSetPixel(DC: TZMDC; X, Y: Integer; Kleur: COLORREF);
begin
  if DC.Target = nil then Exit;
  PlotNative(DC, X + DC.OffX, Y + DC.OffY, DC.ColorToNative(Kleur), R2_COPYPEN);
end;

function GdiGetPixel(DC: TZMDC; X, Y: Integer): COLORREF;
var
  Doel: TZMBitmap;
begin
  Doel := DC.Target;
  Result := CLR_INVALID;
  if Doel = nil then Exit;
  Inc(X, DC.OffX); Inc(Y, DC.OffY);
  if (X < 0) or (Y < 0) or (X >= Doel.Width) or (Y >= Doel.Height) then Exit;
  Result := RGBToColorRef(Doel.NativeToRGB(Doel.GetNative(X, Y)));
end;

procedure PenPlot(DC: TZMDC; X, Y: Integer; Waarde: LongWord; PenBreedte: Integer);
var
  I, J, Helft: Integer;
begin
  if PenBreedte <= 1 then
    PlotNative(DC, X, Y, Waarde, DC.St.ROP2)
  else
  begin
    Helft := PenBreedte div 2;
    for J := Y - Helft to Y - Helft + PenBreedte - 1 do
      for I := X - Helft to X - Helft + PenBreedte - 1 do
        PlotNative(DC, I, J, Waarde, DC.St.ROP2);
  end;
end;

procedure LineNative(DC: TZMDC; X1, Y1, X2, Y2: Integer; Waarde: LongWord; PenBreedte: Integer;
  Stijl: UINT; LaatstePixel: Boolean);
var
  AfstX, AfstY, StapX, StapY, Fout, Dubbelfout, Teller: Integer;
  Tekenen: Boolean;
begin
  AfstX := Abs(X2 - X1); AfstY := -Abs(Y2 - Y1);
  if X1 < X2 then StapX := 1 else StapX := -1;
  if Y1 < Y2 then StapY := 1 else StapY := -1;
  Fout := AfstX + AfstY;
  Teller := 0;
  while True do
  begin
    if (X1 = X2) and (Y1 = Y2) then
    begin
      if LaatstePixel then PenPlot(DC, X1, Y1, Waarde, PenBreedte);
      Break;
    end;
    case Stijl of
      PS_DOT: Tekenen := (Teller mod 2) = 0;
      PS_DASH: Tekenen := (Teller mod 9) < 6;
      PS_DASHDOT: Tekenen := ((Teller mod 12) < 6) or ((Teller mod 12) in [8, 9]);
    else
      Tekenen := True;
    end;
    if Tekenen then PenPlot(DC, X1, Y1, Waarde, PenBreedte);
    Inc(Teller);
    Dubbelfout := 2 * Fout;
    if Dubbelfout >= AfstY then begin Inc(Fout, AfstY); Inc(X1, StapX); end;
    if Dubbelfout <= AfstX then begin Inc(Fout, AfstX); Inc(Y1, StapY); end;
  end;
end;

procedure GdiLine(DC: TZMDC; X1, Y1, X2, Y2: Integer; LaatstePixel: Boolean);
var
  Pen: TZMPen;
begin
  Pen := DC.St.Pen;
  if (Pen = nil) or (Pen.Style = PS_NULL) or (DC.Target = nil) then Exit;
  LineNative(DC, X1 + DC.OffX, Y1 + DC.OffY, X2 + DC.OffX, Y2 + DC.OffY,
    DC.ColorToNative(Pen.Color), Pen.Width, Pen.Style, LaatstePixel);
end;

procedure GdiRectangle(DC: TZMDC; X1, Y1, X2, Y2: Integer);
var
  Pen: TZMPen;
  Tussen: Integer;
begin
  if X2 < X1 then begin Tussen := X1; X1 := X2; X2 := Tussen; end;
  if Y2 < Y1 then begin Tussen := Y1; Y1 := Y2; Y2 := Tussen; end;
  Pen := DC.St.Pen;
  if (DC.St.Brush <> nil) and (DC.St.Brush.Style <> BS_NULL) then
  begin
    if (Pen <> nil) and (Pen.Style <> PS_NULL) then
      GdiPatBlt(DC, X1 + 1, Y1 + 1, X2 - X1 - 2, Y2 - Y1 - 2, PATCOPY)
    else
      GdiPatBlt(DC, X1, Y1, X2 - X1 - 1, Y2 - Y1 - 1, PATCOPY);
  end;
  if (Pen <> nil) and (Pen.Style <> PS_NULL) then
  begin
    GdiLine(DC, X1, Y1, X2 - 1, Y1, False);
    GdiLine(DC, X2 - 1, Y1, X2 - 1, Y2 - 1, False);
    GdiLine(DC, X2 - 1, Y2 - 1, X1, Y2 - 1, False);
    GdiLine(DC, X1, Y2 - 1, X1, Y1, False);
  end;
end;

{ scanlijn-polygonvulling (alternatieve regel), target-coördinaten }
procedure FillPolyNative(DC: TZMDC; const Punten: array of TPoint);
var
  LaagsteY, HoogsteY, Y, I, J, Aantal, Snijpunten, Tussen: Integer;
  XSnij: array of Integer;
  Patroon: TPatInfo;
  X, XVan, XTot: Integer;
  YMidden, X1, Y1, X2, Y2: Double;
begin
  Aantal := Length(Punten);
  if Aantal < 3 then Exit;
  PreparePattern(DC, Patroon);
  LaagsteY := Punten[0].Y; HoogsteY := Punten[0].Y;
  for I := 1 to Aantal - 1 do
  begin
    if Punten[I].Y < LaagsteY then LaagsteY := Punten[I].Y;
    if Punten[I].Y > HoogsteY then HoogsteY := Punten[I].Y;
  end;
  SetLength(XSnij, Aantal);
  for Y := LaagsteY to HoogsteY - 1 do
  begin
    YMidden := Y + 0.5;
    Snijpunten := 0;
    J := Aantal - 1;
    for I := 0 to Aantal - 1 do
    begin
      X1 := Punten[J].X; Y1 := Punten[J].Y; X2 := Punten[I].X; Y2 := Punten[I].Y;
      if ((Y1 <= YMidden) and (Y2 > YMidden)) or ((Y2 <= YMidden) and (Y1 > YMidden)) then
      begin
        XSnij[Snijpunten] := Round(X1 + (YMidden - Y1) * (X2 - X1) / (Y2 - Y1));
        Inc(Snijpunten);
      end;
      J := I;
    end;
    { sorteer }
    for I := 1 to Snijpunten - 1 do
    begin
      Tussen := XSnij[I]; J := I - 1;
      while (J >= 0) and (XSnij[J] > Tussen) do begin XSnij[J + 1] := XSnij[J]; Dec(J); end;
      XSnij[J + 1] := Tussen;
    end;
    I := 0;
    while I + 1 < Snijpunten do
    begin
      XVan := XSnij[I]; XTot := XSnij[I + 1];
      for X := XVan to XTot - 1 do
        PlotNative(DC, X, Y, PatAt(Patroon, DC, X, Y), R2_COPYPEN);
      Inc(I, 2);
    end;
  end;
end;

procedure GdiPolygon(DC: TZMDC; const Punten: array of TPoint; Vullen: Boolean);
var
  Omgezet: array of TPoint;
  I, Aantal: Integer;
begin
  Aantal := Length(Punten);
  if (Aantal < 2) or (DC.Target = nil) then Exit;
  SetLength(Omgezet, Aantal);
  for I := 0 to Aantal - 1 do Omgezet[I] := DC.LPtoT(Punten[I].X, Punten[I].Y);
  if Vullen and (DC.St.Brush <> nil) and (DC.St.Brush.Style <> BS_NULL) then
    FillPolyNative(DC, Omgezet);
  if (DC.St.Pen <> nil) and (DC.St.Pen.Style <> PS_NULL) then
    for I := 0 to Aantal - 1 do
      LineNative(DC, Omgezet[I].X, Omgezet[I].Y, Omgezet[(I + 1) mod Aantal].X, Omgezet[(I + 1) mod Aantal].Y,
        DC.ColorToNative(DC.St.Pen.Color), DC.St.Pen.Width, DC.St.Pen.Style, False);
end;

procedure GdiPolyline(DC: TZMDC; const Punten: array of TPoint);
var
  I: Integer;
begin
  for I := 0 to High(Punten) - 1 do
    GdiLine(DC, Punten[I].X, Punten[I].Y, Punten[I + 1].X, Punten[I + 1].Y, False);
end;

procedure EllipsePoints(X1, Y1, X2, Y2: Integer; var Punten: TZMRects);
{ geeft per rij het horizontale bereik [Left, Right) van de in de
  rechthoek ingeschreven ellips, in Pts (Top = Bottom - 1 = rij) }
var
  CX, CY, RX, RY, DYn, HalveBreedte: Double;
  Y: Integer;
begin
  Punten := nil;
  RX := (X2 - X1) / 2; RY := (Y2 - Y1) / 2;
  if (RX <= 0) or (RY <= 0) then Exit;
  CX := X1 + RX; CY := Y1 + RY;
  for Y := Y1 to Y2 - 1 do
  begin
    DYn := (Y + 0.5 - CY) / RY;
    if Abs(DYn) > 1 then Continue;
    HalveBreedte := RX * Sqrt(1 - DYn * DYn);
    SetLength(Punten, Length(Punten) + 1);
    Punten[High(Punten)] := Rect(Round(CX - HalveBreedte), Y, Round(CX + HalveBreedte), Y + 1);
  end;
end;

procedure GdiEllipse(DC: TZMDC; X1, Y1, X2, Y2: Integer);
var
  Rijen: TZMRects;
  I, X: Integer;
  Patroon: TPatInfo;
  OfsX, OfsY: Integer;
  Waarde: LongWord;
  PenBreedte: Integer;
  Vorige: TRect;
begin
  if DC.Target = nil then Exit;
  OfsX := DC.OffX; OfsY := DC.OffY;
  EllipsePoints(X1 + OfsX, Y1 + OfsY, X2 + OfsX, Y2 + OfsY, Rijen);
  if (DC.St.Brush <> nil) and (DC.St.Brush.Style <> BS_NULL) then
  begin
    PreparePattern(DC, Patroon);
    for I := 0 to High(Rijen) do
      for X := Rijen[I].Left to Rijen[I].Right - 1 do
        PlotNative(DC, X, Rijen[I].Top, PatAt(Patroon, DC, X, Rijen[I].Top), R2_COPYPEN);
  end;
  if (DC.St.Pen <> nil) and (DC.St.Pen.Style <> PS_NULL) and (Length(Rijen) > 0) then
  begin
    Waarde := DC.ColorToNative(DC.St.Pen.Color);
    PenBreedte := DC.St.Pen.Width;
    for I := 0 to High(Rijen) do
    begin
      if I = 0 then Vorige := Rijen[I] else Vorige := Rijen[I - 1];
      { linker- en rechterrand, verbonden met de vorige rij }
      for X := Min(Rijen[I].Left, Vorige.Left) to Max(Rijen[I].Left, Vorige.Left) do
        PenPlot(DC, X, Rijen[I].Top, Waarde, PenBreedte);
      for X := Min(Rijen[I].Right, Vorige.Right) - 1 to Max(Rijen[I].Right, Vorige.Right) - 1 do
        PenPlot(DC, X, Rijen[I].Top, Waarde, PenBreedte);
    end;
    for X := Rijen[0].Left to Rijen[0].Right - 1 do PenPlot(DC, X, Rijen[0].Top, Waarde, PenBreedte);
    I := High(Rijen);
    for X := Rijen[I].Left to Rijen[I].Right - 1 do PenPlot(DC, X, Rijen[I].Top, Waarde, PenBreedte);
  end;
end;

procedure GdiRoundRect(DC: TZMDC; X1, Y1, X2, Y2, RondBreedte, RondHoogte: Integer);
var
  Punten: array of TPoint;
  Aantal, I, Stappen: Integer;
  Hoek, RX, RY: Double;
  procedure Hoekpunt(CX, CY: Double; Beginhoek: Double);
  var J: Integer;
  begin
    for J := 0 to Stappen do
    begin
      Hoek := Beginhoek + (Pi / 2) * J / Stappen;
      Punten[Aantal] := Point(Round(CX + RX * Cos(Hoek)), Round(CY - RY * Sin(Hoek)));
      Inc(Aantal);
    end;
  end;
begin
  RX := RondBreedte / 2; RY := RondHoogte / 2;
  if (RX < 1) or (RY < 1) then
  begin
    GdiRectangle(DC, X1, Y1, X2, Y2);
    Exit;
  end;
  if RX > (X2 - X1) / 2 then RX := (X2 - X1) / 2;
  if RY > (Y2 - Y1) / 2 then RY := (Y2 - Y1) / 2;
  Stappen := 6;
  SetLength(Punten, 4 * (Stappen + 1));
  Aantal := 0;
  Hoekpunt(X2 - 1 - RX, Y1 + RY, 0);
  Hoekpunt(X1 + RX, Y1 + RY, Pi / 2);
  Hoekpunt(X1 + RX, Y2 - 1 - RY, Pi);
  Hoekpunt(X2 - 1 - RX, Y2 - 1 - RY, 3 * Pi / 2);
  I := Aantal;
  SetLength(Punten, I);
  GdiPolygon(DC, Punten, True);
end;

procedure GdiFocusRect(DC: TZMDC; const R: TRect);
var
  X, Y, OfsX, OfsY: Integer;
  Doel: TZMBitmap;
  procedure Inverteer(PX, PY: Integer);
  begin
    if (PX < 0) or (PY < 0) or (PX >= Doel.Width) or (PY >= Doel.Height) then Exit;
    if not RectsContain(DC.Eff, PX, PY) then Exit;
    Doel.SetNative(PX, PY, (not Doel.GetNative(PX, PY)) and Doel.NativeMask);
  end;
begin
  Doel := DC.Target;
  if Doel = nil then Exit;
  OfsX := DC.OffX; OfsY := DC.OffY;
  for X := R.Left to R.Right - 1 do
    if (X + R.Top) and 1 = 0 then
    begin
      Inverteer(X + OfsX, R.Top + OfsY);
      if R.Bottom - 1 > R.Top then Inverteer(X + OfsX, R.Bottom - 1 + OfsY);
    end;
  for Y := R.Top + 1 to R.Bottom - 2 do
    if (Y + R.Left) and 1 = 0 then
    begin
      Inverteer(R.Left + OfsX, Y + OfsY);
      if R.Right - 1 > R.Left then Inverteer(R.Right - 1 + OfsX, Y + OfsY);
    end;
  Doel.Dirty := True;
end;

procedure GdiFloodFill(DC: TZMDC; X, Y: Integer; Kleur: COLORREF; Oppervlak: Boolean);
var
  Doel: TZMBitmap;
  Referentie, Waarde: LongWord;
  Stapel: array of TPoint;
  Stapelpos: Integer;
  Punt: TPoint;
  Patroon: TPatInfo;
  Bezocht: array of Boolean;
  function Overeenkomt(PX, PY: Integer): Boolean;
  var Natief: LongWord;
  begin
    Natief := Doel.GetNative(PX, PY);
    if Oppervlak then Result := Natief = Referentie else Result := Natief <> Referentie;
  end;
  procedure Duw(PX, PY: Integer);
  begin
    if (PX < 0) or (PY < 0) or (PX >= Doel.Width) or (PY >= Doel.Height) then Exit;
    if Bezocht[PY * Doel.Width + PX] then Exit;
    if not RectsContain(DC.Eff, PX, PY) then Exit;
    if not Overeenkomt(PX, PY) then Exit;
    Bezocht[PY * Doel.Width + PX] := True;
    if Stapelpos >= Length(Stapel) then SetLength(Stapel, Length(Stapel) * 2 + 64);
    Stapel[Stapelpos] := Point(PX, PY);
    Inc(Stapelpos);
  end;
begin
  Doel := DC.Target;
  if Doel = nil then Exit;
  Inc(X, DC.OffX); Inc(Y, DC.OffY);
  Referentie := DC.ColorToNative(Kleur);
  PreparePattern(DC, Patroon);
  SetLength(Bezocht, Doel.Width * Doel.Height);
  Stapelpos := 0;
  Duw(X, Y);
  while Stapelpos > 0 do
  begin
    Dec(Stapelpos);
    Punt := Stapel[Stapelpos];
    Waarde := PatAt(Patroon, DC, Punt.X, Punt.Y);
    Doel.SetNative(Punt.X, Punt.Y, Waarde);
    Duw(Punt.X + 1, Punt.Y); Duw(Punt.X - 1, Punt.Y); Duw(Punt.X, Punt.Y + 1); Duw(Punt.X, Punt.Y - 1);
  end;
  Doel.Dirty := True;
end;

{ ---------------------------------------------------------------- tekst }

function GdiFace(DC: TZMDC): PZMFace;
begin
  if (DC.St.Font <> nil) and (DC.St.Font.Face <> nil) then
    Result := DC.St.Font.Face
  else
    Result := TZMFontObj(StockObjects[SYSTEM_FONT]).Face;
end;

{ Net als de DIB-engine van Wine: TrueType-lettertypen worden anti-aliased (GGO_GRAY4) op DIB's
  met meer dan 8 bpp; bitmaplettertypen (MS Sans Serif, System, ...) en doelen met <= 8 bpp
  krijgen 1-bit glyphs. De voortgangsbreedtes van de glyphs verschillen tussen beide. }
function IsBitmapFontName(const Naam: string): Boolean;
var
  Genormeerd: string;
begin
  Genormeerd := LowerCase(Trim(Naam));
  Result := (Genormeerd = 'ms sans serif') or (Genormeerd = 'ms serif') or (Genormeerd = 'system') or (Genormeerd = 'fixedsys') or
    (Genormeerd = 'terminal') or (Genormeerd = 'small fonts') or (Genormeerd = 'courier') or (Genormeerd = 'modern') or
    (Genormeerd = 'roman') or (Genormeerd = 'script') or (Genormeerd = '');
end;

function GdiUseAA(DC: TZMDC): Boolean;
var
  Lettertype: TZMFontObj;
begin
  Result := False;
  { anti-aliasing vereist een doel met > 8 bpp en een grootte die de gasp-tabel van het lettertype
    markeert voor grijstinten-weergave (zoals Windows/Wine doet) }
  if (DC.Target = nil) or (DC.Target.BPP <= 8) then Exit;
  Lettertype := DC.St.Font;
  if (Lettertype = nil) or (Lettertype.LF.lfQuality = NONANTIALIASED_QUALITY) then Exit;
  if Lettertype.BitmapFont < 0 then
    if IsBitmapFontName(StrPas(Lettertype.LF.lfFaceName)) then Lettertype.BitmapFont := 1 else Lettertype.BitmapFont := 0;
  Result := (Lettertype.BitmapFont = 0) and not ZMNoAntialias and GdiFace(DC)^.Gray;
end;

function GdiGlyphs(DC: TZMDC): PZMGlyphs;
begin
  if GdiUseAA(DC) then Result := @GdiFace(DC)^.AAGlyphs else Result := @GdiFace(DC)^.Glyphs;
end;

{ Tekstafmetingen gebruiken de normaal gehinte voortgangsbreedtes van TrueType-lettertypen, ook waar de
  glyphs 1-bit getekend worden met de (smallere of bredere) mono-voortgangsbreedtes: Wine meet
  met GGO_METRICS (FT_LOAD_DEFAULT) en tekent met FT_LOAD_TARGET_MONO. }
function GdiExtentGlyphs(DC: TZMDC): PZMGlyphs;
var
  Lettertype: TZMFontObj;
begin
  Lettertype := DC.St.Font;
  if Lettertype <> nil then
  begin
    if Lettertype.BitmapFont < 0 then
      if IsBitmapFontName(StrPas(Lettertype.LF.lfFaceName)) then Lettertype.BitmapFont := 1 else Lettertype.BitmapFont := 0;
    if (Lettertype.BitmapFont = 0) and not ZMNoAntialias then Exit(@GdiFace(DC)^.AAGlyphs);
  end;
  Result := @GdiFace(DC)^.Glyphs;
end;

function GdiTextWidth(DC: TZMDC; Tekst: PAnsiChar; Aantal: Integer): Integer;
var
  I: Integer;
  Glyfen: PZMGlyphs;
begin
  Result := 0;
  if Tekst = nil then Exit;
  Glyfen := GdiExtentGlyphs(DC);
  for I := 0 to Aantal - 1 do
    Inc(Result, Glyfen^[Byte(Tekst[I])].Adv + DC.St.CharExtra);
end;

{ Wine dibdrv: anti-aliased glyph-pixels mengen met een gammaverloop }
const
  AARamp: array[0..16] of Byte = (0, $4d, $68, $7c, $8c, $9a, $a7, $b2, $bd, $c7, $d0, $d9,
    $e1, $e9, $f0, $f8, $ff);

function AAComp(Doelkleur, Tekstkleur, Niveau: Integer): Integer; inline;
var
  MinKleur, MaxKleur: Integer;
begin
  MinKleur := (AARamp[Niveau] * Tekstkleur) div $FF;
  MaxKleur := AARamp[16 - Niveau] + (($FF - AARamp[16 - Niveau]) * Tekstkleur) div $FF;
  if Doelkleur = Tekstkleur then Result := Doelkleur
  else if Doelkleur > Tekstkleur then Result := Tekstkleur + ((Doelkleur - Tekstkleur) * (MaxKleur - Tekstkleur)) div ($FF - Tekstkleur)
  else Result := Tekstkleur - ((Tekstkleur - Doelkleur) * (Tekstkleur - MinKleur)) div Tekstkleur;
end;

procedure DrawGlyphAA(DC: TZMDC; const Glyf: TZMGlyph; X, Y: Integer; RGB: LongWord; const Knip: TZMRects);
var
  I, PX, PY, Dekking: Integer;
  GlyfR, KnipR: TRect;
  Rij: PByte;
  Doel: TZMBitmap;
  Doelwaarde: LongWord;
  TekstR, TekstG, TekstB: Integer;
begin
  if (Glyf.W <= 0) or (Glyf.H <= 0) or (Glyf.Data = nil) then Exit;
  Doel := DC.Target;
  TekstR := (RGB shr 16) and $FF; TekstG := (RGB shr 8) and $FF; TekstB := RGB and $FF;
  GlyfR := Rect(X + Glyf.XOff, Y + Glyf.YOff, X + Glyf.XOff + Glyf.W, Y + Glyf.YOff + Glyf.H);
  for I := 0 to High(Knip) do
  begin
    KnipR := Knip[I];
    if KnipR.Left < GlyfR.Left then KnipR.Left := GlyfR.Left;
    if KnipR.Top < GlyfR.Top then KnipR.Top := GlyfR.Top;
    if KnipR.Right > GlyfR.Right then KnipR.Right := GlyfR.Right;
    if KnipR.Bottom > GlyfR.Bottom then KnipR.Bottom := GlyfR.Bottom;
    if (KnipR.Right <= KnipR.Left) or (KnipR.Bottom <= KnipR.Top) then Continue;
    for PY := KnipR.Top to KnipR.Bottom - 1 do
    begin
      Rij := Glyf.Data + (PY - GlyfR.Top) * Glyf.W;
      for PX := KnipR.Left to KnipR.Right - 1 do
      begin
        Dekking := Rij[PX - GlyfR.Left];
        if Dekking <= 1 then Continue;   { zoals Wine: niveau 0 en 1 laten de pixel staan }
        if Dekking >= 16 then
          Doel.SetNative(PX, PY, Doel.RGBToNative(RGB))
        else
        begin
          Doelwaarde := Doel.NativeToRGB(Doel.GetNative(PX, PY));
          Doelwaarde := (LongWord(AAComp((Doelwaarde shr 16) and $FF, TekstR, Dekking)) shl 16) or
            (LongWord(AAComp((Doelwaarde shr 8) and $FF, TekstG, Dekking)) shl 8) or LongWord(AAComp(Doelwaarde and $FF, TekstB, Dekking));
          Doel.SetNative(PX, PY, Doel.RGBToNative(Doelwaarde));
        end;
      end;
    end;
  end;
end;

procedure DrawGlyph(DC: TZMDC; const Glyf: TZMGlyph; X, Y: Integer; Waarde: LongWord; const Knip: TZMRects);
var
  I, GlyfRij, GlyfKol, Rijlengte, PX, PY: Integer;
  GlyfR, KnipR: TRect;
  Rij: PByte;
  Doel: TZMBitmap;
begin
  if (Glyf.W <= 0) or (Glyf.H <= 0) or (Glyf.Data = nil) then Exit;
  Doel := DC.Target;
  Rijlengte := (Glyf.W + 7) div 8;
  GlyfR := Rect(X + Glyf.XOff, Y + Glyf.YOff, X + Glyf.XOff + Glyf.W, Y + Glyf.YOff + Glyf.H);
  for I := 0 to High(Knip) do
  begin
    KnipR := Knip[I];
    if KnipR.Left < GlyfR.Left then KnipR.Left := GlyfR.Left;
    if KnipR.Top < GlyfR.Top then KnipR.Top := GlyfR.Top;
    if KnipR.Right > GlyfR.Right then KnipR.Right := GlyfR.Right;
    if KnipR.Bottom > GlyfR.Bottom then KnipR.Bottom := GlyfR.Bottom;
    if (KnipR.Right <= KnipR.Left) or (KnipR.Bottom <= KnipR.Top) then Continue;
    for PY := KnipR.Top to KnipR.Bottom - 1 do
    begin
      GlyfRij := PY - GlyfR.Top;
      Rij := Glyf.Data + GlyfRij * Rijlengte;
      for PX := KnipR.Left to KnipR.Right - 1 do
      begin
        GlyfKol := PX - GlyfR.Left;
        if Rij[GlyfKol shr 3] and ($80 shr (GlyfKol and 7)) <> 0 then
          Doel.SetNative(PX, PY, Waarde);
      end;
    end;
  end;
end;

procedure GdiTextOut(DC: TZMDC; X, Y: Integer; Tekst: PAnsiChar; Aantal: Integer;
  MetVulling: Boolean; KnipR: PRect; VulR: PRect);
var
  Gezicht: PZMFace;
  Breedte, I, TekstX, TekstY, OfsX, OfsY: Integer;
  Knip: TZMRects;
  Waarde: LongWord;
  Achtergrond: TRect;
  Uitlijning: UINT;
  Letterdef: TLogFont;
  Glyfen: PZMGlyphs;
  Antialias: Boolean;
begin
  if (DC.Target = nil) or (DC.Target.Bits = nil) then Exit;
  Gezicht := GdiFace(DC);
  Glyfen := GdiGlyphs(DC);
  Antialias := GdiUseAA(DC);
  Breedte := GdiTextWidth(DC, Tekst, Aantal);
  Uitlijning := DC.St.TextAlign;
  if Uitlijning and TA_UPDATECP <> 0 then
  begin
    X := DC.St.CurPos.X;
    Y := DC.St.CurPos.Y;
  end;
  case Uitlijning and (TA_CENTER) of
    TA_RIGHT: Dec(X, Breedte);
    TA_CENTER: Dec(X, Breedte div 2);
  end;
  if Uitlijning and TA_BASELINE = TA_BASELINE then Dec(Y, Gezicht^.Ascent)
  else if Uitlijning and TA_BOTTOM <> 0 then Dec(Y, Gezicht^.Height);
  if Uitlijning and TA_UPDATECP <> 0 then
    DC.St.CurPos.X := X + Breedte;
  OfsX := DC.OffX; OfsY := DC.OffY;
  Knip := DC.Eff;
  if KnipR <> nil then
    Knip := RectsIntersectRect(Knip, Rect(KnipR^.Left + OfsX, KnipR^.Top + OfsY, KnipR^.Right + OfsX, KnipR^.Bottom + OfsY));
  if VulR <> nil then
    FillNative(DC, Rect(VulR^.Left + OfsX, VulR^.Top + OfsY, VulR^.Right + OfsX, VulR^.Bottom + OfsY),
      DC.ColorToNative(DC.St.BkColor));
  if MetVulling and (DC.St.BkMode = OPAQUE) then
  begin
    Achtergrond := Rect(X + OfsX, Y + OfsY, X + OfsX + Breedte, Y + OfsY + Gezicht^.Height);
    if KnipR <> nil then
      IntersectRect(Achtergrond, Achtergrond, Rect(KnipR^.Left + OfsX, KnipR^.Top + OfsY, KnipR^.Right + OfsX, KnipR^.Bottom + OfsY));
    FillNative(DC, Achtergrond, DC.ColorToNative(DC.St.BkColor));
  end;
  Waarde := DC.ColorToNative(DC.St.TextColor);
  TekstX := X + OfsX;
  TekstY := Y + OfsY;
  for I := 0 to Aantal - 1 do
  begin
    if Antialias then
      DrawGlyphAA(DC, Glyfen^[Byte(Tekst[I])], TekstX, TekstY, DC.ColorToRGB(DC.St.TextColor), Knip)
    else
      DrawGlyph(DC, Glyfen^[Byte(Tekst[I])], TekstX, TekstY, Waarde, Knip);
    Inc(TekstX, Glyfen^[Byte(Tekst[I])].Adv + DC.St.CharExtra);
  end;
  if DC.St.Font <> nil then
  begin
    Letterdef := DC.St.Font.LF;
    if Letterdef.lfUnderline <> 0 then
      FillNative(DC, RectsBox(RectsIntersectRect(Knip,
        Rect(X + OfsX, Y + OfsY + Gezicht^.Ascent + 1, X + OfsX + Breedte, Y + OfsY + Gezicht^.Ascent + 2))), Waarde);
    if Letterdef.lfStrikeOut <> 0 then
      FillNative(DC, RectsBox(RectsIntersectRect(Knip,
        Rect(X + OfsX, Y + OfsY + Gezicht^.Ascent * 2 div 3, X + OfsX + Breedte, Y + OfsY + Gezicht^.Ascent * 2 div 3 + 1))), Waarde);
  end;
  DC.Target.Dirty := True;
end;

function GdiDrawText(DC: TZMDC; Tekst: PAnsiChar; Aantal: Integer; var R: TRect; Opmaak: UINT): Integer;
type
  TLine = record Start, Len: Integer; end;
var
  Gezicht: PZMFace;
  Invoer: AnsiString;
  Regels: array of TLine;
  I, RegelHoogte, MaxBreedte, Breedte, Y, X, Positie, LaatsteSpatie, RegelStart, HuidigeBreedte, TotaleHoogte: Integer;
  Afbreken: Boolean;
  Regeltekst: AnsiString;
  Onderlijn: Integer;
  procedure VoegRegelToe(Beginpos, Lengte: Integer);
  begin
    SetLength(Regels, Length(Regels) + 1);
    Regels[High(Regels)].Start := Beginpos;
    Regels[High(Regels)].Len := Lengte;
  end;
  function TekenBreedte(Index: Integer): Integer;
  begin
    Result := GdiExtentGlyphs(DC)^[Byte(Invoer[Index])].Adv + DC.St.CharExtra;
  end;
  procedure VerwijderPrefix(var Tekstregel: AnsiString; var Onderpos: Integer);
  var J: Integer;
  begin
    Onderpos := -1;
    if Opmaak and DT_NOPREFIX <> 0 then Exit;
    J := 1;
    while J <= Length(Tekstregel) do
    begin
      if Tekstregel[J] = '&' then
      begin
        Delete(Tekstregel, J, 1);
        if (J <= Length(Tekstregel)) and (Tekstregel[J] <> '&') then Onderpos := J;
      end;
      Inc(J);
    end;
  end;
begin
  Result := 0;
  Gezicht := GdiFace(DC);
  if Aantal < 0 then Aantal := StrLen(Tekst);
  SetString(Invoer, Tekst, Aantal);
  if Opmaak and DT_EXPANDTABS <> 0 then
    Invoer := StringReplace(Invoer, #9, '        ', [rfReplaceAll]);
  RegelHoogte := Gezicht^.Height;
  if Opmaak and DT_EXTERNALLEADING <> 0 then Inc(RegelHoogte, 0);
  MaxBreedte := R.Right - R.Left;
  Afbreken := (Opmaak and DT_WORDBREAK <> 0) and (Opmaak and DT_SINGLELINE = 0);
  Regels := nil;
  if Opmaak and DT_SINGLELINE <> 0 then
  begin
    for I := 1 to Length(Invoer) do
      if Invoer[I] in [#13, #10] then Invoer[I] := ' ';
    VoegRegelToe(1, Length(Invoer));
  end
  else
  begin
    Positie := 1;
    RegelStart := 1;
    LaatsteSpatie := 0;
    HuidigeBreedte := 0;
    while Positie <= Length(Invoer) do
    begin
      if Invoer[Positie] = #13 then
      begin
        VoegRegelToe(RegelStart, Positie - RegelStart);
        if (Positie < Length(Invoer)) and (Invoer[Positie + 1] = #10) then Inc(Positie);
        Inc(Positie);
        RegelStart := Positie; LaatsteSpatie := 0; HuidigeBreedte := 0;
        Continue;
      end;
      if Invoer[Positie] = #10 then
      begin
        VoegRegelToe(RegelStart, Positie - RegelStart);
        Inc(Positie);
        RegelStart := Positie; LaatsteSpatie := 0; HuidigeBreedte := 0;
        Continue;
      end;
      if Invoer[Positie] = ' ' then LaatsteSpatie := Positie;
      Inc(HuidigeBreedte, TekenBreedte(Positie));
      if Afbreken and (HuidigeBreedte > MaxBreedte) and (Positie > RegelStart) then
      begin
        if LaatsteSpatie >= RegelStart then
        begin
          VoegRegelToe(RegelStart, LaatsteSpatie - RegelStart);
          Positie := LaatsteSpatie + 1;
        end
        else
        begin
          VoegRegelToe(RegelStart, Positie - RegelStart);
        end;
        RegelStart := Positie; LaatsteSpatie := 0; HuidigeBreedte := 0;
        Continue;
      end;
      Inc(Positie);
    end;
    if (RegelStart <= Length(Invoer)) or (Length(Regels) = 0) then
      VoegRegelToe(RegelStart, Length(Invoer) - RegelStart + 1);
  end;
  TotaleHoogte := Length(Regels) * RegelHoogte;
  if Opmaak and DT_CALCRECT <> 0 then
  begin
    MaxBreedte := 0;
    for I := 0 to High(Regels) do
    begin
      Regeltekst := Copy(Invoer, Regels[I].Start, Regels[I].Len);
      VerwijderPrefix(Regeltekst, Onderlijn);
      Breedte := GdiTextWidth(DC, PAnsiChar(Regeltekst), Length(Regeltekst));
      if Breedte > MaxBreedte then MaxBreedte := Breedte;
    end;
    if not Afbreken or (MaxBreedte > R.Right - R.Left) or True then
      R.Right := R.Left + MaxBreedte;
    R.Bottom := R.Top + TotaleHoogte;
    Exit(TotaleHoogte);
  end;
  if Opmaak and DT_SINGLELINE <> 0 then
  begin
    if Opmaak and DT_VCENTER <> 0 then Y := R.Top + (R.Bottom - R.Top - RegelHoogte) div 2
    else if Opmaak and DT_BOTTOM <> 0 then Y := R.Bottom - RegelHoogte
    else Y := R.Top;
  end
  else
    Y := R.Top;
  for I := 0 to High(Regels) do
  begin
    Regeltekst := Copy(Invoer, Regels[I].Start, Regels[I].Len);
    VerwijderPrefix(Regeltekst, Onderlijn);
    Breedte := GdiTextWidth(DC, PAnsiChar(Regeltekst), Length(Regeltekst));
    if Opmaak and DT_CENTER <> 0 then X := R.Left + (R.Right - R.Left - Breedte) div 2
    else if Opmaak and DT_RIGHT <> 0 then X := R.Right - Breedte
    else X := R.Left;
    if Opmaak and DT_NOCLIP <> 0 then
      GdiTextOut(DC, X, Y, PAnsiChar(Regeltekst), Length(Regeltekst), True, nil, nil)
    else
      GdiTextOut(DC, X, Y, PAnsiChar(Regeltekst), Length(Regeltekst), True, @R, nil);
    if Onderlijn > 0 then
    begin
      Positie := X + GdiTextWidth(DC, PAnsiChar(Regeltekst), Onderlijn - 1);
      GdiFillSolid(DC, Rect(Positie, Y + Gezicht^.Ascent + 1, Positie + GdiExtentGlyphs(DC)^[Byte(Regeltekst[Onderlijn])].Adv,
        Y + Gezicht^.Ascent + 2), DC.St.TextColor);
    end;
    Inc(Y, RegelHoogte);
  end;
  Result := TotaleHoogte;
end;

{ ---------------------------------------------------------------- standaardobjecten }

procedure InitStockObjects;
const
  Sys: array[0..28] of COLORREF = (
    $C8D0D4, $808000, $800000, $808080, $C0C0C0, $FFFFFF, $000000, $000000, $000000,
    $FFFFFF, $C0C0C0, $C0C0C0, $808080, $800000, $FFFFFF, $C0C0C0, $808080, $808080,
    $000000, $C0C0C0, $FFFFFF, $000000, $DFDFDF, $000000, $E1FFFF, $B5B5B5, $800000,
    $D08410, $C0C0C0);
var
  Kwast: TZMBrush;
  Pen: TZMPen;
  Letterdef: TLogFont;
  Palet: TZMPalette;
  I: Integer;
  procedure ZetStock(Nr: Integer; Ding: TZMGdiObj);
  begin
    Ding.IsStock := True;
    StockObjects[Nr] := Ding;
  end;
  function MaakKwast(Stijl: UINT; Kleur: COLORREF): TZMBrush;
  begin
    Result := TZMBrush.Create;
    Result.Style := Stijl;
    Result.Color := Kleur;
  end;
  function MaakPen(Stijl: UINT; Kleur: COLORREF): TZMPen;
  begin
    Result := TZMPen.Create;
    Result.Style := Stijl;
    Result.Color := Kleur;
  end;
  function MaakLetter(Hoogte, Gewicht: Integer; const Naam: AnsiString; Lettersoort: Byte): TZMFontObj;
  begin
    FillChar(Letterdef, SizeOf(Letterdef), 0);
    Letterdef.lfHeight := Hoogte;
    Letterdef.lfWeight := Gewicht;
    Letterdef.lfPitchAndFamily := Lettersoort;
    StrPLCopy(Letterdef.lfFaceName, Naam, 31);
    Result := TZMFontObj.Create(Letterdef);
  end;
begin
  if StockObjects[0] <> nil then Exit;
  ZetStock(WHITE_BRUSH, MaakKwast(BS_SOLID, $FFFFFF));
  ZetStock(LTGRAY_BRUSH, MaakKwast(BS_SOLID, $C0C0C0));
  ZetStock(GRAY_BRUSH, MaakKwast(BS_SOLID, $808080));
  ZetStock(DKGRAY_BRUSH, MaakKwast(BS_SOLID, $404040));
  ZetStock(BLACK_BRUSH, MaakKwast(BS_SOLID, $000000));
  ZetStock(NULL_BRUSH, MaakKwast(BS_NULL, 0));
  ZetStock(WHITE_PEN, MaakPen(PS_SOLID, $FFFFFF));
  ZetStock(BLACK_PEN, MaakPen(PS_SOLID, 0));
  ZetStock(NULL_PEN, MaakPen(PS_NULL, 0));
  ZetStock(9, MaakKwast(BS_NULL, 0));
  ZetStock(OEM_FIXED_FONT, MaakLetter(-12, 400, 'Courier New', FIXED_PITCH));
  ZetStock(ANSI_FIXED_FONT, MaakLetter(-12, 400, 'Courier New', FIXED_PITCH));
  ZetStock(ANSI_VAR_FONT, MaakLetter(-11, 400, 'MS Sans Serif', VARIABLE_PITCH));
  ZetStock(SYSTEM_FONT, MaakLetter(16, 700, 'System', VARIABLE_PITCH));
  ZetStock(DEVICE_DEFAULT_FONT, MaakLetter(16, 700, 'System', VARIABLE_PITCH));
  Palet := TZMPalette.Create;
  Palet.Count := 20;
  begin
    { de 20 vaste systeemkleuren }
    HalftoneEntries(Palet.Entries);
    for I := 0 to 9 do Palet.Entries[10 + I] := Palet.Entries[246 + I];
  end;
  ZetStock(DEFAULT_PALETTE, Palet);
  ZetStock(SYSTEM_FIXED_FONT, MaakLetter(-12, 400, 'Courier New', FIXED_PITCH));
  ZetStock(DEFAULT_GUI_FONT, MaakLetter(-11, 400, 'MS Sans Serif', VARIABLE_PITCH));
  for I := 0 to High(SysColors) do
  begin
    if I <= High(Sys) then SysColors[I] := Sys[I] else SysColors[I] := 0;
    Kwast := MaakKwast(BS_SOLID, SysColors[I]);
    Kwast.IsStock := True;
    SysColorBrushes[I] := Kwast;
  end;
  Pen := nil;
  if Pen = nil then ;
end;

initialization
  ZMNoAntialias := GetEnvironmentVariable('ZM_NO_AA') = '1';
  InitStockObjects;
end.

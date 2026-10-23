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
  ZM_GDI_MAGIE = $47444D5A;  { 'ZMDG' }

type
  TZMRechtlijst = array of TRect;

  TZMGdiObj = class
  public
    Magie: LongWord;
    Handle: THandle;
    ObjSoort: Integer;     { OBJ_xxx }
    IsVoorraadObject: Boolean;
    constructor Create(ASoort: Integer);
    destructor Destroy; override;
  end;

  TZMPalet = class(TZMGdiObj)
  public
    Count: Integer;
    Entries: array[0..255] of TPaletteEntry;
    constructor Create;
  end;

  TZMBitmap = class(TZMGdiObj)
  private
    FDichtbijCache: array of SmallInt;   { 15-bit RGB -> dichtstbijzijnde index + 1 }
    FDichtbijStempel: LongWord;
  public
    Width, Height, BPP, Rijbytes: Integer;
    Bits: PByte;
    EigenBits: Boolean;
    NumColors: Integer;
    Kleuren: array[0..255] of LongWord;  { $00RRGGBB }
    KleurStempel: LongWord;               { wordt verhoogd wanneer Kleuren wijzigt }
    Vuil: Boolean;                     { gezet door tekenen (gebruikt voor het scherm) }
    IsDIB: Boolean;                     { DIB-sectie (versus apparaatafhankelijke bitmap) }
    GeselecteerdIn: TObject;                { DC waarin de bitmap is geselecteerd }
    constructor Create(ABreedte, AHoogte, ABPP: Integer);
    destructor Destroy; override;
    procedure ZetStandaardKleuren;
    procedure KleurenGewijzigd;
    function RijPtr(Y: Integer): PByte; inline;
    function LeesNatief(X, Y: Integer): LongWord;
    procedure ZetNatief(X, Y: Integer; Waarde: LongWord);
    function NatiefNaarRGB(Waarde: LongWord): LongWord;
    function RGBNaarNatief(RGB: LongWord): LongWord;
    function Dichtstbij(RGB: LongWord): Integer;
    function NatiefMasker: LongWord;
  end;

  TZMKwast = class(TZMGdiObj)
  public
    Style: UINT;
    Color: COLORREF;
    Arceringsoort: PtrInt;
    Motief: TZMBitmap;  { eigen kopie voor BS_PATTERN }
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

  TZMLetterObj = class(TZMGdiObj)
  public
    LF: TLogFont;
    Lettergezicht: PZMGezicht;
    BitmapLetter: Integer;   { -1 onbekend, 0 TrueType, 1 bitmaplettertype }
    constructor Create(const ALettertype: TLogFont);
  end;

  TZMRegio = class(TZMGdiObj)
  public
    Rechtlijst: TZMRechtlijst;
    constructor Create;
    function Omhullende: TRect;
  end;

  TZMDCToestand = record
    VensterOorsprong, ViewportOorsprong: TPoint;
    HeeftKnip: Boolean;
    KnipRegio: TZMRechtlijst;
    Pen: TZMPen;
    Brush: TZMKwast;
    Font: TZMLetterObj;
    Palette: TZMPalet;
    BkColor, TekstKleurVoor: COLORREF;
    BkMode, ROP2, StretchMode: Integer;
    TekstUitlijning: UINT;
    HuidigePositie, KwastOorsprong: TPoint;
    CharExtra: Integer;
  end;

  TZMDC = class(TZMGdiObj)
  private
    FEffectief: TZMRechtlijst;
    FEffGeldig: Boolean;
  public
    Target: TZMBitmap;     { oppervlak waarop getekend wordt }
    IsGeheugenDC: Boolean;
    StandaardBitmap: TZMBitmap;  { 1x1 mono-bitmap van een nieuwe geheugen-DC }
    Wnd: HWND;             { venster van een vensterDC (0 = scherm / geheugen) }
    IsTekenDC: Boolean;
    ApparaatOorsprong: TPoint;        { positie van de oorsprong van het apparaat (client) in Target }
    HeeftZichtbaar: Boolean;
    ZichtRegio: TZMRechtlijst;      { zichtbaar gebied in Target-coördinaten }
    ZichtGeneratie: Integer;       { ZMZichtGeneratie toen ZichtRegio berekend werd (vensterDCs) }
    IsVensterDC: Boolean;   { GetWindowDC: oorsprong bij de vensterhoek, niet bij de client }
    TekenRegio: TZMRechtlijst;    { BeginPaint: updateregio (Target-coördinaten) }
    HeeftTekenRegio: Boolean;
    St: TZMDCToestand;
    Bewaard: array of TZMDCToestand;
    constructor Create(ADoel: TZMBitmap);
    destructor Destroy; override;
    procedure MaakKnipOngeldig;
    function Effectief: TZMRechtlijst;                { effectieve knipregio in Target-coördinaten }
    function LPnaarT(X, Y: Integer): TPoint; inline;   { logisch -> target }
    function OorsprongX: Integer; inline;
    function OorsprongY: Integer; inline;
    function KleurNaarNatief(Kleur: COLORREF): LongWord;
    function ColorToRGB(Kleur: COLORREF): LongWord;
    procedure SelecteerBitmap(Bitmap: TZMBitmap);
  end;

var
  { ZM_NO_AA=1: tekst nooit anti-aliasen }
  ZMGeenAntialias: Boolean = False;
  { vensterDCs berekenen hun zichtbare regio opnieuw wanneer de vensterindeling wijzigt }
  ZMZichtGeneratie: Integer = 1;
  ZMZichtLeverancier: procedure(DC: TObject) = nil;

  StandaardObjecten: array[0..17] of TZMGdiObj;
  SysteemKleuren: array[0..30] of COLORREF;
  SysteemKleurKwasten: array[0..30] of TZMKwast;

{ handle-hulpfuncties }
function GdiObject(Handvat: THandle): TZMGdiObj;
function GdiDC(Handvat: THandle): TZMDC;
function GdiBitmap(Handvat: THandle): TZMBitmap;
function GdiPalet(Handvat: THandle): TZMPalet;
function GdiKwast(Handvat: THandle): TZMKwast;
function GdiRegio(Handvat: THandle): TZMRegio;
function GdiLetter(Handvat: THandle): TZMLetterObj;
function H2(Ding: TObject): THandle;

{ kleuren }
function KleurRefNaarRGB(Kleur: COLORREF): LongWord; inline;   { $00BBGGRR -> $00RRGGBB }
function RGBNaarKleurRef(Kleur: LongWord): COLORREF; inline;

{ rechthoeklijsten }
function RechtlijstSnijdRechthoek(const Rechthoeken: TZMRechtlijst; const R: TRect): TZMRechtlijst;
function RechtlijstSnijd(const Rechthoeken, Andere: TZMRechtlijst): TZMRechtlijst;
function RechtlijstAftrekRechthoek(const Rechthoeken: TZMRechtlijst; const R: TRect): TZMRechtlijst;
function RechtlijstAftrek(const Rechthoeken, Andere: TZMRechtlijst): TZMRechtlijst;
function RechtlijstVereniging(const Rechthoeken, Andere: TZMRechtlijst): TZMRechtlijst;
function RechtlijstVerschuif(const Rechthoeken: TZMRechtlijst; VerschuifX, VerschuifY: Integer): TZMRechtlijst;
function RechtlijstOmhulling(const Rechthoeken: TZMRechtlijst): TRect;
function RechtlijstBevat(const Rechthoeken: TZMRechtlijst; X, Y: Integer): Boolean;
function RechtlijstKopie(const Rechthoeken: TZMRechtlijst): TZMRechtlijst;

{ tekenprimitieven (coördinaten zijn logisch, d.w.z. zoals ze aan de API worden doorgegeven) }
procedure GdiKopieer(DoelDC: TZMDC; X, Y, Breedte, Hoogte: Integer; BronDC: TZMDC; BronPosX, BronPosY, BronBreedte, BronHoogte: Integer;
  Rop: DWORD; Uitrekken: Boolean);
procedure GdiKopieerBitmap(DoelDC: TZMDC; X, Y, Breedte, Hoogte: Integer; BronBitmap: TZMBitmap; BronAchtergrond: COLORREF;
  BronPosX, BronPosY, BronBreedte, BronHoogte: Integer; Rop: DWORD; Uitrekken: Boolean);
procedure GdiPatKopieer(DC: TZMDC; X, Y, Breedte, Hoogte: Integer; Rop: DWORD);
procedure GdiVulRechthoek(DC: TZMDC; const R: TRect; Kwast: TZMKwast);
procedure GdiVulEffen(DC: TZMDC; const R: TRect; Kleur: COLORREF);
procedure GdiInverteerRechthoek(DC: TZMDC; const R: TRect);
procedure GdiFocusRechthoek(DC: TZMDC; const R: TRect);
procedure GdiLijn(DC: TZMDC; X1, Y1, X2, Y2: Integer; LaatstePixel: Boolean);
procedure GdiRechthoek(DC: TZMDC; X1, Y1, X2, Y2: Integer);
procedure GdiEllips(DC: TZMDC; X1, Y1, X2, Y2: Integer);
procedure GdiAfrondRechthoek(DC: TZMDC; X1, Y1, X2, Y2, RondBreedte, RondHoogte: Integer);
procedure GdiVeelhoek(DC: TZMDC; const Punten: array of TPoint; Vullen: Boolean);
procedure GdiPolylijn(DC: TZMDC; const Punten: array of TPoint);
procedure GdiZetPixel(DC: TZMDC; X, Y: Integer; Kleur: COLORREF);
function GdiLeesPixel(DC: TZMDC; X, Y: Integer): COLORREF;
procedure GdiVulGebied(DC: TZMDC; X, Y: Integer; Kleur: COLORREF; Oppervlak: Boolean);

{ tekst }
function GdiGezicht(DC: TZMDC): PZMGezicht;
function GdiGebruikAA(DC: TZMDC): Boolean;
function GdiGlyfen(DC: TZMDC): PZMTekenbeelden;
function GdiTekstBreedte(DC: TZMDC; Tekst: PAnsiChar; Aantal: Integer): Integer;
function IsBitmapLetterNaam(const Naam: string): Boolean;
procedure GdiTekstUit(DC: TZMDC; X, Y: Integer; Tekst: PAnsiChar; Aantal: Integer;
  MetVulling: Boolean; KnipR: PRect; VulR: PRect);
function GdiTekenTekst(DC: TZMDC; Tekst: PAnsiChar; Aantal: Integer; var R: TRect; Opmaak: UINT): Integer;

{ hulpfuncties }
procedure ZMLeesRij(Bitmap: TZMBitmap; Y, X, Aantal: Integer; Buffer: PLongWord);
procedure ZMSchrijfRij(Bitmap: TZMBitmap; Y, X, Aantal: Integer; Buffer: PLongWord);
function NieuweBitmapUitInfo(const Info: TBitmapInfo; Gebruik: UINT; Palet: TZMPalet): TZMBitmap;
procedure HalftoneIngangen(var Ingangen: array of TPaletteEntry);
procedure InitStandaardObjecten;

implementation

uses SysUtils, Math, Classes, ZMHandles;

{ ---------------------------------------------------------------- objecten }

constructor TZMGdiObj.Create(ASoort: Integer);
begin
  inherited Create;
  Magie := ZM_GDI_MAGIE;
  ObjSoort := ASoort;
  Handle := ZMReserveerGreep(Self);
end;

destructor TZMGdiObj.Destroy;
begin
  Magie := 0;
  ZMGeefGreepVrij(Handle);
  inherited Destroy;
end;

function H2(Ding: TObject): THandle;
begin
  if Ding = nil then Result := 0 else Result := TZMGdiObj(Ding).Handle;
end;

function GdiObject(Handvat: THandle): TZMGdiObj;
var Ding: TObject;
begin
  Result := nil;
  Ding := ZMGreepVoorwerp(Handvat);
  if (Ding <> nil) and (Ding is TZMGdiObj) then Result := TZMGdiObj(Ding);
end;

function GdiDC(Handvat: THandle): TZMDC;
var Ding: TZMGdiObj;
begin
  Ding := GdiObject(Handvat);
  if (Ding <> nil) and (Ding is TZMDC) then Result := TZMDC(Ding) else Result := nil;
end;

function GdiBitmap(Handvat: THandle): TZMBitmap;
var Ding: TZMGdiObj;
begin
  Ding := GdiObject(Handvat);
  if (Ding <> nil) and (Ding is TZMBitmap) then Result := TZMBitmap(Ding) else Result := nil;
end;

function GdiPalet(Handvat: THandle): TZMPalet;
var Ding: TZMGdiObj;
begin
  Ding := GdiObject(Handvat);
  if (Ding <> nil) and (Ding is TZMPalet) then Result := TZMPalet(Ding) else Result := nil;
end;

function GdiKwast(Handvat: THandle): TZMKwast;
var Ding: TZMGdiObj;
begin
  if (Handvat > 0) and (Handvat <= 31) then
  begin
    { (COLOR_xxx + 1) gebruikt als klasse-achtergrondkwast }
    Result := SysteemKleurKwasten[Handvat - 1];
    Exit;
  end;
  Ding := GdiObject(Handvat);
  if (Ding <> nil) and (Ding is TZMKwast) then Result := TZMKwast(Ding) else Result := nil;
end;

function GdiRegio(Handvat: THandle): TZMRegio;
var Ding: TZMGdiObj;
begin
  Ding := GdiObject(Handvat);
  if (Ding <> nil) and (Ding is TZMRegio) then Result := TZMRegio(Ding) else Result := nil;
end;

function GdiLetter(Handvat: THandle): TZMLetterObj;
var Ding: TZMGdiObj;
begin
  Ding := GdiObject(Handvat);
  if (Ding <> nil) and (Ding is TZMLetterObj) then Result := TZMLetterObj(Ding) else Result := nil;
end;

constructor TZMPalet.Create;
begin
  inherited Create(OBJ_PAL);
end;

constructor TZMKwast.Create;
begin
  inherited Create(OBJ_BRUSH);
end;

destructor TZMKwast.Destroy;
begin
  Motief.Free;
  inherited Destroy;
end;

constructor TZMPen.Create;
begin
  inherited Create(OBJ_PEN);
  Width := 1;
end;

constructor TZMLetterObj.Create(const ALettertype: TLogFont);
begin
  inherited Create(OBJ_FONT);
  LF := ALettertype;
  Lettergezicht := ZMZoekGezicht(LF);
  BitmapLetter := -1;
end;

constructor TZMRegio.Create;
begin
  inherited Create(OBJ_REGION);
end;

function TZMRegio.Omhullende: TRect;
begin
  Result := RechtlijstOmhulling(Rechtlijst);
end;

{ ---------------------------------------------------------------- kleuren }

function KleurRefNaarRGB(Kleur: COLORREF): LongWord; inline;
begin
  Result := ((Kleur and $FF) shl 16) or (Kleur and $FF00) or ((Kleur shr 16) and $FF);
end;

function RGBNaarKleurRef(Kleur: LongWord): COLORREF; inline;
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
  Rijbytes := ((Width * BPP + 31) div 32) * 4;
  if Rijbytes * Height > 0 then
  begin
    Bits := AllocMem(Rijbytes * Height);
    EigenBits := True;
  end;
  ZetStandaardKleuren;
end;

destructor TZMBitmap.Destroy;
begin
  if EigenBits and (Bits <> nil) then FreeMem(Bits);
  inherited Destroy;
end;

procedure HalftoneIngangen(var Ingangen: array of TPaletteEntry);
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

procedure TZMBitmap.ZetStandaardKleuren;
var
  Ingangen: array[0..255] of TPaletteEntry;
  I: Integer;
begin
  case BPP of
    1:
      begin
        NumColors := 2;
        Kleuren[0] := 0;
        Kleuren[1] := $FFFFFF;
      end;
    4:
      begin
        NumColors := 16;
        HalftoneIngangen(Ingangen);
        for I := 0 to 7 do
          Kleuren[I] := (Ingangen[I].peRed shl 16) or (Ingangen[I].peGreen shl 8) or Ingangen[I].peBlue;
        for I := 8 to 15 do
          Kleuren[I] := (Ingangen[240 + I].peRed shl 16) or (Ingangen[240 + I].peGreen shl 8) or Ingangen[240 + I].peBlue;
        Kleuren[7] := $C0C0C0;
        Kleuren[8] := $808080;
      end;
    8:
      begin
        NumColors := 256;
        HalftoneIngangen(Ingangen);
        for I := 0 to 255 do
          Kleuren[I] := (Ingangen[I].peRed shl 16) or (Ingangen[I].peGreen shl 8) or Ingangen[I].peBlue;
      end;
  else
    NumColors := 0;
  end;
  KleurenGewijzigd;
end;

procedure TZMBitmap.KleurenGewijzigd;
begin
  Inc(KleurStempel);
end;

function TZMBitmap.RijPtr(Y: Integer): PByte; inline;
begin
  Result := Bits + PtrInt(Y) * Rijbytes;
end;

function TZMBitmap.NatiefMasker: LongWord;
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

function TZMBitmap.LeesNatief(X, Y: Integer): LongWord;
var
  Rij: PByte;
begin
  Rij := Bits + PtrInt(Y) * Rijbytes;
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

procedure TZMBitmap.ZetNatief(X, Y: Integer; Waarde: LongWord);
var
  Rij: PByte;
  Masker: Byte;
begin
  Rij := Bits + PtrInt(Y) * Rijbytes;
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

function TZMBitmap.NatiefNaarRGB(Waarde: LongWord): LongWord;
begin
  case BPP of
    1, 4, 8:
      if Integer(Waarde) < NumColors then Result := Kleuren[Waarde] else Result := 0;
    16:
      Result := (((Waarde shr 10) and $1F) * 255 div 31) shl 16 or
        (((Waarde shr 5) and $1F) * 255 div 31) shl 8 or ((Waarde and $1F) * 255 div 31);
  else
    Result := Waarde and $FFFFFF;
  end;
end;

function TZMBitmap.Dichtstbij(RGB: LongWord): Integer;
var
  Sleutel, I, Afstand, BesteAfstand, R, G, B, VerschilR, VerschilG, VerschilB: Integer;
begin
  if NumColors <= 0 then Exit(0);
  Sleutel := ((RGB shr 9) and $7C00) or ((RGB shr 6) and $3E0) or ((RGB shr 3) and $1F);
  if (Length(FDichtbijCache) = 0) or (FDichtbijStempel <> KleurStempel) then
  begin
    SetLength(FDichtbijCache, 32768);
    FillChar(FDichtbijCache[0], 32768 * SizeOf(SmallInt), 0);
    FDichtbijStempel := KleurStempel;
  end;
  { exacte kleuren worden direct opgezocht (de cache geldt alleen per 5-bit cel) }
  for I := 0 to NumColors - 1 do
    if Kleuren[I] = RGB then Exit(I);
  if FDichtbijCache[Sleutel] > 0 then Exit(FDichtbijCache[Sleutel] - 1);
  R := (RGB shr 16) and $FF; G := (RGB shr 8) and $FF; B := RGB and $FF;
  BesteAfstand := MaxInt;
  Result := 0;
  for I := 0 to NumColors - 1 do
  begin
    VerschilR := R - Integer((Kleuren[I] shr 16) and $FF);
    VerschilG := G - Integer((Kleuren[I] shr 8) and $FF);
    VerschilB := B - Integer(Kleuren[I] and $FF);
    Afstand := VerschilR * VerschilR * 3 + VerschilG * VerschilG * 4 + VerschilB * VerschilB * 2;
    if Afstand < BesteAfstand then
    begin
      BesteAfstand := Afstand;
      Result := I;
    end;
  end;
  FDichtbijCache[Sleutel] := Result + 1;
end;

function TZMBitmap.RGBNaarNatief(RGB: LongWord): LongWord;
begin
  case BPP of
    1:
      if NumColors = 2 then Result := Dichtstbij(RGB)
      else if ((RGB shr 16) and $FF) + ((RGB shr 8) and $FF) + (RGB and $FF) >= 384 then Result := 1
      else Result := 0;
    4, 8: Result := Dichtstbij(RGB);
    16: Result := (((RGB shr 19) and $1F) shl 10) or (((RGB shr 11) and $1F) shl 5) or ((RGB shr 3) and $1F);
  else
    Result := RGB and $FFFFFF;
  end;
end;

function NieuweBitmapUitInfo(const Info: TBitmapInfo; Gebruik: UINT; Palet: TZMPalet): TZMBitmap;
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
            Result.Kleuren[I] := (peRed shl 16) or (peGreen shl 8) or peBlue
        else
          Result.Kleuren[I] := 0;
      end;
    end
    else
    begin
      Kwad := @Info.bmiColors[0];
      for I := 0 to Aantal - 1 do
        Result.Kleuren[I] := (Kwad[I].rgbRed shl 16) or (Kwad[I].rgbGreen shl 8) or Kwad[I].rgbBlue;
    end;
    for I := Aantal to Result.NumColors - 1 do Result.Kleuren[I] := 0;
    Result.KleurenGewijzigd;
  end;
end;

{ ---------------------------------------------------------------- rechthoeklijsten }

function RechtlijstKopie(const Rechthoeken: TZMRechtlijst): TZMRechtlijst;
begin
  Result := Copy(Rechthoeken, 0, Length(Rechthoeken));
end;

procedure VoegRechthoekToe(var Rechthoeken: TZMRechtlijst; const R: TRect); inline;
begin
  if (R.Right > R.Left) and (R.Bottom > R.Top) then
  begin
    SetLength(Rechthoeken, Length(Rechthoeken) + 1);
    Rechthoeken[High(Rechthoeken)] := R;
  end;
end;

function RechtlijstSnijdRechthoek(const Rechthoeken: TZMRechtlijst; const R: TRect): TZMRechtlijst;
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
    VoegRechthoekToe(Result, Tussen);
  end;
end;

function RechtlijstSnijd(const Rechthoeken, Andere: TZMRechtlijst): TZMRechtlijst;
var
  I, J: Integer;
  Tussen: TZMRechtlijst;
begin
  Result := nil;
  for J := 0 to High(Andere) do
  begin
    Tussen := RechtlijstSnijdRechthoek(Rechthoeken, Andere[J]);
    for I := 0 to High(Tussen) do VoegRechthoekToe(Result, Tussen[I]);
  end;
end;

function RechtlijstAftrekRechthoek(const Rechthoeken: TZMRechtlijst; const R: TRect): TZMRechtlijst;
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
      VoegRechthoekToe(Result, Deel);
      Continue;
    end;
    { bovenste strook }
    if R.Top > Deel.Top then VoegRechthoekToe(Result, Rect(Deel.Left, Deel.Top, Deel.Right, R.Top));
    { onderste strook }
    if R.Bottom < Deel.Bottom then VoegRechthoekToe(Result, Rect(Deel.Left, R.Bottom, Deel.Right, Deel.Bottom));
    { midden: linker- en rechterdeel }
    if R.Left > Deel.Left then
      VoegRechthoekToe(Result, Rect(Deel.Left, Max(Deel.Top, R.Top), R.Left, Min(Deel.Bottom, R.Bottom)));
    if R.Right < Deel.Right then
      VoegRechthoekToe(Result, Rect(R.Right, Max(Deel.Top, R.Top), Deel.Right, Min(Deel.Bottom, R.Bottom)));
  end;
end;

function RechtlijstAftrek(const Rechthoeken, Andere: TZMRechtlijst): TZMRechtlijst;
var
  J: Integer;
begin
  Result := RechtlijstKopie(Rechthoeken);
  for J := 0 to High(Andere) do
    Result := RechtlijstAftrekRechthoek(Result, Andere[J]);
end;

function RechtlijstVereniging(const Rechthoeken, Andere: TZMRechtlijst): TZMRechtlijst;
var
  I: Integer;
  Tussen: TZMRechtlijst;
begin
  Result := RechtlijstKopie(Rechthoeken);
  Tussen := RechtlijstAftrek(Andere, Rechthoeken);
  for I := 0 to High(Tussen) do VoegRechthoekToe(Result, Tussen[I]);
end;

function RechtlijstVerschuif(const Rechthoeken: TZMRechtlijst; VerschuifX, VerschuifY: Integer): TZMRechtlijst;
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

function RechtlijstOmhulling(const Rechthoeken: TZMRechtlijst): TRect;
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

function RechtlijstBevat(const Rechthoeken: TZMRechtlijst; X, Y: Integer): Boolean;
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
  St.Pen := TZMPen(StandaardObjecten[BLACK_PEN]);
  St.Brush := TZMKwast(StandaardObjecten[WHITE_BRUSH]);
  St.Font := TZMLetterObj(StandaardObjecten[SYSTEM_FONT]);
  St.Palette := TZMPalet(StandaardObjecten[DEFAULT_PALETTE]);
  St.BkColor := $FFFFFF;
  St.TekstKleurVoor := 0;
  St.BkMode := OPAQUE;
  St.ROP2 := R2_COPYPEN;
  St.StretchMode := BLACKONWHITE;
end;

destructor TZMDC.Destroy;
begin
  if (Target <> nil) and (Target.GeselecteerdIn = Self) then Target.GeselecteerdIn := nil;
  StandaardBitmap.Free;
  inherited Destroy;
end;

procedure TZMDC.SelecteerBitmap(Bitmap: TZMBitmap);
begin
  if (Target <> nil) and (Target.GeselecteerdIn = Self) then Target.GeselecteerdIn := nil;
  Target := Bitmap;
  if Bitmap <> nil then Bitmap.GeselecteerdIn := Self;
  MaakKnipOngeldig;
end;

procedure TZMDC.MaakKnipOngeldig;
begin
  FEffGeldig := False;
end;

function TZMDC.Effectief: TZMRechtlijst;
var
  Volledig: TZMRechtlijst;
begin
  if (Wnd <> 0) and (ZichtGeneratie <> ZMZichtGeneratie) and Assigned(ZMZichtLeverancier) then
  begin
    ZMZichtLeverancier(Self);
    ZichtGeneratie := ZMZichtGeneratie;
    FEffGeldig := False;
  end;
  if not FEffGeldig then
  begin
    SetLength(Volledig, 1);
    if Target <> nil then
      Volledig[0] := Rect(0, 0, Target.Width, Target.Height)
    else
      Volledig[0] := Rect(0, 0, 0, 0);
    if HeeftZichtbaar then Volledig := RechtlijstSnijd(Volledig, ZichtRegio);
    if HeeftTekenRegio then Volledig := RechtlijstSnijd(Volledig, TekenRegio);
    if St.HeeftKnip then
      Volledig := RechtlijstSnijd(Volledig, RechtlijstVerschuif(St.KnipRegio, ApparaatOorsprong.X, ApparaatOorsprong.Y));
    FEffectief := Volledig;
    FEffGeldig := True;
  end;
  Result := FEffectief;
end;

function TZMDC.OorsprongX: Integer; inline;
begin
  Result := ApparaatOorsprong.X + St.ViewportOorsprong.X - St.VensterOorsprong.X;
end;

function TZMDC.OorsprongY: Integer; inline;
begin
  Result := ApparaatOorsprong.Y + St.ViewportOorsprong.Y - St.VensterOorsprong.Y;
end;

function TZMDC.LPnaarT(X, Y: Integer): TPoint; inline;
begin
  Result.X := X + OorsprongX;
  Result.Y := Y + OorsprongY;
end;

function TZMDC.ColorToRGB(Kleur: COLORREF): LongWord;
var
  I: Integer;
begin
  if (Kleur and $FF000000) = $01000000 then
  begin
    I := Kleur and $FFFF;
    if (Target <> nil) and (Target.BPP <= 8) and (I < Target.NumColors) then
      Result := Target.Kleuren[I]
    else if (St.Palette <> nil) and (I < St.Palette.Count) then
      with St.Palette.Entries[I] do Result := (peRed shl 16) or (peGreen shl 8) or peBlue
    else
      Result := 0;
  end
  else
    Result := KleurRefNaarRGB(Kleur and $FFFFFF);
end;

function TZMDC.KleurNaarNatief(Kleur: COLORREF): LongWord;
begin
  if Target = nil then Exit(0);
  if ((Kleur and $FF000000) = $01000000) and (Target.BPP <= 8) then
    Result := (Kleur and $FFFF) and Target.NatiefMasker
  else
    Result := Target.RGBNaarNatief(ColorToRGB(Kleur));
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

function RopGebruiktBron(Code: Byte): Boolean; inline;
begin
  Result := ((Code shr 2) and $33) <> (Code and $33);
end;

function RopGebruiktDoel(Code: Byte): Boolean; inline;
begin
  Result := ((Code shr 1) and $55) <> (Code and $55);
end;

function RopGebruiktPatroon(Code: Byte): Boolean; inline;
begin
  Result := ((Code shr 4) and $0F) <> (Code and $0F);
end;

{ patroonwaarde van het kwast van de DC op een doelpixel (native) }
type
  TPatroonInfo = record
    Effen: Boolean;
    Value: LongWord;
    Patronen: array[0..7, 0..7] of LongWord;
  end;

procedure BereidPatroonVoor(DC: TZMDC; var Patroon: TPatroonInfo);
const
  HatchBits: array[0..5, 0..7] of Byte = (
    ($00, $00, $00, $00, $FF, $00, $00, $00),   { horizontaal }
    ($08, $08, $08, $08, $08, $08, $08, $08),   { verticaal }
    ($80, $40, $20, $10, $08, $04, $02, $01),   { schuin (/) }
    ($01, $02, $04, $08, $10, $20, $40, $80),   { schuin (\) }
    ($08, $08, $08, $08, $FF, $08, $08, $08),   { kruis }
    ($81, $42, $24, $18, $18, $24, $42, $81));  { diagonaal kruis }
var
  Kwast: TZMKwast;
  X, Y, Arcering: Integer;
  Voorgrond, Achtergrond: LongWord;
  Bitmap: TZMBitmap;
begin
  Kwast := DC.St.Brush;
  Patroon.Effen := True;
  Patroon.Value := 0;
  if Kwast = nil then Exit;
  case Kwast.Style of
    BS_SOLID: Patroon.Value := DC.KleurNaarNatief(Kwast.Color);
    BS_HATCHED:
      begin
        Patroon.Effen := False;
        Voorgrond := DC.KleurNaarNatief(Kwast.Color);
        Achtergrond := DC.KleurNaarNatief(DC.St.BkColor);
        Arcering := Kwast.Arceringsoort;
        if (Arcering < 0) or (Arcering > 5) then Arcering := 0;
        for Y := 0 to 7 do
          for X := 0 to 7 do
            if HatchBits[Arcering, Y] and ($80 shr X) <> 0 then Patroon.Patronen[Y, X] := Voorgrond else Patroon.Patronen[Y, X] := Achtergrond;
      end;
    BS_PATTERN, BS_DIBPATTERN:
      begin
        Bitmap := Kwast.Motief;
        if (Bitmap = nil) or (Bitmap.Width = 0) or (Bitmap.Height = 0) then Exit;
        Patroon.Effen := False;
        for Y := 0 to 7 do
          for X := 0 to 7 do
          begin
            if Bitmap.BPP = 1 then
            begin
              if Bitmap.LeesNatief(X mod Bitmap.Width, Y mod Bitmap.Height) = 0 then
                Patroon.Patronen[Y, X] := DC.KleurNaarNatief(DC.St.TekstKleurVoor)
              else
                Patroon.Patronen[Y, X] := DC.KleurNaarNatief(DC.St.BkColor);
            end
            else
              Patroon.Patronen[Y, X] := DC.Target.RGBNaarNatief(Bitmap.NatiefNaarRGB(Bitmap.LeesNatief(X mod Bitmap.Width, Y mod Bitmap.Height)));
          end;
      end;
  else
    Patroon.Value := DC.KleurNaarNatief(Kwast.Color);
  end;
end;

function PatroonOp(const Patroon: TPatroonInfo; DC: TZMDC; X, Y: Integer): LongWord; inline;
begin
  if Patroon.Effen then Result := Patroon.Value
  else Result := Patroon.Patronen[(Y - DC.St.KwastOorsprong.Y) and 7, (X - DC.St.KwastOorsprong.X) and 7];
end;

{ ---------------------------------------------------------------- blits }

procedure ZMLeesRij(Bitmap: TZMBitmap; Y, X, Aantal: Integer; Buffer: PLongWord);
var
  Rij: PByte;
  I: Integer;
begin
  Rij := Bitmap.RijPtr(Y);
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
    for I := 0 to Aantal - 1 do Buffer[I] := Bitmap.LeesNatief(X + I, Y);
  end;
end;

procedure ZMSchrijfRij(Bitmap: TZMBitmap; Y, X, Aantal: Integer; Buffer: PLongWord);
var
  Rij: PByte;
  I, Xpos: Integer;
  Masker: Byte;
begin
  if Aantal <= 0 then Exit;
  Rij := Bitmap.RijPtr(Y);
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
    for I := 0 to Aantal - 1 do Bitmap.ZetNatief(X + I, Y, Buffer[I]);
  end;
end;

type
  TOmzettingSoort = (ckIdentity, ckLUT, ckToMono, ckRGBToIndex, ckRGBToRGB, ckGeneric);

procedure GdiKopieerBitmap(DoelDC: TZMDC; X, Y, Breedte, Hoogte: Integer; BronBitmap: TZMBitmap; BronAchtergrond: COLORREF;
  BronPosX, BronPosY, BronBreedte, BronHoogte: Integer; Rop: DWORD; Uitrekken: Boolean);
var
  Code: Byte;
  GebruikBron, GebruikDoel, GebruikPatroon: Boolean;
  Doel: TZMBitmap;
  Knip: TZMRechtlijst;
  DoelR, KnipR: TRect;
  I, DoelXX, DoelYY, BronXX, BronYY, SpiegelX, SpiegelY: Integer;
  Omzetting: TOmzettingSoort;
  Tabel: array[0..255] of LongWord;
  BronAchtergrondNatief: LongWord;
  Masker: LongWord;
  Patroon: TPatroonInfo;
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
  GebruikBron := RopGebruiktBron(Code) and (BronBitmap <> nil) and (BronBitmap.Bits <> nil);
  GebruikDoel := RopGebruiktDoel(Code);
  GebruikPatroon := RopGebruiktPatroon(Code);
  if RopGebruiktBron(Code) and not GebruikBron then Exit;
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
  OfsX := DoelDC.OorsprongX;
  OfsY := DoelDC.OorsprongY;
  DoelR := Rect(X + OfsX, Y + OfsY, X + OfsX + Breedte, Y + OfsY + Hoogte);
  Knip := RechtlijstSnijdRechthoek(DoelDC.Effectief, DoelR);
  if Length(Knip) = 0 then Exit;
  Masker := Doel.NatiefMasker;
  if GebruikPatroon then BereidPatroonVoor(DoelDC, Patroon);

  { kleurconversie van bron naar doel }
  Omzetting := ckGeneric;
  BronAchtergrondNatief := 0;
  if GebruikBron then
  begin
    if BronBitmap.BPP = 1 then
    begin
      Omzetting := ckLUT;
      Tabel[0] := DoelDC.KleurNaarNatief(DoelDC.St.TekstKleurVoor);
      Tabel[1] := DoelDC.KleurNaarNatief(DoelDC.St.BkColor);
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
        BronAchtergrondNatief := BronBitmap.RGBNaarNatief(KleurRefNaarRGB(BronAchtergrond and $FFFFFF));
    end
    else if BronBitmap.BPP <= 8 then
    begin
      if (Doel.BPP = BronBitmap.BPP) and (Doel.NumColors = BronBitmap.NumColors) and
        CompareMem(@Doel.Kleuren[0], @BronBitmap.Kleuren[0], BronBitmap.NumColors * 4) then
        Omzetting := ckIdentity
      else
      begin
        Omzetting := ckLUT;
        for I := 0 to (1 shl BronBitmap.BPP) - 1 do
          Tabel[I] := Doel.RGBNaarNatief(BronBitmap.NatiefNaarRGB(I));
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
        BronRij := BronBitmap.RijPtr(BronYY);
        DoelRij := Doel.RijPtr(DoelYY);
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
            BronW := BronBitmap.LeesNatief(BronXX, BronYY);
            case Omzetting of
              ckLUT: Waarde := Tabel[BronW];
              ckToMono: if BronW = BronAchtergrondNatief then Waarde := 1 else Waarde := 0;
              ckRGBToIndex: Waarde := Doel.Dichtstbij(BronBitmap.NatiefNaarRGB(BronW));
              ckRGBToRGB: Waarde := BronW;
              ckIdentity: Waarde := BronW;
            else
              Waarde := Doel.RGBNaarNatief(BronBitmap.NatiefNaarRGB(BronW));
            end;
            Doel.ZetNatief(DoelXX, DoelYY, Waarde);
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
          ZMLeesRij(BronBitmap, BronYY, BronXX + XVan, XTot - XVan, @BronBuf[XVan]);
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
            if Geldig[K] then BronBuf[K] := BronBitmap.LeesNatief(BronXX, BronYY) else BronBuf[K] := 0;
          end;
        { kleurconversie }
        case Omzetting of
          ckLUT: for K := XVan to XTot - 1 do BronBuf[K] := Tabel[BronBuf[K] and $FF];
          ckToMono: for K := XVan to XTot - 1 do
              if BronBuf[K] = BronAchtergrondNatief then BronBuf[K] := 1 else BronBuf[K] := 0;
          ckRGBToIndex: for K := XVan to XTot - 1 do BronBuf[K] := Doel.Dichtstbij(BronBitmap.NatiefNaarRGB(BronBuf[K]));
          ckRGBToRGB, ckIdentity: ;
        else
          for K := XVan to XTot - 1 do BronBuf[K] := Doel.RGBNaarNatief(BronBitmap.NatiefNaarRGB(BronBuf[K]));
        end;
      end
      else
        for K := 0 to Aantal - 1 do Geldig[K] := True;
      if GebruikDoel or not ((BronBreedte = DoelBreedte) and (SpiegelX = 0)) or not GebruikBron then
        ZMLeesRij(Doel, DoelYY, KnipR.Left, Aantal, @DoelBuf[0]);
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
            if GebruikPatroon then Patwaarde := PatroonOp(Patroon, DoelDC, KnipR.Left + K, DoelYY) else Patwaarde := 0;
            DoelBuf[K] := Rop3(Code, Patwaarde, BronBuf[K], DoelBuf[K]) and Masker;
          end;
      end;
      ZMSchrijfRij(Doel, DoelYY, KnipR.Left + XVan, XTot - XVan, @DoelBuf[XVan]);
    end;
  end;
  Doel.Vuil := True;
end;

procedure GdiKopieer(DoelDC: TZMDC; X, Y, Breedte, Hoogte: Integer; BronDC: TZMDC; BronPosX, BronPosY, BronBreedte, BronHoogte: Integer;
  Rop: DWORD; Uitrekken: Boolean);
var
  BronBitmap: TZMBitmap;
  BronOfsX, BronOfsY: Integer;
begin
  if DoelDC = nil then Exit;
  if BronDC <> nil then
  begin
    BronBitmap := BronDC.Target;
    BronOfsX := BronDC.OorsprongX;
    BronOfsY := BronDC.OorsprongY;
    GdiKopieerBitmap(DoelDC, X, Y, Breedte, Hoogte, BronBitmap, BronDC.St.BkColor, BronPosX + BronOfsX, BronPosY + BronOfsY, BronBreedte, BronHoogte, Rop, Uitrekken);
  end
  else
    GdiKopieerBitmap(DoelDC, X, Y, Breedte, Hoogte, nil, 0, 0, 0, 0, 0, Rop, Uitrekken);
end;

procedure GdiPatKopieer(DC: TZMDC; X, Y, Breedte, Hoogte: Integer; Rop: DWORD);
begin
  GdiKopieerBitmap(DC, X, Y, Breedte, Hoogte, nil, 0, 0, 0, 0, 0, Rop and $00FF0000, False);
end;

{ vul een rechthoek (target-coördinaten) met een effen native waarde, geknipt }
procedure VulNatief(DC: TZMDC; R: TRect; Waarde: LongWord);
var
  Knip: TZMRechtlijst;
  I, X, Y: Integer;
  Doel: TZMBitmap;
  Rij: PLongWord;
  KnipR: TRect;
begin
  Doel := DC.Target;
  if (Doel = nil) or (Doel.Bits = nil) then Exit;
  Knip := RechtlijstSnijdRechthoek(DC.Effectief, R);
  for I := 0 to High(Knip) do
  begin
    KnipR := Knip[I];
    for Y := KnipR.Top to KnipR.Bottom - 1 do
      case Doel.BPP of
        32:
          begin
            Rij := PLongWord(Doel.RijPtr(Y)) + KnipR.Left;
            for X := KnipR.Left to KnipR.Right - 1 do
            begin
              Rij^ := Waarde;
              Inc(Rij);
            end;
          end;
        8: FillChar(Doel.RijPtr(Y)[KnipR.Left], KnipR.Right - KnipR.Left, Byte(Waarde));
      else
        for X := KnipR.Left to KnipR.Right - 1 do Doel.ZetNatief(X, Y, Waarde);
      end;
  end;
  Doel.Vuil := True;
end;

procedure GdiVulRechthoek(DC: TZMDC; const R: TRect; Kwast: TZMKwast);
var
  Oud: TZMKwast;
begin
  if (Kwast = nil) or (Kwast.Style = BS_NULL) then Exit;
  Oud := DC.St.Brush;
  DC.St.Brush := Kwast;
  try
    GdiPatKopieer(DC, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top, PATCOPY);
  finally
    DC.St.Brush := Oud;
  end;
end;

procedure GdiVulEffen(DC: TZMDC; const R: TRect; Kleur: COLORREF);
var
  OfsX, OfsY: Integer;
begin
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then Exit;
  OfsX := DC.OorsprongX; OfsY := DC.OorsprongY;
  VulNatief(DC, Rect(R.Left + OfsX, R.Top + OfsY, R.Right + OfsX, R.Bottom + OfsY), DC.KleurNaarNatief(Kleur));
end;

procedure GdiInverteerRechthoek(DC: TZMDC; const R: TRect);
begin
  GdiPatKopieer(DC, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top, DSTINVERT);
end;

{ ---------------------------------------------------------------- pixels en lijnen }

procedure TekenPixelNatief(DC: TZMDC; X, Y: Integer; Waarde: LongWord; Modus: Integer); inline;
var
  Doel: TZMBitmap;
  Doelwaarde: LongWord;
begin
  Doel := DC.Target;
  if (X < 0) or (Y < 0) or (X >= Doel.Width) or (Y >= Doel.Height) then Exit;
  if not RechtlijstBevat(DC.Effectief, X, Y) then Exit;
  if Modus = R2_COPYPEN then
    Doel.ZetNatief(X, Y, Waarde)
  else
  begin
    Doelwaarde := Doel.LeesNatief(X, Y);
    case Modus of
      R2_BLACK: Doelwaarde := 0;
      R2_WHITE: Doelwaarde := Doel.RGBNaarNatief($FFFFFF);
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
    Doel.ZetNatief(X, Y, Doelwaarde and Doel.NatiefMasker);
  end;
  Doel.Vuil := True;
end;

procedure GdiZetPixel(DC: TZMDC; X, Y: Integer; Kleur: COLORREF);
begin
  if DC.Target = nil then Exit;
  TekenPixelNatief(DC, X + DC.OorsprongX, Y + DC.OorsprongY, DC.KleurNaarNatief(Kleur), R2_COPYPEN);
end;

function GdiLeesPixel(DC: TZMDC; X, Y: Integer): COLORREF;
var
  Doel: TZMBitmap;
begin
  Doel := DC.Target;
  Result := CLR_INVALID;
  if Doel = nil then Exit;
  Inc(X, DC.OorsprongX); Inc(Y, DC.OorsprongY);
  if (X < 0) or (Y < 0) or (X >= Doel.Width) or (Y >= Doel.Height) then Exit;
  Result := RGBNaarKleurRef(Doel.NatiefNaarRGB(Doel.LeesNatief(X, Y)));
end;

procedure PenTekenen(DC: TZMDC; X, Y: Integer; Waarde: LongWord; PenBreedte: Integer);
var
  I, J, Helft: Integer;
begin
  if PenBreedte <= 1 then
    TekenPixelNatief(DC, X, Y, Waarde, DC.St.ROP2)
  else
  begin
    Helft := PenBreedte div 2;
    for J := Y - Helft to Y - Helft + PenBreedte - 1 do
      for I := X - Helft to X - Helft + PenBreedte - 1 do
        TekenPixelNatief(DC, I, J, Waarde, DC.St.ROP2);
  end;
end;

procedure LijnNatief(DC: TZMDC; X1, Y1, X2, Y2: Integer; Waarde: LongWord; PenBreedte: Integer;
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
      if LaatstePixel then PenTekenen(DC, X1, Y1, Waarde, PenBreedte);
      Break;
    end;
    case Stijl of
      PS_DOT: Tekenen := (Teller mod 2) = 0;
      PS_DASH: Tekenen := (Teller mod 9) < 6;
      PS_DASHDOT: Tekenen := ((Teller mod 12) < 6) or ((Teller mod 12) in [8, 9]);
    else
      Tekenen := True;
    end;
    if Tekenen then PenTekenen(DC, X1, Y1, Waarde, PenBreedte);
    Inc(Teller);
    Dubbelfout := 2 * Fout;
    if Dubbelfout >= AfstY then begin Inc(Fout, AfstY); Inc(X1, StapX); end;
    if Dubbelfout <= AfstX then begin Inc(Fout, AfstX); Inc(Y1, StapY); end;
  end;
end;

procedure GdiLijn(DC: TZMDC; X1, Y1, X2, Y2: Integer; LaatstePixel: Boolean);
var
  Pen: TZMPen;
begin
  Pen := DC.St.Pen;
  if (Pen = nil) or (Pen.Style = PS_NULL) or (DC.Target = nil) then Exit;
  LijnNatief(DC, X1 + DC.OorsprongX, Y1 + DC.OorsprongY, X2 + DC.OorsprongX, Y2 + DC.OorsprongY,
    DC.KleurNaarNatief(Pen.Color), Pen.Width, Pen.Style, LaatstePixel);
end;

procedure GdiRechthoek(DC: TZMDC; X1, Y1, X2, Y2: Integer);
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
      GdiPatKopieer(DC, X1 + 1, Y1 + 1, X2 - X1 - 2, Y2 - Y1 - 2, PATCOPY)
    else
      GdiPatKopieer(DC, X1, Y1, X2 - X1 - 1, Y2 - Y1 - 1, PATCOPY);
  end;
  if (Pen <> nil) and (Pen.Style <> PS_NULL) then
  begin
    GdiLijn(DC, X1, Y1, X2 - 1, Y1, False);
    GdiLijn(DC, X2 - 1, Y1, X2 - 1, Y2 - 1, False);
    GdiLijn(DC, X2 - 1, Y2 - 1, X1, Y2 - 1, False);
    GdiLijn(DC, X1, Y2 - 1, X1, Y1, False);
  end;
end;

{ scanlijn-polygonvulling (alternatieve regel), target-coördinaten }
procedure VulVeelhoekNatief(DC: TZMDC; const Punten: array of TPoint);
var
  LaagsteY, HoogsteY, Y, I, J, Aantal, Snijpunten, Tussen: Integer;
  XSnij: array of Integer;
  Patroon: TPatroonInfo;
  X, XVan, XTot: Integer;
  YMidden, X1, Y1, X2, Y2: Double;
begin
  Aantal := Length(Punten);
  if Aantal < 3 then Exit;
  BereidPatroonVoor(DC, Patroon);
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
        TekenPixelNatief(DC, X, Y, PatroonOp(Patroon, DC, X, Y), R2_COPYPEN);
      Inc(I, 2);
    end;
  end;
end;

procedure GdiVeelhoek(DC: TZMDC; const Punten: array of TPoint; Vullen: Boolean);
var
  Omgezet: array of TPoint;
  I, Aantal: Integer;
begin
  Aantal := Length(Punten);
  if (Aantal < 2) or (DC.Target = nil) then Exit;
  SetLength(Omgezet, Aantal);
  for I := 0 to Aantal - 1 do Omgezet[I] := DC.LPnaarT(Punten[I].X, Punten[I].Y);
  if Vullen and (DC.St.Brush <> nil) and (DC.St.Brush.Style <> BS_NULL) then
    VulVeelhoekNatief(DC, Omgezet);
  if (DC.St.Pen <> nil) and (DC.St.Pen.Style <> PS_NULL) then
    for I := 0 to Aantal - 1 do
      LijnNatief(DC, Omgezet[I].X, Omgezet[I].Y, Omgezet[(I + 1) mod Aantal].X, Omgezet[(I + 1) mod Aantal].Y,
        DC.KleurNaarNatief(DC.St.Pen.Color), DC.St.Pen.Width, DC.St.Pen.Style, False);
end;

procedure GdiPolylijn(DC: TZMDC; const Punten: array of TPoint);
var
  I: Integer;
begin
  for I := 0 to High(Punten) - 1 do
    GdiLijn(DC, Punten[I].X, Punten[I].Y, Punten[I + 1].X, Punten[I + 1].Y, False);
end;

procedure EllipsPunten(X1, Y1, X2, Y2: Integer; var Punten: TZMRechtlijst);
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

procedure GdiEllips(DC: TZMDC; X1, Y1, X2, Y2: Integer);
var
  Rijen: TZMRechtlijst;
  I, X: Integer;
  Patroon: TPatroonInfo;
  OfsX, OfsY: Integer;
  Waarde: LongWord;
  PenBreedte: Integer;
  Vorige: TRect;
begin
  if DC.Target = nil then Exit;
  OfsX := DC.OorsprongX; OfsY := DC.OorsprongY;
  EllipsPunten(X1 + OfsX, Y1 + OfsY, X2 + OfsX, Y2 + OfsY, Rijen);
  if (DC.St.Brush <> nil) and (DC.St.Brush.Style <> BS_NULL) then
  begin
    BereidPatroonVoor(DC, Patroon);
    for I := 0 to High(Rijen) do
      for X := Rijen[I].Left to Rijen[I].Right - 1 do
        TekenPixelNatief(DC, X, Rijen[I].Top, PatroonOp(Patroon, DC, X, Rijen[I].Top), R2_COPYPEN);
  end;
  if (DC.St.Pen <> nil) and (DC.St.Pen.Style <> PS_NULL) and (Length(Rijen) > 0) then
  begin
    Waarde := DC.KleurNaarNatief(DC.St.Pen.Color);
    PenBreedte := DC.St.Pen.Width;
    for I := 0 to High(Rijen) do
    begin
      if I = 0 then Vorige := Rijen[I] else Vorige := Rijen[I - 1];
      { linker- en rechterrand, verbonden met de vorige rij }
      for X := Min(Rijen[I].Left, Vorige.Left) to Max(Rijen[I].Left, Vorige.Left) do
        PenTekenen(DC, X, Rijen[I].Top, Waarde, PenBreedte);
      for X := Min(Rijen[I].Right, Vorige.Right) - 1 to Max(Rijen[I].Right, Vorige.Right) - 1 do
        PenTekenen(DC, X, Rijen[I].Top, Waarde, PenBreedte);
    end;
    for X := Rijen[0].Left to Rijen[0].Right - 1 do PenTekenen(DC, X, Rijen[0].Top, Waarde, PenBreedte);
    I := High(Rijen);
    for X := Rijen[I].Left to Rijen[I].Right - 1 do PenTekenen(DC, X, Rijen[I].Top, Waarde, PenBreedte);
  end;
end;

procedure GdiAfrondRechthoek(DC: TZMDC; X1, Y1, X2, Y2, RondBreedte, RondHoogte: Integer);
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
    GdiRechthoek(DC, X1, Y1, X2, Y2);
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
  GdiVeelhoek(DC, Punten, True);
end;

procedure GdiFocusRechthoek(DC: TZMDC; const R: TRect);
var
  X, Y, OfsX, OfsY: Integer;
  Doel: TZMBitmap;
  procedure Inverteer(PX, PY: Integer);
  begin
    if (PX < 0) or (PY < 0) or (PX >= Doel.Width) or (PY >= Doel.Height) then Exit;
    if not RechtlijstBevat(DC.Effectief, PX, PY) then Exit;
    Doel.ZetNatief(PX, PY, (not Doel.LeesNatief(PX, PY)) and Doel.NatiefMasker);
  end;
begin
  Doel := DC.Target;
  if Doel = nil then Exit;
  OfsX := DC.OorsprongX; OfsY := DC.OorsprongY;
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
  Doel.Vuil := True;
end;

procedure GdiVulGebied(DC: TZMDC; X, Y: Integer; Kleur: COLORREF; Oppervlak: Boolean);
var
  Doel: TZMBitmap;
  Referentie, Waarde: LongWord;
  Stapel: array of TPoint;
  Stapelpos: Integer;
  Punt: TPoint;
  Patroon: TPatroonInfo;
  Bezocht: array of Boolean;
  function Overeenkomt(PX, PY: Integer): Boolean;
  var Natief: LongWord;
  begin
    Natief := Doel.LeesNatief(PX, PY);
    if Oppervlak then Result := Natief = Referentie else Result := Natief <> Referentie;
  end;
  procedure Duw(PX, PY: Integer);
  begin
    if (PX < 0) or (PY < 0) or (PX >= Doel.Width) or (PY >= Doel.Height) then Exit;
    if Bezocht[PY * Doel.Width + PX] then Exit;
    if not RechtlijstBevat(DC.Effectief, PX, PY) then Exit;
    if not Overeenkomt(PX, PY) then Exit;
    Bezocht[PY * Doel.Width + PX] := True;
    if Stapelpos >= Length(Stapel) then SetLength(Stapel, Length(Stapel) * 2 + 64);
    Stapel[Stapelpos] := Point(PX, PY);
    Inc(Stapelpos);
  end;
begin
  Doel := DC.Target;
  if Doel = nil then Exit;
  Inc(X, DC.OorsprongX); Inc(Y, DC.OorsprongY);
  Referentie := DC.KleurNaarNatief(Kleur);
  BereidPatroonVoor(DC, Patroon);
  SetLength(Bezocht, Doel.Width * Doel.Height);
  Stapelpos := 0;
  Duw(X, Y);
  while Stapelpos > 0 do
  begin
    Dec(Stapelpos);
    Punt := Stapel[Stapelpos];
    Waarde := PatroonOp(Patroon, DC, Punt.X, Punt.Y);
    Doel.ZetNatief(Punt.X, Punt.Y, Waarde);
    Duw(Punt.X + 1, Punt.Y); Duw(Punt.X - 1, Punt.Y); Duw(Punt.X, Punt.Y + 1); Duw(Punt.X, Punt.Y - 1);
  end;
  Doel.Vuil := True;
end;

{ ---------------------------------------------------------------- tekst }

function GdiGezicht(DC: TZMDC): PZMGezicht;
begin
  if (DC.St.Font <> nil) and (DC.St.Font.Lettergezicht <> nil) then
    Result := DC.St.Font.Lettergezicht
  else
    Result := TZMLetterObj(StandaardObjecten[SYSTEM_FONT]).Lettergezicht;
end;

{ Net als de DIB-engine van Wine: TrueType-lettertypen worden anti-aliased (GGO_GRAY4) op DIB's
  met meer dan 8 bpp; bitmaplettertypen (MS Sans Serif, System, ...) en doelen met <= 8 bpp
  krijgen 1-bit glyphs. De voortgangsbreedtes van de glyphs verschillen tussen beide. }
function IsBitmapLetterNaam(const Naam: string): Boolean;
var
  Genormeerd: string;
begin
  Genormeerd := LowerCase(Trim(Naam));
  Result := (Genormeerd = 'ms sans serif') or (Genormeerd = 'ms serif') or (Genormeerd = 'system') or (Genormeerd = 'fixedsys') or
    (Genormeerd = 'terminal') or (Genormeerd = 'small fonts') or (Genormeerd = 'courier') or (Genormeerd = 'modern') or
    (Genormeerd = 'roman') or (Genormeerd = 'script') or (Genormeerd = '');
end;

function GdiGebruikAA(DC: TZMDC): Boolean;
var
  Lettertype: TZMLetterObj;
begin
  Result := False;
  { anti-aliasing vereist een doel met > 8 bpp en een grootte die de gasp-tabel van het lettertype
    markeert voor grijstinten-weergave (zoals Windows/Wine doet) }
  if (DC.Target = nil) or (DC.Target.BPP <= 8) then Exit;
  Lettertype := DC.St.Font;
  if (Lettertype = nil) or (Lettertype.LF.lfQuality = NONANTIALIASED_QUALITY) then Exit;
  if Lettertype.BitmapLetter < 0 then
    if IsBitmapLetterNaam(StrPas(Lettertype.LF.lfFaceName)) then Lettertype.BitmapLetter := 1 else Lettertype.BitmapLetter := 0;
  {$IFDEF CPUWASM32}
  { De browser vergroot het framebuffer vaak met een niet-gehele factor. Gebruik
    ook bij kleine TrueType-letters de grijze glyphs: mono-randen worden anders
    ongelijk dik en lastig leesbaar. De tekstmetingen gebruiken deze advances al. }
  Result := (Lettertype.BitmapLetter = 0) and not ZMGeenAntialias;
  {$ELSE}
  Result := (Lettertype.BitmapLetter = 0) and not ZMGeenAntialias and GdiGezicht(DC)^.Grijstint;
  {$ENDIF}
end;

function GdiGlyfen(DC: TZMDC): PZMTekenbeelden;
begin
  if GdiGebruikAA(DC) then Result := @GdiGezicht(DC)^.AATekenbeelden else Result := @GdiGezicht(DC)^.Tekenbeelden;
end;

{ Tekstafmetingen gebruiken de normaal gehinte voortgangsbreedtes van TrueType-lettertypen, ook waar de
  glyphs 1-bit getekend worden met de (smallere of bredere) mono-voortgangsbreedtes: Wine meet
  met GGO_METRICS (FT_LOAD_DEFAULT) en tekent met FT_LOAD_TARGET_MONO. }
function GdiOmvangGlyfen(DC: TZMDC): PZMTekenbeelden;
var
  Lettertype: TZMLetterObj;
begin
  Lettertype := DC.St.Font;
  if Lettertype <> nil then
  begin
    if Lettertype.BitmapLetter < 0 then
      if IsBitmapLetterNaam(StrPas(Lettertype.LF.lfFaceName)) then Lettertype.BitmapLetter := 1 else Lettertype.BitmapLetter := 0;
    if (Lettertype.BitmapLetter = 0) and not ZMGeenAntialias then Exit(@GdiGezicht(DC)^.AATekenbeelden);
  end;
  Result := @GdiGezicht(DC)^.Tekenbeelden;
end;

function GdiTekstBreedte(DC: TZMDC; Tekst: PAnsiChar; Aantal: Integer): Integer;
var
  I: Integer;
  Glyfen: PZMTekenbeelden;
begin
  Result := 0;
  if Tekst = nil then Exit;
  Glyfen := GdiOmvangGlyfen(DC);
  for I := 0 to Aantal - 1 do
    Inc(Result, Glyfen^[Byte(Tekst[I])].Voortgang + DC.St.CharExtra);
end;

{ Wine dibdrv: anti-aliased glyph-pixels mengen met een gammaverloop }
const
  AAVerloop: array[0..16] of Byte = (0, $4d, $68, $7c, $8c, $9a, $a7, $b2, $bd, $c7, $d0, $d9,
    $e1, $e9, $f0, $f8, $ff);

function AACombineer(Doelkleur, Tekstkleur, Niveau: Integer): Integer; inline;
var
  MinKleur, MaxKleur: Integer;
begin
  MinKleur := (AAVerloop[Niveau] * Tekstkleur) div $FF;
  MaxKleur := AAVerloop[16 - Niveau] + (($FF - AAVerloop[16 - Niveau]) * Tekstkleur) div $FF;
  if Doelkleur = Tekstkleur then Result := Doelkleur
  else if Doelkleur > Tekstkleur then Result := Tekstkleur + ((Doelkleur - Tekstkleur) * (MaxKleur - Tekstkleur)) div ($FF - Tekstkleur)
  else Result := Tekstkleur - ((Tekstkleur - Doelkleur) * (Tekstkleur - MinKleur)) div Tekstkleur;
end;

procedure TekenGlyfAA(DC: TZMDC; const Glyf: TZMTekenbeeld; X, Y: Integer; RGB: LongWord; const Knip: TZMRechtlijst);
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
  GlyfR := Rect(X + Glyf.XVerschuiving, Y + Glyf.YVerschuiving, X + Glyf.XVerschuiving + Glyf.W, Y + Glyf.YVerschuiving + Glyf.H);
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
          Doel.ZetNatief(PX, PY, Doel.RGBNaarNatief(RGB))
        else
        begin
          Doelwaarde := Doel.NatiefNaarRGB(Doel.LeesNatief(PX, PY));
          Doelwaarde := (LongWord(AACombineer((Doelwaarde shr 16) and $FF, TekstR, Dekking)) shl 16) or
            (LongWord(AACombineer((Doelwaarde shr 8) and $FF, TekstG, Dekking)) shl 8) or LongWord(AACombineer(Doelwaarde and $FF, TekstB, Dekking));
          Doel.ZetNatief(PX, PY, Doel.RGBNaarNatief(Doelwaarde));
        end;
      end;
    end;
  end;
end;

procedure TekenGlyf(DC: TZMDC; const Glyf: TZMTekenbeeld; X, Y: Integer; Waarde: LongWord; const Knip: TZMRechtlijst);
var
  I, GlyfRij, GlyfKol, Rijlengte, PX, PY: Integer;
  GlyfR, KnipR: TRect;
  Rij: PByte;
  Doel: TZMBitmap;
begin
  if (Glyf.W <= 0) or (Glyf.H <= 0) or (Glyf.Data = nil) then Exit;
  Doel := DC.Target;
  Rijlengte := (Glyf.W + 7) div 8;
  GlyfR := Rect(X + Glyf.XVerschuiving, Y + Glyf.YVerschuiving, X + Glyf.XVerschuiving + Glyf.W, Y + Glyf.YVerschuiving + Glyf.H);
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
          Doel.ZetNatief(PX, PY, Waarde);
      end;
    end;
  end;
end;

procedure GdiTekstUit(DC: TZMDC; X, Y: Integer; Tekst: PAnsiChar; Aantal: Integer;
  MetVulling: Boolean; KnipR: PRect; VulR: PRect);
var
  Gezicht: PZMGezicht;
  Breedte, I, TekstX, TekstY, OfsX, OfsY: Integer;
  Knip: TZMRechtlijst;
  Waarde: LongWord;
  Achtergrond: TRect;
  Uitlijning: UINT;
  Letterdef: TLogFont;
  Glyfen: PZMTekenbeelden;
  Antialias: Boolean;
begin
  if (DC.Target = nil) or (DC.Target.Bits = nil) then Exit;
  Gezicht := GdiGezicht(DC);
  Glyfen := GdiGlyfen(DC);
  Antialias := GdiGebruikAA(DC);
  Breedte := GdiTekstBreedte(DC, Tekst, Aantal);
  Uitlijning := DC.St.TekstUitlijning;
  if Uitlijning and TA_UPDATECP <> 0 then
  begin
    X := DC.St.HuidigePositie.X;
    Y := DC.St.HuidigePositie.Y;
  end;
  case Uitlijning and (TA_CENTER) of
    TA_RIGHT: Dec(X, Breedte);
    TA_CENTER: Dec(X, Breedte div 2);
  end;
  if Uitlijning and TA_BASELINE = TA_BASELINE then Dec(Y, Gezicht^.Opstijging)
  else if Uitlijning and TA_BOTTOM <> 0 then Dec(Y, Gezicht^.Height);
  if Uitlijning and TA_UPDATECP <> 0 then
    DC.St.HuidigePositie.X := X + Breedte;
  OfsX := DC.OorsprongX; OfsY := DC.OorsprongY;
  Knip := DC.Effectief;
  if KnipR <> nil then
    Knip := RechtlijstSnijdRechthoek(Knip, Rect(KnipR^.Left + OfsX, KnipR^.Top + OfsY, KnipR^.Right + OfsX, KnipR^.Bottom + OfsY));
  if VulR <> nil then
    VulNatief(DC, Rect(VulR^.Left + OfsX, VulR^.Top + OfsY, VulR^.Right + OfsX, VulR^.Bottom + OfsY),
      DC.KleurNaarNatief(DC.St.BkColor));
  if MetVulling and (DC.St.BkMode = OPAQUE) then
  begin
    Achtergrond := Rect(X + OfsX, Y + OfsY, X + OfsX + Breedte, Y + OfsY + Gezicht^.Height);
    if KnipR <> nil then
      IntersectRect(Achtergrond, Achtergrond, Rect(KnipR^.Left + OfsX, KnipR^.Top + OfsY, KnipR^.Right + OfsX, KnipR^.Bottom + OfsY));
    VulNatief(DC, Achtergrond, DC.KleurNaarNatief(DC.St.BkColor));
  end;
  Waarde := DC.KleurNaarNatief(DC.St.TekstKleurVoor);
  TekstX := X + OfsX;
  TekstY := Y + OfsY;
  for I := 0 to Aantal - 1 do
  begin
    if Antialias then
      TekenGlyfAA(DC, Glyfen^[Byte(Tekst[I])], TekstX, TekstY, DC.ColorToRGB(DC.St.TekstKleurVoor), Knip)
    else
      TekenGlyf(DC, Glyfen^[Byte(Tekst[I])], TekstX, TekstY, Waarde, Knip);
    Inc(TekstX, Glyfen^[Byte(Tekst[I])].Voortgang + DC.St.CharExtra);
  end;
  if DC.St.Font <> nil then
  begin
    Letterdef := DC.St.Font.LF;
    if Letterdef.lfUnderline <> 0 then
      VulNatief(DC, RechtlijstOmhulling(RechtlijstSnijdRechthoek(Knip,
        Rect(X + OfsX, Y + OfsY + Gezicht^.Opstijging + 1, X + OfsX + Breedte, Y + OfsY + Gezicht^.Opstijging + 2))), Waarde);
    if Letterdef.lfStrikeOut <> 0 then
      VulNatief(DC, RechtlijstOmhulling(RechtlijstSnijdRechthoek(Knip,
        Rect(X + OfsX, Y + OfsY + Gezicht^.Opstijging * 2 div 3, X + OfsX + Breedte, Y + OfsY + Gezicht^.Opstijging * 2 div 3 + 1))), Waarde);
  end;
  DC.Target.Vuil := True;
end;

function GdiTekenTekst(DC: TZMDC; Tekst: PAnsiChar; Aantal: Integer; var R: TRect; Opmaak: UINT): Integer;
type
  TLine = record Start, Len: Integer; end;
var
  Gezicht: PZMGezicht;
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
    Result := GdiOmvangGlyfen(DC)^[Byte(Invoer[Index])].Voortgang + DC.St.CharExtra;
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
  Gezicht := GdiGezicht(DC);
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
      Breedte := GdiTekstBreedte(DC, PAnsiChar(Regeltekst), Length(Regeltekst));
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
    Breedte := GdiTekstBreedte(DC, PAnsiChar(Regeltekst), Length(Regeltekst));
    if Opmaak and DT_CENTER <> 0 then X := R.Left + (R.Right - R.Left - Breedte) div 2
    else if Opmaak and DT_RIGHT <> 0 then X := R.Right - Breedte
    else X := R.Left;
    if Opmaak and DT_NOCLIP <> 0 then
      GdiTekstUit(DC, X, Y, PAnsiChar(Regeltekst), Length(Regeltekst), True, nil, nil)
    else
      GdiTekstUit(DC, X, Y, PAnsiChar(Regeltekst), Length(Regeltekst), True, @R, nil);
    if Onderlijn > 0 then
    begin
      Positie := X + GdiTekstBreedte(DC, PAnsiChar(Regeltekst), Onderlijn - 1);
      GdiVulEffen(DC, Rect(Positie, Y + Gezicht^.Opstijging + 1, Positie + GdiOmvangGlyfen(DC)^[Byte(Regeltekst[Onderlijn])].Voortgang,
        Y + Gezicht^.Opstijging + 2), DC.St.TekstKleurVoor);
    end;
    Inc(Y, RegelHoogte);
  end;
  Result := TotaleHoogte;
end;

{ ---------------------------------------------------------------- standaardobjecten }

procedure InitStandaardObjecten;
const
  Sys: array[0..28] of COLORREF = (
    $C8D0D4, $808000, $800000, $808080, $C0C0C0, $FFFFFF, $000000, $000000, $000000,
    $FFFFFF, $C0C0C0, $C0C0C0, $808080, $800000, $FFFFFF, $C0C0C0, $808080, $808080,
    $000000, $C0C0C0, $FFFFFF, $000000, $DFDFDF, $000000, $E1FFFF, $B5B5B5, $800000,
    $D08410, $C0C0C0);
var
  Kwast: TZMKwast;
  Pen: TZMPen;
  Letterdef: TLogFont;
  Palet: TZMPalet;
  I: Integer;
  procedure ZetStock(Nr: Integer; Ding: TZMGdiObj);
  begin
    Ding.IsVoorraadObject := True;
    StandaardObjecten[Nr] := Ding;
  end;
  function MaakKwast(Stijl: UINT; Kleur: COLORREF): TZMKwast;
  begin
    Result := TZMKwast.Create;
    Result.Style := Stijl;
    Result.Color := Kleur;
  end;
  function MaakPen(Stijl: UINT; Kleur: COLORREF): TZMPen;
  begin
    Result := TZMPen.Create;
    Result.Style := Stijl;
    Result.Color := Kleur;
  end;
  function MaakLetter(Hoogte, Gewicht: Integer; const Naam: AnsiString; Lettersoort: Byte): TZMLetterObj;
  begin
    FillChar(Letterdef, SizeOf(Letterdef), 0);
    Letterdef.lfHeight := Hoogte;
    Letterdef.lfWeight := Gewicht;
    Letterdef.lfPitchAndFamily := Lettersoort;
    StrPLCopy(Letterdef.lfFaceName, Naam, 31);
    Result := TZMLetterObj.Create(Letterdef);
  end;
begin
  if StandaardObjecten[0] <> nil then Exit;
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
  Palet := TZMPalet.Create;
  Palet.Count := 20;
  begin
    { de 20 vaste systeemkleuren }
    HalftoneIngangen(Palet.Entries);
    for I := 0 to 9 do Palet.Entries[10 + I] := Palet.Entries[246 + I];
  end;
  ZetStock(DEFAULT_PALETTE, Palet);
  ZetStock(SYSTEM_FIXED_FONT, MaakLetter(-12, 400, 'Courier New', FIXED_PITCH));
  ZetStock(DEFAULT_GUI_FONT, MaakLetter(-11, 400, 'MS Sans Serif', VARIABLE_PITCH));
  for I := 0 to High(SysteemKleuren) do
  begin
    if I <= High(Sys) then SysteemKleuren[I] := Sys[I] else SysteemKleuren[I] := 0;
    Kwast := MaakKwast(BS_SOLID, SysteemKleuren[I]);
    Kwast.IsVoorraadObject := True;
    SysteemKleurKwasten[I] := Kwast;
  end;
  Pen := nil;
  if Pen = nil then ;
end;

initialization
  ZMGeenAntialias := GetEnvironmentVariable('ZM_NO_AA') = '1';
  InitStandaardObjecten;
end.

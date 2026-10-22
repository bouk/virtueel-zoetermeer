unit ZMFonts;

{ Bitmaplettertypen voor de software-GDI.

  De glyphgegevens worden gegenereerd door tools/gen-fonts.py uit vrije lettertypen in nixpkgs
  (Liberation Sans/Serif/Mono) naar fonts/zmfontdata.inc. Elk lettertype is een
  familie/gewicht/cursief op één pixelgrootte; glyphs zijn 1 bit per pixel
  (Windows 9x maakte kleine tekst ook niet anti-aliased). Tekens zijn
  Windows-1252-codepunten 0..255. }

{$MODE DELPHI}{$H+}{$R-}{$Q-}

interface

uses Windows;

type
  PZMTekenbeeld = ^TZMTekenbeeld;
  TZMTekenbeeld = record
    Voortgang: SmallInt;       { voortgangsbreedte }
    W, H: SmallInt;      { bitmapgrootte }
    XVerschuiving, YVerschuiving: SmallInt; { positie van de bitmap ten opzichte van de linkerbovenhoek van de cel }
    Data: PByte;         { rijen van ((W+7) div 8) bytes, MSB = meest linkse pixel }
  end;

  TZMTekenbeelden = array[0..255] of TZMTekenbeeld;
  PZMTekenbeelden = ^TZMTekenbeelden;

  PZMGezicht = ^TZMGezicht;
  TZMGezicht = record
    Lettertypefamilie: string;      { 'sans', 'serif', 'mono', 'system' }
    Vetgedrukt, Schuin: Boolean;
    EmPixels: Integer;       { gevraagde em-grootte in pixels (= -lfHeight) }
    Height: Integer;     { celhoogte = Opstijging + Afdaling }
    Opstijging, Afdaling: Integer;
    InterneInterlinie: Integer; { Height - EmPixels }
    GemiddeldeBreedte, MaxWidth: Integer;
    Grijstint: Boolean;       { gasp: anti-alias bij deze grootte }
    Tekenbeelden: TZMTekenbeelden;     { 1 bpp, gehinte mono-voortgangsbreedtes }
    AATekenbeelden: TZMTekenbeelden;   { 1 byte per pixel, grijsniveau 0..16 }
  end;

{ Zoekt het lettertype dat het best bij een LOGFONT past (Windows-lettertypekoppeling, vereenvoudigd). }
function ZMZoekGezicht(const Lettertype: TLogFont): PZMGezicht;
function ZMGezichtAantal: Integer;
function ZMGezichtOpNummer(Nummer: Integer): PZMGezicht;

implementation

uses SysUtils, paszlib;

{$I fonts/zmfontdata.inc}

var
  FontData: array of Byte;

type
  TFaceArray = array of TZMGezicht;

var
  Faces: TFaceArray;
  Loaded: Boolean = False;

procedure LaadGezichten;
var
  Teller, Glyph, Positie, Aantal: Integer;
  Gezicht: ^TZMGezicht;
  LengteUit: LongWord;
  function LeesW: Integer;
  begin
    Result := SmallInt(FontData[Positie] or (FontData[Positie + 1] shl 8));
    Inc(Positie, 2);
  end;
  procedure LeesGlyphs(var Glyphen: array of TZMTekenbeeld; Antialias: Boolean);
  var
    Glyphnr: Integer;
  begin
    for Glyphnr := 0 to 255 do
    begin
      Glyphen[Glyphnr].Voortgang := LeesW;
      Glyphen[Glyphnr].W := LeesW;
      Glyphen[Glyphnr].H := LeesW;
      Glyphen[Glyphnr].XVerschuiving := LeesW;
      Glyphen[Glyphnr].YVerschuiving := LeesW;
      if Antialias then Aantal := Glyphen[Glyphnr].W * Glyphen[Glyphnr].H
      else Aantal := ((Glyphen[Glyphnr].W + 7) div 8) * Glyphen[Glyphnr].H;
      if Aantal > 0 then Glyphen[Glyphnr].Data := @FontData[Positie] else Glyphen[Glyphnr].Data := nil;
      Inc(Positie, Aantal);
    end;
  end;
begin
  Loaded := True;
  SetLength(FontData, ZMFontDataSize);
  LengteUit := ZMFontDataSize;
  if uncompress(@FontData[0], LengteUit, @ZMFontDataZ[0], Length(ZMFontDataZ)) <> Z_OK then
    raise Exception.Create('ZMFonts: cannot inflate the font data');
  SetLength(Faces, ZMFontFaceCount);
  Positie := 0;
  for Teller := 0 to ZMFontFaceCount - 1 do
  begin
    Gezicht := @Faces[Teller];
    Gezicht^.Lettertypefamilie := ZMFontFaceInfo[Teller].Lettertypefamilie;
    Gezicht^.Vetgedrukt := ZMFontFaceInfo[Teller].Vetgedrukt;
    Gezicht^.Schuin := ZMFontFaceInfo[Teller].Schuin;
    Positie := ZMFontFaceInfo[Teller].BronPositie;
    Gezicht^.EmPixels := LeesW;
    Gezicht^.Opstijging := LeesW;
    Gezicht^.Afdaling := LeesW;
    Gezicht^.Height := Gezicht^.Opstijging + Gezicht^.Afdaling;
    Gezicht^.InterneInterlinie := Gezicht^.Height - Gezicht^.EmPixels;
    if Gezicht^.InterneInterlinie < 0 then Gezicht^.InterneInterlinie := 0;
    Gezicht^.GemiddeldeBreedte := LeesW;
    Gezicht^.MaxWidth := LeesW;
    Gezicht^.Grijstint := LeesW <> 0;
    LeesGlyphs(Gezicht^.Tekenbeelden, False);
    LeesGlyphs(Gezicht^.AATekenbeelden, True);
  end;
end;

function ZMGezichtAantal: Integer;
begin
  if not Loaded then LaadGezichten;
  Result := Length(Faces);
end;

function ZMGezichtOpNummer(Nummer: Integer): PZMGezicht;
begin
  if not Loaded then LaadGezichten;
  Result := @Faces[Nummer];
end;

function FamilieVan(const Naam: string; Spatiering: Byte): string;
var
  Kleinnaam: string;
begin
  Kleinnaam := LowerCase(Trim(Naam));
  if (Kleinnaam = 'system') or (Kleinnaam = 'fixedsys') then
    Result := 'system'
  else if (Pos('courier', Kleinnaam) > 0) or (Pos('mono', Kleinnaam) > 0) or (Kleinnaam = 'terminal') or
    (Pos('lucida console', Kleinnaam) > 0) then
    Result := 'mono'
  else if (Pos('times', Kleinnaam) > 0) or (Pos('serif', Kleinnaam) = 1) or (Kleinnaam = 'ms serif') or
    (Pos('georgia', Kleinnaam) > 0) or (Pos('garamond', Kleinnaam) > 0) then
    Result := 'serif'
  else if (Kleinnaam = '') and ((Spatiering and 3) = FIXED_PITCH) then
    Result := 'mono'
  else
    Result := 'sans';
end;

function ZMZoekGezicht(const Lettertype: TLogFont): PZMGezicht;
var
  Familie: string;
  Vet, Cursief: Boolean;
  Emgrootte, Teller, Punten, Beste, Verschil: Integer;
  Gezicht: ^TZMGezicht;
begin
  if not Loaded then LaadGezichten;
  Familie := FamilieVan(StrPas(Lettertype.lfFaceName), Lettertype.lfPitchAndFamily);
  Vet := Lettertype.lfWeight >= 600;
  Cursief := Lettertype.lfItalic <> 0;
  Emgrootte := Lettertype.lfHeight;
  if Emgrootte = 0 then Emgrootte := 13
  else if Emgrootte > 0 then
    { positieve hoogte = celhoogte; benader de em-grootte }
    Emgrootte := (Emgrootte * 85 + 50) div 100;
  if Emgrootte < 0 then Emgrootte := -Emgrootte;
  if Familie = 'system' then
  begin
    { Het Windows-lettertype 'System' is een vet bitmaplettertype van 16px (em ~13), ongeacht wat er gevraagd wordt. }
    Vet := True;
  end;
  Result := nil;
  Beste := MaxInt;
  for Teller := 0 to High(Faces) do
  begin
    Gezicht := @Faces[Teller];
    Punten := 0;
    if Gezicht^.Lettertypefamilie <> Familie then
    begin
      if (Familie = 'system') and (Gezicht^.Lettertypefamilie = 'sans') then Inc(Punten, 500)
      else if Familie = 'system' then Inc(Punten, 100000)
      else Inc(Punten, 100000);
    end;
    if Gezicht^.Vetgedrukt <> Vet then Inc(Punten, 2000);
    if Gezicht^.Schuin <> Cursief then Inc(Punten, 1000);
    Verschil := Abs(Gezicht^.EmPixels - Emgrootte);
    Inc(Punten, Verschil * 100);
    if Gezicht^.EmPixels > Emgrootte then Inc(Punten, 10);  { bij gelijke score de kleinere voorkeur, zodat tekst past }
    if Punten < Beste then
    begin
      Beste := Punten;
      Result := Gezicht;
    end;
  end;
  if Result = nil then
    Result := @Faces[0];
end;

end.

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
  PZMGlyph = ^TZMGlyph;
  TZMGlyph = record
    Adv: SmallInt;       { voortgangsbreedte }
    W, H: SmallInt;      { bitmapgrootte }
    XOff, YOff: SmallInt; { positie van de bitmap ten opzichte van de linkerbovenhoek van de cel }
    Data: PByte;         { rijen van ((W+7) div 8) bytes, MSB = meest linkse pixel }
  end;

  TZMGlyphs = array[0..255] of TZMGlyph;
  PZMGlyphs = ^TZMGlyphs;

  PZMFace = ^TZMFace;
  TZMFace = record
    Family: string;      { 'sans', 'serif', 'mono', 'system' }
    Bold, Italic: Boolean;
    EmPx: Integer;       { gevraagde em-grootte in pixels (= -lfHeight) }
    Height: Integer;     { celhoogte = Ascent + Descent }
    Ascent, Descent: Integer;
    IntLeading: Integer; { Height - EmPx }
    AvgWidth, MaxWidth: Integer;
    Gray: Boolean;       { gasp: anti-alias bij deze grootte }
    Glyphs: TZMGlyphs;     { 1 bpp, gehinte mono-voortgangsbreedtes }
    AAGlyphs: TZMGlyphs;   { 1 byte per pixel, grijsniveau 0..16 }
  end;

{ Zoekt het lettertype dat het best bij een LOGFONT past (Windows-lettertypekoppeling, vereenvoudigd). }
function ZMFindFace(const Lettertype: TLogFont): PZMFace;
function ZMFaceCount: Integer;
function ZMFaceByIndex(Nummer: Integer): PZMFace;

implementation

uses SysUtils, paszlib;

{$I fonts/zmfontdata.inc}

var
  FontData: array of Byte;

type
  TFaceArray = array of TZMFace;

var
  Faces: TFaceArray;
  Loaded: Boolean = False;

procedure LoadFaces;
var
  Teller, Glyph, Positie, Aantal: Integer;
  Gezicht: ^TZMFace;
  LengteUit: LongWord;
  function LeesW: Integer;
  begin
    Result := SmallInt(FontData[Positie] or (FontData[Positie + 1] shl 8));
    Inc(Positie, 2);
  end;
  procedure LeesGlyphs(var Glyphen: array of TZMGlyph; Antialias: Boolean);
  var
    Glyphnr: Integer;
  begin
    for Glyphnr := 0 to 255 do
    begin
      Glyphen[Glyphnr].Adv := LeesW;
      Glyphen[Glyphnr].W := LeesW;
      Glyphen[Glyphnr].H := LeesW;
      Glyphen[Glyphnr].XOff := LeesW;
      Glyphen[Glyphnr].YOff := LeesW;
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
    Gezicht^.Family := ZMFontFaceInfo[Teller].Family;
    Gezicht^.Bold := ZMFontFaceInfo[Teller].Bold;
    Gezicht^.Italic := ZMFontFaceInfo[Teller].Italic;
    Positie := ZMFontFaceInfo[Teller].Offset;
    Gezicht^.EmPx := LeesW;
    Gezicht^.Ascent := LeesW;
    Gezicht^.Descent := LeesW;
    Gezicht^.Height := Gezicht^.Ascent + Gezicht^.Descent;
    Gezicht^.IntLeading := Gezicht^.Height - Gezicht^.EmPx;
    if Gezicht^.IntLeading < 0 then Gezicht^.IntLeading := 0;
    Gezicht^.AvgWidth := LeesW;
    Gezicht^.MaxWidth := LeesW;
    Gezicht^.Gray := LeesW <> 0;
    LeesGlyphs(Gezicht^.Glyphs, False);
    LeesGlyphs(Gezicht^.AAGlyphs, True);
  end;
end;

function ZMFaceCount: Integer;
begin
  if not Loaded then LoadFaces;
  Result := Length(Faces);
end;

function ZMFaceByIndex(Nummer: Integer): PZMFace;
begin
  if not Loaded then LoadFaces;
  Result := @Faces[Nummer];
end;

function FamilyOf(const Naam: string; Spatiering: Byte): string;
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

function ZMFindFace(const Lettertype: TLogFont): PZMFace;
var
  Familie: string;
  Vet, Cursief: Boolean;
  Emgrootte, Teller, Punten, Beste, Verschil: Integer;
  Gezicht: ^TZMFace;
begin
  if not Loaded then LoadFaces;
  Familie := FamilyOf(StrPas(Lettertype.lfFaceName), Lettertype.lfPitchAndFamily);
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
    if Gezicht^.Family <> Familie then
    begin
      if (Familie = 'system') and (Gezicht^.Family = 'sans') then Inc(Punten, 500)
      else if Familie = 'system' then Inc(Punten, 100000)
      else Inc(Punten, 100000);
    end;
    if Gezicht^.Bold <> Vet then Inc(Punten, 2000);
    if Gezicht^.Italic <> Cursief then Inc(Punten, 1000);
    Verschil := Abs(Gezicht^.EmPx - Emgrootte);
    Inc(Punten, Verschil * 100);
    if Gezicht^.EmPx > Emgrootte then Inc(Punten, 10);  { bij gelijke score de kleinere voorkeur, zodat tekst past }
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

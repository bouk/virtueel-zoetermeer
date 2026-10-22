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
function ZMFindFace(const LF: TLogFont): PZMFace;
function ZMFaceCount: Integer;
function ZMFaceByIndex(I: Integer): PZMFace;

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
  I, G, P, N: Integer;
  F: ^TZMFace;
  DestLen: LongWord;
  function RdW: Integer;
  begin
    Result := SmallInt(FontData[P] or (FontData[P + 1] shl 8));
    Inc(P, 2);
  end;
  procedure ReadGlyphs(var Glyphs: array of TZMGlyph; AA: Boolean);
  var
    G2: Integer;
  begin
    for G2 := 0 to 255 do
    begin
      Glyphs[G2].Adv := RdW;
      Glyphs[G2].W := RdW;
      Glyphs[G2].H := RdW;
      Glyphs[G2].XOff := RdW;
      Glyphs[G2].YOff := RdW;
      if AA then N := Glyphs[G2].W * Glyphs[G2].H
      else N := ((Glyphs[G2].W + 7) div 8) * Glyphs[G2].H;
      if N > 0 then Glyphs[G2].Data := @FontData[P] else Glyphs[G2].Data := nil;
      Inc(P, N);
    end;
  end;
begin
  Loaded := True;
  SetLength(FontData, ZMFontDataSize);
  DestLen := ZMFontDataSize;
  if uncompress(@FontData[0], DestLen, @ZMFontDataZ[0], Length(ZMFontDataZ)) <> Z_OK then
    raise Exception.Create('ZMFonts: cannot inflate the font data');
  SetLength(Faces, ZMFontFaceCount);
  P := 0;
  for I := 0 to ZMFontFaceCount - 1 do
  begin
    F := @Faces[I];
    F^.Family := ZMFontFaceInfo[I].Family;
    F^.Bold := ZMFontFaceInfo[I].Bold;
    F^.Italic := ZMFontFaceInfo[I].Italic;
    P := ZMFontFaceInfo[I].Offset;
    F^.EmPx := RdW;
    F^.Ascent := RdW;
    F^.Descent := RdW;
    F^.Height := F^.Ascent + F^.Descent;
    F^.IntLeading := F^.Height - F^.EmPx;
    if F^.IntLeading < 0 then F^.IntLeading := 0;
    F^.AvgWidth := RdW;
    F^.MaxWidth := RdW;
    F^.Gray := RdW <> 0;
    ReadGlyphs(F^.Glyphs, False);
    ReadGlyphs(F^.AAGlyphs, True);
  end;
end;

function ZMFaceCount: Integer;
begin
  if not Loaded then LoadFaces;
  Result := Length(Faces);
end;

function ZMFaceByIndex(I: Integer): PZMFace;
begin
  if not Loaded then LoadFaces;
  Result := @Faces[I];
end;

function FamilyOf(const Name: string; Pitch: Byte): string;
var
  N: string;
begin
  N := LowerCase(Trim(Name));
  if (N = 'system') or (N = 'fixedsys') then
    Result := 'system'
  else if (Pos('courier', N) > 0) or (Pos('mono', N) > 0) or (N = 'terminal') or
    (Pos('lucida console', N) > 0) then
    Result := 'mono'
  else if (Pos('times', N) > 0) or (Pos('serif', N) = 1) or (N = 'ms serif') or
    (Pos('georgia', N) > 0) or (Pos('garamond', N) > 0) then
    Result := 'serif'
  else if (N = '') and ((Pitch and 3) = FIXED_PITCH) then
    Result := 'mono'
  else
    Result := 'sans';
end;

function ZMFindFace(const LF: TLogFont): PZMFace;
var
  Fam: string;
  Bold, Italic: Boolean;
  Em, I, Score, Best, D: Integer;
  F: ^TZMFace;
begin
  if not Loaded then LoadFaces;
  Fam := FamilyOf(StrPas(LF.lfFaceName), LF.lfPitchAndFamily);
  Bold := LF.lfWeight >= 600;
  Italic := LF.lfItalic <> 0;
  Em := LF.lfHeight;
  if Em = 0 then Em := 13
  else if Em > 0 then
    { positieve hoogte = celhoogte; benader de em-grootte }
    Em := (Em * 85 + 50) div 100;
  if Em < 0 then Em := -Em;
  if Fam = 'system' then
  begin
    { Het Windows-lettertype 'System' is een vet bitmaplettertype van 16px (em ~13), ongeacht wat er gevraagd wordt. }
    Bold := True;
  end;
  Result := nil;
  Best := MaxInt;
  for I := 0 to High(Faces) do
  begin
    F := @Faces[I];
    Score := 0;
    if F^.Family <> Fam then
    begin
      if (Fam = 'system') and (F^.Family = 'sans') then Inc(Score, 500)
      else if Fam = 'system' then Inc(Score, 100000)
      else Inc(Score, 100000);
    end;
    if F^.Bold <> Bold then Inc(Score, 2000);
    if F^.Italic <> Italic then Inc(Score, 1000);
    D := Abs(F^.EmPx - Em);
    Inc(Score, D * 100);
    if F^.EmPx > Em then Inc(Score, 10);  { bij gelijke score de kleinere voorkeur, zodat tekst past }
    if Score < Best then
    begin
      Best := Score;
      Result := F;
    end;
  end;
  if Result = nil then
    Result := @Faces[0];
end;

end.

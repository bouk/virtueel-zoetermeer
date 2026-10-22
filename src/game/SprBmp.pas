unit SprBmp;

{ TBmpSurface: TSurface geimplementeerd met een GDI-TBitmap (24-bit DIB) en, wanneer een
  transparante kleur is ingesteld, een monochroom maskerbitmap.
  Gedecompileerd uit ROS.exe v1.1, code 00461C00-00463223. }

{$I zm.inc}

interface

uses
  Windows, SysUtils, Classes, Graphics, uSurface;

type
  TBmpSurface = class(TSurface)
  private
    FBitmap: TBitmap;            { +0x30 }
    FMask: TBitmap;              { +0x34  wit waar transparant; nil wanneer geen transparante kleur is ingesteld }
    FTransparentColor: TColor;   { +0x38 }
    procedure CreateMask;
    class procedure StretchDraw(DC: HDC; Mask, Bitmap: TBitmap; SrcRect, DestRect: TRect;
      MirrorX, MirrorY: Boolean);
  protected
    function GetHeight: Integer; override;                           { +0x20 }
    function GetWidth: Integer; override;                            { +0x2C }
  public
    constructor CreateSize(AWidth, AHeight: Integer); override;      { +0x60 }
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;                 { +0x08 }
    procedure LoadFromStream(Stream: TStream); override;             { +0x50 }
    procedure SaveToStream(Stream: TStream); override;               { +0x54 }
    function GetPixel(X, Y: Integer): Integer; override;             { +0x64 }
    procedure SetPixel(X, Y: Integer; Index: Byte); override;        { +0x68 }
    function GetCanvas: TCanvas; override;                           { +0x6C }
    function GetPaletteColor(Index: Integer): TRGBQuad; override;    { +0x70 }
    procedure SetPaletteColor(Index: Integer; Color: TRGBQuad); override; { +0x74 }
    function GetTransparentColor: TColor; override;                  { +0x78 }
    procedure SetTransparentColor(Value: TColor); override;          { +0x7C }
    function GetPaletteHandle: HPALETTE; override;                   { +0x80 }
    function GetHandle: HBITMAP; override;                           { +0x84 }
    class function GetScreen: TSurfaceScreen; override;              { +0x88 }
    function GetPaletteCount: Integer; override;                     { +0x8C }
    procedure DebugShow(Caption: string); override;                  { +0x90 }
    procedure SavePalette(FileName: string); override;               { +0x94 }
    procedure ConvertTo(Target: TSurface); override;                 { +0x98 }
    procedure CopyPalette(Source: TSurface); override;               { +0x9C }
    procedure CopyFrom(Source: TSurface; SrcRect, DestRect: TRect;
      MirrorX, MirrorY: Boolean); override;                          { +0xA0 }
    procedure DrawTo(DC: HDC; SrcRect, DestRect: TRect;
      MirrorX, MirrorY: Boolean); override;                          { +0xA4 }
    procedure SetSize(AWidth, AHeight: Integer; Stretch: Boolean); override; { +0xA8 }
    procedure TextOut(X, Y: Integer; AFont: TFont; Text: string); override;  { +0xAC }
    function TextWidth(AFont: TFont; Text: string): Integer; override;       { +0xB0 }
    function TextHeight(AFont: TFont; Text: string): Integer; override;      { +0xB4 }
    procedure FillRect(R: TRect; Color: Byte); override;             { +0xB8 }
    property Bitmap: TBitmap read FBitmap;
    property Mask: TBitmap read FMask;
  end;

  { msimg32.TransparentBlt. LET OP: in het origineel zonder stdcall gedeclareerd; hij wordt nooit
    aangeroepen omdat de DLL nooit geladen wordt (HasTransparentBlt blijft False). }
  TTransparentBltProc = function(DC: HDC; X, Y, W, H: Integer; SrcDC: HDC;
    SX, SY, SW, SH: Integer; Color: UINT): BOOL;

const
  HandleCheck: Integer = 0;        { 00488D40: handles worden erin gemengd om hun aanmaak af te dwingen }
  BmpSurfaceCount: Integer = 0;    { 00488D44: aantal levende TBmpSurface-instanties }
  { 00488D48: BITMAPFILEHEADER + BITMAPINFOHEADER van een 256x100 8-bit bitmap }
  PaletteBmpHeader: array[0..$35] of Byte = (
    $42, $4D, $36, $68, $00, $00, $00, $00, $00, $00, $36, $04, $00, $00,
    $28, $00, $00, $00, $00, $01, $00, $00, $64, $00, $00, $00, $01, $00,
    $08, $00, $00, $00, $00, $00, $00, $64, $00, $00, $C4, $0E, $00, $00,
    $C4, $0E, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00);

var
  BmpScreen: TSurfaceScreen;               { 0048A8BC: is altijd nil }
  TransparentBltProc: TTransparentBltProc; { 0048A8C4 }
  HasTransparentBlt: Boolean;              { 0048A8C8 }

procedure SetupBitmap(Bmp: TBitmap);
procedure RealizeBitmap(Bmp: TBitmap);
procedure SwapInt(var A, B: Integer);

implementation

uses
  Forms, uTool, fShow;

var
  MsImgHandle: HMODULE;

{ @00461D3C }
procedure SetupBitmap(Bmp: TBitmap);
var
  Versie: TWinVersion;
begin
  Bmp.HandleType := bmDIB;
  Bmp.PixelFormat := pf24bit;
  Exit;
  { LET OP: in het origineel ook onbereikbaar }
  GetWinVersion(Versie);
  if (Versie.IsNT and (Versie.Major < 4)) or (Versie.Major = $5F) or (Versie.Minor = 0) then
    Bmp.HandleType := bmDDB
  else
  begin
    Bmp.HandleType := bmDIB;
    Bmp.PixelFormat := pf24bit;
  end;
  Bmp.HandleType := bmDDB;
end;

{ @00461DA4 }
procedure RealizeBitmap(Bmp: TBitmap);
begin
  HandleCheck := HandleCheck xor Integer(Bmp.Handle);
  HandleCheck := HandleCheck xor Integer(Bmp.Canvas.Handle);
end;

{ @00461DC8 }
constructor TBmpSurface.CreateSize(AWidth, AHeight: Integer);
var
  Formulier: TForm;
begin
  inherited CreateSize(AWidth, AHeight);
  FBitmap := TBitmap.Create;
  SetupBitmap(FBitmap);
  FBitmap.Width := AWidth;
  FBitmap.Height := AHeight;
  BitBlt(FBitmap.Canvas.Handle, 0, 0, AWidth, AHeight, FBitmap.Canvas.Handle, 0, 0, BLACKNESS);
  Formulier := TForm.Create(nil);
  Formulier.Canvas.Draw(0, 0, FBitmap);
  Formulier.Free;
  Blank := True;
  FMask := nil;
  FTransparentColor := clNoTransparent;
  Inc(BmpSurfaceCount);
end;

{ @00461EAC }
destructor TBmpSurface.Destroy;
begin
  FBitmap.Free;
  if FMask <> nil then
  begin
    FMask.Free;
    FMask := nil;
  end;
  Dec(BmpSurfaceCount);
  inherited Destroy;
end;

{ @00461EF0 }
class function TBmpSurface.GetScreen: TSurfaceScreen;
begin
  Result := BmpScreen;
end;

{ @00461EF8 }
function TBmpSurface.GetPixel(X, Y: Integer): Integer;
begin
  Result := ColorToIndex(FBitmap.Canvas.Pixels[X, Y]);
end;

{ @00461F20 }
procedure TBmpSurface.SetPixel(X, Y: Integer; Index: Byte);
var
  Kleur: TRGBQuad;
begin
  Kleur := GetPaletteColor(Index);
  FBitmap.Canvas.Pixels[X, Y] := (Kleur.rgbBlue shl 16) + (Kleur.rgbGreen shl 8) + Kleur.rgbRed;
end;

{ @00461F74 }
function TBmpSurface.GetCanvas: TCanvas;
begin
  Result := FBitmap.Canvas;
end;

{ @00461F80 }
function TBmpSurface.GetPaletteColor(Index: Integer): TRGBQuad;
var
  Invoer: TPaletteEntry;
begin
  GetPaletteEntries(FBitmap.Palette, Index, 1, Invoer);
  Result.rgbBlue := Invoer.peBlue;
  Result.rgbGreen := Invoer.peGreen;
  Result.rgbRed := Invoer.peRed;
  { LET OP: rgbReserved blijft ongedefinieerd, zoals in het origineel }
end;

{ @00461FC0 }
procedure TBmpSurface.SetPaletteColor(Index: Integer; Color: TRGBQuad);
var
  Invoer: TPaletteEntry;
begin
  Invoer.peBlue := Color.rgbBlue;
  Invoer.peGreen := Color.rgbGreen;
  Invoer.peRed := Color.rgbRed;
  Invoer.peFlags := PC_NOCOLLAPSE;
  SetPaletteEntries(FBitmap.Palette, Index, 1, Invoer);
end;

{ @00462004 }
function TBmpSurface.GetTransparentColor: TColor;
begin
  Result := FTransparentColor;
end;

{ @00462008 }
procedure TBmpSurface.CreateMask;
begin
  FMask := TBitmap.Create;
  FMask.HandleType := bmDIB;
  FMask.PixelFormat := pf24bit;
  FMask.Width := FBitmap.Width;
  FMask.Height := FBitmap.Height;
end;

{ @00462058 }
procedure TBmpSurface.SetTransparentColor(Value: TColor);
var
  OudAchtergrond: COLORREF;
  OudePenKleur: TColor;
  RGBWaarde: Integer;
  Tijdelijk: TBitmap;
  X, Y: Integer;
  BronRegel, MaskerRegel, Regel: PByteArray;
  Bron, Doel: PInteger;
  S0, S1, S2, M0, M1, M2: PByte;
begin
  if Value = FTransparentColor then
    Exit;
  if HasTransparentBlt then
  begin
    FTransparentColor := Value;
    Exit;
  end;
  if (FTransparentColor <> 0) and (FTransparentColor <> clNoTransparent) then
  begin
    { geef de transparante pixels (zwart gemaakt door SRCAND hieronder) hun kleur terug }
    OudePenKleur := FMask.Canvas.Pen.Color;
    FBitmap.Canvas.Pen.Color := 0;
    OudAchtergrond := SetBkColor(FBitmap.Canvas.Handle, FTransparentColor);
    BitBlt(FBitmap.Canvas.Handle, 0, 0, FBitmap.Width, FBitmap.Height,
      FMask.Canvas.Handle, 0, 0, SRCPAINT);
    SetBkColor(FBitmap.Canvas.Handle, OudAchtergrond);
    FBitmap.Canvas.Pen.Color := OudePenKleur;
  end;
  if FTransparentColor = clNoTransparent then
    CreateMask;
  FTransparentColor := Value;
  if Value = clNoTransparent then
  begin
    FMask.Free;
    FMask := nil;
    Exit;
  end;
  OudAchtergrond := SetBkColor(FBitmap.Canvas.Handle, FTransparentColor);
  { TColor $00BBGGRR -> $00RRGGBB zoals opgeslagen in een 24-bit scanregel }
  RGBWaarde := ((FTransparentColor and $FF) shl 16) + (FTransparentColor and $FF00) +
    ((FTransparentColor and $FF0000) shr 16);
  FMask.HandleType := bmDIB;
  FMask.PixelFormat := pf24bit;
  Tijdelijk := TBitmap.Create;
  Tijdelijk.HandleType := bmDIB;
  Tijdelijk.PixelFormat := pf24bit;
  Tijdelijk.Width := FBitmap.Width;
  Tijdelijk.Height := FBitmap.Height;
  BitBlt(Tijdelijk.Canvas.Handle, 0, 0, FBitmap.Width, FBitmap.Height,
    FBitmap.Canvas.Handle, 0, 0, SRCCOPY);
  for Y := 0 to Tijdelijk.Height - 1 do
  begin
    BronRegel := Tijdelijk.ScanLine[Y];
    MaskerRegel := FMask.ScanLine[Y];
    for X := 0 to FBitmap.Width - 1 do
    begin
      Bron := PInteger(@BronRegel[X * 3]);
      Doel := PInteger(@MaskerRegel[X * 3]);
      if X = Tijdelijk.Width - 1 then
      begin
        { laatste pixel van de regel: bytetoegang, een dword zou voorbij het eind lezen }
        S0 := @BronRegel[X * 3];
        S1 := S0;
        Inc(S1);
        S2 := S0;
        Inc(S2, 2);
        M0 := @MaskerRegel[X * 3];
        M1 := M0;
        Inc(M1);
        M2 := M0;
        Inc(M2, 2);
        if ((S0^ + S1^ shl 8 + S2^ shl 16) and $FFFFFF) = (RGBWaarde and $FFFFFF) then
        begin
          M0^ := M0^ or $FF;
          M1^ := M1^ or $FF;
          M2^ := M2^ or $FF;
        end
        else
        begin
          M0^ := M0^ and 0;
          M1^ := M1^ and 0;
          M2^ := M2^ and 0;
        end;
      end
      else if (Bron^ and $FFFFFF) = (RGBWaarde and $FFFFFF) then
        Doel^ := Doel^ or $FFFFFF
      else
        Doel^ := Doel^ and Integer($FF000000);
    end;
  end;
  FMask.Monochrome := True;
  Tijdelijk.Free;
  SetBkColor(FBitmap.Canvas.Handle, OudAchtergrond);
  if (Value <> 0) and (FTransparentColor <> clNoTransparent) then
  begin
    if FBitmap.PixelFormat = pf8bit then
    begin
      for Y := 0 to FBitmap.Height - 1 do
      begin
        Regel := FBitmap.ScanLine[Y];
        for X := 0 to FBitmap.Width - 1 do
          if Regel[X] = $FC then
            Regel[X] := 0;
      end;
    end
    else
    begin
      { maak de transparante pixels zwart zodat het beeld met OR op het gemaskerde doel gezet kan worden }
      BitBlt(FMask.Canvas.Handle, 0, 0, FMask.Width, FMask.Height,
        FMask.Canvas.Handle, 0, 0, DSTINVERT);
      BitBlt(FBitmap.Canvas.Handle, 0, 0, FBitmap.Width, FBitmap.Height,
        FMask.Canvas.Handle, 0, 0, SRCAND);
      BitBlt(FMask.Canvas.Handle, 0, 0, FMask.Width, FMask.Height,
        FMask.Canvas.Handle, 0, 0, DSTINVERT);
    end;
  end;
end;

{ @0046250C }
function TBmpSurface.GetPaletteHandle: HPALETTE;
begin
  Result := FBitmap.Palette;
end;

{ @00462518 }
function TBmpSurface.GetHandle: HBITMAP;
begin
  Result := FBitmap.Handle;
end;

{ @00462524 }
function TBmpSurface.GetWidth: Integer;
begin
  Result := FBitmap.Width;
end;

{ @00462530 }
function TBmpSurface.GetHeight: Integer;
begin
  Result := FBitmap.Height;
end;

{ @0046253C }
function TBmpSurface.GetPaletteCount: Integer;
begin
  Result := 256;
end;

{ @00462544 }
procedure TBmpSurface.ConvertTo(Target: TSurface);
begin
end;

{ @00462548 }
procedure TBmpSurface.CopyPalette(Source: TSurface);
var
  I: Integer;
begin
  for I := 0 to GetPaletteCount - 1 do
    SetPaletteColor(I, Source.GetPaletteColor(I));
end;

{ @00462588  Schrijft het palet als een 256x100 bitmapbestand (een kolom per item). }
procedure TBmpSurface.SavePalette(FileName: string);
var
  Bestand: file;
  Buffer: array[0..$6835] of Byte;
  I, Y: Integer;
begin
  for I := 0 to $35 do
    Buffer[I] := PaletteBmpHeader[I];
  for I := 0 to 255 do
  begin
    { LET OP: het origineel leest de kleur als Longint: byte 0, shr 8, shr 16 }
    Buffer[$36 + I * 4] := GetPaletteColor(I).rgbBlue;
    Buffer[$36 + I * 4 + 1] := GetPaletteColor(I).rgbGreen;
    Buffer[$36 + I * 4 + 2] := GetPaletteColor(I).rgbRed;
    Buffer[$36 + I * 4 + 3] := 0;
    for Y := 0 to 99 do
      Buffer[$436 + I + Y * 256] := I;
  end;
  AssignFile(Bestand, FileName);
  Rewrite(Bestand, 1);
  BlockWrite(Bestand, Buffer, SizeOf(Buffer));
  CloseFile(Bestand);
end;

{ @004626C0 }
procedure TBmpSurface.CopyFrom(Source: TSurface; SrcRect, DestRect: TRect;
  MirrorX, MirrorY: Boolean);
var
  Bron: TBmpSurface;
  A, B: TBmpSurface;
begin
  if not (Source is TBmpSurface) then
    raise Exception.Create('Can only copy from BmpSurfaces');
  Bron := Source as TBmpSurface;
  HandleCheck := HandleCheck + Integer(FBitmap.Handle);
  HandleCheck := HandleCheck + Integer(FBitmap.Canvas.Handle);
  A := Bron;
  B := Self;
  if A.Blank and B.Blank then
    Exit;
  if B.Blank <> A.Blank then
  begin
    { de lege neemt het palet van de andere over }
    if B.Blank then
    begin
      A := Self;
      B := Bron;
    end;
    A.Blank := False;
    A.FBitmap.Palette := B.FBitmap.Palette;
  end;
  Bron.DrawTo(FBitmap.Canvas.Handle, SrcRect, DestRect, MirrorX, MirrorY);
end;

{ @004627D4 }
procedure SwapInt(var A, B: Integer);
var
  Hulp: Integer;
begin
  Hulp := A;
  A := B;
  B := Hulp;
end;

{ @004627E0 }
class procedure TBmpSurface.StretchDraw(DC: HDC; Mask, Bitmap: TBitmap; SrcRect, DestRect: TRect;
  MirrorX, MirrorY: Boolean);
var
  HeeftMasker: Boolean;
  OudPalet, OudBitmapPalet: HPALETTE;
  OudModus: Integer;
  Rasterop: DWORD;
begin
  HeeftMasker := Mask <> nil;
  if MirrorX then
  begin
    SwapInt(DestRect.Left, DestRect.Right);
    Dec(DestRect.Left);
    Dec(DestRect.Right);
  end;
  if MirrorY then
  begin
    SwapInt(DestRect.Top, DestRect.Bottom);
    Dec(DestRect.Top);
    Dec(DestRect.Bottom);
  end;
  if HeeftMasker then
    StretchBlt(DC, DestRect.Left, DestRect.Top, DestRect.Right - DestRect.Left,
      DestRect.Bottom - DestRect.Top, Mask.Canvas.Handle, SrcRect.Left, SrcRect.Top,
      SrcRect.Right - SrcRect.Left, SrcRect.Bottom - SrcRect.Top, SRCAND);
  if Bitmap.Palette <> 0 then
  begin
    OudPalet := SelectPalette(DC, Bitmap.Palette, True);
    RealizePalette(DC);
    OudBitmapPalet := SelectPalette(Bitmap.Canvas.Handle, Bitmap.Palette, True);
    RealizePalette(Bitmap.Canvas.Handle);
  end;
  if HeeftMasker then
    Rasterop := SRCPAINT
  else
    Rasterop := SRCCOPY;
  OudModus := SetStretchBltMode(DC, COLORONCOLOR);
  StretchBlt(DC, DestRect.Left, DestRect.Top, DestRect.Right - DestRect.Left,
    DestRect.Bottom - DestRect.Top, Bitmap.Canvas.Handle, SrcRect.Left, SrcRect.Top,
    SrcRect.Right - SrcRect.Left, SrcRect.Bottom - SrcRect.Top, Rasterop);
  SetStretchBltMode(DC, OudModus);
  if Bitmap.Palette <> 0 then
  begin
    SelectPalette(DC, OudPalet, True);
    SelectPalette(Bitmap.Canvas.Handle, OudBitmapPalet, True);
  end;
end;

{ @00462980 }
procedure TBmpSurface.DrawTo(DC: HDC; SrcRect, DestRect: TRect; MirrorX, MirrorY: Boolean);
begin
  if HasTransparentBlt and (GetTransparentColor <> clNoTransparent) then
  begin
    if MirrorX then
    begin
      SwapInt(DestRect.Left, DestRect.Right);
      Dec(DestRect.Left);
      Dec(DestRect.Right);
    end;
    if MirrorY then
    begin
      SwapInt(DestRect.Top, DestRect.Bottom);
      Dec(DestRect.Top);
      Dec(DestRect.Bottom);
    end;
    TransparentBltProc(DC, DestRect.Left, DestRect.Top, DestRect.Right - DestRect.Left,
      DestRect.Bottom - DestRect.Top, FBitmap.Canvas.Handle, SrcRect.Left, SrcRect.Top,
      SrcRect.Right - SrcRect.Left, SrcRect.Bottom - SrcRect.Top, FTransparentColor);
    GetLastError;
  end
  else if GetTransparentColor <> clNoTransparent then
    StretchDraw(DC, FMask, FBitmap, SrcRect, DestRect, MirrorX, MirrorY)
  else
    StretchDraw(DC, nil, FBitmap, SrcRect, DestRect, MirrorX, MirrorY);
end;

{ @00462A94 }
procedure TBmpSurface.Assign(Source: TPersistent);
var
  Bron: TBmpSurface;
begin
  if Source is TBmpSurface then
  begin
    Bron := Source as TBmpSurface;
    Blank := Bron.Blank;
    FBitmap.Assign(Bron.FBitmap);
    FTransparentColor := Bron.GetTransparentColor;
    if FTransparentColor <> clNoTransparent then
    begin
      if FMask = nil then
        CreateMask;
      FMask.Assign(Bron.FMask);
      RealizeBitmap(FMask);
    end
    else
    begin
      FMask.Free;
      FMask := nil;
    end;
  end
  else
    inherited Assign(Source);
end;

{ @00462B20  Accepteert een bitmap met of zonder een prefix van 2 of 8 bytes voor de 'BM'. }
procedure TBmpSurface.LoadFromStream(Stream: TStream);
var
  Signatuur: Word;
begin
  Stream.Read(Signatuur, 2);
  if Signatuur = $4D42 then
    Stream.Seek(-2, soFromCurrent)
  else
  begin
    Stream.Seek(2, soFromCurrent);
    Stream.Read(Signatuur, 2);
    if Signatuur = $4D42 then
      Stream.Seek(-2, soFromCurrent)
    else
      Stream.Seek(6, soFromCurrent);
  end;
  FBitmap.Free;
  FBitmap := TBitmap.Create;
  FBitmap.LoadFromStream(Stream);
  RealizeBitmap(FBitmap);
  FTransparentColor := clNoTransparent;
  Blank := False;
end;

{ @00462BD4 }
procedure TBmpSurface.SaveToStream(Stream: TStream);
begin
  FBitmap.SaveToStream(Stream);
  FTransparentColor := clNoTransparent;
end;

{ @00462BF0 }
procedure TBmpSurface.SetSize(AWidth, AHeight: Integer; Stretch: Boolean);
var
  Tijdelijk: TBitmap;
  OudModus: Integer;
begin
  if not Stretch then
  begin
    RealizeBitmap(FBitmap);
    FBitmap.Width := AWidth;
    RealizeBitmap(FBitmap);
    FBitmap.Height := AHeight;
    if FMask <> nil then
    begin
      RealizeBitmap(FMask);
      FMask.Width := AWidth;
      RealizeBitmap(FMask);
      FMask.Height := AHeight;
    end;
  end
  else
  begin
    Tijdelijk := TBitmap.Create;
    SetupBitmap(Tijdelijk);
    Tijdelijk.Assign(FBitmap);
    RealizeBitmap(Tijdelijk);
    Tijdelijk.Width := AWidth;
    RealizeBitmap(Tijdelijk);
    Tijdelijk.Height := AHeight;
    RealizeBitmap(Tijdelijk);
    OudModus := SetStretchBltMode(Tijdelijk.Canvas.Handle, COLORONCOLOR);
    StretchBlt(Tijdelijk.Canvas.Handle, 0, 0, AWidth, AHeight, FBitmap.Canvas.Handle, 0, 0,
      FBitmap.Width, FBitmap.Height, SRCCOPY);
    SetStretchBltMode(Tijdelijk.Canvas.Handle, OudModus);
    RealizeBitmap(FBitmap);
    FBitmap.Width := AWidth;
    RealizeBitmap(FBitmap);
    FBitmap.Height := AHeight;
    RealizeBitmap(FBitmap);
    BitBlt(FBitmap.Canvas.Handle, 0, 0, AWidth, AHeight, Tijdelijk.Canvas.Handle, 0, 0, SRCCOPY);
    RealizeBitmap(FBitmap);
    if FMask <> nil then
    begin
      Tijdelijk.Assign(FMask);
      RealizeBitmap(Tijdelijk);
      Tijdelijk.Width := AWidth;
      RealizeBitmap(Tijdelijk);
      Tijdelijk.Height := AHeight;
      OudModus := SetStretchBltMode(Tijdelijk.Canvas.Handle, COLORONCOLOR);
      { LET OP: rekt FBitmap (al vergroot), niet het oude masker, naar het nieuwe masker }
      StretchBlt(Tijdelijk.Canvas.Handle, 0, 0, AWidth, AHeight, FBitmap.Canvas.Handle, 0, 0,
        FBitmap.Width, FBitmap.Height, SRCCOPY);
      SetStretchBltMode(Tijdelijk.Canvas.Handle, OudModus);
      FMask.Assign(Tijdelijk);
    end;
    Tijdelijk.Free;
  end;
end;

{ @00462E3C }
procedure TBmpSurface.TextOut(X, Y: Integer; AFont: TFont; Text: string);
var
  OudTransparant: TColor;
  OudLettertype: TFont;
begin
  if GetTransparentColor <> clNoTransparent then
  begin
    OudTransparant := GetTransparentColor;
    SetTransparentColor(0);
  end;
  OudLettertype := TFont.Create;
  OudLettertype.Assign(FBitmap.Canvas.Font);
  FBitmap.Canvas.Font.Assign(AFont);
  FBitmap.Canvas.TextOut(X, Y, Text);
  FBitmap.Canvas.Font.Assign(OudLettertype);
  OudLettertype.Free;
  if GetTransparentColor <> clNoTransparent then
    SetTransparentColor(OudTransparant);
end;

{ @00462F24 }
procedure TBmpSurface.DebugShow(Caption: string);
begin
  ShowBitmap(FBitmap, Caption);
end;

{ @00462F70 }
function TBmpSurface.TextWidth(AFont: TFont; Text: string): Integer;
var
  Vlak: TSurface;
begin
  Vlak := NewSurface;
  Vlak.GetCanvas.Font := AFont;
  Result := Vlak.GetCanvas.TextWidth(Text);
  Vlak.Free;
end;

{ @00462FE4 }
function TBmpSurface.TextHeight(AFont: TFont; Text: string): Integer;
var
  Vlak: TSurface;
begin
  Vlak := NewSurface;
  Vlak.GetCanvas.Font := AFont;
  Result := Vlak.GetCanvas.TextHeight(Text);
  Vlak.Free;
end;

{ @00463058 }
procedure TBmpSurface.FillRect(R: TRect; Color: Byte);
var
  Waarde: Integer;
  Rasterop: DWORD;
  OudeStijl: TBrushStyle;
  OudeKwastKleur, OudePenKleur: TColor;
begin
  Waarde := Color;
  { LET OP: een Byte kan nooit $FFFFFF zijn }
  if (Waarde = 0) or (Waarde = $FFFFFF) then
  begin
    if Waarde = 0 then
      Rasterop := BLACKNESS
    else
      Rasterop := WHITENESS;
    BitBlt(FBitmap.Canvas.Handle, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top,
      FBitmap.Canvas.Handle, 0, 0, Rasterop);
  end
  else
  begin
    Waarde := IndexToColor(Waarde);
    RealizeBitmap(FBitmap);
    OudeStijl := FBitmap.Canvas.Brush.Style;
    OudeKwastKleur := FBitmap.Canvas.Brush.Color;
    OudePenKleur := FBitmap.Canvas.Pen.Color;
    FBitmap.Canvas.Brush.Style := bsClear;
    FBitmap.Canvas.Brush.Color := Waarde;
    FBitmap.Canvas.Pen.Color := Waarde;
    FBitmap.Canvas.FillRect(R);
    FBitmap.Canvas.Pen.Color := OudePenKleur;
    FBitmap.Canvas.Brush.Style := OudeStijl;
    FBitmap.Canvas.Brush.Color := OudeKwastKleur;
  end;
end;

{ @004631D4 }
initialization
  if SurfaceClass <> nil then
    SurfaceClass := TBmpSurface;
  BmpScreen := nil;
  { LET OP: msimg32.dll wordt nooit geladen (de handle is in het origineel een constante 0, die in een
    register bewaard wordt), dus TransparentBlt wordt nooit gebruikt }
  MsImgHandle := 0;
  if MsImgHandle <> 0 then
  begin
    @TransparentBltProc := GetProcAddress(MsImgHandle, 'TransparentBlt');
    HasTransparentBlt := True;
  end
  else
    HasTransparentBlt := False;

end.

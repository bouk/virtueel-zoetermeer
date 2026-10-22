unit SprBmp;

{ TBmpSurface: TSurface implemented with a GDI TBitmap (24-bit DIB) and, when a
  transparent colour is set, a monochrome mask bitmap.
  Decompiled from ROS.exe v1.1, code 00461C00-00463223. }

{$I zm.inc}

interface

uses
  Windows, SysUtils, Classes, Graphics, uSurface;

type
  TBmpSurface = class(TSurface)
  private
    FBitmap: TBitmap;            { +0x30 }
    FMask: TBitmap;              { +0x34  white where transparent; nil when no transparent colour }
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

  { msimg32.TransparentBlt. NOTE: declared without stdcall in the original; it is never
    called because the DLL is never loaded (HasTransparentBlt stays False). }
  TTransparentBltProc = function(DC: HDC; X, Y, W, H: Integer; SrcDC: HDC;
    SX, SY, SW, SH: Integer; Color: UINT): BOOL;

const
  HandleCheck: Integer = 0;        { 00488D40: handles are mixed in to force their creation }
  BmpSurfaceCount: Integer = 0;    { 00488D44: number of TBmpSurface instances alive }
  { 00488D48: BITMAPFILEHEADER + BITMAPINFOHEADER of a 256x100 8-bit bitmap }
  PaletteBmpHeader: array[0..$35] of Byte = (
    $42, $4D, $36, $68, $00, $00, $00, $00, $00, $00, $36, $04, $00, $00,
    $28, $00, $00, $00, $00, $01, $00, $00, $64, $00, $00, $00, $01, $00,
    $08, $00, $00, $00, $00, $00, $00, $64, $00, $00, $C4, $0E, $00, $00,
    $C4, $0E, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00);

var
  BmpScreen: TSurfaceScreen;               { 0048A8BC: always nil }
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
  V: TWinVersion;
begin
  Bmp.HandleType := bmDIB;
  Bmp.PixelFormat := pf24bit;
  Exit;
  { NOTE: unreachable in the original as well }
  GetWinVersion(V);
  if (V.IsNT and (V.Major < 4)) or (V.Major = $5F) or (V.Minor = 0) then
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
  Form: TForm;
begin
  inherited CreateSize(AWidth, AHeight);
  FBitmap := TBitmap.Create;
  SetupBitmap(FBitmap);
  FBitmap.Width := AWidth;
  FBitmap.Height := AHeight;
  BitBlt(FBitmap.Canvas.Handle, 0, 0, AWidth, AHeight, FBitmap.Canvas.Handle, 0, 0, BLACKNESS);
  Form := TForm.Create(nil);
  Form.Canvas.Draw(0, 0, FBitmap);
  Form.Free;
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
  C: TRGBQuad;
begin
  C := GetPaletteColor(Index);
  FBitmap.Canvas.Pixels[X, Y] := (C.rgbBlue shl 16) + (C.rgbGreen shl 8) + C.rgbRed;
end;

{ @00461F74 }
function TBmpSurface.GetCanvas: TCanvas;
begin
  Result := FBitmap.Canvas;
end;

{ @00461F80 }
function TBmpSurface.GetPaletteColor(Index: Integer): TRGBQuad;
var
  Entry: TPaletteEntry;
begin
  GetPaletteEntries(FBitmap.Palette, Index, 1, Entry);
  Result.rgbBlue := Entry.peBlue;
  Result.rgbGreen := Entry.peGreen;
  Result.rgbRed := Entry.peRed;
  { NOTE: rgbReserved is left undefined, as in the original }
end;

{ @00461FC0 }
procedure TBmpSurface.SetPaletteColor(Index: Integer; Color: TRGBQuad);
var
  Entry: TPaletteEntry;
begin
  Entry.peBlue := Color.rgbBlue;
  Entry.peGreen := Color.rgbGreen;
  Entry.peRed := Color.rgbRed;
  Entry.peFlags := PC_NOCOLLAPSE;
  SetPaletteEntries(FBitmap.Palette, Index, 1, Entry);
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
  OldBkColor: COLORREF;
  OldPenColor: TColor;
  RGBValue: Integer;
  Tmp: TBitmap;
  X, Y: Integer;
  SrcLine, MaskLine, Line: PByteArray;
  Src, Dst: PInteger;
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
    { give the transparent pixels (blackened by SRCAND below) their colour back }
    OldPenColor := FMask.Canvas.Pen.Color;
    FBitmap.Canvas.Pen.Color := 0;
    OldBkColor := SetBkColor(FBitmap.Canvas.Handle, FTransparentColor);
    BitBlt(FBitmap.Canvas.Handle, 0, 0, FBitmap.Width, FBitmap.Height,
      FMask.Canvas.Handle, 0, 0, SRCPAINT);
    SetBkColor(FBitmap.Canvas.Handle, OldBkColor);
    FBitmap.Canvas.Pen.Color := OldPenColor;
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
  OldBkColor := SetBkColor(FBitmap.Canvas.Handle, FTransparentColor);
  { TColor $00BBGGRR -> $00RRGGBB as stored in a 24-bit scan line }
  RGBValue := ((FTransparentColor and $FF) shl 16) + (FTransparentColor and $FF00) +
    ((FTransparentColor and $FF0000) shr 16);
  FMask.HandleType := bmDIB;
  FMask.PixelFormat := pf24bit;
  Tmp := TBitmap.Create;
  Tmp.HandleType := bmDIB;
  Tmp.PixelFormat := pf24bit;
  Tmp.Width := FBitmap.Width;
  Tmp.Height := FBitmap.Height;
  BitBlt(Tmp.Canvas.Handle, 0, 0, FBitmap.Width, FBitmap.Height,
    FBitmap.Canvas.Handle, 0, 0, SRCCOPY);
  for Y := 0 to Tmp.Height - 1 do
  begin
    SrcLine := Tmp.ScanLine[Y];
    MaskLine := FMask.ScanLine[Y];
    for X := 0 to FBitmap.Width - 1 do
    begin
      Src := PInteger(@SrcLine[X * 3]);
      Dst := PInteger(@MaskLine[X * 3]);
      if X = Tmp.Width - 1 then
      begin
        { last pixel of the line: byte access, a dword would read past the end }
        S0 := @SrcLine[X * 3];
        S1 := S0;
        Inc(S1);
        S2 := S0;
        Inc(S2, 2);
        M0 := @MaskLine[X * 3];
        M1 := M0;
        Inc(M1);
        M2 := M0;
        Inc(M2, 2);
        if ((S0^ + S1^ shl 8 + S2^ shl 16) and $FFFFFF) = (RGBValue and $FFFFFF) then
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
      else if (Src^ and $FFFFFF) = (RGBValue and $FFFFFF) then
        Dst^ := Dst^ or $FFFFFF
      else
        Dst^ := Dst^ and Integer($FF000000);
    end;
  end;
  FMask.Monochrome := True;
  Tmp.Free;
  SetBkColor(FBitmap.Canvas.Handle, OldBkColor);
  if (Value <> 0) and (FTransparentColor <> clNoTransparent) then
  begin
    if FBitmap.PixelFormat = pf8bit then
    begin
      for Y := 0 to FBitmap.Height - 1 do
      begin
        Line := FBitmap.ScanLine[Y];
        for X := 0 to FBitmap.Width - 1 do
          if Line[X] = $FC then
            Line[X] := 0;
      end;
    end
    else
    begin
      { blacken the transparent pixels so the image can be ORed onto the masked target }
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

{ @00462588  Writes the palette as a 256x100 bitmap file (one column per entry). }
procedure TBmpSurface.SavePalette(FileName: string);
var
  F: file;
  Buf: array[0..$6835] of Byte;
  I, Y: Integer;
begin
  for I := 0 to $35 do
    Buf[I] := PaletteBmpHeader[I];
  for I := 0 to 255 do
  begin
    { NOTE: the original reads the colour as a Longint: byte 0, shr 8, shr 16 }
    Buf[$36 + I * 4] := GetPaletteColor(I).rgbBlue;
    Buf[$36 + I * 4 + 1] := GetPaletteColor(I).rgbGreen;
    Buf[$36 + I * 4 + 2] := GetPaletteColor(I).rgbRed;
    Buf[$36 + I * 4 + 3] := 0;
    for Y := 0 to 99 do
      Buf[$436 + I + Y * 256] := I;
  end;
  AssignFile(F, FileName);
  Rewrite(F, 1);
  BlockWrite(F, Buf, SizeOf(Buf));
  CloseFile(F);
end;

{ @004626C0 }
procedure TBmpSurface.CopyFrom(Source: TSurface; SrcRect, DestRect: TRect;
  MirrorX, MirrorY: Boolean);
var
  Src: TBmpSurface;
  A, B: TBmpSurface;
begin
  if not (Source is TBmpSurface) then
    raise Exception.Create('Can only copy from BmpSurfaces');
  Src := Source as TBmpSurface;
  HandleCheck := HandleCheck + Integer(FBitmap.Handle);
  HandleCheck := HandleCheck + Integer(FBitmap.Canvas.Handle);
  A := Src;
  B := Self;
  if A.Blank and B.Blank then
    Exit;
  if B.Blank <> A.Blank then
  begin
    { the blank one adopts the palette of the other }
    if B.Blank then
    begin
      A := Self;
      B := Src;
    end;
    A.Blank := False;
    A.FBitmap.Palette := B.FBitmap.Palette;
  end;
  Src.DrawTo(FBitmap.Canvas.Handle, SrcRect, DestRect, MirrorX, MirrorY);
end;

{ @004627D4 }
procedure SwapInt(var A, B: Integer);
var
  T: Integer;
begin
  T := A;
  A := B;
  B := T;
end;

{ @004627E0 }
class procedure TBmpSurface.StretchDraw(DC: HDC; Mask, Bitmap: TBitmap; SrcRect, DestRect: TRect;
  MirrorX, MirrorY: Boolean);
var
  HasMask: Boolean;
  OldPal, OldBmpPal: HPALETTE;
  OldMode: Integer;
  Rop: DWORD;
begin
  HasMask := Mask <> nil;
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
  if HasMask then
    StretchBlt(DC, DestRect.Left, DestRect.Top, DestRect.Right - DestRect.Left,
      DestRect.Bottom - DestRect.Top, Mask.Canvas.Handle, SrcRect.Left, SrcRect.Top,
      SrcRect.Right - SrcRect.Left, SrcRect.Bottom - SrcRect.Top, SRCAND);
  if Bitmap.Palette <> 0 then
  begin
    OldPal := SelectPalette(DC, Bitmap.Palette, True);
    RealizePalette(DC);
    OldBmpPal := SelectPalette(Bitmap.Canvas.Handle, Bitmap.Palette, True);
    RealizePalette(Bitmap.Canvas.Handle);
  end;
  if HasMask then
    Rop := SRCPAINT
  else
    Rop := SRCCOPY;
  OldMode := SetStretchBltMode(DC, COLORONCOLOR);
  StretchBlt(DC, DestRect.Left, DestRect.Top, DestRect.Right - DestRect.Left,
    DestRect.Bottom - DestRect.Top, Bitmap.Canvas.Handle, SrcRect.Left, SrcRect.Top,
    SrcRect.Right - SrcRect.Left, SrcRect.Bottom - SrcRect.Top, Rop);
  SetStretchBltMode(DC, OldMode);
  if Bitmap.Palette <> 0 then
  begin
    SelectPalette(DC, OldPal, True);
    SelectPalette(Bitmap.Canvas.Handle, OldBmpPal, True);
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
  Src: TBmpSurface;
begin
  if Source is TBmpSurface then
  begin
    Src := Source as TBmpSurface;
    Blank := Src.Blank;
    FBitmap.Assign(Src.FBitmap);
    FTransparentColor := Src.GetTransparentColor;
    if FTransparentColor <> clNoTransparent then
    begin
      if FMask = nil then
        CreateMask;
      FMask.Assign(Src.FMask);
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

{ @00462B20  Accepts a bitmap with or without a 2- or 8-byte prefix before the 'BM'. }
procedure TBmpSurface.LoadFromStream(Stream: TStream);
var
  Sig: Word;
begin
  Stream.Read(Sig, 2);
  if Sig = $4D42 then
    Stream.Seek(-2, soFromCurrent)
  else
  begin
    Stream.Seek(2, soFromCurrent);
    Stream.Read(Sig, 2);
    if Sig = $4D42 then
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
  Tmp: TBitmap;
  OldMode: Integer;
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
    Tmp := TBitmap.Create;
    SetupBitmap(Tmp);
    Tmp.Assign(FBitmap);
    RealizeBitmap(Tmp);
    Tmp.Width := AWidth;
    RealizeBitmap(Tmp);
    Tmp.Height := AHeight;
    RealizeBitmap(Tmp);
    OldMode := SetStretchBltMode(Tmp.Canvas.Handle, COLORONCOLOR);
    StretchBlt(Tmp.Canvas.Handle, 0, 0, AWidth, AHeight, FBitmap.Canvas.Handle, 0, 0,
      FBitmap.Width, FBitmap.Height, SRCCOPY);
    SetStretchBltMode(Tmp.Canvas.Handle, OldMode);
    RealizeBitmap(FBitmap);
    FBitmap.Width := AWidth;
    RealizeBitmap(FBitmap);
    FBitmap.Height := AHeight;
    RealizeBitmap(FBitmap);
    BitBlt(FBitmap.Canvas.Handle, 0, 0, AWidth, AHeight, Tmp.Canvas.Handle, 0, 0, SRCCOPY);
    RealizeBitmap(FBitmap);
    if FMask <> nil then
    begin
      Tmp.Assign(FMask);
      RealizeBitmap(Tmp);
      Tmp.Width := AWidth;
      RealizeBitmap(Tmp);
      Tmp.Height := AHeight;
      OldMode := SetStretchBltMode(Tmp.Canvas.Handle, COLORONCOLOR);
      { NOTE: stretches FBitmap (already resized), not the old mask, into the new mask }
      StretchBlt(Tmp.Canvas.Handle, 0, 0, AWidth, AHeight, FBitmap.Canvas.Handle, 0, 0,
        FBitmap.Width, FBitmap.Height, SRCCOPY);
      SetStretchBltMode(Tmp.Canvas.Handle, OldMode);
      FMask.Assign(Tmp);
    end;
    Tmp.Free;
  end;
end;

{ @00462E3C }
procedure TBmpSurface.TextOut(X, Y: Integer; AFont: TFont; Text: string);
var
  OldTransparent: TColor;
  OldFont: TFont;
begin
  if GetTransparentColor <> clNoTransparent then
  begin
    OldTransparent := GetTransparentColor;
    SetTransparentColor(0);
  end;
  OldFont := TFont.Create;
  OldFont.Assign(FBitmap.Canvas.Font);
  FBitmap.Canvas.Font.Assign(AFont);
  FBitmap.Canvas.TextOut(X, Y, Text);
  FBitmap.Canvas.Font.Assign(OldFont);
  OldFont.Free;
  if GetTransparentColor <> clNoTransparent then
    SetTransparentColor(OldTransparent);
end;

{ @00462F24 }
procedure TBmpSurface.DebugShow(Caption: string);
begin
  ShowBitmap(FBitmap, Caption);
end;

{ @00462F70 }
function TBmpSurface.TextWidth(AFont: TFont; Text: string): Integer;
var
  S: TSurface;
begin
  S := NewSurface;
  S.GetCanvas.Font := AFont;
  Result := S.GetCanvas.TextWidth(Text);
  S.Free;
end;

{ @00462FE4 }
function TBmpSurface.TextHeight(AFont: TFont; Text: string): Integer;
var
  S: TSurface;
begin
  S := NewSurface;
  S.GetCanvas.Font := AFont;
  Result := S.GetCanvas.TextHeight(Text);
  S.Free;
end;

{ @00463058 }
procedure TBmpSurface.FillRect(R: TRect; Color: Byte);
var
  C: Integer;
  Rop: DWORD;
  OldStyle: TBrushStyle;
  OldBrushColor, OldPenColor: TColor;
begin
  C := Color;
  { NOTE: a Byte can never be $FFFFFF }
  if (C = 0) or (C = $FFFFFF) then
  begin
    if C = 0 then
      Rop := BLACKNESS
    else
      Rop := WHITENESS;
    BitBlt(FBitmap.Canvas.Handle, R.Left, R.Top, R.Right - R.Left, R.Bottom - R.Top,
      FBitmap.Canvas.Handle, 0, 0, Rop);
  end
  else
  begin
    C := IndexToColor(C);
    RealizeBitmap(FBitmap);
    OldStyle := FBitmap.Canvas.Brush.Style;
    OldBrushColor := FBitmap.Canvas.Brush.Color;
    OldPenColor := FBitmap.Canvas.Pen.Color;
    FBitmap.Canvas.Brush.Style := bsClear;
    FBitmap.Canvas.Brush.Color := C;
    FBitmap.Canvas.Pen.Color := C;
    FBitmap.Canvas.FillRect(R);
    FBitmap.Canvas.Pen.Color := OldPenColor;
    FBitmap.Canvas.Brush.Style := OldStyle;
    FBitmap.Canvas.Brush.Color := OldBrushColor;
  end;
end;

{ @004631D4 }
initialization
  if SurfaceClass <> nil then
    SurfaceClass := TBmpSurface;
  BmpScreen := nil;
  { NOTE: msimg32.dll is never loaded (the handle is a constant 0 in the original, kept
    in a register), so TransparentBlt is never used }
  MsImgHandle := 0;
  if MsImgHandle <> 0 then
  begin
    @TransparentBltProc := GetProcAddress(MsImgHandle, 'TransparentBlt');
    HasTransparentBlt := True;
  end
  else
    HasTransparentBlt := False;

end.

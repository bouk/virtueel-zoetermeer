program test_bitmap;

{ Compat layer test: 8-bit DIBs with palettes, ScanLine, BitBlt/StretchBlt with
  the raster operations of the sprite engine (mask blits), TBitmap streaming.
  Needs the game data: ZM_DATA=<dir with images/8bits>. }

{$MODE DELPHI}{$H+}

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, ZMWin, ZMData;

var
  F: TForm;
  Bmp, Mask, Mono: TBitmap;
  DC: HDC;
  X, Y, W, H: Integer;
  P: PByteArray;
  T: Byte;
  OutFile, Name: string;
  Fails: Integer;

procedure Check(Cond: Boolean; const Msg: string);
begin
  if not Cond then
  begin
    WriteLn('FAIL: ', Msg);
    Inc(Fails);
  end;
end;

begin
  Fails := 0;
  OutFile := ParamStr(1);
  if OutFile = '' then OutFile := 'test_bitmap.png';
  Name := ZMResolvePath(ZMDataDir + 'images/8bits/K-Sloop_up.bmp');
  Bmp := TBitmap.Create;
  Bmp.LoadFromFile(Name);
  Check(Bmp.PixelFormat = pf8bit, 'the sprite should load as pf8bit');
  W := Bmp.Width;
  H := Bmp.Height;
  WriteLn('loaded ', Name, ' ', W, 'x', H);

  F := TForm.CreateNew(Application);
  F.BorderStyle := bsNone;
  F.Color := clTeal;
  F.SetBounds(0, 0, 1024, 768);
  F.Show;
  Application.ProcessMessages;

  DC := GetDC(F.Handle);
  try
    { plain copy, 8 bit -> screen, and 3x zoom }
    BitBlt(DC, 0, 0, W, H, Bmp.Canvas.Handle, 0, 0, SRCCOPY);
    StretchBlt(DC, 0, 300, W * 3, H * 3, Bmp.Canvas.Handle, 0, 0, W, H, SRCCOPY);
    { stretched half size }
    SetStretchBltMode(DC, COLORONCOLOR);
    StretchBlt(DC, 0, H + 8, W div 2, H div 2, Bmp.Canvas.Handle, 0, 0, W, H, SRCCOPY);
    { transparent blit the classic way: monochrome mask of the top-left colour }
    Mono := TBitmap.Create;
    Mono.Monochrome := True;
    Mono.Width := W;
    Mono.Height := H;
    SetBkColor(Bmp.Canvas.Handle, Bmp.Canvas.Pixels[0, 0]);
    BitBlt(Mono.Canvas.Handle, 0, 0, W, H, Bmp.Canvas.Handle, 0, 0, SRCCOPY);
    Check(Mono.Canvas.Pixels[0, 0] = clWhite, 'mask of background pixel must be white');
    SetBkColor(DC, clWhite);
    SetTextColor(DC, clBlack);
    BitBlt(DC, W div 2 + 16, H + 8, W, H, Bmp.Canvas.Handle, 0, 0, SRCINVERT);
    BitBlt(DC, W div 2 + 16, H + 8, W, H, Mono.Canvas.Handle, 0, 0, SRCAND);
    BitBlt(DC, W div 2 + 16, H + 8, W, H, Bmp.Canvas.Handle, 0, 0, SRCINVERT);
    { ScanLine: invert the palette indices of a copy }
    Mask := TBitmap.Create;
    Mask.Assign(Bmp);
    for Y := 0 to Mask.Height - 1 do
    begin
      P := Mask.ScanLine[Y];
      for X := 0 to Mask.Width - 1 do
        P^[X] := 255 - P^[X];
    end;
    T := PByteArray(Bmp.ScanLine[0])^[0];
    Check(PByteArray(Mask.ScanLine[0])^[0] = 255 - T, 'ScanLine write');
    BitBlt(DC, W + 16, 0, W, H, Mask.Canvas.Handle, 0, 0, SRCCOPY);
    { 24 bit conversion }
    Mask.PixelFormat := pf24bit;
    Check(Mask.PixelFormat = pf24bit, 'pf24bit conversion');
    { text on the screen DC }
    SetBkMode(DC, TRANSPARENT);
    SetTextColor(DC, clYellow);
    TextOut(DC, W + 16, H + 8, 'BitBlt / StretchBlt / mask blit / ScanLine', 42);
  finally
    ReleaseDC(F.Handle, DC);
  end;
  ZMPresent(True);
  ZMSaveScreenshot(OutFile);
  if Fails = 0 then WriteLn('OK test_bitmap -> ', OutFile) else Halt(1);
end.

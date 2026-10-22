program test_bitmap;

{ Test van de compatlaag: 8-bits DIB's met palet, ScanLine, BitBlt/StretchBlt met de
  rasterbewerkingen van de sprite-engine (maskerblits), TBitmap-streaming.
  Vereist de spelgegevens: ZM_DATA=<map met images/8bits>. }

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
  Name := ZMOplosPad(ZMDataMap + 'images/8bits/K-Sloop_up.bmp');
  Bmp := TBitmap.Create;
  Bmp.LoadFromFile(Name);
  Check(Bmp.PixelFormat = pf8bit, 'de sprite moet als pf8bit worden geladen');
  W := Bmp.Width;
  H := Bmp.Height;
  WriteLn('geladen ', Name, ' ', W, 'x', H);

  F := TForm.CreateNew(Application);
  F.BorderStyle := bsNone;
  F.Color := clTeal;
  F.SetBounds(0, 0, 1024, 768);
  F.Show;
  Application.ProcessMessages;

  DC := GetDC(F.Handle);
  try
    { gewone kopie, 8 bits -> scherm, en 3x vergroting }
    BitBlt(DC, 0, 0, W, H, Bmp.Canvas.Handle, 0, 0, SRCCOPY);
    StretchBlt(DC, 0, 300, W * 3, H * 3, Bmp.Canvas.Handle, 0, 0, W, H, SRCCOPY);
    { gestretcht op halve grootte }
    SetStretchBltMode(DC, COLORONCOLOR);
    StretchBlt(DC, 0, H + 8, W div 2, H div 2, Bmp.Canvas.Handle, 0, 0, W, H, SRCCOPY);
    { transparante blit op de klassieke manier: zwart-witmasker van de kleur linksboven }
    Mono := TBitmap.Create;
    Mono.Monochrome := True;
    Mono.Width := W;
    Mono.Height := H;
    SetBkColor(Bmp.Canvas.Handle, Bmp.Canvas.Pixels[0, 0]);
    BitBlt(Mono.Canvas.Handle, 0, 0, W, H, Bmp.Canvas.Handle, 0, 0, SRCCOPY);
    Check(Mono.Canvas.Pixels[0, 0] = clWhite, 'masker van achtergrondpixel moet wit zijn');
    SetBkColor(DC, clWhite);
    SetTextColor(DC, clBlack);
    BitBlt(DC, W div 2 + 16, H + 8, W, H, Bmp.Canvas.Handle, 0, 0, SRCINVERT);
    BitBlt(DC, W div 2 + 16, H + 8, W, H, Mono.Canvas.Handle, 0, 0, SRCAND);
    BitBlt(DC, W div 2 + 16, H + 8, W, H, Bmp.Canvas.Handle, 0, 0, SRCINVERT);
    { ScanLine: keer de palet-indices van een kopie om }
    Mask := TBitmap.Create;
    Mask.Assign(Bmp);
    for Y := 0 to Mask.Height - 1 do
    begin
      P := Mask.ScanLine[Y];
      for X := 0 to Mask.Width - 1 do
        P^[X] := 255 - P^[X];
    end;
    T := PByteArray(Bmp.ScanLine[0])^[0];
    Check(PByteArray(Mask.ScanLine[0])^[0] = 255 - T, 'ScanLine-schrijven');
    BitBlt(DC, W + 16, 0, W, H, Mask.Canvas.Handle, 0, 0, SRCCOPY);
    { conversie naar 24 bits }
    Mask.PixelFormat := pf24bit;
    Check(Mask.PixelFormat = pf24bit, 'conversie naar pf24bit');
    { tekst op de schermhandle (DC) }
    SetBkMode(DC, TRANSPARENT);
    SetTextColor(DC, clYellow);
    TextOut(DC, W + 16, H + 8, 'BitBlt / StretchBlt / mask blit / ScanLine', 42);
  finally
    ReleaseDC(F.Handle, DC);
  end;
  ZMPresenteer(True);
  ZMBewaarSchermafdruk(OutFile);
  if Fails = 0 then WriteLn('OK test_bitmap -> ', OutFile) else Halt(1);
end.

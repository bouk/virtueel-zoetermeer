unit uQuickDirectX;

{ Minimal DirectDraw use: exclusive full-screen mode switching.
  Decompiled from ROS.exe v1.1, code 00477870-00477C5F. }

{$I zm.inc}

interface

uses
  Windows, ddraw;

const
  DirectXActive: Boolean = False;   { 00488F1C }

var
  DirectDraw: IDirectDraw;          { 0048B13C }
  DDErrorText: string;              { 0048B140 }
  DDResult: HResult;                { 0048B144 }

procedure StartDirectX(AWidth, AHeight: Integer);
procedure StopDirectX;

implementation

uses
  SysUtils, Forms, uString;

{ @00477870 }
procedure StartDirectX(AWidth, AHeight: Integer);
var
  DC: HDC;
  Bits: Integer;
  HexText: string;
begin
  if not DirectXActive then
  try
    DC := GetDC(0);
    Bits := GetDeviceCaps(DC, BITSPIXEL);
    ReleaseDC(0, DC);
    if Bits < 8 then
      raise Exception.Create('Not in correct color mode');
    if DirectDrawCreate(nil, DirectDraw, nil) <> DD_OK then
      raise Exception.Create('Failed to create IDirectDraw object');
    DDResult := DirectDraw.SetCooperativeLevel(Application.Handle,
      DDSCL_EXCLUSIVE or DDSCL_FULLSCREEN or DDSCL_ALLOWREBOOT or DDSCL_ALLOWMODEX);
    if DDResult <> DD_OK then
    begin
      HexText := LongToHex(DDResult);   { NOTE: not used }
      case DDResult of
        DDERR_EXCLUSIVEMODEALREADYSET:
          DDErrorText := 'Exclude mode already set';
        DDERR_HWNDALREADYSET:
          DDErrorText := 'HWND already set';
        DDERR_HWNDSUBCLASSED:
          DDErrorText := 'Hwnd Subclasses';
        DDERR_INVALIDOBJECT:
          DDErrorText := 'Invalid Object';
        DDERR_INVALIDPARAMS:
          DDErrorText := 'Invalid Params';
        DDERR_OUTOFMEMORY:
          DDErrorText := 'Out of memory';
      else
        DDErrorText := 'Unknown error';
      end;
      raise Exception.Create('DirectDraw2 SetCooperativeLevel Failed: ' + DDErrorText);
    end;
    if DirectDraw.SetDisplayMode(AWidth, AHeight, 24) <> DD_OK then
      if DirectDraw.SetDisplayMode(AWidth, AHeight, Bits) <> DD_OK then
        raise Exception.Create('Set Display Mode Failed');
    DirectXActive := True;
  except
    DirectXActive := False;
  end;
end;

{ @00477BF4 }
procedure StopDirectX;
begin
  if DirectXActive then
  begin
    DirectDraw.RestoreDisplayMode;
    { NOTE: the original ddraw header was the old class-based one (it uses OLE2), with
      a Release method; _Release is the same vtable slot (+0x08) in interface-based headers }
    DirectDraw._Release;
    { the original clears the variable without another Release }
    Pointer(DirectDraw) := nil;
  end;
end;

end.

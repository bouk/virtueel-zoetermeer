unit uQuickDirectX;

{ Minimaal DirectDrawObject-gebruik: schakelen naar exclusieve volledig-schermmodus.
  Gedecompileerd uit ROS.exe v1.1, code 00477870-00477C5F. }

{$I zm.inc}

interface

uses
  Windows, ddraw;

const
  DirectXActief: Boolean = False;   { 00488F1C }

var
  DirectDrawObject: IDirectDraw;          { 0048B13C }
  DDFoutTekst: string;              { 0048B140 }
  DDResultaat: HResult;                { 0048B144 }

procedure DirectXStarten(AWidth, AHeight: Integer);
procedure DirectXStoppen;

implementation

uses
  SysUtils, Forms, uString;

{ @00477870 }
procedure DirectXStarten(AWidth, AHeight: Integer);
var
  DC: HDC;
  Kleurdiepte: Integer;
  HexTekst: string;
begin
  if not DirectXActief then
  try
    DC := GetDC(0);
    Kleurdiepte := GetDeviceCaps(DC, BITSPIXEL);
    ReleaseDC(0, DC);
    if Kleurdiepte < 8 then
      raise Exception.Create('Not in correct color mode');
    if DirectDrawCreate(nil, DirectDrawObject, nil) <> DD_OK then
      raise Exception.Create('Failed to create IDirectDraw object');
    DDResultaat := DirectDrawObject.SetCooperativeLevel(Application.Handle,
      DDSCL_EXCLUSIVE or DDSCL_FULLSCREEN or DDSCL_ALLOWREBOOT or DDSCL_ALLOWMODEX);
    if DDResultaat <> DD_OK then
    begin
      HexTekst := LongNaarHex(DDResultaat);   { LET OP: niet gebruikt }
      case DDResultaat of
        DDERR_EXCLUSIVEMODEALREADYSET:
          DDFoutTekst := 'Exclude mode already set';
        DDERR_HWNDALREADYSET:
          DDFoutTekst := 'HWND already set';
        DDERR_HWNDSUBCLASSED:
          DDFoutTekst := 'Hwnd Subclasses';
        DDERR_INVALIDOBJECT:
          DDFoutTekst := 'Invalid Object';
        DDERR_INVALIDPARAMS:
          DDFoutTekst := 'Invalid Params';
        DDERR_OUTOFMEMORY:
          DDFoutTekst := 'Out of memory';
      else
        DDFoutTekst := 'Unknown error';
      end;
      raise Exception.Create('DirectDraw2 SetCooperativeLevel Failed: ' + DDFoutTekst);
    end;
    if DirectDrawObject.SetDisplayMode(AWidth, AHeight, 24) <> DD_OK then
      if DirectDrawObject.SetDisplayMode(AWidth, AHeight, Kleurdiepte) <> DD_OK then
        raise Exception.Create('Set Display Mode Failed');
    DirectXActief := True;
  except
    DirectXActief := False;
  end;
end;

{ @00477BF4 }
procedure DirectXStoppen;
begin
  if DirectXActief then
  begin
    DirectDrawObject.RestoreDisplayMode;
    { LET OP: de oorspronkelijke ddraw-header was de oude klassegebaseerde (die OLE2 gebruikt),
      met een Release-methode; _Release is in interface-gebaseerde headers dezelfde vtable-slot
      (+0x08) }
    DirectDrawObject._Release;
    { het origineel maakt de variabele leeg zonder nog een Release }
    Pointer(DirectDrawObject) := nil;
  end;
end;

end.

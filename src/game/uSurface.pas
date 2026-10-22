unit uSurface;

{ TSurface: abstract palet-gebaseerd tekenoppervlak van de sprite-engine (een TGraphic).
  De enige implementatie die in ROS.exe gelinkt is, is TBmpSurface (unit SprBmp).
  Gedecompileerd uit ROS.exe v1.1, code 00463224-0046384F. }

{$I zm.inc}

interface

uses
  Windows, Classes, Graphics;

const
  { markering "geen transparante kleur", gebruikt door alle oppervlakken }
  clNoTransparent = $2FFFFFF;

type
  TSurface = class;
  TSurfaceClass = class of TSurface;

  { Schermobject van een hardware-(DirectDraw-)oppervlakimplementatie, teruggegeven door
    TSurface.GetScreen. Er is geen implementatie ervan gelinkt in ROS.exe (TBmpSurface
    geeft nil terug); alleen de slots die uSpritebox aanroept zijn bekend. }
  TSurfaceScreen = class(TObject)
  public
    procedure Virtual00; virtual; abstract;               { +0x00 }
    function GetBackSurface: TSurface; virtual; abstract;  { +0x04 }
    procedure Virtual08; virtual; abstract;               { +0x08 }
    procedure Flip; virtual; abstract;                    { +0x0C }
  end;

  TSurface = class(TGraphic)
  private
    FReserved1C: Integer;    { +0x1C  wordt door geen enkele code in ROS.exe gebruikt }
    FBlank: Boolean;         { +0x20  oppervlak heeft (nog) geen eigen beeld (en palet) }
    FReserved24: Integer;    { +0x24  niet gebruikt }
    FReserved28: Integer;    { +0x28  niet gebruikt }
    FReserved2C: Integer;    { +0x2C  niet gebruikt }
  protected
    procedure Draw(ACanvas: TCanvas; const ARect: TRect); override;           { +0x14 }
    function GetEmpty: Boolean; override;                                      { +0x1C }
    procedure SetHeight(Value: Integer); override;                             { +0x34 }
    procedure SetWidth(Value: Integer); override;                              { +0x40 }
  public
    constructor Create; override;                                              { +0x0C }
    constructor CreateSize(AWidth, AHeight: Integer); virtual;                 { +0x60 }
    function GetPixel(X, Y: Integer): Integer; virtual; abstract;              { +0x64 }
    procedure SetPixel(X, Y: Integer; Index: Byte); virtual; abstract;         { +0x68 }
    function GetCanvas: TCanvas; virtual; abstract;                            { +0x6C }
    function GetPaletteColor(Index: Integer): TRGBQuad; virtual; abstract;     { +0x70 }
    procedure SetPaletteColor(Index: Integer; Color: TRGBQuad); virtual; abstract; { +0x74 }
    function GetTransparentColor: TColor; virtual; abstract;                   { +0x78 }
    procedure SetTransparentColor(Value: TColor); virtual; abstract;           { +0x7C }
    function GetPaletteHandle: HPALETTE; virtual; abstract;                    { +0x80 }
    function GetHandle: HBITMAP; virtual;                                      { +0x84 }
    class function GetScreen: TSurfaceScreen; virtual;                         { +0x88 }
    function GetPaletteCount: Integer; virtual; abstract;                      { +0x8C }
    procedure DebugShow(Caption: string); virtual; abstract;                   { +0x90 }
    procedure SavePalette(FileName: string); virtual; abstract;                { +0x94 }
    procedure ConvertTo(Target: TSurface); virtual; abstract;                  { +0x98 }
    procedure CopyPalette(Source: TSurface); virtual; abstract;                { +0x9C }
    procedure CopyFrom(Source: TSurface; SrcRect, DestRect: TRect;
      MirrorX, MirrorY: Boolean); virtual; abstract;                           { +0xA0 }
    procedure DrawTo(DC: HDC; SrcRect, DestRect: TRect;
      MirrorX, MirrorY: Boolean); virtual; abstract;                           { +0xA4 }
    procedure SetSize(AWidth, AHeight: Integer; Stretch: Boolean); virtual;    { +0xA8 }
    procedure TextOut(X, Y: Integer; AFont: TFont; Text: string); virtual; abstract; { +0xAC }
    function TextWidth(AFont: TFont; Text: string): Integer; virtual; abstract;  { +0xB0 }
    function TextHeight(AFont: TFont; Text: string): Integer; virtual; abstract; { +0xB4 }
    procedure FillRect(R: TRect; Color: Byte); virtual; abstract;              { +0xB8 }
    procedure Clear(Color: Byte); virtual;                                     { +0xBC }
    procedure DrawSurface(Source: TSurface; X, Y: Integer);
    procedure CopyTo(Dest: TSurface; SrcRect, DestRect: TRect; MirrorX, MirrorY: Boolean);
    function ColorToIndex(Color: TColor): Integer;
    function IndexToColor(Index: Integer): TColor;
    property Blank: Boolean read FBlank write FBlank;
    property Canvas: TCanvas read GetCanvas;
    property TransparentColor: TColor read GetTransparentColor write SetTransparentColor;
    property PaletteColors[Index: Integer]: TRGBQuad read GetPaletteColor write SetPaletteColor;
    property PaletteCount: Integer read GetPaletteCount;
    property Handle: HBITMAP read GetHandle;
  end;

var
  SurfaceClass: TSurfaceClass;   { 0048A8CC: klasse die door NewSurface gebruikt wordt }

function NewSurface: TSurface;
function NewSurfaceSize(AWidth, AHeight: Integer): TSurface;
function SurfaceScreen: TSurfaceScreen;

implementation

uses
  SprBmp;

{ @00463370 }
constructor TSurface.Create;
begin
  CreateSize(1, 1);
end;

{ @004633B0 }
constructor TSurface.CreateSize(AWidth, AHeight: Integer);
begin
  inherited Create;
end;

{ @004633EC }
function TSurface.GetHandle: HBITMAP;
begin
  Result := 0;
end;

{ @004633F0 }
procedure TSurface.Draw(ACanvas: TCanvas; const ARect: TRect);
begin
  DrawTo(ACanvas.Handle,
    Classes.Rect(0, 0, ARect.Right - ARect.Left, ARect.Bottom - ARect.Top),
    ARect, False, False);
end;

{ @0046343C }
procedure TSurface.SetSize(AWidth, AHeight: Integer; Stretch: Boolean);
var
  Tijdelijk: TSurface;
  I: Integer;
  Doel: TRect;
  OudTransparant: TColor;
begin
  Tijdelijk := NewSurfaceSize(AWidth, AHeight);
  for I := 0 to 255 do
    Tijdelijk.SetPaletteColor(I, GetPaletteColor(I));
  Tijdelijk.CopyPalette(Self);
  if Stretch then
    Doel := Classes.Rect(0, 0, AWidth, AHeight)
  else
    Doel := Classes.Rect(0, 0, Width, Height);
  OudTransparant := GetTransparentColor;
  SetTransparentColor(clNoTransparent);
  Tijdelijk.CopyFrom(Self, Classes.Rect(0, 0, Width, Height), Doel, False, False);
  Assign(Tijdelijk);
  SetTransparentColor(OudTransparant);
  Tijdelijk.Free;
end;

{ @00463534 }
procedure TSurface.SetWidth(Value: Integer);
begin
  if Value <> Width then
    SetSize(Value, Height, False);
end;

{ @00463560 }
procedure TSurface.SetHeight(Value: Integer);
begin
  if Value <> Height then
    SetSize(Width, Value, False);
end;

{ @0046358C }
function TSurface.GetEmpty: Boolean;
begin
  if (Width <> 0) and (Height <> 0) then
    Result := False
  else
    Result := True;
end;

{ @004635B0 }
class function TSurface.GetScreen: TSurfaceScreen;
begin
  Result := nil;
end;

{ @004635B4 }
procedure TSurface.DrawSurface(Source: TSurface; X, Y: Integer);
begin
  CopyFrom(Source, Classes.Rect(0, 0, Source.Width, Source.Height),
    Classes.Rect(X, Y, X + Source.Width, Y + Source.Height), False, False);
end;

{ @00463628 }
procedure TSurface.CopyTo(Dest: TSurface; SrcRect, DestRect: TRect; MirrorX, MirrorY: Boolean);
begin
  Dest.CopyFrom(Self, SrcRect, DestRect, MirrorX, MirrorY);
end;

{ @00463674 }
procedure TSurface.Clear(Color: Byte);
begin
  FillRect(Classes.Rect(0, 0, Width, Height), Color);
end;

{ @004636B0 }
function TSurface.ColorToIndex(Color: TColor): Integer;
var
  Blauw, Rood, Groen: Integer;
  BesteAfstand, Afstand, I: Integer;
  Kleur: TRGBQuad;
begin
  Blauw := GetBValue(Color);
  Rood := GetRValue(Color);
  Groen := GetGValue(Color);
  BesteAfstand := 765;
  Result := -1;
  for I := 0 to GetPaletteCount - 1 do
  begin
    Kleur := GetPaletteColor(I);
    Afstand := Abs(Blauw - Kleur.rgbBlue) + Abs(Groen - Kleur.rgbGreen) + Abs(Rood - Kleur.rgbRed);
    if Afstand < BesteAfstand then
    begin
      BesteAfstand := Afstand;
      Result := I;
    end;
  end;
end;

{ @0046377C }
function TSurface.IndexToColor(Index: Integer): TColor;
var
  Kleur: TRGBQuad;
begin
  Kleur := GetPaletteColor(Index);
  { = PaletteRGB(Kleur.rgbRed, Kleur.rgbGreen, Kleur.rgbBlue) }
  Result := ((Kleur.rgbBlue + $200) shl 8 + Kleur.rgbGreen) shl 8 + Kleur.rgbRed;
end;

{ @004637B4 }
function NewSurface: TSurface;
begin
  if SurfaceClass = nil then
    Result := TBmpSurface.Create
  else
    Result := SurfaceClass.Create;
end;

{ @004637D8 }
function NewSurfaceSize(AWidth, AHeight: Integer): TSurface;
begin
  if SurfaceClass = nil then
    Result := TBmpSurface.CreateSize(AWidth, AHeight)
  else
    Result := SurfaceClass.CreateSize(AWidth, AHeight);
end;

{ @00463800 }
function SurfaceScreen: TSurfaceScreen;
begin
  Result := SurfaceClass.GetScreen;
end;

{ @0046383C }
initialization
  SurfaceClass := TBmpSurface;

end.

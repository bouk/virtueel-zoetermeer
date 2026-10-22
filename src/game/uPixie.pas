unit uPixie;

{ TPixie: abstracte basisklasse van alles wat een TSpriteBox tekent (sprites, goblins,
  tekstballonnen, views).
  Gedecompileerd uit ROS.exe v1.1, code 00463850-00463C13. }

{$I zm.inc}

interface

uses
  Windows, Classes, Controls, uSurface;

type
  { Momentopname van de zichtbare toestand van een pixie, gebruikt om te zien wat opnieuw getekend moet worden }
  TPixieStaat = record    { 0x18 bytes }
    Left: Integer;
    Top: Integer;
    Z: Integer;
    Width: Integer;
    Height: Integer;
    Visible: Boolean;
  end;

  TPixie = class(TComponent)
  protected
    { protected, niet private: TSprite.LeesWijziging in uSprite leest en schrijft FState }
    FVisible: Boolean;               { +0x24 }
    FLeft: SmallInt;                 { +0x26 }
    FTop: SmallInt;                  { +0x28 }
    FZVolgorde: SmallInt;                    { +0x2A }
    FState: TPixieStaat;             { +0x2C  toestand bij de laatste LeesWijziging }
    FGereserveerd44: Integer;            { +0x44  niet gebruikt in ROS.exe }
    FOnMouseDown: TMouseEvent;       { +0x48 }
    FOnMouseUp: TMouseEvent;         { +0x50 }
    FOnMouseMove: TMouseMoveEvent;   { +0x58 }
    FOpMuisVerlaten: TNotifyEvent;     { +0x60 }
  public
    procedure SetVisible(Value: Boolean); virtual;                    { +0x30 }
    procedure ZetX(Value: Integer); virtual;                          { +0x34 }
    procedure ZetY(Value: Integer); virtual;                          { +0x38 }
    procedure ZetZ(Value: Integer); virtual;                          { +0x3C }
    function LeesX: Integer; virtual;                                  { +0x40 }
    function LeesY: Integer; virtual;                                  { +0x44 }
    function LeesZ: Integer; virtual;                                  { +0x48 }
    function LeesLinks: Integer; virtual;                               { +0x4C }
    procedure SetLeft(Value: Integer); virtual;                       { +0x50 }
    function LeesBoven: Integer; virtual;                                { +0x54 }
    procedure SetTop(Value: Integer); virtual;                        { +0x58 }
    function GetWidth: Integer; virtual; abstract;                    { +0x5C }
    function GetHeight: Integer; virtual; abstract;                   { +0x60 }
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); virtual; abstract;                              { +0x64 }
    procedure TekenDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); virtual; abstract;                              { +0x68 }
    function Overlapt(R: TRect): Boolean; virtual;                  { +0x6C }
    procedure LeesStaat(var State: TPixieStaat); virtual;              { +0x70 }
    procedure LeesWijziging(var OldState, NewState: TPixieStaat); virtual; { +0x74 }
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); virtual;                                        { +0x78 }
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); virtual;                                        { +0x7C }
    procedure MouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer); virtual;                                        { +0x80 }
    procedure MuisVerlaten; virtual;                                    { +0x84 }
    function GetBoundsRect: TRect;
    property Visible: Boolean read FVisible write SetVisible;
    property X: Integer read LeesX write ZetX;
    property Y: Integer read LeesY write ZetY;
    property Z: Integer read LeesZ write ZetZ;
    property Left: Integer read LeesLinks write SetLeft;
    property Top: Integer read LeesBoven write SetTop;
    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
    property BoundsRect: TRect read GetBoundsRect;
  published
    property OnMouseDown: TMouseEvent read FOnMouseDown write FOnMouseDown;
    property OnMouseMove: TMouseMoveEvent read FOnMouseMove write FOnMouseMove;
    property OnMouseUp: TMouseEvent read FOnMouseUp write FOnMouseUp;
    property OnMouseLeave: TNotifyEvent read FOpMuisVerlaten write FOpMuisVerlaten;
  end;

implementation

{ @004639E4 }
procedure TPixie.SetVisible(Value: Boolean);
begin
  FVisible := Value;
end;

{ @004639E8 }
procedure TPixie.ZetX(Value: Integer);
begin
  SetLeft(Value);
end;

{ @004639F0 }
procedure TPixie.ZetY(Value: Integer);
begin
  SetTop(Value);
end;

{ @004639F8 }
function TPixie.LeesX: Integer;
begin
  Result := LeesLinks;
end;

{ @00463A00 }
function TPixie.LeesY: Integer;
begin
  Result := LeesBoven;
end;

{ @00463A08 }
function TPixie.LeesZ: Integer;
begin
  Result := FZVolgorde;
end;

{ @00463A10 }
procedure TPixie.ZetZ(Value: Integer);
begin
  FZVolgorde := Value;
end;

{ @00463A18 }
function TPixie.LeesLinks: Integer;
begin
  Result := FLeft;
end;

{ @00463A20 }
procedure TPixie.SetLeft(Value: Integer);
begin
  FLeft := Value;
end;

{ @00463A28 }
function TPixie.LeesBoven: Integer;
begin
  Result := FTop;
end;

{ @00463A30 }
procedure TPixie.SetTop(Value: Integer);
begin
  FTop := Value;
end;

{ @00463A38 }
function TPixie.GetBoundsRect: TRect;
begin
  Result := Bounds(LeesLinks, LeesBoven, GetWidth, GetHeight);
end;

{ @00463A68 }
function TPixie.Overlapt(R: TRect): Boolean;
var
  Doel: TRect;
begin
  Result := IntersectRect(Doel, GetBoundsRect, R);
end;

{ @00463AA4 }
procedure TPixie.LeesStaat(var State: TPixieStaat);
begin
  State.Left := LeesLinks;
  State.Top := LeesBoven;
  State.Z := LeesZ;
  State.Width := GetWidth;
  State.Height := GetHeight;
  State.Visible := FVisible;
end;

{ @00463AE4  Geeft de vorige en de huidige toestand terug; wanneer er niets veranderd is,
  worden beide als onzichtbaar gemarkeerd zodat er niets opnieuw getekend wordt. }
procedure TPixie.LeesWijziging(var OldState, NewState: TPixieStaat);
var
  S: TPixieStaat;
begin
  OldState := FState;
  LeesStaat(S);
  FState := S;
  NewState := FState;
  if (NewState.Left = OldState.Left) and (NewState.Top = OldState.Top) and
     (NewState.Z = OldState.Z) and (NewState.Width = OldState.Width) and
     (NewState.Height = OldState.Height) and (NewState.Visible = OldState.Visible) then
  begin
    NewState.Visible := False;
    OldState.Visible := False;
  end;
end;

{ @00463B68 }
procedure TPixie.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if Assigned(FOnMouseMove) then
    FOnMouseMove(Self, Shift, X, Y);
end;

{ @00463B94 }
procedure TPixie.MuisVerlaten;
begin
  if Assigned(FOpMuisVerlaten) then
    FOpMuisVerlaten(Self);
end;

{ @00463BA8 }
procedure TPixie.MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  { LET OP: het origineel test het event maar roept het nooit aan }
  if Assigned(FOnMouseDown) then
    ;
end;

{ @00463BB4 }
procedure TPixie.MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  if Assigned(FOnMouseUp) then
    FOnMouseUp(Self, Button, Shift, X, Y);
end;

end.

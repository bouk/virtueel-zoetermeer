unit uPixie;

{ TPixie: abstract base class of everything a TSpriteBox draws (sprites, goblins,
  text balloons, views).
  Decompiled from ROS.exe v1.1, code 00463850-00463C13. }

{$I zm.inc}

interface

uses
  Windows, Classes, Controls, uSurface;

type
  { Snapshot of the visible state of a pixie, used to detect what must be redrawn }
  TPixieState = record    { 0x18 bytes }
    Left: Integer;
    Top: Integer;
    Z: Integer;
    Width: Integer;
    Height: Integer;
    Visible: Boolean;
  end;

  TPixie = class(TComponent)
  private
    FVisible: Boolean;               { +0x24 }
    FLeft: SmallInt;                 { +0x26 }
    FTop: SmallInt;                  { +0x28 }
    FZ: SmallInt;                    { +0x2A }
    FState: TPixieState;             { +0x2C  state at the last GetChange }
    FReserved44: Integer;            { +0x44  not used in ROS.exe }
    FOnMouseDown: TMouseEvent;       { +0x48 }
    FOnMouseUp: TMouseEvent;         { +0x50 }
    FOnMouseMove: TMouseMoveEvent;   { +0x58 }
    FOnMouseLeave: TNotifyEvent;     { +0x60 }
  public
    procedure SetVisible(Value: Boolean); virtual;                    { +0x30 }
    procedure SetX(Value: Integer); virtual;                          { +0x34 }
    procedure SetY(Value: Integer); virtual;                          { +0x38 }
    procedure SetZ(Value: Integer); virtual;                          { +0x3C }
    function GetX: Integer; virtual;                                  { +0x40 }
    function GetY: Integer; virtual;                                  { +0x44 }
    function GetZ: Integer; virtual;                                  { +0x48 }
    function GetLeft: Integer; virtual;                               { +0x4C }
    procedure SetLeft(Value: Integer); virtual;                       { +0x50 }
    function GetTop: Integer; virtual;                                { +0x54 }
    procedure SetTop(Value: Integer); virtual;                        { +0x58 }
    function GetWidth: Integer; virtual; abstract;                    { +0x5C }
    function GetHeight: Integer; virtual; abstract;                   { +0x60 }
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); virtual; abstract;                              { +0x64 }
    procedure DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); virtual; abstract;                              { +0x68 }
    function Intersects(R: TRect): Boolean; virtual;                  { +0x6C }
    procedure GetState(var State: TPixieState); virtual;              { +0x70 }
    procedure GetChange(var OldState, NewState: TPixieState); virtual; { +0x74 }
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); virtual;                                        { +0x78 }
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); virtual;                                        { +0x7C }
    procedure MouseMove(Sender: TObject; Shift: TShiftState;
      X, Y: Integer); virtual;                                        { +0x80 }
    procedure MouseLeave; virtual;                                    { +0x84 }
    function GetBoundsRect: TRect;
    property Visible: Boolean read FVisible write SetVisible;
    property X: Integer read GetX write SetX;
    property Y: Integer read GetY write SetY;
    property Z: Integer read GetZ write SetZ;
    property Left: Integer read GetLeft write SetLeft;
    property Top: Integer read GetTop write SetTop;
    property Width: Integer read GetWidth;
    property Height: Integer read GetHeight;
    property BoundsRect: TRect read GetBoundsRect;
  published
    property OnMouseDown: TMouseEvent read FOnMouseDown write FOnMouseDown;
    property OnMouseMove: TMouseMoveEvent read FOnMouseMove write FOnMouseMove;
    property OnMouseUp: TMouseEvent read FOnMouseUp write FOnMouseUp;
    property OnMouseLeave: TNotifyEvent read FOnMouseLeave write FOnMouseLeave;
  end;

implementation

{ @004639E4 }
procedure TPixie.SetVisible(Value: Boolean);
begin
  FVisible := Value;
end;

{ @004639E8 }
procedure TPixie.SetX(Value: Integer);
begin
  SetLeft(Value);
end;

{ @004639F0 }
procedure TPixie.SetY(Value: Integer);
begin
  SetTop(Value);
end;

{ @004639F8 }
function TPixie.GetX: Integer;
begin
  Result := GetLeft;
end;

{ @00463A00 }
function TPixie.GetY: Integer;
begin
  Result := GetTop;
end;

{ @00463A08 }
function TPixie.GetZ: Integer;
begin
  Result := FZ;
end;

{ @00463A10 }
procedure TPixie.SetZ(Value: Integer);
begin
  FZ := Value;
end;

{ @00463A18 }
function TPixie.GetLeft: Integer;
begin
  Result := FLeft;
end;

{ @00463A20 }
procedure TPixie.SetLeft(Value: Integer);
begin
  FLeft := Value;
end;

{ @00463A28 }
function TPixie.GetTop: Integer;
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
  Result := Bounds(GetLeft, GetTop, GetWidth, GetHeight);
end;

{ @00463A68 }
function TPixie.Intersects(R: TRect): Boolean;
var
  Dummy: TRect;
begin
  Result := IntersectRect(Dummy, GetBoundsRect, R);
end;

{ @00463AA4 }
procedure TPixie.GetState(var State: TPixieState);
begin
  State.Left := GetLeft;
  State.Top := GetTop;
  State.Z := GetZ;
  State.Width := GetWidth;
  State.Height := GetHeight;
  State.Visible := FVisible;
end;

{ @00463AE4  Returns the previous and the current state; when nothing changed both are
  marked invisible so that nothing gets redrawn. }
procedure TPixie.GetChange(var OldState, NewState: TPixieState);
var
  S: TPixieState;
begin
  OldState := FState;
  GetState(S);
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
procedure TPixie.MouseLeave;
begin
  if Assigned(FOnMouseLeave) then
    FOnMouseLeave(Self);
end;

{ @00463BA8 }
procedure TPixie.MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
begin
  { NOTE: the original tests the event but never calls it }
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

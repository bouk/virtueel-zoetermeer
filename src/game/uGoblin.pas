unit uGoblin;

{ TGoblin: a pixie that fills its area with a tiled surface.
  Decompiled from ROS.exe v1.1, code 0046C478-0046C9CC. }

{$I zm.inc}

interface

uses
  Windows, Classes, uSurface, uPixie, uSpritebox;

type
  TGoblin = class(TPixie)
  private
    FArea: TRect;                   { +0x68  area covered (never set in ROS.exe) }
    FSurface: TSurface;             { +0x78  tile }
    FSpriteBox: TSpriteBox;         { +0x7C }
    FChanged: Boolean;              { +0x80  surface changed: force a redraw }
    procedure SetSpriteBox(Value: TSpriteBox);
    procedure SetSurface(Value: TSurface);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure GetChange(var OldState, NewState: TPixieState); override;
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;
    procedure DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;
    procedure SetZ(Value: Integer); override;
    property Area: TRect read FArea write FArea;
  published
    property SpriteBox: TSpriteBox read FSpriteBox write SetSpriteBox;
    property Surface: TSurface read FSurface write SetSurface;
  end;

implementation

{ @0046C5BC }
constructor TGoblin.Create(AOwner: TComponent);
begin
  FSurface := NewSurface;
  inherited Create(AOwner);
end;

{ @0046C600 }
destructor TGoblin.Destroy;
begin
  FSurface.Free;
  SetSpriteBox(nil);
  inherited Destroy;
end;

{ @0046C638 }
procedure TGoblin.GetChange(var OldState, NewState: TPixieState);
begin
  inherited GetChange(OldState, NewState);
  if FChanged and not OldState.Visible and not NewState.Visible then
  begin
    OldState.Visible := True;
    NewState.Visible := True;
  end;
  FChanged := False;
end;

{ @0046C674 }
procedure TGoblin.SetSpriteBox(Value: TSpriteBox);
begin
  if Value <> FSpriteBox then
  begin
    if FSpriteBox <> nil then
      FSpriteBox.RemovePixie(Self);
    FSpriteBox := Value;
    if FSpriteBox <> nil then
      FSpriteBox.AddPixie(Self);
  end;
end;

{ @0046C6A0 }
procedure TGoblin.SetSurface(Value: TSurface);
begin
  if Value <> FSurface then
  begin
    FSurface.Assign(Value);
    FChanged := True;
  end;
end;

{ @0046C6B8 }
function TGoblin.GetWidth: Integer;
begin
  Result := FArea.Right - FArea.Left;
end;

{ @0046C6C4 }
function TGoblin.GetHeight: Integer;
begin
  Result := FArea.Bottom - FArea.Top;
end;

{ @0046C6D0 }
procedure TGoblin.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Scale: Double);
begin
  DrawDC(Surface.GetCanvas.Handle, DX, DY, ClipRect, Scale);
end;

{ @0046C71C  tiles FSurface over FArea; ClipRect and Scale are ignored }
procedure TGoblin.DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect; Scale: Double);
var
  R: TRect;
  OffsX, OffsY: Integer;
  NX, NY, IX, IY: Integer;
  SX, SY, EX, EY: Integer;
  PosX, PosY: Integer;
begin
  OffsX := FArea.Left - FArea.Left mod FSurface.Width;
  OffsY := FArea.Top - FArea.Top mod FSurface.Height;
  R := Rect(FArea.Left - OffsX, FArea.Top - OffsY, FArea.Right - OffsX,
    FArea.Bottom - OffsY);
  repeat
    if R.Left < 0 then
    begin
      Inc(R.Left, FSurface.Width);
      Inc(R.Right, FSurface.Width);
    end;
    if R.Top < 0 then
    begin
      Inc(R.Top, FSurface.Height);
      Inc(R.Bottom, FSurface.Height);
    end;
  until (R.Top >= 0) and (R.Left >= 0);
  NX := 0;
  repeat
    Inc(NX);
  until FSurface.Width * NX >= R.Right;
  NY := 0;
  repeat
    Inc(NY);
  until FSurface.Height * NY >= R.Bottom;
  PosX := 0;
  for IX := 1 to NX do
  begin
    if IX = 1 then
      SX := R.Left
    else
      SX := 0;
    if IX = NX then
      EX := R.Right - FSurface.Width * (IX - 1)
    else
      EX := FSurface.Width;
    PosY := 0;
    for IY := 1 to NY do
    begin
      if IY = 1 then
        SY := R.Top
      else
        SY := 0;
      if IY = NY then
        EY := R.Bottom - FSurface.Height * (IY - 1)
      else
        EY := FSurface.Height;
      FSurface.DrawTo(DC, Rect(SX, SY, EX, EY),
        Bounds(PosX + DX, PosY + DY, EX - SX, EY - SY), False, False);
      PosY := EY + PosY - SY;
    end;
    PosX := PosX + EX - SX;
  end;
end;

{ @0046C968 }
procedure TGoblin.SetZ(Value: Integer);
begin
  if Value <> GetZ then
  begin
    inherited SetZ(Value);
    if FSpriteBox <> nil then
      FSpriteBox.UpdateZOrder(Self);
  end;
end;

end.

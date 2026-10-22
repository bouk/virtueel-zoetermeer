unit uGoblin;

{ TGoblin: een pixie die zijn gebied vult met een betegeld oppervlak.
  Gedecompileerd uit ROS.exe v1.1, code 0046C478-0046C9CC. }

{$I zm.inc}

interface

uses
  Windows, Classes, uSurface, uPixie, uSpritebox;

type
  TGoblin = class(TPixie)
  private
    FArea: TRect;                   { +0x68  bedekt gebied (wordt nooit gezet in ROS.exe) }
    FSurface: TSurface;             { +0x78  tegel }
    FSpriteBox: TSpriteBox;         { +0x7C }
    FChanged: Boolean;              { +0x80  oppervlak gewijzigd: forceer een hertekening }
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

{ @0046C71C  tegelt FSurface over FArea; ClipRect en Scale worden genegeerd }
procedure TGoblin.DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect; Scale: Double);
var
  Kader: TRect;
  VersX, VersY: Integer;
  AantalX, AantalY, NrX, NrY: Integer;
  BeginX, BeginY, EindX, EindY: Integer;
  PosX, PosY: Integer;
begin
  VersX := FArea.Left - FArea.Left mod FSurface.Width;
  VersY := FArea.Top - FArea.Top mod FSurface.Height;
  Kader := Rect(FArea.Left - VersX, FArea.Top - VersY, FArea.Right - VersX,
    FArea.Bottom - VersY);
  repeat
    if Kader.Left < 0 then
    begin
      Inc(Kader.Left, FSurface.Width);
      Inc(Kader.Right, FSurface.Width);
    end;
    if Kader.Top < 0 then
    begin
      Inc(Kader.Top, FSurface.Height);
      Inc(Kader.Bottom, FSurface.Height);
    end;
  until (Kader.Top >= 0) and (Kader.Left >= 0);
  AantalX := 0;
  repeat
    Inc(AantalX);
  until FSurface.Width * AantalX >= Kader.Right;
  AantalY := 0;
  repeat
    Inc(AantalY);
  until FSurface.Height * AantalY >= Kader.Bottom;
  PosX := 0;
  for NrX := 1 to AantalX do
  begin
    if NrX = 1 then
      BeginX := Kader.Left
    else
      BeginX := 0;
    if NrX = AantalX then
      EindX := Kader.Right - FSurface.Width * (NrX - 1)
    else
      EindX := FSurface.Width;
    PosY := 0;
    for NrY := 1 to AantalY do
    begin
      if NrY = 1 then
        BeginY := Kader.Top
      else
        BeginY := 0;
      if NrY = AantalY then
        EindY := Kader.Bottom - FSurface.Height * (NrY - 1)
      else
        EindY := FSurface.Height;
      FSurface.DrawTo(DC, Rect(BeginX, BeginY, EindX, EindY),
        Bounds(PosX + DX, PosY + DY, EindX - BeginX, EindY - BeginY), False, False);
      PosY := EindY + PosY - BeginY;
    end;
    PosX := PosX + EindX - BeginX;
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

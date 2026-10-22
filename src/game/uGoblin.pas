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
    FGebied: TRect;                   { +0x68  bedekt gebied (wordt nooit gezet in ROS.exe) }
    FOppervlak: TSurface;             { +0x78  tegel }
    FSpriteVak: TSpriteBox;         { +0x7C }
    FGewijzigd: Boolean;              { +0x80  oppervlak gewijzigd: forceer een hertekening }
    procedure ZetSpriteVak(Value: TSpriteBox);
    procedure ZetOppervlak(Value: TSurface);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LeesWijziging(var OldState, NewState: TPixieStaat); override;
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); override;
    procedure TekenDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); override;
    procedure ZetZ(Value: Integer); override;
    property Gebied: TRect read FGebied write FGebied;
  published
    property SpriteBox: TSpriteBox read FSpriteVak write ZetSpriteVak;
    property Surface: TSurface read FOppervlak write ZetOppervlak;
  end;

implementation

{ @0046C5BC }
constructor TGoblin.Create(AOwner: TComponent);
begin
  FOppervlak := NieuwOppervlak;
  inherited Create(AOwner);
end;

{ @0046C600 }
destructor TGoblin.Destroy;
begin
  FOppervlak.Free;
  ZetSpriteVak(nil);
  inherited Destroy;
end;

{ @0046C638 }
procedure TGoblin.LeesWijziging(var OldState, NewState: TPixieStaat);
begin
  inherited LeesWijziging(OldState, NewState);
  if FGewijzigd and not OldState.Visible and not NewState.Visible then
  begin
    OldState.Visible := True;
    NewState.Visible := True;
  end;
  FGewijzigd := False;
end;

{ @0046C674 }
procedure TGoblin.ZetSpriteVak(Value: TSpriteBox);
begin
  if Value <> FSpriteVak then
  begin
    if FSpriteVak <> nil then
      FSpriteVak.VerwijderPixie(Self);
    FSpriteVak := Value;
    if FSpriteVak <> nil then
      FSpriteVak.VoegPixieToe(Self);
  end;
end;

{ @0046C6A0 }
procedure TGoblin.ZetOppervlak(Value: TSurface);
begin
  if Value <> FOppervlak then
  begin
    FOppervlak.Assign(Value);
    FGewijzigd := True;
  end;
end;

{ @0046C6B8 }
function TGoblin.GetWidth: Integer;
begin
  Result := FGebied.Right - FGebied.Left;
end;

{ @0046C6C4 }
function TGoblin.GetHeight: Integer;
begin
  Result := FGebied.Bottom - FGebied.Top;
end;

{ @0046C6D0 }
procedure TGoblin.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Schaalfactor: Double);
begin
  TekenDC(Surface.GetCanvas.Handle, DX, DY, ClipRect, Schaalfactor);
end;

{ @0046C71C  tegelt FOppervlak over FGebied; ClipRect en Schaalfactor worden genegeerd }
procedure TGoblin.TekenDC(DC: HDC; DX, DY: Integer; ClipRect: TRect; Schaalfactor: Double);
var
  Kader: TRect;
  VersX, VersY: Integer;
  AantalX, AantalY, NrX, NrY: Integer;
  BeginX, BeginY, EindX, EindY: Integer;
  PosX, PosY: Integer;
begin
  VersX := FGebied.Left - FGebied.Left mod FOppervlak.Width;
  VersY := FGebied.Top - FGebied.Top mod FOppervlak.Height;
  Kader := Rect(FGebied.Left - VersX, FGebied.Top - VersY, FGebied.Right - VersX,
    FGebied.Bottom - VersY);
  repeat
    if Kader.Left < 0 then
    begin
      Inc(Kader.Left, FOppervlak.Width);
      Inc(Kader.Right, FOppervlak.Width);
    end;
    if Kader.Top < 0 then
    begin
      Inc(Kader.Top, FOppervlak.Height);
      Inc(Kader.Bottom, FOppervlak.Height);
    end;
  until (Kader.Top >= 0) and (Kader.Left >= 0);
  AantalX := 0;
  repeat
    Inc(AantalX);
  until FOppervlak.Width * AantalX >= Kader.Right;
  AantalY := 0;
  repeat
    Inc(AantalY);
  until FOppervlak.Height * AantalY >= Kader.Bottom;
  PosX := 0;
  for NrX := 1 to AantalX do
  begin
    if NrX = 1 then
      BeginX := Kader.Left
    else
      BeginX := 0;
    if NrX = AantalX then
      EindX := Kader.Right - FOppervlak.Width * (NrX - 1)
    else
      EindX := FOppervlak.Width;
    PosY := 0;
    for NrY := 1 to AantalY do
    begin
      if NrY = 1 then
        BeginY := Kader.Top
      else
        BeginY := 0;
      if NrY = AantalY then
        EindY := Kader.Bottom - FOppervlak.Height * (NrY - 1)
      else
        EindY := FOppervlak.Height;
      FOppervlak.TekenNaar(DC, Rect(BeginX, BeginY, EindX, EindY),
        Bounds(PosX + DX, PosY + DY, EindX - BeginX, EindY - BeginY), False, False);
      PosY := EindY + PosY - BeginY;
    end;
    PosX := PosX + EindX - BeginX;
  end;
end;

{ @0046C968 }
procedure TGoblin.ZetZ(Value: Integer);
begin
  if Value <> LeesZ then
  begin
    inherited ZetZ(Value);
    if FSpriteVak <> nil then
      FSpriteVak.VernieuwZVolgorde(Self);
  end;
end;

end.

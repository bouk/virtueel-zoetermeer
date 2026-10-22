unit uSpritebox;

{ TSpriteBox: het besturingselement waarop alle pixies (sprites, goblins,
  tekstballonnen) over een achtergrondafbeelding worden getekend. Elke Flip verzamelt de
  gewijzigde gebieden van alle pixies en tekent alleen die opnieuw, hetzij op een
  DirectDrawObject-scherm (VolledigeWissel/GewijzigdeWissel, niet beschikbaar in deze build) of direct met
  GDI (GDIWissel/TekenGebied). TThreeD voegt een eenvoudige perspectiefprojectie toe.
  Gedecompileerd uit ROS.exe v1.1, code 0046C9CC-0046EA44. }

{$I zm.inc}

interface

uses
  Windows, Messages, Classes, Graphics, Controls, Menus,
  uTool, uSurface, uPixie;

type
  { Perspectief: een punt (X, Y, Z) wordt geprojecteerd naar (XDis, YDis) met
    factor DiaF / (ZDis + Z). }
  TThreeD = class(TPersistent)
  private
    FEnabled: Boolean;              { +0x04 }
    FXAfstand: Integer;                 { +0x08 }
    FYAfstand: Integer;                 { +0x0C }
    FZAfstand: Integer;                 { +0x10 }
    FBrandpunt: Integer;                 { +0x14 }
  public
    procedure Projecteer(X, Y, Z: Integer; var PX, PY: Integer; var Factor: Double);
    procedure Assign(Source: TPersistent); override;
  published
    property Enabled: Boolean read FEnabled write FEnabled;
    property XDis: Integer read FXAfstand write FXAfstand;
    property YDis: Integer read FYAfstand write FYAfstand;
    property ZDis: Integer read FZAfstand write FZAfstand;
    property DiaF: Integer read FBrandpunt write FBrandpunt;
  end;

  THandleBackGround = (hbUsePicture, hbUseColor, hbDontPaint);

  TSpriteBox = class(TCustomControl)
  private
    FGereserveerd1F4: Integer;          { +0x1F4  niet gebruikt }
    FAchterRechthoeken: TRectPosList;       { +0x1F8  gewijzigde gebieden, bewaard voor een schermoppervlak }
    FGewijzigdeRechthoeken: TRectPosList;      { +0x1FC  gewijzigde gebieden sinds de laatste flip }
    FAutoWissel: Boolean;             { +0x200 }
    FBevroren: Boolean;               { +0x201  Flip doet niets (wordt nooit gezet) }
    FCenter: Boolean;               { +0x202 }
    FAutoSize: Boolean;             { +0x203 }
    FStretch: Boolean;              { +0x204 }
    FPicture: TSurface;             { +0x208  achtergrond }
    FPaletAfbeelding: TSurface;        { +0x20C }
    FPalette: HPALETTE;             { +0x210  halftone-palet }
    FGereserveerd214: Boolean;          { +0x214  op False gezet, nooit gelezen }
    FPixies: TList;                 { +0x218  gesorteerd op Z, hoogste eerst }
    FGereserveerd21C: TRect;            { +0x21C  niet gebruikt }
    FWisselModus: Byte;                { +0x22C  0: VolledigeWissel, 1: GewijzigdeWissel (wordt nooit gezet) }
    FTekenVenster: HWND;              { +0x230  venster om op te tekenen in plaats van Handle (wordt nooit gezet) }
    FDrieD: TThreeD;               { +0x234 }
    FHerladen: string;                { +0x238 }
    FGestart: Boolean;              { +0x23C  eerste Paint uitgevoerd }
    FOnWissel: TNotifyEvent;          { +0x240 }
    FOnGestart: TNotifyEvent;       { +0x248 }
    FOnShow: TNotifyEvent;          { +0x250 }
    FSchaal: Double;                 { +0x258 }
    FVastlegPixie: TPixie;          { +0x260  pixie die de muis heeft vastgelegd }
    FMuisPixie: TPixie;            { +0x264  pixie onder de muis }
    FFrameTijd: Integer;            { +0x268  gladgestreken ms per flip }
    FLaatsteTik: Integer;             { +0x26C }
    FAchtergrondModus: THandleBackGround; { +0x270 }
    FAchtergrondKleur: TColor;       { +0x274 }
    procedure WMEraseBkgnd(var Message: TWMEraseBkgnd); message WM_ERASEBKGND;
    procedure WMGestart(var Message: TMessage); message WM_USER + 2;
    procedure SetAutoSize(Value: Boolean);
    procedure ZetAutoWissel(Value: Boolean);
    procedure SetPicture(Value: TSurface);
    procedure ZetPaletAfbeelding(Value: TSurface);
    procedure VoegVernieuwingToe(R: TRect);
    procedure VoegRechthoekenSamen(Lijst: TRectPosList);
    procedure TekenGebied(DC: HDC; R: TRect; VersX, VersY: Integer);
    function ZRichting(Nr: Integer): Integer;
    procedure VernieuwZVolgordeOp(Nr: Integer);
  protected
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Paint; override;
    procedure MaakStaatOngeldig(State: TPixieStaat); virtual;              { +0xB8 }
    procedure TekenAchtergrond(Source: TSurface; DC: HDC;
      SrcRect, DestRect: TRect); virtual;                                { +0xBC }
    procedure VolledigeWissel; virtual;                                         { +0xC0 }
    procedure GewijzigdeWissel; virtual;                                        { +0xC4 }
    procedure GDIWissel; virtual;                                          { +0xC8 }
    procedure Flip; virtual;                                             { +0xCC }
    procedure MaakGebiedOngeldig(R: TRect; Z: Integer); virtual;             { +0xD0 }
    function GeenAfbeelding: Boolean;
    function LeesPixie(Nr: Integer): TPixie;
    function PixieAantal: Integer;
    function LeesTekenVenster: HWND;
    procedure InvalidateRect(R: TRect);
    function ZoekPixie(X, Y: Integer): TPixie;
    function PixieOp(X, Y: Integer): TPixie;
    procedure VoegPixieToe(Pixie: TPixie);
    procedure VerwijderPixie(Pixie: TPixie);
    procedure VernieuwZVolgorde(Pixie: TPixie);
    procedure VernieuwPalet(Achtergrond: Boolean);
    procedure ZetVastlegPixie(Pixie: TPixie);
    property Count: Integer read PixieAantal;
    property Items[Nr: Integer]: TPixie read LeesPixie;
    property Canvas;
    property Schaalfactor: Double read FSchaal write FSchaal;
    property FrameTijd: Integer read FFrameTijd;
    property VastlegPixie: TPixie read FVastlegPixie write ZetVastlegPixie;
    property MuisPixie: TPixie read FMuisPixie;
    property TekenVenster: HWND read FTekenVenster write FTekenVenster;
    property WisselModus: Byte read FWisselModus write FWisselModus;
    property Bevroren: Boolean read FBevroren write FBevroren;
  published
    property ThreeD: TThreeD read FDrieD write FDrieD;
    property Align default alNone;
    property AutoFlip: Boolean read FAutoWissel write ZetAutoWissel;
    property AutoSize: Boolean read FAutoSize write SetAutoSize default False;
    property Center: Boolean read FCenter write FCenter default False;
    property DragCursor;
    property DragMode;
    property Enabled;
    property ParentShowHint;
    property Picture: TSurface read FPicture write SetPicture;
    property PaletteImage: TSurface read FPaletAfbeelding write ZetPaletAfbeelding;
    property Reload: string read FHerladen write FHerladen;
    property PopupMenu;
    property ShowHint;
    property Stretch: Boolean read FStretch write FStretch default False;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnFlip: TNotifyEvent read FOnWissel write FOnWissel;
    property OnStarted: TNotifyEvent read FOnGestart write FOnGestart;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
    property HandleBackGround: THandleBackGround read FAchtergrondModus write FAchtergrondModus;
    property BackGroundColor: TColor read FAchtergrondKleur write FAchtergrondKleur;
  end;

  TSpriteBoxList = class(TList)
  public
    function Add(Box: TSpriteBox): TSpriteBox;
    function LeesSpriteBox(Nr: Integer): TSpriteBox;
    procedure AlleWisselen;
    property SpriteBoxen[Nr: Integer]: TSpriteBox read LeesSpriteBox; default;
  end;

var
  TijdelijkVlak: TSurface;            { 0048A934  werkoppervlak van TekenGebied }
  SpriteBoxen: TSpriteBoxList;      { 0048A938 }
  OudeExitProc: Pointer;             { 0048A940 }

implementation

uses
  SysUtils, Forms, MMSystem, uTiming, uSprite, uTextBalloon, uGoblin;

{$J+}
const
  TekenDiepte: Integer = 0;           { 00488E78  nesting van TekenGebied, begrensd op 5 }
{$J-}

{ ----------------------------------------------------------------- TSpriteBox }

{ @0046D1A8 }
constructor TSpriteBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csAcceptsControls];
  FSchaal := 1.0;
  Width := 320;
  Height := 240;
  FGereserveerd214 := False;
  FAchterRechthoeken := TRectPosList.Create;
  FGewijzigdeRechthoeken := TRectPosList.Create;
  FPixies := TList.Create;
  FLaatsteTik := GetTickCount;
  FDrieD := TThreeD.Create;
  FPicture := NieuwOppervlak;
  FPalette := 0;
  if FPicture = nil then
    raise Exception.Create('Could not create surface');
  SpriteBoxen.Add(Self);
end;

{ @0046D2D4 }
destructor TSpriteBox.Destroy;
var
  I: Integer;
begin
  for I := PixieAantal - 1 downto 0 do
    if LeesPixie(I) is TSprite then
      (LeesPixie(I) as TSprite).SpriteBox := nil
    else if LeesPixie(I) is TTextBalloon then
      (LeesPixie(I) as TTextBalloon).SpriteBox := nil
    else if LeesPixie(I) is TGoblin then
      (LeesPixie(I) as TGoblin).SpriteBox := nil;
  FPixies.Free;
  FAchterRechthoeken.Free;
  FGewijzigdeRechthoeken.Free;
  FDrieD.Free;
  FPicture.Free;
  SpriteBoxen.Remove(Self);
  if FPalette <> 0 then
  begin
    DeleteObject(FPalette);
    FPalette := 0;
  end;
  inherited Destroy;
end;

{ @0046D410 }
function TSpriteBox.GeenAfbeelding: Boolean;
begin
  Result := FPicture = nil;
end;

{ @0046D41C }
function TSpriteBox.LeesPixie(Nr: Integer): TPixie;
begin
  Result := TObject(FPixies[Nr]) as TPixie;
end;

{ @0046D440 }
function TSpriteBox.PixieAantal: Integer;
begin
  Result := FPixies.Count;
end;

{ @0046D44C }
procedure TSpriteBox.WMEraseBkgnd(var Message: TWMEraseBkgnd);
begin
  if csDesigning in ComponentState then
  begin
    Message.Result := 0;
    inherited;
  end;
end;

{ @0046D460  gepost door de eerste Paint: start de timerlus }
procedure TSpriteBox.WMGestart(var Message: TMessage);
begin
  if not (csDesigning in ComponentState) then
  begin
    if Assigned(FOnGestart) then
      FOnGestart(Self);
    Flip;
    InvalidateRect(Rect(0, 0, Width, Height));
    SnelleTimerLus(nil);
  end;
end;

{ @0046D4BC }
procedure TSpriteBox.SetAutoSize(Value: Boolean);
begin
  FAutoSize := Value;
  if (csDesigning in ComponentState) and not (csLoading in ComponentState) and
    FAutoSize then
  begin
    Width := FPicture.Width;
    Height := FPicture.Height;
  end;
end;

{ ------------------------------------------------------------------- TThreeD }

{ @0046D504 }
procedure TThreeD.Projecteer(X, Y, Z: Integer; var PX, PY: Integer; var Factor: Double);
begin
  PX := (X - FXAfstand) * FBrandpunt div (FZAfstand + Z) + FXAfstand;
  PY := (Y - FYAfstand) * FBrandpunt div (FZAfstand + Z) + FYAfstand;
  Factor := FBrandpunt / (FZAfstand + Z);
end;

{ @0046D564 }
procedure TThreeD.Assign(Source: TPersistent);
begin
  if not (Source is TThreeD) then
    inherited Assign(Source)
  else
    with Source as TThreeD do
    begin
      Self.FEnabled := FEnabled;
      Self.FXAfstand := FXAfstand;
      Self.FYAfstand := FYAfstand;
      Self.FZAfstand := FZAfstand;
      Self.FBrandpunt := FBrandpunt;
    end;
end;

{ ----------------------------------------------------------------- TSpriteBox }

{ @0046D5B8 }
procedure TSpriteBox.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPixie;
begin
  P := PixieOp(X, Y);
  if P <> nil then
    P.MouseDown(P, Button, Shift, X - P.LeesLinks, Y - P.LeesBoven);
  inherited MouseDown(Button, Shift, X, Y);
end;

{ @0046D620 }
procedure TSpriteBox.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  P: TPixie;
begin
  P := PixieOp(X, Y);
  if P <> nil then
    P.MouseMove(P, Shift, X - P.LeesLinks, Y - P.LeesBoven);
  if (P <> FMuisPixie) and (FMuisPixie <> nil) then
    FMuisPixie.MuisVerlaten;
  FMuisPixie := P;
  inherited MouseMove(Shift, X, Y);
end;

{ @0046D6A8 }
procedure TSpriteBox.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  P: TPixie;
begin
  P := PixieOp(X, Y);
  if P <> nil then
    if P <> nil then   { LET OP: in het origineel tweemaal getest }
      P.MouseUp(P, Button, Shift, X - P.LeesLinks, Y - P.LeesBoven);
  inherited MouseUp(Button, Shift, X, Y);
end;

{ @0046D714 }
procedure TSpriteBox.Paint;
begin
  if not FGestart then
  begin
    FGestart := True;
    if Assigned(FOnShow) then
      FOnShow(Self);
    PostMessage(Handle, WM_USER + 2, 0, 0);
  end;
  if csDesigning in ComponentState then
  begin
    Canvas.Pen.Style := psDash;
    Canvas.Brush.Style := bsClear;
    Canvas.Rectangle(0, 0, Width, Height);
  end;
  if not (csDesigning in ComponentState) or not FPicture.Empty then
    if csDesigning in ComponentState then
      TekenGebied(Canvas.Handle, Rect(0, 0, Width, Height), 0, 0)
    else
      InvalidateRect(Rect(0, 0, Width, Height));
end;

{ @0046D800 }
procedure TSpriteBox.VoegVernieuwingToe(R: TRect);
begin
  if (R.Right - R.Left > 0) and (R.Bottom - R.Top > 0) then
  begin
    if OppervlakScherm <> nil then
      FAchterRechthoeken.VoegRectToe(R);
    FGewijzigdeRechthoeken.VoegRectToe(R);
  end;
end;

{ @0046D858 }
procedure TSpriteBox.ZetAutoWissel(Value: Boolean);
begin
  if Value <> FAutoWissel then
  begin
    if not Value then
      Flip;
    FAutoWissel := Value;
  end;
end;

{ @0046D880  voegt overlappende rechthoeken samen; samengevoegde krijgen X = -9999 }
procedure TSpriteBox.VoegRechthoekenSamen(Lijst: TRectPosList);
var
  I, J: Integer;
  A, B: TRectPos;
  T: DWORD;
begin
  T := timeGetTime;   { LET OP: overblijfsel van timing, niet gebruikt }
  for I := Lijst.Count - 1 downto 1 do
    for J := I - 1 downto 0 do
    begin
      A := TRectPos(TList(Lijst)[I]);
      if A.X <> -9999 then
      begin
        B := TRectPos(TList(Lijst)[J]);
        if B.Overlapt(A) then
        begin
          B.Vereniging(A);
          A.X := -9999;
          Break;
        end;
      end;
    end;
  T := timeGetTime;
end;

{ @0046D900 }
function TSpriteBox.LeesTekenVenster: HWND;
begin
  if FTekenVenster <> 0 then
    Result := FTekenVenster
  else
    Result := Handle;
end;

{ @0046D914  tekent alles opnieuw op het schermoppervlak }
procedure TSpriteBox.VolledigeWissel;
var
  RP: TRectPos;
  I: Integer;
  P: TPixie;
  PX, PY: Integer;
  Schaal: Double;
begin
  if FAchterRechthoeken.Count <> 0 then
  begin
    LijstVrijgeven(FGewijzigdeRechthoeken);
    LijstVrijgeven(FAchterRechthoeken);
    FPicture.SetTransparentColor(clGeenTransparant);
    OppervlakScherm.LeesAchterOppervlak.KopieerVan(FPicture, Rect(0, 0, Width - 1, Height - 1),
      Rect(0, 0, Width - 1, Height - 1), False, False);
    RP := TRectPos.Create(0, 0, 0, 0);   { LET OP: wordt nooit vrijgegeven }
    for I := 0 to FPixies.Count - 1 do
    begin
      P := LeesPixie(I);
      if P.Visible then
      begin
        if not FDrieD.Enabled then
        begin
          RP.SetRect(LeesPixie(I).GetBoundsRect);
          Schaal := 1.0;
        end
        else
        begin
          FDrieD.Projecteer(P.LeesLinks, P.LeesBoven, P.LeesZ, PX, PY, Schaal);
          RP.SetRect(Bounds(PX, PY, Round(LeesPixie(I).GetWidth * Schaal),
            Round(LeesPixie(I).GetHeight * Schaal)));
        end;
        P.Draw(OppervlakScherm.LeesAchterOppervlak, 0, 0, RP.LeesRect, Schaal);
      end;
    end;
    OppervlakScherm.Flip;
  end;
end;

{ @0046DB0C  tekent de gewijzigde gebieden opnieuw op het schermoppervlak }
procedure TSpriteBox.GewijzigdeWissel;
var
  RP: TRectPos;
  I, J: Integer;
  P: TPixie;
  PX, PY: Integer;
  Schaal: Double;
  Geraakt: Boolean;
  Tijdelijk: TRectPosList;
begin
  if FAchterRechthoeken.Count <> 0 then
  begin
    VoegRechthoekenSamen(FGewijzigdeRechthoeken);
    FPicture.SetTransparentColor(clGeenTransparant);
    for I := 0 to FGewijzigdeRechthoeken.Count - 1 do
      if FGewijzigdeRechthoeken[I].X <> -9999 then
        if GeenAfbeelding then
          OppervlakScherm.LeesAchterOppervlak.FillRect(FGewijzigdeRechthoeken[I].LeesRect, 0)
        else
          OppervlakScherm.LeesAchterOppervlak.KopieerVan(FPicture, FGewijzigdeRechthoeken[I].LeesRect,
            FGewijzigdeRechthoeken[I].LeesRect, False, False);
    RP := TRectPos.Create(0, 0, 0, 0);   { LET OP: wordt nooit vrijgegeven }
    for I := 0 to FPixies.Count - 1 do
    begin
      P := LeesPixie(I);
      if P.Visible then
      begin
        if not FDrieD.Enabled then
        begin
          RP.SetRect(LeesPixie(I).GetBoundsRect);
          Schaal := 1.0;
        end
        else
        begin
          FDrieD.Projecteer(P.LeesLinks, P.LeesBoven, P.LeesZ, PX, PY, Schaal);
          RP.SetRect(Bounds(PX, PY, Round(LeesPixie(I).GetWidth * Schaal),
            Round(LeesPixie(I).GetHeight * Schaal)));
        end;
        Geraakt := False;
        for J := 0 to FGewijzigdeRechthoeken.Count - 1 do
          if FGewijzigdeRechthoeken[J].X <> -9999 then
            if RP.Overlapt(TRectPos(TList(FGewijzigdeRechthoeken)[J])) then
            begin
              Geraakt := True;
              Break;
            end;
        if Geraakt then
          P.Draw(OppervlakScherm.LeesAchterOppervlak, 0, 0, RP.LeesRect, Schaal);
      end;
    end;
    OppervlakScherm.Flip;
    LijstVrijgeven(FGewijzigdeRechthoeken);
    Tijdelijk := FGewijzigdeRechthoeken;
    FGewijzigdeRechthoeken := FAchterRechthoeken;
    FAchterRechthoeken := Tijdelijk;
  end;
end;

{ @0046DE00  tekent de gewijzigde gebieden direct opnieuw op het venster }
procedure TSpriteBox.GDIWissel;
var
  Venster: HWND;
  DC: HDC;
  I: Integer;
begin
  if FGewijzigdeRechthoeken.Count <> 0 then
  begin
    VoegRechthoekenSamen(FGewijzigdeRechthoeken);
    Venster := LeesTekenVenster;
    DC := GetDC(Venster);
    for I := 0 to FGewijzigdeRechthoeken.Count - 1 do
      if FGewijzigdeRechthoeken[I].X <> -9999 then
        TekenGebied(DC, FGewijzigdeRechthoeken[I].LeesRect, 0, 0);
    ReleaseDC(Venster, DC);
    LijstVrijgeven(FGewijzigdeRechthoeken);
  end;
end;

{ @0046DEA8 }
procedure TSpriteBox.MaakStaatOngeldig(State: TPixieStaat);
var
  PX, PY: Integer;
  Factor: Double;
begin
  if State.Visible then
    if not FDrieD.Enabled then
      InvalidateRect(Bounds(State.Left, State.Top, State.Width, State.Height))
    else
    begin
      FDrieD.Projecteer(State.Left, State.Top, State.Z, PX, PY, Factor);
      InvalidateRect(Bounds(PX, PY, Round(State.Width * Factor),
        Round(State.Height * Factor)));
    end;
end;

{ @0046DF60  verzamelt de wijzigingen van alle pixies en tekent ze opnieuw }
procedure TSpriteBox.Flip;
var
  P: TPoint;
  Venster: HWND;
  I: Integer;
  OudeStaat, NieuweStaat: TPixieStaat;
  T: Integer;
begin
  GetCursorPos(P);
  Venster := WindowFromPoint(P);
  if (Venster <> LeesTekenVenster) and (FMuisPixie <> nil) then
  begin
    FMuisPixie.MuisVerlaten;
    FMuisPixie := nil;
  end;
  if not FBevroren then
  begin
    for I := FPixies.Count - 1 downto 0 do
    begin
      LeesPixie(I).LeesWijziging(OudeStaat, NieuweStaat);
      MaakStaatOngeldig(OudeStaat);
      MaakStaatOngeldig(NieuweStaat);
    end;
    T := GetTickCount;
    FFrameTijd := Round(FFrameTijd * 0.8 + (T - FLaatsteTik) * 0.2);
    FLaatsteTik := T;
    if Assigned(FOnWissel) then
      FOnWissel(Self);
    if OppervlakScherm = nil then
      GDIWissel
    else
      case FWisselModus of
        0: VolledigeWissel;
        1: GewijzigdeWissel;
      end;
  end;
end;

{ @0046E0B0 }
procedure TSpriteBox.InvalidateRect(R: TRect);
begin
  if (R.Left = 0) and (R.Right = 0) then   { LET OP: Right, niet Top }
    R.Left := 1;
  MaakGebiedOngeldig(R, -9999);
end;

{ @0046E0F0  Z = -9999: R staat al in schermcoordinaten }
procedure TSpriteBox.MaakGebiedOngeldig(R: TRect; Z: Integer);
var
  PX, PY, W, H: Integer;
  Factor: Double;
begin
  if FDrieD.Enabled and (Z <> -9999) then
  begin
    FDrieD.Projecteer(R.Left, R.Top, Z, PX, PY, Factor);
    W := Round((R.Right - R.Left) * Factor);
    H := Round((R.Bottom - R.Top) * Factor) + PY;
    R := Rect(PX, PY, PX + W, H);
  end;
  if R.Left < 0 then
    R.Left := 0;
  if R.Top < 0 then
    R.Top := 0;
  if Width < R.Right then
    R.Right := Width;
  if Height < R.Bottom then
    R.Bottom := Height;
  VoegVernieuwingToe(R);
  if FAutoWissel then
    Flip;
end;

{ @0046E1E4 }
procedure TSpriteBox.TekenAchtergrond(Source: TSurface; DC: HDC;
  SrcRect, DestRect: TRect);
begin
  if FSchaal <> 1 then
  begin
    DestRect.Left := Round(DestRect.Left * FSchaal);
    DestRect.Right := Round(DestRect.Right * FSchaal);
    DestRect.Top := Round(DestRect.Top * FSchaal);
    DestRect.Bottom := Round(DestRect.Bottom * FSchaal);
  end;
  VernieuwPalet(False);
  Source.TekenNaar(DC, SrcRect, DestRect, False, False);
end;

{ @0046E294  tekent achtergrond en pixies van R (venstercoordinaten + verschuiving)
  via TijdelijkVlak, of recursief per pixie als TijdelijkVlak te klein is }
procedure TSpriteBox.TekenGebied(DC: HDC; R: TRect; VersX, VersY: Integer);
var
  GebruikTemp: Boolean;
  BronR, DoelR, PR, Tijdelijk: TRect;
  Vlak: TSurface;
  I: Integer;
  P: TPixie;
  PX, PY, W, H: Integer;
  Schaal: Double;
begin
  Inc(TekenDiepte);
  if TekenDiepte > 5 then
    TekenDiepte := 5;
  R.Right := IMinimum(R.Right, Width);
  R.Bottom := IMinimum(R.Bottom, Height);
  R.Top := IMaximum(0, R.Top);
  R.Left := IMaximum(0, R.Left);
  if TijdelijkVlak = nil then
    TijdelijkVlak := NieuwOppervlak;
  if (TijdelijkVlak.Height < Screen.Height) or (TijdelijkVlak.Width < Screen.Width) then
  begin
    TijdelijkVlak.Width := Screen.Width;
    TijdelijkVlak.Height := Screen.Height;
  end;
  GebruikTemp := (TijdelijkVlak.Width >= R.Right - R.Left) and
    (TijdelijkVlak.Height >= R.Bottom - R.Top);
  if RechthoekBreedte(R) > TijdelijkVlak.Width then
    GebruikTemp := True;
  if RechthoekHoogte(R) > TijdelijkVlak.Height then
    GebruikTemp := True;
  BronR := Rect(R.Left - VersX, R.Top - VersY, R.Right - VersX, R.Bottom - VersY);
  if GebruikTemp then
    DoelR := Rect(0, 0, R.Right - R.Left, R.Bottom - R.Top)
  else
    DoelR := Rect(R.Left - VersX, R.Top - VersY, R.Right - VersX, R.Bottom - VersY);
  Vlak := TijdelijkVlak;
  if GeenAfbeelding then
  begin
    if GebruikTemp then
      Vlak.FillRect(DoelR, 0)
    else
      { LET OP: de doel-Y is in het origineel R.Right }
      BitBlt(DC, R.Left, R.Right, R.Right - R.Left, R.Bottom - R.Top, DC, 0, 0, BLACKNESS);
  end
  else if GebruikTemp then
    case FAchtergrondModus of
      hbUsePicture:
        begin
          Vlak.SetTransparentColor(clGeenTransparant);
          Vlak.KopieerVan(FPicture, BronR, DoelR, False, False);
        end;
      hbUseColor: ;
      hbDontPaint: ;
    end
  else
    TekenAchtergrond(FPicture, DC, DoelR, R);
  for I := 0 to FPixies.Count - 1 do
  begin
    P := LeesPixie(I);
    if P.Visible then
    begin
      if not FDrieD.Enabled then
      begin
        PR := LeesPixie(I).GetBoundsRect;
        Schaal := 1.0;
        PX := P.LeesLinks;
        PY := P.LeesBoven;
        W := LeesPixie(I).GetWidth;    { LET OP: W en H worden hier niet gebruikt }
        H := LeesPixie(I).GetHeight;
      end
      else
      begin
        FDrieD.Projecteer(P.LeesLinks, P.LeesBoven, P.LeesZ, PX, PY, Schaal);
        W := Round(LeesPixie(I).GetWidth * Schaal);
        H := Round(LeesPixie(I).GetHeight * Schaal);
        PR := Rect(PX, PY, PX + W, PY + H);
      end;
      if IntersectRect(Tijdelijk, PR, BronR) then
        if GebruikTemp then
          P.Draw(Vlak, PX + VersX - R.Left, PY + VersY - R.Top, DoelR, Schaal)
        else
          TekenGebied(DC, PR, VersX, VersY);
    end;
  end;
  if GebruikTemp then
  begin
    Vlak.SetTransparentColor(clGeenTransparant);
    TekenAchtergrond(Vlak, DC, DoelR, R);
  end;
  Dec(TekenDiepte);
end;

{ @0046E690  bovenste zichtbare pixie op (X, Y) }
function TSpriteBox.ZoekPixie(X, Y: Integer): TPixie;
var
  I: Integer;
  R: TRect;
begin
  for I := PixieAantal - 1 downto 0 do
  begin
    R := LeesPixie(I).GetBoundsRect;
    if LeesPixie(I).Visible and (X >= R.Left) and (X <= R.Right) and
      (Y >= R.Top) and (Y <= R.Bottom) then
    begin
      Result := LeesPixie(I);
      Exit;
    end;
  end;
  Result := nil;
end;

{ @0046E700 }
function TSpriteBox.PixieOp(X, Y: Integer): TPixie;
begin
  if FVastlegPixie = nil then
    Result := ZoekPixie(X, Y)
  else
    Result := FVastlegPixie;
end;

{ @0046E718 }
procedure TSpriteBox.VoegPixieToe(Pixie: TPixie);
begin
  VernieuwZVolgordeOp(FPixies.Add(Pixie));
end;

{ @0046E734 }
procedure TSpriteBox.VerwijderPixie(Pixie: TPixie);
var
  OudeStaat, NieuweStaat: TPixieStaat;
begin
  Pixie.LeesWijziging(OudeStaat, NieuweStaat);
  if Pixie = FMuisPixie then
  begin
    FMuisPixie.MuisVerlaten;
    FMuisPixie := nil;
  end;
  OudeStaat.Visible := True;
  MaakStaatOngeldig(OudeStaat);
  FPixies.Remove(Pixie);
end;

{ @0046E78C }
procedure TSpriteBox.SetPicture(Value: TSurface);
begin
  FPicture := Value;
  Paint;
end;

{ @0046E7A4 }
procedure TSpriteBox.ZetPaletAfbeelding(Value: TSurface);
begin
  if FPaletAfbeelding = nil then
    FPaletAfbeelding := NieuwOppervlak;
  FPaletAfbeelding.Assign(Value);
end;

{ @0046E7D0 }
procedure TSpriteBox.VernieuwZVolgorde(Pixie: TPixie);
var
  Nr: Integer;
begin
  Nr := FPixies.IndexOf(Pixie);
  if Nr <> -1 then
    VernieuwZVolgordeOp(Nr);
end;

{ @0046E7F0  -1/1: de pixie op Index moet omhoog/omlaag om Z aflopend te houden }
function TSpriteBox.ZRichting(Nr: Integer): Integer;
begin
  Result := 0;
  if FPixies.Count <> 1 then
    if (Nr > 0) and (LeesPixie(Nr - 1).LeesZ < LeesPixie(Nr).LeesZ) then
      Result := -1
    else if (Nr < FPixies.Count - 1) and
      (LeesPixie(Nr + 1).LeesZ > LeesPixie(Nr).LeesZ) then
      Result := 1;
end;

{ @0046E870 }
procedure TSpriteBox.VernieuwZVolgordeOp(Nr: Integer);
var
  D: Integer;
begin
  repeat
    D := ZRichting(Nr);
    if D <> 0 then
    begin
      FPixies.Exchange(Nr, D + Nr);
      Inc(Nr, D);
    end;
  until D = 0;
end;

{ @0046E8A0 }
procedure TSpriteBox.VernieuwPalet(Achtergrond: Boolean);
var
  Venster: HWND;
  DC: HDC;
  Palet, OudPalet: HPALETTE;
begin
  Venster := LeesTekenVenster;
  DC := GetDC(Venster);
  if GetDeviceCaps(DC, RASTERCAPS) and RC_PALETTE = RC_PALETTE then
  begin
    if FPaletAfbeelding <> nil then
      Palet := FPaletAfbeelding.LeesPaletHandle
    else
    begin
      if FPalette = 0 then
        FPalette := CreateHalftonePalette(DC);
      Palet := FPalette;
    end;
    OudPalet := SelectPalette(DC, Palet, Achtergrond);
    RealizePalette(DC);
    SelectPalette(DC, OudPalet, False);
  end;
  ReleaseDC(Venster, DC);
end;

{ @0046E928 }
procedure TSpriteBox.ZetVastlegPixie(Pixie: TPixie);
begin
  if Pixie <> FVastlegPixie then
  begin
    FVastlegPixie := Pixie;
    if Pixie = nil then
      MouseCapture := False
    else
      MouseCapture := True;
  end;
end;

{ ------------------------------------------------------------- TSpriteBoxList }

{ @0046E94C }
function TSpriteBoxList.Add(Box: TSpriteBox): TSpriteBox;
begin
  inherited Add(Box);
  Result := Box;
end;

{ @0046E95C }
function TSpriteBoxList.LeesSpriteBox(Nr: Integer): TSpriteBox;
begin
  Result := TObject(Get(Nr)) as TSpriteBox;
end;

{ @0046E97C }
procedure TSpriteBoxList.AlleWisselen;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if LeesSpriteBox(I).Visible then
      LeesSpriteBox(I).Flip;
end;

{ @0046E9B4  afsluitprocedure }
procedure SpriteBoxAfsluiting;
begin
  if TijdelijkVlak <> nil then
    TijdelijkVlak.Free;
  ExitProc := OudeExitProc;
end;

initialization
  { @0046EA08 }
  TijdelijkVlak := nil;
  OudeExitProc := ExitProc;
  ExitProc := @SpriteBoxAfsluiting;
  SpriteBoxen := TSpriteBoxList.Create;

{ De finalization op @0046E9D8 is de lege, door de compiler gegenereerde stub. }

end.

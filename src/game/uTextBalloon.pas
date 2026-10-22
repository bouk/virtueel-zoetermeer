unit uTextBalloon;

{ TTextBalloon: een spreekballon (afgeronde rechthoek met een punt naar
  de spreker) met tekst die per woord over regels wordt verdeeld, getekend als pixie van een TSpriteBox.
  De tekst wordt in regels verdeeld zodat het tekstblok dicht bij een
  verhouding van sqrt(2) uitkomt.
  Gedecompileerd uit ROS.exe v1.1, code 004653E8-00466FA8. }

{$I zm.inc}

interface

uses
  Windows, Classes, Graphics, uSurface, uPixie, uSpritebox;

type
  { aantal woorden per tekstregel }
  TRegelWoorden = array[0..99] of Integer;

  TTextBalloon = class(TPixie)
  private
    FBallonTekst: string;           { +0x68 }
    FPuntX: Integer;                 { +0x6C  punt van de aanwijzer, ten opzichte van Left }
    FPuntY: Integer;                 { +0x70 }
    FSpriteVak: TSpriteBox;         { +0x74 }
    FZijKleur: TColor;             { +0x78 }
    FAchtergrondKleur: TColor;       { +0x7C }
    FXVerschuiving: Integer;              { +0x80  positie van de ballon ten opzichte van X }
    FYVerschuiving: Integer;              { +0x84 }
    FX: Integer;                    { +0x88  het punt waar de ballon naar wijst }
    FY: Integer;                    { +0x8C }
    FRompX: Integer;                { +0x90  ballonlichaam, ten opzichte van Left }
    FRompY: Integer;                { +0x94 }
    FOmvangX: Integer;              { +0x98  Width - 1 }
    FOmvangY: Integer;              { +0x9C  Height - 1 }
    FBallonLijnBreedte: Integer;     { +0xA0 }
    FFont: TFont;                   { +0xA4 }
    FAfgerondeHoek: Boolean;          { +0xA8 }
    procedure SetFont(Value: TFont);
    procedure FontChanged(Sender: TObject);
    procedure ZetBallonTekst(Value: string);
    procedure VernieuwIndeling;
    procedure ZetBallonLijnBreedte(Value: Integer);
    procedure ZetAfgerondeHoek(Value: Boolean);
    procedure ZetXVerschuiving(Value: Integer);
    procedure ZetYVerschuiving(Value: Integer);
    procedure ZetSpriteVak(Value: TSpriteBox);
    procedure ZetZijKleur(Value: TColor);
    procedure ZetAchtergrondKleur(Value: TColor);
    procedure TekenBallon(Canvas: TCanvas; Left, Top, Right, Bottom, TipX,
      PuntY: Integer);
    function RegelVerhouding(AantalRegels: Integer; Tekst: string; Canvas: TCanvas;
      var MaxBreedte: Integer; var Woorden: TRegelWoorden; MaxRegels: Integer): Double;
    procedure PastTekst(Tekst: string; Canvas: TCanvas; Left, Top: Integer;
      var Right, Bottom, AantalRegels, MaxBreedte: Integer; var Woorden: TRegelWoorden;
      MaxRegels: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); override;
    procedure TekenDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Schaalfactor: Double); override;
    procedure ZetX(Value: Integer); override;
    procedure ZetY(Value: Integer); override;
    procedure ZetZ(Value: Integer); override;
    function LeesX: Integer; override;
    function LeesY: Integer; override;
  published
    property SpriteBox: TSpriteBox read FSpriteVak write ZetSpriteVak;
    property BalloonText: string read FBallonTekst write ZetBallonTekst;
    property XOffset: Integer read FXVerschuiving write ZetXVerschuiving;
    property YOffset: Integer read FYVerschuiving write ZetYVerschuiving;
    property SideColor: TColor read FZijKleur write ZetZijKleur;
    property BackGroundColor: TColor read FAchtergrondKleur write ZetAchtergrondKleur;
    property BalloonLineWidth: Integer read FBallonLijnBreedte write ZetBallonLijnBreedte;
    property RoundCorner: Boolean read FAfgerondeHoek write ZetAfgerondeHoek;
    property Font: TFont read FFont write SetFont;
  end;

implementation

uses
  uString, uTool;

type
  { Puntindex van elk van de 8 hoekpunten van de ballon, na de 3 punten van
    de aanwijzer (indices 0..2); de volgorde hangt af van de zijde van de aanwijzer. }
  THoekVolgorde = array[0..7] of Integer;

{$J+}
const
  HoekVolgordeLinks: THoekVolgorde = (5, 6, 7, 8, 9, 10, 3, 4);     { 00488D8C }
  HoekVolgordeRechts: THoekVolgorde = (9, 10, 3, 4, 5, 6, 7, 8);    { 00488DAC }
  HoekVolgordeOnder: THoekVolgorde = (3, 4, 5, 6, 7, 8, 9, 10);   { 00488DCC }
  HoekVolgordeBoven: THoekVolgorde = (7, 8, 9, 10, 3, 4, 5, 6);      { 00488DEC }
{$J-}

{ @00465654 }
constructor TTextBalloon.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ZetXVerschuiving(50);
  ZetYVerschuiving(-100);
  ZetBallonLijnBreedte(5);
  ZetZijKleur(clBlack);
  ZetAchtergrondKleur(clWhite);
  FFont := TFont.Create;
  ZetAfgerondeHoek(True);
  FFont.OnChange := FontChanged;
end;

{ @004656F0 }
destructor TTextBalloon.Destroy;
begin
  ZetSpriteVak(nil);
  FFont.Free;
  inherited Destroy;
end;

{ @0046572C }
procedure TTextBalloon.SetFont(Value: TFont);
begin
  if (FFont <> nil) and (Value <> nil) then
    FFont.Assign(Value);
end;

{ @00465748 }
procedure TTextBalloon.FontChanged(Sender: TObject);
begin
  VernieuwIndeling;
end;

{ @00465750 }
function TTextBalloon.GetWidth: Integer;
begin
  Result := FOmvangX + 1;
end;

{ @00465758 }
function TTextBalloon.GetHeight: Integer;
begin
  Result := FOmvangY + 1;
end;

{ @00465760 }
procedure TTextBalloon.ZetBallonTekst(Value: string);
begin
  if FBallonTekst <> Value then
  begin
    FBallonTekst := Value;
    VernieuwIndeling;
  end;
end;

{ @004657C0  berekent grootte, positie, lichaam en aanwijzer van de ballon }
procedure TTextBalloon.VernieuwIndeling;
var
  Right, Bottom, MaxBreedte, AantalRegels: Integer;
  Woorden: TRegelWoorden;
  OudeFont: TFont;
begin
  if csDesigning in ComponentState then
    Exit;
  if FSpriteVak = nil then
    Exit;
  OudeFont := FSpriteVak.Canvas.Font;
  FSpriteVak.Canvas.Font := FFont;
  PastTekst(FBallonTekst, FSpriteVak.Canvas, 0, 0, Right, Bottom, AantalRegels,
    MaxBreedte, Woorden, 100);
  if FXVerschuiving > Round(Right / 2) then
  begin
    SetLeft(LeesX);
    FOmvangX := Round(Right / 2) + FXVerschuiving;
    FRompX := Round((FBallonLijnBreedte - Right) / 2) + FXVerschuiving;
    FPuntX := Round(FBallonLijnBreedte / 2);
  end;
  if (FXVerschuiving <= Round(Right / 2)) and (FXVerschuiving > -Round(Right / 2)) then
  begin
    SetLeft(LeesX + FXVerschuiving - Round(Right / 2));
    FOmvangX := Right;
    FRompX := Round(FBallonLijnBreedte / 2);
    FPuntX := Round((Right + FBallonLijnBreedte) / 2) - FXVerschuiving;
  end;
  if FXVerschuiving <= -Round(Right / 2) then
  begin
    SetLeft(LeesX + FXVerschuiving - Round(Right / 2));
    FOmvangX := Round(Right / 2) - FXVerschuiving;
    FRompX := Round(FBallonLijnBreedte / 2);
    FPuntX := Round((Right + FBallonLijnBreedte) / 2) - FXVerschuiving;
  end;
  if FYVerschuiving > Bottom then
  begin
    SetTop(LeesY);
    FOmvangY := FYVerschuiving;
    FRompY := Round(FBallonLijnBreedte / 2) + (FYVerschuiving - Bottom);
    FPuntY := Round(FBallonLijnBreedte / 2);
  end;
  if (FYVerschuiving <= Bottom) and (FYVerschuiving > 0) then
  begin
    SetTop(LeesY + FYVerschuiving - Bottom);
    FOmvangY := Bottom;
    FRompY := Round(FBallonLijnBreedte / 2);
    FPuntY := Round(FBallonLijnBreedte / 2) + (Bottom - FYVerschuiving);
  end;
  if FYVerschuiving <= 0 then
  begin
    SetTop(LeesY + FYVerschuiving - Bottom);
    FOmvangY := Bottom - FYVerschuiving;
    FRompY := Round(FBallonLijnBreedte / 2);
    FPuntY := Round(FBallonLijnBreedte / 2) + (Bottom - FYVerschuiving);
  end;
  SetLeft(LeesLinks - Round(FBallonLijnBreedte / 2));
  SetTop(LeesBoven - Round(FBallonLijnBreedte / 2));
  Inc(FOmvangX, FBallonLijnBreedte);
  Inc(FOmvangY, FBallonLijnBreedte);
  FSpriteVak.Canvas.Font := OudeFont;
end;

{ @00465C08 }
procedure TTextBalloon.ZetBallonLijnBreedte(Value: Integer);
begin
  if Value <> FBallonLijnBreedte then
    FBallonLijnBreedte := Value;
end;

{ @00465C18 }
procedure TTextBalloon.ZetAfgerondeHoek(Value: Boolean);
begin
  if Value <> FAfgerondeHoek then
    FAfgerondeHoek := Value;
end;

{ @00465C28 }
procedure TTextBalloon.ZetXVerschuiving(Value: Integer);
begin
  if Value <> FXVerschuiving then
  begin
    FXVerschuiving := Value;
    VernieuwIndeling;
  end;
end;

{ @00465C3C }
procedure TTextBalloon.ZetYVerschuiving(Value: Integer);
begin
  if Value <> FYVerschuiving then
  begin
    FYVerschuiving := Value;
    VernieuwIndeling;
  end;
end;

{ @00465C50 }
procedure TTextBalloon.ZetSpriteVak(Value: TSpriteBox);
begin
  if Value <> FSpriteVak then
  begin
    if FSpriteVak <> nil then
      FSpriteVak.VerwijderPixie(Self);
    FSpriteVak := Value;
    if FSpriteVak <> nil then
      FSpriteVak.VoegPixieToe(Self);
    VernieuwIndeling;
  end;
end;

{ @00465C84 }
procedure TTextBalloon.ZetZijKleur(Value: TColor);
begin
  if Value <> FZijKleur then
    FZijKleur := Value;
end;

{ @00465C90 }
procedure TTextBalloon.ZetAchtergrondKleur(Value: TColor);
begin
  if Value <> FAchtergrondKleur then
    FAchtergrondKleur := Value;
end;

{ @00465C9C  ballonlichaam (Left, Top, Right, Bottom) met een aanwijzer naar
  (TipX, PuntY), als een veelhoek; afgeronde hoeken krijgen elk N extra punten }
procedure TTextBalloon.TekenBallon(Canvas: TCanvas; Left, Top, Right, Bottom,
  TipX, PuntY: Integer);
var
  Straal, N: Integer;
  HalfBreedte, HalfHoogte: Integer;
  Helling, A, B: Double;
  Spits: TPoint;
  Volgorde: THoekVolgorde;
  Punten: array[0..70] of TPoint;
  I, K: Integer;
begin
  Canvas.Pen.Width := FBallonLijnBreedte;
  Canvas.Pen.Color := FZijKleur;
  Canvas.Brush.Color := FAchtergrondKleur;
  Straal := 10;
  if FAfgerondeHoek then
    N := IMinimum(15, Round(Straal / 2))
  else
    N := 0;
  HalfBreedte := Round((Right - Left) / 2);
  HalfHoogte := Round((Bottom - Top) / 2);
  { de diagonalen van het lichaam: Y = X * Slope + A en Y = -X * Slope + B }
  Helling := (Bottom - Top) / (Right - Left);
  A := Top - Left * Helling;
  B := Bottom + Left * Helling;
  Spits.X := TipX;
  Spits.Y := PuntY;
  Punten[1].X := TipX;
  Punten[1].Y := PuntY;
  { aanwijzer aan de linkerzijde }
  if (TipX * Helling + A < PuntY) and (PuntY < -Helling * TipX + B) then
  begin
    Move(HoekVolgordeLinks, Volgorde, SizeOf(Volgorde));
    Punten[0].X := Left;
    Punten[2].X := Left;
    if Top + HalfHoogte < PuntY then
    begin
      Punten[0].Y := Top + HalfHoogte;
      Punten[2].Y := Top + HalfHoogte + Straal;
    end
    else
    begin
      Punten[0].Y := Top + HalfHoogte - Straal;
      Punten[2].Y := Top + HalfHoogte;
    end;
  end;
  { rechterzijde }
  if (PuntY < TipX * Helling + A) and (PuntY > -Helling * TipX + B) then
  begin
    Move(HoekVolgordeRechts, Volgorde, SizeOf(Volgorde));
    Punten[0].X := Right;
    Punten[2].X := Right;
    if Top + HalfHoogte < PuntY then
    begin
      Punten[2].Y := Top + HalfHoogte;
      Punten[0].Y := Top + HalfHoogte + Straal;
    end
    else
    begin
      Punten[2].Y := Top + HalfHoogte - Straal;
      Punten[0].Y := Top + HalfHoogte;
    end;
  end;
  { bovenzijde }
  if ((PuntY - A) / Helling <= TipX) and (TipX <= -(PuntY - B) / Helling) then
  begin
    Move(HoekVolgordeBoven, Volgorde, SizeOf(Volgorde));
    Punten[0].Y := Top;
    Punten[2].Y := Top;
    if TipX > Left + HalfBreedte then
    begin
      Punten[2].X := Left + HalfBreedte;
      Punten[0].X := Left + HalfBreedte + Straal;
    end
    else
    begin
      Punten[2].X := Left + HalfBreedte - Straal;
      Punten[0].X := Left + HalfBreedte;
    end;
  end;
  { onderzijde }
  if (TipX <= (PuntY - A) / Helling) and (TipX >= -(PuntY - B) / Helling) then
  begin
    Move(HoekVolgordeOnder, Volgorde, SizeOf(Volgorde));
    Punten[0].Y := Bottom;
    Punten[2].Y := Bottom;
    if TipX > Left + HalfBreedte then
    begin
      Punten[0].X := Left + HalfBreedte;
      Punten[2].X := Left + HalfBreedte + Straal;
    end
    else
    begin
      Punten[0].X := Left + HalfBreedte - Straal;
      Punten[2].X := Left + HalfBreedte;
    end;
  end;
  { punt binnen het lichaam: geen aanwijzer }
  if PtInRect(Rect(Left, Top, Right, Bottom), Spits) then
    Punten[1] := Punten[0];
  { rechtsonder hoek }
  Punten[Volgorde[0] + (Volgorde[0] - 2) div 2 * N].X := Right - Straal;
  Punten[Volgorde[0] + (Volgorde[0] - 2) div 2 * N].Y := Bottom;
  for I := 1 to N do
  begin
    K := Volgorde[0] + I + (Volgorde[0] - 2) div 2 * N;
    Punten[K].X := Round(Sin(I * (Pi / 2) / (N + 1)) * Straal) + (Right - Straal);
    Punten[K].Y := Round(Cos(I * (Pi / 2) / (N + 1)) * Straal) + (Bottom - Straal);
  end;
  Punten[Volgorde[1] + (Volgorde[1] - 2) div 2 * N].X := Right;
  Punten[Volgorde[1] + (Volgorde[1] - 2) div 2 * N].Y := Bottom - Straal;
  { rechtsboven hoek }
  Punten[Volgorde[2] + (Volgorde[2] - 2) div 2 * N].X := Right;
  Punten[Volgorde[2] + (Volgorde[2] - 2) div 2 * N].Y := Top + Straal;
  for I := 1 to N do
  begin
    K := Volgorde[2] + I + (Volgorde[2] - 2) div 2 * N;
    Punten[K].X := Round(Cos(I * (Pi / 2) / (N + 1)) * Straal) + (Right - Straal);
    Punten[K].Y := Top + Straal - Round(Sin(I * (Pi / 2) / (N + 1)) * Straal);
  end;
  Punten[Volgorde[3] + (Volgorde[3] - 2) div 2 * N].X := Right - Straal;
  Punten[Volgorde[3] + (Volgorde[3] - 2) div 2 * N].Y := Top;
  { linksboven hoek }
  Punten[Volgorde[4] + (Volgorde[4] - 2) div 2 * N].X := Left + Straal;
  Punten[Volgorde[4] + (Volgorde[4] - 2) div 2 * N].Y := Top;
  for I := 1 to N do
  begin
    K := Volgorde[4] + I + (Volgorde[4] - 2) div 2 * N;
    Punten[K].X := Left + Straal - Round(Sin(I * (Pi / 2) / (N + 1)) * Straal);
    Punten[K].Y := Top + Straal - Round(Cos(I * (Pi / 2) / (N + 1)) * Straal);
  end;
  Punten[Volgorde[5] + (Volgorde[5] - 2) div 2 * N].X := Left;
  Punten[Volgorde[5] + (Volgorde[5] - 2) div 2 * N].Y := Top + Straal;
  { linksonder hoek }
  Punten[Volgorde[6] + (Volgorde[6] - 2) div 2 * N].X := Left;
  Punten[Volgorde[6] + (Volgorde[6] - 2) div 2 * N].Y := Bottom - Straal;
  for I := 1 to N do
  begin
    K := Volgorde[6] + I + (Volgorde[6] - 2) div 2 * N;
    Punten[K].X := Left + Straal - Round(Cos(I * (Pi / 2) / (N + 1)) * Straal);
    Punten[K].Y := Round(Sin(I * (Pi / 2) / (N + 1)) * Straal) + (Bottom - Straal);
  end;
  Punten[Volgorde[7] + (Volgorde[7] - 2) div 2 * N].X := Left + Straal;
  Punten[Volgorde[7] + (Volgorde[7] - 2) div 2 * N].Y := Bottom;
  Canvas.Polygon(Slice(Punten, N * 4 + 11));
end;

{ @0046663C }
procedure TTextBalloon.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Schaalfactor: Double);
begin
  TekenDC(Surface.GetCanvas.Handle, DX, DY, ClipRect, Schaalfactor);
end;

{ @00466688  verdeelt Text in LineCount regels (Words); geeft de verhouding van
  de breedste regel tot de regelhoogte (0: geen tekst, -1: minder woorden dan regels) }
function TTextBalloon.RegelVerhouding(AantalRegels: Integer; Tekst: string; Canvas: TCanvas;
  var MaxBreedte: Integer; var Woorden: TRegelWoorden; MaxRegels: Integer): Double;
var
  S, Woord: string;
  SpatieBreedte, RegelHoogte, WoordAantal: Integer;
  WoordBreedtes: array[0..100] of Integer;
  RegelBreedtes: array[0..100] of Integer;
  Aantallen: array[0..100] of Integer;
  BesteAantallen: array[0..100] of Integer;
  Rest, Totaal, Aantal, Breedte, Breedste: Integer;
  I, J, K, MinRegel, MaxRegel, BesteBreedte: Integer;
  Verhouding, BesteVerhouding: Double;
  Klaar: Boolean;
begin
  { LET OP: MaxAantalRegels wordt niet gebruikt }
  S := Tekst;
  SpatieBreedte := Canvas.TextWidth(' ');
  RegelHoogte := Round(FFont.Size * (AantalRegels + 0.5 + (AantalRegels - 1) * 0.75));
  WoordAantal := 0;
  while S <> '' do
  begin
    Woord := SplitsEerste(S, ' ');
    WoordBreedtes[WoordAantal] := Canvas.TextWidth(Woord);
    Inc(WoordAantal);
  end;
  if WoordAantal = 0 then
    Result := 0
  else if WoordAantal < AantalRegels then
    Result := -1
  else if WoordAantal > 15 then
  begin
    { veel woorden: verdeel ze gelijkmatig over de regels }
    Rest := WoordAantal;
    Totaal := 0;
    for I := 0 to AantalRegels - 2 do
    begin
      Aantal := Round(Rest / (AantalRegels - I));
      Woorden[I] := Aantal;
      Inc(Totaal, Aantal);
      Dec(Rest, Aantal);
    end;
    Woorden[AantalRegels - 1] := WoordAantal - Totaal;
    K := 0;
    Breedste := -1;
    for I := 0 to AantalRegels - 1 do
    begin
      Breedte := 0;
      for J := 0 to Woorden[I] - 1 do
      begin
        if J > 0 then
          Inc(Breedte, SpatieBreedte);
        Inc(Breedte, WoordBreedtes[K]);
        Inc(K);
      end;
      if Breedte > Breedste then
        Breedste := Breedte;
    end;
    MaxBreedte := Breedste;
    Result := Breedste / RegelHoogte;
  end
  else
  begin
    { weinig woorden: probeer elke splitsing en houd de meest gelijkmatige }
    BesteVerhouding := -1;
    Aantallen[0] := WoordAantal;
    for I := 1 to AantalRegels - 1 do
      Aantallen[I] := 0;
    Klaar := False;
    while not Klaar do
    begin
      K := 0;
      for I := 0 to AantalRegels - 1 do
      begin
        RegelBreedtes[I] := 0;
        for J := 0 to Aantallen[I] - 1 do
        begin
          Inc(RegelBreedtes[I], WoordBreedtes[K]);
          if J > 0 then
            Inc(RegelBreedtes[I], SpatieBreedte);
          Inc(K);
        end;
      end;
      MinRegel := 0;
      MaxRegel := 0;
      for I := 0 to AantalRegels - 1 do
      begin
        if RegelBreedtes[MaxRegel] < RegelBreedtes[I] then
          MaxRegel := I;
        if RegelBreedtes[I] < RegelBreedtes[MinRegel] then
          MinRegel := I;
      end;
      Verhouding := RegelBreedtes[MinRegel] / RegelBreedtes[MaxRegel];
      if Verhouding > BesteVerhouding then
      begin
        BesteVerhouding := Verhouding;
        for I := 0 to AantalRegels - 1 do
        begin
          BesteAantallen[I] := Aantallen[I];
          BesteBreedte := RegelBreedtes[MaxRegel];
        end;
      end;
      { volgende splitsing }
      I := AantalRegels - 2;
      while (I >= 0) and (Aantallen[I] = 0) do
        Dec(I);
      if I = -1 then
        Klaar := True
      else
      begin
        Dec(Aantallen[I]);
        Inc(Aantallen[I + 1]);
        for J := I + 2 to AantalRegels - 1 do
        begin
          Inc(Aantallen[I + 1], Aantallen[J]);
          Aantallen[J] := 0;
        end;
      end;
    end;
    Result := BesteBreedte / RegelHoogte;
    MaxBreedte := BesteBreedte;
    for I := 0 to AantalRegels - 1 do
      Woorden[I] := BesteAantallen[I];
  end;
end;

{ @00466A58  kiest het aantal regels waarvan de blokverhouding het dichtst bij
  sqrt(2) ligt en geeft het ballonlichaam terug (Left, Top)-(Right, Bottom) }
procedure TTextBalloon.PastTekst(Tekst: string; Canvas: TCanvas; Left, Top: Integer;
  var Right, Bottom, AantalRegels, MaxBreedte: Integer; var Woorden: TRegelWoorden;
  MaxRegels: Integer);
var
  N, Marge: Integer;
  Verhouding, BesteVerschil: Double;
begin
  N := 0;
  Verhouding := 10;
  BesteVerschil := 10000;
  while Verhouding <> -1 do
  begin
    Inc(N);
    Verhouding := RegelVerhouding(N, Tekst, Canvas, MaxBreedte, Woorden, MaxRegels);
    if Verhouding = 0 then
    begin
      AantalRegels := 0;
      Right := Left + 50;
      Bottom := Top + 36;
      Exit;
    end;
    if (Abs(Sqrt(2) - Verhouding) < BesteVerschil) and (Verhouding <> -1) then
      BesteVerschil := Abs(Sqrt(2) - Verhouding)
    else
    begin
      AantalRegels := N - 1;
      Break;
    end;
  end;
  Verhouding := RegelVerhouding(AantalRegels, Tekst, Canvas, MaxBreedte, Woorden, MaxRegels);
  Marge := 20;
  Right := Round(MaxBreedte + Left + Marge);
  Bottom := Round(MaxBreedte / Verhouding + Top + Marge);
end;

{ @00466DE8 }
procedure TTextBalloon.TekenDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
  Schaalfactor: Double);
var
  Woorden: TRegelWoorden;
  Canvas: TCanvas;
  MaxBreedte: Integer;
  BodyLeft, BodyTop: Integer;
  BodyRight, BodyBottom, AantalRegels: Integer;
  TipX, PuntY: Integer;
  OudeFont: TFont;

  { @00466BD4 }
  procedure DrawLines(AantalRegels: Integer; Tekst: string);
  var
    Regels: TStringList;
    S, Regel, Woord: string;
    I, J, Marge, X: Integer;
  begin
    Regels := TStringList.Create;   { LET OP: wordt nooit vrijgegeven }
    S := Tekst;
    Regel := '';
    for I := 0 to AantalRegels - 1 do
    begin
      Regel := '';
      for J := 1 to Woorden[I] do
        if Regel <> '' then
        begin
          Woord := SplitsEerste(S, ' ');
          Regel := Regel + ' ' + Woord;
        end
        else
        begin
          Woord := SplitsEerste(S, ' ');
          Regel := Regel + Woord;
        end;
      Regels.Add(Regel);
    end;
    Marge := 10;
    Canvas.Brush.Style := bsClear;
    for I := 0 to AantalRegels - 1 do
    begin
      X := Round((MaxBreedte - Canvas.TextWidth(Regels[I])) / 2);
      Canvas.TextOut(BodyLeft + X + Marge,
        Round(Canvas.Font.Size * (I * 1.75) + (BodyTop + Marge)), Regels[I]);
    end;
  end;

begin
  Canvas := TCanvas.Create;
  Canvas.Handle := DC;
  BodyLeft := FRompX + DX;
  BodyTop := FRompY + DY;
  TipX := DX + FPuntX;
  PuntY := DY + FPuntY;
  OudeFont := Canvas.Font;
  Canvas.Font := FFont;
  PastTekst(FBallonTekst, Canvas, BodyLeft, BodyTop, BodyRight, BodyBottom,
    AantalRegels, MaxBreedte, Woorden, 100);
  TekenBallon(Canvas, BodyLeft, BodyTop, BodyRight, BodyBottom, TipX, PuntY);
  DrawLines(AantalRegels, FBallonTekst);
  Canvas.Font := OudeFont;
  Canvas.Free;
end;

{ @00466F1C }
procedure TTextBalloon.ZetX(Value: Integer);
begin
  FX := Value;
  VernieuwIndeling;
end;

{ @00466F28 }
procedure TTextBalloon.ZetY(Value: Integer);
begin
  FY := Value;
  VernieuwIndeling;
end;

{ @00466F34 }
procedure TTextBalloon.ZetZ(Value: Integer);
begin
  if Value <> LeesZ then
  begin
    inherited ZetZ(Value);
    if FSpriteVak <> nil then
      FSpriteVak.VernieuwZVolgorde(Self);
  end;
end;

{ @00466F60 }
function TTextBalloon.LeesX: Integer;
begin
  Result := FX;
end;

{ @00466F68 }
function TTextBalloon.LeesY: Integer;
begin
  Result := FY;
end;

{ De finalization op @00466F70 is de lege, door de compiler gegenereerde stub. }

end.

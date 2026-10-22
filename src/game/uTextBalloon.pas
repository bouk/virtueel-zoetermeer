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
  TLineWords = array[0..99] of Integer;

  TTextBalloon = class(TPixie)
  private
    FBalloonText: string;           { +0x68 }
    FTipX: Integer;                 { +0x6C  punt van de aanwijzer, ten opzichte van Left }
    FTipY: Integer;                 { +0x70 }
    FSpriteBox: TSpriteBox;         { +0x74 }
    FSideColor: TColor;             { +0x78 }
    FBackGroundColor: TColor;       { +0x7C }
    FXOffset: Integer;              { +0x80  positie van de ballon ten opzichte van X }
    FYOffset: Integer;              { +0x84 }
    FX: Integer;                    { +0x88  het punt waar de ballon naar wijst }
    FY: Integer;                    { +0x8C }
    FBodyX: Integer;                { +0x90  ballonlichaam, ten opzichte van Left }
    FBodyY: Integer;                { +0x94 }
    FExtentX: Integer;              { +0x98  Width - 1 }
    FExtentY: Integer;              { +0x9C  Height - 1 }
    FBalloonLineWidth: Integer;     { +0xA0 }
    FFont: TFont;                   { +0xA4 }
    FRoundCorner: Boolean;          { +0xA8 }
    procedure SetFont(Value: TFont);
    procedure FontChanged(Sender: TObject);
    procedure SetBalloonText(Value: string);
    procedure UpdateLayout;
    procedure SetBalloonLineWidth(Value: Integer);
    procedure SetRoundCorner(Value: Boolean);
    procedure SetXOffset(Value: Integer);
    procedure SetYOffset(Value: Integer);
    procedure SetSpriteBox(Value: TSpriteBox);
    procedure SetSideColor(Value: TColor);
    procedure SetBackGroundColor(Value: TColor);
    procedure DrawBalloon(Canvas: TCanvas; Left, Top, Right, Bottom, TipX,
      TipY: Integer);
    function LineRatio(AantalRegels: Integer; Tekst: string; Canvas: TCanvas;
      var MaxBreedte: Integer; var Woorden: TLineWords; MaxRegels: Integer): Double;
    procedure FitText(Tekst: string; Canvas: TCanvas; Left, Top: Integer;
      var Right, Bottom, AantalRegels, MaxBreedte: Integer; var Woorden: TLineWords;
      MaxRegels: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;
    procedure DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;
    procedure SetX(Value: Integer); override;
    procedure SetY(Value: Integer); override;
    procedure SetZ(Value: Integer); override;
    function GetX: Integer; override;
    function GetY: Integer; override;
  published
    property SpriteBox: TSpriteBox read FSpriteBox write SetSpriteBox;
    property BalloonText: string read FBalloonText write SetBalloonText;
    property XOffset: Integer read FXOffset write SetXOffset;
    property YOffset: Integer read FYOffset write SetYOffset;
    property SideColor: TColor read FSideColor write SetSideColor;
    property BackGroundColor: TColor read FBackGroundColor write SetBackGroundColor;
    property BalloonLineWidth: Integer read FBalloonLineWidth write SetBalloonLineWidth;
    property RoundCorner: Boolean read FRoundCorner write SetRoundCorner;
    property Font: TFont read FFont write SetFont;
  end;

implementation

uses
  uString, uTool;

type
  { Puntindex van elk van de 8 hoekpunten van de ballon, na de 3 punten van
    de aanwijzer (indices 0..2); de volgorde hangt af van de zijde van de aanwijzer. }
  TCornerOrder = array[0..7] of Integer;

{$J+}
const
  CornerOrderLeft: TCornerOrder = (5, 6, 7, 8, 9, 10, 3, 4);     { 00488D8C }
  CornerOrderRight: TCornerOrder = (9, 10, 3, 4, 5, 6, 7, 8);    { 00488DAC }
  CornerOrderBottom: TCornerOrder = (3, 4, 5, 6, 7, 8, 9, 10);   { 00488DCC }
  CornerOrderTop: TCornerOrder = (7, 8, 9, 10, 3, 4, 5, 6);      { 00488DEC }
{$J-}

{ @00465654 }
constructor TTextBalloon.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetXOffset(50);
  SetYOffset(-100);
  SetBalloonLineWidth(5);
  SetSideColor(clBlack);
  SetBackGroundColor(clWhite);
  FFont := TFont.Create;
  SetRoundCorner(True);
  FFont.OnChange := FontChanged;
end;

{ @004656F0 }
destructor TTextBalloon.Destroy;
begin
  SetSpriteBox(nil);
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
  UpdateLayout;
end;

{ @00465750 }
function TTextBalloon.GetWidth: Integer;
begin
  Result := FExtentX + 1;
end;

{ @00465758 }
function TTextBalloon.GetHeight: Integer;
begin
  Result := FExtentY + 1;
end;

{ @00465760 }
procedure TTextBalloon.SetBalloonText(Value: string);
begin
  if FBalloonText <> Value then
  begin
    FBalloonText := Value;
    UpdateLayout;
  end;
end;

{ @004657C0  berekent grootte, positie, lichaam en aanwijzer van de ballon }
procedure TTextBalloon.UpdateLayout;
var
  Right, Bottom, MaxBreedte, AantalRegels: Integer;
  Woorden: TLineWords;
  OudeFont: TFont;
begin
  if csDesigning in ComponentState then
    Exit;
  if FSpriteBox = nil then
    Exit;
  OudeFont := FSpriteBox.Canvas.Font;
  FSpriteBox.Canvas.Font := FFont;
  FitText(FBalloonText, FSpriteBox.Canvas, 0, 0, Right, Bottom, AantalRegels,
    MaxBreedte, Woorden, 100);
  if FXOffset > Round(Right / 2) then
  begin
    SetLeft(GetX);
    FExtentX := Round(Right / 2) + FXOffset;
    FBodyX := Round((FBalloonLineWidth - Right) / 2) + FXOffset;
    FTipX := Round(FBalloonLineWidth / 2);
  end;
  if (FXOffset <= Round(Right / 2)) and (FXOffset > -Round(Right / 2)) then
  begin
    SetLeft(GetX + FXOffset - Round(Right / 2));
    FExtentX := Right;
    FBodyX := Round(FBalloonLineWidth / 2);
    FTipX := Round((Right + FBalloonLineWidth) / 2) - FXOffset;
  end;
  if FXOffset <= -Round(Right / 2) then
  begin
    SetLeft(GetX + FXOffset - Round(Right / 2));
    FExtentX := Round(Right / 2) - FXOffset;
    FBodyX := Round(FBalloonLineWidth / 2);
    FTipX := Round((Right + FBalloonLineWidth) / 2) - FXOffset;
  end;
  if FYOffset > Bottom then
  begin
    SetTop(GetY);
    FExtentY := FYOffset;
    FBodyY := Round(FBalloonLineWidth / 2) + (FYOffset - Bottom);
    FTipY := Round(FBalloonLineWidth / 2);
  end;
  if (FYOffset <= Bottom) and (FYOffset > 0) then
  begin
    SetTop(GetY + FYOffset - Bottom);
    FExtentY := Bottom;
    FBodyY := Round(FBalloonLineWidth / 2);
    FTipY := Round(FBalloonLineWidth / 2) + (Bottom - FYOffset);
  end;
  if FYOffset <= 0 then
  begin
    SetTop(GetY + FYOffset - Bottom);
    FExtentY := Bottom - FYOffset;
    FBodyY := Round(FBalloonLineWidth / 2);
    FTipY := Round(FBalloonLineWidth / 2) + (Bottom - FYOffset);
  end;
  SetLeft(GetLeft - Round(FBalloonLineWidth / 2));
  SetTop(GetTop - Round(FBalloonLineWidth / 2));
  Inc(FExtentX, FBalloonLineWidth);
  Inc(FExtentY, FBalloonLineWidth);
  FSpriteBox.Canvas.Font := OudeFont;
end;

{ @00465C08 }
procedure TTextBalloon.SetBalloonLineWidth(Value: Integer);
begin
  if Value <> FBalloonLineWidth then
    FBalloonLineWidth := Value;
end;

{ @00465C18 }
procedure TTextBalloon.SetRoundCorner(Value: Boolean);
begin
  if Value <> FRoundCorner then
    FRoundCorner := Value;
end;

{ @00465C28 }
procedure TTextBalloon.SetXOffset(Value: Integer);
begin
  if Value <> FXOffset then
  begin
    FXOffset := Value;
    UpdateLayout;
  end;
end;

{ @00465C3C }
procedure TTextBalloon.SetYOffset(Value: Integer);
begin
  if Value <> FYOffset then
  begin
    FYOffset := Value;
    UpdateLayout;
  end;
end;

{ @00465C50 }
procedure TTextBalloon.SetSpriteBox(Value: TSpriteBox);
begin
  if Value <> FSpriteBox then
  begin
    if FSpriteBox <> nil then
      FSpriteBox.RemovePixie(Self);
    FSpriteBox := Value;
    if FSpriteBox <> nil then
      FSpriteBox.AddPixie(Self);
    UpdateLayout;
  end;
end;

{ @00465C84 }
procedure TTextBalloon.SetSideColor(Value: TColor);
begin
  if Value <> FSideColor then
    FSideColor := Value;
end;

{ @00465C90 }
procedure TTextBalloon.SetBackGroundColor(Value: TColor);
begin
  if Value <> FBackGroundColor then
    FBackGroundColor := Value;
end;

{ @00465C9C  ballonlichaam (Left, Top, Right, Bottom) met een aanwijzer naar
  (TipX, TipY), als een veelhoek; afgeronde hoeken krijgen elk N extra punten }
procedure TTextBalloon.DrawBalloon(Canvas: TCanvas; Left, Top, Right, Bottom,
  TipX, TipY: Integer);
var
  Straal, N: Integer;
  HalfBreedte, HalfHoogte: Integer;
  Helling, A, B: Double;
  Spits: TPoint;
  Volgorde: TCornerOrder;
  Punten: array[0..70] of TPoint;
  I, K: Integer;
begin
  Canvas.Pen.Width := FBalloonLineWidth;
  Canvas.Pen.Color := FSideColor;
  Canvas.Brush.Color := FBackGroundColor;
  Straal := 10;
  if FRoundCorner then
    N := IMin(15, Round(Straal / 2))
  else
    N := 0;
  HalfBreedte := Round((Right - Left) / 2);
  HalfHoogte := Round((Bottom - Top) / 2);
  { de diagonalen van het lichaam: Y = X * Slope + A en Y = -X * Slope + B }
  Helling := (Bottom - Top) / (Right - Left);
  A := Top - Left * Helling;
  B := Bottom + Left * Helling;
  Spits.X := TipX;
  Spits.Y := TipY;
  Punten[1].X := TipX;
  Punten[1].Y := TipY;
  { aanwijzer aan de linkerzijde }
  if (TipX * Helling + A < TipY) and (TipY < -Helling * TipX + B) then
  begin
    Move(CornerOrderLeft, Volgorde, SizeOf(Volgorde));
    Punten[0].X := Left;
    Punten[2].X := Left;
    if Top + HalfHoogte < TipY then
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
  if (TipY < TipX * Helling + A) and (TipY > -Helling * TipX + B) then
  begin
    Move(CornerOrderRight, Volgorde, SizeOf(Volgorde));
    Punten[0].X := Right;
    Punten[2].X := Right;
    if Top + HalfHoogte < TipY then
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
  if ((TipY - A) / Helling <= TipX) and (TipX <= -(TipY - B) / Helling) then
  begin
    Move(CornerOrderTop, Volgorde, SizeOf(Volgorde));
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
  if (TipX <= (TipY - A) / Helling) and (TipX >= -(TipY - B) / Helling) then
  begin
    Move(CornerOrderBottom, Volgorde, SizeOf(Volgorde));
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
  Scale: Double);
begin
  DrawDC(Surface.GetCanvas.Handle, DX, DY, ClipRect, Scale);
end;

{ @00466688  verdeelt Text in LineCount regels (Words); geeft de verhouding van
  de breedste regel tot de regelhoogte (0: geen tekst, -1: minder woorden dan regels) }
function TTextBalloon.LineRatio(AantalRegels: Integer; Tekst: string; Canvas: TCanvas;
  var MaxBreedte: Integer; var Woorden: TLineWords; MaxRegels: Integer): Double;
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
  { LET OP: MaxLines wordt niet gebruikt }
  S := Tekst;
  SpatieBreedte := Canvas.TextWidth(' ');
  RegelHoogte := Round(FFont.Size * (AantalRegels + 0.5 + (AantalRegels - 1) * 0.75));
  WoordAantal := 0;
  while S <> '' do
  begin
    Woord := SplitFirst(S, ' ');
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
procedure TTextBalloon.FitText(Tekst: string; Canvas: TCanvas; Left, Top: Integer;
  var Right, Bottom, AantalRegels, MaxBreedte: Integer; var Woorden: TLineWords;
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
    Verhouding := LineRatio(N, Tekst, Canvas, MaxBreedte, Woorden, MaxRegels);
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
  Verhouding := LineRatio(AantalRegels, Tekst, Canvas, MaxBreedte, Woorden, MaxRegels);
  Marge := 20;
  Right := Round(MaxBreedte + Left + Marge);
  Bottom := Round(MaxBreedte / Verhouding + Top + Marge);
end;

{ @00466DE8 }
procedure TTextBalloon.DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
  Scale: Double);
var
  Woorden: TLineWords;
  Canvas: TCanvas;
  MaxBreedte: Integer;
  BodyLeft, BodyTop: Integer;
  BodyRight, BodyBottom, AantalRegels: Integer;
  TipX, TipY: Integer;
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
          Woord := SplitFirst(S, ' ');
          Regel := Regel + ' ' + Woord;
        end
        else
        begin
          Woord := SplitFirst(S, ' ');
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
  BodyLeft := FBodyX + DX;
  BodyTop := FBodyY + DY;
  TipX := DX + FTipX;
  TipY := DY + FTipY;
  OudeFont := Canvas.Font;
  Canvas.Font := FFont;
  FitText(FBalloonText, Canvas, BodyLeft, BodyTop, BodyRight, BodyBottom,
    AantalRegels, MaxBreedte, Woorden, 100);
  DrawBalloon(Canvas, BodyLeft, BodyTop, BodyRight, BodyBottom, TipX, TipY);
  DrawLines(AantalRegels, FBalloonText);
  Canvas.Font := OudeFont;
  Canvas.Free;
end;

{ @00466F1C }
procedure TTextBalloon.SetX(Value: Integer);
begin
  FX := Value;
  UpdateLayout;
end;

{ @00466F28 }
procedure TTextBalloon.SetY(Value: Integer);
begin
  FY := Value;
  UpdateLayout;
end;

{ @00466F34 }
procedure TTextBalloon.SetZ(Value: Integer);
begin
  if Value <> GetZ then
  begin
    inherited SetZ(Value);
    if FSpriteBox <> nil then
      FSpriteBox.UpdateZOrder(Self);
  end;
end;

{ @00466F60 }
function TTextBalloon.GetX: Integer;
begin
  Result := FX;
end;

{ @00466F68 }
function TTextBalloon.GetY: Integer;
begin
  Result := FY;
end;

{ De finalization op @00466F70 is de lege, door de compiler gegenereerde stub. }

end.

unit ZMDraw;

{ Klassieke (Windows 9x) uitstraling voor de standaardbesturingselementen: 3D-kaders, knopvlakken,
  selectievakjes, schuifbalken, pijlen. Gebruikt door StdCtrls, Buttons, ComCtrls, Grids. }

{$MODE DELPHI}{$H+}

interface

uses Windows, Graphics;

const
  ZMSchuifbalkGrootte = 16;

type
  TZMScrollPart = (spNone, spLineUp, spPageUp, spThumb, spPageDown, spLineDown);

procedure ZMKader3D(Tekenvlak: TCanvas; R: TRect; LinksBoven, RechtsOnder: TColor);
procedure ZMTekenVerheven(Tekenvlak: TCanvas; var R: TRect);      { knoprand, 2 px }
procedure ZMTekenVerzonken(Tekenvlak: TCanvas; var R: TRect);      { bewerkrand, 2 px }
procedure ZMTekenKnopvlak(Tekenvlak: TCanvas; R: TRect; Ingedrukt, IsStandaard, HeeftFocus: Boolean);
procedure ZMTekenVinkje(Tekenvlak: TCanvas; R: TRect; Aangevinkt, Grijs, Ingeschakeld: Boolean);
procedure ZMTekenKeuzerondje(Tekenvlak: TCanvas; R: TRect; Aangevinkt, Ingeschakeld: Boolean);
procedure ZMTekenPijl(Tekenvlak: TCanvas; R: TRect; Richting: Integer; Ingeschakeld: Boolean); { 0 omhoog 1 omlaag 2 links 3 rechts }
procedure ZMTekenSchuifbalk(Tekenvlak: TCanvas; R: TRect; Verticaal: Boolean; Minimum, Maximum, Positie, Pagina: Integer;
  Ingedrukt: TZMScrollPart; Ingeschakeld: Boolean);
function ZMSchuifTreffer(R: TRect; Verticaal: Boolean; Minimum, Maximum, Positie, Pagina: Integer; Punt: TPoint): TZMScrollPart;
function ZMSchuifknopRechthoek(R: TRect; Verticaal: Boolean; Minimum, Maximum, Positie, Pagina: Integer): TRect;
procedure ZMTekenUitgeschakeldeTekst(Tekenvlak: TCanvas; R: TRect; const Tekst: string; Vlaggen: UINT);

implementation

uses Classes;

procedure ZMKader3D(Tekenvlak: TCanvas; R: TRect; LinksBoven, RechtsOnder: TColor);
begin
  with Tekenvlak do
  begin
    Pen.Style := psSolid;
    Pen.Width := 1;
    Pen.Color := LinksBoven;
    MoveTo(R.Left, R.Bottom - 1);
    LineTo(R.Left, R.Top);
    LineTo(R.Right - 1, R.Top);
    Pen.Color := RechtsOnder;
    LineTo(R.Right - 1, R.Bottom - 1);
    LineTo(R.Left - 1, R.Bottom - 1);
  end;
end;

procedure ZMTekenVerheven(Tekenvlak: TCanvas; var R: TRect);
begin
  ZMKader3D(Tekenvlak, R, clBtnHighlight, cl3DDkShadow);
  InflateRect(R, -1, -1);
  ZMKader3D(Tekenvlak, R, cl3DLight, clBtnShadow);
  InflateRect(R, -1, -1);
end;

procedure ZMTekenVerzonken(Tekenvlak: TCanvas; var R: TRect);
begin
  ZMKader3D(Tekenvlak, R, clBtnShadow, clBtnHighlight);
  InflateRect(R, -1, -1);
  ZMKader3D(Tekenvlak, R, cl3DDkShadow, cl3DLight);
  InflateRect(R, -1, -1);
end;

procedure ZMTekenKnopvlak(Tekenvlak: TCanvas; R: TRect; Ingedrukt, IsStandaard, HeeftFocus: Boolean);
begin
  with Tekenvlak do
  begin
    Brush.Style := bsSolid;
    if IsStandaard or HeeftFocus then
    begin
      Brush.Color := clWindowFrame;
      FrameRect(R);
      InflateRect(R, -1, -1);
    end;
    if Ingedrukt then
    begin
      Brush.Color := clBtnShadow;
      FrameRect(R);
      InflateRect(R, -1, -1);
      Brush.Color := clBtnFace;
      FillRect(R);
    end
    else
    begin
      ZMTekenVerheven(Tekenvlak, R);
      Brush.Color := clBtnFace;
      FillRect(R);
    end;
  end;
end;

procedure ZMTekenVinkje(Tekenvlak: TCanvas; R: TRect; Aangevinkt, Grijs, Ingeschakeld: Boolean);
var
  Teller, Xpositie, Ypositie: Integer;
begin
  ZMTekenVerzonken(Tekenvlak, R);
  with Tekenvlak do
  begin
    Brush.Style := bsSolid;
    if Ingeschakeld and not Grijs then Brush.Color := clWindow else Brush.Color := clBtnFace;
    FillRect(R);
    if Aangevinkt then
    begin
      if Ingeschakeld then Pen.Color := clWindowText else Pen.Color := clBtnShadow;
      Xpositie := R.Left + 1;
      Ypositie := R.Top + 3;
      for Teller := 0 to 2 do
      begin
        MoveTo(Xpositie + Teller, Ypositie + Teller + 0);
        LineTo(Xpositie + Teller, Ypositie + Teller + 3);
      end;
      for Teller := 0 to 3 do
      begin
        MoveTo(Xpositie + 3 + Teller, Ypositie + 1 - Teller);
        LineTo(Xpositie + 3 + Teller, Ypositie + 4 - Teller);
      end;
    end;
  end;
end;

procedure ZMTekenKeuzerondje(Tekenvlak: TCanvas; R: TRect; Aangevinkt, Ingeschakeld: Boolean);
var
  MiddenX, MiddenY: Integer;
begin
  with Tekenvlak do
  begin
    Pen.Color := clBtnShadow;
    if Ingeschakeld then Brush.Color := clWindow else Brush.Color := clBtnFace;
    Brush.Style := bsSolid;
    Ellipse(R.Left, R.Top, R.Left + 12, R.Top + 12);
    Pen.Color := cl3DDkShadow;
    Brush.Style := bsClear;
    Ellipse(R.Left + 1, R.Top + 1, R.Left + 11, R.Top + 11);
    if Aangevinkt then
    begin
      MiddenX := R.Left + 6;
      MiddenY := R.Top + 6;
      Brush.Style := bsSolid;
      if Ingeschakeld then Brush.Color := clWindowText else Brush.Color := clBtnShadow;
      FillRect(Rect(MiddenX - 2, MiddenY - 1, MiddenX + 2, MiddenY + 1));
      FillRect(Rect(MiddenX - 1, MiddenY - 2, MiddenX + 1, MiddenY + 2));
    end;
  end;
end;

procedure ZMTekenPijl(Tekenvlak: TCanvas; R: TRect; Richting: Integer; Ingeschakeld: Boolean);
var
  MiddenX, MiddenY, Teller: Integer;
  procedure Teken(VerschuivingX, VerschuivingY: Integer; Kleur: TColor);
  var Stap: Integer;
  begin
    Tekenvlak.Pen.Color := Kleur;
    for Stap := 0 to 3 do
      case Richting of
        0: begin Tekenvlak.MoveTo(MiddenX - Stap + VerschuivingX, MiddenY - 2 + Stap + VerschuivingY); Tekenvlak.LineTo(MiddenX + Stap + 1 + VerschuivingX, MiddenY - 2 + Stap + VerschuivingY); end;
        1: begin Tekenvlak.MoveTo(MiddenX - Stap + VerschuivingX, MiddenY + 1 - Stap + VerschuivingY); Tekenvlak.LineTo(MiddenX + Stap + 1 + VerschuivingX, MiddenY + 1 - Stap + VerschuivingY); end;
        2: begin Tekenvlak.MoveTo(MiddenX - 2 + Stap + VerschuivingX, MiddenY - Stap + VerschuivingY); Tekenvlak.LineTo(MiddenX - 2 + Stap + VerschuivingX, MiddenY + Stap + 1 + VerschuivingY); end;
        3: begin Tekenvlak.MoveTo(MiddenX + 1 - Stap + VerschuivingX, MiddenY - Stap + VerschuivingY); Tekenvlak.LineTo(MiddenX + 1 - Stap + VerschuivingX, MiddenY + Stap + 1 + VerschuivingY); end;
      end;
  end;
begin
  MiddenX := (R.Left + R.Right) div 2;
  MiddenY := (R.Top + R.Bottom) div 2;
  Teller := 0;
  if Ingeschakeld then
    Teken(0, 0, clBtnText)
  else
  begin
    Teken(1, 1, clBtnHighlight);
    Teken(0, 0, clBtnShadow);
  end;
  if Teller = 0 then ;
end;

function SpoorRechthoek(R: TRect; Verticaal: Boolean): TRect;
begin
  Result := R;
  if Verticaal then
  begin
    Inc(Result.Top, ZMSchuifbalkGrootte);
    Dec(Result.Bottom, ZMSchuifbalkGrootte);
  end
  else
  begin
    Inc(Result.Left, ZMSchuifbalkGrootte);
    Dec(Result.Right, ZMSchuifbalkGrootte);
  end;
end;

function ZMSchuifknopRechthoek(R: TRect; Verticaal: Boolean; Minimum, Maximum, Positie, Pagina: Integer): TRect;
var
  Spoor: TRect;
  Lengte, Knoplengte, Bereik, Verschuiving: Integer;
begin
  Spoor := SpoorRechthoek(R, Verticaal);
  if Verticaal then Lengte := Spoor.Bottom - Spoor.Top else Lengte := Spoor.Right - Spoor.Left;
  Bereik := Maximum - Minimum + 1;
  if Pagina <= 0 then Knoplengte := ZMSchuifbalkGrootte
  else if Bereik > 0 then Knoplengte := Lengte * Pagina div Bereik
  else Knoplengte := Lengte;
  if Knoplengte < 8 then Knoplengte := 8;
  if Knoplengte > Lengte then Knoplengte := Lengte;
  if Pagina > 0 then Bereik := Maximum - Minimum + 1 - Pagina else Bereik := Maximum - Minimum;
  if Bereik <= 0 then Verschuiving := 0
  else Verschuiving := Int64(Lengte - Knoplengte) * (Positie - Minimum) div Bereik;
  if Verschuiving < 0 then Verschuiving := 0;
  if Verschuiving > Lengte - Knoplengte then Verschuiving := Lengte - Knoplengte;
  Result := Spoor;
  if Verticaal then
  begin
    Result.Top := Spoor.Top + Verschuiving;
    Result.Bottom := Result.Top + Knoplengte;
  end
  else
  begin
    Result.Left := Spoor.Left + Verschuiving;
    Result.Right := Result.Left + Knoplengte;
  end;
end;

procedure ZMTekenSchuifbalk(Tekenvlak: TCanvas; R: TRect; Verticaal: Boolean; Minimum, Maximum, Positie, Pagina: Integer;
  Ingedrukt: TZMScrollPart; Ingeschakeld: Boolean);
var
  Knop1, Knop2, Spoor, Duim: TRect;
  procedure Knop(Knopgebied: TRect; Richting: Integer; Gedrukt: Boolean);
  begin
    if Gedrukt then
    begin
      Tekenvlak.Brush.Color := clBtnShadow;
      Tekenvlak.FrameRect(Knopgebied);
      InflateRect(Knopgebied, -1, -1);
      Tekenvlak.Brush.Color := clBtnFace;
      Tekenvlak.FillRect(Knopgebied);
      OffsetRect(Knopgebied, 1, 1);
    end
    else
    begin
      ZMTekenVerheven(Tekenvlak, Knopgebied);
      Tekenvlak.Brush.Color := clBtnFace;
      Tekenvlak.FillRect(Knopgebied);
    end;
    ZMTekenPijl(Tekenvlak, Knopgebied, Richting, Ingeschakeld);
  end;
begin
  Tekenvlak.Brush.Style := bsSolid;
  if Verticaal then
  begin
    Knop1 := Rect(R.Left, R.Top, R.Right, R.Top + ZMSchuifbalkGrootte);
    Knop2 := Rect(R.Left, R.Bottom - ZMSchuifbalkGrootte, R.Right, R.Bottom);
    Knop(Knop1, 0, Ingedrukt = spLineUp);
    Knop(Knop2, 1, Ingedrukt = spLineDown);
  end
  else
  begin
    Knop1 := Rect(R.Left, R.Top, R.Left + ZMSchuifbalkGrootte, R.Bottom);
    Knop2 := Rect(R.Right - ZMSchuifbalkGrootte, R.Top, R.Right, R.Bottom);
    Knop(Knop1, 2, Ingedrukt = spLineUp);
    Knop(Knop2, 3, Ingedrukt = spLineDown);
  end;
  Spoor := SpoorRechthoek(R, Verticaal);
  { gerasterde baan }
  Tekenvlak.Brush.Color := cl3DLight;
  Tekenvlak.FillRect(Spoor);
  if Ingeschakeld and (Maximum > Minimum) then
  begin
    Duim := ZMSchuifknopRechthoek(R, Verticaal, Minimum, Maximum, Positie, Pagina);
    ZMTekenVerheven(Tekenvlak, Duim);
    Tekenvlak.Brush.Color := clBtnFace;
    Tekenvlak.FillRect(Duim);
  end;
end;

function ZMSchuifTreffer(R: TRect; Verticaal: Boolean; Minimum, Maximum, Positie, Pagina: Integer; Punt: TPoint): TZMScrollPart;
var
  Duim: TRect;
begin
  Result := spNone;
  if not PtInRect(R, Punt) then Exit;
  Duim := ZMSchuifknopRechthoek(R, Verticaal, Minimum, Maximum, Positie, Pagina);
  if Verticaal then
  begin
    if Punt.Y < R.Top + ZMSchuifbalkGrootte then Result := spLineUp
    else if Punt.Y >= R.Bottom - ZMSchuifbalkGrootte then Result := spLineDown
    else if Punt.Y < Duim.Top then Result := spPageUp
    else if Punt.Y >= Duim.Bottom then Result := spPageDown
    else Result := spThumb;
  end
  else
  begin
    if Punt.X < R.Left + ZMSchuifbalkGrootte then Result := spLineUp
    else if Punt.X >= R.Right - ZMSchuifbalkGrootte then Result := spLineDown
    else if Punt.X < Duim.Left then Result := spPageUp
    else if Punt.X >= Duim.Right then Result := spPageDown
    else Result := spThumb;
  end;
end;

procedure ZMTekenUitgeschakeldeTekst(Tekenvlak: TCanvas; R: TRect; const Tekst: string; Vlaggen: UINT);
var
  RSchaduw: TRect;
begin
  Tekenvlak.Brush.Style := bsClear;
  RSchaduw := R;
  OffsetRect(RSchaduw, 1, 1);
  Tekenvlak.Font.Color := clBtnHighlight;
  DrawText(Tekenvlak.Handle, PChar(Tekst), Length(Tekst), RSchaduw, Vlaggen);
  Tekenvlak.Font.Color := clBtnShadow;
  DrawText(Tekenvlak.Handle, PChar(Tekst), Length(Tekst), R, Vlaggen);
end;

end.

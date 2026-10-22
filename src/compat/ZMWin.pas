unit ZMWin;

{ Vensterbeheer en berichtenwachtrij van de compatlaag.

  Er is één geëmuleerd scherm (een 32-bits bitmap, standaard 1024x768). Topniveauvensters
  staan erop, kindvensters binnen hun ouders; elk venster tekent rechtstreeks in het
  scherm via vensters-DC's waarvan het zichtbare gebied overlappende zusters en kinderen
  uitsluit (WS_CLIPSIBLINGS | WS_CLIPCHILDREN-semantiek), precies zoals bij niet-
  gecomposeerd Windows. De backend toont het scherm.

  Berichten: een wachtrij met geplaatste berichten, SendMessage = directe aanroep,
  WM_PAINT en WM_TIMER worden gesynthetiseerd wanneer de wachtrij leeg is, invoer komt van
  de backend. Al het wachten loopt via ZMWachtOpBericht (WaitMessage/GetMessage), de enige
  plek waar het programma blokkeert; een browserbackend haakt daar in. }

{$MODE DELPHI}{$H+}{$R-}{$Q-}

interface

uses Windows, Messages, ZMGdi, ZMPlatform;

type
  TZMVenster = class;
  TZMVensterArray = array of TZMVenster;

  TZMVenster = class
  public
    Handle: HWND;
    Parent: TZMVenster;
    Owner: HWND;
    Kindvensters: TZMVensterArray;       { z-volgorde: index 0 = onderste }
    VensterKlasseNaam: string;
    KlasseStijl: UINT;
    KlasseKwast: HBRUSH;
    KlasseAanwijzer: HCURSOR;
    Style, ExStyle: DWORD;
    R: TRect;                        { vensterrechthoek in clientcoördinaten van de ouder (scherm voor topniveau) }
    Text: string;
    Method: TWndMethod;
    Proc: Pointer;                   { TWndProcFunc als Method niet is toegewezen }
    ID: PtrInt;
    GebruikersData: PtrInt;
    BijwerkRgn: TZMRechtlijst;                { clientcoördinaten }
    WisAchtergrond: Boolean;
    NCVuil: Boolean;
    Destroying: Boolean;
    ZichtGeneratie: Integer;
    ZichtKlientCache, ZichtVensterCache: TZMRechtlijst;
    function NCInsets: TRect;
    function KlientRectScherm: TRect;
    function VensterRectScherm: TRect;
    function IsVisible: Boolean;     { dit venster en alle voorouders hebben WS_VISIBLE }
    function IsIngeschakeldBoom: Boolean;
    function TopLevel: TZMVenster;
  end;

  TZMEnumVensterProc = function(Venster: HWND; Gegevens: Pointer): Boolean;

var
  ZMScherm: TZMBitmap;
  ZMSchermBreedte: Integer = 1024;
  ZMSchermHoogte: Integer = 768;
  ZMAfsluitGevraagd: Boolean = False;
  ZMAfsluitcode: Integer = 0;
  { venster dat WM_CLOSE krijgt wanneer de gebruiker het backendvenster sluit }
  ZMHoofdVenster: HWND = 0;
  { aangeroepen wanneer het platformvenster gesloten wordt; standaard plaatst WM_CLOSE in ZMHoofdVenster }
  ZMBijSluitverzoek: procedure = nil;
  { idle-hook (TApplication.Idle), aangeroepen door WaitMessage vóór het blokkeren }
  ZMBureaubladKleur: LongWord = 0;
  { MessageBox-implementatie (geïnstalleerd door Forms: een dialoog in de framebuffer) }
  ZMBerichtvensterHaak: function(Venster: HWND; const Tekst, Titel: string; Vlaggen: UINT): Integer = nil;

procedure ZMInitialiseer;
procedure ZMAfsluiten;
procedure ZMZetSchermGrootte(Breedte, Hoogte: Integer);
function ZMTikken: LongWord;

function ZMVensterObj(Venster: HWND): TZMVenster;
function ZMMaakVenster(UitStijl: DWORD; const KlasseNaam, Tekst: string; Stijl: DWORD;
  X, Y, Breedte, Hoogte: Integer; Ouder: HWND; Ident: PtrInt; AMethode: TWndMethod; ProcAdres: Pointer): HWND;
function ZMVernietigVenster(Venster: HWND): Boolean;
procedure ZMZetVensterPositie(Venster, Na: HWND; X, Y, Breedte, Hoogte: Integer; Vlaggen: UINT);
function ZMToonVenster(Venster: HWND; Tonen: Boolean): Boolean;
procedure ZMZetOuder(Venster, NieuweOuder: HWND);
function ZMVensterVanPunt(Punt: TPoint; Overslaan: Boolean): HWND;
procedure ZMKlientNaarScherm(Venster: HWND; var Punt: TPoint);
procedure ZMSchermNaarKlient(Venster: HWND; var Punt: TPoint);
procedure ZMOpsommenTopniveau(Terugroep: TZMEnumVensterProc; Gegevens: Pointer);
procedure ZMOpsommenKinderen(Venster: HWND; Terugroep: TZMEnumVensterProc; Gegevens: Pointer);
function ZMLeesVensterInZ(Venster: HWND; Opdracht: UINT): HWND;
procedure ZMZetStijl(Venster: HWND; NieuweStijl: DWORD);
procedure ZMZetUitStijl(Venster: HWND; NieuweUitStijl: DWORD);

{ tekenen }
procedure ZMMaakOngeldig(Venster: HWND; R: PRect; Wissen: Boolean);
procedure ZMMaakBoomOngeldig(VensterObj: TZMVenster; const SchermR: TRect);
procedure ZMMaakSchermOngeldig(const SchermR: TRect);
procedure ZMMaakGeldig(Venster: HWND; R: PRect);
function ZMLeesBijwerkRect(Venster: HWND; var R: TRect): Boolean;
function ZMLeesDC(Venster: HWND; HeelVenster: Boolean): HDC;
procedure ZMGeefDCVrij(DC: HDC);
function ZMBeginTekenen(Venster: HWND; var TekenInfo: TPaintStruct): HDC;
procedure ZMEindeTekenen(Venster: HWND; const TekenInfo: TPaintStruct);
procedure ZMVerversVenster(Venster: HWND);
procedure ZMTekenNC(VensterObj: TZMVenster);

{ berichten }
function ZMPlaatsBericht(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): Boolean;
function ZMZendBericht(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
function ZMBekijkBericht(var Melding: TMsg; Venster: HWND; MinBericht, MaxBericht, Verwijderen: UINT): Boolean;
function ZMLeesBericht(var Melding: TMsg; Venster: HWND; MinBericht, MaxBericht: UINT): Boolean;
procedure ZMVertaalBericht(const Melding: TMsg);
function ZMVerwerkBericht(const Melding: TMsg): LRESULT;
procedure ZMWachtOpBericht;
function ZMStandaardVensterProc(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
function ZMRoepVensterAan(VensterObj: TZMVenster; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
procedure ZMPeilInvoer;
procedure ZMPresenteer(Forceer: Boolean);
function ZMBerichtPositie: TPoint;
function ZMBerichtTijd: LongWord;

{ timers }
function ZMZetTimer(Venster: HWND; Ident, Verstreken: UINT; Terugroep: Pointer): UINT;
function ZMVerwijderTimer(Venster: HWND; Ident: UINT): Boolean;
function ZMVoegMMTimerToe(Vertraging: UINT; Terugroep: Pointer; Gebruiker: PtrUInt; Periodiek: Boolean): UINT;
function ZMVerwijderMMTimer(Ident: UINT): Boolean;

{ focus, activering, capture, invoerstatus }
function ZMZetFocus(Venster: HWND): HWND;
function ZMLeesFocus: HWND;
function ZMZetActief(Venster: HWND): HWND;
function ZMLeesActief: HWND;
function ZMZetVastlegging(Venster: HWND): HWND;
function ZMLeesVastlegging: HWND;
procedure ZMGeefVastleggingVrij;
function ZMSchakelVensterIn(Venster: HWND; Inschakelen: Boolean): Boolean;
function ZMToetsStatus(Toets: Integer): SmallInt;
function ZMAanwijzerPositie: TPoint;
procedure ZMZetAanwijzerPositie(X, Y: Integer);
procedure ZMZetAanwijzerVorm(Aanwijzer: HCURSOR);
function ZMAanwijzerVanId(Ident: PtrUInt): HCURSOR;

procedure ZMDumpVensters;

{ Synthetische invoer, in de wachtrij gezet zoals backend-gebeurtenissen (werkt ook headless).
  Coördinaten zijn relatief aan het clientgebied van het hoofdformulier (ZMHoofdVenster; het
  scherm als die er niet is). Button: 0 = alleen verplaatsen, 1 = links, 2 = rechts. }
procedure ZMInjecteerMuis(X, Y: Integer; Knop: Integer; Omlaag: Boolean);
procedure ZMInjecteerToets(Toets: Word; Omlaag: Boolean);
procedure ZMInjecteerKarakter(Karakter: Char);

{ testondersteuning: sla het geëmuleerde scherm op als PNG }
function ZMBewaarSchermafdruk(const Bestandsnaam: string): Boolean;

implementation

uses SysUtils, Classes, ZMHandles, ddraw{$IFNDEF ZM_NO_SDL3}, ZMSdl3Backend{$ENDIF};

type
  TTimerRec = record
    Wnd: HWND;
    ID: UINT;
    Interval: UINT;
    Due: LongWord;
    Proc: Pointer;
    Pending: Boolean;
    Active: Boolean;
    IsMM: Boolean;
    User: PtrUInt;
    Periodic: Boolean;
  end;

var
  TopLevels: TZMVensterArray;      { z-volgorde: 0 = onderste }
  Queue: array of TMsg;
  QHead, QCount: Integer;
  Timers: array of TTimerRec;
  NextTimerID: UINT = 1000;
  FocusWnd, ActiveWnd, CaptureWnd: HWND;
  KeyDown: array[0..255] of Boolean;
  MousePos: TPoint;
  LastMsgPos: TPoint;
  LastMsgTime: LongWord;
  LastPresent: LongWord;
  Initialized: Boolean = False;
  BackendOpen: Boolean = False;
  LastClickTime: LongWord;
  LastClickPos: TPoint;
  LastClickBtn: Integer;
  LastClickWnd: HWND;
  InSend: Integer;
  CurCursor: HCURSOR;
  DesktopDirty: Boolean;
  OrigScreenW, OrigScreenH: Integer;
  StartTicks: LongWord;
  ShotFile: string;
  ShotAt: Integer;
  ExitAt: Integer = -1;
  Injected: array of TZMGebeurtenis;
  InIdleHook: Boolean = False;
  SyntheticMove: Boolean = False;
  MouseSeen: Boolean = False;
  Script: string;
  ScriptPos: Integer;

const
  CAPTION_H = 18;

{ ---------------------------------------------------------------- basis }

var
  TikBegin: Int64 = -1;

{ Milliseconden sinds de start van het programma (GetTickCount, timeGetTime). Windows telt vanaf
  het opstarten van de computer; ZM_TIKBEGIN=<ms> laat de teller bij die waarde beginnen, om
  gedrag bij een grote tikteller na te spelen (zie ZMKlok). }
function ZMTikken: LongWord;
begin
  if TikBegin < 0 then
    TikBegin := StrToInt64Def(GetEnvironmentVariable('ZM_TIKBEGIN'), 0);
  Result := LongWord(Int64(ZMBackend.KloktijdMs) + TikBegin);
end;

function ZMVensterObj(Venster: HWND): TZMVenster;
var
  Obj: TObject;
begin
  Obj := ZMGreepVoorwerp(Venster);
  if (Obj <> nil) and (Obj is TZMVenster) then Result := TZMVenster(Obj) else Result := nil;
end;

procedure ZichtVerhogen;
begin
  Inc(ZMZichtGeneratie);
end;

function TZMVenster.NCInsets: TRect;
var
  Rand: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  Rand := 0;
  if Style and WS_THICKFRAME <> 0 then Rand := 4
  else if (Style and WS_DLGFRAME <> 0) or (ExStyle and WS_EX_DLGMODALFRAME <> 0) then Rand := 3
  else if Style and WS_BORDER <> 0 then Rand := 1;
  if ExStyle and WS_EX_CLIENTEDGE <> 0 then Inc(Rand, 2);
  if ExStyle and WS_EX_STATICEDGE <> 0 then Inc(Rand, 1);
  Result := Rect(Rand, Rand, Rand, Rand);
  if Style and WS_CAPTION = WS_CAPTION then Inc(Result.Top, CAPTION_H + 1);
end;

function TZMVenster.VensterRectScherm: TRect;
var
  Ouder: TZMVenster;
  Marge: TRect;
begin
  Result := R;
  Ouder := Parent;
  while Ouder <> nil do
  begin
    Marge := Ouder.NCInsets;
    OffsetRect(Result, Ouder.R.Left + Marge.Left, Ouder.R.Top + Marge.Top);
    Ouder := Ouder.Parent;
  end;
end;

function TZMVenster.KlientRectScherm: TRect;
var
  Marge: TRect;
begin
  Result := VensterRectScherm;
  Marge := NCInsets;
  Inc(Result.Left, Marge.Left);
  Inc(Result.Top, Marge.Top);
  Dec(Result.Right, Marge.Right);
  Dec(Result.Bottom, Marge.Bottom);
  if Result.Right < Result.Left then Result.Right := Result.Left;
  if Result.Bottom < Result.Top then Result.Bottom := Result.Top;
end;

function TZMVenster.IsVisible: Boolean;
var
  VensterObj: TZMVenster;
begin
  VensterObj := Self;
  while VensterObj <> nil do
  begin
    if VensterObj.Style and WS_VISIBLE = 0 then Exit(False);
    VensterObj := VensterObj.Parent;
  end;
  Result := True;
end;

function TZMVenster.IsIngeschakeldBoom: Boolean;
var
  VensterObj: TZMVenster;
begin
  VensterObj := Self;
  while VensterObj <> nil do
  begin
    if VensterObj.Style and WS_DISABLED <> 0 then Exit(False);
    VensterObj := VensterObj.Parent;
  end;
  Result := True;
end;

function TZMVenster.TopLevel: TZMVenster;
begin
  Result := Self;
  while Result.Parent <> nil do Result := Result.Parent;
end;

{ ---------------------------------------------------------------- zichtbaarheid }

procedure BerekenZicht(VensterObj: TZMVenster);
var
  Zichtbaar, VensterGebied: TZMRechtlijst;
  Voorouder, Zus: TZMVenster;
  I, Plaats: Integer;
  Zusters: TZMVensterArray;
  KlientR: TRect;
begin
  VensterObj.ZichtGeneratie := ZMZichtGeneratie;
  VensterObj.ZichtKlientCache := nil;
  VensterObj.ZichtVensterCache := nil;
  if not VensterObj.IsVisible then Exit;
  SetLength(VensterGebied, 1);
  VensterGebied[0] := VensterObj.VensterRectScherm;
  { knip bij tot de clientgebieden van de voorouders }
  Voorouder := VensterObj.Parent;
  while Voorouder <> nil do
  begin
    VensterGebied := RechtlijstSnijdRechthoek(VensterGebied, Voorouder.KlientRectScherm);
    Voorouder := Voorouder.Parent;
  end;
  VensterGebied := RechtlijstSnijdRechthoek(VensterGebied, Rect(0, 0, ZMSchermBreedte, ZMSchermHoogte));
  { trek zusters boven W en boven elke voorouder af }
  Voorouder := VensterObj;
  while Voorouder <> nil do
  begin
    if Voorouder.Parent = nil then Zusters := TopLevels else Zusters := Voorouder.Parent.Kindvensters;
    Plaats := -1;
    for I := 0 to High(Zusters) do
      if Zusters[I] = Voorouder then begin Plaats := I; Break; end;
    for I := Plaats + 1 to High(Zusters) do
    begin
      Zus := Zusters[I];
      if Zus.Style and WS_VISIBLE <> 0 then
        VensterGebied := RechtlijstAftrekRechthoek(VensterGebied, Zus.VensterRectScherm);
    end;
    Voorouder := Voorouder.Parent;
  end;
  VensterObj.ZichtVensterCache := VensterGebied;
  KlientR := VensterObj.KlientRectScherm;
  Zichtbaar := RechtlijstSnijdRechthoek(VensterGebied, KlientR);
  for I := 0 to High(VensterObj.Kindvensters) do
    if VensterObj.Kindvensters[I].Style and WS_VISIBLE <> 0 then
      Zichtbaar := RechtlijstAftrekRechthoek(Zichtbaar, VensterObj.Kindvensters[I].VensterRectScherm);
  VensterObj.ZichtKlientCache := Zichtbaar;
  { de vensterrechthoek min de kinderen ook (voor vensters-DC's) }
  for I := 0 to High(VensterObj.Kindvensters) do
    if VensterObj.Kindvensters[I].Style and WS_VISIBLE <> 0 then
      VensterObj.ZichtVensterCache := RechtlijstAftrekRechthoek(VensterObj.ZichtVensterCache, VensterObj.Kindvensters[I].VensterRectScherm);
end;

function ZichtKlient(VensterObj: TZMVenster): TZMRechtlijst;
begin
  if VensterObj.ZichtGeneratie <> ZMZichtGeneratie then BerekenZicht(VensterObj);
  Result := VensterObj.ZichtKlientCache;
end;

function ZichtVenster(VensterObj: TZMVenster): TZMRechtlijst;
begin
  if VensterObj.ZichtGeneratie <> ZMZichtGeneratie then BerekenZicht(VensterObj);
  Result := VensterObj.ZichtVensterCache;
end;

procedure DCZichtLeverancier(DCObjekt: TObject);
var
  DC: TZMDC;
  VensterObj: TZMVenster;
  R: TRect;
begin
  DC := TZMDC(DCObjekt);
  VensterObj := ZMVensterObj(DC.Wnd);
  if VensterObj = nil then
  begin
    DC.ZichtRegio := nil;
    Exit;
  end;
  if DC.IsVensterDC then
  begin
    DC.ZichtRegio := ZichtVenster(VensterObj);
    R := VensterObj.VensterRectScherm;
  end
  else
  begin
    DC.ZichtRegio := ZichtKlient(VensterObj);
    R := VensterObj.KlientRectScherm;
  end;
  DC.ApparaatOorsprong := Point(R.Left, R.Top);
  DC.MaakKnipOngeldig;
end;

{ ---------------------------------------------------------------- initialisatie }

function StandaardSluitVerzoek: Boolean;
begin
  Result := True;
end;

procedure ZMInitialiseer;
begin
  if Initialized then Exit;
  Initialized := True;
  InitStandaardObjecten;
  ZMZichtLeverancier := DCZichtLeverancier;
  ZMScherm := TZMBitmap.Create(ZMSchermBreedte, ZMSchermHoogte, 32);
  ZMScherm.Vuil := True;
  OrigScreenW := ZMSchermBreedte;
  OrigScreenH := ZMSchermHoogte;
end;

procedure ZorgVoorBackend;
begin
  if BackendOpen then Exit;
  ZMInitialiseer;
  BackendOpen := True;
  if not ZMBackend.Open('Virtueel Zoetermeer', ZMSchermBreedte, ZMSchermHoogte) then
  begin
    WriteLn(StdErr, 'compat: geen beeldschermbackend, draait headless');
    ZMValTerugOpNul;
    ZMBackend.Open('Virtueel Zoetermeer', ZMSchermBreedte, ZMSchermHoogte);
  end;
  StartTicks := ZMTikken;
  ShotFile := GetEnvironmentVariable('ZM_SCREENSHOT');
  ShotAt := StrToIntDef(GetEnvironmentVariable('ZM_SCREENSHOT_AT'), 3000);
  ExitAt := StrToIntDef(GetEnvironmentVariable('ZM_EXIT_AT'), -1);
  Script := GetEnvironmentVariable('ZM_SCRIPT');
  ScriptPos := 1;
end;

procedure ZMAfsluiten;
begin
  if BackendOpen then ZMBackend.Close;
  BackendOpen := False;
end;

procedure ZMZetSchermGrootte(Breedte, Hoogte: Integer);
var
  NieuwScherm: TZMBitmap;
begin
  ZMInitialiseer;
  if (Breedte = ZMSchermBreedte) and (Hoogte = ZMSchermHoogte) then Exit;
  NieuwScherm := TZMBitmap.Create(Breedte, Hoogte, 32);
  ZMScherm.Free;
  ZMScherm := NieuwScherm;
  ZMSchermBreedte := Breedte;
  ZMSchermHoogte := Hoogte;
  ZichtVerhogen;
  if BackendOpen then ZMBackend.Resize(Breedte, Hoogte);
  ZMMaakSchermOngeldig(Rect(0, 0, Breedte, Hoogte));
end;

function DDZetModus(Breedte, Hoogte, Bitdiepte: Integer): Boolean;
begin
  { het beeldscherm wordt op een vaste grootte geëmuleerd; modusveranderingen worden geaccepteerd }
  Result := True;
end;

procedure DDHerstelModus;
begin
end;

{ ---------------------------------------------------------------- aanmaak }

type
  TVensterLijst = TZMVensterArray;

procedure LijstVerwijder(var Lijst: TVensterLijst; VensterObj: TZMVenster);
var
  I, J: Integer;
begin
  for I := 0 to High(Lijst) do
    if Lijst[I] = VensterObj then
    begin
      for J := I to High(Lijst) - 1 do Lijst[J] := Lijst[J + 1];
      SetLength(Lijst, Length(Lijst) - 1);
      Exit;
    end;
end;

procedure LijstInvoeg(var Lijst: TVensterLijst; VensterObj: TZMVenster; Plaats: Integer);
var
  J: Integer;
begin
  if (Plaats < 0) or (Plaats > Length(Lijst)) then Plaats := Length(Lijst);
  SetLength(Lijst, Length(Lijst) + 1);
  for J := High(Lijst) downto Plaats + 1 do Lijst[J] := Lijst[J - 1];
  Lijst[Plaats] := VensterObj;
end;

function ZustersVan(VensterObj: TZMVenster): TVensterLijst;
begin
  if VensterObj.Parent = nil then Result := TopLevels else Result := VensterObj.Parent.Kindvensters;
end;

procedure ZetZusters(VensterObj: TZMVenster; const Lijst: TVensterLijst);
begin
  if VensterObj.Parent = nil then TopLevels := Lijst else VensterObj.Parent.Kindvensters := Lijst;
end;

{ invoegindex, rekening houdend met WS_EX_TOPMOST voor topniveauvensters }
function BovensteInvoegIndex(const Lijst: TVensterLijst; VensterObj: TZMVenster): Integer;
begin
  Result := Length(Lijst);
  if (VensterObj.Parent = nil) and (VensterObj.ExStyle and WS_EX_TOPMOST = 0) then
    while (Result > 0) and (Lijst[Result - 1].ExStyle and WS_EX_TOPMOST <> 0) do Dec(Result);
end;

function ZMMaakVenster(UitStijl: DWORD; const KlasseNaam, Tekst: string; Stijl: DWORD;
  X, Y, Breedte, Hoogte: Integer; Ouder: HWND; Ident: PtrInt; AMethode: TWndMethod; ProcAdres: Pointer): HWND;
var
  VensterObj: TZMVenster;
  OuderObj: TZMVenster;
  Lijst: TVensterLijst;
  Maakstruct: TCreateStruct;
begin
  ZMInitialiseer;
  VensterObj := TZMVenster.Create;
  VensterObj.Handle := ZMReserveerGreep(VensterObj);
  VensterObj.VensterKlasseNaam := KlasseNaam;
  VensterObj.KlasseStijl := CS_DBLCLKS;
  VensterObj.Style := Stijl;
  VensterObj.ExStyle := UitStijl;
  VensterObj.Text := Tekst;
  VensterObj.Method := AMethode;
  VensterObj.Proc := ProcAdres;
  VensterObj.ID := Ident;
  if Breedte < 0 then Breedte := 0;
  if Hoogte < 0 then Hoogte := 0;
  VensterObj.R := Rect(X, Y, X + Breedte, Y + Hoogte);
  OuderObj := ZMVensterObj(Ouder);
  if (OuderObj <> nil) and (Stijl and WS_CHILD <> 0) then
  begin
    VensterObj.Parent := OuderObj;
    Lijst := OuderObj.Kindvensters;
    LijstInvoeg(Lijst, VensterObj, Length(Lijst));
    OuderObj.Kindvensters := Lijst;
  end
  else
  begin
    if OuderObj <> nil then VensterObj.Owner := Ouder;
    Lijst := TopLevels;
    LijstInvoeg(Lijst, VensterObj, BovensteInvoegIndex(Lijst, VensterObj));
    TopLevels := Lijst;
  end;
  VensterObj.NCVuil := True;
  ZichtVerhogen;
  Result := VensterObj.Handle;
  FillChar(Maakstruct, SizeOf(Maakstruct), 0);
  Maakstruct.x := X; Maakstruct.y := Y; Maakstruct.cx := Breedte; Maakstruct.cy := Hoogte;
  Maakstruct.style := Stijl;
  Maakstruct.dwExStyle := UitStijl;
  Maakstruct.hwndParent := Ouder;
  ZMRoepVensterAan(VensterObj, WM_NCCREATE, 0, LPARAM(@Maakstruct));
  ZMRoepVensterAan(VensterObj, WM_CREATE, 0, LPARAM(@Maakstruct));
  if Stijl and WS_VISIBLE <> 0 then
    ZMMaakSchermOngeldig(VensterObj.VensterRectScherm);
end;

function ZMVernietigVenster(Venster: HWND): Boolean;
var
  VensterObj: TZMVenster;
  Lijst: TVensterLijst;
  VensterR: TRect;
  WasZichtbaar: Boolean;
  I: Integer;
begin
  VensterObj := ZMVensterObj(Venster);
  if (VensterObj = nil) or VensterObj.Destroying then Exit(False);
  VensterObj.Destroying := True;
  WasZichtbaar := VensterObj.IsVisible;
  VensterR := VensterObj.VensterRectScherm;
  if WasZichtbaar then
  begin
    VensterObj.Style := VensterObj.Style and not WS_VISIBLE;
    ZichtVerhogen;
  end;
  ZMRoepVensterAan(VensterObj, WM_DESTROY, 0, 0);
  while Length(VensterObj.Kindvensters) > 0 do
    if not ZMVernietigVenster(VensterObj.Kindvensters[High(VensterObj.Kindvensters)].Handle) then
    begin
      Lijst := VensterObj.Kindvensters;
      SetLength(Lijst, Length(Lijst) - 1);
      VensterObj.Kindvensters := Lijst;
    end;
  { eigen topniveauvensters gaan mee met hun eigenaar }
  I := 0;
  while I <= High(TopLevels) do
  begin
    if (TopLevels[I].Owner = Venster) and not TopLevels[I].Destroying then
    begin
      ZMVernietigVenster(TopLevels[I].Handle);
      I := 0;
    end
    else
      Inc(I);
  end;
  ZMRoepVensterAan(VensterObj, WM_NCDESTROY, 0, 0);
  for I := 0 to High(Timers) do
    if Timers[I].Active and (Timers[I].Wnd = Venster) then Timers[I].Active := False;
  if FocusWnd = Venster then FocusWnd := 0;
  if CaptureWnd = Venster then CaptureWnd := 0;
  if ActiveWnd = Venster then ActiveWnd := 0;
  if ZMHoofdVenster = Venster then ZMHoofdVenster := 0;
  Lijst := ZustersVan(VensterObj);
  LijstVerwijder(Lijst, VensterObj);
  ZetZusters(VensterObj, Lijst);
  { verwijder wachtende berichten voor dit venster }
  for I := 0 to QCount - 1 do
    if Queue[(QHead + I) mod Length(Queue)].hwnd = Venster then
      Queue[(QHead + I) mod Length(Queue)].message := WM_NULL;
  ZichtVerhogen;
  if WasZichtbaar then ZMMaakSchermOngeldig(VensterR);
  ZMGeefGreepVrij(Venster);
  VensterObj.Free;
  if (ActiveWnd = 0) and (Length(TopLevels) > 0) then
  begin
    for I := High(TopLevels) downto 0 do
      if TopLevels[I].IsVisible and TopLevels[I].IsIngeschakeldBoom then
      begin
        ZMZetActief(TopLevels[I].Handle);
        Break;
      end;
  end;
  Result := True;
end;

procedure ZMZetStijl(Venster: HWND; NieuweStijl: DWORD);
var
  VensterObj: TZMVenster;
begin
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  if VensterObj.Style = NieuweStijl then Exit;
  VensterObj.Style := NieuweStijl;
  ZichtVerhogen;
  VensterObj.NCVuil := True;
  if VensterObj.IsVisible then ZMMaakSchermOngeldig(VensterObj.VensterRectScherm);
end;

procedure ZMZetUitStijl(Venster: HWND; NieuweUitStijl: DWORD);
var
  VensterObj: TZMVenster;
begin
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  VensterObj.ExStyle := NieuweUitStijl;
  ZichtVerhogen;
  VensterObj.NCVuil := True;
  if VensterObj.IsVisible then ZMMaakSchermOngeldig(VensterObj.VensterRectScherm);
end;

procedure ZMZetVensterPositie(Venster, Na: HWND; X, Y, Breedte, Hoogte: Integer; Vlaggen: UINT);
var
  VensterObj: TZMVenster;
  OudR, OudScherm, NieuwScherm: TRect;
  Lijst: TVensterLijst;
  Verplaatst, Hergrootd, WasZichtbaar, Gewijzigd: Boolean;
  Positie: TWindowPos;
  I: Integer;
begin
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  OudR := VensterObj.R;
  WasZichtbaar := VensterObj.IsVisible;
  OudScherm := VensterObj.VensterRectScherm;
  Gewijzigd := False;
  if Vlaggen and SWP_NOMOVE = 0 then
  begin
    if (X <> OudR.Left) or (Y <> OudR.Top) then
    begin
      OffsetRect(VensterObj.R, X - VensterObj.R.Left, Y - VensterObj.R.Top);
      Gewijzigd := True;
    end;
  end;
  if Vlaggen and SWP_NOSIZE = 0 then
  begin
    if Breedte < 0 then Breedte := 0;
    if Hoogte < 0 then Hoogte := 0;
    if (Breedte <> VensterObj.R.Right - VensterObj.R.Left) or (Hoogte <> VensterObj.R.Bottom - VensterObj.R.Top) then
    begin
      VensterObj.R.Right := VensterObj.R.Left + Breedte;
      VensterObj.R.Bottom := VensterObj.R.Top + Hoogte;
      Gewijzigd := True;
    end;
  end;
  if Vlaggen and SWP_NOZORDER = 0 then
  begin
    Lijst := ZustersVan(VensterObj);
    LijstVerwijder(Lijst, VensterObj);
    if Na = HWND_TOPMOST then
    begin
      VensterObj.ExStyle := VensterObj.ExStyle or WS_EX_TOPMOST;
      LijstInvoeg(Lijst, VensterObj, Length(Lijst));
    end
    else if Na = HWND_NOTOPMOST then
    begin
      VensterObj.ExStyle := VensterObj.ExStyle and not WS_EX_TOPMOST;
      LijstInvoeg(Lijst, VensterObj, BovensteInvoegIndex(Lijst, VensterObj));
    end
    else if Na = HWND_TOP then
      LijstInvoeg(Lijst, VensterObj, BovensteInvoegIndex(Lijst, VensterObj))
    else if Na = HWND_BOTTOM then
      LijstInvoeg(Lijst, VensterObj, 0)
    else
    begin
      { plaats onder After }
      I := 0;
      while (I <= High(Lijst)) and (Lijst[I].Handle <> Na) do Inc(I);
      if I > High(Lijst) then LijstInvoeg(Lijst, VensterObj, BovensteInvoegIndex(Lijst, VensterObj))
      else LijstInvoeg(Lijst, VensterObj, I);
    end;
    ZetZusters(VensterObj, Lijst);
    Gewijzigd := True;
  end;
  if Vlaggen and SWP_SHOWWINDOW <> 0 then
  begin
    if VensterObj.Style and WS_VISIBLE = 0 then Gewijzigd := True;
    VensterObj.Style := VensterObj.Style or WS_VISIBLE;
  end;
  if Vlaggen and SWP_HIDEWINDOW <> 0 then
  begin
    if VensterObj.Style and WS_VISIBLE <> 0 then Gewijzigd := True;
    VensterObj.Style := VensterObj.Style and not WS_VISIBLE;
  end;
  if Vlaggen and SWP_FRAMECHANGED <> 0 then Gewijzigd := True;
  if not Gewijzigd then Exit;
  ZichtVerhogen;
  VensterObj.NCVuil := True;
  if WasZichtbaar then ZMMaakSchermOngeldig(OudScherm);
  NieuwScherm := VensterObj.VensterRectScherm;
  if VensterObj.IsVisible then ZMMaakSchermOngeldig(NieuwScherm);
  if PtInRect(OudScherm, MousePos) or PtInRect(NieuwScherm, MousePos) then SyntheticMove := True;
  Verplaatst := (OudR.Left <> VensterObj.R.Left) or (OudR.Top <> VensterObj.R.Top);
  Hergrootd := (OudR.Right - OudR.Left <> VensterObj.R.Right - VensterObj.R.Left) or
    (OudR.Bottom - OudR.Top <> VensterObj.R.Bottom - VensterObj.R.Top);
  Positie.hwnd := Venster;
  Positie.hwndInsertAfter := Na;
  Positie.x := VensterObj.R.Left; Positie.y := VensterObj.R.Top;
  Positie.cx := VensterObj.R.Right - VensterObj.R.Left; Positie.cy := VensterObj.R.Bottom - VensterObj.R.Top;
  Positie.flags := Vlaggen;
  if Vlaggen and SWP_NOSENDCHANGING = 0 then
    ZMRoepVensterAan(VensterObj, WM_WINDOWPOSCHANGED, 0, LPARAM(@Positie));
  if Verplaatst then
    ZMRoepVensterAan(VensterObj, WM_MOVE, 0, MakeLParam(Word(VensterObj.R.Left), Word(VensterObj.R.Top)));
  if Hergrootd then
    with VensterObj.KlientRectScherm do
      ZMRoepVensterAan(VensterObj, WM_SIZE, SIZE_RESTORED, MakeLParam(Word(Right - Left), Word(Bottom - Top)));
  if (Vlaggen and SWP_SHOWWINDOW <> 0) and not WasZichtbaar then
    ZMRoepVensterAan(VensterObj, WM_SHOWWINDOW, 1, 0)
  else if (Vlaggen and SWP_HIDEWINDOW <> 0) and WasZichtbaar then
    ZMRoepVensterAan(VensterObj, WM_SHOWWINDOW, 0, 0);
end;

function ZMToonVenster(Venster: HWND; Tonen: Boolean): Boolean;
var
  VensterObj: TZMVenster;
begin
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit(False);
  Result := VensterObj.Style and WS_VISIBLE <> 0;
  if Tonen = Result then Exit;
  if Tonen then
    ZMZetVensterPositie(Venster, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_SHOWWINDOW)
  else
  begin
    ZMZetVensterPositie(Venster, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_HIDEWINDOW);
    if (FocusWnd <> 0) then
    begin
      { focus binnen een verborgen venster gaat verloren }
      if (FocusWnd = Venster) or (IsChild(Venster, FocusWnd)) then ZMZetFocus(0);
    end;
    if ActiveWnd = Venster then
    begin
      ActiveWnd := 0;
    end;
  end;
end;

procedure ZMZetOuder(Venster, NieuweOuder: HWND);
var
  VensterObj, OuderObj: TZMVenster;
  Lijst: TVensterLijst;
  WasZichtbaar: Boolean;
  OudScherm: TRect;
begin
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  OuderObj := ZMVensterObj(NieuweOuder);
  if VensterObj.Parent = OuderObj then Exit;
  WasZichtbaar := VensterObj.IsVisible;
  OudScherm := VensterObj.VensterRectScherm;
  Lijst := ZustersVan(VensterObj);
  LijstVerwijder(Lijst, VensterObj);
  ZetZusters(VensterObj, Lijst);
  VensterObj.Parent := OuderObj;
  if OuderObj <> nil then
  begin
    VensterObj.Style := VensterObj.Style or WS_CHILD;
    Lijst := OuderObj.Kindvensters;
  end
  else
    Lijst := TopLevels;
  LijstInvoeg(Lijst, VensterObj, BovensteInvoegIndex(Lijst, VensterObj));
  ZetZusters(VensterObj, Lijst);
  ZichtVerhogen;
  if WasZichtbaar then ZMMaakSchermOngeldig(OudScherm);
  if VensterObj.IsVisible then ZMMaakSchermOngeldig(VensterObj.VensterRectScherm);
end;

function HitTest(const Lijst: TVensterLijst; Punt: TPoint; Overslaan: Boolean): TZMVenster;
var
  I: Integer;
  VensterObj, Kind: TZMVenster;
  R: TRect;
begin
  Result := nil;
  for I := High(Lijst) downto 0 do
  begin
    VensterObj := Lijst[I];
    if VensterObj.Style and WS_VISIBLE = 0 then Continue;
    R := VensterObj.VensterRectScherm;
    if not PtInRect(R, Punt) then Continue;
    if PtInRect(VensterObj.KlientRectScherm, Punt) then
    begin
      Kind := HitTest(VensterObj.Kindvensters, Punt, Overslaan);
      if Kind <> nil then Exit(Kind);
    end;
    if Overslaan and (VensterObj.Style and WS_DISABLED <> 0) then Exit(nil);
    Exit(VensterObj);
  end;
end;

function ZMVensterVanPunt(Punt: TPoint; Overslaan: Boolean): HWND;
var
  VensterObj: TZMVenster;
begin
  VensterObj := HitTest(TopLevels, Punt, Overslaan);
  if VensterObj = nil then Result := 0 else Result := VensterObj.Handle;
end;

procedure ZMKlientNaarScherm(Venster: HWND; var Punt: TPoint);
var
  VensterObj: TZMVenster;
  R: TRect;
begin
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  R := VensterObj.KlientRectScherm;
  Inc(Punt.X, R.Left);
  Inc(Punt.Y, R.Top);
end;

procedure ZMSchermNaarKlient(Venster: HWND; var Punt: TPoint);
var
  VensterObj: TZMVenster;
  R: TRect;
begin
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  R := VensterObj.KlientRectScherm;
  Dec(Punt.X, R.Left);
  Dec(Punt.Y, R.Top);
end;

procedure ZMOpsommenTopniveau(Terugroep: TZMEnumVensterProc; Gegevens: Pointer);
var
  Lijst: TVensterLijst;
  I: Integer;
begin
  Lijst := Copy(TopLevels, 0, Length(TopLevels));
  for I := High(Lijst) downto 0 do
    if not Terugroep(Lijst[I].Handle, Gegevens) then Break;
end;

procedure ZMOpsommenKinderen(Venster: HWND; Terugroep: TZMEnumVensterProc; Gegevens: Pointer);
var
  VensterObj: TZMVenster;
  Lijst: TVensterLijst;
  I: Integer;
begin
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  Lijst := Copy(VensterObj.Kindvensters, 0, Length(VensterObj.Kindvensters));
  for I := High(Lijst) downto 0 do
    if not Terugroep(Lijst[I].Handle, Gegevens) then Break;
end;

function ZMLeesVensterInZ(Venster: HWND; Opdracht: UINT): HWND;
const
  GW_HWNDFIRST = 0; GW_HWNDLAST = 1; GW_HWNDNEXT = 2; GW_HWNDPREV = 3; GW_OWNER = 4; GW_CHILD = 5;
var
  VensterObj: TZMVenster;
  Lijst: TVensterLijst;
  I: Integer;
begin
  Result := 0;
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then
  begin
    if (Venster = 0) and (Opdracht = GW_CHILD) and (Length(TopLevels) > 0) then
      Result := TopLevels[High(TopLevels)].Handle;
    Exit;
  end;
  Lijst := ZustersVan(VensterObj);
  case Opdracht of
    GW_HWNDFIRST: if Length(Lijst) > 0 then Result := Lijst[High(Lijst)].Handle;
    GW_HWNDLAST: if Length(Lijst) > 0 then Result := Lijst[0].Handle;
    GW_HWNDNEXT, GW_HWNDPREV:
      for I := 0 to High(Lijst) do
        if Lijst[I] = VensterObj then
        begin
          if (Opdracht = GW_HWNDNEXT) and (I > 0) then Result := Lijst[I - 1].Handle;
          if (Opdracht = GW_HWNDPREV) and (I < High(Lijst)) then Result := Lijst[I + 1].Handle;
          Break;
        end;
    GW_OWNER: Result := VensterObj.Owner;
    GW_CHILD: if Length(VensterObj.Kindvensters) > 0 then Result := VensterObj.Kindvensters[High(VensterObj.Kindvensters)].Handle;
  end;
end;

{ ---------------------------------------------------------------- tekenen }

procedure VoegBijwerkingToe(VensterObj: TZMVenster; const KlientR: TRect; Wissen: Boolean);
var
  KlientLok: TRect;
  Rechthoeken: TZMRechtlijst;
begin
  with VensterObj.KlientRectScherm do KlientLok := Rect(0, 0, Right - Left, Bottom - Top);
  SetLength(Rechthoeken, 1);
  Rechthoeken[0] := KlientR;
  Rechthoeken := RechtlijstSnijdRechthoek(Rechthoeken, KlientLok);
  if Length(Rechthoeken) = 0 then Exit;
  VensterObj.BijwerkRgn := RechtlijstVereniging(VensterObj.BijwerkRgn, Rechthoeken);
  { houd het gebied klein: vouw het samen tot zijn omhullende rechthoek als het versplintert }
  if Length(VensterObj.BijwerkRgn) > 16 then
  begin
    SetLength(Rechthoeken, 1);
    Rechthoeken[0] := RechtlijstOmhulling(VensterObj.BijwerkRgn);
    VensterObj.BijwerkRgn := Rechthoeken;
  end;
  if Wissen then VensterObj.WisAchtergrond := True;
end;

procedure ZMMaakBoomOngeldig(VensterObj: TZMVenster; const SchermR: TRect);
var
  VensterR, KlientR, Snijding: TRect;
  I: Integer;
begin
  if VensterObj.Style and WS_VISIBLE = 0 then Exit;
  VensterR := VensterObj.VensterRectScherm;
  if not IntersectRect(Snijding, VensterR, SchermR) then Exit;
  KlientR := VensterObj.KlientRectScherm;
  if not EqualRect(VensterR, KlientR) then
    if not (PtInRect(KlientR, Snijding.TopLeft) and PtInRect(KlientR, Point(Snijding.Right - 1, Snijding.Bottom - 1))) then
      VensterObj.NCVuil := True;
  if IntersectRect(Snijding, KlientR, SchermR) then
  begin
    OffsetRect(Snijding, -KlientR.Left, -KlientR.Top);
    VoegBijwerkingToe(VensterObj, Snijding, True);
  end;
  for I := 0 to High(VensterObj.Kindvensters) do
    ZMMaakBoomOngeldig(VensterObj.Kindvensters[I], SchermR);
end;

procedure ZMMaakSchermOngeldig(const SchermR: TRect);
var
  I: Integer;
begin
  ZMInitialiseer;
  for I := 0 to High(TopLevels) do
    ZMMaakBoomOngeldig(TopLevels[I], SchermR);
  DesktopDirty := True;
end;

procedure TekenBureaublad;
var
  Bureaugebied: TZMRechtlijst;
  I, X, Y: Integer;
  Pixel: PLongWord;
begin
  DesktopDirty := False;
  SetLength(Bureaugebied, 1);
  Bureaugebied[0] := Rect(0, 0, ZMSchermBreedte, ZMSchermHoogte);
  for I := 0 to High(TopLevels) do
    if TopLevels[I].Style and WS_VISIBLE <> 0 then
      Bureaugebied := RechtlijstAftrekRechthoek(Bureaugebied, TopLevels[I].VensterRectScherm);
  for I := 0 to High(Bureaugebied) do
    for Y := Bureaugebied[I].Top to Bureaugebied[I].Bottom - 1 do
    begin
      Pixel := PLongWord(ZMScherm.RijPtr(Y)) + Bureaugebied[I].Left;
      for X := Bureaugebied[I].Left to Bureaugebied[I].Right - 1 do
      begin
        Pixel^ := ZMBureaubladKleur;
        Inc(Pixel);
      end;
    end;
  if Length(Bureaugebied) > 0 then ZMScherm.Vuil := True;
end;

procedure ZMMaakOngeldig(Venster: HWND; R: PRect; Wissen: Boolean);
var
  VensterObj: TZMVenster;
  KlientR: TRect;
begin
  if Venster = 0 then
  begin
    if R = nil then ZMMaakSchermOngeldig(Rect(0, 0, ZMSchermBreedte, ZMSchermHoogte))
    else ZMMaakSchermOngeldig(R^);
    Exit;
  end;
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  if R = nil then
  begin
    with VensterObj.KlientRectScherm do KlientR := Rect(0, 0, Right - Left, Bottom - Top);
    VoegBijwerkingToe(VensterObj, KlientR, Wissen);
  end
  else
    VoegBijwerkingToe(VensterObj, R^, Wissen);
end;

procedure ZMMaakGeldig(Venster: HWND; R: PRect);
var
  VensterObj: TZMVenster;
begin
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  if R = nil then
  begin
    VensterObj.BijwerkRgn := nil;
    VensterObj.WisAchtergrond := False;
  end
  else
    VensterObj.BijwerkRgn := RechtlijstAftrekRechthoek(VensterObj.BijwerkRgn, R^);
end;

function ZMLeesBijwerkRect(Venster: HWND; var R: TRect): Boolean;
var
  VensterObj: TZMVenster;
begin
  VensterObj := ZMVensterObj(Venster);
  if (VensterObj = nil) or (Length(VensterObj.BijwerkRgn) = 0) then
  begin
    R := Rect(0, 0, 0, 0);
    Exit(False);
  end;
  R := RechtlijstOmhulling(VensterObj.BijwerkRgn);
  Result := True;
end;

function ZMLeesDC(Venster: HWND; HeelVenster: Boolean): HDC;
var
  DC: TZMDC;
  VensterObj: TZMVenster;
begin
  ZMInitialiseer;
  DC := TZMDC.Create(ZMScherm);
  if Venster = 0 then
  begin
    DC.HeeftZichtbaar := False;
    Exit(DC.Handle);
  end;
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then
  begin
    DC.Free;
    Exit(0);
  end;
  DC.Wnd := Venster;
  DC.IsVensterDC := HeelVenster;
  DC.HeeftZichtbaar := True;
  DCZichtLeverancier(DC);
  DC.ZichtGeneratie := ZMZichtGeneratie;
  Result := DC.Handle;
end;

procedure ZMGeefDCVrij(DC: HDC);
var
  Teken: TZMDC;
begin
  Teken := GdiDC(DC);
  if (Teken <> nil) and not Teken.IsGeheugenDC then Teken.Free;
end;

function ZMBeginTekenen(Venster: HWND; var TekenInfo: TPaintStruct): HDC;
var
  VensterObj: TZMVenster;
  DC: TZMDC;
  KlientR: TRect;
begin
  FillChar(TekenInfo, SizeOf(TekenInfo), 0);
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit(0);
  Result := ZMLeesDC(Venster, False);
  DC := GdiDC(Result);
  KlientR := VensterObj.KlientRectScherm;
  DC.TekenRegio := RechtlijstVerschuif(VensterObj.BijwerkRgn, KlientR.Left, KlientR.Top);
  DC.HeeftTekenRegio := True;
  DC.IsTekenDC := True;
  DC.MaakKnipOngeldig;
  TekenInfo.hdc := Result;
  TekenInfo.rcPaint := RechtlijstOmhulling(VensterObj.BijwerkRgn);
  TekenInfo.fErase := VensterObj.WisAchtergrond;
  VensterObj.BijwerkRgn := nil;
  if VensterObj.WisAchtergrond then
  begin
    VensterObj.WisAchtergrond := False;
    if ZMRoepVensterAan(VensterObj, WM_ERASEBKGND, WPARAM(Result), 0) <> 0 then
      TekenInfo.fErase := False;
  end;
end;

procedure ZMEindeTekenen(Venster: HWND; const TekenInfo: TPaintStruct);
begin
  ZMGeefDCVrij(TekenInfo.hdc);
end;

procedure PaintWindow(VensterObj: TZMVenster);
begin
  if VensterObj.NCVuil then ZMTekenNC(VensterObj);
  if Length(VensterObj.BijwerkRgn) > 0 then
    ZMRoepVensterAan(VensterObj, WM_PAINT, 0, 0);
end;

procedure ZMVerversVenster(Venster: HWND);
var
  VensterObj: TZMVenster;
  I: Integer;
  Kinderen: TVensterLijst;
begin
  VensterObj := ZMVensterObj(Venster);
  if (VensterObj = nil) or not VensterObj.IsVisible then Exit;
  PaintWindow(VensterObj);
  Kinderen := Copy(VensterObj.Kindvensters, 0, Length(VensterObj.Kindvensters));
  for I := 0 to High(Kinderen) do
    if ZMVensterObj(Kinderen[I].Handle) = Kinderen[I] then
      ZMVerversVenster(Kinderen[I].Handle);
end;

procedure ZMTekenNC(VensterObj: TZMVenster);
var
  DC: HDC;
  Teken: TZMDC;
  R, KlientR, TitelR: TRect;
  Marge: TRect;
  Actief: Boolean;
  Lettertype: TLogFont;
  FontObj: TZMLetterObj;
  OudFont: TZMLetterObj;
  procedure Kader(const Gebied: TRect; LinksBoven, RechtsOnder: COLORREF);
  begin
    GdiVulEffen(Teken, Rect(Gebied.Left, Gebied.Top, Gebied.Right - 1, Gebied.Top + 1), LinksBoven);
    GdiVulEffen(Teken, Rect(Gebied.Left, Gebied.Top, Gebied.Left + 1, Gebied.Bottom - 1), LinksBoven);
    GdiVulEffen(Teken, Rect(Gebied.Left, Gebied.Bottom - 1, Gebied.Right, Gebied.Bottom), RechtsOnder);
    GdiVulEffen(Teken, Rect(Gebied.Right - 1, Gebied.Top, Gebied.Right, Gebied.Bottom), RechtsOnder);
  end;
begin
  VensterObj.NCVuil := False;
  Marge := VensterObj.NCInsets;
  if (Marge.Left = 0) and (Marge.Top = 0) and (Marge.Right = 0) and (Marge.Bottom = 0) then Exit;
  if not VensterObj.IsVisible then Exit;
  DC := ZMLeesDC(VensterObj.Handle, True);
  Teken := GdiDC(DC);
  try
    { sluit het clientgebied uit }
    R := Rect(0, 0, VensterObj.R.Right - VensterObj.R.Left, VensterObj.R.Bottom - VensterObj.R.Top);
    KlientR := Rect(Marge.Left, Marge.Top, R.Right - Marge.Right, R.Bottom - Marge.Bottom);
    Teken.St.HeeftKnip := True;
    SetLength(Teken.St.KnipRegio, 1);
    Teken.St.KnipRegio[0] := R;
    Teken.St.KnipRegio := RechtlijstAftrekRechthoek(Teken.St.KnipRegio, KlientR);
    Teken.MaakKnipOngeldig;
    if VensterObj.ExStyle and WS_EX_CLIENTEDGE <> 0 then
    begin
      Kader(Rect(KlientR.Left - 2, KlientR.Top - 2, KlientR.Right + 2, KlientR.Bottom + 2), $808080, $FFFFFF);
      Kader(Rect(KlientR.Left - 1, KlientR.Top - 1, KlientR.Right + 1, KlientR.Bottom + 1), $404040, $C0C0C0);
    end;
    if VensterObj.ExStyle and WS_EX_STATICEDGE <> 0 then
      Kader(Rect(KlientR.Left - 1, KlientR.Top - 1, KlientR.Right + 1, KlientR.Bottom + 1), $808080, $FFFFFF);
    if (VensterObj.Style and (WS_THICKFRAME or WS_DLGFRAME) <> 0) or (VensterObj.ExStyle and WS_EX_DLGMODALFRAME <> 0) then
    begin
      GdiVulEffen(Teken, R, SysteemKleuren[COLOR_BTNFACE]);
      Kader(R, $C0C0C0, $000000);
      Kader(Rect(1, 1, R.Right - 1, R.Bottom - 1), $FFFFFF, $808080);
    end
    else if VensterObj.Style and WS_BORDER <> 0 then
      Kader(R, $000000, $000000);
    if VensterObj.Style and WS_CAPTION = WS_CAPTION then
    begin
      Actief := (ActiveWnd = VensterObj.Handle);
      TitelR := Rect(Marge.Left, Marge.Top - CAPTION_H - 1, R.Right - Marge.Right, Marge.Top - 1);
      if Actief then GdiVulEffen(Teken, TitelR, SysteemKleuren[COLOR_ACTIVECAPTION])
      else GdiVulEffen(Teken, TitelR, SysteemKleuren[COLOR_INACTIVECAPTION]);
      FillChar(Lettertype, SizeOf(Lettertype), 0);
      Lettertype.lfHeight := -11;
      Lettertype.lfWeight := FW_BOLD;
      Lettertype.lfFaceName := 'MS Sans Serif';
      FontObj := TZMLetterObj.Create(Lettertype);
      OudFont := Teken.St.Font;
      Teken.St.Font := FontObj;
      Teken.St.BkMode := TRANSPARENT;
      if Actief then Teken.St.TekstKleurVoor := $FFFFFF else Teken.St.TekstKleurVoor := $C0C0C0;
      GdiTekstUit(Teken, TitelR.Left + 4, TitelR.Top + (CAPTION_H - FontObj.Lettergezicht^.Height) div 2,
        PAnsiChar(AnsiString(VensterObj.Text)), Length(VensterObj.Text), False, @TitelR, nil);
      Teken.St.Font := OudFont;
      FontObj.Free;
      if VensterObj.Style and WS_SYSMENU <> 0 then
      begin
        { sluitknop }
        TitelR := Rect(TitelR.Right - 18, TitelR.Top + 2, TitelR.Right - 2, TitelR.Bottom - 2);
        GdiVulEffen(Teken, TitelR, SysteemKleuren[COLOR_BTNFACE]);
        Kader(TitelR, $FFFFFF, $000000);
        Teken.St.Pen := TZMPen(StandaardObjecten[BLACK_PEN]);
        GdiLijn(Teken, TitelR.Left + 4, TitelR.Top + 3, TitelR.Right - 5, TitelR.Bottom - 4, True);
        GdiLijn(Teken, TitelR.Left + 5, TitelR.Top + 3, TitelR.Right - 4, TitelR.Bottom - 4, True);
        GdiLijn(Teken, TitelR.Right - 5, TitelR.Top + 3, TitelR.Left + 4, TitelR.Bottom - 4, True);
        GdiLijn(Teken, TitelR.Right - 4, TitelR.Top + 3, TitelR.Left + 5, TitelR.Bottom - 4, True);
      end;
    end;
  finally
    ZMGeefDCVrij(DC);
  end;
end;

{ ---------------------------------------------------------------- berichten }

function ZMRoepVensterAan(VensterObj: TZMVenster; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
var
  Melding: TMessage;
begin
  Result := 0;
  if VensterObj = nil then Exit;
  if Assigned(VensterObj.Method) then
  begin
    FillChar(Melding, SizeOf(Melding), 0);
    Melding.Msg := Bericht;
    Melding.WParam := WPar;
    Melding.LParam := LPar;
    Inc(InSend);
    try
      VensterObj.Method(Melding);
    finally
      Dec(InSend);
    end;
    Result := Melding.Result;
  end
  else if VensterObj.Proc <> nil then
    Result := TWndProcFunc(VensterObj.Proc)(VensterObj.Handle, Bericht, WPar, LPar)
  else
    Result := ZMStandaardVensterProc(VensterObj.Handle, Bericht, WPar, LPar);
end;

function ZMZendBericht(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
var
  VensterObj: TZMVenster;
  I: Integer;
begin
  if Venster = HWND_BROADCAST then
  begin
    for I := 0 to High(TopLevels) do ZMRoepVensterAan(TopLevels[I], Bericht, WPar, LPar);
    Exit(0);
  end;
  VensterObj := ZMVensterObj(Venster);
  Result := ZMRoepVensterAan(VensterObj, Bericht, WPar, LPar);
end;

procedure WachtrijDuw(const Melding: TMsg);
var
  NieuweWacht: array of TMsg;
  I: Integer;
begin
  if QCount >= Length(Queue) then
  begin
    SetLength(NieuweWacht, Length(Queue) * 2 + 64);
    for I := 0 to QCount - 1 do NieuweWacht[I] := Queue[(QHead + I) mod Length(Queue)];
    Queue := NieuweWacht;
    QHead := 0;
  end;
  Queue[(QHead + QCount) mod Length(Queue)] := Melding;
  Inc(QCount);
end;

function ZMPlaatsBericht(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): Boolean;
var
  Melding: TMsg;
begin
  ZMInitialiseer;
  if (Venster <> 0) and (Venster <> HWND_BROADCAST) and (ZMVensterObj(Venster) = nil) then Exit(False);
  Melding.hwnd := Venster;
  Melding.message := Bericht;
  Melding.wParam := WPar;
  Melding.lParam := LPar;
  Melding.time := ZMTikken;
  Melding.pt := MousePos;
  WachtrijDuw(Melding);
  Result := True;
end;

function BerichtPast(const Melding: TMsg; Venster: HWND; MinBericht, MaxBericht: UINT): Boolean;
begin
  Result := False;
  if Melding.message = WM_NULL then
  begin
    { geannuleerd bericht; laat het matchen zodat het wordt weggegooid }
    Exit(True);
  end;
  if (Venster <> 0) and (Melding.hwnd <> Venster) and not IsChild(Venster, Melding.hwnd) then Exit;
  if (MinBericht <> 0) or (MaxBericht <> 0) then
    if (Melding.message < MinBericht) or (Melding.message > MaxBericht) then Exit;
  Result := True;
end;

function RoepMMTimersAan: Boolean; forward;
procedure PlaatsMuis(Bericht: UINT; Punt: TPoint; ExtraWPar: WPARAM); forward;

function ZoekTekenbericht(Venster: HWND; var Melding: TMsg): Boolean;
  function Zoek(const Lijst: TVensterLijst): TZMVenster;
  var
    I: Integer;
    VensterObj: TZMVenster;
  begin
    Result := nil;
    for I := 0 to High(Lijst) do
    begin
      VensterObj := Lijst[I];
      if VensterObj.Style and WS_VISIBLE = 0 then Continue;
      if (Length(VensterObj.BijwerkRgn) > 0) or VensterObj.NCVuil then
        if (Venster = 0) or (VensterObj.Handle = Venster) or IsChild(Venster, VensterObj.Handle) then Exit(VensterObj);
      Result := Zoek(VensterObj.Kindvensters);
      if Result <> nil then Exit;
    end;
  end;
var
  VensterObj: TZMVenster;
begin
  if DesktopDirty then TekenBureaublad;
  repeat
    VensterObj := Zoek(TopLevels);
    if VensterObj = nil then Exit(False);
    if VensterObj.NCVuil then ZMTekenNC(VensterObj);
  until Length(VensterObj.BijwerkRgn) > 0;
  Melding.hwnd := VensterObj.Handle;
  Melding.message := WM_PAINT;
  Melding.wParam := 0;
  Melding.lParam := 0;
  Melding.time := ZMTikken;
  Melding.pt := MousePos;
  Result := True;
end;

function ZoekTimer(Venster: HWND; var Melding: TMsg; Verwijderen: Boolean): Boolean;
var
  I, Beste: Integer;
  Nu: LongWord;
begin
  Result := False;
  Nu := ZMTikken;
  Beste := -1;
  for I := 0 to High(Timers) do
    with Timers[I] do
      if Active and not IsMM and (LongInt(Nu - Due) >= 0) and ((Venster = 0) or (Wnd = Venster)) then
        if (Beste < 0) or (LongInt(Timers[Beste].Due - Due) > 0) then Beste := I;
  if Beste < 0 then Exit;
  Melding.hwnd := Timers[Beste].Wnd;
  Melding.message := WM_TIMER;
  Melding.wParam := Timers[Beste].ID;
  Melding.lParam := LPARAM(PtrUInt(Timers[Beste].Proc));
  Melding.time := Nu;
  Melding.pt := MousePos;
  if Verwijderen then
  begin
    Timers[Beste].Due := Nu + Timers[Beste].Interval;
  end;
  Result := True;
end;

var
  LaatstePeiling: LongWord;

procedure DumpBoom(const Lijst: TVensterLijst; Inspringing: string);
var
  I: Integer;
  VensterObj: TZMVenster;
begin
  for I := High(Lijst) downto 0 do
  begin
    VensterObj := Lijst[I];
    WriteLn(StdErr, Inspringing, VensterObj.Handle, ' ', VensterObj.VensterKlasseNaam, ' "', VensterObj.Text, '" vis=', Ord(VensterObj.Style and WS_VISIBLE <> 0),
      ' dis=', Ord(VensterObj.Style and WS_DISABLED <> 0), ' R=', VensterObj.R.Left, ',', VensterObj.R.Top, ',', VensterObj.R.Right, ',', VensterObj.R.Bottom,
      ' upd=', Length(VensterObj.BijwerkRgn));
    DumpBoom(VensterObj.Kindvensters, Inspringing + '  ');
  end;
end;

procedure ZMDumpVensters;
begin
  WriteLn(StdErr, 'vensterboom (bovenste eerst), actief=', ActiveWnd, ' focus=', FocusWnd, ' capture=', CaptureWnd);
  DumpBoom(TopLevels, '  ');
end;

{ ZM_SCRIPT="ms:cmd[:args];..." met cmd = click:x,y | rclick:x,y | move:x,y |
  key:vk | char:c | shot:bestand.png | exit. Tijden zijn ms sinds de start, coördinaten
  zijn relatief aan het clientgebied van het hoofdformulier. Voor tests zonder harnas. }
procedure VoerScriptUit(Tijd: LongWord);
var
  Onderdeel, Commando, Argument: string;
  Beginpos, Eindpos, X, Y: Integer;
  Tijdstip: Integer;
begin
  while ScriptPos <= Length(Script) do
  begin
    Beginpos := ScriptPos;
    Eindpos := Beginpos;
    while (Eindpos <= Length(Script)) and (Script[Eindpos] <> ';') do Inc(Eindpos);
    Onderdeel := Trim(Copy(Script, Beginpos, Eindpos - Beginpos));
    Tijdstip := StrToIntDef(Copy(Onderdeel, 1, Pos(':', Onderdeel) - 1), 0);
    if Integer(Tijd) < Tijdstip then Exit;
    ScriptPos := Eindpos + 1;
    Delete(Onderdeel, 1, Pos(':', Onderdeel));
    if Pos(':', Onderdeel) > 0 then
    begin
      Commando := Copy(Onderdeel, 1, Pos(':', Onderdeel) - 1);
      Argument := Copy(Onderdeel, Pos(':', Onderdeel) + 1, MaxInt);
    end
    else
    begin
      Commando := Onderdeel;
      Argument := '';
    end;
    X := StrToIntDef(Copy(Argument, 1, Pos(',', Argument) - 1), 0);
    Y := StrToIntDef(Copy(Argument, Pos(',', Argument) + 1, MaxInt), 0);
    if Commando = 'click' then
    begin
      ZMInjecteerMuis(X, Y, 1, True);
      ZMInjecteerMuis(X, Y, 1, False);
    end
    else if Commando = 'rclick' then
    begin
      ZMInjecteerMuis(X, Y, 2, True);
      ZMInjecteerMuis(X, Y, 2, False);
    end
    else if Commando = 'move' then ZMInjecteerMuis(X, Y, 0, False)
    else if Commando = 'key' then
    begin
      ZMInjecteerToets(StrToIntDef(Argument, 0), True);
      ZMInjecteerToets(StrToIntDef(Argument, 0), False);
    end
    else if Commando = 'char' then
    begin
      if Argument <> '' then ZMInjecteerKarakter(Argument[1]);
    end
    else if Commando = 'shot' then
    begin
      ZMPresenteer(True);
      if ZMBewaarSchermafdruk(Argument) then WriteLn(StdErr, 'compat: screenshot opgeslagen in ', Argument);
    end
    else if Commando = 'exit' then
      Halt(0);
  end;
end;

procedure TestHaken;
var
  Tijd: LongWord;
begin
  if Script <> '' then VoerScriptUit(ZMTikken - StartTicks);
  if (ShotFile = '') and (ExitAt < 0) then Exit;
  Tijd := ZMTikken - StartTicks;
  if (ShotFile <> '') and (Integer(Tijd) >= ShotAt) then
  begin
    if ZMBewaarSchermafdruk(ShotFile) then
      WriteLn(StdErr, 'compat: screenshot opgeslagen in ', ShotFile);
    if GetEnvironmentVariable('ZM_DEBUG') <> '' then ZMDumpVensters;
    ShotFile := '';
  end;
  if (ExitAt >= 0) and (Integer(Tijd) >= ExitAt) then
  begin
    WriteLn(StdErr, 'compat: ZM_EXIT_AT bereikt, wordt afgesloten');
    Halt(0);
  end;
end;

function ZMBekijkBericht(var Melding: TMsg; Venster: HWND; MinBericht, MaxBericht, Verwijderen: UINT): Boolean;
var
  I, J, Plaats: Integer;
  Nu: LongWord;
begin
  ZMInitialiseer;
  ZorgVoorBackend;
  Nu := ZMTikken;
  if (Nu - LaatstePeiling >= 4) or (QCount = 0) or (Length(Injected) > 0) or Assigned(ZMInactiefHaak) or (Script <> '') then
  begin
    LaatstePeiling := Nu;
    ZMPeilInvoer;
    TestHaken;
  end;
  RoepMMTimersAan;
  { geplaatste / invoerberichten }
  for I := 0 to QCount - 1 do
  begin
    Plaats := (QHead + I) mod Length(Queue);
    if BerichtPast(Queue[Plaats], Venster, MinBericht, MaxBericht) then
    begin
      Melding := Queue[Plaats];
      if (Verwijderen and PM_REMOVE <> 0) or (Melding.message = WM_NULL) then
      begin
        { verwijder item I }
        J := I;
        while J < QCount - 1 do
        begin
          Queue[(QHead + J) mod Length(Queue)] := Queue[(QHead + J + 1) mod Length(Queue)];
          Inc(J);
        end;
        Dec(QCount);
        if Melding.message = WM_NULL then
          Exit(ZMBekijkBericht(Melding, Venster, MinBericht, MaxBericht, Verwijderen));
      end;
      LastMsgPos := Melding.pt;
      LastMsgTime := Melding.time;
      if Melding.message = WM_QUIT then ZMAfsluitGevraagd := True;
      Exit(True);
    end;
  end;
  { synthetische muisbeweging (na het loslaten van capture of vensterwijzigingen onder de cursor) }
  if SyntheticMove and MouseSeen and (QCount = 0) then
  begin
    SyntheticMove := False;
    PlaatsMuis(WM_MOUSEMOVE, MousePos, 0);
    if QCount > 0 then Exit(ZMBekijkBericht(Melding, Venster, MinBericht, MaxBericht, Verwijderen));
  end;
  { tekenen }
  if ((MinBericht = 0) and (MaxBericht = 0)) or ((WM_PAINT >= MinBericht) and (WM_PAINT <= MaxBericht)) then
    if ZoekTekenbericht(Venster, Melding) then
    begin
      LastMsgPos := Melding.pt;
      LastMsgTime := Melding.time;
      Exit(True);
    end;
  { timers }
  if ((MinBericht = 0) and (MaxBericht = 0)) or ((WM_TIMER >= MinBericht) and (WM_TIMER <= MaxBericht)) then
    if ZoekTimer(Venster, Melding, Verwijderen and PM_REMOVE <> 0) then
    begin
      LastMsgPos := Melding.pt;
      LastMsgTime := Melding.time;
      Exit(True);
    end;
  { niets: toon wat er getekend is }
  ZMPresenteer(False);
  Result := False;
end;

function VolgendeTimerVerval: Integer;
var
  I: Integer;
  Nu: LongWord;
  Verschil: LongInt;
begin
  Result := 50;
  Nu := ZMTikken;
  for I := 0 to High(Timers) do
    if Timers[I].Active then
    begin
      Verschil := LongInt(Timers[I].Due - Nu);
      if Verschil < 0 then Verschil := 0;
      if Verschil < Result then Result := Verschil;
    end;
end;

procedure ZMWachtOpBericht;
var
  Wacht: Integer;
  Melding: TMsg;
begin
  ZorgVoorBackend;
  if ZMBekijkBericht(Melding, 0, 0, 0, PM_NOREMOVE) then Exit;
  ZMPresenteer(True);
  Wacht := VolgendeTimerVerval;
  if Wacht > 0 then ZMBackend.WachtOpGebeurtenis(Wacht);
end;

function ZMLeesBericht(var Melding: TMsg; Venster: HWND; MinBericht, MaxBericht: UINT): Boolean;
begin
  while not ZMBekijkBericht(Melding, Venster, MinBericht, MaxBericht, PM_REMOVE) do
    ZMWachtOpBericht;
  Result := Melding.message <> WM_QUIT;
end;

procedure ZMVertaalBericht(const Melding: TMsg);
var
  Code: Integer;
begin
  if (Melding.message <> WM_KEYDOWN) and (Melding.message <> WM_SYSKEYDOWN) then Exit;
  Code := -1;
  case Melding.wParam of
    VK_RETURN: Code := 13;
    VK_ESCAPE: Code := 27;
    VK_BACK: Code := 8;
    VK_TAB: Code := 9;
  else
    if KeyDown[VK_CONTROL] and not KeyDown[VK_MENU] then
    begin
      if (Melding.wParam >= Ord('A')) and (Melding.wParam <= Ord('Z')) then Code := Melding.wParam - Ord('A') + 1;
    end;
  end;
  if Code >= 0 then
    if Melding.message = WM_KEYDOWN then
      ZMPlaatsBericht(Melding.hwnd, WM_CHAR, Code, Melding.lParam)
    else
      ZMPlaatsBericht(Melding.hwnd, WM_SYSCHAR, Code, Melding.lParam);
end;

function ZMVerwerkBericht(const Melding: TMsg): LRESULT;
var
  VensterObj: TZMVenster;
begin
  Result := 0;
  if (Melding.message = WM_TIMER) and (Melding.lParam <> 0) then
  begin
    TTimerProc(Pointer(PtrUInt(Melding.lParam)))(Melding.hwnd, WM_TIMER, Melding.wParam, ZMTikken);
    Exit;
  end;
  VensterObj := ZMVensterObj(Melding.hwnd);
  if VensterObj = nil then Exit;
  Result := ZMRoepVensterAan(VensterObj, Melding.message, Melding.wParam, Melding.lParam);
  if (Melding.message = WM_PAINT) and (ZMVensterObj(Melding.hwnd) = VensterObj) and (Length(VensterObj.BijwerkRgn) > 0) then
  begin
    { het venster heeft niet getekend (geen BeginPaint): valideer het zodat we niet blijven lussen }
    VensterObj.BijwerkRgn := nil;
    VensterObj.WisAchtergrond := False;
  end;
end;

function ZMStandaardVensterProc(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
var
  VensterObj: TZMVenster;
  TekenInfo: TPaintStruct;
  DC: HDC;
  R: TRect;
  Kwast: TZMKwast;
begin
  Result := 0;
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  case Bericht of
    WM_PAINT:
      begin
        ZMBeginTekenen(Venster, TekenInfo);
        ZMEindeTekenen(Venster, TekenInfo);
      end;
    WM_ERASEBKGND:
      begin
        Kwast := GdiKwast(VensterObj.KlasseKwast);
        if Kwast <> nil then
        begin
          DC := HDC(WPar);
          with VensterObj.KlientRectScherm do R := Rect(0, 0, Right - Left, Bottom - Top);
          GdiVulRechthoek(GdiDC(DC), R, Kwast);
          Result := 1;
        end;
      end;
    WM_CLOSE: ZMVernietigVenster(Venster);
    WM_SETTEXT:
      begin
        if LPar <> 0 then VensterObj.Text := StrPas(PAnsiChar(LPar)) else VensterObj.Text := '';
        VensterObj.NCVuil := True;
        Result := 1;
      end;
    WM_GETTEXT:
      begin
        if (LPar <> 0) and (WPar > 0) then
        begin
          StrPLCopy(PAnsiChar(LPar), VensterObj.Text, WPar - 1);
          Result := StrLen(PAnsiChar(LPar));
        end;
      end;
    WM_GETTEXTLENGTH: Result := Length(VensterObj.Text);
    WM_ACTIVATE:
      if (LoWord(WPar) <> WA_INACTIVE) and (VensterObj.Parent = nil) then
        if (FocusWnd = 0) or ((FocusWnd <> Venster) and not IsChild(Venster, FocusWnd)) then
          ZMZetFocus(Venster);
    WM_NCHITTEST: Result := HTCLIENT;
    WM_SETCURSOR:
      begin
        if VensterObj.KlasseAanwijzer <> 0 then ZMZetAanwijzerVorm(VensterObj.KlasseAanwijzer)
        else ZMZetAanwijzerVorm(ZMAanwijzerVanId(32512));
        Result := 1;
      end;
    WM_MOUSEACTIVATE: Result := 1;  { MA_ACTIVATE }
    WM_SYSKEYDOWN:
      if WPar = VK_F4 then ZMPlaatsBericht(VensterObj.TopLevel.Handle, WM_CLOSE, 0, 0);
    WM_SYSCOMMAND:
      if (WPar and $FFF0) = SC_CLOSE then ZMPlaatsBericht(Venster, WM_CLOSE, 0, 0);
  end;
end;

{ ---------------------------------------------------------------- timers }

function ZMZetTimer(Venster: HWND; Ident, Verstreken: UINT; Terugroep: Pointer): UINT;
var
  I: Integer;
begin
  ZMInitialiseer;
  if Verstreken < 1 then Verstreken := 1;
  if Venster = 0 then
  begin
    Inc(NextTimerID);
    Ident := NextTimerID;
  end;
  for I := 0 to High(Timers) do
    if Timers[I].Active and not Timers[I].IsMM and (Timers[I].Wnd = Venster) and (Timers[I].ID = Ident) then
    begin
      Timers[I].Interval := Verstreken;
      Timers[I].Due := ZMTikken + Verstreken;
      Timers[I].Proc := Terugroep;
      Exit(Ident);
    end;
  I := 0;
  while (I <= High(Timers)) and Timers[I].Active do Inc(I);
  if I > High(Timers) then SetLength(Timers, I + 1);
  FillChar(Timers[I], SizeOf(TTimerRec), 0);
  Timers[I].Wnd := Venster;
  Timers[I].ID := Ident;
  Timers[I].Interval := Verstreken;
  Timers[I].Due := ZMTikken + Verstreken;
  Timers[I].Proc := Terugroep;
  Timers[I].Active := True;
  if Ident = 0 then Result := 1 else Result := Ident;
end;

function ZMVerwijderTimer(Venster: HWND; Ident: UINT): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Timers) do
    if Timers[I].Active and not Timers[I].IsMM and (Timers[I].Wnd = Venster) and (Timers[I].ID = Ident) then
    begin
      Timers[I].Active := False;
      Result := True;
    end;
end;

function ZMVoegMMTimerToe(Vertraging: UINT; Terugroep: Pointer; Gebruiker: PtrUInt; Periodiek: Boolean): UINT;
var
  I: Integer;
begin
  ZMInitialiseer;
  if Vertraging < 1 then Vertraging := 1;
  I := 0;
  while (I <= High(Timers)) and Timers[I].Active do Inc(I);
  if I > High(Timers) then SetLength(Timers, I + 1);
  FillChar(Timers[I], SizeOf(TTimerRec), 0);
  Inc(NextTimerID);
  Timers[I].ID := NextTimerID;
  Timers[I].Interval := Vertraging;
  Timers[I].Due := ZMTikken + Vertraging;
  Timers[I].Proc := Terugroep;
  Timers[I].User := Gebruiker;
  Timers[I].Periodic := Periodiek;
  Timers[I].IsMM := True;
  Timers[I].Active := True;
  Result := NextTimerID;
end;

function ZMVerwijderMMTimer(Ident: UINT): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Timers) do
    if Timers[I].Active and Timers[I].IsMM and (Timers[I].ID = Ident) then
    begin
      Timers[I].Active := False;
      Result := True;
    end;
end;

type
  TMMTerugroep = procedure(uTimerID, uMessage: UINT; dwUser, dw1, dw2: PtrUInt); stdcall;

var
  BinnenMMTimer: Boolean = False;

function RoepMMTimersAan: Boolean;
var
  I: Integer;
  Nu: LongWord;
  Terugroep: TMMTerugroep;
begin
  Result := False;
  if BinnenMMTimer then Exit;
  BinnenMMTimer := True;
  try
    Nu := ZMTikken;
    for I := 0 to High(Timers) do
      if Timers[I].Active and Timers[I].IsMM and (LongInt(Nu - Timers[I].Due) >= 0) then
      begin
        if Timers[I].Periodic then
          Timers[I].Due := Nu + Timers[I].Interval
        else
          Timers[I].Active := False;
        Terugroep := TMMTerugroep(Timers[I].Proc);
        if Assigned(Terugroep) then Terugroep(Timers[I].ID, 0, Timers[I].User, 0, 0);
        Result := True;
      end;
  finally
    BinnenMMTimer := False;
  end;
end;

{ ---------------------------------------------------------------- focus enz. }

function ZMLeesFocus: HWND;
begin
  Result := FocusWnd;
end;

function ZMZetFocus(Venster: HWND): HWND;
var
  Oud: HWND;
  VensterObj: TZMVenster;
begin
  Result := FocusWnd;
  if Venster = FocusWnd then Exit;
  VensterObj := ZMVensterObj(Venster);
  if (Venster <> 0) and (VensterObj = nil) then Exit;
  if (VensterObj <> nil) and (ActiveWnd <> VensterObj.TopLevel.Handle) then
    ZMZetActief(VensterObj.TopLevel.Handle);
  Oud := FocusWnd;
  FocusWnd := Venster;
  if (Oud <> 0) and (ZMVensterObj(Oud) <> nil) then
    ZMZendBericht(Oud, WM_KILLFOCUS, Venster, 0);
  if (FocusWnd = Venster) and (Venster <> 0) then
    ZMZendBericht(Venster, WM_SETFOCUS, Oud, 0);
end;

function ZMLeesActief: HWND;
begin
  Result := ActiveWnd;
end;

function ZMZetActief(Venster: HWND): HWND;
var
  Oud: HWND;
  VensterObj, OudObj: TZMVenster;
begin
  Result := ActiveWnd;
  VensterObj := ZMVensterObj(Venster);
  if VensterObj <> nil then VensterObj := VensterObj.TopLevel;
  if VensterObj <> nil then Venster := VensterObj.Handle;
  if Venster = ActiveWnd then Exit;
  Oud := ActiveWnd;
  ActiveWnd := Venster;
  OudObj := ZMVensterObj(Oud);
  if OudObj <> nil then
  begin
    OudObj.NCVuil := True;
    ZMZendBericht(Oud, WM_NCACTIVATE, 0, 0);
    ZMZendBericht(Oud, WM_ACTIVATE, WA_INACTIVE, LPARAM(Venster));
  end;
  if VensterObj <> nil then
  begin
    { breng naar de bovenkant van de z-volgorde }
    ZMZetVensterPositie(Venster, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOSENDCHANGING);
    VensterObj.NCVuil := True;
    ZMZendBericht(Venster, WM_NCACTIVATE, 1, 0);
    ZMZendBericht(Venster, WM_ACTIVATE, WA_ACTIVE, LPARAM(Oud));
  end;
end;

function ZMZetVastlegging(Venster: HWND): HWND;
begin
  Result := CaptureWnd;
  CaptureWnd := Venster;
end;

function ZMLeesVastlegging: HWND;
begin
  Result := CaptureWnd;
end;

procedure ZMGeefVastleggingVrij;
var
  Oud: HWND;
begin
  Oud := CaptureWnd;
  CaptureWnd := 0;
  if Oud <> 0 then
  begin
    ZMZendBericht(Oud, WM_CAPTURECHANGED, 0, 0);
    { zoals Windows/Wine: het loslaten van capture levert een muisbeweging op, zodat het
      venster onder de cursor weet waar de aanwijzer staat }
    SyntheticMove := True;
  end;
end;

function ZMSchakelVensterIn(Venster: HWND; Inschakelen: Boolean): Boolean;
var
  VensterObj: TZMVenster;
begin
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit(False);
  Result := VensterObj.Style and WS_DISABLED <> 0;  { vorige toestand: True = was uitgeschakeld }
  if Inschakelen = not Result then Exit;
  if Inschakelen then VensterObj.Style := VensterObj.Style and not WS_DISABLED
  else
  begin
    VensterObj.Style := VensterObj.Style or WS_DISABLED;
    if (FocusWnd = Venster) or IsChild(Venster, FocusWnd) then ZMZetFocus(0);
  end;
  ZMZendBericht(Venster, WM_ENABLE, Ord(Inschakelen), 0);
end;

function ZMToetsStatus(Toets: Integer): SmallInt;
begin
  if (Toets >= 0) and (Toets <= 255) and KeyDown[Toets] then Result := SmallInt($8000) else Result := 0;
end;

function ZMAanwijzerPositie: TPoint;
begin
  Result := MousePos;
end;

procedure ZMZetAanwijzerPositie(X, Y: Integer);
begin
  MousePos := Point(X, Y);
end;

function ZMBerichtPositie: TPoint;
begin
  Result := LastMsgPos;
end;

function ZMBerichtTijd: LongWord;
begin
  Result := LastMsgTime;
end;

{ cursors zijn kleine gehele getallen: de IDC_xxx-resource-id's }
function ZMAanwijzerVanId(Ident: PtrUInt): HCURSOR;
begin
  Result := HCURSOR(Ident);
end;

procedure ZMZetAanwijzerVorm(Aanwijzer: HCURSOR);
var
  Vorm: TZMCursorvorm;
begin
  if Aanwijzer = CurCursor then Exit;
  CurCursor := Aanwijzer;
  case Aanwijzer of
    0: Vorm := zcNone;
    32513: Vorm := zcIBeam;
    32514: Vorm := zcWait;
    32515: Vorm := zcCross;
    32640, 32646: Vorm := zcSizeAll;
    32642: Vorm := zcSizeNWSE;
    32643: Vorm := zcSizeNESW;
    32644: Vorm := zcSizeWE;
    32645: Vorm := zcSizeNS;
    32648: Vorm := zcNo;
    32649: Vorm := zcHand;
    32650: Vorm := zcAppStart;
  else
    Vorm := zcArrow;
  end;
  ZMBackend.SetCursor(Vorm);
end;

{ ---------------------------------------------------------------- input }

function MuisToetsen: WPARAM;
begin
  Result := 0;
  if KeyDown[VK_LBUTTON] then Result := Result or MK_LBUTTON;
  if KeyDown[VK_RBUTTON] then Result := Result or MK_RBUTTON;
  if KeyDown[VK_MBUTTON] then Result := Result or MK_MBUTTON;
  if KeyDown[VK_SHIFT] then Result := Result or MK_SHIFT;
  if KeyDown[VK_CONTROL] then Result := Result or MK_CONTROL;
end;

procedure PlaatsMuis(Bericht: UINT; Punt: TPoint; ExtraWPar: WPARAM);
var
  Venster: HWND;
  VensterObj: TZMVenster;
  KlientPunt: TPoint;
  Ingedrukt: Boolean;
  Bovenste: TZMVenster;
begin
  Ingedrukt := (Bericht = WM_LBUTTONDOWN) or (Bericht = WM_RBUTTONDOWN) or (Bericht = WM_MBUTTONDOWN);
  if CaptureWnd <> 0 then
    Venster := CaptureWnd
  else
    Venster := ZMVensterVanPunt(Punt, False);
  VensterObj := ZMVensterObj(Venster);
  if VensterObj = nil then Exit;
  if (CaptureWnd = 0) and not VensterObj.IsIngeschakeldBoom then
  begin
    if Ingedrukt then
    begin
      ZMBackend.Beep;
      { breng een ingeschakeld (modaal) venster naar voren }
      if (ActiveWnd <> 0) then ZMZetActief(ActiveWnd);
    end;
    Exit;
  end;
  if Ingedrukt then
  begin
    Bovenste := VensterObj.TopLevel;
    if Bovenste.Handle <> ActiveWnd then
      if ZMZendBericht(Venster, WM_MOUSEACTIVATE, Bovenste.Handle, MakeLParam(HTCLIENT, Bericht)) <> 3 then
        ZMZetActief(Bovenste.Handle);
    VensterObj := ZMVensterObj(Venster);
    if VensterObj = nil then Exit;
  end;
  if (CaptureWnd = 0) and not PtInRect(VensterObj.KlientRectScherm, Punt) then Exit;  { niet-clientgebied }
  ZMZendBericht(Venster, WM_SETCURSOR, Venster, MakeLParam(HTCLIENT, Bericht));
  KlientPunt := Punt;
  ZMSchermNaarKlient(Venster, KlientPunt);
  ZMPlaatsBericht(Venster, Bericht, MuisToetsen or ExtraWPar, MakeLParam(Word(SmallInt(KlientPunt.X)), Word(SmallInt(KlientPunt.Y))));
end;

procedure VerwerkGebeurtenis(const Gebeurtenis: TZMGebeurtenis);
var
  Bericht: UINT;
  Venster: HWND;
  Nu: LongWord;
  VensterObj: TZMVenster;
  Toets: Integer;
  I: Integer;
  LPar: LPARAM;
begin
  case Gebeurtenis.Kind of
    zeQuit:
      if Assigned(ZMBijSluitverzoek) then ZMBijSluitverzoek
      else if ZMHoofdVenster <> 0 then ZMPlaatsBericht(ZMHoofdVenster, WM_CLOSE, 0, 0)
      else ZMPlaatsBericht(0, WM_QUIT, 0, 0);
    zeExpose:
      ZMScherm.Vuil := True;
    zeMouseMove:
      begin
        MouseSeen := True;
        MousePos := Point(Gebeurtenis.X, Gebeurtenis.Y);
        { samenvoegen: vervang een wachtende WM_MOUSEMOVE }
        for I := QCount - 1 downto 0 do
          if Queue[(QHead + I) mod Length(Queue)].message = WM_MOUSEMOVE then
          begin
            Queue[(QHead + I) mod Length(Queue)].message := WM_NULL;
            Break;
          end
          else if Queue[(QHead + I) mod Length(Queue)].message <> WM_NULL then
            Break;
        PlaatsMuis(WM_MOUSEMOVE, MousePos, 0);
      end;
    zeMouseDown, zeMouseUp:
      begin
        MouseSeen := True;
        MousePos := Point(Gebeurtenis.X, Gebeurtenis.Y);
        case Gebeurtenis.Button of
          1: Toets := VK_LBUTTON;
          2: Toets := VK_RBUTTON;
        else
          Toets := VK_MBUTTON;
        end;
        KeyDown[Toets] := Gebeurtenis.Kind = zeMouseDown;
        if Gebeurtenis.Kind = zeMouseDown then
        begin
          case Gebeurtenis.Button of
            1: Bericht := WM_LBUTTONDOWN;
            2: Bericht := WM_RBUTTONDOWN;
          else
            Bericht := WM_MBUTTONDOWN;
          end;
          Nu := ZMTikken;
          if CaptureWnd <> 0 then Venster := CaptureWnd else Venster := ZMVensterVanPunt(MousePos, False);
          if (Gebeurtenis.Button = LastClickBtn) and (Nu - LastClickTime < GetDoubleClickTime) and
            (Abs(MousePos.X - LastClickPos.X) <= 4) and (Abs(MousePos.Y - LastClickPos.Y) <= 4) and
            (Venster = LastClickWnd) then
          begin
            VensterObj := ZMVensterObj(Venster);
            if (VensterObj <> nil) and (VensterObj.KlasseStijl and CS_DBLCLKS <> 0) then
              Bericht := Bericht + 2;  { xBUTTONDBLCLK }
            LastClickTime := 0;
          end
          else
          begin
            LastClickTime := Nu;
            LastClickPos := MousePos;
            LastClickBtn := Gebeurtenis.Button;
            LastClickWnd := Venster;
          end;
        end
        else
          case Gebeurtenis.Button of
            1: Bericht := WM_LBUTTONUP;
            2: Bericht := WM_RBUTTONUP;
          else
            Bericht := WM_MBUTTONUP;
          end;
        PlaatsMuis(Bericht, MousePos, 0);
      end;
    zeMouseWheel:
      begin
        if FocusWnd <> 0 then Venster := FocusWnd else Venster := ZMVensterVanPunt(MousePos, True);
        if Venster <> 0 then
          ZMPlaatsBericht(Venster, WM_MOUSEWHEEL, (MuisToetsen and $FFFF) or (WPARAM(Word(SmallInt(Gebeurtenis.Wiel))) shl 16),
            MakeLParam(Word(SmallInt(MousePos.X)), Word(SmallInt(MousePos.Y))));
      end;
    zeKeyDown, zeKeyUp:
      begin
        Toets := Gebeurtenis.Key;
        if (Toets <= 0) or (Toets > 255) then Exit;
        KeyDown[Toets] := Gebeurtenis.Kind = zeKeyDown;
        if Toets in [VK_LSHIFT, VK_RSHIFT] then KeyDown[VK_SHIFT] := KeyDown[VK_LSHIFT] or KeyDown[VK_RSHIFT];
        if Toets in [VK_LCONTROL, VK_RCONTROL] then KeyDown[VK_CONTROL] := KeyDown[VK_LCONTROL] or KeyDown[VK_RCONTROL];
        if Toets in [VK_LMENU, VK_RMENU] then KeyDown[VK_MENU] := KeyDown[VK_LMENU] or KeyDown[VK_RMENU];
        case Toets of
          VK_LSHIFT, VK_RSHIFT: Toets := VK_SHIFT;
          VK_LCONTROL, VK_RCONTROL: Toets := VK_CONTROL;
          VK_LMENU, VK_RMENU: Toets := VK_MENU;
        end;
        Venster := FocusWnd;
        if Venster = 0 then Venster := ActiveWnd;
        if Venster = 0 then Exit;
        LPar := 1 or (LPARAM(Gebeurtenis.Toetsnummer and $FF) shl 16);
        if Gebeurtenis.Herhaald then LPar := LPar or (1 shl 30);
        if KeyDown[VK_MENU] or (Toets = VK_MENU) or (Toets = VK_F10) then
        begin
          if Gebeurtenis.Kind = zeKeyDown then Bericht := WM_SYSKEYDOWN else Bericht := WM_SYSKEYUP;
          LPar := LPar or (1 shl 29);
        end
        else if Gebeurtenis.Kind = zeKeyDown then Bericht := WM_KEYDOWN
        else Bericht := WM_KEYUP;
        if Gebeurtenis.Kind = zeKeyUp then LPar := LPar or LPARAM(LongWord($C0000000));
        ZMPlaatsBericht(Venster, Bericht, Toets, LPar);
      end;
    zeText:
      begin
        if KeyDown[VK_CONTROL] or KeyDown[VK_MENU] then Exit;
        Venster := FocusWnd;
        if Venster = 0 then Venster := ActiveWnd;
        if Venster = 0 then Exit;
        for I := 1 to Length(Gebeurtenis.Text) do
          ZMPlaatsBericht(Venster, WM_CHAR, Byte(Gebeurtenis.Text[I]), 1);
      end;
    zeActivate: ;
    zeDeactivate:
      FillChar(KeyDown, SizeOf(KeyDown), 0);
  end;
end;

procedure Injecteer(const Gebeurtenis: TZMGebeurtenis);
begin
  SetLength(Injected, Length(Injected) + 1);
  Injected[High(Injected)] := Gebeurtenis;
end;

procedure ZMInjecteerMuis(X, Y: Integer; Knop: Integer; Omlaag: Boolean);
var
  Gebeurtenis: TZMGebeurtenis;
  Punt: TPoint;
begin
  FillChar(Gebeurtenis, SizeOf(Gebeurtenis), 0);
  Punt := Point(X, Y);
  if ZMHoofdVenster <> 0 then ZMKlientNaarScherm(ZMHoofdVenster, Punt);
  Gebeurtenis.X := Punt.X;
  Gebeurtenis.Y := Punt.Y;
  if Knop = 0 then
    Gebeurtenis.Kind := zeMouseMove
  else
  begin
    { eerst verplaatsen, zoals een echte muis }
    Gebeurtenis.Kind := zeMouseMove;
    Injecteer(Gebeurtenis);
    if Omlaag then Gebeurtenis.Kind := zeMouseDown else Gebeurtenis.Kind := zeMouseUp;
    Gebeurtenis.Button := Knop;
  end;
  Injecteer(Gebeurtenis);
end;

procedure ZMInjecteerToets(Toets: Word; Omlaag: Boolean);
var
  Gebeurtenis: TZMGebeurtenis;
begin
  FillChar(Gebeurtenis, SizeOf(Gebeurtenis), 0);
  if Omlaag then Gebeurtenis.Kind := zeKeyDown else Gebeurtenis.Kind := zeKeyUp;
  Gebeurtenis.Key := Toets;
  Injecteer(Gebeurtenis);
end;

procedure ZMInjecteerKarakter(Karakter: Char);
var
  Gebeurtenis: TZMGebeurtenis;
begin
  FillChar(Gebeurtenis, SizeOf(Gebeurtenis), 0);
  Gebeurtenis.Kind := zeText;
  Gebeurtenis.Text := Karakter;
  Injecteer(Gebeurtenis);
end;

procedure ZMPeilInvoer;
var
  Gebeurtenis: TZMGebeurtenis;
  I: Integer;
  Gebeurtenissen: array of TZMGebeurtenis;
begin
  ZorgVoorBackend;
  if Assigned(ZMInactiefHaak) and not InIdleHook then
  begin
    InIdleHook := True;
    try
      ZMInactiefHaak;
    finally
      InIdleHook := False;
    end;
  end;
  if Length(Injected) > 0 then
  begin
    Gebeurtenissen := Injected;
    Injected := nil;
    for I := 0 to High(Gebeurtenissen) do VerwerkGebeurtenis(Gebeurtenissen[I]);
  end;
  while ZMBackend.PeilGebeurtenis(Gebeurtenis) do
    VerwerkGebeurtenis(Gebeurtenis);
end;

procedure ZMPresenteer(Forceer: Boolean);
var
  Nu: LongWord;
begin
  if (ZMScherm = nil) or not ZMScherm.Vuil then Exit;
  Nu := ZMTikken;
  if not Forceer and (Nu - LastPresent < 15) then Exit;
  ZorgVoorBackend;
  LastPresent := Nu;
  ZMScherm.Vuil := False;
  ZMBackend.Toon(ZMScherm.Bits, ZMScherm.Width, ZMScherm.Height, ZMScherm.Rijbytes);
end;

function ZMBewaarSchermafdruk(const Bestandsnaam: string): Boolean;
begin
  ZMInitialiseer;
  Result := ZMBewaarPNG(Bestandsnaam, ZMScherm.Bits, ZMScherm.Width, ZMScherm.Height, ZMScherm.Rijbytes);
end;

initialization
  ZMSetDisplayModeHook := DDZetModus;
  ZMRestoreDisplayModeHook := DDHerstelModus;
end.

unit ZMWin;

{ Vensterbeheer en berichtenwachtrij van de compatlaag.

  Er is één geëmuleerd scherm (een 32-bits bitmap, standaard 1024x768). Topniveauvensters
  staan erop, kindvensters binnen hun ouders; elk venster tekent rechtstreeks in het
  scherm via vensters-DC's waarvan het zichtbare gebied overlappende zusters en kinderen
  uitsluit (WS_CLIPSIBLINGS | WS_CLIPCHILDREN-semantiek), precies zoals bij niet-
  gecomposeerd Windows. De backend toont het scherm.

  Berichten: een wachtrij met geplaatste berichten, SendMessage = directe aanroep,
  WM_PAINT en WM_TIMER worden gesynthetiseerd wanneer de wachtrij leeg is, invoer komt van
  de backend. Al het wachten loopt via ZMWaitMessage (WaitMessage/GetMessage), de enige
  plek waar het programma blokkeert; een browserbackend haakt daar in. }

{$MODE DELPHI}{$H+}{$R-}{$Q-}

interface

uses Windows, Messages, ZMGdi, ZMPlatform;

type
  TZMWindow = class;
  TZMWindowArray = array of TZMWindow;

  TZMWindow = class
  public
    Handle: HWND;
    Parent: TZMWindow;
    Owner: HWND;
    Children: TZMWindowArray;       { z-volgorde: index 0 = onderste }
    ClsName: string;
    ClsStyle: UINT;
    ClsBrush: HBRUSH;
    ClsCursor: HCURSOR;
    Style, ExStyle: DWORD;
    R: TRect;                        { vensterrechthoek in clientcoördinaten van de ouder (scherm voor topniveau) }
    Text: string;
    Method: TWndMethod;
    Proc: Pointer;                   { TWndProcFunc als Method niet is toegewezen }
    ID: PtrInt;
    UserData: PtrInt;
    UpdRgn: TZMRects;                { clientcoördinaten }
    EraseBk: Boolean;
    NCDirty: Boolean;
    Destroying: Boolean;
    VisGen: Integer;
    VisClientCache, VisWindowCache: TZMRects;
    function NCInsets: TRect;
    function ClientRectScreen: TRect;
    function WindowRectScreen: TRect;
    function IsVisible: Boolean;     { dit venster en alle voorouders hebben WS_VISIBLE }
    function IsEnabledTree: Boolean;
    function TopLevel: TZMWindow;
  end;

  TZMEnumWindowProc = function(Venster: HWND; Gegevens: Pointer): Boolean;

var
  ZMScreen: TZMBitmap;
  ZMScreenW: Integer = 1024;
  ZMScreenH: Integer = 768;
  ZMQuitRequested: Boolean = False;
  ZMExitCode: Integer = 0;
  { venster dat WM_CLOSE krijgt wanneer de gebruiker het backendvenster sluit }
  ZMMainWindow: HWND = 0;
  { aangeroepen wanneer het platformvenster gesloten wordt; standaard plaatst WM_CLOSE in ZMMainWindow }
  ZMOnCloseRequest: procedure = nil;
  { idle-hook (TApplication.Idle), aangeroepen door WaitMessage vóór het blokkeren }
  ZMDesktopColor: LongWord = 0;
  { MessageBox-implementatie (geïnstalleerd door Forms: een dialoog in de framebuffer) }
  ZMMessageBoxHook: function(Venster: HWND; const Tekst, Titel: string; Vlaggen: UINT): Integer = nil;

procedure ZMInit;
procedure ZMShutdown;
procedure ZMSetScreenSize(Breedte, Hoogte: Integer);
function ZMTicks: LongWord;

function ZMWindowObj(Venster: HWND): TZMWindow;
function ZMCreateWindow(UitStijl: DWORD; const KlasseNaam, Tekst: string; Stijl: DWORD;
  X, Y, Breedte, Hoogte: Integer; Ouder: HWND; Ident: PtrInt; AMethode: TWndMethod; ProcAdres: Pointer): HWND;
function ZMDestroyWindow(Venster: HWND): Boolean;
procedure ZMSetWindowPos(Venster, Na: HWND; X, Y, Breedte, Hoogte: Integer; Vlaggen: UINT);
function ZMShowWindow(Venster: HWND; Tonen: Boolean): Boolean;
procedure ZMSetParent(Venster, NieuweOuder: HWND);
function ZMWindowFromPoint(Punt: TPoint; Overslaan: Boolean): HWND;
procedure ZMClientToScreen(Venster: HWND; var Punt: TPoint);
procedure ZMScreenToClient(Venster: HWND; var Punt: TPoint);
procedure ZMEnumTopLevel(Terugroep: TZMEnumWindowProc; Gegevens: Pointer);
procedure ZMEnumChildren(Venster: HWND; Terugroep: TZMEnumWindowProc; Gegevens: Pointer);
function ZMGetWindowInZ(Venster: HWND; Opdracht: UINT): HWND;
procedure ZMSetStyle(Venster: HWND; NieuweStijl: DWORD);
procedure ZMSetExStyle(Venster: HWND; NieuweUitStijl: DWORD);

{ tekenen }
procedure ZMInvalidate(Venster: HWND; R: PRect; Wissen: Boolean);
procedure ZMInvalidateTree(VensterObj: TZMWindow; const SchermR: TRect);
procedure ZMInvalidateScreen(const SchermR: TRect);
procedure ZMValidate(Venster: HWND; R: PRect);
function ZMGetUpdateRect(Venster: HWND; var R: TRect): Boolean;
function ZMGetDC(Venster: HWND; HeelVenster: Boolean): HDC;
procedure ZMReleaseDC(DC: HDC);
function ZMBeginPaint(Venster: HWND; var TekenInfo: TPaintStruct): HDC;
procedure ZMEndPaint(Venster: HWND; const TekenInfo: TPaintStruct);
procedure ZMUpdateWindow(Venster: HWND);
procedure ZMPaintNC(VensterObj: TZMWindow);

{ berichten }
function ZMPostMessage(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): Boolean;
function ZMSendMessage(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
function ZMPeekMessage(var Melding: TMsg; Venster: HWND; MinBericht, MaxBericht, Verwijderen: UINT): Boolean;
function ZMGetMessage(var Melding: TMsg; Venster: HWND; MinBericht, MaxBericht: UINT): Boolean;
procedure ZMTranslateMessage(const Melding: TMsg);
function ZMDispatchMessage(const Melding: TMsg): LRESULT;
procedure ZMWaitMessage;
function ZMDefWindowProc(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
function ZMCallWindow(VensterObj: TZMWindow; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
procedure ZMPollInput;
procedure ZMPresent(Forceer: Boolean);
function ZMMessagePos: TPoint;
function ZMMessageTime: LongWord;

{ timers }
function ZMSetTimer(Venster: HWND; Ident, Verstreken: UINT; Terugroep: Pointer): UINT;
function ZMKillTimer(Venster: HWND; Ident: UINT): Boolean;
function ZMAddMMTimer(Vertraging: UINT; Terugroep: Pointer; Gebruiker: PtrUInt; Periodiek: Boolean): UINT;
function ZMKillMMTimer(Ident: UINT): Boolean;

{ focus, activering, capture, invoerstatus }
function ZMSetFocus(Venster: HWND): HWND;
function ZMGetFocus: HWND;
function ZMSetActive(Venster: HWND): HWND;
function ZMGetActive: HWND;
function ZMSetCapture(Venster: HWND): HWND;
function ZMGetCapture: HWND;
procedure ZMReleaseCapture;
function ZMEnableWindow(Venster: HWND; Inschakelen: Boolean): Boolean;
function ZMKeyState(Toets: Integer): SmallInt;
function ZMCursorPos: TPoint;
procedure ZMSetCursorPos(X, Y: Integer);
procedure ZMSetCursorShape(Aanwijzer: HCURSOR);
function ZMCursorFromId(Ident: PtrUInt): HCURSOR;

procedure ZMDumpWindows;

{ Synthetische invoer, in de wachtrij gezet zoals backend-gebeurtenissen (werkt ook headless).
  Coördinaten zijn relatief aan het clientgebied van het hoofdformulier (ZMMainWindow; het
  scherm als die er niet is). Button: 0 = alleen verplaatsen, 1 = links, 2 = rechts. }
procedure ZMInjectMouse(X, Y: Integer; Knop: Integer; Omlaag: Boolean);
procedure ZMInjectKey(Toets: Word; Omlaag: Boolean);
procedure ZMInjectChar(Karakter: Char);

{ testondersteuning: sla het geëmuleerde scherm op als PNG }
function ZMSaveScreenshot(const Bestandsnaam: string): Boolean;

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
  TopLevels: TZMWindowArray;      { z-volgorde: 0 = onderste }
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
  Injected: array of TZMEvent;
  InIdleHook: Boolean = False;
  SyntheticMove: Boolean = False;
  MouseSeen: Boolean = False;
  Script: string;
  ScriptPos: Integer;

const
  CAPTION_H = 18;

{ ---------------------------------------------------------------- basis }

function ZMTicks: LongWord;
begin
  Result := ZMBackend.Ticks;
end;

function ZMWindowObj(Venster: HWND): TZMWindow;
var
  Obj: TObject;
begin
  Obj := ZMHandleObj(Venster);
  if (Obj <> nil) and (Obj is TZMWindow) then Result := TZMWindow(Obj) else Result := nil;
end;

procedure BumpVis;
begin
  Inc(ZMVisGeneration);
end;

function TZMWindow.NCInsets: TRect;
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

function TZMWindow.WindowRectScreen: TRect;
var
  Ouder: TZMWindow;
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

function TZMWindow.ClientRectScreen: TRect;
var
  Marge: TRect;
begin
  Result := WindowRectScreen;
  Marge := NCInsets;
  Inc(Result.Left, Marge.Left);
  Inc(Result.Top, Marge.Top);
  Dec(Result.Right, Marge.Right);
  Dec(Result.Bottom, Marge.Bottom);
  if Result.Right < Result.Left then Result.Right := Result.Left;
  if Result.Bottom < Result.Top then Result.Bottom := Result.Top;
end;

function TZMWindow.IsVisible: Boolean;
var
  VensterObj: TZMWindow;
begin
  VensterObj := Self;
  while VensterObj <> nil do
  begin
    if VensterObj.Style and WS_VISIBLE = 0 then Exit(False);
    VensterObj := VensterObj.Parent;
  end;
  Result := True;
end;

function TZMWindow.IsEnabledTree: Boolean;
var
  VensterObj: TZMWindow;
begin
  VensterObj := Self;
  while VensterObj <> nil do
  begin
    if VensterObj.Style and WS_DISABLED <> 0 then Exit(False);
    VensterObj := VensterObj.Parent;
  end;
  Result := True;
end;

function TZMWindow.TopLevel: TZMWindow;
begin
  Result := Self;
  while Result.Parent <> nil do Result := Result.Parent;
end;

{ ---------------------------------------------------------------- zichtbaarheid }

procedure ComputeVis(VensterObj: TZMWindow);
var
  Zichtbaar, VensterGebied: TZMRects;
  Voorouder, Zus: TZMWindow;
  I, Plaats: Integer;
  Zusters: TZMWindowArray;
  KlientR: TRect;
begin
  VensterObj.VisGen := ZMVisGeneration;
  VensterObj.VisClientCache := nil;
  VensterObj.VisWindowCache := nil;
  if not VensterObj.IsVisible then Exit;
  SetLength(VensterGebied, 1);
  VensterGebied[0] := VensterObj.WindowRectScreen;
  { knip bij tot de clientgebieden van de voorouders }
  Voorouder := VensterObj.Parent;
  while Voorouder <> nil do
  begin
    VensterGebied := RectsIntersectRect(VensterGebied, Voorouder.ClientRectScreen);
    Voorouder := Voorouder.Parent;
  end;
  VensterGebied := RectsIntersectRect(VensterGebied, Rect(0, 0, ZMScreenW, ZMScreenH));
  { trek zusters boven W en boven elke voorouder af }
  Voorouder := VensterObj;
  while Voorouder <> nil do
  begin
    if Voorouder.Parent = nil then Zusters := TopLevels else Zusters := Voorouder.Parent.Children;
    Plaats := -1;
    for I := 0 to High(Zusters) do
      if Zusters[I] = Voorouder then begin Plaats := I; Break; end;
    for I := Plaats + 1 to High(Zusters) do
    begin
      Zus := Zusters[I];
      if Zus.Style and WS_VISIBLE <> 0 then
        VensterGebied := RectsSubtractRect(VensterGebied, Zus.WindowRectScreen);
    end;
    Voorouder := Voorouder.Parent;
  end;
  VensterObj.VisWindowCache := VensterGebied;
  KlientR := VensterObj.ClientRectScreen;
  Zichtbaar := RectsIntersectRect(VensterGebied, KlientR);
  for I := 0 to High(VensterObj.Children) do
    if VensterObj.Children[I].Style and WS_VISIBLE <> 0 then
      Zichtbaar := RectsSubtractRect(Zichtbaar, VensterObj.Children[I].WindowRectScreen);
  VensterObj.VisClientCache := Zichtbaar;
  { de vensterrechthoek min de kinderen ook (voor vensters-DC's) }
  for I := 0 to High(VensterObj.Children) do
    if VensterObj.Children[I].Style and WS_VISIBLE <> 0 then
      VensterObj.VisWindowCache := RectsSubtractRect(VensterObj.VisWindowCache, VensterObj.Children[I].WindowRectScreen);
end;

function VisClient(VensterObj: TZMWindow): TZMRects;
begin
  if VensterObj.VisGen <> ZMVisGeneration then ComputeVis(VensterObj);
  Result := VensterObj.VisClientCache;
end;

function VisWindow(VensterObj: TZMWindow): TZMRects;
begin
  if VensterObj.VisGen <> ZMVisGeneration then ComputeVis(VensterObj);
  Result := VensterObj.VisWindowCache;
end;

procedure DCVisProvider(DCObjekt: TObject);
var
  DC: TZMDC;
  VensterObj: TZMWindow;
  R: TRect;
begin
  DC := TZMDC(DCObjekt);
  VensterObj := ZMWindowObj(DC.Wnd);
  if VensterObj = nil then
  begin
    DC.VisRgn := nil;
    Exit;
  end;
  if DC.IsWindowDC then
  begin
    DC.VisRgn := VisWindow(VensterObj);
    R := VensterObj.WindowRectScreen;
  end
  else
  begin
    DC.VisRgn := VisClient(VensterObj);
    R := VensterObj.ClientRectScreen;
  end;
  DC.DevOrg := Point(R.Left, R.Top);
  DC.InvalidateClip;
end;

{ ---------------------------------------------------------------- initialisatie }

function DefaultCloseRequest: Boolean;
begin
  Result := True;
end;

procedure ZMInit;
begin
  if Initialized then Exit;
  Initialized := True;
  InitStockObjects;
  ZMVisProvider := DCVisProvider;
  ZMScreen := TZMBitmap.Create(ZMScreenW, ZMScreenH, 32);
  ZMScreen.Dirty := True;
  OrigScreenW := ZMScreenW;
  OrigScreenH := ZMScreenH;
end;

procedure EnsureBackend;
begin
  if BackendOpen then Exit;
  ZMInit;
  BackendOpen := True;
  if not ZMBackend.Open('Virtueel Zoetermeer', ZMScreenW, ZMScreenH) then
  begin
    WriteLn(StdErr, 'compat: geen beeldschermbackend, draait headless');
    ZMFallbackToNull;
    ZMBackend.Open('Virtueel Zoetermeer', ZMScreenW, ZMScreenH);
  end;
  StartTicks := ZMTicks;
  ShotFile := GetEnvironmentVariable('ZM_SCREENSHOT');
  ShotAt := StrToIntDef(GetEnvironmentVariable('ZM_SCREENSHOT_AT'), 3000);
  ExitAt := StrToIntDef(GetEnvironmentVariable('ZM_EXIT_AT'), -1);
  Script := GetEnvironmentVariable('ZM_SCRIPT');
  ScriptPos := 1;
end;

procedure ZMShutdown;
begin
  if BackendOpen then ZMBackend.Close;
  BackendOpen := False;
end;

procedure ZMSetScreenSize(Breedte, Hoogte: Integer);
var
  NieuwScherm: TZMBitmap;
begin
  ZMInit;
  if (Breedte = ZMScreenW) and (Hoogte = ZMScreenH) then Exit;
  NieuwScherm := TZMBitmap.Create(Breedte, Hoogte, 32);
  ZMScreen.Free;
  ZMScreen := NieuwScherm;
  ZMScreenW := Breedte;
  ZMScreenH := Hoogte;
  BumpVis;
  if BackendOpen then ZMBackend.Resize(Breedte, Hoogte);
  ZMInvalidateScreen(Rect(0, 0, Breedte, Hoogte));
end;

function DDSetMode(Breedte, Hoogte, Bitdiepte: Integer): Boolean;
begin
  { het beeldscherm wordt op een vaste grootte geëmuleerd; modusveranderingen worden geaccepteerd }
  Result := True;
end;

procedure DDRestoreMode;
begin
end;

{ ---------------------------------------------------------------- aanmaak }

type
  TWinArray = TZMWindowArray;

procedure ArrRemove(var Lijst: TWinArray; VensterObj: TZMWindow);
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

procedure ArrInsert(var Lijst: TWinArray; VensterObj: TZMWindow; Plaats: Integer);
var
  J: Integer;
begin
  if (Plaats < 0) or (Plaats > Length(Lijst)) then Plaats := Length(Lijst);
  SetLength(Lijst, Length(Lijst) + 1);
  for J := High(Lijst) downto Plaats + 1 do Lijst[J] := Lijst[J - 1];
  Lijst[Plaats] := VensterObj;
end;

function SiblingsOf(VensterObj: TZMWindow): TWinArray;
begin
  if VensterObj.Parent = nil then Result := TopLevels else Result := VensterObj.Parent.Children;
end;

procedure SetSiblings(VensterObj: TZMWindow; const Lijst: TWinArray);
begin
  if VensterObj.Parent = nil then TopLevels := Lijst else VensterObj.Parent.Children := Lijst;
end;

{ invoegindex, rekening houdend met WS_EX_TOPMOST voor topniveauvensters }
function TopInsertIndex(const Lijst: TWinArray; VensterObj: TZMWindow): Integer;
begin
  Result := Length(Lijst);
  if (VensterObj.Parent = nil) and (VensterObj.ExStyle and WS_EX_TOPMOST = 0) then
    while (Result > 0) and (Lijst[Result - 1].ExStyle and WS_EX_TOPMOST <> 0) do Dec(Result);
end;

function ZMCreateWindow(UitStijl: DWORD; const KlasseNaam, Tekst: string; Stijl: DWORD;
  X, Y, Breedte, Hoogte: Integer; Ouder: HWND; Ident: PtrInt; AMethode: TWndMethod; ProcAdres: Pointer): HWND;
var
  VensterObj: TZMWindow;
  OuderObj: TZMWindow;
  Lijst: TWinArray;
  Maakstruct: TCreateStruct;
begin
  ZMInit;
  VensterObj := TZMWindow.Create;
  VensterObj.Handle := ZMAllocHandle(VensterObj);
  VensterObj.ClsName := KlasseNaam;
  VensterObj.ClsStyle := CS_DBLCLKS;
  VensterObj.Style := Stijl;
  VensterObj.ExStyle := UitStijl;
  VensterObj.Text := Tekst;
  VensterObj.Method := AMethode;
  VensterObj.Proc := ProcAdres;
  VensterObj.ID := Ident;
  if Breedte < 0 then Breedte := 0;
  if Hoogte < 0 then Hoogte := 0;
  VensterObj.R := Rect(X, Y, X + Breedte, Y + Hoogte);
  OuderObj := ZMWindowObj(Ouder);
  if (OuderObj <> nil) and (Stijl and WS_CHILD <> 0) then
  begin
    VensterObj.Parent := OuderObj;
    Lijst := OuderObj.Children;
    ArrInsert(Lijst, VensterObj, Length(Lijst));
    OuderObj.Children := Lijst;
  end
  else
  begin
    if OuderObj <> nil then VensterObj.Owner := Ouder;
    Lijst := TopLevels;
    ArrInsert(Lijst, VensterObj, TopInsertIndex(Lijst, VensterObj));
    TopLevels := Lijst;
  end;
  VensterObj.NCDirty := True;
  BumpVis;
  Result := VensterObj.Handle;
  FillChar(Maakstruct, SizeOf(Maakstruct), 0);
  Maakstruct.x := X; Maakstruct.y := Y; Maakstruct.cx := Breedte; Maakstruct.cy := Hoogte;
  Maakstruct.style := Stijl;
  Maakstruct.dwExStyle := UitStijl;
  Maakstruct.hwndParent := Ouder;
  ZMCallWindow(VensterObj, WM_NCCREATE, 0, LPARAM(@Maakstruct));
  ZMCallWindow(VensterObj, WM_CREATE, 0, LPARAM(@Maakstruct));
  if Stijl and WS_VISIBLE <> 0 then
    ZMInvalidateScreen(VensterObj.WindowRectScreen);
end;

function ZMDestroyWindow(Venster: HWND): Boolean;
var
  VensterObj: TZMWindow;
  Lijst: TWinArray;
  VensterR: TRect;
  WasZichtbaar: Boolean;
  I: Integer;
begin
  VensterObj := ZMWindowObj(Venster);
  if (VensterObj = nil) or VensterObj.Destroying then Exit(False);
  VensterObj.Destroying := True;
  WasZichtbaar := VensterObj.IsVisible;
  VensterR := VensterObj.WindowRectScreen;
  if WasZichtbaar then
  begin
    VensterObj.Style := VensterObj.Style and not WS_VISIBLE;
    BumpVis;
  end;
  ZMCallWindow(VensterObj, WM_DESTROY, 0, 0);
  while Length(VensterObj.Children) > 0 do
    if not ZMDestroyWindow(VensterObj.Children[High(VensterObj.Children)].Handle) then
    begin
      Lijst := VensterObj.Children;
      SetLength(Lijst, Length(Lijst) - 1);
      VensterObj.Children := Lijst;
    end;
  { eigen topniveauvensters gaan mee met hun eigenaar }
  I := 0;
  while I <= High(TopLevels) do
  begin
    if (TopLevels[I].Owner = Venster) and not TopLevels[I].Destroying then
    begin
      ZMDestroyWindow(TopLevels[I].Handle);
      I := 0;
    end
    else
      Inc(I);
  end;
  ZMCallWindow(VensterObj, WM_NCDESTROY, 0, 0);
  for I := 0 to High(Timers) do
    if Timers[I].Active and (Timers[I].Wnd = Venster) then Timers[I].Active := False;
  if FocusWnd = Venster then FocusWnd := 0;
  if CaptureWnd = Venster then CaptureWnd := 0;
  if ActiveWnd = Venster then ActiveWnd := 0;
  if ZMMainWindow = Venster then ZMMainWindow := 0;
  Lijst := SiblingsOf(VensterObj);
  ArrRemove(Lijst, VensterObj);
  SetSiblings(VensterObj, Lijst);
  { verwijder wachtende berichten voor dit venster }
  for I := 0 to QCount - 1 do
    if Queue[(QHead + I) mod Length(Queue)].hwnd = Venster then
      Queue[(QHead + I) mod Length(Queue)].message := WM_NULL;
  BumpVis;
  if WasZichtbaar then ZMInvalidateScreen(VensterR);
  ZMFreeHandle(Venster);
  VensterObj.Free;
  if (ActiveWnd = 0) and (Length(TopLevels) > 0) then
  begin
    for I := High(TopLevels) downto 0 do
      if TopLevels[I].IsVisible and TopLevels[I].IsEnabledTree then
      begin
        ZMSetActive(TopLevels[I].Handle);
        Break;
      end;
  end;
  Result := True;
end;

procedure ZMSetStyle(Venster: HWND; NieuweStijl: DWORD);
var
  VensterObj: TZMWindow;
begin
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  if VensterObj.Style = NieuweStijl then Exit;
  VensterObj.Style := NieuweStijl;
  BumpVis;
  VensterObj.NCDirty := True;
  if VensterObj.IsVisible then ZMInvalidateScreen(VensterObj.WindowRectScreen);
end;

procedure ZMSetExStyle(Venster: HWND; NieuweUitStijl: DWORD);
var
  VensterObj: TZMWindow;
begin
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  VensterObj.ExStyle := NieuweUitStijl;
  BumpVis;
  VensterObj.NCDirty := True;
  if VensterObj.IsVisible then ZMInvalidateScreen(VensterObj.WindowRectScreen);
end;

procedure ZMSetWindowPos(Venster, Na: HWND; X, Y, Breedte, Hoogte: Integer; Vlaggen: UINT);
var
  VensterObj: TZMWindow;
  OudR, OudScherm, NieuwScherm: TRect;
  Lijst: TWinArray;
  Verplaatst, Hergrootd, WasZichtbaar, Gewijzigd: Boolean;
  Positie: TWindowPos;
  I: Integer;
begin
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  OudR := VensterObj.R;
  WasZichtbaar := VensterObj.IsVisible;
  OudScherm := VensterObj.WindowRectScreen;
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
    Lijst := SiblingsOf(VensterObj);
    ArrRemove(Lijst, VensterObj);
    if Na = HWND_TOPMOST then
    begin
      VensterObj.ExStyle := VensterObj.ExStyle or WS_EX_TOPMOST;
      ArrInsert(Lijst, VensterObj, Length(Lijst));
    end
    else if Na = HWND_NOTOPMOST then
    begin
      VensterObj.ExStyle := VensterObj.ExStyle and not WS_EX_TOPMOST;
      ArrInsert(Lijst, VensterObj, TopInsertIndex(Lijst, VensterObj));
    end
    else if Na = HWND_TOP then
      ArrInsert(Lijst, VensterObj, TopInsertIndex(Lijst, VensterObj))
    else if Na = HWND_BOTTOM then
      ArrInsert(Lijst, VensterObj, 0)
    else
    begin
      { plaats onder After }
      I := 0;
      while (I <= High(Lijst)) and (Lijst[I].Handle <> Na) do Inc(I);
      if I > High(Lijst) then ArrInsert(Lijst, VensterObj, TopInsertIndex(Lijst, VensterObj))
      else ArrInsert(Lijst, VensterObj, I);
    end;
    SetSiblings(VensterObj, Lijst);
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
  BumpVis;
  VensterObj.NCDirty := True;
  if WasZichtbaar then ZMInvalidateScreen(OudScherm);
  NieuwScherm := VensterObj.WindowRectScreen;
  if VensterObj.IsVisible then ZMInvalidateScreen(NieuwScherm);
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
    ZMCallWindow(VensterObj, WM_WINDOWPOSCHANGED, 0, LPARAM(@Positie));
  if Verplaatst then
    ZMCallWindow(VensterObj, WM_MOVE, 0, MakeLParam(Word(VensterObj.R.Left), Word(VensterObj.R.Top)));
  if Hergrootd then
    with VensterObj.ClientRectScreen do
      ZMCallWindow(VensterObj, WM_SIZE, SIZE_RESTORED, MakeLParam(Word(Right - Left), Word(Bottom - Top)));
  if (Vlaggen and SWP_SHOWWINDOW <> 0) and not WasZichtbaar then
    ZMCallWindow(VensterObj, WM_SHOWWINDOW, 1, 0)
  else if (Vlaggen and SWP_HIDEWINDOW <> 0) and WasZichtbaar then
    ZMCallWindow(VensterObj, WM_SHOWWINDOW, 0, 0);
end;

function ZMShowWindow(Venster: HWND; Tonen: Boolean): Boolean;
var
  VensterObj: TZMWindow;
begin
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit(False);
  Result := VensterObj.Style and WS_VISIBLE <> 0;
  if Tonen = Result then Exit;
  if Tonen then
    ZMSetWindowPos(Venster, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_SHOWWINDOW)
  else
  begin
    ZMSetWindowPos(Venster, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_HIDEWINDOW);
    if (FocusWnd <> 0) then
    begin
      { focus binnen een verborgen venster gaat verloren }
      if (FocusWnd = Venster) or (IsChild(Venster, FocusWnd)) then ZMSetFocus(0);
    end;
    if ActiveWnd = Venster then
    begin
      ActiveWnd := 0;
    end;
  end;
end;

procedure ZMSetParent(Venster, NieuweOuder: HWND);
var
  VensterObj, OuderObj: TZMWindow;
  Lijst: TWinArray;
  WasZichtbaar: Boolean;
  OudScherm: TRect;
begin
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  OuderObj := ZMWindowObj(NieuweOuder);
  if VensterObj.Parent = OuderObj then Exit;
  WasZichtbaar := VensterObj.IsVisible;
  OudScherm := VensterObj.WindowRectScreen;
  Lijst := SiblingsOf(VensterObj);
  ArrRemove(Lijst, VensterObj);
  SetSiblings(VensterObj, Lijst);
  VensterObj.Parent := OuderObj;
  if OuderObj <> nil then
  begin
    VensterObj.Style := VensterObj.Style or WS_CHILD;
    Lijst := OuderObj.Children;
  end
  else
    Lijst := TopLevels;
  ArrInsert(Lijst, VensterObj, TopInsertIndex(Lijst, VensterObj));
  SetSiblings(VensterObj, Lijst);
  BumpVis;
  if WasZichtbaar then ZMInvalidateScreen(OudScherm);
  if VensterObj.IsVisible then ZMInvalidateScreen(VensterObj.WindowRectScreen);
end;

function HitTest(const Lijst: TWinArray; Punt: TPoint; Overslaan: Boolean): TZMWindow;
var
  I: Integer;
  VensterObj, Kind: TZMWindow;
  R: TRect;
begin
  Result := nil;
  for I := High(Lijst) downto 0 do
  begin
    VensterObj := Lijst[I];
    if VensterObj.Style and WS_VISIBLE = 0 then Continue;
    R := VensterObj.WindowRectScreen;
    if not PtInRect(R, Punt) then Continue;
    if PtInRect(VensterObj.ClientRectScreen, Punt) then
    begin
      Kind := HitTest(VensterObj.Children, Punt, Overslaan);
      if Kind <> nil then Exit(Kind);
    end;
    if Overslaan and (VensterObj.Style and WS_DISABLED <> 0) then Exit(nil);
    Exit(VensterObj);
  end;
end;

function ZMWindowFromPoint(Punt: TPoint; Overslaan: Boolean): HWND;
var
  VensterObj: TZMWindow;
begin
  VensterObj := HitTest(TopLevels, Punt, Overslaan);
  if VensterObj = nil then Result := 0 else Result := VensterObj.Handle;
end;

procedure ZMClientToScreen(Venster: HWND; var Punt: TPoint);
var
  VensterObj: TZMWindow;
  R: TRect;
begin
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  R := VensterObj.ClientRectScreen;
  Inc(Punt.X, R.Left);
  Inc(Punt.Y, R.Top);
end;

procedure ZMScreenToClient(Venster: HWND; var Punt: TPoint);
var
  VensterObj: TZMWindow;
  R: TRect;
begin
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  R := VensterObj.ClientRectScreen;
  Dec(Punt.X, R.Left);
  Dec(Punt.Y, R.Top);
end;

procedure ZMEnumTopLevel(Terugroep: TZMEnumWindowProc; Gegevens: Pointer);
var
  Lijst: TWinArray;
  I: Integer;
begin
  Lijst := Copy(TopLevels, 0, Length(TopLevels));
  for I := High(Lijst) downto 0 do
    if not Terugroep(Lijst[I].Handle, Gegevens) then Break;
end;

procedure ZMEnumChildren(Venster: HWND; Terugroep: TZMEnumWindowProc; Gegevens: Pointer);
var
  VensterObj: TZMWindow;
  Lijst: TWinArray;
  I: Integer;
begin
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  Lijst := Copy(VensterObj.Children, 0, Length(VensterObj.Children));
  for I := High(Lijst) downto 0 do
    if not Terugroep(Lijst[I].Handle, Gegevens) then Break;
end;

function ZMGetWindowInZ(Venster: HWND; Opdracht: UINT): HWND;
const
  GW_HWNDFIRST = 0; GW_HWNDLAST = 1; GW_HWNDNEXT = 2; GW_HWNDPREV = 3; GW_OWNER = 4; GW_CHILD = 5;
var
  VensterObj: TZMWindow;
  Lijst: TWinArray;
  I: Integer;
begin
  Result := 0;
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then
  begin
    if (Venster = 0) and (Opdracht = GW_CHILD) and (Length(TopLevels) > 0) then
      Result := TopLevels[High(TopLevels)].Handle;
    Exit;
  end;
  Lijst := SiblingsOf(VensterObj);
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
    GW_CHILD: if Length(VensterObj.Children) > 0 then Result := VensterObj.Children[High(VensterObj.Children)].Handle;
  end;
end;

{ ---------------------------------------------------------------- tekenen }

procedure AddUpdate(VensterObj: TZMWindow; const KlientR: TRect; Wissen: Boolean);
var
  KlientLok: TRect;
  Rechthoeken: TZMRects;
begin
  with VensterObj.ClientRectScreen do KlientLok := Rect(0, 0, Right - Left, Bottom - Top);
  SetLength(Rechthoeken, 1);
  Rechthoeken[0] := KlientR;
  Rechthoeken := RectsIntersectRect(Rechthoeken, KlientLok);
  if Length(Rechthoeken) = 0 then Exit;
  VensterObj.UpdRgn := RectsUnion(VensterObj.UpdRgn, Rechthoeken);
  { houd het gebied klein: vouw het samen tot zijn omhullende rechthoek als het versplintert }
  if Length(VensterObj.UpdRgn) > 16 then
  begin
    SetLength(Rechthoeken, 1);
    Rechthoeken[0] := RectsBox(VensterObj.UpdRgn);
    VensterObj.UpdRgn := Rechthoeken;
  end;
  if Wissen then VensterObj.EraseBk := True;
end;

procedure ZMInvalidateTree(VensterObj: TZMWindow; const SchermR: TRect);
var
  VensterR, KlientR, Snijding: TRect;
  I: Integer;
begin
  if VensterObj.Style and WS_VISIBLE = 0 then Exit;
  VensterR := VensterObj.WindowRectScreen;
  if not IntersectRect(Snijding, VensterR, SchermR) then Exit;
  KlientR := VensterObj.ClientRectScreen;
  if not EqualRect(VensterR, KlientR) then
    if not (PtInRect(KlientR, Snijding.TopLeft) and PtInRect(KlientR, Point(Snijding.Right - 1, Snijding.Bottom - 1))) then
      VensterObj.NCDirty := True;
  if IntersectRect(Snijding, KlientR, SchermR) then
  begin
    OffsetRect(Snijding, -KlientR.Left, -KlientR.Top);
    AddUpdate(VensterObj, Snijding, True);
  end;
  for I := 0 to High(VensterObj.Children) do
    ZMInvalidateTree(VensterObj.Children[I], SchermR);
end;

procedure ZMInvalidateScreen(const SchermR: TRect);
var
  I: Integer;
begin
  ZMInit;
  for I := 0 to High(TopLevels) do
    ZMInvalidateTree(TopLevels[I], SchermR);
  DesktopDirty := True;
end;

procedure PaintDesktop;
var
  Bureaugebied: TZMRects;
  I, X, Y: Integer;
  Pixel: PLongWord;
begin
  DesktopDirty := False;
  SetLength(Bureaugebied, 1);
  Bureaugebied[0] := Rect(0, 0, ZMScreenW, ZMScreenH);
  for I := 0 to High(TopLevels) do
    if TopLevels[I].Style and WS_VISIBLE <> 0 then
      Bureaugebied := RectsSubtractRect(Bureaugebied, TopLevels[I].WindowRectScreen);
  for I := 0 to High(Bureaugebied) do
    for Y := Bureaugebied[I].Top to Bureaugebied[I].Bottom - 1 do
    begin
      Pixel := PLongWord(ZMScreen.RowPtr(Y)) + Bureaugebied[I].Left;
      for X := Bureaugebied[I].Left to Bureaugebied[I].Right - 1 do
      begin
        Pixel^ := ZMDesktopColor;
        Inc(Pixel);
      end;
    end;
  if Length(Bureaugebied) > 0 then ZMScreen.Dirty := True;
end;

procedure ZMInvalidate(Venster: HWND; R: PRect; Wissen: Boolean);
var
  VensterObj: TZMWindow;
  KlientR: TRect;
begin
  if Venster = 0 then
  begin
    if R = nil then ZMInvalidateScreen(Rect(0, 0, ZMScreenW, ZMScreenH))
    else ZMInvalidateScreen(R^);
    Exit;
  end;
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  if R = nil then
  begin
    with VensterObj.ClientRectScreen do KlientR := Rect(0, 0, Right - Left, Bottom - Top);
    AddUpdate(VensterObj, KlientR, Wissen);
  end
  else
    AddUpdate(VensterObj, R^, Wissen);
end;

procedure ZMValidate(Venster: HWND; R: PRect);
var
  VensterObj: TZMWindow;
begin
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  if R = nil then
  begin
    VensterObj.UpdRgn := nil;
    VensterObj.EraseBk := False;
  end
  else
    VensterObj.UpdRgn := RectsSubtractRect(VensterObj.UpdRgn, R^);
end;

function ZMGetUpdateRect(Venster: HWND; var R: TRect): Boolean;
var
  VensterObj: TZMWindow;
begin
  VensterObj := ZMWindowObj(Venster);
  if (VensterObj = nil) or (Length(VensterObj.UpdRgn) = 0) then
  begin
    R := Rect(0, 0, 0, 0);
    Exit(False);
  end;
  R := RectsBox(VensterObj.UpdRgn);
  Result := True;
end;

function ZMGetDC(Venster: HWND; HeelVenster: Boolean): HDC;
var
  DC: TZMDC;
  VensterObj: TZMWindow;
begin
  ZMInit;
  DC := TZMDC.Create(ZMScreen);
  if Venster = 0 then
  begin
    DC.HasVis := False;
    Exit(DC.Handle);
  end;
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then
  begin
    DC.Free;
    Exit(0);
  end;
  DC.Wnd := Venster;
  DC.IsWindowDC := HeelVenster;
  DC.HasVis := True;
  DCVisProvider(DC);
  DC.VisGen := ZMVisGeneration;
  Result := DC.Handle;
end;

procedure ZMReleaseDC(DC: HDC);
var
  Teken: TZMDC;
begin
  Teken := GdiDC(DC);
  if (Teken <> nil) and not Teken.IsMemDC then Teken.Free;
end;

function ZMBeginPaint(Venster: HWND; var TekenInfo: TPaintStruct): HDC;
var
  VensterObj: TZMWindow;
  DC: TZMDC;
  KlientR: TRect;
begin
  FillChar(TekenInfo, SizeOf(TekenInfo), 0);
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit(0);
  Result := ZMGetDC(Venster, False);
  DC := GdiDC(Result);
  KlientR := VensterObj.ClientRectScreen;
  DC.PaintRgn := RectsOffset(VensterObj.UpdRgn, KlientR.Left, KlientR.Top);
  DC.HasPaintRgn := True;
  DC.IsPaintDC := True;
  DC.InvalidateClip;
  TekenInfo.hdc := Result;
  TekenInfo.rcPaint := RectsBox(VensterObj.UpdRgn);
  TekenInfo.fErase := VensterObj.EraseBk;
  VensterObj.UpdRgn := nil;
  if VensterObj.EraseBk then
  begin
    VensterObj.EraseBk := False;
    if ZMCallWindow(VensterObj, WM_ERASEBKGND, WPARAM(Result), 0) <> 0 then
      TekenInfo.fErase := False;
  end;
end;

procedure ZMEndPaint(Venster: HWND; const TekenInfo: TPaintStruct);
begin
  ZMReleaseDC(TekenInfo.hdc);
end;

procedure PaintWindow(VensterObj: TZMWindow);
begin
  if VensterObj.NCDirty then ZMPaintNC(VensterObj);
  if Length(VensterObj.UpdRgn) > 0 then
    ZMCallWindow(VensterObj, WM_PAINT, 0, 0);
end;

procedure ZMUpdateWindow(Venster: HWND);
var
  VensterObj: TZMWindow;
  I: Integer;
  Kinderen: TWinArray;
begin
  VensterObj := ZMWindowObj(Venster);
  if (VensterObj = nil) or not VensterObj.IsVisible then Exit;
  PaintWindow(VensterObj);
  Kinderen := Copy(VensterObj.Children, 0, Length(VensterObj.Children));
  for I := 0 to High(Kinderen) do
    if ZMWindowObj(Kinderen[I].Handle) = Kinderen[I] then
      ZMUpdateWindow(Kinderen[I].Handle);
end;

procedure ZMPaintNC(VensterObj: TZMWindow);
var
  DC: HDC;
  Teken: TZMDC;
  R, KlientR, TitelR: TRect;
  Marge: TRect;
  Actief: Boolean;
  Lettertype: TLogFont;
  FontObj: TZMFontObj;
  OudFont: TZMFontObj;
  procedure Kader(const Gebied: TRect; LinksBoven, RechtsOnder: COLORREF);
  begin
    GdiFillSolid(Teken, Rect(Gebied.Left, Gebied.Top, Gebied.Right - 1, Gebied.Top + 1), LinksBoven);
    GdiFillSolid(Teken, Rect(Gebied.Left, Gebied.Top, Gebied.Left + 1, Gebied.Bottom - 1), LinksBoven);
    GdiFillSolid(Teken, Rect(Gebied.Left, Gebied.Bottom - 1, Gebied.Right, Gebied.Bottom), RechtsOnder);
    GdiFillSolid(Teken, Rect(Gebied.Right - 1, Gebied.Top, Gebied.Right, Gebied.Bottom), RechtsOnder);
  end;
begin
  VensterObj.NCDirty := False;
  Marge := VensterObj.NCInsets;
  if (Marge.Left = 0) and (Marge.Top = 0) and (Marge.Right = 0) and (Marge.Bottom = 0) then Exit;
  if not VensterObj.IsVisible then Exit;
  DC := ZMGetDC(VensterObj.Handle, True);
  Teken := GdiDC(DC);
  try
    { sluit het clientgebied uit }
    R := Rect(0, 0, VensterObj.R.Right - VensterObj.R.Left, VensterObj.R.Bottom - VensterObj.R.Top);
    KlientR := Rect(Marge.Left, Marge.Top, R.Right - Marge.Right, R.Bottom - Marge.Bottom);
    Teken.St.HasClip := True;
    SetLength(Teken.St.ClipRgn, 1);
    Teken.St.ClipRgn[0] := R;
    Teken.St.ClipRgn := RectsSubtractRect(Teken.St.ClipRgn, KlientR);
    Teken.InvalidateClip;
    if VensterObj.ExStyle and WS_EX_CLIENTEDGE <> 0 then
    begin
      Kader(Rect(KlientR.Left - 2, KlientR.Top - 2, KlientR.Right + 2, KlientR.Bottom + 2), $808080, $FFFFFF);
      Kader(Rect(KlientR.Left - 1, KlientR.Top - 1, KlientR.Right + 1, KlientR.Bottom + 1), $404040, $C0C0C0);
    end;
    if VensterObj.ExStyle and WS_EX_STATICEDGE <> 0 then
      Kader(Rect(KlientR.Left - 1, KlientR.Top - 1, KlientR.Right + 1, KlientR.Bottom + 1), $808080, $FFFFFF);
    if (VensterObj.Style and (WS_THICKFRAME or WS_DLGFRAME) <> 0) or (VensterObj.ExStyle and WS_EX_DLGMODALFRAME <> 0) then
    begin
      GdiFillSolid(Teken, R, SysColors[COLOR_BTNFACE]);
      Kader(R, $C0C0C0, $000000);
      Kader(Rect(1, 1, R.Right - 1, R.Bottom - 1), $FFFFFF, $808080);
    end
    else if VensterObj.Style and WS_BORDER <> 0 then
      Kader(R, $000000, $000000);
    if VensterObj.Style and WS_CAPTION = WS_CAPTION then
    begin
      Actief := (ActiveWnd = VensterObj.Handle);
      TitelR := Rect(Marge.Left, Marge.Top - CAPTION_H - 1, R.Right - Marge.Right, Marge.Top - 1);
      if Actief then GdiFillSolid(Teken, TitelR, SysColors[COLOR_ACTIVECAPTION])
      else GdiFillSolid(Teken, TitelR, SysColors[COLOR_INACTIVECAPTION]);
      FillChar(Lettertype, SizeOf(Lettertype), 0);
      Lettertype.lfHeight := -11;
      Lettertype.lfWeight := FW_BOLD;
      Lettertype.lfFaceName := 'MS Sans Serif';
      FontObj := TZMFontObj.Create(Lettertype);
      OudFont := Teken.St.Font;
      Teken.St.Font := FontObj;
      Teken.St.BkMode := TRANSPARENT;
      if Actief then Teken.St.TextColor := $FFFFFF else Teken.St.TextColor := $C0C0C0;
      GdiTextOut(Teken, TitelR.Left + 4, TitelR.Top + (CAPTION_H - FontObj.Face^.Height) div 2,
        PAnsiChar(AnsiString(VensterObj.Text)), Length(VensterObj.Text), False, @TitelR, nil);
      Teken.St.Font := OudFont;
      FontObj.Free;
      if VensterObj.Style and WS_SYSMENU <> 0 then
      begin
        { sluitknop }
        TitelR := Rect(TitelR.Right - 18, TitelR.Top + 2, TitelR.Right - 2, TitelR.Bottom - 2);
        GdiFillSolid(Teken, TitelR, SysColors[COLOR_BTNFACE]);
        Kader(TitelR, $FFFFFF, $000000);
        Teken.St.Pen := TZMPen(StockObjects[BLACK_PEN]);
        GdiLine(Teken, TitelR.Left + 4, TitelR.Top + 3, TitelR.Right - 5, TitelR.Bottom - 4, True);
        GdiLine(Teken, TitelR.Left + 5, TitelR.Top + 3, TitelR.Right - 4, TitelR.Bottom - 4, True);
        GdiLine(Teken, TitelR.Right - 5, TitelR.Top + 3, TitelR.Left + 4, TitelR.Bottom - 4, True);
        GdiLine(Teken, TitelR.Right - 4, TitelR.Top + 3, TitelR.Left + 5, TitelR.Bottom - 4, True);
      end;
    end;
  finally
    ZMReleaseDC(DC);
  end;
end;

{ ---------------------------------------------------------------- berichten }

function ZMCallWindow(VensterObj: TZMWindow; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
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
    Result := ZMDefWindowProc(VensterObj.Handle, Bericht, WPar, LPar);
end;

function ZMSendMessage(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
var
  VensterObj: TZMWindow;
  I: Integer;
begin
  if Venster = HWND_BROADCAST then
  begin
    for I := 0 to High(TopLevels) do ZMCallWindow(TopLevels[I], Bericht, WPar, LPar);
    Exit(0);
  end;
  VensterObj := ZMWindowObj(Venster);
  Result := ZMCallWindow(VensterObj, Bericht, WPar, LPar);
end;

procedure QueuePush(const Melding: TMsg);
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

function ZMPostMessage(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): Boolean;
var
  Melding: TMsg;
begin
  ZMInit;
  if (Venster <> 0) and (Venster <> HWND_BROADCAST) and (ZMWindowObj(Venster) = nil) then Exit(False);
  Melding.hwnd := Venster;
  Melding.message := Bericht;
  Melding.wParam := WPar;
  Melding.lParam := LPar;
  Melding.time := ZMTicks;
  Melding.pt := MousePos;
  QueuePush(Melding);
  Result := True;
end;

function MsgMatches(const Melding: TMsg; Venster: HWND; MinBericht, MaxBericht: UINT): Boolean;
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

function CallMMTimers: Boolean; forward;
procedure PostMouse(Bericht: UINT; Punt: TPoint; ExtraWPar: WPARAM); forward;

function FindPaint(Venster: HWND; var Melding: TMsg): Boolean;
  function Zoek(const Lijst: TWinArray): TZMWindow;
  var
    I: Integer;
    VensterObj: TZMWindow;
  begin
    Result := nil;
    for I := 0 to High(Lijst) do
    begin
      VensterObj := Lijst[I];
      if VensterObj.Style and WS_VISIBLE = 0 then Continue;
      if (Length(VensterObj.UpdRgn) > 0) or VensterObj.NCDirty then
        if (Venster = 0) or (VensterObj.Handle = Venster) or IsChild(Venster, VensterObj.Handle) then Exit(VensterObj);
      Result := Zoek(VensterObj.Children);
      if Result <> nil then Exit;
    end;
  end;
var
  VensterObj: TZMWindow;
begin
  if DesktopDirty then PaintDesktop;
  repeat
    VensterObj := Zoek(TopLevels);
    if VensterObj = nil then Exit(False);
    if VensterObj.NCDirty then ZMPaintNC(VensterObj);
  until Length(VensterObj.UpdRgn) > 0;
  Melding.hwnd := VensterObj.Handle;
  Melding.message := WM_PAINT;
  Melding.wParam := 0;
  Melding.lParam := 0;
  Melding.time := ZMTicks;
  Melding.pt := MousePos;
  Result := True;
end;

function FindTimer(Venster: HWND; var Melding: TMsg; Verwijderen: Boolean): Boolean;
var
  I, Beste: Integer;
  Nu: LongWord;
begin
  Result := False;
  Nu := ZMTicks;
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
  LastPoll: LongWord;

procedure DumpTree(const Lijst: TWinArray; Inspringing: string);
var
  I: Integer;
  VensterObj: TZMWindow;
begin
  for I := High(Lijst) downto 0 do
  begin
    VensterObj := Lijst[I];
    WriteLn(StdErr, Inspringing, VensterObj.Handle, ' ', VensterObj.ClsName, ' "', VensterObj.Text, '" vis=', Ord(VensterObj.Style and WS_VISIBLE <> 0),
      ' dis=', Ord(VensterObj.Style and WS_DISABLED <> 0), ' R=', VensterObj.R.Left, ',', VensterObj.R.Top, ',', VensterObj.R.Right, ',', VensterObj.R.Bottom,
      ' upd=', Length(VensterObj.UpdRgn));
    DumpTree(VensterObj.Children, Inspringing + '  ');
  end;
end;

procedure ZMDumpWindows;
begin
  WriteLn(StdErr, 'vensterboom (bovenste eerst), actief=', ActiveWnd, ' focus=', FocusWnd, ' capture=', CaptureWnd);
  DumpTree(TopLevels, '  ');
end;

{ ZM_SCRIPT="ms:cmd[:args];..." met cmd = click:x,y | rclick:x,y | move:x,y |
  key:vk | char:c | shot:bestand.png | exit. Tijden zijn ms sinds de start, coördinaten
  zijn relatief aan het clientgebied van het hoofdformulier. Voor tests zonder harnas. }
procedure RunScript(Tijd: LongWord);
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
      ZMInjectMouse(X, Y, 1, True);
      ZMInjectMouse(X, Y, 1, False);
    end
    else if Commando = 'rclick' then
    begin
      ZMInjectMouse(X, Y, 2, True);
      ZMInjectMouse(X, Y, 2, False);
    end
    else if Commando = 'move' then ZMInjectMouse(X, Y, 0, False)
    else if Commando = 'key' then
    begin
      ZMInjectKey(StrToIntDef(Argument, 0), True);
      ZMInjectKey(StrToIntDef(Argument, 0), False);
    end
    else if Commando = 'char' then
    begin
      if Argument <> '' then ZMInjectChar(Argument[1]);
    end
    else if Commando = 'shot' then
    begin
      ZMPresent(True);
      if ZMSaveScreenshot(Argument) then WriteLn(StdErr, 'compat: screenshot opgeslagen in ', Argument);
    end
    else if Commando = 'exit' then
      Halt(0);
  end;
end;

procedure TestHooks;
var
  Tijd: LongWord;
begin
  if Script <> '' then RunScript(ZMTicks - StartTicks);
  if (ShotFile = '') and (ExitAt < 0) then Exit;
  Tijd := ZMTicks - StartTicks;
  if (ShotFile <> '') and (Integer(Tijd) >= ShotAt) then
  begin
    if ZMSaveScreenshot(ShotFile) then
      WriteLn(StdErr, 'compat: screenshot opgeslagen in ', ShotFile);
    if GetEnvironmentVariable('ZM_DEBUG') <> '' then ZMDumpWindows;
    ShotFile := '';
  end;
  if (ExitAt >= 0) and (Integer(Tijd) >= ExitAt) then
  begin
    WriteLn(StdErr, 'compat: ZM_EXIT_AT bereikt, wordt afgesloten');
    Halt(0);
  end;
end;

function ZMPeekMessage(var Melding: TMsg; Venster: HWND; MinBericht, MaxBericht, Verwijderen: UINT): Boolean;
var
  I, J, Plaats: Integer;
  Nu: LongWord;
begin
  ZMInit;
  EnsureBackend;
  Nu := ZMTicks;
  if (Nu - LastPoll >= 4) or (QCount = 0) or (Length(Injected) > 0) or Assigned(ZMIdleHook) or (Script <> '') then
  begin
    LastPoll := Nu;
    ZMPollInput;
    TestHooks;
  end;
  CallMMTimers;
  { geplaatste / invoerberichten }
  for I := 0 to QCount - 1 do
  begin
    Plaats := (QHead + I) mod Length(Queue);
    if MsgMatches(Queue[Plaats], Venster, MinBericht, MaxBericht) then
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
          Exit(ZMPeekMessage(Melding, Venster, MinBericht, MaxBericht, Verwijderen));
      end;
      LastMsgPos := Melding.pt;
      LastMsgTime := Melding.time;
      if Melding.message = WM_QUIT then ZMQuitRequested := True;
      Exit(True);
    end;
  end;
  { synthetische muisbeweging (na het loslaten van capture of vensterwijzigingen onder de cursor) }
  if SyntheticMove and MouseSeen and (QCount = 0) then
  begin
    SyntheticMove := False;
    PostMouse(WM_MOUSEMOVE, MousePos, 0);
    if QCount > 0 then Exit(ZMPeekMessage(Melding, Venster, MinBericht, MaxBericht, Verwijderen));
  end;
  { tekenen }
  if ((MinBericht = 0) and (MaxBericht = 0)) or ((WM_PAINT >= MinBericht) and (WM_PAINT <= MaxBericht)) then
    if FindPaint(Venster, Melding) then
    begin
      LastMsgPos := Melding.pt;
      LastMsgTime := Melding.time;
      Exit(True);
    end;
  { timers }
  if ((MinBericht = 0) and (MaxBericht = 0)) or ((WM_TIMER >= MinBericht) and (WM_TIMER <= MaxBericht)) then
    if FindTimer(Venster, Melding, Verwijderen and PM_REMOVE <> 0) then
    begin
      LastMsgPos := Melding.pt;
      LastMsgTime := Melding.time;
      Exit(True);
    end;
  { niets: toon wat er getekend is }
  ZMPresent(False);
  Result := False;
end;

function NextTimerDue: Integer;
var
  I: Integer;
  Nu: LongWord;
  Verschil: LongInt;
begin
  Result := 50;
  Nu := ZMTicks;
  for I := 0 to High(Timers) do
    if Timers[I].Active then
    begin
      Verschil := LongInt(Timers[I].Due - Nu);
      if Verschil < 0 then Verschil := 0;
      if Verschil < Result then Result := Verschil;
    end;
end;

procedure ZMWaitMessage;
var
  Wacht: Integer;
  Melding: TMsg;
begin
  EnsureBackend;
  if ZMPeekMessage(Melding, 0, 0, 0, PM_NOREMOVE) then Exit;
  ZMPresent(True);
  Wacht := NextTimerDue;
  if Wacht > 0 then ZMBackend.WaitEvent(Wacht);
end;

function ZMGetMessage(var Melding: TMsg; Venster: HWND; MinBericht, MaxBericht: UINT): Boolean;
begin
  while not ZMPeekMessage(Melding, Venster, MinBericht, MaxBericht, PM_REMOVE) do
    ZMWaitMessage;
  Result := Melding.message <> WM_QUIT;
end;

procedure ZMTranslateMessage(const Melding: TMsg);
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
      ZMPostMessage(Melding.hwnd, WM_CHAR, Code, Melding.lParam)
    else
      ZMPostMessage(Melding.hwnd, WM_SYSCHAR, Code, Melding.lParam);
end;

function ZMDispatchMessage(const Melding: TMsg): LRESULT;
var
  VensterObj: TZMWindow;
begin
  Result := 0;
  if (Melding.message = WM_TIMER) and (Melding.lParam <> 0) then
  begin
    TTimerProc(Pointer(PtrUInt(Melding.lParam)))(Melding.hwnd, WM_TIMER, Melding.wParam, ZMTicks);
    Exit;
  end;
  VensterObj := ZMWindowObj(Melding.hwnd);
  if VensterObj = nil then Exit;
  Result := ZMCallWindow(VensterObj, Melding.message, Melding.wParam, Melding.lParam);
  if (Melding.message = WM_PAINT) and (ZMWindowObj(Melding.hwnd) = VensterObj) and (Length(VensterObj.UpdRgn) > 0) then
  begin
    { het venster heeft niet getekend (geen BeginPaint): valideer het zodat we niet blijven lussen }
    VensterObj.UpdRgn := nil;
    VensterObj.EraseBk := False;
  end;
end;

function ZMDefWindowProc(Venster: HWND; Bericht: UINT; WPar: WPARAM; LPar: LPARAM): LRESULT;
var
  VensterObj: TZMWindow;
  TekenInfo: TPaintStruct;
  DC: HDC;
  R: TRect;
  Kwast: TZMBrush;
begin
  Result := 0;
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  case Bericht of
    WM_PAINT:
      begin
        ZMBeginPaint(Venster, TekenInfo);
        ZMEndPaint(Venster, TekenInfo);
      end;
    WM_ERASEBKGND:
      begin
        Kwast := GdiBrush(VensterObj.ClsBrush);
        if Kwast <> nil then
        begin
          DC := HDC(WPar);
          with VensterObj.ClientRectScreen do R := Rect(0, 0, Right - Left, Bottom - Top);
          GdiFillRect(GdiDC(DC), R, Kwast);
          Result := 1;
        end;
      end;
    WM_CLOSE: ZMDestroyWindow(Venster);
    WM_SETTEXT:
      begin
        if LPar <> 0 then VensterObj.Text := StrPas(PAnsiChar(LPar)) else VensterObj.Text := '';
        VensterObj.NCDirty := True;
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
          ZMSetFocus(Venster);
    WM_NCHITTEST: Result := HTCLIENT;
    WM_SETCURSOR:
      begin
        if VensterObj.ClsCursor <> 0 then ZMSetCursorShape(VensterObj.ClsCursor)
        else ZMSetCursorShape(ZMCursorFromId(32512));
        Result := 1;
      end;
    WM_MOUSEACTIVATE: Result := 1;  { MA_ACTIVATE }
    WM_SYSKEYDOWN:
      if WPar = VK_F4 then ZMPostMessage(VensterObj.TopLevel.Handle, WM_CLOSE, 0, 0);
    WM_SYSCOMMAND:
      if (WPar and $FFF0) = SC_CLOSE then ZMPostMessage(Venster, WM_CLOSE, 0, 0);
  end;
end;

{ ---------------------------------------------------------------- timers }

function ZMSetTimer(Venster: HWND; Ident, Verstreken: UINT; Terugroep: Pointer): UINT;
var
  I: Integer;
begin
  ZMInit;
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
      Timers[I].Due := ZMTicks + Verstreken;
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
  Timers[I].Due := ZMTicks + Verstreken;
  Timers[I].Proc := Terugroep;
  Timers[I].Active := True;
  if Ident = 0 then Result := 1 else Result := Ident;
end;

function ZMKillTimer(Venster: HWND; Ident: UINT): Boolean;
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

function ZMAddMMTimer(Vertraging: UINT; Terugroep: Pointer; Gebruiker: PtrUInt; Periodiek: Boolean): UINT;
var
  I: Integer;
begin
  ZMInit;
  if Vertraging < 1 then Vertraging := 1;
  I := 0;
  while (I <= High(Timers)) and Timers[I].Active do Inc(I);
  if I > High(Timers) then SetLength(Timers, I + 1);
  FillChar(Timers[I], SizeOf(TTimerRec), 0);
  Inc(NextTimerID);
  Timers[I].ID := NextTimerID;
  Timers[I].Interval := Vertraging;
  Timers[I].Due := ZMTicks + Vertraging;
  Timers[I].Proc := Terugroep;
  Timers[I].User := Gebruiker;
  Timers[I].Periodic := Periodiek;
  Timers[I].IsMM := True;
  Timers[I].Active := True;
  Result := NextTimerID;
end;

function ZMKillMMTimer(Ident: UINT): Boolean;
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
  TMMProc = procedure(uTimerID, uMessage: UINT; dwUser, dw1, dw2: PtrUInt); stdcall;

var
  InMMTimer: Boolean = False;

function CallMMTimers: Boolean;
var
  I: Integer;
  Nu: LongWord;
  Terugroep: TMMProc;
begin
  Result := False;
  if InMMTimer then Exit;
  InMMTimer := True;
  try
    Nu := ZMTicks;
    for I := 0 to High(Timers) do
      if Timers[I].Active and Timers[I].IsMM and (LongInt(Nu - Timers[I].Due) >= 0) then
      begin
        if Timers[I].Periodic then
          Timers[I].Due := Nu + Timers[I].Interval
        else
          Timers[I].Active := False;
        Terugroep := TMMProc(Timers[I].Proc);
        if Assigned(Terugroep) then Terugroep(Timers[I].ID, 0, Timers[I].User, 0, 0);
        Result := True;
      end;
  finally
    InMMTimer := False;
  end;
end;

{ ---------------------------------------------------------------- focus enz. }

function ZMGetFocus: HWND;
begin
  Result := FocusWnd;
end;

function ZMSetFocus(Venster: HWND): HWND;
var
  Oud: HWND;
  VensterObj: TZMWindow;
begin
  Result := FocusWnd;
  if Venster = FocusWnd then Exit;
  VensterObj := ZMWindowObj(Venster);
  if (Venster <> 0) and (VensterObj = nil) then Exit;
  if (VensterObj <> nil) and (ActiveWnd <> VensterObj.TopLevel.Handle) then
    ZMSetActive(VensterObj.TopLevel.Handle);
  Oud := FocusWnd;
  FocusWnd := Venster;
  if (Oud <> 0) and (ZMWindowObj(Oud) <> nil) then
    ZMSendMessage(Oud, WM_KILLFOCUS, Venster, 0);
  if (FocusWnd = Venster) and (Venster <> 0) then
    ZMSendMessage(Venster, WM_SETFOCUS, Oud, 0);
end;

function ZMGetActive: HWND;
begin
  Result := ActiveWnd;
end;

function ZMSetActive(Venster: HWND): HWND;
var
  Oud: HWND;
  VensterObj, OudObj: TZMWindow;
begin
  Result := ActiveWnd;
  VensterObj := ZMWindowObj(Venster);
  if VensterObj <> nil then VensterObj := VensterObj.TopLevel;
  if VensterObj <> nil then Venster := VensterObj.Handle;
  if Venster = ActiveWnd then Exit;
  Oud := ActiveWnd;
  ActiveWnd := Venster;
  OudObj := ZMWindowObj(Oud);
  if OudObj <> nil then
  begin
    OudObj.NCDirty := True;
    ZMSendMessage(Oud, WM_NCACTIVATE, 0, 0);
    ZMSendMessage(Oud, WM_ACTIVATE, WA_INACTIVE, LPARAM(Venster));
  end;
  if VensterObj <> nil then
  begin
    { breng naar de bovenkant van de z-volgorde }
    ZMSetWindowPos(Venster, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOSENDCHANGING);
    VensterObj.NCDirty := True;
    ZMSendMessage(Venster, WM_NCACTIVATE, 1, 0);
    ZMSendMessage(Venster, WM_ACTIVATE, WA_ACTIVE, LPARAM(Oud));
  end;
end;

function ZMSetCapture(Venster: HWND): HWND;
begin
  Result := CaptureWnd;
  CaptureWnd := Venster;
end;

function ZMGetCapture: HWND;
begin
  Result := CaptureWnd;
end;

procedure ZMReleaseCapture;
var
  Oud: HWND;
begin
  Oud := CaptureWnd;
  CaptureWnd := 0;
  if Oud <> 0 then
  begin
    ZMSendMessage(Oud, WM_CAPTURECHANGED, 0, 0);
    { zoals Windows/Wine: het loslaten van capture levert een muisbeweging op, zodat het
      venster onder de cursor weet waar de aanwijzer staat }
    SyntheticMove := True;
  end;
end;

function ZMEnableWindow(Venster: HWND; Inschakelen: Boolean): Boolean;
var
  VensterObj: TZMWindow;
begin
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit(False);
  Result := VensterObj.Style and WS_DISABLED <> 0;  { vorige toestand: True = was uitgeschakeld }
  if Inschakelen = not Result then Exit;
  if Inschakelen then VensterObj.Style := VensterObj.Style and not WS_DISABLED
  else
  begin
    VensterObj.Style := VensterObj.Style or WS_DISABLED;
    if (FocusWnd = Venster) or IsChild(Venster, FocusWnd) then ZMSetFocus(0);
  end;
  ZMSendMessage(Venster, WM_ENABLE, Ord(Inschakelen), 0);
end;

function ZMKeyState(Toets: Integer): SmallInt;
begin
  if (Toets >= 0) and (Toets <= 255) and KeyDown[Toets] then Result := SmallInt($8000) else Result := 0;
end;

function ZMCursorPos: TPoint;
begin
  Result := MousePos;
end;

procedure ZMSetCursorPos(X, Y: Integer);
begin
  MousePos := Point(X, Y);
end;

function ZMMessagePos: TPoint;
begin
  Result := LastMsgPos;
end;

function ZMMessageTime: LongWord;
begin
  Result := LastMsgTime;
end;

{ cursors zijn kleine gehele getallen: de IDC_xxx-resource-id's }
function ZMCursorFromId(Ident: PtrUInt): HCURSOR;
begin
  Result := HCURSOR(Ident);
end;

procedure ZMSetCursorShape(Aanwijzer: HCURSOR);
var
  Vorm: TZMCursorShape;
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

function MouseKeys: WPARAM;
begin
  Result := 0;
  if KeyDown[VK_LBUTTON] then Result := Result or MK_LBUTTON;
  if KeyDown[VK_RBUTTON] then Result := Result or MK_RBUTTON;
  if KeyDown[VK_MBUTTON] then Result := Result or MK_MBUTTON;
  if KeyDown[VK_SHIFT] then Result := Result or MK_SHIFT;
  if KeyDown[VK_CONTROL] then Result := Result or MK_CONTROL;
end;

procedure PostMouse(Bericht: UINT; Punt: TPoint; ExtraWPar: WPARAM);
var
  Venster: HWND;
  VensterObj: TZMWindow;
  KlientPunt: TPoint;
  Ingedrukt: Boolean;
  Bovenste: TZMWindow;
begin
  Ingedrukt := (Bericht = WM_LBUTTONDOWN) or (Bericht = WM_RBUTTONDOWN) or (Bericht = WM_MBUTTONDOWN);
  if CaptureWnd <> 0 then
    Venster := CaptureWnd
  else
    Venster := ZMWindowFromPoint(Punt, False);
  VensterObj := ZMWindowObj(Venster);
  if VensterObj = nil then Exit;
  if (CaptureWnd = 0) and not VensterObj.IsEnabledTree then
  begin
    if Ingedrukt then
    begin
      ZMBackend.Beep;
      { breng een ingeschakeld (modaal) venster naar voren }
      if (ActiveWnd <> 0) then ZMSetActive(ActiveWnd);
    end;
    Exit;
  end;
  if Ingedrukt then
  begin
    Bovenste := VensterObj.TopLevel;
    if Bovenste.Handle <> ActiveWnd then
      if ZMSendMessage(Venster, WM_MOUSEACTIVATE, Bovenste.Handle, MakeLParam(HTCLIENT, Bericht)) <> 3 then
        ZMSetActive(Bovenste.Handle);
    VensterObj := ZMWindowObj(Venster);
    if VensterObj = nil then Exit;
  end;
  if (CaptureWnd = 0) and not PtInRect(VensterObj.ClientRectScreen, Punt) then Exit;  { niet-clientgebied }
  ZMSendMessage(Venster, WM_SETCURSOR, Venster, MakeLParam(HTCLIENT, Bericht));
  KlientPunt := Punt;
  ZMScreenToClient(Venster, KlientPunt);
  ZMPostMessage(Venster, Bericht, MouseKeys or ExtraWPar, MakeLParam(Word(SmallInt(KlientPunt.X)), Word(SmallInt(KlientPunt.Y))));
end;

procedure HandleEvent(const Gebeurtenis: TZMEvent);
var
  Bericht: UINT;
  Venster: HWND;
  Nu: LongWord;
  VensterObj: TZMWindow;
  Toets: Integer;
  I: Integer;
  LPar: LPARAM;
begin
  case Gebeurtenis.Kind of
    zeQuit:
      if Assigned(ZMOnCloseRequest) then ZMOnCloseRequest
      else if ZMMainWindow <> 0 then ZMPostMessage(ZMMainWindow, WM_CLOSE, 0, 0)
      else ZMPostMessage(0, WM_QUIT, 0, 0);
    zeExpose:
      ZMScreen.Dirty := True;
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
        PostMouse(WM_MOUSEMOVE, MousePos, 0);
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
          Nu := ZMTicks;
          if CaptureWnd <> 0 then Venster := CaptureWnd else Venster := ZMWindowFromPoint(MousePos, False);
          if (Gebeurtenis.Button = LastClickBtn) and (Nu - LastClickTime < GetDoubleClickTime) and
            (Abs(MousePos.X - LastClickPos.X) <= 4) and (Abs(MousePos.Y - LastClickPos.Y) <= 4) and
            (Venster = LastClickWnd) then
          begin
            VensterObj := ZMWindowObj(Venster);
            if (VensterObj <> nil) and (VensterObj.ClsStyle and CS_DBLCLKS <> 0) then
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
        PostMouse(Bericht, MousePos, 0);
      end;
    zeMouseWheel:
      begin
        if FocusWnd <> 0 then Venster := FocusWnd else Venster := ZMWindowFromPoint(MousePos, True);
        if Venster <> 0 then
          ZMPostMessage(Venster, WM_MOUSEWHEEL, (MouseKeys and $FFFF) or (WPARAM(Word(SmallInt(Gebeurtenis.Wheel))) shl 16),
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
        LPar := 1 or (LPARAM(Gebeurtenis.ScanCode and $FF) shl 16);
        if Gebeurtenis.Repeated then LPar := LPar or (1 shl 30);
        if KeyDown[VK_MENU] or (Toets = VK_MENU) or (Toets = VK_F10) then
        begin
          if Gebeurtenis.Kind = zeKeyDown then Bericht := WM_SYSKEYDOWN else Bericht := WM_SYSKEYUP;
          LPar := LPar or (1 shl 29);
        end
        else if Gebeurtenis.Kind = zeKeyDown then Bericht := WM_KEYDOWN
        else Bericht := WM_KEYUP;
        if Gebeurtenis.Kind = zeKeyUp then LPar := LPar or LPARAM(LongWord($C0000000));
        ZMPostMessage(Venster, Bericht, Toets, LPar);
      end;
    zeText:
      begin
        if KeyDown[VK_CONTROL] or KeyDown[VK_MENU] then Exit;
        Venster := FocusWnd;
        if Venster = 0 then Venster := ActiveWnd;
        if Venster = 0 then Exit;
        for I := 1 to Length(Gebeurtenis.Text) do
          ZMPostMessage(Venster, WM_CHAR, Byte(Gebeurtenis.Text[I]), 1);
      end;
    zeActivate: ;
    zeDeactivate:
      FillChar(KeyDown, SizeOf(KeyDown), 0);
  end;
end;

procedure Inject(const Gebeurtenis: TZMEvent);
begin
  SetLength(Injected, Length(Injected) + 1);
  Injected[High(Injected)] := Gebeurtenis;
end;

procedure ZMInjectMouse(X, Y: Integer; Knop: Integer; Omlaag: Boolean);
var
  Gebeurtenis: TZMEvent;
  Punt: TPoint;
begin
  FillChar(Gebeurtenis, SizeOf(Gebeurtenis), 0);
  Punt := Point(X, Y);
  if ZMMainWindow <> 0 then ZMClientToScreen(ZMMainWindow, Punt);
  Gebeurtenis.X := Punt.X;
  Gebeurtenis.Y := Punt.Y;
  if Knop = 0 then
    Gebeurtenis.Kind := zeMouseMove
  else
  begin
    { eerst verplaatsen, zoals een echte muis }
    Gebeurtenis.Kind := zeMouseMove;
    Inject(Gebeurtenis);
    if Omlaag then Gebeurtenis.Kind := zeMouseDown else Gebeurtenis.Kind := zeMouseUp;
    Gebeurtenis.Button := Knop;
  end;
  Inject(Gebeurtenis);
end;

procedure ZMInjectKey(Toets: Word; Omlaag: Boolean);
var
  Gebeurtenis: TZMEvent;
begin
  FillChar(Gebeurtenis, SizeOf(Gebeurtenis), 0);
  if Omlaag then Gebeurtenis.Kind := zeKeyDown else Gebeurtenis.Kind := zeKeyUp;
  Gebeurtenis.Key := Toets;
  Inject(Gebeurtenis);
end;

procedure ZMInjectChar(Karakter: Char);
var
  Gebeurtenis: TZMEvent;
begin
  FillChar(Gebeurtenis, SizeOf(Gebeurtenis), 0);
  Gebeurtenis.Kind := zeText;
  Gebeurtenis.Text := Karakter;
  Inject(Gebeurtenis);
end;

procedure ZMPollInput;
var
  Gebeurtenis: TZMEvent;
  I: Integer;
  Gebeurtenissen: array of TZMEvent;
begin
  EnsureBackend;
  if Assigned(ZMIdleHook) and not InIdleHook then
  begin
    InIdleHook := True;
    try
      ZMIdleHook;
    finally
      InIdleHook := False;
    end;
  end;
  if Length(Injected) > 0 then
  begin
    Gebeurtenissen := Injected;
    Injected := nil;
    for I := 0 to High(Gebeurtenissen) do HandleEvent(Gebeurtenissen[I]);
  end;
  while ZMBackend.PollEvent(Gebeurtenis) do
    HandleEvent(Gebeurtenis);
end;

procedure ZMPresent(Forceer: Boolean);
var
  Nu: LongWord;
begin
  if (ZMScreen = nil) or not ZMScreen.Dirty then Exit;
  Nu := ZMTicks;
  if not Forceer and (Nu - LastPresent < 15) then Exit;
  EnsureBackend;
  LastPresent := Nu;
  ZMScreen.Dirty := False;
  ZMBackend.Present(ZMScreen.Bits, ZMScreen.Width, ZMScreen.Height, ZMScreen.Stride);
end;

function ZMSaveScreenshot(const Bestandsnaam: string): Boolean;
begin
  ZMInit;
  Result := ZMSavePNG(Bestandsnaam, ZMScreen.Bits, ZMScreen.Width, ZMScreen.Height, ZMScreen.Stride);
end;

initialization
  ZMSetDisplayModeHook := DDSetMode;
  ZMRestoreDisplayModeHook := DDRestoreMode;
end.

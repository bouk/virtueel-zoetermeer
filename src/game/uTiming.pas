unit uTiming;

{ Hoge-resolutie "snelle" timers voor de spriteengine.

  Elke TCustomFastTimer heeft een eigen verborgen venster (AllocateHWnd) en tikt
  normaal via WM_TIMER. Zolang SnelleTimerLus loopt, worden de timers in plaats
  daarvan aangestuurd vanuit een actieve lus die ook berichten verwerkt, wacht op
  de verticale retrace en alle spriteboxen laat wisselen (flip). Multimediatimers
  (winmm) waren gepland: de unit houdt er een bibliotheekhandle en procedure-
  variabelen voor bij, maar ze worden in deze build nooit geladen (FGebruikMMTimer
  wordt nooit gezet).

  Gedecompileerd uit ROS.exe v1.1, code 0046F530-0046FF58. }

{$I zm.inc}

interface

uses
  Windows, Messages, Classes;

type
  { Resultaat van TCustomFastTimer.LeesTimerModus. }
  TTimerModus = (tmWindowsTimer, tmMultimediaTimer, tmTimerLoop);

  TCustomFastTimer = class(TComponent)
  private
    FVersie: string;                 { +0x24 }
    FEnabled: Boolean;              { +0x28 }
    FInterval: Integer;             { +0x2C }
    FGereserveerd30: Integer;           { +0x30  wordt nooit gebruikt }
    FWindowHandle: HWND;            { +0x34  from AllocateHWnd }
    FTimerVenster: HWND;                { +0x38  venster dat wordt gebruikt voor SetTimer/DefWindowProc }
    FGereserveerd3C: Integer;           { +0x3C  wordt nooit gebruikt }
    FOnTimer: TNotifyEvent;         { +0x40 }
    FBijOverslaan: TNotifyEvent;     { +0x48 }
    FGebruikMMTimer: Boolean;           { +0x50  wordt nooit gezet }
    FMMTimerNr: Integer;            { +0x54 }
    FVolgNr: Integer;                   { +0x58 }
    FVolgendeTijd: Integer;             { +0x5C  tijdstip (ms) waarop de volgende tik verschuldigd is }
    FLaatsteTijd: Integer;             { +0x60 }
    FVorigeTijd: Integer;             { +0x64 }
    FPrioriteit: Integer;             { +0x68 }
    FSynchroonRetrace: Boolean;          { +0x6C  rondt het interval af op retrace-perioden }
    FBijgewerkt: Boolean;              { +0x6D }
    procedure WndProc(var Msg: TMessage);
    procedure UpdateTimer;
    function LeesWerkelijkInterval: Integer;
    procedure DoeTimer(Gebeurtenis: TNotifyEvent);
  protected
    function LeesVersie: string;
    procedure SetEnabled(Value: Boolean);
    procedure SetInterval(Value: Integer);
    procedure SetOnTimer(Value: TNotifyEvent);
    procedure Timer; dynamic;
    procedure OverslaanTimer; virtual;
    function LeesTimerModus: TTimerModus;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Interval: Integer read FInterval write SetInterval;
    property Priority: Integer read FPrioriteit write FPrioriteit;
    property SynchroonRetrace: Boolean read FSynchroonRetrace write FSynchroonRetrace;
    property VolgendeTijd: Integer read FVolgendeTijd;
    property LaatsteTijd: Integer read FLaatsteTijd;
    property VorigeTijd: Integer read FVorigeTijd;
    property ID: Integer read FVolgNr;
  end;

  TFastTimer = class(TCustomFastTimer)
  published
    property About: string read LeesVersie write FVersie;
    property Enabled default False;
    property Interval;
    property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;
    property OnSkipTimer: TNotifyEvent read FBijOverslaan write FBijOverslaan;
    property Priority default 5;
  end;

  TFastTimerList = class(TList)
  public
    function Add(Timer: TCustomFastTimer): TCustomFastTimer;
    function LeesTimer(Index: Integer): TCustomFastTimer;
    function VolgendeTimer: TCustomFastTimer;
    property Klokken[Index: Integer]: TCustomFastTimer read LeesTimer; default;
  end;

  TMMStopProc = procedure(ID: Word);

{$J+}
const
  GeenMMTimers: Boolean = False;              { 00488E7C }
  MaxLusTijd: Integer = 500;               { 00488E80  ms per doorgang van de timerlus }
  InactieveLusTijd: Integer = 0;                { 00488E84 }
  InTimerLus: Boolean = False;             { 00488E88 }
  MaxBerichtLussen: Integer = 1;             { 00488E8C }
  TimerAantal: Integer = 9123;               { 00488E90 }
  TijdSchaal: Double = 1.0;                  { 00488E94 }
{$J-}

var
  SnelleTimers: TFastTimerList;               { 0048A948 }
  RetraceTijd: Integer;                     { 0048A94C }
  IsWinNT: Boolean;                         { 0048A950 }
  MMZetGebeurtenisProc: Pointer;                  { 0048A958  wordt nooit toegekend }
  MMLeesApparaatProc: Pointer;                { 0048A95C  wordt nooit toegekend }
  MMStopGebeurtenisProc: TMMStopProc;             { 0048A960  wordt nooit toegekend }
  MMTimerGebruikers: Integer;                    { 0048A964 }
  WinMMGeladen: Boolean;                     { 0048A968 }
  WinMMHandvat: THandle;                     { 0048A96C }
  StartTijd: Integer;                       { 0048A970 }

procedure BevrijdWinMM;
procedure GeefMMTimerVrij;
function LeesTijd: Integer;
procedure ZetMaxBerichtLussen(Value: Integer);
procedure SnelleTimerLus(OnIdle: TNotifyEvent);
procedure WachtOpRetrace;
function LeesRetraceTijd: Integer;
procedure MeetRetrace;
procedure ControleerWinNT;

implementation

uses
  SysUtils, Forms, MMSystem, uTool, uLog, uSpritebox;

{ @0046F7F4 }
procedure BevrijdWinMM;
begin
  if WinMMHandvat >= HINSTANCE_ERROR then
    FreeLibrary(WinMMHandvat);
  WinMMHandvat := 0;
end;

{ @0046F810 }
procedure GeefMMTimerVrij;
begin
  if MMTimerGebruikers > 0 then
    Dec(MMTimerGebruikers);
  if (MMTimerGebruikers = 0) and WinMMGeladen then
    BevrijdWinMM;
end;

{ @0046F838  milliseconden sinds de initialisatie van de unit, geschaald door TijdSchaal }
function LeesTijd: Integer;
begin
  Result := Round((timeGetTime - StartTijd) / TijdSchaal);
end;

{ @0046F86C }
procedure ZetMaxBerichtLussen(Value: Integer);
begin
  MaxBerichtLussen := Value;
end;

{ @0046F874 }
constructor TCustomFastTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FVersie := '1.0';
  FEnabled := False;
  FInterval := 110;
  FWindowHandle := AllocateHWnd(WndProc);
  FTimerVenster := FWindowHandle;
  FGebruikMMTimer := False;
  FMMTimerNr := 0;
  SnelleTimers.Add(Self);
  Inc(TimerAantal);
  FVolgNr := TimerAantal;
  FVorigeTijd := LeesTijd;
  FLaatsteTijd := LeesTijd;
  FPrioriteit := 5;
  FSynchroonRetrace := False;
end;

{ @0046F928 }
destructor TCustomFastTimer.Destroy;
begin
  SetEnabled(False);
  FEnabled := False;
  UpdateTimer;
  if LeesTimerModus = tmMultimediaTimer then
    GeefMMTimerVrij;
  DeallocateHWnd(FWindowHandle);
  SnelleTimers.Remove(Self);
  inherited Destroy;
end;

{ @0046F988 }
procedure TCustomFastTimer.WndProc(var Msg: TMessage);
begin
  case Msg.Msg of
    WM_TIMER, WM_USER + 1:
      try
        if FEnabled then
          Timer;
      except
        Application.HandleException(Self);
      end;
  else
    Msg.Result := DefWindowProc(FTimerVenster, Msg.Msg, Msg.WParam, Msg.LParam);
  end;
end;

{ @0046FA0C }
procedure TCustomFastTimer.UpdateTimer;
begin
  FBijgewerkt := True;
  if FEnabled then
  begin
    FVolgendeTijd := LeesWerkelijkInterval + LeesTijd;
    FVorigeTijd := LeesTijd;
    FLaatsteTijd := LeesTijd;
  end;
  if LeesTimerModus = tmWindowsTimer then
  begin
    KillTimer(FTimerVenster, 1);
    if (FInterval <> 0) and FEnabled then
      if SetTimer(FTimerVenster, 1, Round(FInterval), nil) = 0 then
        raise EOutOfResources.Create('Not enough timers available.');
  end;
end;

{ @0046FAC4 }
function TCustomFastTimer.LeesVersie: string;
begin
  Result := '1.0';
end;

{ @0046FAE4 }
procedure TCustomFastTimer.SetEnabled(Value: Boolean);
begin
  if Value <> FEnabled then
  begin
    FEnabled := Value;
    UpdateTimer;
  end;
end;

{ @0046FAF4 }
function TCustomFastTimer.LeesWerkelijkInterval: Integer;
var
  Periodes: Integer;
begin
  if FSynchroonRetrace then
  begin
    Periodes := Round(FInterval / LeesRetraceTijd);
    Result := IMaximum(LeesRetraceTijd, Periodes * LeesRetraceTijd);
  end
  else
    Result := FInterval;
end;

{ @0046FB34 }
procedure TCustomFastTimer.SetInterval(Value: Integer);
begin
  if Value <> FInterval then
  begin
    FInterval := Value;
    UpdateTimer;
  end;
end;

{ @0046FB44 }
procedure TCustomFastTimer.SetOnTimer(Value: TNotifyEvent);
begin
  FOnTimer := Value;
  UpdateTimer;
end;

{ @0046FB5C }
procedure TCustomFastTimer.DoeTimer(Gebeurtenis: TNotifyEvent);
begin
  FBijgewerkt := False;
  FVorigeTijd := FLaatsteTijd;
  FLaatsteTijd := LeesTijd;
  if Assigned(Gebeurtenis) then
    Gebeurtenis(Self);
  try
    if not FBijgewerkt then
      Inc(FVolgendeTijd, LeesWerkelijkInterval);
  except
  end;
end;

{ @0046FBC8 }
procedure TCustomFastTimer.Timer;
begin
  DoeTimer(FOnTimer);
end;

{ @0046FBD4 }
procedure TCustomFastTimer.OverslaanTimer;
begin
  DoeTimer(FBijOverslaan);
end;

{ @0046FBE0 }
function TCustomFastTimer.LeesTimerModus: TTimerModus;
begin
  if InTimerLus then
    Result := tmTimerLoop
  else if GeenMMTimers then
    Result := tmWindowsTimer
  else if FGebruikMMTimer then
    Result := tmMultimediaTimer
  else
    Result := tmWindowsTimer;
end;

{ @0046FC08 }
function TFastTimerList.Add(Timer: TCustomFastTimer): TCustomFastTimer;
begin
  inherited Add(Timer);
  Result := Timer;
end;

{ @0046FC18 }
function TFastTimerList.LeesTimer(Index: Integer): TCustomFastTimer;
begin
  Result := TObject(Get(Index)) as TCustomFastTimer;
end;

{ @0046FC38  de ingeschakelde timer die het meest achterloopt, of nil }
function TFastTimerList.VolgendeTimer: TCustomFastTimer;
var
  I: Integer;
  Verval: Integer;
begin
  Verval := LeesTijd;
  Result := nil;
  for I := 0 to Count - 1 do
    if (LeesTimer(I).FVolgendeTijd < Verval) and LeesTimer(I).FEnabled then
    begin
      Result := LeesTimer(I);
      Verval := LeesTimer(I).FVolgendeTijd;
    end;
end;

{ @0046FCA4  voert alle snelle timers uit tot de applicatie wordt afgesloten. }
procedure SnelleTimerLus(OnIdle: TNotifyEvent);
var
  I, Lussen: Integer;
  T: TCustomFastTimer;
  Begintijd, Verstreken: Integer;
  Stoppen: Boolean;
begin
  { LET OP: OnIdle wordt nooit gebruikt }
  if not InTimerLus then
  begin
    for I := 0 to SnelleTimers.Count - 1 do
    begin
      T := SnelleTimers.LeesTimer(I);
      if T.LeesTimerModus = tmMultimediaTimer then
      begin
        if T.FMMTimerNr > 0 then
          MMStopGebeurtenisProc(T.FMMTimerNr);
      end
      else
        KillTimer(T.FTimerVenster, 1);
    end;
    InTimerLus := True;
    repeat
      Begintijd := LeesTijd;
      Lussen := 1;
      Stoppen := False;
      repeat
        Stoppen := Stoppen or ProcessMessage;
        Inc(Lussen);
      until (Lussen > MaxBerichtLussen) or Stoppen;
      repeat
        if not Stoppen then
        begin
          T := SnelleTimers.VolgendeTimer;
          if T <> nil then
            if LeesTijd - T.FVolgendeTijd > T.FPrioriteit * 80 then
              T.OverslaanTimer
            else
              T.Timer;
        end;
        Verstreken := LeesTijd - Begintijd;
      until Stoppen or (Verstreken > MaxLusTijd) or ((T = nil) and (Verstreken > InactieveLusTijd));
      if not IsWinNT then
        repeat
        until (LeesPoort($3DA) and 8) <> 0;
      SpriteBoxen.AlleWisselen;
    until Stoppen;
    for I := 0 to SnelleTimers.Count - 1 do
      SnelleTimers.LeesTimer(I).UpdateTimer;
    InTimerLus := False;
  end;
end;

{ @0046FE10  wacht op het begin van de volgende verticale retrace (VGA-statuspoort) }
procedure WachtOpRetrace;
begin
  repeat
  until (LeesPoort($3DA) and 8) = 0;
  repeat
  until (LeesPoort($3DA) and 8) <> 0;
end;

{ @0046FE2C }
function LeesRetraceTijd: Integer;
begin
  if RetraceTijd = 0 then
    MeetRetrace;
  Result := RetraceTijd;
end;

{ @0046FE40 }
procedure MeetRetrace;
var
  Begintijd, I: Integer;
begin
  if IsWinNT then
    RetraceTijd := 1
  else
  begin
    WachtOpRetrace;
    Begintijd := LeesTijd;
    for I := 1 to 10 do
      WachtOpRetrace;
    RetraceTijd := (LeesTijd - Begintijd) div 10;
  end;
end;

{ @0046FE8C }
procedure ControleerWinNT;
var
  Versie: TOSVersionInfo;
begin
  Versie.dwOSVersionInfoSize := SizeOf(Versie);
  GetVersionEx(Versie);
  IsWinNT := Versie.dwPlatformId = VER_PLATFORM_WIN32_NT;
  if IsWinNT then
    ZetMaxBerichtLussen(1000);
end;

initialization
  { @0046FEF8 }
  ControleerWinNT;
  MeetRetrace;
  MMTimerGebruikers := 0;
  RetraceTijd := 0;
  WinMMGeladen := False;
  WinMMHandvat := 0;
  SnelleTimers := TFastTimerList.Create;
  MMZetGebeurtenisProc := nil;
  MMLeesApparaatProc := nil;
  MMStopGebeurtenisProc := nil;
  StartTijd := timeGetTime;

{ De finalization bij @0046FEC8 is de lege, door de compiler gegenereerde stub. }

end.

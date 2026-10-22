unit uTiming;

{ High resolution "fast" timers for the sprite engine.

  Every TCustomFastTimer owns a hidden window (AllocateHWnd) and normally
  ticks through WM_TIMER. While FastTimerLoop runs, the timers are instead
  driven from a busy loop that also pumps messages, waits for the vertical
  retrace and flips all sprite boxes. Multimedia timers (winmm) were planned:
  the unit keeps a library handle and procedure variables for them, but they
  are never loaded in this build (FUseMMTimer is never set).

  Decompiled from ROS.exe v1.1, code 0046F530-0046FF58. }

{$I zm.inc}

interface

uses
  Windows, Messages, Classes;

type
  { Result of TCustomFastTimer.GetTimerMode. }
  TTimerMode = (tmWindowsTimer, tmMultimediaTimer, tmTimerLoop);

  TCustomFastTimer = class(TComponent)
  private
    FAbout: string;                 { +0x24 }
    FEnabled: Boolean;              { +0x28 }
    FInterval: Integer;             { +0x2C }
    FReserved30: Integer;           { +0x30  never referenced }
    FWindowHandle: HWND;            { +0x34  from AllocateHWnd }
    FTimerWnd: HWND;                { +0x38  window used for SetTimer/DefWindowProc }
    FReserved3C: Integer;           { +0x3C  never referenced }
    FOnTimer: TNotifyEvent;         { +0x40 }
    FOnSkipTimer: TNotifyEvent;     { +0x48 }
    FUseMMTimer: Boolean;           { +0x50  never set }
    FMMTimerID: Integer;            { +0x54 }
    FID: Integer;                   { +0x58 }
    FNextTime: Integer;             { +0x5C  time (ms) the next tick is due }
    FLastTime: Integer;             { +0x60 }
    FPrevTime: Integer;             { +0x64 }
    FPriority: Integer;             { +0x68 }
    FSyncRetrace: Boolean;          { +0x6C  round the interval to retrace periods }
    FUpdated: Boolean;              { +0x6D }
    procedure WndProc(var Msg: TMessage);
    procedure UpdateTimer;
    function GetRealInterval: Integer;
    procedure DoTimer(Event: TNotifyEvent);
  protected
    function GetAbout: string;
    procedure SetEnabled(Value: Boolean);
    procedure SetInterval(Value: Integer);
    procedure SetOnTimer(Value: TNotifyEvent);
    procedure Timer; dynamic;
    procedure SkipTimer; virtual;
    function GetTimerMode: TTimerMode;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Interval: Integer read FInterval write SetInterval;
    property Priority: Integer read FPriority write FPriority;
    property SyncRetrace: Boolean read FSyncRetrace write FSyncRetrace;
    property NextTime: Integer read FNextTime;
    property LastTime: Integer read FLastTime;
    property PrevTime: Integer read FPrevTime;
    property ID: Integer read FID;
  end;

  TFastTimer = class(TCustomFastTimer)
  published
    property About: string read GetAbout write FAbout;
    property Enabled default False;
    property Interval;
    property OnTimer: TNotifyEvent read FOnTimer write SetOnTimer;
    property OnSkipTimer: TNotifyEvent read FOnSkipTimer write FOnSkipTimer;
    property Priority default 5;
  end;

  TFastTimerList = class(TList)
  public
    function Add(Timer: TCustomFastTimer): TCustomFastTimer;
    function GetTimer(Index: Integer): TCustomFastTimer;
    function NextDue: TCustomFastTimer;
    property Timers[Index: Integer]: TCustomFastTimer read GetTimer; default;
  end;

  TMMKillProc = procedure(ID: Word);

{$J+}
const
  NoMMTimers: Boolean = False;              { 00488E7C }
  MaxLoopTime: Integer = 500;               { 00488E80  ms per pass of the timer loop }
  IdleLoopTime: Integer = 0;                { 00488E84 }
  InTimerLoop: Boolean = False;             { 00488E88 }
  MaxMessageLoops: Integer = 1;             { 00488E8C }
  TimerCount: Integer = 9123;               { 00488E90 }
  TimeScale: Double = 1.0;                  { 00488E94 }
{$J-}

var
  FastTimers: TFastTimerList;               { 0048A948 }
  RetraceTime: Integer;                     { 0048A94C }
  IsWinNT: Boolean;                         { 0048A950 }
  MMSetEventProc: Pointer;                  { 0048A958  never assigned }
  MMGetDevCapsProc: Pointer;                { 0048A95C  never assigned }
  MMKillEventProc: TMMKillProc;             { 0048A960  never assigned }
  MMTimerUsers: Integer;                    { 0048A964 }
  WinMMLoaded: Boolean;                     { 0048A968 }
  WinMMHandle: THandle;                     { 0048A96C }
  StartTime: Integer;                       { 0048A970 }

procedure FreeWinMM;
procedure ReleaseMMTimer;
function GetTime: Integer;
procedure SetMaxMessageLoops(Value: Integer);
procedure FastTimerLoop(OnIdle: TNotifyEvent);
procedure WaitRetrace;
function GetRetraceTime: Integer;
procedure MeasureRetrace;
procedure CheckWinNT;

implementation

uses
  SysUtils, Forms, MMSystem, uTool, uLog, uSpritebox;

{ @0046F7F4 }
procedure FreeWinMM;
begin
  if WinMMHandle >= HINSTANCE_ERROR then
    FreeLibrary(WinMMHandle);
  WinMMHandle := 0;
end;

{ @0046F810 }
procedure ReleaseMMTimer;
begin
  if MMTimerUsers > 0 then
    Dec(MMTimerUsers);
  if (MMTimerUsers = 0) and WinMMLoaded then
    FreeWinMM;
end;

{ @0046F838  milliseconds since unit initialization, scaled by TimeScale }
function GetTime: Integer;
begin
  Result := Round((timeGetTime - StartTime) / TimeScale);
end;

{ @0046F86C }
procedure SetMaxMessageLoops(Value: Integer);
begin
  MaxMessageLoops := Value;
end;

{ @0046F874 }
constructor TCustomFastTimer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAbout := '1.0';
  FEnabled := False;
  FInterval := 110;
  FWindowHandle := AllocateHWnd(WndProc);
  FTimerWnd := FWindowHandle;
  FUseMMTimer := False;
  FMMTimerID := 0;
  FastTimers.Add(Self);
  Inc(TimerCount);
  FID := TimerCount;
  FPrevTime := GetTime;
  FLastTime := GetTime;
  FPriority := 5;
  FSyncRetrace := False;
end;

{ @0046F928 }
destructor TCustomFastTimer.Destroy;
begin
  SetEnabled(False);
  FEnabled := False;
  UpdateTimer;
  if GetTimerMode = tmMultimediaTimer then
    ReleaseMMTimer;
  DeallocateHWnd(FWindowHandle);
  FastTimers.Remove(Self);
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
    Msg.Result := DefWindowProc(FTimerWnd, Msg.Msg, Msg.WParam, Msg.LParam);
  end;
end;

{ @0046FA0C }
procedure TCustomFastTimer.UpdateTimer;
begin
  FUpdated := True;
  if FEnabled then
  begin
    FNextTime := GetRealInterval + GetTime;
    FPrevTime := GetTime;
    FLastTime := GetTime;
  end;
  if GetTimerMode = tmWindowsTimer then
  begin
    KillTimer(FTimerWnd, 1);
    if (FInterval <> 0) and FEnabled then
      if SetTimer(FTimerWnd, 1, Round(FInterval), nil) = 0 then
        raise EOutOfResources.Create('Not enough timers available.');
  end;
end;

{ @0046FAC4 }
function TCustomFastTimer.GetAbout: string;
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
function TCustomFastTimer.GetRealInterval: Integer;
var
  Periods: Integer;
begin
  if FSyncRetrace then
  begin
    Periods := Round(FInterval / GetRetraceTime);
    Result := IMax(GetRetraceTime, Periods * GetRetraceTime);
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
procedure TCustomFastTimer.DoTimer(Event: TNotifyEvent);
begin
  FUpdated := False;
  FPrevTime := FLastTime;
  FLastTime := GetTime;
  if Assigned(Event) then
    Event(Self);
  try
    if not FUpdated then
      Inc(FNextTime, GetRealInterval);
  except
  end;
end;

{ @0046FBC8 }
procedure TCustomFastTimer.Timer;
begin
  DoTimer(FOnTimer);
end;

{ @0046FBD4 }
procedure TCustomFastTimer.SkipTimer;
begin
  DoTimer(FOnSkipTimer);
end;

{ @0046FBE0 }
function TCustomFastTimer.GetTimerMode: TTimerMode;
begin
  if InTimerLoop then
    Result := tmTimerLoop
  else if NoMMTimers then
    Result := tmWindowsTimer
  else if FUseMMTimer then
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
function TFastTimerList.GetTimer(Index: Integer): TCustomFastTimer;
begin
  Result := TObject(Get(Index)) as TCustomFastTimer;
end;

{ @0046FC38  the enabled timer that is most overdue, or nil }
function TFastTimerList.NextDue: TCustomFastTimer;
var
  I: Integer;
  Due: Integer;
begin
  Due := GetTime;
  Result := nil;
  for I := 0 to Count - 1 do
    if (GetTimer(I).FNextTime < Due) and GetTimer(I).FEnabled then
    begin
      Result := GetTimer(I);
      Due := GetTimer(I).FNextTime;
    end;
end;

{ @0046FCA4  runs all fast timers until the application quits. }
procedure FastTimerLoop(OnIdle: TNotifyEvent);
var
  I, Loops: Integer;
  T: TCustomFastTimer;
  Start, Elapsed: Integer;
  Quit: Boolean;
begin
  { NOTE: OnIdle is never used }
  if not InTimerLoop then
  begin
    for I := 0 to FastTimers.Count - 1 do
    begin
      T := FastTimers.GetTimer(I);
      if T.GetTimerMode = tmMultimediaTimer then
      begin
        if T.FMMTimerID > 0 then
          MMKillEventProc(T.FMMTimerID);
      end
      else
        KillTimer(T.FTimerWnd, 1);
    end;
    InTimerLoop := True;
    repeat
      Start := GetTime;
      Loops := 1;
      Quit := False;
      repeat
        Quit := Quit or ProcessMessage;
        Inc(Loops);
      until (Loops > MaxMessageLoops) or Quit;
      repeat
        if not Quit then
        begin
          T := FastTimers.NextDue;
          if T <> nil then
            if GetTime - T.FNextTime > T.FPriority * 80 then
              T.SkipTimer
            else
              T.Timer;
        end;
        Elapsed := GetTime - Start;
      until Quit or (Elapsed > MaxLoopTime) or ((T = nil) and (Elapsed > IdleLoopTime));
      if not IsWinNT then
        repeat
        until (InPort($3DA) and 8) <> 0;
      SpriteBoxes.FlipAll;
    until Quit;
    for I := 0 to FastTimers.Count - 1 do
      FastTimers.GetTimer(I).UpdateTimer;
    InTimerLoop := False;
  end;
end;

{ @0046FE10  waits for the start of the next vertical retrace (VGA status port) }
procedure WaitRetrace;
begin
  repeat
  until (InPort($3DA) and 8) = 0;
  repeat
  until (InPort($3DA) and 8) <> 0;
end;

{ @0046FE2C }
function GetRetraceTime: Integer;
begin
  if RetraceTime = 0 then
    MeasureRetrace;
  Result := RetraceTime;
end;

{ @0046FE40 }
procedure MeasureRetrace;
var
  Start, I: Integer;
begin
  if IsWinNT then
    RetraceTime := 1
  else
  begin
    WaitRetrace;
    Start := GetTime;
    for I := 1 to 10 do
      WaitRetrace;
    RetraceTime := (GetTime - Start) div 10;
  end;
end;

{ @0046FE8C }
procedure CheckWinNT;
var
  Info: TOSVersionInfo;
begin
  Info.dwOSVersionInfoSize := SizeOf(Info);
  GetVersionEx(Info);
  IsWinNT := Info.dwPlatformId = VER_PLATFORM_WIN32_NT;
  if IsWinNT then
    SetMaxMessageLoops(1000);
end;

initialization
  { @0046FEF8 }
  CheckWinNT;
  MeasureRetrace;
  MMTimerUsers := 0;
  RetraceTime := 0;
  WinMMLoaded := False;
  WinMMHandle := 0;
  FastTimers := TFastTimerList.Create;
  MMSetEventProc := nil;
  MMGetDevCapsProc := nil;
  MMKillEventProc := nil;
  StartTime := timeGetTime;

{ The finalization at @0046FEC8 is the empty compiler-generated stub. }

end.

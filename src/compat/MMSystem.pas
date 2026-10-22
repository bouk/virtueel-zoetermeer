unit MMSystem;

{ Draagbare subset van de Delphi 5-unit MMSystem: multimedia-timer en geluid-API.
  De timing komt van de platformbackend; timeSetEvent-callbacks worden afgeleverd
  vanuit de berichtenlus van de compat-laag (er zijn geen threads). Geluidsweergave
  doet niets (ROS.exe speelt geen geluiden af). }

{$MODE DELPHI}{$H+}

interface

uses Windows;

type
  MMRESULT = UINT;
  DWORD_PTR = PtrUInt;
  TFNTimeCallBack = procedure(uTimerID, uMessage: UINT; dwUser, dw1, dw2: DWORD_PTR); stdcall;

  TTimeCaps = record
    wPeriodMin: UINT;
    wPeriodMax: UINT;
  end;
  PTimeCaps = ^TTimeCaps;

const
  TIMERR_NOERROR = 0;
  TIMERR_NOCANDO = 97;
  TIMERR_STRUCT = 129;
  TIME_ONESHOT = 0;
  TIME_PERIODIC = 1;
  TIME_CALLBACK_FUNCTION = 0;
  TIME_CALLBACK_EVENT_SET = $10;
  TIME_CALLBACK_EVENT_PULSE = $20;
  MMSYSERR_NOERROR = 0;
  MMSYSERR_ERROR = 1;

  SND_SYNC = 0;
  SND_ASYNC = 1;
  SND_NODEFAULT = 2;
  SND_MEMORY = 4;
  SND_LOOP = 8;
  SND_NOSTOP = $10;
  SND_PURGE = $40;
  SND_ALIAS = $10000;
  SND_FILENAME = $20000;
  SND_RESOURCE = $40004;

function timeGetTime: DWORD; stdcall;
function timeBeginPeriod(uPeriod: UINT): MMRESULT; stdcall;
function timeEndPeriod(uPeriod: UINT): MMRESULT; stdcall;
function timeGetDevCaps(lpTimeCaps: PTimeCaps; uSize: UINT): MMRESULT; stdcall;
function timeSetEvent(uDelay, uResolution: UINT; lpFunction: TFNTimeCallBack;
  dwUser: DWORD_PTR; uFlags: UINT): MMRESULT; stdcall;
function timeKillEvent(uID: UINT): MMRESULT; stdcall;
function PlaySound(pszSound: PAnsiChar; hmod: HMODULE; fdwSound: DWORD): BOOL; stdcall;
function sndPlaySound(lpszSoundName: PAnsiChar; uFlags: UINT): BOOL; stdcall;

implementation

uses ZMWin;

function timeGetTime: DWORD; stdcall;
begin
  Result := ZMTicks;
end;

function timeBeginPeriod(uPeriod: UINT): MMRESULT; stdcall;
begin
  Result := TIMERR_NOERROR;
end;

function timeEndPeriod(uPeriod: UINT): MMRESULT; stdcall;
begin
  Result := TIMERR_NOERROR;
end;

function timeGetDevCaps(lpTimeCaps: PTimeCaps; uSize: UINT): MMRESULT; stdcall;
begin
  if lpTimeCaps = nil then Exit(TIMERR_STRUCT);
  lpTimeCaps^.wPeriodMin := 1;
  lpTimeCaps^.wPeriodMax := 1000000;
  Result := TIMERR_NOERROR;
end;

function timeSetEvent(uDelay, uResolution: UINT; lpFunction: TFNTimeCallBack;
  dwUser: DWORD_PTR; uFlags: UINT): MMRESULT; stdcall;
begin
  Result := ZMAddMMTimer(uDelay, @lpFunction, dwUser, uFlags and TIME_PERIODIC <> 0);
end;

function timeKillEvent(uID: UINT): MMRESULT; stdcall;
begin
  if ZMKillMMTimer(uID) then Result := TIMERR_NOERROR else Result := MMSYSERR_ERROR;
end;

function PlaySound(pszSound: PAnsiChar; hmod: HMODULE; fdwSound: DWORD): BOOL; stdcall;
begin
  Result := True;
end;

function sndPlaySound(lpszSoundName: PAnsiChar; uFlags: UINT): BOOL; stdcall;
begin
  Result := True;
end;

end.

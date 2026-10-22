program RosWeb;

{ Virtueel Zoetermeer, WebAssembly build: src/game/Ros.dpr plus the browser platform
  backend (ZMWasmBackend registers itself). Keep the uses list in step with Ros.dpr. }

{$I zm.inc}

uses
  ZMAsyncStack,  { als eerste: buffer voor Asyncify (src/web/ZMAsyncStack.pas) }
  IniFiles in '../compat/IniFiles.pas',  { de compat-versie (Delphi 5-semantiek), niet die van de RTL }
  Forms,
  Uctrl,
  uTool,
  uString,
  uTiming,
  uSpritebox,
  uLog,
  Sprframe,
  uSurface,
  SprBmp,
  fShow {formDebugShow},
  uGoblin,
  uTextBalloon,
  uPixie,
  uSprite,
  cEditCtr,
  uSequence,
  uResizeScreen,
  Sprbehav,
  uTransition,
  uQuickDirectX,
  Unit49,
  Unit78,
  uTrein,
  Uconst,
  fBack {frmBlack},
  Fmain {frmMain},
  fReport {frmReport},
  Uworld,
  Uview,
  Usett,
  uAutos,
  ZMWasmBackend;  { browser platform backend (registers itself) }

begin
  Application.Title := 'Virtueel Zoetermeer';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

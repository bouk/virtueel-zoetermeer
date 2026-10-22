program RosTest;

{ The game (src/game/Ros.dpr) plus the differential-test harness (ZMHarness), which runs
  ZM_TESTSCRIPT and writes state dumps to ZM_TESTOUT. Keep the uses list in step with
  Ros.dpr. }

{$I zm.inc}

uses
  Forms,
  Uctrl, uTool, uString, uTiming, uSpritebox, uLog, Sprframe, uSurface, SprBmp, fShow,
  uGoblin, uTextBalloon, uPixie, uSprite, cEditCtr, uSequence, uResizeScreen, Sprbehav,
  uTransition, uQuickDirectX, Unit49, Unit78, uTrein, Uconst, fBack, Fmain, fReport,
  Uworld, Uview, Usett, uAutos,
  ZMHarness;

begin
  Application.Title := 'Virtueel Zoetermeer';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

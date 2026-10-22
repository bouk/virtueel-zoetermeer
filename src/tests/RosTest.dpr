program RosTest;

{ Het spel (src/game/Ros.dpr) plus het differentiële-testharnas (ZMHarness), dat
  ZM_TESTSCRIPT uitvoert en statusdumps naar ZM_TESTOUT schrijft. Houd de uses-lijst
  gelijk aan die van Ros.dpr. }

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

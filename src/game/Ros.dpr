program Ros;

{ Virtueel Zoetermeer.
  Decompiled from ROS.exe v1.1, code 00486F64-004872CB (entry point 00487264).
  The units are listed in the order of the PACKAGEINFO unit list
  (symbols/units-1.1.json 'package_units'); Unit49 and Unit78 are the two
  code-less units whose real names are unknown. The original does not call
  Application.Initialize. }

{$I zm.inc}

uses
  Forms,
  Uctrl in 'Uctrl.pas',
  uTool in 'uTool.pas',
  uString in 'uString.pas',
  uTiming in 'uTiming.pas',
  uSpritebox in 'uSpritebox.pas',
  uLog in 'uLog.pas',
  Sprframe in 'Sprframe.pas',
  uSurface in 'uSurface.pas',
  SprBmp in 'SprBmp.pas',
  fShow in 'fShow.pas' {formDebugShow},
  uGoblin in 'uGoblin.pas',
  uTextBalloon in 'uTextBalloon.pas',
  uPixie in 'uPixie.pas',
  uSprite in 'uSprite.pas',
  cEditCtr in 'cEditCtr.pas',
  uSequence in 'uSequence.pas',
  uResizeScreen in 'uResizeScreen.pas',
  Sprbehav in 'Sprbehav.pas',
  uTransition in 'uTransition.pas',
  uQuickDirectX in 'uQuickDirectX.pas',
  Unit49 in 'Unit49.pas',
  Unit78 in 'Unit78.pas',
  uTrein in 'uTrein.pas',
  Uconst in 'Uconst.pas',
  fBack in 'fBack.pas' {frmBlack},
  Fmain in 'Fmain.pas' {frmMain},
  fReport in 'fReport.pas' {frmReport},
  Uworld in 'Uworld.pas',
  Uview in 'Uview.pas',
  Usett in 'Usett.pas',
  uAutos in 'uAutos.pas';

{$IFNDEF FPC}
{$R *.res}  { Delphi only: icon and version resources of the original project }
{$ENDIF}

{ @00487264 }
begin
  Application.Title := 'Virtueel Zoetermeer';
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

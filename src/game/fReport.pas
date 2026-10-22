unit fReport;

{ TfrmReport: the yearly report ("Rapportage"). One tab per district plus the
  totals; TWorld.Rapport fills Lists[] (line 0 of every list is the tab caption,
  the remaining lines are shown in the memo). Every tab has its own memo colour.
  Decompiled from ROS.exe v1.1, code 0047FD68-00480257. }

{$I zm.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls;

type
  { VMT 0047FDB4, instance size $308 }
  TfrmReport = class(TForm)
    butOK: TButton;                    { +0x2D0 }
    tcTabs: TTabControl;               { +0x2D4 }
    memoTab: TMemo;                    { +0x2D8 }
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure butOKClick(Sender: TObject);
    procedure tcTabsChange(Sender: TObject);
    procedure tcTabsDrawTab(Control: TCustomTabControl; TabIndex: Integer;
      const Rect: TRect; Active: Boolean);
  private
    procedure ShowTab(Index: Integer);
  public
    Lists: array[0..10] of TStrings;   { +0x2DC  filled by TWorld.Rapport }
    function Execute(TabCount: Integer): Integer;
  end;

var
  frmReport: TfrmReport;   { not referenced: removed by the linker }

implementation

uses
  Fmain;

{$IFNDEF FPC}
{$R *.dfm}  { Delphi only: the portable build streams forms from the user's ROS.exe }
{$ENDIF}

const
  { 0048919C, 004891A8, 004891B4: memo background colour per tab }
  TabR: array[0..11] of Byte =
    ($FF, $FF, $A5, $D4, $AA, $E3, $AA, $EF, $D4, $A5, $FF, $90);
  TabG: array[0..11] of Byte =
    ($FF, $E1, $BF, $9A, $D2, $B1, $D2, $E5, $9A, $BF, $E1, $90);
  TabB: array[0..11] of Byte =
    ($FF, $8B, $74, $8A, $E2, $95, $E2, $D5, $8A, $74, $8B, $90);

{ @0047FF5C }
procedure TfrmReport.FormCreate(Sender: TObject);
var
  I: Integer;
begin
  Left := frmMain.Left + (852 - Width) div 2;
  Top := frmMain.Top + (767 - Height) div 2;
  for I := 0 to 10 do
    Lists[I] := TStringList.Create;
end;

{ @0047FFC4 }
procedure TfrmReport.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to 10 do
    Lists[I].Free;
end;

{ @0047FFE0 }
function TfrmReport.Execute(TabCount: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to TabCount - 1 do
    tcTabs.Tabs.Add(Lists[I][0]);
  ShowTab(0);
  ShowModal;
  { NOTE: Result is never assigned in the original (returns garbage); the
    only caller ignores it. }
end;

{ @00480074 }
procedure TfrmReport.ShowTab(Index: Integer);
var
  I: Integer;
begin
  memoTab.Color := RGB(TabR[Index], TabG[Index], TabB[Index]);
  memoTab.Lines.Clear;
  for I := 1 to Lists[Index].Count - 1 do
    memoTab.Lines.Add(Lists[Index][I]);
end;

{ @00480144 }
procedure TfrmReport.butOKClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;

{ @00480150 }
procedure TfrmReport.tcTabsChange(Sender: TObject);
begin
  ShowTab(tcTabs.TabIndex);
end;

{ @0048016C }
procedure TfrmReport.tcTabsDrawTab(Control: TCustomTabControl; TabIndex: Integer;
  const Rect: TRect; Active: Boolean);
var
  R: TRect;
begin
  R := Rect;
  Inc(R.Left, 4);   { NOTE: R is never used }
  Control.Canvas.Font.Color := clWhite;
  Control.Canvas.TextRect(Rect, Rect.Left + 4, Rect.Top + 4, Lists[TabIndex][0]);
  Control.Canvas.DrawFocusRect(Rect);
end;

end.

unit fReport;

{ TfrmReport: het jaarrapport ("Rapportage"). Een tabblad per wijk plus de totalen;
  TWorld.Rapport vult Lists[] (regel 0 van elke lijst is het tabbladopschrift, de
  overige regels worden in het memo getoond). Elk tabblad heeft zijn eigen memokleur.
  Gedecompileerd uit ROS.exe v1.1, code 0047FD68-00480257. }

{$I zm.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ComCtrls;

type
  { VMT 0047FDB4, instantiegrootte $308 }
  TfrmReport = class(TForm)
    butOK: TButton;                    { +0x2D0 }
    tcTabs: TTabControl;               { +0x2D4 }
    memoTab: TMemo;                    { +0x2D8 }
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure butOKClick(Sender: TObject);
    procedure tcTabsChange(Sender: TObject);
    procedure tcTabsDrawTab(Besturing: TCustomTabControl; TabNr: Integer;
      const Vlak: TRect; Actief: Boolean);
  private
    procedure ShowTab(Nr: Integer);
  public
    Lists: array[0..10] of TStrings;   { +0x2DC  gevuld door TWorld.Rapport }
    function Execute(AantalTabs: Integer): Integer;
  end;

var
  frmReport: TfrmReport;   { niet gebruikt: wordt door de linker verwijderd }

implementation

uses
  Fmain;

{$IFNDEF FPC}
{$R *.dfm}  { Alleen Delphi: de draagbare build laadt formulieren uit de ROS.exe van de gebruiker }
{$ENDIF}

const
  { 0048919C, 004891A8, 004891B4: achtergrondkleur van het memo per tabblad }
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
function TfrmReport.Execute(AantalTabs: Integer): Integer;
var
  I: Integer;
begin
  for I := 0 to AantalTabs - 1 do
    tcTabs.Tabs.Add(Lists[I][0]);
  ShowTab(0);
  ShowModal;
  { LET OP: Result wordt in het origineel nooit toegekend (geeft een willekeurige
    waarde terug); de enige aanroeper negeert het. }
end;

{ @00480074 }
procedure TfrmReport.ShowTab(Nr: Integer);
var
  I: Integer;
begin
  memoTab.Color := RGB(TabR[Nr], TabG[Nr], TabB[Nr]);
  memoTab.Lines.Clear;
  for I := 1 to Lists[Nr].Count - 1 do
    memoTab.Lines.Add(Lists[Nr][I]);
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
procedure TfrmReport.tcTabsDrawTab(Besturing: TCustomTabControl; TabNr: Integer;
  const Vlak: TRect; Actief: Boolean);
var
  R: TRect;
begin
  R := Vlak;
  Inc(R.Left, 4);   { LET OP: R wordt nooit gebruikt }
  Besturing.Canvas.Font.Color := clWhite;
  Besturing.Canvas.TextRect(Vlak, Vlak.Left + 4, Vlak.Top + 4, Lists[TabNr][0]);
  Besturing.Canvas.DrawFocusRect(Vlak);
end;

end.

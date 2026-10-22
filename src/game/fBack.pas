unit fBack;

{ TfrmBlack: het zwarte, schermvullende achtergrondvenster achter het hoofdvenster,
  met het laadplaatje, de laadvoortgangstekst en het versienummer. Toetsaanslagen
  en muisklikken erop worden doorgegeven aan het hoofdvenster.
  Gedecompileerd uit ROS.exe v1.1, code 00486C6C-00486F63. }

{$I zm.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, ExtCtrls;

type
  { VMT 00486CB8, instantiegrootte $2E0 }
  TfrmBlack = class(TForm)
    imgLoading: TImage;                { +0x2D0 }
    lblLoading: TLabel;                { +0x2D4 }
    lblLoading0: TLabel;               { +0x2D8 }
    lblVersion: TLabel;                { +0x2DC }
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormCreate(Sender: TObject);
  end;

var
  frmBlack: TfrmBlack;   { niet gebruikt: wordt door de linker verwijderd }

implementation

uses
  Fmain;

{$IFNDEF FPC}
{$R *.dfm}  { Alleen Delphi: de draagbare build laadt formulieren uit de ROS.exe van de gebruiker }
{$ENDIF}

{ @00486E68 }
procedure TfrmBlack.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  frmMain.sbStageKeyDown(Sender, Key, Shift);
end;

{ @00486E80 }
procedure TfrmBlack.FormKeyPress(Sender: TObject; var Key: Char);
begin
  frmMain.sbStageKeyPress(Sender, Key);
end;

{ @00486E90 }
procedure TfrmBlack.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  frmMain.BringToFront;
end;

{ @00486EA4 }
procedure TfrmBlack.FormCreate(Sender: TObject);
begin
  imgLoading.Left := (Screen.Width - imgLoading.Width) div 2;
  imgLoading.Top := (Screen.Height - imgLoading.Height) div 2;
  lblLoading0.Left := imgLoading.Left + 12;
  lblLoading0.Top := imgLoading.Top + 80;
end;

end.

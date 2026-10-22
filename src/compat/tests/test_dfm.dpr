program test_dfm;

{ Test van de compatlaag: TCustomForm.Create leest de formulierresource TFRMBLACK uit de
  ROS.exe van de gebruiker (ZM_EXE of ZM_DATA) in met TReader: TImage met een ingebedde
  bitmap (Picture.Data), TLabels met lettertypen, en events die aan gepubliceerde methoden
  zijn gekoppeld. }

{$MODE DELPHI}{$H+}

uses
  Windows, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls, ZMWin;

type
  TfrmBlack = class(TForm)
    imgLoading: TImage;
    lblLoading: TLabel;
    lblLoading0: TLabel;
    lblVersion: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormKeyPress(Sender: TObject; var Key: Char);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
  public
    Created: Boolean;
  end;

procedure TfrmBlack.FormCreate(Sender: TObject);
begin
  Created := True;
  lblVersion.Caption := 'Versie compat';
end;

procedure TfrmBlack.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
end;

procedure TfrmBlack.FormKeyPress(Sender: TObject; var Key: Char);
begin
end;

procedure TfrmBlack.FormMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
end;

var
  F: TfrmBlack;
  OutFile: string;
  Fails: Integer;

procedure Check(Cond: Boolean; const Msg: string);
begin
  if not Cond then
  begin
    WriteLn('FAIL: ', Msg);
    Inc(Fails);
  end;
end;

begin
  Fails := 0;
  OutFile := ParamStr(1);
  if OutFile = '' then OutFile := 'test_dfm.png';
  Application.CreateForm(TfrmBlack, F);
  Check(F.Created, 'OnCreate (FormCreate) is niet aangeroepen');
  Check(F.imgLoading <> nil, 'imgLoading is niet ingelezen');
  Check((F.imgLoading <> nil) and (F.imgLoading.Picture.Width = 400), 'breedte van de imgLoading-afbeelding');
  Check(F.lblLoading.Font.Height = -32, 'lettergrootte van lblLoading');
  Check(F.lblLoading.Alignment = taCenter, 'uitlijning van lblLoading');
  Check(F.BorderStyle = bsNone, 'BorderStyle');
  Check(F.WindowState = wsMaximized, 'WindowState');
  Check(F.Color = clBlack, 'Color');
  F.Show;
  Application.ProcessMessages;
  Application.ProcessMessages;
  ZMPresenteer(True);
  ZMBewaarSchermafdruk(OutFile);
  if Fails = 0 then WriteLn('OK test_dfm -> ', OutFile) else Halt(1);
end.

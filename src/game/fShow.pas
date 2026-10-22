unit fShow;

{ Debug window that shows a bitmap (TSurface.DebugShow).
  Decompiled from ROS.exe v1.1, code 004616A8-00461B0F; form in build/dfm-1.1/TFORMDEBUGSHOW.txt. }

{$I zm.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, Buttons, ExtCtrls;

type
  TDebugShowKind = (dkGraphic, dkText);

  TformDebugShow = class(TForm)
    OKBtn: TBitBtn;              { +0x2D0 }
    PaintBox1: TPaintBox;        { +0x2D4 }
    Label1: TLabel;              { +0x2D8 }
    memText: TMemo;              { +0x2DC }
    procedure PaintBox1Paint(Sender: TObject);
    procedure OKBtnKeyPress(Sender: TObject; var Key: Char);
    procedure FormResize(Sender: TObject);
  private
    FKind: TDebugShowKind;       { +0x2E0 }
    FGraphic: TGraphic;          { +0x2E4 }
    FView: TControl;             { +0x2E8  control that is resized with the form }
  public
    procedure ShowGraphic(AGraphic: TGraphic; ACaption: string);
  end;

var
  formDebugShow: TformDebugShow;   { 0048A8B0 }

procedure CreateDebugShow;
procedure FreeDebugShow;
procedure ShowBitmap(AGraphic: TGraphic; ACaption: string);

implementation

{$IFNDEF FPC}
{$R *.dfm}  { Delphi only: the portable build streams forms from the user's ROS.exe }
{$ENDIF}

{ @00461898 }
procedure TformDebugShow.ShowGraphic(AGraphic: TGraphic; ACaption: string);
begin
  FGraphic := AGraphic;
  FKind := dkGraphic;
  FView := PaintBox1;
  PaintBox1.Visible := True;
  Caption := ACaption;
  ShowModal;
end;

{ @00461914 }
procedure TformDebugShow.PaintBox1Paint(Sender: TObject);
begin
  case FKind of
    dkGraphic:
      begin
        PaintBox1.Canvas.Draw(0, 0, FGraphic);
        Label1.Caption := 'Width: ' + IntToStr(FGraphic.Width) +
          ' Height: ' + IntToStr(FGraphic.Height);
      end;
  end;
end;

{ @004619F0 }
procedure TformDebugShow.OKBtnKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #27 then
    Close;
end;

{ @004619FC }
procedure TformDebugShow.FormResize(Sender: TObject);
var
  W, H: Integer;
begin
  { NOTE: uses the global formDebugShow instead of Self }
  W := formDebugShow.Width - 24;
  if W > 25 then
    FView.Width := W;
  H := formDebugShow.Height - 91;
  if H > 25 then
    FView.Height := H;
end;

{ @00461A3C }
procedure CreateDebugShow;
begin
  if formDebugShow = nil then
    Application.CreateForm(TformDebugShow, formDebugShow);
end;

{ @00461A60 }
procedure FreeDebugShow;
begin
  if formDebugShow <> nil then
  begin
    formDebugShow.Free;
    formDebugShow := nil;
  end;
end;

{ @00461A7C }
procedure ShowBitmap(AGraphic: TGraphic; ACaption: string);
begin
  CreateDebugShow;
  formDebugShow.ShowGraphic(AGraphic, ACaption);
  FreeDebugShow;
end;

end.

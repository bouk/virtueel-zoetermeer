unit fShow;

{ Debugvenster dat een bitmap toont (TSurface.ToonDebug).
  Gedecompileerd uit ROS.exe v1.1, code 004616A8-00461B0F; formulier in build/dfm-1.1/TFORMDEBUGSHOW.txt. }

{$I zm.inc}

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, Buttons, ExtCtrls;

type
  TDebugToonSoort = (dkGraphic, dkText);

  TformDebugShow = class(TForm)
    OKBtn: TBitBtn;              { +0x2D0 }
    PaintBox1: TPaintBox;        { +0x2D4 }
    Label1: TLabel;              { +0x2D8 }
    memText: TMemo;              { +0x2DC }
    procedure PaintBox1Paint(Sender: TObject);
    procedure OKBtnKeyPress(Sender: TObject; var Key: Char);
    procedure FormResize(Sender: TObject);
  private
    FKind: TDebugToonSoort;       { +0x2E0 }
    FGraphic: TGraphic;          { +0x2E4 }
    FWeergave: TControl;             { +0x2E8  besturing die samen met het formulier van grootte verandert }
  public
    procedure ToonAfbeelding(AAfbeelding: TGraphic; ATitel: string);
  end;

var
  formDebugShow: TformDebugShow;   { 0048A8B0 }

procedure MaakDebugToon;
procedure VrijDebugToon;
procedure ToonBitmap(AAfbeelding: TGraphic; ATitel: string);

implementation

{$IFNDEF FPC}
{$R *.dfm}  { Alleen Delphi: de draagbare build laadt formulieren uit de ROS.exe van de gebruiker }
{$ENDIF}

{ @00461898 }
procedure TformDebugShow.ToonAfbeelding(AAfbeelding: TGraphic; ATitel: string);
begin
  FGraphic := AAfbeelding;
  FKind := dkGraphic;
  FWeergave := PaintBox1;
  PaintBox1.Visible := True;
  Caption := ATitel;
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
  Breedte, Hoogte: Integer;
begin
  { LET OP: gebruikt de globale formDebugShow in plaats van Self }
  Breedte := formDebugShow.Width - 24;
  if Breedte > 25 then
    FWeergave.Width := Breedte;
  Hoogte := formDebugShow.Height - 91;
  if Hoogte > 25 then
    FWeergave.Height := Hoogte;
end;

{ @00461A3C }
procedure MaakDebugToon;
begin
  if formDebugShow = nil then
    Application.CreateForm(TformDebugShow, formDebugShow);
end;

{ @00461A60 }
procedure VrijDebugToon;
begin
  if formDebugShow <> nil then
  begin
    formDebugShow.Free;
    formDebugShow := nil;
  end;
end;

{ @00461A7C }
procedure ToonBitmap(AAfbeelding: TGraphic; ATitel: string);
begin
  MaakDebugToon;
  formDebugShow.ToonAfbeelding(AAfbeelding, ATitel);
  VrijDebugToon;
end;

end.

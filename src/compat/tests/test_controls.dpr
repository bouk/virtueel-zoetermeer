program test_controls;

{ Compat layer test: standard controls on a form, drawn into the emulated screen.
  Run headless: ZM_HEADLESS=1 test_controls <out.png> }

{$MODE DELPHI}{$H+}

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ExtCtrls,
  Buttons, ComCtrls, ZMWin;

type
  TTestForm = class(TForm)
  public
    Lbl, Big: TLabel;
    Btn: TButton;
    BitBtn: TBitBtn;
    Memo: TMemo;
    Edit: TEdit;
    Check: TCheckBox;
    Radio1, Radio2: TRadioButton;
    List: TListBox;
    Combo: TComboBox;
    Tabs: TTabControl;
    Panel: TPanel;
    Paint: TPaintBox;
    Clicks: Integer;
    procedure BtnClick(Sender: TObject);
    procedure PaintPaint(Sender: TObject);
    procedure TabsDraw(Control: TCustomTabControl; ATab: Integer; const Rect: TRect; Active: Boolean);
  end;

procedure TTestForm.BtnClick(Sender: TObject);
begin
  Inc(Clicks);
  Lbl.Caption := 'Clicked ' + IntToStr(Clicks) + 'x';
end;

procedure TTestForm.PaintPaint(Sender: TObject);
begin
  with Paint.Canvas do
  begin
    Brush.Color := clWhite;
    FillRect(Rect(0, 0, Paint.Width, Paint.Height));
    Pen.Color := clRed;
    Pen.Width := 2;
    Ellipse(4, 4, 60, 60);
    Brush.Color := clYellow;
    Polygon([Point(70, 60), Point(100, 4), Point(130, 60)]);
    Pen.Width := 1;
    Pen.Color := clBlue;
    MoveTo(0, 0);
    LineTo(Paint.Width - 1, Paint.Height - 1);
    Font.Name := 'Courier New';
    Font.Size := 10;
    Brush.Style := bsClear;
    TextOut(4, 64, 'Courier New 10');
  end;
end;

procedure TTestForm.TabsDraw(Control: TCustomTabControl; ATab: Integer; const Rect: TRect; Active: Boolean);
begin
  with Control as TTabControl do
  begin
    if Active then Canvas.Font.Color := clRed else Canvas.Font.Color := clNavy;
    Canvas.TextOut(Rect.Left + 2, Rect.Top + 1, Tabs[ATab]);
  end;
end;

var
  F: TTestForm;
  I: Integer;
  OutFile: string;

begin
  OutFile := ParamStr(1);
  if OutFile = '' then OutFile := 'test_controls.png';
  F := TTestForm.CreateNew(Application);
  with F do
  begin
    Caption := 'Compat controls test';
    BorderStyle := bsSingle;
    SetBounds(40, 30, 640, 480);
    Font.Name := 'MS Sans Serif';
    Font.Height := -11;
    Lbl := TLabel.Create(F);
    Lbl.Parent := F;
    Lbl.SetBounds(16, 12, 200, 13);
    Lbl.Caption := 'MS Sans Serif 8: The quick brown fox (Ågë€)';
    Big := TLabel.Create(F);
    Big.Parent := F;
    Big.Font.Name := 'Arial';
    Big.Font.Height := -24;
    Big.Font.Style := [fsBold];
    Big.Font.Color := clNavy;
    Big.Left := 16;
    Big.Top := 30;
    Big.Caption := 'Arial Bold 24px';
    Btn := TButton.Create(F);
    Btn.Parent := F;
    Btn.SetBounds(16, 70, 90, 25);
    Btn.Caption := '&Click me';
    Btn.Default := True;
    Btn.OnClick := BtnClick;
    BitBtn := TBitBtn.Create(F);
    BitBtn.Parent := F;
    BitBtn.SetBounds(116, 70, 87, 27);
    BitBtn.Kind := bkOK;
    Edit := TEdit.Create(F);
    Edit.Parent := F;
    Edit.SetBounds(16, 108, 187, 21);
    Edit.Text := 'Edit text';
    Check := TCheckBox.Create(F);
    Check.Parent := F;
    Check.SetBounds(16, 138, 120, 17);
    Check.Caption := 'Check box';
    Check.Checked := True;
    Radio1 := TRadioButton.Create(F);
    Radio1.Parent := F;
    Radio1.SetBounds(16, 160, 120, 17);
    Radio1.Caption := 'Radio 1';
    Radio2 := TRadioButton.Create(F);
    Radio2.Parent := F;
    Radio2.SetBounds(16, 180, 120, 17);
    Radio2.Caption := 'Radio 2';
    Radio2.Checked := True;
    Memo := TMemo.Create(F);
    Memo.Parent := F;
    Memo.SetBounds(220, 12, 200, 120);
    Memo.ScrollBars := ssVertical;
    for I := 1 to 20 do
      Memo.Lines.Add('Memo line ' + IntToStr(I) + ' with some text that wraps around');
    List := TListBox.Create(F);
    List.Parent := F;
    List.SetBounds(430, 12, 190, 120);
    for I := 1 to 12 do List.Items.Add('List item ' + IntToStr(I));
    List.ItemIndex := 2;
    Combo := TComboBox.Create(F);
    Combo.Parent := F;
    Combo.Style := csDropDownList;
    Combo.SetBounds(220, 140, 200, 21);
    Combo.Items.Add('Combo item A');
    Combo.Items.Add('Combo item B');
    Combo.ItemIndex := 1;
    Tabs := TTabControl.Create(F);
    Tabs.Parent := F;
    Tabs.SetBounds(16, 210, 404, 120);
    Tabs.MultiLine := True;
    Tabs.OwnerDraw := True;
    Tabs.OnDrawTab := TabsDraw;
    Tabs.Tabs.Add('Algemeen');
    Tabs.Tabs.Add('Wegen');
    Tabs.Tabs.Add('Sport en recreatie');
    Tabs.TabIndex := 1;
    Panel := TPanel.Create(F);
    Panel.Parent := F;
    Panel.SetBounds(430, 140, 190, 60);
    Panel.Caption := 'Panel';
    Paint := TPaintBox.Create(F);
    Paint.Parent := F;
    Paint.SetBounds(430, 210, 190, 120);
    Paint.OnPaint := PaintPaint;
  end;
  F.Show;
  ZMMainWindow := F.Handle;   { ZMInjectMouse coordinates are relative to this window }
  Application.ProcessMessages;
  { click the button through the message queue }
  ZMInjectMouse(60, 82, 1, True);
  ZMInjectMouse(60, 82, 1, False);
  for I := 1 to 5 do Application.ProcessMessages;
  if F.Clicks <> 1 then
  begin
    WriteLn('FAIL: button click not delivered');
    Halt(1);
  end;
  for I := 1 to 3 do Application.ProcessMessages;
  ZMPresent(True);
  ZMSaveScreenshot(OutFile);
  WriteLn('OK test_controls -> ', OutFile);
end.

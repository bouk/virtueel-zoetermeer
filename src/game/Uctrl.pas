unit Uctrl;

{ TCtrlForm: een formulier waarvan de standaardbesturingen naar een spritebox
  verplaatst kunnen worden. AttachControls koppelt de besturingen aan de spritebox
  en maakt voor elke sprite met de naam 'sprite<Name>' op het formulier van de
  besturing met de naam '<prefix><Name>' (prefix uit ControlDefs, bijv. butStart
  voor spriteStart) een gedrag van die sprite en verbergt de besturing.
  DetachControls maakt dit ongedaan. TfrmMain erft van TCtrlForm.
  Gedecompileerd uit ROS.exe v1.1, code 00477C60-0047841C. }

{$I zm.inc}

interface

uses
  Classes, Controls, Forms, uSpritebox;

type
  TControlDef = record
    ControlClass: TControlClass;
    Prefix: string;
  end;

  TCtrlForm = class(TForm)
  private
    procedure ControlToSprite(Control: TControl; Definitie: TControlDef;
      SpriteBox: TSpriteBox);
  public
    procedure AttachControls(MakeSprites: Boolean; SpriteBox: TSpriteBox);
    procedure DetachControls(FreeBehaviours: Boolean; SpriteBox: TSpriteBox);
  end;

implementation

uses
  StdCtrls, ExtCtrls, Grids, uString, uTool, uSprite, cEditCtr, Sprbehav;

const
  { 00488F20 }
  ControlDefs: array[0..10] of TControlDef = (
    (ControlClass: TButton;      Prefix: 'but'),
    (ControlClass: TRadioButton; Prefix: 'rad'),
    (ControlClass: TListBox;     Prefix: 'list'),
    (ControlClass: TCheckBox;    Prefix: 'chk'),
    (ControlClass: TMemo;        Prefix: 'memo'),
    (ControlClass: TComboBox;    Prefix: 'cmb'),
    (ControlClass: TEdit;        Prefix: 'txt'),
    (ControlClass: TScrollBox;   Prefix: 'scroll'),
    (ControlClass: TPaintBox;    Prefix: 'pb'),
    (ControlClass: TImage;       Prefix: 'img'),
    (ControlClass: TStringGrid;  Prefix: 'grid'));

var
  ComboBox: TComboBox;   { 0048B14C }

{ @00477E74 }
procedure TCtrlForm.ControlToSprite(Control: TControl; Definitie: TControlDef;
  SpriteBox: TSpriteBox);
var
  I: Integer;
  Sprite: TSprite;
begin
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TSprite then
    begin
      Sprite := Components[I] as TSprite;
      if Definitie.Prefix + DelLeft(Sprite.Name, 6) = Control.Name then
      begin
        Sprite.SpriteBox := SpriteBox;
        ControlToBehaviour(Sprite, Control);
        Control.Visible := False;
        if Control is TButton then
        begin
          Sprite.AddBehaviour('CURSOR_BEHAV', TBehavCursor.Create(crHandje));
          Sprite.GetBehaviour('CURSOR_BEHAV').SetActive(True);
        end;
      end;
    end;
end;

{ @00477FE4 }
procedure TCtrlForm.AttachControls(MakeSprites: Boolean; SpriteBox: TSpriteBox);
var
  I, J: Integer;
begin
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TSprite then
      (Components[I] as TSprite).SpriteBox := SpriteBox
    else
      for J := Low(ControlDefs) to High(ControlDefs) do
        if (Components[I] is ControlDefs[J].ControlClass) and
          (Components[I] is TControl) and
          (((Components[I] as TControl).Parent is TForm) or
           ((Components[I] as TControl).Parent is TSpriteBox)) then
        begin
          (Components[I] as TControl).Parent := SpriteBox;
          if Components[I] is TComboBox then
          begin
            ComboBox := Components[I] as TComboBox;
            ComboBox.ItemIndex := ComboBox.Tag - 1;
          end;
          if MakeSprites then
            ControlToSprite(Components[I] as TControl, ControlDefs[J], SpriteBox);
        end;
end;

{ @0047817C }
procedure TCtrlForm.DetachControls(FreeBehaviours: Boolean; SpriteBox: TSpriteBox);
var
  I, J: Integer;
  Sprite: TSprite;
begin
  for I := ComponentCount - 1 downto 0 do
    if Components[I] is TSprite then
    begin
      Sprite := Components[I] as TSprite;
      if Sprite.Dynamic then
      begin
        Sprite.Visible := False;
        Sprite.Kill;
      end
      else
      begin
        if FreeBehaviours then
          FreeList(Sprite.Behaviours);
        Sprite.SpriteBox := nil;
        if Sprite.GetBehaviour('CONTROL_BEHAV') is TBehavMemo then
          (Sprite.GetBehaviour('CONTROL_BEHAV') as TBehavMemo).ScrollBar.Visible := False;
      end;
    end
    else
      for J := Low(ControlDefs) to High(ControlDefs) do
        if (Components[I] is ControlDefs[J].ControlClass) and
          (Components[I] is TControl) and
          ((Components[I] as TControl).Parent = SpriteBox) then
        begin
          if Components[I] is TComboBox then
          begin
            ComboBox := Components[I] as TComboBox;
            ComboBox.Tag := ComboBox.ItemIndex + 1;
          end;
          (Components[I] as TControl).Parent := Self;
        end;
end;

end.

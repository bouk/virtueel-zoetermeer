unit Uctrl;

{ TCtrlForm: een formulier waarvan de standaardbesturingen naar een spritebox
  verplaatst kunnen worden. KoppelBesturingen koppelt de besturingen aan de spritebox
  en maakt voor elke sprite met de naam 'sprite<Name>' op het formulier van de
  besturing met de naam '<prefix><Name>' (prefix uit BesturingDefs, bijv. butStart
  voor spriteStart) een gedrag van die sprite en verbergt de besturing.
  OntkoppelBesturingen maakt dit ongedaan. TfrmMain erft van TCtrlForm.
  Gedecompileerd uit ROS.exe v1.1, code 00477C60-0047841C. }

{$I zm.inc}

interface

uses
  Classes, Controls, Forms, uSpritebox;

type
  TBesturingDef = record
    BesturingKlasse: TControlClass;
    NaamVoorvoegsel: string;
  end;

  TCtrlForm = class(TForm)
  private
    procedure BesturingNaarSprite(Control: TControl; Definitie: TBesturingDef;
      SpriteBox: TSpriteBox);
  public
    procedure KoppelBesturingen(MakeSprites: Boolean; SpriteBox: TSpriteBox);
    procedure OntkoppelBesturingen(FreeBehaviours: Boolean; SpriteBox: TSpriteBox);
  end;

implementation

uses
  StdCtrls, ExtCtrls, Grids, uString, uTool, uSprite, cEditCtr, Sprbehav;

const
  { 00488F20 }
  BesturingDefs: array[0..10] of TBesturingDef = (
    (BesturingKlasse: TButton;      NaamVoorvoegsel: 'but'),
    (BesturingKlasse: TRadioButton; NaamVoorvoegsel: 'rad'),
    (BesturingKlasse: TListBox;     NaamVoorvoegsel: 'list'),
    (BesturingKlasse: TCheckBox;    NaamVoorvoegsel: 'chk'),
    (BesturingKlasse: TMemo;        NaamVoorvoegsel: 'memo'),
    (BesturingKlasse: TComboBox;    NaamVoorvoegsel: 'cmb'),
    (BesturingKlasse: TEdit;        NaamVoorvoegsel: 'txt'),
    (BesturingKlasse: TScrollBox;   NaamVoorvoegsel: 'scroll'),
    (BesturingKlasse: TPaintBox;    NaamVoorvoegsel: 'pb'),
    (BesturingKlasse: TImage;       NaamVoorvoegsel: 'img'),
    (BesturingKlasse: TStringGrid;  NaamVoorvoegsel: 'grid'));

var
  Keuzelijst: TComboBox;   { 0048B14C }

{ @00477E74 }
procedure TCtrlForm.BesturingNaarSprite(Control: TControl; Definitie: TBesturingDef;
  SpriteBox: TSpriteBox);
var
  I: Integer;
  Sprite: TSprite;
begin
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TSprite then
    begin
      Sprite := Components[I] as TSprite;
      if Definitie.NaamVoorvoegsel + VerwijderLinks(Sprite.Name, 6) = Control.Name then
      begin
        Sprite.SpriteBox := SpriteBox;
        BesturingNaarGedrag(Sprite, Control);
        Control.Visible := False;
        if Control is TButton then
        begin
          Sprite.VoegGedragToe('CURSOR_BEHAV', TBehavCursor.Create(crHandje));
          Sprite.LeesGedrag('CURSOR_BEHAV').SetActive(True);
        end;
      end;
    end;
end;

{ @00477FE4 }
procedure TCtrlForm.KoppelBesturingen(MakeSprites: Boolean; SpriteBox: TSpriteBox);
var
  I, J: Integer;
begin
  for I := 0 to ComponentCount - 1 do
    if Components[I] is TSprite then
      (Components[I] as TSprite).SpriteBox := SpriteBox
    else
      for J := Low(BesturingDefs) to High(BesturingDefs) do
        if (Components[I] is BesturingDefs[J].BesturingKlasse) and
          (Components[I] is TControl) and
          (((Components[I] as TControl).Parent is TForm) or
           ((Components[I] as TControl).Parent is TSpriteBox)) then
        begin
          (Components[I] as TControl).Parent := SpriteBox;
          if Components[I] is TComboBox then
          begin
            Keuzelijst := Components[I] as TComboBox;
            Keuzelijst.ItemIndex := Keuzelijst.Tag - 1;
          end;
          if MakeSprites then
            BesturingNaarSprite(Components[I] as TControl, BesturingDefs[J], SpriteBox);
        end;
end;

{ @0047817C }
procedure TCtrlForm.OntkoppelBesturingen(FreeBehaviours: Boolean; SpriteBox: TSpriteBox);
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
        Sprite.Verwijder;
      end
      else
      begin
        if FreeBehaviours then
          LijstVrijgeven(Sprite.Gedragslijst);
        Sprite.SpriteBox := nil;
        if Sprite.LeesGedrag('CONTROL_BEHAV') is TBehavMemo then
          (Sprite.LeesGedrag('CONTROL_BEHAV') as TBehavMemo).ScrollBar.Visible := False;
      end;
    end
    else
      for J := Low(BesturingDefs) to High(BesturingDefs) do
        if (Components[I] is BesturingDefs[J].BesturingKlasse) and
          (Components[I] is TControl) and
          ((Components[I] as TControl).Parent = SpriteBox) then
        begin
          if Components[I] is TComboBox then
          begin
            Keuzelijst := Components[I] as TComboBox;
            Keuzelijst.Tag := Keuzelijst.ItemIndex + 1;
          end;
          (Components[I] as TControl).Parent := Self;
        end;
end;

end.

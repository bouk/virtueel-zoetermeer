unit cEditCtr;

{ TComment: randloos, zwart invoerveld dat als onderschrift- of opmerkingbesturing
  wordt gebruikt; registreert ook de cursor "HANDJE" (hand).
  Gedecompileerd uit ROS.exe v1.1, code 00469244-0046952B. }

{$I zm.inc}

interface

uses
  Windows, Classes, Graphics, Controls, Forms, StdCtrls;

const
  crHandje = 123;

type
  TComment = class(TCustomEdit)
  private
    procedure ZetOnderschrift(Waarde: string);
    function LeesOnderschrift: string;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption: string read LeesOnderschrift write ZetOnderschrift;
  end;

implementation

{ @004693B8 }
procedure TComment.ZetOnderschrift(Waarde: string);
begin
  Text := Waarde;
end;

{ @00469404 }
function TComment.LeesOnderschrift: string;
begin
  Result := Text;
end;

{ @00469418 }
constructor TComment.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Visible := False;
  BorderStyle := bsNone;
  Color := clBlack;
  Ctl3D := False;
  Height := 14;
  Width := 60;
  with Font do
  begin
    Color := clWhite;
    Name := 'Arial';
    Size := 8;
  end;
end;

{ @004694FC }
initialization
  Screen.Cursors[crHandje] := LoadCursor(HInstance, 'HANDJE');

end.

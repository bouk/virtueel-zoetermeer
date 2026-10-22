unit cEditCtr;

{ TComment: borderless, black edit used as a caption/comment control; also registers
  the "HANDJE" (hand) cursor.
  Decompiled from ROS.exe v1.1, code 00469244-0046952B. }

{$I zm.inc}

interface

uses
  Windows, Classes, Graphics, Controls, Forms, StdCtrls;

const
  crHandje = 123;

type
  TComment = class(TCustomEdit)
  private
    procedure SetCaption(Value: string);
    function GetCaption: string;
  public
    constructor Create(AOwner: TComponent); override;
  published
    property Caption: string read GetCaption write SetCaption;
  end;

implementation

{ @004693B8 }
procedure TComment.SetCaption(Value: string);
begin
  Text := Value;
end;

{ @00469404 }
function TComment.GetCaption: string;
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

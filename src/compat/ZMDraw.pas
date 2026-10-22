unit ZMDraw;

{ Classic (Windows 9x) look for the standard controls: 3D frames, button faces,
  check boxes, scroll bars, arrows. Used by StdCtrls, Buttons, ComCtrls, Grids. }

{$MODE DELPHI}{$H+}

interface

uses Windows, Graphics;

const
  ZMScrollBarSize = 16;

type
  TZMScrollPart = (spNone, spLineUp, spPageUp, spThumb, spPageDown, spLineDown);

procedure ZMFrame3D(Canvas: TCanvas; R: TRect; TopLeft, BottomRight: TColor);
procedure ZMDrawRaised(Canvas: TCanvas; var R: TRect);      { button edge, 2 px }
procedure ZMDrawSunken(Canvas: TCanvas; var R: TRect);      { edit edge, 2 px }
procedure ZMDrawButtonFace(Canvas: TCanvas; R: TRect; Pressed, IsDefault, Focused: Boolean);
procedure ZMDrawCheck(Canvas: TCanvas; R: TRect; Checked, Grayed, Enabled: Boolean);
procedure ZMDrawRadio(Canvas: TCanvas; R: TRect; Checked, Enabled: Boolean);
procedure ZMDrawArrow(Canvas: TCanvas; R: TRect; Dir: Integer; Enabled: Boolean); { 0 up 1 down 2 left 3 right }
procedure ZMDrawScrollBar(Canvas: TCanvas; R: TRect; Vertical: Boolean; Min, Max, Pos, Page: Integer;
  Pressed: TZMScrollPart; Enabled: Boolean);
function ZMScrollHit(R: TRect; Vertical: Boolean; Min, Max, Pos, Page: Integer; P: TPoint): TZMScrollPart;
function ZMScrollThumbRect(R: TRect; Vertical: Boolean; Min, Max, Pos, Page: Integer): TRect;
procedure ZMDrawDisabledText(Canvas: TCanvas; R: TRect; const S: string; Flags: UINT);

implementation

uses Classes;

procedure ZMFrame3D(Canvas: TCanvas; R: TRect; TopLeft, BottomRight: TColor);
begin
  with Canvas do
  begin
    Pen.Style := psSolid;
    Pen.Width := 1;
    Pen.Color := TopLeft;
    MoveTo(R.Left, R.Bottom - 1);
    LineTo(R.Left, R.Top);
    LineTo(R.Right - 1, R.Top);
    Pen.Color := BottomRight;
    LineTo(R.Right - 1, R.Bottom - 1);
    LineTo(R.Left - 1, R.Bottom - 1);
  end;
end;

procedure ZMDrawRaised(Canvas: TCanvas; var R: TRect);
begin
  ZMFrame3D(Canvas, R, clBtnHighlight, cl3DDkShadow);
  InflateRect(R, -1, -1);
  ZMFrame3D(Canvas, R, cl3DLight, clBtnShadow);
  InflateRect(R, -1, -1);
end;

procedure ZMDrawSunken(Canvas: TCanvas; var R: TRect);
begin
  ZMFrame3D(Canvas, R, clBtnShadow, clBtnHighlight);
  InflateRect(R, -1, -1);
  ZMFrame3D(Canvas, R, cl3DDkShadow, cl3DLight);
  InflateRect(R, -1, -1);
end;

procedure ZMDrawButtonFace(Canvas: TCanvas; R: TRect; Pressed, IsDefault, Focused: Boolean);
begin
  with Canvas do
  begin
    Brush.Style := bsSolid;
    if IsDefault or Focused then
    begin
      Brush.Color := clWindowFrame;
      FrameRect(R);
      InflateRect(R, -1, -1);
    end;
    if Pressed then
    begin
      Brush.Color := clBtnShadow;
      FrameRect(R);
      InflateRect(R, -1, -1);
      Brush.Color := clBtnFace;
      FillRect(R);
    end
    else
    begin
      ZMDrawRaised(Canvas, R);
      Brush.Color := clBtnFace;
      FillRect(R);
    end;
  end;
end;

procedure ZMDrawCheck(Canvas: TCanvas; R: TRect; Checked, Grayed, Enabled: Boolean);
var
  I, X, Y: Integer;
begin
  ZMDrawSunken(Canvas, R);
  with Canvas do
  begin
    Brush.Style := bsSolid;
    if Enabled and not Grayed then Brush.Color := clWindow else Brush.Color := clBtnFace;
    FillRect(R);
    if Checked then
    begin
      if Enabled then Pen.Color := clWindowText else Pen.Color := clBtnShadow;
      X := R.Left + 1;
      Y := R.Top + 3;
      for I := 0 to 2 do
      begin
        MoveTo(X + I, Y + I + 0);
        LineTo(X + I, Y + I + 3);
      end;
      for I := 0 to 3 do
      begin
        MoveTo(X + 3 + I, Y + 1 - I);
        LineTo(X + 3 + I, Y + 4 - I);
      end;
    end;
  end;
end;

procedure ZMDrawRadio(Canvas: TCanvas; R: TRect; Checked, Enabled: Boolean);
var
  CX, CY: Integer;
begin
  with Canvas do
  begin
    Pen.Color := clBtnShadow;
    if Enabled then Brush.Color := clWindow else Brush.Color := clBtnFace;
    Brush.Style := bsSolid;
    Ellipse(R.Left, R.Top, R.Left + 12, R.Top + 12);
    Pen.Color := cl3DDkShadow;
    Brush.Style := bsClear;
    Ellipse(R.Left + 1, R.Top + 1, R.Left + 11, R.Top + 11);
    if Checked then
    begin
      CX := R.Left + 6;
      CY := R.Top + 6;
      Brush.Style := bsSolid;
      if Enabled then Brush.Color := clWindowText else Brush.Color := clBtnShadow;
      FillRect(Rect(CX - 2, CY - 1, CX + 2, CY + 1));
      FillRect(Rect(CX - 1, CY - 2, CX + 1, CY + 2));
    end;
  end;
end;

procedure ZMDrawArrow(Canvas: TCanvas; R: TRect; Dir: Integer; Enabled: Boolean);
var
  CX, CY, I: Integer;
  procedure Draw(DX, DY: Integer; C: TColor);
  var J: Integer;
  begin
    Canvas.Pen.Color := C;
    for J := 0 to 3 do
      case Dir of
        0: begin Canvas.MoveTo(CX - J + DX, CY - 2 + J + DY); Canvas.LineTo(CX + J + 1 + DX, CY - 2 + J + DY); end;
        1: begin Canvas.MoveTo(CX - J + DX, CY + 1 - J + DY); Canvas.LineTo(CX + J + 1 + DX, CY + 1 - J + DY); end;
        2: begin Canvas.MoveTo(CX - 2 + J + DX, CY - J + DY); Canvas.LineTo(CX - 2 + J + DX, CY + J + 1 + DY); end;
        3: begin Canvas.MoveTo(CX + 1 - J + DX, CY - J + DY); Canvas.LineTo(CX + 1 - J + DX, CY + J + 1 + DY); end;
      end;
  end;
begin
  CX := (R.Left + R.Right) div 2;
  CY := (R.Top + R.Bottom) div 2;
  I := 0;
  if Enabled then
    Draw(0, 0, clBtnText)
  else
  begin
    Draw(1, 1, clBtnHighlight);
    Draw(0, 0, clBtnShadow);
  end;
  if I = 0 then ;
end;

function TrackRect(R: TRect; Vertical: Boolean): TRect;
begin
  Result := R;
  if Vertical then
  begin
    Inc(Result.Top, ZMScrollBarSize);
    Dec(Result.Bottom, ZMScrollBarSize);
  end
  else
  begin
    Inc(Result.Left, ZMScrollBarSize);
    Dec(Result.Right, ZMScrollBarSize);
  end;
end;

function ZMScrollThumbRect(R: TRect; Vertical: Boolean; Min, Max, Pos, Page: Integer): TRect;
var
  T: TRect;
  Len, ThumbLen, Range, Off: Integer;
begin
  T := TrackRect(R, Vertical);
  if Vertical then Len := T.Bottom - T.Top else Len := T.Right - T.Left;
  Range := Max - Min + 1;
  if Page <= 0 then ThumbLen := ZMScrollBarSize
  else if Range > 0 then ThumbLen := Len * Page div Range
  else ThumbLen := Len;
  if ThumbLen < 8 then ThumbLen := 8;
  if ThumbLen > Len then ThumbLen := Len;
  if Page > 0 then Range := Max - Min + 1 - Page else Range := Max - Min;
  if Range <= 0 then Off := 0
  else Off := Int64(Len - ThumbLen) * (Pos - Min) div Range;
  if Off < 0 then Off := 0;
  if Off > Len - ThumbLen then Off := Len - ThumbLen;
  Result := T;
  if Vertical then
  begin
    Result.Top := T.Top + Off;
    Result.Bottom := Result.Top + ThumbLen;
  end
  else
  begin
    Result.Left := T.Left + Off;
    Result.Right := Result.Left + ThumbLen;
  end;
end;

procedure ZMDrawScrollBar(Canvas: TCanvas; R: TRect; Vertical: Boolean; Min, Max, Pos, Page: Integer;
  Pressed: TZMScrollPart; Enabled: Boolean);
var
  B1, B2, T, Th: TRect;
  procedure Btn(BR: TRect; Dir: Integer; P: Boolean);
  begin
    if P then
    begin
      Canvas.Brush.Color := clBtnShadow;
      Canvas.FrameRect(BR);
      InflateRect(BR, -1, -1);
      Canvas.Brush.Color := clBtnFace;
      Canvas.FillRect(BR);
      OffsetRect(BR, 1, 1);
    end
    else
    begin
      ZMDrawRaised(Canvas, BR);
      Canvas.Brush.Color := clBtnFace;
      Canvas.FillRect(BR);
    end;
    ZMDrawArrow(Canvas, BR, Dir, Enabled);
  end;
begin
  Canvas.Brush.Style := bsSolid;
  if Vertical then
  begin
    B1 := Rect(R.Left, R.Top, R.Right, R.Top + ZMScrollBarSize);
    B2 := Rect(R.Left, R.Bottom - ZMScrollBarSize, R.Right, R.Bottom);
    Btn(B1, 0, Pressed = spLineUp);
    Btn(B2, 1, Pressed = spLineDown);
  end
  else
  begin
    B1 := Rect(R.Left, R.Top, R.Left + ZMScrollBarSize, R.Bottom);
    B2 := Rect(R.Right - ZMScrollBarSize, R.Top, R.Right, R.Bottom);
    Btn(B1, 2, Pressed = spLineUp);
    Btn(B2, 3, Pressed = spLineDown);
  end;
  T := TrackRect(R, Vertical);
  { dithered track }
  Canvas.Brush.Color := cl3DLight;
  Canvas.FillRect(T);
  if Enabled and (Max > Min) then
  begin
    Th := ZMScrollThumbRect(R, Vertical, Min, Max, Pos, Page);
    ZMDrawRaised(Canvas, Th);
    Canvas.Brush.Color := clBtnFace;
    Canvas.FillRect(Th);
  end;
end;

function ZMScrollHit(R: TRect; Vertical: Boolean; Min, Max, Pos, Page: Integer; P: TPoint): TZMScrollPart;
var
  Th: TRect;
begin
  Result := spNone;
  if not PtInRect(R, P) then Exit;
  Th := ZMScrollThumbRect(R, Vertical, Min, Max, Pos, Page);
  if Vertical then
  begin
    if P.Y < R.Top + ZMScrollBarSize then Result := spLineUp
    else if P.Y >= R.Bottom - ZMScrollBarSize then Result := spLineDown
    else if P.Y < Th.Top then Result := spPageUp
    else if P.Y >= Th.Bottom then Result := spPageDown
    else Result := spThumb;
  end
  else
  begin
    if P.X < R.Left + ZMScrollBarSize then Result := spLineUp
    else if P.X >= R.Right - ZMScrollBarSize then Result := spLineDown
    else if P.X < Th.Left then Result := spPageUp
    else if P.X >= Th.Right then Result := spPageDown
    else Result := spThumb;
  end;
end;

procedure ZMDrawDisabledText(Canvas: TCanvas; R: TRect; const S: string; Flags: UINT);
var
  R2: TRect;
begin
  Canvas.Brush.Style := bsClear;
  R2 := R;
  OffsetRect(R2, 1, 1);
  Canvas.Font.Color := clBtnHighlight;
  DrawText(Canvas.Handle, PChar(S), Length(S), R2, Flags);
  Canvas.Font.Color := clBtnShadow;
  DrawText(Canvas.Handle, PChar(S), Length(S), R, Flags);
end;

end.

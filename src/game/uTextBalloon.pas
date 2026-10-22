unit uTextBalloon;

{ TTextBalloon: a speech balloon (rounded rectangle with a pointer towards
  the speaker) with word-wrapped text, drawn as a pixie of a TSpriteBox.
  The text is split into lines so that the text block gets close to a
  sqrt(2) aspect ratio.
  Decompiled from ROS.exe v1.1, code 004653E8-00466FA8. }

{$I zm.inc}

interface

uses
  Windows, Classes, Graphics, uSurface, uPixie, uSpritebox;

type
  { number of words per text line }
  TLineWords = array[0..99] of Integer;

  TTextBalloon = class(TPixie)
  private
    FBalloonText: string;           { +0x68 }
    FTipX: Integer;                 { +0x6C  pointer tip, relative to Left }
    FTipY: Integer;                 { +0x70 }
    FSpriteBox: TSpriteBox;         { +0x74 }
    FSideColor: TColor;             { +0x78 }
    FBackGroundColor: TColor;       { +0x7C }
    FXOffset: Integer;              { +0x80  balloon position relative to X }
    FYOffset: Integer;              { +0x84 }
    FX: Integer;                    { +0x88  the point the balloon points at }
    FY: Integer;                    { +0x8C }
    FBodyX: Integer;                { +0x90  balloon body, relative to Left }
    FBodyY: Integer;                { +0x94 }
    FExtentX: Integer;              { +0x98  Width - 1 }
    FExtentY: Integer;              { +0x9C  Height - 1 }
    FBalloonLineWidth: Integer;     { +0xA0 }
    FFont: TFont;                   { +0xA4 }
    FRoundCorner: Boolean;          { +0xA8 }
    procedure SetFont(Value: TFont);
    procedure FontChanged(Sender: TObject);
    procedure SetBalloonText(Value: string);
    procedure UpdateLayout;
    procedure SetBalloonLineWidth(Value: Integer);
    procedure SetRoundCorner(Value: Boolean);
    procedure SetXOffset(Value: Integer);
    procedure SetYOffset(Value: Integer);
    procedure SetSpriteBox(Value: TSpriteBox);
    procedure SetSideColor(Value: TColor);
    procedure SetBackGroundColor(Value: TColor);
    procedure DrawBalloon(Canvas: TCanvas; Left, Top, Right, Bottom, TipX,
      TipY: Integer);
    function LineRatio(LineCount: Integer; Text: string; Canvas: TCanvas;
      var MaxWidth: Integer; var Words: TLineWords; MaxLines: Integer): Double;
    procedure FitText(Text: string; Canvas: TCanvas; Left, Top: Integer;
      var Right, Bottom, LineCount, MaxWidth: Integer; var Words: TLineWords;
      MaxLines: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function GetWidth: Integer; override;
    function GetHeight: Integer; override;
    procedure Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;
    procedure DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
      Scale: Double); override;
    procedure SetX(Value: Integer); override;
    procedure SetY(Value: Integer); override;
    procedure SetZ(Value: Integer); override;
    function GetX: Integer; override;
    function GetY: Integer; override;
  published
    property SpriteBox: TSpriteBox read FSpriteBox write SetSpriteBox;
    property BalloonText: string read FBalloonText write SetBalloonText;
    property XOffset: Integer read FXOffset write SetXOffset;
    property YOffset: Integer read FYOffset write SetYOffset;
    property SideColor: TColor read FSideColor write SetSideColor;
    property BackGroundColor: TColor read FBackGroundColor write SetBackGroundColor;
    property BalloonLineWidth: Integer read FBalloonLineWidth write SetBalloonLineWidth;
    property RoundCorner: Boolean read FRoundCorner write SetRoundCorner;
    property Font: TFont read FFont write SetFont;
  end;

implementation

uses
  uString, uTool;

type
  { Point index of each of the 8 balloon corner points, after the 3 points of
    the pointer (indices 0..2); the order depends on the side of the pointer. }
  TCornerOrder = array[0..7] of Integer;

{$J+}
const
  CornerOrderLeft: TCornerOrder = (5, 6, 7, 8, 9, 10, 3, 4);     { 00488D8C }
  CornerOrderRight: TCornerOrder = (9, 10, 3, 4, 5, 6, 7, 8);    { 00488DAC }
  CornerOrderBottom: TCornerOrder = (3, 4, 5, 6, 7, 8, 9, 10);   { 00488DCC }
  CornerOrderTop: TCornerOrder = (7, 8, 9, 10, 3, 4, 5, 6);      { 00488DEC }
{$J-}

{ @00465654 }
constructor TTextBalloon.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetXOffset(50);
  SetYOffset(-100);
  SetBalloonLineWidth(5);
  SetSideColor(clBlack);
  SetBackGroundColor(clWhite);
  FFont := TFont.Create;
  SetRoundCorner(True);
  FFont.OnChange := FontChanged;
end;

{ @004656F0 }
destructor TTextBalloon.Destroy;
begin
  SetSpriteBox(nil);
  FFont.Free;
  inherited Destroy;
end;

{ @0046572C }
procedure TTextBalloon.SetFont(Value: TFont);
begin
  if (FFont <> nil) and (Value <> nil) then
    FFont.Assign(Value);
end;

{ @00465748 }
procedure TTextBalloon.FontChanged(Sender: TObject);
begin
  UpdateLayout;
end;

{ @00465750 }
function TTextBalloon.GetWidth: Integer;
begin
  Result := FExtentX + 1;
end;

{ @00465758 }
function TTextBalloon.GetHeight: Integer;
begin
  Result := FExtentY + 1;
end;

{ @00465760 }
procedure TTextBalloon.SetBalloonText(Value: string);
begin
  if FBalloonText <> Value then
  begin
    FBalloonText := Value;
    UpdateLayout;
  end;
end;

{ @004657C0  computes size, position, body and pointer of the balloon }
procedure TTextBalloon.UpdateLayout;
var
  Right, Bottom, MaxWidth, LineCount: Integer;
  Words: TLineWords;
  OldFont: TFont;
begin
  if csDesigning in ComponentState then
    Exit;
  if FSpriteBox = nil then
    Exit;
  OldFont := FSpriteBox.Canvas.Font;
  FSpriteBox.Canvas.Font := FFont;
  FitText(FBalloonText, FSpriteBox.Canvas, 0, 0, Right, Bottom, LineCount,
    MaxWidth, Words, 100);
  if FXOffset > Round(Right / 2) then
  begin
    SetLeft(GetX);
    FExtentX := Round(Right / 2) + FXOffset;
    FBodyX := Round((FBalloonLineWidth - Right) / 2) + FXOffset;
    FTipX := Round(FBalloonLineWidth / 2);
  end;
  if (FXOffset <= Round(Right / 2)) and (FXOffset > -Round(Right / 2)) then
  begin
    SetLeft(GetX + FXOffset - Round(Right / 2));
    FExtentX := Right;
    FBodyX := Round(FBalloonLineWidth / 2);
    FTipX := Round((Right + FBalloonLineWidth) / 2) - FXOffset;
  end;
  if FXOffset <= -Round(Right / 2) then
  begin
    SetLeft(GetX + FXOffset - Round(Right / 2));
    FExtentX := Round(Right / 2) - FXOffset;
    FBodyX := Round(FBalloonLineWidth / 2);
    FTipX := Round((Right + FBalloonLineWidth) / 2) - FXOffset;
  end;
  if FYOffset > Bottom then
  begin
    SetTop(GetY);
    FExtentY := FYOffset;
    FBodyY := Round(FBalloonLineWidth / 2) + (FYOffset - Bottom);
    FTipY := Round(FBalloonLineWidth / 2);
  end;
  if (FYOffset <= Bottom) and (FYOffset > 0) then
  begin
    SetTop(GetY + FYOffset - Bottom);
    FExtentY := Bottom;
    FBodyY := Round(FBalloonLineWidth / 2);
    FTipY := Round(FBalloonLineWidth / 2) + (Bottom - FYOffset);
  end;
  if FYOffset <= 0 then
  begin
    SetTop(GetY + FYOffset - Bottom);
    FExtentY := Bottom - FYOffset;
    FBodyY := Round(FBalloonLineWidth / 2);
    FTipY := Round(FBalloonLineWidth / 2) + (Bottom - FYOffset);
  end;
  SetLeft(GetLeft - Round(FBalloonLineWidth / 2));
  SetTop(GetTop - Round(FBalloonLineWidth / 2));
  Inc(FExtentX, FBalloonLineWidth);
  Inc(FExtentY, FBalloonLineWidth);
  FSpriteBox.Canvas.Font := OldFont;
end;

{ @00465C08 }
procedure TTextBalloon.SetBalloonLineWidth(Value: Integer);
begin
  if Value <> FBalloonLineWidth then
    FBalloonLineWidth := Value;
end;

{ @00465C18 }
procedure TTextBalloon.SetRoundCorner(Value: Boolean);
begin
  if Value <> FRoundCorner then
    FRoundCorner := Value;
end;

{ @00465C28 }
procedure TTextBalloon.SetXOffset(Value: Integer);
begin
  if Value <> FXOffset then
  begin
    FXOffset := Value;
    UpdateLayout;
  end;
end;

{ @00465C3C }
procedure TTextBalloon.SetYOffset(Value: Integer);
begin
  if Value <> FYOffset then
  begin
    FYOffset := Value;
    UpdateLayout;
  end;
end;

{ @00465C50 }
procedure TTextBalloon.SetSpriteBox(Value: TSpriteBox);
begin
  if Value <> FSpriteBox then
  begin
    if FSpriteBox <> nil then
      FSpriteBox.RemovePixie(Self);
    FSpriteBox := Value;
    if FSpriteBox <> nil then
      FSpriteBox.AddPixie(Self);
    UpdateLayout;
  end;
end;

{ @00465C84 }
procedure TTextBalloon.SetSideColor(Value: TColor);
begin
  if Value <> FSideColor then
    FSideColor := Value;
end;

{ @00465C90 }
procedure TTextBalloon.SetBackGroundColor(Value: TColor);
begin
  if Value <> FBackGroundColor then
    FBackGroundColor := Value;
end;

{ @00465C9C  balloon body (Left, Top, Right, Bottom) with a pointer towards
  (TipX, TipY), as one polygon; rounded corners get N extra points each }
procedure TTextBalloon.DrawBalloon(Canvas: TCanvas; Left, Top, Right, Bottom,
  TipX, TipY: Integer);
var
  Radius, N: Integer;
  HalfW, HalfH: Integer;
  Slope, A, B: Double;
  Tip: TPoint;
  Order: TCornerOrder;
  Points: array[0..70] of TPoint;
  I, K: Integer;
begin
  Canvas.Pen.Width := FBalloonLineWidth;
  Canvas.Pen.Color := FSideColor;
  Canvas.Brush.Color := FBackGroundColor;
  Radius := 10;
  if FRoundCorner then
    N := IMin(15, Round(Radius / 2))
  else
    N := 0;
  HalfW := Round((Right - Left) / 2);
  HalfH := Round((Bottom - Top) / 2);
  { the diagonals of the body: Y = X * Slope + A and Y = -X * Slope + B }
  Slope := (Bottom - Top) / (Right - Left);
  A := Top - Left * Slope;
  B := Bottom + Left * Slope;
  Tip.X := TipX;
  Tip.Y := TipY;
  Points[1].X := TipX;
  Points[1].Y := TipY;
  { pointer on the left side }
  if (TipX * Slope + A < TipY) and (TipY < -Slope * TipX + B) then
  begin
    Move(CornerOrderLeft, Order, SizeOf(Order));
    Points[0].X := Left;
    Points[2].X := Left;
    if Top + HalfH < TipY then
    begin
      Points[0].Y := Top + HalfH;
      Points[2].Y := Top + HalfH + Radius;
    end
    else
    begin
      Points[0].Y := Top + HalfH - Radius;
      Points[2].Y := Top + HalfH;
    end;
  end;
  { right side }
  if (TipY < TipX * Slope + A) and (TipY > -Slope * TipX + B) then
  begin
    Move(CornerOrderRight, Order, SizeOf(Order));
    Points[0].X := Right;
    Points[2].X := Right;
    if Top + HalfH < TipY then
    begin
      Points[2].Y := Top + HalfH;
      Points[0].Y := Top + HalfH + Radius;
    end
    else
    begin
      Points[2].Y := Top + HalfH - Radius;
      Points[0].Y := Top + HalfH;
    end;
  end;
  { top side }
  if ((TipY - A) / Slope <= TipX) and (TipX <= -(TipY - B) / Slope) then
  begin
    Move(CornerOrderTop, Order, SizeOf(Order));
    Points[0].Y := Top;
    Points[2].Y := Top;
    if TipX > Left + HalfW then
    begin
      Points[2].X := Left + HalfW;
      Points[0].X := Left + HalfW + Radius;
    end
    else
    begin
      Points[2].X := Left + HalfW - Radius;
      Points[0].X := Left + HalfW;
    end;
  end;
  { bottom side }
  if (TipX <= (TipY - A) / Slope) and (TipX >= -(TipY - B) / Slope) then
  begin
    Move(CornerOrderBottom, Order, SizeOf(Order));
    Points[0].Y := Bottom;
    Points[2].Y := Bottom;
    if TipX > Left + HalfW then
    begin
      Points[0].X := Left + HalfW;
      Points[2].X := Left + HalfW + Radius;
    end
    else
    begin
      Points[0].X := Left + HalfW - Radius;
      Points[2].X := Left + HalfW;
    end;
  end;
  { tip inside the body: no pointer }
  if PtInRect(Rect(Left, Top, Right, Bottom), Tip) then
    Points[1] := Points[0];
  { bottom right corner }
  Points[Order[0] + (Order[0] - 2) div 2 * N].X := Right - Radius;
  Points[Order[0] + (Order[0] - 2) div 2 * N].Y := Bottom;
  for I := 1 to N do
  begin
    K := Order[0] + I + (Order[0] - 2) div 2 * N;
    Points[K].X := Round(Sin(I * (Pi / 2) / (N + 1)) * Radius) + (Right - Radius);
    Points[K].Y := Round(Cos(I * (Pi / 2) / (N + 1)) * Radius) + (Bottom - Radius);
  end;
  Points[Order[1] + (Order[1] - 2) div 2 * N].X := Right;
  Points[Order[1] + (Order[1] - 2) div 2 * N].Y := Bottom - Radius;
  { top right corner }
  Points[Order[2] + (Order[2] - 2) div 2 * N].X := Right;
  Points[Order[2] + (Order[2] - 2) div 2 * N].Y := Top + Radius;
  for I := 1 to N do
  begin
    K := Order[2] + I + (Order[2] - 2) div 2 * N;
    Points[K].X := Round(Cos(I * (Pi / 2) / (N + 1)) * Radius) + (Right - Radius);
    Points[K].Y := Top + Radius - Round(Sin(I * (Pi / 2) / (N + 1)) * Radius);
  end;
  Points[Order[3] + (Order[3] - 2) div 2 * N].X := Right - Radius;
  Points[Order[3] + (Order[3] - 2) div 2 * N].Y := Top;
  { top left corner }
  Points[Order[4] + (Order[4] - 2) div 2 * N].X := Left + Radius;
  Points[Order[4] + (Order[4] - 2) div 2 * N].Y := Top;
  for I := 1 to N do
  begin
    K := Order[4] + I + (Order[4] - 2) div 2 * N;
    Points[K].X := Left + Radius - Round(Sin(I * (Pi / 2) / (N + 1)) * Radius);
    Points[K].Y := Top + Radius - Round(Cos(I * (Pi / 2) / (N + 1)) * Radius);
  end;
  Points[Order[5] + (Order[5] - 2) div 2 * N].X := Left;
  Points[Order[5] + (Order[5] - 2) div 2 * N].Y := Top + Radius;
  { bottom left corner }
  Points[Order[6] + (Order[6] - 2) div 2 * N].X := Left;
  Points[Order[6] + (Order[6] - 2) div 2 * N].Y := Bottom - Radius;
  for I := 1 to N do
  begin
    K := Order[6] + I + (Order[6] - 2) div 2 * N;
    Points[K].X := Left + Radius - Round(Cos(I * (Pi / 2) / (N + 1)) * Radius);
    Points[K].Y := Round(Sin(I * (Pi / 2) / (N + 1)) * Radius) + (Bottom - Radius);
  end;
  Points[Order[7] + (Order[7] - 2) div 2 * N].X := Left + Radius;
  Points[Order[7] + (Order[7] - 2) div 2 * N].Y := Bottom;
  Canvas.Polygon(Slice(Points, N * 4 + 11));
end;

{ @0046663C }
procedure TTextBalloon.Draw(Surface: TSurface; DX, DY: Integer; ClipRect: TRect;
  Scale: Double);
begin
  DrawDC(Surface.GetCanvas.Handle, DX, DY, ClipRect, Scale);
end;

{ @00466688  splits Text into LineCount lines (Words); returns the ratio of
  the widest line to the line height (0: no text, -1: fewer words than lines) }
function TTextBalloon.LineRatio(LineCount: Integer; Text: string; Canvas: TCanvas;
  var MaxWidth: Integer; var Words: TLineWords; MaxLines: Integer): Double;
var
  S, Word: string;
  SpaceWidth, LineHeight, WordCount: Integer;
  WordWidths: array[0..100] of Integer;
  LineWidths: array[0..100] of Integer;
  Counts: array[0..100] of Integer;
  BestCounts: array[0..100] of Integer;
  Rest, Total, Count, Width, Widest: Integer;
  I, J, K, MinLine, MaxLine, BestWidest: Integer;
  Ratio, BestRatio: Double;
  Done: Boolean;
begin
  { NOTE: MaxLines is not used }
  S := Text;
  SpaceWidth := Canvas.TextWidth(' ');
  LineHeight := Round(FFont.Size * (LineCount + 0.5 + (LineCount - 1) * 0.75));
  WordCount := 0;
  while S <> '' do
  begin
    SplitFirst(S, ' ', Word);
    WordWidths[WordCount] := Canvas.TextWidth(Word);
    Inc(WordCount);
  end;
  if WordCount = 0 then
    Result := 0
  else if WordCount < LineCount then
    Result := -1
  else if WordCount > 15 then
  begin
    { many words: spread them evenly over the lines }
    Rest := WordCount;
    Total := 0;
    for I := 0 to LineCount - 2 do
    begin
      Count := Round(Rest / (LineCount - I));
      Words[I] := Count;
      Inc(Total, Count);
      Dec(Rest, Count);
    end;
    Words[LineCount - 1] := WordCount - Total;
    K := 0;
    Widest := -1;
    for I := 0 to LineCount - 1 do
    begin
      Width := 0;
      for J := 0 to Words[I] - 1 do
      begin
        if J > 0 then
          Inc(Width, SpaceWidth);
        Inc(Width, WordWidths[K]);
        Inc(K);
      end;
      if Width > Widest then
        Widest := Width;
    end;
    MaxWidth := Widest;
    Result := Widest / LineHeight;
  end
  else
  begin
    { few words: try every split and keep the most even one }
    BestRatio := -1;
    Counts[0] := WordCount;
    for I := 1 to LineCount - 1 do
      Counts[I] := 0;
    Done := False;
    while not Done do
    begin
      K := 0;
      for I := 0 to LineCount - 1 do
      begin
        LineWidths[I] := 0;
        for J := 0 to Counts[I] - 1 do
        begin
          Inc(LineWidths[I], WordWidths[K]);
          if J > 0 then
            Inc(LineWidths[I], SpaceWidth);
          Inc(K);
        end;
      end;
      MinLine := 0;
      MaxLine := 0;
      for I := 0 to LineCount - 1 do
      begin
        if LineWidths[MaxLine] < LineWidths[I] then
          MaxLine := I;
        if LineWidths[I] < LineWidths[MinLine] then
          MinLine := I;
      end;
      Ratio := LineWidths[MinLine] / LineWidths[MaxLine];
      if Ratio > BestRatio then
      begin
        BestRatio := Ratio;
        for I := 0 to LineCount - 1 do
        begin
          BestCounts[I] := Counts[I];
          BestWidest := LineWidths[MaxLine];
        end;
      end;
      { next split }
      I := LineCount - 2;
      while (I >= 0) and (Counts[I] = 0) do
        Dec(I);
      if I = -1 then
        Done := True
      else
      begin
        Dec(Counts[I]);
        Inc(Counts[I + 1]);
        for J := I + 2 to LineCount - 1 do
        begin
          Inc(Counts[I + 1], Counts[J]);
          Counts[J] := 0;
        end;
      end;
    end;
    Result := BestWidest / LineHeight;
    MaxWidth := BestWidest;
    for I := 0 to LineCount - 1 do
      Words[I] := BestCounts[I];
  end;
end;

{ @00466A58  chooses the number of lines whose block ratio is closest to
  sqrt(2) and returns the balloon body (Left, Top)-(Right, Bottom) }
procedure TTextBalloon.FitText(Text: string; Canvas: TCanvas; Left, Top: Integer;
  var Right, Bottom, LineCount, MaxWidth: Integer; var Words: TLineWords;
  MaxLines: Integer);
var
  N, Margin: Integer;
  Ratio, BestDiff: Double;
begin
  N := 0;
  Ratio := 10;
  BestDiff := 10000;
  while Ratio <> -1 do
  begin
    Inc(N);
    Ratio := LineRatio(N, Text, Canvas, MaxWidth, Words, MaxLines);
    if Ratio = 0 then
    begin
      LineCount := 0;
      Right := Left + 50;
      Bottom := Top + 36;
      Exit;
    end;
    if (Abs(Sqrt(2) - Ratio) < BestDiff) and (Ratio <> -1) then
      BestDiff := Abs(Sqrt(2) - Ratio)
    else
    begin
      LineCount := N - 1;
      Break;
    end;
  end;
  Ratio := LineRatio(LineCount, Text, Canvas, MaxWidth, Words, MaxLines);
  Margin := 20;
  Right := Round(MaxWidth + Left + Margin);
  Bottom := Round(MaxWidth / Ratio + Top + Margin);
end;

{ @00466DE8 }
procedure TTextBalloon.DrawDC(DC: HDC; DX, DY: Integer; ClipRect: TRect;
  Scale: Double);
var
  Words: TLineWords;
  Canvas: TCanvas;
  MaxWidth: Integer;
  BodyLeft, BodyTop: Integer;
  BodyRight, BodyBottom, LineCount: Integer;
  TipX, TipY: Integer;
  OldFont: TFont;

  { @00466BD4 }
  procedure DrawLines(LineCount: Integer; Text: string);
  var
    Lines: TStringList;
    S, Line, Word: string;
    I, J, Margin, X: Integer;
  begin
    Lines := TStringList.Create;   { NOTE: never freed }
    S := Text;
    Line := '';
    for I := 0 to LineCount - 1 do
    begin
      Line := '';
      for J := 1 to Words[I] do
        if Line <> '' then
        begin
          SplitFirst(S, ' ', Word);
          Line := Line + ' ' + Word;
        end
        else
        begin
          SplitFirst(S, ' ', Word);
          Line := Line + Word;
        end;
      Lines.Add(Line);
    end;
    Margin := 10;
    Canvas.Brush.Style := bsClear;
    for I := 0 to LineCount - 1 do
    begin
      X := Round((MaxWidth - Canvas.TextWidth(Lines[I])) / 2);
      Canvas.TextOut(BodyLeft + X + Margin,
        Round(Canvas.Font.Size * (I * 1.75) + (BodyTop + Margin)), Lines[I]);
    end;
  end;

begin
  Canvas := TCanvas.Create;
  Canvas.Handle := DC;
  BodyLeft := FBodyX + DX;
  BodyTop := FBodyY + DY;
  TipX := DX + FTipX;
  TipY := DY + FTipY;
  OldFont := Canvas.Font;
  Canvas.Font := FFont;
  FitText(FBalloonText, Canvas, BodyLeft, BodyTop, BodyRight, BodyBottom,
    LineCount, MaxWidth, Words, 100);
  DrawBalloon(Canvas, BodyLeft, BodyTop, BodyRight, BodyBottom, TipX, TipY);
  DrawLines(LineCount, FBalloonText);
  Canvas.Font := OldFont;
  Canvas.Free;
end;

{ @00466F1C }
procedure TTextBalloon.SetX(Value: Integer);
begin
  FX := Value;
  UpdateLayout;
end;

{ @00466F28 }
procedure TTextBalloon.SetY(Value: Integer);
begin
  FY := Value;
  UpdateLayout;
end;

{ @00466F34 }
procedure TTextBalloon.SetZ(Value: Integer);
begin
  if Value <> GetZ then
  begin
    inherited SetZ(Value);
    if FSpriteBox <> nil then
      FSpriteBox.UpdateZOrder(Self);
  end;
end;

{ @00466F60 }
function TTextBalloon.GetX: Integer;
begin
  Result := FX;
end;

{ @00466F68 }
function TTextBalloon.GetY: Integer;
begin
  Result := FY;
end;

{ The finalization at @00466F70 is the empty compiler-generated stub. }

end.

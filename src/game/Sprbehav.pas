unit Sprbehav;

{ Sprite behaviours that make a sprite act like a standard control: a push
  button, check box, radio button, multi-line memo or static text, plus a
  behaviour that switches the mouse cursor while the mouse is over a sprite.
  TCtrlForm (Uctrl) uses ControlToBehaviour to replace the controls on a form
  by sprites carrying these behaviours.
  Decompiled from ROS.exe v1.1, code 0046FFC8-0047216C. }

{$I zm.inc}
{$R+}   { the original was compiled with range checking on (@BoundErr calls) }

interface

uses
  Windows, Classes, Graphics, Controls, Forms, StdCtrls,
  uSurface, uPixie, Sprframe, uSprite, uSpritebox;

type
  { Sets the screen cursor while the mouse is over the sprite and restores
    the previous cursor when it leaves (unless it went to another sprite that
    has a TBehavCursor too). }
  TBehavCursor = class(TBehaviour)
  private
    FOldCursor: TCursor;                    { +0x20 }
    FCursor: TCursor;                       { +0x22 }
    FInside: Boolean;                       { +0x24 }
  public
    constructor Create(ACursor: TCursor);
    procedure MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave(Sender: TObject); override;
    property Cursor: TCursor read FCursor write FCursor;
    property OldCursor: TCursor read FOldCursor;
    property Inside: Boolean read FInside;
  end;

  { Common base: a sprite with StateCount states that shows one of four frames
    per state (hover, normal, pressed, pressed-but-mouse-outside) and fires
    OnClick when the mouse is released over it. Optional sequences (animations)
    can be played on mouse enter/leave/down/up instead of a frame change. }
  TBehavControl = class(TBehaviour)
  private
    FFrames: TStringList;                   { +0x20  4 frame names per state }
    FPressed: Boolean;                      { +0x24 }
    FSeqHover: string;                      { +0x28  looped while the mouse is over }
    FSeqLeave: string;                      { +0x2C  played once when the mouse leaves }
    FSeqEnter: string;                      { +0x30  played once when the mouse enters }
    FSeqDown: string;                       { +0x34  played once on mouse down }
    FSeqUp: string;                         { +0x38  played once on mouse up }
    FEnterPlayed: Boolean;                  { +0x3C  FSeqEnter was started }
    FDown: Boolean;                         { +0x3D }
    FHover: Boolean;                        { +0x3E }
    FState: Integer;                        { +0x40 }
    FStateCount: Integer;                   { +0x44 }
    FOnClick: TNotifyEvent;                 { +0x48 }
    procedure SetDown(Value: Boolean);
    procedure SetHover(Value: Boolean);
    function GetFrameName: string;
    procedure UpdateFrame;
  protected
    procedure SetState(Value: Integer); virtual;
  public
    constructor Create(AStateCount: Integer; Frames: array of string);
    procedure FinishSequence(Sender: TObject; var RepeatCount: Integer); override;
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseLeave(Sender: TObject); override;
    procedure SetActive(Value: Boolean); override;
    property Frames: TStringList read FFrames;
    property Pressed: Boolean read FPressed;
    property Down: Boolean read FDown;
    property Hover: Boolean read FHover;
    property State: Integer read FState write SetState;
    property StateCount: Integer read FStateCount;
    property SeqHover: string read FSeqHover write FSeqHover;
    property SeqLeave: string read FSeqLeave write FSeqLeave;
    property SeqEnter: string read FSeqEnter write FSeqEnter;
    property SeqDown: string read FSeqDown write FSeqDown;
    property SeqUp: string read FSeqUp write FSeqUp;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  { Two states: unchecked (0) and checked (1). }
  TBehavCheckBox = class(TBehavControl)
  private
    FReserved50: Integer;                   { +0x50  never referenced }
    FReserved54: Integer;                   { +0x54  never referenced }
    procedure SetChecked(Value: Boolean);
    function GetChecked: Boolean;
  public
    constructor Create(AUnchecked, AChecked, AUncheckedDown, ACheckedDown: string);
    procedure CheckBoxClick(Sender: TObject);
    property Checked: Boolean read GetChecked write SetChecked;
  end;

  { A check box that unchecks every other radio button behaviour in the
    sprite box when it gets checked, and cannot be unchecked by clicking. }
  TBehavRadioButton = class(TBehavCheckBox)
  private
    FGroup: string;                         { +0x58  name of the original parent control }
  protected
    procedure SetState(Value: Integer); override;
  public
    constructor Create(AUnchecked, AChecked, AUncheckedDown, ACheckedDown,
      AGroup: string);
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    property Group: string read FGroup write FGroup;
  end;

  { One state; frames Up/Down and optionally Over (mouse hover). }
  TBehavButton = class(TBehavControl)
  public
    constructor Create(AUp, ADown: string); overload;
    constructor Create(AUp, ADown, AOver: string); overload;
  end;

  { Draws the lines of a (hidden) TMemo on the sprite, with a TScrollBar on
    the sprite box when the text does not fit. A '^' in the text toggles bold. }
  TBehavMemo = class(TBehavControl)
  private
    FMemo: TMemo;                           { +0x50 }
    FReserved54: Integer;                   { +0x54  never referenced }
    FReserved58: Integer;                   { +0x58  never referenced }
    FScrollBar: TScrollBar;                 { +0x5C }
    FOffset: TPoint;                        { +0x60 }
  public
    constructor Create(AMemo: TMemo);
    destructor Destroy; override;
    procedure SetActive(Value: Boolean); override;
    procedure Move(Sender: TObject; var X, Y, Z: Integer); override;
    procedure MemoChange(Sender: TObject);
    procedure AfterBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
      Where: TRect; Size: Real); override;
    property Memo: TMemo read FMemo;
    property ScrollBar: TScrollBar read FScrollBar;
    property Offset: TPoint read FOffset write FOffset;
  end;

  { A text drawn by TBehavText. Align is 'l', 'r' or 'c'. }
  TCaption = class(TObject)
  private
    FText: string;                          { +0x04 }
    FFont: TFont;                           { +0x08 }
    FLeft: Integer;                         { +0x0C }
    FTop: Integer;                          { +0x10 }
    FAlign: Char;                           { +0x14 }
  public
    constructor Create(AText, AFontName: string; ASize: Integer; AColor: TColor;
      ALeft, ATop: Integer; AAlign: Char);
    property Text: string read FText write FText;
    property Font: TFont read FFont;
    property Left: Integer read FLeft write FLeft;
    property Top: Integer read FTop write FTop;
    property Align: Char read FAlign write FAlign;
  end;

  { Draws a caption on the sprite after it is blitted. Captions can be set per
    frame name (Captions); otherwise the Default caption is drawn. }
  TBehavText = class(TBehaviour)
  private
    FCaptions: TStringList;                 { +0x20  frame name -> TCaption, sorted }
    FDefault: TCaption;                     { +0x24 }
  public
    constructor Create(AFontName: string; ASize: Integer; AColor: TColor);
    destructor Destroy; override;
    procedure SetCaption(FrameName, Text: string);
    procedure AfterBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
      Where: TRect; Size: Real); override;
    property Captions: TStringList read FCaptions;
    property DefaultCaption: TCaption read FDefault;
  end;

function AddTextBehaviour(Sprite: TSprite; Text: string; X, Y: Integer;
  Font: TFont): TCaption;
procedure ControlToBehaviour(Sprite: TSprite; Control: TControl);

implementation

uses
  uString;

{ ---------------------------------------------------------------- TBehavControl }

{ @0047048C }
constructor TBehavControl.Create(AStateCount: Integer; Frames: array of string);
var
  I: Integer;
begin
  inherited Create;
  FOnClick := OnClick;   { NOTE: assigns the event to itself (no-op in the original) }
  FStateCount := AStateCount;
  FFrames := TStringList.Create;
  for I := 0 to High(Frames) do
    FFrames.Add(Frames[I]);
  FPressed := False;
  FDown := False;
  FHover := False;
  FState := 0;
end;

{ @0047058C }
procedure TBehavControl.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not PtInRect(Rect(0, 0, Sprite.Width, Sprite.Height), Point(X, Y)) then
    SetHover(False)
  else
    SetHover(True);
end;

{ @004705F4 }
procedure TBehavControl.MouseLeave(Sender: TObject);
begin
  SetHover(False);
end;

{ @004705FC }
procedure TBehavControl.MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  SetDown(True);
  FPressed := True;
  Sprite.SetMouseCapture(True);
end;

{ @00470620 }
procedure TBehavControl.MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  FPressed := False;
  SetDown(False);
  Sprite.SetMouseCapture(False);
  if PtInRect(Rect(0, 0, Sprite.Width, Sprite.Height), Point(X, Y)) then
  begin
    SetState((FState + 1) mod FStateCount);
    if Assigned(FOnClick) then
      FOnClick(Self);
  end
  else
    SetHover(False);
end;

{ @004706B4 }
procedure TBehavControl.SetActive(Value: Boolean);
begin
  inherited SetActive(Value);
  if Value then
    UpdateFrame;
end;

{ @004706D4 }
procedure TBehavControl.SetDown(Value: Boolean);
begin
  if Value <> FDown then
  begin
    FDown := Value;
    Sprite.StopSequence;
    if FDown and (FSeqDown <> '') then
      Sprite.PlaySequence(FSeqDown, 1)
    else if not FDown and (FSeqUp <> '') then
      Sprite.PlaySequence(FSeqUp, 1)
    else
      UpdateFrame;
  end;
end;

{ @0047072C }
procedure TBehavControl.SetHover(Value: Boolean);
begin
  if Value <> FHover then
  begin
    FHover := Value;
    Sprite.StopSequence;
    if FHover and (FSeqHover + FSeqEnter <> '') then
    begin
      if FSeqEnter <> '' then
      begin
        Sprite.PlaySequence(FSeqEnter, 1);
        FEnterPlayed := True;
      end
      else
        Sprite.PlaySequence(FSeqHover, -1);
    end
    else if not FHover and (FSeqLeave <> '') then
      Sprite.PlaySequence(FSeqLeave, 1)
    else
      UpdateFrame;
  end;
end;

{ @004707E0 }
procedure TBehavControl.FinishSequence(Sender: TObject; var RepeatCount: Integer);
begin
  { NOTE: FEnterPlayed is never reset }
  if FEnterPlayed then
    if (Sprite.CurSequence.Name = FSeqEnter) and (FSeqHover <> '') then
      Sprite.PlaySequence(FSeqHover, -1);
end;

{ @00470850 }
procedure TBehavControl.SetState(Value: Integer);
begin
  if Value <> FState then
  begin
    FState := Value;
    UpdateFrame;
  end;
end;

{ @00470860 }
function TBehavControl.GetFrameName: string;
var
  Index: Integer;
begin
  Index := FState * 4;
  if FDown then
  begin
    if FHover then
      Inc(Index, 2)
    else
      Inc(Index, 3);
  end
  else if not FHover then
    Inc(Index);
  Result := FFrames[Index];
end;

{ @0047089C }
procedure TBehavControl.UpdateFrame;
begin
  Sprite.CurrentFrame := GetFrameName;
  Sprite.Redraw;
end;

{ --------------------------------------------------------------- TBehavCheckBox }

{ @0047091C }
constructor TBehavCheckBox.Create(AUnchecked, AChecked, AUncheckedDown,
  ACheckedDown: string);
begin
  inherited Create(2, [AUnchecked, AUnchecked, AUncheckedDown, AUnchecked,
    AChecked, AChecked, ACheckedDown, AChecked]);
end;

{ @004709F4 }
procedure TBehavCheckBox.CheckBoxClick(Sender: TObject);
begin
  SetChecked((Sender as TCheckBox).Checked);
end;

{ @00470A1C }
procedure TBehavCheckBox.SetChecked(Value: Boolean);
begin
  if Value then
    SetState(1)
  else
    SetState(0);
end;

{ @00470A34 }
function TBehavCheckBox.GetChecked: Boolean;
begin
  Result := FState <> 0;
end;

{ ------------------------------------------------------------ TBehavRadioButton }

{ @00470A3C }
constructor TBehavRadioButton.Create(AUnchecked, AChecked, AUncheckedDown,
  ACheckedDown, AGroup: string);
begin
  inherited Create(AUnchecked, AChecked, AUncheckedDown, ACheckedDown);
  FGroup := AGroup;
end;

{ @00470AF8 }
procedure TBehavRadioButton.MouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  WasChecked: Boolean;
begin
  WasChecked := GetChecked;
  inherited MouseUp(Sender, Button, Shift, X, Y);
  if WasChecked and not GetChecked then
    SetChecked(True);
end;

{ @00470B48 }
procedure TBehavRadioButton.SetState(Value: Integer);
var
  Box: TSpriteBox;
  Behaviours: TBehaviourList;
  B: TBehaviour;
  I, J: Integer;
begin
  inherited SetState(Value);
  if GetChecked then
  begin
    { NOTE: FGroup is not used; every radio button in the sprite box is unchecked }
    Box := Sprite.SpriteBox;
    for I := 0 to Box.Count - 1 do
    begin
      Behaviours := (Box.Items[I] as TSprite).Behaviours;
      for J := 0 to Behaviours.Count - 1 do
      begin
        B := Behaviours.Items[J];
        if (B is TBehavRadioButton) and (B <> Self) then
          (B as TBehavRadioButton).SetChecked(False);
      end;
    end;
  end;
end;

{ ----------------------------------------------------------------- TBehavCursor }

{ @00470C08 }
constructor TBehavCursor.Create(ACursor: TCursor);
begin
  inherited Create;
  FCursor := ACursor;
  FInside := False;
end;

{ @00470C4C }
procedure TBehavCursor.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if Active and not FInside then
  begin
    FInside := True;
    if Sprite.SpriteBox <> nil then
      FOldCursor := Sprite.SpriteBox.Cursor
    else
      FOldCursor := Screen.Cursor;
    Screen.Cursor := FCursor;
  end;
end;

{ @00470C9C }
procedure TBehavCursor.MouseLeave(Sender: TObject);
var
  OtherInside: Boolean;
  Box: TSpriteBox;
  Behaviours: TBehaviourList;
  B: TBehaviour;
  I, J: Integer;
begin
  if Active then
  begin
    FInside := False;
    OtherInside := False;
    Box := Sprite.SpriteBox;
    for I := 0 to Box.Count - 1 do
      if Box.Items[I] is TSprite then
      begin
        Behaviours := (Box.Items[I] as TSprite).Behaviours;
        for J := 0 to Behaviours.Count - 1 do
        begin
          B := Behaviours.Items[J];
          if (B is TBehavCursor) and (B <> Self) then
            if (B as TBehavCursor).FInside then
              OtherInside := True;
        end;
      end;
    if not OtherInside then
      Screen.Cursor := FOldCursor;
  end;
end;

{ ----------------------------------------------------------------- TBehavButton }

{ @00470DA0 }
constructor TBehavButton.Create(AUp, ADown: string);
begin
  inherited Create(1, [AUp, AUp, ADown, AUp]);
end;

{ @00470E4C }
constructor TBehavButton.Create(AUp, ADown, AOver: string);
begin
  if AUp = '' then
    AUp := ADown;
  if ADown = '' then
    ADown := AUp;
  if AOver = '' then
    Create(AUp, ADown)
  else
    inherited Create(1, [AOver, AUp, ADown, AUp]);
end;

{ --------------------------------------------------------------------- TCaption }

{ @00470F3C }
constructor TCaption.Create(AText, AFontName: string; ASize: Integer;
  AColor: TColor; ALeft, ATop: Integer; AAlign: Char);
begin
  inherited Create;
  FText := AText;
  FFont := TFont.Create;
  FFont.Name := AFontName;
  FFont.Size := ASize;
  FFont.Color := AColor;
  FLeft := ALeft;
  FTop := ATop;
  FAlign := AAlign;
end;

{ ------------------------------------------------------------------- TBehavText }

{ @00471010 }
constructor TBehavText.Create(AFontName: string; ASize: Integer; AColor: TColor);
begin
  inherited Create;
  FDefault := TCaption.Create('', AFontName, ASize, AColor, 0, 0, 'l');
  FCaptions := TStringList.Create;
  FCaptions.Sorted := True;
end;

{ @004710C4 }
destructor TBehavText.Destroy;
begin
  { NOTE: the TCaption objects in FCaptions (and their fonts) are not freed }
  FCaptions.Free;
  FDefault.Free;
  inherited Destroy;
end;

{ @004710FC }
procedure TBehavText.SetCaption(FrameName, Text: string);
var
  Index: Integer;
begin
  if FCaptions.Find(FrameName, Index) then
    (FCaptions.Objects[Index] as TCaption).FText := Text
  else
    FCaptions.AddObject(FrameName, TCaption.Create(Text, FDefault.FFont.Name,
      FDefault.FFont.Size, FDefault.FFont.Color, FDefault.FLeft, FDefault.FTop,
      FDefault.FAlign));
end;

{ @004711E0 }
procedure TBehavText.AfterBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
  Where: TRect; Size: Real);
var
  Spr: TSprite;
  XPos: Integer;
  OldStyle: TBrushStyle;
  Index: Integer;
  Cap: TCaption;
begin
  Spr := Sender as TSprite;
  Index := FCaptions.IndexOf(Spr.CurrentFrame);
  if Index > -1 then
    Cap := FCaptions.Objects[Index] as TCaption
  else
    Cap := FDefault;
  if Cap.FText <> '' then
  begin
    { NOTE: XPos stays undefined for an Align other than 'l', 'r', 'c' }
    case Cap.FAlign of
      'l': XPos := X + Cap.FLeft;
      'r': XPos := Spr.Width + X - Surface.TextWidth(Cap.FFont, Cap.FText) - Cap.FLeft;
      'c': XPos := (Spr.Width - Surface.TextWidth(Cap.FFont, Cap.FText)) div 2 + X;
    end;
    OldStyle := Surface.Canvas.Brush.Style;
    Surface.Canvas.Brush.Style := bsClear;
    Surface.TextOut(XPos, Y + Cap.FTop, Cap.FFont, Cap.FText);
    Surface.Canvas.Brush.Style := OldStyle;
  end;
end;

{ ------------------------------------------------------------------- TBehavMemo }

{ @00471354 }
constructor TBehavMemo.Create(AMemo: TMemo);
begin
  inherited Create(1, ['', '', '', '']);
  FOffset := Point(0, 0);
  FMemo := AMemo;
  FMemo.OnChange := MemoChange;
end;

{ @004713E4 }
destructor TBehavMemo.Destroy;
begin
  if FScrollBar <> nil then
  begin
    FScrollBar.Visible := False;
    FScrollBar.Free;
    FScrollBar := nil;
  end;
  FMemo.OnChange := nil;
  inherited Destroy;
end;

{ @00471438 }
procedure TBehavMemo.SetActive(Value: Boolean);
begin
  if Value then
  begin
    FScrollBar := TScrollBar.Create(Sprite.SpriteBox);
    FScrollBar.Left := Screen.Width + 1;
    FScrollBar.Top := Screen.Height + 1;
    FScrollBar.Parent := Sprite.SpriteBox;
    FScrollBar.Kind := sbVertical;
    FScrollBar.OnChange := MemoChange;
    FScrollBar.Visible := False;
  end
  else
  begin
    FScrollBar.Free;
    FScrollBar := nil;
  end;
  inherited SetActive(Value);
end;

{ @004714D8 }
procedure TBehavMemo.Move(Sender: TObject; var X, Y, Z: Integer);
begin
  if not Sprite.Showing then
    FScrollBar.Visible := False;
  FScrollBar.BoundsRect := Bounds(X - Sprite.HotSpotX + Sprite.Width,
    Y - Sprite.HotSpotY, FScrollBar.Width, Sprite.Height);
end;

{ @00471554 }
procedure TBehavMemo.MemoChange(Sender: TObject);
begin
  with Sprite do
    SpriteBox.InvalidateRect(BoundsRect);
end;

{ @004715E8 }
procedure TBehavMemo.AfterBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
  Where: TRect; Size: Real);
var
  CurX, I, TopLine, LineHeight, MaxPos, LargeStep, VisibleLines: Integer;
  TextSize: TSize;
  DC: HDC;
  OldFont: HGDIOBJ;
  OldBrushStyle: TBrushStyle;
  OldFontStyle: TFontStyles;
  Line, Part: string;
  Toggle: Boolean;

  { @00471578 }
  procedure ToggleBold;
  begin
    if fsBold in FMemo.Font.Style then
      FMemo.Font.Style := FMemo.Font.Style - [fsBold]
    else
      FMemo.Font.Style := FMemo.Font.Style + [fsBold];
  end;

begin
  DC := GetDC(FMemo.Handle);
  OldFont := SelectObject(DC, FMemo.Font.Handle);
  if GetTextExtentPoint(DC, 'jl', 2, TextSize) then
    LineHeight := TextSize.cy
  else
    LineHeight := 8;
  SelectObject(DC, OldFont);
  ReleaseDC(FMemo.Handle, DC);

  if FMemo.Lines.Count * LineHeight > Sprite.Height then
  begin
    FScrollBar.Visible := True;
    with FScrollBar do
    begin
      MaxPos := ((FMemo.Lines.Count + 1) * LineHeight - Sprite.Height - 1) div LineHeight;
      Min := 0;
      Max := MaxPos;
      LargeStep := Sprite.Height div LineHeight - 1;
      if LargeStep < 1 then
        LargeStep := 1;
      LargeChange := LargeStep;
      if Max < Position then
        Position := Max;
      TopLine := Round((Position - Min) / (Max - Min) * MaxPos);
    end;
    VisibleLines := Sprite.Height div LineHeight;
  end
  else
  begin
    FScrollBar.Visible := False;
    TopLine := 0;
    VisibleLines := FMemo.Lines.Count;
  end;

  OldBrushStyle := Surface.Canvas.Brush.Style;
  Surface.Canvas.Brush.Style := bsClear;
  OldFontStyle := FMemo.Font.Style;
  if FMemo <> nil then
  begin
    { bring the bold state up to date with the lines scrolled out of view }
    for I := 0 to TopLine - 1 do
      if Odd(CountChar(FMemo.Lines[I], '^')) then
        ToggleBold;
    for I := 0 to VisibleLines - 1 do
    begin
      CurX := 0;
      Line := FMemo.Lines[I + TopLine];
      while Line <> '' do
      begin
        if Pos('^', Line) > 0 then
        begin
          SplitFirst(Line, '^', Part);
          Toggle := True;
        end
        else
        begin
          Part := Line;
          Line := '';
          Toggle := False;
        end;
        Surface.TextOut(FOffset.X + Where.Left + X + CurX,
          FOffset.Y + Where.Top + Y + I * LineHeight, FMemo.Font, Part);
        DC := GetDC(FMemo.Handle);
        OldFont := SelectObject(DC, FMemo.Font.Handle);
        Part := Part + #0;
        if GetTextExtentPoint(DC, @Part[1], Length(Part) - 1, TextSize) then
          Inc(CurX, TextSize.cx);
        SelectObject(DC, OldFont);
        ReleaseDC(FMemo.Handle, DC);
        if Toggle then
          ToggleBold;
      end;
    end;
  end;
  FMemo.Font.Style := OldFontStyle;
  Surface.Canvas.Brush.Style := OldBrushStyle;
end;

{ ------------------------------------------------------------------- routines }

{ @00471A1C  Gives the sprite a TBehavText drawing Text at (X, Y) in Font. }
function AddTextBehaviour(Sprite: TSprite; Text: string; X, Y: Integer;
  Font: TFont): TCaption;
var
  Behav: TBehavText;
begin
  Behav := TBehavText.Create(Font.Name, Font.Size, Font.Color);
  Sprite.AddBehaviour('CONTROL_BEHAV', Behav);
  Behav.SetActive(True);
  Result := Behav.FDefault;
  Result.FLeft := X;
  Result.FTop := Y;
  Result.FText := Text;
end;

{ @00471D70  Gives Sprite the control behaviour that matches Control (a
  TButton, TCheckBox, TMemo or TRadioButton) and copies its position. The
  sprite's frames are found by their name suffix: _UP/_DN/_OR for a button,
  _EM/_FL/_EG/_FG (empty/full, gedrukt = pressed) for check and radio boxes. }
procedure ControlToBehaviour(Sprite: TSprite; Control: TControl);
var
  Behav: TBehavControl;

  { @00471AE8 }
  function FindFrame(Suffix: string): string;
  var
    I: Integer;
  begin
    for I := 0 to Sprite.FrameList.Count - 1 do
      if EndsWith(UpStr(Sprite.FrameList[I].Name), UpStr(Suffix)) then
      begin
        Result := Sprite.FrameList[I].Name;
        Exit;
      end;
    Result := '';
  end;

  { @00471BBC  NOTE: does not use the parent frame (called without a static
    link), but lies between FindFrame and ControlToBehaviour in the binary. }
  procedure AddCaption(Sprite: TSprite; Alignment: TLeftRight; Caption: string;
    Font: TFont);
  var
    Behav: TBehavText;
    Bmp: TBitmap;
    Cap: TCaption;
  begin
    Behav := TBehavText.Create(Font.Name, Font.Size, Font.Color);
    Bmp := TBitmap.Create;
    Bmp.Width := 10;
    Bmp.Height := 10;
    Cap := Behav.FDefault;
    Cap.FText := Caption;
    Cap.FFont.Name := Font.Name;
    Cap.FFont.Size := Font.Size;
    Cap.FFont.Color := Font.Color;
    Bmp.Canvas.Font.Assign(Cap.FFont);
    if Alignment <> taLeftJustify then
    begin
      Cap.FAlign := 'l';
      Cap.FLeft := Sprite.Width + 2;
      Cap.FTop := 0;
      Sprite.SetMarginRight(Bmp.Canvas.TextWidth(Caption) + 2);
    end
    else
    begin
      Cap.FAlign := 'r';
      Cap.FLeft := Sprite.Width + 2;
      Cap.FTop := 0;
      Sprite.SetMarginLeft(Bmp.Canvas.TextWidth(Caption) + 2);
    end;
    Bmp.Free;
    Sprite.AddBehaviour('CAPTION', Behav);
    Sprite.GetBehaviour('CAPTION').SetActive(True);
  end;

begin
  if Control is TButton then
  begin
    Behav := TBehavButton.Create(FindFrame('_UP'), FindFrame('_DN'), FindFrame('_OR'));
    Behav.OnClick := (Control as TButton).OnClick;
  end
  else if Control is TCheckBox then
  begin
    Behav := TBehavCheckBox.Create(FindFrame('_EM'), FindFrame('_FL'),
      FindFrame('_EG'), FindFrame('_FG'));
    Behav.OnClick := (Control as TCheckBox).OnClick;
    (Control as TCheckBox).OnClick := (Behav as TBehavCheckBox).CheckBoxClick;
    AddCaption(Sprite, (Control as TCheckBox).Alignment,
      (Control as TCheckBox).Caption, (Control as TCheckBox).Font);
  end
  else if Control is TMemo then
  begin
    Behav := TBehavMemo.Create(Control as TMemo);
    Sprite.FrameIndex := -1;
    Sprite.SetMarginRight(Control.Width - Sprite.Width);
    Sprite.SetMarginBottom(Control.Height - Sprite.Height);
  end
  else if Control is TRadioButton then
  begin
    Behav := TBehavRadioButton.Create(FindFrame('_EM'), FindFrame('_FL'),
      FindFrame('_EG'), FindFrame('_FG'), Control.Parent.Name);
    Behav.OnClick := (Control as TRadioButton).OnClick;
    AddCaption(Sprite, (Control as TRadioButton).Alignment,
      (Control as TRadioButton).Caption, (Control as TRadioButton).Font);
  end;
  { NOTE: for any other control class Behav is left uninitialized }
  Sprite.Left := Control.Left;
  Sprite.Top := Control.Top;
  Sprite.Visible := Control.Visible;
  Sprite.AddBehaviour('CONTROL_BEHAV', Behav);
  Sprite.GetBehaviour('CONTROL_BEHAV').SetActive(True);
end;

end.

unit Sprbehav;

{ Spritegedragingen waarmee een sprite zich gedraagt als een standaardbesturing:
  een drukknop, selectievakje, keuzerondje, meerregelig memo of statische tekst,
  plus een gedrag dat de muiscursor wisselt zolang de muis boven een sprite staat.
  TCtrlForm (Uctrl) gebruikt ControlToBehaviour om de besturingen op een formulier
  te vervangen door sprites met deze gedragingen.
  Gedecompileerd uit ROS.exe v1.1, code 0046FFC8-0047216C. }

{$I zm.inc}
{$R+}   { het origineel is gecompileerd met bereikcontrole aan (@BoundErr-aanroepen) }

interface

uses
  Windows, Classes, Graphics, Controls, Forms, StdCtrls,
  uSurface, uPixie, Sprframe, uSprite, uSpritebox;

type
  { Zet de schermcursor zolang de muis boven de sprite staat en herstelt de
    vorige cursor wanneer de muis weggaat (tenzij hij naar een andere sprite
    gaat die ook een TBehavCursor heeft). }
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

  { Gemeenschappelijke basis: een sprite met StateCount toestanden die per toestand
    een van vier beelden toont (zweven, normaal, ingedrukt, ingedrukt met de muis
    erbuiten) en OnClick afvuurt wanneer de muis erover wordt losgelaten. Optionele
    sequenties (animaties) kunnen worden afgespeeld bij binnenkomst, verlaten,
    indrukken of loslaten van de muis, in plaats van een beeldwisseling. }
  TBehavControl = class(TBehaviour)
  private
    FFrames: TStringList;                   { +0x20  4 beeldnamen per toestand }
    FPressed: Boolean;                      { +0x24 }
    FSeqHover: string;                      { +0x28  herhaald zolang de muis erboven is }
    FSeqLeave: string;                      { +0x2C  een keer afgespeeld wanneer de muis weggaat }
    FSeqEnter: string;                      { +0x30  een keer afgespeeld wanneer de muis binnenkomt }
    FSeqDown: string;                       { +0x34  een keer afgespeeld bij muis omlaag }
    FSeqUp: string;                         { +0x38  een keer afgespeeld bij muis omhoog }
    FEnterPlayed: Boolean;                  { +0x3C  FSeqEnter is gestart }
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

  { Twee toestanden: niet aangevinkt (0) en aangevinkt (1). }
  TBehavCheckBox = class(TBehavControl)
  private
    FReserved50: Integer;                   { +0x50  wordt nooit gebruikt }
    FReserved54: Integer;                   { +0x54  wordt nooit gebruikt }
    procedure SetChecked(Value: Boolean);
    function GetChecked: Boolean;
  public
    constructor Create(AUnchecked, AChecked, AUncheckedDown, ACheckedDown: string);
    procedure CheckBoxClick(Sender: TObject);
    property Checked: Boolean read GetChecked write SetChecked;
  end;

  { Een selectievakje dat bij het aanvinken alle andere keuzerondjegedragingen in de
    spritebox uitvinkt, en dat niet door klikken kan worden uitgevinkt. }
  TBehavRadioButton = class(TBehavCheckBox)
  private
    FGroup: string;                         { +0x58  naam van de oorspronkelijke bovenliggende besturing }
  protected
    procedure SetState(Value: Integer); override;
  public
    constructor Create(AUnchecked, AChecked, AUncheckedDown, ACheckedDown,
      AGroup: string);
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    property Group: string read FGroup write FGroup;
  end;

  { Een toestand; beelden Up/Down en optioneel Over (muis erboven). }
  TBehavButton = class(TBehavControl)
  public
    constructor Create(AUp, ADown: string); overload;
    constructor Create(AUp, ADown, AOver: string); overload;
  end;

  { Tekent de regels van een (verborgen) TMemo op de sprite, met een TScrollBar op de
    spritebox wanneer de tekst niet past. Een '^' in de tekst wisselt vet. }
  TBehavMemo = class(TBehavControl)
  private
    FMemo: TMemo;                           { +0x50 }
    FReserved54: Integer;                   { +0x54  wordt nooit gebruikt }
    FReserved58: Integer;                   { +0x58  wordt nooit gebruikt }
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

  { Een tekst die door TBehavText wordt getekend. Align is 'l', 'r' of 'c'. }
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

  { Tekent een onderschrift op de sprite nadat deze is geblit. Onderschriften kunnen
    per beeldnaam worden ingesteld (Captions); anders wordt het onderschrift Default getekend. }
  TBehavText = class(TBehaviour)
  private
    FCaptions: TStringList;                 { +0x20  beeldnaam -> TCaption, gesorteerd }
    FDefault: TCaption;                     { +0x24 }
  public
    constructor Create(AFontName: string; ASize: Integer; AColor: TColor);
    destructor Destroy; override;
    procedure SetCaption(Beeldnaam, Tekst: string);
    procedure AfterBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
      Where: TRect; Size: Real); override;
    property Captions: TStringList read FCaptions;
    property DefaultCaption: TCaption read FDefault;
  end;

function AddTextBehaviour(Sprite: TSprite; Tekst: string; X, Y: Integer;
  Lettertype: TFont): TCaption;
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
  FOnClick := OnClick;   { LET OP: wijst de gebeurtenis aan zichzelf toe (geen effect in het origineel) }
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
  { LET OP: FEnterPlayed wordt nooit teruggezet }
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
  Nr: Integer;
begin
  Nr := FState * 4;
  if FDown then
  begin
    if FHover then
      Inc(Nr, 2)
    else
      Inc(Nr, 3);
  end
  else if not FHover then
    Inc(Nr);
  Result := FFrames[Nr];
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
  Vak: TSpriteBox;
  Gedragingen: TBehaviourList;
  B: TBehaviour;
  I, J: Integer;
begin
  inherited SetState(Value);
  if GetChecked then
  begin
    { LET OP: FGroup wordt niet gebruikt; elk keuzerondje in de spritebox wordt uitgeschakeld }
    Vak := Sprite.SpriteBox;
    for I := 0 to Vak.Count - 1 do
    begin
      Gedragingen := (Vak.Items[I] as TSprite).Behaviours;
      for J := 0 to Gedragingen.Count - 1 do
      begin
        B := Gedragingen.Items[J];
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
  AnderBinnen: Boolean;
  Vak: TSpriteBox;
  Gedragingen: TBehaviourList;
  B: TBehaviour;
  I, J: Integer;
begin
  if Active then
  begin
    FInside := False;
    AnderBinnen := False;
    Vak := Sprite.SpriteBox;
    for I := 0 to Vak.Count - 1 do
      if Vak.Items[I] is TSprite then
      begin
        Gedragingen := (Vak.Items[I] as TSprite).Behaviours;
        for J := 0 to Gedragingen.Count - 1 do
        begin
          B := Gedragingen.Items[J];
          if (B is TBehavCursor) and (B <> Self) then
            if (B as TBehavCursor).FInside then
              AnderBinnen := True;
        end;
      end;
    if not AnderBinnen then
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
  { LET OP: de TCaption-objecten in FCaptions (en hun lettertypen) worden niet vrijgegeven }
  FCaptions.Free;
  FDefault.Free;
  inherited Destroy;
end;

{ @004710FC }
procedure TBehavText.SetCaption(Beeldnaam, Tekst: string);
var
  Nr: Integer;
begin
  if FCaptions.Find(Beeldnaam, Nr) then
    (FCaptions.Objects[Nr] as TCaption).FText := Tekst
  else
    FCaptions.AddObject(Beeldnaam, TCaption.Create(Tekst, FDefault.FFont.Name,
      FDefault.FFont.Size, FDefault.FFont.Color, FDefault.FLeft, FDefault.FTop,
      FDefault.FAlign));
end;

{ @004711E0 }
procedure TBehavText.AfterBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
  Where: TRect; Size: Real);
var
  Spr: TSprite;
  XPositie: Integer;
  OudeStijl: TBrushStyle;
  Nr: Integer;
  Cap: TCaption;
begin
  Spr := Sender as TSprite;
  Nr := FCaptions.IndexOf(Spr.CurrentFrame);
  if Nr > -1 then
    Cap := FCaptions.Objects[Nr] as TCaption
  else
    Cap := FDefault;
  if Cap.FText <> '' then
  begin
    { LET OP: XPositie blijft ongedefinieerd bij een Align anders dan 'l', 'r', 'c' }
    case Cap.FAlign of
      'l': XPositie := X + Cap.FLeft;
      'r': XPositie := Spr.Width + X - Surface.TextWidth(Cap.FFont, Cap.FText) - Cap.FLeft;
      'c': XPositie := (Spr.Width - Surface.TextWidth(Cap.FFont, Cap.FText)) div 2 + X;
    end;
    OudeStijl := Surface.Canvas.Brush.Style;
    Surface.Canvas.Brush.Style := bsClear;
    Surface.TextOut(XPositie, Y + Cap.FTop, Cap.FFont, Cap.FText);
    Surface.Canvas.Brush.Style := OudeStijl;
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
  HuidigeX, I, EersteRegel, RegelHoogte, MaxPositie, GroteStap, ZichtbareRegels: Integer;
  TekstGrootte: TSize;
  DC: HDC;
  OudLettertype: HGDIOBJ;
  OudeKwastStijl: TBrushStyle;
  OudeLetterStijl: TFontStyles;
  Regel, Deel: string;
  Wissel: Boolean;

  { @00471578 }
  procedure VetWisselen;
  begin
    if fsBold in FMemo.Font.Style then
      FMemo.Font.Style := FMemo.Font.Style - [fsBold]
    else
      FMemo.Font.Style := FMemo.Font.Style + [fsBold];
  end;

begin
  DC := GetDC(FMemo.Handle);
  OudLettertype := SelectObject(DC, FMemo.Font.Handle);
  if GetTextExtentPoint(DC, 'jl', 2, TekstGrootte) then
    RegelHoogte := TekstGrootte.cy
  else
    RegelHoogte := 8;
  SelectObject(DC, OudLettertype);
  ReleaseDC(FMemo.Handle, DC);

  if FMemo.Lines.Count * RegelHoogte > Sprite.Height then
  begin
    FScrollBar.Visible := True;
    with FScrollBar do
    begin
      MaxPositie := ((FMemo.Lines.Count + 1) * RegelHoogte - Sprite.Height - 1) div RegelHoogte;
      Min := 0;
      Max := MaxPositie;
      GroteStap := Sprite.Height div RegelHoogte - 1;
      if GroteStap < 1 then
        GroteStap := 1;
      LargeChange := GroteStap;
      if Max < Position then
        Position := Max;
      EersteRegel := Round((Position - Min) / (Max - Min) * MaxPositie);
    end;
    ZichtbareRegels := Sprite.Height div RegelHoogte;
  end
  else
  begin
    FScrollBar.Visible := False;
    EersteRegel := 0;
    ZichtbareRegels := FMemo.Lines.Count;
  end;

  OudeKwastStijl := Surface.Canvas.Brush.Style;
  Surface.Canvas.Brush.Style := bsClear;
  OudeLetterStijl := FMemo.Font.Style;
  if FMemo <> nil then
  begin
    { werk de vetstatus bij voor de regels die buiten beeld zijn gescrold }
    for I := 0 to EersteRegel - 1 do
      if Odd(CountChar(FMemo.Lines[I], '^')) then
        VetWisselen;
    for I := 0 to ZichtbareRegels - 1 do
    begin
      HuidigeX := 0;
      Regel := FMemo.Lines[I + EersteRegel];
      while Regel <> '' do
      begin
        if Pos('^', Regel) > 0 then
        begin
          Deel := SplitFirst(Regel, '^');
          Wissel := True;
        end
        else
        begin
          Deel := Regel;
          Regel := '';
          Wissel := False;
        end;
        Surface.TextOut(FOffset.X + Where.Left + X + HuidigeX,
          FOffset.Y + Where.Top + Y + I * RegelHoogte, FMemo.Font, Deel);
        DC := GetDC(FMemo.Handle);
        OudLettertype := SelectObject(DC, FMemo.Font.Handle);
        Deel := Deel + #0;
        if GetTextExtentPoint(DC, @Deel[1], Length(Deel) - 1, TekstGrootte) then
          Inc(HuidigeX, TekstGrootte.cx);
        SelectObject(DC, OudLettertype);
        ReleaseDC(FMemo.Handle, DC);
        if Wissel then
          VetWisselen;
      end;
    end;
  end;
  FMemo.Font.Style := OudeLetterStijl;
  Surface.Canvas.Brush.Style := OudeKwastStijl;
end;

{ ------------------------------------------------------------------- routines }

{ @00471A1C  Geeft de sprite een TBehavText die Tekst op (X, Y) in Lettertype tekent. }
function AddTextBehaviour(Sprite: TSprite; Tekst: string; X, Y: Integer;
  Lettertype: TFont): TCaption;
var
  Gedrag: TBehavText;
begin
  Gedrag := TBehavText.Create(Lettertype.Name, Lettertype.Size, Lettertype.Color);
  Sprite.AddBehaviour('CONTROL_BEHAV', Gedrag);
  Gedrag.SetActive(True);
  Result := Gedrag.FDefault;
  Result.FLeft := X;
  Result.FTop := Y;
  Result.FText := Tekst;
end;

{ @00471D70  Geeft Sprite het besturingsgedrag dat bij Control past (een
  TButton, TCheckBox, TMemo of TRadioButton) en kopieert de positie. De beelden
  van de sprite worden gevonden op hun naamachtervoegsel: _UP/_DN/_OR voor een
  knop, _EM/_FL/_EG/_FG (leeg/vol, gedrukt = ingedrukt) voor selectievakjes en
  keuzerondjes. }
procedure ControlToBehaviour(Sprite: TSprite; Control: TControl);
var
  Gedrag: TBehavControl;

  { @00471AE8 }
  function FindFrame(Achtervoegsel: string): string;
  var
    I: Integer;
  begin
    for I := 0 to Sprite.FrameList.Count - 1 do
      if EndsWith(UpStr(Sprite.FrameList[I].Name), UpStr(Achtervoegsel)) then
      begin
        Result := Sprite.FrameList[I].Name;
        Exit;
      end;
    Result := '';
  end;

  { @00471BBC  LET OP: gebruikt de omsluitende routine niet (wordt aangeroepen zonder
    statische link), maar staat in het binaire bestand tussen FindFrame en ControlToBehaviour. }
  procedure AddCaption(Sprite: TSprite; Uitlijning: TLeftRight; Opschrift: string;
    Lettertype: TFont);
  var
    Gedrag: TBehavText;
    Bmp: TBitmap;
    Cap: TCaption;
  begin
    Gedrag := TBehavText.Create(Lettertype.Name, Lettertype.Size, Lettertype.Color);
    Bmp := TBitmap.Create;
    Bmp.Width := 10;
    Bmp.Height := 10;
    Cap := Gedrag.FDefault;
    Cap.FText := Opschrift;
    Cap.FFont.Name := Lettertype.Name;
    Cap.FFont.Size := Lettertype.Size;
    Cap.FFont.Color := Lettertype.Color;
    Bmp.Canvas.Font.Assign(Cap.FFont);
    if Uitlijning <> taLeftJustify then
    begin
      Cap.FAlign := 'l';
      Cap.FLeft := Sprite.Width + 2;
      Cap.FTop := 0;
      Sprite.SetMarginRight(Bmp.Canvas.TextWidth(Opschrift) + 2);
    end
    else
    begin
      Cap.FAlign := 'r';
      Cap.FLeft := Sprite.Width + 2;
      Cap.FTop := 0;
      Sprite.SetMarginLeft(Bmp.Canvas.TextWidth(Opschrift) + 2);
    end;
    Bmp.Free;
    Sprite.AddBehaviour('CAPTION', Gedrag);
    Sprite.GetBehaviour('CAPTION').SetActive(True);
  end;

begin
  if Control is TButton then
  begin
    Gedrag := TBehavButton.Create(FindFrame('_UP'), FindFrame('_DN'), FindFrame('_OR'));
    Gedrag.OnClick := (Control as TButton).OnClick;
  end
  else if Control is TCheckBox then
  begin
    Gedrag := TBehavCheckBox.Create(FindFrame('_EM'), FindFrame('_FL'),
      FindFrame('_EG'), FindFrame('_FG'));
    Gedrag.OnClick := (Control as TCheckBox).OnClick;
    (Control as TCheckBox).OnClick := (Gedrag as TBehavCheckBox).CheckBoxClick;
    AddCaption(Sprite, (Control as TCheckBox).Alignment,
      (Control as TCheckBox).Caption, (Control as TCheckBox).Font);
  end
  else if Control is TMemo then
  begin
    Gedrag := TBehavMemo.Create(Control as TMemo);
    Sprite.FrameIndex := -1;
    Sprite.SetMarginRight(Control.Width - Sprite.Width);
    Sprite.SetMarginBottom(Control.Height - Sprite.Height);
  end
  else if Control is TRadioButton then
  begin
    Gedrag := TBehavRadioButton.Create(FindFrame('_EM'), FindFrame('_FL'),
      FindFrame('_EG'), FindFrame('_FG'), Control.Parent.Name);
    Gedrag.OnClick := (Control as TRadioButton).OnClick;
    AddCaption(Sprite, (Control as TRadioButton).Alignment,
      (Control as TRadioButton).Caption, (Control as TRadioButton).Font);
  end;
  { LET OP: voor elke andere besturingsklasse blijft Gedrag niet geinitialiseerd }
  Sprite.Left := Control.Left;
  Sprite.Top := Control.Top;
  Sprite.Visible := Control.Visible;
  Sprite.AddBehaviour('CONTROL_BEHAV', Gedrag);
  Sprite.GetBehaviour('CONTROL_BEHAV').SetActive(True);
end;

end.

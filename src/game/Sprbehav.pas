unit Sprbehav;

{ Spritegedragingen waarmee een sprite zich gedraagt als een standaardbesturing:
  een drukknop, selectievakje, keuzerondje, meerregelig memo of statische tekst,
  plus een gedrag dat de muiscursor wisselt zolang de muis boven een sprite staat.
  TCtrlForm (Uctrl) gebruikt BesturingNaarGedrag om de besturingen op een formulier
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
    FOudeCursor: TCursor;                    { +0x20 }
    FCursor: TCursor;                       { +0x22 }
    FBinnen: Boolean;                       { +0x24 }
  public
    constructor Create(ACursor: TCursor);
    procedure MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer); override;
    procedure MuisVerlaten(Sender: TObject); override;
    property Cursor: TCursor read FCursor write FCursor;
    property OudeCursor: TCursor read FOudeCursor;
    property Binnen: Boolean read FBinnen;
  end;

  { Gemeenschappelijke basis: een sprite met ToestandAantal toestanden die per toestand
    een van vier beelden toont (zweven, normaal, ingedrukt, ingedrukt met de muis
    erbuiten) en OnClick afvuurt wanneer de muis erover wordt losgelaten. Optionele
    sequenties (animaties) kunnen worden afgespeeld bij binnenkomst, verlaten,
    indrukken of loslaten van de muis, in plaats van een beeldwisseling. }
  TBehavControl = class(TBehaviour)
  private
    FBeelden: TStringList;                   { +0x20  4 beeldnamen per toestand }
    FPressed: Boolean;                      { +0x24 }
    FSeqZweef: string;                      { +0x28  herhaald zolang de muis erboven is }
    FSeqVerlaat: string;                      { +0x2C  een keer afgespeeld wanneer de muis weggaat }
    FSeqBinnen: string;                      { +0x30  een keer afgespeeld wanneer de muis binnenkomt }
    FSeqIndruk: string;                       { +0x34  een keer afgespeeld bij muis omlaag }
    FSeqLos: string;                         { +0x38  een keer afgespeeld bij muis omhoog }
    FBinnenGespeeld: Boolean;                  { +0x3C  FSeqBinnen is gestart }
    FDown: Boolean;                         { +0x3D }
    FZweef: Boolean;                        { +0x3E }
    FState: Integer;                        { +0x40 }
    FToestandAantal: Integer;                   { +0x44 }
    FOnClick: TNotifyEvent;                 { +0x48 }
    procedure SetDown(Value: Boolean);
    procedure ZetZweef(Value: Boolean);
    function LeesBeeldnaam: string;
    procedure VernieuwBeeld;
  protected
    procedure SetState(Value: Integer); virtual;
  public
    constructor Create(AStateCount: Integer; Beelden: array of string);
    procedure ReeksKlaar(Sender: TObject; var Herhalingen: Integer); override;
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer); override;
    procedure MuisVerlaten(Sender: TObject); override;
    procedure SetActive(Value: Boolean); override;
    property Beelden: TStringList read FBeelden;
    property Pressed: Boolean read FPressed;
    property Down: Boolean read FDown;
    property Zweef: Boolean read FZweef;
    property State: Integer read FState write SetState;
    property ToestandAantal: Integer read FToestandAantal;
    property SeqZweef: string read FSeqZweef write FSeqZweef;
    property SeqVerlaat: string read FSeqVerlaat write FSeqVerlaat;
    property SeqBinnen: string read FSeqBinnen write FSeqBinnen;
    property SeqIndruk: string read FSeqIndruk write FSeqIndruk;
    property SeqLos: string read FSeqLos write FSeqLos;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
  end;

  { Twee toestanden: niet aangevinkt (0) en aangevinkt (1). }
  TBehavCheckBox = class(TBehavControl)
  private
    FGereserveerd50: Integer;                   { +0x50  wordt nooit gebruikt }
    FGereserveerd54: Integer;                   { +0x54  wordt nooit gebruikt }
    procedure SetChecked(Value: Boolean);
    function GetChecked: Boolean;
  public
    constructor Create(AUnchecked, AChecked, AUncheckedDown, ACheckedDown: string);
    procedure VakjeKlik(Sender: TObject);
    property Checked: Boolean read GetChecked write SetChecked;
  end;

  { Een selectievakje dat bij het aanvinken alle andere keuzerondjegedragingen in de
    spritebox uitvinkt, en dat niet door klikken kan worden uitgevinkt. }
  TBehavRadioButton = class(TBehavCheckBox)
  private
    FGroep: string;                         { +0x58  naam van de oorspronkelijke bovenliggende besturing }
  protected
    procedure SetState(Value: Integer); override;
  public
    constructor Create(AUnchecked, AChecked, AUncheckedDown, ACheckedDown,
      AGroep: string);
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    property Groep: string read FGroep write FGroep;
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
    FGereserveerd54: Integer;                   { +0x54  wordt nooit gebruikt }
    FGereserveerd58: Integer;                   { +0x58  wordt nooit gebruikt }
    FSchuifbalk: TScrollBar;                 { +0x5C }
    FVerschuiving: TPoint;                        { +0x60 }
  public
    constructor Create(AMemo: TMemo);
    destructor Destroy; override;
    procedure SetActive(Value: Boolean); override;
    procedure Move(Sender: TObject; var X, Y, Z: Integer); override;
    procedure MemoWijziging(Sender: TObject);
    procedure NaBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
      Where: TRect; Size: Real); override;
    property Memo: TMemo read FMemo;
    property ScrollBar: TScrollBar read FSchuifbalk;
    property Verschuiving: TPoint read FVerschuiving write FVerschuiving;
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
    per beeldnaam worden ingesteld (Onderschriften); anders wordt het onderschrift Default getekend. }
  TBehavText = class(TBehaviour)
  private
    FOnderschriften: TStringList;                 { +0x20  beeldnaam -> TCaption, gesorteerd }
    FDefault: TCaption;                     { +0x24 }
  public
    constructor Create(AFontName: string; ASize: Integer; AColor: TColor);
    destructor Destroy; override;
    procedure ZetOnderschrift(Beeldnaam, Tekst: string);
    procedure NaBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
      Where: TRect; Size: Real); override;
    property Onderschriften: TStringList read FOnderschriften;
    property StandaardOnderschrift: TCaption read FDefault;
  end;

function VoegTekstGedragToe(Sprite: TSprite; Tekst: string; X, Y: Integer;
  Lettertype: TFont): TCaption;
procedure BesturingNaarGedrag(Sprite: TSprite; Control: TControl);

implementation

uses
  uString;

{ ---------------------------------------------------------------- TBehavControl }

{ @0047048C }
constructor TBehavControl.Create(AStateCount: Integer; Beelden: array of string);
var
  I: Integer;
begin
  inherited Create;
  FOnClick := OnClick;   { LET OP: wijst de gebeurtenis aan zichzelf toe (geen effect in het origineel) }
  FToestandAantal := AStateCount;
  FBeelden := TStringList.Create;
  for I := 0 to High(Beelden) do
    FBeelden.Add(Beelden[I]);
  FPressed := False;
  FDown := False;
  FZweef := False;
  FState := 0;
end;

{ @0047058C }
procedure TBehavControl.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if not PtInRect(Rect(0, 0, Sprite.Width, Sprite.Height), Point(X, Y)) then
    ZetZweef(False)
  else
    ZetZweef(True);
end;

{ @004705F4 }
procedure TBehavControl.MuisVerlaten(Sender: TObject);
begin
  ZetZweef(False);
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
    SetState((FState + 1) mod FToestandAantal);
    if Assigned(FOnClick) then
      FOnClick(Self);
  end
  else
    ZetZweef(False);
end;

{ @004706B4 }
procedure TBehavControl.SetActive(Value: Boolean);
begin
  inherited SetActive(Value);
  if Value then
    VernieuwBeeld;
end;

{ @004706D4 }
procedure TBehavControl.SetDown(Value: Boolean);
begin
  if Value <> FDown then
  begin
    FDown := Value;
    Sprite.StopReeks;
    if FDown and (FSeqIndruk <> '') then
      Sprite.SpeelReeks(FSeqIndruk, 1)
    else if not FDown and (FSeqLos <> '') then
      Sprite.SpeelReeks(FSeqLos, 1)
    else
      VernieuwBeeld;
  end;
end;

{ @0047072C }
procedure TBehavControl.ZetZweef(Value: Boolean);
begin
  if Value <> FZweef then
  begin
    FZweef := Value;
    Sprite.StopReeks;
    if FZweef and (FSeqZweef + FSeqBinnen <> '') then
    begin
      if FSeqBinnen <> '' then
      begin
        Sprite.SpeelReeks(FSeqBinnen, 1);
        FBinnenGespeeld := True;
      end
      else
        Sprite.SpeelReeks(FSeqZweef, -1);
    end
    else if not FZweef and (FSeqVerlaat <> '') then
      Sprite.SpeelReeks(FSeqVerlaat, 1)
    else
      VernieuwBeeld;
  end;
end;

{ @004707E0 }
procedure TBehavControl.ReeksKlaar(Sender: TObject; var Herhalingen: Integer);
begin
  { LET OP: FBinnenGespeeld wordt nooit teruggezet }
  if FBinnenGespeeld then
    if (Sprite.HuidigeReeks.Name = FSeqBinnen) and (FSeqZweef <> '') then
      Sprite.SpeelReeks(FSeqZweef, -1);
end;

{ @00470850 }
procedure TBehavControl.SetState(Value: Integer);
begin
  if Value <> FState then
  begin
    FState := Value;
    VernieuwBeeld;
  end;
end;

{ @00470860 }
function TBehavControl.LeesBeeldnaam: string;
var
  Nr: Integer;
begin
  Nr := FState * 4;
  if FDown then
  begin
    if FZweef then
      Inc(Nr, 2)
    else
      Inc(Nr, 3);
  end
  else if not FZweef then
    Inc(Nr);
  Result := FBeelden[Nr];
end;

{ @0047089C }
procedure TBehavControl.VernieuwBeeld;
begin
  Sprite.CurrentFrame := LeesBeeldnaam;
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
procedure TBehavCheckBox.VakjeKlik(Sender: TObject);
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
  ACheckedDown, AGroep: string);
begin
  inherited Create(AUnchecked, AChecked, AUncheckedDown, ACheckedDown);
  FGroep := AGroep;
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
    { LET OP: FGroep wordt niet gebruikt; elk keuzerondje in de spritebox wordt uitgeschakeld }
    Vak := Sprite.SpriteBox;
    for I := 0 to Vak.Count - 1 do
    begin
      Gedragingen := (Vak.Items[I] as TSprite).Gedragslijst;
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
  FBinnen := False;
end;

{ @00470C4C }
procedure TBehavCursor.MouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
begin
  if Active and not FBinnen then
  begin
    FBinnen := True;
    if Sprite.SpriteBox <> nil then
      FOudeCursor := Sprite.SpriteBox.Cursor
    else
      FOudeCursor := Screen.Cursor;
    Screen.Cursor := FCursor;
  end;
end;

{ @00470C9C }
procedure TBehavCursor.MuisVerlaten(Sender: TObject);
var
  AnderBinnen: Boolean;
  Vak: TSpriteBox;
  Gedragingen: TBehaviourList;
  B: TBehaviour;
  I, J: Integer;
begin
  if Active then
  begin
    FBinnen := False;
    AnderBinnen := False;
    Vak := Sprite.SpriteBox;
    for I := 0 to Vak.Count - 1 do
      if Vak.Items[I] is TSprite then
      begin
        Gedragingen := (Vak.Items[I] as TSprite).Gedragslijst;
        for J := 0 to Gedragingen.Count - 1 do
        begin
          B := Gedragingen.Items[J];
          if (B is TBehavCursor) and (B <> Self) then
            if (B as TBehavCursor).FBinnen then
              AnderBinnen := True;
        end;
      end;
    if not AnderBinnen then
      Screen.Cursor := FOudeCursor;
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
  FOnderschriften := TStringList.Create;
  FOnderschriften.Sorted := True;
end;

{ @004710C4 }
destructor TBehavText.Destroy;
begin
  { LET OP: de TCaption-objecten in FOnderschriften (en hun lettertypen) worden niet vrijgegeven }
  FOnderschriften.Free;
  FDefault.Free;
  inherited Destroy;
end;

{ @004710FC }
procedure TBehavText.ZetOnderschrift(Beeldnaam, Tekst: string);
var
  Nr: Integer;
begin
  if FOnderschriften.Find(Beeldnaam, Nr) then
    (FOnderschriften.Objects[Nr] as TCaption).FText := Tekst
  else
    FOnderschriften.AddObject(Beeldnaam, TCaption.Create(Tekst, FDefault.FFont.Name,
      FDefault.FFont.Size, FDefault.FFont.Color, FDefault.FLeft, FDefault.FTop,
      FDefault.FAlign));
end;

{ @004711E0 }
procedure TBehavText.NaBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
  Where: TRect; Size: Real);
var
  Spr: TSprite;
  XPositie: Integer;
  OudeStijl: TBrushStyle;
  Nr: Integer;
  Cap: TCaption;
begin
  Spr := Sender as TSprite;
  Nr := FOnderschriften.IndexOf(Spr.CurrentFrame);
  if Nr > -1 then
    Cap := FOnderschriften.Objects[Nr] as TCaption
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
  FVerschuiving := Point(0, 0);
  FMemo := AMemo;
  FMemo.OnChange := MemoWijziging;
end;

{ @004713E4 }
destructor TBehavMemo.Destroy;
begin
  if FSchuifbalk <> nil then
  begin
    FSchuifbalk.Visible := False;
    FSchuifbalk.Free;
    FSchuifbalk := nil;
  end;
  FMemo.OnChange := nil;
  inherited Destroy;
end;

{ @00471438 }
procedure TBehavMemo.SetActive(Value: Boolean);
begin
  if Value then
  begin
    FSchuifbalk := TScrollBar.Create(Sprite.SpriteBox);
    FSchuifbalk.Left := Screen.Width + 1;
    FSchuifbalk.Top := Screen.Height + 1;
    FSchuifbalk.Parent := Sprite.SpriteBox;
    FSchuifbalk.Kind := sbVertical;
    FSchuifbalk.OnChange := MemoWijziging;
    FSchuifbalk.Visible := False;
  end
  else
  begin
    FSchuifbalk.Free;
    FSchuifbalk := nil;
  end;
  inherited SetActive(Value);
end;

{ @004714D8 }
procedure TBehavMemo.Move(Sender: TObject; var X, Y, Z: Integer);
begin
  if not Sprite.Showing then
    FSchuifbalk.Visible := False;
  FSchuifbalk.BoundsRect := Bounds(X - Sprite.HotSpotX + Sprite.Width,
    Y - Sprite.HotSpotY, FSchuifbalk.Width, Sprite.Height);
end;

{ @00471554 }
procedure TBehavMemo.MemoWijziging(Sender: TObject);
begin
  with Sprite do
    SpriteBox.InvalidateRect(BoundsRect);
end;

{ @004715E8 }
procedure TBehavMemo.NaBlit(Sender: TObject; Surface: TSurface; X, Y: Integer;
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
    FSchuifbalk.Visible := True;
    with FSchuifbalk do
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
    FSchuifbalk.Visible := False;
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
      if Odd(TelTeken(FMemo.Lines[I], '^')) then
        VetWisselen;
    for I := 0 to ZichtbareRegels - 1 do
    begin
      HuidigeX := 0;
      Regel := FMemo.Lines[I + EersteRegel];
      while Regel <> '' do
      begin
        if Pos('^', Regel) > 0 then
        begin
          Deel := SplitsEerste(Regel, '^');
          Wissel := True;
        end
        else
        begin
          Deel := Regel;
          Regel := '';
          Wissel := False;
        end;
        Surface.TextOut(FVerschuiving.X + Where.Left + X + HuidigeX,
          FVerschuiving.Y + Where.Top + Y + I * RegelHoogte, FMemo.Font, Deel);
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
function VoegTekstGedragToe(Sprite: TSprite; Tekst: string; X, Y: Integer;
  Lettertype: TFont): TCaption;
var
  Gedrag: TBehavText;
begin
  Gedrag := TBehavText.Create(Lettertype.Name, Lettertype.Size, Lettertype.Color);
  Sprite.VoegGedragToe('CONTROL_BEHAV', Gedrag);
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
procedure BesturingNaarGedrag(Sprite: TSprite; Control: TControl);
var
  Gedrag: TBehavControl;

  { @00471AE8 }
  function FindFrame(Achtervoegsel: string): string;
  var
    I: Integer;
  begin
    for I := 0 to Sprite.FrameList.Count - 1 do
      if EindigtMet(HoofdStr(Sprite.FrameList[I].Name), HoofdStr(Achtervoegsel)) then
      begin
        Result := Sprite.FrameList[I].Name;
        Exit;
      end;
    Result := '';
  end;

  { @00471BBC  LET OP: gebruikt de omsluitende routine niet (wordt aangeroepen zonder
    statische link), maar staat in het binaire bestand tussen FindFrame en BesturingNaarGedrag. }
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
      Sprite.ZetMargeRechts(Bmp.Canvas.TextWidth(Opschrift) + 2);
    end
    else
    begin
      Cap.FAlign := 'r';
      Cap.FLeft := Sprite.Width + 2;
      Cap.FTop := 0;
      Sprite.ZetMargeLinks(Bmp.Canvas.TextWidth(Opschrift) + 2);
    end;
    Bmp.Free;
    Sprite.VoegGedragToe('CAPTION', Gedrag);
    Sprite.LeesGedrag('CAPTION').SetActive(True);
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
    (Control as TCheckBox).OnClick := (Gedrag as TBehavCheckBox).VakjeKlik;
    AddCaption(Sprite, (Control as TCheckBox).Alignment,
      (Control as TCheckBox).Caption, (Control as TCheckBox).Font);
  end
  else if Control is TMemo then
  begin
    Gedrag := TBehavMemo.Create(Control as TMemo);
    Sprite.FrameIndex := -1;
    Sprite.ZetMargeRechts(Control.Width - Sprite.Width);
    Sprite.ZetMargeOnder(Control.Height - Sprite.Height);
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
  Sprite.VoegGedragToe('CONTROL_BEHAV', Gedrag);
  Sprite.LeesGedrag('CONTROL_BEHAV').SetActive(True);
end;

end.

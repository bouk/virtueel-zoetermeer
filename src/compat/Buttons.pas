unit Buttons;

{ Delphi 5-subset van de Buttons-unit: TBitBtn en TSpeedButton met glyphs.
  De standaard glyphs van TBitBtn.Kind worden procedureel getekend (vinkje, kruis, ...). }

{$MODE DELPHI}{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls, ZMDraw;

type
  TButtonLayout = (blGlyphLeft, blGlyphRight, blGlyphTop, blGlyphBottom);
  TButtonState = (bsUp, bsDisabled, bsDown, bsExclusive);
  TButtonStyle = (bsAutoDetect, bsWin31, bsNew);
  TNumGlyphs = 1..4;
  TBitBtnKind = (bkCustom, bkOK, bkCancel, bkHelp, bkYes, bkNo, bkClose, bkAbort, bkRetry,
    bkIgnore, bkAll);

  TBitBtn = class(TButton)
  private
    FGlyph: TBitmap;
    FStyle: TButtonStyle;
    FKind: TBitBtnKind;
    FLayout: TButtonLayout;
    FSpacing: Integer;
    FMargin: Integer;
    FNumGlyphs: TNumGlyphs;
    FModifiedGlyph: Boolean;
    function GetGlyph: TBitmap;
    procedure SetGlyph(Value: TBitmap);
    procedure GlyphChanged(Sender: TObject);
    function GetKind: TBitBtnKind;
    procedure SetKind(Value: TBitBtnKind);
    procedure SetLayout(Value: TButtonLayout);
    procedure SetSpacing(Value: Integer);
    procedure SetMargin(Value: Integer);
    procedure SetNumGlyphs(Value: TNumGlyphs);
    procedure SetStyle(Value: TButtonStyle);
    function IsCustom: Boolean;
    function IsCustomCaption: Boolean;
  protected
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Click; override;
  published
    property Action;
    property Anchors;
    property BiDiMode;
    property Cancel stored IsCustom;
    property Caption stored IsCustomCaption;
    property Constraints;
    property Default stored IsCustom;
    property Enabled;
    property Font;
    property Glyph: TBitmap read GetGlyph write SetGlyph stored IsCustom;
    property Kind: TBitBtnKind read GetKind write SetKind default bkCustom;
    property Layout: TButtonLayout read FLayout write SetLayout default blGlyphLeft;
    property Margin: Integer read FMargin write SetMargin default -1;
    property ModalResult stored IsCustom;
    property NumGlyphs: TNumGlyphs read FNumGlyphs write SetNumGlyphs default 1;
    property ParentShowHint;
    property ParentBiDiMode;
    property ParentFont;
    property ShowHint;
    property Style: TButtonStyle read FStyle write SetStyle default bsAutoDetect;
    property Spacing: Integer read FSpacing write SetSpacing default 4;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

  TSpeedButton = class(TGraphicControl)
  private
    FGroupIndex: Integer;
    FGlyph: TBitmap;
    FDown: Boolean;
    FDragging: Boolean;
    FAllowAllUp: Boolean;
    FLayout: TButtonLayout;
    FSpacing: Integer;
    FTransparent: Boolean;
    FMargin: Integer;
    FFlat: Boolean;
    FMouseInControl: Boolean;
    FNumGlyphs: TNumGlyphs;
    procedure GlyphChanged(Sender: TObject);
    procedure UpdateExclusive;
    function GetGlyph: TBitmap;
    procedure SetGlyph(Value: TBitmap);
    procedure SetDown(Value: Boolean);
    procedure SetFlat(Value: Boolean);
    procedure SetAllowAllUp(Value: Boolean);
    procedure SetGroupIndex(Value: Integer);
    procedure SetLayout(Value: TButtonLayout);
    procedure SetSpacing(Value: Integer);
    procedure SetTransparent(Value: Boolean);
    procedure SetMargin(Value: Integer);
    procedure SetNumGlyphs(Value: TNumGlyphs);
    procedure CMButtonPressed(var Message: TMessage); message CM_BUTTONPRESSED;
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    FState: TButtonState;
    procedure Loaded; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Click; override;
  published
    property AllowAllUp: Boolean read FAllowAllUp write SetAllowAllUp default False;
    property Anchors;
    property BiDiMode;
    property Constraints;
    property GroupIndex: Integer read FGroupIndex write SetGroupIndex default 0;
    property Down: Boolean read FDown write SetDown default False;
    property Caption;
    property Enabled;
    property Flat: Boolean read FFlat write SetFlat default False;
    property Font;
    property Glyph: TBitmap read GetGlyph write SetGlyph;
    property Layout: TButtonLayout read FLayout write SetLayout default blGlyphLeft;
    property Margin: Integer read FMargin write SetMargin default -1;
    property NumGlyphs: TNumGlyphs read FNumGlyphs write SetNumGlyphs default 1;
    property ParentFont;
    property ParentShowHint;
    property ParentBiDiMode;
    property PopupMenu;
    property ShowHint;
    property Spacing: Integer read FSpacing write SetSpacing default 4;
    property Transparent: Boolean read FTransparent write SetTransparent default True;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

function DrawButtonFace(Canvas: TCanvas; const Client: TRect; BevelWidth: Integer;
  Style: TButtonStyle; IsRounded, IsDown, IsFocused: Boolean): TRect;

implementation

uses Math;

const
  BitBtnCaptions: array[TBitBtnKind] of string = ('', 'OK', 'Annuleren', '&Help', '&Ja', '&Nee',
    '&Sluiten', '&Afbreken', '&Opnieuw', '&Negeren', '&Alles');
  BitBtnModalResults: array[TBitBtnKind] of TModalResult = (0, mrOk, mrCancel, 0, mrYes, mrNo,
    0, mrAbort, mrRetry, mrIgnore, mrAll);

function DrawButtonFace(Canvas: TCanvas; const Client: TRect; BevelWidth: Integer;
  Style: TButtonStyle; IsRounded, IsDown, IsFocused: Boolean): TRect;
begin
  Result := Client;
  ZMTekenKnopvlak(Canvas, Result, IsDown, False, IsFocused);
  InflateRect(Result, -2, -2);
end;

{ Tekent het glyph van een standaard knopsoort, 16x16, op X, Y. }
procedure TekenSoortGlyph(Tekenvlak: TCanvas; Soort: TBitBtnKind; X, Y: Integer; Ingeschakeld: Boolean);
var
  I: Integer;
  C: TColor;
begin
  with Tekenvlak do
    case Soort of
      bkOK, bkYes, bkAll:
        begin
          if Ingeschakeld then C := clGreen else C := clBtnShadow;
          Pen.Color := C;
          for I := 0 to 1 do
          begin
            MoveTo(X + 2, Y + 8 + I);
            LineTo(X + 6, Y + 12 + I);
            LineTo(X + 14, Y + 4 + I);
          end;
          MoveTo(X + 2, Y + 7);
          LineTo(X + 6, Y + 11);
          LineTo(X + 14, Y + 3);
        end;
      bkCancel, bkNo, bkAbort:
        begin
          if Ingeschakeld then C := clRed else C := clBtnShadow;
          Pen.Color := C;
          for I := 0 to 1 do
          begin
            MoveTo(X + 3 + I, Y + 3);
            LineTo(X + 13 + I, Y + 13);
            MoveTo(X + 12 + I, Y + 3);
            LineTo(X + 2 + I, Y + 13);
          end;
        end;
      bkHelp, bkIgnore, bkRetry, bkClose:
        begin
          if Ingeschakeld then C := clNavy else C := clBtnShadow;
          Font.Color := C;
          Brush.Style := bsClear;
          case Soort of
            bkHelp: TextOut(X + 4, Y, '?');
            bkIgnore: TextOut(X + 4, Y, '!');
            bkRetry: TextOut(X + 3, Y, '@');
            bkClose: TextOut(X + 3, Y, '>');
          end;
        end;
    end;
end;

procedure TekenGlyphEnTekst(Tekenvlak: TCanvas; R: TRect; Glyph: TBitmap; Aantalglyphs: Integer;
  Soort: TBitBtnKind; const Titel: string; Indeling: TButtonLayout; Marge, Afstand: Integer;
  Ingeschakeld, Omlaag: Boolean);
var
  GW, GH, TW, TH, X, Y, Totaalbreedte, Totaalhoogte, Idx, SX: Integer;
  TR: TRect;
  Bron: TBitmap;
  Deel: TBitmap;
  Heeftglyph, Voorraad: Boolean;
begin
  Voorraad := (Soort <> bkCustom) and ((Glyph = nil) or Glyph.Empty);
  Heeftglyph := Voorraad or ((Glyph <> nil) and not Glyph.Empty);
  if Voorraad then
  begin
    GW := 16;
    GH := 16;
  end
  else if Heeftglyph then
  begin
    GW := Glyph.Width div Max(1, Aantalglyphs);
    GH := Glyph.Height;
  end
  else
  begin
    GW := 0;
    GH := 0;
  end;
  TR := Rect(0, 0, R.Right - R.Left, 0);
  DrawText(Tekenvlak.Handle, PChar(Titel), Length(Titel), TR, DT_CALCRECT or DT_SINGLELINE);
  TW := TR.Right;
  TH := TR.Bottom;
  if Titel = '' then TW := 0;
  if Afstand < 0 then Afstand := 4;
  if (GW = 0) or (TW = 0) then Afstand := 0;
  if Indeling in [blGlyphLeft, blGlyphRight] then
  begin
    Totaalbreedte := GW + Afstand + TW;
    if Marge < 0 then X := R.Left + (R.Right - R.Left - Totaalbreedte) div 2 else X := R.Left + Marge;
    Y := R.Top + (R.Bottom - R.Top - GH) div 2;
    if Indeling = blGlyphRight then
    begin
      TR := Rect(X, R.Top, X + TW, R.Bottom);
      X := X + TW + Afstand;
    end
    else
      TR := Rect(X + GW + Afstand, R.Top, X + GW + Afstand + TW, R.Bottom);
  end
  else
  begin
    Totaalhoogte := GH + Afstand + TH;
    X := R.Left + (R.Right - R.Left - GW) div 2;
    if Marge < 0 then Y := R.Top + (R.Bottom - R.Top - Totaalhoogte) div 2 else Y := R.Top + Marge;
    if Indeling = blGlyphBottom then
    begin
      TR := Rect(R.Left, Y, R.Right, Y + TH);
      Y := Y + TH + Afstand;
    end
    else
      TR := Rect(R.Left, Y + GH + Afstand, R.Right, Y + GH + Afstand + TH);
  end;
  if Omlaag then
  begin
    Inc(X);
    Inc(Y);
    OffsetRect(TR, 1, 1);
  end;
  if Voorraad then
    TekenSoortGlyph(Tekenvlak, Soort, X, Y, Ingeschakeld)
  else if Heeftglyph then
  begin
    Idx := 0;
    if not Ingeschakeld and (Aantalglyphs >= 2) then Idx := 1;
    if Omlaag and (Aantalglyphs >= 3) then Idx := 2;
    SX := Idx * GW;
    Deel := TBitmap.Create;
    try
      Deel.Width := GW;
      Deel.Height := GH;
      Deel.Canvas.CopyRect(Rect(0, 0, GW, GH), Glyph.Canvas, Rect(SX, 0, SX + GW, GH));
      Deel.Transparent := True;
      Deel.TransparentColor := Glyph.Canvas.Pixels[SX, GH - 1];
      Bron := Deel;
      Tekenvlak.Draw(X, Y, Bron);
    finally
      Deel.Free;
    end;
  end;
  Tekenvlak.Brush.Style := bsClear;
  if Ingeschakeld then
    DrawText(Tekenvlak.Handle, PChar(Titel), Length(Titel), TR, DT_CENTER or DT_VCENTER or DT_SINGLELINE)
  else
    ZMTekenUitgeschakeldeTekst(Tekenvlak, TR, Titel, DT_CENTER or DT_VCENTER or DT_SINGLELINE);
end;

{ ---------------------------------------------------------------- TBitBtn }

constructor TBitBtn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FGlyph := TBitmap.Create;
  FGlyph.OnChange := GlyphChanged;
  FKind := bkCustom;
  FLayout := blGlyphLeft;
  FStyle := bsAutoDetect;
  FSpacing := 4;
  FMargin := -1;
  FNumGlyphs := 1;
  ControlStyle := ControlStyle + [csReflector];
end;

destructor TBitBtn.Destroy;
begin
  FGlyph.Free;
  inherited Destroy;
end;

procedure TBitBtn.Click;
var
  Formulier: TCustomForm;
begin
  if FKind = bkClose then
  begin
    Formulier := GetParentForm(Self);
    if Formulier <> nil then Formulier.Close
    else inherited Click;
  end
  else
    inherited Click;
end;

function TBitBtn.GetGlyph: TBitmap;
begin
  Result := FGlyph;
end;

procedure TBitBtn.SetGlyph(Value: TBitmap);
begin
  FGlyph.Assign(Value);
  FModifiedGlyph := True;
  Invalidate;
end;

procedure TBitBtn.GlyphChanged(Sender: TObject);
begin
  if (FGlyph.Width > 0) and (FGlyph.Height > 0) and (FGlyph.Width mod FGlyph.Height = 0) and
    (FGlyph.Width div FGlyph.Height in [1..4]) and (csLoading in ComponentState) then ;
  Invalidate;
end;

function TBitBtn.GetKind: TBitBtnKind;
begin
  Result := FKind;
end;

procedure TBitBtn.SetKind(Value: TBitBtnKind);
begin
  if Value <> FKind then
  begin
    if Value <> bkCustom then
    begin
      Default := Value in [bkOK, bkYes];
      Cancel := Value in [bkCancel, bkNo];
      if ((csLoading in ComponentState) and (Caption = '')) or not (csLoading in ComponentState) then
        if BitBtnCaptions[Value] <> '' then Caption := BitBtnCaptions[Value];
      ModalResult := BitBtnModalResults[Value];
      FGlyph.Assign(nil);
    end;
    FKind := Value;
    Invalidate;
  end;
end;

function TBitBtn.IsCustom: Boolean;
begin
  Result := Kind = bkCustom;
end;

function TBitBtn.IsCustomCaption: Boolean;
begin
  Result := AnsiCompareStr(Caption, BitBtnCaptions[FKind]) <> 0;
end;

procedure TBitBtn.SetLayout(Value: TButtonLayout);
begin
  FLayout := Value;
  Invalidate;
end;

procedure TBitBtn.SetSpacing(Value: Integer);
begin
  FSpacing := Value;
  Invalidate;
end;

procedure TBitBtn.SetMargin(Value: Integer);
begin
  FMargin := Value;
  Invalidate;
end;

procedure TBitBtn.SetNumGlyphs(Value: TNumGlyphs);
begin
  FNumGlyphs := Value;
  Invalidate;
end;

procedure TBitBtn.SetStyle(Value: TButtonStyle);
begin
  FStyle := Value;
  Invalidate;
end;

procedure TBitBtn.Paint;
var
  R: TRect;
  C: TCanvas;
  Omlaag: Boolean;
begin
  C := PaintCanvas;
  begin
    R := ClientRect;
    Omlaag := FPressed and FMouseInside;
    ZMTekenKnopvlak(C, R, Omlaag, Default or Focused, Focused);
    C.Font := Font;
    InflateRect(R, -2, -2);
    TekenGlyphEnTekst(C, R, FGlyph, FNumGlyphs, FKind, Caption, FLayout, FMargin, FSpacing,
      Enabled, Omlaag);
    if Focused then
    begin
      R := ClientRect;
      InflateRect(R, -4, -4);
      C.Brush.Color := clBtnFace;
      C.DrawFocusRect(R);
    end;
  end;
end;

{ ---------------------------------------------------------------- TSpeedButton }

constructor TSpeedButton.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  SetBounds(0, 0, 23, 22);
  ControlStyle := [csCaptureMouse, csDoubleClicks];
  ParentFont := True;
  Color := clBtnFace;
  FGlyph := TBitmap.Create;
  FGlyph.OnChange := GlyphChanged;
  FSpacing := 4;
  FMargin := -1;
  FLayout := blGlyphLeft;
  FTransparent := True;
  FNumGlyphs := 1;
end;

destructor TSpeedButton.Destroy;
begin
  FGlyph.Free;
  inherited Destroy;
end;

procedure TSpeedButton.Loaded;
begin
  inherited Loaded;
  if Enabled then FState := bsUp else FState := bsDisabled;
end;

procedure TSpeedButton.Paint;
var
  R: TRect;
  Omlaag: Boolean;
begin
  if not Enabled then FState := bsDisabled
  else if FState = bsDisabled then
    if FDown and (GroupIndex <> 0) then FState := bsExclusive else FState := bsUp;
  Omlaag := FState in [bsDown, bsExclusive];
  R := ClientRect;
  Canvas.Font := Font;
  if not FFlat or FMouseInControl or Omlaag then
    ZMTekenKnopvlak(Canvas, R, Omlaag, False, False)
  else if not FTransparent then
  begin
    Canvas.Brush.Color := Color;
    Canvas.FillRect(R);
  end;
  InflateRect(R, -2, -2);
  TekenGlyphEnTekst(Canvas, R, FGlyph, FNumGlyphs, bkCustom, Caption, FLayout, FMargin, FSpacing,
    Enabled, Omlaag);
end;

procedure TSpeedButton.UpdateExclusive;
var
  Bericht: TMessage;
begin
  if (FGroupIndex <> 0) and (Parent <> nil) then
  begin
    FillChar(Bericht, SizeOf(Bericht), 0);
    Bericht.Msg := CM_BUTTONPRESSED;
    Bericht.WParam := FGroupIndex;
    Bericht.LParam := LPARAM(Self);
    Parent.Broadcast(Bericht);
  end;
end;

procedure TSpeedButton.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited MouseDown(Button, Shift, X, Y);
  if (Button = mbLeft) and Enabled then
  begin
    if not FDown then
    begin
      FState := bsDown;
      Invalidate;
    end;
    FDragging := True;
  end;
end;

procedure TSpeedButton.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Nieuwestaat: TButtonState;
begin
  inherited MouseMove(Shift, X, Y);
  if FDragging then
  begin
    if not FDown then Nieuwestaat := bsUp else Nieuwestaat := bsExclusive;
    if (X >= 0) and (X < ClientWidth) and (Y >= 0) and (Y <= ClientHeight) then
      if FDown then Nieuwestaat := bsExclusive else Nieuwestaat := bsDown;
    if Nieuwestaat <> FState then
    begin
      FState := Nieuwestaat;
      Invalidate;
    end;
  end;
end;

procedure TSpeedButton.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  DoKlik: Boolean;
begin
  inherited MouseUp(Button, Shift, X, Y);
  if FDragging then
  begin
    FDragging := False;
    DoKlik := (X >= 0) and (X < ClientWidth) and (Y >= 0) and (Y <= ClientHeight);
    if FGroupIndex = 0 then
    begin
      FState := bsUp;
      FMouseInControl := False;
      if DoKlik and not (FState in [bsExclusive, bsDown]) then Invalidate;
    end
    else if DoKlik then
    begin
      SetDown(not FDown);
      if FDown then Repaint;
    end
    else
    begin
      if FDown then FState := bsExclusive;
      Repaint;
    end;
    if DoKlik then Click;
  end;
end;

procedure TSpeedButton.Click;
begin
  inherited Click;
end;

function TSpeedButton.GetGlyph: TBitmap;
begin
  Result := FGlyph;
end;

procedure TSpeedButton.SetGlyph(Value: TBitmap);
begin
  FGlyph.Assign(Value);
  Invalidate;
end;

procedure TSpeedButton.GlyphChanged(Sender: TObject);
begin
  Invalidate;
end;

procedure TSpeedButton.SetDown(Value: Boolean);
begin
  if FGroupIndex = 0 then Value := False;
  if Value <> FDown then
  begin
    if FDown and (not FAllowAllUp) then Exit;
    FDown := Value;
    if Value then
    begin
      if FState = bsUp then Invalidate;
      FState := bsExclusive;
    end
    else
    begin
      FState := bsUp;
      Repaint;
    end;
    if Value then UpdateExclusive;
  end;
end;

procedure TSpeedButton.SetFlat(Value: Boolean);
begin
  FFlat := Value;
  Invalidate;
end;

procedure TSpeedButton.SetGroupIndex(Value: Integer);
begin
  if FGroupIndex <> Value then
  begin
    FGroupIndex := Value;
    UpdateExclusive;
  end;
end;

procedure TSpeedButton.SetLayout(Value: TButtonLayout);
begin
  FLayout := Value;
  Invalidate;
end;

procedure TSpeedButton.SetMargin(Value: Integer);
begin
  FMargin := Value;
  Invalidate;
end;

procedure TSpeedButton.SetNumGlyphs(Value: TNumGlyphs);
begin
  FNumGlyphs := Value;
  Invalidate;
end;

procedure TSpeedButton.SetSpacing(Value: Integer);
begin
  FSpacing := Value;
  Invalidate;
end;

procedure TSpeedButton.SetTransparent(Value: Boolean);
begin
  FTransparent := Value;
  Invalidate;
end;

procedure TSpeedButton.SetAllowAllUp(Value: Boolean);
begin
  if FAllowAllUp <> Value then
  begin
    FAllowAllUp := Value;
    UpdateExclusive;
  end;
end;

procedure TSpeedButton.CMButtonPressed(var Message: TMessage);
var
  Sender: TSpeedButton;
begin
  if Message.WParam = WPARAM(FGroupIndex) then
  begin
    Sender := TSpeedButton(Message.LParam);
    if Sender <> Self then
    begin
      if Sender.Down and FDown then
      begin
        FDown := False;
        FState := bsUp;
        Invalidate;
      end;
      FAllowAllUp := Sender.AllowAllUp;
    end;
  end;
end;

procedure TSpeedButton.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  if FFlat and not FMouseInControl and Enabled then
  begin
    FMouseInControl := True;
    Repaint;
  end;
end;

procedure TSpeedButton.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if FFlat and FMouseInControl and Enabled and not FDragging then
  begin
    FMouseInControl := False;
    Invalidate;
  end;
end;

initialization
  RegisterClasses([TBitBtn, TSpeedButton]);
end.

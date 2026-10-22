unit Dialogs;

{ Delphi 5-subset van de Dialogs-unit: ShowMessage, MessageDlg, InputBox/InputQuery en
  TOpenDialog/TSaveDialog, geimplementeerd als modale formulieren binnen het nagebootste
  scherm (geen native dialogen, dus dit werkt ook in een browser). }

{$MODE DELPHI}{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls;

type
  TMsgDlgType = (mtWarning, mtError, mtInformation, mtConfirmation, mtCustom);
  TMsgDlgBtn = (mbYes, mbNo, mbOK, mbCancel, mbAbort, mbRetry, mbIgnore, mbAll, mbNoToAll,
    mbYesToAll, mbHelp);
  TMsgDlgButtons = set of TMsgDlgBtn;

const
  mbYesNoCancel = [mbYes, mbNo, mbCancel];
  mbOKCancel = [mbOK, mbCancel];
  mbAbortRetryIgnore = [mbAbort, mbRetry, mbIgnore];

type
  TCommonDialog = class(TComponent)
  private
    FCtl3D: Boolean;
    FHelpContext: THelpContext;
    FHandle: HWND;
    FOnClose: TNotifyEvent;
    FOnShow: TNotifyEvent;
  protected
    procedure DoClose; dynamic;
    procedure DoShow; dynamic;
  public
    constructor Create(AOwner: TComponent); override;
    function Execute: Boolean; virtual; abstract;
    property Handle: HWND read FHandle;
  published
    property Ctl3D: Boolean read FCtl3D write FCtl3D default True;
    property HelpContext: THelpContext read FHelpContext write FHelpContext default 0;
    property OnClose: TNotifyEvent read FOnClose write FOnClose;
    property OnShow: TNotifyEvent read FOnShow write FOnShow;
  end;

  TOpenOption = (ofReadOnly, ofOverwritePrompt, ofHideReadOnly, ofNoChangeDir, ofShowHelp,
    ofNoValidate, ofAllowMultiSelect, ofExtensionDifferent, ofPathMustExist,
    ofFileMustExist, ofCreatePrompt, ofShareAware, ofNoReadOnlyReturn, ofNoTestFileCreate,
    ofNoNetworkButton, ofNoLongNames, ofOldStyleDialog, ofNoDereferenceLinks, ofEnableIncludeNotify,
    ofEnableSizing);
  TOpenOptions = set of TOpenOption;
  TFileEditStyle = (fsEdit, fsComboBox);
  TIncludeItemEvent = procedure(const OFN: Pointer; var Include: Boolean) of object;

  TOpenDialog = class(TCommonDialog)
  private
    FHistoryList: TStrings;
    FOptions: TOpenOptions;
    FFilter: string;
    FFilterIndex: Integer;
    FCurrentFilterIndex: Integer;
    FInitialDir: string;
    FTitle: string;
    FDefaultExt: string;
    FFileName: TFileName;
    FFiles: TStrings;
    FFileEditStyle: TFileEditStyle;
    FOnSelectionChange: TNotifyEvent;
    FOnFolderChange: TNotifyEvent;
    FOnTypeChange: TNotifyEvent;
    FOnCanClose: TCloseQueryEvent;
    FOnIncludeItem: TIncludeItemEvent;
    function GetFileName: TFileName;
    function GetFilterIndex: Integer;
    procedure SetHistoryList(Value: TStrings);
    procedure SetInitialDir(const Value: string);
  protected
    FIsSave: Boolean;
    function DoCanClose: Boolean; dynamic;
    function DoExecute: Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: Boolean; override;
    property FileEditStyle: TFileEditStyle read FFileEditStyle write FFileEditStyle;
    property Files: TStrings read FFiles;
    property HistoryList: TStrings read FHistoryList write SetHistoryList;
  published
    property DefaultExt: string read FDefaultExt write FDefaultExt;
    property FileName: TFileName read GetFileName write FFileName;
    property Filter: string read FFilter write FFilter;
    property FilterIndex: Integer read GetFilterIndex write FFilterIndex default 1;
    property InitialDir: string read FInitialDir write SetInitialDir;
    property Options: TOpenOptions read FOptions write FOptions default [ofHideReadOnly];
    property Title: string read FTitle write FTitle;
    property OnCanClose: TCloseQueryEvent read FOnCanClose write FOnCanClose;
    property OnFolderChange: TNotifyEvent read FOnFolderChange write FOnFolderChange;
    property OnSelectionChange: TNotifyEvent read FOnSelectionChange write FOnSelectionChange;
    property OnTypeChange: TNotifyEvent read FOnTypeChange write FOnTypeChange;
    property OnIncludeItem: TIncludeItemEvent read FOnIncludeItem write FOnIncludeItem;
  end;

  TSaveDialog = class(TOpenDialog)
  public
    constructor Create(AOwner: TComponent); override;
    function Execute: Boolean; override;
  end;

  TColorDialog = class(TCommonDialog)
  private
    FColor: TColor;
  public
    function Execute: Boolean; override;
  published
    property Color: TColor read FColor write FColor default clBlack;
  end;

  TFontDialog = class(TCommonDialog)
  private
    FFont: TFont;
    procedure SetFont(Value: TFont);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Execute: Boolean; override;
  published
    property Font: TFont read FFont write SetFont;
  end;

function CreateMessageDialog(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons): TForm;
function MessageDlg(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons;
  HelpCtx: Longint): Integer;
function MessageDlgPos(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons;
  HelpCtx: Longint; X, Y: Integer): Integer;
procedure ShowMessage(const Msg: string);
procedure ShowMessageFmt(const Msg: string; Params: array of const);
procedure ShowMessagePos(const Msg: string; X, Y: Integer);
function InputBox(const ACaption, APrompt, ADefault: string): string;
function InputQuery(const ACaption, APrompt: string; var Value: string): Boolean;

implementation

uses Math, ZMData;

const
  BtnCaptions: array[TMsgDlgBtn] of string = ('&Ja', '&Nee', 'OK', 'Annuleren', '&Afbreken',
    '&Opnieuw', '&Negeren', '&Alles', 'N&ee voor alles', 'Ja voor a&lles', '&Help');
  BtnResults: array[TMsgDlgBtn] of Integer = (mrYes, mrNo, mrOk, mrCancel, mrAbort,
    mrRetry, mrIgnore, mrAll, mrNoToAll, mrYesToAll, 0);
  DlgCaptions: array[TMsgDlgType] of string = ('Waarschuwing', 'Fout', 'Informatie',
    'Bevestigen', '');

function CreateMessageDialog(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons): TForm;
var
  Lbl: TLabel;
  B: TButton;
  Knop: TMsgDlgBtn;
  N, X, BW, BH, Totaalbreedte, Tekstbreedte, Teksthoogte: Integer;
  R: TRect;
  Standaardset: Boolean;
begin
  Result := TForm.CreateNew(Application);
  Result.BorderStyle := bsDialog;
  if DlgType = mtCustom then Result.Caption := Application.Title
  else Result.Caption := DlgCaptions[DlgType];
  Result.Position := poScreenCenter;
  Result.Font.Name := 'MS Sans Serif';
  Result.Font.Height := -11;
  Result.Canvas.Font := Result.Font;
  R := Rect(0, 0, 400, 0);
  DrawText(Result.Canvas.Handle, PChar(Msg), Length(Msg), R, DT_CALCRECT or DT_WORDBREAK or DT_NOPREFIX);
  Tekstbreedte := Max(R.Right, 100);
  Teksthoogte := R.Bottom;
  Lbl := TLabel.Create(Result);
  Lbl.Parent := Result;
  Lbl.AutoSize := False;
  Lbl.WordWrap := True;
  Lbl.ShowAccelChar := False;
  Lbl.Caption := Msg;
  Lbl.SetBounds(16, 16, Tekstbreedte, Teksthoogte);
  BW := 75;
  BH := 25;
  N := 0;
  for Knop := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
    if Knop in Buttons then Inc(N);
  if N = 0 then
  begin
    Buttons := [mbOK];
    N := 1;
  end;
  Totaalbreedte := N * BW + (N - 1) * 8;
  Result.ClientWidth := Max(Tekstbreedte + 32, Totaalbreedte + 32);
  Result.ClientHeight := Teksthoogte + 32 + BH + 12;
  X := (Result.ClientWidth - Totaalbreedte) div 2;
  Standaardset := False;
  for Knop := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
    if Knop in Buttons then
    begin
      B := TButton.Create(Result);
      B.Parent := Result;
      B.Caption := BtnCaptions[Knop];
      B.ModalResult := BtnResults[Knop];
      B.SetBounds(X, Teksthoogte + 32, BW, BH);
      if not Standaardset and (Knop in [mbOK, mbYes]) then
      begin
        B.Default := True;
        Result.ActiveControl := B;
        Standaardset := True;
      end;
      if (Knop = mbCancel) or ((Knop = mbNo) and not (mbCancel in Buttons)) then B.Cancel := True;
      Inc(X, BW + 8);
    end;
end;

function MessageDlgPos(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons;
  HelpCtx: Longint; X, Y: Integer): Integer;
var
  F: TForm;
begin
  F := CreateMessageDialog(Msg, DlgType, Buttons);
  try
    if X >= 0 then
    begin
      F.Position := poDesigned;
      F.Left := X;
    end;
    if Y >= 0 then F.Top := Y;
    Result := F.ShowModal;
  finally
    F.Free;
  end;
end;

function MessageDlg(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons;
  HelpCtx: Longint): Integer;
begin
  Result := MessageDlgPos(Msg, DlgType, Buttons, HelpCtx, -1, -1);
end;

procedure ShowMessage(const Msg: string);
begin
  ShowMessagePos(Msg, -1, -1);
end;

procedure ShowMessageFmt(const Msg: string; Params: array of const);
begin
  ShowMessage(Format(Msg, Params));
end;

procedure ShowMessagePos(const Msg: string; X, Y: Integer);
begin
  MessageDlgPos(Msg, mtCustom, [mbOK], 0, X, Y);
end;

function InputQuery(const ACaption, APrompt: string; var Value: string): Boolean;
var
  F: TForm;
  L: TLabel;
  E: TEdit;
  B: TButton;
begin
  Result := False;
  F := TForm.CreateNew(Application);
  try
    F.BorderStyle := bsDialog;
    F.Caption := ACaption;
    F.Position := poScreenCenter;
    F.Font.Name := 'MS Sans Serif';
    F.Font.Height := -11;
    F.ClientWidth := 260;
    F.ClientHeight := 100;
    L := TLabel.Create(F);
    L.Parent := F;
    L.Caption := APrompt;
    L.SetBounds(8, 8, 240, 16);
    E := TEdit.Create(F);
    E.Parent := F;
    E.SetBounds(8, 28, 244, 21);
    E.Text := Value;
    E.SelectAll;
    B := TButton.Create(F);
    B.Parent := F;
    B.Caption := 'OK';
    B.ModalResult := mrOk;
    B.Default := True;
    B.SetBounds(96, 64, 75, 25);
    B := TButton.Create(F);
    B.Parent := F;
    B.Caption := 'Annuleren';
    B.ModalResult := mrCancel;
    B.Cancel := True;
    B.SetBounds(177, 64, 75, 25);
    F.ActiveControl := E;
    if F.ShowModal = mrOk then
    begin
      Value := E.Text;
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

function InputBox(const ACaption, APrompt, ADefault: string): string;
begin
  Result := ADefault;
  InputQuery(ACaption, APrompt, Result);
end;

{ ---------------------------------------------------------------- TCommonDialog }

constructor TCommonDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCtl3D := True;
end;

procedure TCommonDialog.DoClose;
begin
  if Assigned(FOnClose) then FOnClose(Self);
end;

procedure TCommonDialog.DoShow;
begin
  if Assigned(FOnShow) then FOnShow(Self);
end;

{ ---------------------------------------------------------------- bestandsdialoog }

type
  TBestandsDialoogForm = class(TForm)
  public
    Dialoog: TOpenDialog;
    Dir: string;
    LblMap: TLabel;
    List: TListBox;
    Bewerk: TEdit;
    Types: TComboBox;
    KnopOK, KnopAnnuleren: TButton;
    Maskerlijst: TStringList;
    procedure Fill;
    procedure LijstKlik(Sender: TObject);
    procedure LijstDubbelKlik(Sender: TObject);
    procedure TypenWijzigen(Sender: TObject);
    procedure OKKlik(Sender: TObject);
    function HuidigeMaskers: TStringList;
  end;

function PasMasker(const Naam, Masker: string): Boolean;
var
  N, M: string;
  function Passend(NI, MI: Integer): Boolean;
  begin
    while MI <= Length(M) do
    begin
      case M[MI] of
        '*':
          begin
            if MI = Length(M) then Exit(True);
            while NI <= Length(N) + 1 do
            begin
              if Passend(NI, MI + 1) then Exit(True);
              Inc(NI);
            end;
            Exit(False);
          end;
        '?':
          if NI > Length(N) then Exit(False);
      else
        if (NI > Length(N)) or (N[NI] <> M[MI]) then Exit(False);
      end;
      Inc(NI);
      Inc(MI);
    end;
    Result := NI > Length(N);
  end;
begin
  N := LowerCase(Naam);
  M := LowerCase(Masker);
  if (M = '*.*') then Exit(True);
  Result := Passend(1, 1);
end;

function TBestandsDialoogForm.HuidigeMaskers: TStringList;
var
  Delen: TStringList;
  I, Idx: Integer;
  S: string;
begin
  Result := TStringList.Create;
  Delen := TStringList.Create;
  try
    Delen.Delimiter := '|';
    Delen.StrictDelimiter := True;
    Delen.DelimitedText := Dialoog.Filter;
    Idx := Types.ItemIndex;
    if Idx < 0 then Idx := 0;
    if 2 * Idx + 1 < Delen.Count then S := Delen[2 * Idx + 1] else S := '*.*';
    Result.Delimiter := ';';
    Result.StrictDelimiter := True;
    Result.DelimitedText := S;
    for I := 0 to Result.Count - 1 do Result[I] := Trim(Result[I]);
  finally
    Delen.Free;
  end;
end;

procedure TBestandsDialoogForm.Fill;
var
  SR: TSearchRec;
  Mappen, Bestanden: TStringList;
  M: TStringList;
  I: Integer;
  Ok: Boolean;
begin
  Mappen := TStringList.Create;
  Bestanden := TStringList.Create;
  M := HuidigeMaskers;
  try
    Mappen.Sorted := True;
    Bestanden.Sorted := True;
    if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name = '.') then Continue;
        if SR.Attr and faDirectory <> 0 then
        begin
          if (SR.Name <> '..') and (SR.Name[1] = '.') then Continue;
          Mappen.Add('[' + SR.Name + ']');
        end
        else
        begin
          Ok := False;
          for I := 0 to M.Count - 1 do
            if PasMasker(SR.Name, M[I]) then Ok := True;
          if Ok then Bestanden.Add(SR.Name);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    if (Mappen.IndexOf('[..]') < 0) and (ExcludeTrailingPathDelimiter(Dir) <> '') and (Dir <> '/') then
      Mappen.Add('[..]');
    List.Items.BeginUpdate;
    try
      List.Items.Clear;
      List.Items.AddStrings(Mappen);
      List.Items.AddStrings(Bestanden);
    finally
      List.Items.EndUpdate;
    end;
    LblMap.Caption := Dir;
  finally
    Mappen.Free;
    Bestanden.Free;
    M.Free;
  end;
end;

procedure TBestandsDialoogForm.LijstKlik(Sender: TObject);
var
  S: string;
begin
  if List.ItemIndex < 0 then Exit;
  S := List.Items[List.ItemIndex];
  if (S <> '') and (S[1] <> '[') then Bewerk.Text := S;
end;

procedure TBestandsDialoogForm.LijstDubbelKlik(Sender: TObject);
var
  S: string;
begin
  if List.ItemIndex < 0 then Exit;
  S := List.Items[List.ItemIndex];
  if (S <> '') and (S[1] = '[') then
  begin
    S := Copy(S, 2, Length(S) - 2);
    if S = '..' then
      Dir := ExtractFileDir(ExcludeTrailingPathDelimiter(Dir))
    else
      Dir := IncludeTrailingPathDelimiter(Dir) + S;
    if Dir = '' then Dir := PathDelim;
    Fill;
  end
  else
  begin
    Bewerk.Text := S;
    OKKlik(nil);
  end;
end;

procedure TBestandsDialoogForm.TypenWijzigen(Sender: TObject);
begin
  Fill;
end;

procedure TBestandsDialoogForm.OKKlik(Sender: TObject);
var
  S: string;
begin
  S := Trim(Bewerk.Text);
  if S = '' then Exit;
  if (Pos('*', S) > 0) or (Pos('?', S) > 0) then
  begin
    Fill;
    Exit;
  end;
  if (Dialoog.DefaultExt <> '') and (ExtractFileExt(S) = '') then
    S := S + '.' + Dialoog.DefaultExt;
  if (S[1] <> PathDelim) then S := IncludeTrailingPathDelimiter(Dir) + S;
  if DirectoryExists(S) then
  begin
    Dir := S;
    Bewerk.Text := '';
    Fill;
    Exit;
  end;
  if (ofFileMustExist in Dialoog.Options) and not FileExists(S) then
  begin
    MessageDlg(ExtractFileName(S) + #13#10 + 'Bestand niet gevonden.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if Dialoog.FIsSave and (ofOverwritePrompt in Dialoog.Options) and FileExists(S) then
    if MessageDlg(ExtractFileName(S) + ' bestaat al.' + #13#10 + 'Wilt u het vervangen?',
      mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  Dialoog.FFileName := S;
  ModalResult := mrOk;
end;

constructor TOpenDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHistoryList := TStringList.Create;
  FOptions := [ofHideReadOnly];
  FFiles := TStringList.Create;
  FFilterIndex := 1;
end;

destructor TOpenDialog.Destroy;
begin
  FFiles.Free;
  FHistoryList.Free;
  inherited Destroy;
end;

function TOpenDialog.GetFileName: TFileName;
begin
  Result := FFileName;
end;

function TOpenDialog.GetFilterIndex: Integer;
begin
  Result := FFilterIndex;
end;

procedure TOpenDialog.SetHistoryList(Value: TStrings);
begin
  FHistoryList.Assign(Value);
end;

procedure TOpenDialog.SetInitialDir(const Value: string);
var
  L: Integer;
begin
  L := Length(Value);
  if (L > 1) and IsPathDelimiter(Value, L) and not IsDelimiter(':', Value, L - 1) then Dec(L);
  FInitialDir := Copy(Value, 1, L);
end;

function TOpenDialog.DoCanClose: Boolean;
begin
  Result := True;
  if Assigned(FOnCanClose) then FOnCanClose(Self, Result);
end;

function TOpenDialog.DoExecute: Boolean;
var
  F: TBestandsDialoogForm;
  Delen: TStringList;
  I: Integer;
  L: TLabel;
  Start: string;
begin
  Result := False;
  F := TBestandsDialoogForm.CreateNew(Application);
  try
    F.Dialoog := Self;
    F.BorderStyle := bsDialog;
    if FTitle <> '' then F.Caption := FTitle
    else if FIsSave then F.Caption := 'Opslaan als'
    else F.Caption := 'Openen';
    F.Position := poScreenCenter;
    F.Font.Name := 'MS Sans Serif';
    F.Font.Height := -11;
    F.ClientWidth := 420;
    F.ClientHeight := 300;
    { startmap }
    Start := '';
    if FFileName <> '' then Start := ExtractFilePath(ZMOplosPad(FFileName));
    if (Start = '') and (FInitialDir <> '') then Start := ZMOplosPad(FInitialDir);
    { Zonder beginmap (of als die in de datamap ligt, zoals de spelmap op Windows)
      begint de dialoog in de overlay, waar bewaarde spellen staan. }
    if (Start <> '') and (ZMBewaarMap <> '') and
      ZMInDataMap(IncludeTrailingPathDelimiter(ExpandFileName(Start)) + 'x') then
      Start := ZMBewaarMap;
    if (Start = '') and (ZMBewaarMap <> '') then Start := ZMBewaarMap;
    if (Start = '') or not DirectoryExists(Start) then Start := GetCurrentDir;
    F.Dir := ExcludeTrailingPathDelimiter(ExpandFileName(Start));
    if F.Dir = '' then F.Dir := PathDelim;
    F.LblMap := TLabel.Create(F);
    F.LblMap.Parent := F;
    F.LblMap.AutoSize := False;
    F.LblMap.SetBounds(8, 8, 404, 16);
    F.List := TListBox.Create(F);
    F.List.Parent := F;
    F.List.SetBounds(8, 28, 404, 180);
    F.List.OnClick := F.LijstKlik;
    F.List.OnDblClick := F.LijstDubbelKlik;
    L := TLabel.Create(F);
    L.Parent := F;
    L.Caption := '&Bestandsnaam:';
    L.SetBounds(8, 220, 80, 16);
    F.Bewerk := TEdit.Create(F);
    F.Bewerk.Parent := F;
    F.Bewerk.SetBounds(96, 216, 228, 21);
    F.Bewerk.Text := ExtractFileName(FFileName);
    L := TLabel.Create(F);
    L.Parent := F;
    L.Caption := 'Bestands&type:';
    L.SetBounds(8, 250, 80, 16);
    F.Types := TComboBox.Create(F);
    F.Types.Parent := F;
    F.Types.Style := csDropDownList;
    F.Types.SetBounds(96, 246, 228, 21);
    Delen := TStringList.Create;
    try
      Delen.Delimiter := '|';
      Delen.StrictDelimiter := True;
      Delen.DelimitedText := FFilter;
      I := 0;
      while I < Delen.Count do
      begin
        F.Types.Items.Add(Delen[I]);
        Inc(I, 2);
      end;
    finally
      Delen.Free;
    end;
    if F.Types.Items.Count = 0 then F.Types.Items.Add('Alle bestanden (*.*)');
    F.Types.ItemIndex := Max(0, Min(FFilterIndex - 1, F.Types.Items.Count - 1));
    F.Types.OnChange := F.TypenWijzigen;
    F.KnopOK := TButton.Create(F);
    F.KnopOK.Parent := F;
    if FIsSave then F.KnopOK.Caption := '&Opslaan' else F.KnopOK.Caption := '&Openen';
    F.KnopOK.Default := True;
    F.KnopOK.SetBounds(336, 214, 75, 25);
    F.KnopOK.OnClick := F.OKKlik;
    F.KnopAnnuleren := TButton.Create(F);
    F.KnopAnnuleren.Parent := F;
    F.KnopAnnuleren.Caption := 'Annuleren';
    F.KnopAnnuleren.Cancel := True;
    F.KnopAnnuleren.ModalResult := mrCancel;
    F.KnopAnnuleren.SetBounds(336, 244, 75, 25);
    F.Fill;
    F.ActiveControl := F.Bewerk;
    DoShow;
    if F.ShowModal = mrOk then
    begin
      FFilterIndex := F.Types.ItemIndex + 1;
      { opslaan in de datamap wordt opslaan in de overlay }
      if FIsSave then FFileName := ZMSchrijfPad(FFileName);
      FFiles.Clear;
      FFiles.Add(FFileName);
      Result := DoCanClose;
    end;
    DoClose;
  finally
    F.Free;
  end;
end;

function TOpenDialog.Execute: Boolean;
begin
  FIsSave := False;
  Result := DoExecute;
end;

constructor TSaveDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
end;

function TSaveDialog.Execute: Boolean;
begin
  FIsSave := True;
  Result := DoExecute;
end;

function TColorDialog.Execute: Boolean;
begin
  Result := False;
end;

constructor TFontDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FFont := TFont.Create;
end;

destructor TFontDialog.Destroy;
begin
  FFont.Free;
  inherited Destroy;
end;

procedure TFontDialog.SetFont(Value: TFont);
begin
  FFont.Assign(Value);
end;

function TFontDialog.Execute: Boolean;
begin
  Result := False;
end;

initialization
  RegisterClasses([TOpenDialog, TSaveDialog, TColorDialog, TFontDialog]);
end.

unit Dialogs;

{ Delphi 5 Dialogs subset: ShowMessage, MessageDlg, InputBox/InputQuery and
  TOpenDialog/TSaveDialog, implemented as modal forms inside the emulated screen
  (no native dialogs, so this also works in a browser). }

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
  BtnCaptions: array[TMsgDlgBtn] of string = ('&Yes', '&No', 'OK', 'Cancel', '&Abort',
    '&Retry', '&Ignore', '&All', 'N&o to All', 'Yes to &All', '&Help');
  BtnResults: array[TMsgDlgBtn] of Integer = (mrYes, mrNo, mrOk, mrCancel, mrAbort,
    mrRetry, mrIgnore, mrAll, mrNoToAll, mrYesToAll, 0);
  DlgCaptions: array[TMsgDlgType] of string = ('Warning', 'Error', 'Information',
    'Confirm', '');

function CreateMessageDialog(const Msg: string; DlgType: TMsgDlgType; Buttons: TMsgDlgButtons): TForm;
var
  Lbl: TLabel;
  B: TButton;
  Btn: TMsgDlgBtn;
  N, X, BW, BH, TotalW, TextW, TextH: Integer;
  R: TRect;
  DefSet: Boolean;
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
  TextW := Max(R.Right, 100);
  TextH := R.Bottom;
  Lbl := TLabel.Create(Result);
  Lbl.Parent := Result;
  Lbl.AutoSize := False;
  Lbl.WordWrap := True;
  Lbl.ShowAccelChar := False;
  Lbl.Caption := Msg;
  Lbl.SetBounds(16, 16, TextW, TextH);
  BW := 75;
  BH := 25;
  N := 0;
  for Btn := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
    if Btn in Buttons then Inc(N);
  if N = 0 then
  begin
    Buttons := [mbOK];
    N := 1;
  end;
  TotalW := N * BW + (N - 1) * 8;
  Result.ClientWidth := Max(TextW + 32, TotalW + 32);
  Result.ClientHeight := TextH + 32 + BH + 12;
  X := (Result.ClientWidth - TotalW) div 2;
  DefSet := False;
  for Btn := Low(TMsgDlgBtn) to High(TMsgDlgBtn) do
    if Btn in Buttons then
    begin
      B := TButton.Create(Result);
      B.Parent := Result;
      B.Caption := BtnCaptions[Btn];
      B.ModalResult := BtnResults[Btn];
      B.SetBounds(X, TextH + 32, BW, BH);
      if not DefSet and (Btn in [mbOK, mbYes]) then
      begin
        B.Default := True;
        Result.ActiveControl := B;
        DefSet := True;
      end;
      if (Btn = mbCancel) or ((Btn = mbNo) and not (mbCancel in Buttons)) then B.Cancel := True;
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
    B.Caption := 'Cancel';
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

{ ---------------------------------------------------------------- file dialog }

type
  TFileDlgForm = class(TForm)
  public
    Dlg: TOpenDialog;
    Dir: string;
    LblDir: TLabel;
    List: TListBox;
    Edit: TEdit;
    Types: TComboBox;
    BtnOK, BtnCancel: TButton;
    Masks: TStringList;
    procedure Fill;
    procedure ListClick(Sender: TObject);
    procedure ListDblClick(Sender: TObject);
    procedure TypesChange(Sender: TObject);
    procedure OKClick(Sender: TObject);
    function CurrentMasks: TStringList;
  end;

function MatchMask(const Name, Mask: string): Boolean;
var
  N, M: string;
  function Match(NI, MI: Integer): Boolean;
  begin
    while MI <= Length(M) do
    begin
      case M[MI] of
        '*':
          begin
            if MI = Length(M) then Exit(True);
            while NI <= Length(N) + 1 do
            begin
              if Match(NI, MI + 1) then Exit(True);
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
  N := LowerCase(Name);
  M := LowerCase(Mask);
  if (M = '*.*') then Exit(True);
  Result := Match(1, 1);
end;

function TFileDlgForm.CurrentMasks: TStringList;
var
  Parts: TStringList;
  I, Idx: Integer;
  S: string;
begin
  Result := TStringList.Create;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := '|';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Dlg.Filter;
    Idx := Types.ItemIndex;
    if Idx < 0 then Idx := 0;
    if 2 * Idx + 1 < Parts.Count then S := Parts[2 * Idx + 1] else S := '*.*';
    Result.Delimiter := ';';
    Result.StrictDelimiter := True;
    Result.DelimitedText := S;
    for I := 0 to Result.Count - 1 do Result[I] := Trim(Result[I]);
  finally
    Parts.Free;
  end;
end;

procedure TFileDlgForm.Fill;
var
  SR: TSearchRec;
  Dirs, Files: TStringList;
  M: TStringList;
  I: Integer;
  Ok: Boolean;
begin
  Dirs := TStringList.Create;
  Files := TStringList.Create;
  M := CurrentMasks;
  try
    Dirs.Sorted := True;
    Files.Sorted := True;
    if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if (SR.Name = '.') then Continue;
        if SR.Attr and faDirectory <> 0 then
        begin
          if (SR.Name <> '..') and (SR.Name[1] = '.') then Continue;
          Dirs.Add('[' + SR.Name + ']');
        end
        else
        begin
          Ok := False;
          for I := 0 to M.Count - 1 do
            if MatchMask(SR.Name, M[I]) then Ok := True;
          if Ok then Files.Add(SR.Name);
        end;
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    if (Dirs.IndexOf('[..]') < 0) and (ExcludeTrailingPathDelimiter(Dir) <> '') and (Dir <> '/') then
      Dirs.Add('[..]');
    List.Items.BeginUpdate;
    try
      List.Items.Clear;
      List.Items.AddStrings(Dirs);
      List.Items.AddStrings(Files);
    finally
      List.Items.EndUpdate;
    end;
    LblDir.Caption := Dir;
  finally
    Dirs.Free;
    Files.Free;
    M.Free;
  end;
end;

procedure TFileDlgForm.ListClick(Sender: TObject);
var
  S: string;
begin
  if List.ItemIndex < 0 then Exit;
  S := List.Items[List.ItemIndex];
  if (S <> '') and (S[1] <> '[') then Edit.Text := S;
end;

procedure TFileDlgForm.ListDblClick(Sender: TObject);
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
    Edit.Text := S;
    OKClick(nil);
  end;
end;

procedure TFileDlgForm.TypesChange(Sender: TObject);
begin
  Fill;
end;

procedure TFileDlgForm.OKClick(Sender: TObject);
var
  S: string;
begin
  S := Trim(Edit.Text);
  if S = '' then Exit;
  if (Pos('*', S) > 0) or (Pos('?', S) > 0) then
  begin
    Fill;
    Exit;
  end;
  if (Dlg.DefaultExt <> '') and (ExtractFileExt(S) = '') then
    S := S + '.' + Dlg.DefaultExt;
  if (S[1] <> PathDelim) then S := IncludeTrailingPathDelimiter(Dir) + S;
  if DirectoryExists(S) then
  begin
    Dir := S;
    Edit.Text := '';
    Fill;
    Exit;
  end;
  if (ofFileMustExist in Dlg.Options) and not FileExists(S) then
  begin
    MessageDlg(ExtractFileName(S) + #13#10 + 'File not found.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if Dlg.FIsSave and (ofOverwritePrompt in Dlg.Options) and FileExists(S) then
    if MessageDlg(ExtractFileName(S) + ' already exists.' + #13#10 + 'Do you want to replace it?',
      mtWarning, [mbYes, mbNo], 0) <> mrYes then Exit;
  Dlg.FFileName := S;
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
  F: TFileDlgForm;
  Parts: TStringList;
  I: Integer;
  L: TLabel;
  Start: string;
begin
  Result := False;
  F := TFileDlgForm.CreateNew(Application);
  try
    F.Dlg := Self;
    F.BorderStyle := bsDialog;
    if FTitle <> '' then F.Caption := FTitle
    else if FIsSave then F.Caption := 'Save As'
    else F.Caption := 'Open';
    F.Position := poScreenCenter;
    F.Font.Name := 'MS Sans Serif';
    F.Font.Height := -11;
    F.ClientWidth := 420;
    F.ClientHeight := 300;
    { start directory }
    Start := '';
    if FFileName <> '' then Start := ExtractFilePath(ZMResolvePath(FFileName));
    if (Start = '') and (FInitialDir <> '') then Start := ZMResolvePath(FInitialDir);
    if (Start = '') or not DirectoryExists(Start) then Start := GetCurrentDir;
    F.Dir := ExcludeTrailingPathDelimiter(ExpandFileName(Start));
    if F.Dir = '' then F.Dir := PathDelim;
    F.LblDir := TLabel.Create(F);
    F.LblDir.Parent := F;
    F.LblDir.AutoSize := False;
    F.LblDir.SetBounds(8, 8, 404, 16);
    F.List := TListBox.Create(F);
    F.List.Parent := F;
    F.List.SetBounds(8, 28, 404, 180);
    F.List.OnClick := F.ListClick;
    F.List.OnDblClick := F.ListDblClick;
    L := TLabel.Create(F);
    L.Parent := F;
    L.Caption := 'File &name:';
    L.SetBounds(8, 220, 80, 16);
    F.Edit := TEdit.Create(F);
    F.Edit.Parent := F;
    F.Edit.SetBounds(96, 216, 228, 21);
    F.Edit.Text := ExtractFileName(FFileName);
    L := TLabel.Create(F);
    L.Parent := F;
    L.Caption := 'Files of &type:';
    L.SetBounds(8, 250, 80, 16);
    F.Types := TComboBox.Create(F);
    F.Types.Parent := F;
    F.Types.Style := csDropDownList;
    F.Types.SetBounds(96, 246, 228, 21);
    Parts := TStringList.Create;
    try
      Parts.Delimiter := '|';
      Parts.StrictDelimiter := True;
      Parts.DelimitedText := FFilter;
      I := 0;
      while I < Parts.Count do
      begin
        F.Types.Items.Add(Parts[I]);
        Inc(I, 2);
      end;
    finally
      Parts.Free;
    end;
    if F.Types.Items.Count = 0 then F.Types.Items.Add('All files (*.*)');
    F.Types.ItemIndex := Max(0, Min(FFilterIndex - 1, F.Types.Items.Count - 1));
    F.Types.OnChange := F.TypesChange;
    F.BtnOK := TButton.Create(F);
    F.BtnOK.Parent := F;
    if FIsSave then F.BtnOK.Caption := '&Save' else F.BtnOK.Caption := '&Open';
    F.BtnOK.Default := True;
    F.BtnOK.SetBounds(336, 214, 75, 25);
    F.BtnOK.OnClick := F.OKClick;
    F.BtnCancel := TButton.Create(F);
    F.BtnCancel.Parent := F;
    F.BtnCancel.Caption := 'Cancel';
    F.BtnCancel.Cancel := True;
    F.BtnCancel.ModalResult := mrCancel;
    F.BtnCancel.SetBounds(336, 244, 75, 25);
    F.Fill;
    F.ActiveControl := F.Edit;
    DoShow;
    if F.ShowModal = mrOk then
    begin
      FFilterIndex := F.Types.ItemIndex + 1;
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

unit FileCtrl;

{ Delphi 5-subset van de FileCtrl-unit: TDirectoryListBox, TDriveComboBox, TFileListBox,
  TFilterComboBox en de maphulpfuncties. Stations hebben op Unix geen betekenis;
  de stationskeuzelijst toont een enkel 'c:'-item. }

{$MODE DELPHI}{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, StdCtrls;

type
  TFileAttr = (ftReadOnly, ftHidden, ftSystem, ftVolumeID, ftDirectory, ftArchive, ftNormal);
  TFileType = set of TFileAttr;
  TDriveType = (dtUnknown, dtNoDrive, dtFloppy, dtFixed, dtNetwork, dtCDROM, dtRAM);
  TTextCase = (tcLowerCase, tcUpperCase);
  TSelectDirOpt = (sdAllowCreate, sdPerformCreate, sdPrompt);
  TSelectDirOpts = set of TSelectDirOpt;

  TDriveComboBox = class;

  TDirectoryListBox = class(TCustomListBox)
  private
    FDirectory: string;
    FDirLabel: TLabel;
    FDriveCombo: TDriveComboBox;
    FOnChange: TNotifyEvent;
    procedure SetDirectory(const Value: string);
    procedure SetDirLabel(Value: TLabel);
    procedure SetDrive(Value: Char);
    function GetDrive: Char;
    procedure Fill;
  protected
    procedure Change; virtual;
    procedure DblClick; override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    function GetItemPath(Index: Integer): string;
    procedure OpenCurrent;
    procedure Update; reintroduce;
    property Drive: Char read GetDrive write SetDrive;
    property Directory: string read FDirectory write SetDirectory;
  published
    property Align;
    property Color;
    property Ctl3D;
    property DirLabel: TLabel read FDirLabel write SetDirLabel;
    property Enabled;
    property Font;
    property IntegralHeight;
    property ItemHeight;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnClick;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyDown;
    property OnKeyPress;
    property OnKeyUp;
    property OnMouseDown;
    property OnMouseMove;
    property OnMouseUp;
  end;

  TDriveComboBox = class(TCustomComboBox)
  private
    FDirList: TDirectoryListBox;
    FDrive: Char;
    FTextCase: TTextCase;
    procedure SetDirListBox(Value: TDirectoryListBox);
    procedure SetDrive(NewDrive: Char);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    property Drive: Char read FDrive write SetDrive;
  published
    property Color;
    property Ctl3D;
    property DirList: TDirectoryListBox read FDirList write SetDirListBox;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentCtl3D;
    property ParentFont;
    property ParentShowHint;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property TextCase: TTextCase read FTextCase write FTextCase default tcLowerCase;
    property Visible;
    property OnChange;
    property OnClick;
    property OnEnter;
    property OnExit;
  end;

  TFileListBox = class(TCustomListBox)
  private
    FDirectory: string;
    FMask: string;
    FFileType: TFileType;
    FOnChange: TNotifyEvent;
    function GetFileName: string;
    procedure SetDirectory(const Value: string);
    procedure SetMask(const Value: string);
    procedure SetFileName(const Value: string);
  protected
    procedure Change; virtual;
    procedure Click; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Update; reintroduce;
    property Directory: string read FDirectory write SetDirectory;
    property FileName: string read GetFileName write SetFileName;
  published
    property Align;
    property Color;
    property FileType: TFileType read FFileType write FFileType default [ftNormal];
    property Font;
    property ItemHeight;
    property Mask: string read FMask write SetMask;
    property MultiSelect;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnClick;
    property OnDblClick;
  end;

  TFilterComboBox = class(TCustomComboBox)
  private
    FFilter: string;
    FFileList: TFileListBox;
    function GetMask: string;
    procedure SetFilter(const Value: string);
  public
    constructor Create(AOwner: TComponent); override;
    property Mask: string read GetMask;
  published
    property FileList: TFileListBox read FFileList write FFileList;
    property Filter: string read FFilter write SetFilter;
    property Font;
    property TabOrder;
    property Visible;
    property OnChange;
  end;

function SelectDirectory(var Directory: string; Options: TSelectDirOpts; HelpCtx: Longint): Boolean; overload;
function SelectDirectory(const Caption: string; const Root: WideString; out Directory: string): Boolean; overload;
function DirectoryExists(const Name: string): Boolean;
function ForceDirectories(Dir: string): Boolean;
function MinimizeName(const Filename: TFileName; Canvas: TCanvas; MaxLen: Integer): TFileName;

implementation

uses Math, ZMData;

function DirectoryExists(const Name: string): Boolean;
begin
  Result := SysUtils.DirectoryExists(ZMResolvePath(Name));
end;

function ForceDirectories(Dir: string): Boolean;
begin
  Result := SysUtils.ForceDirectories(ZMResolvePath(Dir));
end;

function MinimizeName(const Filename: TFileName; Canvas: TCanvas; MaxLen: Integer): TFileName;
begin
  Result := Filename;
  while (Length(Result) > 4) and (Canvas.TextWidth(Result) > MaxLen) do
    Result := '...' + Copy(Result, 5, MaxInt);
end;

{ ---------------------------------------------------------------- TDirectoryListBox }

constructor TDirectoryListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Width := 145;
  Sorted := False;
  FDirectory := GetCurrentDir;
  ItemHeight := 16;
end;

procedure TDirectoryListBox.Fill;
var
  SR: TSearchRec;
  L: TStringList;
  Parts: TStringList;
  I: Integer;
  P: string;
begin
  Items.BeginUpdate;
  L := TStringList.Create;
  Parts := TStringList.Create;
  try
    Items.Clear;
    { eerst de padonderdelen, daarna de submappen }
    Parts.Delimiter := PathDelim;
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := FDirectory;
    Items.Add(PathDelim);
    for I := 0 to Parts.Count - 1 do
      if Parts[I] <> '' then Items.Add(Parts[I]);
    ItemIndex := Items.Count - 1;
    L.Sorted := True;
    if FindFirst(IncludeTrailingPathDelimiter(FDirectory) + '*', faDirectory, SR) = 0 then
    begin
      repeat
        if (SR.Attr and faDirectory <> 0) and (SR.Name[1] <> '.') then L.Add(SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
    for I := 0 to L.Count - 1 do Items.Add('  ' + L[I]);
  finally
    L.Free;
    Parts.Free;
    Items.EndUpdate;
  end;
  if FDirLabel <> nil then
  begin
    P := FDirectory;
    FDirLabel.Caption := P;
  end;
end;

function TDirectoryListBox.GetItemPath(Index: Integer): string;
var
  I: Integer;
  S: string;
begin
  S := Items[Index];
  if Copy(S, 1, 2) = '  ' then
    Result := IncludeTrailingPathDelimiter(FDirectory) + Copy(S, 3, MaxInt)
  else
  begin
    Result := '';
    for I := 1 to Index do Result := Result + PathDelim + Items[I];
    if Result = '' then Result := PathDelim;
  end;
end;

procedure TDirectoryListBox.OpenCurrent;
begin
  if ItemIndex >= 0 then Directory := GetItemPath(ItemIndex);
end;

procedure TDirectoryListBox.DblClick;
begin
  inherited DblClick;
  OpenCurrent;
end;

procedure TDirectoryListBox.Update;
begin
  Fill;
end;

procedure TDirectoryListBox.SetDirectory(const Value: string);
begin
  if SysUtils.DirectoryExists(Value) then
  begin
    FDirectory := ExcludeTrailingPathDelimiter(ExpandFileName(Value));
    if FDirectory = '' then FDirectory := PathDelim;
    Fill;
    Change;
  end;
end;

procedure TDirectoryListBox.SetDirLabel(Value: TLabel);
begin
  FDirLabel := Value;
  if Value <> nil then
  begin
    Value.FreeNotification(Self);
    Value.Caption := FDirectory;
  end;
end;

function TDirectoryListBox.GetDrive: Char;
begin
  Result := 'c';
end;

procedure TDirectoryListBox.SetDrive(Value: Char);
begin
end;

procedure TDirectoryListBox.Change;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TDirectoryListBox.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FDirLabel then FDirLabel := nil;
    if AComponent = FDriveCombo then FDriveCombo := nil;
  end;
end;

{ ---------------------------------------------------------------- TDriveComboBox }

constructor TDriveComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Style := csDropDownList;
  FDrive := 'c';
  Items.Add('c: [ZM_DATA]');
  ItemIndex := 0;
end;

procedure TDriveComboBox.SetDirListBox(Value: TDirectoryListBox);
begin
  FDirList := Value;
  if Value <> nil then
  begin
    Value.FDriveCombo := Self;
    Value.FreeNotification(Self);
  end;
end;

procedure TDriveComboBox.SetDrive(NewDrive: Char);
begin
  FDrive := NewDrive;
end;

procedure TDriveComboBox.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FDirList) then FDirList := nil;
end;

{ ---------------------------------------------------------------- TFileListBox }

constructor TFileListBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FMask := '*.*';
  FFileType := [ftNormal];
  FDirectory := GetCurrentDir;
  Sorted := True;
end;

procedure TFileListBox.Update;
var
  SR: TSearchRec;
begin
  Items.BeginUpdate;
  try
    Items.Clear;
    if FindFirst(IncludeTrailingPathDelimiter(FDirectory) + '*', faAnyFile, SR) = 0 then
    begin
      repeat
        if SR.Attr and faDirectory = 0 then
          if (FMask = '*.*') or (FMask = '*') or SameText(ExtractFileExt(SR.Name), ExtractFileExt(FMask)) then
            Items.Add(SR.Name);
      until FindNext(SR) <> 0;
      FindClose(SR);
    end;
  finally
    Items.EndUpdate;
  end;
end;

function TFileListBox.GetFileName: string;
begin
  if ItemIndex >= 0 then
    Result := IncludeTrailingPathDelimiter(FDirectory) + Items[ItemIndex]
  else
    Result := '';
end;

procedure TFileListBox.SetFileName(const Value: string);
begin
  ItemIndex := Items.IndexOf(ExtractFileName(Value));
end;

procedure TFileListBox.SetDirectory(const Value: string);
begin
  FDirectory := Value;
  Update;
  Change;
end;

procedure TFileListBox.SetMask(const Value: string);
begin
  FMask := Value;
  Update;
end;

procedure TFileListBox.Change;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TFileListBox.Click;
begin
  inherited Click;
  Change;
end;

{ ---------------------------------------------------------------- TFilterComboBox }

constructor TFilterComboBox.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Style := csDropDownList;
  FFilter := 'Alle bestanden (*.*)|*.*';
  SetFilter(FFilter);
end;

procedure TFilterComboBox.SetFilter(const Value: string);
var
  P: TStringList;
  I: Integer;
begin
  FFilter := Value;
  P := TStringList.Create;
  try
    P.Delimiter := '|';
    P.StrictDelimiter := True;
    P.DelimitedText := Value;
    Items.Clear;
    I := 0;
    while I < P.Count do
    begin
      Items.Add(P[I]);
      Inc(I, 2);
    end;
  finally
    P.Free;
  end;
  ItemIndex := 0;
end;

function TFilterComboBox.GetMask: string;
var
  P: TStringList;
begin
  Result := '*.*';
  P := TStringList.Create;
  try
    P.Delimiter := '|';
    P.StrictDelimiter := True;
    P.DelimitedText := FFilter;
    if 2 * ItemIndex + 1 < P.Count then Result := P[2 * ItemIndex + 1];
  finally
    P.Free;
  end;
end;

{ ---------------------------------------------------------------- SelectDirectory (mapkiezer) }

function SelectDirectory(var Directory: string; Options: TSelectDirOpts; HelpCtx: Longint): Boolean;
var
  F: TForm;
  L: TDirectoryListBox;
  B: TButton;
begin
  Result := False;
  F := TForm.CreateNew(Application);
  try
    F.BorderStyle := bsDialog;
    F.Caption := 'Map selecteren';
    F.Position := poScreenCenter;
    F.ClientWidth := 300;
    F.ClientHeight := 260;
    L := TDirectoryListBox.Create(F);
    L.Parent := F;
    L.SetBounds(8, 8, 284, 200);
    if Directory <> '' then L.Directory := ZMResolvePath(Directory);
    B := TButton.Create(F);
    B.Parent := F;
    B.Caption := 'OK';
    B.Default := True;
    B.ModalResult := mrOk;
    B.SetBounds(136, 224, 75, 25);
    B := TButton.Create(F);
    B.Parent := F;
    B.Caption := 'Annuleren';
    B.Cancel := True;
    B.ModalResult := mrCancel;
    B.SetBounds(217, 224, 75, 25);
    if F.ShowModal = mrOk then
    begin
      Directory := L.Directory;
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

function SelectDirectory(const Caption: string; const Root: WideString; out Directory: string): Boolean;
begin
  Directory := '';
  Result := SelectDirectory(Directory, [], 0);
end;

initialization
  RegisterClasses([TDirectoryListBox, TDriveComboBox, TFileListBox, TFilterComboBox]);
end.

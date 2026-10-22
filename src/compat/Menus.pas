unit Menus;

{ Delphi 5 Menus unit subset: TMenuItem, TMainMenu, TPopupMenu, shortcuts.
  Menus are kept as data; TPopupMenu.Popup shows nothing yet (the game's
  popup menus belong to the sprite editor forms, which are not part of the
  playable game). }

{$MODE DELPHI}{$H+}

interface

uses Windows, Messages, SysUtils, Classes, Graphics;

type
  TMenuItem = class;
  TMenuBreak = (mbNone, mbBreak, mbBarBreak);
  TMenuChangeEvent = procedure(Sender: TObject; Source: TMenuItem; Rebuild: Boolean) of object;
  TMenuDrawItemEvent = procedure(Sender: TObject; ACanvas: TCanvas; ARect: TRect; Selected: Boolean) of object;
  TMenuMeasureItemEvent = procedure(Sender: TObject; ACanvas: TCanvas; var Width, Height: Integer) of object;
  TMenuItemAutoFlag = (maAutomatic, maManual, maParent);
  TMenuAutoFlag = maAutomatic..maManual;
  TShortCut = Low(Word)..High(Word);
  TPopupAlignment = (paLeft, paRight, paCenter);
  TTrackButton = (tbRightButton, tbLeftButton);
  TMenuAnimations = (maLeftToRight, maRightToLeft, maTopToBottom, maBottomToTop, maNone);
  TMenuAnimation = set of TMenuAnimations;

  TMenuItem = class(TComponent)
  private
    FCaption: string;
    FChecked: Boolean;
    FEnabled: Boolean;
    FDefault: Boolean;
    FRadioItem: Boolean;
    FVisible: Boolean;
    FGroupIndex: Byte;
    FImageIndex: Integer;
    FBreak: TMenuBreak;
    FShortCut: TShortCut;
    FHint: string;
    FItems: TList;
    FParent: TMenuItem;
    FHelpContext: Integer;
    FAutoCheck: Boolean;
    FBitmap: TBitmap;
    FOnClick: TNotifyEvent;
    FOnDrawItem: TMenuDrawItemEvent;
    FOnMeasureItem: TMenuMeasureItemEvent;
    function GetCount: Integer;
    function GetItem(Index: Integer): TMenuItem;
    function GetMenuIndex: Integer;
    procedure SetMenuIndex(Value: Integer);
  protected
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    procedure SetChildOrder(Child: TComponent; Order: Integer); override;
    procedure SetParentComponent(Value: TComponent); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure Add(Item: TMenuItem); overload;
    procedure Add(const AItems: array of TMenuItem); overload;
    procedure Clear;
    procedure Click; virtual;
    procedure Delete(Index: Integer);
    function Find(ACaption: string): TMenuItem;
    function GetParentComponent: TComponent; override;
    function HasParent: Boolean; override;
    function IndexOf(Item: TMenuItem): Integer;
    procedure Insert(Index: Integer; Item: TMenuItem);
    procedure Remove(Item: TMenuItem);
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TMenuItem read GetItem; default;
    property MenuIndex: Integer read GetMenuIndex write SetMenuIndex;
    property Parent: TMenuItem read FParent;
  published
    property AutoCheck: Boolean read FAutoCheck write FAutoCheck default False;
    property Bitmap: TBitmap read FBitmap write FBitmap;
    property Break: TMenuBreak read FBreak write FBreak default mbNone;
    property Caption: string read FCaption write FCaption;
    property Checked: Boolean read FChecked write FChecked default False;
    property Default: Boolean read FDefault write FDefault default False;
    property Enabled: Boolean read FEnabled write FEnabled default True;
    property GroupIndex: Byte read FGroupIndex write FGroupIndex default 0;
    property HelpContext: Integer read FHelpContext write FHelpContext default 0;
    property Hint: string read FHint write FHint;
    property ImageIndex: Integer read FImageIndex write FImageIndex default -1;
    property RadioItem: Boolean read FRadioItem write FRadioItem default False;
    property ShortCut: TShortCut read FShortCut write FShortCut default 0;
    property Visible: Boolean read FVisible write FVisible default True;
    property OnClick: TNotifyEvent read FOnClick write FOnClick;
    property OnDrawItem: TMenuDrawItemEvent read FOnDrawItem write FOnDrawItem;
    property OnMeasureItem: TMenuMeasureItemEvent read FOnMeasureItem write FOnMeasureItem;
  end;

  TMenu = class(TComponent)
  private
    FItems: TMenuItem;
    FOwnerDraw: Boolean;
    FAutoHotkeys: TMenuAutoFlag;
    FAutoLineReduction: TMenuAutoFlag;
    FOnChange: TMenuChangeEvent;
    function GetHandle: HMENU;
  protected
    procedure GetChildren(Proc: TGetChildProc; Root: TComponent); override;
    procedure SetChildOrder(Child: TComponent; Order: Integer); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function DispatchCommand(ACommand: Word): Boolean;
    function FindItem(Value: Integer; Kind: Integer): TMenuItem;
    function IsShortCut(var Message: TWMKey): Boolean; dynamic;
    property Handle: HMENU read GetHandle;
    property OnChange: TMenuChangeEvent read FOnChange write FOnChange;
  published
    property AutoHotkeys: TMenuAutoFlag read FAutoHotkeys write FAutoHotkeys default maAutomatic;
    property AutoLineReduction: TMenuAutoFlag read FAutoLineReduction write FAutoLineReduction default maAutomatic;
    property Items: TMenuItem read FItems;
    property OwnerDraw: Boolean read FOwnerDraw write FOwnerDraw default False;
  end;

  TMainMenu = class(TMenu)
  private
    FAutoMerge: Boolean;
  public
    procedure Merge(Menu: TMainMenu);
    procedure Unmerge(Menu: TMainMenu);
  published
    property AutoMerge: Boolean read FAutoMerge write FAutoMerge default False;
  end;

  TPopupMenu = class(TMenu)
  private
    FPopupPoint: TPoint;
    FAlignment: TPopupAlignment;
    FAutoPopup: Boolean;
    FPopupComponent: TComponent;
    FTrackButton: TTrackButton;
    FMenuAnimation: TMenuAnimation;
    FOnPopup: TNotifyEvent;
  protected
    procedure DoPopup(Sender: TObject); virtual;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Popup(X, Y: Integer); virtual;
    property PopupComponent: TComponent read FPopupComponent write FPopupComponent;
    property PopupPoint: TPoint read FPopupPoint;
  published
    property Alignment: TPopupAlignment read FAlignment write FAlignment default paLeft;
    property AutoPopup: Boolean read FAutoPopup write FAutoPopup default True;
    property MenuAnimation: TMenuAnimation read FMenuAnimation write FMenuAnimation default [];
    property TrackButton: TTrackButton read FTrackButton write FTrackButton default tbRightButton;
    property OnPopup: TNotifyEvent read FOnPopup write FOnPopup;
  end;

  TPopupList = class(TList)
  public
    procedure Add(Popup: TPopupMenu);
    procedure Remove(Popup: TPopupMenu);
  end;

function ShortCut(Key: Word; Shift: TShiftState): TShortCut;
procedure ShortCutToKey(ShortCut: TShortCut; var Key: Word; var Shift: TShiftState);
function ShortCutToText(ShortCut: TShortCut): string;
function TextToShortCut(Text: string): TShortCut;
function NewMenu(Owner: TComponent; const AName: string; const Items: array of TMenuItem): TMainMenu;
function NewPopupMenu(Owner: TComponent; const AName: string; Alignment: TPopupAlignment;
  AutoPopup: Boolean; const Items: array of TMenuItem): TPopupMenu;
function NewItem(const ACaption: string; AShortCut: TShortCut; AChecked, AEnabled: Boolean;
  AOnClick: TNotifyEvent; hCtx: Word; const AName: string): TMenuItem;
function NewLine: TMenuItem;
function StripHotkey(const Text: string): string;

const
  scShift = $2000;
  scCtrl = $4000;
  scAlt = $8000;
  scNone = 0;
  cHotkeyPrefix = '&';
  cLineCaption = '-';

var
  PopupList: TPopupList;

implementation

{ ---------------------------------------------------------------- TMenuItem }

constructor TMenuItem.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FVisible := True;
  FEnabled := True;
  FImageIndex := -1;
end;

destructor TMenuItem.Destroy;
begin
  if FParent <> nil then FParent.Remove(Self);
  while Count > 0 do Items[0].Free;
  FItems.Free;
  inherited Destroy;
end;

function TMenuItem.GetCount: Integer;
begin
  if FItems = nil then Result := 0 else Result := FItems.Count;
end;

function TMenuItem.GetItem(Index: Integer): TMenuItem;
begin
  Result := TMenuItem(FItems[Index]);
end;

function TMenuItem.GetMenuIndex: Integer;
begin
  if FParent = nil then Result := -1 else Result := FParent.IndexOf(Self);
end;

procedure TMenuItem.SetMenuIndex(Value: Integer);
var
  P: TMenuItem;
begin
  P := FParent;
  if P = nil then Exit;
  P.Remove(Self);
  P.Insert(Value, Self);
end;

procedure TMenuItem.Add(Item: TMenuItem);
begin
  Insert(Count, Item);
end;

procedure TMenuItem.Add(const AItems: array of TMenuItem);
var
  I: Integer;
begin
  for I := Low(AItems) to High(AItems) do Add(AItems[I]);
end;

procedure TMenuItem.Insert(Index: Integer; Item: TMenuItem);
begin
  if Item.FParent <> nil then Item.FParent.Remove(Item);
  if FItems = nil then FItems := TList.Create;
  if Index > FItems.Count then Index := FItems.Count;
  FItems.Insert(Index, Item);
  Item.FParent := Self;
end;

procedure TMenuItem.Delete(Index: Integer);
var
  Item: TMenuItem;
begin
  Item := Items[Index];
  FItems.Delete(Index);
  Item.FParent := nil;
end;

procedure TMenuItem.Remove(Item: TMenuItem);
var
  I: Integer;
begin
  I := IndexOf(Item);
  if I >= 0 then Delete(I);
end;

procedure TMenuItem.Clear;
begin
  while Count > 0 do Items[Count - 1].Free;
end;

function TMenuItem.IndexOf(Item: TMenuItem): Integer;
begin
  if FItems = nil then Result := -1 else Result := FItems.IndexOf(Item);
end;

function TMenuItem.Find(ACaption: string): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  ACaption := StripHotkey(ACaption);
  for I := 0 to Count - 1 do
    if AnsiSameText(ACaption, StripHotkey(Items[I].Caption)) then Exit(Items[I]);
end;

procedure TMenuItem.Click;
begin
  if FEnabled then
  begin
    if FAutoCheck then FChecked := not FChecked;
    if Assigned(FOnClick) then FOnClick(Self);
  end;
end;

procedure TMenuItem.GetChildren(Proc: TGetChildProc; Root: TComponent);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do Proc(Items[I]);
end;

procedure TMenuItem.SetChildOrder(Child: TComponent; Order: Integer);
begin
  (Child as TMenuItem).MenuIndex := Order;
end;

procedure TMenuItem.SetParentComponent(Value: TComponent);
begin
  if FParent <> nil then FParent.Remove(Self);
  if Value <> nil then
    if Value is TMenu then TMenu(Value).Items.Add(Self)
    else if Value is TMenuItem then TMenuItem(Value).Add(Self);
end;

function TMenuItem.GetParentComponent: TComponent;
begin
  Result := FParent;
  if (FParent <> nil) and (FParent.Owner is TMenu) and (TMenu(FParent.Owner).Items = FParent) then
    Result := FParent.Owner;
end;

function TMenuItem.HasParent: Boolean;
begin
  Result := True;
end;

{ ---------------------------------------------------------------- TMenu }

constructor TMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FItems := TMenuItem.Create(Self);
end;

destructor TMenu.Destroy;
begin
  FItems.Free;
  inherited Destroy;
end;

function TMenu.GetHandle: HMENU;
begin
  Result := 0;
end;

procedure TMenu.GetChildren(Proc: TGetChildProc; Root: TComponent);
begin
  FItems.GetChildren(Proc, Root);
end;

procedure TMenu.SetChildOrder(Child: TComponent; Order: Integer);
begin
  FItems.SetChildOrder(Child, Order);
end;

function TMenu.DispatchCommand(ACommand: Word): Boolean;
begin
  Result := False;
end;

function TMenu.FindItem(Value: Integer; Kind: Integer): TMenuItem;
begin
  Result := nil;
end;

function TMenu.IsShortCut(var Message: TWMKey): Boolean;

  function Scan(Item: TMenuItem; SC: TShortCut): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := 0 to Item.Count - 1 do
    begin
      if (Item[I].ShortCut = SC) and (SC <> 0) and Item[I].Enabled then
      begin
        Item[I].Click;
        Exit(True);
      end;
      if Scan(Item[I], SC) then Exit(True);
    end;
  end;

var
  Shift: TShiftState;
begin
  Shift := [];
  if GetKeyState(VK_SHIFT) < 0 then Include(Shift, ssShift);
  if GetKeyState(VK_CONTROL) < 0 then Include(Shift, ssCtrl);
  if Message.KeyData and $20000000 <> 0 then Include(Shift, ssAlt);
  Result := Scan(FItems, ShortCut(Message.CharCode, Shift));
end;

procedure TMainMenu.Merge(Menu: TMainMenu);
begin
end;

procedure TMainMenu.Unmerge(Menu: TMainMenu);
begin
end;

{ ---------------------------------------------------------------- TPopupMenu }

constructor TPopupMenu.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoPopup := True;
end;

procedure TPopupMenu.DoPopup(Sender: TObject);
begin
  if Assigned(FOnPopup) then FOnPopup(Sender);
end;

procedure TPopupMenu.Popup(X, Y: Integer);
begin
  FPopupPoint := Point(X, Y);
  DoPopup(Self);
end;

procedure TPopupList.Add(Popup: TPopupMenu);
begin
  inherited Add(Popup);
end;

procedure TPopupList.Remove(Popup: TPopupMenu);
begin
  inherited Remove(Popup);
end;

{ ---------------------------------------------------------------- helpers }

function ShortCut(Key: Word; Shift: TShiftState): TShortCut;
begin
  Result := 0;
  if WordRec(Key).Hi <> 0 then Exit;
  Result := Key;
  if ssShift in Shift then Inc(Result, scShift);
  if ssCtrl in Shift then Inc(Result, scCtrl);
  if ssAlt in Shift then Inc(Result, scAlt);
end;

procedure ShortCutToKey(ShortCut: TShortCut; var Key: Word; var Shift: TShiftState);
begin
  Key := ShortCut and not (scShift + scCtrl + scAlt);
  Shift := [];
  if ShortCut and scShift <> 0 then Include(Shift, ssShift);
  if ShortCut and scCtrl <> 0 then Include(Shift, ssCtrl);
  if ShortCut and scAlt <> 0 then Include(Shift, ssAlt);
end;

function KeyName(Key: Word): string;
begin
  case Key of
    VK_BACK: Result := 'BkSp';
    VK_TAB: Result := 'Tab';
    VK_RETURN: Result := 'Enter';
    VK_ESCAPE: Result := 'Esc';
    VK_SPACE: Result := 'Space';
    VK_PRIOR: Result := 'PgUp';
    VK_NEXT: Result := 'PgDn';
    VK_END: Result := 'End';
    VK_HOME: Result := 'Home';
    VK_LEFT: Result := 'Left';
    VK_UP: Result := 'Up';
    VK_RIGHT: Result := 'Right';
    VK_DOWN: Result := 'Down';
    VK_INSERT: Result := 'Ins';
    VK_DELETE: Result := 'Del';
    Ord('0')..Ord('9'), Ord('A')..Ord('Z'): Result := Chr(Key);
    VK_F1..VK_F12: Result := 'F' + IntToStr(Key - VK_F1 + 1);
  else
    Result := '';
  end;
end;

function ShortCutToText(ShortCut: TShortCut): string;
var
  Name: string;
begin
  Name := KeyName(ShortCut and $FF);
  if Name = '' then Exit('');
  Result := '';
  if ShortCut and scShift <> 0 then Result := Result + 'Shift+';
  if ShortCut and scCtrl <> 0 then Result := Result + 'Ctrl+';
  if ShortCut and scAlt <> 0 then Result := Result + 'Alt+';
  Result := Result + Name;
end;

function TextToShortCut(Text: string): TShortCut;
var
  Shift: TShortCut;
  K: Word;
begin
  Shift := 0;
  while True do
  begin
    if AnsiSameText(Copy(Text, 1, 6), 'Shift+') then begin Inc(Shift, scShift); Delete(Text, 1, 6); end
    else if AnsiSameText(Copy(Text, 1, 5), 'Ctrl+') then begin Inc(Shift, scCtrl); Delete(Text, 1, 5); end
    else if AnsiSameText(Copy(Text, 1, 4), 'Alt+') then begin Inc(Shift, scAlt); Delete(Text, 1, 4); end
    else Break;
  end;
  Result := 0;
  if Text = '' then Exit;
  for K := 8 to 255 do
    if AnsiSameText(Text, KeyName(K)) then Exit(Shift or K);
end;

function NewMenu(Owner: TComponent; const AName: string; const Items: array of TMenuItem): TMainMenu;
begin
  Result := TMainMenu.Create(Owner);
  Result.Name := AName;
  Result.Items.Add(Items);
end;

function NewPopupMenu(Owner: TComponent; const AName: string; Alignment: TPopupAlignment;
  AutoPopup: Boolean; const Items: array of TMenuItem): TPopupMenu;
begin
  Result := TPopupMenu.Create(Owner);
  Result.Name := AName;
  Result.Alignment := Alignment;
  Result.AutoPopup := AutoPopup;
  Result.Items.Add(Items);
end;

function NewItem(const ACaption: string; AShortCut: TShortCut; AChecked, AEnabled: Boolean;
  AOnClick: TNotifyEvent; hCtx: Word; const AName: string): TMenuItem;
begin
  Result := TMenuItem.Create(nil);
  Result.Caption := ACaption;
  Result.ShortCut := AShortCut;
  Result.Checked := AChecked;
  Result.Enabled := AEnabled;
  Result.OnClick := AOnClick;
  Result.HelpContext := hCtx;
  Result.Name := AName;
end;

function NewLine: TMenuItem;
begin
  Result := TMenuItem.Create(nil);
  Result.Caption := cLineCaption;
end;

function StripHotkey(const Text: string): string;
var
  I: Integer;
begin
  Result := Text;
  I := 1;
  while I <= Length(Result) do
  begin
    if Result[I] = cHotkeyPrefix then Delete(Result, I, 1);
    Inc(I);
  end;
end;

initialization
  PopupList := TPopupList.Create;
  RegisterClasses([TMenuItem, TMainMenu, TPopupMenu]);
finalization
  PopupList.Free;
end.

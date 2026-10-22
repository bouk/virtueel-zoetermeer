unit uResizeScreen;

{ Het schermresolutie wisselen met ChangeDisplaySettings.
  Gedecompileerd uit ROS.exe v1.1, code 00464F18-004653AF. }

{$I zm.inc}

interface

uses
  Windows, Classes;

type
  TScrnMode = class(TObject)
  private
    FBitsPerPel: Integer;     { +0x04 }
    FWidth: Integer;          { +0x08 }
    FHeight: Integer;         { +0x0C }
    FFrequency: Integer;      { +0x10 }
  public
    constructor Create(AWidth, AHeight, ABitsPerPel, AFrequency: Integer);
    destructor Destroy; override;
    function Apply: Boolean;
    function Matches(AWidth, AHeight, ABitsPerPel, AFrequency: Integer): Boolean;
    property BitsPerPel: Integer read FBitsPerPel;
    property Width: Integer read FWidth;
    property Height: Integer read FHeight;
    property Frequency: Integer read FFrequency;
  end;

  { Alle schermmodi van het primaire beeldscherm }
  TScrnModeList = class(TList)
  public
    constructor Create;
    destructor Destroy; override;
    procedure StoreCurrentMode;
    function Add(Mode: TScrnMode): TScrnMode;
    function Find(AWidth, AHeight, ABitsPerPel, AFrequency: Integer): TScrnMode;
    function GetMode(Index: Integer): TScrnMode;
    property Modes[Index: Integer]: TScrnMode read GetMode; default;
  end;

const
  ScreenChanged: Boolean = False;   { 00488D88 }

var
  OriginalMode: TScrnMode;          { 0048A8E8 }
  NewMode: TScrnMode;               { 0048A8EC }
  ModeList: TScrnModeList;          { 0048A8F0 }

function SetScreenMode(AWidth, AHeight, ABitsPerPel: Integer): Boolean;
procedure RestoreScreenMode;
function IsScreenChanged: Boolean;

implementation

uses
  Forms, uTool;

{ @00464FDC }
constructor TScrnMode.Create(AWidth, AHeight, ABitsPerPel, AFrequency: Integer);
begin
  inherited Create;
  FBitsPerPel := ABitsPerPel;
  FWidth := AWidth;
  FHeight := AHeight;
  FFrequency := AFrequency;
end;

{ @00465030 }
destructor TScrnMode.Destroy;
begin
  inherited Destroy;
end;

{ @00465058 }
function TScrnMode.Apply: Boolean;
var
  Modus: TDeviceMode;
begin
  Modus.dmSize := SizeOf(Modus);
  Modus.dmBitsPerPel := FBitsPerPel;
  Modus.dmPelsWidth := FWidth;
  Modus.dmPelsHeight := FHeight;
  Modus.dmDisplayFlags := 0;
  Modus.dmDisplayFrequency := FFrequency;
  Modus.dmFields := DM_BITSPERPEL or DM_PELSWIDTH or DM_PELSHEIGHT or DM_DISPLAYFREQUENCY;
  Result := False;
  case ChangeDisplaySettings(Modus, 0) of
    DISP_CHANGE_SUCCESSFUL:
      Result := True;
    DISP_CHANGE_RESTART:
      ;
    DISP_CHANGE_BADFLAGS:
      ;
    DISP_CHANGE_FAILED:
      ;
    DISP_CHANGE_BADMODE:
      ;
    DISP_CHANGE_NOTUPDATED:
      ;
  end;
end;

{ @004650D4  AFrequency = -1 komt overeen met elke verversingsfrequentie. }
function TScrnMode.Matches(AWidth, AHeight, ABitsPerPel, AFrequency: Integer): Boolean;
begin
  Result := (FBitsPerPel = ABitsPerPel) and (AWidth = FWidth) and (AHeight = FHeight);
  if AFrequency <> -1 then
    Result := Result and (AFrequency = FFrequency);
end;

{ @00465114 }
constructor TScrnModeList.Create;
var
  I: Integer;
  Meer: Boolean;
  Modus: TDeviceMode;
begin
  inherited Create;
  I := 0;
  repeat
    Meer := EnumDisplaySettings(nil, I, Modus);
    Add(TScrnMode.Create(Modus.dmPelsWidth, Modus.dmPelsHeight,
      Modus.dmBitsPerPel, Modus.dmDisplayFrequency));
    Inc(I);
  until not Meer;
  StoreCurrentMode;
end;

{ @004651A0 }
destructor TScrnModeList.Destroy;
begin
  FreeList(Self);
  inherited Destroy;
end;

{ @004651CC }
procedure TScrnModeList.StoreCurrentMode;
var
  Breedte, Hoogte: Integer;
  DC: HDC;
  Kleurdiepte, Ververs: Integer;
begin
  Breedte := Screen.Width;    { LET OP: ongebruikt }
  Hoogte := Screen.Height;    { LET OP: ongebruikt }
  DC := GetDC(0);
  Kleurdiepte := GetDeviceCaps(DC, BITSPIXEL);
  Ververs := GetDeviceCaps(DC, VREFRESH);
  ReleaseDC(0, DC);
  OriginalMode := Find(Screen.Width, Screen.Height, Kleurdiepte, Ververs);
end;

{ @00465240 }
function TScrnModeList.Add(Mode: TScrnMode): TScrnMode;
begin
  inherited Add(Mode);
  Result := Mode;
end;

{ @00465250 }
function TScrnModeList.Find(AWidth, AHeight, ABitsPerPel, AFrequency: Integer): TScrnMode;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if GetMode(I).Matches(AWidth, AHeight, ABitsPerPel, AFrequency) then
    begin
      Result := GetMode(I);
      Break;
    end;
end;

{ @004652B0 }
function TScrnModeList.GetMode(Index: Integer): TScrnMode;
begin
  Result := TObject(Get(Index)) as TScrnMode;
end;

{ @004652D0 }
function SetScreenMode(AWidth, AHeight, ABitsPerPel: Integer): Boolean;
begin
  { LET OP: Result wordt in het origineel nooit toegekend (geeft terug wat er in EBX stond) }
  ModeList := TScrnModeList.Create;
  if OriginalMode <> nil then
  begin
    NewMode := ModeList.Find(AWidth, AHeight, ABitsPerPel, -1);
    if NewMode <> nil then
    begin
      ScreenChanged := True;
      if not NewMode.Apply then
        RestoreScreenMode;
    end;
  end;
end;

{ @00465334 }
procedure RestoreScreenMode;
begin
  if ScreenChanged then
  begin
    OriginalMode.Apply;
    ModeList.Free;
    ModeList := nil;
    OriginalMode := nil;
    NewMode := nil;
    ScreenChanged := False;
  end;
end;

{ @00465370 }
function IsScreenChanged: Boolean;
begin
  Result := ScreenChanged;
end;

end.

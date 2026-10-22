unit uResizeScreen;

{ Switching the display resolution with ChangeDisplaySettings.
  Decompiled from ROS.exe v1.1, code 00464F18-004653AF. }

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

  { All display modes of the primary display }
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
  DevMode: TDeviceMode;
begin
  DevMode.dmSize := SizeOf(DevMode);
  DevMode.dmBitsPerPel := FBitsPerPel;
  DevMode.dmPelsWidth := FWidth;
  DevMode.dmPelsHeight := FHeight;
  DevMode.dmDisplayFlags := 0;
  DevMode.dmDisplayFrequency := FFrequency;
  DevMode.dmFields := DM_BITSPERPEL or DM_PELSWIDTH or DM_PELSHEIGHT or DM_DISPLAYFREQUENCY;
  Result := False;
  case ChangeDisplaySettings(DevMode, 0) of
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

{ @004650D4  AFrequency = -1 matches any refresh rate. }
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
  More: Boolean;
  DevMode: TDeviceMode;
begin
  inherited Create;
  I := 0;
  repeat
    More := EnumDisplaySettings(nil, I, DevMode);
    Add(TScrnMode.Create(DevMode.dmPelsWidth, DevMode.dmPelsHeight,
      DevMode.dmBitsPerPel, DevMode.dmDisplayFrequency));
    Inc(I);
  until not More;
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
  W, H: Integer;
  DC: HDC;
  Bits, Refresh: Integer;
begin
  W := Screen.Width;    { NOTE: unused }
  H := Screen.Height;   { NOTE: unused }
  DC := GetDC(0);
  Bits := GetDeviceCaps(DC, BITSPIXEL);
  Refresh := GetDeviceCaps(DC, VREFRESH);
  ReleaseDC(0, DC);
  OriginalMode := Find(Screen.Width, Screen.Height, Bits, Refresh);
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
  { NOTE: Result is never assigned in the original (returns whatever was in EBX) }
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

unit Sprframe;

{ Sprite-frames. Een TFrameList bezit een oppervlak waarop al zijn frames naast elkaar liggen;
  een TFrame is een benoemde rechthoek van dat oppervlak. De lijst wordt in de DFM gestreamd
  als de binaire eigenschap 'Data'.
  Gedecompileerd uit ROS.exe v1.1, code 00463C14-00464F17. }

{$I zm.inc}

interface

uses
  Windows, SysUtils, Classes, Graphics, uSurface;

type
  EFrame = class(Exception);

  TFrameName = string[80];

  TFrameList = class;

  TFrame = class(TPersistent)
  private
    FName: TFrameName;          { +0x04 }
    FFrameList: TFrameList;     { +0x58 }
    FX: SmallInt;               { +0x5C  positie op het oppervlak van de framelijst }
    FY: SmallInt;               { +0x5E }
    FWidth: SmallInt;           { +0x60 }
    FHeight: SmallInt;          { +0x62 }
    FHotSpotX: SmallInt;        { +0x64 }
    FHotSpotY: SmallInt;        { +0x66 }
    FData: TMemoryStream;       { +0x68 }
    procedure Init(Name: TFrameName; AFrameList: TFrameList; Surface: TSurface);
    procedure IncCount;
  public
    constructor Create(Name: TFrameName; AFrameList: TFrameList; Surface: TSurface;
      ATransparentColor: TColor);
    constructor CreateEmpty(AFrameList: TFrameList);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure Draw(Dest: TSurface; DestRect: TRect;
      MirrorX, MirrorY, Transparent: Boolean); virtual;           { +0x0C }
    procedure DrawDC(DC: HDC; DestRect: TRect;
      MirrorX, MirrorY, Transparent: Boolean); virtual;           { +0x10 }
    procedure FreeData;
    function GetWidth: Integer;
    procedure SetWidth(Value: Integer);
    function GetHeight: Integer;
    procedure SetHeight(Value: Integer);
    function GetSurface: TSurface;
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
    property Name: TFrameName read FName write FName;
    property FrameList: TFrameList read FFrameList;
    property X: SmallInt read FX write FX;
    property Y: SmallInt read FY write FY;
    property Width: Integer read GetWidth write SetWidth;
    property Height: Integer read GetHeight write SetHeight;
    property HotSpotX: SmallInt read FHotSpotX write FHotSpotX;
    property HotSpotY: SmallInt read FHotSpotY write FHotSpotY;
    property Data: TMemoryStream read FData write FData;
    property Surface: TSurface read GetSurface;
  end;

  { Lijst die zijn objecten bezit (en vrijgeeft) }
  TPersistentList = class(TPersistent)
  private
    FList: TList;               { +0x04 }
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear; virtual;                                     { +0x0C }
    function GetCount: Integer;
    property List: TList read FList;
    property Count: Integer read GetCount;
  end;

  TFrameList = class(TPersistentList)
  private
    FTransparentColor: TColor;  { +0x08 }
    FSurface: TSurface;         { +0x0C }
    FClearing: Boolean;         { +0x10 }
    FFormat: string[127];       { +0x11  beeldformaat van de gestreamde data ('DFM' / 'BMP') }
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(ATransparentColor: TColor);
    destructor Destroy; override;
    procedure RemoveFrame(Frame: TFrame);
    procedure AddImage(Image: TSurface; var X, Y: SmallInt);
    procedure Clear; override;
    function IndexOf(Name: TFrameName): Integer;
    procedure Assign(Source: TPersistent); override;
    function FrameByName(Name: TFrameName): TFrame;
    function GetFrame(Index: Integer): TFrame;
    function Add(Name: TFrameName; Image: TSurface): TFrame;
    function AddFrame(Name: TFrameName; Image: TSurface): TFrame;
    procedure SetTransparentColor(Value: TColor);
    property Frames[Index: Integer]: TFrame read GetFrame; default;
    property Surface: TSurface read FSurface;
    property TransparentColor: TColor read FTransparentColor write SetTransparentColor;
  end;

  TFrameProgressEvent = procedure(Position, Size: Integer) of object;

const
  ElrondMode: Boolean = False;  { 00488D80 }
  FrameCount: Integer = 0;      { 00488D84: aantal levende TFrame-instanties }

var
  OnFrameProgress: TFrameProgressEvent;  { 0048A8D8: wordt aangeroepen terwijl frames gestreamd worden }

implementation

uses
  Forms, Dialogs, uString;

{ @00463E78 }
procedure DoProgress(Stream: TStream);
begin
  if Assigned(OnFrameProgress) then
    OnFrameProgress(Stream.Position, Stream.Size);
end;

{ @00463EA8 }
procedure TFrame.Init(Name: TFrameName; AFrameList: TFrameList; Surface: TSurface);
begin
  FName := Name;
  FFrameList := AFrameList;
  if Surface = nil then
  begin
    FHeight := 0;
    FWidth := 0;
  end
  else
  begin
    FHeight := Surface.Height;
    FWidth := Surface.Width;
  end;
  FX := -1;
  FY := -1;
  FData := nil;
end;

{ @00463F24 }
constructor TFrame.Create(Name: TFrameName; AFrameList: TFrameList; Surface: TSurface;
  ATransparentColor: TColor);
begin
  inherited Create;
  Init(Name, AFrameList, Surface);
  if FFrameList <> nil then
    FFrameList.AddImage(Surface, FX, FY);
  IncCount;
  if FFrameList = nil then
    raise EFrame.Create('Creation of frame failed. Framelist cannot be nil');
end;

{ @00464004 }
constructor TFrame.CreateEmpty(AFrameList: TFrameList);
begin
  inherited Create;
  Init('', AFrameList, nil);
  IncCount;
  FFrameList := AFrameList;
  if FFrameList = nil then
    raise EFrame.Create('Creation of frame failed. Framelist cannot be nil');
end;

{ @004640BC }
destructor TFrame.Destroy;
begin
  FFrameList.RemoveFrame(Self);
  Dec(FrameCount);
  FreeData;
  inherited Destroy;
end;

{ @004640F8 }
procedure TFrame.Assign(Source: TPersistent);
var
  Bron: TFrame;
begin
  if not (Source is TFrame) then
    inherited Assign(Source)
  else
  begin
    Bron := Source as TFrame;
    FName := Bron.FName;
    FX := Bron.FX;
    FY := Bron.FY;
    FWidth := Bron.FWidth;
    FHeight := Bron.FHeight;
    FHotSpotX := Bron.FHotSpotX;
    FHotSpotY := Bron.FHotSpotY;
    FreeData;
    if Bron.FData <> nil then
    begin
      FData := TMemoryStream.Create;
      FData.LoadFromStream(Bron.FData);
    end;
  end;
end;

{ @00464194 }
procedure TFrame.FreeData;
begin
  if FData <> nil then
  begin
    FData.Free;
    FData := nil;
  end;
end;

{ @004641AC }
function TFrame.GetWidth: Integer;
begin
  Result := FWidth;
end;

{ @004641B4 }
procedure TFrame.SetWidth(Value: Integer);
begin
  FWidth := Value;
end;

{ @004641BC }
function TFrame.GetHeight: Integer;
begin
  Result := FHeight;
end;

{ @004641C4 }
procedure TFrame.SetHeight(Value: Integer);
begin
  FHeight := Value;
end;

{ @004641CC }
procedure TFrame.IncCount;
begin
  Inc(FrameCount);
end;

{ @004641D4 }
function TFrame.GetSurface: TSurface;
begin
  Result := FFrameList.FSurface;
end;

{ @004641DC }
procedure TFrame.DrawDC(DC: HDC; DestRect: TRect; MirrorX, MirrorY, Transparent: Boolean);
begin
  if Transparent then
    GetSurface.SetTransparentColor(FFrameList.FTransparentColor)
  else
    GetSurface.SetTransparentColor(clNoTransparent);
  GetSurface.DrawTo(DC, Rect(FX, FY, FX + FWidth, FY + FHeight), DestRect, MirrorX, MirrorY);
end;

{ @00464274 }
procedure TFrame.Draw(Dest: TSurface; DestRect: TRect; MirrorX, MirrorY, Transparent: Boolean);
var
  Oppervlak: TSurface;
begin
  if Transparent then
    GetSurface.SetTransparentColor(FFrameList.FTransparentColor)
  else
    GetSurface.SetTransparentColor(clNoTransparent);
  Oppervlak := GetSurface;
  Dest.CopyFrom(Oppervlak, Rect(FX, FY, FX + FWidth, FY + FHeight), DestRect, MirrorX, MirrorY);
end;

{ @00464310 }
procedure TFrame.ReadData(Stream: TStream);
var
  Versie: Byte;
begin
  DoProgress(Stream);
  Stream.ReadBuffer(Versie, 1);
  if Versie <= 1 then
  begin
    Stream.ReadBuffer(FName, SizeOf(FName));
    Stream.ReadBuffer(FX, 2);
    Stream.ReadBuffer(FY, 2);
    Stream.ReadBuffer(FWidth, 2);
    Stream.ReadBuffer(FHeight, 2);
    if Versie = 1 then
    begin
      Stream.ReadBuffer(FHotSpotX, 2);
      Stream.ReadBuffer(FHotSpotY, 2);
    end;
    if FFrameList = nil then
      raise EFrame.Create('Frame.ReadData: no FrameList');
  end
  else
    raise EFrame.Create('Frame.ReadData: TestByte larger than one');
  DoProgress(Stream);
end;

{ @00464440 }
procedure TFrame.WriteData(Stream: TStream);
var
  Versie: Byte;
begin
  Versie := 1;
  Stream.WriteBuffer(Versie, 1);
  Stream.WriteBuffer(FName, SizeOf(FName));
  Stream.WriteBuffer(FX, 2);
  Stream.WriteBuffer(FY, 2);
  Stream.WriteBuffer(FWidth, 2);
  Stream.WriteBuffer(FHeight, 2);
  Stream.WriteBuffer(FHotSpotX, 2);
  Stream.WriteBuffer(FHotSpotY, 2);
end;

{ @004644C8 }
constructor TPersistentList.Create;
begin
  inherited Create;
  FList := TList.Create;
end;

{ @0046450C }
destructor TPersistentList.Destroy;
begin
  Clear;
  FList.Free;
  inherited Destroy;
end;

{ @00464540 }
procedure TPersistentList.Clear;
var
  I: Integer;
begin
  for I := 0 to GetCount - 1 do
    TObject(FList[I]).Free;
  FList.Clear;
end;

{ @00464578 }
function TPersistentList.GetCount: Integer;
begin
  Result := FList.Count;
end;

{ @00464580 }
constructor TFrameList.Create(ATransparentColor: TColor);
begin
  inherited Create;
  FSurface := NewSurface;
  SetTransparentColor(ATransparentColor);
  FClearing := False;
end;

{ @004645D0 }
destructor TFrameList.Destroy;
begin
  Clear;
  FSurface.Free;
  inherited Destroy;
end;

{ @00464604  Snijdt de strook van het frame uit het oppervlak en schuift de frames rechts ervan
  naar links op. }
procedure TFrameList.RemoveFrame(Frame: TFrame);
var
  DestRect, SrcRect: TRect;
  I: Integer;
begin
  if FClearing then
    Exit;
  DestRect := Rect(Frame.FX, Frame.FY, FSurface.Width - Frame.GetWidth, FSurface.Height);
  SrcRect := Rect(Frame.GetWidth + Frame.FX, Frame.FY, FSurface.Width, FSurface.Height);
  for I := 0 to GetCount - 1 do
    if GetFrame(I).FX > Frame.FX then
      Dec(GetFrame(I).FX, Frame.GetWidth);
  FSurface.SetTransparentColor(clNoTransparent);
  FSurface.CopyFrom(FSurface, SrcRect, DestRect, False, False);
  FSurface.SetTransparentColor(FTransparentColor);
  FSurface.Width := FSurface.Width - Frame.GetWidth;
end;

{ @0046470C  Voegt Image rechts aan het oppervlak toe (of op X, Y wanneer die zijn opgegeven). }
procedure TFrameList.AddImage(Image: TSurface; var X, Y: SmallInt);
begin
  if (X = -1) or (Y = -1) then
  begin
    Y := 0;
    X := FSurface.Width;
  end;
  if GetCount = 0 then
  begin
    FSurface.Free;
    FSurface := NewSurface;
    FSurface.Assign(Image);
    X := 0;
  end;
  if FSurface.Width < Image.Width + X then
    FSurface.Width := Image.Width + X;
  if FSurface.Height < Image.Height + Y then
    FSurface.Height := Image.Height + Y;
  FSurface.SetTransparentColor(clNoTransparent);
  FSurface.CopyFrom(Image, Rect(0, 0, Image.Width, Image.Height),
    Rect(X, Y, X + Image.Width, Y + Image.Height), False, False);
  FSurface.SetTransparentColor(FTransparentColor);
end;

{ @00464854 }
procedure TFrameList.Clear;
begin
  if GetCount <> 0 then
  begin
    FClearing := True;
    inherited Clear;
    if FSurface <> nil then
    begin
      FSurface.Width := 1;
      FSurface.Height := 1;
    end;
    FClearing := False;
  end;
end;

{ @00464894 }
function TFrameList.IndexOf(Name: TFrameName): Integer;
var
  I: Integer;
begin
  for I := 0 to GetCount - 1 do
    if SameText2(GetFrame(I).FName, Name) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

{ @00464940 }
procedure TFrameList.Assign(Source: TPersistent);
var
  Bron: TFrameList;
  I: Integer;
  Nieuw: TFrame;
begin
  if not (Source is TFrameList) then
    inherited Assign(Source)
  else
  begin
    SetTransparentColor(clNoTransparent);
    Bron := Source as TFrameList;
    Clear;
    FClearing := False;
    FSurface.Assign(Bron.FSurface);
    for I := 0 to Bron.GetCount - 1 do
    begin
      Nieuw := TFrame.CreateEmpty(Self);
      Nieuw.Assign(Bron.GetFrame(I));
      FList.Add(Nieuw);
    end;
    SetTransparentColor(Bron.FTransparentColor);
  end;
end;

{ @004649F4 }
function TFrameList.FrameByName(Name: TFrameName): TFrame;
var
  I: Integer;
begin
  for I := 0 to GetCount - 1 do
    if SameText2(GetFrame(I).FName, Name) then
    begin
      Result := GetFrame(I);
      Exit;
    end;
  raise EFrame.Create('Bitmap name does not exist (' + Name + ')');
end;

{ @00464B38 }
function TFrameList.GetFrame(Index: Integer): TFrame;
begin
  Result := TObject(FList[Index]) as TFrame;
end;

{ @00464B58 }
function TFrameList.Add(Name: TFrameName; Image: TSurface): TFrame;
begin
  Result := TFrame.Create(Name, Self, Image, FTransparentColor);
  FList.Add(Result);
end;

{ @00464BA4 }
function TFrameList.AddFrame(Name: TFrameName; Image: TSurface): TFrame;
begin
  if ElrondMode then
  begin
    Application.MessageBox('You are in Elrond mode', '', 0);
    Result := nil;
  end
  else
    Result := Add(Name, Image);
end;

{ @00464C10 }
procedure TFrameList.SetTransparentColor(Value: TColor);
begin
  FSurface.SetTransparentColor(Value);
  FTransparentColor := Value;
end;

{ @00464C28 }
procedure TFrameList.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  Filer.DefineBinaryProperty('Data', ReadData, WriteData, True);
end;

{ @00464C64 }
procedure TFrameList.ReadData(Stream: TStream);
var
  Aantal: SmallInt;
  I: Integer;
  Beeld: TFrame;
begin
  FSurface.SetTransparentColor(clNoTransparent);
  DoProgress(Stream);
  Stream.ReadBuffer(Aantal, 2);
  if Aantal >= 0 then
    FFormat := 'DFM'   { oude data: geen formaatkop, Aantal is het aantal frames }
  else
  begin
    Stream.ReadBuffer(FFormat[1], -Aantal);
    SetLength(FFormat, -Aantal);
    Stream.ReadBuffer(Aantal, 2);
  end;
  for I := 1 to Aantal do
  begin
    Beeld := TFrame.CreateEmpty(Self);
    Beeld.ReadData(Stream);
    FList.Add(Beeld);
  end;
  if GetCount <> 0 then
    FSurface.LoadFromStream(Stream);
  DoProgress(Stream);
  FSurface.SetTransparentColor(FTransparentColor);
end;

{ @00464D28  doet niets (overblijfsel van het debuggen) }
procedure DebugStr(Tekst: string);
begin
  Tekst := Tekst + 'X';
end;

{ @00464D80 }
procedure TFrameList.WriteData(Stream: TStream);
var
  OudTransparant: TColor;
  Aantal: SmallInt;
  Formaat: string;
  I: Integer;
begin
  try
    OudTransparant := FTransparentColor;
    SetTransparentColor(clNoTransparent);
    Aantal := -3;
    Formaat := 'BMP';
    Stream.WriteBuffer(Aantal, 2);
    Stream.WriteBuffer(Formaat[1], -Aantal);
    Aantal := GetCount;
    Stream.WriteBuffer(Aantal, 2);
    for I := 0 to Aantal - 1 do
      GetFrame(I).WriteData(Stream);
    DebugStr(IntToStr(FSurface.Width));
    if GetCount <> 0 then
      FSurface.SaveToStream(Stream);
    SetTransparentColor(OudTransparant);
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

{ @00464F00 }
initialization
  OnFrameProgress := nil;

end.

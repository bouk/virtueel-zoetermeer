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

  TFrameNaam = string[80];

  TFrameList = class;

  TFrame = class(TPersistent)
  private
    FName: TFrameNaam;          { +0x04 }
    FFrameLijst: TFrameList;     { +0x58 }
    FX: SmallInt;               { +0x5C  positie op het oppervlak van de framelijst }
    FY: SmallInt;               { +0x5E }
    FWidth: SmallInt;           { +0x60 }
    FHeight: SmallInt;          { +0x62 }
    FHotpuntX: SmallInt;        { +0x64 }
    FHotpuntY: SmallInt;        { +0x66 }
    FData: TMemoryStream;       { +0x68 }
    procedure Initialiseer(Name: TFrameNaam; AFrameList: TFrameList; Surface: TSurface);
    procedure VerhoogAantal;
  public
    constructor Create(Name: TFrameNaam; AFrameList: TFrameList; Surface: TSurface;
      ATransparantKleur: TColor);
    constructor MaakLeeg(AFrameList: TFrameList);
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    procedure Draw(Dest: TSurface; DestRect: TRect;
      MirrorX, MirrorY, Transparent: Boolean); virtual;           { +0x0C }
    procedure TekenDC(DC: HDC; DestRect: TRect;
      MirrorX, MirrorY, Transparent: Boolean); virtual;           { +0x10 }
    procedure GeefDataVrij;
    function GetWidth: Integer;
    procedure SetWidth(Value: Integer);
    function GetHeight: Integer;
    procedure SetHeight(Value: Integer);
    function LeesOppervlak: TSurface;
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
    property Name: TFrameNaam read FName write FName;
    property FrameList: TFrameList read FFrameLijst;
    property X: SmallInt read FX write FX;
    property Y: SmallInt read FY write FY;
    property Width: Integer read GetWidth write SetWidth;
    property Height: Integer read GetHeight write SetHeight;
    property HotSpotX: SmallInt read FHotpuntX write FHotpuntX;
    property HotSpotY: SmallInt read FHotpuntY write FHotpuntY;
    property Data: TMemoryStream read FData write FData;
    property Surface: TSurface read LeesOppervlak;
  end;

  { Lijst die zijn objecten bezit (en vrijgeeft) }
  TPersistentList = class(TPersistent)
  private
    FLijst: TList;               { +0x04 }
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear; virtual;                                     { +0x0C }
    function GetCount: Integer;
    property List: TList read FLijst;
    property Count: Integer read GetCount;
  end;

  TFrameList = class(TPersistentList)
  private
    FTransparentColor: TColor;  { +0x08 }
    FOppervlak: TSurface;         { +0x0C }
    FLeegmaken: Boolean;         { +0x10 }
    FFormaat: string[127];       { +0x11  beeldformaat van de gestreamde data ('DFM' / 'BMP') }
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(ATransparantKleur: TColor);
    destructor Destroy; override;
    procedure VerwijderFrame(Frame: TFrame);
    procedure VoegBeeldToe(Image: TSurface; var X, Y: SmallInt);
    procedure Clear; override;
    function IndexOf(Name: TFrameNaam): Integer;
    procedure Assign(Source: TPersistent); override;
    function FrameOpNaam(Name: TFrameNaam): TFrame;
    function LeesFrame(Index: Integer): TFrame;
    function Add(Name: TFrameNaam; Image: TSurface): TFrame;
    function VoegFrameToe(Name: TFrameNaam; Image: TSurface): TFrame;
    procedure SetTransparentColor(Value: TColor);
    property Beelden[Index: Integer]: TFrame read LeesFrame; default;
    property Surface: TSurface read FOppervlak;
    property TransparentColor: TColor read FTransparentColor write SetTransparentColor;
  end;

  TFrameVoortgangEvent = procedure(Position, Size: Integer) of object;

const
  ElrondModus: Boolean = False;  { 00488D80 }
  FrameAantal: Integer = 0;      { 00488D84: aantal levende TFrame-instanties }

var
  OnFrameVoortgang: TFrameVoortgangEvent;  { 0048A8D8: wordt aangeroepen terwijl frames gestreamd worden }

implementation

uses
  Forms, Dialogs, uString;

{ @00463E78 }
procedure MeldVoortgang(Stream: TStream);
begin
  if Assigned(OnFrameVoortgang) then
    OnFrameVoortgang(Stream.Position, Stream.Size);
end;

{ @00463EA8 }
procedure TFrame.Initialiseer(Name: TFrameNaam; AFrameList: TFrameList; Surface: TSurface);
begin
  FName := Name;
  FFrameLijst := AFrameList;
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
constructor TFrame.Create(Name: TFrameNaam; AFrameList: TFrameList; Surface: TSurface;
  ATransparantKleur: TColor);
begin
  inherited Create;
  Initialiseer(Name, AFrameList, Surface);
  if FFrameLijst <> nil then
    FFrameLijst.VoegBeeldToe(Surface, FX, FY);
  VerhoogAantal;
  if FFrameLijst = nil then
    raise EFrame.Create('Creation of frame failed. Framelist cannot be nil');
end;

{ @00464004 }
constructor TFrame.MaakLeeg(AFrameList: TFrameList);
begin
  inherited Create;
  Initialiseer('', AFrameList, nil);
  VerhoogAantal;
  FFrameLijst := AFrameList;
  if FFrameLijst = nil then
    raise EFrame.Create('Creation of frame failed. Framelist cannot be nil');
end;

{ @004640BC }
destructor TFrame.Destroy;
begin
  FFrameLijst.VerwijderFrame(Self);
  Dec(FrameAantal);
  GeefDataVrij;
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
    FHotpuntX := Bron.FHotpuntX;
    FHotpuntY := Bron.FHotpuntY;
    GeefDataVrij;
    if Bron.FData <> nil then
    begin
      FData := TMemoryStream.Create;
      FData.LoadFromStream(Bron.FData);
    end;
  end;
end;

{ @00464194 }
procedure TFrame.GeefDataVrij;
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
procedure TFrame.VerhoogAantal;
begin
  Inc(FrameAantal);
end;

{ @004641D4 }
function TFrame.LeesOppervlak: TSurface;
begin
  Result := FFrameLijst.FOppervlak;
end;

{ @004641DC }
procedure TFrame.TekenDC(DC: HDC; DestRect: TRect; MirrorX, MirrorY, Transparent: Boolean);
begin
  if Transparent then
    LeesOppervlak.SetTransparentColor(FFrameLijst.FTransparentColor)
  else
    LeesOppervlak.SetTransparentColor(clGeenTransparant);
  LeesOppervlak.TekenNaar(DC, Rect(FX, FY, FX + FWidth, FY + FHeight), DestRect, MirrorX, MirrorY);
end;

{ @00464274 }
procedure TFrame.Draw(Dest: TSurface; DestRect: TRect; MirrorX, MirrorY, Transparent: Boolean);
var
  Oppervlak: TSurface;
begin
  if Transparent then
    LeesOppervlak.SetTransparentColor(FFrameLijst.FTransparentColor)
  else
    LeesOppervlak.SetTransparentColor(clGeenTransparant);
  Oppervlak := LeesOppervlak;
  Dest.KopieerVan(Oppervlak, Rect(FX, FY, FX + FWidth, FY + FHeight), DestRect, MirrorX, MirrorY);
end;

{ @00464310 }
procedure TFrame.ReadData(Stream: TStream);
var
  Versie: Byte;
begin
  MeldVoortgang(Stream);
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
      Stream.ReadBuffer(FHotpuntX, 2);
      Stream.ReadBuffer(FHotpuntY, 2);
    end;
    if FFrameLijst = nil then
      raise EFrame.Create('Frame.ReadData: no FrameList');
  end
  else
    raise EFrame.Create('Frame.ReadData: TestByte larger than one');
  MeldVoortgang(Stream);
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
  Stream.WriteBuffer(FHotpuntX, 2);
  Stream.WriteBuffer(FHotpuntY, 2);
end;

{ @004644C8 }
constructor TPersistentList.Create;
begin
  inherited Create;
  FLijst := TList.Create;
end;

{ @0046450C }
destructor TPersistentList.Destroy;
begin
  Clear;
  FLijst.Free;
  inherited Destroy;
end;

{ @00464540 }
procedure TPersistentList.Clear;
var
  I: Integer;
begin
  for I := 0 to GetCount - 1 do
    TObject(FLijst[I]).Free;
  FLijst.Clear;
end;

{ @00464578 }
function TPersistentList.GetCount: Integer;
begin
  Result := FLijst.Count;
end;

{ @00464580 }
constructor TFrameList.Create(ATransparantKleur: TColor);
begin
  inherited Create;
  FOppervlak := NieuwOppervlak;
  SetTransparentColor(ATransparantKleur);
  FLeegmaken := False;
end;

{ @004645D0 }
destructor TFrameList.Destroy;
begin
  Clear;
  FOppervlak.Free;
  inherited Destroy;
end;

{ @00464604  Snijdt de strook van het frame uit het oppervlak en schuift de frames rechts ervan
  naar links op. }
procedure TFrameList.VerwijderFrame(Frame: TFrame);
var
  DestRect, SrcRect: TRect;
  I: Integer;
begin
  if FLeegmaken then
    Exit;
  DestRect := Rect(Frame.FX, Frame.FY, FOppervlak.Width - Frame.GetWidth, FOppervlak.Height);
  SrcRect := Rect(Frame.GetWidth + Frame.FX, Frame.FY, FOppervlak.Width, FOppervlak.Height);
  for I := 0 to GetCount - 1 do
    if LeesFrame(I).FX > Frame.FX then
      Dec(LeesFrame(I).FX, Frame.GetWidth);
  FOppervlak.SetTransparentColor(clGeenTransparant);
  FOppervlak.KopieerVan(FOppervlak, SrcRect, DestRect, False, False);
  FOppervlak.SetTransparentColor(FTransparentColor);
  FOppervlak.Width := FOppervlak.Width - Frame.GetWidth;
end;

{ @0046470C  Voegt Image rechts aan het oppervlak toe (of op X, Y wanneer die zijn opgegeven). }
procedure TFrameList.VoegBeeldToe(Image: TSurface; var X, Y: SmallInt);
begin
  if (X = -1) or (Y = -1) then
  begin
    Y := 0;
    X := FOppervlak.Width;
  end;
  if GetCount = 0 then
  begin
    FOppervlak.Free;
    FOppervlak := NieuwOppervlak;
    FOppervlak.Assign(Image);
    X := 0;
  end;
  if FOppervlak.Width < Image.Width + X then
    FOppervlak.Width := Image.Width + X;
  if FOppervlak.Height < Image.Height + Y then
    FOppervlak.Height := Image.Height + Y;
  FOppervlak.SetTransparentColor(clGeenTransparant);
  FOppervlak.KopieerVan(Image, Rect(0, 0, Image.Width, Image.Height),
    Rect(X, Y, X + Image.Width, Y + Image.Height), False, False);
  FOppervlak.SetTransparentColor(FTransparentColor);
end;

{ @00464854 }
procedure TFrameList.Clear;
begin
  if GetCount <> 0 then
  begin
    FLeegmaken := True;
    inherited Clear;
    if FOppervlak <> nil then
    begin
      FOppervlak.Width := 1;
      FOppervlak.Height := 1;
    end;
    FLeegmaken := False;
  end;
end;

{ @00464894 }
function TFrameList.IndexOf(Name: TFrameNaam): Integer;
var
  I: Integer;
begin
  for I := 0 to GetCount - 1 do
    if GelijkTekst2(LeesFrame(I).FName, Name) then
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
    SetTransparentColor(clGeenTransparant);
    Bron := Source as TFrameList;
    Clear;
    FLeegmaken := False;
    FOppervlak.Assign(Bron.FOppervlak);
    for I := 0 to Bron.GetCount - 1 do
    begin
      Nieuw := TFrame.MaakLeeg(Self);
      Nieuw.Assign(Bron.LeesFrame(I));
      FLijst.Add(Nieuw);
    end;
    SetTransparentColor(Bron.FTransparentColor);
  end;
end;

{ @004649F4 }
function TFrameList.FrameOpNaam(Name: TFrameNaam): TFrame;
var
  I: Integer;
begin
  for I := 0 to GetCount - 1 do
    if GelijkTekst2(LeesFrame(I).FName, Name) then
    begin
      Result := LeesFrame(I);
      Exit;
    end;
  raise EFrame.Create('Bitmap name does not exist (' + Name + ')');
end;

{ @00464B38 }
function TFrameList.LeesFrame(Index: Integer): TFrame;
begin
  Result := TObject(FLijst[Index]) as TFrame;
end;

{ @00464B58 }
function TFrameList.Add(Name: TFrameNaam; Image: TSurface): TFrame;
begin
  Result := TFrame.Create(Name, Self, Image, FTransparentColor);
  FLijst.Add(Result);
end;

{ @00464BA4 }
function TFrameList.VoegFrameToe(Name: TFrameNaam; Image: TSurface): TFrame;
begin
  if ElrondModus then
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
  FOppervlak.SetTransparentColor(Value);
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
  FOppervlak.SetTransparentColor(clGeenTransparant);
  MeldVoortgang(Stream);
  Stream.ReadBuffer(Aantal, 2);
  if Aantal >= 0 then
    FFormaat := 'DFM'   { oude data: geen formaatkop, Aantal is het aantal frames }
  else
  begin
    Stream.ReadBuffer(FFormaat[1], -Aantal);
    SetLength(FFormaat, -Aantal);
    Stream.ReadBuffer(Aantal, 2);
  end;
  for I := 1 to Aantal do
  begin
    Beeld := TFrame.MaakLeeg(Self);
    Beeld.ReadData(Stream);
    FLijst.Add(Beeld);
  end;
  if GetCount <> 0 then
    FOppervlak.LoadFromStream(Stream);
  MeldVoortgang(Stream);
  FOppervlak.SetTransparentColor(FTransparentColor);
end;

{ @00464D28  doet niets (overblijfsel van het debuggen) }
procedure DebugTekst(Tekst: string);
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
    SetTransparentColor(clGeenTransparant);
    Aantal := -3;
    Formaat := 'BMP';
    Stream.WriteBuffer(Aantal, 2);
    Stream.WriteBuffer(Formaat[1], -Aantal);
    Aantal := GetCount;
    Stream.WriteBuffer(Aantal, 2);
    for I := 0 to Aantal - 1 do
      LeesFrame(I).WriteData(Stream);
    DebugTekst(IntToStr(FOppervlak.Width));
    if GetCount <> 0 then
      FOppervlak.SaveToStream(Stream);
    SetTransparentColor(OudTransparant);
  except
    on E: Exception do
      ShowMessage(E.Message);
  end;
end;

{ @00464F00 }
initialization
  OnFrameVoortgang := nil;

end.

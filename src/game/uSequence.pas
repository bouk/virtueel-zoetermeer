unit uSequence;

{ Animatiereeksen van een TSprite. Een TSequence is een benoemde lijst van TFrameRefs
  (framenaam, verschuiving en vertraging); TSequenceList bevat alle reeksen van een
  sprite. Beide worden als binaire 'Data'-properties in het formulierbestand gestreamd.
  Gedecompileerd uit ROS.exe v1.1, code 0046EA44-0046F530. }

{$I zm.inc}

interface

uses
  Classes, Sprframe;

type
  { Framenamen en reeksnamen. De RTTI van TSprite.CurrentFrame plaatst dit
    type in Sprframe (tkString, maximale lengte 80); Sprframe.pas noemt het
    TFrameNaam, dus het wordt hier onder de oorspronkelijke naam gedeclareerd. }
  TName = string[80];

  TFrameRef = class(TPersistent)
  private
    FFrameNaam: TName;           { +0x04 }
    FEigenaar: TComponent;          { +0x58  de TSprite }
    FVersX: SmallInt;               { +0x5C }
    FVersY: SmallInt;               { +0x5E }
    FVersZ: SmallInt;               { +0x60  gestreamd sinds versie 1.1b }
    FVertraging: Real48;              { +0x68  seconden }
    procedure ZetFrameNaam(Value: TName);
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(AOwner: TComponent);
    procedure Assign(Source: TPersistent); override;
    function LeesFrameIndex: Integer;
    function LeesVersX: Integer;
    function LeesVersY: Integer;
    function LeesVersZ: Integer;
    property FrameNaam: TName read FFrameNaam write ZetFrameNaam;
    property Owner: TComponent read FEigenaar;
    property Delay: Real48 read FVertraging write FVertraging;
  end;

  TSequence = class(TPersistentList)
  private
    FName: TName;                { +0x08 }
    FTijd: Double;               { +0x60  op 0 gezet en gekopieerd, nooit gelezen }
    FEigenaar: TComponent;          { +0x68  de TSprite }
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(AOwner: TComponent);
    procedure Assign(Source: TPersistent); override;
    procedure LeesStap(Nr: Integer; var FrameIndex, DX, DY, DZ: Integer;
      var Delay: Double);
    function LeesFrameVerwijzing(Nr: Integer): TFrameRef;
    property Name: TName read FName write FName;
    property Owner: TComponent read FEigenaar;
    property FrameVerwijzingen[Nr: Integer]: TFrameRef read LeesFrameVerwijzing; default;
  end;

  TSequenceList = class(TPersistentList)
  private
    FEigenaar: TComponent;          { +0x08  de TSprite }
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(AOwner: TComponent);
    procedure Assign(Source: TPersistent); override;
    function LeesReeks(Nr: Integer): TSequence;
    function ReeksOpNaam(Name: TName): TSequence;
    function IndexOf(Name: TName): Integer;
    function Add(Reeks: TSequence): Integer;
    property Owner: TComponent read FEigenaar;
    property Reeksen[Nr: Integer]: TSequence read LeesReeks; default;
  end;

implementation

uses
  SysUtils, uSprite;

{ ------------------------------------------------------------------ TFrameRef }

{ @0046EBF8 }
constructor TFrameRef.Create(AOwner: TComponent);
begin
  inherited Create;
  FEigenaar := AOwner;
end;

{ @0046EC34 }
procedure TFrameRef.ZetFrameNaam(Value: TName);
begin
  FFrameNaam := Value;
end;

{ @0046EC68 }
function TFrameRef.LeesFrameIndex: Integer;
begin
  Result := (FEigenaar as TSprite).FrameList.IndexOf(FFrameNaam);
end;

{ @0046EC88 }
function TFrameRef.LeesVersX: Integer;
begin
  Result := FVersX;
end;

{ @0046EC90 }
function TFrameRef.LeesVersY: Integer;
begin
  Result := FVersY;
end;

{ @0046EC98 }
function TFrameRef.LeesVersZ: Integer;
begin
  Result := FVersZ;
end;

{ @0046ECA0  record: naam (81) DX (2) DY (2) [DZ (2)] Delay (6, Real48) }
procedure TFrameRef.ReadData(Stream: TStream);
var
  Versie: string;
  S: TName;
begin
  if FEigenaar <> nil then
    Versie := (FEigenaar as TSprite).Versienummer
  else
    Versie := '';
  Stream.ReadBuffer(S, SizeOf(TName));
  ZetFrameNaam(S);
  Stream.ReadBuffer(FVersX, 2);
  Stream.ReadBuffer(FVersY, 2);
  if Versie >= '1.1b' then
    Stream.ReadBuffer(FVersZ, 2)
  else
    FVersZ := 0;
  Stream.ReadBuffer(FVertraging, 6);
end;

{ @0046ED8C }
procedure TFrameRef.WriteData(Stream: TStream);
begin
  Stream.WriteBuffer(FFrameNaam, SizeOf(TName));
  Stream.WriteBuffer(FVersX, 2);
  Stream.WriteBuffer(FVersY, 2);
  Stream.WriteBuffer(FVersZ, 2);
  Stream.WriteBuffer(FVertraging, 6);
end;

{ @0046EDE0 }
procedure TFrameRef.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  Filer.DefineBinaryProperty('Data', ReadData, WriteData, True);
end;

{ @0046EE1C }
procedure TFrameRef.Assign(Source: TPersistent);
var
  Verwijzing: TFrameRef;
begin
  if not (Source is TFrameRef) then
    inherited Assign(Source)
  else
  begin
    Verwijzing := Source as TFrameRef;
    FFrameNaam := Verwijzing.FFrameNaam;
    FEigenaar := Verwijzing.FEigenaar;
    FVersX := Verwijzing.FVersX;
    FVersY := Verwijzing.FVersY;
    FVersZ := Verwijzing.FVersZ;
    FVertraging := Verwijzing.FVertraging;
  end;
end;

{ ------------------------------------------------------------------ TSequence }

{ @0046EE8C }
constructor TSequence.Create(AOwner: TComponent);
begin
  inherited Create;
  FName := 'New Sequence';
  FTijd := 0;
  FEigenaar := AOwner;
end;

{ @0046EEF4 }
procedure TSequence.Assign(Source: TPersistent);
var
  Reeks: TSequence;
  Verwijzing: TFrameRef;
  I: Integer;
begin
  if not (Source is TSequence) then
    inherited Assign(Source)
  else
  begin
    Reeks := Source as TSequence;
    FName := Reeks.FName;
    FTijd := Reeks.FTijd;
    FEigenaar := Reeks.FEigenaar;
    Clear;
    for I := 0 to Reeks.Count - 1 do
    begin
      Verwijzing := TFrameRef.Create(FEigenaar);
      Verwijzing.Assign(Reeks.LeesFrameVerwijzing(I));
      List.Add(Verwijzing);
    end;
  end;
end;

{ @0046EFA0  frame-index, verschuiving en vertraging van stap Index (-1: eerste frame, geen verschuiving) }
procedure TSequence.LeesStap(Nr: Integer; var FrameIndex, DX, DY, DZ: Integer;
  var Delay: Double);
begin
  if Nr = -1 then
  begin
    DX := 0;
    DY := 0;
    DZ := 0;
    Delay := 0;
    FrameIndex := LeesFrameVerwijzing(0).LeesFrameIndex;
  end
  else
  begin
    DX := LeesFrameVerwijzing(Nr).LeesVersX;
    DY := LeesFrameVerwijzing(Nr).LeesVersY;
    DZ := LeesFrameVerwijzing(Nr).LeesVersZ;
    Delay := LeesFrameVerwijzing(Nr).FVertraging;
    FrameIndex := LeesFrameVerwijzing(Nr).LeesFrameIndex;
  end;
end;

{ @0046F04C }
function TSequence.LeesFrameVerwijzing(Nr: Integer): TFrameRef;
begin
  Result := TObject(List[Nr]) as TFrameRef;
end;

{ @0046F06C  record: naam (81) aantal (2) frame-verwijzingen }
procedure TSequence.ReadData(Stream: TStream);
var
  N, I: SmallInt;
  Verwijzing: TFrameRef;
begin
  Stream.ReadBuffer(FName, SizeOf(TName));
  Stream.ReadBuffer(N, 2);
  for I := 0 to N - 1 do
  begin
    Verwijzing := TFrameRef.Create(FEigenaar);
    Verwijzing.ReadData(Stream);
    List.Add(Verwijzing);
  end;
end;

{ @0046F0CC }
procedure TSequence.WriteData(Stream: TStream);
var
  N, I: SmallInt;
begin
  Stream.WriteBuffer(FName, SizeOf(TName));
  N := List.Count;
  Stream.WriteBuffer(N, 2);
  for I := 0 to N - 1 do
    LeesFrameVerwijzing(I).WriteData(Stream);
end;

{ @0046F128 }
procedure TSequence.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  Filer.DefineBinaryProperty('Data', ReadData, WriteData, True);
end;

{ -------------------------------------------------------------- TSequenceList }

{ @0046F164 }
constructor TSequenceList.Create(AOwner: TComponent);
begin
  inherited Create;
  FEigenaar := AOwner;
end;

{ @0046F1A0 }
procedure TSequenceList.Assign(Source: TPersistent);
var
  Lijst: TSequenceList;
  Reeks: TSequence;
  I: Integer;
begin
  if not (Source is TSequenceList) then
    inherited Assign(Source)
  else
  begin
    Lijst := Source as TSequenceList;
    FEigenaar := Lijst.FEigenaar;
    Clear;
    for I := 0 to Lijst.Count - 1 do
    begin
      Reeks := TSequence.Create(FEigenaar);
      Reeks.Assign(Lijst.LeesReeks(I));
      Add(Reeks);
    end;
  end;
end;

{ @0046F230 }
function TSequenceList.LeesReeks(Nr: Integer): TSequence;
begin
  Result := TObject(List[Nr]) as TSequence;
end;

{ @0046F250 }
function TSequenceList.ReeksOpNaam(Name: TName): TSequence;
var
  Nr: Integer;
begin
  Nr := IndexOf(Name);
  if Nr < 0 then
    raise ESprite.Create('SequenceByName: ' + Name + ' not found');
  Result := LeesReeks(Nr);
end;

{ @0046F34C  hoofdletterongevoelig }
function TSequenceList.IndexOf(Name: TName): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if UpperCase(LeesReeks(I).FName) = UpperCase(Name) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

{ @0046F410 }
function TSequenceList.Add(Reeks: TSequence): Integer;
begin
  Result := List.Add(Reeks);
end;

{ @0046F41C }
procedure TSequenceList.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  Filer.DefineBinaryProperty('Data', ReadData, WriteData, True);
end;

{ @0046F458  record: aantal (2) reeksen }
procedure TSequenceList.ReadData(Stream: TStream);
var
  N, I: SmallInt;
  Reeks: TSequence;
begin
  Stream.ReadBuffer(N, 2);
  for I := 0 to N - 1 do
  begin
    Reeks := TSequence.Create(FEigenaar);
    Reeks.ReadData(Stream);
    List.Add(Reeks);
  end;
end;

{ @0046F4AC }
procedure TSequenceList.WriteData(Stream: TStream);
var
  N, I: SmallInt;
begin
  N := List.Count;
  Stream.WriteBuffer(N, 2);
  for I := 0 to N - 1 do
    LeesReeks(I).WriteData(Stream);
end;

end.

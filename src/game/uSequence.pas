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
    TFrameName, dus het wordt hier onder de oorspronkelijke naam gedeclareerd. }
  TName = string[80];

  TFrameRef = class(TPersistent)
  private
    FFrameName: TName;           { +0x04 }
    FOwner: TComponent;          { +0x58  de TSprite }
    FDX: SmallInt;               { +0x5C }
    FDY: SmallInt;               { +0x5E }
    FDZ: SmallInt;               { +0x60  gestreamd sinds versie 1.1b }
    FDelay: Real48;              { +0x68  seconden }
    procedure SetFrameName(Value: TName);
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(AOwner: TComponent);
    procedure Assign(Source: TPersistent); override;
    function GetFrameIndex: Integer;
    function GetDX: Integer;
    function GetDY: Integer;
    function GetDZ: Integer;
    property FrameName: TName read FFrameName write SetFrameName;
    property Owner: TComponent read FOwner;
    property Delay: Real48 read FDelay write FDelay;
  end;

  TSequence = class(TPersistentList)
  private
    FName: TName;                { +0x08 }
    FTime: Double;               { +0x60  op 0 gezet en gekopieerd, nooit gelezen }
    FOwner: TComponent;          { +0x68  de TSprite }
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(AOwner: TComponent);
    procedure Assign(Source: TPersistent); override;
    procedure GetStep(Nr: Integer; var FrameIndex, DX, DY, DZ: Integer;
      var Delay: Double);
    function GetFrameRef(Nr: Integer): TFrameRef;
    property Name: TName read FName write FName;
    property Owner: TComponent read FOwner;
    property FrameRefs[Nr: Integer]: TFrameRef read GetFrameRef; default;
  end;

  TSequenceList = class(TPersistentList)
  private
    FOwner: TComponent;          { +0x08  de TSprite }
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(AOwner: TComponent);
    procedure Assign(Source: TPersistent); override;
    function GetSequence(Nr: Integer): TSequence;
    function SequenceByName(Name: TName): TSequence;
    function IndexOf(Name: TName): Integer;
    function Add(Reeks: TSequence): Integer;
    property Owner: TComponent read FOwner;
    property Sequences[Nr: Integer]: TSequence read GetSequence; default;
  end;

implementation

uses
  SysUtils, uSprite;

{ ------------------------------------------------------------------ TFrameRef }

{ @0046EBF8 }
constructor TFrameRef.Create(AOwner: TComponent);
begin
  inherited Create;
  FOwner := AOwner;
end;

{ @0046EC34 }
procedure TFrameRef.SetFrameName(Value: TName);
begin
  FFrameName := Value;
end;

{ @0046EC68 }
function TFrameRef.GetFrameIndex: Integer;
begin
  Result := (FOwner as TSprite).FrameList.IndexOf(FFrameName);
end;

{ @0046EC88 }
function TFrameRef.GetDX: Integer;
begin
  Result := FDX;
end;

{ @0046EC90 }
function TFrameRef.GetDY: Integer;
begin
  Result := FDY;
end;

{ @0046EC98 }
function TFrameRef.GetDZ: Integer;
begin
  Result := FDZ;
end;

{ @0046ECA0  record: naam (81) DX (2) DY (2) [DZ (2)] Delay (6, Real48) }
procedure TFrameRef.ReadData(Stream: TStream);
var
  Versie: string;
  S: TName;
begin
  if FOwner <> nil then
    Versie := (FOwner as TSprite).Version
  else
    Versie := '';
  Stream.ReadBuffer(S, SizeOf(TName));
  SetFrameName(S);
  Stream.ReadBuffer(FDX, 2);
  Stream.ReadBuffer(FDY, 2);
  if Versie >= '1.1b' then
    Stream.ReadBuffer(FDZ, 2)
  else
    FDZ := 0;
  Stream.ReadBuffer(FDelay, 6);
end;

{ @0046ED8C }
procedure TFrameRef.WriteData(Stream: TStream);
begin
  Stream.WriteBuffer(FFrameName, SizeOf(TName));
  Stream.WriteBuffer(FDX, 2);
  Stream.WriteBuffer(FDY, 2);
  Stream.WriteBuffer(FDZ, 2);
  Stream.WriteBuffer(FDelay, 6);
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
    FFrameName := Verwijzing.FFrameName;
    FOwner := Verwijzing.FOwner;
    FDX := Verwijzing.FDX;
    FDY := Verwijzing.FDY;
    FDZ := Verwijzing.FDZ;
    FDelay := Verwijzing.FDelay;
  end;
end;

{ ------------------------------------------------------------------ TSequence }

{ @0046EE8C }
constructor TSequence.Create(AOwner: TComponent);
begin
  inherited Create;
  FName := 'New Sequence';
  FTime := 0;
  FOwner := AOwner;
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
    FTime := Reeks.FTime;
    FOwner := Reeks.FOwner;
    Clear;
    for I := 0 to Reeks.Count - 1 do
    begin
      Verwijzing := TFrameRef.Create(FOwner);
      Verwijzing.Assign(Reeks.GetFrameRef(I));
      List.Add(Verwijzing);
    end;
  end;
end;

{ @0046EFA0  frame-index, verschuiving en vertraging van stap Index (-1: eerste frame, geen verschuiving) }
procedure TSequence.GetStep(Nr: Integer; var FrameIndex, DX, DY, DZ: Integer;
  var Delay: Double);
begin
  if Nr = -1 then
  begin
    DX := 0;
    DY := 0;
    DZ := 0;
    Delay := 0;
    FrameIndex := GetFrameRef(0).GetFrameIndex;
  end
  else
  begin
    DX := GetFrameRef(Nr).GetDX;
    DY := GetFrameRef(Nr).GetDY;
    DZ := GetFrameRef(Nr).GetDZ;
    Delay := GetFrameRef(Nr).FDelay;
    FrameIndex := GetFrameRef(Nr).GetFrameIndex;
  end;
end;

{ @0046F04C }
function TSequence.GetFrameRef(Nr: Integer): TFrameRef;
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
    Verwijzing := TFrameRef.Create(FOwner);
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
    GetFrameRef(I).WriteData(Stream);
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
  FOwner := AOwner;
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
    FOwner := Lijst.FOwner;
    Clear;
    for I := 0 to Lijst.Count - 1 do
    begin
      Reeks := TSequence.Create(FOwner);
      Reeks.Assign(Lijst.GetSequence(I));
      Add(Reeks);
    end;
  end;
end;

{ @0046F230 }
function TSequenceList.GetSequence(Nr: Integer): TSequence;
begin
  Result := TObject(List[Nr]) as TSequence;
end;

{ @0046F250 }
function TSequenceList.SequenceByName(Name: TName): TSequence;
var
  Nr: Integer;
begin
  Nr := IndexOf(Name);
  if Nr < 0 then
    raise ESprite.Create('SequenceByName: ' + Name + ' not found');
  Result := GetSequence(Nr);
end;

{ @0046F34C  hoofdletterongevoelig }
function TSequenceList.IndexOf(Name: TName): Integer;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if UpperCase(GetSequence(I).FName) = UpperCase(Name) then
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
    Reeks := TSequence.Create(FOwner);
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
    GetSequence(I).WriteData(Stream);
end;

end.

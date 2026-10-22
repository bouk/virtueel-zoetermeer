unit uSequence;

{ Animation sequences of a TSprite. A TSequence is a named list of TFrameRefs
  (frame name, offset and delay); TSequenceList holds all sequences of a
  sprite. Both are streamed as binary 'Data' properties in the form file.
  Decompiled from ROS.exe v1.1, code 0046EA44-0046F530. }

{$I zm.inc}

interface

uses
  Classes, Sprframe;

type
  { Frame and sequence names. The RTTI of TSprite.CurrentFrame places this
    type in Sprframe (tkString, max. length 80); Sprframe.pas calls it
    TFrameName, so it is declared here under its original name. }
  TName = string[80];

  TFrameRef = class(TPersistent)
  private
    FFrameName: TName;           { +0x04 }
    FOwner: TComponent;          { +0x58  the TSprite }
    FDX: SmallInt;               { +0x5C }
    FDY: SmallInt;               { +0x5E }
    FDZ: SmallInt;               { +0x60  streamed since version 1.1b }
    FDelay: Real48;              { +0x68  seconds }
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
    FTime: Double;               { +0x60  set to 0 and copied, never read }
    FOwner: TComponent;          { +0x68  the TSprite }
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(AOwner: TComponent);
    procedure Assign(Source: TPersistent); override;
    procedure GetStep(Index: Integer; var FrameIndex, DX, DY, DZ: Integer;
      var Delay: Double);
    function GetFrameRef(Index: Integer): TFrameRef;
    property Name: TName read FName write FName;
    property Owner: TComponent read FOwner;
    property FrameRefs[Index: Integer]: TFrameRef read GetFrameRef; default;
  end;

  TSequenceList = class(TPersistentList)
  private
    FOwner: TComponent;          { +0x08  the TSprite }
    procedure ReadData(Stream: TStream);
    procedure WriteData(Stream: TStream);
  protected
    procedure DefineProperties(Filer: TFiler); override;
  public
    constructor Create(AOwner: TComponent);
    procedure Assign(Source: TPersistent); override;
    function GetSequence(Index: Integer): TSequence;
    function SequenceByName(Name: TName): TSequence;
    function IndexOf(Name: TName): Integer;
    function Add(Sequence: TSequence): Integer;
    property Owner: TComponent read FOwner;
    property Sequences[Index: Integer]: TSequence read GetSequence; default;
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

{ @0046ECA0  record: name (81) DX (2) DY (2) [DZ (2)] Delay (6, Real48) }
procedure TFrameRef.ReadData(Stream: TStream);
var
  Version: string;
  S: TName;
begin
  if FOwner <> nil then
    Version := (FOwner as TSprite).Version
  else
    Version := '';
  Stream.ReadBuffer(S, SizeOf(TName));
  SetFrameName(S);
  Stream.ReadBuffer(FDX, 2);
  Stream.ReadBuffer(FDY, 2);
  if Version >= '1.1b' then
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
  Ref: TFrameRef;
begin
  if not (Source is TFrameRef) then
    inherited Assign(Source)
  else
  begin
    Ref := Source as TFrameRef;
    FFrameName := Ref.FFrameName;
    FOwner := Ref.FOwner;
    FDX := Ref.FDX;
    FDY := Ref.FDY;
    FDZ := Ref.FDZ;
    FDelay := Ref.FDelay;
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
  Seq: TSequence;
  Ref: TFrameRef;
  I: Integer;
begin
  if not (Source is TSequence) then
    inherited Assign(Source)
  else
  begin
    Seq := Source as TSequence;
    FName := Seq.FName;
    FTime := Seq.FTime;
    FOwner := Seq.FOwner;
    Clear;
    for I := 0 to Seq.Count - 1 do
    begin
      Ref := TFrameRef.Create(FOwner);
      Ref.Assign(Seq.GetFrameRef(I));
      List.Add(Ref);
    end;
  end;
end;

{ @0046EFA0  frame index, offset and delay of step Index (-1: first frame, no offset) }
procedure TSequence.GetStep(Index: Integer; var FrameIndex, DX, DY, DZ: Integer;
  var Delay: Double);
begin
  if Index = -1 then
  begin
    DX := 0;
    DY := 0;
    DZ := 0;
    Delay := 0;
    FrameIndex := GetFrameRef(0).GetFrameIndex;
  end
  else
  begin
    DX := GetFrameRef(Index).GetDX;
    DY := GetFrameRef(Index).GetDY;
    DZ := GetFrameRef(Index).GetDZ;
    Delay := GetFrameRef(Index).FDelay;
    FrameIndex := GetFrameRef(Index).GetFrameIndex;
  end;
end;

{ @0046F04C }
function TSequence.GetFrameRef(Index: Integer): TFrameRef;
begin
  Result := TObject(List[Index]) as TFrameRef;
end;

{ @0046F06C  record: name (81) count (2) frame refs }
procedure TSequence.ReadData(Stream: TStream);
var
  N, I: SmallInt;
  Ref: TFrameRef;
begin
  Stream.ReadBuffer(FName, SizeOf(TName));
  Stream.ReadBuffer(N, 2);
  for I := 0 to N - 1 do
  begin
    Ref := TFrameRef.Create(FOwner);
    Ref.ReadData(Stream);
    List.Add(Ref);
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
  List: TSequenceList;
  Seq: TSequence;
  I: Integer;
begin
  if not (Source is TSequenceList) then
    inherited Assign(Source)
  else
  begin
    List := Source as TSequenceList;
    FOwner := List.FOwner;
    Clear;
    for I := 0 to List.Count - 1 do
    begin
      Seq := TSequence.Create(FOwner);
      Seq.Assign(List.GetSequence(I));
      Add(Seq);
    end;
  end;
end;

{ @0046F230 }
function TSequenceList.GetSequence(Index: Integer): TSequence;
begin
  Result := TObject(List[Index]) as TSequence;
end;

{ @0046F250 }
function TSequenceList.SequenceByName(Name: TName): TSequence;
var
  Index: Integer;
begin
  Index := IndexOf(Name);
  if Index < 0 then
    raise ESprite.Create('SequenceByName: ' + Name + ' not found');
  Result := GetSequence(Index);
end;

{ @0046F34C  case-insensitive }
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
function TSequenceList.Add(Sequence: TSequence): Integer;
begin
  Result := List.Add(Sequence);
end;

{ @0046F41C }
procedure TSequenceList.DefineProperties(Filer: TFiler);
begin
  inherited DefineProperties(Filer);
  Filer.DefineBinaryProperty('Data', ReadData, WriteData, True);
end;

{ @0046F458  record: count (2) sequences }
procedure TSequenceList.ReadData(Stream: TStream);
var
  N, I: SmallInt;
  Seq: TSequence;
begin
  Stream.ReadBuffer(N, 2);
  for I := 0 to N - 1 do
  begin
    Seq := TSequence.Create(FOwner);
    Seq.ReadData(Stream);
    List.Add(Seq);
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

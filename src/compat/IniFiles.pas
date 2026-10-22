unit IniFiles;

{ IniFiles met het gedrag van Delphi 5. Deze unit schaduwt die van FPC: de TIniFile
  van FPC herschrijft bij elke wijziging het hele bestand en laat daarbij commentaar
  en lege regels weg. Die van Delphi 5 roept voor alles de profielfuncties van
  Windows aan (GetPrivateProfileString, WritePrivateProfileString), die het bestand
  ter plekke bewerken; dat doet deze unit ook (via Windows.pas en ZMProfile).

  TMemIniFile werkt zoals in Delphi 5 in het geheugen en schrijft bij UpdateFile het
  hele bestand (zonder commentaar, net als het origineel). Alle schrijfacties gaan
  naar de overlay van ZMData, nooit naar de datamap. }

{$MODE DELPHI}{$H+}

interface

uses SysUtils, Classes;

type
  TCustomIniFile = class(TObject)
  private
    FFileName: string;
  public
    constructor Create(const FileName: string);
    function SectionExists(const Section: string): Boolean;
    function ReadString(const Section, Ident, Default: string): string; virtual; abstract;
    procedure WriteString(const Section, Ident, Value: string); virtual; abstract;
    function ReadInteger(const Section, Ident: string; Default: Longint): Longint; virtual;
    procedure WriteInteger(const Section, Ident: string; Value: Longint); virtual;
    function ReadBool(const Section, Ident: string; Default: Boolean): Boolean; virtual;
    procedure WriteBool(const Section, Ident: string; Value: Boolean); virtual;
    function ReadDate(const Section, Name: string; Default: TDateTime): TDateTime; virtual;
    function ReadDateTime(const Section, Name: string; Default: TDateTime): TDateTime; virtual;
    function ReadFloat(const Section, Name: string; Default: Double): Double; virtual;
    function ReadTime(const Section, Name: string; Default: TDateTime): TDateTime; virtual;
    procedure WriteDate(const Section, Name: string; Value: TDateTime); virtual;
    procedure WriteDateTime(const Section, Name: string; Value: TDateTime); virtual;
    procedure WriteFloat(const Section, Name: string; Value: Double); virtual;
    procedure WriteTime(const Section, Name: string; Value: TDateTime); virtual;
    procedure ReadSection(const Section: string; Strings: TStrings); virtual; abstract;
    procedure ReadSections(Strings: TStrings); virtual; abstract;
    procedure ReadSectionValues(const Section: string; Strings: TStrings); virtual; abstract;
    procedure EraseSection(const Section: string); virtual; abstract;
    procedure DeleteKey(const Section, Ident: string); virtual; abstract;
    procedure UpdateFile; virtual; abstract;
    function ValueExists(const Section, Ident: string): Boolean;
    property FileName: string read FFileName;
  end;

  TIniFile = class(TCustomIniFile)
  public
    destructor Destroy; override;
    function ReadString(const Section, Ident, Default: string): string; override;
    procedure WriteString(const Section, Ident, Value: string); override;
    procedure ReadSection(const Section: string; Strings: TStrings); override;
    procedure ReadSections(Strings: TStrings); override;
    procedure ReadSectionValues(const Section: string; Strings: TStrings); override;
    procedure EraseSection(const Section: string); override;
    procedure DeleteKey(const Section, Ident: string); override;
    procedure UpdateFile; override;
  end;

  TMemIniFile = class(TCustomIniFile)
  private
    FSections: TStringList;   { naam -> TStringList met 'sleutel=waarde' }
    function AddSection(const Section: string): TStrings;
    procedure LoadValues;
  public
    constructor Create(const FileName: string);
    destructor Destroy; override;
    procedure Clear;
    procedure DeleteKey(const Section, Ident: string); override;
    procedure EraseSection(const Section: string); override;
    procedure GetStrings(List: TStrings);
    procedure ReadSection(const Section: string; Strings: TStrings); override;
    procedure ReadSections(Strings: TStrings); override;
    procedure ReadSectionValues(const Section: string; Strings: TStrings); override;
    function ReadString(const Section, Ident, Default: string): string; override;
    procedure Rename(const FileName: string; Reload: Boolean);
    procedure SetStrings(List: TStrings);
    procedure UpdateFile; override;
    procedure WriteString(const Section, Ident, Value: string); override;
  end;

implementation

uses Windows, ZMData;

const
  SIniBestandSchrijffout = 'Kan niet schrijven naar %s';

{ ---------------------------------------------------------------- TCustomIniFile }

constructor TCustomIniFile.Create(const FileName: string);
begin
  inherited Create;
  FFileName := FileName;
end;

function TCustomIniFile.SectionExists(const Section: string): Boolean;
var
  S: TStringList;
begin
  S := TStringList.Create;
  try
    ReadSection(Section, S);
    Result := S.Count > 0;
  finally
    S.Free;
  end;
end;

function TCustomIniFile.ReadInteger(const Section, Ident: string; Default: Longint): Longint;
var
  IntTekst: string;
begin
  IntTekst := ReadString(Section, Ident, '');
  if (Length(IntTekst) > 2) and (IntTekst[1] = '0') and (IntTekst[2] in ['X', 'x']) then
    IntTekst := '$' + Copy(IntTekst, 3, Maxint);
  Result := StrToIntDef(IntTekst, Default);
end;

procedure TCustomIniFile.WriteInteger(const Section, Ident: string; Value: Longint);
begin
  WriteString(Section, Ident, IntToStr(Value));
end;

function TCustomIniFile.ReadBool(const Section, Ident: string; Default: Boolean): Boolean;
begin
  Result := ReadInteger(Section, Ident, Ord(Default)) <> 0;
end;

procedure TCustomIniFile.WriteBool(const Section, Ident: string; Value: Boolean);
const
  Values: array[Boolean] of string = ('0', '1');
begin
  WriteString(Section, Ident, Values[Value]);
end;

function TCustomIniFile.ReadDate(const Section, Name: string; Default: TDateTime): TDateTime;
var
  S: string;
begin
  S := ReadString(Section, Name, '');
  Result := Default;
  if S <> '' then
  try
    Result := StrToDate(S);
  except
    on EConvertError do ;
  end;
end;

function TCustomIniFile.ReadDateTime(const Section, Name: string; Default: TDateTime): TDateTime;
var
  S: string;
begin
  S := ReadString(Section, Name, '');
  Result := Default;
  if S <> '' then
  try
    Result := StrToDateTime(S);
  except
    on EConvertError do ;
  end;
end;

function TCustomIniFile.ReadFloat(const Section, Name: string; Default: Double): Double;
var
  S: string;
begin
  S := ReadString(Section, Name, '');
  Result := Default;
  if S <> '' then
  try
    Result := StrToFloat(S);
  except
    on EConvertError do ;
  end;
end;

function TCustomIniFile.ReadTime(const Section, Name: string; Default: TDateTime): TDateTime;
var
  S: string;
begin
  S := ReadString(Section, Name, '');
  Result := Default;
  if S <> '' then
  try
    Result := StrToTime(S);
  except
    on EConvertError do ;
  end;
end;

procedure TCustomIniFile.WriteDate(const Section, Name: string; Value: TDateTime);
begin
  WriteString(Section, Name, DateToStr(Value));
end;

procedure TCustomIniFile.WriteDateTime(const Section, Name: string; Value: TDateTime);
begin
  WriteString(Section, Name, DateTimeToStr(Value));
end;

procedure TCustomIniFile.WriteFloat(const Section, Name: string; Value: Double);
begin
  WriteString(Section, Name, FloatToStr(Value));
end;

procedure TCustomIniFile.WriteTime(const Section, Name: string; Value: TDateTime);
begin
  WriteString(Section, Name, TimeToStr(Value));
end;

function TCustomIniFile.ValueExists(const Section, Ident: string): Boolean;
var
  S: TStringList;
begin
  S := TStringList.Create;
  try
    ReadSection(Section, S);
    Result := S.IndexOf(Ident) > -1;
  finally
    S.Free;
  end;
end;

{ ---------------------------------------------------------------- TIniFile }

destructor TIniFile.Destroy;
begin
  UpdateFile;
  inherited Destroy;
end;

function TIniFile.ReadString(const Section, Ident, Default: string): string;
var
  Buffer: array[0..2047] of AnsiChar;
begin
  SetString(Result, Buffer, GetPrivateProfileString(PAnsiChar(Section), PAnsiChar(Ident),
    PAnsiChar(Default), Buffer, SizeOf(Buffer), PAnsiChar(FFileName)));
end;

procedure TIniFile.WriteString(const Section, Ident, Value: string);
begin
  if not WritePrivateProfileString(PAnsiChar(Section), PAnsiChar(Ident), PAnsiChar(Value),
    PAnsiChar(FFileName)) then
    raise Exception.CreateFmt(SIniBestandSchrijffout, [FFileName]);
end;

procedure TIniFile.ReadSections(Strings: TStrings);
const
  BufSize = 16384;
var
  Buffer, P: PAnsiChar;
begin
  GetMem(Buffer, BufSize);
  try
    Strings.BeginUpdate;
    try
      Strings.Clear;
      if GetPrivateProfileString(nil, nil, nil, Buffer, BufSize, PAnsiChar(FFileName)) <> 0 then
      begin
        P := Buffer;
        while P^ <> #0 do
        begin
          Strings.Add(P);
          Inc(P, StrLen(P) + 1);
        end;
      end;
    finally
      Strings.EndUpdate;
    end;
  finally
    FreeMem(Buffer, BufSize);
  end;
end;

procedure TIniFile.ReadSection(const Section: string; Strings: TStrings);
var
  Buffer, P: PAnsiChar;
  Tekenaantal: Integer;
  Buffergrootte: Integer;

  procedure LeesTekstgegevens;
  begin
    Strings.BeginUpdate;
    try
      Strings.Clear;
      if Tekenaantal <> 0 then
      begin
        P := Buffer;
        while P^ <> #0 do
        begin
          Strings.Add(P);
          Inc(P, StrLen(P) + 1);
        end;
      end;
    finally
      Strings.EndUpdate;
    end;
  end;

begin
  Buffergrootte := 1024;
  while True do
  begin
    GetMem(Buffer, Buffergrootte);
    try
      Tekenaantal := GetPrivateProfileString(PAnsiChar(Section), nil, nil, Buffer, Buffergrootte,
        PAnsiChar(FFileName));
      if Tekenaantal < Buffergrootte - 2 then
      begin
        LeesTekstgegevens;
        Break;
      end;
    finally
      FreeMem(Buffer, Buffergrootte);
    end;
    Buffergrootte := Buffergrootte * 4;
  end;
end;

procedure TIniFile.ReadSectionValues(const Section: string; Strings: TStrings);
var
  Toetslijst: TStringList;
  I: Integer;
begin
  Toetslijst := TStringList.Create;
  try
    ReadSection(Section, Toetslijst);
    Strings.BeginUpdate;
    try
      Strings.Clear;
      for I := 0 to Toetslijst.Count - 1 do
        Strings.Add(Toetslijst[I] + '=' + ReadString(Section, Toetslijst[I], ''));
    finally
      Strings.EndUpdate;
    end;
  finally
    Toetslijst.Free;
  end;
end;

procedure TIniFile.EraseSection(const Section: string);
begin
  if not WritePrivateProfileString(PAnsiChar(Section), nil, nil, PAnsiChar(FFileName)) then
    raise Exception.CreateFmt(SIniBestandSchrijffout, [FFileName]);
end;

procedure TIniFile.DeleteKey(const Section, Ident: string);
begin
  WritePrivateProfileString(PAnsiChar(Section), PAnsiChar(Ident), nil, PAnsiChar(FFileName));
end;

procedure TIniFile.UpdateFile;
begin
  WritePrivateProfileString(nil, nil, nil, PAnsiChar(FFileName));
end;

{ ---------------------------------------------------------------- TMemIniFile }

constructor TMemIniFile.Create(const FileName: string);
begin
  inherited Create(FileName);
  FSections := TStringList.Create;
  LoadValues;
end;

destructor TMemIniFile.Destroy;
begin
  if FSections <> nil then Clear;
  FSections.Free;
  inherited Destroy;
end;

function TMemIniFile.AddSection(const Section: string): TStrings;
begin
  Result := TStringList.Create;
  try
    FSections.AddObject(Section, Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TMemIniFile.Clear;
var
  I: Integer;
begin
  for I := 0 to FSections.Count - 1 do
    TObject(FSections.Objects[I]).Free;
  FSections.Clear;
end;

procedure TMemIniFile.DeleteKey(const Section, Ident: string);
var
  I, J: Integer;
  Teksten: TStrings;
begin
  I := FSections.IndexOf(Section);
  if I >= 0 then
  begin
    Teksten := TStrings(FSections.Objects[I]);
    J := Teksten.IndexOfName(Ident);
    if J >= 0 then Teksten.Delete(J);
  end;
end;

procedure TMemIniFile.EraseSection(const Section: string);
var
  I: Integer;
begin
  I := FSections.IndexOf(Section);
  if I >= 0 then
  begin
    TStrings(FSections.Objects[I]).Free;
    FSections.Delete(I);
  end;
end;

procedure TMemIniFile.GetStrings(List: TStrings);
var
  I, J: Integer;
  Teksten: TStrings;
begin
  List.BeginUpdate;
  try
    for I := 0 to FSections.Count - 1 do
    begin
      List.Add('[' + FSections[I] + ']');
      Teksten := TStrings(FSections.Objects[I]);
      for J := 0 to Teksten.Count - 1 do List.Add(Teksten[J]);
      List.Add('');
    end;
  finally
    List.EndUpdate;
  end;
end;

procedure TMemIniFile.LoadValues;
var
  Lijst: TStringList;
  Pad: string;
begin
  Pad := ZMOplosPad(FileName);
  if (FileName <> '') and FileExists(Pad) then
  begin
    Lijst := TStringList.Create;
    try
      Lijst.LoadFromFile(Pad);
      SetStrings(Lijst);
    finally
      Lijst.Free;
    end;
  end
  else
    Clear;
end;

procedure TMemIniFile.ReadSection(const Section: string; Strings: TStrings);
var
  I, J: Integer;
  Sectieteksten: TStrings;
begin
  Strings.BeginUpdate;
  try
    Strings.Clear;
    I := FSections.IndexOf(Section);
    if I >= 0 then
    begin
      Sectieteksten := TStrings(FSections.Objects[I]);
      for J := 0 to Sectieteksten.Count - 1 do
        Strings.Add(Sectieteksten.Names[J]);
    end;
  finally
    Strings.EndUpdate;
  end;
end;

procedure TMemIniFile.ReadSections(Strings: TStrings);
begin
  Strings.Assign(FSections);
end;

procedure TMemIniFile.ReadSectionValues(const Section: string; Strings: TStrings);
var
  I: Integer;
begin
  Strings.BeginUpdate;
  try
    Strings.Clear;
    I := FSections.IndexOf(Section);
    if I >= 0 then Strings.Assign(TStrings(FSections.Objects[I]));
  finally
    Strings.EndUpdate;
  end;
end;

function TMemIniFile.ReadString(const Section, Ident, Default: string): string;
var
  I: Integer;
  Teksten: TStrings;
begin
  I := FSections.IndexOf(Section);
  if I >= 0 then
  begin
    Teksten := TStrings(FSections.Objects[I]);
    I := Teksten.IndexOfName(Ident);
    if I >= 0 then
    begin
      Result := Copy(Teksten[I], Length(Ident) + 2, Maxint);
      Exit;
    end;
  end;
  Result := Default;
end;

procedure TMemIniFile.Rename(const FileName: string; Reload: Boolean);
begin
  FFileName := FileName;
  if Reload then LoadValues;
end;

procedure TMemIniFile.SetStrings(List: TStrings);
var
  I: Integer;
  S: string;
  Teksten: TStrings;
begin
  Clear;
  Teksten := nil;
  for I := 0 to List.Count - 1 do
  begin
    S := Trim(List[I]);
    if (S <> '') and (S[1] <> ';') then
      if (S[1] = '[') and (S[Length(S)] = ']') then
        Teksten := AddSection(Trim(Copy(S, 2, Length(S) - 2)))
      else if Teksten <> nil then
        Teksten.Add(S);
  end;
end;

procedure TMemIniFile.UpdateFile;
var
  Lijst: TStringList;
begin
  Lijst := TStringList.Create;
  try
    GetStrings(Lijst);
    Lijst.SaveToFile(ZMSchrijfPad(ZMOplosPad(FileName)));
  finally
    Lijst.Free;
  end;
end;

procedure TMemIniFile.WriteString(const Section, Ident, Value: string);
var
  I: Integer;
  S: string;
  Teksten: TStrings;
begin
  I := FSections.IndexOf(Section);
  if I >= 0 then
    Teksten := TStrings(FSections.Objects[I])
  else
    Teksten := AddSection(Section);
  S := Ident + '=' + Value;
  I := Teksten.IndexOfName(Ident);
  if I >= 0 then Teksten[I] := S else Teksten.Add(S);
end;

end.

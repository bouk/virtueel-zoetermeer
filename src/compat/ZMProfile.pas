unit ZMProfile;

{ INI-bestanden zoals Windows ze leest en schrijft (GetPrivateProfileString en
  WritePrivateProfileString), gebruikt door Windows.pas en door IniFiles.pas.

  Lezen: sectie- en sleutelnamen zonder onderscheid tussen hoofd- en kleine letters,
  witruimte rond namen en waarden telt niet mee, een waarde tussen enkele of dubbele
  aanhalingstekens verliest die tekens, regels die met ';' beginnen zijn commentaar.
  Een sleutel zonder '=' heeft geen waarde (dan geldt de standaardwaarde, zoals in Wine).

  Schrijven gebeurt ter plekke: alleen de betreffende regel wordt vervangen, ingevoegd
  (na de laatste sleutel van de sectie) of verwijderd. Commentaar, lege regels,
  volgorde en regeleinden (CRLF of LF) van de rest van het bestand blijven precies
  zoals ze waren. Een nieuwe sectie komt achteraan het bestand. Er wordt geschreven
  naar ZMWritePath (de overlay van ZMData), nooit in de datamap. }

{$MODE DELPHI}{$H+}

interface

function ZMGetPrivateProfileString(lpAppName, lpKeyName, lpDefault: PAnsiChar;
  lpReturnedString: PAnsiChar; nSize: LongWord; lpFileName: PAnsiChar): LongWord;
function ZMWritePrivateProfileString(lpAppName, lpKeyName, lpString,
  lpFileName: PAnsiChar): Boolean;
function ZMGetPrivateProfileInt(lpAppName, lpKeyName: PAnsiChar; nDefault: Integer;
  lpFileName: PAnsiChar): LongWord;

implementation

uses SysUtils, Classes, ZMData;

type
  { Een ingelezen INI-bestand: de regels zonder regeleinde. }
  TProfileFile = class
    Path: string;          { opgelost pad waar gelezen is }
    Lines: TStringList;
    EOL: string;           { #13#10 of #10, zoals in het bestand }
    FinalEOL: Boolean;     { eindigde het bestand op een regeleinde }
    Stamp: LongInt;        { FileAge bij het inlezen }
    Size: Int64;
    constructor Create;
    destructor Destroy; override;
  end;

var
  Cache: TStringList = nil;   { pad -> TProfileFile }

constructor TProfileFile.Create;
begin
  Lines := TStringList.Create;
  EOL := #13#10;
  FinalEOL := True;
end;

destructor TProfileFile.Destroy;
begin
  Lines.Free;
  inherited Destroy;
end;

function FileSizeOf(const Path: string): Int64;
var
  SR: TSearchRec;
begin
  Result := -1;
  if FindFirst(Path, faAnyFile, SR) = 0 then
  begin
    Result := SR.Size;
    FindClose(SR);
  end;
end;

function ResolveName(lpFileName: PAnsiChar): string;
begin
  Result := ZMResolvePath(StrPas(lpFileName));
end;

procedure SplitLines(const Data: string; F: TProfileFile);
var
  I, Start: Integer;
  L: string;
begin
  F.Lines.Clear;
  F.EOL := #13#10;
  F.FinalEOL := True;
  if Data = '' then Exit;
  if (Pos(#10, Data) > 0) and (Pos(#13#10, Data) = 0) then F.EOL := #10;
  Start := 1;
  for I := 1 to Length(Data) do
    if Data[I] = #10 then
    begin
      L := Copy(Data, Start, I - Start);
      if (L <> '') and (L[Length(L)] = #13) then SetLength(L, Length(L) - 1);
      F.Lines.Add(L);
      Start := I + 1;
    end;
  F.FinalEOL := Start > Length(Data);
  if not F.FinalEOL then
  begin
    L := Copy(Data, Start, MaxInt);
    if (L <> '') and (L[Length(L)] = #13) then SetLength(L, Length(L) - 1);
    F.Lines.Add(L);
  end;
end;

function ReadWhole(const Path: string; out Data: string): Boolean;
var
  S: TFileStream;
begin
  Data := '';
  Result := False;
  if not FileExists(Path) then Exit;
  try
    S := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Data, S.Size);
      if S.Size > 0 then S.ReadBuffer(Data[1], S.Size);
      Result := True;
    finally
      S.Free;
    end;
  except
    Data := '';
    Result := False;
  end;
end;

{ Het bestand uit de cache, of opnieuw ingelezen als het op schijf veranderd is.
  Een ontbrekend bestand geeft een leeg TProfileFile (Exists = False). }
function Load(const Path: string; out Exists: Boolean): TProfileFile;
var
  I: Integer;
  Age: LongInt;
  Size: Int64;
  Data: string;
begin
  if Cache = nil then
  begin
    Cache := TStringList.Create;
    Cache.Sorted := True;
    Cache.OwnsObjects := True;
  end;
  Exists := FileExists(Path);
  Age := FileAge(Path);
  Size := FileSizeOf(Path);
  I := Cache.IndexOf(Path);
  if I >= 0 then
  begin
    Result := TProfileFile(Cache.Objects[I]);
    if Exists and (Result.Stamp = Age) and (Result.Size = Size) then Exit;
    Cache.Delete(I);
  end;
  Result := TProfileFile.Create;
  Result.Path := Path;
  Result.Stamp := Age;
  Result.Size := Size;
  if Exists and ReadWhole(Path, Data) then SplitLines(Data, Result);
  Cache.AddObject(Path, Result);
end;

procedure Forget(const Path: string);
var
  I: Integer;
begin
  if Cache = nil then Exit;
  I := Cache.IndexOf(Path);
  if I >= 0 then Cache.Delete(I);
end;

{ ---------------------------------------------------------------- regels ontleden }

const
  Blanks = [' ', #9];

function TrimBlanks(const S: string): string;
var
  A, B: Integer;
begin
  A := 1;
  B := Length(S);
  while (A <= B) and (S[A] in Blanks) do Inc(A);
  while (B >= A) and (S[B] in Blanks) do Dec(B);
  Result := Copy(S, A, B - A + 1);
end;

{ True als de regel een sectiekop is; Name krijgt de naam tussen de haken. }
function IsSection(const Line: string; out Name: string): Boolean;
var
  S: string;
  P: Integer;
begin
  S := TrimBlanks(Line);
  Result := (S <> '') and (S[1] = '[');
  if not Result then Exit;
  P := Pos(']', S);
  if P = 0 then P := Length(S) + 1;
  Name := TrimBlanks(Copy(S, 2, P - 2));
end;

{ True als de regel een sleutel is (geen sectie, commentaar of lege regel). }
function IsKey(const Line: string; out Name, Value: string; out HasValue: Boolean): Boolean;
var
  S: string;
  P: Integer;
begin
  S := TrimBlanks(Line);
  Result := (S <> '') and (S[1] <> '[') and (S[1] <> ';');
  if not Result then Exit;
  P := Pos('=', S);
  HasValue := P > 0;
  if HasValue then
  begin
    Name := TrimBlanks(Copy(S, 1, P - 1));
    Value := TrimBlanks(Copy(S, P + 1, MaxInt));
  end
  else
  begin
    Name := S;
    Value := '';
  end;
end;

function Unquote(const S: string): string;
begin
  if (Length(S) >= 2) and (S[1] in ['"', '''']) and (S[Length(S)] = S[1]) then
    Result := Copy(S, 2, Length(S) - 2)
  else
    Result := S;
end;

{ Index van de eerste sectiekop met deze naam vanaf regel From, of -1. }
function FindSection(F: TProfileFile; const Section: string; From: Integer): Integer;
var
  I: Integer;
  N: string;
begin
  for I := From to F.Lines.Count - 1 do
    if IsSection(F.Lines[I], N) and SameText(N, Section) then Exit(I);
  Result := -1;
end;

{ Eerste regel na de sectie die op regel Head begint (de volgende kop of het einde). }
function SectionEnd(F: TProfileFile; Head: Integer): Integer;
var
  N: string;
begin
  Result := Head + 1;
  while (Result < F.Lines.Count) and not IsSection(F.Lines[Result], N) do Inc(Result);
end;

{ Regelnummer van de sleutel in (een van de secties met naam) Section, of -1. }
function FindKey(F: TProfileFile; const Section, Key: string): Integer;
var
  H, I: Integer;
  N, V: string;
  HV: Boolean;
begin
  H := FindSection(F, Section, 0);
  while H >= 0 do
  begin
    I := H + 1;
    while (I < F.Lines.Count) and not IsSection(F.Lines[I], N) do
    begin
      if IsKey(F.Lines[I], N, V, HV) and SameText(N, Key) then Exit(I);
      Inc(I);
    end;
    H := FindSection(F, Section, I);
  end;
  Result := -1;
end;

{ ---------------------------------------------------------------- lezen }

{ Kopieert een lijst van namen (elk afgesloten met #0, plus een extra #0) naar de
  buffer, met de afkapregels van Windows: past de lijst niet, dan eindigt de buffer op
  twee nullen en is het resultaat nSize - 2. }
function CopyList(Names: TStringList; Buf: PAnsiChar; nSize: LongWord): LongWord;
var
  I, J: Integer;
  P: LongWord;
  S: string;
begin
  P := 0;
  Result := 0;
  if nSize < 2 then
  begin
    if nSize = 1 then Buf[0] := #0;
    Exit;
  end;
  for I := 0 to Names.Count - 1 do
  begin
    S := Names[I];
    for J := 1 to Length(S) + 1 do
    begin
      if P >= nSize - 2 then
      begin
        Buf[nSize - 2] := #0;
        Buf[nSize - 1] := #0;
        Exit(nSize - 2);
      end;
      if J <= Length(S) then Buf[P] := S[J] else Buf[P] := #0;
      Inc(P);
    end;
  end;
  Buf[P] := #0;
  if P = 0 then Buf[1] := #0;
  Result := P;
end;

function CopyValue(const S: string; Buf: PAnsiChar; nSize: LongWord): LongWord;
begin
  Result := 0;
  if nSize = 0 then Exit;
  if LongWord(Length(S)) >= nSize then
  begin
    Move(PAnsiChar(S)^, Buf^, nSize - 1);
    Buf[nSize - 1] := #0;
    Exit(nSize - 1);
  end;
  if S <> '' then Move(PAnsiChar(S)^, Buf^, Length(S));
  Buf[Length(S)] := #0;
  Result := Length(S);
end;

function ZMGetPrivateProfileString(lpAppName, lpKeyName, lpDefault: PAnsiChar;
  lpReturnedString: PAnsiChar; nSize: LongWord; lpFileName: PAnsiChar): LongWord;
var
  F: TProfileFile;
  Exists, HV: Boolean;
  Names: TStringList;
  I, H: Integer;
  N, V, Def: string;
begin
  Result := 0;
  if (lpReturnedString = nil) or (nSize = 0) then Exit;
  { Windows haalt spaties achteraan de standaardwaarde weg }
  if lpDefault <> nil then Def := StrPas(lpDefault) else Def := '';
  while (Def <> '') and (Def[Length(Def)] = ' ') do SetLength(Def, Length(Def) - 1);
  if lpFileName = nil then Exit(CopyValue(Def, lpReturnedString, nSize));
  F := Load(ResolveName(lpFileName), Exists);
  if lpAppName = nil then
  begin
    { alle sectienamen }
    Names := TStringList.Create;
    try
      for I := 0 to F.Lines.Count - 1 do
        if IsSection(F.Lines[I], N) then Names.Add(N);
      Result := CopyList(Names, lpReturnedString, nSize);
    finally
      Names.Free;
    end;
    Exit;
  end;
  if lpKeyName = nil then
  begin
    { alle sleutels van de sectie }
    Names := TStringList.Create;
    try
      H := FindSection(F, StrPas(lpAppName), 0);
      while H >= 0 do
      begin
        I := H + 1;
        while (I < F.Lines.Count) and not IsSection(F.Lines[I], N) do
        begin
          if IsKey(F.Lines[I], N, V, HV) then Names.Add(N);
          Inc(I);
        end;
        H := FindSection(F, StrPas(lpAppName), I);
      end;
      Result := CopyList(Names, lpReturnedString, nSize);
    finally
      Names.Free;
    end;
    Exit;
  end;
  I := FindKey(F, StrPas(lpAppName), StrPas(lpKeyName));
  if (I >= 0) and IsKey(F.Lines[I], N, V, HV) and HV then
    Result := CopyValue(Unquote(V), lpReturnedString, nSize)
  else
    Result := CopyValue(Def, lpReturnedString, nSize);
end;

function ZMGetPrivateProfileInt(lpAppName, lpKeyName: PAnsiChar; nDefault: Integer;
  lpFileName: PAnsiChar): LongWord;
var
  Buf: array[0..255] of AnsiChar;
  S: string;
  I, V: Integer;
  Neg: Boolean;
begin
  { zoals Windows: de cijfers aan het begin tellen, de rest wordt genegeerd }
  ZMGetPrivateProfileString(lpAppName, lpKeyName, '', Buf, SizeOf(Buf), lpFileName);
  S := TrimBlanks(StrPas(Buf));
  if S = '' then Exit(LongWord(nDefault));
  I := 1;
  Neg := False;
  if S[1] in ['-', '+'] then
  begin
    Neg := S[1] = '-';
    Inc(I);
  end;
  V := 0;
  while (I <= Length(S)) and (S[I] in ['0'..'9']) do
  begin
    V := V * 10 + Ord(S[I]) - Ord('0');
    Inc(I);
  end;
  if Neg then V := -V;
  Result := LongWord(V);
end;

{ ---------------------------------------------------------------- schrijven }

function Save(F: TProfileFile; const ReadPath: string): Boolean;
var
  Target, Data: string;
  I: Integer;
  S: TFileStream;
begin
  Result := False;
  Data := '';
  for I := 0 to F.Lines.Count - 1 do
  begin
    Data := Data + F.Lines[I];
    if (I < F.Lines.Count - 1) or F.FinalEOL then Data := Data + F.EOL;
  end;
  Target := ZMWritePath(ReadPath);
  try
    S := TFileStream.Create(Target, fmCreate);
    try
      if Data <> '' then S.WriteBuffer(Data[1], Length(Data));
    finally
      S.Free;
    end;
    Result := True;
  except
    Result := False;
  end;
  Forget(ReadPath);
  Forget(Target);
end;

function ZMWritePrivateProfileString(lpAppName, lpKeyName, lpString,
  lpFileName: PAnsiChar): Boolean;
var
  F: TProfileFile;
  Path, Section, N, V, W: string;
  Exists, HV: Boolean;
  H, E, I, Last: Integer;
  Changed: Boolean;
begin
  { (nil, nil, nil): de cache legen; er is niets uit te stellen }
  if (lpAppName = nil) and (lpKeyName = nil) and (lpString = nil) then
  begin
    if Cache <> nil then Cache.Clear;
    Exit(True);
  end;
  Result := False;
  if (lpAppName = nil) or (lpFileName = nil) then Exit;
  Path := ResolveName(lpFileName);
  F := Load(Path, Exists);
  Section := StrPas(lpAppName);
  Changed := False;
  if lpKeyName = nil then
  begin
    { hele sectie verwijderen (kop en alle regels tot de volgende kop) }
    H := FindSection(F, Section, 0);
    while H >= 0 do
    begin
      E := SectionEnd(F, H);
      for I := E - 1 downto H do F.Lines.Delete(I);
      Changed := True;
      H := FindSection(F, Section, H);
    end;
  end
  else if lpString = nil then
  begin
    { sleutel verwijderen }
    I := FindKey(F, Section, StrPas(lpKeyName));
    if I >= 0 then
    begin
      F.Lines.Delete(I);
      Changed := True;
    end;
  end
  else
  begin
    I := FindKey(F, Section, StrPas(lpKeyName));
    if I >= 0 then
    begin
      { bestaande regel: alles tot en met het '=' (en de witruimte erna) blijft
        staan, alleen de waarde wordt vervangen }
      N := F.Lines[I];
      H := Pos('=', N);
      if H > 0 then
      begin
        while (H < Length(N)) and (N[H + 1] in Blanks) do Inc(H);
        V := Copy(N, 1, H) + StrPas(lpString);
      end
      else
        V := TrimBlanks(N) + '=' + StrPas(lpString);
      if V <> F.Lines[I] then
      begin
        F.Lines[I] := V;
        Changed := True;
      end;
    end
    else
    begin
      V := StrPas(lpKeyName) + '=' + StrPas(lpString);
      H := FindSection(F, Section, 0);
      if H >= 0 then
      begin
        { na de laatste sleutel (of de kop) van de sectie invoegen, voor de lege
          regels en het commentaar waarmee de volgende sectie begint }
        E := SectionEnd(F, H);
        Last := H;
        for I := H + 1 to E - 1 do
          if IsKey(F.Lines[I], N, W, HV) then Last := I;
        F.Lines.Insert(Last + 1, V);
      end
      else
      begin
        F.Lines.Add('[' + Section + ']');
        F.Lines.Add(V);
      end;
      Changed := True;
    end;
  end;
  if not Changed then Exit(True);
  if not Exists then F.FinalEOL := True;
  Result := Save(F, Path);
end;

finalization
  Cache.Free;
end.

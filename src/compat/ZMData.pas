unit ZMData;

{ Where the original game files are, and access to them.

  The user's own copy of the game supplies ROS.exe (form resources) and the data
  files. The data directory is found, in this order, from:
    1. the command-line option  --data=<dir>  (or  --data <dir>)
    2. the environment variable ZM_DATA
    3. the current directory, then the directory of the executable
  A directory qualifies when it contains ROS.exe or an images/ folder (any case).
  ROS.exe itself may be overridden with ZM_EXE / --exe=<file> (the data files of
  v1.1 and the exe can live in different directories).

  Paths written the Windows way (backslashes, any letter case) are resolved
  against the real file system by ZMResolvePath. }

{$MODE DELPHI}{$H+}

interface

uses Windows;

function ZMDataDir: string;          { with trailing path delimiter }
function ZMExeFile: string;          { full path of the original ROS.exe ('' if not found) }
function ZMExeName: string;          { what ParamStr(0)/Application.ExeName report (see ZMShadowDir) }
{ The "shadow" directory makes the game's Windows-style paths work through the
  plain RTL (TIniFile, AssignFile, FindFirst, TStrings.LoadFromFile). The game builds
  paths as ExtractFilePath(ParamStr(0)) + '\' + 'images\8bits\x.bmp'. ParamStr(0)
  reports <shadow>/ROS.exe, so such a path is '<shadow>/\images\8bits\x.bmp': one
  file name (backslashes are ordinary characters on Unix) in the shadow directory.
  The shadow directory holds symlinks with exactly those names (in several letter
  cases) to the user's data files, and directories named '\images\8bits\' for
  FindFirst. It lives in $XDG_CACHE_HOME/zoetermeer (override: ZM_SHADOW). }
function ZMShadowDir: string;
function ZMResolvePath(const Path: string): string;
function ZMFileExists(const Path: string): Boolean;

{ PE resources of the original ROS.exe }
function ZMFindExeResource(Name, ResType: PAnsiChar): HRSRC;
function ZMExeResourceData(Res: HRSRC): Pointer;
function ZMExeResourceSize(Res: HRSRC): DWORD;
function ZMLoadExeResource(const Name: string; ResType: PtrUInt; out Data: Pointer; out Size: Integer): Boolean;

implementation

uses SysUtils, Classes{$IFDEF UNIX}, BaseUnix{$ENDIF};

var
  GDataDir: string = '';
  GExeFile: string = '';
  Located: Boolean = False;
  ExeImage: array of Byte;
  ExeLoaded: Boolean = False;

function OptionValue(const Name: string): string;
var
  I: Integer;
  S: string;
begin
  Result := '';
  for I := 1 to System.ParamCount do
  begin
    S := System.ParamStr(I);
    if Copy(S, 1, Length(Name) + 3) = '--' + Name + '=' then
      Exit(Copy(S, Length(Name) + 4, MaxInt));
    if (S = '--' + Name) and (I < System.ParamCount) then
      Exit(System.ParamStr(I + 1));
  end;
end;

{ case-insensitive lookup of one directory entry }
function FindEntry(const Dir, Name: string): string;
var
  SR: TSearchRec;
begin
  Result := '';
  if (Name = '') or (Name = '.') or (Name = '..') then Exit(Name);
  if FileExists(IncludeTrailingPathDelimiter(Dir) + Name) or
    DirectoryExists(IncludeTrailingPathDelimiter(Dir) + Name) then
    Exit(Name);
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if SameText(SR.Name, Name) then
      begin
        Result := SR.Name;
        Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function ZMResolvePath(const Path: string): string;
var
  P, Part, Cur, Found: string;
  I, Start: Integer;
  Abs: Boolean;
begin
  if FileExists(Path) or DirectoryExists(Path) then Exit(Path);
  P := Path;
  for I := 1 to Length(P) do
    if P[I] = '\' then P[I] := '/';
  { drive letters (C:/...) are mapped onto the data directory }
  if (Length(P) >= 2) and (P[2] = ':') then
    P := ZMDataDir + Copy(P, 4, MaxInt);
  if FileExists(P) or DirectoryExists(P) then Exit(P);
  Abs := (P <> '') and (P[1] = '/');
  if Abs then Cur := '/' else Cur := '.';
  Result := '';
  if Abs then Result := '/';
  I := 1;
  while I <= Length(P) do
  begin
    while (I <= Length(P)) and (P[I] = '/') do Inc(I);
    Start := I;
    while (I <= Length(P)) and (P[I] <> '/') do Inc(I);
    Part := Copy(P, Start, I - Start);
    if Part = '' then Break;
    Found := FindEntry(Cur, Part);
    if Found = '' then Found := Part;  { does not exist (yet): keep the spelling }
    if (Result <> '') and (Result[Length(Result)] <> '/') then Result := Result + '/';
    Result := Result + Found;
    if Cur = '/' then Cur := '/' + Found
    else Cur := Cur + '/' + Found;
  end;
  if (P <> '') and (P[Length(P)] = '/') and (Result <> '') and (Result[Length(Result)] <> '/') then
    Result := Result + '/';
  if Result = '' then Result := P;
end;

function ZMFileExists(const Path: string): Boolean;
begin
  Result := FileExists(ZMResolvePath(Path));
end;

function DirHasGame(const D: string): Boolean;
begin
  Result := (D <> '') and DirectoryExists(D) and
    ((FindEntry(D, 'ROS.exe') <> '') or (FindEntry(D, 'images') <> ''));
end;

procedure Locate;
var
  Cands: array[0..3] of string;
  I: Integer;
  D, E: string;
begin
  if Located then Exit;
  Located := True;
  Cands[0] := OptionValue('data');
  Cands[1] := GetEnvironmentVariable('ZM_DATA');
  Cands[2] := GetCurrentDir;
  Cands[3] := ExtractFilePath(ExpandFileName(System.ParamStr(0)));
  GDataDir := '';
  for I := 0 to High(Cands) do
    if DirHasGame(Cands[I]) then
    begin
      GDataDir := IncludeTrailingPathDelimiter(ExpandFileName(Cands[I]));
      Break;
    end;
  if GDataDir = '' then
    GDataDir := IncludeTrailingPathDelimiter(GetCurrentDir);
  E := OptionValue('exe');
  if E = '' then E := GetEnvironmentVariable('ZM_EXE');
  if (E <> '') and FileExists(E) then
    GExeFile := ExpandFileName(E)
  else
  begin
    D := FindEntry(GDataDir, 'ROS.exe');
    if D <> '' then GExeFile := GDataDir + D;
  end;
end;

function ZMDataDir: string;
begin
  Locate;
  Result := GDataDir;
end;

function ZMExeFile: string;
begin
  Locate;
  Result := GExeFile;
end;

var
  GShadow: string = '';

{$IFDEF UNIX}
{ Directory listing with literal names (FindFirst would treat '\' as a separator). }
function ListDir(const Dir: string; out Names: TStringList; out IsDir: TList): Boolean;
var
  D: PDir;
  E: PDirent;
  N: string;
  Info: Stat;
begin
  Names := TStringList.Create;
  IsDir := TList.Create;
  D := FpOpenDir(PChar(Dir));
  Result := D <> nil;
  if D = nil then Exit;
  repeat
    E := FpReadDir(D^);
    if E = nil then Break;
    N := StrPas(PChar(@E^.d_name[0]));
    if (N = '.') or (N = '..') then Continue;
    Names.Add(N);
    if (FpLStat(PChar(Dir + '/' + N), Info) = 0) and fpS_ISDIR(Info.st_mode) then
      IsDir.Add(Pointer(1))
    else
      IsDir.Add(nil);
  until False;
  FpCloseDir(D^);
end;

{ remove the symlinks of a previous run (files the game wrote stay) }
procedure ClearLinks(const Dir: string);
var
  Names: TStringList;
  IsDir: TList;
  I: Integer;
  P: string;
  Info: Stat;
begin
  ListDir(Dir, Names, IsDir);
  try
    for I := 0 to Names.Count - 1 do
    begin
      P := Dir + '/' + Names[I];
      if (FpLStat(PChar(P), Info) = 0) and fpS_ISLNK(Info.st_mode) then
        FpUnlink(PChar(P))
      else if IsDir[I] <> nil then
        ClearLinks(P);
    end;
  finally
    Names.Free;
    IsDir.Free;
  end;
end;

function Exists(const P: string): Boolean;
var
  Info: Stat;
begin
  Result := FpLStat(PChar(P), Info) = 0;
end;

procedure LinkVariants(const Target, LinkDir, Prefix, Name: string);
var
  Variants: array[0..3] of string;
  I: Integer;
  L: string;
begin
  Variants[0] := Name;
  Variants[1] := LowerCase(Name);
  Variants[2] := ChangeFileExt(Name, LowerCase(ExtractFileExt(Name)));
  Variants[3] := UpperCase(Name);
  for I := 0 to High(Variants) do
  begin
    L := LinkDir + '/' + Prefix + Variants[I];
    if not Exists(L) then FpSymlink(PChar(Target), PChar(L));
  end;
end;

procedure ShadowTree(const SrcDir, Rel: string);
var
  Names: TStringList;
  IsDir: TList;
  I: Integer;
  Sub, Root: string;
begin
  { Rel is the Windows-style relative path of SrcDir, e.g. '\images\8bits\'.
    Root files get links in several letter cases ('\ZoetermeerGame.ini' for
    ZoetermeerGame.Ini); files in subdirectories get exactly one link each with
    the on-disk name, because FindFirst('<shadow>/\images\8bits\*.bmp') lists
    the shadow root and must return every file once. Plain (non-backslash) links
    to the root entries are made too. }
  Root := ExcludeTrailingPathDelimiter(GShadow);
  ListDir(SrcDir, Names, IsDir);
  try
    for I := 0 to Names.Count - 1 do
    begin
      Sub := SrcDir + '/' + Names[I];
      if IsDir[I] <> nil then
      begin
        if Rel = '\' then LinkVariants(Sub, Root, '', Names[I]);
        ShadowTree(Sub, Rel + Names[I] + '\');
      end
      else if Rel = '\' then
      begin
        LinkVariants(Sub, Root, Rel, Names[I]);
        LinkVariants(Sub, Root, '', Names[I]);
      end
      else if not Exists(Root + '/' + Rel + Names[I]) then
        FpSymlink(PChar(Sub), PChar(Root + '/' + Rel + Names[I]));
    end;
  finally
    Names.Free;
    IsDir.Free;
  end;
end;
{$ENDIF}

function ZMShadowDir: string;
var
  Base: string;
  H: LongWord;
  I: Integer;
  D: string;
begin
  if GShadow <> '' then Exit(GShadow);
  D := ExcludeTrailingPathDelimiter(ZMDataDir);
  Base := GetEnvironmentVariable('ZM_SHADOW');
  if Base = '' then
  begin
    Base := GetEnvironmentVariable('XDG_CACHE_HOME');
    if Base = '' then Base := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.cache';
    H := 5381;
    for I := 1 to Length(D) do H := H * 33 + Ord(D[I]);
    Base := IncludeTrailingPathDelimiter(Base) + 'zoetermeer' + PathDelim + 'root-' + IntToHex(H, 8);
  end;
  ForceDirectories(Base);
  GShadow := IncludeTrailingPathDelimiter(Base);
{$IFDEF UNIX}
  ClearLinks(Base);
  ShadowTree(D, '\');
  if ZMExeFile <> '' then
    LinkVariants(ZMExeFile, Base, '', 'ROS.exe');
{$ENDIF}
  Result := GShadow;
end;

function ZMExeName: string;
begin
{$IFDEF UNIX}
  Result := ZMShadowDir + 'ROS.exe';
{$ELSE}
  Locate;
  Result := GDataDir + 'ROS.exe';
{$ENDIF}
end;

{ ---------------------------------------------------------------- PE resources }

type
  TResEntry = record
    Offset, Size: LongWord;  { file offset and size of the data }
  end;

var
  ResEntries: array of TResEntry;

procedure LoadExe;
var
  F: TFileStream;
begin
  if ExeLoaded then Exit;
  ExeLoaded := True;
  if ZMExeFile = '' then Exit;
  try
    F := TFileStream.Create(ZMExeFile, fmOpenRead or fmShareDenyNone);
    try
      SetLength(ExeImage, F.Size);
      if F.Size > 0 then F.ReadBuffer(ExeImage[0], F.Size);
    finally
      F.Free;
    end;
  except
    SetLength(ExeImage, 0);
  end;
end;

function RdW(Ofs: LongWord): Word;
begin
  if Ofs + 2 > LongWord(Length(ExeImage)) then Exit(0);
  Result := ExeImage[Ofs] or (ExeImage[Ofs + 1] shl 8);
end;

function RdD(Ofs: LongWord): LongWord;
begin
  if Ofs + 4 > LongWord(Length(ExeImage)) then Exit(0);
  Result := ExeImage[Ofs] or (LongWord(ExeImage[Ofs + 1]) shl 8) or
    (LongWord(ExeImage[Ofs + 2]) shl 16) or (LongWord(ExeImage[Ofs + 3]) shl 24);
end;

function Max(A, B: LongWord): LongWord;
begin
  if A > B then Result := A else Result := B;
end;

{ Find a resource: returns its file offset/size via the out params. }
function FindRes(const Name: string; NameId: PtrUInt; TypeName: string; TypeId: PtrUInt;
  out Offset, Size: LongWord): Boolean;
var
  PE, SecTab, NSec, I, RsrcRVA, RsrcRaw, RsrcVSize: LongWord;
  OptSize: Word;

  function RvaToOfs(RVA: LongWord): LongWord;
  begin
    Result := RVA - RsrcRVA + RsrcRaw;
  end;

  function DirName(Ofs: LongWord): string;
  var
    L, K: Integer;
  begin
    Result := '';
    L := RdW(RsrcRaw + Ofs);
    for K := 0 to L - 1 do
      Result := Result + Chr(RdW(RsrcRaw + Ofs + 2 + LongWord(K) * 2) and $FF);
  end;

  { search a directory for a name or id; returns the entry's OffsetToData }
  function Lookup(DirOfs: LongWord; const AName: string; AId: PtrUInt; out Child: LongWord): Boolean;
  var
    NNamed, NId, K, E: LongWord;
    NameField, DataField: LongWord;
  begin
    Result := False;
    NNamed := RdW(RsrcRaw + DirOfs + 12);
    NId := RdW(RsrcRaw + DirOfs + 14);
    for K := 0 to NNamed + NId - 1 do
    begin
      E := RsrcRaw + DirOfs + 16 + K * 8;
      NameField := RdD(E);
      DataField := RdD(E + 4);
      if NameField and $80000000 <> 0 then
      begin
        if (AName <> '') and SameText(DirName(NameField and $7FFFFFFF), AName) then
        begin
          Child := DataField;
          Exit(True);
        end;
      end
      else if (AName = '') and ((AId = 0) or (NameField = AId)) then
      begin
        Child := DataField;
        Exit(True);
      end;
    end;
  end;

var
  C1, C2, C3, DataEntry: LongWord;
begin
  Result := False;
  Offset := 0;
  Size := 0;
  LoadExe;
  if Length(ExeImage) < $100 then Exit;
  if RdW(0) <> $5A4D then Exit;
  PE := RdD($3C);
  if RdD(PE) <> $00004550 then Exit;
  NSec := RdW(PE + 6);
  OptSize := RdW(PE + 20);
  SecTab := PE + 24 + OptSize;
  RsrcRVA := RdD(PE + 24 + 112);   { data directory 2 (resources), PE32 }
  RsrcRaw := 0;
  RsrcVSize := 0;
  for I := 0 to NSec - 1 do
    if (RsrcRVA >= RdD(SecTab + I * 40 + 12)) and
      (RsrcRVA < RdD(SecTab + I * 40 + 12) + Max(RdD(SecTab + I * 40 + 8), RdD(SecTab + I * 40 + 16))) then
    begin
      RsrcRaw := RdD(SecTab + I * 40 + 20) + (RsrcRVA - RdD(SecTab + I * 40 + 12));
      RsrcVSize := RdD(SecTab + I * 40 + 8);
      RsrcRVA := RsrcRVA;  { section-relative base already applied }
      Break;
    end;
  if RsrcRaw = 0 then Exit;
  if RsrcVSize = 0 then ;
  if not Lookup(0, TypeName, TypeId, C1) or (C1 and $80000000 = 0) then Exit;
  if not Lookup(C1 and $7FFFFFFF, Name, NameId, C2) or (C2 and $80000000 = 0) then Exit;
  if not Lookup(C2 and $7FFFFFFF, '', 0, C3) or (C3 and $80000000 <> 0) then Exit;
  DataEntry := RsrcRaw + C3;
  Offset := RvaToOfs(RdD(DataEntry));
  Size := RdD(DataEntry + 4);
  Result := (Offset + Size <= LongWord(Length(ExeImage)));
end;

function ResKey(P: PAnsiChar; out S: string; out Id: PtrUInt): Boolean;
begin
  if PtrUInt(P) < $10000 then
  begin
    S := '';
    Id := PtrUInt(P);
  end
  else
  begin
    S := StrPas(P);
    Id := 0;
    if (S <> '') and (S[1] = '#') then
    begin
      Id := StrToIntDef(Copy(S, 2, MaxInt), 0);
      S := '';
    end;
  end;
  Result := True;
end;

function ZMFindExeResource(Name, ResType: PAnsiChar): HRSRC;
var
  NS, TS: string;
  NI, TI: PtrUInt;
  O, S: LongWord;
begin
  Result := 0;
  ResKey(Name, NS, NI);
  ResKey(ResType, TS, TI);
  if not FindRes(NS, NI, TS, TI, O, S) then Exit;
  SetLength(ResEntries, Length(ResEntries) + 1);
  ResEntries[High(ResEntries)].Offset := O;
  ResEntries[High(ResEntries)].Size := S;
  Result := $7000 + High(ResEntries);
end;

function ZMExeResourceData(Res: HRSRC): Pointer;
var
  I: Integer;
begin
  I := Integer(Res) - $7000;
  if (I < 0) or (I > High(ResEntries)) then Exit(nil);
  Result := @ExeImage[ResEntries[I].Offset];
end;

function ZMExeResourceSize(Res: HRSRC): DWORD;
var
  I: Integer;
begin
  I := Integer(Res) - $7000;
  if (I < 0) or (I > High(ResEntries)) then Exit(0);
  Result := ResEntries[I].Size;
end;

function ZMLoadExeResource(const Name: string; ResType: PtrUInt; out Data: Pointer; out Size: Integer): Boolean;
var
  O, S: LongWord;
begin
  Data := nil;
  Size := 0;
  Result := FindRes(Name, 0, '', ResType, O, S);
  if Result then
  begin
    Data := @ExeImage[O];
    Size := S;
  end;
end;

end.

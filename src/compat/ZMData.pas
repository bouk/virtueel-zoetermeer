unit ZMData;

{ Waar de originele spelbestanden staan, en de toegang ertoe.

  De eigen kopie van het spel levert ROS.exe (formulierresources) en de datafiles. De
  datamap wordt in deze volgorde gezocht:
    1. de commandoregeloptie --data=<map> (of --data <map>)
    2. de omgevingsvariabele ZM_DATA
    3. de huidige map, daarna de map van het uitvoerbare bestand
  Een map komt in aanmerking als die ROS.exe of een images/-map bevat (elke letterkast).
  ROS.exe zelf kan overschreven worden met ZM_EXE / --exe=<bestand> (de datafiles van
  v1.1 en het exe kunnen in verschillende mappen staan).

  Paden in Windows-schrijfwijze (backslashes, elke letterkast) worden door
  ZMResolvePath opgelost tegen het echte bestandssysteem. }

{$MODE DELPHI}{$H+}

interface

uses Windows;

function ZMDataDir: string;          { met afsluitend scheidingsteken }
function ZMExeFile: string;          { volledig pad van het originele ROS.exe ('' als het niet gevonden is) }
function ZMExeName: string;          { wat ParamStr(0)/Application.ExeName teruggeven (zie ZMShadowDir) }
{ De "schaduw"-map laat de Windows-achtige paden van het spel werken via de gewone RTL
  (TIniFile, AssignFile, FindFirst, TStrings.LoadFromFile). Het spel bouwt paden als
  ExtractFilePath(ParamStr(0)) + '\' + 'images\8bits\x.bmp'. ParamStr(0) geeft
  <schaduw>/ROS.exe, dus zo'n pad wordt '<schaduw>/\images\8bits\x.bmp': één bestandsnaam
  (backslashes zijn gewone tekens op Unix) in de schaduwmap. De schaduwmap bevat symlinks
  met precies die namen (in meerdere letterkasten) naar de datafiles van de gebruiker, en
  mappen met de naam '\images\8bits\' voor FindFirst. Hij staat in
  $XDG_CACHE_HOME/zoetermeer (overschrijven met ZM_SHADOW). }
function ZMShadowDir: string;
function ZMResolvePath(const Path: string): string;

{ Schrijfbare overlay. Het spel schrijft nooit in de datamap (die kan een alleen-lezen
  Nix-store-pad zijn). Bestanden die het spel aanmaakt of wijzigt (de highscore in
  ZoetermeerLevels.Ini, bewaarde steden) komen in een map per gebruiker:
    ZM_SAVE, anders $XDG_DATA_HOME/zoetermeer (standaard ~/.local/share/zoetermeer),
    op macOS ~/Library/Application Support/Virtueel Zoetermeer.
  Bij het lezen wint de kopie in de overlay van het origineel: de schaduwmap verwijst
  naar de overlaykopie zodra die bestaat.
  ZMSaveDir geeft de map met afsluitend scheidingsteken ('' als er geen overlay is,
  zoals in de webversie, die zelf voor opslag zorgt).
  ZMWritePath geeft voor een pad dat het spel wil schrijven het pad dat echt
  beschreven moet worden: voor bestanden uit de datamap (of de schaduwmap) is dat de
  overlaykopie. Een bestaand origineel wordt eerst gekopieerd (copy-on-write), zodat
  bewerkingen ter plekke (WritePrivateProfileString) op de echte inhoud werken. Paden
  buiten de datamap blijven ongewijzigd. }
function ZMSaveDir: string;
function ZMWritePath(const Path: string): string;
{ True als Path in de datamap of de schaduwmap ligt (dan schrijft ZMWritePath elders) }
function ZMInDataDir(const Path: string): Boolean;
function ZMFileExists(const Path: string): Boolean;

{ PE-resources van het originele ROS.exe }
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

{ zoekt één map-item hoofdletterongevoelig op }
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

function ResolveRaw(const Path: string): string; forward;

function OverlayCopy(const Path: string): string; forward;

function ZMResolvePath(const Path: string): string;
begin
  Result := ResolveRaw(Path);
  Result := OverlayCopy(Result);
end;

function ResolveRaw(const Path: string): string;
var
  P, Part, Cur, Found: string;
  I, Start: Integer;
  Abs: Boolean;
begin
  if FileExists(Path) or DirectoryExists(Path) then Exit(Path);
  P := Path;
  for I := 1 to Length(P) do
    if P[I] = '\' then P[I] := '/';
  { stationsletters (C:/...) worden naar de datamap omgezet }
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
    if Found = '' then Found := Part;  { bestaat (nog) niet: houd de schrijfwijze aan }
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
{ Maplijst met letterlijke namen (FindFirst zou '\' als scheidingsteken zien). }
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

{ verwijdert de symlinks van een vorige run (bestanden die het spel schreef, blijven) }
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

procedure LinkVariants(const Target, LinkDir, Prefix, Name: string; Force: Boolean = False);
var
  Variants: array[0..3] of string;
  I: Integer;
  L: string;
  Info: Stat;
begin
  Variants[0] := Name;
  Variants[1] := LowerCase(Name);
  Variants[2] := ChangeFileExt(Name, LowerCase(ExtractFileExt(Name)));
  Variants[3] := UpperCase(Name);
  for I := 0 to High(Variants) do
  begin
    L := LinkDir + '/' + Prefix + Variants[I];
    { Force: een bestaande link vervangen (overlaykopie in plaats van origineel) }
    if Force and (FpLStat(PChar(L), Info) = 0) and fpS_ISLNK(Info.st_mode) then
      FpUnlink(PChar(L));
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
  { Rel is het Windows-achtige relatieve pad van SrcDir, bijv. '\images\8bits\'.
    Bestanden in de hoofdmap krijgen links in meerdere letterkasten ('\ZoetermeerGame.ini'
    voor ZoetermeerGame.Ini); bestanden in submappen krijgen precies één link elk met de
    naam op schijf, omdat FindFirst('<schaduw>/\images\8bits\*.bmp') de hoofdmap van de
    schaduw doorzoekt en elk bestand precies één keer moet teruggeven. Ook gewone
    (zonder backslash) links naar de items in de hoofdmap worden aangemaakt. }
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

{ ---------------------------------------------------------------- overlay }

var
  GSave: string = '';
  GSaveKnown: Boolean = False;

function ZMSaveDir: string;
var
  D: string;
begin
  if GSaveKnown then Exit(GSave);
  GSaveKnown := True;
  GSave := '';
{$IFDEF UNIX}
  D := GetEnvironmentVariable('ZM_SAVE');
  if D = '' then
  begin
{$IFDEF DARWIN}
    D := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
      'Library/Application Support/Virtueel Zoetermeer';
{$ELSE}
    D := GetEnvironmentVariable('XDG_DATA_HOME');
    if D = '' then D := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.local/share';
    D := IncludeTrailingPathDelimiter(D) + 'zoetermeer';
{$ENDIF}
  end;
  D := ExpandFileName(D);
  if ForceDirectories(D) then GSave := IncludeTrailingPathDelimiter(D);
{$ENDIF}
  Result := GSave;
end;

function StartsWith(const S, Prefix: string): Boolean;
begin
  Result := (Prefix <> '') and (Copy(S, 1, Length(Prefix)) = Prefix);
end;

{ Het pad van Path relatief aan de datamap, met '/' als scheidingsteken; '' als Path
  niet in de datamap of de schaduwmap ligt. In de schaduwmap zijn backslashes gewone
  tekens in de naam: '<schaduw>/\images\8bits\x.bmp' wordt 'images/8bits/x.bmp'. }
function DataRelative(const Path: string): string;
var
  I: Integer;
  Full: string;
begin
  Result := '';
  Full := ExpandFileName(Path);
  if StartsWith(Full, ZMShadowDir) then
    Result := Copy(Full, Length(ZMShadowDir) + 1, MaxInt)
  else if StartsWith(Full, ZMDataDir) then
    Result := Copy(Full, Length(ZMDataDir) + 1, MaxInt)
  else
    Exit;
  for I := 1 to Length(Result) do
    if Result[I] = '\' then Result[I] := '/';
  while (Result <> '') and (Result[1] = '/') do Delete(Result, 1, 1);
end;

{ Laat de schaduwnamen van het databestand Rel naar Target wijzen. }
procedure LinkShadow(const Rel, Target: string);
{$IFDEF UNIX}
var
  Root, WinRel: string;
  I: Integer;
  Info: Stat;
begin
  Root := ExcludeTrailingPathDelimiter(ZMShadowDir);
  if Pos('/', Rel) = 0 then
  begin
    LinkVariants(Target, Root, '\', Rel, True);
    LinkVariants(Target, Root, '', Rel, True);
  end
  else
  begin
    WinRel := '\' + Rel;
    for I := 1 to Length(WinRel) do
      if WinRel[I] = '/' then WinRel[I] := '\';
    if (FpLStat(PChar(Root + '/' + WinRel), Info) = 0) and fpS_ISLNK(Info.st_mode) then
      FpUnlink(PChar(Root + '/' + WinRel));
    if not Exists(Root + '/' + WinRel) then
      FpSymlink(PChar(Target), PChar(Root + '/' + WinRel));
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}

{$IFDEF UNIX}
{ Alle bestanden in de overlay krijgen schaduwnamen (lezen gaat voor op het origineel). }
procedure OverlayTree(const Dir, Rel: string);
var
  Names: TStringList;
  IsDir: TList;
  I: Integer;
begin
  ListDir(Dir, Names, IsDir);
  try
    for I := 0 to Names.Count - 1 do
      if IsDir[I] <> nil then
        OverlayTree(Dir + '/' + Names[I], Rel + Names[I] + '/')
      else
        LinkShadow(Rel + Names[I], Dir + '/' + Names[I]);
  finally
    Names.Free;
    IsDir.Free;
  end;
end;
{$ENDIF}

{ Voor een bestaand pad in de datamap: de overlaykopie als die er is. }
function OverlayCopy(const Path: string): string;
var
  Rel, Ov: string;
begin
  Result := Path;
  if (ZMSaveDir = '') or not StartsWith(Path, ZMDataDir) then Exit;
  Rel := Copy(Path, Length(ZMDataDir) + 1, MaxInt);
  Ov := ResolveRaw(ZMSaveDir + Rel);
  if FileExists(Ov) then Result := Ov;
end;

function CopyFileContents(const Src, Dst: string): Boolean;
var
  A, B: TFileStream;
begin
  Result := False;
  try
    A := TFileStream.Create(Src, fmOpenRead or fmShareDenyNone);
    try
      B := TFileStream.Create(Dst, fmCreate);
      try
        if A.Size > 0 then B.CopyFrom(A, A.Size);
        Result := True;
      finally
        B.Free;
      end;
    finally
      A.Free;
    end;
  except
    Result := False;
  end;
end;

function ZMInDataDir(const Path: string): Boolean;
begin
  Result := DataRelative(Path) <> '';
end;

function ZMWritePath(const Path: string): string;
var
  Rel, Src, Dst: string;
begin
  Result := Path;
  if ZMSaveDir = '' then Exit;
  if StartsWith(ExpandFileName(Path), ZMSaveDir) then Exit;
  Rel := DataRelative(Path);
  if Rel = '' then Exit;
  { de schrijfwijze van het origineel aanhouden (ZoetermeerLevels.Ini, niet .ini) }
  Src := ResolveRaw(ZMDataDir + Rel);
  if FileExists(Src) and StartsWith(Src, ZMDataDir) then
    Rel := Copy(Src, Length(ZMDataDir) + 1, MaxInt)
  else
    Src := '';
  Dst := ResolveRaw(ZMSaveDir + Rel);
  if not FileExists(Dst) then
  begin
    ForceDirectories(ExtractFileDir(Dst));
    if Src <> '' then CopyFileContents(Src, Dst);
  end;
  LinkShadow(Rel, Dst);
  Result := Dst;
end;

{$IFDEF UNIX}
var
  GShadowOwned: Boolean = False;

{ Verwijdert een schaduwmap: symlinks en (lege of door het spel gevulde) gewone
  bestanden; symlinks naar mappen worden nooit gevolgd. }
procedure RemoveTree(const Dir: string);
var
  Names: TStringList;
  IsDir: TList;
  I: Integer;
  P: string;
  Info: Stat;
begin
  if not ListDir(Dir, Names, IsDir) then
  begin
    Names.Free;
    IsDir.Free;
    Exit;
  end;
  try
    for I := 0 to Names.Count - 1 do
    begin
      P := Dir + '/' + Names[I];
      if (FpLStat(PChar(P), Info) = 0) and fpS_ISDIR(Info.st_mode) then
        RemoveTree(P)
      else
        FpUnlink(PChar(P));
    end;
  finally
    Names.Free;
    IsDir.Free;
  end;
  FpRmdir(PChar(Dir));
end;

{ Ruimt in Root de schaduwmappen op van processen die niet meer bestaan, en de
  losse symlinks van oudere versies (die één gedeelde map gebruikten). }
procedure CleanStale(const Root: string);
var
  Names: TStringList;
  IsDir: TList;
  I, Pid: Integer;
  P: string;
  Info: Stat;
begin
  ListDir(Root, Names, IsDir);
  try
    for I := 0 to Names.Count - 1 do
    begin
      P := Root + '/' + Names[I];
      if FpLStat(PChar(P), Info) <> 0 then Continue;
      if fpS_ISLNK(Info.st_mode) then
        FpUnlink(PChar(P))
      else if fpS_ISDIR(Info.st_mode) and TryStrToInt(Names[I], Pid) and (Pid > 0) and
        (FpKill(Pid, 0) <> 0) and (fpGetErrno = ESysESRCH) then
        RemoveTree(P);
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
{$IFDEF UNIX}
    { Elk proces krijgt een eigen schaduwmap (<root>/<pid>): het opnieuw opbouwen van
      een gedeelde map haalde de links even weg onder een ander, al draaiend proces
      (bijvoorbeeld twee testruns tegelijk). Mappen van beëindigde processen worden
      hier opgeruimd, de eigen map bij het afsluiten. }
    Base := ExpandFileName(Base);
    ForceDirectories(Base);
    CleanStale(Base);
    Base := Base + PathDelim + IntToStr(FpGetPid);
    GShadowOwned := True;
{$ENDIF}
  end;
  Base := ExpandFileName(Base);
  ForceDirectories(Base);
  GShadow := IncludeTrailingPathDelimiter(Base);
{$IFDEF UNIX}
  ClearLinks(Base);
  ShadowTree(D, '\');
  if ZMExeFile <> '' then
    LinkVariants(ZMExeFile, Base, '', 'ROS.exe');
  if ZMSaveDir <> '' then OverlayTree(ExcludeTrailingPathDelimiter(ZMSaveDir), '');
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

{ ---------------------------------------------------------------- PE-resources }

type
  TResEntry = record
    Offset, Size: LongWord;  { bestandsoffset en grootte van de data }
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

{ Zoekt een resource: geeft de bestandsoffset/grootte via de out-parameters. }
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

  { zoekt in een map op naam of id; geeft de OffsetToData van het item }
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
  RsrcRVA := RdD(PE + 24 + 112);   { datadirectory 2 (resources), PE32 }
  RsrcRaw := 0;
  RsrcVSize := 0;
  for I := 0 to NSec - 1 do
    if (RsrcRVA >= RdD(SecTab + I * 40 + 12)) and
      (RsrcRVA < RdD(SecTab + I * 40 + 12) + Max(RdD(SecTab + I * 40 + 8), RdD(SecTab + I * 40 + 16))) then
    begin
      RsrcRaw := RdD(SecTab + I * 40 + 20) + (RsrcRVA - RdD(SecTab + I * 40 + 12));
      RsrcVSize := RdD(SecTab + I * 40 + 8);
      RsrcRVA := RsrcRVA;  { sectie-relatieve basis is al toegepast }
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

{$IFDEF UNIX}
finalization
  if GShadowOwned and (GShadow <> '') then
    RemoveTree(ExcludeTrailingPathDelimiter(GShadow));
{$ENDIF}
end.

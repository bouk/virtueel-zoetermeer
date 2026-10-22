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
function ZMResolvePath(const Pad: string): string;

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
function ZMWritePath(const Pad: string): string;
{ True als Path in de datamap of de schaduwmap ligt (dan schrijft ZMWritePath elders) }
function ZMInDataDir(const Pad: string): Boolean;
function ZMFileExists(const Pad: string): Boolean;

{ PE-resources van het originele ROS.exe }
function ZMFindExeResource(Naam, Hulpbronsoort: PAnsiChar): HRSRC;
function ZMExeResourceData(Hulpbron: HRSRC): Pointer;
function ZMExeResourceSize(Hulpbron: HRSRC): DWORD;
function ZMLoadExeResource(const Naam: string; Hulpbronsoort: PtrUInt; out Gegevens: Pointer; out Grootte: Integer): Boolean;

implementation

uses SysUtils, Classes{$IFDEF UNIX}, BaseUnix{$ENDIF};

var
  GDataDir: string = '';
  GExeFile: string = '';
  Located: Boolean = False;
  ExeImage: array of Byte;
  ExeLoaded: Boolean = False;

function OptionValue(const Naam: string): string;
var
  Index: Integer;
  Tekst: string;
begin
  Result := '';
  for Index := 1 to System.ParamCount do
  begin
    Tekst := System.ParamStr(Index);
    if Copy(Tekst, 1, Length(Naam) + 3) = '--' + Naam + '=' then
      Exit(Copy(Tekst, Length(Naam) + 4, MaxInt));
    if (Tekst = '--' + Naam) and (Index < System.ParamCount) then
      Exit(System.ParamStr(Index + 1));
  end;
end;

{ zoekt één map-item hoofdletterongevoelig op }
function FindEntry(const Map, Naam: string): string;
var
  Zoekrecord: TSearchRec;
begin
  Result := '';
  if (Naam = '') or (Naam = '.') or (Naam = '..') then Exit(Naam);
  if FileExists(IncludeTrailingPathDelimiter(Map) + Naam) or
    DirectoryExists(IncludeTrailingPathDelimiter(Map) + Naam) then
    Exit(Naam);
  if FindFirst(IncludeTrailingPathDelimiter(Map) + '*', faAnyFile, Zoekrecord) = 0 then
  begin
    repeat
      if SameText(Zoekrecord.Name, Naam) then
      begin
        Result := Zoekrecord.Name;
        Break;
      end;
    until FindNext(Zoekrecord) <> 0;
    FindClose(Zoekrecord);
  end;
end;

function ResolveRaw(const Pad: string): string; forward;

function OverlayCopy(const Pad: string): string; forward;

function ZMResolvePath(const Pad: string): string;
begin
  Result := ResolveRaw(Pad);
  Result := OverlayCopy(Result);
end;

function ResolveRaw(const Pad: string): string;
var
  Genormaliseerd, Deel, Huidig, Gevonden: string;
  Index, Startpositie: Integer;
  Absoluut: Boolean;
begin
  if FileExists(Pad) or DirectoryExists(Pad) then Exit(Pad);
  Genormaliseerd := Pad;
  for Index := 1 to Length(Genormaliseerd) do
    if Genormaliseerd[Index] = '\' then Genormaliseerd[Index] := '/';
  { stationsletters (C:/...) worden naar de datamap omgezet }
  if (Length(Genormaliseerd) >= 2) and (Genormaliseerd[2] = ':') then
    Genormaliseerd := ZMDataDir + Copy(Genormaliseerd, 4, MaxInt);
  if FileExists(Genormaliseerd) or DirectoryExists(Genormaliseerd) then Exit(Genormaliseerd);
  Absoluut := (Genormaliseerd <> '') and (Genormaliseerd[1] = '/');
  if Absoluut then Huidig := '/' else Huidig := '.';
  Result := '';
  if Absoluut then Result := '/';
  Index := 1;
  while Index <= Length(Genormaliseerd) do
  begin
    while (Index <= Length(Genormaliseerd)) and (Genormaliseerd[Index] = '/') do Inc(Index);
    Startpositie := Index;
    while (Index <= Length(Genormaliseerd)) and (Genormaliseerd[Index] <> '/') do Inc(Index);
    Deel := Copy(Genormaliseerd, Startpositie, Index - Startpositie);
    if Deel = '' then Break;
    Gevonden := FindEntry(Huidig, Deel);
    if Gevonden = '' then Gevonden := Deel;  { bestaat (nog) niet: houd de schrijfwijze aan }
    if (Result <> '') and (Result[Length(Result)] <> '/') then Result := Result + '/';
    Result := Result + Gevonden;
    if Huidig = '/' then Huidig := '/' + Gevonden
    else Huidig := Huidig + '/' + Gevonden;
  end;
  if (Genormaliseerd <> '') and (Genormaliseerd[Length(Genormaliseerd)] = '/') and (Result <> '') and (Result[Length(Result)] <> '/') then
    Result := Result + '/';
  if Result = '' then Result := Genormaliseerd;
end;

function ZMFileExists(const Pad: string): Boolean;
begin
  Result := FileExists(ZMResolvePath(Pad));
end;

function DirHasGame(const Map: string): Boolean;
begin
  Result := (Map <> '') and DirectoryExists(Map) and
    ((FindEntry(Map, 'ROS.exe') <> '') or (FindEntry(Map, 'images') <> ''));
end;

procedure Locate;
var
  Kandidaten: array[0..3] of string;
  Index: Integer;
  Gevonden, ExeOptie: string;
begin
  if Located then Exit;
  Located := True;
  Kandidaten[0] := OptionValue('data');
  Kandidaten[1] := GetEnvironmentVariable('ZM_DATA');
  Kandidaten[2] := GetCurrentDir;
  Kandidaten[3] := ExtractFilePath(ExpandFileName(System.ParamStr(0)));
  GDataDir := '';
  for Index := 0 to High(Kandidaten) do
    if DirHasGame(Kandidaten[Index]) then
    begin
      GDataDir := IncludeTrailingPathDelimiter(ExpandFileName(Kandidaten[Index]));
      Break;
    end;
  if GDataDir = '' then
    GDataDir := IncludeTrailingPathDelimiter(GetCurrentDir);
  ExeOptie := OptionValue('exe');
  if ExeOptie = '' then ExeOptie := GetEnvironmentVariable('ZM_EXE');
  if (ExeOptie <> '') and FileExists(ExeOptie) then
    GExeFile := ExpandFileName(ExeOptie)
  else
  begin
    Gevonden := FindEntry(GDataDir, 'ROS.exe');
    if Gevonden <> '' then GExeFile := GDataDir + Gevonden;
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
function ListDir(const Map: string; out Namen: TStringList; out IsMap: TList): Boolean;
var
  Mapgreep: PDir;
  Vermelding: PDirent;
  Naam: string;
  Informatie: Stat;
begin
  Namen := TStringList.Create;
  IsMap := TList.Create;
  Mapgreep := FpOpenDir(PChar(Map));
  Result := Mapgreep <> nil;
  if Mapgreep = nil then Exit;
  repeat
    Vermelding := FpReadDir(Mapgreep^);
    if Vermelding = nil then Break;
    Naam := StrPas(PChar(@Vermelding^.d_name[0]));
    if (Naam = '.') or (Naam = '..') then Continue;
    Namen.Add(Naam);
    if (FpLStat(PChar(Map + '/' + Naam), Informatie) = 0) and fpS_ISDIR(Informatie.st_mode) then
      IsMap.Add(Pointer(1))
    else
      IsMap.Add(nil);
  until False;
  FpCloseDir(Mapgreep^);
end;

{ verwijdert de symlinks van een vorige run (bestanden die het spel schreef, blijven) }
procedure ClearLinks(const Map: string);
var
  Namen: TStringList;
  IsMap: TList;
  Index: Integer;
  Pad: string;
  Informatie: Stat;
begin
  ListDir(Map, Namen, IsMap);
  try
    for Index := 0 to Namen.Count - 1 do
    begin
      Pad := Map + '/' + Namen[Index];
      if (FpLStat(PChar(Pad), Informatie) = 0) and fpS_ISLNK(Informatie.st_mode) then
        FpUnlink(PChar(Pad))
      else if IsMap[Index] <> nil then
        ClearLinks(Pad);
    end;
  finally
    Namen.Free;
    IsMap.Free;
  end;
end;

function Exists(const Pad: string): Boolean;
var
  Informatie: Stat;
begin
  Result := FpLStat(PChar(Pad), Informatie) = 0;
end;

procedure LinkVariants(const Doel, LinkMap, Voorvoegsel, Naam: string; Forceren: Boolean = False);
var
  Varianten: array[0..3] of string;
  Index: Integer;
  Link: string;
  Informatie: Stat;
begin
  Varianten[0] := Naam;
  Varianten[1] := LowerCase(Naam);
  Varianten[2] := ChangeFileExt(Naam, LowerCase(ExtractFileExt(Naam)));
  Varianten[3] := UpperCase(Naam);
  for Index := 0 to High(Varianten) do
  begin
    Link := LinkMap + '/' + Voorvoegsel + Varianten[Index];
    { Force: een bestaande link vervangen (overlaykopie in plaats van origineel) }
    if Forceren and (FpLStat(PChar(Link), Informatie) = 0) and fpS_ISLNK(Informatie.st_mode) then
      FpUnlink(PChar(Link));
    if not Exists(Link) then FpSymlink(PChar(Doel), PChar(Link));
  end;
end;

procedure ShadowTree(const BronMap, Relatief: string);
var
  Namen: TStringList;
  IsMap: TList;
  Index: Integer;
  Onderdeel, Wortel: string;
begin
  { Rel is het Windows-achtige relatieve pad van SrcDir, bijv. '\images\8bits\'.
    Bestanden in de hoofdmap krijgen links in meerdere letterkasten ('\ZoetermeerGame.ini'
    voor ZoetermeerGame.Ini); bestanden in submappen krijgen precies één link elk met de
    naam op schijf, omdat FindFirst('<schaduw>/\images\8bits\*.bmp') de hoofdmap van de
    schaduw doorzoekt en elk bestand precies één keer moet teruggeven. Ook gewone
    (zonder backslash) links naar de items in de hoofdmap worden aangemaakt. }
  Wortel := ExcludeTrailingPathDelimiter(GShadow);
  ListDir(BronMap, Namen, IsMap);
  try
    for Index := 0 to Namen.Count - 1 do
    begin
      Onderdeel := BronMap + '/' + Namen[Index];
      if IsMap[Index] <> nil then
      begin
        if Relatief = '\' then LinkVariants(Onderdeel, Wortel, '', Namen[Index]);
        ShadowTree(Onderdeel, Relatief + Namen[Index] + '\');
      end
      else if Relatief = '\' then
      begin
        LinkVariants(Onderdeel, Wortel, Relatief, Namen[Index]);
        LinkVariants(Onderdeel, Wortel, '', Namen[Index]);
      end
      else if not Exists(Wortel + '/' + Relatief + Namen[Index]) then
        FpSymlink(PChar(Onderdeel), PChar(Wortel + '/' + Relatief + Namen[Index]));
    end;
  finally
    Namen.Free;
    IsMap.Free;
  end;
end;
{$ENDIF}

{ ---------------------------------------------------------------- overlay }

var
  GSave: string = '';
  GSaveKnown: Boolean = False;

function ZMSaveDir: string;
var
  Mapnaam: string;
begin
  if GSaveKnown then Exit(GSave);
  GSaveKnown := True;
  GSave := '';
{$IFDEF UNIX}
  Mapnaam := GetEnvironmentVariable('ZM_SAVE');
  if Mapnaam = '' then
  begin
{$IFDEF DARWIN}
    Mapnaam := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) +
      'Library/Application Support/Virtueel Zoetermeer';
{$ELSE}
    Mapnaam := GetEnvironmentVariable('XDG_DATA_HOME');
    if Mapnaam = '' then Mapnaam := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.local/share';
    Mapnaam := IncludeTrailingPathDelimiter(Mapnaam) + 'zoetermeer';
{$ENDIF}
  end;
  Mapnaam := ExpandFileName(Mapnaam);
  if ForceDirectories(Mapnaam) then GSave := IncludeTrailingPathDelimiter(Mapnaam);
{$ENDIF}
  Result := GSave;
end;

function StartsWith(const Tekst, Voorvoegsel: string): Boolean;
begin
  Result := (Voorvoegsel <> '') and (Copy(Tekst, 1, Length(Voorvoegsel)) = Voorvoegsel);
end;

{ Het pad van Path relatief aan de datamap, met '/' als scheidingsteken; '' als Path
  niet in de datamap of de schaduwmap ligt. In de schaduwmap zijn backslashes gewone
  tekens in de naam: '<schaduw>/\images\8bits\x.bmp' wordt 'images/8bits/x.bmp'. }
function DataRelative(const Pad: string): string;
var
  Index: Integer;
  Volledig: string;
begin
  Result := '';
  Volledig := ExpandFileName(Pad);
  if StartsWith(Volledig, ZMShadowDir) then
    Result := Copy(Volledig, Length(ZMShadowDir) + 1, MaxInt)
  else if StartsWith(Volledig, ZMDataDir) then
    Result := Copy(Volledig, Length(ZMDataDir) + 1, MaxInt)
  else
    Exit;
  for Index := 1 to Length(Result) do
    if Result[Index] = '\' then Result[Index] := '/';
  while (Result <> '') and (Result[1] = '/') do Delete(Result, 1, 1);
end;

{ Laat de schaduwnamen van het databestand Rel naar Target wijzen. }
procedure LinkShadow(const Relatief, Doel: string);
{$IFDEF UNIX}
var
  Wortel, WinRelatief: string;
  Index: Integer;
  Informatie: Stat;
begin
  Wortel := ExcludeTrailingPathDelimiter(ZMShadowDir);
  if Pos('/', Relatief) = 0 then
  begin
    LinkVariants(Doel, Wortel, '\', Relatief, True);
    LinkVariants(Doel, Wortel, '', Relatief, True);
  end
  else
  begin
    WinRelatief := '\' + Relatief;
    for Index := 1 to Length(WinRelatief) do
      if WinRelatief[Index] = '/' then WinRelatief[Index] := '\';
    if (FpLStat(PChar(Wortel + '/' + WinRelatief), Informatie) = 0) and fpS_ISLNK(Informatie.st_mode) then
      FpUnlink(PChar(Wortel + '/' + WinRelatief));
    if not Exists(Wortel + '/' + WinRelatief) then
      FpSymlink(PChar(Doel), PChar(Wortel + '/' + WinRelatief));
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}

{$IFDEF UNIX}
{ Alle bestanden in de overlay krijgen schaduwnamen (lezen gaat voor op het origineel). }
procedure OverlayTree(const Map, Relatief: string);
var
  Namen: TStringList;
  IsMap: TList;
  Index: Integer;
begin
  ListDir(Map, Namen, IsMap);
  try
    for Index := 0 to Namen.Count - 1 do
      if IsMap[Index] <> nil then
        OverlayTree(Map + '/' + Namen[Index], Relatief + Namen[Index] + '/')
      else
        LinkShadow(Relatief + Namen[Index], Map + '/' + Namen[Index]);
  finally
    Namen.Free;
    IsMap.Free;
  end;
end;
{$ENDIF}

{ Voor een bestaand pad in de datamap: de overlaykopie als die er is. }
function OverlayCopy(const Pad: string): string;
var
  Relatief, Overlaypad: string;
begin
  Result := Pad;
  if (ZMSaveDir = '') or not StartsWith(Pad, ZMDataDir) then Exit;
  Relatief := Copy(Pad, Length(ZMDataDir) + 1, MaxInt);
  Overlaypad := ResolveRaw(ZMSaveDir + Relatief);
  if FileExists(Overlaypad) then Result := Overlaypad;
end;

function CopyFileContents(const Bron, Doel: string): Boolean;
var
  Bronstroom, Doelstroom: TFileStream;
begin
  Result := False;
  try
    Bronstroom := TFileStream.Create(Bron, fmOpenRead or fmShareDenyNone);
    try
      Doelstroom := TFileStream.Create(Doel, fmCreate);
      try
        if Bronstroom.Size > 0 then Doelstroom.CopyFrom(Bronstroom, Bronstroom.Size);
        Result := True;
      finally
        Doelstroom.Free;
      end;
    finally
      Bronstroom.Free;
    end;
  except
    Result := False;
  end;
end;

function ZMInDataDir(const Pad: string): Boolean;
begin
  Result := DataRelative(Pad) <> '';
end;

function ZMWritePath(const Pad: string): string;
var
  Relatief, Bron, Doel: string;
begin
  Result := Pad;
  if ZMSaveDir = '' then Exit;
  if StartsWith(ExpandFileName(Pad), ZMSaveDir) then Exit;
  Relatief := DataRelative(Pad);
  if Relatief = '' then Exit;
  { de schrijfwijze van het origineel aanhouden (ZoetermeerLevels.Ini, niet .ini) }
  Bron := ResolveRaw(ZMDataDir + Relatief);
  if FileExists(Bron) and StartsWith(Bron, ZMDataDir) then
    Relatief := Copy(Bron, Length(ZMDataDir) + 1, MaxInt)
  else
    Bron := '';
  Doel := ResolveRaw(ZMSaveDir + Relatief);
  if not FileExists(Doel) then
  begin
    ForceDirectories(ExtractFileDir(Doel));
    if Bron <> '' then CopyFileContents(Bron, Doel);
  end;
  LinkShadow(Relatief, Doel);
  Result := Doel;
end;

{$IFDEF UNIX}
var
  GShadowOwned: Boolean = False;

{ Verwijdert een schaduwmap: symlinks en (lege of door het spel gevulde) gewone
  bestanden; symlinks naar mappen worden nooit gevolgd. }
procedure RemoveTree(const Map: string);
var
  Namen: TStringList;
  IsMap: TList;
  Index: Integer;
  Pad: string;
  Informatie: Stat;
begin
  if not ListDir(Map, Namen, IsMap) then
  begin
    Namen.Free;
    IsMap.Free;
    Exit;
  end;
  try
    for Index := 0 to Namen.Count - 1 do
    begin
      Pad := Map + '/' + Namen[Index];
      if (FpLStat(PChar(Pad), Informatie) = 0) and fpS_ISDIR(Informatie.st_mode) then
        RemoveTree(Pad)
      else
        FpUnlink(PChar(Pad));
    end;
  finally
    Namen.Free;
    IsMap.Free;
  end;
  FpRmdir(PChar(Map));
end;

{ Ruimt in Root de schaduwmappen op van processen die niet meer bestaan, en de
  losse symlinks van oudere versies (die één gedeelde map gebruikten). }
procedure CleanStale(const Wortel: string);
var
  Namen: TStringList;
  IsMap: TList;
  Index, Procesnr: Integer;
  Pad: string;
  Informatie: Stat;
begin
  ListDir(Wortel, Namen, IsMap);
  try
    for Index := 0 to Namen.Count - 1 do
    begin
      Pad := Wortel + '/' + Namen[Index];
      if FpLStat(PChar(Pad), Informatie) <> 0 then Continue;
      if fpS_ISLNK(Informatie.st_mode) then
        FpUnlink(PChar(Pad))
      else if fpS_ISDIR(Informatie.st_mode) and TryStrToInt(Namen[Index], Procesnr) and (Procesnr > 0) and
        (FpKill(Procesnr, 0) <> 0) and (fpGetErrno = ESysESRCH) then
        RemoveTree(Pad);
    end;
  finally
    Namen.Free;
    IsMap.Free;
  end;
end;
{$ENDIF}

function ZMShadowDir: string;
var
  Basis: string;
  Hashwaarde: LongWord;
  Index: Integer;
  Mapnaam: string;
begin
  if GShadow <> '' then Exit(GShadow);
  Mapnaam := ExcludeTrailingPathDelimiter(ZMDataDir);
  Basis := GetEnvironmentVariable('ZM_SHADOW');
  if Basis = '' then
  begin
    Basis := GetEnvironmentVariable('XDG_CACHE_HOME');
    if Basis = '' then Basis := IncludeTrailingPathDelimiter(GetEnvironmentVariable('HOME')) + '.cache';
    Hashwaarde := 5381;
    for Index := 1 to Length(Mapnaam) do Hashwaarde := Hashwaarde * 33 + Ord(Mapnaam[Index]);
    Basis := IncludeTrailingPathDelimiter(Basis) + 'zoetermeer' + PathDelim + 'root-' + IntToHex(Hashwaarde, 8);
{$IFDEF UNIX}
    { Elk proces krijgt een eigen schaduwmap (<root>/<pid>): het opnieuw opbouwen van
      een gedeelde map haalde de links even weg onder een ander, al draaiend proces
      (bijvoorbeeld twee testruns tegelijk). Mappen van beëindigde processen worden
      hier opgeruimd, de eigen map bij het afsluiten. }
    Basis := ExpandFileName(Basis);
    ForceDirectories(Basis);
    CleanStale(Basis);
    Basis := Basis + PathDelim + IntToStr(FpGetPid);
    GShadowOwned := True;
{$ENDIF}
  end;
  Basis := ExpandFileName(Basis);
  ForceDirectories(Basis);
  GShadow := IncludeTrailingPathDelimiter(Basis);
{$IFDEF UNIX}
  ClearLinks(Basis);
  ShadowTree(Mapnaam, '\');
  if ZMExeFile <> '' then
    LinkVariants(ZMExeFile, Basis, '', 'ROS.exe');
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
  Bestandstroom: TFileStream;
begin
  if ExeLoaded then Exit;
  ExeLoaded := True;
  if ZMExeFile = '' then Exit;
  try
    Bestandstroom := TFileStream.Create(ZMExeFile, fmOpenRead or fmShareDenyNone);
    try
      SetLength(ExeImage, Bestandstroom.Size);
      if Bestandstroom.Size > 0 then Bestandstroom.ReadBuffer(ExeImage[0], Bestandstroom.Size);
    finally
      Bestandstroom.Free;
    end;
  except
    SetLength(ExeImage, 0);
  end;
end;

function RdW(Verschuiving: LongWord): Word;
begin
  if Verschuiving + 2 > LongWord(Length(ExeImage)) then Exit(0);
  Result := ExeImage[Verschuiving] or (ExeImage[Verschuiving + 1] shl 8);
end;

function RdD(Verschuiving: LongWord): LongWord;
begin
  if Verschuiving + 4 > LongWord(Length(ExeImage)) then Exit(0);
  Result := ExeImage[Verschuiving] or (LongWord(ExeImage[Verschuiving + 1]) shl 8) or
    (LongWord(ExeImage[Verschuiving + 2]) shl 16) or (LongWord(ExeImage[Verschuiving + 3]) shl 24);
end;

function Max(Eerste, Tweede: LongWord): LongWord;
begin
  if Eerste > Tweede then Result := Eerste else Result := Tweede;
end;

{ Zoekt een resource: geeft de bestandsoffset/grootte via de out-parameters. }
function FindRes(const Naam: string; NaamId: PtrUInt; Soortnaam: string; SoortId: PtrUInt;
  out Bestandsoffset, Grootte: LongWord): Boolean;
var
  PeKop, SectieTabel, AantalSecties, Index, HulpbronRVA, HulpbronRuw, HulpbronVGrootte: LongWord;
  OptGrootte: Word;

  function RvaNaarVerschuiving(Rva: LongWord): LongWord;
  begin
    Result := Rva - HulpbronRVA + HulpbronRuw;
  end;

  function MapNaam(Verschuiving: LongWord): string;
  var
    Lengte, Teller: Integer;
  begin
    Result := '';
    Lengte := RdW(HulpbronRuw + Verschuiving);
    for Teller := 0 to Lengte - 1 do
      Result := Result + Chr(RdW(HulpbronRuw + Verschuiving + 2 + LongWord(Teller) * 2) and $FF);
  end;

  { zoekt in een map op naam of id; geeft de OffsetToData van het item }
  function Opzoeken(MapVerschuiving: LongWord; const GezochteNaam: string; GezochteId: PtrUInt; out Kind: LongWord): Boolean;
  var
    AantalNaam, AantalId, Teller, Vermelding: LongWord;
    NaamVeld, DataVeld: LongWord;
  begin
    Result := False;
    AantalNaam := RdW(HulpbronRuw + MapVerschuiving + 12);
    AantalId := RdW(HulpbronRuw + MapVerschuiving + 14);
    for Teller := 0 to AantalNaam + AantalId - 1 do
    begin
      Vermelding := HulpbronRuw + MapVerschuiving + 16 + Teller * 8;
      NaamVeld := RdD(Vermelding);
      DataVeld := RdD(Vermelding + 4);
      if NaamVeld and $80000000 <> 0 then
      begin
        if (GezochteNaam <> '') and SameText(MapNaam(NaamVeld and $7FFFFFFF), GezochteNaam) then
        begin
          Kind := DataVeld;
          Exit(True);
        end;
      end
      else if (GezochteNaam = '') and ((GezochteId = 0) or (NaamVeld = GezochteId)) then
      begin
        Kind := DataVeld;
        Exit(True);
      end;
    end;
  end;

var
  Niveau1, Niveau2, Niveau3, DataVermelding: LongWord;
begin
  Result := False;
  Bestandsoffset := 0;
  Grootte := 0;
  LoadExe;
  if Length(ExeImage) < $100 then Exit;
  if RdW(0) <> $5A4D then Exit;
  PeKop := RdD($3C);
  if RdD(PeKop) <> $00004550 then Exit;
  AantalSecties := RdW(PeKop + 6);
  OptGrootte := RdW(PeKop + 20);
  SectieTabel := PeKop + 24 + OptGrootte;
  HulpbronRVA := RdD(PeKop + 24 + 112);   { datadirectory 2 (resources), PE32 }
  HulpbronRuw := 0;
  HulpbronVGrootte := 0;
  for Index := 0 to AantalSecties - 1 do
    if (HulpbronRVA >= RdD(SectieTabel + Index * 40 + 12)) and
      (HulpbronRVA < RdD(SectieTabel + Index * 40 + 12) + Max(RdD(SectieTabel + Index * 40 + 8), RdD(SectieTabel + Index * 40 + 16))) then
    begin
      HulpbronRuw := RdD(SectieTabel + Index * 40 + 20) + (HulpbronRVA - RdD(SectieTabel + Index * 40 + 12));
      HulpbronVGrootte := RdD(SectieTabel + Index * 40 + 8);
      HulpbronRVA := HulpbronRVA;  { sectie-relatieve basis is al toegepast }
      Break;
    end;
  if HulpbronRuw = 0 then Exit;
  if HulpbronVGrootte = 0 then ;
  if not Opzoeken(0, Soortnaam, SoortId, Niveau1) or (Niveau1 and $80000000 = 0) then Exit;
  if not Opzoeken(Niveau1 and $7FFFFFFF, Naam, NaamId, Niveau2) or (Niveau2 and $80000000 = 0) then Exit;
  if not Opzoeken(Niveau2 and $7FFFFFFF, '', 0, Niveau3) or (Niveau3 and $80000000 <> 0) then Exit;
  DataVermelding := HulpbronRuw + Niveau3;
  Bestandsoffset := RvaNaarVerschuiving(RdD(DataVermelding));
  Grootte := RdD(DataVermelding + 4);
  Result := (Bestandsoffset + Grootte <= LongWord(Length(ExeImage)));
end;

function ResKey(Invoer: PAnsiChar; out Naam: string; out Nummer: PtrUInt): Boolean;
begin
  if PtrUInt(Invoer) < $10000 then
  begin
    Naam := '';
    Nummer := PtrUInt(Invoer);
  end
  else
  begin
    Naam := StrPas(Invoer);
    Nummer := 0;
    if (Naam <> '') and (Naam[1] = '#') then
    begin
      Nummer := StrToIntDef(Copy(Naam, 2, MaxInt), 0);
      Naam := '';
    end;
  end;
  Result := True;
end;

function ZMFindExeResource(Naam, Hulpbronsoort: PAnsiChar): HRSRC;
var
  NaamTekst, SoortTekst: string;
  NaamNummer, SoortNummer: PtrUInt;
  Verschuiving, Grootte: LongWord;
begin
  Result := 0;
  ResKey(Naam, NaamTekst, NaamNummer);
  ResKey(Hulpbronsoort, SoortTekst, SoortNummer);
  if not FindRes(NaamTekst, NaamNummer, SoortTekst, SoortNummer, Verschuiving, Grootte) then Exit;
  SetLength(ResEntries, Length(ResEntries) + 1);
  ResEntries[High(ResEntries)].Offset := Verschuiving;
  ResEntries[High(ResEntries)].Size := Grootte;
  Result := $7000 + High(ResEntries);
end;

function ZMExeResourceData(Hulpbron: HRSRC): Pointer;
var
  Index: Integer;
begin
  Index := Integer(Hulpbron) - $7000;
  if (Index < 0) or (Index > High(ResEntries)) then Exit(nil);
  Result := @ExeImage[ResEntries[Index].Offset];
end;

function ZMExeResourceSize(Hulpbron: HRSRC): DWORD;
var
  Index: Integer;
begin
  Index := Integer(Hulpbron) - $7000;
  if (Index < 0) or (Index > High(ResEntries)) then Exit(0);
  Result := ResEntries[Index].Size;
end;

function ZMLoadExeResource(const Naam: string; Hulpbronsoort: PtrUInt; out Gegevens: Pointer; out Grootte: Integer): Boolean;
var
  Verschuiving, Lengte: LongWord;
begin
  Gegevens := nil;
  Grootte := 0;
  Result := FindRes(Naam, 0, '', Hulpbronsoort, Verschuiving, Lengte);
  if Result then
  begin
    Gegevens := @ExeImage[Verschuiving];
    Grootte := Lengte;
  end;
end;

{$IFDEF UNIX}
finalization
  if GShadowOwned and (GShadow <> '') then
    RemoveTree(ExcludeTrailingPathDelimiter(GShadow));
{$ENDIF}
end.

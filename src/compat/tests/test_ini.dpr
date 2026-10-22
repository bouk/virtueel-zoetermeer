program test_ini;

{ Test van IniFiles/ZMProfile en de schrijfbare overlay van ZMData.
  tools/compat-test.sh start dit programma met een eigen (synthetische) datamap:
    ZM_DATA   map met Test.ini (CRLF-regeleinden, commentaar, lege regels) en images/
    ZM_SAVE   lege overlaymap
    ZM_SHADOW eigen schaduwmap
  Gecontroleerd wordt: leesregels van GetPrivateProfileString, schrijven ter plekke
  (commentaar, lege regels, volgorde en regeleinden blijven), dat de datamap nooit
  verandert en dat lezen daarna de overlaykopie ziet. }

{$MODE DELPHI}{$H+}

uses
  Windows, SysUtils, Classes, IniFiles, ZMData;

const
  CRLF = #13#10;
  Origineel =
    '[General]' + CRLF +
    '; commentaar' + CRLF +
    'Naam = Waarde' + CRLF +
    'Getal=12' + CRLF +
    'Quoted="  met spaties  "' + CRLF +
    'Hex=0x1F' + CRLF +
    CRLF +
    '[Level1]' + CRLF +
    'Duration=180' + CRLF +
    '; einde' + CRLF;

var
  Fails: Integer;

procedure Check(Cond: Boolean; const Msg: string);
begin
  if not Cond then
  begin
    WriteLn('FOUT: ', Msg);
    Inc(Fails);
  end;
end;

function ReadFile(const Path: string): string;
var
  S: TFileStream;
begin
  Result := '';
  if not FileExists(Path) then Exit;
  S := TFileStream.Create(Path, fmOpenRead);
  try
    SetLength(Result, S.Size);
    if S.Size > 0 then S.ReadBuffer(Result[1], S.Size);
  finally
    S.Free;
  end;
end;

procedure CheckEq(const Got, Want, Msg: string);
begin
  Check(Got = Want, Msg + ': kreeg ' + QuotedStr(Got) + ', verwacht ' + QuotedStr(Want));
end;

var
  Ini: TIniFile;
  Path, DataFile, SaveFile, Verwacht: string;
  L: TStringList;
  Buf: array[0..63] of AnsiChar;
  N: DWORD;
begin
  Fails := 0;
  { het pad zoals het spel het maakt: map van ParamStr(0) + '\Test.ini' }
  Path := ExtractFilePath(Windows.ParamStr(0)) + '\Test.ini';
  DataFile := ZMDataDir + 'Test.ini';
  SaveFile := ZMSaveDir + 'Test.ini';
  Check(ZMSaveDir <> '', 'ZM_SAVE moet een overlay opleveren');
  CheckEq(ReadFile(DataFile), Origineel, 'datamap voor de test');

  Ini := TIniFile.Create(Path);
  try
    CheckEq(Ini.ReadString('general', 'NAAM', '?'), 'Waarde', 'hoofdletterongevoelig, witruimte');
    Check(Ini.ReadInteger('General', 'Getal', 0) = 12, 'ReadInteger');
    Check(Ini.ReadInteger('General', 'Hex', 0) = 31, 'ReadInteger met 0x');
    CheckEq(Ini.ReadString('General', 'Quoted', ''), '  met spaties  ', 'aanhalingstekens weg');
    CheckEq(Ini.ReadString('General', 'Ontbreekt', 'std  '), 'std', 'standaardwaarde zonder spaties achteraan');
    Check(Ini.ReadBool('Level1', 'Duration', False), 'ReadBool');
    Check(not Ini.ReadBool('Level1', 'Ontbreekt', False), 'ReadBool standaard');
    Check(Ini.SectionExists('LEVEL1') and not Ini.SectionExists('Level2'), 'SectionExists');
    Check(Ini.ValueExists('General', 'Getal'), 'ValueExists');
    L := TStringList.Create;
    try
      Ini.ReadSections(L);
      CheckEq(L.CommaText, 'General,Level1', 'ReadSections');
      Ini.ReadSection('General', L);
      CheckEq(L.CommaText, 'Naam,Getal,Quoted,Hex', 'ReadSection (zonder commentaar)');
      Ini.ReadSectionValues('Level1', L);
      CheckEq(L.CommaText, 'Duration=180', 'ReadSectionValues');
    finally
      L.Free;
    end;

    { afkappen zoals Windows }
    N := GetPrivateProfileString('General', 'Naam', '', Buf, 4, PAnsiChar(Path));
    Check((N = 3) and (StrPas(Buf) = 'Waa'), 'afkappen van een waarde');

    { schrijven: alleen de overlay verandert }
    Ini.WriteInteger('General', 'Getal', 99);
    Ini.WriteString('General', 'Naam', 'Nieuw');
    Ini.WriteString('General', 'Extra', 'ja');
    Ini.WriteString('Level2', 'Duration', '60');
    Ini.WriteInteger('Level1', 'HighScore', 5);
  finally
    Ini.Free;
  end;

  CheckEq(ReadFile(DataFile), Origineel, 'de datamap mag niet veranderen');
  Verwacht :=
    '[General]' + CRLF +
    '; commentaar' + CRLF +
    'Naam = Nieuw' + CRLF +
    'Getal=99' + CRLF +
    'Quoted="  met spaties  "' + CRLF +
    'Hex=0x1F' + CRLF +
    'Extra=ja' + CRLF +
    CRLF +
    '[Level1]' + CRLF +
    'Duration=180' + CRLF +
    'HighScore=5' + CRLF +
    '; einde' + CRLF +
    '[Level2]' + CRLF +
    'Duration=60' + CRLF;
  CheckEq(ReadFile(SaveFile), Verwacht, 'overlaykopie na schrijven ter plekke');

  { een nieuw object leest de overlaykopie (via de schaduwmap) }
  Ini := TIniFile.Create(Path);
  try
    Check(Ini.ReadInteger('General', 'Getal', 0) = 99, 'lezen na schrijven ziet de overlay');
    Ini.DeleteKey('General', 'Extra');
    Ini.EraseSection('Level2');
  finally
    Ini.Free;
  end;
  Verwacht := StringReplace(Verwacht, 'Extra=ja' + CRLF, '', []);
  Verwacht := StringReplace(Verwacht, '[Level2]' + CRLF + 'Duration=60' + CRLF, '', []);
  CheckEq(ReadFile(SaveFile), Verwacht, 'DeleteKey en EraseSection');
  CheckEq(ReadFile(DataFile), Origineel, 'de datamap mag niet veranderen (2)');

  { lezen via de datamap zelf geeft ook de overlaykopie }
  CheckEq(ReadFile(ZMResolvePath(ZMDataDir + 'test.INI')), Verwacht, 'ZMResolvePath kiest de overlay');

  if Fails = 0 then WriteLn('test_ini: alles goed') else WriteLn('test_ini: ', Fails, ' fouten');
  if Fails > 0 then Halt(1);
end.

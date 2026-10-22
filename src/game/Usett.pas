unit Usett;

{ Game settings (ZoetermeerGame.ini / ZoetermeerLevels.ini), the level task and
  the running game status.
  Decompiled from ROS.exe v1.1, code 0047216C-00472E8B. }

{$I zm.inc}

interface

uses
  Classes;

type
  { VMT 004721B8, instance size $C.
    The number of houses and offices that must be built in a level. }
  TTask = class(TObject)
  private
    FHouses: Integer;              { +0x4 }
    FOffices: Integer;             { +0x8 }
  public
    constructor Create(AHouses, AOffices: Integer);
    procedure Add(Task: TTask);
    procedure Clear;
    property Houses: Integer read FHouses write FHouses;
    property Offices: Integer read FOffices write FOffices;
  end;

  { RTTI 004721C4 'TLevel', size $40. One [LevelN] section of ZoetermeerLevels.ini. }
  TLevel = record
    Uitleg: string;                { +0x00 'Uitleg' }
    Laag: TStringList;             { +0x04 'Laag'    (comma separated names) }
    Midden: TStringList;           { +0x08 'Midden' }
    Hoog: TStringList;             { +0x0C 'Hoog' }
    Kantoor: TStringList;          { +0x10 'Kantoor' }
    Duration: Integer;             { +0x14 'Duration' }
    Task: TTask;                   { +0x18 'Houses', 'Offices' }
    StartGeld: Integer;            { +0x1C 'StartGeld' }
    OpenWijk: Integer;             { +0x20 'openwijk' }
                                   { +0x24 (alignment) }
    HappyTreshold: Double;         { +0x28 'HappyTreshold' / 100 }
    PercKantoren: Double;          { +0x30 'PercKantoren' }
    Huisprijs: Integer;            { +0x38 'Huisprijs' }
                                   { +0x3C (alignment) }
  end;

  { VMT 0047223C, instance size $370. }
  TSettings = class(TObject)
  public
    GameIniFile: string;           { +0x004 <AppPath>ZoetermeerGame.ini }
    LevelsIniFile: string;         { +0x008 <AppPath><LevelsFile> }
    HighScore: Integer;            { +0x00C }
    Startgeld: Integer;            { +0x010 }
    NiveauTekst: string;           { +0x014 }
    NiveauKop: string;             { +0x018 }
    IntroTekst: string;            { +0x01C }
    IntroKop: string;              { +0x020 }
    AcceptabeleReistijd: Integer;  { +0x024 }
    Levels: array[0..11] of TLevel;   { +0x028 (RTTI 004721E0 '.3'); 1..11 are loaded }
    Groen: array[0..11] of Integer;   { +0x328 }
    MaxGroen: Integer;             { +0x358 }
    MaxOverlast: Integer;          { +0x35C }
    ShowAutos: Boolean;            { +0x360 }
    KantorenNaastSnelweg: Boolean;    { +0x361 }
    FabriekenNaastSnelweg: Boolean;   { +0x362 }
    HuizenNaastSnelweg: Boolean;      { +0x363 }
    TerminalsNaastSnelweg: Boolean;   { +0x364 }
    ScreenChangeLevel: Integer;    { +0x368 }
    AutosVisible: Boolean;         { +0x36C }
    KlaverbladAutosVisible: Boolean;  { +0x36D }
    constructor Create(LevelsFile: string);
    destructor Destroy; override;
    procedure SaveHighScore;
    procedure Load;
  end;

  { VMT 004722D4, instance size $20. }
  TStatus = class(TObject)
  private
    FScore: Integer;               { +0x04 }
    FGeld: Integer;                { +0x08 }
    FReserved0C: Integer;          { +0x0C never accessed }
    FOnChange: TNotifyEvent;       { +0x10 Code, +0x14 Data }
    FTask: TTask;                  { +0x18 houses/offices built in this level }
    FLevel: Integer;               { +0x1C }
  public
    constructor Create;
    procedure SetGeld(Value: Integer);
    property Score: Integer read FScore write FScore;
    property Geld: Integer read FGeld write SetGeld;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Task: TTask read FTask write FTask;
    property Level: Integer read FLevel write FLevel;
  end;

implementation

uses
  SysUtils, IniFiles, uString, uTool;

{ @004722DC }
constructor TSettings.Create(LevelsFile: string);
begin
  inherited Create;
  GameIniFile := AddPath(AppPath, 'ZoetermeerGame.ini');
  LevelsIniFile := AddPath(AppPath, LevelsFile);
  Load;
end;

{ @004723B8 }
destructor TSettings.Destroy;
begin
  SaveHighScore;
  inherited Destroy;
end;

{ @004723E4 }
procedure TSettings.SaveHighScore;
var
  Ini: TIniFile;
begin
  try
    Ini := TIniFile.Create(LevelsIniFile);
    Ini.WriteInteger('General', 'HighScore', HighScore);
    Ini.Free;
  except
  end;
end;

{ @00472514 }
procedure TSettings.Load;
var
  LevelsIni: TIniFile;   { EBP-4 }
  GameIni: TIniFile;     { EBP-0xC }
  I: Integer;
  Houses, Offices: Integer;
  S: string;
  Section: string;

  { @00472464 }
  function ReadList(Section, Ident: string): TStringList;
  var
    S, Item: string;
  begin
    S := LevelsIni.ReadString(Section, Ident, '');
    Result := TStringList.Create;
    while S <> '' do
    begin
      Item := SplitFirst(S, ',');
      Result.Add(Item);
    end;
  end;

begin
  GameIni := TIniFile.Create(GameIniFile);
  LevelsIni := TIniFile.Create(LevelsIniFile);

  I := 1;
  IntroTekst := '';
  repeat
    S := GameIni.ReadString('General', 'IntroTekst' + IntToStr(I), '<eoi>');
    if S <> '<eoi>' then
      IntroTekst := IntroTekst + ReplaceStr(S + ' ', '~', #13#10);
    Inc(I);
  until (S = '<eoi>') or (I > 100);
  IntroKop := GameIni.ReadString('General', 'IntroKop', 'Geen Intro KopTekst');

  I := 1;
  NiveauTekst := '';
  repeat
    S := GameIni.ReadString('General', 'NiveauTekst' + IntToStr(I), '<eoi>');
    if S <> '<eoi>' then
      NiveauTekst := NiveauTekst + ReplaceStr(S + ' ', '~', #13#10);
    Inc(I);
  until (S = '<eoi>') or (I > 100);
  NiveauKop := GameIni.ReadString('General', 'NiveauKop', 'Geen Niveau KopTekst');

  HighScore := LevelsIni.ReadInteger('General', 'HighScore', 0);
  MaxGroen := LevelsIni.ReadInteger('General', 'MaxGroen', 100);
  ScreenChangeLevel := LevelsIni.ReadInteger('General', 'ScreenChangeLevel', 1);
  AcceptabeleReistijd := LevelsIni.ReadInteger('General', 'AcceptabeleReistijd', 8);
  AutosVisible := LevelsIni.ReadBool('General', 'AutosVisible', False);
  KantorenNaastSnelweg := LevelsIni.ReadBool('General', 'KantorenNaastSnelwegToegestaan', False);
  FabriekenNaastSnelweg := LevelsIni.ReadBool('General', 'FabriekenNaastSnelwegToegestaan', False);
  HuizenNaastSnelweg := LevelsIni.ReadBool('General', 'HuizenNaastSnelwegToegestaan', False);
  TerminalsNaastSnelweg := LevelsIni.ReadBool('General', 'TerminalsNaastSnelwegToegestaan', False);
  KlaverbladAutosVisible := LevelsIni.ReadBool('General', 'KlaverbladAutosVisible', False);
  Startgeld := LevelsIni.ReadInteger('General', 'Startgeld', 1000);

  for I := 1 to 11 do
  begin
    Section := 'Level' + IntToStr(I);
    Groen[I] := LevelsIni.ReadInteger(Section, 'Groen', 10);
    with Levels[I] do
    begin
      Uitleg := LevelsIni.ReadString(Section, 'Uitleg', 'Geen Uitleg');
      Duration := LevelsIni.ReadInteger(Section, 'Duration', 3600);
      Houses := LevelsIni.ReadInteger(Section, 'Houses', 3600);
      Offices := LevelsIni.ReadInteger(Section, 'Offices', 3600);
      StartGeld := LevelsIni.ReadInteger(Section, 'StartGeld', 10000);
      OpenWijk := LevelsIni.ReadInteger(Section, 'openwijk', 0);
      HappyTreshold := LevelsIni.ReadInteger(Section, 'HappyTreshold', 0) / 100;
      Task := TTask.Create(Houses, Offices);
      Laag := ReadList(Section, 'Laag');
      Midden := ReadList(Section, 'Midden');
      Hoog := ReadList(Section, 'Hoog');
      Kantoor := ReadList(Section, 'Kantoor');
      PercKantoren := LevelsIni.ReadInteger(Section, 'PercKantoren', 50);
      Huisprijs := LevelsIni.ReadInteger(Section, 'Huisprijs', 200000);
    end;
  end;

  MaxOverlast := LevelsIni.ReadInteger('General', 'MaxOverlast', 10000);
  ShowAutos := LevelsIni.ReadBool('General', 'ShowAutos', True);
  GameIni.Free;
  LevelsIni.Free;
end;

{ @00472DA4 }
constructor TStatus.Create;
begin
  inherited Create;
  FOnChange := nil;
  FScore := 0;
  FGeld := 0;
end;

{ @00472DEC }
procedure TStatus.SetGeld(Value: Integer);
begin
  if Value <> FGeld then
  begin
    FGeld := Value;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

{ @00472E08 }
constructor TTask.Create(AHouses, AOffices: Integer);
begin
  { NOTE: no inherited Create in the original. }
  FHouses := AHouses;
  FOffices := AOffices;
end;

{ @00472E38 }
procedure TTask.Add(Task: TTask);
begin
  Inc(FHouses, Task.FHouses);
  Inc(FOffices, Task.FOffices);
end;

{ @00472E48 }
procedure TTask.Clear;
begin
  FHouses := 0;
  FOffices := 0;
end;

end.

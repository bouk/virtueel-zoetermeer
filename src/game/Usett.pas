unit Usett;

{ Spelinstellingen (ZoetermeerGame.ini / ZoetermeerLevels.ini), de niveau-opdracht en
  de status van het lopende spel.
  Gedecompileerd uit ROS.exe v1.1, code 0047216C-00472E8B. }

{$I zm.inc}

interface

uses
  Classes;

type
  { VMT 004721B8, instantiegrootte $C.
    Het aantal huizen en kantoren dat in een niveau gebouwd moet worden. }
  TTask = class(TObject)
  private
    FHuizen: Integer;              { +0x4 }
    FKantoren: Integer;             { +0x8 }
  public
    constructor Create(AHuizen, AKantoren: Integer);
    procedure Add(Andere: TTask);
    procedure Clear;
    property Woonhuizen: Integer read FHuizen write FHuizen;
    property Kantoorpanden: Integer read FKantoren write FKantoren;
  end;

  { RTTI 004721C4 'TNiveau', grootte $40. Eén [LevelN]-sectie van ZoetermeerLevels.ini. }
  TNiveau = record
    Uitleg: string;                { +0x00 'Uitleg' }
    Laag: TStringList;             { +0x04 'Laag'    (door komma's gescheiden namen) }
    Midden: TStringList;           { +0x08 'Midden' }
    Hoog: TStringList;             { +0x0C 'Hoog' }
    Kantoor: TStringList;          { +0x10 'Kantoor' }
    Duur: Integer;             { +0x14 'Duur' }
    Taak: TTask;                   { +0x18 'Woonhuizen', 'Kantoorpanden' }
    Startgeld: Integer;            { +0x1C 'Startgeld' }
    OpenWijk: Integer;             { +0x20 'openwijk' }
                                   { +0x24 (uitlijning) }
    TevredenDrempel: Double;         { +0x28 'TevredenDrempel' / 100 }
    PercKantoren: Double;          { +0x30 'PercKantoren' }
    Huisprijs: Integer;            { +0x38 'Huisprijs' }
                                   { +0x3C (uitlijning) }
  end;

  { VMT 0047223C, instantiegrootte $370. }
  TSettings = class(TObject)
  public
    SpelIniBestand: string;           { +0x004 <AppPad>ZoetermeerGame.ini }
    NiveauIniBestand: string;         { +0x008 <AppPad><LevelsFile> }
    HoogsteScore: Integer;            { +0x00C }
    Startgeld: Integer;            { +0x010 }
    NiveauTekst: string;           { +0x014 }
    NiveauKop: string;             { +0x018 }
    IntroTekst: string;            { +0x01C }
    IntroKop: string;              { +0x020 }
    AcceptabeleReistijd: Integer;  { +0x024 }
    Niveaus: array[0..11] of TNiveau;   { +0x028 (RTTI 004721E0 '.3'); 1..11 worden geladen }
    Groen: array[0..11] of Integer;   { +0x328 }
    MaxGroen: Integer;             { +0x358 }
    MaxOverlast: Integer;          { +0x35C }
    ToonAutos: Boolean;            { +0x360 }
    KantorenNaastSnelweg: Boolean;    { +0x361 }
    FabriekenNaastSnelweg: Boolean;   { +0x362 }
    HuizenNaastSnelweg: Boolean;      { +0x363 }
    TerminalsNaastSnelweg: Boolean;   { +0x364 }
    SchermWisselNiveau: Integer;    { +0x368 }
    AutosZichtbaar: Boolean;         { +0x36C }
    KlaverbladAutosZichtbaar: Boolean;  { +0x36D }
    constructor Create(LevelsBestand: string);
    destructor Destroy; override;
    procedure BewaarHoogsteScore;
    procedure Laden;
  end;

  { VMT 004722D4, instantiegrootte $20. }
  TStatus = class(TObject)
  private
    FScore: Integer;               { +0x04 }
    FGeld: Integer;                { +0x08 }
    FGereserveerd0C: Integer;          { +0x0C nooit benaderd }
    FOnChange: TNotifyEvent;       { +0x10 Code, +0x14 Data }
    FOpdracht: TTask;                  { +0x18 huizen/kantoren gebouwd in dit niveau }
    FNiveau: Integer;               { +0x1C }
  public
    constructor Create;
    procedure ZetGeld(Waarde: Integer);
    property Score: Integer read FScore write FScore;
    property Geld: Integer read FGeld write ZetGeld;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property Taak: TTask read FOpdracht write FOpdracht;
    property Speelniveau: Integer read FNiveau write FNiveau;
  end;

implementation

uses
  SysUtils, IniFiles, uString, uTool;

{ @004722DC }
constructor TSettings.Create(LevelsBestand: string);
begin
  inherited Create;
  SpelIniBestand := VoegPadToe(AppPad, 'ZoetermeerGame.ini');
  NiveauIniBestand := VoegPadToe(AppPad, LevelsBestand);
  Laden;
end;

{ @004723B8 }
destructor TSettings.Destroy;
begin
  BewaarHoogsteScore;
  inherited Destroy;
end;

{ @004723E4 }
procedure TSettings.BewaarHoogsteScore;
var
  Ini: TIniFile;
begin
  try
    Ini := TIniFile.Create(NiveauIniBestand);
    Ini.WriteInteger('General', 'HighScore', HoogsteScore);
    Ini.Free;
  except
  end;
end;

{ @00472514 }
procedure TSettings.Laden;
var
  NiveauIni: TIniFile;   { EBP-4 }
  SpelIni: TIniFile;     { EBP-0xC }
  I: Integer;
  Huizen, Kantoren: Integer;
  S: string;
  Sectie: string;

  { @00472464 }
  function LeesLijst(Sectie, Sleutel: string): TStringList;
  var
    S, Item: string;
  begin
    S := NiveauIni.ReadString(Sectie, Sleutel, '');
    Result := TStringList.Create;
    while S <> '' do
    begin
      Item := SplitsEerste(S, ',');
      Result.Add(Item);
    end;
  end;

begin
  SpelIni := TIniFile.Create(SpelIniBestand);
  NiveauIni := TIniFile.Create(NiveauIniBestand);

  I := 1;
  IntroTekst := '';
  repeat
    S := SpelIni.ReadString('General', 'IntroTekst' + IntToStr(I), '<eoi>');
    if S <> '<eoi>' then
      IntroTekst := IntroTekst + VervangStr(S + ' ', '~', #13#10);
    Inc(I);
  until (S = '<eoi>') or (I > 100);
  IntroKop := SpelIni.ReadString('General', 'IntroKop', 'Geen Intro KopTekst');

  I := 1;
  NiveauTekst := '';
  repeat
    S := SpelIni.ReadString('General', 'NiveauTekst' + IntToStr(I), '<eoi>');
    if S <> '<eoi>' then
      NiveauTekst := NiveauTekst + VervangStr(S + ' ', '~', #13#10);
    Inc(I);
  until (S = '<eoi>') or (I > 100);
  NiveauKop := SpelIni.ReadString('General', 'NiveauKop', 'Geen Niveau KopTekst');

  HoogsteScore := NiveauIni.ReadInteger('General', 'HighScore', 0);
  MaxGroen := NiveauIni.ReadInteger('General', 'MaxGroen', 100);
  SchermWisselNiveau := NiveauIni.ReadInteger('General', 'ScreenChangeLevel', 1);
  AcceptabeleReistijd := NiveauIni.ReadInteger('General', 'AcceptabeleReistijd', 8);
  AutosZichtbaar := NiveauIni.ReadBool('General', 'AutosVisible', False);
  KantorenNaastSnelweg := NiveauIni.ReadBool('General', 'KantorenNaastSnelwegToegestaan', False);
  FabriekenNaastSnelweg := NiveauIni.ReadBool('General', 'FabriekenNaastSnelwegToegestaan', False);
  HuizenNaastSnelweg := NiveauIni.ReadBool('General', 'HuizenNaastSnelwegToegestaan', False);
  TerminalsNaastSnelweg := NiveauIni.ReadBool('General', 'TerminalsNaastSnelwegToegestaan', False);
  KlaverbladAutosZichtbaar := NiveauIni.ReadBool('General', 'KlaverbladAutosVisible', False);
  Startgeld := NiveauIni.ReadInteger('General', 'Startgeld', 1000);

  for I := 1 to 11 do
  begin
    Sectie := 'Level' + IntToStr(I);
    Groen[I] := NiveauIni.ReadInteger(Sectie, 'Groen', 10);
    with Niveaus[I] do
    begin
      Uitleg := NiveauIni.ReadString(Sectie, 'Uitleg', 'Geen Uitleg');
      Duur := NiveauIni.ReadInteger(Sectie, 'Duration', 3600);
      Huizen := NiveauIni.ReadInteger(Sectie, 'Houses', 3600);
      Kantoren := NiveauIni.ReadInteger(Sectie, 'Offices', 3600);
      Startgeld := NiveauIni.ReadInteger(Sectie, 'StartGeld', 10000);
      OpenWijk := NiveauIni.ReadInteger(Sectie, 'openwijk', 0);
      TevredenDrempel := NiveauIni.ReadInteger(Sectie, 'HappyTreshold', 0) / 100;
      Taak := TTask.Create(Huizen, Kantoren);
      Laag := LeesLijst(Sectie, 'Laag');
      Midden := LeesLijst(Sectie, 'Midden');
      Hoog := LeesLijst(Sectie, 'Hoog');
      Kantoor := LeesLijst(Sectie, 'Kantoor');
      PercKantoren := NiveauIni.ReadInteger(Sectie, 'PercKantoren', 50);
      Huisprijs := NiveauIni.ReadInteger(Sectie, 'Huisprijs', 200000);
    end;
  end;

  MaxOverlast := NiveauIni.ReadInteger('General', 'MaxOverlast', 10000);
  ToonAutos := NiveauIni.ReadBool('General', 'ShowAutos', True);
  SpelIni.Free;
  NiveauIni.Free;
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
procedure TStatus.ZetGeld(Waarde: Integer);
begin
  if Waarde <> FGeld then
  begin
    FGeld := Waarde;
    if Assigned(FOnChange) then
      FOnChange(Self);
  end;
end;

{ @00472E08 }
constructor TTask.Create(AHuizen, AKantoren: Integer);
begin
  { LET OP: geen inherited Create in het origineel. }
  FHuizen := AHuizen;
  FKantoren := AKantoren;
end;

{ @00472E38 }
procedure TTask.Add(Andere: TTask);
begin
  Inc(FHuizen, Andere.FHuizen);
  Inc(FKantoren, Andere.FKantoren);
end;

{ @00472E48 }
procedure TTask.Clear;
begin
  FHuizen := 0;
  FKantoren := 0;
end;

end.

unit ZMHarness;

{ Testharnas voor de portable build.

  Twee manieren van werken:

  * Script (differentiële tests): ZM_TESTSCRIPT=<bestand.zms> wordt in zijn geheel ingelezen en
    afgespeeld, precies zoals tools/orig_probe.py dat tegen het origineel doet; daarna stopt
    het programma. Dumps en screenshots gaan naar ZM_TESTOUT. Zie docs/DIFFTEST.md.

  * Live (een agent die het spel speelt, tools/speel.py): ZM_BESTURING=<bestand> wordt
    voortdurend gevolgd; nieuwe regels worden meteen uitgevoerd. Na elke regel schrijft het
    harnas het regelnummer naar <ZM_TESTOUT>/bevestigd, en elke seconde een teken van leven
    naar <ZM_TESTOUT>/hartslag (voor het opsporen van een hangend spel).

  Commando's (één per regel, # begint commentaar):
    wait <ms> | move <x> <y> | click <x> <y> [right] | key <naam> | seed <n> |
    dump <naam> | sprites <naam> | shot <naam> | stop

  Het harnas draait vanuit ZMIdleHook (bij elke ronde van de berichtenlus, ook binnen modale
  lussen) en geeft invoer door via ZMWin, alsof die van de backend kwam. }

{$MODE DELPHI}{$H+}

interface

implementation

uses
  SysUtils, Classes, Windows, ZMPlatform, ZMWin, ZMRandom, Fmain, Uworld, uSprite;

type
  TActieSoort = (asBeweeg, asDruk, asLos, asToets, asTeken, asSeed, asDump, asFoto, asSprites,
    asBevestig, asStop);
  TActie = record
    Tijd: Int64;            { ms sinds de start van het harnas }
    Soort: TActieSoort;
    X, Y, Knop: Integer;
    Arg: string;
  end;

const
  GeenSeed = Low(Int64);

var
  Acties: array of TActie;
  Volgende: Integer;
  StartTijd: Int64 = -1;
  UitMap: string;
  OpenstaandeSeed: Int64 = GeenSeed;

  { live-modus }
  BesturingsBestand: string;
  VerwerkteRegels: Integer;
  LaatsteControle, LaatsteHartslag: Int64;
  Tikken: Int64;

procedure Voeg(Tijd: Int64; Soort: TActieSoort; X, Y, Knop: Integer; const Arg: string);
var
  N: Integer;
begin
  N := Length(Acties);
  SetLength(Acties, N + 1);
  Acties[N].Tijd := Tijd;
  Acties[N].Soort := Soort;
  Acties[N].X := X;
  Acties[N].Y := Y;
  Acties[N].Knop := Knop;
  Acties[N].Arg := Arg;
end;

{ xdotool-toetsnamen uit de scripts -> Windows virtual keys of tekens }
procedure VoegToets(Tijd: Int64; const Naam: string);
const
  Namen: array[0..9] of string = ('Return', 'Escape', 'Left', 'Right', 'Up', 'Down',
    'Tab', 'BackSpace', 'Delete', 'space');
  Codes: array[0..9] of Word = (VK_RETURN, VK_ESCAPE, VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN,
    VK_TAB, VK_BACK, VK_DELETE, VK_SPACE);
var
  I: Integer;
begin
  if Naam = 'plus' then
    Voeg(Tijd, asTeken, 0, 0, 0, '+')
  else if Naam = 'minus' then
    Voeg(Tijd, asTeken, 0, 0, 0, '-')
  else if Length(Naam) = 1 then
    Voeg(Tijd, asTeken, 0, 0, 0, Naam)
  else
  begin
    for I := Low(Namen) to High(Namen) do
      if Naam = Namen[I] then
      begin
        Voeg(Tijd, asToets, Codes[I], 1, 0, '');
        Voeg(Tijd + 50, asToets, Codes[I], 0, 0, '');
        Exit;
      end;
    raise Exception.CreateFmt('harnas: onbekende toets %s', [Naam]);
  end;
end;

{ Zet één scriptregel om in getimede basisacties vanaf tijdstip T (dat schuift op).
  Een klik nadert het doel van 60 px links in stappen van 3 px (30 ms ertussen), wacht
  300 ms, drukt, en laat 150 ms later los, net als tools/orig_probe.py. }
procedure VerwerkRegel(Regel: string; var T: Int64);
var
  F: TStringList;
  J, X, Y, Knop: Integer;
begin
  if Pos('#', Regel) > 0 then
    Regel := Copy(Regel, 1, Pos('#', Regel) - 1);
  F := TStringList.Create;
  try
    ExtractStrings([' ', #9], [], PChar(Regel), F);
    if F.Count = 0 then
      Exit;
    if F[0] = 'wait' then
      Inc(T, StrToInt(F[1]))
    else if F[0] = 'move' then
      Voeg(T, asBeweeg, StrToInt(F[1]), StrToInt(F[2]), 0, '')
    else if F[0] = 'click' then
    begin
      X := StrToInt(F[1]);
      Y := StrToInt(F[2]);
      Knop := 1;
      if (F.Count > 3) and (F[3] = 'right') then
        Knop := 2;
      for J := 20 downto 0 do
      begin
        Voeg(T, asBeweeg, X - 3 * J, Y, 0, '');
        Inc(T, 30);
      end;
      Inc(T, 300);
      Voeg(T, asDruk, X, Y, Knop, '');
      Inc(T, 150);
      Voeg(T, asLos, X, Y, Knop, '');
    end
    else if F[0] = 'key' then
    begin
      VoegToets(T, F[1]);
      Inc(T, 100);
    end
    else if F[0] = 'seed' then
      Voeg(T, asSeed, StrToInt(F[1]), 0, 0, '')
    else if F[0] = 'dump' then
      Voeg(T, asDump, 0, 0, 0, F[1])
    else if F[0] = 'sprites' then
      Voeg(T, asSprites, 0, 0, 0, F[1])
    else if F[0] = 'shot' then
      Voeg(T, asFoto, 0, 0, 0, F[1])
    else if F[0] = 'stop' then
      Voeg(T, asStop, 0, 0, 0, '')
    else
      raise Exception.CreateFmt('harnas: onbekend commando: %s', [Regel]);
  finally
    F.Free;
  end;
end;

procedure LeesScript(const Bestand: string);
var
  Regels: TStringList;
  I: Integer;
  T: Int64;
begin
  Regels := TStringList.Create;
  try
    Regels.LoadFromFile(Bestand);
    T := 0;
    for I := 0 to Regels.Count - 1 do
      VerwerkRegel(Regels[I], T);
    Voeg(T + 500, asStop, 0, 0, 0, '');
  finally
    Regels.Free;
  end;
end;

{ Zelfde formaat als state_text in tools/orig_probe.py }
function Toestand: string;
var
  S: TStringList;
  X, Y: Integer;
  W: TWorld;
  C: TCell;
  Opmaak: TFormatSettings;

  function Streep(const V: string): string;
  begin
    if V = '' then Result := '-' else Result := V;
  end;

begin
  Opmaak := DefaultFormatSettings;
  Opmaak.DecimalSeparator := '.';
  W := frmMain.FWereld;
  S := TStringList.Create;
  try
    S.Add(Format('level %d', [frmMain.FStatus.Speelniveau]));
    S.Add(Format('geld %d', [frmMain.FStatus.Geld]));
    S.Add(Format('score %d', [frmMain.FStatus.Score]));
    S.Add(Format('reistijd %.6f', [W.Reistijd], Opmaak));
    for X := 0 to WereldGrootte - 1 do
      for Y := 0 to WereldGrootte - 1 do
      begin
        C := W.Cells[X, Y];
        S.Add(Format('cell %d %d %s %s %d %d %d', [X, Y, Streep(C.Inhoud), Streep(C.Param),
          C.Wijk, C.Wegen, Ord(C.Bereikbaar)]));
      end;
    S.LineBreak := #10;
    Result := S.Text;
  finally
    S.Free;
  end;
end;

{ Alleen voor de port, om te debuggen: alle sprites van het hoofdformulier }
function SpritesTekst: string;
var
  S: TStringList;
  I: Integer;
  Sp: TSprite;
  Beelden: Integer;
begin
  S := TStringList.Create;
  try
    for I := 0 to frmMain.ComponentCount - 1 do
      if frmMain.Components[I] is TSprite then
      begin
        Sp := TSprite(frmMain.Components[I]);
        Beelden := -1;
        if Sp.FrameList <> nil then
          Beelden := Sp.FrameList.Count;
        S.Add(Format('%s visible=%d pos=%d,%d frame=%s index=%d frames=%d',
          [Sp.Name, Ord(Sp.Visible), Sp.Left, Sp.Top, Sp.CurrentFrame, Sp.FrameIndex, Beelden]));
      end;
    S.LineBreak := #10;
    Result := S.Text;
  finally
    S.Free;
  end;
end;

procedure SchrijfBestand(const Naam, Tekst: string);
var
  F: TFileStream;
  Tijdelijk: string;
begin
  { eerst naar een tijdelijk bestand en dan hernoemen: lezers zien nooit een half bestand }
  Tijdelijk := Naam + '.tmp';
  F := TFileStream.Create(Tijdelijk, fmCreate);
  try
    if Tekst <> '' then
      F.WriteBuffer(Tekst[1], Length(Tekst));
  finally
    F.Free;
  end;
  DeleteFile(Naam);
  RenameFile(Tijdelijk, Naam);
end;

function UitPad(const Naam: string): string;
begin
  Result := IncludeTrailingPathDelimiter(UitMap) + Naam;
end;

{ Live-modus: nieuwe regels uit het besturingsbestand inplannen }
procedure VolgBesturing(Nu: Int64);
var
  Regels: TStringList;
  T: Int64;
begin
  if not FileExists(BesturingsBestand) then
    Exit;
  Regels := TStringList.Create;
  try
    Regels.LoadFromFile(BesturingsBestand);
    while VerwerkteRegels < Regels.Count do
    begin
      { een regel schuift pas aan als alles ervoor gedaan is }
      T := Nu - StartTijd;
      if (Volgende < Length(Acties)) and (Acties[High(Acties)].Tijd > T) then
        T := Acties[High(Acties)].Tijd;
      VerwerkRegel(Regels[VerwerkteRegels], T);
      Inc(VerwerkteRegels);
      Voeg(T, asBevestig, VerwerkteRegels, 0, 0, '');
    end;
  finally
    Regels.Free;
  end;
end;

procedure Tik;
var
  Nu: Int64;
  A: TActie;
begin
  Nu := GetTickCount64;
  if StartTijd < 0 then
    StartTijd := Nu;
  Inc(Tikken);
  if BesturingsBestand <> '' then
  begin
    if Nu - LaatsteControle >= 50 then
    begin
      LaatsteControle := Nu;
      VolgBesturing(Nu);
    end;
    if Nu - LaatsteHartslag >= 1000 then
    begin
      LaatsteHartslag := Nu;
      SchrijfBestand(UitPad('hartslag'), Format('%d %d'#10, [Nu - StartTijd, Tikken]));
    end;
  end;
  while (Volgende < Length(Acties)) and (Nu - StartTijd >= Acties[Volgende].Tijd) do
  begin
    A := Acties[Volgende];
    Inc(Volgende);
    case A.Soort of
      asBeweeg: ZMInjectMouse(A.X, A.Y, 0, False);
      asDruk:
        begin
          { een 'seed' geldt vlak voor de volgende muisklik (zie docs/DIFFTEST.md) }
          if OpenstaandeSeed <> GeenSeed then
          begin
            ZMRandom.RandSeed := OpenstaandeSeed;
            OpenstaandeSeed := GeenSeed;
          end;
          ZMInjectMouse(A.X, A.Y, A.Knop, True);
        end;
      asLos: ZMInjectMouse(A.X, A.Y, A.Knop, False);
      asToets: ZMInjectKey(A.X, A.Y <> 0);
      asTeken: ZMInjectChar(A.Arg[1]);
      asSeed: OpenstaandeSeed := A.X;
      asDump: SchrijfBestand(UitPad(A.Arg + '.state'), Toestand);
      asSprites: SchrijfBestand(UitPad(A.Arg + '.sprites'), SpritesTekst);
      asFoto: ZMSaveScreenshot(UitPad(A.Arg + '.png'));
      asBevestig: SchrijfBestand(UitPad('bevestigd'), IntToStr(A.X) + #10);
      asStop: Halt(0);
    end;
  end;
end;

initialization
  UitMap := GetEnvironmentVariable('ZM_TESTOUT');
  if UitMap = '' then
    UitMap := '.';
  if GetEnvironmentVariable('ZM_TESTSCRIPT') <> '' then
  begin
    ForceDirectories(UitMap);
    LeesScript(GetEnvironmentVariable('ZM_TESTSCRIPT'));
    ZMIdleHook := Tik;
  end
  else if GetEnvironmentVariable('ZM_BESTURING') <> '' then
  begin
    ForceDirectories(UitMap);
    BesturingsBestand := GetEnvironmentVariable('ZM_BESTURING');
    ZMIdleHook := Tik;
  end;
end.

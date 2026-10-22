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
  naar ZMSchrijfPad (de overlay van ZMData), nooit in de datamap. }

{$MODE DELPHI}{$H+}

interface

function ZMLeesPrivateProfileString(SectieNaam, SleutelNaam, Standaard: PAnsiChar;
  Resultaat: PAnsiChar; Grootte: LongWord; Bestandsnaam: PAnsiChar): LongWord;
function ZMSchrijfPrivateProfileString(SectieNaam, SleutelNaam, NieuweWaarde,
  Bestandsnaam: PAnsiChar): Boolean;
function ZMLeesPrivateProfileGetal(SectieNaam, SleutelNaam: PAnsiChar; Standaardgetal: Integer;
  Bestandsnaam: PAnsiChar): LongWord;

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

function BestandsGrootte(const Pad: string): Int64;
var
  Zoekrecord: TSearchRec;
begin
  Result := -1;
  if FindFirst(Pad, faAnyFile, Zoekrecord) = 0 then
  begin
    Result := Zoekrecord.Size;
    FindClose(Zoekrecord);
  end;
end;

function OplosNaam(Bestandsnaam: PAnsiChar): string;
begin
  Result := ZMOplosPad(StrPas(Bestandsnaam));
end;

procedure SplitsRegels(const Gegevens: string; Profiel: TProfileFile);
var
  Index, Startpositie: Integer;
  Regel: string;
begin
  Profiel.Lines.Clear;
  Profiel.EOL := #13#10;
  Profiel.FinalEOL := True;
  if Gegevens = '' then Exit;
  if (Pos(#10, Gegevens) > 0) and (Pos(#13#10, Gegevens) = 0) then Profiel.EOL := #10;
  Startpositie := 1;
  for Index := 1 to Length(Gegevens) do
    if Gegevens[Index] = #10 then
    begin
      Regel := Copy(Gegevens, Startpositie, Index - Startpositie);
      if (Regel <> '') and (Regel[Length(Regel)] = #13) then SetLength(Regel, Length(Regel) - 1);
      Profiel.Lines.Add(Regel);
      Startpositie := Index + 1;
    end;
  Profiel.FinalEOL := Startpositie > Length(Gegevens);
  if not Profiel.FinalEOL then
  begin
    Regel := Copy(Gegevens, Startpositie, MaxInt);
    if (Regel <> '') and (Regel[Length(Regel)] = #13) then SetLength(Regel, Length(Regel) - 1);
    Profiel.Lines.Add(Regel);
  end;
end;

function LeesHeel(const Pad: string; out Inhoud: string): Boolean;
var
  Stroom: TFileStream;
begin
  Inhoud := '';
  Result := False;
  if not FileExists(Pad) then Exit;
  try
    Stroom := TFileStream.Create(Pad, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Inhoud, Stroom.Size);
      if Stroom.Size > 0 then Stroom.ReadBuffer(Inhoud[1], Stroom.Size);
      Result := True;
    finally
      Stroom.Free;
    end;
  except
    Inhoud := '';
    Result := False;
  end;
end;

{ Het bestand uit de cache, of opnieuw ingelezen als het op schijf veranderd is.
  Een ontbrekend bestand geeft een leeg TProfileFile (IsAanwezig = False). }
function Laad(const Pad: string; out Bestaat: Boolean): TProfileFile;
var
  Index: Integer;
  Leeftijd: LongInt;
  Grootte: Int64;
  Gegevens: string;
begin
  if Cache = nil then
  begin
    Cache := TStringList.Create;
    Cache.Sorted := True;
    Cache.OwnsObjects := True;
  end;
  Bestaat := FileExists(Pad);
  Leeftijd := FileAge(Pad);
  Grootte := BestandsGrootte(Pad);
  Index := Cache.IndexOf(Pad);
  if Index >= 0 then
  begin
    Result := TProfileFile(Cache.Objects[Index]);
    if Bestaat and (Result.Stamp = Leeftijd) and (Result.Size = Grootte) then Exit;
    Cache.Delete(Index);
  end;
  Result := TProfileFile.Create;
  Result.Path := Pad;
  Result.Stamp := Leeftijd;
  Result.Size := Grootte;
  if Bestaat and LeesHeel(Pad, Gegevens) then SplitsRegels(Gegevens, Result);
  Cache.AddObject(Pad, Result);
end;

procedure Vergeet(const Pad: string);
var
  Index: Integer;
begin
  if Cache = nil then Exit;
  Index := Cache.IndexOf(Pad);
  if Index >= 0 then Cache.Delete(Index);
end;

{ ---------------------------------------------------------------- regels ontleden }

const
  Witruimte = [' ', #9];

function VerwijderWitruimte(const Tekst: string): string;
var
  Eerste, Laatste: Integer;
begin
  Eerste := 1;
  Laatste := Length(Tekst);
  while (Eerste <= Laatste) and (Tekst[Eerste] in Witruimte) do Inc(Eerste);
  while (Laatste >= Eerste) and (Tekst[Laatste] in Witruimte) do Dec(Laatste);
  Result := Copy(Tekst, Eerste, Laatste - Eerste + 1);
end;

{ True als de regel een sectiekop is; Name krijgt de naam tussen de haken. }
function IsSectie(const Regel: string; out Naam: string): Boolean;
var
  Tekst: string;
  Positie: Integer;
begin
  Tekst := VerwijderWitruimte(Regel);
  Result := (Tekst <> '') and (Tekst[1] = '[');
  if not Result then Exit;
  Positie := Pos(']', Tekst);
  if Positie = 0 then Positie := Length(Tekst) + 1;
  Naam := VerwijderWitruimte(Copy(Tekst, 2, Positie - 2));
end;

{ True als de regel een sleutel is (geen sectie, commentaar of lege regel). }
function IsSleutel(const Regel: string; out Naam, Waarde: string; out HeeftWaarde: Boolean): Boolean;
var
  Tekst: string;
  Positie: Integer;
begin
  Tekst := VerwijderWitruimte(Regel);
  Result := (Tekst <> '') and (Tekst[1] <> '[') and (Tekst[1] <> ';');
  if not Result then Exit;
  Positie := Pos('=', Tekst);
  HeeftWaarde := Positie > 0;
  if HeeftWaarde then
  begin
    Naam := VerwijderWitruimte(Copy(Tekst, 1, Positie - 1));
    Waarde := VerwijderWitruimte(Copy(Tekst, Positie + 1, MaxInt));
  end
  else
  begin
    Naam := Tekst;
    Waarde := '';
  end;
end;

function ZonderAanhalingen(const Tekst: string): string;
begin
  if (Length(Tekst) >= 2) and (Tekst[1] in ['"', '''']) and (Tekst[Length(Tekst)] = Tekst[1]) then
    Result := Copy(Tekst, 2, Length(Tekst) - 2)
  else
    Result := Tekst;
end;

{ Index van de eerste sectiekop met deze naam vanaf regel From, of -1. }
function ZoekSectie(Profiel: TProfileFile; const Sectie: string; Vanaf: Integer): Integer;
var
  Index: Integer;
  Naam: string;
begin
  for Index := Vanaf to Profiel.Lines.Count - 1 do
    if IsSectie(Profiel.Lines[Index], Naam) and SameText(Naam, Sectie) then Exit(Index);
  Result := -1;
end;

{ Eerste regel na de sectie die op regel Head begint (de volgende kop of het einde). }
function SectieEinde(Profiel: TProfileFile; Kop: Integer): Integer;
var
  Naam: string;
begin
  Result := Kop + 1;
  while (Result < Profiel.Lines.Count) and not IsSectie(Profiel.Lines[Result], Naam) do Inc(Result);
end;

{ Regelnummer van de sleutel in (een van de secties met naam) Section, of -1. }
function ZoekSleutel(Profiel: TProfileFile; const Sectie, Sleutel: string): Integer;
var
  Kop, Index: Integer;
  Naam, Waarde: string;
  HeeftWaarde: Boolean;
begin
  Kop := ZoekSectie(Profiel, Sectie, 0);
  while Kop >= 0 do
  begin
    Index := Kop + 1;
    while (Index < Profiel.Lines.Count) and not IsSectie(Profiel.Lines[Index], Naam) do
    begin
      if IsSleutel(Profiel.Lines[Index], Naam, Waarde, HeeftWaarde) and SameText(Naam, Sleutel) then Exit(Index);
      Inc(Index);
    end;
    Kop := ZoekSectie(Profiel, Sectie, Index);
  end;
  Result := -1;
end;

{ ---------------------------------------------------------------- lezen }

{ Kopieert een lijst van namen (elk afgesloten met #0, plus een extra #0) naar de
  buffer, met de afkapregels van Windows: past de lijst niet, dan eindigt de buffer op
  twee nullen en is het resultaat nSize - 2. }
function KopieerLijst(Namen: TStringList; Buffer: PAnsiChar; Grootte: LongWord): LongWord;
var
  Index, Teller: Integer;
  Positie: LongWord;
  Tekst: string;
begin
  Positie := 0;
  Result := 0;
  if Grootte < 2 then
  begin
    if Grootte = 1 then Buffer[0] := #0;
    Exit;
  end;
  for Index := 0 to Namen.Count - 1 do
  begin
    Tekst := Namen[Index];
    for Teller := 1 to Length(Tekst) + 1 do
    begin
      if Positie >= Grootte - 2 then
      begin
        Buffer[Grootte - 2] := #0;
        Buffer[Grootte - 1] := #0;
        Exit(Grootte - 2);
      end;
      if Teller <= Length(Tekst) then Buffer[Positie] := Tekst[Teller] else Buffer[Positie] := #0;
      Inc(Positie);
    end;
  end;
  Buffer[Positie] := #0;
  if Positie = 0 then Buffer[1] := #0;
  Result := Positie;
end;

function KopieerWaarde(const Tekst: string; Buffer: PAnsiChar; Grootte: LongWord): LongWord;
begin
  Result := 0;
  if Grootte = 0 then Exit;
  if LongWord(Length(Tekst)) >= Grootte then
  begin
    Move(PAnsiChar(Tekst)^, Buffer^, Grootte - 1);
    Buffer[Grootte - 1] := #0;
    Exit(Grootte - 1);
  end;
  if Tekst <> '' then Move(PAnsiChar(Tekst)^, Buffer^, Length(Tekst));
  Buffer[Length(Tekst)] := #0;
  Result := Length(Tekst);
end;

function ZMLeesPrivateProfileString(SectieNaam, SleutelNaam, Standaard: PAnsiChar;
  Resultaat: PAnsiChar; Grootte: LongWord; Bestandsnaam: PAnsiChar): LongWord;
var
  Profiel: TProfileFile;
  Bestaat, HeeftWaarde: Boolean;
  Namen: TStringList;
  Index, Kop: Integer;
  Naam, Waarde, Standaardtekst: string;
begin
  Result := 0;
  if (Resultaat = nil) or (Grootte = 0) then Exit;
  { Windows haalt spaties achteraan de standaardwaarde weg }
  if Standaard <> nil then Standaardtekst := StrPas(Standaard) else Standaardtekst := '';
  while (Standaardtekst <> '') and (Standaardtekst[Length(Standaardtekst)] = ' ') do SetLength(Standaardtekst, Length(Standaardtekst) - 1);
  if Bestandsnaam = nil then Exit(KopieerWaarde(Standaardtekst, Resultaat, Grootte));
  Profiel := Laad(OplosNaam(Bestandsnaam), Bestaat);
  if SectieNaam = nil then
  begin
    { alle sectienamen }
    Namen := TStringList.Create;
    try
      for Index := 0 to Profiel.Lines.Count - 1 do
        if IsSectie(Profiel.Lines[Index], Naam) then Namen.Add(Naam);
      Result := KopieerLijst(Namen, Resultaat, Grootte);
    finally
      Namen.Free;
    end;
    Exit;
  end;
  if SleutelNaam = nil then
  begin
    { alle sleutels van de sectie }
    Namen := TStringList.Create;
    try
      Kop := ZoekSectie(Profiel, StrPas(SectieNaam), 0);
      while Kop >= 0 do
      begin
        Index := Kop + 1;
        while (Index < Profiel.Lines.Count) and not IsSectie(Profiel.Lines[Index], Naam) do
        begin
          if IsSleutel(Profiel.Lines[Index], Naam, Waarde, HeeftWaarde) then Namen.Add(Naam);
          Inc(Index);
        end;
        Kop := ZoekSectie(Profiel, StrPas(SectieNaam), Index);
      end;
      Result := KopieerLijst(Namen, Resultaat, Grootte);
    finally
      Namen.Free;
    end;
    Exit;
  end;
  Index := ZoekSleutel(Profiel, StrPas(SectieNaam), StrPas(SleutelNaam));
  if (Index >= 0) and IsSleutel(Profiel.Lines[Index], Naam, Waarde, HeeftWaarde) and HeeftWaarde then
    Result := KopieerWaarde(ZonderAanhalingen(Waarde), Resultaat, Grootte)
  else
    Result := KopieerWaarde(Standaardtekst, Resultaat, Grootte);
end;

function ZMLeesPrivateProfileGetal(SectieNaam, SleutelNaam: PAnsiChar; Standaardgetal: Integer;
  Bestandsnaam: PAnsiChar): LongWord;
var
  Buffer: array[0..255] of AnsiChar;
  Tekst: string;
  Index, Waarde: Integer;
  Negatief: Boolean;
begin
  { zoals Windows: de cijfers aan het begin tellen, de rest wordt genegeerd }
  ZMLeesPrivateProfileString(SectieNaam, SleutelNaam, '', Buffer, SizeOf(Buffer), Bestandsnaam);
  Tekst := VerwijderWitruimte(StrPas(Buffer));
  if Tekst = '' then Exit(LongWord(Standaardgetal));
  Index := 1;
  Negatief := False;
  if Tekst[1] in ['-', '+'] then
  begin
    Negatief := Tekst[1] = '-';
    Inc(Index);
  end;
  Waarde := 0;
  while (Index <= Length(Tekst)) and (Tekst[Index] in ['0'..'9']) do
  begin
    Waarde := Waarde * 10 + Ord(Tekst[Index]) - Ord('0');
    Inc(Index);
  end;
  if Negatief then Waarde := -Waarde;
  Result := LongWord(Waarde);
end;

{ ---------------------------------------------------------------- schrijven }

function Bewaar(Profiel: TProfileFile; const LeesPad: string): Boolean;
var
  Doel, Gegevens: string;
  Index: Integer;
  Stroom: TFileStream;
begin
  Result := False;
  Gegevens := '';
  for Index := 0 to Profiel.Lines.Count - 1 do
  begin
    Gegevens := Gegevens + Profiel.Lines[Index];
    if (Index < Profiel.Lines.Count - 1) or Profiel.FinalEOL then Gegevens := Gegevens + Profiel.EOL;
  end;
  Doel := ZMSchrijfPad(LeesPad);
  try
    Stroom := TFileStream.Create(Doel, fmCreate);
    try
      if Gegevens <> '' then Stroom.WriteBuffer(Gegevens[1], Length(Gegevens));
    finally
      Stroom.Free;
    end;
    Result := True;
  except
    Result := False;
  end;
  Vergeet(LeesPad);
  Vergeet(Doel);
end;

function ZMSchrijfPrivateProfileString(SectieNaam, SleutelNaam, NieuweWaarde,
  Bestandsnaam: PAnsiChar): Boolean;
var
  Profiel: TProfileFile;
  Pad, Sectie, Naam, Nieuweregel, Waarde: string;
  Bestaat, HeeftWaarde: Boolean;
  Kop, Einde, Index, Laatste: Integer;
  Gewijzigd: Boolean;
begin
  { (nil, nil, nil): de cache legen; er is niets uit te stellen }
  if (SectieNaam = nil) and (SleutelNaam = nil) and (NieuweWaarde = nil) then
  begin
    if Cache <> nil then Cache.Clear;
    Exit(True);
  end;
  Result := False;
  if (SectieNaam = nil) or (Bestandsnaam = nil) then Exit;
  Pad := OplosNaam(Bestandsnaam);
  Profiel := Laad(Pad, Bestaat);
  Sectie := StrPas(SectieNaam);
  Gewijzigd := False;
  if SleutelNaam = nil then
  begin
    { hele sectie verwijderen (kop en alle regels tot de volgende kop) }
    Kop := ZoekSectie(Profiel, Sectie, 0);
    while Kop >= 0 do
    begin
      Einde := SectieEinde(Profiel, Kop);
      for Index := Einde - 1 downto Kop do Profiel.Lines.Delete(Index);
      Gewijzigd := True;
      Kop := ZoekSectie(Profiel, Sectie, Kop);
    end;
  end
  else if NieuweWaarde = nil then
  begin
    { sleutel verwijderen }
    Index := ZoekSleutel(Profiel, Sectie, StrPas(SleutelNaam));
    if Index >= 0 then
    begin
      Profiel.Lines.Delete(Index);
      Gewijzigd := True;
    end;
  end
  else
  begin
    Index := ZoekSleutel(Profiel, Sectie, StrPas(SleutelNaam));
    if Index >= 0 then
    begin
      { bestaande regel: alles tot en met het '=' (en de witruimte erna) blijft
        staan, alleen de waarde wordt vervangen }
      Naam := Profiel.Lines[Index];
      Kop := Pos('=', Naam);
      if Kop > 0 then
      begin
        while (Kop < Length(Naam)) and (Naam[Kop + 1] in Witruimte) do Inc(Kop);
        Nieuweregel := Copy(Naam, 1, Kop) + StrPas(NieuweWaarde);
      end
      else
        Nieuweregel := VerwijderWitruimte(Naam) + '=' + StrPas(NieuweWaarde);
      if Nieuweregel <> Profiel.Lines[Index] then
      begin
        Profiel.Lines[Index] := Nieuweregel;
        Gewijzigd := True;
      end;
    end
    else
    begin
      Nieuweregel := StrPas(SleutelNaam) + '=' + StrPas(NieuweWaarde);
      Kop := ZoekSectie(Profiel, Sectie, 0);
      if Kop >= 0 then
      begin
        { na de laatste sleutel (of de kop) van de sectie invoegen, voor de lege
          regels en het commentaar waarmee de volgende sectie begint }
        Einde := SectieEinde(Profiel, Kop);
        Laatste := Kop;
        for Index := Kop + 1 to Einde - 1 do
          if IsSleutel(Profiel.Lines[Index], Naam, Waarde, HeeftWaarde) then Laatste := Index;
        Profiel.Lines.Insert(Laatste + 1, Nieuweregel);
      end
      else
      begin
        Profiel.Lines.Add('[' + Sectie + ']');
        Profiel.Lines.Add(Nieuweregel);
      end;
      Gewijzigd := True;
    end;
  end;
  if not Gewijzigd then Exit(True);
  if not Bestaat then Profiel.FinalEOL := True;
  Result := Bewaar(Profiel, Pad);
end;

finalization
  Cache.Free;
end.

unit ZMWasmBackend;

{ Browserbackend voor de compatlaag (WebAssembly, wasm32-wasip1).

  Alle platformdiensten komen van JavaScript-imports in de module 'zm' (web/zoetermeer.js).
  zm.wait en zm.delay onderbreken de WebAssembly-stack (de module wordt nabewerkt met
  Asyncify van binaryen, zie docs/WASM.md), zodat de blokkerende berichtenlussen, modale
  dialogen en pauzes van het spel ongewijzigd werken terwijl de browser doorloopt.

  Registreert zichzelf met een hogere prioriteit dan de null-backend, net als de
  SDL3-backend. }

{$MODE DELPHI}{$H+}

interface

implementation

uses
  ZMPlatform;

{ imports (uit web/zoetermeer.js) }
procedure zm_toon(Beeldpunten: Pointer; Breedte, Hoogte, Regellengte: Integer); external 'zm' name 'present';
function zm_peil_gebeurtenis(Geheugen: Pointer): Integer; external 'zm' name 'poll_event';
procedure zm_wacht(WachtMs: Integer); external 'zm' name 'wait';
procedure zm_pauzeer(Milliseconden: Integer); external 'zm' name 'delay';
function zm_tikken: Double; external 'zm' name 'ticks';
procedure zm_zet_titel(Titel: PAnsiChar); external 'zm' name 'set_title';
procedure zm_zet_cursor(Vorm: Integer); external 'zm' name 'set_cursor';
procedure zm_piep; external 'zm' name 'beep';
procedure zm_open(Breedte, Hoogte: Integer); external 'zm' name 'open';

type
  { Indeling gedeeld met poll_event in web/zoetermeer.js: 12 Int32-velden, gevolgd door
    maximaal 15 bytes Windows-1252-tekst. }
  TRuweGebeurtenis = packed record
    Kind, X, Y, Button, Key, Toetsnummer, Herhaald, Wiel, Shift, Ctrl, Alt, TekstLengte: Longint;
    Text: array[0..15] of AnsiChar;
  end;

  TZMWasmBackend = class(TZMBackend)
  public
    function Name: string; override;
    function Open(const Title: string; W, H: Integer): Boolean; override;
    procedure Resize(W, H: Integer); override;
    procedure Toon(Pixels: Pointer; W, H, Rijbytes: Integer); override;
    function PeilGebeurtenis(out E: TZMGebeurtenis): Boolean; override;
    procedure WachtOpGebeurtenis(TimeoutMs: Integer); override;
    function KloktijdMs: LongWord; override;
    function PrestatieTeller: Int64; override;
    function PrestatieFrequentie: Int64; override;
    procedure Pauzeer(Ms: Integer); override;
    procedure SetTitle(const S: string); override;
    procedure SetCursor(Shape: TZMCursorvorm); override;
    procedure Beep; override;
  end;

function TZMWasmBackend.Name: string;
begin
  Result := 'wasm';
end;

function TZMWasmBackend.Open(const Title: string; W, H: Integer): Boolean;
begin
  zm_open(W, H);
  SetTitle(Title);
  Result := True;
end;

procedure TZMWasmBackend.Resize(W, H: Integer);
begin
  zm_open(W, H);
end;

procedure TZMWasmBackend.Toon(Pixels: Pointer; W, H, Rijbytes: Integer);
begin
  zm_toon(Pixels, W, H, Rijbytes);
end;

function TZMWasmBackend.PeilGebeurtenis(out E: TZMGebeurtenis): Boolean;
var
  R: TRuweGebeurtenis;
  Aantal: Integer;
begin
  FillChar(E, SizeOf(E), 0);
  Result := zm_peil_gebeurtenis(@R) <> 0;
  if not Result then
    Exit;
  E.Kind := TZMGebeurtenisSoort(R.Kind);
  E.X := R.X;
  E.Y := R.Y;
  E.Button := R.Button;
  E.Key := R.Key;
  E.Toetsnummer := R.Toetsnummer;
  E.Herhaald := R.Herhaald <> 0;
  E.Wiel := R.Wiel;
  E.Shift := R.Shift <> 0;
  E.Ctrl := R.Ctrl <> 0;
  E.Alt := R.Alt <> 0;
  Aantal := R.TekstLengte;
  if Aantal > 15 then
    Aantal := 15;
  SetLength(E.Text, Aantal);
  if Aantal > 0 then
    Move(R.Text[0], E.Text[1], Aantal);
end;

procedure TZMWasmBackend.WachtOpGebeurtenis(TimeoutMs: Integer);
begin
  zm_wacht(TimeoutMs);
end;

function TZMWasmBackend.KloktijdMs: LongWord;
begin
  Result := LongWord(Trunc(zm_tikken));
end;

function TZMWasmBackend.PrestatieTeller: Int64;
begin
  Result := Trunc(zm_tikken * 1000.0);   { microseconds }
end;

function TZMWasmBackend.PrestatieFrequentie: Int64;
begin
  Result := 1000000;
end;

procedure TZMWasmBackend.Pauzeer(Ms: Integer);
begin
  zm_pauzeer(Ms);
end;

procedure TZMWasmBackend.SetTitle(const S: string);
var
  Tekst: AnsiString;
begin
  Tekst := S + #0;
  zm_zet_titel(PAnsiChar(Tekst));
end;

procedure TZMWasmBackend.SetCursor(Shape: TZMCursorvorm);
begin
  zm_zet_cursor(Ord(Shape));
end;

procedure TZMWasmBackend.Beep;
begin
  zm_piep;
end;

initialization
  ZMRegistreerBackend(TZMWasmBackend.Create, 10);
end.

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
procedure zm_present(Beeldpunten: Pointer; Breedte, Hoogte, Regellengte: Integer); external 'zm' name 'present';
function zm_poll_event(Geheugen: Pointer): Integer; external 'zm' name 'poll_event';
procedure zm_wait(WachtMs: Integer); external 'zm' name 'wait';
procedure zm_delay(Milliseconden: Integer); external 'zm' name 'delay';
function zm_ticks: Double; external 'zm' name 'ticks';
procedure zm_set_title(Titel: PAnsiChar); external 'zm' name 'set_title';
procedure zm_set_cursor(Vorm: Integer); external 'zm' name 'set_cursor';
procedure zm_beep; external 'zm' name 'beep';
procedure zm_open(Breedte, Hoogte: Integer); external 'zm' name 'open';

type
  { Indeling gedeeld met poll_event in web/zoetermeer.js: 12 Int32-velden, gevolgd door
    maximaal 15 bytes Windows-1252-tekst. }
  TRawEvent = packed record
    Kind, X, Y, Button, Key, ScanCode, Repeated, Wheel, Shift, Ctrl, Alt, TextLen: Longint;
    Text: array[0..15] of AnsiChar;
  end;

  TZMWasmBackend = class(TZMBackend)
  public
    function Name: string; override;
    function Open(const Title: string; W, H: Integer): Boolean; override;
    procedure Resize(W, H: Integer); override;
    procedure Present(Pixels: Pointer; W, H, Stride: Integer); override;
    function PollEvent(out E: TZMEvent): Boolean; override;
    procedure WaitEvent(TimeoutMs: Integer); override;
    function Ticks: LongWord; override;
    function PerfCounter: Int64; override;
    function PerfFrequency: Int64; override;
    procedure Delay(Ms: Integer); override;
    procedure SetTitle(const S: string); override;
    procedure SetCursor(Shape: TZMCursorShape); override;
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

procedure TZMWasmBackend.Present(Pixels: Pointer; W, H, Stride: Integer);
begin
  zm_present(Pixels, W, H, Stride);
end;

function TZMWasmBackend.PollEvent(out E: TZMEvent): Boolean;
var
  R: TRawEvent;
  Aantal: Integer;
begin
  FillChar(E, SizeOf(E), 0);
  Result := zm_poll_event(@R) <> 0;
  if not Result then
    Exit;
  E.Kind := TZMEventKind(R.Kind);
  E.X := R.X;
  E.Y := R.Y;
  E.Button := R.Button;
  E.Key := R.Key;
  E.ScanCode := R.ScanCode;
  E.Repeated := R.Repeated <> 0;
  E.Wheel := R.Wheel;
  E.Shift := R.Shift <> 0;
  E.Ctrl := R.Ctrl <> 0;
  E.Alt := R.Alt <> 0;
  Aantal := R.TextLen;
  if Aantal > 15 then
    Aantal := 15;
  SetLength(E.Text, Aantal);
  if Aantal > 0 then
    Move(R.Text[0], E.Text[1], Aantal);
end;

procedure TZMWasmBackend.WaitEvent(TimeoutMs: Integer);
begin
  zm_wait(TimeoutMs);
end;

function TZMWasmBackend.Ticks: LongWord;
begin
  Result := LongWord(Trunc(zm_ticks));
end;

function TZMWasmBackend.PerfCounter: Int64;
begin
  Result := Trunc(zm_ticks * 1000.0);   { microseconds }
end;

function TZMWasmBackend.PerfFrequency: Int64;
begin
  Result := 1000000;
end;

procedure TZMWasmBackend.Delay(Ms: Integer);
begin
  zm_delay(Ms);
end;

procedure TZMWasmBackend.SetTitle(const S: string);
var
  Tekst: AnsiString;
begin
  Tekst := S + #0;
  zm_set_title(PAnsiChar(Tekst));
end;

procedure TZMWasmBackend.SetCursor(Shape: TZMCursorShape);
begin
  zm_set_cursor(Ord(Shape));
end;

procedure TZMWasmBackend.Beep;
begin
  zm_beep;
end;

initialization
  ZMRegisterBackend(TZMWasmBackend.Create, 10);
end.

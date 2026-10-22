unit ZMSdl3Backend;

{ SDL3-implementatie van de compat-platformbackend (ZMPlatform.TZMBackend).

  Eén vergrootbaar venster toont het geëmuleerde scherm met letterboxschaling
  (SDL_SetRenderLogicalPresentation), zodat muiscoördinaten terugkomen in schermpixels.
  Toetsen worden vertaald naar Windows-virtual-keycodes; tekstinvoer komt binnen als
  UTF-8 en wordt omgezet naar Windows-1252.

  De backend registreert zichzelf in de initialization-sectie; als SDL3 niet geladen of
  geïnitialiseerd kan worden, blijft de null-backend actief. Omgeving:
    ZM_HEADLESS=1   open geen venster (null-backend)
    ZM_SCALE=n      beginschaalfactor van het venster (standaard 1)
    ZM_FULLSCREEN=1 start op het volledige bureaublad
  De eigen variabelen van SDL werken ook (SDL_VIDEODRIVER=offscreen enz.). }

{$MODE DELPHI}{$H+}

interface

uses ZMPlatform, SDL3;

type
  TZMSdl3Backend = class(TZMBackend)
  private
    FVenster: PSDL_Window;
    FTekenaar: PSDL_Renderer;
    FTextuur: PSDL_Texture;
    FW, FH: Integer;
    FGeopend: Boolean;
    FCursors: array[TZMCursorvorm] of PSDL_Cursor;
    FCursorVorm: TZMCursorvorm;
    FWachtend: TZMGebeurtenis;
    FHeeftWachtend: Boolean;
    function Vertaal(const Gebeurtenis: SDL_Event; out Uit: TZMGebeurtenis): Boolean;
  public
    function Name: string; override;
    function Open(const Title: string; W, H: Integer): Boolean; override;
    procedure Close; override;
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
  end;

implementation

uses SysUtils, Windows;

function GebeurtenisU32(const Gebeurtenis: SDL_Event; Ofset: Integer): LongWord; inline;
begin
  Result := PLongWord(@Gebeurtenis.padding[Ofset])^;
end;

function GebeurtenisI32(const Gebeurtenis: SDL_Event; Ofset: Integer): LongInt; inline;
begin
  Result := PLongInt(@Gebeurtenis.padding[Ofset])^;
end;

function GebeurtenisF32(const Gebeurtenis: SDL_Event; Ofset: Integer): Single; inline;
begin
  Result := PSingle(@Gebeurtenis.padding[Ofset])^;
end;

function GebeurtenisU16(const Gebeurtenis: SDL_Event; Ofset: Integer): Word; inline;
begin
  Result := PWord(@Gebeurtenis.padding[Ofset])^;
end;

function GebeurtenisU8(const Gebeurtenis: SDL_Event; Ofset: Integer): Byte; inline;
begin
  Result := Gebeurtenis.padding[Ofset];
end;

{ SDL-scancode -> Windows-virtual-key }
function ScancodeNaarVK(Toetsnummer: LongWord; Toetscode: LongWord): Word;
begin
  { letters volgen de toetsenbordindeling (keycode), al het andere de positie }
  if (Toetscode >= Ord('a')) and (Toetscode <= Ord('z')) then Exit(Toetscode - 32);
  case Toetsnummer of
    4..29: Result := Ord('A') + Toetsnummer - 4;
    30..38: Result := Ord('1') + Toetsnummer - 30;
    39: Result := Ord('0');
    40: Result := VK_RETURN;
    41: Result := VK_ESCAPE;
    42: Result := VK_BACK;
    43: Result := VK_TAB;
    44: Result := VK_SPACE;
    45: Result := $BD;  { VK_OEM_MINUS }
    46: Result := $BB;  { VK_OEM_PLUS }
    47: Result := $DB;
    48: Result := $DD;
    49: Result := $DC;
    51: Result := $BA;
    52: Result := $DE;
    53: Result := $C0;
    54: Result := $BC;
    55: Result := $BE;
    56: Result := $BF;
    57: Result := VK_CAPITAL;
    58..69: Result := VK_F1 + Toetsnummer - 58;
    70: Result := VK_SNAPSHOT;
    71: Result := VK_SCROLL;
    72: Result := VK_PAUSE;
    73: Result := VK_INSERT;
    74: Result := VK_HOME;
    75: Result := VK_PRIOR;
    76: Result := VK_DELETE;
    77: Result := VK_END;
    78: Result := VK_NEXT;
    79: Result := VK_RIGHT;
    80: Result := VK_LEFT;
    81: Result := VK_DOWN;
    82: Result := VK_UP;
    83: Result := VK_NUMLOCK;
    84: Result := VK_DIVIDE;
    85: Result := VK_MULTIPLY;
    86: Result := VK_SUBTRACT;
    87: Result := VK_ADD;
    88: Result := VK_RETURN;
    89..97: Result := VK_NUMPAD1 + Toetsnummer - 89;
    98: Result := VK_NUMPAD0;
    99: Result := VK_DECIMAL;
    224: Result := VK_LCONTROL;
    225: Result := VK_LSHIFT;
    226: Result := VK_LMENU;
    227: Result := VK_LWIN;
    228: Result := VK_RCONTROL;
    229: Result := VK_RSHIFT;
    230: Result := VK_RMENU;
    231: Result := VK_RWIN;
  else
    Result := 0;
  end;
end;

function TZMSdl3Backend.Name: string;
begin
  Result := 'sdl3';
end;

function TZMSdl3Backend.Open(const Title: string; W, H: Integer): Boolean;
var
  Schaal: Integer;
  Vlaggen: QWord;
begin
  Result := FGeopend;
  if FGeopend then Exit;
  if not SDL_Init(SDL_INIT_VIDEO or SDL_INIT_EVENTS) then
  begin
    WriteLn(StdErr, 'SDL_Init mislukt: ', SDL_GetError);
    Exit(False);
  end;
  Schaal := StrToIntDef(GetEnvironmentVariable('ZM_SCALE'), 1);
  if Schaal < 1 then Schaal := 1;
  Vlaggen := SDL_WINDOW_RESIZABLE;
  if GetEnvironmentVariable('ZM_FULLSCREEN') = '1' then Vlaggen := Vlaggen or $1;  { SDL_WINDOW_FULLSCREEN }
  FVenster := SDL_CreateWindow(PAnsiChar(AnsiString(Title)), W * Schaal, H * Schaal, Vlaggen);
  if FVenster = nil then
  begin
    WriteLn(StdErr, 'SDL_CreateWindow mislukt: ', SDL_GetError);
    Exit(False);
  end;
  FTekenaar := SDL_CreateRenderer(FVenster, nil);
  if FTekenaar = nil then
  begin
    WriteLn(StdErr, 'SDL_CreateRenderer mislukt: ', SDL_GetError);
    Exit(False);
  end;
  FGeopend := True;
  Resize(W, H);
  SDL_StartTextInput(FVenster);
  Result := True;
end;

procedure TZMSdl3Backend.Resize(W, H: Integer);
begin
  if not FGeopend then Exit;
  if FTextuur <> nil then SDL_DestroyTexture(FTextuur);
  FW := W;
  FH := H;
  FTextuur := SDL_CreateTexture(FTekenaar, SDL_PIXELFORMAT_XRGB8888, SDL_TEXTUREACCESS_STREAMING, W, H);
  SDL_SetTextureScaleMode(FTextuur, SDL_SCALEMODE_NEAREST);
  SDL_SetRenderLogicalPresentation(FTekenaar, W, H, SDL_LOGICAL_PRESENTATION_LETTERBOX);
end;

procedure TZMSdl3Backend.Close;
var
  Vorm: TZMCursorvorm;
begin
  if not FGeopend then Exit;
  FGeopend := False;
  for Vorm := Low(Vorm) to High(Vorm) do FCursors[Vorm] := nil;
  if FTextuur <> nil then SDL_DestroyTexture(FTextuur);
  if FTekenaar <> nil then SDL_DestroyRenderer(FTekenaar);
  if FVenster <> nil then SDL_DestroyWindow(FVenster);
  FTextuur := nil;
  FTekenaar := nil;
  FVenster := nil;
  SDL_Quit;
end;

procedure TZMSdl3Backend.Toon(Pixels: Pointer; W, H, Rijbytes: Integer);
begin
  if not FGeopend then Exit;
  if (W <> FW) or (H <> FH) then Resize(W, H);
  SDL_UpdateTexture(FTextuur, nil, Pixels, Rijbytes);
  SDL_SetRenderDrawColor(FTekenaar, 0, 0, 0, 255);
  SDL_RenderClear(FTekenaar);
  SDL_RenderTexture(FTekenaar, FTextuur, nil, nil);
  SDL_RenderPresent(FTekenaar);
end;

function TZMSdl3Backend.Vertaal(const Gebeurtenis: SDL_Event; out Uit: TZMGebeurtenis): Boolean;
var
  Soort: LongWord;
  Modificatoren: Word;
  Tekstptr: PAnsiChar;
  Omgezet: SDL_Event;
begin
  FillChar(Uit, SizeOf(Uit), 0);
  Result := True;
  Soort := Gebeurtenis.type_;
  case Soort of
    SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
      Uit.Kind := zeQuit;
    SDL_EVENT_WINDOW_EXPOSED:
      Uit.Kind := zeExpose;
    SDL_EVENT_WINDOW_FOCUS_GAINED:
      Uit.Kind := zeActivate;
    SDL_EVENT_WINDOW_FOCUS_LOST:
      Uit.Kind := zeDeactivate;
    SDL_EVENT_WINDOW_MOUSE_LEAVE:
      Uit.Kind := zeMouseLeave;
    SDL_EVENT_MOUSE_MOTION, SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP,
    SDL_EVENT_MOUSE_WHEEL:
      begin
        Omgezet := Gebeurtenis;
        SDL_ConvertEventToRenderCoordinates(FTekenaar, @Omgezet);
        case Soort of
          SDL_EVENT_MOUSE_MOTION:
            begin
              Uit.Kind := zeMouseMove;
              Uit.X := Trunc(GebeurtenisF32(Omgezet, 28));
              Uit.Y := Trunc(GebeurtenisF32(Omgezet, 32));
            end;
          SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP:
            begin
              if Soort = SDL_EVENT_MOUSE_BUTTON_DOWN then Uit.Kind := zeMouseDown else Uit.Kind := zeMouseUp;
              case GebeurtenisU8(Omgezet, 24) of
                1: Uit.Button := 1;
                2: Uit.Button := 3;
                3: Uit.Button := 2;
              else
                Exit(False);
              end;
              Uit.X := Trunc(GebeurtenisF32(Omgezet, 28));
              Uit.Y := Trunc(GebeurtenisF32(Omgezet, 32));
            end;
          SDL_EVENT_MOUSE_WHEEL:
            begin
              Uit.Kind := zeMouseWheel;
              Uit.Wiel := Round(GebeurtenisF32(Omgezet, 28) * 120);
              if GebeurtenisU32(Omgezet, 32) = 1 then Uit.Wiel := -Uit.Wiel;  { omgekeerd }
              Uit.X := Trunc(GebeurtenisF32(Omgezet, 36));
              Uit.Y := Trunc(GebeurtenisF32(Omgezet, 40));
              if Uit.Wiel = 0 then Exit(False);
            end;
        end;
      end;
    SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_UP:
      begin
        if Soort = SDL_EVENT_KEY_DOWN then Uit.Kind := zeKeyDown else Uit.Kind := zeKeyUp;
        Uit.Toetsnummer := GebeurtenisU32(Gebeurtenis, 24);
        Uit.Key := ScancodeNaarVK(GebeurtenisU32(Gebeurtenis, 24), GebeurtenisU32(Gebeurtenis, 28));
        Modificatoren := GebeurtenisU16(Gebeurtenis, 32);
        Uit.Shift := Modificatoren and SDL_KMOD_SHIFT <> 0;
        Uit.Ctrl := Modificatoren and SDL_KMOD_CTRL <> 0;
        Uit.Alt := Modificatoren and SDL_KMOD_ALT <> 0;
        Uit.Herhaald := GebeurtenisU8(Gebeurtenis, 37) <> 0;
        if Uit.Key = 0 then Exit(False);
      end;
    SDL_EVENT_TEXT_INPUT:
      begin
        Uit.Kind := zeText;
        Tekstptr := PPAnsiChar(@Gebeurtenis.padding[24])^;
        if Tekstptr <> nil then Uit.Text := Copy(ZMUtf8NaarCp1252(Tekstptr), 1, 15);
        if Uit.Text = '' then Exit(False);
      end;
  else
    Result := False;
  end;
end;

function TZMSdl3Backend.PeilGebeurtenis(out E: TZMGebeurtenis): Boolean;
var
  Gebeurtenis: SDL_Event;
begin
  if FHeeftWachtend then
  begin
    E := FWachtend;
    FHeeftWachtend := False;
    Exit(True);
  end;
  Result := False;
  if not FGeopend then
  begin
    FillChar(E, SizeOf(E), 0);
    Exit;
  end;
  while SDL_PollEvent(@Gebeurtenis) do
    if Vertaal(Gebeurtenis, E) then Exit(True);
end;

procedure TZMSdl3Backend.WachtOpGebeurtenis(TimeoutMs: Integer);
var
  Gebeurtenis: SDL_Event;
begin
  if not FGeopend then
  begin
    inherited WachtOpGebeurtenis(TimeoutMs);
    Exit;
  end;
  if FHeeftWachtend then Exit;
  if SDL_WaitEventTimeout(@Gebeurtenis, TimeoutMs) then
    FHeeftWachtend := Vertaal(Gebeurtenis, FWachtend);
end;

function TZMSdl3Backend.KloktijdMs: LongWord;
begin
  Result := LongWord(SDL_GetTicks);
end;

function TZMSdl3Backend.PrestatieTeller: Int64;
begin
  Result := Int64(SDL_GetPerformanceCounter);
end;

function TZMSdl3Backend.PrestatieFrequentie: Int64;
begin
  Result := Int64(SDL_GetPerformanceFrequency);
end;

procedure TZMSdl3Backend.Pauzeer(Ms: Integer);
begin
  if Ms > 0 then SDL_Delay(Ms);
end;

procedure TZMSdl3Backend.SetTitle(const S: string);
begin
  if FGeopend then SDL_SetWindowTitle(FVenster, PAnsiChar(AnsiString(S)));
end;

procedure TZMSdl3Backend.SetCursor(Shape: TZMCursorvorm);
const
  Codes: array[TZMCursorvorm] of LongInt = (SDL_SYSTEM_CURSOR_DEFAULT, SDL_SYSTEM_CURSOR_TEXT,
    SDL_SYSTEM_CURSOR_WAIT, SDL_SYSTEM_CURSOR_CROSSHAIR, SDL_SYSTEM_CURSOR_POINTER,
    SDL_SYSTEM_CURSOR_MOVE, SDL_SYSTEM_CURSOR_NS_RESIZE, SDL_SYSTEM_CURSOR_EW_RESIZE,
    SDL_SYSTEM_CURSOR_NWSE_RESIZE, SDL_SYSTEM_CURSOR_NESW_RESIZE, SDL_SYSTEM_CURSOR_NOT_ALLOWED,
    SDL_SYSTEM_CURSOR_PROGRESS, SDL_SYSTEM_CURSOR_DEFAULT);
begin
  if not FGeopend or (Shape = FCursorVorm) then Exit;
  FCursorVorm := Shape;
  if Shape = zcNone then
  begin
    SDL_HideCursor;
    Exit;
  end;
  SDL_ShowCursor;
  if FCursors[Shape] = nil then FCursors[Shape] := SDL_CreateSystemCursor(Codes[Shape]);
  if FCursors[Shape] <> nil then SDL_SetCursor(FCursors[Shape]);
end;

initialization
  if (GetEnvironmentVariable('ZM_HEADLESS') <> '1') and SDL3_Load then
    ZMRegistreerBackend(TZMSdl3Backend.Create, 10);
end.

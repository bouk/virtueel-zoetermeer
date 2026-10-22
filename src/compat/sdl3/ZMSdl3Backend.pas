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
    FWindow: PSDL_Window;
    FRenderer: PSDL_Renderer;
    FTexture: PSDL_Texture;
    FW, FH: Integer;
    FOpen: Boolean;
    FCursors: array[TZMCursorShape] of PSDL_Cursor;
    FCursorShape: TZMCursorShape;
    FPending: TZMEvent;
    FHasPending: Boolean;
    function Translate(const Ev: SDL_Event; out E: TZMEvent): Boolean;
  public
    function Name: string; override;
    function Open(const Title: string; W, H: Integer): Boolean; override;
    procedure Close; override;
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
  end;

implementation

uses SysUtils, Windows;

function EvU32(const Ev: SDL_Event; Ofs: Integer): LongWord; inline;
begin
  Result := PLongWord(@Ev.padding[Ofs])^;
end;

function EvI32(const Ev: SDL_Event; Ofs: Integer): LongInt; inline;
begin
  Result := PLongInt(@Ev.padding[Ofs])^;
end;

function EvF32(const Ev: SDL_Event; Ofs: Integer): Single; inline;
begin
  Result := PSingle(@Ev.padding[Ofs])^;
end;

function EvU16(const Ev: SDL_Event; Ofs: Integer): Word; inline;
begin
  Result := PWord(@Ev.padding[Ofs])^;
end;

function EvU8(const Ev: SDL_Event; Ofs: Integer): Byte; inline;
begin
  Result := Ev.padding[Ofs];
end;

{ SDL-scancode -> Windows-virtual-key }
function ScanToVK(Scan: LongWord; Key: LongWord): Word;
begin
  { letters volgen de toetsenbordindeling (keycode), al het andere de positie }
  if (Key >= Ord('a')) and (Key <= Ord('z')) then Exit(Key - 32);
  case Scan of
    4..29: Result := Ord('A') + Scan - 4;
    30..38: Result := Ord('1') + Scan - 30;
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
    58..69: Result := VK_F1 + Scan - 58;
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
    89..97: Result := VK_NUMPAD1 + Scan - 89;
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
  Scale: Integer;
  Flags: QWord;
begin
  Result := FOpen;
  if FOpen then Exit;
  if not SDL_Init(SDL_INIT_VIDEO or SDL_INIT_EVENTS) then
  begin
    WriteLn(StdErr, 'SDL_Init mislukt: ', SDL_GetError);
    Exit(False);
  end;
  Scale := StrToIntDef(GetEnvironmentVariable('ZM_SCALE'), 1);
  if Scale < 1 then Scale := 1;
  Flags := SDL_WINDOW_RESIZABLE;
  if GetEnvironmentVariable('ZM_FULLSCREEN') = '1' then Flags := Flags or $1;  { SDL_WINDOW_FULLSCREEN }
  FWindow := SDL_CreateWindow(PAnsiChar(AnsiString(Title)), W * Scale, H * Scale, Flags);
  if FWindow = nil then
  begin
    WriteLn(StdErr, 'SDL_CreateWindow mislukt: ', SDL_GetError);
    Exit(False);
  end;
  FRenderer := SDL_CreateRenderer(FWindow, nil);
  if FRenderer = nil then
  begin
    WriteLn(StdErr, 'SDL_CreateRenderer mislukt: ', SDL_GetError);
    Exit(False);
  end;
  FOpen := True;
  Resize(W, H);
  SDL_StartTextInput(FWindow);
  Result := True;
end;

procedure TZMSdl3Backend.Resize(W, H: Integer);
begin
  if not FOpen then Exit;
  if FTexture <> nil then SDL_DestroyTexture(FTexture);
  FW := W;
  FH := H;
  FTexture := SDL_CreateTexture(FRenderer, SDL_PIXELFORMAT_XRGB8888, SDL_TEXTUREACCESS_STREAMING, W, H);
  SDL_SetTextureScaleMode(FTexture, SDL_SCALEMODE_NEAREST);
  SDL_SetRenderLogicalPresentation(FRenderer, W, H, SDL_LOGICAL_PRESENTATION_LETTERBOX);
end;

procedure TZMSdl3Backend.Close;
var
  C: TZMCursorShape;
begin
  if not FOpen then Exit;
  FOpen := False;
  for C := Low(C) to High(C) do FCursors[C] := nil;
  if FTexture <> nil then SDL_DestroyTexture(FTexture);
  if FRenderer <> nil then SDL_DestroyRenderer(FRenderer);
  if FWindow <> nil then SDL_DestroyWindow(FWindow);
  FTexture := nil;
  FRenderer := nil;
  FWindow := nil;
  SDL_Quit;
end;

procedure TZMSdl3Backend.Present(Pixels: Pointer; W, H, Stride: Integer);
begin
  if not FOpen then Exit;
  if (W <> FW) or (H <> FH) then Resize(W, H);
  SDL_UpdateTexture(FTexture, nil, Pixels, Stride);
  SDL_SetRenderDrawColor(FRenderer, 0, 0, 0, 255);
  SDL_RenderClear(FRenderer);
  SDL_RenderTexture(FRenderer, FTexture, nil, nil);
  SDL_RenderPresent(FRenderer);
end;

function TZMSdl3Backend.Translate(const Ev: SDL_Event; out E: TZMEvent): Boolean;
var
  T: LongWord;
  Mods: Word;
  P: PAnsiChar;
  Ev2: SDL_Event;
begin
  FillChar(E, SizeOf(E), 0);
  Result := True;
  T := Ev.type_;
  case T of
    SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
      E.Kind := zeQuit;
    SDL_EVENT_WINDOW_EXPOSED:
      E.Kind := zeExpose;
    SDL_EVENT_WINDOW_FOCUS_GAINED:
      E.Kind := zeActivate;
    SDL_EVENT_WINDOW_FOCUS_LOST:
      E.Kind := zeDeactivate;
    SDL_EVENT_WINDOW_MOUSE_LEAVE:
      E.Kind := zeMouseLeave;
    SDL_EVENT_MOUSE_MOTION, SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP,
    SDL_EVENT_MOUSE_WHEEL:
      begin
        Ev2 := Ev;
        SDL_ConvertEventToRenderCoordinates(FRenderer, @Ev2);
        case T of
          SDL_EVENT_MOUSE_MOTION:
            begin
              E.Kind := zeMouseMove;
              E.X := Trunc(EvF32(Ev2, 28));
              E.Y := Trunc(EvF32(Ev2, 32));
            end;
          SDL_EVENT_MOUSE_BUTTON_DOWN, SDL_EVENT_MOUSE_BUTTON_UP:
            begin
              if T = SDL_EVENT_MOUSE_BUTTON_DOWN then E.Kind := zeMouseDown else E.Kind := zeMouseUp;
              case EvU8(Ev2, 24) of
                1: E.Button := 1;
                2: E.Button := 3;
                3: E.Button := 2;
              else
                Exit(False);
              end;
              E.X := Trunc(EvF32(Ev2, 28));
              E.Y := Trunc(EvF32(Ev2, 32));
            end;
          SDL_EVENT_MOUSE_WHEEL:
            begin
              E.Kind := zeMouseWheel;
              E.Wheel := Round(EvF32(Ev2, 28) * 120);
              if EvU32(Ev2, 32) = 1 then E.Wheel := -E.Wheel;  { omgekeerd }
              E.X := Trunc(EvF32(Ev2, 36));
              E.Y := Trunc(EvF32(Ev2, 40));
              if E.Wheel = 0 then Exit(False);
            end;
        end;
      end;
    SDL_EVENT_KEY_DOWN, SDL_EVENT_KEY_UP:
      begin
        if T = SDL_EVENT_KEY_DOWN then E.Kind := zeKeyDown else E.Kind := zeKeyUp;
        E.ScanCode := EvU32(Ev, 24);
        E.Key := ScanToVK(EvU32(Ev, 24), EvU32(Ev, 28));
        Mods := EvU16(Ev, 32);
        E.Shift := Mods and SDL_KMOD_SHIFT <> 0;
        E.Ctrl := Mods and SDL_KMOD_CTRL <> 0;
        E.Alt := Mods and SDL_KMOD_ALT <> 0;
        E.Repeated := EvU8(Ev, 37) <> 0;
        if E.Key = 0 then Exit(False);
      end;
    SDL_EVENT_TEXT_INPUT:
      begin
        E.Kind := zeText;
        P := PPAnsiChar(@Ev.padding[24])^;
        if P <> nil then E.Text := Copy(ZMUtf8ToCp1252(P), 1, 15);
        if E.Text = '' then Exit(False);
      end;
  else
    Result := False;
  end;
end;

function TZMSdl3Backend.PollEvent(out E: TZMEvent): Boolean;
var
  Ev: SDL_Event;
begin
  if FHasPending then
  begin
    E := FPending;
    FHasPending := False;
    Exit(True);
  end;
  Result := False;
  if not FOpen then
  begin
    FillChar(E, SizeOf(E), 0);
    Exit;
  end;
  while SDL_PollEvent(@Ev) do
    if Translate(Ev, E) then Exit(True);
end;

procedure TZMSdl3Backend.WaitEvent(TimeoutMs: Integer);
var
  Ev: SDL_Event;
begin
  if not FOpen then
  begin
    inherited WaitEvent(TimeoutMs);
    Exit;
  end;
  if FHasPending then Exit;
  if SDL_WaitEventTimeout(@Ev, TimeoutMs) then
    FHasPending := Translate(Ev, FPending);
end;

function TZMSdl3Backend.Ticks: LongWord;
begin
  Result := LongWord(SDL_GetTicks);
end;

function TZMSdl3Backend.PerfCounter: Int64;
begin
  Result := Int64(SDL_GetPerformanceCounter);
end;

function TZMSdl3Backend.PerfFrequency: Int64;
begin
  Result := Int64(SDL_GetPerformanceFrequency);
end;

procedure TZMSdl3Backend.Delay(Ms: Integer);
begin
  if Ms > 0 then SDL_Delay(Ms);
end;

procedure TZMSdl3Backend.SetTitle(const S: string);
begin
  if FOpen then SDL_SetWindowTitle(FWindow, PAnsiChar(AnsiString(S)));
end;

procedure TZMSdl3Backend.SetCursor(Shape: TZMCursorShape);
const
  Ids: array[TZMCursorShape] of LongInt = (SDL_SYSTEM_CURSOR_DEFAULT, SDL_SYSTEM_CURSOR_TEXT,
    SDL_SYSTEM_CURSOR_WAIT, SDL_SYSTEM_CURSOR_CROSSHAIR, SDL_SYSTEM_CURSOR_POINTER,
    SDL_SYSTEM_CURSOR_MOVE, SDL_SYSTEM_CURSOR_NS_RESIZE, SDL_SYSTEM_CURSOR_EW_RESIZE,
    SDL_SYSTEM_CURSOR_NWSE_RESIZE, SDL_SYSTEM_CURSOR_NESW_RESIZE, SDL_SYSTEM_CURSOR_NOT_ALLOWED,
    SDL_SYSTEM_CURSOR_PROGRESS, SDL_SYSTEM_CURSOR_DEFAULT);
begin
  if not FOpen or (Shape = FCursorShape) then Exit;
  FCursorShape := Shape;
  if Shape = zcNone then
  begin
    SDL_HideCursor;
    Exit;
  end;
  SDL_ShowCursor;
  if FCursors[Shape] = nil then FCursors[Shape] := SDL_CreateSystemCursor(Ids[Shape]);
  if FCursors[Shape] <> nil then SDL_SetCursor(FCursors[Shape]);
end;

initialization
  if (GetEnvironmentVariable('ZM_HEADLESS') <> '1') and SDL3_Load then
    ZMRegisterBackend(TZMSdl3Backend.Create, 10);
end.

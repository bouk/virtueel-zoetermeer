unit SDL3;

{ Minimale SDL3-binding: alleen wat de compat-backend gebruikt.

  De bibliotheek wordt pas tijdens het draaien geladen (geen afhankelijkheid bij het
  linken), zodat een build ook werkt op machines zonder SDL3 (headless/null-backend) en
  dezelfde binary libSDL3.so.0 / libSDL3.0.dylib vindt via de gewone laadpaden.
  Zoekvolgorde: $ZM_SDL3_LIB, de standaard bibliotheeknamen, dan de libdir van elke
  sdl3.pc in $PKG_CONFIG_PATH (zo wordt hij binnen `nix develop` gevonden). }

{$MODE DELPHI}{$H+}

interface

type
  PSDL_Window = Pointer;
  PSDL_Renderer = Pointer;
  PSDL_Texture = Pointer;
  PSDL_Cursor = Pointer;

  SDL_FRect = record
    x, y, w, h: Single;
  end;
  PSDL_FRect = ^SDL_FRect;

  SDL_Rect = record
    x, y, w, h: LongInt;
  end;
  PSDL_Rect = ^SDL_Rect;

  { SDL_Event is een union van 128 bytes; de velden die we lezen, benaderen we via een offset }
  SDL_Event = record
    case Integer of
      0: (type_: LongWord);
      1: (padding: array[0..127] of Byte);
  end;
  PSDL_Event = ^SDL_Event;

const
  SDL_INIT_VIDEO = $00000020;
  SDL_INIT_EVENTS = $00004000;

  SDL_WINDOW_RESIZABLE = $0000000000000020;
  SDL_WINDOW_HIDDEN = $0000000000000008;
  SDL_WINDOW_HIGH_PIXEL_DENSITY = $0000000000002000;

  SDL_PIXELFORMAT_XRGB8888 = $16161804;
  SDL_TEXTUREACCESS_STREAMING = 1;
  SDL_LOGICAL_PRESENTATION_LETTERBOX = 2;
  SDL_SCALEMODE_NEAREST = 0;
  SDL_SCALEMODE_LINEAR = 1;

  SDL_EVENT_QUIT = $100;
  SDL_EVENT_WINDOW_EXPOSED = $204;
  SDL_EVENT_WINDOW_MOUSE_LEAVE = $20D;
  SDL_EVENT_WINDOW_FOCUS_GAINED = $20E;
  SDL_EVENT_WINDOW_FOCUS_LOST = $20F;
  SDL_EVENT_WINDOW_CLOSE_REQUESTED = $210;
  SDL_EVENT_KEY_DOWN = $300;
  SDL_EVENT_KEY_UP = $301;
  SDL_EVENT_TEXT_INPUT = $303;
  SDL_EVENT_MOUSE_MOTION = $400;
  SDL_EVENT_MOUSE_BUTTON_DOWN = $401;
  SDL_EVENT_MOUSE_BUTTON_UP = $402;
  SDL_EVENT_MOUSE_WHEEL = $403;

  SDL_KMOD_LSHIFT = $0001; SDL_KMOD_RSHIFT = $0002;
  SDL_KMOD_LCTRL = $0040; SDL_KMOD_RCTRL = $0080;
  SDL_KMOD_LALT = $0100; SDL_KMOD_RALT = $0200;
  SDL_KMOD_SHIFT = $0003; SDL_KMOD_CTRL = $00C0; SDL_KMOD_ALT = $0300;

  SDL_SYSTEM_CURSOR_DEFAULT = 0;
  SDL_SYSTEM_CURSOR_TEXT = 1;
  SDL_SYSTEM_CURSOR_WAIT = 2;
  SDL_SYSTEM_CURSOR_CROSSHAIR = 3;
  SDL_SYSTEM_CURSOR_PROGRESS = 4;
  SDL_SYSTEM_CURSOR_NWSE_RESIZE = 5;
  SDL_SYSTEM_CURSOR_NESW_RESIZE = 6;
  SDL_SYSTEM_CURSOR_EW_RESIZE = 7;
  SDL_SYSTEM_CURSOR_NS_RESIZE = 8;
  SDL_SYSTEM_CURSOR_MOVE = 9;
  SDL_SYSTEM_CURSOR_NOT_ALLOWED = 10;
  SDL_SYSTEM_CURSOR_POINTER = 11;

var
  SDL_Init: function(flags: LongWord): Boolean; cdecl;
  SDL_Quit: procedure; cdecl;
  SDL_GetError: function: PAnsiChar; cdecl;
  SDL_SetHint: function(name, value: PAnsiChar): Boolean; cdecl;
  SDL_CreateWindow: function(title: PAnsiChar; w, h: LongInt; flags: QWord): PSDL_Window; cdecl;
  SDL_DestroyWindow: procedure(window: PSDL_Window); cdecl;
  SDL_SetWindowTitle: function(window: PSDL_Window; title: PAnsiChar): Boolean; cdecl;
  SDL_SetWindowSize: function(window: PSDL_Window; w, h: LongInt): Boolean; cdecl;
  SDL_ShowWindow: function(window: PSDL_Window): Boolean; cdecl;
  SDL_CreateRenderer: function(window: PSDL_Window; name: PAnsiChar): PSDL_Renderer; cdecl;
  SDL_DestroyRenderer: procedure(renderer: PSDL_Renderer); cdecl;
  SDL_SetRenderLogicalPresentation: function(renderer: PSDL_Renderer; w, h: LongInt; mode: LongInt): Boolean; cdecl;
  SDL_SetRenderDrawColor: function(renderer: PSDL_Renderer; r, g, b, a: Byte): Boolean; cdecl;
  SDL_RenderClear: function(renderer: PSDL_Renderer): Boolean; cdecl;
  SDL_RenderTexture: function(renderer: PSDL_Renderer; texture: PSDL_Texture; srcrect, dstrect: PSDL_FRect): Boolean; cdecl;
  SDL_RenderPresent: function(renderer: PSDL_Renderer): Boolean; cdecl;
  SDL_CreateTexture: function(renderer: PSDL_Renderer; format: LongWord; access, w, h: LongInt): PSDL_Texture; cdecl;
  SDL_DestroyTexture: procedure(texture: PSDL_Texture); cdecl;
  SDL_SetTextureScaleMode: function(texture: PSDL_Texture; mode: LongInt): Boolean; cdecl;
  SDL_UpdateTexture: function(texture: PSDL_Texture; rect: PSDL_Rect; pixels: Pointer; pitch: LongInt): Boolean; cdecl;
  SDL_ConvertEventToRenderCoordinates: function(renderer: PSDL_Renderer; event: PSDL_Event): Boolean; cdecl;
  SDL_PollEvent: function(event: PSDL_Event): Boolean; cdecl;
  SDL_WaitEventTimeout: function(event: PSDL_Event; timeoutMS: LongInt): Boolean; cdecl;
  SDL_GetTicks: function: QWord; cdecl;
  SDL_GetPerformanceCounter: function: QWord; cdecl;
  SDL_GetPerformanceFrequency: function: QWord; cdecl;
  SDL_Delay: procedure(ms: LongWord); cdecl;
  SDL_StartTextInput: function(window: PSDL_Window): Boolean; cdecl;
  SDL_CreateSystemCursor: function(id: LongInt): PSDL_Cursor; cdecl;
  SDL_SetCursor: function(cursor: PSDL_Cursor): Boolean; cdecl;
  SDL_ShowCursor: function: Boolean; cdecl;
  SDL_HideCursor: function: Boolean; cdecl;

function SDL3_Load: Boolean;
function SDL3_Loaded: Boolean;

implementation

uses SysUtils, Classes, DynLibs;

var
  Lib: TLibHandle = NilHandle;

function SDL3_Loaded: Boolean;
begin
  Result := Lib <> NilHandle;
end;

function PcBibliotheekMappen: TStringList;
var
  Paden: TStringList;
  Teller, Regelnr: Integer;
  PcBestand: TStringList;
  Bestandsnaam: string;
begin
  Result := TStringList.Create;
  Paden := TStringList.Create;
  try
    Paden.Delimiter := ':';
    Paden.StrictDelimiter := True;
    Paden.DelimitedText := GetEnvironmentVariable('PKG_CONFIG_PATH');
    for Teller := 0 to Paden.Count - 1 do
    begin
      Bestandsnaam := IncludeTrailingPathDelimiter(Paden[Teller]) + 'sdl3.pc';
      if not FileExists(Bestandsnaam) then Continue;
      PcBestand := TStringList.Create;
      try
        PcBestand.LoadFromFile(Bestandsnaam);
        for Regelnr := 0 to PcBestand.Count - 1 do
          if Copy(PcBestand[Regelnr], 1, 7) = 'libdir=' then
            Result.Add(Copy(PcBestand[Regelnr], 8, MaxInt));
      finally
        PcBestand.Free;
      end;
    end;
  finally
    Paden.Free;
  end;
end;

function ProbeerLaden(const Naam: string): Boolean;
begin
  if Naam = '' then Exit(False);
  Lib := LoadLibrary(Naam);
  Result := Lib <> NilHandle;
end;

function SDL3_Load: Boolean;
const
  Namen: array[0..4] of string = ('libSDL3.so.0', 'libSDL3.so', 'libSDL3.0.dylib',
    'libSDL3.dylib', 'SDL3.dll');
var
  Teller, Mapnr: Integer;
  Mappen: TStringList;
  Ontbreekt: string;
  procedure Haal(var Adres; const Naam: string);
  begin
    Pointer(Adres) := GetProcAddress(Lib, Naam);
    if Pointer(Adres) = nil then Ontbreekt := Ontbreekt + ' ' + Naam;
  end;
begin
  if Lib <> NilHandle then Exit(True);
  Result := ProbeerLaden(GetEnvironmentVariable('ZM_SDL3_LIB'));
  for Teller := 0 to High(Namen) do
    if not Result then Result := ProbeerLaden(Namen[Teller]);
  if not Result then
  begin
    Mappen := PcBibliotheekMappen;
    try
      for Mapnr := 0 to Mappen.Count - 1 do
        for Teller := 0 to High(Namen) do
          if not Result then
            Result := ProbeerLaden(IncludeTrailingPathDelimiter(Mappen[Mapnr]) + Namen[Teller]);
    finally
      Mappen.Free;
    end;
  end;
  if not Result then Exit;
  Ontbreekt := '';
  Haal(SDL_Init, 'SDL_Init');
  Haal(SDL_Quit, 'SDL_Quit');
  Haal(SDL_GetError, 'SDL_GetError');
  Haal(SDL_SetHint, 'SDL_SetHint');
  Haal(SDL_CreateWindow, 'SDL_CreateWindow');
  Haal(SDL_DestroyWindow, 'SDL_DestroyWindow');
  Haal(SDL_SetWindowTitle, 'SDL_SetWindowTitle');
  Haal(SDL_SetWindowSize, 'SDL_SetWindowSize');
  Haal(SDL_ShowWindow, 'SDL_ShowWindow');
  Haal(SDL_CreateRenderer, 'SDL_CreateRenderer');
  Haal(SDL_DestroyRenderer, 'SDL_DestroyRenderer');
  Haal(SDL_SetRenderLogicalPresentation, 'SDL_SetRenderLogicalPresentation');
  Haal(SDL_SetRenderDrawColor, 'SDL_SetRenderDrawColor');
  Haal(SDL_RenderClear, 'SDL_RenderClear');
  Haal(SDL_RenderTexture, 'SDL_RenderTexture');
  Haal(SDL_RenderPresent, 'SDL_RenderPresent');
  Haal(SDL_CreateTexture, 'SDL_CreateTexture');
  Haal(SDL_DestroyTexture, 'SDL_DestroyTexture');
  Haal(SDL_SetTextureScaleMode, 'SDL_SetTextureScaleMode');
  Haal(SDL_UpdateTexture, 'SDL_UpdateTexture');
  Haal(SDL_ConvertEventToRenderCoordinates, 'SDL_ConvertEventToRenderCoordinates');
  Haal(SDL_PollEvent, 'SDL_PollEvent');
  Haal(SDL_WaitEventTimeout, 'SDL_WaitEventTimeout');
  Haal(SDL_GetTicks, 'SDL_GetTicks');
  Haal(SDL_GetPerformanceCounter, 'SDL_GetPerformanceCounter');
  Haal(SDL_GetPerformanceFrequency, 'SDL_GetPerformanceFrequency');
  Haal(SDL_Delay, 'SDL_Delay');
  Haal(SDL_StartTextInput, 'SDL_StartTextInput');
  Haal(SDL_CreateSystemCursor, 'SDL_CreateSystemCursor');
  Haal(SDL_SetCursor, 'SDL_SetCursor');
  Haal(SDL_ShowCursor, 'SDL_ShowCursor');
  Haal(SDL_HideCursor, 'SDL_HideCursor');
  if Ontbreekt <> '' then
  begin
    UnloadLibrary(Lib);
    Lib := NilHandle;
    Result := False;
  end;
end;

end.

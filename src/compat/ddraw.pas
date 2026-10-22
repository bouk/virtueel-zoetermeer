unit ddraw;

{ Subset van de DirectDraw-headers (interfaces in de stijl van JEDI/Erik Unger) met een
  softwareimplementatie. ROS.exe gebruikt DirectDraw alleen om de schermmodus te wisselen
  (SetCooperativeLevel, SetDisplayMode, RestoreDisplayMode, Release); die worden
  nagebootst in de vensterbeheerder van de compat-laag. Het aanmaken van surfaces wordt
  niet ondersteund (DDERR_UNSUPPORTED); het spel tekent via GDI. }

{$MODE DELPHI}{$H+}

interface

uses Windows;

const
  DD_OK = 0;
  DD_FALSE = S_FALSE;

  _FACDD = $876;
  MAKE_DDHRESULT = HResult(1 shl 31) or HResult(_FACDD shl 16);

  DDERR_ALREADYINITIALIZED = MAKE_DDHRESULT + 5;
  DDERR_CANNOTATTACHSURFACE = MAKE_DDHRESULT + 10;
  DDERR_CANNOTDETACHSURFACE = MAKE_DDHRESULT + 20;
  DDERR_CURRENTLYNOTAVAIL = MAKE_DDHRESULT + 40;
  DDERR_EXCEPTION = MAKE_DDHRESULT + 55;
  DDERR_GENERIC = E_FAIL;
  DDERR_HEIGHTALIGN = MAKE_DDHRESULT + 90;
  DDERR_INCOMPATIBLEPRIMARY = MAKE_DDHRESULT + 95;
  DDERR_INVALIDCAPS = MAKE_DDHRESULT + 100;
  DDERR_INVALIDCLIPLIST = MAKE_DDHRESULT + 110;
  DDERR_INVALIDMODE = MAKE_DDHRESULT + 120;
  DDERR_INVALIDOBJECT = MAKE_DDHRESULT + 130;
  DDERR_INVALIDPARAMS = E_INVALIDARG;
  DDERR_INVALIDPIXELFORMAT = MAKE_DDHRESULT + 145;
  DDERR_INVALIDRECT = MAKE_DDHRESULT + 150;
  DDERR_LOCKEDSURFACES = MAKE_DDHRESULT + 160;
  DDERR_NO3D = MAKE_DDHRESULT + 170;
  DDERR_NOCLIPLIST = MAKE_DDHRESULT + 205;
  DDERR_NOEXCLUSIVEMODE = MAKE_DDHRESULT + 225;
  DDERR_NOTFOUND = MAKE_DDHRESULT + 255;
  DDERR_OUTOFMEMORY = E_OUTOFMEMORY;
  DDERR_OUTOFVIDEOMEMORY = MAKE_DDHRESULT + 380;
  DDERR_PRIMARYSURFACEALREADYEXISTS = MAKE_DDHRESULT + 564;
  DDERR_SURFACEBUSY = MAKE_DDHRESULT + 430;
  DDERR_SURFACELOST = MAKE_DDHRESULT + 450;
  DDERR_UNSUPPORTED = E_NOTIMPL;
  DDERR_UNSUPPORTEDMODE = MAKE_DDHRESULT + 590;
  DDERR_WASSTILLDRAWING = MAKE_DDHRESULT + 540;
  DDERR_EXCLUSIVEMODEALREADYSET = MAKE_DDHRESULT + 581;
  DDERR_NOTPALETTIZED = MAKE_DDHRESULT + 589;
  DDERR_HWNDSUBCLASSED = MAKE_DDHRESULT + 570;
  DDERR_HWNDALREADYSET = MAKE_DDHRESULT + 571;
  DDERR_NOPALETTEATTACHED = MAKE_DDHRESULT + 572;
  DDERR_NOTINITIALIZED = HResult($800401F0);

  DDSCL_FULLSCREEN = $00000001;
  DDSCL_ALLOWREBOOT = $00000002;
  DDSCL_NOWINDOWCHANGES = $00000004;
  DDSCL_NORMAL = $00000008;
  DDSCL_EXCLUSIVE = $00000010;
  DDSCL_ALLOWMODEX = $00000040;
  DDSCL_SETFOCUSWINDOW = $00000080;
  DDSCL_SETDEVICEWINDOW = $00000100;
  DDSCL_CREATEDEVICEWINDOW = $00000200;
  DDSCL_MULTITHREADED = $00000400;
  DDSCL_FPUSETUP = $00000800;

  DDWAITVB_BLOCKBEGIN = $00000001;
  DDWAITVB_BLOCKBEGINEVENT = $00000002;
  DDWAITVB_BLOCKEND = $00000004;

  DDSD_CAPS = $00000001;
  DDSD_HEIGHT = $00000002;
  DDSD_WIDTH = $00000004;
  DDSD_PITCH = $00000008;
  DDSD_BACKBUFFERCOUNT = $00000020;
  DDSD_PIXELFORMAT = $00001000;
  DDSCAPS_BACKBUFFER = $00000004;
  DDSCAPS_COMPLEX = $00000008;
  DDSCAPS_FLIP = $00000010;
  DDSCAPS_OFFSCREENPLAIN = $00000040;
  DDSCAPS_PRIMARYSURFACE = $00000200;
  DDSCAPS_SYSTEMMEMORY = $00000800;
  DDSCAPS_VIDEOMEMORY = $00004000;

type
  TDDColorKey = record
    dwColorSpaceLowValue: DWORD;
    dwColorSpaceHighValue: DWORD;
  end;
  PDDColorKey = ^TDDColorKey;

  TDDPixelFormat = record
    dwSize: DWORD;
    dwFlags: DWORD;
    dwFourCC: DWORD;
    dwRGBBitCount: DWORD;
    dwRBitMask: DWORD;
    dwGBitMask: DWORD;
    dwBBitMask: DWORD;
    dwRGBAlphaBitMask: DWORD;
  end;
  PDDPixelFormat = ^TDDPixelFormat;

  TDDSCaps = record
    dwCaps: DWORD;
  end;
  PDDSCaps = ^TDDSCaps;

  TDDSurfaceDesc = record
    dwSize: DWORD;
    dwFlags: DWORD;
    dwHeight: DWORD;
    dwWidth: DWORD;
    lPitch: Longint;
    dwBackBufferCount: DWORD;
    dwRefreshRate: DWORD;
    dwAlphaBitDepth: DWORD;
    dwReserved: DWORD;
    lpSurface: Pointer;
    ddckCKDestOverlay: TDDColorKey;
    ddckCKDestBlt: TDDColorKey;
    ddckCKSrcOverlay: TDDColorKey;
    ddckCKSrcBlt: TDDColorKey;
    ddpfPixelFormat: TDDPixelFormat;
    ddsCaps: TDDSCaps;
  end;
  PDDSurfaceDesc = ^TDDSurfaceDesc;

  TDDCaps = record
    dwSize: DWORD;
    dwCaps: DWORD;
    dwCaps2: DWORD;
    Reserved: array[0..77] of DWORD;
  end;
  PDDCaps = ^TDDCaps;

  TDDEnumModesCallback = function(const lpDDSurfaceDesc: TDDSurfaceDesc; lpContext: Pointer): HResult; stdcall;
  TDDEnumSurfacesCallback = Pointer;

  IDirectDrawSurface = interface;
  IDirectDrawPalette = interface;
  IDirectDrawClipper = interface;

  IDirectDraw = interface(IUnknown)
    ['{6C14DB80-A733-11CE-A521-0020AF0BE560}']
    function Compact: HResult; stdcall;
    function CreateClipper(dwFlags: DWORD; out lplpDDClipper: IDirectDrawClipper;
      pUnkOuter: IUnknown): HResult; stdcall;
    function CreatePalette(dwFlags: DWORD; lpColorTable: Pointer;
      out lplpDDPalette: IDirectDrawPalette; pUnkOuter: IUnknown): HResult; stdcall;
    function CreateSurface(var lpDDSurfaceDesc: TDDSurfaceDesc;
      out lplpDDSurface: IDirectDrawSurface; pUnkOuter: IUnknown): HResult; stdcall;
    function DuplicateSurface(lpDDSurface: IDirectDrawSurface;
      out lplpDupDDSurface: IDirectDrawSurface): HResult; stdcall;
    function EnumDisplayModes(dwFlags: DWORD; lpDDSurfaceDesc: PDDSurfaceDesc;
      lpContext: Pointer; lpEnumModesCallback: TDDEnumModesCallback): HResult; stdcall;
    function EnumSurfaces(dwFlags: DWORD; const lpDDSD: TDDSurfaceDesc;
      lpContext: Pointer; lpEnumCallback: TDDEnumSurfacesCallback): HResult; stdcall;
    function FlipToGDISurface: HResult; stdcall;
    function GetCaps(lpDDDriverCaps: PDDCaps; lpDDHELCaps: PDDCaps): HResult; stdcall;
    function GetDisplayMode(out lpDDSurfaceDesc: TDDSurfaceDesc): HResult; stdcall;
    function GetFourCCCodes(var lpNumCodes: DWORD; lpCodes: PDWORD): HResult; stdcall;
    function GetGDISurface(out lplpGDIDDSSurface: IDirectDrawSurface): HResult; stdcall;
    function GetMonitorFrequency(out lpdwFrequency: DWORD): HResult; stdcall;
    function GetScanLine(out lpdwScanLine: DWORD): HResult; stdcall;
    function GetVerticalBlankStatus(out lpbIsInVB: BOOL): HResult; stdcall;
    function Initialize(lpGUID: PGUID): HResult; stdcall;
    function RestoreDisplayMode: HResult; stdcall;
    function SetCooperativeLevel(hWnd: HWND; dwFlags: DWORD): HResult; stdcall;
    function SetDisplayMode(dwWidth: DWORD; dwHeight: DWORD; dwBPP: DWORD): HResult; stdcall;
    function WaitForVerticalBlank(dwFlags: DWORD; hEvent: THandle): HResult; stdcall;
  end;

  IDirectDrawPalette = interface(IUnknown)
    ['{6C14DB84-A733-11CE-A521-0020AF0BE560}']
    function GetCaps(out lpdwCaps: DWORD): HResult; stdcall;
    function GetEntries(dwFlags: DWORD; dwBase: DWORD; dwNumEntries: DWORD; lpEntries: Pointer): HResult; stdcall;
    function Initialize(lpDD: IDirectDraw; dwFlags: DWORD; lpDDColorTable: Pointer): HResult; stdcall;
    function SetEntries(dwFlags: DWORD; dwStartingEntry: DWORD; dwCount: DWORD; lpEntries: Pointer): HResult; stdcall;
  end;

  IDirectDrawClipper = interface(IUnknown)
    ['{6C14DB85-A733-11CE-A521-0020AF0BE560}']
    function GetClipList(lpRect: PRect; lpClipList: Pointer; var lpdwSize: DWORD): HResult; stdcall;
    function GetHWnd(out lphWnd: HWND): HResult; stdcall;
    function Initialize(lpDD: IDirectDraw; dwFlags: DWORD): HResult; stdcall;
    function IsClipListChanged(out lpbChanged: BOOL): HResult; stdcall;
    function SetClipList(lpClipList: Pointer; dwFlags: DWORD): HResult; stdcall;
    function SetHWnd(dwFlags: DWORD; hWnd: HWND): HResult; stdcall;
  end;

  IDirectDrawSurface = interface(IUnknown)
    ['{6C14DB81-A733-11CE-A521-0020AF0BE560}']
    function AddAttachedSurface(lpDDSAttachedSurface: IDirectDrawSurface): HResult; stdcall;
    function AddOverlayDirtyRect(const lpRect: TRect): HResult; stdcall;
    function Blt(lpDestRect: PRect; lpDDSrcSurface: IDirectDrawSurface; lpSrcRect: PRect;
      dwFlags: DWORD; lpDDBltFx: Pointer): HResult; stdcall;
    function BltBatch(const lpDDBltBatch; dwCount: DWORD; dwFlags: DWORD): HResult; stdcall;
    function BltFast(dwX: DWORD; dwY: DWORD; lpDDSrcSurface: IDirectDrawSurface;
      lpSrcRect: PRect; dwTrans: DWORD): HResult; stdcall;
    function DeleteAttachedSurface(dwFlags: DWORD; lpDDSAttachedSurface: IDirectDrawSurface): HResult; stdcall;
    function EnumAttachedSurfaces(lpContext: Pointer; lpEnumSurfacesCallback: TDDEnumSurfacesCallback): HResult; stdcall;
    function EnumOverlayZOrders(dwFlags: DWORD; lpContext: Pointer; lpfnCallback: Pointer): HResult; stdcall;
    function Flip(lpDDSurfaceTargetOverride: IDirectDrawSurface; dwFlags: DWORD): HResult; stdcall;
    function GetAttachedSurface(var lpDDSCaps: TDDSCaps; out lplpDDAttachedSurface: IDirectDrawSurface): HResult; stdcall;
    function GetBltStatus(dwFlags: DWORD): HResult; stdcall;
    function GetCaps(out lpDDSCaps: TDDSCaps): HResult; stdcall;
    function GetClipper(out lplpDDClipper: IDirectDrawClipper): HResult; stdcall;
    function GetColorKey(dwFlags: DWORD; out lpDDColorKey: TDDColorKey): HResult; stdcall;
    function GetDC(out lphDC: HDC): HResult; stdcall;
    function GetFlipStatus(dwFlags: DWORD): HResult; stdcall;
    function GetOverlayPosition(out lplX, lplY: Longint): HResult; stdcall;
    function GetPalette(out lplpDDPalette: IDirectDrawPalette): HResult; stdcall;
    function GetPixelFormat(out lpDDPixelFormat: TDDPixelFormat): HResult; stdcall;
    function GetSurfaceDesc(out lpDDSurfaceDesc: TDDSurfaceDesc): HResult; stdcall;
    function Initialize(lpDD: IDirectDraw; out lpDDSurfaceDesc: TDDSurfaceDesc): HResult; stdcall;
    function IsLost: HResult; stdcall;
    function Lock(lpDestRect: PRect; out lpDDSurfaceDesc: TDDSurfaceDesc; dwFlags: DWORD; hEvent: THandle): HResult; stdcall;
    function ReleaseDC(hDC: HDC): HResult; stdcall;
    function Restore: HResult; stdcall;
    function SetClipper(lpDDClipper: IDirectDrawClipper): HResult; stdcall;
    function SetColorKey(dwFlags: DWORD; lpDDColorKey: PDDColorKey): HResult; stdcall;
    function SetOverlayPosition(lX, lY: Longint): HResult; stdcall;
    function SetPalette(lpDDPalette: IDirectDrawPalette): HResult; stdcall;
    function Unlock(lpSurfaceData: Pointer): HResult; stdcall;
    function UpdateOverlay(lpSrcRect: PRect; lpDDDestSurface: IDirectDrawSurface;
      lpDestRect: PRect; dwFlags: DWORD; lpDDOverlayFx: Pointer): HResult; stdcall;
    function UpdateOverlayDisplay(dwFlags: DWORD): HResult; stdcall;
    function UpdateOverlayZOrder(dwFlags: DWORD; lpDDSReference: IDirectDrawSurface): HResult; stdcall;
  end;

function DirectDrawCreate(lpGUID: PGUID; out lplpDD: IDirectDraw; pUnkOuter: IUnknown): HResult; stdcall;

{ Hook die de vensterbeheerder gebruikt om schermmodus-wijzigingen door te voeren (ingesteld door ZMWin). }
var
  ZMSetDisplayModeHook: function(W, H, Bpp: Integer): Boolean = nil;
  ZMRestoreDisplayModeHook: procedure = nil;

implementation

type
  { Niet referentie-geteld: het spel roept _Release zelf aan en maakt daarna de
    variabele leeg zonder nog een release (semantiek van de oude klassegebaseerde header). }
  TDirectDrawEmu = class(TObject, IUnknown, IDirectDraw)
  private
    FCoopWnd: HWND;
    FModeSet: Boolean;
  public
    function QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} iid: TGuid; out obj): Longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    function _AddRef: Longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    function _Release: Longint; {$IFNDEF WINDOWS}cdecl{$ELSE}stdcall{$ENDIF};
    function Compact: HResult; stdcall;
    function CreateClipper(dwFlags: DWORD; out lplpDDClipper: IDirectDrawClipper;
      pUnkOuter: IUnknown): HResult; stdcall;
    function CreatePalette(dwFlags: DWORD; lpColorTable: Pointer;
      out lplpDDPalette: IDirectDrawPalette; pUnkOuter: IUnknown): HResult; stdcall;
    function CreateSurface(var lpDDSurfaceDesc: TDDSurfaceDesc;
      out lplpDDSurface: IDirectDrawSurface; pUnkOuter: IUnknown): HResult; stdcall;
    function DuplicateSurface(lpDDSurface: IDirectDrawSurface;
      out lplpDupDDSurface: IDirectDrawSurface): HResult; stdcall;
    function EnumDisplayModes(dwFlags: DWORD; lpDDSurfaceDesc: PDDSurfaceDesc;
      lpContext: Pointer; lpEnumModesCallback: TDDEnumModesCallback): HResult; stdcall;
    function EnumSurfaces(dwFlags: DWORD; const lpDDSD: TDDSurfaceDesc;
      lpContext: Pointer; lpEnumCallback: TDDEnumSurfacesCallback): HResult; stdcall;
    function FlipToGDISurface: HResult; stdcall;
    function GetCaps(lpDDDriverCaps: PDDCaps; lpDDHELCaps: PDDCaps): HResult; stdcall;
    function GetDisplayMode(out lpDDSurfaceDesc: TDDSurfaceDesc): HResult; stdcall;
    function GetFourCCCodes(var lpNumCodes: DWORD; lpCodes: PDWORD): HResult; stdcall;
    function GetGDISurface(out lplpGDIDDSSurface: IDirectDrawSurface): HResult; stdcall;
    function GetMonitorFrequency(out lpdwFrequency: DWORD): HResult; stdcall;
    function GetScanLine(out lpdwScanLine: DWORD): HResult; stdcall;
    function GetVerticalBlankStatus(out lpbIsInVB: BOOL): HResult; stdcall;
    function Initialize(lpGUID: PGUID): HResult; stdcall;
    function RestoreDisplayMode: HResult; stdcall;
    function SetCooperativeLevel(hWnd: HWND; dwFlags: DWORD): HResult; stdcall;
    function SetDisplayMode(dwWidth: DWORD; dwHeight: DWORD; dwBPP: DWORD): HResult; stdcall;
    function WaitForVerticalBlank(dwFlags: DWORD; hEvent: THandle): HResult; stdcall;
  end;

function TDirectDrawEmu.QueryInterface({$IFDEF FPC_HAS_CONSTREF}constref{$ELSE}const{$ENDIF} iid: TGuid; out obj): Longint;
begin
  if GetInterface(iid, obj) then Result := S_OK else Result := E_NOINTERFACE;
end;

function TDirectDrawEmu._AddRef: Longint;
begin
  Result := 1;
end;

function TDirectDrawEmu._Release: Longint;
begin
  Result := 1;
end;

function TDirectDrawEmu.Compact: HResult; stdcall;
begin
  Result := DD_OK;
end;

function TDirectDrawEmu.CreateClipper(dwFlags: DWORD; out lplpDDClipper: IDirectDrawClipper;
  pUnkOuter: IUnknown): HResult; stdcall;
begin
  Pointer(lplpDDClipper) := nil;
  Result := DDERR_UNSUPPORTED;
end;

function TDirectDrawEmu.CreatePalette(dwFlags: DWORD; lpColorTable: Pointer;
  out lplpDDPalette: IDirectDrawPalette; pUnkOuter: IUnknown): HResult; stdcall;
begin
  Pointer(lplpDDPalette) := nil;
  Result := DDERR_UNSUPPORTED;
end;

function TDirectDrawEmu.CreateSurface(var lpDDSurfaceDesc: TDDSurfaceDesc;
  out lplpDDSurface: IDirectDrawSurface; pUnkOuter: IUnknown): HResult; stdcall;
begin
  Pointer(lplpDDSurface) := nil;
  Result := DDERR_UNSUPPORTED;
end;

function TDirectDrawEmu.DuplicateSurface(lpDDSurface: IDirectDrawSurface;
  out lplpDupDDSurface: IDirectDrawSurface): HResult; stdcall;
begin
  Pointer(lplpDupDDSurface) := nil;
  Result := DDERR_UNSUPPORTED;
end;

function TDirectDrawEmu.EnumDisplayModes(dwFlags: DWORD; lpDDSurfaceDesc: PDDSurfaceDesc;
  lpContext: Pointer; lpEnumModesCallback: TDDEnumModesCallback): HResult; stdcall;
const
  Modes: array[0..2, 0..1] of Integer = ((640, 480), (800, 600), (1024, 768));
var
  I: Integer;
  D: TDDSurfaceDesc;
begin
  for I := 0 to High(Modes) do
  begin
    FillChar(D, SizeOf(D), 0);
    D.dwSize := SizeOf(D);
    D.dwFlags := DDSD_WIDTH or DDSD_HEIGHT or DDSD_PIXELFORMAT;
    D.dwWidth := Modes[I, 0];
    D.dwHeight := Modes[I, 1];
    D.ddpfPixelFormat.dwRGBBitCount := 32;
    if lpEnumModesCallback(D, lpContext) = 0 then Break;
  end;
  Result := DD_OK;
end;

function TDirectDrawEmu.EnumSurfaces(dwFlags: DWORD; const lpDDSD: TDDSurfaceDesc;
  lpContext: Pointer; lpEnumCallback: TDDEnumSurfacesCallback): HResult; stdcall;
begin
  Result := DD_OK;
end;

function TDirectDrawEmu.FlipToGDISurface: HResult; stdcall;
begin
  Result := DD_OK;
end;

function TDirectDrawEmu.GetCaps(lpDDDriverCaps: PDDCaps; lpDDHELCaps: PDDCaps): HResult; stdcall;
begin
  if lpDDDriverCaps <> nil then FillChar(lpDDDriverCaps^.dwCaps, SizeOf(TDDCaps) - 4, 0);
  if lpDDHELCaps <> nil then FillChar(lpDDHELCaps^.dwCaps, SizeOf(TDDCaps) - 4, 0);
  Result := DD_OK;
end;

function TDirectDrawEmu.GetDisplayMode(out lpDDSurfaceDesc: TDDSurfaceDesc): HResult; stdcall;
begin
  FillChar(lpDDSurfaceDesc, SizeOf(lpDDSurfaceDesc), 0);
  lpDDSurfaceDesc.dwSize := SizeOf(TDDSurfaceDesc);
  lpDDSurfaceDesc.dwFlags := DDSD_WIDTH or DDSD_HEIGHT or DDSD_PIXELFORMAT;
  lpDDSurfaceDesc.dwWidth := GetSystemMetrics(SM_CXSCREEN);
  lpDDSurfaceDesc.dwHeight := GetSystemMetrics(SM_CYSCREEN);
  lpDDSurfaceDesc.ddpfPixelFormat.dwRGBBitCount := 32;
  Result := DD_OK;
end;

function TDirectDrawEmu.GetFourCCCodes(var lpNumCodes: DWORD; lpCodes: PDWORD): HResult; stdcall;
begin
  lpNumCodes := 0;
  Result := DD_OK;
end;

function TDirectDrawEmu.GetGDISurface(out lplpGDIDDSSurface: IDirectDrawSurface): HResult; stdcall;
begin
  Pointer(lplpGDIDDSSurface) := nil;
  Result := DDERR_UNSUPPORTED;
end;

function TDirectDrawEmu.GetMonitorFrequency(out lpdwFrequency: DWORD): HResult; stdcall;
begin
  lpdwFrequency := 60;
  Result := DD_OK;
end;

function TDirectDrawEmu.GetScanLine(out lpdwScanLine: DWORD): HResult; stdcall;
begin
  lpdwScanLine := 0;
  Result := DD_OK;
end;

function TDirectDrawEmu.GetVerticalBlankStatus(out lpbIsInVB: BOOL): HResult; stdcall;
begin
  lpbIsInVB := True;
  Result := DD_OK;
end;

function TDirectDrawEmu.Initialize(lpGUID: PGUID): HResult; stdcall;
begin
  Result := DDERR_ALREADYINITIALIZED;
end;

function TDirectDrawEmu.RestoreDisplayMode: HResult; stdcall;
begin
  if FModeSet and Assigned(ZMRestoreDisplayModeHook) then ZMRestoreDisplayModeHook;
  FModeSet := False;
  Result := DD_OK;
end;

function TDirectDrawEmu.SetCooperativeLevel(hWnd: HWND; dwFlags: DWORD): HResult; stdcall;
begin
  FCoopWnd := hWnd;
  Result := DD_OK;
end;

function TDirectDrawEmu.SetDisplayMode(dwWidth: DWORD; dwHeight: DWORD; dwBPP: DWORD): HResult; stdcall;
begin
  if not (dwBPP in [8, 15, 16, 24, 32]) then Exit(DDERR_INVALIDMODE);
  if Assigned(ZMSetDisplayModeHook) and not ZMSetDisplayModeHook(dwWidth, dwHeight, dwBPP) then
    Exit(DDERR_UNSUPPORTEDMODE);
  FModeSet := True;
  Result := DD_OK;
end;

function TDirectDrawEmu.WaitForVerticalBlank(dwFlags: DWORD; hEvent: THandle): HResult; stdcall;
begin
  Result := DD_OK;
end;

var
  TheDD: TDirectDrawEmu = nil;

function DirectDrawCreate(lpGUID: PGUID; out lplpDD: IDirectDraw; pUnkOuter: IUnknown): HResult; stdcall;
begin
  if TheDD = nil then TheDD := TDirectDrawEmu.Create;
  Pointer(lplpDD) := nil;
  lplpDD := TheDD as IDirectDraw;
  Result := DD_OK;
end;

finalization
  TheDD.Free;
end.

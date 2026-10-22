unit ZMWin;

{ Window manager and message queue of the compat layer.

  There is one emulated screen (a 32-bit bitmap, default 1024x768). Top-level
  windows live on it, child windows inside their parents; every window draws
  straight into the screen through window DCs whose visible region excludes
  overlapping siblings and children (WS_CLIPSIBLINGS | WS_CLIPCHILDREN semantics),
  exactly like non-composited Windows. The backend shows the screen.

  Messages: a posted-message queue, SendMessage = direct call, WM_PAINT and
  WM_TIMER are synthesized when the queue is empty, input comes from the backend.
  All waiting goes through ZMWaitMessage (WaitMessage/GetMessage), the single
  place where the program blocks; a browser backend will hook in there. }

{$MODE DELPHI}{$H+}{$R-}{$Q-}

interface

uses Windows, Messages, ZMGdi, ZMPlatform;

type
  TZMWindow = class;
  TZMWindowArray = array of TZMWindow;

  TZMWindow = class
  public
    Handle: HWND;
    Parent: TZMWindow;
    Owner: HWND;
    Children: TZMWindowArray;       { z-order: index 0 = bottom }
    ClsName: string;
    ClsStyle: UINT;
    ClsBrush: HBRUSH;
    ClsCursor: HCURSOR;
    Style, ExStyle: DWORD;
    R: TRect;                        { window rect in parent client coords (screen for top-level) }
    Text: string;
    Method: TWndMethod;
    Proc: Pointer;                   { TWndProcFunc when Method is not assigned }
    ID: PtrInt;
    UserData: PtrInt;
    UpdRgn: TZMRects;                { client coordinates }
    EraseBk: Boolean;
    NCDirty: Boolean;
    Destroying: Boolean;
    VisGen: Integer;
    VisClientCache, VisWindowCache: TZMRects;
    function NCInsets: TRect;
    function ClientRectScreen: TRect;
    function WindowRectScreen: TRect;
    function IsVisible: Boolean;     { this and all ancestors have WS_VISIBLE }
    function IsEnabledTree: Boolean;
    function TopLevel: TZMWindow;
  end;

  TZMEnumWindowProc = function(Wnd: HWND; Data: Pointer): Boolean;

var
  ZMScreen: TZMBitmap;
  ZMScreenW: Integer = 1024;
  ZMScreenH: Integer = 768;
  ZMQuitRequested: Boolean = False;
  ZMExitCode: Integer = 0;
  { window that gets WM_CLOSE when the user closes the backend window }
  ZMMainWindow: HWND = 0;
  { called when the platform window is closed; default posts WM_CLOSE to ZMMainWindow }
  ZMOnCloseRequest: procedure = nil;
  { idle hook (TApplication.Idle), called by WaitMessage before blocking }
  ZMDesktopColor: LongWord = 0;
  { MessageBox implementation (installed by Forms: an in-framebuffer dialog) }
  ZMMessageBoxHook: function(Wnd: HWND; const Text, Caption: string; Flags: UINT): Integer = nil;

procedure ZMInit;
procedure ZMShutdown;
procedure ZMSetScreenSize(W, H: Integer);
function ZMTicks: LongWord;

function ZMWindowObj(H: HWND): TZMWindow;
function ZMCreateWindow(ExStyle: DWORD; const ClsName, Text: string; Style: DWORD;
  X, Y, W, H: Integer; Parent: HWND; ID: PtrInt; AMethod: TWndMethod; AProc: Pointer): HWND;
function ZMDestroyWindow(H: HWND): Boolean;
procedure ZMSetWindowPos(H, After: HWND; X, Y, W, H2: Integer; Flags: UINT);
function ZMShowWindow(H: HWND; Show: Boolean): Boolean;
procedure ZMSetParent(H, NewParent: HWND);
function ZMWindowFromPoint(P: TPoint; SkipDisabled: Boolean): HWND;
procedure ZMClientToScreen(H: HWND; var P: TPoint);
procedure ZMScreenToClient(H: HWND; var P: TPoint);
procedure ZMEnumTopLevel(Proc: TZMEnumWindowProc; Data: Pointer);
procedure ZMEnumChildren(H: HWND; Proc: TZMEnumWindowProc; Data: Pointer);
function ZMGetWindowInZ(H: HWND; Cmd: UINT): HWND;
procedure ZMSetStyle(H: HWND; NewStyle: DWORD);
procedure ZMSetExStyle(H: HWND; NewStyle: DWORD);

{ painting }
procedure ZMInvalidate(H: HWND; R: PRect; Erase: Boolean);
procedure ZMInvalidateTree(W: TZMWindow; const ScreenR: TRect);
procedure ZMInvalidateScreen(const ScreenR: TRect);
procedure ZMValidate(H: HWND; R: PRect);
function ZMGetUpdateRect(H: HWND; var R: TRect): Boolean;
function ZMGetDC(H: HWND; WholeWindow: Boolean): HDC;
procedure ZMReleaseDC(DC: HDC);
function ZMBeginPaint(H: HWND; var PS: TPaintStruct): HDC;
procedure ZMEndPaint(H: HWND; const PS: TPaintStruct);
procedure ZMUpdateWindow(H: HWND);
procedure ZMPaintNC(W: TZMWindow);

{ messages }
function ZMPostMessage(H: HWND; Msg: UINT; WP: WPARAM; LP: LPARAM): Boolean;
function ZMSendMessage(H: HWND; Msg: UINT; WP: WPARAM; LP: LPARAM): LRESULT;
function ZMPeekMessage(var M: TMsg; H: HWND; MinMsg, MaxMsg, Remove: UINT): Boolean;
function ZMGetMessage(var M: TMsg; H: HWND; MinMsg, MaxMsg: UINT): Boolean;
procedure ZMTranslateMessage(const M: TMsg);
function ZMDispatchMessage(const M: TMsg): LRESULT;
procedure ZMWaitMessage;
function ZMDefWindowProc(H: HWND; Msg: UINT; WP: WPARAM; LP: LPARAM): LRESULT;
function ZMCallWindow(W: TZMWindow; Msg: UINT; WP: WPARAM; LP: LPARAM): LRESULT;
procedure ZMPollInput;
procedure ZMPresent(Force: Boolean);
function ZMMessagePos: TPoint;
function ZMMessageTime: LongWord;

{ timers }
function ZMSetTimer(H: HWND; ID, Elapse: UINT; Proc: Pointer): UINT;
function ZMKillTimer(H: HWND; ID: UINT): Boolean;
function ZMAddMMTimer(Delay: UINT; Proc: Pointer; User: PtrUInt; Periodic: Boolean): UINT;
function ZMKillMMTimer(ID: UINT): Boolean;

{ focus, activation, capture, input state }
function ZMSetFocus(H: HWND): HWND;
function ZMGetFocus: HWND;
function ZMSetActive(H: HWND): HWND;
function ZMGetActive: HWND;
function ZMSetCapture(H: HWND): HWND;
function ZMGetCapture: HWND;
procedure ZMReleaseCapture;
function ZMEnableWindow(H: HWND; Enable: Boolean): Boolean;
function ZMKeyState(VK: Integer): SmallInt;
function ZMCursorPos: TPoint;
procedure ZMSetCursorPos(X, Y: Integer);
procedure ZMSetCursorShape(C: HCURSOR);
function ZMCursorFromId(Id: PtrUInt): HCURSOR;

procedure ZMDumpWindows;

{ Synthetic input, queued exactly like backend events (works headless too).
  Coordinates are relative to the client area of the main form (ZMMainWindow;
  the screen if there is none). Button: 0 = move only, 1 = left, 2 = right. }
procedure ZMInjectMouse(X, Y: Integer; Button: Integer; Down: Boolean);
procedure ZMInjectKey(VK: Word; Down: Boolean);
procedure ZMInjectChar(C: Char);

{ test support: save the emulated screen as PNG }
function ZMSaveScreenshot(const FileName: string): Boolean;

implementation

uses SysUtils, Classes, ZMHandles, ddraw{$IFNDEF ZM_NO_SDL3}, ZMSdl3Backend{$ENDIF};

type
  TTimerRec = record
    Wnd: HWND;
    ID: UINT;
    Interval: UINT;
    Due: LongWord;
    Proc: Pointer;
    Pending: Boolean;
    Active: Boolean;
    IsMM: Boolean;
    User: PtrUInt;
    Periodic: Boolean;
  end;

var
  TopLevels: TZMWindowArray;      { z-order: 0 = bottom }
  Queue: array of TMsg;
  QHead, QCount: Integer;
  Timers: array of TTimerRec;
  NextTimerID: UINT = 1000;
  FocusWnd, ActiveWnd, CaptureWnd: HWND;
  KeyDown: array[0..255] of Boolean;
  MousePos: TPoint;
  LastMsgPos: TPoint;
  LastMsgTime: LongWord;
  LastPresent: LongWord;
  Initialized: Boolean = False;
  BackendOpen: Boolean = False;
  LastClickTime: LongWord;
  LastClickPos: TPoint;
  LastClickBtn: Integer;
  LastClickWnd: HWND;
  InSend: Integer;
  CurCursor: HCURSOR;
  DesktopDirty: Boolean;
  OrigScreenW, OrigScreenH: Integer;
  StartTicks: LongWord;
  ShotFile: string;
  ShotAt: Integer;
  ExitAt: Integer = -1;
  Injected: array of TZMEvent;
  InIdleHook: Boolean = False;
  Script: string;
  ScriptPos: Integer;

const
  CAPTION_H = 18;

{ ---------------------------------------------------------------- basics }

function ZMTicks: LongWord;
begin
  Result := ZMBackend.Ticks;
end;

function ZMWindowObj(H: HWND): TZMWindow;
var
  O: TObject;
begin
  O := ZMHandleObj(H);
  if (O <> nil) and (O is TZMWindow) then Result := TZMWindow(O) else Result := nil;
end;

procedure BumpVis;
begin
  Inc(ZMVisGeneration);
end;

function TZMWindow.NCInsets: TRect;
var
  B: Integer;
begin
  Result := Rect(0, 0, 0, 0);
  B := 0;
  if Style and WS_THICKFRAME <> 0 then B := 4
  else if (Style and WS_DLGFRAME <> 0) or (ExStyle and WS_EX_DLGMODALFRAME <> 0) then B := 3
  else if Style and WS_BORDER <> 0 then B := 1;
  if ExStyle and WS_EX_CLIENTEDGE <> 0 then Inc(B, 2);
  if ExStyle and WS_EX_STATICEDGE <> 0 then Inc(B, 1);
  Result := Rect(B, B, B, B);
  if Style and WS_CAPTION = WS_CAPTION then Inc(Result.Top, CAPTION_H + 1);
end;

function TZMWindow.WindowRectScreen: TRect;
var
  P: TZMWindow;
  O: TRect;
begin
  Result := R;
  P := Parent;
  while P <> nil do
  begin
    O := P.NCInsets;
    OffsetRect(Result, P.R.Left + O.Left, P.R.Top + O.Top);
    P := P.Parent;
  end;
end;

function TZMWindow.ClientRectScreen: TRect;
var
  N: TRect;
begin
  Result := WindowRectScreen;
  N := NCInsets;
  Inc(Result.Left, N.Left);
  Inc(Result.Top, N.Top);
  Dec(Result.Right, N.Right);
  Dec(Result.Bottom, N.Bottom);
  if Result.Right < Result.Left then Result.Right := Result.Left;
  if Result.Bottom < Result.Top then Result.Bottom := Result.Top;
end;

function TZMWindow.IsVisible: Boolean;
var
  W: TZMWindow;
begin
  W := Self;
  while W <> nil do
  begin
    if W.Style and WS_VISIBLE = 0 then Exit(False);
    W := W.Parent;
  end;
  Result := True;
end;

function TZMWindow.IsEnabledTree: Boolean;
var
  W: TZMWindow;
begin
  W := Self;
  while W <> nil do
  begin
    if W.Style and WS_DISABLED <> 0 then Exit(False);
    W := W.Parent;
  end;
  Result := True;
end;

function TZMWindow.TopLevel: TZMWindow;
begin
  Result := Self;
  while Result.Parent <> nil do Result := Result.Parent;
end;

{ ---------------------------------------------------------------- visibility }

procedure ComputeVis(W: TZMWindow);
var
  Vis, Win: TZMRects;
  A, S: TZMWindow;
  I, Idx: Integer;
  Sibs: TZMWindowArray;
  CR: TRect;
begin
  W.VisGen := ZMVisGeneration;
  W.VisClientCache := nil;
  W.VisWindowCache := nil;
  if not W.IsVisible then Exit;
  SetLength(Win, 1);
  Win[0] := W.WindowRectScreen;
  { clip to ancestors' client areas }
  A := W.Parent;
  while A <> nil do
  begin
    Win := RectsIntersectRect(Win, A.ClientRectScreen);
    A := A.Parent;
  end;
  Win := RectsIntersectRect(Win, Rect(0, 0, ZMScreenW, ZMScreenH));
  { subtract siblings above W and above each ancestor }
  A := W;
  while A <> nil do
  begin
    if A.Parent = nil then Sibs := TopLevels else Sibs := A.Parent.Children;
    Idx := -1;
    for I := 0 to High(Sibs) do
      if Sibs[I] = A then begin Idx := I; Break; end;
    for I := Idx + 1 to High(Sibs) do
    begin
      S := Sibs[I];
      if S.Style and WS_VISIBLE <> 0 then
        Win := RectsSubtractRect(Win, S.WindowRectScreen);
    end;
    A := A.Parent;
  end;
  W.VisWindowCache := Win;
  CR := W.ClientRectScreen;
  Vis := RectsIntersectRect(Win, CR);
  for I := 0 to High(W.Children) do
    if W.Children[I].Style and WS_VISIBLE <> 0 then
      Vis := RectsSubtractRect(Vis, W.Children[I].WindowRectScreen);
  W.VisClientCache := Vis;
  { the window rect minus children too (for window DCs) }
  for I := 0 to High(W.Children) do
    if W.Children[I].Style and WS_VISIBLE <> 0 then
      W.VisWindowCache := RectsSubtractRect(W.VisWindowCache, W.Children[I].WindowRectScreen);
end;

function VisClient(W: TZMWindow): TZMRects;
begin
  if W.VisGen <> ZMVisGeneration then ComputeVis(W);
  Result := W.VisClientCache;
end;

function VisWindow(W: TZMWindow): TZMRects;
begin
  if W.VisGen <> ZMVisGeneration then ComputeVis(W);
  Result := W.VisWindowCache;
end;

procedure DCVisProvider(DCObj: TObject);
var
  DC: TZMDC;
  W: TZMWindow;
  R: TRect;
begin
  DC := TZMDC(DCObj);
  W := ZMWindowObj(DC.Wnd);
  if W = nil then
  begin
    DC.VisRgn := nil;
    Exit;
  end;
  if DC.IsWindowDC then
  begin
    DC.VisRgn := VisWindow(W);
    R := W.WindowRectScreen;
  end
  else
  begin
    DC.VisRgn := VisClient(W);
    R := W.ClientRectScreen;
  end;
  DC.DevOrg := Point(R.Left, R.Top);
  DC.InvalidateClip;
end;

{ ---------------------------------------------------------------- init }

function DefaultCloseRequest: Boolean;
begin
  Result := True;
end;

procedure ZMInit;
begin
  if Initialized then Exit;
  Initialized := True;
  InitStockObjects;
  ZMVisProvider := DCVisProvider;
  ZMScreen := TZMBitmap.Create(ZMScreenW, ZMScreenH, 32);
  ZMScreen.Dirty := True;
  OrigScreenW := ZMScreenW;
  OrigScreenH := ZMScreenH;
end;

procedure EnsureBackend;
begin
  if BackendOpen then Exit;
  ZMInit;
  BackendOpen := True;
  if not ZMBackend.Open('Virtueel Zoetermeer', ZMScreenW, ZMScreenH) then
  begin
    WriteLn(StdErr, 'compat: no display backend, running headless');
    ZMFallbackToNull;
    ZMBackend.Open('Virtueel Zoetermeer', ZMScreenW, ZMScreenH);
  end;
  StartTicks := ZMTicks;
  ShotFile := GetEnvironmentVariable('ZM_SCREENSHOT');
  ShotAt := StrToIntDef(GetEnvironmentVariable('ZM_SCREENSHOT_AT'), 3000);
  ExitAt := StrToIntDef(GetEnvironmentVariable('ZM_EXIT_AT'), -1);
  Script := GetEnvironmentVariable('ZM_SCRIPT');
  ScriptPos := 1;
end;

procedure ZMShutdown;
begin
  if BackendOpen then ZMBackend.Close;
  BackendOpen := False;
end;

procedure ZMSetScreenSize(W, H: Integer);
var
  NewScr: TZMBitmap;
begin
  ZMInit;
  if (W = ZMScreenW) and (H = ZMScreenH) then Exit;
  NewScr := TZMBitmap.Create(W, H, 32);
  ZMScreen.Free;
  ZMScreen := NewScr;
  ZMScreenW := W;
  ZMScreenH := H;
  BumpVis;
  if BackendOpen then ZMBackend.Resize(W, H);
  ZMInvalidateScreen(Rect(0, 0, W, H));
end;

function DDSetMode(W, H, Bpp: Integer): Boolean;
begin
  { the display is emulated at a fixed size; mode changes are accepted }
  Result := True;
end;

procedure DDRestoreMode;
begin
end;

{ ---------------------------------------------------------------- creation }

type
  TWinArray = TZMWindowArray;

procedure ArrRemove(var A: TWinArray; W: TZMWindow);
var
  I, J: Integer;
begin
  for I := 0 to High(A) do
    if A[I] = W then
    begin
      for J := I to High(A) - 1 do A[J] := A[J + 1];
      SetLength(A, Length(A) - 1);
      Exit;
    end;
end;

procedure ArrInsert(var A: TWinArray; W: TZMWindow; Index: Integer);
var
  J: Integer;
begin
  if (Index < 0) or (Index > Length(A)) then Index := Length(A);
  SetLength(A, Length(A) + 1);
  for J := High(A) downto Index + 1 do A[J] := A[J - 1];
  A[Index] := W;
end;

function SiblingsOf(W: TZMWindow): TWinArray;
begin
  if W.Parent = nil then Result := TopLevels else Result := W.Parent.Children;
end;

procedure SetSiblings(W: TZMWindow; const A: TWinArray);
begin
  if W.Parent = nil then TopLevels := A else W.Parent.Children := A;
end;

{ insertion index honouring WS_EX_TOPMOST for top-level windows }
function TopInsertIndex(const A: TWinArray; W: TZMWindow): Integer;
begin
  Result := Length(A);
  if (W.Parent = nil) and (W.ExStyle and WS_EX_TOPMOST = 0) then
    while (Result > 0) and (A[Result - 1].ExStyle and WS_EX_TOPMOST <> 0) do Dec(Result);
end;

function ZMCreateWindow(ExStyle: DWORD; const ClsName, Text: string; Style: DWORD;
  X, Y, W, H: Integer; Parent: HWND; ID: PtrInt; AMethod: TWndMethod; AProc: Pointer): HWND;
var
  Win: TZMWindow;
  P: TZMWindow;
  A: TWinArray;
  CS: TCreateStruct;
begin
  ZMInit;
  Win := TZMWindow.Create;
  Win.Handle := ZMAllocHandle(Win);
  Win.ClsName := ClsName;
  Win.ClsStyle := CS_DBLCLKS;
  Win.Style := Style;
  Win.ExStyle := ExStyle;
  Win.Text := Text;
  Win.Method := AMethod;
  Win.Proc := AProc;
  Win.ID := ID;
  if W < 0 then W := 0;
  if H < 0 then H := 0;
  Win.R := Rect(X, Y, X + W, Y + H);
  P := ZMWindowObj(Parent);
  if (P <> nil) and (Style and WS_CHILD <> 0) then
  begin
    Win.Parent := P;
    A := P.Children;
    ArrInsert(A, Win, Length(A));
    P.Children := A;
  end
  else
  begin
    if P <> nil then Win.Owner := Parent;
    A := TopLevels;
    ArrInsert(A, Win, TopInsertIndex(A, Win));
    TopLevels := A;
  end;
  Win.NCDirty := True;
  BumpVis;
  Result := Win.Handle;
  FillChar(CS, SizeOf(CS), 0);
  CS.x := X; CS.y := Y; CS.cx := W; CS.cy := H;
  CS.style := Style;
  CS.dwExStyle := ExStyle;
  CS.hwndParent := Parent;
  ZMCallWindow(Win, WM_NCCREATE, 0, LPARAM(@CS));
  ZMCallWindow(Win, WM_CREATE, 0, LPARAM(@CS));
  if Style and WS_VISIBLE <> 0 then
    ZMInvalidateScreen(Win.WindowRectScreen);
end;

function ZMDestroyWindow(H: HWND): Boolean;
var
  W: TZMWindow;
  A: TWinArray;
  WR: TRect;
  WasVisible: Boolean;
  I: Integer;
begin
  W := ZMWindowObj(H);
  if (W = nil) or W.Destroying then Exit(False);
  W.Destroying := True;
  WasVisible := W.IsVisible;
  WR := W.WindowRectScreen;
  if WasVisible then
  begin
    W.Style := W.Style and not WS_VISIBLE;
    BumpVis;
  end;
  ZMCallWindow(W, WM_DESTROY, 0, 0);
  while Length(W.Children) > 0 do
    if not ZMDestroyWindow(W.Children[High(W.Children)].Handle) then
    begin
      A := W.Children;
      SetLength(A, Length(A) - 1);
      W.Children := A;
    end;
  { owned top-level windows go with their owner }
  I := 0;
  while I <= High(TopLevels) do
  begin
    if (TopLevels[I].Owner = H) and not TopLevels[I].Destroying then
    begin
      ZMDestroyWindow(TopLevels[I].Handle);
      I := 0;
    end
    else
      Inc(I);
  end;
  ZMCallWindow(W, WM_NCDESTROY, 0, 0);
  for I := 0 to High(Timers) do
    if Timers[I].Active and (Timers[I].Wnd = H) then Timers[I].Active := False;
  if FocusWnd = H then FocusWnd := 0;
  if CaptureWnd = H then CaptureWnd := 0;
  if ActiveWnd = H then ActiveWnd := 0;
  if ZMMainWindow = H then ZMMainWindow := 0;
  A := SiblingsOf(W);
  ArrRemove(A, W);
  SetSiblings(W, A);
  { remove queued messages for this window }
  for I := 0 to QCount - 1 do
    if Queue[(QHead + I) mod Length(Queue)].hwnd = H then
      Queue[(QHead + I) mod Length(Queue)].message := WM_NULL;
  BumpVis;
  if WasVisible then ZMInvalidateScreen(WR);
  ZMFreeHandle(H);
  W.Free;
  if (ActiveWnd = 0) and (Length(TopLevels) > 0) then
  begin
    for I := High(TopLevels) downto 0 do
      if TopLevels[I].IsVisible and TopLevels[I].IsEnabledTree then
      begin
        ZMSetActive(TopLevels[I].Handle);
        Break;
      end;
  end;
  Result := True;
end;

procedure ZMSetStyle(H: HWND; NewStyle: DWORD);
var
  W: TZMWindow;
begin
  W := ZMWindowObj(H);
  if W = nil then Exit;
  if W.Style = NewStyle then Exit;
  W.Style := NewStyle;
  BumpVis;
  W.NCDirty := True;
  if W.IsVisible then ZMInvalidateScreen(W.WindowRectScreen);
end;

procedure ZMSetExStyle(H: HWND; NewStyle: DWORD);
var
  W: TZMWindow;
begin
  W := ZMWindowObj(H);
  if W = nil then Exit;
  W.ExStyle := NewStyle;
  BumpVis;
  W.NCDirty := True;
  if W.IsVisible then ZMInvalidateScreen(W.WindowRectScreen);
end;

procedure ZMSetWindowPos(H, After: HWND; X, Y, W, H2: Integer; Flags: UINT);
var
  Win: TZMWindow;
  OldR, OldScr, NewScr: TRect;
  A: TWinArray;
  Moved, Sized, WasVis, Changed: Boolean;
  WP: TWindowPos;
  I: Integer;
begin
  Win := ZMWindowObj(H);
  if Win = nil then Exit;
  OldR := Win.R;
  WasVis := Win.IsVisible;
  OldScr := Win.WindowRectScreen;
  Changed := False;
  if Flags and SWP_NOMOVE = 0 then
  begin
    if (X <> OldR.Left) or (Y <> OldR.Top) then
    begin
      OffsetRect(Win.R, X - Win.R.Left, Y - Win.R.Top);
      Changed := True;
    end;
  end;
  if Flags and SWP_NOSIZE = 0 then
  begin
    if W < 0 then W := 0;
    if H2 < 0 then H2 := 0;
    if (W <> Win.R.Right - Win.R.Left) or (H2 <> Win.R.Bottom - Win.R.Top) then
    begin
      Win.R.Right := Win.R.Left + W;
      Win.R.Bottom := Win.R.Top + H2;
      Changed := True;
    end;
  end;
  if Flags and SWP_NOZORDER = 0 then
  begin
    A := SiblingsOf(Win);
    ArrRemove(A, Win);
    if After = HWND_TOPMOST then
    begin
      Win.ExStyle := Win.ExStyle or WS_EX_TOPMOST;
      ArrInsert(A, Win, Length(A));
    end
    else if After = HWND_NOTOPMOST then
    begin
      Win.ExStyle := Win.ExStyle and not WS_EX_TOPMOST;
      ArrInsert(A, Win, TopInsertIndex(A, Win));
    end
    else if After = HWND_TOP then
      ArrInsert(A, Win, TopInsertIndex(A, Win))
    else if After = HWND_BOTTOM then
      ArrInsert(A, Win, 0)
    else
    begin
      { place below After }
      I := 0;
      while (I <= High(A)) and (A[I].Handle <> After) do Inc(I);
      if I > High(A) then ArrInsert(A, Win, TopInsertIndex(A, Win))
      else ArrInsert(A, Win, I);
    end;
    SetSiblings(Win, A);
    Changed := True;
  end;
  if Flags and SWP_SHOWWINDOW <> 0 then
  begin
    if Win.Style and WS_VISIBLE = 0 then Changed := True;
    Win.Style := Win.Style or WS_VISIBLE;
  end;
  if Flags and SWP_HIDEWINDOW <> 0 then
  begin
    if Win.Style and WS_VISIBLE <> 0 then Changed := True;
    Win.Style := Win.Style and not WS_VISIBLE;
  end;
  if Flags and SWP_FRAMECHANGED <> 0 then Changed := True;
  if not Changed then Exit;
  BumpVis;
  Win.NCDirty := True;
  if WasVis then ZMInvalidateScreen(OldScr);
  NewScr := Win.WindowRectScreen;
  if Win.IsVisible then ZMInvalidateScreen(NewScr);
  Moved := (OldR.Left <> Win.R.Left) or (OldR.Top <> Win.R.Top);
  Sized := (OldR.Right - OldR.Left <> Win.R.Right - Win.R.Left) or
    (OldR.Bottom - OldR.Top <> Win.R.Bottom - Win.R.Top);
  WP.hwnd := H;
  WP.hwndInsertAfter := After;
  WP.x := Win.R.Left; WP.y := Win.R.Top;
  WP.cx := Win.R.Right - Win.R.Left; WP.cy := Win.R.Bottom - Win.R.Top;
  WP.flags := Flags;
  if Flags and SWP_NOSENDCHANGING = 0 then
    ZMCallWindow(Win, WM_WINDOWPOSCHANGED, 0, LPARAM(@WP));
  if Moved then
    ZMCallWindow(Win, WM_MOVE, 0, MakeLParam(Word(Win.R.Left), Word(Win.R.Top)));
  if Sized then
    with Win.ClientRectScreen do
      ZMCallWindow(Win, WM_SIZE, SIZE_RESTORED, MakeLParam(Word(Right - Left), Word(Bottom - Top)));
  if (Flags and SWP_SHOWWINDOW <> 0) and not WasVis then
    ZMCallWindow(Win, WM_SHOWWINDOW, 1, 0)
  else if (Flags and SWP_HIDEWINDOW <> 0) and WasVis then
    ZMCallWindow(Win, WM_SHOWWINDOW, 0, 0);
end;

function ZMShowWindow(H: HWND; Show: Boolean): Boolean;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(H);
  if W = nil then Exit(False);
  Result := W.Style and WS_VISIBLE <> 0;
  if Show = Result then Exit;
  if Show then
    ZMSetWindowPos(H, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_SHOWWINDOW)
  else
  begin
    ZMSetWindowPos(H, 0, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOZORDER or SWP_HIDEWINDOW);
    if (FocusWnd <> 0) then
    begin
      { focus inside a hidden window is lost }
      if (FocusWnd = H) or (IsChild(H, FocusWnd)) then ZMSetFocus(0);
    end;
    if ActiveWnd = H then
    begin
      ActiveWnd := 0;
    end;
  end;
end;

procedure ZMSetParent(H, NewParent: HWND);
var
  W, P: TZMWindow;
  A: TWinArray;
  WasVis: Boolean;
  OldScr: TRect;
begin
  W := ZMWindowObj(H);
  if W = nil then Exit;
  P := ZMWindowObj(NewParent);
  if W.Parent = P then Exit;
  WasVis := W.IsVisible;
  OldScr := W.WindowRectScreen;
  A := SiblingsOf(W);
  ArrRemove(A, W);
  SetSiblings(W, A);
  W.Parent := P;
  if P <> nil then
  begin
    W.Style := W.Style or WS_CHILD;
    A := P.Children;
  end
  else
    A := TopLevels;
  ArrInsert(A, W, TopInsertIndex(A, W));
  SetSiblings(W, A);
  BumpVis;
  if WasVis then ZMInvalidateScreen(OldScr);
  if W.IsVisible then ZMInvalidateScreen(W.WindowRectScreen);
end;

function HitTest(const A: TWinArray; P: TPoint; SkipDisabled: Boolean): TZMWindow;
var
  I: Integer;
  W, C: TZMWindow;
  R: TRect;
begin
  Result := nil;
  for I := High(A) downto 0 do
  begin
    W := A[I];
    if W.Style and WS_VISIBLE = 0 then Continue;
    R := W.WindowRectScreen;
    if not PtInRect(R, P) then Continue;
    if PtInRect(W.ClientRectScreen, P) then
    begin
      C := HitTest(W.Children, P, SkipDisabled);
      if C <> nil then Exit(C);
    end;
    if SkipDisabled and (W.Style and WS_DISABLED <> 0) then Exit(nil);
    Exit(W);
  end;
end;

function ZMWindowFromPoint(P: TPoint; SkipDisabled: Boolean): HWND;
var
  W: TZMWindow;
begin
  W := HitTest(TopLevels, P, SkipDisabled);
  if W = nil then Result := 0 else Result := W.Handle;
end;

procedure ZMClientToScreen(H: HWND; var P: TPoint);
var
  W: TZMWindow;
  R: TRect;
begin
  W := ZMWindowObj(H);
  if W = nil then Exit;
  R := W.ClientRectScreen;
  Inc(P.X, R.Left);
  Inc(P.Y, R.Top);
end;

procedure ZMScreenToClient(H: HWND; var P: TPoint);
var
  W: TZMWindow;
  R: TRect;
begin
  W := ZMWindowObj(H);
  if W = nil then Exit;
  R := W.ClientRectScreen;
  Dec(P.X, R.Left);
  Dec(P.Y, R.Top);
end;

procedure ZMEnumTopLevel(Proc: TZMEnumWindowProc; Data: Pointer);
var
  A: TWinArray;
  I: Integer;
begin
  A := Copy(TopLevels, 0, Length(TopLevels));
  for I := High(A) downto 0 do
    if not Proc(A[I].Handle, Data) then Break;
end;

procedure ZMEnumChildren(H: HWND; Proc: TZMEnumWindowProc; Data: Pointer);
var
  W: TZMWindow;
  A: TWinArray;
  I: Integer;
begin
  W := ZMWindowObj(H);
  if W = nil then Exit;
  A := Copy(W.Children, 0, Length(W.Children));
  for I := High(A) downto 0 do
    if not Proc(A[I].Handle, Data) then Break;
end;

function ZMGetWindowInZ(H: HWND; Cmd: UINT): HWND;
const
  GW_HWNDFIRST = 0; GW_HWNDLAST = 1; GW_HWNDNEXT = 2; GW_HWNDPREV = 3; GW_OWNER = 4; GW_CHILD = 5;
var
  W: TZMWindow;
  A: TWinArray;
  I: Integer;
begin
  Result := 0;
  W := ZMWindowObj(H);
  if W = nil then
  begin
    if (H = 0) and (Cmd = GW_CHILD) and (Length(TopLevels) > 0) then
      Result := TopLevels[High(TopLevels)].Handle;
    Exit;
  end;
  A := SiblingsOf(W);
  case Cmd of
    GW_HWNDFIRST: if Length(A) > 0 then Result := A[High(A)].Handle;
    GW_HWNDLAST: if Length(A) > 0 then Result := A[0].Handle;
    GW_HWNDNEXT, GW_HWNDPREV:
      for I := 0 to High(A) do
        if A[I] = W then
        begin
          if (Cmd = GW_HWNDNEXT) and (I > 0) then Result := A[I - 1].Handle;
          if (Cmd = GW_HWNDPREV) and (I < High(A)) then Result := A[I + 1].Handle;
          Break;
        end;
    GW_OWNER: Result := W.Owner;
    GW_CHILD: if Length(W.Children) > 0 then Result := W.Children[High(W.Children)].Handle;
  end;
end;

{ ---------------------------------------------------------------- painting }

procedure AddUpdate(W: TZMWindow; const ClientR: TRect; Erase: Boolean);
var
  CR: TRect;
  T: TZMRects;
begin
  with W.ClientRectScreen do CR := Rect(0, 0, Right - Left, Bottom - Top);
  SetLength(T, 1);
  T[0] := ClientR;
  T := RectsIntersectRect(T, CR);
  if Length(T) = 0 then Exit;
  W.UpdRgn := RectsUnion(W.UpdRgn, T);
  { keep the region small: collapse to its bounding box when it fragments }
  if Length(W.UpdRgn) > 16 then
  begin
    SetLength(T, 1);
    T[0] := RectsBox(W.UpdRgn);
    W.UpdRgn := T;
  end;
  if Erase then W.EraseBk := True;
end;

procedure ZMInvalidateTree(W: TZMWindow; const ScreenR: TRect);
var
  WR, CR, I2: TRect;
  I: Integer;
begin
  if W.Style and WS_VISIBLE = 0 then Exit;
  WR := W.WindowRectScreen;
  if not IntersectRect(I2, WR, ScreenR) then Exit;
  CR := W.ClientRectScreen;
  if not EqualRect(WR, CR) then
    if not (PtInRect(CR, I2.TopLeft) and PtInRect(CR, Point(I2.Right - 1, I2.Bottom - 1))) then
      W.NCDirty := True;
  if IntersectRect(I2, CR, ScreenR) then
  begin
    OffsetRect(I2, -CR.Left, -CR.Top);
    AddUpdate(W, I2, True);
  end;
  for I := 0 to High(W.Children) do
    ZMInvalidateTree(W.Children[I], ScreenR);
end;

procedure ZMInvalidateScreen(const ScreenR: TRect);
var
  I: Integer;
begin
  ZMInit;
  for I := 0 to High(TopLevels) do
    ZMInvalidateTree(TopLevels[I], ScreenR);
  DesktopDirty := True;
end;

procedure PaintDesktop;
var
  D: TZMRects;
  I, X, Y: Integer;
  P: PLongWord;
begin
  DesktopDirty := False;
  SetLength(D, 1);
  D[0] := Rect(0, 0, ZMScreenW, ZMScreenH);
  for I := 0 to High(TopLevels) do
    if TopLevels[I].Style and WS_VISIBLE <> 0 then
      D := RectsSubtractRect(D, TopLevels[I].WindowRectScreen);
  for I := 0 to High(D) do
    for Y := D[I].Top to D[I].Bottom - 1 do
    begin
      P := PLongWord(ZMScreen.RowPtr(Y)) + D[I].Left;
      for X := D[I].Left to D[I].Right - 1 do
      begin
        P^ := ZMDesktopColor;
        Inc(P);
      end;
    end;
  if Length(D) > 0 then ZMScreen.Dirty := True;
end;

procedure ZMInvalidate(H: HWND; R: PRect; Erase: Boolean);
var
  W: TZMWindow;
  CR: TRect;
begin
  if H = 0 then
  begin
    if R = nil then ZMInvalidateScreen(Rect(0, 0, ZMScreenW, ZMScreenH))
    else ZMInvalidateScreen(R^);
    Exit;
  end;
  W := ZMWindowObj(H);
  if W = nil then Exit;
  if R = nil then
  begin
    with W.ClientRectScreen do CR := Rect(0, 0, Right - Left, Bottom - Top);
    AddUpdate(W, CR, Erase);
  end
  else
    AddUpdate(W, R^, Erase);
end;

procedure ZMValidate(H: HWND; R: PRect);
var
  W: TZMWindow;
begin
  W := ZMWindowObj(H);
  if W = nil then Exit;
  if R = nil then
  begin
    W.UpdRgn := nil;
    W.EraseBk := False;
  end
  else
    W.UpdRgn := RectsSubtractRect(W.UpdRgn, R^);
end;

function ZMGetUpdateRect(H: HWND; var R: TRect): Boolean;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(H);
  if (W = nil) or (Length(W.UpdRgn) = 0) then
  begin
    R := Rect(0, 0, 0, 0);
    Exit(False);
  end;
  R := RectsBox(W.UpdRgn);
  Result := True;
end;

function ZMGetDC(H: HWND; WholeWindow: Boolean): HDC;
var
  DC: TZMDC;
  W: TZMWindow;
begin
  ZMInit;
  DC := TZMDC.Create(ZMScreen);
  if H = 0 then
  begin
    DC.HasVis := False;
    Exit(DC.Handle);
  end;
  W := ZMWindowObj(H);
  if W = nil then
  begin
    DC.Free;
    Exit(0);
  end;
  DC.Wnd := H;
  DC.IsWindowDC := WholeWindow;
  DC.HasVis := True;
  DCVisProvider(DC);
  DC.VisGen := ZMVisGeneration;
  Result := DC.Handle;
end;

procedure ZMReleaseDC(DC: HDC);
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if (D <> nil) and not D.IsMemDC then D.Free;
end;

function ZMBeginPaint(H: HWND; var PS: TPaintStruct): HDC;
var
  W: TZMWindow;
  DC: TZMDC;
  CR: TRect;
begin
  FillChar(PS, SizeOf(PS), 0);
  W := ZMWindowObj(H);
  if W = nil then Exit(0);
  Result := ZMGetDC(H, False);
  DC := GdiDC(Result);
  CR := W.ClientRectScreen;
  DC.PaintRgn := RectsOffset(W.UpdRgn, CR.Left, CR.Top);
  DC.HasPaintRgn := True;
  DC.IsPaintDC := True;
  DC.InvalidateClip;
  PS.hdc := Result;
  PS.rcPaint := RectsBox(W.UpdRgn);
  PS.fErase := W.EraseBk;
  W.UpdRgn := nil;
  if W.EraseBk then
  begin
    W.EraseBk := False;
    if ZMCallWindow(W, WM_ERASEBKGND, WPARAM(Result), 0) <> 0 then
      PS.fErase := False;
  end;
end;

procedure ZMEndPaint(H: HWND; const PS: TPaintStruct);
begin
  ZMReleaseDC(PS.hdc);
end;

procedure PaintWindow(W: TZMWindow);
begin
  if W.NCDirty then ZMPaintNC(W);
  if Length(W.UpdRgn) > 0 then
    ZMCallWindow(W, WM_PAINT, 0, 0);
end;

procedure ZMUpdateWindow(H: HWND);
var
  W: TZMWindow;
  I: Integer;
  Kids: TWinArray;
begin
  W := ZMWindowObj(H);
  if (W = nil) or not W.IsVisible then Exit;
  PaintWindow(W);
  Kids := Copy(W.Children, 0, Length(W.Children));
  for I := 0 to High(Kids) do
    if ZMWindowObj(Kids[I].Handle) = Kids[I] then
      ZMUpdateWindow(Kids[I].Handle);
end;

procedure ZMPaintNC(W: TZMWindow);
var
  DC: HDC;
  D: TZMDC;
  R, CR, TR: TRect;
  N: TRect;
  Act: Boolean;
  LF: TLogFont;
  F: TZMFontObj;
  OldF: TZMFontObj;
  procedure Edge(const A: TRect; TL, BR: COLORREF);
  begin
    GdiFillSolid(D, Rect(A.Left, A.Top, A.Right - 1, A.Top + 1), TL);
    GdiFillSolid(D, Rect(A.Left, A.Top, A.Left + 1, A.Bottom - 1), TL);
    GdiFillSolid(D, Rect(A.Left, A.Bottom - 1, A.Right, A.Bottom), BR);
    GdiFillSolid(D, Rect(A.Right - 1, A.Top, A.Right, A.Bottom), BR);
  end;
begin
  W.NCDirty := False;
  N := W.NCInsets;
  if (N.Left = 0) and (N.Top = 0) and (N.Right = 0) and (N.Bottom = 0) then Exit;
  if not W.IsVisible then Exit;
  DC := ZMGetDC(W.Handle, True);
  D := GdiDC(DC);
  try
    { exclude the client area }
    R := Rect(0, 0, W.R.Right - W.R.Left, W.R.Bottom - W.R.Top);
    CR := Rect(N.Left, N.Top, R.Right - N.Right, R.Bottom - N.Bottom);
    D.St.HasClip := True;
    SetLength(D.St.ClipRgn, 1);
    D.St.ClipRgn[0] := R;
    D.St.ClipRgn := RectsSubtractRect(D.St.ClipRgn, CR);
    D.InvalidateClip;
    if W.ExStyle and WS_EX_CLIENTEDGE <> 0 then
    begin
      Edge(Rect(CR.Left - 2, CR.Top - 2, CR.Right + 2, CR.Bottom + 2), $808080, $FFFFFF);
      Edge(Rect(CR.Left - 1, CR.Top - 1, CR.Right + 1, CR.Bottom + 1), $404040, $C0C0C0);
    end;
    if W.ExStyle and WS_EX_STATICEDGE <> 0 then
      Edge(Rect(CR.Left - 1, CR.Top - 1, CR.Right + 1, CR.Bottom + 1), $808080, $FFFFFF);
    if (W.Style and (WS_THICKFRAME or WS_DLGFRAME) <> 0) or (W.ExStyle and WS_EX_DLGMODALFRAME <> 0) then
    begin
      GdiFillSolid(D, R, SysColors[COLOR_BTNFACE]);
      Edge(R, $C0C0C0, $000000);
      Edge(Rect(1, 1, R.Right - 1, R.Bottom - 1), $FFFFFF, $808080);
    end
    else if W.Style and WS_BORDER <> 0 then
      Edge(R, $000000, $000000);
    if W.Style and WS_CAPTION = WS_CAPTION then
    begin
      Act := (ActiveWnd = W.Handle);
      TR := Rect(N.Left, N.Top - CAPTION_H - 1, R.Right - N.Right, N.Top - 1);
      if Act then GdiFillSolid(D, TR, SysColors[COLOR_ACTIVECAPTION])
      else GdiFillSolid(D, TR, SysColors[COLOR_INACTIVECAPTION]);
      FillChar(LF, SizeOf(LF), 0);
      LF.lfHeight := -11;
      LF.lfWeight := FW_BOLD;
      LF.lfFaceName := 'MS Sans Serif';
      F := TZMFontObj.Create(LF);
      OldF := D.St.Font;
      D.St.Font := F;
      D.St.BkMode := TRANSPARENT;
      if Act then D.St.TextColor := $FFFFFF else D.St.TextColor := $C0C0C0;
      GdiTextOut(D, TR.Left + 4, TR.Top + (CAPTION_H - F.Face^.Height) div 2,
        PAnsiChar(AnsiString(W.Text)), Length(W.Text), False, @TR, nil);
      D.St.Font := OldF;
      F.Free;
      if W.Style and WS_SYSMENU <> 0 then
      begin
        { close button }
        TR := Rect(TR.Right - 18, TR.Top + 2, TR.Right - 2, TR.Bottom - 2);
        GdiFillSolid(D, TR, SysColors[COLOR_BTNFACE]);
        Edge(TR, $FFFFFF, $000000);
        D.St.Pen := TZMPen(StockObjects[BLACK_PEN]);
        GdiLine(D, TR.Left + 4, TR.Top + 3, TR.Right - 5, TR.Bottom - 4, True);
        GdiLine(D, TR.Left + 5, TR.Top + 3, TR.Right - 4, TR.Bottom - 4, True);
        GdiLine(D, TR.Right - 5, TR.Top + 3, TR.Left + 4, TR.Bottom - 4, True);
        GdiLine(D, TR.Right - 4, TR.Top + 3, TR.Left + 5, TR.Bottom - 4, True);
      end;
    end;
  finally
    ZMReleaseDC(DC);
  end;
end;

{ ---------------------------------------------------------------- messages }

function ZMCallWindow(W: TZMWindow; Msg: UINT; WP: WPARAM; LP: LPARAM): LRESULT;
var
  M: TMessage;
begin
  Result := 0;
  if W = nil then Exit;
  if Assigned(W.Method) then
  begin
    FillChar(M, SizeOf(M), 0);
    M.Msg := Msg;
    M.WParam := WP;
    M.LParam := LP;
    Inc(InSend);
    try
      W.Method(M);
    finally
      Dec(InSend);
    end;
    Result := M.Result;
  end
  else if W.Proc <> nil then
    Result := TWndProcFunc(W.Proc)(W.Handle, Msg, WP, LP)
  else
    Result := ZMDefWindowProc(W.Handle, Msg, WP, LP);
end;

function ZMSendMessage(H: HWND; Msg: UINT; WP: WPARAM; LP: LPARAM): LRESULT;
var
  W: TZMWindow;
  I: Integer;
begin
  if H = HWND_BROADCAST then
  begin
    for I := 0 to High(TopLevels) do ZMCallWindow(TopLevels[I], Msg, WP, LP);
    Exit(0);
  end;
  W := ZMWindowObj(H);
  Result := ZMCallWindow(W, Msg, WP, LP);
end;

procedure QueuePush(const M: TMsg);
var
  NewQ: array of TMsg;
  I: Integer;
begin
  if QCount >= Length(Queue) then
  begin
    SetLength(NewQ, Length(Queue) * 2 + 64);
    for I := 0 to QCount - 1 do NewQ[I] := Queue[(QHead + I) mod Length(Queue)];
    Queue := NewQ;
    QHead := 0;
  end;
  Queue[(QHead + QCount) mod Length(Queue)] := M;
  Inc(QCount);
end;

function ZMPostMessage(H: HWND; Msg: UINT; WP: WPARAM; LP: LPARAM): Boolean;
var
  M: TMsg;
begin
  ZMInit;
  if (H <> 0) and (H <> HWND_BROADCAST) and (ZMWindowObj(H) = nil) then Exit(False);
  M.hwnd := H;
  M.message := Msg;
  M.wParam := WP;
  M.lParam := LP;
  M.time := ZMTicks;
  M.pt := MousePos;
  QueuePush(M);
  Result := True;
end;

function MsgMatches(const M: TMsg; H: HWND; MinMsg, MaxMsg: UINT): Boolean;
begin
  Result := False;
  if M.message = WM_NULL then
  begin
    { cancelled message; match so it gets dropped }
    Exit(True);
  end;
  if (H <> 0) and (M.hwnd <> H) and not IsChild(H, M.hwnd) then Exit;
  if (MinMsg <> 0) or (MaxMsg <> 0) then
    if (M.message < MinMsg) or (M.message > MaxMsg) then Exit;
  Result := True;
end;

function CallMMTimers: Boolean; forward;

function FindPaint(H: HWND; var M: TMsg): Boolean;
  function Scan(const A: TWinArray): TZMWindow;
  var
    I: Integer;
    W: TZMWindow;
  begin
    Result := nil;
    for I := 0 to High(A) do
    begin
      W := A[I];
      if W.Style and WS_VISIBLE = 0 then Continue;
      if (Length(W.UpdRgn) > 0) or W.NCDirty then
        if (H = 0) or (W.Handle = H) or IsChild(H, W.Handle) then Exit(W);
      Result := Scan(W.Children);
      if Result <> nil then Exit;
    end;
  end;
var
  W: TZMWindow;
begin
  if DesktopDirty then PaintDesktop;
  repeat
    W := Scan(TopLevels);
    if W = nil then Exit(False);
    if W.NCDirty then ZMPaintNC(W);
  until Length(W.UpdRgn) > 0;
  M.hwnd := W.Handle;
  M.message := WM_PAINT;
  M.wParam := 0;
  M.lParam := 0;
  M.time := ZMTicks;
  M.pt := MousePos;
  Result := True;
end;

function FindTimer(H: HWND; var M: TMsg; Remove: Boolean): Boolean;
var
  I, Best: Integer;
  Now: LongWord;
begin
  Result := False;
  Now := ZMTicks;
  Best := -1;
  for I := 0 to High(Timers) do
    with Timers[I] do
      if Active and not IsMM and (LongInt(Now - Due) >= 0) and ((H = 0) or (Wnd = H)) then
        if (Best < 0) or (LongInt(Timers[Best].Due - Due) > 0) then Best := I;
  if Best < 0 then Exit;
  M.hwnd := Timers[Best].Wnd;
  M.message := WM_TIMER;
  M.wParam := Timers[Best].ID;
  M.lParam := LPARAM(PtrUInt(Timers[Best].Proc));
  M.time := Now;
  M.pt := MousePos;
  if Remove then
  begin
    Timers[Best].Due := Now + Timers[Best].Interval;
  end;
  Result := True;
end;

var
  LastPoll: LongWord;

procedure DumpTree(const A: TWinArray; Indent: string);
var
  I: Integer;
  W: TZMWindow;
begin
  for I := High(A) downto 0 do
  begin
    W := A[I];
    WriteLn(StdErr, Indent, W.Handle, ' ', W.ClsName, ' "', W.Text, '" vis=', Ord(W.Style and WS_VISIBLE <> 0),
      ' dis=', Ord(W.Style and WS_DISABLED <> 0), ' R=', W.R.Left, ',', W.R.Top, ',', W.R.Right, ',', W.R.Bottom,
      ' upd=', Length(W.UpdRgn));
    DumpTree(W.Children, Indent + '  ');
  end;
end;

procedure ZMDumpWindows;
begin
  WriteLn(StdErr, 'window tree (top first), active=', ActiveWnd, ' focus=', FocusWnd, ' capture=', CaptureWnd);
  DumpTree(TopLevels, '  ');
end;

{ ZM_SCRIPT="ms:cmd[:args];..." with cmd = click:x,y | rclick:x,y | move:x,y |
  key:vk | char:c | shot:file.png | exit. Times are ms since start, coordinates
  relative to the main form's client area. For tests without a harness. }
procedure RunScript(T: LongWord);
var
  Item, Cmd, Arg: string;
  P, Q, X, Y: Integer;
  At: Integer;
begin
  while ScriptPos <= Length(Script) do
  begin
    P := ScriptPos;
    Q := P;
    while (Q <= Length(Script)) and (Script[Q] <> ';') do Inc(Q);
    Item := Trim(Copy(Script, P, Q - P));
    At := StrToIntDef(Copy(Item, 1, Pos(':', Item) - 1), 0);
    if Integer(T) < At then Exit;
    ScriptPos := Q + 1;
    Delete(Item, 1, Pos(':', Item));
    if Pos(':', Item) > 0 then
    begin
      Cmd := Copy(Item, 1, Pos(':', Item) - 1);
      Arg := Copy(Item, Pos(':', Item) + 1, MaxInt);
    end
    else
    begin
      Cmd := Item;
      Arg := '';
    end;
    X := StrToIntDef(Copy(Arg, 1, Pos(',', Arg) - 1), 0);
    Y := StrToIntDef(Copy(Arg, Pos(',', Arg) + 1, MaxInt), 0);
    if Cmd = 'click' then
    begin
      ZMInjectMouse(X, Y, 1, True);
      ZMInjectMouse(X, Y, 1, False);
    end
    else if Cmd = 'rclick' then
    begin
      ZMInjectMouse(X, Y, 2, True);
      ZMInjectMouse(X, Y, 2, False);
    end
    else if Cmd = 'move' then ZMInjectMouse(X, Y, 0, False)
    else if Cmd = 'key' then
    begin
      ZMInjectKey(StrToIntDef(Arg, 0), True);
      ZMInjectKey(StrToIntDef(Arg, 0), False);
    end
    else if Cmd = 'char' then
    begin
      if Arg <> '' then ZMInjectChar(Arg[1]);
    end
    else if Cmd = 'shot' then
    begin
      ZMPresent(True);
      if ZMSaveScreenshot(Arg) then WriteLn(StdErr, 'compat: screenshot saved to ', Arg);
    end
    else if Cmd = 'exit' then
      Halt(0);
  end;
end;

procedure TestHooks;
var
  T: LongWord;
begin
  if Script <> '' then RunScript(ZMTicks - StartTicks);
  if (ShotFile = '') and (ExitAt < 0) then Exit;
  T := ZMTicks - StartTicks;
  if (ShotFile <> '') and (Integer(T) >= ShotAt) then
  begin
    if ZMSaveScreenshot(ShotFile) then
      WriteLn(StdErr, 'compat: screenshot saved to ', ShotFile);
    if GetEnvironmentVariable('ZM_DEBUG') <> '' then ZMDumpWindows;
    ShotFile := '';
  end;
  if (ExitAt >= 0) and (Integer(T) >= ExitAt) then
  begin
    WriteLn(StdErr, 'compat: ZM_EXIT_AT reached, exiting');
    Halt(0);
  end;
end;

function ZMPeekMessage(var M: TMsg; H: HWND; MinMsg, MaxMsg, Remove: UINT): Boolean;
var
  I, J, Idx: Integer;
  Now: LongWord;
begin
  ZMInit;
  EnsureBackend;
  Now := ZMTicks;
  if (Now - LastPoll >= 4) or (QCount = 0) or (Length(Injected) > 0) or Assigned(ZMIdleHook) or (Script <> '') then
  begin
    LastPoll := Now;
    ZMPollInput;
    TestHooks;
  end;
  CallMMTimers;
  { posted / input messages }
  for I := 0 to QCount - 1 do
  begin
    Idx := (QHead + I) mod Length(Queue);
    if MsgMatches(Queue[Idx], H, MinMsg, MaxMsg) then
    begin
      M := Queue[Idx];
      if (Remove and PM_REMOVE <> 0) or (M.message = WM_NULL) then
      begin
        { remove entry I }
        J := I;
        while J < QCount - 1 do
        begin
          Queue[(QHead + J) mod Length(Queue)] := Queue[(QHead + J + 1) mod Length(Queue)];
          Inc(J);
        end;
        Dec(QCount);
        if M.message = WM_NULL then
          Exit(ZMPeekMessage(M, H, MinMsg, MaxMsg, Remove));
      end;
      LastMsgPos := M.pt;
      LastMsgTime := M.time;
      if M.message = WM_QUIT then ZMQuitRequested := True;
      Exit(True);
    end;
  end;
  { paint }
  if ((MinMsg = 0) and (MaxMsg = 0)) or ((WM_PAINT >= MinMsg) and (WM_PAINT <= MaxMsg)) then
    if FindPaint(H, M) then
    begin
      LastMsgPos := M.pt;
      LastMsgTime := M.time;
      Exit(True);
    end;
  { timers }
  if ((MinMsg = 0) and (MaxMsg = 0)) or ((WM_TIMER >= MinMsg) and (WM_TIMER <= MaxMsg)) then
    if FindTimer(H, M, Remove and PM_REMOVE <> 0) then
    begin
      LastMsgPos := M.pt;
      LastMsgTime := M.time;
      Exit(True);
    end;
  { nothing: show what was drawn }
  ZMPresent(False);
  Result := False;
end;

function NextTimerDue: Integer;
var
  I: Integer;
  Now: LongWord;
  D: LongInt;
begin
  Result := 50;
  Now := ZMTicks;
  for I := 0 to High(Timers) do
    if Timers[I].Active then
    begin
      D := LongInt(Timers[I].Due - Now);
      if D < 0 then D := 0;
      if D < Result then Result := D;
    end;
end;

procedure ZMWaitMessage;
var
  T: Integer;
  M: TMsg;
begin
  EnsureBackend;
  if ZMPeekMessage(M, 0, 0, 0, PM_NOREMOVE) then Exit;
  ZMPresent(True);
  T := NextTimerDue;
  if T > 0 then ZMBackend.WaitEvent(T);
end;

function ZMGetMessage(var M: TMsg; H: HWND; MinMsg, MaxMsg: UINT): Boolean;
begin
  while not ZMPeekMessage(M, H, MinMsg, MaxMsg, PM_REMOVE) do
    ZMWaitMessage;
  Result := M.message <> WM_QUIT;
end;

procedure ZMTranslateMessage(const M: TMsg);
var
  C: Integer;
begin
  if (M.message <> WM_KEYDOWN) and (M.message <> WM_SYSKEYDOWN) then Exit;
  C := -1;
  case M.wParam of
    VK_RETURN: C := 13;
    VK_ESCAPE: C := 27;
    VK_BACK: C := 8;
    VK_TAB: C := 9;
  else
    if KeyDown[VK_CONTROL] and not KeyDown[VK_MENU] then
    begin
      if (M.wParam >= Ord('A')) and (M.wParam <= Ord('Z')) then C := M.wParam - Ord('A') + 1;
    end;
  end;
  if C >= 0 then
    if M.message = WM_KEYDOWN then
      ZMPostMessage(M.hwnd, WM_CHAR, C, M.lParam)
    else
      ZMPostMessage(M.hwnd, WM_SYSCHAR, C, M.lParam);
end;

function ZMDispatchMessage(const M: TMsg): LRESULT;
var
  W: TZMWindow;
begin
  Result := 0;
  if (M.message = WM_TIMER) and (M.lParam <> 0) then
  begin
    TTimerProc(Pointer(PtrUInt(M.lParam)))(M.hwnd, WM_TIMER, M.wParam, ZMTicks);
    Exit;
  end;
  W := ZMWindowObj(M.hwnd);
  if W = nil then Exit;
  Result := ZMCallWindow(W, M.message, M.wParam, M.lParam);
  if (M.message = WM_PAINT) and (ZMWindowObj(M.hwnd) = W) and (Length(W.UpdRgn) > 0) then
  begin
    { the window did not paint (no BeginPaint): validate so we do not loop }
    W.UpdRgn := nil;
    W.EraseBk := False;
  end;
end;

function ZMDefWindowProc(H: HWND; Msg: UINT; WP: WPARAM; LP: LPARAM): LRESULT;
var
  W: TZMWindow;
  PS: TPaintStruct;
  DC: HDC;
  R: TRect;
  B: TZMBrush;
begin
  Result := 0;
  W := ZMWindowObj(H);
  if W = nil then Exit;
  case Msg of
    WM_PAINT:
      begin
        ZMBeginPaint(H, PS);
        ZMEndPaint(H, PS);
      end;
    WM_ERASEBKGND:
      begin
        B := GdiBrush(W.ClsBrush);
        if B <> nil then
        begin
          DC := HDC(WP);
          with W.ClientRectScreen do R := Rect(0, 0, Right - Left, Bottom - Top);
          GdiFillRect(GdiDC(DC), R, B);
          Result := 1;
        end;
      end;
    WM_CLOSE: ZMDestroyWindow(H);
    WM_SETTEXT:
      begin
        if LP <> 0 then W.Text := StrPas(PAnsiChar(LP)) else W.Text := '';
        W.NCDirty := True;
        Result := 1;
      end;
    WM_GETTEXT:
      begin
        if (LP <> 0) and (WP > 0) then
        begin
          StrPLCopy(PAnsiChar(LP), W.Text, WP - 1);
          Result := StrLen(PAnsiChar(LP));
        end;
      end;
    WM_GETTEXTLENGTH: Result := Length(W.Text);
    WM_ACTIVATE:
      if (LoWord(WP) <> WA_INACTIVE) and (W.Parent = nil) then
        if (FocusWnd = 0) or ((FocusWnd <> H) and not IsChild(H, FocusWnd)) then
          ZMSetFocus(H);
    WM_NCHITTEST: Result := HTCLIENT;
    WM_SETCURSOR:
      begin
        if W.ClsCursor <> 0 then ZMSetCursorShape(W.ClsCursor)
        else ZMSetCursorShape(ZMCursorFromId(32512));
        Result := 1;
      end;
    WM_MOUSEACTIVATE: Result := 1;  { MA_ACTIVATE }
    WM_SYSKEYDOWN:
      if WP = VK_F4 then ZMPostMessage(W.TopLevel.Handle, WM_CLOSE, 0, 0);
    WM_SYSCOMMAND:
      if (WP and $FFF0) = SC_CLOSE then ZMPostMessage(H, WM_CLOSE, 0, 0);
  end;
end;

{ ---------------------------------------------------------------- timers }

function ZMSetTimer(H: HWND; ID, Elapse: UINT; Proc: Pointer): UINT;
var
  I: Integer;
begin
  ZMInit;
  if Elapse < 1 then Elapse := 1;
  if H = 0 then
  begin
    Inc(NextTimerID);
    ID := NextTimerID;
  end;
  for I := 0 to High(Timers) do
    if Timers[I].Active and not Timers[I].IsMM and (Timers[I].Wnd = H) and (Timers[I].ID = ID) then
    begin
      Timers[I].Interval := Elapse;
      Timers[I].Due := ZMTicks + Elapse;
      Timers[I].Proc := Proc;
      Exit(ID);
    end;
  I := 0;
  while (I <= High(Timers)) and Timers[I].Active do Inc(I);
  if I > High(Timers) then SetLength(Timers, I + 1);
  FillChar(Timers[I], SizeOf(TTimerRec), 0);
  Timers[I].Wnd := H;
  Timers[I].ID := ID;
  Timers[I].Interval := Elapse;
  Timers[I].Due := ZMTicks + Elapse;
  Timers[I].Proc := Proc;
  Timers[I].Active := True;
  if ID = 0 then Result := 1 else Result := ID;
end;

function ZMKillTimer(H: HWND; ID: UINT): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Timers) do
    if Timers[I].Active and not Timers[I].IsMM and (Timers[I].Wnd = H) and (Timers[I].ID = ID) then
    begin
      Timers[I].Active := False;
      Result := True;
    end;
end;

function ZMAddMMTimer(Delay: UINT; Proc: Pointer; User: PtrUInt; Periodic: Boolean): UINT;
var
  I: Integer;
begin
  ZMInit;
  if Delay < 1 then Delay := 1;
  I := 0;
  while (I <= High(Timers)) and Timers[I].Active do Inc(I);
  if I > High(Timers) then SetLength(Timers, I + 1);
  FillChar(Timers[I], SizeOf(TTimerRec), 0);
  Inc(NextTimerID);
  Timers[I].ID := NextTimerID;
  Timers[I].Interval := Delay;
  Timers[I].Due := ZMTicks + Delay;
  Timers[I].Proc := Proc;
  Timers[I].User := User;
  Timers[I].Periodic := Periodic;
  Timers[I].IsMM := True;
  Timers[I].Active := True;
  Result := NextTimerID;
end;

function ZMKillMMTimer(ID: UINT): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Timers) do
    if Timers[I].Active and Timers[I].IsMM and (Timers[I].ID = ID) then
    begin
      Timers[I].Active := False;
      Result := True;
    end;
end;

type
  TMMProc = procedure(uTimerID, uMessage: UINT; dwUser, dw1, dw2: PtrUInt); stdcall;

var
  InMMTimer: Boolean = False;

function CallMMTimers: Boolean;
var
  I: Integer;
  Now: LongWord;
  P: TMMProc;
begin
  Result := False;
  if InMMTimer then Exit;
  InMMTimer := True;
  try
    Now := ZMTicks;
    for I := 0 to High(Timers) do
      if Timers[I].Active and Timers[I].IsMM and (LongInt(Now - Timers[I].Due) >= 0) then
      begin
        if Timers[I].Periodic then
          Timers[I].Due := Now + Timers[I].Interval
        else
          Timers[I].Active := False;
        P := TMMProc(Timers[I].Proc);
        if Assigned(P) then P(Timers[I].ID, 0, Timers[I].User, 0, 0);
        Result := True;
      end;
  finally
    InMMTimer := False;
  end;
end;

{ ---------------------------------------------------------------- focus etc. }

function ZMGetFocus: HWND;
begin
  Result := FocusWnd;
end;

function ZMSetFocus(H: HWND): HWND;
var
  Old: HWND;
  W: TZMWindow;
begin
  Result := FocusWnd;
  if H = FocusWnd then Exit;
  W := ZMWindowObj(H);
  if (H <> 0) and (W = nil) then Exit;
  if (W <> nil) and (ActiveWnd <> W.TopLevel.Handle) then
    ZMSetActive(W.TopLevel.Handle);
  Old := FocusWnd;
  FocusWnd := H;
  if (Old <> 0) and (ZMWindowObj(Old) <> nil) then
    ZMSendMessage(Old, WM_KILLFOCUS, H, 0);
  if (FocusWnd = H) and (H <> 0) then
    ZMSendMessage(H, WM_SETFOCUS, Old, 0);
end;

function ZMGetActive: HWND;
begin
  Result := ActiveWnd;
end;

function ZMSetActive(H: HWND): HWND;
var
  Old: HWND;
  W, OW: TZMWindow;
begin
  Result := ActiveWnd;
  W := ZMWindowObj(H);
  if W <> nil then W := W.TopLevel;
  if W <> nil then H := W.Handle;
  if H = ActiveWnd then Exit;
  Old := ActiveWnd;
  ActiveWnd := H;
  OW := ZMWindowObj(Old);
  if OW <> nil then
  begin
    OW.NCDirty := True;
    ZMSendMessage(Old, WM_NCACTIVATE, 0, 0);
    ZMSendMessage(Old, WM_ACTIVATE, WA_INACTIVE, LPARAM(H));
  end;
  if W <> nil then
  begin
    { bring to the top of the z-order }
    ZMSetWindowPos(H, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOSENDCHANGING);
    W.NCDirty := True;
    ZMSendMessage(H, WM_NCACTIVATE, 1, 0);
    ZMSendMessage(H, WM_ACTIVATE, WA_ACTIVE, LPARAM(Old));
  end;
end;

function ZMSetCapture(H: HWND): HWND;
begin
  Result := CaptureWnd;
  CaptureWnd := H;
end;

function ZMGetCapture: HWND;
begin
  Result := CaptureWnd;
end;

procedure ZMReleaseCapture;
var
  Old: HWND;
begin
  Old := CaptureWnd;
  CaptureWnd := 0;
  if Old <> 0 then ZMSendMessage(Old, WM_CAPTURECHANGED, 0, 0);
end;

function ZMEnableWindow(H: HWND; Enable: Boolean): Boolean;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(H);
  if W = nil then Exit(False);
  Result := W.Style and WS_DISABLED <> 0;  { previous state: True = was disabled }
  if Enable = not Result then Exit;
  if Enable then W.Style := W.Style and not WS_DISABLED
  else
  begin
    W.Style := W.Style or WS_DISABLED;
    if (FocusWnd = H) or IsChild(H, FocusWnd) then ZMSetFocus(0);
  end;
  ZMSendMessage(H, WM_ENABLE, Ord(Enable), 0);
end;

function ZMKeyState(VK: Integer): SmallInt;
begin
  if (VK >= 0) and (VK <= 255) and KeyDown[VK] then Result := SmallInt($8000) else Result := 0;
end;

function ZMCursorPos: TPoint;
begin
  Result := MousePos;
end;

procedure ZMSetCursorPos(X, Y: Integer);
begin
  MousePos := Point(X, Y);
end;

function ZMMessagePos: TPoint;
begin
  Result := LastMsgPos;
end;

function ZMMessageTime: LongWord;
begin
  Result := LastMsgTime;
end;

{ cursors are small integers: the IDC_xxx resource ids }
function ZMCursorFromId(Id: PtrUInt): HCURSOR;
begin
  Result := HCURSOR(Id);
end;

procedure ZMSetCursorShape(C: HCURSOR);
var
  S: TZMCursorShape;
begin
  if C = CurCursor then Exit;
  CurCursor := C;
  case C of
    0: S := zcNone;
    32513: S := zcIBeam;
    32514: S := zcWait;
    32515: S := zcCross;
    32640, 32646: S := zcSizeAll;
    32642: S := zcSizeNWSE;
    32643: S := zcSizeNESW;
    32644: S := zcSizeWE;
    32645: S := zcSizeNS;
    32648: S := zcNo;
    32649: S := zcHand;
    32650: S := zcAppStart;
  else
    S := zcArrow;
  end;
  ZMBackend.SetCursor(S);
end;

{ ---------------------------------------------------------------- input }

function MouseKeys: WPARAM;
begin
  Result := 0;
  if KeyDown[VK_LBUTTON] then Result := Result or MK_LBUTTON;
  if KeyDown[VK_RBUTTON] then Result := Result or MK_RBUTTON;
  if KeyDown[VK_MBUTTON] then Result := Result or MK_MBUTTON;
  if KeyDown[VK_SHIFT] then Result := Result or MK_SHIFT;
  if KeyDown[VK_CONTROL] then Result := Result or MK_CONTROL;
end;

procedure PostMouse(Msg: UINT; P: TPoint; ExtraWP: WPARAM);
var
  H: HWND;
  W: TZMWindow;
  C: TPoint;
  IsDown: Boolean;
  Top: TZMWindow;
begin
  IsDown := (Msg = WM_LBUTTONDOWN) or (Msg = WM_RBUTTONDOWN) or (Msg = WM_MBUTTONDOWN);
  if CaptureWnd <> 0 then
    H := CaptureWnd
  else
    H := ZMWindowFromPoint(P, False);
  W := ZMWindowObj(H);
  if W = nil then Exit;
  if (CaptureWnd = 0) and not W.IsEnabledTree then
  begin
    if IsDown then
    begin
      ZMBackend.Beep;
      { bring an enabled (modal) window forward }
      if (ActiveWnd <> 0) then ZMSetActive(ActiveWnd);
    end;
    Exit;
  end;
  if IsDown then
  begin
    Top := W.TopLevel;
    if Top.Handle <> ActiveWnd then
      if ZMSendMessage(H, WM_MOUSEACTIVATE, Top.Handle, MakeLParam(HTCLIENT, Msg)) <> 3 then
        ZMSetActive(Top.Handle);
    W := ZMWindowObj(H);
    if W = nil then Exit;
  end;
  if (CaptureWnd = 0) and not PtInRect(W.ClientRectScreen, P) then Exit;  { non-client }
  ZMSendMessage(H, WM_SETCURSOR, H, MakeLParam(HTCLIENT, Msg));
  C := P;
  ZMScreenToClient(H, C);
  ZMPostMessage(H, Msg, MouseKeys or ExtraWP, MakeLParam(Word(SmallInt(C.X)), Word(SmallInt(C.Y))));
end;

procedure HandleEvent(const E: TZMEvent);
var
  Msg: UINT;
  H: HWND;
  Now: LongWord;
  W: TZMWindow;
  VK: Integer;
  I: Integer;
  LP: LPARAM;
begin
  case E.Kind of
    zeQuit:
      if Assigned(ZMOnCloseRequest) then ZMOnCloseRequest
      else if ZMMainWindow <> 0 then ZMPostMessage(ZMMainWindow, WM_CLOSE, 0, 0)
      else ZMPostMessage(0, WM_QUIT, 0, 0);
    zeExpose:
      ZMScreen.Dirty := True;
    zeMouseMove:
      begin
        MousePos := Point(E.X, E.Y);
        { coalesce: replace a pending WM_MOUSEMOVE }
        for I := QCount - 1 downto 0 do
          if Queue[(QHead + I) mod Length(Queue)].message = WM_MOUSEMOVE then
          begin
            Queue[(QHead + I) mod Length(Queue)].message := WM_NULL;
            Break;
          end
          else if Queue[(QHead + I) mod Length(Queue)].message <> WM_NULL then
            Break;
        PostMouse(WM_MOUSEMOVE, MousePos, 0);
      end;
    zeMouseDown, zeMouseUp:
      begin
        MousePos := Point(E.X, E.Y);
        case E.Button of
          1: VK := VK_LBUTTON;
          2: VK := VK_RBUTTON;
        else
          VK := VK_MBUTTON;
        end;
        KeyDown[VK] := E.Kind = zeMouseDown;
        if E.Kind = zeMouseDown then
        begin
          case E.Button of
            1: Msg := WM_LBUTTONDOWN;
            2: Msg := WM_RBUTTONDOWN;
          else
            Msg := WM_MBUTTONDOWN;
          end;
          Now := ZMTicks;
          if CaptureWnd <> 0 then H := CaptureWnd else H := ZMWindowFromPoint(MousePos, False);
          if (E.Button = LastClickBtn) and (Now - LastClickTime < GetDoubleClickTime) and
            (Abs(MousePos.X - LastClickPos.X) <= 4) and (Abs(MousePos.Y - LastClickPos.Y) <= 4) and
            (H = LastClickWnd) then
          begin
            W := ZMWindowObj(H);
            if (W <> nil) and (W.ClsStyle and CS_DBLCLKS <> 0) then
              Msg := Msg + 2;  { xBUTTONDBLCLK }
            LastClickTime := 0;
          end
          else
          begin
            LastClickTime := Now;
            LastClickPos := MousePos;
            LastClickBtn := E.Button;
            LastClickWnd := H;
          end;
        end
        else
          case E.Button of
            1: Msg := WM_LBUTTONUP;
            2: Msg := WM_RBUTTONUP;
          else
            Msg := WM_MBUTTONUP;
          end;
        PostMouse(Msg, MousePos, 0);
      end;
    zeMouseWheel:
      begin
        if FocusWnd <> 0 then H := FocusWnd else H := ZMWindowFromPoint(MousePos, True);
        if H <> 0 then
          ZMPostMessage(H, WM_MOUSEWHEEL, (MouseKeys and $FFFF) or (WPARAM(Word(SmallInt(E.Wheel))) shl 16),
            MakeLParam(Word(SmallInt(MousePos.X)), Word(SmallInt(MousePos.Y))));
      end;
    zeKeyDown, zeKeyUp:
      begin
        VK := E.Key;
        if (VK <= 0) or (VK > 255) then Exit;
        KeyDown[VK] := E.Kind = zeKeyDown;
        if VK in [VK_LSHIFT, VK_RSHIFT] then KeyDown[VK_SHIFT] := KeyDown[VK_LSHIFT] or KeyDown[VK_RSHIFT];
        if VK in [VK_LCONTROL, VK_RCONTROL] then KeyDown[VK_CONTROL] := KeyDown[VK_LCONTROL] or KeyDown[VK_RCONTROL];
        if VK in [VK_LMENU, VK_RMENU] then KeyDown[VK_MENU] := KeyDown[VK_LMENU] or KeyDown[VK_RMENU];
        case VK of
          VK_LSHIFT, VK_RSHIFT: VK := VK_SHIFT;
          VK_LCONTROL, VK_RCONTROL: VK := VK_CONTROL;
          VK_LMENU, VK_RMENU: VK := VK_MENU;
        end;
        H := FocusWnd;
        if H = 0 then H := ActiveWnd;
        if H = 0 then Exit;
        LP := 1 or (LPARAM(E.ScanCode and $FF) shl 16);
        if E.Repeated then LP := LP or (1 shl 30);
        if KeyDown[VK_MENU] or (VK = VK_MENU) or (VK = VK_F10) then
        begin
          if E.Kind = zeKeyDown then Msg := WM_SYSKEYDOWN else Msg := WM_SYSKEYUP;
          LP := LP or (1 shl 29);
        end
        else if E.Kind = zeKeyDown then Msg := WM_KEYDOWN
        else Msg := WM_KEYUP;
        if E.Kind = zeKeyUp then LP := LP or LPARAM(LongWord($C0000000));
        ZMPostMessage(H, Msg, VK, LP);
      end;
    zeText:
      begin
        if KeyDown[VK_CONTROL] or KeyDown[VK_MENU] then Exit;
        H := FocusWnd;
        if H = 0 then H := ActiveWnd;
        if H = 0 then Exit;
        for I := 1 to Length(E.Text) do
          ZMPostMessage(H, WM_CHAR, Byte(E.Text[I]), 1);
      end;
    zeActivate: ;
    zeDeactivate:
      FillChar(KeyDown, SizeOf(KeyDown), 0);
  end;
end;

procedure Inject(const E: TZMEvent);
begin
  SetLength(Injected, Length(Injected) + 1);
  Injected[High(Injected)] := E;
end;

procedure ZMInjectMouse(X, Y: Integer; Button: Integer; Down: Boolean);
var
  E: TZMEvent;
  P: TPoint;
begin
  FillChar(E, SizeOf(E), 0);
  P := Point(X, Y);
  if ZMMainWindow <> 0 then ZMClientToScreen(ZMMainWindow, P);
  E.X := P.X;
  E.Y := P.Y;
  if Button = 0 then
    E.Kind := zeMouseMove
  else
  begin
    { move first, like a real mouse }
    E.Kind := zeMouseMove;
    Inject(E);
    if Down then E.Kind := zeMouseDown else E.Kind := zeMouseUp;
    E.Button := Button;
  end;
  Inject(E);
end;

procedure ZMInjectKey(VK: Word; Down: Boolean);
var
  E: TZMEvent;
begin
  FillChar(E, SizeOf(E), 0);
  if Down then E.Kind := zeKeyDown else E.Kind := zeKeyUp;
  E.Key := VK;
  Inject(E);
end;

procedure ZMInjectChar(C: Char);
var
  E: TZMEvent;
begin
  FillChar(E, SizeOf(E), 0);
  E.Kind := zeText;
  E.Text := C;
  Inject(E);
end;

procedure ZMPollInput;
var
  E: TZMEvent;
  I: Integer;
  Q: array of TZMEvent;
begin
  EnsureBackend;
  if Assigned(ZMIdleHook) and not InIdleHook then
  begin
    InIdleHook := True;
    try
      ZMIdleHook;
    finally
      InIdleHook := False;
    end;
  end;
  if Length(Injected) > 0 then
  begin
    Q := Injected;
    Injected := nil;
    for I := 0 to High(Q) do HandleEvent(Q[I]);
  end;
  while ZMBackend.PollEvent(E) do
    HandleEvent(E);
end;

procedure ZMPresent(Force: Boolean);
var
  Now: LongWord;
begin
  if (ZMScreen = nil) or not ZMScreen.Dirty then Exit;
  Now := ZMTicks;
  if not Force and (Now - LastPresent < 15) then Exit;
  EnsureBackend;
  LastPresent := Now;
  ZMScreen.Dirty := False;
  ZMBackend.Present(ZMScreen.Bits, ZMScreen.Width, ZMScreen.Height, ZMScreen.Stride);
end;

function ZMSaveScreenshot(const FileName: string): Boolean;
begin
  ZMInit;
  Result := ZMSavePNG(FileName, ZMScreen.Bits, ZMScreen.Width, ZMScreen.Height, ZMScreen.Stride);
end;

initialization
  ZMSetDisplayModeHook := DDSetMode;
  ZMRestoreDisplayModeHook := DDRestoreMode;
end.

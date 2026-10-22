{ Implementatie van de Windows-unit (wordt ingesloten door Windows.pas). }

uses SysUtils, Classes, Math, ZMHandles, ZMGdi, ZMFonts, ZMWin, ZMPlatform, ZMData, ZMProfile;

var
  LastErr: DWORD;
  ScreenModeW: Integer = 0;
  ScreenModeH: Integer = 0;

function ParamStr(Index: Integer): string;
begin
  if Index = 0 then Result := ZMExeName else Result := System.ParamStr(Index);
end;

{ ---------------------------------------------------------------- macro's }

function RGB(r, g, b: Byte): COLORREF;
begin
  Result := r or (g shl 8) or (b shl 16);
end;

function PaletteRGB(r, g, b: Byte): COLORREF;
begin
  Result := $02000000 or RGB(r, g, b);
end;

function PaletteIndex(i: Word): COLORREF;
begin
  Result := $01000000 or i;
end;

function GetRValue(rgb: DWORD): Byte;
begin
  Result := Byte(rgb);
end;

function GetGValue(rgb: DWORD): Byte;
begin
  Result := Byte(rgb shr 8);
end;

function GetBValue(rgb: DWORD): Byte;
begin
  Result := Byte(rgb shr 16);
end;

function MakeLong(a, b: Word): Longint;
begin
  Result := Longint(LongWord(a) or (LongWord(b) shl 16));
end;

function MakeWord(a, b: Byte): Word;
begin
  Result := a or (b shl 8);
end;

function HiWord(l: DWORD): Word;
begin
  Result := l shr 16;
end;

function LoWord(l: DWORD): Word;
begin
  Result := Word(l);
end;

function HiByte(w: Word): Byte;
begin
  Result := w shr 8;
end;

function LoByte(w: Word): Byte;
begin
  Result := Byte(w);
end;

function MakeWParam(l, h: Word): WPARAM;
begin
  Result := WPARAM(LongWord(l) or (LongWord(h) shl 16));
end;

function MakeLParam(l, h: Word): LPARAM;
begin
  Result := LPARAM(LongWord(l) or (LongWord(h) shl 16));
end;

function MakeLResult(l, h: Word): LRESULT;
begin
  Result := LRESULT(LongWord(l) or (LongWord(h) shl 16));
end;

function MakeIntResource(id: PtrUInt): PAnsiChar;
begin
  Result := PAnsiChar(id);
end;

function MakeROP4(fore, back: DWORD): DWORD;
begin
  Result := ((back shl 8) and $FF000000) or fore;
end;

{ ---------------------------------------------------------------- rechthoeken }

function IntersectRect(var lprcDst: TRect; const lprcSrc1, lprcSrc2: TRect): BOOL;
var
  R: TRect;
begin
  R.Left := Max(lprcSrc1.Left, lprcSrc2.Left);
  R.Top := Max(lprcSrc1.Top, lprcSrc2.Top);
  R.Right := Min(lprcSrc1.Right, lprcSrc2.Right);
  R.Bottom := Min(lprcSrc1.Bottom, lprcSrc2.Bottom);
  if (R.Right <= R.Left) or (R.Bottom <= R.Top) then
  begin
    lprcDst := Types.Rect(0, 0, 0, 0);
    Result := False;
  end
  else
  begin
    lprcDst := R;
    Result := True;
  end;
end;

function UnionRect(var lprcDst: TRect; const lprcSrc1, lprcSrc2: TRect): BOOL;
var
  E1, E2: Boolean;
  R: TRect;
begin
  E1 := (lprcSrc1.Right <= lprcSrc1.Left) or (lprcSrc1.Bottom <= lprcSrc1.Top);
  E2 := (lprcSrc2.Right <= lprcSrc2.Left) or (lprcSrc2.Bottom <= lprcSrc2.Top);
  if E1 and E2 then
  begin
    lprcDst := Types.Rect(0, 0, 0, 0);
    Exit(False);
  end;
  if E1 then R := lprcSrc2
  else if E2 then R := lprcSrc1
  else
  begin
    R.Left := Min(lprcSrc1.Left, lprcSrc2.Left);
    R.Top := Min(lprcSrc1.Top, lprcSrc2.Top);
    R.Right := Max(lprcSrc1.Right, lprcSrc2.Right);
    R.Bottom := Max(lprcSrc1.Bottom, lprcSrc2.Bottom);
  end;
  lprcDst := R;
  Result := True;
end;

function SubtractRect(var lprcDst: TRect; const lprcSrc1, lprcSrc2: TRect): BOOL;
var
  R, I: TRect;
begin
  R := lprcSrc1;
  if IntersectRect(I, lprcSrc1, lprcSrc2) then
  begin
    if (I.Left = R.Left) and (I.Right = R.Right) then
    begin
      if I.Top = R.Top then R.Top := I.Bottom
      else if I.Bottom = R.Bottom then R.Bottom := I.Top;
    end
    else if (I.Top = R.Top) and (I.Bottom = R.Bottom) then
    begin
      if I.Left = R.Left then R.Left := I.Right
      else if I.Right = R.Right then R.Right := I.Left;
    end;
  end;
  lprcDst := R;
  Result := (R.Right > R.Left) and (R.Bottom > R.Top);
end;

function OffsetRect(var lprc: TRect; dx, dy: Integer): BOOL;
begin
  Inc(lprc.Left, dx);
  Inc(lprc.Right, dx);
  Inc(lprc.Top, dy);
  Inc(lprc.Bottom, dy);
  Result := True;
end;

function InflateRect(var lprc: TRect; dx, dy: Integer): BOOL;
begin
  Dec(lprc.Left, dx);
  Inc(lprc.Right, dx);
  Dec(lprc.Top, dy);
  Inc(lprc.Bottom, dy);
  Result := True;
end;

function PtInRect(const lprc: TRect; pt: TPoint): BOOL;
begin
  Result := (pt.X >= lprc.Left) and (pt.X < lprc.Right) and (pt.Y >= lprc.Top) and (pt.Y < lprc.Bottom);
end;

function IsRectEmpty(const lprc: TRect): BOOL;
begin
  Result := (lprc.Right <= lprc.Left) or (lprc.Bottom <= lprc.Top);
end;

function EqualRect(const lprc1, lprc2: TRect): BOOL;
begin
  Result := (lprc1.Left = lprc2.Left) and (lprc1.Top = lprc2.Top) and
    (lprc1.Right = lprc2.Right) and (lprc1.Bottom = lprc2.Bottom);
end;

function SetRect(var lprc: TRect; xLeft, yTop, xRight, yBottom: Integer): BOOL;
begin
  lprc := Types.Rect(xLeft, yTop, xRight, yBottom);
  Result := True;
end;

function SetRectEmpty(var lprc: TRect): BOOL;
begin
  lprc := Types.Rect(0, 0, 0, 0);
  Result := True;
end;

function CopyRect(var lprcDst: TRect; const lprcSrc: TRect): BOOL;
begin
  lprcDst := lprcSrc;
  Result := True;
end;

{ ---------------------------------------------------------------- apparaatcontexts (DC's) }

function GetDC(hWnd: HWND): HDC;
begin
  Result := ZMGetDC(hWnd, False);
end;

function GetWindowDC(hWnd: HWND): HDC;
begin
  Result := ZMGetDC(hWnd, True);
end;

function GetDCEx(hWnd: HWND; hrgnClip: HRGN; flags: DWORD): HDC;
begin
  Result := ZMGetDC(hWnd, flags and 1 <> 0);
end;

function ReleaseDC(hWnd: HWND; hDC: HDC): Integer;
begin
  ZMReleaseDC(hDC);
  Result := 1;
end;

function CreateCompatibleDC(DC: HDC): HDC;
var
  D: TZMDC;
begin
  ZMInit;
  D := TZMDC.Create(nil);
  D.IsMemDC := True;
  D.DefBitmap := TZMBitmap.Create(1, 1, 1);
  D.SelectBitmap(D.DefBitmap);
  Result := D.Handle;
end;

function CreateDC(lpszDriver, lpszDevice, lpszOutput: PAnsiChar; lpdvmInit: PDeviceMode): HDC;
begin
  Result := ZMGetDC(0, False);
end;

function DeleteDC(DC: HDC): BOOL;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  Result := D <> nil;
  D.Free;
end;

function SaveDC(DC: HDC): Integer;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(0);
  SetLength(D.Saved, Length(D.Saved) + 1);
  D.Saved[High(D.Saved)] := D.St;
  D.Saved[High(D.Saved)].ClipRgn := RectsCopy(D.St.ClipRgn);
  Result := Length(D.Saved);
end;

function RestoreDC(DC: HDC; SavedDC: Integer): BOOL;
var
  D: TZMDC;
  N: Integer;
begin
  D := GdiDC(DC);
  if (D = nil) or (Length(D.Saved) = 0) then Exit(False);
  if SavedDC < 0 then N := Length(D.Saved) + SavedDC else N := SavedDC - 1;
  if (N < 0) or (N > High(D.Saved)) then Exit(False);
  D.St := D.Saved[N];
  SetLength(D.Saved, N);
  D.InvalidateClip;
  Result := True;
end;

function GetDeviceCaps(DC: HDC; Index: Integer): Integer;
var
  D: TZMDC;
  BPP: Integer;
begin
  D := GdiDC(DC);
  BPP := 32;
  if (D <> nil) and D.IsMemDC and (D.Target <> nil) then BPP := D.Target.BPP;
  case Index of
    DRIVERVERSION: Result := $400;
    TECHNOLOGY: Result := 1;  { DT_RASDISPLAY }
    HORZSIZE: Result := ZMScreenW * 254 div 960;
    VERTSIZE: Result := ZMScreenH * 254 div 960;
    HORZRES, DESKTOPHORZRES: Result := ZMScreenW;
    VERTRES, DESKTOPVERTRES: Result := ZMScreenH;
    BITSPIXEL: Result := BPP;
    PLANES: Result := 1;
    NUMCOLORS: if BPP <= 8 then Result := 1 shl BPP else Result := -1;
    RASTERCAPS: Result := RC_BITBLT or RC_BITMAP64 or RC_DI_BITMAP or RC_DIBTODEV or
      RC_STRETCHBLT or RC_STRETCHDIB or RC_FLOODFILL;
    LOGPIXELSX, LOGPIXELSY: Result := 96;
    SIZEPALETTE: Result := 0;
    NUMRESERVED: Result := 20;
    COLORRES: Result := 24;
    VREFRESH: Result := 60;
    ASPECTX, ASPECTY: Result := 36;
    ASPECTXY: Result := 51;
  else
    Result := 0;
  end;
end;

function WindowFromDC(DC: HDC): HWND;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Result := 0 else Result := D.Wnd;
end;

function SelectObject(DC: HDC; p2: HGDIOBJ): HGDIOBJ;
var
  D: TZMDC;
  O: TZMGdiObj;
begin
  Result := 0;
  D := GdiDC(DC);
  O := GdiObj(p2);
  if (D = nil) or (O = nil) then Exit(HGDI_ERROR);
  if O is TZMPen then
  begin
    Result := H2(D.St.Pen);
    D.St.Pen := TZMPen(O);
  end
  else if O is TZMBrush then
  begin
    Result := H2(D.St.Brush);
    D.St.Brush := TZMBrush(O);
  end
  else if O is TZMFontObj then
  begin
    Result := H2(D.St.Font);
    D.St.Font := TZMFontObj(O);
  end
  else if O is TZMBitmap then
  begin
    if not D.IsMemDC then Exit(0);
    Result := H2(D.Target);
    D.SelectBitmap(TZMBitmap(O));
  end
  else if O is TZMRegion then
  begin
    SelectClipRgn(DC, p2);
    Result := SIMPLEREGION;
  end
  else if O is TZMPalette then
  begin
    Result := H2(D.St.Palette);
    D.St.Palette := TZMPalette(O);
  end;
end;

function DeleteObject(p1: HGDIOBJ): BOOL;
var
  O: TZMGdiObj;
  B: TZMBitmap;
begin
  O := GdiObj(p1);
  if (O = nil) or O.IsStock or (O is TZMDC) then Exit(O <> nil);
  if O is TZMBitmap then
  begin
    B := TZMBitmap(O);
    if (B.SelectedIn <> nil) and (TZMDC(B.SelectedIn).Target = B) then
      Exit(False);  { nog geselecteerd in een DC, zoals in Windows }
  end;
  O.Free;
  Result := True;
end;

function GetStockObject(Index: Integer): HGDIOBJ;
begin
  ZMInit;
  if (Index >= 0) and (Index <= High(StockObjects)) and (StockObjects[Index] <> nil) then
    Result := StockObjects[Index].Handle
  else
    Result := 0;
end;

function GetCurrentObject(DC: HDC; p2: UINT): HGDIOBJ;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  Result := 0;
  if D = nil then Exit;
  case p2 of
    OBJ_PEN: Result := H2(D.St.Pen);
    OBJ_BRUSH: Result := H2(D.St.Brush);
    OBJ_FONT: Result := H2(D.St.Font);
    OBJ_PAL: Result := H2(D.St.Palette);
    OBJ_BITMAP: Result := H2(D.Target);
  end;
end;

function GetObject(p1: HGDIOBJ; p2: Integer; p3: Pointer): Integer;
var
  O: TZMGdiObj;
  BM: TBitmap;
  DS: TDIBSection;
  LB: TLogBrush;
  LP: TLogPen;
  N: Word;
begin
  Result := 0;
  O := GdiObj(p1);
  if O = nil then Exit;
  if O is TZMBitmap then
    with TZMBitmap(O) do
    begin
      FillChar(DS, SizeOf(DS), 0);
      DS.dsBm.bmWidth := Width;
      DS.dsBm.bmHeight := Height;
      DS.dsBm.bmWidthBytes := Stride;
      DS.dsBm.bmPlanes := 1;
      DS.dsBm.bmBitsPixel := BPP;
      DS.dsBm.bmBits := Bits;
      DS.dsBmih.biSize := SizeOf(TBitmapInfoHeader);
      DS.dsBmih.biWidth := Width;
      DS.dsBmih.biHeight := -Height;  { van boven naar beneden }
      DS.dsBmih.biPlanes := 1;
      DS.dsBmih.biBitCount := BPP;
      DS.dsBmih.biSizeImage := Stride * Height;
      if BPP <= 8 then DS.dsBmih.biClrUsed := NumColors;
      if p3 = nil then Exit(SizeOf(TDIBSection));
      if p2 >= SizeOf(TDIBSection) then
      begin
        Move(DS, p3^, SizeOf(DS));
        Result := SizeOf(DS);
      end
      else
      begin
        BM := DS.dsBm;
        Result := Min(p2, SizeOf(BM));
        Move(BM, p3^, Result);
      end;
    end
  else if O is TZMFontObj then
  begin
    if p3 = nil then Exit(SizeOf(TLogFont));
    Result := Min(p2, SizeOf(TLogFont));
    Move(TZMFontObj(O).LF, p3^, Result);
  end
  else if O is TZMBrush then
  begin
    LB.lbStyle := TZMBrush(O).Style;
    LB.lbColor := TZMBrush(O).Color;
    LB.lbHatch := TZMBrush(O).Hatch;
    if p3 = nil then Exit(SizeOf(LB));
    Result := Min(p2, SizeOf(LB));
    Move(LB, p3^, Result);
  end
  else if O is TZMPen then
  begin
    LP.lopnStyle := TZMPen(O).Style;
    LP.lopnWidth := Types.Point(TZMPen(O).Width, 0);
    LP.lopnColor := TZMPen(O).Color;
    if p3 = nil then Exit(SizeOf(LP));
    Result := Min(p2, SizeOf(LP));
    Move(LP, p3^, Result);
  end
  else if O is TZMPalette then
  begin
    N := TZMPalette(O).Count;
    if p3 <> nil then PWord(p3)^ := N;
    Result := 2;
  end;
end;

function GetObjectType(h: HGDIOBJ): DWORD;
var
  O: TZMGdiObj;
begin
  O := GdiObj(h);
  if O = nil then Exit(0);
  Result := O.ObjType;
  if (O is TZMDC) and TZMDC(O).IsMemDC then Result := OBJ_MEMDC;
end;

function SetBkColor(DC: HDC; Color: COLORREF): COLORREF;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(CLR_INVALID);
  Result := D.St.BkColor;
  D.St.BkColor := Color;
end;

function GetBkColor(DC: HDC): COLORREF;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Result := CLR_INVALID else Result := D.St.BkColor;
end;

function SetBkMode(DC: HDC; BkMode: Integer): Integer;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(0);
  Result := D.St.BkMode;
  D.St.BkMode := BkMode;
end;

function GetBkMode(DC: HDC): Integer;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Result := 0 else Result := D.St.BkMode;
end;

function SetTextColor(DC: HDC; Color: COLORREF): COLORREF;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(CLR_INVALID);
  Result := D.St.TextColor;
  D.St.TextColor := Color;
end;

function GetTextColor(DC: HDC): COLORREF;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Result := CLR_INVALID else Result := D.St.TextColor;
end;

function SetTextAlign(DC: HDC; Flags: UINT): UINT;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(GDI_ERROR);
  Result := D.St.TextAlign;
  D.St.TextAlign := Flags;
end;

function GetTextAlign(DC: HDC): UINT;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Result := GDI_ERROR else Result := D.St.TextAlign;
end;

function SetROP2(DC: HDC; p2: Integer): Integer;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(0);
  Result := D.St.ROP2;
  D.St.ROP2 := p2;
end;

function GetROP2(DC: HDC): Integer;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Result := 0 else Result := D.St.ROP2;
end;

function SetStretchBltMode(DC: HDC; StretchMode: Integer): Integer;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(0);
  Result := D.St.StretchMode;
  D.St.StretchMode := StretchMode;
end;

function GetStretchBltMode(DC: HDC): Integer;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Result := 0 else Result := D.St.StretchMode;
end;

function SetBrushOrgEx(DC: HDC; X, Y: Integer; PrevPt: PPoint): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  if PrevPt <> nil then PrevPt^ := D.St.BrushOrg;
  D.St.BrushOrg := Types.Point(X, Y);
  Result := True;
end;

function SetWindowOrgEx(DC: HDC; X, Y: Integer; Point: PPoint): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  if Point <> nil then Point^ := D.St.WinOrg;
  D.St.WinOrg := Types.Point(X, Y);
  Result := True;
end;

function GetWindowOrgEx(DC: HDC; var Point: TPoint): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  Point := D.St.WinOrg;
  Result := True;
end;

function SetViewportOrgEx(DC: HDC; X, Y: Integer; Point: PPoint): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  if Point <> nil then Point^ := D.St.VpOrg;
  D.St.VpOrg := Types.Point(X, Y);
  Result := True;
end;

function GetViewportOrgEx(DC: HDC; var Point: TPoint): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  Point := D.St.VpOrg;
  Result := True;
end;

function SetMapMode(DC: HDC; p2: Integer): Integer;
begin
  Result := 1;  { alleen MM_TEXT }
end;

function MoveToEx(DC: HDC; p2, p3: Integer; p4: PPoint): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  if p4 <> nil then p4^ := D.St.CurPos;
  D.St.CurPos := Types.Point(p2, p3);
  Result := True;
end;

function LineTo(DC: HDC; X, Y: Integer): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  GdiLine(D, D.St.CurPos.X, D.St.CurPos.Y, X, Y, False);
  D.St.CurPos := Types.Point(X, Y);
  Result := True;
end;

function GetCurrentPositionEx(DC: HDC; Point: PPoint): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if (D = nil) or (Point = nil) then Exit(False);
  Point^ := D.St.CurPos;
  Result := True;
end;

function Rectangle(DC: HDC; X1, Y1, X2, Y2: Integer): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  GdiRectangle(D, X1, Y1, X2, Y2);
  Result := True;
end;

function RoundRect(DC: HDC; X1, Y1, X2, Y2, X3, Y3: Integer): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  GdiRoundRect(D, X1, Y1, X2, Y2, X3, Y3);
  Result := True;
end;

function Ellipse(DC: HDC; X1, Y1, X2, Y2: Integer): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  GdiEllipse(D, X1, Y1, X2, Y2);
  Result := True;
end;

function Polygon(DC: HDC; const Points; Count: Integer): BOOL;
var
  D: TZMDC;
  P: array of TPoint;
begin
  D := GdiDC(DC);
  if (D = nil) or (Count <= 0) then Exit(False);
  SetLength(P, Count);
  Move(Points, P[0], Count * SizeOf(TPoint));
  GdiPolygon(D, P, True);
  Result := True;
end;

function Polyline(DC: HDC; const Points; Count: Integer): BOOL;
var
  D: TZMDC;
  P: array of TPoint;
begin
  D := GdiDC(DC);
  if (D = nil) or (Count <= 0) then Exit(False);
  SetLength(P, Count);
  Move(Points, P[0], Count * SizeOf(TPoint));
  GdiPolyline(D, P);
  Result := True;
end;

function FillRect(hDC: HDC; const lprc: TRect; hbr: HBRUSH): Integer;
var
  D: TZMDC;
begin
  D := GdiDC(hDC);
  if D = nil then Exit(0);
  GdiFillRect(D, lprc, GdiBrush(hbr));
  Result := 1;
end;

function FrameRect(hDC: HDC; const lprc: TRect; hbr: HBRUSH): Integer;
var
  D: TZMDC;
  B: TZMBrush;
begin
  D := GdiDC(hDC);
  B := GdiBrush(hbr);
  if (D = nil) or (B = nil) then Exit(0);
  with lprc do
  begin
    GdiFillRect(D, Types.Rect(Left, Top, Right, Top + 1), B);
    GdiFillRect(D, Types.Rect(Left, Bottom - 1, Right, Bottom), B);
    GdiFillRect(D, Types.Rect(Left, Top, Left + 1, Bottom), B);
    GdiFillRect(D, Types.Rect(Right - 1, Top, Right, Bottom), B);
  end;
  Result := 1;
end;

function InvertRect(hDC: HDC; const lprc: TRect): BOOL;
var D: TZMDC;
begin
  D := GdiDC(hDC);
  if D = nil then Exit(False);
  GdiInvertRect(D, lprc);
  Result := True;
end;

function DrawFocusRect(hDC: HDC; const lprc: TRect): BOOL;
var D: TZMDC;
begin
  D := GdiDC(hDC);
  if D = nil then Exit(False);
  GdiFocusRect(D, lprc);
  Result := True;
end;

function DrawEdge(hdc: HDC; var qrc: TRect; edge: UINT; grfFlags: UINT): BOOL;
var
  D: TZMDC;
  R: TRect;
  procedure Line(Outer: Boolean; TL, BR: COLORREF);
  begin
    if grfFlags and BF_FLAT <> 0 then
    begin
      TL := SysColors[COLOR_BTNSHADOW];
      BR := TL;
    end;
    if grfFlags and BF_TOP <> 0 then GdiFillSolid(D, Types.Rect(R.Left, R.Top, R.Right, R.Top + 1), TL);
    if grfFlags and BF_LEFT <> 0 then GdiFillSolid(D, Types.Rect(R.Left, R.Top, R.Left + 1, R.Bottom), TL);
    if grfFlags and BF_BOTTOM <> 0 then GdiFillSolid(D, Types.Rect(R.Left, R.Bottom - 1, R.Right, R.Bottom), BR);
    if grfFlags and BF_RIGHT <> 0 then GdiFillSolid(D, Types.Rect(R.Right - 1, R.Top, R.Right, R.Bottom), BR);
    if grfFlags and BF_TOP <> 0 then Inc(R.Top);
    if grfFlags and BF_LEFT <> 0 then Inc(R.Left);
    if grfFlags and BF_BOTTOM <> 0 then Dec(R.Bottom);
    if grfFlags and BF_RIGHT <> 0 then Dec(R.Right);
  end;
begin
  D := GdiDC(hdc);
  if D = nil then Exit(False);
  R := qrc;
  if edge and BDR_RAISEDOUTER <> 0 then Line(True, SysColors[COLOR_3DLIGHT], SysColors[COLOR_3DDKSHADOW])
  else if edge and BDR_SUNKENOUTER <> 0 then Line(True, SysColors[COLOR_BTNSHADOW], SysColors[COLOR_BTNHIGHLIGHT]);
  if edge and BDR_RAISEDINNER <> 0 then Line(False, SysColors[COLOR_BTNHIGHLIGHT], SysColors[COLOR_BTNSHADOW])
  else if edge and BDR_SUNKENINNER <> 0 then Line(False, SysColors[COLOR_3DDKSHADOW], SysColors[COLOR_3DLIGHT]);
  if grfFlags and BF_MIDDLE <> 0 then GdiFillSolid(D, R, SysColors[COLOR_BTNFACE]);
  if grfFlags and BF_ADJUST <> 0 then qrc := R;
  Result := True;
end;

function DrawFrameControl(DC: HDC; const Rect: TRect; uType, uState: UINT): BOOL;
var
  R: TRect;
  D: TZMDC;
  C: COLORREF;
  CX, CY, I: Integer;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  R := Rect;
  case uType of
    DFC_BUTTON:
      if uState and $F = DFCS_BUTTONPUSH then
      begin
        if uState and DFCS_PUSHED <> 0 then
          DrawEdge(DC, R, EDGE_SUNKEN, BF_RECT or BF_MIDDLE)
        else
          DrawEdge(DC, R, EDGE_RAISED, BF_RECT or BF_MIDDLE);
      end
      else
      begin
        if uState and $F = DFCS_BUTTONCHECK then
        begin
          DrawEdge(DC, R, EDGE_SUNKEN, BF_RECT or BF_ADJUST);
          if uState and DFCS_INACTIVE <> 0 then C := SysColors[COLOR_BTNFACE] else C := $FFFFFF;
          GdiFillSolid(D, R, C);
          if uState and DFCS_CHECKED <> 0 then
            for I := 0 to 2 do
            begin
              GdiFillSolid(D, Types.Rect(R.Left + 1 + I, R.Top + 3 + I, R.Left + 2 + I, R.Top + 6 + I), 0);
              GdiFillSolid(D, Types.Rect(R.Left + 4 + I, R.Top + 5 - I, R.Left + 5 + I, R.Top + 8 - I), 0);
            end;
        end
        else
        begin
          { radioknop }
          D.St.Brush := TZMBrush(StockObjects[WHITE_BRUSH]);
          D.St.Pen := TZMPen(StockObjects[BLACK_PEN]);
          GdiEllipse(D, R.Left, R.Top, R.Right, R.Bottom);
          if uState and DFCS_CHECKED <> 0 then
          begin
            CX := (R.Left + R.Right) div 2;
            CY := (R.Top + R.Bottom) div 2;
            GdiFillSolid(D, Types.Rect(CX - 2, CY - 1, CX + 2, CY + 1), 0);
            GdiFillSolid(D, Types.Rect(CX - 1, CY - 2, CX + 1, CY + 2), 0);
          end;
        end;
      end;
    DFC_SCROLL:
      begin
        if uState and DFCS_PUSHED <> 0 then
          DrawEdge(DC, R, BDR_SUNKENOUTER, BF_RECT or BF_MIDDLE or BF_FLAT)
        else
          DrawEdge(DC, R, EDGE_RAISED, BF_RECT or BF_MIDDLE);
        CX := (R.Left + R.Right) div 2;
        CY := (R.Top + R.Bottom) div 2;
        if uState and DFCS_INACTIVE <> 0 then C := SysColors[COLOR_BTNSHADOW] else C := 0;
        for I := 0 to 3 do
          case uState and $F of
            DFCS_SCROLLUP: GdiFillSolid(D, Types.Rect(CX - I, CY - 2 + I, CX + I + 1, CY - 1 + I), C);
            DFCS_SCROLLDOWN: GdiFillSolid(D, Types.Rect(CX - I, CY + 1 - I, CX + I + 1, CY + 2 - I), C);
            DFCS_SCROLLLEFT: GdiFillSolid(D, Types.Rect(CX - 2 + I, CY - I, CX - 1 + I, CY + I + 1), C);
            DFCS_SCROLLRIGHT: GdiFillSolid(D, Types.Rect(CX + 1 - I, CY - I, CX + 2 - I, CY + I + 1), C);
          end;
      end;
  end;
  Result := True;
end;

function PatBlt(DC: HDC; X, Y, Width, Height: Integer; Rop: DWORD): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  GdiPatBlt(D, X, Y, Width, Height, Rop);
  Result := True;
end;

function SetPixel(DC: HDC; X, Y: Integer; Color: COLORREF): COLORREF;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(CLR_INVALID);
  GdiSetPixel(D, X, Y, Color);
  Result := Color;
end;

function SetPixelV(DC: HDC; X, Y: Integer; Color: COLORREF): BOOL;
begin
  Result := SetPixel(DC, X, Y, Color) <> CLR_INVALID;
end;

function GetPixel(DC: HDC; X, Y: Integer): COLORREF;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(CLR_INVALID);
  Result := GdiGetPixel(D, X, Y);
end;

function FloodFill(DC: HDC; XStart, YStart: Integer; Color: COLORREF): BOOL;
begin
  Result := ExtFloodFill(DC, XStart, YStart, Color, 0);
end;

function ExtFloodFill(DC: HDC; XStart, YStart: Integer; Color: COLORREF; FillType: UINT): BOOL;
var D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  GdiFloodFill(D, XStart, YStart, Color, FillType = 1);
  Result := True;
end;

function BitBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC;
  XSrc, YSrc: Integer; Rop: DWORD): BOOL;
var
  D: TZMDC;
begin
  D := GdiDC(DestDC);
  if D = nil then Exit(False);
  GdiBlt(D, X, Y, Width, Height, GdiDC(SrcDC), XSrc, YSrc, Width, Height, Rop, False);
  Result := True;
end;

function StretchBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC;
  XSrc, YSrc, SrcWidth, SrcHeight: Integer; Rop: DWORD): BOOL;
var
  D: TZMDC;
begin
  D := GdiDC(DestDC);
  if D = nil then Exit(False);
  GdiBlt(D, X, Y, Width, Height, GdiDC(SrcDC), XSrc, YSrc, SrcWidth, SrcHeight, Rop, True);
  Result := True;
end;

function MaskBlt(DestDC: HDC; XDest, YDest, Width, Height: Integer; SrcDC: HDC;
  XSrc, YSrc: Integer; Mask: HBITMAP; xMask, yMask: Integer; Rop: DWORD): BOOL;
begin
  Result := BitBlt(DestDC, XDest, YDest, Width, Height, SrcDC, XSrc, YSrc, Rop and $00FFFFFF);
end;

function TransparentBlt(DestDC: HDC; X, Y, Width, Height: Integer; SrcDC: HDC;
  XSrc, YSrc, SrcWidth, SrcHeight: Integer; Transparent: UINT): BOOL;
var
  D, S: TZMDC;
  XX, YY, SX, SY: Integer;
  C: COLORREF;
begin
  D := GdiDC(DestDC);
  S := GdiDC(SrcDC);
  if (D = nil) or (S = nil) or (Width <= 0) or (Height <= 0) then Exit(False);
  for YY := 0 to Height - 1 do
    for XX := 0 to Width - 1 do
    begin
      SX := XSrc + XX * SrcWidth div Width;
      SY := YSrc + YY * SrcHeight div Height;
      C := GdiGetPixel(S, SX, SY);
      if (C <> CLR_INVALID) and (C <> (Transparent and $FFFFFF)) then GdiSetPixel(D, X + XX, Y + YY, C);
    end;
  Result := True;
end;

function GdiFlush: BOOL;
begin
  Result := True;
end;

{ ---------------------------------------------------------------- bitmaps }

function CreateCompatibleBitmap(DC: HDC; Width, Height: Integer): HBITMAP;
var
  D: TZMDC;
  B: TZMBitmap;
  BPP: Integer;
begin
  ZMInit;
  D := GdiDC(DC);
  BPP := 32;
  if (D <> nil) and D.IsMemDC and (D.Target <> nil) then
  begin
    BPP := D.Target.BPP;
    if BPP < 8 then BPP := D.Target.BPP;
  end;
  B := TZMBitmap.Create(Width, Height, BPP);
  if (D <> nil) and D.IsMemDC and (D.Target <> nil) and (BPP <= 8) then
  begin
    B.NumColors := D.Target.NumColors;
    Move(D.Target.Colors, B.Colors, SizeOf(B.Colors));
    B.ColorsChanged;
  end;
  Result := B.Handle;
end;

function CreateBitmap(Width, Height: Integer; Planes, BitCount: Longint; Bits: Pointer): HBITMAP;
var
  B: TZMBitmap;
  Y, SrcStride: Integer;
begin
  ZMInit;
  if not (BitCount in [1, 4, 8, 16, 24, 32]) then BitCount := 1;
  B := TZMBitmap.Create(Width, Height, BitCount);
  if Bits <> nil then
  begin
    SrcStride := ((Width * BitCount + 15) div 16) * 2;   { DDB-rijen zijn WORD-uitgelijnd }
    for Y := 0 to Height - 1 do
      Move((PByte(Bits) + Y * SrcStride)^, B.RowPtr(Y)^, Min(SrcStride, B.Stride));
  end;
  Result := B.Handle;
end;

function CreateBitmapIndirect(const p1: TBitmap): HBITMAP;
begin
  Result := CreateBitmap(p1.bmWidth, p1.bmHeight, p1.bmPlanes, p1.bmBitsPixel, p1.bmBits);
end;

function CurPal(DC: HDC): TZMPalette;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if D <> nil then Result := D.St.Palette else Result := nil;
end;

function CreateDIBSection(DC: HDC; const p2: TBitmapInfo; p3: UINT; var p4: Pointer;
  p5: THandle; p6: DWORD): HBITMAP;
var
  B: TZMBitmap;
begin
  ZMInit;
  B := NewBitmapFromInfo(p2, p3, CurPal(DC));
  p4 := B.Bits;
  Result := B.Handle;
end;

{ kopieer DIB-bits (van onder naar boven, tenzij biHeight < 0) naar een bitmap }
procedure CopyDIBIn(B: TZMBitmap; StartScan, NumScans: Integer; Bits: Pointer; const BI: TBitmapInfo; Usage: UINT; Pal: TZMPalette);
var
  Src: TZMBitmap;
  Y, SY, SrcStride, H, X: Integer;
  TopDown: Boolean;
  Row: PByte;
begin
  if Bits = nil then Exit;
  H := Abs(BI.bmiHeader.biHeight);
  TopDown := BI.bmiHeader.biHeight < 0;
  SrcStride := ((BI.bmiHeader.biWidth * BI.bmiHeader.biBitCount + 31) div 32) * 4;
  if (B.BPP = BI.bmiHeader.biBitCount) and (BI.bmiHeader.biCompression = BI_RGB) then
  begin
    for Y := StartScan to Min(Integer(StartScan + NumScans), H) - 1 do
    begin
      if TopDown then SY := Y else SY := H - 1 - Y;
      if (SY < 0) or (SY >= B.Height) then Continue;
      Row := PByte(Bits) + (Y - StartScan) * SrcStride;
      Move(Row^, B.RowPtr(SY)^, Min(SrcStride, B.Stride));
    end;
    Exit;
  end;
  { formaatconversie via een tijdelijke DIB }
  Src := NewBitmapFromInfo(BI, Usage, Pal);
  try
    for Y := StartScan to Min(Integer(StartScan + NumScans), H) - 1 do
    begin
      if TopDown then SY := Y else SY := H - 1 - Y;
      Row := PByte(Bits) + (Y - StartScan) * SrcStride;
      if SY < Src.Height then Move(Row^, Src.RowPtr(SY)^, Min(SrcStride, Src.Stride));
    end;
    for Y := 0 to Min(B.Height, Src.Height) - 1 do
      for X := 0 to Min(B.Width, Src.Width) - 1 do
        B.SetNative(X, Y, B.RGBToNative(Src.NativeToRGB(Src.GetNative(X, Y))));
  finally
    Src.Free;
  end;
end;

function CreateDIBitmap(DC: HDC; var InfoHeader: TBitmapInfoHeader; dwUsage: DWORD;
  InitBits: Pointer; var InitInfo: TBitmapInfo; wUsage: UINT): HBITMAP;
var
  B: TZMBitmap;
begin
  ZMInit;
  B := TZMBitmap.Create(InfoHeader.biWidth, Abs(InfoHeader.biHeight), 32);
  if dwUsage and 4 <> 0 then  { CBM_INIT }
    CopyDIBIn(B, 0, Abs(InitInfo.bmiHeader.biHeight), InitBits, InitInfo, wUsage, CurPal(DC));
  Result := B.Handle;
end;

function GetDIBits(DC: HDC; Bitmap: HBITMAP; StartScan, NumScans: UINT;
  Bits: Pointer; var BitInfo: TBitmapInfo; Usage: UINT): Integer;
var
  B: TZMBitmap;
  I, Y, SY, X, BC, DstStride, H: Integer;
  Q: PRGBQuad;
  Tmp: TZMBitmap;
  TopDown: Boolean;
begin
  Result := 0;
  B := GdiBitmap(Bitmap);
  if B = nil then Exit;
  if BitInfo.bmiHeader.biBitCount = 0 then
  begin
    { formaat opvragen }
    BitInfo.bmiHeader.biWidth := B.Width;
    BitInfo.bmiHeader.biHeight := B.Height;
    BitInfo.bmiHeader.biPlanes := 1;
    BitInfo.bmiHeader.biBitCount := B.BPP;
    BitInfo.bmiHeader.biCompression := BI_RGB;
    BitInfo.bmiHeader.biSizeImage := ((B.Width * B.BPP + 31) div 32) * 4 * B.Height;
    Exit(B.Height);
  end;
  BC := BitInfo.bmiHeader.biBitCount;
  if BC <= 8 then
  begin
    Q := @BitInfo.bmiColors[0];
    if (B.BPP <= 8) and (B.BPP = BC) then
      for I := 0 to (1 shl BC) - 1 do
      begin
        Q[I].rgbRed := (B.Colors[I] shr 16) and $FF;
        Q[I].rgbGreen := (B.Colors[I] shr 8) and $FF;
        Q[I].rgbBlue := B.Colors[I] and $FF;
        Q[I].rgbReserved := 0;
      end;
  end;
  if Bits = nil then Exit(B.Height);
  H := Abs(BitInfo.bmiHeader.biHeight);
  if H = 0 then H := B.Height;
  TopDown := BitInfo.bmiHeader.biHeight < 0;
  DstStride := ((B.Width * BC + 31) div 32) * 4;
  Tmp := NewBitmapFromInfo(BitInfo, DIB_RGB_COLORS, nil);
  try
    for Y := 0 to Min(Tmp.Height, B.Height) - 1 do
      for X := 0 to Min(Tmp.Width, B.Width) - 1 do
        if (Tmp.BPP = B.BPP) and (B.BPP <= 8) then
          Tmp.SetNative(X, Y, B.GetNative(X, Y))
        else
          Tmp.SetNative(X, Y, Tmp.RGBToNative(B.NativeToRGB(B.GetNative(X, Y))));
    for Y := StartScan to Min(Integer(StartScan + NumScans), H) - 1 do
    begin
      if TopDown then SY := Y else SY := H - 1 - Y;
      if SY >= Tmp.Height then Continue;
      Move(Tmp.RowPtr(SY)^, (PByte(Bits) + (Y - StartScan) * DstStride)^, Min(DstStride, Tmp.Stride));
      Inc(Result);
    end;
  finally
    Tmp.Free;
  end;
end;

function SetDIBits(DC: HDC; Bitmap: HBITMAP; StartScan, NumScans: UINT;
  Bits: Pointer; var BitsInfo: TBitmapInfo; Usage: UINT): Integer;
var
  B: TZMBitmap;
begin
  B := GdiBitmap(Bitmap);
  if B = nil then Exit(0);
  CopyDIBIn(B, StartScan, NumScans, Bits, BitsInfo, Usage, CurPal(DC));
  Result := NumScans;
end;

function StretchDIBits(DC: HDC; DestX, DestY, DestWidth, DestHeight, SrcX, SrcY,
  SrcWidth, SrcHeight: Integer; Bits: Pointer; var BitsInfo: TBitmapInfo;
  Usage: UINT; Rop: DWORD): Integer;
var
  D: TZMDC;
  Src: TZMBitmap;
  H: Integer;
begin
  D := GdiDC(DC);
  if D = nil then Exit(0);
  Src := NewBitmapFromInfo(BitsInfo, Usage, D.St.Palette);
  try
    H := Abs(BitsInfo.bmiHeader.biHeight);
    CopyDIBIn(Src, 0, H, Bits, BitsInfo, Usage, D.St.Palette);
    { DIB-brongecoördinaten zijn van onder naar boven bij DIB's die van onder naar boven lopen }
    if BitsInfo.bmiHeader.biHeight > 0 then
      SrcY := H - SrcY - SrcHeight;
    GdiBltBitmap(D, DestX, DestY, DestWidth, DestHeight, Src, $FFFFFF, SrcX, SrcY,
      SrcWidth, SrcHeight, Rop, True);
  finally
    Src.Free;
  end;
  Result := DestHeight;
end;

function SetDIBitsToDevice(DC: HDC; DestX, DestY: Integer; Width, Height: DWORD;
  SrcX, SrcY: Integer; nStartScan, NumScans: UINT; Bits: Pointer;
  var BitsInfo: TBitmapInfo; Usage: UINT): Integer;
begin
  Result := StretchDIBits(DC, DestX, DestY, Width, Height, SrcX, SrcY, Width, Height,
    Bits, BitsInfo, Usage, SRCCOPY);
end;

function GetDIBColorTable(DC: HDC; p2, p3: UINT; var RGBQuadStructs): UINT;
var
  D: TZMDC;
  I: Integer;
  Q: PRGBQuad;
begin
  Result := 0;
  D := GdiDC(DC);
  if (D = nil) or (D.Target = nil) or (D.Target.BPP > 8) then Exit;
  Q := @RGBQuadStructs;
  for I := p2 to Min(Integer(p2 + p3), D.Target.NumColors) - 1 do
  begin
    Q^.rgbRed := (D.Target.Colors[I] shr 16) and $FF;
    Q^.rgbGreen := (D.Target.Colors[I] shr 8) and $FF;
    Q^.rgbBlue := D.Target.Colors[I] and $FF;
    Q^.rgbReserved := 0;
    Inc(Q);
    Inc(Result);
  end;
end;

function SetDIBColorTable(DC: HDC; p2, p3: UINT; var RGBQuadSTructs): UINT;
var
  D: TZMDC;
  I: Integer;
  Q: PRGBQuad;
begin
  Result := 0;
  D := GdiDC(DC);
  if (D = nil) or (D.Target = nil) or (D.Target.BPP > 8) then Exit;
  Q := @RGBQuadSTructs;
  for I := p2 to Min(Integer(p2 + p3), D.Target.NumColors) - 1 do
  begin
    D.Target.Colors[I] := (Q^.rgbRed shl 16) or (Q^.rgbGreen shl 8) or Q^.rgbBlue;
    Inc(Q);
    Inc(Result);
  end;
  D.Target.ColorsChanged;
end;

function GetBitmapBits(Bitmap: HBITMAP; Count: Longint; Bits: Pointer): Longint;
var
  B: TZMBitmap;
begin
  B := GdiBitmap(Bitmap);
  if (B = nil) or (Bits = nil) then Exit(0);
  Result := Min(Count, B.Stride * B.Height);
  Move(B.Bits^, Bits^, Result);
end;

function SetBitmapBits(p1: HBITMAP; p2: DWORD; bits: Pointer): Longint;
var
  B: TZMBitmap;
begin
  B := GdiBitmap(p1);
  if (B = nil) or (bits = nil) then Exit(0);
  Result := Min(Integer(p2), B.Stride * B.Height);
  Move(bits^, B.Bits^, Result);
end;

{ ---------------------------------------------------------------- paletten }

function CreatePalette(const LogPalette: TLogPalette): HPALETTE;
var
  P: TZMPalette;
  N: Integer;
begin
  ZMInit;
  P := TZMPalette.Create;
  N := Min(LogPalette.palNumEntries, 256);
  P.Count := N;
  if N > 0 then Move(LogPalette.palPalEntry[0], P.Entries[0], N * SizeOf(TPaletteEntry));
  Result := P.Handle;
end;

function CreateHalftonePalette(DC: HDC): HPALETTE;
var
  P: TZMPalette;
begin
  ZMInit;
  P := TZMPalette.Create;
  P.Count := 256;
  HalftoneEntries(P.Entries);
  Result := P.Handle;
end;

function SelectPalette(DC: HDC; Palette: HPALETTE; ForceBackground: Bool): HPALETTE;
var
  D: TZMDC;
  P: TZMPalette;
begin
  D := GdiDC(DC);
  P := GdiPalette(Palette);
  if (D = nil) or (P = nil) then Exit(0);
  Result := H2(D.St.Palette);
  D.St.Palette := P;
end;

function RealizePalette(DC: HDC): UINT;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if (D = nil) or (D.St.Palette = nil) then Exit(0);
  Result := 0;   { true-colour-scherm: er verandert niets in het systeempalet }
end;

function GetPaletteEntries(Palette: HPALETTE; StartIndex, NumEntries: UINT;
  var PaletteEntries): UINT;
var
  P: TZMPalette;
  N: Integer;
begin
  P := GdiPalette(Palette);
  if P = nil then Exit(0);
  if @PaletteEntries = nil then Exit(P.Count);
  if Integer(StartIndex) >= P.Count then Exit(0);
  N := Min(Integer(NumEntries), P.Count - Integer(StartIndex));
  Move(P.Entries[StartIndex], PaletteEntries, N * SizeOf(TPaletteEntry));
  Result := N;
end;

function SetPaletteEntries(Palette: HPALETTE; StartIndex, NumEntries: UINT;
  var PaletteEntries): UINT;
var
  P: TZMPalette;
  N: Integer;
begin
  P := GdiPalette(Palette);
  if (P = nil) or (Integer(StartIndex) >= P.Count) then Exit(0);
  N := Min(Integer(NumEntries), P.Count - Integer(StartIndex));
  Move(PaletteEntries, P.Entries[StartIndex], N * SizeOf(TPaletteEntry));
  Result := N;
end;

function AnimatePalette(Palette: HPALETTE; StartIndex, NumEntries: UINT; PaletteColors: Pointer): BOOL;
begin
  Result := SetPaletteEntries(Palette, StartIndex, NumEntries, PaletteColors^) > 0;
end;

function ResizePalette(Palette: HPALETTE; Entries: UINT): BOOL;
var
  P: TZMPalette;
begin
  P := GdiPalette(Palette);
  if P = nil then Exit(False);
  P.Count := Min(Integer(Entries), 256);
  Result := True;
end;

function GetNearestPaletteIndex(Palette: HPALETTE; Color: COLORREF): UINT;
var
  P: TZMPalette;
  I, D, Best: Integer;
begin
  P := GdiPalette(Palette);
  Result := CLR_INVALID;
  if (P = nil) or (P.Count = 0) then Exit;
  Best := MaxInt;
  for I := 0 to P.Count - 1 do
    with P.Entries[I] do
    begin
      D := Sqr(peRed - GetRValue(Color)) + Sqr(peGreen - GetGValue(Color)) + Sqr(peBlue - GetBValue(Color));
      if D < Best then
      begin
        Best := D;
        Result := I;
      end;
    end;
end;

function GetNearestColor(DC: HDC; Color: COLORREF): COLORREF;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if (D = nil) or (D.Target = nil) then Exit(Color and $FFFFFF);
  Result := RGBToColorRef(D.Target.NativeToRGB(D.ColorToNative(Color)));
end;

function GetSystemPaletteEntries(DC: HDC; StartIndex, NumEntries: UINT;
  var PaletteEntries): UINT;
var
  E: array[0..255] of TPaletteEntry;
  N: Integer;
begin
  HalftoneEntries(E);
  if @PaletteEntries = nil then Exit(256);
  N := Min(Integer(NumEntries), 256 - Integer(StartIndex));
  if N <= 0 then Exit(0);
  Move(E[StartIndex], PaletteEntries, N * SizeOf(TPaletteEntry));
  Result := N;
end;

function UnrealizeObject(hGDIObj: HGDIOBJ): BOOL;
begin
  Result := True;
end;

function UpdateColors(DC: HDC): BOOL;
begin
  Result := True;
end;

{ ---------------------------------------------------------------- kwasten, pennen, lettertypen }

function CreateSolidBrush(p1: COLORREF): HBRUSH;
var
  B: TZMBrush;
begin
  ZMInit;
  B := TZMBrush.Create;
  B.Style := BS_SOLID;
  B.Color := p1;
  Result := B.Handle;
end;

function CreateBrushIndirect(const p1: TLogBrush): HBRUSH;
var
  B: TZMBrush;
  P: TZMBitmap;
begin
  ZMInit;
  B := TZMBrush.Create;
  B.Style := p1.lbStyle;
  B.Color := p1.lbColor;
  B.Hatch := p1.lbHatch;
  if (B.Style = BS_PATTERN) then
  begin
    P := GdiBitmap(HBITMAP(p1.lbHatch));
    if P <> nil then
    begin
      B.Pattern := TZMBitmap.Create(P.Width, P.Height, P.BPP);
      Move(P.Bits^, B.Pattern.Bits^, P.Stride * P.Height);
      B.Pattern.NumColors := P.NumColors;
      B.Pattern.Colors := P.Colors;
      B.Pattern.ColorsChanged;
    end;
  end;
  Result := B.Handle;
end;

function CreateHatchBrush(p1: Integer; p2: COLORREF): HBRUSH;
var
  LB: TLogBrush;
begin
  LB.lbStyle := BS_HATCHED;
  LB.lbColor := p2;
  LB.lbHatch := p1;
  Result := CreateBrushIndirect(LB);
end;

function CreatePatternBrush(Bitmap: HBITMAP): HBRUSH;
var
  LB: TLogBrush;
begin
  LB.lbStyle := BS_PATTERN;
  LB.lbColor := 0;
  LB.lbHatch := PtrInt(Bitmap);
  Result := CreateBrushIndirect(LB);
end;

function CreatePen(Style, Width: Integer; Color: COLORREF): HPEN;
var
  P: TZMPen;
begin
  ZMInit;
  P := TZMPen.Create;
  P.Style := Style and $F;
  if P.Style = PS_INSIDEFRAME then P.Style := PS_SOLID;
  if Width < 1 then Width := 1;
  P.Width := Width;
  P.Color := Color;
  Result := P.Handle;
end;

function CreatePenIndirect(const LogPen: TLogPen): HPEN;
begin
  Result := CreatePen(LogPen.lopnStyle, LogPen.lopnWidth.X, LogPen.lopnColor);
end;

function CreateFontIndirect(const p1: TLogFont): HFONT;
begin
  ZMInit;
  Result := TZMFontObj.Create(p1).Handle;
end;

function CreateFont(nHeight, nWidth, nEscapement, nOrientaion, fnWeight: Integer;
  fdwItalic, fdwUnderline, fdwStrikeOut, fdwCharSet, fdwOutputPrecision,
  fdwClipPrecision, fdwQuality, fdwPitchAndFamily: DWORD; lpszFace: PAnsiChar): HFONT;
var
  LF: TLogFont;
begin
  FillChar(LF, SizeOf(LF), 0);
  LF.lfHeight := nHeight;
  LF.lfWidth := nWidth;
  LF.lfEscapement := nEscapement;
  LF.lfOrientation := nOrientaion;
  LF.lfWeight := fnWeight;
  LF.lfItalic := fdwItalic;
  LF.lfUnderline := fdwUnderline;
  LF.lfStrikeOut := fdwStrikeOut;
  LF.lfCharSet := fdwCharSet;
  LF.lfPitchAndFamily := fdwPitchAndFamily;
  if lpszFace <> nil then StrPLCopy(LF.lfFaceName, lpszFace, 31);
  Result := CreateFontIndirect(LF);
end;

function GetSysColorBrush(nIndex: Integer): HBRUSH;
begin
  ZMInit;
  if (nIndex >= 0) and (nIndex <= High(SysColorBrushes)) then
    Result := SysColorBrushes[nIndex].Handle
  else
    Result := 0;
end;

{ ---------------------------------------------------------------- tekst }

function TextOut(DC: HDC; X, Y: Integer; Str: PAnsiChar; Count: Integer): BOOL;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  GdiTextOut(D, X, Y, Str, Count, True, nil, nil);
  Result := True;
end;

function ExtTextOut(DC: HDC; X, Y: Integer; Options: Longint; Rect: PRect;
  Str: PAnsiChar; Count: Longint; Dx: PInteger): BOOL;
var
  D: TZMDC;
  Clip, Opq: PRect;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  Clip := nil;
  Opq := nil;
  if (Rect <> nil) and (Options and ETO_CLIPPED <> 0) then Clip := Rect;
  if (Rect <> nil) and (Options and ETO_OPAQUE <> 0) then Opq := Rect;
  GdiTextOut(D, X, Y, Str, Count, Opq = nil, Clip, Opq);
  Result := True;
end;

function DrawText(hDC: HDC; lpString: PAnsiChar; nCount: Integer; var lpRect: TRect;
  uFormat: UINT): Integer;
var
  D: TZMDC;
begin
  D := GdiDC(hDC);
  if D = nil then Exit(0);
  Result := GdiDrawText(D, lpString, nCount, lpRect, uFormat);
end;

function GetTextExtentPoint(DC: HDC; Str: PAnsiChar; Count: Integer; var Size: TSize): BOOL;
var
  D: TZMDC;
  F: PZMFace;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  F := GdiFace(D);
  Size.cx := GdiTextWidth(D, Str, Count);
  Size.cy := F^.Height;
  Result := True;
end;

function GetTextExtentPoint32(DC: HDC; Str: PAnsiChar; Count: Integer; var Size: TSize): BOOL;
begin
  Result := GetTextExtentPoint(DC, Str, Count, Size);
end;

function GetTextMetrics(DC: HDC; var TM: TTextMetric): BOOL;
var
  D: TZMDC;
  F: PZMFace;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  F := GdiFace(D);
  FillChar(TM, SizeOf(TM), 0);
  TM.tmHeight := F^.Height;
  TM.tmAscent := F^.Ascent;
  TM.tmDescent := F^.Descent;
  TM.tmInternalLeading := F^.IntLeading;
  TM.tmAveCharWidth := F^.AvgWidth;
  TM.tmMaxCharWidth := F^.MaxWidth;
  if F^.Bold then TM.tmWeight := FW_BOLD else TM.tmWeight := FW_NORMAL;
  TM.tmDigitizedAspectX := 96;
  TM.tmDigitizedAspectY := 96;
  TM.tmFirstChar := #32;
  TM.tmLastChar := #255;
  TM.tmDefaultChar := '?';
  TM.tmBreakChar := ' ';
  TM.tmItalic := Ord(F^.Italic);
  if F^.Family = 'mono' then TM.tmPitchAndFamily := FF_MODERN
  else TM.tmPitchAndFamily := FF_SWISS or 1 or 4;  { variabele breedte, TrueType }
  if D.St.Font <> nil then TM.tmCharSet := D.St.Font.LF.lfCharSet;
  Result := True;
end;

function GetTextFace(DC: HDC; Count: Integer; Buffer: PAnsiChar): Integer;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if (D = nil) or (D.St.Font = nil) then Exit(0);
  if Buffer <> nil then StrPLCopy(Buffer, D.St.Font.LF.lfFaceName, Count - 1);
  Result := StrLen(D.St.Font.LF.lfFaceName);
end;

function SetTextCharacterExtra(DC: HDC; CharExtra: Integer): Integer;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(0);
  Result := D.St.CharExtra;
  D.St.CharExtra := CharExtra;
end;

{ ---------------------------------------------------------------- gebieden }

function NewRgn(const R: TRect): HRGN;
var
  G: TZMRegion;
begin
  ZMInit;
  G := TZMRegion.Create;
  if (R.Right > R.Left) and (R.Bottom > R.Top) then
  begin
    SetLength(G.Rects, 1);
    G.Rects[0] := R;
  end;
  Result := G.Handle;
end;

function CreateRectRgn(p1, p2, p3, p4: Integer): HRGN;
begin
  Result := NewRgn(Types.Rect(Min(p1, p3), Min(p2, p4), Max(p1, p3), Max(p2, p4)));
end;

function CreateRectRgnIndirect(const p1: TRect): HRGN;
begin
  Result := CreateRectRgn(p1.Left, p1.Top, p1.Right, p1.Bottom);
end;

function CreateEllipticRgn(p1, p2, p3, p4: Integer): HRGN;
var
  G: TZMRegion;
  CX, CY, RX, RY, DY, HW: Double;
  Y: Integer;
begin
  ZMInit;
  G := TZMRegion.Create;
  RX := (p3 - p1) / 2; RY := (p4 - p2) / 2;
  CX := p1 + RX; CY := p2 + RY;
  if (RX > 0) and (RY > 0) then
    for Y := p2 to p4 - 1 do
    begin
      DY := (Y + 0.5 - CY) / RY;
      if Abs(DY) > 1 then Continue;
      HW := RX * Sqrt(1 - DY * DY);
      if Round(CX + HW) > Round(CX - HW) then
      begin
        SetLength(G.Rects, Length(G.Rects) + 1);
        G.Rects[High(G.Rects)] := Types.Rect(Round(CX - HW), Y, Round(CX + HW), Y + 1);
      end;
    end;
  Result := G.Handle;
end;

function CreatePolygonRgn(const Points; Count, FillMode: Integer): HRGN;
var
  P: PPoint;
  I: Integer;
  R: TRect;
begin
  { benadering: omsluitend kader }
  P := @Points;
  if Count <= 0 then Exit(NewRgn(Types.Rect(0, 0, 0, 0)));
  R := Types.Rect(P^.X, P^.Y, P^.X, P^.Y);
  for I := 0 to Count - 1 do
  begin
    R.Left := Min(R.Left, P^.X); R.Top := Min(R.Top, P^.Y);
    R.Right := Max(R.Right, P^.X); R.Bottom := Max(R.Bottom, P^.Y);
    Inc(P);
  end;
  Result := NewRgn(R);
end;

function RgnType(G: TZMRegion): Integer;
begin
  case Length(G.Rects) of
    0: Result := NULLREGION;
    1: Result := SIMPLEREGION;
  else
    Result := COMPLEXREGION;
  end;
end;

function SetRectRgn(Rgn: HRGN; X1, Y1, X2, Y2: Integer): BOOL;
var
  G: TZMRegion;
begin
  G := GdiRegion(Rgn);
  if G = nil then Exit(False);
  G.Rects := nil;
  if (X2 > X1) and (Y2 > Y1) then
  begin
    SetLength(G.Rects, 1);
    G.Rects[0] := Types.Rect(X1, Y1, X2, Y2);
  end;
  Result := True;
end;

function CombineRgn(p1, p2, p3: HRGN; p4: Integer): Integer;
var
  D, A, B: TZMRegion;
  R: TZMRects;
begin
  D := GdiRegion(p1);
  A := GdiRegion(p2);
  B := GdiRegion(p3);
  if (D = nil) or (A = nil) then Exit(ERROR);
  case p4 of
    RGN_AND: if B = nil then Exit(ERROR) else R := RectsIntersect(A.Rects, B.Rects);
    RGN_OR: if B = nil then Exit(ERROR) else R := RectsUnion(A.Rects, B.Rects);
    RGN_DIFF: if B = nil then Exit(ERROR) else R := RectsSubtract(A.Rects, B.Rects);
    RGN_XOR: if B = nil then Exit(ERROR) else
      R := RectsUnion(RectsSubtract(A.Rects, B.Rects), RectsSubtract(B.Rects, A.Rects));
    RGN_COPY: R := RectsCopy(A.Rects);
  else
    Exit(ERROR);
  end;
  D.Rects := R;
  Result := RgnType(D);
end;

function OffsetRgn(RGN: HRGN; XOffset, YOffset: Integer): Integer;
var
  G: TZMRegion;
begin
  G := GdiRegion(RGN);
  if G = nil then Exit(ERROR);
  G.Rects := RectsOffset(G.Rects, XOffset, YOffset);
  Result := RgnType(G);
end;

function GetRgnBox(RGN: HRGN; var p2: TRect): Integer;
var
  G: TZMRegion;
begin
  G := GdiRegion(RGN);
  if G = nil then Exit(ERROR);
  p2 := G.Box;
  Result := RgnType(G);
end;

function PtInRegion(RGN: HRGN; X, Y: Integer): BOOL;
var
  G: TZMRegion;
begin
  G := GdiRegion(RGN);
  Result := (G <> nil) and RectsContain(G.Rects, X, Y);
end;

function RectInRegion(RGN: HRGN; const p2: TRect): BOOL;
var
  G: TZMRegion;
begin
  G := GdiRegion(RGN);
  Result := (G <> nil) and (Length(RectsIntersectRect(G.Rects, p2)) > 0);
end;

function SelectClipRgn(DC: HDC; Region: HRGN): Integer;
var
  D: TZMDC;
  G: TZMRegion;
begin
  D := GdiDC(DC);
  if D = nil then Exit(ERROR);
  G := GdiRegion(Region);
  if G = nil then
  begin
    D.St.HasClip := False;
    D.St.ClipRgn := nil;
    D.InvalidateClip;
    Exit(SIMPLEREGION);
  end;
  D.St.HasClip := True;
  D.St.ClipRgn := RectsCopy(G.Rects);
  D.InvalidateClip;
  Result := RgnType(G);
end;

function DeviceAll(D: TZMDC): TZMRects;
begin
  SetLength(Result, 1);
  Result[0] := Types.Rect(-100000, -100000, 100000, 100000);
end;

function ExtSelectClipRgn(DC: HDC; Region: HRGN; Mode: Integer): Integer;
var
  D: TZMDC;
  G: TZMRegion;
  Cur: TZMRects;
begin
  D := GdiDC(DC);
  if D = nil then Exit(ERROR);
  G := GdiRegion(Region);
  if Mode = RGN_COPY then Exit(SelectClipRgn(DC, Region));
  if G = nil then Exit(ERROR);
  if D.St.HasClip then Cur := D.St.ClipRgn else Cur := DeviceAll(D);
  case Mode of
    RGN_AND: Cur := RectsIntersect(Cur, G.Rects);
    RGN_OR: Cur := RectsUnion(Cur, G.Rects);
    RGN_DIFF: Cur := RectsSubtract(Cur, G.Rects);
    RGN_XOR: Cur := RectsUnion(RectsSubtract(Cur, G.Rects), RectsSubtract(G.Rects, Cur));
  end;
  D.St.HasClip := True;
  D.St.ClipRgn := Cur;
  D.InvalidateClip;
  if Length(Cur) = 0 then Result := NULLREGION else Result := SIMPLEREGION;
end;

{ logische -> apparaat(client)-coördinaten voor knipvierkanten }
function LToDev(D: TZMDC; const R: TRect): TRect;
begin
  Result := R;
  OffsetRect(Result, D.St.VpOrg.X - D.St.WinOrg.X, D.St.VpOrg.Y - D.St.WinOrg.Y);
end;

function GetClipBox(DC: HDC; var Rect: TRect): Integer;
var
  D: TZMDC;
  E: TZMRects;
begin
  D := GdiDC(DC);
  if D = nil then Exit(ERROR);
  E := D.Eff;
  if Length(E) = 0 then
  begin
    Rect := Types.Rect(0, 0, 0, 0);
    Exit(NULLREGION);
  end;
  Rect := RectsBox(E);
  OffsetRect(Rect, -D.OffX, -D.OffY);
  if Length(E) = 1 then Result := SIMPLEREGION else Result := COMPLEXREGION;
end;

function GetClipRgn(DC: HDC; rgn: HRGN): Integer;
var
  D: TZMDC;
  G: TZMRegion;
begin
  D := GdiDC(DC);
  G := GdiRegion(rgn);
  if (D = nil) or (G = nil) then Exit(-1);
  if not D.St.HasClip then Exit(0);
  G.Rects := RectsCopy(D.St.ClipRgn);
  Result := 1;
end;

function IntersectClipRect(DC: HDC; X1, Y1, X2, Y2: Integer): Integer;
var
  D: TZMDC;
  Cur: TZMRects;
begin
  D := GdiDC(DC);
  if D = nil then Exit(ERROR);
  if D.St.HasClip then Cur := D.St.ClipRgn else Cur := DeviceAll(D);
  Cur := RectsIntersectRect(Cur, LToDev(D, Types.Rect(X1, Y1, X2, Y2)));
  D.St.HasClip := True;
  D.St.ClipRgn := Cur;
  D.InvalidateClip;
  if Length(Cur) = 0 then Result := NULLREGION else Result := SIMPLEREGION;
end;

function ExcludeClipRect(DC: HDC; LeftRect, TopRect, RightRect, BottomRect: Integer): Integer;
var
  D: TZMDC;
  Cur: TZMRects;
begin
  D := GdiDC(DC);
  if D = nil then Exit(ERROR);
  if D.St.HasClip then Cur := D.St.ClipRgn else Cur := DeviceAll(D);
  Cur := RectsSubtractRect(Cur, LToDev(D, Types.Rect(LeftRect, TopRect, RightRect, BottomRect)));
  D.St.HasClip := True;
  D.St.ClipRgn := Cur;
  D.InvalidateClip;
  if Length(Cur) = 0 then Result := NULLREGION else Result := COMPLEXREGION;
end;

function OffsetClipRgn(DC: HDC; XOffset, YOffset: Integer): Integer;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(ERROR);
  if D.St.HasClip then
  begin
    D.St.ClipRgn := RectsOffset(D.St.ClipRgn, XOffset, YOffset);
    D.InvalidateClip;
  end;
  Result := SIMPLEREGION;
end;

function RectVisible(DC: HDC; const Rect: TRect): BOOL;
var
  D: TZMDC;
  R: TRect;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  R := Rect;
  OffsetRect(R, D.OffX, D.OffY);
  Result := Length(RectsIntersectRect(D.Eff, R)) > 0;
end;

function PtVisible(DC: HDC; X, Y: Integer): BOOL;
var
  D: TZMDC;
begin
  D := GdiDC(DC);
  if D = nil then Exit(False);
  Result := RectsContain(D.Eff, X + D.OffX, Y + D.OffY);
end;

{ ---------------------------------------------------------------- cursors / iconen }

function LoadCursor(hInstance: HINST; lpCursorName: PAnsiChar): HCURSOR;
begin
  if PtrUInt(lpCursorName) < $10000 then
    Result := HCURSOR(PtrUInt(lpCursorName))
  else
    Result := 32649;  { benoemde cursorresources van ROS.exe (de 'handje') worden niet geladen: hand }
end;

function LoadIcon(hInstance: HINST; lpIconName: PAnsiChar): HICON;
begin
  if PtrUInt(lpIconName) < $10000 then Result := HICON(PtrUInt(lpIconName)) else Result := 32512;
end;

function LoadBitmap(hInstance: HINST; lpBitmapName: PAnsiChar): HBITMAP;
begin
  Result := 0;
end;

function LoadImage(hInst: HINST; ImageName: PAnsiChar; ImageType: UINT; X, Y: Integer; Flags: UINT): THandle;
begin
  Result := 0;
end;

function SetCursor(hCursor: HCURSOR): HCURSOR;
begin
  Result := 32512;
  ZMSetCursorShape(hCursor);
end;

function GetCursor: HCURSOR;
begin
  Result := 32512;
end;

var
  CursorShowCount: Integer = 0;

function ShowCursor(bShow: BOOL): Integer;
begin
  if bShow then Inc(CursorShowCount) else Dec(CursorShowCount);
  if CursorShowCount < 0 then ZMBackend.SetCursor(zcNone)
  else ZMBackend.SetCursor(zcArrow);
  Result := CursorShowCount;
end;

function GetCursorPos(var lpPoint: TPoint): BOOL;
begin
  lpPoint := ZMCursorPos;
  Result := True;
end;

function SetCursorPos(X, Y: Integer): BOOL;
begin
  ZMSetCursorPos(X, Y);
  Result := True;
end;

function ClipCursor(lpRect: PRect): BOOL;
begin
  Result := True;
end;

function DestroyCursor(hCursor: HICON): BOOL;
begin
  Result := True;
end;

function DestroyIcon(hIcon: HICON): BOOL;
begin
  Result := True;
end;

function CreateIconIndirect(var piconinfo: TIconInfo): HICON;
begin
  Result := 32512;
end;

function CopyIcon(hIcon: HICON): HICON;
begin
  Result := hIcon;
end;

function DrawIcon(hDC: HDC; X, Y: Integer; hIcon: HICON): BOOL;
begin
  Result := True;
end;

function DrawIconEx(hdc: HDC; xLeft, yTop: Integer; hIcon: HICON; cxWidth, cyWidth: Integer;
  istepIfAniCur: UINT; hbrFlickerFreeDraw: HBRUSH; diFlags: UINT): BOOL;
begin
  Result := True;
end;

function GetIconInfo(hIcon: HICON; var piconinfo: TIconInfo): BOOL;
begin
  FillChar(piconinfo, SizeOf(piconinfo), 0);
  Result := False;
end;

{ ---------------------------------------------------------------- vensters }

type
  TRegClass = record
    Name: string;
    WC: TWndClass;
  end;

var
  RegClasses: array of TRegClass;

function FindClass(const Name: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(RegClasses) do
    if SameText(RegClasses[I].Name, Name) then Exit(I);
  Result := -1;
end;

function ClassNameStr(P: PAnsiChar): string;
begin
  if PtrUInt(P) < $10000 then Result := '#' + IntToStr(PtrUInt(P)) else Result := StrPas(P);
end;

function CreateWindowEx(dwExStyle: DWORD; lpClassName: PAnsiChar; lpWindowName: PAnsiChar;
  dwStyle: DWORD; X, Y, nWidth, nHeight: Integer; hWndParent: HWND; hMenu: HMENU;
  hInstance: HINST; lpParam: Pointer): HWND;
var
  I: Integer;
  Proc: Pointer;
  W: TZMWindow;
  Name, Txt: string;
begin
  Name := ClassNameStr(lpClassName);
  I := FindClass(Name);
  Proc := nil;
  if I >= 0 then Proc := RegClasses[I].WC.lpfnWndProc;
  if lpWindowName <> nil then Txt := StrPas(lpWindowName) else Txt := '';
  if X = Integer($80000000) then X := 0;
  if Y = Integer($80000000) then Y := 0;
  if nWidth = Integer($80000000) then nWidth := 400;
  if nHeight = Integer($80000000) then nHeight := 300;
  Result := ZMCreateWindow(dwExStyle, Name, Txt, dwStyle, X, Y, nWidth, nHeight, hWndParent,
    PtrInt(hMenu), nil, Proc);
  W := ZMWindowObj(Result);
  if (W <> nil) and (I >= 0) then
  begin
    W.ClsStyle := RegClasses[I].WC.style;
    W.ClsBrush := RegClasses[I].WC.hbrBackground;
    W.ClsCursor := RegClasses[I].WC.hCursor;
  end;
end;

function CreateWindow(lpClassName: PAnsiChar; lpWindowName: PAnsiChar; dwStyle: DWORD;
  X, Y, nWidth, nHeight: Integer; hWndParent: HWND; hMenu: HMENU; hInstance: HINST;
  lpParam: Pointer): HWND;
begin
  Result := CreateWindowEx(0, lpClassName, lpWindowName, dwStyle, X, Y, nWidth, nHeight,
    hWndParent, hMenu, hInstance, lpParam);
end;

function DestroyWindow(hWnd: HWND): BOOL;
begin
  Result := ZMDestroyWindow(hWnd);
end;

function RegisterClass(const lpWndClass: TWndClass): ATOM;
var
  I: Integer;
  Name: string;
begin
  Name := ClassNameStr(lpWndClass.lpszClassName);
  I := FindClass(Name);
  if I < 0 then
  begin
    I := Length(RegClasses);
    SetLength(RegClasses, I + 1);
  end;
  RegClasses[I].Name := Name;
  RegClasses[I].WC := lpWndClass;
  Result := $C000 + I;
end;

function UnregisterClass(lpClassName: PAnsiChar; hInstance: HINST): BOOL;
var
  I: Integer;
begin
  I := FindClass(ClassNameStr(lpClassName));
  Result := I >= 0;
  if Result then RegClasses[I].Name := '';
end;

function GetClassInfo(hInstance: HINST; lpClassName: PAnsiChar; var lpWndClass: TWndClass): BOOL;
var
  I: Integer;
begin
  I := FindClass(ClassNameStr(lpClassName));
  Result := I >= 0;
  if Result then lpWndClass := RegClasses[I].WC;
end;

function IsWindow(hWnd: HWND): BOOL;
begin
  Result := ZMWindowObj(hWnd) <> nil;
end;

function IsWindowVisible(hWnd: HWND): BOOL;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  Result := (W <> nil) and W.IsVisible;
end;

function IsWindowEnabled(hWnd: HWND): BOOL;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  Result := (W <> nil) and (W.Style and WS_DISABLED = 0);
end;

function IsIconic(hWnd: HWND): BOOL;
begin
  Result := False;
end;

function IsZoomed(hWnd: HWND): BOOL;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  Result := (W <> nil) and (W.Style and WS_MAXIMIZE <> 0);
end;

function IsChild(hWndParent, hWnd: HWND): BOOL;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  if W <> nil then W := W.Parent;
  while W <> nil do
  begin
    if W.Handle = hWndParent then Exit(True);
    W := W.Parent;
  end;
  Result := False;
end;

function EnableWindow(hWnd: HWND; bEnable: BOOL): BOOL;
begin
  Result := ZMEnableWindow(hWnd, bEnable);
end;

function ShowWindow(hWnd: HWND; nCmdShow: Integer): BOOL;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  if W = nil then Exit(False);
  case nCmdShow of
    SW_HIDE: Result := ZMShowWindow(hWnd, False);
    SW_SHOWMAXIMIZED:
      begin
        W.Style := W.Style or WS_MAXIMIZE;
        if W.Parent = nil then
          ZMSetWindowPos(hWnd, 0, 0, 0, ZMScreenW, ZMScreenH, SWP_NOZORDER);
        Result := ZMShowWindow(hWnd, True);
        ZMSetActive(hWnd);
      end;
    SW_SHOWNOACTIVATE, SW_SHOWNA, SW_SHOWMINNOACTIVE:
      Result := ZMShowWindow(hWnd, True);
  else
    begin
      if nCmdShow in [SW_RESTORE, SW_SHOWNORMAL] then W.Style := W.Style and not WS_MAXIMIZE;
      Result := ZMShowWindow(hWnd, True);
      if (W.Parent = nil) and (nCmdShow <> SW_SHOWMINIMIZED) then ZMSetActive(hWnd);
    end;
  end;
end;

function SetWindowPos(hWnd: HWND; hWndInsertAfter: HWND; X, Y, cx, cy: Integer; uFlags: UINT): BOOL;
begin
  ZMSetWindowPos(hWnd, hWndInsertAfter, X, Y, cx, cy, uFlags);
  if uFlags and SWP_SHOWWINDOW <> 0 then
    if (ZMWindowObj(hWnd) <> nil) and (ZMWindowObj(hWnd).Parent = nil) and (uFlags and SWP_NOACTIVATE = 0) then
      ZMSetActive(hWnd);
  Result := ZMWindowObj(hWnd) <> nil;
end;

function MoveWindow(hWnd: HWND; X, Y, nWidth, nHeight: Integer; bRepaint: BOOL): BOOL;
begin
  ZMSetWindowPos(hWnd, 0, X, Y, nWidth, nHeight, SWP_NOZORDER or SWP_NOACTIVATE);
  Result := ZMWindowObj(hWnd) <> nil;
end;

function BringWindowToTop(hWnd: HWND): BOOL;
begin
  ZMSetWindowPos(hWnd, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
  Result := True;
end;

function SetForegroundWindow(hWnd: HWND): BOOL;
begin
  ZMSetActive(hWnd);
  Result := True;
end;

function GetForegroundWindow: HWND;
begin
  Result := ZMGetActive;
end;

function SetActiveWindow(hWnd: HWND): HWND;
begin
  Result := ZMSetActive(hWnd);
end;

function GetActiveWindow: HWND;
begin
  Result := ZMGetActive;
end;

function SetFocus(hWnd: HWND): HWND;
begin
  Result := ZMSetFocus(hWnd);
end;

function GetFocus: HWND;
begin
  Result := ZMGetFocus;
end;

function SetCapture(hWnd: HWND): HWND;
begin
  Result := ZMSetCapture(hWnd);
end;

function GetCapture: HWND;
begin
  Result := ZMGetCapture;
end;

function ReleaseCapture: BOOL;
begin
  ZMReleaseCapture;
  Result := True;
end;

function GetParent(hWnd: HWND): HWND;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  if W = nil then Exit(0);
  if W.Parent <> nil then Result := W.Parent.Handle else Result := W.Owner;
end;

function SetParent(hWndChild, hWndNewParent: HWND): HWND;
begin
  Result := GetParent(hWndChild);
  ZMSetParent(hWndChild, hWndNewParent);
end;

function GetWindow(hWnd: HWND; uCmd: UINT): HWND;
begin
  Result := ZMGetWindowInZ(hWnd, uCmd);
end;

function GetTopWindow(hWnd: HWND): HWND;
begin
  Result := ZMGetWindowInZ(hWnd, 5);
end;

function GetDesktopWindow: HWND;
begin
  Result := 0;
end;

function GetWindowRect(hWnd: HWND; var lpRect: TRect): BOOL;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  if W = nil then
  begin
    lpRect := Types.Rect(0, 0, ZMScreenW, ZMScreenH);
    Exit(hWnd = 0);
  end;
  lpRect := W.WindowRectScreen;
  Result := True;
end;

function GetClientRect(hWnd: HWND; var lpRect: TRect): BOOL;
var
  W: TZMWindow;
  R: TRect;
begin
  W := ZMWindowObj(hWnd);
  if W = nil then
  begin
    lpRect := Types.Rect(0, 0, ZMScreenW, ZMScreenH);
    Exit(hWnd = 0);
  end;
  R := W.ClientRectScreen;
  lpRect := Types.Rect(0, 0, R.Right - R.Left, R.Bottom - R.Top);
  Result := True;
end;

function ClientToScreen(hWnd: HWND; var lpPoint: TPoint): BOOL;
begin
  ZMClientToScreen(hWnd, lpPoint);
  Result := True;
end;

function ScreenToClient(hWnd: HWND; var lpPoint: TPoint): BOOL;
begin
  ZMScreenToClient(hWnd, lpPoint);
  Result := True;
end;

function MapWindowPoints(hWndFrom, hWndTo: HWND; var lpPoints; cPoints: UINT): Integer;
var
  P: PPoint;
  I: Integer;
  A, B: TPoint;
begin
  A := Types.Point(0, 0);
  B := Types.Point(0, 0);
  if hWndFrom <> 0 then ZMClientToScreen(hWndFrom, A);
  if hWndTo <> 0 then ZMClientToScreen(hWndTo, B);
  P := @lpPoints;
  for I := 0 to Integer(cPoints) - 1 do
  begin
    Inc(P^.X, A.X - B.X);
    Inc(P^.Y, A.Y - B.Y);
    Inc(P);
  end;
  Result := MakeLong(Word(A.X - B.X), Word(A.Y - B.Y));
end;

function WindowFromPoint(Point: TPoint): HWND;
begin
  Result := ZMWindowFromPoint(Point, False);
end;

function ChildWindowFromPoint(hWndParent: HWND; Point: TPoint): HWND;
var
  P: TPoint;
  H: HWND;
begin
  P := Point;
  ZMClientToScreen(hWndParent, P);
  H := ZMWindowFromPoint(P, False);
  while (H <> 0) and (GetParent(H) <> hWndParent) and (H <> hWndParent) do
    H := GetParent(H);
  if H = 0 then H := hWndParent;
  Result := H;
end;

function InvalidateRect(hWnd: HWND; lpRect: PRect; bErase: BOOL): BOOL;
begin
  ZMInvalidate(hWnd, lpRect, bErase);
  Result := True;
end;

function InvalidateRgn(hWnd: HWND; hRgn: HRGN; bErase: BOOL): BOOL;
var
  G: TZMRegion;
  R: TRect;
begin
  G := GdiRegion(hRgn);
  if G = nil then
    ZMInvalidate(hWnd, nil, bErase)
  else
  begin
    R := G.Box;
    ZMInvalidate(hWnd, @R, bErase);
  end;
  Result := True;
end;

function ValidateRect(hWnd: HWND; lpRect: PRect): BOOL;
begin
  ZMValidate(hWnd, lpRect);
  Result := True;
end;

function UpdateWindow(hWnd: HWND): BOOL;
begin
  ZMUpdateWindow(hWnd);
  Result := True;
end;

function RedrawWindow(hWnd: HWND; lprcUpdate: PRect; hrgnUpdate: HRGN; flags: UINT): BOOL;
const
  RDW_INVALIDATE = 1; RDW_ERASE = 4; RDW_FRAME = $400; RDW_UPDATENOW = $100; RDW_ALLCHILDREN = $80;
var
  W: TZMWindow;
  R: TRect;
begin
  W := ZMWindowObj(hWnd);
  if flags and RDW_INVALIDATE <> 0 then
  begin
    if (flags and RDW_ALLCHILDREN <> 0) and (W <> nil) then
    begin
      if lprcUpdate <> nil then
      begin
        R := lprcUpdate^;
        OffsetRect(R, W.ClientRectScreen.Left, W.ClientRectScreen.Top);
      end
      else
        R := W.WindowRectScreen;
      ZMInvalidateTree(W, R);
    end
    else
      ZMInvalidate(hWnd, lprcUpdate, flags and RDW_ERASE <> 0);
    if (flags and RDW_FRAME <> 0) and (W <> nil) then W.NCDirty := True;
  end;
  if flags and RDW_UPDATENOW <> 0 then ZMUpdateWindow(hWnd);
  Result := True;
end;

function GetUpdateRect(hWnd: HWND; lpRect: PRect; bErase: BOOL): BOOL;
var
  R: TRect;
begin
  Result := ZMGetUpdateRect(hWnd, R);
  if lpRect <> nil then lpRect^ := R;
end;

function BeginPaint(hWnd: HWND; var lpPaint: TPaintStruct): HDC;
begin
  Result := ZMBeginPaint(hWnd, lpPaint);
end;

function EndPaint(hWnd: HWND; const lpPaint: TPaintStruct): BOOL;
begin
  ZMEndPaint(hWnd, lpPaint);
  Result := True;
end;

function ScrollWindow(hWnd: HWND; XAmount, YAmount: Integer; Rect, ClipRect: PRect): BOOL;
begin
  ZMInvalidate(hWnd, nil, True);
  Result := True;
end;

function SetWindowText(hWnd: HWND; lpString: PAnsiChar): BOOL;
begin
  Result := ZMSendMessage(hWnd, $000C, 0, LPARAM(lpString)) <> 0;
end;

function GetWindowText(hWnd: HWND; lpString: PAnsiChar; nMaxCount: Integer): Integer;
begin
  Result := ZMSendMessage(hWnd, $000D, nMaxCount, LPARAM(lpString));
end;

function GetWindowTextLength(hWnd: HWND): Integer;
begin
  Result := ZMSendMessage(hWnd, $000E, 0, 0);
end;

function GetWindowLong(hWnd: HWND; nIndex: Integer): PtrInt;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  Result := 0;
  if W = nil then Exit;
  case nIndex of
    GWL_STYLE: Result := PtrInt(W.Style);
    GWL_EXSTYLE: Result := PtrInt(W.ExStyle);
    GWL_ID: Result := W.ID;
    GWL_USERDATA: Result := W.UserData;
    GWL_WNDPROC: Result := PtrInt(W.Proc);
    GWL_HWNDPARENT: Result := PtrInt(GetParent(hWnd));
    GWL_HINSTANCE: Result := PtrInt(HInstance);
  end;
end;

function SetWindowLong(hWnd: HWND; nIndex: Integer; dwNewLong: PtrInt): PtrInt;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  Result := 0;
  if W = nil then Exit;
  Result := GetWindowLong(hWnd, nIndex);
  case nIndex of
    GWL_STYLE: ZMSetStyle(hWnd, DWORD(dwNewLong));
    GWL_EXSTYLE: ZMSetExStyle(hWnd, DWORD(dwNewLong));
    GWL_ID: W.ID := dwNewLong;
    GWL_USERDATA: W.UserData := dwNewLong;
    GWL_WNDPROC: W.Proc := Pointer(dwNewLong);
    GWL_HWNDPARENT: W.Owner := THandle(dwNewLong);
  end;
end;

function GetWindowLongPtr(hWnd: HWND; nIndex: Integer): PtrInt;
begin
  Result := GetWindowLong(hWnd, nIndex);
end;

function SetWindowLongPtr(hWnd: HWND; nIndex: Integer; dwNewLong: PtrInt): PtrInt;
begin
  Result := SetWindowLong(hWnd, nIndex, dwNewLong);
end;

function GetClassName(hWnd: HWND; lpClassName: PAnsiChar; nMaxCount: Integer): Integer;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  if (W = nil) or (lpClassName = nil) then Exit(0);
  StrPLCopy(lpClassName, W.ClsName, nMaxCount - 1);
  Result := StrLen(lpClassName);
end;

function GetWindowPlacement(hWnd: HWND; WindowPlacement: PWindowPlacement): BOOL;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(hWnd);
  if (W = nil) or (WindowPlacement = nil) then Exit(False);
  WindowPlacement^.flags := 0;
  if W.Style and WS_MAXIMIZE <> 0 then WindowPlacement^.showCmd := SW_SHOWMAXIMIZED
  else WindowPlacement^.showCmd := SW_SHOWNORMAL;
  WindowPlacement^.rcNormalPosition := W.R;
  Result := True;
end;

function SetWindowPlacement(hWnd: HWND; WindowPlacement: PWindowPlacement): BOOL;
begin
  if WindowPlacement = nil then Exit(False);
  with WindowPlacement^.rcNormalPosition do
    ZMSetWindowPos(hWnd, 0, Left, Top, Right - Left, Bottom - Top, SWP_NOZORDER);
  ShowWindow(hWnd, WindowPlacement^.showCmd);
  Result := True;
end;

type
  TFindData = record
    Cls, Txt: string;
    UseCls, UseTxt: Boolean;
    Found: HWND;
  end;
  PFindData = ^TFindData;

function FindProc(Wnd: HWND; Data: Pointer): Boolean;
var
  W: TZMWindow;
begin
  W := ZMWindowObj(Wnd);
  Result := True;
  with PFindData(Data)^ do
    if (not UseCls or SameText(W.ClsName, Cls)) and (not UseTxt or (W.Text = Txt)) then
    begin
      Found := Wnd;
      Result := False;
    end;
end;

function FindWindow(lpClassName, lpWindowName: PAnsiChar): HWND;
var
  F: TFindData;
begin
  F.UseCls := lpClassName <> nil;
  F.UseTxt := lpWindowName <> nil;
  if F.UseCls then F.Cls := ClassNameStr(lpClassName);
  if F.UseTxt then F.Txt := StrPas(lpWindowName);
  F.Found := 0;
  ZMEnumTopLevel(FindProc, @F);
  Result := F.Found;
end;

function GetSystemMetrics(nIndex: Integer): Integer;
begin
  case nIndex of
    SM_CXSCREEN, SM_CXFULLSCREEN, SM_CXMAXIMIZED: Result := ZMScreenW;
    SM_CYSCREEN, SM_CYMAXIMIZED: Result := ZMScreenH;
    SM_CYFULLSCREEN: Result := ZMScreenH - 19;
    SM_CXVSCROLL, SM_CYHSCROLL, SM_CYVSCROLL, SM_CXHSCROLL, SM_CYVTHUMB, SM_CXHTHUMB: Result := 16;
    SM_CYCAPTION: Result := 19;
    SM_CXBORDER, SM_CYBORDER: Result := 1;
    SM_CXDLGFRAME, SM_CYDLGFRAME: Result := 3;
    SM_CXFRAME, SM_CYFRAME: Result := 4;
    SM_CXEDGE, SM_CYEDGE: Result := 2;
    SM_CXICON, SM_CYICON, SM_CXCURSOR, SM_CYCURSOR: Result := 32;
    SM_CXSMICON, SM_CYSMICON: Result := 16;
    SM_CYMENU: Result := 19;
    SM_CXDOUBLECLK, SM_CYDOUBLECLK: Result := 4;
    SM_MOUSEPRESENT, SM_CMONITORS: Result := 1;
  else
    Result := 0;
  end;
end;

function GetSysColor(nIndex: Integer): DWORD;
begin
  ZMInit;
  if (nIndex >= 0) and (nIndex <= High(SysColors)) then Result := SysColors[nIndex] else Result := 0;
end;

function FlashWindow(hWnd: HWND; bInvert: BOOL): BOOL;
begin
  Result := True;
end;

function GetKeyState(nVirtKey: Integer): SHORT;
begin
  Result := ZMKeyState(nVirtKey);
end;

function GetAsyncKeyState(vKey: Integer): SHORT;
begin
  Result := ZMKeyState(vKey);
end;

function GetKeyboardState(var KeyState): BOOL;
var
  P: PByte;
  I: Integer;
begin
  P := @KeyState;
  for I := 0 to 255 do
    if ZMKeyState(I) < 0 then P[I] := $80 else P[I] := 0;
  Result := True;
end;

function MapVirtualKey(uCode, uMapType: UINT): UINT;
begin
  Result := uCode;
end;

function GetDoubleClickTime: UINT;
begin
  Result := 500;
end;

function CallWindowProc(lpPrevWndFunc: TFNWndProc; hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
begin
  if lpPrevWndFunc = nil then
    Result := ZMDefWindowProc(hWnd, Msg, wParam, lParam)
  else
    Result := TWndProcFunc(lpPrevWndFunc)(hWnd, Msg, wParam, lParam);
end;

function DefWindowProc(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
begin
  Result := ZMDefWindowProc(hWnd, Msg, wParam, lParam);
end;

function ChangeDisplaySettings(var lpDevMode: TDeviceMode; dwFlags: DWORD): Longint;
begin
  Result := ChangeDisplaySettings(@lpDevMode, dwFlags);
end;

function ChangeDisplaySettings(lpDevMode: PDeviceMode; dwFlags: DWORD): Longint;
begin
  { het nagebootste scherm behoudt zijn grootte; schermmodus-wijzigingen worden geaccepteerd }
  if lpDevMode <> nil then
  begin
    if lpDevMode^.dmFields and DM_PELSWIDTH <> 0 then ScreenModeW := lpDevMode^.dmPelsWidth;
    if lpDevMode^.dmFields and DM_PELSHEIGHT <> 0 then ScreenModeH := lpDevMode^.dmPelsHeight;
  end;
  Result := DISP_CHANGE_SUCCESSFUL;
end;

function EnumDisplaySettings(lpszDeviceName: PAnsiChar; iModeNum: DWORD; var lpDevMode: TDeviceMode): BOOL;
const
  Modes: array[0..5, 0..2] of Integer = ((640, 480, 8), (800, 600, 16), (1024, 768, 16),
    (1024, 768, 24), (1024, 768, 32), (1280, 1024, 32));
var
  I: Integer;
begin
  FillChar(lpDevMode, SizeOf(lpDevMode), 0);
  lpDevMode.dmSize := SizeOf(TDeviceMode);
  lpDevMode.dmFields := DM_BITSPERPEL or DM_PELSWIDTH or DM_PELSHEIGHT or DM_DISPLAYFREQUENCY;
  lpDevMode.dmDisplayFrequency := 60;
  if (iModeNum = ENUM_CURRENT_SETTINGS) or (iModeNum = ENUM_REGISTRY_SETTINGS) then
  begin
    lpDevMode.dmPelsWidth := ZMScreenW;
    lpDevMode.dmPelsHeight := ZMScreenH;
    lpDevMode.dmBitsPerPel := 32;
    Exit(True);
  end;
  I := iModeNum;
  if (I < 0) or (I > High(Modes)) then Exit(False);
  lpDevMode.dmPelsWidth := Modes[I, 0];
  lpDevMode.dmPelsHeight := Modes[I, 1];
  lpDevMode.dmBitsPerPel := Modes[I, 2];
  Result := True;
end;

function SystemParametersInfo(uiAction, uiParam: UINT; pvParam: Pointer; fWinIni: UINT): BOOL;
const
  SPI_GETWORKAREA = 48;
begin
  Result := True;
  case uiAction of
    SPI_GETWORKAREA: if pvParam <> nil then PRect(pvParam)^ := Types.Rect(0, 0, ZMScreenW, ZMScreenH);
  else
    if pvParam <> nil then PDWORD(pvParam)^ := 0;
  end;
end;

function MessageBeep(uType: UINT): BOOL;
begin
  ZMBackend.Beep;
  Result := True;
end;

function Beep(dwFreq, dwDuration: DWORD): BOOL;
begin
  ZMBackend.Beep;
  Result := True;
end;

function MessageBox(hWnd: HWND; lpText, lpCaption: PAnsiChar; uType: UINT): Integer;
begin
  if Assigned(ZMMessageBoxHook) then
    Result := ZMMessageBoxHook(hWnd, StrPas(lpText), StrPas(lpCaption), uType)
  else
  begin
    WriteLn(StdErr, 'MessageBox: ', StrPas(lpCaption), ': ', StrPas(lpText));
    if uType and $F in [MB_YESNO, MB_YESNOCANCEL] then Result := IDYES else Result := IDOK;
  end;
end;

{ ---------------------------------------------------------------- berichten }

function PostMessage(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): BOOL;
begin
  Result := ZMPostMessage(hWnd, Msg, wParam, lParam);
end;

function SendMessage(hWnd: HWND; Msg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT;
begin
  Result := ZMSendMessage(hWnd, Msg, wParam, lParam);
end;

function PostThreadMessage(idThread: DWORD; Msg: UINT; wParam: WPARAM; lParam: LPARAM): BOOL;
begin
  Result := ZMPostMessage(0, Msg, wParam, lParam);
end;

procedure PostQuitMessage(nExitCode: Integer);
begin
  ZMExitCode := nExitCode;
  ZMPostMessage(0, $0012, nExitCode, 0);
end;

function PeekMessage(var lpMsg: TMsg; hWnd: HWND; wMsgFilterMin, wMsgFilterMax, wRemoveMsg: UINT): BOOL;
begin
  Result := ZMPeekMessage(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax, wRemoveMsg);
end;

function GetMessage(var lpMsg: TMsg; hWnd: HWND; wMsgFilterMin, wMsgFilterMax: UINT): BOOL;
begin
  Result := ZMGetMessage(lpMsg, hWnd, wMsgFilterMin, wMsgFilterMax);
end;

function TranslateMessage(const lpMsg: TMsg): BOOL;
begin
  ZMTranslateMessage(lpMsg);
  Result := True;
end;

function DispatchMessage(const lpMsg: TMsg): Longint;
begin
  Result := ZMDispatchMessage(lpMsg);
end;

function WaitMessage: BOOL;
begin
  ZMWaitMessage;
  Result := True;
end;

function GetMessageTime: Longint;
begin
  Result := ZMMessageTime;
end;

function GetMessagePos: DWORD;
var
  P: TPoint;
begin
  P := ZMMessagePos;
  Result := DWORD(MakeLong(Word(P.X), Word(P.Y)));
end;

function GetQueueStatus(flags: UINT): DWORD;
var
  M: TMsg;
begin
  if ZMPeekMessage(M, 0, 0, 0, PM_NOREMOVE) then Result := $FFFF else Result := 0;
end;

function InSendMessage: BOOL;
begin
  Result := False;
end;

var
  RegisteredMsgs: TStringList;

function RegisterWindowMessage(lpString: PAnsiChar): UINT;
var
  I: Integer;
begin
  if RegisteredMsgs = nil then RegisteredMsgs := TStringList.Create;
  I := RegisteredMsgs.IndexOf(StrPas(lpString));
  if I < 0 then I := RegisteredMsgs.Add(StrPas(lpString));
  Result := $C000 + I;
end;

function SetTimer(hWnd: HWND; nIDEvent, uElapse: UINT; lpTimerFunc: TFNTimerProc): UINT;
begin
  Result := ZMSetTimer(hWnd, nIDEvent, uElapse, lpTimerFunc);
end;

function KillTimer(hWnd: HWND; uIDEvent: UINT): BOOL;
begin
  Result := ZMKillTimer(hWnd, uIDEvent);
end;

function MsgWaitForMultipleObjects(nCount: DWORD; var pHandles; fWaitAll: BOOL;
  dwMilliseconds, dwWakeMask: DWORD): DWORD;
begin
  ZMWaitMessage;
  Result := nCount;  { WAIT_OBJECT_0 + nCount: invoer beschikbaar }
end;

{ ---------------------------------------------------------------- kernel }

function GetTickCount: DWORD;
begin
  Result := ZMTicks;
end;

function QueryPerformanceCounter(var lpPerformanceCount: TLargeInteger): BOOL;
begin
  lpPerformanceCount := ZMBackend.PerfCounter;
  Result := True;
end;

function QueryPerformanceFrequency(var lpFrequency: TLargeInteger): BOOL;
begin
  lpFrequency := ZMBackend.PerfFrequency;
  Result := True;
end;

procedure Sleep(dwMilliseconds: DWORD);
begin
  ZMBackend.Delay(dwMilliseconds);
end;

function GetVersionEx(var lpVersionInformation: TOSVersionInfo): BOOL;
begin
  { meld Windows XP (NT): op 9x draait het spel in een wachtlus op de VGA-retracepoort, en
    de referentieruns van het origineel (Wine) melden ook NT }
  lpVersionInformation.dwMajorVersion := 5;
  lpVersionInformation.dwMinorVersion := 1;
  lpVersionInformation.dwBuildNumber := 2600;
  lpVersionInformation.dwPlatformId := VER_PLATFORM_WIN32_NT;
  FillChar(lpVersionInformation.szCSDVersion, SizeOf(lpVersionInformation.szCSDVersion), 0);
  Result := True;
end;

function GetVersion: DWORD;
begin
  Result := $0A280105;  { 5.1 build 2600, NT }
end;

function GetLastError: DWORD;
begin
  Result := LastErr;
end;

procedure SetLastError(dwErrCode: DWORD);
begin
  LastErr := dwErrCode;
end;

function LoadLibrary(lpLibFileName: PAnsiChar): HMODULE;
begin
  { hier geen Windows-DLL's: aanroepers vallen terug op hun code zonder DLL }
  LastErr := ERROR_FILE_NOT_FOUND;
  Result := 0;
end;

function FreeLibrary(hLibModule: HMODULE): BOOL;
begin
  Result := True;
end;

function GetProcAddress(hModule: HMODULE; lpProcName: PAnsiChar): FARPROC;
begin
  Result := nil;
end;

function GetModuleHandle(lpModuleName: PAnsiChar): HMODULE;
begin
  if lpModuleName = nil then Result := HInstance else Result := 0;
end;

function GetModuleFileName(hModule: HINST; lpFilename: PAnsiChar; nSize: DWORD): DWORD;
var
  S: string;
begin
  S := ZMExeName;
  StrPLCopy(lpFilename, S, nSize - 1);
  Result := StrLen(lpFilename);
end;

function GetCurrentThreadId: DWORD;
begin
  Result := 1;
end;

function GetCurrentProcessId: DWORD;
begin
  Result := 1;
end;

function GetCurrentDirectory(nBufferLength: DWORD; lpBuffer: PAnsiChar): DWORD;
var
  S: string;
begin
  S := GetCurrentDir;
  if lpBuffer <> nil then StrPLCopy(lpBuffer, S, nBufferLength - 1);
  Result := Length(S);
end;

function SetCurrentDirectory(lpPathName: PAnsiChar): BOOL;
begin
  Result := SetCurrentDir(ZMResolvePath(StrPas(lpPathName)));
end;

function GetWindowsDirectory(lpBuffer: PAnsiChar; uSize: UINT): UINT;
begin
  StrPLCopy(lpBuffer, 'C:\WINDOWS', uSize - 1);
  Result := StrLen(lpBuffer);
end;

function GetSystemDirectory(lpBuffer: PAnsiChar; uSize: UINT): UINT;
begin
  StrPLCopy(lpBuffer, 'C:\WINDOWS\SYSTEM', uSize - 1);
  Result := StrLen(lpBuffer);
end;

function GetTempPath(nBufferLength: DWORD; lpBuffer: PAnsiChar): DWORD;
var
  S: string;
begin
  S := IncludeTrailingPathDelimiter(GetTempDir);
  StrPLCopy(lpBuffer, S, nBufferLength - 1);
  Result := Length(S);
end;

function GetDriveType(lpRootPathName: PAnsiChar): UINT;
begin
  Result := DRIVE_FIXED;
end;

function GetLogicalDrives: DWORD;
begin
  Result := 1 shl 2;  { C: }
end;

function SetErrorMode(uMode: UINT): UINT;
begin
  Result := 0;
end;

function GetLocalTime(var lpSystemTime: TSystemTime): BOOL;
var
  N: TDateTime;
  Y, M, D, H, Mi, S, MS: Word;
begin
  N := Now;
  DecodeDate(N, Y, M, D);
  DecodeTime(N, H, Mi, S, MS);
  lpSystemTime.wYear := Y; lpSystemTime.wMonth := M; lpSystemTime.wDay := D;
  lpSystemTime.wDayOfWeek := DayOfWeek(N) - 1;
  lpSystemTime.wHour := H; lpSystemTime.wMinute := Mi; lpSystemTime.wSecond := S;
  lpSystemTime.wMilliseconds := MS;
  Result := True;
end;

function GetSystemTime(var lpSystemTime: TSystemTime): BOOL;
begin
  Result := GetLocalTime(lpSystemTime);
end;

type
  PGlobalBlock = ^TGlobalBlock;
  TGlobalBlock = record
    Size: PtrUInt;
    Data: record end;
  end;

function GlobalAlloc(uFlags: UINT; dwBytes: PtrUInt): HGLOBAL;
var
  B: PGlobalBlock;
  O: TObject;
begin
  B := AllocMem(SizeOf(TGlobalBlock) + dwBytes);
  B^.Size := dwBytes;
  O := TObject(Pointer(B));
  Result := ZMAllocHandle(O);
end;

function GlobalFree(hMem: HGLOBAL): HGLOBAL;
var
  P: Pointer;
begin
  P := Pointer(ZMHandleObj(hMem));
  if P <> nil then
  begin
    FreeMem(P);
    ZMFreeHandle(hMem);
  end;
  Result := 0;
end;

function GlobalLock(hMem: HGLOBAL): Pointer;
var
  P: PGlobalBlock;
begin
  P := PGlobalBlock(Pointer(ZMHandleObj(hMem)));
  if P = nil then Exit(nil);
  Result := @P^.Data;
end;

function GlobalUnlock(hMem: HGLOBAL): BOOL;
begin
  Result := True;
end;

function GlobalSize(hMem: HGLOBAL): PtrUInt;
var
  P: PGlobalBlock;
begin
  P := PGlobalBlock(Pointer(ZMHandleObj(hMem)));
  if P = nil then Result := 0 else Result := P^.Size;
end;

procedure GlobalMemoryStatus(var lpBuffer: TMemoryStatus);
begin
  FillChar(lpBuffer, SizeOf(lpBuffer), 0);
  lpBuffer.dwLength := SizeOf(lpBuffer);
  lpBuffer.dwTotalPhys := 256 * 1024 * 1024;
  lpBuffer.dwAvailPhys := 128 * 1024 * 1024;
  lpBuffer.dwTotalVirtual := 2047 * 1024 * 1024;
  lpBuffer.dwAvailVirtual := 1024 * 1024 * 1024;
end;

procedure InitializeCriticalSection(var lpCriticalSection: TRTLCriticalSection);
begin
  FillChar(lpCriticalSection, SizeOf(lpCriticalSection), 0);
end;

procedure EnterCriticalSection(var lpCriticalSection: TRTLCriticalSection);
begin
end;

procedure LeaveCriticalSection(var lpCriticalSection: TRTLCriticalSection);
begin
end;

procedure DeleteCriticalSection(var lpCriticalSection: TRTLCriticalSection);
begin
end;

function InterlockedIncrement(var Addend: Longint): Longint;
begin
  Inc(Addend);
  Result := Addend;
end;

function InterlockedDecrement(var Addend: Longint): Longint;
begin
  Dec(Addend);
  Result := Addend;
end;

function InterlockedExchange(var Target: Longint; Value: Longint): Longint;
begin
  Result := Target;
  Target := Value;
end;

function MulDiv(nNumber, nNumerator, nDenominator: Integer): Integer;
var
  T: Int64;
begin
  if nDenominator = 0 then Exit(-1);
  T := Int64(nNumber) * nNumerator;
  { rondt half af van nul af, zoals Windows }
  if (T < 0) xor (nDenominator < 0) then
    Result := (T - Abs(nDenominator) div 2) div nDenominator
  else
    Result := (T + Abs(nDenominator) div 2) div nDenominator;
end;

function lstrlen(lpString: PAnsiChar): Integer;
begin
  Result := StrLen(lpString);
end;

function lstrcpy(lpString1, lpString2: PAnsiChar): PAnsiChar;
begin
  Result := StrCopy(lpString1, lpString2);
end;

function lstrcmp(lpString1, lpString2: PAnsiChar): Integer;
begin
  Result := StrComp(lpString1, lpString2);
end;

function lstrcmpi(lpString1, lpString2: PAnsiChar): Integer;
begin
  Result := StrIComp(lpString1, lpString2);
end;

function CharUpper(lpsz: PAnsiChar): PAnsiChar;
begin
  if PtrUInt(lpsz) < $10000 then
    Result := PAnsiChar(PtrUInt(Ord(UpCase(AnsiChar(PtrUInt(lpsz))))))
  else
    Result := StrUpper(lpsz);
end;

function CharLower(lpsz: PAnsiChar): PAnsiChar;
begin
  if PtrUInt(lpsz) < $10000 then
    Result := PAnsiChar(PtrUInt(Ord(LowerCase(AnsiChar(PtrUInt(lpsz))))))
  else
    Result := StrLower(lpsz);
end;

function CharNext(lpsz: PAnsiChar): PAnsiChar;
begin
  if lpsz^ = #0 then Result := lpsz else Result := lpsz + 1;
end;

function CharPrev(lpszStart: PAnsiChar; lpszCurrent: PAnsiChar): PAnsiChar;
begin
  if lpszCurrent > lpszStart then Result := lpszCurrent - 1 else Result := lpszStart;
end;

function OutputDebugString(lpOutputString: PAnsiChar): BOOL;
begin
  if GetEnvironmentVariable('ZM_DEBUG') <> '' then WriteLn(StdErr, StrPas(lpOutputString));
  Result := True;
end;

{ INI-bestanden: zie ZMProfile (bewerkt ter plekke, schrijft naar de overlay) }
function GetPrivateProfileString(lpAppName, lpKeyName, lpDefault: PAnsiChar;
  lpReturnedString: PAnsiChar; nSize: DWORD; lpFileName: PAnsiChar): DWORD;
begin
  Result := ZMGetPrivateProfileString(lpAppName, lpKeyName, lpDefault, lpReturnedString,
    nSize, lpFileName);
end;

function WritePrivateProfileString(lpAppName, lpKeyName, lpString, lpFileName: PAnsiChar): BOOL;
begin
  Result := ZMWritePrivateProfileString(lpAppName, lpKeyName, lpString, lpFileName);
end;

function GetPrivateProfileInt(lpAppName, lpKeyName: PAnsiChar; nDefault: Integer;
  lpFileName: PAnsiChar): UINT;
begin
  Result := ZMGetPrivateProfileInt(lpAppName, lpKeyName, nDefault, lpFileName);
end;

{ ---------------------------------------------------------------- resources }

function FindResource(hModule: HMODULE; lpName, lpType: PAnsiChar): HRSRC;
begin
  Result := ZMFindExeResource(lpName, lpType);
end;

function LoadResource(hModule: HINST; hResInfo: HRSRC): HGLOBAL;
begin
  Result := hResInfo;
end;

function LockResource(hResData: HGLOBAL): Pointer;
begin
  Result := ZMExeResourceData(hResData);
end;

function SizeofResource(hModule: HINST; hResInfo: HRSRC): DWORD;
begin
  Result := ZMExeResourceSize(hResInfo);
end;

function FreeResource(hResData: HGLOBAL): BOOL;
begin
  Result := True;
end;

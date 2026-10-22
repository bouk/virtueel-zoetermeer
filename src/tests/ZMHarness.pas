unit ZMHarness;

{ Differential-test harness for the portable build: runs the same input scripts as
  tools/orig_probe.py does against the original, and writes the same state dumps.

  ZM_TESTSCRIPT=<file.zms>   script to run (see docs/DIFFTEST.md)
  ZM_TESTOUT=<dir>           where dump/shot files go

  The script runs from ZMIdleHook (called on every pass of the message pump, also inside
  modal loops); input is injected through ZMWin as if it came from the backend. }

{$MODE DELPHI}{$H+}

interface

implementation

uses
  SysUtils, Classes, Windows, ZMPlatform, ZMWin, ZMRandom, Fmain, Uworld, uSprite;

type
  TActionKind = (akMove, akDown, akUp, akKey, akChar, akSeed, akDump, akShot, akSprites, akExit);
  TAction = record
    At: Int64;            { ms since script start }
    Kind: TActionKind;
    X, Y, Button: Integer;
    Arg: string;
  end;

var
  Actions: array of TAction;
  Next: Integer;
  StartTime: Int64 = -1;
  OutDir: string;

const
  NoSeed = Low(Int64);

var
  PendingSeed: Int64 = NoSeed;

procedure Add(At: Int64; Kind: TActionKind; X, Y, Button: Integer; const Arg: string);
var
  N: Integer;
begin
  N := Length(Actions);
  SetLength(Actions, N + 1);
  Actions[N].At := At;
  Actions[N].Kind := Kind;
  Actions[N].X := X;
  Actions[N].Y := Y;
  Actions[N].Button := Button;
  Actions[N].Arg := Arg;
end;

{ xdotool key names used in scripts -> Windows virtual keys / characters }
procedure AddKey(At: Int64; const Name: string);
const
  Names: array[0..9] of string = ('Return', 'Escape', 'Left', 'Right', 'Up', 'Down',
    'Tab', 'BackSpace', 'Delete', 'space');
  Codes: array[0..9] of Word = (VK_RETURN, VK_ESCAPE, VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN,
    VK_TAB, VK_BACK, VK_DELETE, VK_SPACE);
var
  I: Integer;
begin
  if Name = 'plus' then
    Add(At, akChar, 0, 0, 0, '+')
  else if Name = 'minus' then
    Add(At, akChar, 0, 0, 0, '-')
  else if Length(Name) = 1 then
    Add(At, akChar, 0, 0, 0, Name)
  else
  begin
    for I := Low(Names) to High(Names) do
      if Name = Names[I] then
      begin
        Add(At, akKey, Codes[I], 1, 0, '');
        Add(At + 50, akKey, Codes[I], 0, 0, '');
        Exit;
      end;
    raise Exception.CreateFmt('harness: unknown key %s', [Name]);
  end;
end;

{ Parse the script into timed primitive actions, mirroring tools/orig_probe.py:
  a click enters the target from 60 px to the left in 3 px steps (30 ms apart), waits
  300 ms, presses, and releases 150 ms later. }
procedure LoadScript(const FileName: string);
var
  Lines, F: TStringList;
  I, J, X, Y, Btn: Integer;
  T: Int64;
  Line: string;
begin
  Lines := TStringList.Create;
  F := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    T := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      if Pos('#', Line) > 0 then
        Line := Copy(Line, 1, Pos('#', Line) - 1);
      F.Clear;
      ExtractStrings([' ', #9], [], PChar(Line), F);
      if F.Count = 0 then
        Continue;
      if F[0] = 'wait' then
        Inc(T, StrToInt(F[1]))
      else if F[0] = 'move' then
        Add(T, akMove, StrToInt(F[1]), StrToInt(F[2]), 0, '')
      else if F[0] = 'click' then
      begin
        X := StrToInt(F[1]);
        Y := StrToInt(F[2]);
        Btn := 1;
        if (F.Count > 3) and (F[3] = 'right') then
          Btn := 2;
        for J := 20 downto 0 do
        begin
          Add(T, akMove, X - 3 * J, Y, 0, '');
          Inc(T, 30);
        end;
        Inc(T, 300);
        Add(T, akDown, X, Y, Btn, '');
        Inc(T, 150);
        Add(T, akUp, X, Y, Btn, '');
      end
      else if F[0] = 'key' then
      begin
        AddKey(T, F[1]);
        Inc(T, 100);
      end
      else if F[0] = 'seed' then
        Add(T, akSeed, StrToInt(F[1]), 0, 0, '')
      else if F[0] = 'dump' then
        Add(T, akDump, 0, 0, 0, F[1])
      else if F[0] = 'sprites' then
        Add(T, akSprites, 0, 0, 0, F[1])
      else if F[0] = 'shot' then
        Add(T, akShot, 0, 0, 0, F[1])
      else
        raise Exception.CreateFmt('harness: unknown command in %s: %s', [FileName, Lines[I]]);
    end;
    Add(T + 500, akExit, 0, 0, 0, '');
  finally
    F.Free;
    Lines.Free;
  end;
end;

{ Same format as tools/orig_probe.py state_text }
function StateText: string;
var
  S: TStringList;
  X, Y: Integer;
  W: TWorld;
  C: TCell;
  Fmt: TFormatSettings;

  function Dash(const V: string): string;
  begin
    if V = '' then Result := '-' else Result := V;
  end;

begin
  Fmt := DefaultFormatSettings;
  Fmt.DecimalSeparator := '.';
  W := frmMain.FWorld;
  S := TStringList.Create;
  try
    S.Add(Format('level %d', [frmMain.FStatus.Level]));
    S.Add(Format('geld %d', [frmMain.FStatus.Geld]));
    S.Add(Format('score %d', [frmMain.FStatus.Score]));
    S.Add(Format('reistijd %.6f', [W.Reistijd], Fmt));
    for X := 0 to WorldSize - 1 do
      for Y := 0 to WorldSize - 1 do
      begin
        C := W.Cells[X, Y];
        S.Add(Format('cell %d %d %s %s %d %d %d', [X, Y, Dash(C.Contents), Dash(C.Param),
          C.Wijk, C.Wegen, Ord(C.Bereikbaar)]));
      end;
    S.LineBreak := #10;
    Result := S.Text;
  finally
    S.Free;
  end;
end;

{ Port-only debugging aid: every sprite of the main form }
function SpritesText: string;
var
  S: TStringList;
  I: Integer;
  Sp: TSprite;
  Frames: Integer;
begin
  S := TStringList.Create;
  try
    for I := 0 to frmMain.ComponentCount - 1 do
      if frmMain.Components[I] is TSprite then
      begin
        Sp := TSprite(frmMain.Components[I]);
        Frames := -1;
        if Sp.FrameList <> nil then
          Frames := Sp.FrameList.Count;
        S.Add(Format('%s visible=%d pos=%d,%d frame=%s index=%d frames=%d',
          [Sp.Name, Ord(Sp.Visible), Sp.Left, Sp.Top, Sp.CurrentFrame, Sp.FrameIndex, Frames]));
      end;
    S.LineBreak := #10;
    Result := S.Text;
  finally
    S.Free;
  end;
end;

procedure WriteFile(const Name, Text: string);
var
  F: TFileStream;
begin
  F := TFileStream.Create(Name, fmCreate);
  try
    if Text <> '' then
      F.WriteBuffer(Text[1], Length(Text));
  finally
    F.Free;
  end;
end;

procedure Tick;
var
  Now: Int64;
  A: TAction;
begin
  Now := GetTickCount64;
  if StartTime < 0 then
    StartTime := Now;
  while (Next < Length(Actions)) and (Now - StartTime >= Actions[Next].At) do
  begin
    A := Actions[Next];
    Inc(Next);
    case A.Kind of
      akMove: ZMInjectMouse(A.X, A.Y, 0, False);
      akDown:
        begin
          { een 'seed' geldt vlak voor de volgende muisklik (zie docs/DIFFTEST.md) }
          if PendingSeed <> NoSeed then
          begin
            ZMRandom.RandSeed := PendingSeed;
            PendingSeed := NoSeed;
          end;
          ZMInjectMouse(A.X, A.Y, A.Button, True);
        end;
      akUp: ZMInjectMouse(A.X, A.Y, A.Button, False);
      akKey: ZMInjectKey(A.X, A.Y <> 0);
      akChar: ZMInjectChar(A.Arg[1]);
      akSeed: PendingSeed := A.X;
      akDump: WriteFile(IncludeTrailingPathDelimiter(OutDir) + A.Arg + '.state', StateText);
      akSprites: WriteFile(IncludeTrailingPathDelimiter(OutDir) + A.Arg + '.sprites', SpritesText);
      akShot: ZMSaveScreenshot(IncludeTrailingPathDelimiter(OutDir) + A.Arg + '.png');
      akExit: Halt(0);
    end;
  end;
end;

initialization
  if GetEnvironmentVariable('ZM_TESTSCRIPT') <> '' then
  begin
    OutDir := GetEnvironmentVariable('ZM_TESTOUT');
    if OutDir = '' then
      OutDir := '.';
    ForceDirectories(OutDir);
    LoadScript(GetEnvironmentVariable('ZM_TESTSCRIPT'));
    ZMIdleHook := Tick;
  end;
end.

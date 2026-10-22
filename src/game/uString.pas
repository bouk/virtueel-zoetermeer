unit uString;

{ String helpers shared by the sprite engine and the game.
  Decompiled from ROS.exe v1.1, code 0045F98C-004609B3. }

{$I zm.inc}

interface

var
  StrConvError: Boolean;   { 0048A898: set by StrToIntDef0/StrToFloatDef0 }

function ReplaceStr(S, Find, Replace: string): string;
function UpStr(S: string): string;
function LowStr(S: string): string;
function SplitFirst(var S: string; Sep: string): string;
function ByteToHex(B: Byte): string;
function WordToHex(W: Word): string;
function LongToHex(L: Longint): string;
function IntStr(I: Longint): string;
function LeftStr(S: string; N: Word): string;
function RealToStr(R: Double): string;
function IsDigit(C: Char): Boolean;
function RepeatStr(S: string; N: Word): string;
procedure UpChar(var C: Char);
procedure LowChar(var C: Char);
procedure MakeUpper(var S: string);
procedure MakeLower(var S: string);
procedure TrimLeftV(var S: string);
procedure TrimRightV(var S: string);
procedure TrimV(var S: string);
function TrimStr(S: string): string;
function AddPath(Dir, Name: string): string;
function DelLeft(S: string; N: Word): string;
function StartsWith(S, Prefix: string): Boolean;
function PadRight(S: string; N: Word): string;
function PadLeft(S: string; N: Word): string;
function ZeroPad(S: string; N: Integer): string;
function StrToIntDef0(S: string): Integer;
function StrToFloatDef0(S: string): Double;
function CountChar(S: string; C: Char): Integer;
function EndsWith(S, Suffix: string): Boolean;
function SameText2(A, B: string): Boolean;
function LongToStr(L: Longint): string;
function FloatToStrT(R: Double): string;

implementation

uses
  SysUtils;

const
  Digits: array[0..35] of Char = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';   { 00488CA0 }
  UpperChars: set of Char = ['A'..'Z'];                                  { 00488CC4 }
  WhiteSpace: set of Char = [#8, #9, #10, #13, ' ', #127];               { 00488CE4 }

{ @0045F98C }
function ReplaceStr(S, Find, Replace: string): string;
var
  Token: string;
begin
  S := S + Find;
  Result := '';
  Token := SplitFirst(S, Find);
  while S <> '' do
  begin
    Result := Result + Token + Replace;
    Token := SplitFirst(S, Find);
  end;
  Result := Result + Token;
end;

{ @0045FA48 }
function UpStr(S: string): string;
begin
  MakeUpper(S);
  Result := S;
end;

{ @0045FA9C }
function LowStr(S: string): string;
begin
  MakeLower(S);
  Result := S;
end;

{ @0045FAF0 }
function SplitFirst(var S: string; Sep: string): string;
var
  P: Word;
begin
  P := Pos(Sep, S);
  if P = 0 then
  begin
    Result := S;
    S := '';
  end
  else
  begin
    Result := Copy(S, 1, P - 1);
    Delete(S, 1, P + Length(Sep) - 1);
  end;
end;

{ @0045FB88 }
function ByteToHex(B: Byte): string;
begin
  Result := Digits[B shr 4] + Digits[B and $F];
end;

{ @0045FBEC }
function WordToHex(W: Word): string;
begin
  Result := ByteToHex(W shr 8) + ByteToHex(W and $FF);
end;

{ @0045FC58 }
function LongToHex(L: Longint): string;
begin
  Result := WordToHex(L shr 16) + WordToHex(L and $FFFF);
end;

{ @0045FCC8 }
function IntStr(I: Longint): string;
var
  S: string;
begin
  Str(I, S);
  Result := S;
end;

{ @0045FD34 }
function LeftStr(S: string; N: Word): string;
begin
  if Length(S) < N then
    Result := S
  else
    Result := Copy(S, 1, N);
end;

{ @0045FDA8 }
function RealToStr(R: Double): string;
var
  S: string;
  L: Word;
begin
  Str(R:0:12, S);
  L := Length(S);
  if Pos('.', S) > 0 then
  begin
    while S[L] = '0' do
      Dec(L);
    if S[L] = '.' then
      Dec(L);
    SetLength(S, L);
  end;
  Result := S;
end;

{ @0045FE74 }
function IsDigit(C: Char): Boolean;
begin
  Result := C in ['0'..'9'];
end;

{ @0045FE84 }
function RepeatStr(S: string; N: Word): string;
var
  T: string;
begin
  T := '';
  while N > 0 do
  begin
    T := T + S;
    Dec(N);
  end;
  Result := T;
end;

{ @0045FF00 }
procedure UpChar(var C: Char);
begin
  C := UpCase(C);
end;

{ @0045FF10 }
procedure LowChar(var C: Char);
begin
  if C in UpperChars then
    C := Chr(Ord(C) + 32);
end;

{ @0045FF2C }
procedure MakeUpper(var S: string);
var
  I: Word;
begin
  for I := 1 to Length(S) do
    UpChar(S[I]);
end;

{ @0045FF60 }
procedure MakeLower(var S: string);
var
  I: Word;
begin
  for I := 1 to Length(S) do
    LowChar(S[I]);
end;

{ @0045FF94 }
procedure TrimLeftV(var S: string);
var
  I: Word;
begin
  if S <> '' then
  begin
    I := 1;
    while S[I] in WhiteSpace do
    begin
      Inc(I);
      if Length(S) < I then
      begin
        S := '';
        Exit;
      end;
    end;
    if I <> 1 then
      Delete(S, 1, I - 1);
  end;
end;

{ @0045FFEC }
procedure TrimRightV(var S: string);
var
  L: Integer;
begin
  if S <> '' then
  begin
    L := Length(S);
    { NOTE: reaches S[0] (the byte before the text) for an all-blank string;
      it is #0 or a length byte and the loop then ends at -1. }
    while S[L] in WhiteSpace do
    begin
      Dec(L);
      if L = -1 then
      begin
        S := '';
        Exit;
      end;
    end;
    SetLength(S, L);
  end;
end;

{ @0046002C }
procedure TrimV(var S: string);
begin
  TrimLeftV(S);
  TrimRightV(S);
end;

{ @00460040 }
function TrimStr(S: string): string;
begin
  TrimV(S);
  Result := S;
end;

{ @00460094 }
function AddPath(Dir, Name: string): string;
var
  Sep: string[1];
begin
  if (Length(Dir) > 0) and (Dir[Length(Dir)] <> ':') and (Dir[Length(Dir)] <> '\') then
    Sep := '\'
  else
    Sep := '';
  Result := Dir + Sep + Name;
end;

{ @00460154 }
function DelLeft(S: string; N: Word): string;
begin
  if Length(S) > N then
  begin
    Delete(S, 1, N);
    Result := S;
  end
  else
    Result := '';
end;

{ @004601CC }
function StartsWith(S, Prefix: string): Boolean;
begin
  if Length(S) < Length(Prefix) then
    Result := False
  else
  begin
    SetLength(S, Length(Prefix));
    Result := S = Prefix;
  end;
end;

{ @0046025C }
function PadRight(S: string; N: Word): string;
begin
  if Length(S) > N then
    Result := Copy(S, 1, N)
  else
    Result := S + RepeatStr(' ', N - Length(S));
end;

{ @00460304 }
function PadLeft(S: string; N: Word): string;
begin
  if Length(S) >= N then
    Result := Copy(S, Length(S) + 1 - N, N)
  else
    Result := RepeatStr(' ', N - Length(S)) + S;
end;

{ @004603B8 }
function ZeroPad(S: string; N: Integer): string;
begin
  if N <= Length(S) then
    Result := S
  else
    Result := RepeatStr('0', N - Length(S)) + S;
end;

{ @00460458 }
function StrToIntDef0(S: string): Integer;
var
  I: Integer;
  C: Char;
  Err: Word;
begin
  TrimV(S);
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if (C <> '-') and not IsDigit(C) then
    begin
      SetLength(S, I - 1);
      Break;
    end;
  end;
  TrimV(S);
  if S = '' then
    Result := 0
  else
  begin
    try
      I := StrToInt(S);
      Err := 0;
    except
      Err := 1;
    end;
    StrConvError := Err <> 0;
    if StrConvError then
      I := 0;
    Result := I;
  end;
end;

{ @00460554 }
function StrToFloatDef0(S: string): Double;
var
  Negative, HadSep: Boolean;
  I: Integer;
  R: Double;
  Err: Word;
begin
  TrimV(S);
  if Length(S) = 0 then
    Result := 0
  else
  begin
    Negative := False;
    if S[1] = '-' then
    begin
      S := Copy(S, 2, Length(S));
      Negative := True;
    end;
    HadSep := False;
    for I := 1 to Length(S) do
      if not IsDigit(S[I]) then
      begin
        if HadSep or (S[I] <> DecimalSeparator) then
        begin
          SetLength(S, I - 1);
          Break;
        end;
        HadSep := True;
      end;
    TrimV(S);
    if S = '' then
      Result := 0
    else
    begin
      if Negative then
        S := '-' + S;
      try
        R := StrToFloat(S);
        Err := 0;
      except
        Err := 1;
        R := 0;
      end;
      StrConvError := Err <> 0;
      Result := R;
    end;
  end;
end;

{ @004606C4 }
function CountChar(S: string; C: Char): Integer;
var
  I, N: Integer;
begin
  N := 0;
  for I := 1 to Length(S) do
    if C = S[I] then
      Inc(N);
  Result := N;
end;

{ @0046072C }
function EndsWith(S, Suffix: string): Boolean;
begin
  Result := Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix)) = Suffix;
end;

{ @004607C0 }
function SameText2(A, B: string): Boolean;
begin
  Result := UpperCase(A) = UpperCase(B);
end;

{ @00460844 }
function LongToStr(L: Longint): string;
var
  S: string;
begin
  Str(L, S);
  Result := S;
end;

{ @004608B0 }
function FloatToStrT(R: Double): string;
var
  S: string;
  L: Word;
begin
  Str(R:0:12, S);
  L := Length(S);
  if Pos('.', S) > 0 then
  begin
    while S[L] = '0' do
      Dec(L);
    if S[L] = '.' then
      Dec(L);
    SetLength(S, L);
  end;
  Result := S;
end;

end.

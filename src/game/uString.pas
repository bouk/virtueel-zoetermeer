unit uString;

{ Tekenreekshulpfuncties, gedeeld door de sprite-engine en het spel.
  Gedecompileerd uit ROS.exe v1.1, code 0045F98C-004609B3. }

{$I zm.inc}

interface

var
  StrConvFout: Boolean;   { 0048A898: wordt gezet door StrNaarIntDef0/StrNaarFloatDef0 }

function VervangStr(S, Find, Replace: string): string;
function HoofdStr(S: string): string;
function KleinStr(S: string): string;
function SplitsEerste(var S: string; Sep: string): string;
function ByteNaarHex(B: Byte): string;
function WoordNaarHex(W: Word): string;
function LongNaarHex(L: Longint): string;
function IntTekst(I: Longint): string;
function LinksStr(S: string; N: Word): string;
function RealNaarStr(R: Double): string;
function IsCijfer(C: Char): Boolean;
function HerhaalStr(S: string; N: Word): string;
procedure HoofdChar(var C: Char);
procedure KleinChar(var C: Char);
procedure MaakHoofdletters(var S: string);
procedure MaakKleinletters(var S: string);
procedure SnijLinksV(var S: string);
procedure SnijRechtsV(var S: string);
procedure SnijV(var S: string);
function SnijStr(S: string): string;
function VoegPadToe(Dir, Name: string): string;
function VerwijderLinks(S: string; N: Word): string;
function BegintMet(S, NaamVoorvoegsel: string): Boolean;
function VulRechts(S: string; N: Word): string;
function VulLinks(S: string; N: Word): string;
function NulVul(S: string; N: Integer): string;
function StrNaarIntDef0(S: string): Integer;
function StrNaarFloatDef0(S: string): Double;
function TelTeken(S: string; C: Char): Integer;
function EindigtMet(S, Suffix: string): Boolean;
function GelijkTekst2(A, B: string): Boolean;
function LongNaarStr(L: Longint): string;
function FloatNaarStrT(R: Double): string;

implementation

uses
  SysUtils;

const
  Digits: array[0..35] of Char = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';   { 00488CA0 }
  UpperChars: set of Char = ['A'..'Z'];                                  { 00488CC4 }
  WhiteSpace: set of Char = [#8, #9, #10, #13, ' ', #127];               { 00488CE4 }

{ @0045F98C }
function VervangStr(S, Find, Replace: string): string;
var
  Stuk: string;
begin
  S := S + Find;
  Result := '';
  Stuk := SplitsEerste(S, Find);
  while S <> '' do
  begin
    Result := Result + Stuk + Replace;
    Stuk := SplitsEerste(S, Find);
  end;
  Result := Result + Stuk;
end;

{ @0045FA48 }
function HoofdStr(S: string): string;
begin
  MaakHoofdletters(S);
  Result := S;
end;

{ @0045FA9C }
function KleinStr(S: string): string;
begin
  MaakKleinletters(S);
  Result := S;
end;

{ @0045FAF0 }
function SplitsEerste(var S: string; Sep: string): string;
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
function ByteNaarHex(B: Byte): string;
begin
  Result := Digits[B shr 4] + Digits[B and $F];
end;

{ @0045FBEC }
function WoordNaarHex(W: Word): string;
begin
  Result := ByteNaarHex(W shr 8) + ByteNaarHex(W and $FF);
end;

{ @0045FC58 }
function LongNaarHex(L: Longint): string;
begin
  Result := WoordNaarHex(L shr 16) + WoordNaarHex(L and $FFFF);
end;

{ @0045FCC8 }
function IntTekst(I: Longint): string;
var
  S: string;
begin
  Str(I, S);
  Result := S;
end;

{ @0045FD34 }
function LinksStr(S: string; N: Word): string;
begin
  if Length(S) < N then
    Result := S
  else
    Result := Copy(S, 1, N);
end;

{ @0045FDA8 }
function RealNaarStr(R: Double): string;
var
  S: string;
  Lengte: Word;
begin
  Str(R:0:12, S);
  Lengte := Length(S);
  if Pos('.', S) > 0 then
  begin
    while S[Lengte] = '0' do
      Dec(Lengte);
    if S[Lengte] = '.' then
      Dec(Lengte);
    SetLength(S, Lengte);
  end;
  Result := S;
end;

{ @0045FE74 }
function IsCijfer(C: Char): Boolean;
begin
  Result := C in ['0'..'9'];
end;

{ @0045FE84 }
function HerhaalStr(S: string; N: Word): string;
var
  Tekst: string;
begin
  Tekst := '';
  while N > 0 do
  begin
    Tekst := Tekst + S;
    Dec(N);
  end;
  Result := Tekst;
end;

{ @0045FF00 }
procedure HoofdChar(var C: Char);
begin
  C := UpCase(C);
end;

{ @0045FF10 }
procedure KleinChar(var C: Char);
begin
  if C in UpperChars then
    C := Chr(Ord(C) + 32);
end;

{ @0045FF2C }
procedure MaakHoofdletters(var S: string);
var
  I: Word;
begin
  for I := 1 to Length(S) do
    HoofdChar(S[I]);
end;

{ @0045FF60 }
procedure MaakKleinletters(var S: string);
var
  I: Word;
begin
  for I := 1 to Length(S) do
    KleinChar(S[I]);
end;

{ @0045FF94 }
procedure SnijLinksV(var S: string);
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
procedure SnijRechtsV(var S: string);
var
  L: Integer;
begin
  if S <> '' then
  begin
    L := Length(S);
    { LET OP: bereikt S[0] (het byte voor de tekst) bij een tekenreeks die alleen spaties bevat;
      dat is #0 of een lengtebyte, en de lus eindigt dan bij -1. }
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
procedure SnijV(var S: string);
begin
  SnijLinksV(S);
  SnijRechtsV(S);
end;

{ @00460040 }
function SnijStr(S: string): string;
begin
  SnijV(S);
  Result := S;
end;

{ @00460094 }
function VoegPadToe(Dir, Name: string): string;
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
function VerwijderLinks(S: string; N: Word): string;
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
function BegintMet(S, NaamVoorvoegsel: string): Boolean;
begin
  if Length(S) < Length(NaamVoorvoegsel) then
    Result := False
  else
  begin
    SetLength(S, Length(NaamVoorvoegsel));
    Result := S = NaamVoorvoegsel;
  end;
end;

{ @0046025C }
function VulRechts(S: string; N: Word): string;
begin
  if Length(S) > N then
    Result := Copy(S, 1, N)
  else
    Result := S + HerhaalStr(' ', N - Length(S));
end;

{ @00460304 }
function VulLinks(S: string; N: Word): string;
begin
  if Length(S) >= N then
    Result := Copy(S, Length(S) + 1 - N, N)
  else
    Result := HerhaalStr(' ', N - Length(S)) + S;
end;

{ @004603B8 }
function NulVul(S: string; N: Integer): string;
begin
  if N <= Length(S) then
    Result := S
  else
    Result := HerhaalStr('0', N - Length(S)) + S;
end;

{ @00460458 }
function StrNaarIntDef0(S: string): Integer;
var
  I: Integer;
  Teken: Char;
  Fout: Word;
begin
  SnijV(S);
  for I := 1 to Length(S) do
  begin
    Teken := S[I];
    if (Teken <> '-') and not IsCijfer(Teken) then
    begin
      SetLength(S, I - 1);
      Break;
    end;
  end;
  SnijV(S);
  if S = '' then
    Result := 0
  else
  begin
    try
      I := StrToInt(S);
      Fout := 0;
    except
      Fout := 1;
    end;
    StrConvFout := Fout <> 0;
    if StrConvFout then
      I := 0;
    Result := I;
  end;
end;

{ @00460554 }
function StrNaarFloatDef0(S: string): Double;
var
  Negatief, HadScheiding: Boolean;
  I: Integer;
  Getal: Double;
  Fout: Word;
begin
  SnijV(S);
  if Length(S) = 0 then
    Result := 0
  else
  begin
    Negatief := False;
    if S[1] = '-' then
    begin
      S := Copy(S, 2, Length(S));
      Negatief := True;
    end;
    HadScheiding := False;
    for I := 1 to Length(S) do
      if not IsCijfer(S[I]) then
      begin
        if HadScheiding or (S[I] <> DecimalSeparator) then
        begin
          SetLength(S, I - 1);
          Break;
        end;
        HadScheiding := True;
      end;
    SnijV(S);
    if S = '' then
      Result := 0
    else
    begin
      if Negatief then
        S := '-' + S;
      try
        Getal := StrToFloat(S);
        Fout := 0;
      except
        Fout := 1;
        Getal := 0;
      end;
      StrConvFout := Fout <> 0;
      Result := Getal;
    end;
  end;
end;

{ @004606C4 }
function TelTeken(S: string; C: Char): Integer;
var
  I, Aantal: Integer;
begin
  Aantal := 0;
  for I := 1 to Length(S) do
    if C = S[I] then
      Inc(Aantal);
  Result := Aantal;
end;

{ @0046072C }
function EindigtMet(S, Suffix: string): Boolean;
begin
  Result := Copy(S, Length(S) - Length(Suffix) + 1, Length(Suffix)) = Suffix;
end;

{ @004607C0 }
function GelijkTekst2(A, B: string): Boolean;
begin
  Result := UpperCase(A) = UpperCase(B);
end;

{ @00460844 }
function LongNaarStr(L: Longint): string;
var
  S: string;
begin
  Str(L, S);
  Result := S;
end;

{ @004608B0 }
function FloatNaarStrT(R: Double): string;
var
  S: string;
  Lengte: Word;
begin
  Str(R:0:12, S);
  Lengte := Length(S);
  if Pos('.', S) > 0 then
  begin
    while S[Lengte] = '0' do
      Dec(Lengte);
    if S[Lengte] = '.' then
      Dec(Lengte);
    SetLength(S, Lengte);
  end;
  Result := S;
end;

end.

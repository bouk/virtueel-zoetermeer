unit ZMRandom;

{ De willekeurige-getallengenerator van Delphi 5, zodat de draagbare build bij dezelfde seed
  dezelfde "willekeurige" keuzes maakt als het origineel (huisvarianten, gebeurtenissen,
  treinen). De eigen Random van Free Pascal is een Mersenne Twister.

  Spelunits die Random/Randomize aanroepen, zetten deze unit als laatste in hun
  uses-clausule onder een IFDEF FPC; dan overschaduwen deze declaraties de System-varianten.

  Overgenomen uit ROS.exe: System.@RandInt (00402B98) en System.Randomize (00402924).
  ZM_RANDSEED=<n> in de omgeving laat Randomize een vaste seed gebruiken (differentiële tests). }

{$MODE DELPHI}

interface

var
  RandSeed: Longint;

procedure Randomize;
function Random(Bereik: Integer): Integer;

implementation

uses
  SysUtils;

procedure Randomize;
var
  Uur, Minuut, Seconde, Milliseconde: Word;
  Vast: string;
begin
  Vast := GetEnvironmentVariable('ZM_RANDSEED');
  if Vast <> '' then
  begin
    RandSeed := StrToInt(Vast);
    Exit;
  end;
  { Delphi 5: GetSystemTime, seed = milliseconden sinds middernacht (UTC) }
  DecodeTime(Time, Uur, Minuut, Seconde, Milliseconde);
  RandSeed := ((Uur * 60 + Minuut) * 60 + Seconde) * 1000 + Milliseconde;
end;

function VolgendZaad: Longword;
begin
  {$PUSH}{$Q-}{$R-}
  RandSeed := Longint(Longword(RandSeed) * $08088405 + 1);
  {$POP}
  Result := Longword(RandSeed);
end;

function Random(Bereik: Integer): Integer;
begin
  { MUL: ongetekend 32x32 -> 64, hoge helft }
  Result := Integer((QWord(VolgendZaad) * QWord(Longword(Bereik))) shr 32);
end;

end.

unit ZMRandom;

{ Delphi 5's random number generator, so the portable build makes the same "random" choices
  as the original (house variants, events, trains) for the same seed. Free Pascal's own
  Random is a Mersenne Twister.

  Game units that call Random/Randomize list this unit last in their uses clause under
  {$IFDEF FPC}, which makes these declarations shadow the System ones.

  Taken from ROS.exe: System.@RandInt (00402B98) and System.Randomize (00402924).
  ZM_RANDSEED=<n> in the environment makes Randomize use a fixed seed (differential tests). }

{$MODE DELPHI}

interface

var
  RandSeed: Longint;

procedure Randomize;
function Random(Range: Integer): Integer;

implementation

uses
  SysUtils;

procedure Randomize;
var
  H, M, S, MS: Word;
  Fixed: string;
begin
  Fixed := GetEnvironmentVariable('ZM_RANDSEED');
  if Fixed <> '' then
  begin
    RandSeed := StrToInt(Fixed);
    Exit;
  end;
  { Delphi 5: GetSystemTime, seed = milliseconds since midnight (UTC) }
  DecodeTime(Time, H, M, S, MS);
  RandSeed := ((H * 60 + M) * 60 + S) * 1000 + MS;
end;

function NextSeed: Longword;
begin
  {$PUSH}{$Q-}{$R-}
  RandSeed := Longint(Longword(RandSeed) * $08088405 + 1);
  {$POP}
  Result := Longword(RandSeed);
end;

function Random(Range: Integer): Integer;
begin
  { MUL: unsigned 32x32 -> 64, high half }
  Result := Integer((QWord(NextSeed) * QWord(Longword(Range))) shr 32);
end;

end.

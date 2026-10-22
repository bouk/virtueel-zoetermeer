unit ZMKlok;

{ GetTickCount zoals Delphi 5 hem bindt.

  In Delphi 5 kent SysUtils geen GetTickCount; een spelunit die zowel Windows als SysUtils
  gebruikt, roept dus altijd Windows.GetTickCount aan. De SysUtils van Free Pascal heeft wel een
  GetTickCount (milliseconden sinds het opstarten van de computer, afgekapt tot 32 bits), en die
  wint als SysUtils na Windows in de uses staat. Spelunits waarvoor dat geldt, zetten deze unit
  als laatste in hun uses-clausule onder een IFDEF FPC (zoals ZMRandom); dan gaat GetTickCount
  weer naar de compat-laag (Windows.GetTickCount: milliseconden sinds de start van het programma).

  Dat verschil is niet alleen cosmetisch. TAutoSprite.Draw.DrawAutos (uAutos, @00475440) rekent
  met het Integer-veld FStartTik := GetTickCount. Is de tikteller 2^31 of meer (de computer draait
  tussen 24,9 en 49,7 dagen, modulo 49,7), dan is FStartTik negatief, wordt het verschil met
  GetTickCount ongeveer 2^32, en draait de inhaallus van DrawAutos bij elke aanroep miljoenen
  keren. Elk beeld kost dan honderden milliseconden, de snelle timers lopen achter en slaan tikken
  over, en bijvoorbeeld de knop "Volgende ronde" (timerRecalc) verschijnt op een onvoorspelbaar
  moment. Het origineel heeft die fout ook (onder Wine is GetTickCount de uptime van de computer);
  tools/orig_probe.py draait Wine daarom in een tijdnaamruimte met een kleine uptime. }

{$MODE DELPHI}

interface

uses
  Windows;

function GetTickCount: DWORD; inline;

implementation

function GetTickCount: DWORD;
begin
  Result := Windows.GetTickCount;
end;

end.

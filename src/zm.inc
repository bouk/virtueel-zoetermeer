{ Gemeenschappelijke compilerinstellingen voor elke Virtueel Zoetermeer-unit.
  Delphi 5 bouwt het origineel; Free Pascal bouwt de draagbare versie. }
{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
  {$GOTO ON}
  {$INLINE ON}
{$ELSE}
  {$H+}
  {$DEFINE DELPHI5}
{$ENDIF}

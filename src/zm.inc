{ Common compiler settings for every Virtueel Zoetermeer unit.
  Delphi 5 builds the original; Free Pascal builds the portable version. }
{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
  {$GOTO ON}
  {$INLINE ON}
{$ELSE}
  {$H+}
  {$DEFINE DELPHI5}
{$ENDIF}

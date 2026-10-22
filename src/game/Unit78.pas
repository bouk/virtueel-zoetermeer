unit Unit78;

{ Unit zonder code; alleen de stringliterals (0x472E94-0x472F2B) en de initialization/
  finalization-stubs (0x472F2C-0x472F7B) overleefden de smart linker. Gedecompileerd uit
  ROS.exe v1.1, code 00472E8C-00472F7B.

  De enige data is de getypte constante hieronder (DATA 00488E9C, 8 AnsiString-pointers); ze
  wordt door niets anders gebruikt dan de finalization van deze unit
  (FinalizeArray(@WavFiles, TypeInfo(string), 8)), dus geen enkele unit leest hem.

  Een identiek array staat in Unit49 (code 00461B10, DATA 00488D20), dus de declaratie is
  waarschijnlijk door twee units (of een include-bestand) gedeeld.

  De echte unitnaam is niet met zekerheid terug te halen. Initialisatievolgorde 78 plaatst hem
  tussen Usett (77) en Uworld (79), dus hij wordt als afhankelijkheid van Uworld geinitialiseerd,
  en hij moet al geinitialiseerd zijn voordat uQuickDirectX (84) dat doet. In de PACKAGEINFO-
  unitlijst (volgorde waarin de compiler de units vond) is de enige niet-toegewezen, projectachtige
  naam in dat deel van de lijst 'uDebug' (genoemd na uQuickDirectX/ddraw/OLE2, voor uTrein). Dat
  past bij dit patroon; Unit49 zou dan het andere exemplaar zijn (uMessage?).
  Zie het A4-rapport. }

{$I zm.inc}

interface

const
  { 00488E9C }
  WavFiles: array[0..7] of string = (
    'ambul.WAV', 'dduck.WAV', 'dicerll.WAV', 'dkbell.WAV',
    'frogs.WAV', 'gbell.WAV', 'houst.WAV', 'wdcat.WAV');

implementation

end.

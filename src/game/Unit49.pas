unit Unit49;

{ Gedecompileerd uit ROS.exe v1.1, code 00461B10-00461BFF.

  Alleen een getypte constante overleefde de smart linking: een array met 8 geluidsbestandsnamen
  (data op 00488D20, stringliterals op 00461B18-00461BAF, opgeruimd door de finalization van de unit).
  Niets in ROS.exe leest hem. Unit78 (ook zonder code) declareert een identieke array van eigen
  bodem (00488E9C); de declaratie komt waarschijnlijk uit een gedeelde bron (gekopieerde unit of
  include-bestand).

  LET OP: de echte unitnaam is onbekend. Op grond van zijn positie in de code (tussen fShow en
  SprBmp) wordt hij gebruikt door de sprite-engine (SprBmp/uSurface/Sprframe), en hij werd in de
  PACKAGEINFO-unitlijst al eerder genoemd dan fShow. Geen van de namen daar zonder code (MMSystem,
  DsgnIntf, Registry, Masks, Sprfrmed, Seldir, ExtLbox, Sprsqlst, Sprseqed, ExtStrGr, uMessage,
  SprCtrl, OLE2, uDebug, ...) is met zekerheid aan hem te koppelen, dus de voorlopige naam blijft. }

{$I zm.inc}

interface

const
  WavFiles: array[0..7] of string = (       { 00488D20 }
    'ambul.WAV', 'dduck.WAV', 'dicerll.WAV', 'dkbell.WAV',
    'frogs.WAV', 'gbell.WAV', 'houst.WAV', 'wdcat.WAV');

implementation

end.

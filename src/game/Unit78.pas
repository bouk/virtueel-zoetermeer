unit Unit78;

{ Code-less unit; only its string literals (0x472E94-0x472F2B) and the
  initialization/finalization stubs (0x472F2C-0x472F7B) survived the smart
  linker. Decompiled from ROS.exe v1.1, code 00472E8C-00472F7B.

  The only data is the typed constant below (DATA 00488E9C, 8 AnsiString
  pointers); it is referenced by nothing but this unit's finalization
  (FinalizeArray(@WavFiles, TypeInfo(string), 8)), i.e. no unit reads it.

  An identical array exists in Unit49 (code 00461B10, DATA 00488D20), so the
  declaration is probably shared by two units (or an include file).

  The real unit name is not recoverable with certainty. Init order 78 puts it
  between Usett (77) and Uworld (79), i.e. it is first initialised as a
  dependency of Uworld, and it must already be initialised before
  uQuickDirectX (84). In the PACKAGEINFO unit list (compiler discovery
  order) the only unassigned project-style name in that part of the list is
  'uDebug' (listed after uQuickDirectX/ddraw/OLE2, before uTrein), which fits
  that pattern; Unit49 would then be the other copy (uMessage?).
  See the A4 report. }

{$I zm.inc}

interface

const
  { 00488E9C }
  WavFiles: array[0..7] of string = (
    'ambul.WAV', 'dduck.WAV', 'dicerll.WAV', 'dkbell.WAV',
    'frogs.WAV', 'gbell.WAV', 'houst.WAV', 'wdcat.WAV');

implementation

end.

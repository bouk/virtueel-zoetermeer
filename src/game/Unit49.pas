unit Unit49;

{ Decompiled from ROS.exe v1.1, code 00461B10-00461BFF.

  Only a typed constant survived smart linking: an array of 8 sound file names
  (data at 00488D20, string literals at 00461B18-00461BAF, finalized by the unit's
  finalization). Nothing in ROS.exe reads it. Unit78 (also code-less) declares an
  identical array of its own (00488E9C); the declaration probably comes from a shared
  source (copied unit or include file).

  NOTE: the real unit name is unknown. By its position in the code (between fShow and
  SprBmp) it is used by the sprite engine (SprBmp/uSurface/Sprframe) and was first
  mentioned before fShow in the PACKAGEINFO unit list; none of the names there without
  code (MMSystem, DsgnIntf, Registry, Masks, Sprfrmed, Seldir, ExtLbox, Sprsqlst,
  Sprseqed, ExtStrGr, uMessage, SprCtrl, OLE2, uDebug, ...) can be tied to it with
  confidence, so the placeholder name is kept. }

{$I zm.inc}

interface

const
  WavFiles: array[0..7] of string = (       { 00488D20 }
    'ambul.WAV', 'dduck.WAV', 'dicerll.WAV', 'dkbell.WAV',
    'frogs.WAV', 'gbell.WAV', 'houst.WAV', 'wdcat.WAV');

implementation

end.

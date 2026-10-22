"""Leid de compilerschakelaars en de compilerbuild van ROS.exe af uit statisch bewijs.

Zonder Delphi 5-compiler kunnen we geen probe-units bouwen. Elke schakelaar laat echter sporen na
in de gegenereerde code; dit hulpmiddel telt die sporen in de projectcode (de units vanaf `uString`)
en vergelijkt de bibliotheekcode met de IDR-kennisbank:

  $R  aanroepen van @BoundErr; @ROUND/@TRUNC met en zonder Int64->Integer-controle
  $Q  aanwezigheid van @IntOver en jo/jno/into-instructies
  $I  @_IOTest na elke aanroep van een I/O-helper uit System
  $W  routines zonder `push ebp; mov ebp,esp`
  $O  registervariabelen, verborgen aflopende lustellers, parameters die naar de stack gaan
  $B  setcc-paren die met and/or gecombineerd worden (volledige evaluatie)
  $U  fdiv-instructies tegenover @FSafeDivide
  $H  @LStr*- tegenover @PStr*-aanroepen, RTTI-soort van gepubliceerde string-properties
  $Z  OrdType in de RTTI van opsommingstypen uit de projectunits
  $M  klassen met RTTI die niet van TPersistent afstammen
  $A  uitlijningsgaten in de record- en klassedeclaraties van src/game (offsetcommentaren),
      bevestigd met geheugentoegangen in de code
  $X  functieresultaten die worden weggegooid
  $J  schrijfacties van projectcode naar het DATA-gedeelte (getypeerde constanten of
      geïnitialiseerde variabelen)
  build  PE-kop, DVCLAL-resource en afwijkingen tussen de gelinkte RTL/VCL en kb5.bin

Gebruik: python tools/schakelaars.py [ROS.exe [kb5.bin [ros.tsv [units.json]]]] [--zonder-kb]
  standaard: orig/game-1.1/ROS.exe orig/kb/kb5.bin symbols/ros-1.1.tsv symbols/units-1.1.json
"""
import collections
import difflib
import glob
import json
import os
import re
import struct
import sys

import capstone
from capstone import x86

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import delphi    # noqa: E402
import idrkb     # noqa: E402
import kbmatch   # noqa: E402
import units as units_mod   # noqa: E402

STANDAARD = ['orig/game-1.1/ROS.exe', 'orig/kb/kb5.bin', 'symbols/ros-1.1.tsv', 'symbols/units-1.1.json']
BRON = 'src/game'

# I/O-helpers uit System waarna de compiler bij {$I+} `call @_IOTest` zet. @Assign hoort er niet bij.
IO_HELPERS = {
    '@ResetText', '@RewritText', '@ResetFile', '@RewritFile', '@Append', '@Close', '@_Flush', '@Flush',
    '@ReadLn', '@ReadString', '@ReadLString', '@ReadCString', '@ReadChar', '@ReadLong', '@ReadExt',
    '@EofText', '@Eof', '@SeekEof', '@SeekEoln', '@Eoln',
    '@WriteLn', '@Write0String', '@WriteString', '@Write0LString', '@WriteLString', '@WriteCString',
    '@Write0CString', '@Write0Long', '@WriteLong', '@Write0Char', '@WriteChar', '@Write0Ext',
    '@Write1Ext', '@Write2Ext', '@WriteBytes', '@WriteSpaces',
    '@BlockRead', '@BlockWrite', '@Seek', '@FileSize', '@FilePos', '@Erase', '@Rename', '@Truncate',
    '@ChDir', '@MkDir', '@RmDir',
}
EXCEPTIE_DOOR = {'@HandleFinally', '@HandleAnyException', '@HandleAutoException'}
CC_REGS = {'eax', 'edx', 'ecx'}
BEWAARDE_REGS = {'ebx', 'esi', 'edi'}
# Resultaattypen die in EAX/AL terugkomen (voor $X): alleen deze tellen we.
ORDINALE_RESULTATEN = {'System.Integer', 'System.Longint', 'System.Boolean', 'System.Cardinal',
                       'System.Pointer', 'System.Word', 'System.Byte', 'System.LongWord',
                       'System.LongBool', 'System.SmallInt', 'Windows.BOOL', 'Windows.HWND',
                       'Windows.THandle', 'Windows.HDC', 'Windows.DWORD', 'Windows.UINT'}

TK_NAMEN = {1: 'tkInteger', 3: 'tkEnumeration', 5: 'tkString', 6: 'tkSet', 7: 'tkClass',
            8: 'tkMethod', 10: 'tkLString', 11: 'tkWString'}
ORD_NAMEN = {0: 'otSByte', 1: 'otUByte', 2: 'otSWord', 3: 'otUWord', 4: 'otSLong', 5: 'otULong'}

# Bekende DVCLAL-waarden van Delphi 4-7 (identificeren de editie).
DVCLAL = {
    '23785d23b6a5f31943f3400226d111c7': 'Standard',
    'a28cdf987b3c3a7926713f090f2a2517': 'Professional',
    '263d4f38c28237b8f3244203179b3a83': 'Enterprise (Client/Server)',
}


def kop(titel):
    print()
    print('== %s ==' % titel)


# ---------------------------------------------------------------------------------- invoer

def lees_symbolen(pad):
    syms = {}
    for regel in open(pad, encoding='latin1'):
        a, soort, unit, naam = regel.rstrip('\n').split('\t')
        syms[int(a, 16)] = (soort, unit, naam)
    return syms


def unitnaam(u):
    return u['name'] or 'Unit%s' % u['init_order']


def projectunits(units):
    """Units van het project: niet-bibliotheek, vanaf de eerste benoemde projectunit."""
    eerste = min(u['start'] for u in units if not u.get('library') and u['name'])
    return [u for u in sorted(units, key=lambda u: u['start'])
            if not u.get('library') and u['start'] >= eerste]


# ------------------------------------------------------------------------- disassemblage

class Routine:
    def __init__(self, start, naam, unit):
        self.start = start
        self.naam = naam
        self.unit = unit
        self.ins = []          # capstone-instructies in adresvolgorde

    def __repr__(self):
        return '%s @%08X' % (self.naam, self.start)


class Ontleder:
    """Recursieve disassemblage van de routines in de projectunits.

    Ingangen zijn de functies uit de symbooltabel. We volgen sprongen binnen de unit, case-
    sprongtabellen, de handlers van try/except/finally (`push offset handler` bij het opzetten
    van het exceptieframe, de terugkeerlabels van finally-blokken, de tabel na
    @HandleOnException) en de code die direct volgt op `jmp @HandleFinally/@HandleAnyException`.
    """

    def __init__(self, im, syms, units):
        self.im = im
        self.md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
        self.md.detail = True
        self.syms = syms
        self.namen = {a: s[2] for a, s in syms.items() if s[0] == 'f'}
        self.adres = {}
        for a, n in sorted(self.namen.items()):
            self.adres.setdefault(n, a)
        self.units = units
        self.routines = []
        for u in units:
            starts = sorted(a for a, s in syms.items()
                            if s[0] == 'f' and u['start'] <= a < u['end'])
            for a in starts:
                r = Routine(a, self.namen[a], unitnaam(u))
                r.ins = self._ontleed(a, u['start'], u['end'])
                self.routines.append(r)

    def _een(self, a):
        return next(self.md.disasm(bytes(self.im.bytes(a, 16)), a, 1), None)

    def _ontleed(self, start, lo, hi):
        gezien = {}
        todo = [start]
        while todo:
            a = todo.pop()
            vorige = None
            while lo <= a < hi and a not in gezien:
                if a != start and a in self.namen:
                    break                       # we lopen een andere routine in
                ins = self._een(a)
                if ins is None:
                    break
                gezien[a] = ins
                volgende = a + ins.size
                m = ins.mnemonic
                op = ins.operands[0] if ins.operands else None
                if m in ('ret', 'retn', 'hlt'):
                    break
                if m == 'push' and op is not None and op.type == x86.X86_OP_IMM and lo <= op.imm < hi:
                    na = self._een(volgende)
                    seh = na is not None and na.mnemonic == 'push' and 'fs:' in na.op_str
                    fin = vorige is not None and vorige.mnemonic == 'mov' and vorige.op_str.startswith('dword ptr fs:')
                    if seh or fin:
                        todo.append(op.imm)
                if m.startswith('j') or m.startswith('loop'):
                    if op is not None and op.type == x86.X86_OP_IMM:
                        doel = op.imm
                        if m == 'jmp':
                            naam = self.namen.get(doel)
                            if naam in EXCEPTIE_DOOR:
                                vorige, a = ins, volgende
                                continue
                            if naam == '@HandleOnException':
                                n = self.im.u32(volgende)
                                if n < 64:
                                    for i in range(n):
                                        todo.append(self.im.u32(volgende + 4 + 8 * i + 4))
                                break
                            if doel in self.namen and doel != start:
                                break           # staartsprong naar een andere routine
                            vorige, a = ins, doel
                            continue
                        todo.append(doel)
                    elif m == 'jmp' and op is not None and op.type == x86.X86_OP_MEM \
                            and op.mem.scale == 4 and lo <= op.mem.disp < hi:
                        p = op.mem.disp            # case-sprongtabel direct na de sprong
                        doelen = []
                        while p < hi and len(doelen) < 1024:
                            t = self.im.u32(p)
                            if not (lo <= t < hi) or (doelen and p >= min(doelen)):
                                break
                            doelen.append(t)
                            p += 4
                        todo.extend(doelen)
                        break
                    if m == 'jmp':
                        break
                vorige, a = ins, volgende
        return [gezien[k] for k in sorted(gezien)]

    def doel(self, ins):
        """Naam van het directe call/jmp-doel, of None."""
        if ins.mnemonic in ('call', 'jmp') and ins.operands and ins.operands[0].type == x86.X86_OP_IMM:
            return self.namen.get(ins.operands[0].imm)
        return None

    def per_unit(self):
        d = collections.OrderedDict()
        for r in self.routines:
            d.setdefault(r.unit, []).append(r)
        return d


# ------------------------------------------------------------------------------ analyses

def analyse_build(im, units, syms):
    kop('Compilerbuild: PE-kop en resources')
    pe = im.pe
    fh, oh = pe.FILE_HEADER, pe.OPTIONAL_HEADER
    print('linkerversie            %d.%02d' % (oh.MajorLinkerVersion, oh.MinorLinkerVersion))
    vast = ' (vaste waarde van de Borland-linker, 19-6-1992: geen builddatum)' \
        if fh.TimeDateStamp == 0x2A425E19 else ''
    print('tijdstempel             0x%08X%s' % (fh.TimeDateStamp, vast))
    print('imagebase               $%08X%s' % (oh.ImageBase, ' (standaard)' if oh.ImageBase == 0x400000 else ''))
    print('subsysteem              %d (%s)' % (oh.Subsystem, {2: 'GUI', 3: 'console'}.get(oh.Subsystem, '?')))
    print('stack commit/reserve    %d, %d  -> {$M %d,%d}%s' % (
        oh.SizeOfStackCommit, oh.SizeOfStackReserve, oh.SizeOfStackCommit, oh.SizeOfStackReserve,
        ' (standaard)' if (oh.SizeOfStackCommit, oh.SizeOfStackReserve) == (16384, 1048576) else ''))
    print('secties                 %s' % ' '.join(s.Name.rstrip(b'\0').decode() for s in pe.sections))
    versie = any(e.id == 16 for e in pe.DIRECTORY_ENTRY_RESOURCE.entries)
    print('versieresource          %s' % ('aanwezig' if versie else 'afwezig'))
    for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if t.id != 10:
            continue
        for n in t.directory.entries:
            if str(n.name) == 'DVCLAL':
                d = n.directory.entries[0].data.struct
                v = pe.get_data(d.OffsetToData, d.Size).hex()
                print('DVCLAL                  %s -> %s' % (v, DVCLAL.get(v, 'onbekend')))
            if str(n.name) == 'PACKAGEINFO':
                d = n.directory.entries[0].data.struct
                vlag, nodig = struct.unpack_from('<II', pe.get_data(d.OffsetToData, 8))
                producent = {0: 'pre-V4', 1: 'onbepaald', 2: 'C++Builder', 3: 'Delphi'}[(vlag >> 26) & 3]
                print('PACKAGEINFO-vlaggen     0x%08X (producent: %s)' % (vlag, producent))
                print('runtimepackages         %d vereist%s' % (nodig, ' (alles statisch gelinkt)' if not nodig else ''))
    data = open(im.pad, 'rb').read()
    # TD32-debuginfo staat achteraan het bestand met de signatuur FB09/FB0A.
    td32 = data[-8:-4] in (b'FB09', b'FB0A')
    print('TD32-debuginfo          %s' % ('aanwezig' if td32 else 'afwezig (niet gelinkt met -V)'))
    print('overlay na de laatste sectie: %d bytes' % (len(data) - max(s.PointerToRawData + s.SizeOfRawData for s in pe.sections)))
    lib_namen = [unitnaam(u) for u in units if u.get('library') and u['name']]
    print('gelinkte bibliotheekunits (benoemd): %d' % len(lib_namen))


def pefile_reloc_index():
    import pefile
    return pefile.DIRECTORY_ENTRY['IMAGE_DIRECTORY_ENTRY_BASERELOC']


def analyse_kb(im, kbpad, units, syms):
    kop('Compilerbuild: gelinkte RTL/VCL tegenover kb5.bin')
    kb = idrkb.KnowledgeBase(kbpad)
    gelinkt = {n.lower() for n in units_mod.package_units(im)}
    procs = [p for p in kb.procs()
             if p.dump_type == 'C' and kb.modules[p.module_id].lower() in gelinkt]
    code = bytes(im.bytes(im.code_start, im.code_end - im.code_start))
    treffers = {}
    for pos, hits in kbmatch.scan(code, kbmatch.build_index(procs)):
        treffers[im.code_start + pos] = hits
    per_module = collections.defaultdict(list)
    per_naam = collections.defaultdict(list)
    for p in procs:
        per_module[kb.modules[p.module_id].lower()].append(p)
        per_naam[p.name].append(p)

    def unit_van(va):
        for u in units:
            if u['start'] <= va < u['end']:
                return u
        return None

    def past(va, p):
        seg = bytes(im.bytes(va, len(p.dump)))
        return len(seg) == len(p.dump) and all(p.relocs[i] or seg[i] == p.dump[i] for i in range(len(p.dump)))

    def verschil(va, p):
        seg = bytes(im.bytes(va, len(p.dump)))
        return [i for i in range(len(p.dump)) if not p.relocs[i] and seg[i] != p.dump[i]]

    tellers = collections.Counter()
    afwijkend = []          # (va, unit, naam, kbproc, verschillen)
    onbekend = []
    gedekt = collections.defaultdict(set)
    for va, (soort, unit, naam) in sorted(syms.items()):
        u = unit_van(va)
        if soort != 'f' or not u or not u.get('library'):
            continue
        tellers['routines'] += 1
        if va in treffers:
            tellers['exact (scan)'] += 1
            continue
        mod = (u['name'] or '').lower()
        if any(past(va, p) for p in per_module.get(mod, ())):
            tellers['exact (kort of onuitgelijnd)'] += 1
            continue
        sleutel = naam.split('.', 1)[1] if naam.split('.')[0].islower() and '.' in naam else naam
        kand = per_naam.get(sleutel, [])
        if kand:
            beste = min(kand, key=lambda p: len(verschil(va, p)))
            afwijkend.append((va, unitnaam(u), naam, beste, verschil(va, beste)))
            tellers['zelfde naam, andere bytes'] += 1
        else:
            onbekend.append((va, unitnaam(u), naam))
            tellers['niet in de KB'] += 1
    for k in ('routines', 'exact (scan)', 'exact (kort of onuitgelijnd)', 'zelfde naam, andere bytes',
              'niet in de KB'):
        print('  %-32s %5d' % (k, tellers[k]))
    eerlijk = tellers['exact (scan)'] + tellers['exact (kort of onuitgelijnd)']
    print('  byte-identiek met de KB: %.1f%% van de benoemde bibliotheekroutines'
          % (100.0 * eerlijk / max(1, tellers['routines'])))
    for va, unit, naam in onbekend:
        print('    niet in de KB: %08X %s %s' % (va, unit, naam))

    # Routines die de symbooltabel niet kent omdat ze niet matchten: zoek bijna-overeenkomsten
    # aan het begin van elk ongedekt gat in een bibliotheekunit.
    for va, hits in treffers.items():
        for p in hits:
            gedekt[va].add(len(p.dump))
    bijna = []
    for u in units:
        if not u.get('library'):
            continue
        dek = bytearray(u['end'] - u['start'])
        for va, lens in gedekt.items():
            if u['start'] <= va < u['end']:
                for i in range(va - u['start'], min(len(dek), va - u['start'] + max(lens))):
                    dek[i] = 1
        i = 0
        mod = (u['name'] or '').lower()
        kandidaten = [p for p in per_module.get(mod, ()) if len(p.dump) >= 32 and not p.name.startswith('_')]
        while i < len(dek):
            if dek[i]:
                i += 1
                continue
            j = i
            while j < len(dek) and not dek[j]:
                j += 1
            if j - i >= 32:
                beste = None
                for off in range(0, min(j - i, 64), 4):
                    va = (u['start'] + i + off + 3) & ~3
                    for p in kandidaten:
                        if len(p.dump) > j - i + 16:
                            continue
                        seg = bytes(im.bytes(va, len(p.dump)))
                        gelijk = sum(1 for k in range(len(p.dump)) if p.relocs[k] or seg[k] == p.dump[k])
                        score = gelijk / len(p.dump)
                        if 0.8 <= score < 1.0 and (beste is None or score > beste[0]):
                            beste = (score, va, p)
                if beste:
                    bijna.append((beste[1], unitnaam(u), beste[2].name, beste[2], verschil(beste[1], beste[2])))
            i = j
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)

    def tekst(code, relocs):
        """Instructieteksten; instructies die een KB-relocatie raken krijgen 'ADR' i.p.v. getallen."""
        uit = []
        for ins in md.disasm(code, 0):
            t = '%s %s' % (ins.mnemonic, ins.op_str)
            if any(relocs[k] for k in range(ins.address, min(len(relocs), ins.address + ins.size))) \
                    or ins.mnemonic == 'call' or (ins.mnemonic.startswith('j') and ins.op_str.startswith('0x')):
                # alleen mnemonic en registers: adressen en verplaatsingen zijn niet vergelijkbaar
                t = '%s %s ADR' % (ins.mnemonic, ','.join(re.findall(
                    r'\b(?:e?[abcd]x|e?[sd]i|e?[sb]p|[abcd][lh]|byte|word|dword|qword)\b', ins.op_str)))
            uit.append(t)
        return uit

    # Bytes in het exe die door een basisrelocatie worden aangepast (absolute adressen).
    reloc_bytes = set()
    im.pe.parse_data_directories(directories=[pefile_reloc_index()])
    for blok in getattr(im.pe, 'DIRECTORY_ENTRY_BASERELOC', []):
        for e in blok.entries:
            if e.type == 3:
                for k in range(4):
                    reloc_bytes.add(im.base + e.rva + k)
    gevallen = {}
    for a in [a for a in afwijkend if a[4]] + bijna:
        gevallen.setdefault(a[0], a)
    echte = 0
    for va, unit, naam, p, versch in sorted(gevallen.values()):
        ref = tekst(bytes(p.dump), p.relocs)
        exe_relocs = bytes(1 if va + k in reloc_bytes else 0 for k in range(len(p.dump) + 64))
        exe = tekst(bytes(im.bytes(va, len(p.dump) + 64)), exe_relocs)[:len(ref) + 4]
        regels = [r for r in difflib.unified_diff(ref, exe, n=0, lineterm='')
                  if r[:1] in '+-' and not r.startswith(('---', '+++'))]
        # Na het einde van de KB-routine vergelijken we niet verder.
        while regels and regels[-1].startswith('+'):
            regels.pop()
        if not [r for r in regels if r.startswith('-')]:
            continue        # alleen relocaties anders
        echte += 1
        print()
        print('  %08X %s %s (KB-module %s, %d bytes, %d bytes anders buiten relocaties)'
              % (va, unit, naam, kb.modules[p.module_id], len(p.dump), len(versch)))
        for r in regels[:28]:
            print('      ' + r)
        if len(regels) > 28:
            print('      ...')
    print()
    print('  routines met een echte codeafwijking t.o.v. kb5.bin: %d' % echte)


def analyse_bereik(ont, per_unit, syms, im):
    kop('$R bereikcontrole en $Q overloopcontrole')
    alle_namen = {s[2] for s in syms.values() if s[0] == 'f'}
    print('@BoundErr gelinkt: %s   @IntOver gelinkt: %s' % ('@BoundErr' in alle_namen, '@IntOver' in alle_namen))
    # @IntOver zou `mov al,5; jmp Error` zijn; zoek dat patroon in heel CODE.
    error = ont.adres.get('system.Error')
    code = bytes(im.bytes(im.code_start, im.code_end - im.code_start))
    stubs = []
    for m in re.finditer(b'\xb0\x05\xe9', code):
        va = im.code_start + m.start()
        if va % 4 == 0 and error and va + 7 + struct.unpack_from('<i', code, m.start() + 3)[0] == error:
            stubs.append(va)
    print('`mov al,5; jmp system.Error` (@IntOver) in CODE: %d keer' % len(stubs))
    # BoundErr-aanroepers in heel CODE (bibliotheek ter vergelijking)
    be = ont.adres.get('@BoundErr')
    bib = 0
    if be:
        for m in re.finditer(b'\xe8', code):
            va = im.code_start + m.start()
            if va + 5 + struct.unpack_from('<i', code, m.start() + 1)[0] == be and va < ont.units[0]['start']:
                bib += 1
    print('call @BoundErr in bibliotheekcode (bytescan): %d' % bib)
    print()
    print('%-14s %8s %8s %8s %10s %10s %8s  %s' % ('unit', 'routines', 'BoundErr', 'jo/jno', 'Round/Trunc', 'gecontr.', 'ongecontr.', 'oordeel'))
    oordelen = {}
    details = []
    for unit, rs in per_unit.items():
        n_be = n_of = n_rt = n_chk = 0
        r_chk, r_unchk = [], []
        for r in rs:
            ins = r.ins
            for k, i in enumerate(ins):
                d = ont.doel(i)
                if i.mnemonic in ('jo', 'jno', 'into'):
                    n_of += 1
                if d == '@BoundErr' and i.mnemonic == 'call':
                    n_be += 1
                if d in ('@ROUND', '@TRUNC') and i.mnemonic == 'call':
                    n_rt += 1
                    gecontroleerd = False
                    sar = False
                    for j in ins[k + 1:k + 16]:
                        if j.mnemonic == 'sar' and j.op_str == 'eax, 0x1f':
                            sar = True
                        dj = ont.doel(j)
                        if j.mnemonic == 'call':
                            gecontroleerd = sar and dj == '@BoundErr'
                            break
                        if j.mnemonic in ('ret', 'jmp'):
                            break
                    if gecontroleerd:
                        n_chk += 1
                        r_chk.append(r)
                    else:
                        r_unchk.append(r)
        if n_be or n_chk:
            oordeel = '$R+' if not r_unchk else 'gemengd'
        else:
            oordeel = '$R-' if n_rt else '(geen bewijs)'
        oordelen[unit] = oordeel
        print('%-14s %8d %8d %8d %10d %10d %8d  %s' % (unit, len(rs), n_be, n_of, n_rt, n_chk, n_rt - n_chk, oordeel))
        if oordeel == 'gemengd':
            details.append((unit, sorted(set(r_chk), key=lambda r: r.start), sorted(set(r_unchk), key=lambda r: r.start)))
    for unit, chk, unchk in details:
        print('  %s: gecontroleerd in %s; ongecontroleerd in %s' % (
            unit, ', '.join(r.naam for r in chk), ', '.join(r.naam for r in unchk)))
    # Soorten @BoundErr-controles
    soort = collections.Counter()
    voorbeelden = {}
    for r in ont.routines:
        for k, i in enumerate(r.ins):
            if i.mnemonic == 'call' and ont.doel(i) == '@BoundErr':
                ctx = r.ins[max(0, k - 6):k]
                s = 'Int64->Integer (na Round/Trunc of Int64-rekenwerk)' \
                    if any(j.mnemonic == 'sar' and j.op_str == 'eax, 0x1f' for j in ctx) \
                    else 'index/subbereik (cmp + voorwaardelijke sprong)'
                soort[(r.unit, s)] += 1
                voorbeelden.setdefault(s, (r, ctx + [i]))
    print()
    for (unit, s), n in sorted(soort.items()):
        print('  %-12s %3d x %s' % (unit, n, s))
    for s, (r, ctx) in voorbeelden.items():
        print('  voorbeeld %s in %s:' % (s.split(' ')[0], r.naam))
        for j in ctx:
            print('      %08X  %s %s' % (j.address, j.mnemonic, j.op_str))
    # Geïndexeerde geheugentoegangen [basis + index*schaal]: bij {$R+} gaat er (voor statische en
    # open arrays) een vergelijking met `call @BoundErr` aan vooraf.
    print()
    print('geïndexeerde toegangen [basis + index*schaal] (geen lea, geen case-tabellen):')
    print('%-14s %8s %14s %14s' % ('unit', 'totaal', 'na @BoundErr', 'zonder controle'))
    for unit, rs in per_unit.items():
        tot = chk = 0
        for r in rs:
            for k, i in enumerate(r.ins):
                if i.mnemonic in ('lea', 'jmp', 'call'):
                    continue
                if not any(o.type == x86.X86_OP_MEM and o.mem.index != 0 for o in i.operands):
                    continue
                tot += 1
                if any(j.mnemonic == 'call' and ont.doel(j) == '@BoundErr' for j in r.ins[max(0, k - 8):k]):
                    chk += 1
        if tot:
            print('%-14s %8d %14d %14d' % (unit, tot, chk, tot - chk))
    rplus = [u for u, o in oordelen.items() if o == '$R+']
    print('units met $R+: %s' % (', '.join(rplus) or '-'))
    return oordelen


def analyse_io(ont, per_unit):
    kop('$I I/O-controle')
    print('%-14s %8s %10s %12s %10s' % ('unit', 'I/O-calls', 'met IOTest', 'zonder', 'IOResult'))
    tot_met = tot_zonder = 0
    voorbeeld = None
    for unit, rs in per_unit.items():
        n_io = met = zonder = ior = 0
        for r in rs:
            ins = r.ins
            for k, i in enumerate(ins):
                if i.mnemonic != 'call':
                    continue
                d = ont.doel(i)
                if d == 'system.IOResult':
                    ior += 1
                if d not in IO_HELPERS:
                    continue
                n_io += 1
                getest = False
                for j in ins[k + 1:k + 24]:
                    if j.mnemonic == 'call':
                        dj = ont.doel(j)
                        if dj == '@_IOTest':
                            getest = True
                            break
                        if dj in IO_HELPERS or dj == '@Assign':
                            continue
                        break
                    if j.mnemonic in ('ret', 'jmp'):
                        break
                if getest:
                    met += 1
                    if voorbeeld is None:
                        voorbeeld = (r, ins[k:k + 3])
                else:
                    zonder += 1
        if n_io or ior:
            print('%-14s %8d %10d %12d %10d' % (unit, n_io, met, zonder, ior))
        tot_met += met
        tot_zonder += zonder
    print('totaal: %d I/O-aanroepen gevolgd door @_IOTest, %d zonder' % (tot_met, tot_zonder))
    if voorbeeld:
        r, ctx = voorbeeld
        print('voorbeeld in %s:' % r.naam)
        for j in ctx:
            print('      %08X  %s %s%s' % (j.address, j.mnemonic, j.op_str,
                                         '   ; ' + (ont.doel(j) or '') if ont.doel(j) else ''))
    return tot_met, tot_zonder


def heeft_frame(r):
    return len(r.ins) >= 2 and r.ins[0].mnemonic == 'push' and r.ins[0].op_str == 'ebp' \
        and r.ins[1].mnemonic == 'mov' and r.ins[1].op_str == 'ebp, esp'


def analyse_frames(ont, per_unit):
    kop('$W stackframes')
    print('%-14s %8s %10s %12s %14s' % ('unit', 'routines', 'met frame', 'zonder frame', 'zonder, met call'))
    tot = collections.Counter()
    blad = []
    for unit, rs in per_unit.items():
        c = collections.Counter()
        for r in rs:
            if not r.ins:
                continue
            c['n'] += 1
            if heeft_frame(r):
                c['frame'] += 1
            else:
                c['geen'] += 1
                if any(i.mnemonic == 'call' for i in r.ins):
                    c['geen+call'] += 1
                elif len(blad) < 6:
                    blad.append(r)
        tot.update(c)
        print('%-14s %8d %10d %12d %14d' % (unit, c['n'], c['frame'], c['geen'], c['geen+call']))
    print('totaal: %d routines, %d met frame, %d zonder (waarvan %d met aanroepen)'
          % (tot['n'], tot['frame'], tot['geen'], tot['geen+call']))
    print('voorbeelden van bladroutines zonder frame:')
    for r in blad:
        print('  %s:  %s' % (r.naam, '; '.join('%s %s' % (i.mnemonic, i.op_str) for i in r.ins[:6])))
    return tot


def analyse_optimalisatie(ont, per_unit):
    kop('$O optimalisatie')
    c = collections.Counter()
    met_regvar = collections.Counter()
    zonder_regvar = collections.Counter()
    voorbeeld_lus = None
    for r in ont.routines:
        ins = r.ins
        if not ins:
            continue
        c['routines'] += 1
        # proloog: bewaarde registers en de eerste kopie van een registerparameter
        k = 0
        if heeft_frame(r):
            k = 2
        bewaard = set()
        while k < len(ins) and ins[k].mnemonic in ('push', 'add', 'sub') and \
                (ins[k].mnemonic != 'push' or ins[k].op_str in BEWAARDE_REGS | {'ecx', 'ebp', '0'}):
            if ins[k].mnemonic == 'push' and ins[k].op_str in BEWAARDE_REGS:
                bewaard.add(ins[k].op_str)
            if ins[k].mnemonic in ('add', 'sub') and not ins[k].op_str.startswith('esp'):
                break
            k += 1
        if bewaard:
            c['routines die ebx/esi/edi bewaren'] += 1
            met_regvar[r.unit] += 1
        elif len(ins) >= 12:
            zonder_regvar[r.unit] += 1
        for i in ins[k:k + 4]:
            if i.mnemonic != 'mov' or len(i.operands) != 2:
                continue
            dst, src = i.op_str.split(', ', 1)
            if src in CC_REGS:
                if dst in BEWAARDE_REGS:
                    c['parameter naar register (mov ebx/esi/edi, eax/edx/ecx)'] += 1
                elif dst.startswith('dword ptr [ebp -'):
                    c['parameter naar stack (mov [ebp-x], eax/edx/ecx)'] += 1
                break
        # lussen
        for k, i in enumerate(ins[:-1]):
            j = ins[k + 1]
            if j.mnemonic == 'jne' and j.operands[0].type == x86.X86_OP_IMM and j.operands[0].imm < i.address:
                if i.mnemonic == 'dec' and i.op_str in BEWAARDE_REGS | CC_REGS | {'ebp'}:
                    c['lus met verborgen aflopende teller in register (dec reg; jne terug)'] += 1
                    if voorbeeld_lus is None:
                        terug = [x for x in ins if j.operands[0].imm <= x.address <= j.address]
                        voorbeeld_lus = (r, terug)
                elif i.mnemonic == 'dec' and i.op_str.startswith('dword ptr [ebp'):
                    c['lus met verborgen aflopende teller op de stack (dec [ebp-x]; jne terug)'] += 1
            if i.mnemonic == 'inc' and i.op_str.startswith('dword ptr [ebp') and \
                    j.mnemonic == 'cmp' and j.op_str.startswith(i.op_str):
                c['lusteller op de stack (inc [ebp-x]; cmp [ebp-x], ...)'] += 1
    for k, v in c.items():
        print('  %-72s %5d' % (k, v))
    # Bij {$O-} gebruikt Delphi 5 geen registervariabelen: een unit met niet-triviale routines
    # maar zonder enige bewaard register zou op {$O-} wijzen.
    verdacht = [u for u in per_unit if zonder_regvar[u] >= 3 and not met_regvar[u]]
    print('  units met >=3 routines van >=12 instructies en geen enkele registervariabele: %s'
          % (', '.join(verdacht) or 'geen'))
    if voorbeeld_lus:
        r, lus = voorbeeld_lus
        print('voorbeeld (%s):' % r.naam)
        for j in lus[-12:]:
            print('      %08X  %s %s' % (j.address, j.mnemonic, j.op_str))
    return c


def analyse_boolean(ont):
    kop('$B booleaanse evaluatie')
    setcc = combinaties = condsprong = 0
    for r in ont.routines:
        ins = r.ins
        for k, i in enumerate(ins):
            if i.mnemonic.startswith('set'):
                setcc += 1
                venster = ins[k + 1:k + 6]
                if any(j.mnemonic.startswith('set') for j in venster) and \
                        any(j.mnemonic in ('and', 'or') and j.op_str.count(', ') == 1 and
                            all(o.type == x86.X86_OP_REG for o in j.operands) and
                            j.operands[0].size == 1 for j in venster):
                    combinaties += 1
            if i.mnemonic.startswith('j') and i.mnemonic != 'jmp':
                condsprong += 1
    print('  setcc-instructies: %d; setcc-paren gecombineerd met and/or (volledige evaluatie): %d'
          % (setcc, combinaties))
    print('  voorwaardelijke sprongen: %d' % condsprong)
    return combinaties


def analyse_fdiv(ont, syms):
    kop('$U Pentium-veilige FDIV')
    n = sum(1 for r in ont.routines for i in r.ins if i.mnemonic in ('fdiv', 'fdivr', 'fdivp', 'fdivrp', 'fidiv', 'fidivr'))
    safe = sorted(s[2] for s in syms.values() if s[0] == 'f' and 'SafeDiv' in s[2])
    print('  fdiv-instructies in projectcode: %d; @FSafeDivide-helpers gelinkt: %s' % (n, ', '.join(safe) or 'geen'))
    return n, safe


def analyse_strings(ont, im, vmts, units):
    kop('$H lange strings')
    c = collections.Counter()
    for r in ont.routines:
        for i in r.ins:
            d = ont.doel(i)
            if d and d.startswith('@LStr'):
                c['@LStr*'] += 1
            elif d and d.startswith('@PStr'):
                c['@PStr*'] += 1
            elif d and d.startswith('@WStr'):
                c['@WStr*'] += 1
    print('  aanroepen in projectcode: %s' % ', '.join('%s %d' % kv for kv in sorted(c.items())))
    props = list(projectprops(im, vmts, units))
    soorten = collections.Counter((tn, TK_NAMEN.get(k, k)) for _, _, tn, k, _ in props if tn in ('String', 'string', 'TName', 'ShortString'))
    for (tn, k), n in sorted(soorten.items()):
        print('  gepubliceerde properties van type %s: %d x %s' % (tn, n, k))
    return c


def projectprops(im, vmts, units):
    """Yield (klasse, prop, typenaam, soort, ordtype) voor gepubliceerde properties van projectklassen."""
    lo = units[0]['start']
    for a, v in sorted(vmts.items()):
        if a < lo or not v.type_info or im.u8(v.type_info) != 7:
            continue
        ti = v.type_info
        p = ti + 2 + im.u8(ti + 1) + 8 + 2
        p += 1 + im.u8(p)
        n = im.u16(p)
        p += 2
        for _ in range(n):
            pt = im.u32(im.u32(p))
            soort = im.u8(pt)
            tn = im.sstr(pt + 1)
            ordt = im.u8(pt + 2 + len(tn)) if soort in (1, 3, 6) else None
            yield v.name, im.sstr(p + 26), tn, soort, (ordt, pt)
            p += 27 + im.u8(p + 26)


def analyse_enum(im, vmts, units):
    kop('$Z grootte van opsommingstypen')
    def in_project(va):
        return any(u['start'] <= va < u['end'] for u in units)
    gezien = {}
    for _, _, tn, soort, (ordt, pt) in projectprops(im, vmts, units):
        if soort == 3 and tn != 'Boolean':
            gezien[pt] = (tn, ordt, im.i32(pt + 3 + len(tn)), im.i32(pt + 7 + len(tn)))
        if soort == 6:
            # verzameling: CompType volgt op OrdType
            comp = im.u32(im.u32(pt + 3 + len(tn)))
            ctn = im.sstr(comp + 1)
            if im.u8(comp) == 3:
                gezien[comp] = (ctn, im.u8(comp + 2 + len(ctn)), im.i32(comp + 3 + len(ctn)), im.i32(comp + 7 + len(ctn)))
    for pt, (tn, ordt, mn, mx) in sorted(gezien.items()):
        waar = 'projectunit' if in_project(pt) else 'bibliotheek'
        print('  %08X %-20s %s  bereik %d..%d  (%s)' % (pt, tn, ORD_NAMEN.get(ordt, ordt), mn, mx, waar))
    proj = [(tn, ordt) for pt, (tn, ordt, _, _) in gezien.items() if in_project(pt)]
    return proj


def analyse_rtti(im, vmts, units):
    kop('$M runtime-type-informatie')
    per_adres = vmts
    lo = units[0]['start']

    def stamt_af(v, naam):
        while v is not None:
            if v.name == naam:
                return True
            v = per_adres.get(v.parent)
        return False

    met = zonder = 0
    vreemd = []
    for a, v in sorted(vmts.items()):
        if a < lo:
            continue
        if v.type_info:
            met += 1
            if not stamt_af(v, 'TPersistent'):
                vreemd.append(v.name)
        else:
            zonder += 1
    print('  projectklassen met RTTI: %d (allemaal TPersistent-afstammelingen: %s); zonder RTTI: %d'
          % (met, 'ja' if not vreemd else 'nee', zonder))
    if vreemd:
        print('  RTTI zonder TPersistent-voorouder ($M+ in de bron): %s' % ', '.join(vreemd))
    return vreemd


# ---- broncode: record- en klasselay-outs (offsetcommentaren) voor $A en $Z

GROOTTE = {
    'byte': (1, 1), 'boolean': (1, 1), 'char': (1, 1), 'ansichar': (1, 1), 'shortint': (1, 1),
    'bytebool': (1, 1), 'smallint': (2, 2), 'word': (2, 2), 'wordbool': (2, 2), 'widechar': (2, 2),
    'integer': (4, 4), 'longint': (4, 4), 'cardinal': (4, 4), 'longword': (4, 4), 'dword': (4, 4),
    'pointer': (4, 4), 'string': (4, 4), 'ansistring': (4, 4), 'pchar': (4, 4), 'single': (4, 4),
    'longbool': (4, 4), 'tcolor': (4, 4), 'thandle': (4, 4), 'hwnd': (4, 4), 'tobject': (4, 4),
    'double': (8, 8), 'int64': (8, 8), 'comp': (8, 8), 'currency': (8, 8),
    'tnotifyevent': (8, 4), 'tpoint': (8, 4), 'trect': (16, 4),
}


def bronlay_outs(klassenamen):
    """Yield (bestand, typenaam, [(offset, veld, type)]) voor declaraties met offsetcommentaren."""
    begin = re.compile(r'^\s*(T\w+)\s*=\s*(packed\s+)?(record|class)\b', re.I)
    veld = re.compile(r'^\s*([A-Za-z_]\w*)\s*:\s*([^;{]+?)\s*;\s*\{\s*\+0x([0-9A-Fa-f]+)')
    for pad in sorted(glob.glob(os.path.join(BRON, '*.pas'))):
        naam = None
        velden = []
        for regel in open(pad, encoding='latin1'):
            m = begin.match(regel)
            if m and not regel.rstrip().endswith(';'):
                if naam and velden:
                    yield pad, naam, velden
                naam, velden = m.group(1), []
                continue
            if naam is None:
                continue
            if re.match(r'^\s*end\s*;', regel, re.I):
                if velden:
                    yield pad, naam, velden
                naam, velden = None, []
                continue
            m = veld.match(regel)
            if m:
                velden.append((int(m.group(3), 16), m.group(1), m.group(2).strip()))


def bronenums():
    enums = set()
    for pad in glob.glob(os.path.join(BRON, '*.pas')):
        for m in re.finditer(r'^\s*(T\w+)\s*=\s*\(\s*\w+\s*[,)]', open(pad, encoding='latin1').read(), re.M):
            enums.add(m.group(1).lower())
    return enums


def type_grootte(t, klassen, enums):
    t = t.lower()
    if t in GROOTTE:
        return GROOTTE[t]
    if t in klassen or (t.startswith('t') and t.endswith('list')):
        return (4, 4)
    if t.endswith('event') or t.startswith('ton'):
        return (8, 4)
    m = re.match(r'array\s*\[\s*(\d+)\s*\.\.\s*(\d+)\s*\]\s*of\s+(\w+)$', t)
    if m:
        el = type_grootte(m.group(3), klassen, enums)
        if el:
            return ((int(m.group(2)) - int(m.group(1)) + 1) * el[0], el[1])
    return None


def geheugentoegangen(ont):
    """{(displacement, grootte): aantal} over alle projectcode, voor toegangen [reg + disp]."""
    d = collections.Counter()
    for r in ont.routines:
        for i in r.ins:
            for o in i.operands:
                if o.type == x86.X86_OP_MEM and o.mem.base not in (0, x86.X86_REG_EBP, x86.X86_REG_ESP) \
                        and o.mem.index == 0:
                    d[(o.mem.disp, o.size)] += 1
    return d


def analyse_uitlijning(ont, vmts):
    kop('$A uitlijning van record- en klassevelden')
    klassen = {v.name.lower() for v in vmts.values()}
    enums = bronenums()
    toeg = geheugentoegangen(ont)
    gaten = []
    tegen = []
    acht = collections.Counter()
    for pad, naam, velden in bronlay_outs(klassen):
        velden = sorted(velden)
        for (o1, v1, t1), (o2, v2, t2) in zip(velden, velden[1:]):
            g1 = type_grootte(t1, klassen, enums)
            g2 = type_grootte(t2, klassen, enums)
            if not g1 or not g2:
                continue
            eind = o1 + g1[0]
            uitgelijnd = (eind + g2[1] - 1) // g2[1] * g2[1]
            if eind == uitgelijnd:
                continue        # geen verschil tussen packed en uitgelijnd
            rec = (os.path.basename(pad), naam, v1, t1, o1, v2, t2, o2, eind, uitgelijnd,
                   sum(n for (d, _), n in toeg.items() if d == o2))
            if o2 == uitgelijnd:
                gaten.append(rec)
            elif o2 == eind:
                tegen.append(rec)
            # 8-byte-velden: uitgelijnd op 8 of maar op 4?
            vier = (eind + min(g2[1], 4) - 1) // min(g2[1], 4) * min(g2[1], 4)
            if vier != uitgelijnd:
                acht[o2 == uitgelijnd] += 1
                if o2 == vier:
                    tegen.append(rec)
    print('  veldparen waar packed en uitgelijnd verschillen: %d volgen {$A+}, %d volgen packed'
          % (len(gaten), len(tegen)))
    print('  8-byte-velden waar uitlijning op 4 en op 8 verschillen: %d op 8, %d op 4'
          % (acht[True], acht[False]))
    for (bestand, naam, v1, t1, o1, v2, t2, o2, eind, uitg, n) in gaten:
        print('    %-16s %-16s %s: %s @+0x%X -> %s: %s @+0x%X (packed: +0x%X); %d codetoegangen [reg+0x%X]'
              % (bestand, naam, v1, t1, o1, v2, t2, o2, eind, n, o2))
    for rec in tegen:
        print('    TEGENVOORBEELD %s' % (rec,))
    # $Z: velden van een opsommingstype uit de projectbron, en hoe de code ze aanspreekt
    kop('$Z velden van opsommingstypen (toegangsgrootte in de code)')
    for pad, naam, velden in bronlay_outs(klassen):
        for o, v, t in velden:
            if t.lower() in enums:
                print('  %-16s %s.%s: %s @+0x%X  byte-toegangen %d, word %d, dword %d'
                      % (os.path.basename(pad), naam, v, t, o, toeg[(o, 1)], toeg[(o, 2)], toeg[(o, 4)]))
    return gaten, tegen


def analyse_extended(ont, kbpad, im):
    """$X: aanroepen van bibliotheekfuncties waarvan het resultaat direct wordt overschreven."""
    kop('$X uitgebreide syntaxis (functieresultaat genegeerd)')
    if kbpad is None:
        print('  (overgeslagen zonder kennisbank)')
        return 0
    kb = idrkb.KnowledgeBase(kbpad)
    # functienamen met een ordinaal resultaat
    functies = {}
    soorten = collections.defaultdict(set)
    for p in kb.procs():
        soorten[(kb.modules[p.module_id].lower(), p.name)].add(
            p.typedef if p.method_kind == 'F' and p.typedef in ORDINALE_RESULTATEN else None)
    for sleutel, typen in soorten.items():
        if len(typen) == 1 and None not in typen:
            functies[sleutel] = typen.pop()     # alleen eenduidig: geen overloads met ander resultaat
    n = 0
    voorbeelden = []
    for r in ont.routines:
        for k, i in enumerate(r.ins[:-1]):
            d = ont.doel(i)
            if i.mnemonic != 'call' or not d:
                continue
            mod = ont.syms[i.operands[0].imm][1].lower()
            sleutel = (mod, d.split('.', 1)[1] if d.split('.')[0].islower() and '.' in d else d)
            if sleutel not in functies:
                continue
            j = r.ins[k + 1]
            if j.address != i.address + i.size:
                continue
            ops = j.op_str.split(', ', 1)
            overschrijft = (j.mnemonic in ('mov', 'lea', 'movzx') and ops[0] == 'eax' and len(ops) == 2
                            and 'eax' not in ops[1] and 'al' not in ops[1].split()) \
                or (j.mnemonic == 'xor' and j.op_str == 'eax, eax') \
                or (j.mnemonic == 'pop' and j.op_str == 'eax')
            if overschrijft:
                n += 1
                if len(voorbeelden) < 5:
                    voorbeelden.append((r, i, j, d, functies[sleutel]))
    print('  aanroepen van functies (ordinaal resultaat) waarna EAX meteen wordt overschreven: %d' % n)
    for r, i, j, d, t in voorbeelden:
        print('    %s: %08X call %s (: %s); %08X %s %s' % (r.naam, i.address, d, t, j.address, j.mnemonic, j.op_str))
    return n


def analyse_overig(syms):
    kop('Overige schakelaars')
    namen = {s[2] for s in syms.values() if s[0] == 'f'}
    for helper, schakelaar in (('@Assert', '$C (asserties)'), ('@IntOver', '$Q'),
                               ('@FSafeDivide', '$U'), ('@BoundErr', '$R')):
        print('  %-14s gelinkt: %-5s  (%s)' % (helper, helper in namen, schakelaar))
    print('  $D, $L, $Y: alleen debug-/symboolinformatie in .dcu/.map, niet zichtbaar in het exe')
    print('  $T, $V, $P, $G: alleen typecontrole of packages, geen codeverschil in dit exe')


def analyse_schrijfbaar(ont, im, syms):
    kop('$J schrijfbare getypeerde constanten')
    data = im.sections['DATA']
    lo = im.base + data.VirtualAddress
    hi = lo + data.Misc_VirtualSize
    doelen = collections.Counter()
    for r in ont.routines:
        for i in r.ins:
            if not i.operands or i.mnemonic in ('cmp', 'test', 'push', 'fld', 'fild') or i.mnemonic.startswith('j'):
                continue
            o = i.operands[0]
            if o.type == x86.X86_OP_MEM and o.mem.base == 0 and o.mem.index == 0 and lo <= o.mem.disp < hi \
                    and i.mnemonic in ('mov', 'inc', 'dec', 'add', 'sub', 'and', 'or', 'xor', 'fstp', 'fst', 'movsb', 'stosd'):
                doelen[o.mem.disp] += 1
    print('  directe schrijfacties van projectcode naar DATA (geïnitialiseerde data): %d adressen' % len(doelen))
    for a, n in sorted(doelen.items()):
        s = syms.get(a)
        print('    %08X %-36s %d x' % (a, (s[1] + ' ' + s[2]) if s else '?', n))
    return doelen


# ----------------------------------------------------------------------------------- main

def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    zonder_kb = '--zonder-kb' in sys.argv
    paden = args + STANDAARD[len(args):]
    exe, kbpad, tsv, unitsjson = paden[:4]
    im = delphi.Image(exe)
    im.pad = exe
    syms = lees_symbolen(tsv)
    units = json.load(open(unitsjson))['units']
    proj = projectunits(units)
    print('Schakelaaranalyse van %s' % exe)
    print('projectunits: %d (%s .. %s), $%08X-$%08X' % (
        len(proj), unitnaam(proj[0]), unitnaam(proj[-1]), proj[0]['start'], proj[-1]['end']))
    ont = Ontleder(im, syms, proj)
    per_unit = ont.per_unit()
    print('routines ontleed: %d, instructies: %d' % (len(ont.routines), sum(len(r.ins) for r in ont.routines)))
    vmts = im.find_vmts()

    analyse_build(im, units, syms)
    if not zonder_kb:
        analyse_kb(im, kbpad, units, syms)
    analyse_bereik(ont, per_unit, syms, im)
    analyse_io(ont, per_unit)
    analyse_frames(ont, per_unit)
    analyse_optimalisatie(ont, per_unit)
    analyse_boolean(ont)
    analyse_fdiv(ont, syms)
    analyse_strings(ont, im, vmts, proj)
    analyse_enum(im, vmts, proj)
    analyse_rtti(im, vmts, proj)
    analyse_uitlijning(ont, vmts)
    analyse_extended(ont, None if zonder_kb else kbpad, im)
    analyse_schrijfbaar(ont, im, syms)
    analyse_overig(syms)


if __name__ == '__main__':
    main()

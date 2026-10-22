"""Vergelijk een herbouwd ROS.exe met het origineel: hele bestand, per PE-sectie en per routine.

Routines worden gekoppeld via de namen in de symbooltabellen van beide kanten:
  * origineel: symbols/ros-1.1.tsv (adres  soort  unit  naam)
  * herbouw:   het gedetailleerde Delphi-mapbestand (dcc32 -GD), sectie "Publics by Value",
               regels als ` 0001:00001234       Unit.Routine` (segment 0001 = CODE op het RVA van
               die sectie). Zonder --map wordt de tsv ook voor de herbouw gebruikt; dat klopt alleen
               als de herbouw dezelfde indeling heeft (handig voor gepatchte kopieën).

Een routine beslaat de bytes van haar beginadres tot de volgende routine of unitgrens in hetzelfde
bestand; stringliterals en RTTI/VMT's die de compiler na een routine neerlegt, horen er dus bij.
Beide kanten worden met capstone gedisassembleerd en genormaliseerd:
  * bytes onder een relocatie (de .reloc-tabel van elk bestand) worden vergeleken als symbolisch
    doel: "symbool + afstand", waarbij alleen symbolen meetellen die aan beide kanten bestaan
    (gekoppelde routines, gedeelde datanamen, VMT's per klassenaam);
  * relatieve sprongen en aanroepen (E8/E9/Jcc/JMP short) naar een doel buiten de routine worden
    op dezelfde manier symbolisch gemaakt;
  * doelen binnen de routine zelf tellen als afstand vanaf het begin van de routine;
  * een doel zonder gedeeld symbool wordt in DATA/BSS/.idata als sectie + afstand vergeleken en
    in CODE gemaskeerd.
Zo veroorzaakt één verschoven functie geen adresruis in alle andere.

Gebruik: python tools/diff.py ORIG.exe BUILD.exe [--map build/delphi/ROS.map]
                              [--tsv symbols/ros-1.1.tsv] [--units symbols/units-1.1.json]
                              [--alles] [-v] [--json uit.json]
  --alles   ook bibliotheekroutines (RTL/VCL) per stuk tonen (standaard alleen projectunits)
  -v        bij een verschil de instructie op die plek van beide kanten tonen
Afsluitcode: 0 als de bestanden byte-identiek zijn, anders 1.
"""
import argparse
import bisect
import collections
import hashlib
import json
import os
import re
import struct
import sys
from dataclasses import dataclass, field

import capstone
import pefile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import delphi  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
STANDAARD_TSV = os.path.join(ROOT, 'symbols', 'ros-1.1.tsv')
STANDAARD_UNITS = os.path.join(ROOT, 'symbols', 'units-1.1.json')

# Units met alleen een door de compiler gegenereerde init-/finalisatiestub zijn niet groter dan dit.
STUBGRENS = 112


# ---- symbolen ------------------------------------------------------------------------------

@dataclass
class Symbool:
    adres: int
    soort: str      # f = routine, d = data, v = VMT, s = stringliteral
    unit: str
    naam: str       # naam zonder unitvoorvoegsel
    sleutel: str    # 'unit.naam' in kleine letters; de koppelsleutel tussen tabellen

    @property
    def volledig(self):
        return '%s.%s' % (self.unit, self.naam) if self.unit else self.naam


def sleutel(unit, naam):
    """Normaliseer (unit, naam) tot een vergelijkbare sleutel; een unitvoorvoegsel in de naam vervalt."""
    if unit and naam.lower().startswith(unit.lower() + '.'):
        naam = naam[len(unit) + 1:]
    return ('%s.%s' % (unit, naam) if unit else naam).lower(), naam


def lees_tsv(pad):
    """Lees symbols/ros-1.1.tsv in als [Symbool]."""
    uit = []
    with open(pad, encoding='utf-8') as f:
        regels = f.read().splitlines()
    for regel in regels:
        delen = regel.rstrip('\n').split('\t')
        if len(delen) < 4 or not delen[0].strip():
            continue
        adres, soort, unit, naam = delen[:4]
        k, kaal = sleutel(unit, naam)
        uit.append(Symbool(int(adres, 16), soort, unit, kaal, k))
    return uit


SEGMENTREGEL = re.compile(r'^\s*([0-9A-Fa-f]{4}):([0-9A-Fa-f]{8})\s+([0-9A-Fa-f]{8})H?\s+(\S+)\s+(\S+)\s*$')
DETAILREGEL = re.compile(r'^\s*([0-9A-Fa-f]{4}):([0-9A-Fa-f]{8})\s+([0-9A-Fa-f]{8})H?\s+C=(\S+)\s.*\bM=(\S+)')
PUBLICREGEL = re.compile(r'^\s*([0-9A-Fa-f]{4}):([0-9A-Fa-f]{8})\s+(\S.*?)\s*$')
STANDAARD_SEGMENTEN = {1: 'CODE', 2: 'DATA', 3: 'BSS', 4: '.tls'}


def lees_map(pad, pe):
    """Lees een gedetailleerd Delphi-mapbestand.

    pe is een pefile.PE (of iets met .sections) om segmentnummers naar adressen om te zetten.
    Geeft (symbolen, unitbereiken) terug; unitbereiken is [(unit, start, eind)] voor CODE, uit
    "Detailed map of segments" (leeg als die sectie ontbreekt).
    """
    base = pe.OPTIONAL_HEADER.ImageBase
    secties = {s.Name.rstrip(b'\0').decode('latin1').upper(): base + s.VirtualAddress for s in pe.sections}
    segmenten = dict(STANDAARD_SEGMENTEN)
    symbolen, unitbereiken = [], []
    stand = 'kop'
    with open(pad, encoding='latin1') as f:
        regels = f.read().splitlines()
    for regel in regels:
        r = regel.rstrip('\r\n')
        if 'Detailed map of segments' in r:
            stand = 'detail'
            continue
        if 'Publics by Name' in r:
            stand = 'opnaam'
            continue
        if 'Publics by Value' in r:
            stand = 'opwaarde'
            continue
        if r.startswith(('Line numbers', 'Bound resource', 'Program entry point')) or 'Program entry point' in r:
            stand = 'einde'
            continue
        if stand == 'kop':
            m = SEGMENTREGEL.match(r)
            if m:
                segmenten[int(m.group(1), 16)] = m.group(4)
        elif stand == 'detail':
            m = DETAILREGEL.match(r)
            if m and m.group(4).upper() == 'CODE':
                seg = segmenten.get(int(m.group(1), 16), '').upper()
                if seg in secties:
                    start = secties[seg] + int(m.group(2), 16)
                    unitbereiken.append((m.group(5), start, start + int(m.group(3), 16)))
        elif stand == 'opwaarde':
            m = PUBLICREGEL.match(r)
            if not m:
                continue
            seg = segmenten.get(int(m.group(1), 16), '').upper()
            if seg not in secties:
                continue
            adres = secties[seg] + int(m.group(2), 16)
            volnaam = m.group(3)
            unit, _, rest = volnaam.partition('.')
            if not rest:
                unit, rest = '', volnaam
            k, kaal = sleutel(unit, rest)
            symbolen.append(Symbool(adres, 'f' if seg == 'CODE' else 'd', unit, kaal, k))
    return symbolen, unitbereiken


def projectunits(units):
    """De units van het project zelf uit units-1.1.json.

    Geen bibliotheekunit, en ofwel benoemd ofwel groter dan alleen een init-/finalisatiestub
    (dezelfde keuze als tools/ghidra/analyze.sh): de 32 units van src/game plus ddraw.
    """
    return [u for u in units if not u['library'] and (u['name'] or u['end'] - u['start'] > STUBGRENS)]


def unitnaam(u):
    return u['name'] or 'Unit%d' % u['init_order']


# ---- het binaire bestand -------------------------------------------------------------------

class Beeld:
    """Een in het geheugen geladen image met relocaties, secties en datablokken in CODE.

    Kan uit een PE-bestand komen (uit_pe) of in tests synthetisch worden opgebouwd.
    """

    def __init__(self, base, geheugen, secties, relocs, code_naam='CODE'):
        self.base = base
        self.mem = geheugen                       # bytes, vanaf base
        self.secties = sorted(secties, key=lambda s: s[1])   # [(naam, start, eind)]
        self.relocs = sorted(relocs)              # VA's van 32-bits absolute relocaties
        self.reloc_set = set(self.relocs)
        cs = [s for s in self.secties if s[0] == code_naam]
        self.code_start, self.code_eind = (cs[0][1], cs[0][2]) if cs else (0, 0)
        self.datastarts = []                      # begin van data (literals, RTTI, VMT) in CODE
        self.vmts = {}                            # klassenaam (klein) -> VMT-adres
        self.vmtstarts = []                       # begin van elke VMT-structuur (incl. RTTI ervoor)
        self.pe = None

    @classmethod
    def uit_pe(cls, pad):
        pe = pefile.PE(pad, fast_load=False)
        base = pe.OPTIONAL_HEADER.ImageBase
        mem = bytes(pe.get_memory_mapped_image())
        secties = [(s.Name.rstrip(b'\0').decode('latin1'), base + s.VirtualAddress,
                    base + s.VirtualAddress + (s.Misc_VirtualSize or s.SizeOfRawData))
                   for s in pe.sections]
        relocs = []
        for blok in getattr(pe, 'DIRECTORY_ENTRY_BASERELOC', []):
            for e in blok.entries:
                if e.type == pefile.RELOCATION_TYPE['IMAGE_REL_BASED_HIGHLOW']:
                    relocs.append(base + e.rva)
        b = cls(base, mem, secties, relocs)
        b.pe = pe
        b.pad = pad
        b._zoek_datablokken(pad)
        return b

    def _zoek_datablokken(self, pad):
        """Stringliterals en VMT-structuren in CODE: daar wordt niet gedisassembleerd."""
        starts = set()
        code = self.lees(self.code_start, self.code_eind - self.code_start)
        i = code.find(b'\xff\xff\xff\xff')
        while i != -1:
            if i % 4 == 0 and i + 8 <= len(code):
                n, = struct.unpack_from('<I', code, i + 4)
                if 0 < n < 0x10000 and i + 8 + n < len(code) and code[i + 8 + n] == 0:
                    starts.add(self.code_start + i)
            i = code.find(b'\xff\xff\xff\xff', i + 1)
        try:
            im = delphi.Image(pad)
            for v in im.find_vmts().values():
                kop = v.addr + delphi.VMT_SELF
                begin = kop
                for p in (im.u32(v.addr + delphi.VMT_CLASS_NAME), v.type_info, v.field_table,
                          v.method_table, v.dynamic_table, im.u32(v.addr + delphi.VMT_INIT_TABLE),
                          im.u32(v.addr + delphi.VMT_AUTO_TABLE), im.u32(v.addr + delphi.VMT_INTF_TABLE)):
                    if p and kop - 0x2000 <= p < kop:
                        begin = min(begin, p)
                self.vmtstarts.append(begin)
                self.vmts.setdefault(v.name.lower(), v.addr)
        except (KeyError, ValueError, struct.error, IndexError):
            pass
        self.vmtstarts.sort()
        self.datastarts = sorted(starts | set(self.vmtstarts))

    # -- toegang --
    def lees(self, va, n):
        o = va - self.base
        return self.mem[o:o + n]

    def u32(self, va):
        return struct.unpack_from('<I', self.mem, va - self.base)[0]

    def sectie_van(self, va):
        for s in self.secties:
            if s[1] <= va < s[2]:
                return s
        return None

    def in_code(self, va):
        return self.code_start <= va < self.code_eind


def lees_json(pad):
    with open(pad, encoding='utf-8') as f:
        return json.load(f)


def lees_bytes(pad):
    with open(pad, 'rb') as f:
        return f.read()


def sha(b):
    return hashlib.sha256(b).hexdigest()


def sectiehashes(pad):
    """sha256 van het hele bestand, de headers en elke PE-sectie (ruwe bytes)."""
    data = lees_bytes(pad)
    pe = pefile.PE(data=data, fast_load=True)
    uit = collections.OrderedDict()
    uit['(bestand)'] = (len(data), sha(data))
    eerste = min([s.PointerToRawData for s in pe.sections if s.SizeOfRawData] or [len(data)])
    uit['(headers)'] = (eerste, sha(data[:eerste]))
    for s in pe.sections:
        naam = s.Name.rstrip(b'\0').decode('latin1')
        ruw = data[s.PointerToRawData:s.PointerToRawData + s.SizeOfRawData] if s.SizeOfRawData else b''
        uit[naam] = (len(ruw), sha(ruw))
    return uit


# ---- normalisatie ---------------------------------------------------------------------------

_MD = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
_PREFIXEN = {0x66, 0x67, 0xF2, 0xF3, 0x2E, 0x3E, 0x26, 0x36, 0x64, 0x65, 0xF0}


def relatieve_sprong(ins):
    """(offset, grootte) van de verplaatsing van een relatieve sprong/aanroep, of None."""
    i = 0
    while i < len(ins) and ins[i] in _PREFIXEN:
        i += 1
    if i >= len(ins):
        return None
    op = ins[i]
    if op in (0xE8, 0xE9) and len(ins) >= i + 5:
        return i + 1, 4
    if op == 0x0F and i + 1 < len(ins) and 0x80 <= ins[i + 1] <= 0x8F and len(ins) >= i + 6:
        return i + 2, 4
    if (op == 0xEB or 0x70 <= op <= 0x7F or 0xE0 <= op <= 0xE3) and len(ins) >= i + 2:
        return i + 1, 1
    return None


class Ankers:
    """Gedeelde symbolen van één kant, per sectie gesorteerd: adres -> sleutel."""

    def __init__(self, beeld, paren):
        self.beeld = beeld
        per = collections.defaultdict(list)
        for adres, k in paren:
            s = beeld.sectie_van(adres)
            if s:
                per[s[0]].append((adres, k))
        self.per = {n: (sorted(set(v)), [a for a, _ in sorted(set(v))]) for n, v in per.items()}

    def los_op(self, doel, start, eind):
        """Zet een doeladres om in een vergelijkbare verwijzing."""
        if start <= doel < eind:
            return ('intern', doel - start)
        s = self.beeld.sectie_van(doel)
        if s is None:
            return ('waarde', doel)
        lijst = self.per.get(s[0])
        if lijst:
            i = bisect.bisect_right(lijst[1], doel) - 1
            if i >= 0:
                adres, k = lijst[0][i]
                return ('sym', k, doel - adres)
        if s[0] == 'CODE':
            return ('?', 'CODE')
        return ('sectie', s[0], doel - s[1])


class Datareeksen:
    """Gesorteerde, niet-overlappende [(begin, eind)] in CODE waar niet gedisassembleerd wordt."""

    def __init__(self, reeksen):
        self.reeksen = reeksen
        self.starts = [r[0] for r in reeksen]

    def eind_van(self, va):
        """Einde van het datablok waar va in ligt, of None."""
        i = bisect.bisect_right(self.starts, va) - 1
        if i >= 0 and va < self.reeksen[i][1]:
            return self.reeksen[i][1]
        return None

    def volgende(self, va):
        i = bisect.bisect_right(self.starts, va)
        return self.starts[i] if i < len(self.starts) else None


def normaliseer(beeld, ankers, start, eind, data):
    """Geef [(afstand, token)] voor de bytes [start, eind) van een routine.

    data: Datareeksen van dit beeld.
    """
    code = beeld.lees(start, eind - start)
    relocs = beeld.relocs
    uit = []
    p = start
    in_data = data.eind_van
    volgende_data = data.volgende

    def reloc_token(r):
        return ('r', ankers.los_op(beeld.u32(r), start, eind))

    while p < eind:
        ri = bisect.bisect_left(relocs, p)
        volgende_reloc = relocs[ri] if ri < len(relocs) else None
        if volgende_reloc == p and p + 4 <= eind:
            uit.append((p - start, reloc_token(p)))
            p += 4
            continue
        data_eind = in_data(p)
        if data_eind is not None:
            # Data: byte voor byte, relocaties als symbolisch doel.
            grens = min(data_eind, eind)
            while p < grens:
                if p in beeld.reloc_set and p + 4 <= eind:
                    uit.append((p - start, reloc_token(p)))
                    p += 4
                else:
                    uit.append((p - start, ('b', code[p - start])))
                    p += 1
            continue
        grens = eind
        vd = volgende_data(p)
        if vd is not None and vd < grens:
            grens = vd
        ins = None
        for _, grootte, _, _ in _MD.disasm_lite(code[p - start:min(p - start + 16, grens - start)], p, 1):
            ins = grootte
        if ins is None:
            uit.append((p - start, ('b', code[p - start])))
            p += 1
            continue
        if volgende_reloc is not None and volgende_reloc < p + ins and volgende_reloc + 4 > p + ins:
            # Een relocatie loopt over de instructiegrens: dit is geen code. Neem de bytes ervoor ruw.
            for q in range(p, volgende_reloc):
                uit.append((q - start, ('b', code[q - start])))
            p = volgende_reloc
            continue
        b = code[p - start:p - start + ins]
        delen = []
        q = 0
        sprong = relatieve_sprong(b)
        while q < ins:
            va = p + q
            if va in beeld.reloc_set:
                delen.append(reloc_token(va))
                q += 4
                continue
            if sprong and q == sprong[0]:
                n = sprong[1]
                rel = int.from_bytes(b[q:q + n], 'little', signed=True)
                doel = p + ins + rel
                if start <= doel < eind:
                    delen.append(b[q:q + n])
                else:
                    delen.append(('rel', ankers.los_op(doel, start, eind)))
                q += n
                continue
            delen.append(b[q:q + 1])
            q += 1
        # Opeenvolgende ruwe bytes samenvoegen.
        samen = []
        for d in delen:
            if isinstance(d, bytes) and samen and isinstance(samen[-1], bytes):
                samen[-1] += d
            else:
                samen.append(d)
        uit.append((p - start, ('c', tuple(samen))))
        p += ins
    return uit


def eerste_verschil(ta, tb, lengte_a, lengte_b):
    """Afstand van het eerste verschillende token, of None als alles gelijk is."""
    for (oa, xa), (ob, xb) in zip(ta, tb):
        if xa != xb or oa != ob:
            return oa
    if len(ta) > len(tb):
        return ta[len(tb)][0]
    if len(tb) > len(ta):
        return tb[len(ta)][0]
    if lengte_a != lengte_b:
        return min(lengte_a, lengte_b)
    return None


def disassembleer(beeld, va, n=1):
    code = beeld.lees(va, 16 * n)
    return ['%08x  %s %s' % (a, m, o) for a, _, m, o in _MD.disasm_lite(code, va, n)]


# ---- koppelen --------------------------------------------------------------------------------

def koppel(orig_r, build_r):
    """Koppel routines op naam: eerst op volledige sleutel (bij dubbele namen in adresvolgorde),
    daarna wat overblijft op naam zonder unit als die aan beide kanten uniek is.
    Geeft {origadres: buildadres}."""
    paren = {}
    per_o, per_b = collections.defaultdict(list), collections.defaultdict(list)
    for s in orig_r:
        per_o[s.sleutel].append(s.adres)
    for s in build_r:
        per_b[s.sleutel].append(s.adres)
    for k, lijst in per_o.items():
        for a, b in zip(sorted(lijst), sorted(per_b.get(k, []))):
            paren[a] = b
    gebruikt = set(paren.values())
    rest_o = collections.defaultdict(list)
    rest_b = collections.defaultdict(list)
    for s in orig_r:
        if s.adres not in paren:
            rest_o[s.naam.lower()].append(s.adres)
    for s in build_r:
        if s.adres not in gebruikt:
            rest_b[s.naam.lower()].append(s.adres)
    for n, lijst in rest_o.items():
        if len(lijst) == 1 and len(rest_b.get(n, [])) == 1:
            paren[lijst[0]] = rest_b[n][0]
    return paren


class Positiekaart:
    """Zet een adres aan de ene kant om naar de andere kant, ten opzichte van de eerstvolgende
    gekoppelde routine (geneste routines staan vlak vóór hun ouder)."""

    def __init__(self, paren):
        self.paren = sorted(paren)                # [(a, b)]
        self.a = [p[0] for p in self.paren]

    def omzetten(self, x):
        i = bisect.bisect_left(self.a, x)
        if i < len(self.paren):
            a, b = self.paren[i]
            kandidaat = b - (a - x)
            # Moet tussen de buren aan de andere kant vallen.
            if i == 0 or self.paren[i - 1][1] < kandidaat:
                return kandidaat
            return None
        if self.paren:
            a, b = self.paren[-1]
            return b + (x - a)
        return None


# ---- vergelijken ------------------------------------------------------------------------------

@dataclass
class Item:
    naam: str
    unit: str
    orig: int = None
    build: int = None
    orig_eind: int = None
    build_eind: int = None
    status: str = ''
    verschil: int = None
    koppeling: str = 'naam'     # naam, positie, unit, alleen-build
    project: bool = False

    @property
    def grootte(self):
        return (self.orig_eind - self.orig) if self.orig is not None and self.orig_eind else 0


@dataclass
class Resultaat:
    secties: list = field(default_factory=list)   # [(naam, orig, build, gelijk)]
    items: list = field(default_factory=list)


def datareeksen(beeld, grenzen):
    """Datareeksen van een beeld: elk datablok (stringliteral, VMT/RTTI) loopt tot de
    eerstvolgende gebiedsgrens (routine of unit)."""
    starts = sorted(set(grenzen))
    uit = []
    for d in beeld.datastarts:
        i = bisect.bisect_right(starts, d)
        e = starts[i] if i < len(starts) else beeld.code_eind
        if uit and d < uit[-1][1]:
            continue
        uit.append((d, e))
    return Datareeksen(uit)


def vergelijk(orig, osym, build, bsym, units, build_units=None):
    """Vergelijk routine voor routine. units: lijst uit units-1.1.json (voor het origineel);
    build_units: [(unit, start, eind)] uit het mapbestand, of None."""
    res = Resultaat()
    unit_van_adres = sorted((u['start'], u['end'], u) for u in units)
    ustarts = [x[0] for x in unit_van_adres]
    project = {id(u) for u in projectunits(units)}

    def unit_bij(a):
        i = bisect.bisect_right(ustarts, a) - 1
        if i >= 0 and a < unit_van_adres[i][1]:
            return unit_van_adres[i][2]
        return None

    o_r = {s.adres: s for s in osym if s.soort == 'f' and orig.in_code(s.adres)}
    b_r = {s.adres: s for s in bsym if s.soort == 'f' and build.in_code(s.adres)}
    paren = koppel(list(o_r.values()), list(b_r.values()))
    kaart = Positiekaart(paren.items())
    terug = Positiekaart([(b, a) for a, b in paren.items()])

    items = []
    for a in sorted(o_r):
        s = o_r[a]
        it = Item(s.volledig, s.unit, orig=a)
        if a in paren:
            it.build = paren[a]
        else:
            it.build = kaart.omzetten(a)
            it.koppeling = 'positie'
        items.append(it)
    gekoppeld_b = set(paren.values())
    for b in sorted(b_r):
        if b in gekoppeld_b:
            continue
        s = b_r[b]
        it = Item(s.volledig, s.unit, build=b, koppeling='alleen-build')
        it.orig = terug.omzetten(b)
        items.append(it)

    # Unitgrenzen: aan de originele kant uit units-1.1.json, aan de buildkant uit het map of via positie.
    bu = {n.lower(): s for n, s, _ in (build_units or [])}
    routine_o = {it.orig for it in items if it.orig is not None}
    for _, _, u in unit_van_adres:
        if u['start'] in routine_o:
            continue
        it = Item('%s.(kop)' % unitnaam(u), unitnaam(u), orig=u['start'], koppeling='unit')
        it.build = bu.get(unitnaam(u).lower())
        if it.build is None:
            it.build = kaart.omzetten(u['start'])
        items.append(it)
    ugrenzen_o = set(ustarts)
    ugrenzen_b = {s for _, s, _ in (build_units or [])}
    for it in items:
        if it.koppeling == 'unit' and it.build is not None:
            ugrenzen_b.add(it.build)

    # Gebiedsgrenzen per kant.
    def ok(beeld, x):
        return x is not None and beeld.in_code(x)

    grenzen_o = sorted({it.orig for it in items if ok(orig, it.orig)} | ugrenzen_o | {orig.code_eind})
    grenzen_b = sorted({it.build for it in items if ok(build, it.build)} | ugrenzen_b | {build.code_eind})

    def einde(grenzen, x):
        i = bisect.bisect_right(grenzen, x)
        return grenzen[i] if i < len(grenzen) else x

    for it in items:
        if ok(orig, it.orig):
            it.orig_eind = einde(grenzen_o, it.orig)
        if ok(build, it.build):
            it.build_eind = einde(grenzen_b, it.build)
        u = unit_bij(it.orig) if it.orig is not None else None
        if u is not None:
            it.unit = unitnaam(u)
            it.project = id(u) in project

    # Ankers: alles wat aan beide kanten bestaat.
    ank_o, ank_b = [], []
    for it in items:
        if ok(orig, it.orig) and ok(build, it.build):
            k = 'r:%x' % it.orig
            ank_o.append((it.orig, k))
            ank_b.append((it.build, k))
    o_d = collections.defaultdict(list)
    b_d = collections.defaultdict(list)
    for s in osym:
        if s.soort == 'd':
            o_d[s.sleutel].append(s.adres)
    for s in bsym:
        if s.soort == 'd':
            b_d[s.sleutel].append(s.adres)
    kale_o = collections.defaultdict(set)
    kale_b = collections.defaultdict(set)
    for k in set(o_d) - set(b_d):
        kale_o[k.rsplit('.', 1)[-1]].add(k)
    for k in set(b_d) - set(o_d):
        kale_b[k.rsplit('.', 1)[-1]].add(k)
    for k in set(o_d) & set(b_d):
        ank_o.append((min(o_d[k]), 'd:' + k))
        ank_b.append((min(b_d[k]), 'd:' + k))
    for kaal, ks in kale_o.items():
        if len(ks) == 1 and len(kale_b.get(kaal, ())) == 1:
            ko, kb = next(iter(ks)), next(iter(kale_b[kaal]))
            ank_o.append((min(o_d[ko]), 'd:' + kaal))
            ank_b.append((min(b_d[kb]), 'd:' + kaal))
    for naam in set(orig.vmts) & set(build.vmts):
        ank_o.append((orig.vmts[naam], 'vmt:' + naam))
        ank_b.append((build.vmts[naam], 'vmt:' + naam))
    ankers_o, ankers_b = Ankers(orig, ank_o), Ankers(build, ank_b)

    # Datablokken lopen tot de volgende gebiedsgrens; die grenzen zijn aan beide kanten dezelfde.
    dr_o = datareeksen(orig, grenzen_o)
    dr_b = datareeksen(build, grenzen_b)

    for it in items:
        if not ok(orig, it.orig) or not ok(build, it.build) or it.orig_eind is None or it.build_eind is None:
            it.status = 'extra' if it.koppeling == 'alleen-build' else 'ontbreekt'
            continue
        ta = normaliseer(orig, ankers_o, it.orig, it.orig_eind, dr_o)
        tb = normaliseer(build, ankers_b, it.build, it.build_eind, dr_b)
        v = eerste_verschil(ta, tb, it.orig_eind - it.orig, it.build_eind - it.build)
        it.status = 'gelijk' if v is None else 'verschilt'
        it.verschil = v
    items.sort(key=lambda it: (it.orig if it.orig is not None else 1 << 40, it.build or 0))
    res.items = items
    return res


def laad(orig_pad, build_pad, map_pad=None, tsv=STANDAARD_TSV, units_pad=STANDAARD_UNITS):
    """Laad alles wat vergelijk() nodig heeft en voer de vergelijking uit."""
    orig = Beeld.uit_pe(orig_pad)
    build = orig if os.path.abspath(build_pad) == os.path.abspath(orig_pad) else Beeld.uit_pe(build_pad)
    osym = lees_tsv(tsv)
    if map_pad:
        bsym, bunits = lees_map(map_pad, build.pe)
    else:
        bsym, bunits = osym, None
    units = lees_json(units_pad)['units']
    res = vergelijk(orig, osym, build, bsym, units, bunits)
    ho, hb = sectiehashes(orig_pad), sectiehashes(build_pad)
    for naam in list(ho) + [n for n in hb if n not in ho]:
        a, b = ho.get(naam), hb.get(naam)
        res.secties.append((naam, a, b, a is not None and b is not None and a[1] == b[1]))
    return res, orig, build


def statustekst(it):
    if it.status == 'verschilt':
        return 'verschilt (eerste verschil op +0x%x)' % it.verschil
    return it.status


def als_json(res):
    return {
        'secties': [{'naam': n, 'orig': a and {'grootte': a[0], 'sha256': a[1]},
                     'build': b and {'grootte': b[0], 'sha256': b[1]}, 'gelijk': g}
                    for n, a, b, g in res.secties],
        'routines': [{'naam': it.naam, 'unit': it.unit, 'project': it.project,
                      'orig': it.orig is not None and '%08x' % it.orig or None,
                      'build': it.build is not None and '%08x' % it.build or None,
                      'grootte': it.grootte,
                      'grootte_build': (it.build_eind - it.build) if it.build_eind else None,
                      'koppeling': it.koppeling, 'status': it.status,
                      'verschil': it.verschil} for it in res.items],
        'samenvatting': samenvatting(res),
    }


def samenvatting(res):
    s = {}
    for groep, sel in (('project', lambda it: it.project), ('bibliotheek', lambda it: not it.project)):
        c = collections.Counter(it.status for it in res.items if sel(it))
        s[groep] = dict(c)
    s['bestand_gelijk'] = bool(res.secties and res.secties[0][3])
    return s


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('orig')
    ap.add_argument('build')
    ap.add_argument('--map', help='gedetailleerd Delphi-mapbestand van de herbouw')
    ap.add_argument('--tsv', default=STANDAARD_TSV)
    ap.add_argument('--units', default=STANDAARD_UNITS)
    ap.add_argument('--alles', action='store_true', help='ook bibliotheekroutines tonen')
    ap.add_argument('-v', action='store_true', help='instructies bij verschillen tonen')
    ap.add_argument('--json', help='schrijf het resultaat ook als JSON')
    args = ap.parse_args()

    res, orig, build = laad(args.orig, args.build, args.map, args.tsv, args.units)
    print('Secties:')
    for naam, a, b, g in res.secties:
        print('  %-10s %-9s %s' % (naam, 'gelijk' if g else 'VERSCHILT',
                                   '' if g else 'orig %s  build %s' % (
                                       a and '%d B %s' % (a[0], a[1][:12]) or '-',
                                       b and '%d B %s' % (b[0], b[1][:12]) or '-')))
    print('\nRoutines%s:' % ('' if args.alles else ' (projectunits; --alles voor alles)'))
    for it in res.items:
        if not (args.alles or it.project):
            continue
        extra = '' if it.koppeling in ('naam', 'unit') else '  [%s]' % it.koppeling
        print('  %-14s %-8s %-40s %s%s' % (it.unit, '%08x' % it.orig if it.orig is not None else '-',
                                           it.naam, statustekst(it), extra))
        if args.v and it.status == 'verschilt':
            for r in disassembleer(orig, it.orig + it.verschil, 2):
                print('      orig:  ' + r)
            for r in disassembleer(build, it.build + it.verschil, 2):
                print('      build: ' + r)
    s = samenvatting(res)
    print('\nSamenvatting:')
    for groep in ('project', 'bibliotheek'):
        c = s[groep]
        print('  %-12s %s' % (groep, ', '.join('%s %d' % kv for kv in sorted(c.items())) or '-'))
    print('  bestand      %s' % ('byte-identiek' if s['bestand_gelijk'] else 'verschilt'))
    if args.json:
        with open(args.json, 'w') as f:
            json.dump(als_json(res), f, indent=1)
    sys.exit(0 if s['bestand_gelijk'] else 1)


if __name__ == '__main__':
    main()

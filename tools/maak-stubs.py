"""Maak bootstrap-stubs voor de matchende Delphi 5-build (PLAN.md, fase 2, "Bootstrap-strategie").

Voor elke projectunit wordt een Pascal-unit geschreven waarin elke routine een `asm … end`-blok
is met de originele bytes als `db`-directives. Elke relocatie (uit de .reloc-tabel) wordt een
symbolische `dd`:
  * doel binnen hetzelfde blok          -> lokaal label `@@Lxxxx` (afstand vanaf het blokbegin)
  * routine van een projectunit         -> de stubnaam (`TTrein_Create`, uit een andere unit
                                           `uTrein.TTrein_Create`), eventueel `+ $afstand`
  * routine van een bibliotheekunit     -> `Unit.Naam` (bijv. `System.@LStrAsg`)
  * benoemde data / VMT                 -> naam uit symbols/ros-1.1.tsv (`VMT_TTrein`)
  * niet herleidbaar                    -> `<Unit>_<adres>` (of `DATA_<adres>`) met commentaar
Stringliterals die de compiler na een routine neerlegt, horen bij het blok van die routine. RTTI,
VMT's en andere door de compiler uit declaraties gegenereerde data worden niet als asm uitgegeven
maar alleen als commentaar vermeld; die komen uit de typedeclaraties.

Delphi zet na elk asm-blok zelf een RET (C3) en vult daarna uit tot een veelvoud van 4
(90 / 8B C0 / 8D 40 00). Standaard wordt daarom een afsluitende `C3 + opvulling` weggelaten
(met commentaar); blokken die niet zo eindigen (RET n, literals, sprong) worden volledig
uitgegeven en met `LET OP` gemarkeerd. --ruw geeft altijd alle bytes.

De uitvoer bevat originele codebytes en mag dus NOOIT worden gecommit; de uitvoermap moet onder
build/ liggen.

Gebruik: python tools/maak-stubs.py ROS.exe build/stubs [--unit uTrein ...] [--ruw]
                                    [--tsv ...] [--units ...]
"""
import argparse
import bisect
import collections
import hashlib
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import diff  # noqa: E402

OPVULLING = (b'', b'\x90', b'\x8b\xc0', b'\x8d\x40\x00')
GERESERVEERD = {'initialization', 'finalization', 'begin', 'end', 'program', 'unit', 'type', 'var',
                'const', 'label', 'procedure', 'function', 'asm', 'main', 'interface', 'implementation'}
IDENT = re.compile(r'^@?[A-Za-z_][A-Za-z0-9_]*$')


def vlak(naam):
    """Maak van een (geneste) routinenaam één Pascal-identifier."""
    return re.sub(r'[^A-Za-z0-9_]', '_', naam.replace('.', '_'))


class Naamtabel:
    """Symbolische namen voor adressen, afgeleid uit symbols/ros-1.1.tsv, en terug."""

    def __init__(self, symbolen, units, beeld):
        self.beeld = beeld
        self.units = sorted(units, key=lambda u: u['start'])
        self.ustarts = [u['start'] for u in self.units]
        self.project = {id(u) for u in diff.projectunits(units)}
        self.stubnaam = {}          # adres -> (unitnaam, identifier) voor projectroutines
        self.tekst = {}             # adres -> verwijzingstekst zonder unitkwalificatie-afhankelijkheid
        gezien = collections.defaultdict(set)
        bezette_tekst = set()
        syms = sorted((s for s in symbolen if s.soort in ('f', 'd', 'v')), key=lambda s: s.adres)
        for s in syms:
            u = self.unit_bij(s.adres)
            if s.soort == 'f' and u is not None and id(u) in self.project:
                un = diff.unitnaam(u)
                ident = vlak(s.naam)
                if ident.lower() in GERESERVEERD or ident[0].isdigit():
                    ident = '%s_%s' % (un, ident)
                basis, n = ident, 2
                while ident.lower() in gezien[un]:
                    ident = '%s_%d' % (basis, n)
                    n += 1
                gezien[un].add(ident.lower())
                self.stubnaam[s.adres] = (un, ident)
                continue
            if s.soort == 'f':
                if u is None or not u['name'] or '_NF_' in s.naam or '_DF_' in s.naam \
                        or s.naam in ('Initialization', 'Finalization'):
                    continue
                if not all(IDENT.match(d) for d in s.naam.split('.')):
                    continue
                t = '%s.%s' % (u['name'], s.naam)
            elif s.soort == 'v':
                t = s.naam
            else:
                t = s.volledig
                if not all(IDENT.match(d) for d in t.split('.')):
                    continue
            if t.lower() in bezette_tekst:
                continue        # dubbele naam (overload, recordveld): alleen het eerste adres
            bezette_tekst.add(t.lower())
            self.tekst[s.adres] = t
        # Alle benoemde adressen, voor "naam + afstand".
        self.adressen = sorted(set(self.stubnaam) | set(self.tekst))
        # Alle symbooladressen (ook zonder bruikbare naam) begrenzen het bereik van een naam.
        self.grenzen = sorted({s.adres for s in syms})
        # VMT's: verwijzingen naar de kop (vmtSelfPtr op -$4C enz.) worden "VMT_X - $afstand".
        self.vmts = sorted(s.adres for s in syms if s.soort == 'v' and s.adres in self.tekst)

    def unit_bij(self, a):
        i = bisect.bisect_right(self.ustarts, a) - 1
        if i >= 0 and a < self.units[i]['end']:
            return self.units[i]
        return None

    def naam_voor(self, adres, vanuit):
        if adres in self.stubnaam:
            un, ident = self.stubnaam[adres]
            return ident if un == vanuit else '%s.%s' % (un, ident)
        return self.tekst.get(adres)

    def verwijzing(self, doel, vanuit, gaten):
        """(tekst, commentaar, unit_of_None) voor een doeladres vanuit unit `vanuit`.
        gaten: (starts, [(begin, eind, soort)]) van alle projectunits."""
        sectie = self.beeld.sectie_van(doel)
        sectienaam = sectie[0] if sectie else 'BUITEN'
        u = self.unit_bij(doel)
        plek = diff.unitnaam(u) if u is not None and sectienaam == 'CODE' else sectienaam.strip('.').upper()
        label = '%s_%08X' % (plek, doel)
        exact = self.naam_voor(doel, vanuit)
        if exact:
            du = self.unit_bij(doel)
            return exact, '%08X' % doel, (diff.unitnaam(du) if du is not None and sectienaam == 'CODE' else None)
        i = bisect.bisect_left(self.vmts, doel)
        if i < len(self.vmts) and self.vmts[i] - doel <= -diff.delphi.VMT_SELF:
            v = self.vmts[i]
            return '%s - $%X' % (self.tekst[v], v - doel), '%08X, VMT-kop' % doel, None
        i = bisect.bisect_right(gaten[0], doel) - 1 if gaten else -1
        if i >= 0 and doel < gaten[1][i][1]:
            return label, 'niet herleidbaar: %s' % gaten[1][i][2], None
        i = bisect.bisect_right(self.adressen, doel) - 1
        if i >= 0:
            a = self.adressen[i]
            j = bisect.bisect_right(self.grenzen, a)
            grens = self.grenzen[j] if j < len(self.grenzen) else (sectie[2] if sectie else doel + 1)
            sa = self.beeld.sectie_van(a)
            if doel < grens and sa == sectie:
                naam = self.naam_voor(a, vanuit)
                tekst = naam if doel == a else '%s + $%X' % (naam, doel - a)
                du = self.unit_bij(a)
                return tekst, '%08X' % doel, (diff.unitnaam(du) if du is not None and sectienaam == 'CODE' else None)
        return label, 'niet herleidbaar: %08X' % doel, None

    def adres_van(self, tekst, vanuit):
        """Omgekeerd: verwijzingstekst (zonder lokale labels) -> adres. Voor de tests."""
        if not hasattr(self, '_omgekeerd'):
            self._omgekeerd = {}
            for a, (un, ident) in self.stubnaam.items():
                self._omgekeerd[(un, ident)] = a
                self._omgekeerd[(None, '%s.%s' % (un, ident))] = a
            for a, t in self.tekst.items():
                self._omgekeerd[(None, t)] = a
        m = re.match(r'^(\S+?)(?:\s*([+-])\s*\$([0-9A-Fa-f]+))?$', tekst.strip())
        naam, afstand = m.group(1), int(m.group(3) or '0', 16) * (-1 if m.group(2) == '-' else 1)
        a = self._omgekeerd.get((vanuit, naam), self._omgekeerd.get((None, naam)))
        if a is None:
            label = re.match(r'^[A-Za-z0-9]+_([0-9A-F]{8})$', naam)
            if not label:
                raise KeyError(naam)
            a = int(label.group(1), 16)
        return a + afstand


def indeling(beeld, u, symbolen):
    """(routines, blokeinde-functie, gaten) van een unit; gaten = [(begin, eind, soort)] die niet
    als asm worden uitgegeven (kop van de unit, RTTI/VMT-data)."""
    routines = sorted(s.adres for s in symbolen if s.soort == 'f' and u['start'] <= s.adres < u['end'])
    # Door de compiler uit declaraties gegenereerde data: VMT's (met hun RTTI) en benoemde RTTI ('d').
    datastarts = {a for a in beeld.vmtstarts if u['start'] <= a < u['end']}
    datastarts |= {s.adres for s in symbolen if s.soort == 'd' and u['start'] <= s.adres < u['end']}
    grenzen = sorted(set(routines) | datastarts | {u['end']})

    def blokeinde(a):
        i = bisect.bisect_right(grenzen, a)
        return grenzen[i] if i < len(grenzen) else u['end']

    gaten = []
    p = u['start']
    for r in routines + [u['end']]:
        if p < r:
            gaten.append((p, r, 'kop van de unit' if p == u['start'] else 'RTTI/VMT-data'))
        if r < u['end']:
            p = blokeinde(r)
    return routines, blokeinde, gaten


def aanroepen(beeld, start, eind, n):
    """{afstand: (mnemonic, doel)} van `call rel32` (E8) en `jmp rel32` (E9) naar een doel buiten
    [start, eind), gevonden met een lineaire sweep over de eerste n bytes; die stopt bij het eerste
    datablok (stringliteral)."""
    i = bisect.bisect_right(beeld.datastarts, start)
    if i < len(beeld.datastarts) and beeld.datastarts[i] < start + n:
        n = beeld.datastarts[i] - start
    code = beeld.lees(start, n)
    relocs = [x - start for x in beeld.relocs if start <= x < start + n]
    uit = {}
    for adres, grootte, _, _ in diff._MD.disasm_lite(code, start):
        p = adres - start
        if any(p < x < p + grootte < x + 4 for x in relocs):
            break           # relocatie over de instructiegrens: dit is geen code meer
        if grootte == 5 and code[p] in (0xE8, 0xE9):
            doel = adres + 5 + int.from_bytes(code[p + 1:p + 5], 'little', signed=True)
            if not start <= doel < eind:
                uit[p] = ('call' if code[p] == 0xE8 else 'jmp', doel)
    return uit


Blok = collections.namedtuple('Blok', 'adres naam ident eind uitgegeven staart labels let_op')


def maak_unit(beeld, namen, u, symbolen, gaten, ruw=False):
    """Geef (pascaltekst, [Blok], gebruikte_units) voor één unit; gaten zoals bij Naamtabel.verwijzing."""
    un = diff.unitnaam(u)
    routines, volgende, eigen_gaten = indeling(beeld, u, symbolen)
    naam_van = {s.adres: s.volledig for s in symbolen if s.soort == 'f'}
    blokken = []
    gebruikt = set()
    regels = []
    for r in routines:
        eind = volgende(r)
        code = beeld.lees(r, eind - r)
        relocs = [x for x in beeld.relocs if r <= x < eind]
        labels = set()
        for x in relocs:
            doel = beeld.u32(x)
            if r <= doel < eind:
                labels.add(doel - r)
        uitgegeven, staart, let_op = len(code), b'', None
        if not ruw:
            for pad in OPVULLING:
                n = len(code) - len(pad) - 1
                if code.endswith(b'\xc3' + pad) and (r + len(code)) % 4 == 0 \
                        and not any(x + 4 > r + n for x in relocs) and not any(l >= n for l in labels):
                    uitgegeven, staart = n, code[n:]
                    break
            else:
                let_op = ('eindigt niet op RET + opvulling (%s); de RET die de compiler na "end" '
                          'toevoegt, verschuift de code' % code[-4:].hex(' ').upper())
        ident = namen.stubnaam[r][1]
        blokken.append(Blok(r, naam_van.get(r, ''), ident, eind, uitgegeven, staart, sorted(labels), let_op))

        regels.append('')
        regels.append('{ @%08X %s (%d bytes) }' % (r, naam_van.get(r, ''), eind - r))
        if let_op:
            regels.append('{ LET OP: %s }' % let_op)
        regels.append('procedure %s; assembler;' % ident)
        regels.append('asm')
        rel_set = set(relocs)
        calls = aanroepen(beeld, r, eind, uitgegeven)
        p = 0
        lopend = []

        def spoel():
            if lopend:
                regels.append('  db ' + ','.join('$%02X' % b for b in lopend))
                lopend.clear()
        while p < uitgegeven:
            if p in labels:
                spoel()
                regels.append('@@L%04X:' % p)
            if r + p in rel_set and p + 4 <= uitgegeven:
                spoel()
                doel = beeld.u32(r + p)
                if r <= doel < eind:
                    regels.append('  dd @@L%04X' % (doel - r))
                else:
                    tekst, commentaar, du = namen.verwijzing(doel, un, gaten)
                    if du and du != un:
                        gebruikt.add(du)
                    regels.append('  dd %s { %s }' % (tekst, commentaar))
                p += 4
                continue
            if p in calls and p + 5 <= uitgegeven and namen.naam_voor(calls[p][1], un):
                # Relatieve aanroep/sprong symbolisch, zodat hij klopt als er iets verschuift.
                spoel()
                mnemonic, doel = calls[p]
                du = namen.unit_bij(doel)
                if du is not None and diff.unitnaam(du) != un and id(du) in namen.project:
                    gebruikt.add(diff.unitnaam(du))
                elif du is not None and du['name'] and diff.unitnaam(du) != un:
                    gebruikt.add(du['name'])
                regels.append('  %s %s { %08X }' % (mnemonic, namen.naam_voor(doel, un), doel))
                p += 5
                continue
            lopend.append(code[p])
            p += 1
            if len(lopend) == 16 or p in labels:
                spoel()
        spoel()
        if uitgegeven in labels:
            regels.append('@@L%04X:' % uitgegeven)
        if staart:
            regels.append('  { RET + opvulling (%s) voegt de compiler toe }' % staart.hex(' ').upper())
        regels.append('end;')

    kop = []
    for g0, g1, soort in eigen_gaten:
        kop.append('{ niet uitgegeven: %08X-%08X (%d bytes), %s; komt uit de declaraties }'
                   % (g0, g1 - 1, g1 - g0, soort))
    interface = ['procedure %s;' % namen.stubnaam[r][1] for r in routines]
    uses = sorted(x for x in gebruikt if x not in ('System', 'SysInit'))
    tekst = '\n'.join(
        ['unit %s;' % un,
         '',
         '{ Bootstrap-stub, gegenereerd door tools/maak-stubs.py uit ROS.exe (sha256 %s...).' % beeld.sha[:12],
         '  NIET COMMITTEN: bevat originele codebytes. Zie docs/MATCHEN.md.',
         '  Code %08X-%08X. Elke routine is een asm-blok met de originele bytes; relocaties zijn' % (u['start'], u['end'] - 1),
         '  symbolische dd-verwijzingen. <Unit>_<adres> is een niet-herleidbaar doel; VMT_<Klasse>',
         '  staat voor het VMT-adres van <Klasse>. Methoden zijn hier losse procedures',
         '  (<Klasse>_<Methode>); Initialization/Finalization horen later in de',
         '  initialization-/finalization-sectie. }',
         '',
         'interface',
         ''] + interface +
        ['', 'implementation', ''] +
        (['uses', '  ' + ', '.join(uses) + ';', ''] if uses else []) +
        kop + regels + ['', 'end.', ''])
    return tekst, blokken, gebruikt


def genereer(beeld, symbolen, units, alleen=None, ruw=False):
    """{unitnaam: (tekst, blokken)} voor de projectunits (of alleen de genoemde)."""
    namen = Naamtabel(symbolen, units, beeld)
    projectunits = sorted(diff.projectunits(units), key=lambda u: u['start'])
    alle_gaten = sorted(g for u in projectunits for g in indeling(beeld, u, symbolen)[2])
    gaten = ([g[0] for g in alle_gaten], alle_gaten)
    uit = collections.OrderedDict()
    for u in projectunits:
        un = diff.unitnaam(u)
        if alleen and un.lower() not in {a.lower() for a in alleen}:
            continue
        tekst, blokken, _ = maak_unit(beeld, namen, u, symbolen, gaten, ruw)
        uit[un] = (tekst, blokken)
    return uit, namen


def laad_beeld(pad):
    beeld = diff.Beeld.uit_pe(pad)
    beeld.sha = hashlib.sha256(diff.lees_bytes(pad)).hexdigest()
    return beeld


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('exe')
    ap.add_argument('uitmap')
    ap.add_argument('--unit', action='append', help='alleen deze unit(s)')
    ap.add_argument('--ruw', action='store_true', help='RET + opvulling niet weglaten')
    ap.add_argument('--tsv', default=diff.STANDAARD_TSV)
    ap.add_argument('--units', default=diff.STANDAARD_UNITS)
    args = ap.parse_args()

    build = os.path.realpath(os.path.join(diff.ROOT, 'build'))
    uitmap = os.path.realpath(args.uitmap)
    if not (uitmap == build or uitmap.startswith(build + os.sep)):
        sys.exit('fout: de uitvoer bevat originele codebytes en moet onder %s/ komen (niet committen)' % build)
    os.makedirs(uitmap, exist_ok=True)

    beeld = laad_beeld(args.exe)
    symbolen = diff.lees_tsv(args.tsv)
    units = diff.lees_json(args.units)['units']
    resultaat, _ = genereer(beeld, symbolen, units, args.unit, args.ruw)
    tot = collections.Counter()
    for un, (tekst, blokken) in resultaat.items():
        with open(os.path.join(uitmap, un + '.pas'), 'w', encoding='latin1', newline='\r\n') as f:
            f.write(tekst)
        ok = sum(1 for b in blokken if not b.let_op)
        tot['units'] += 1
        tot['routines'] += len(blokken)
        tot['zonder_let_op'] += ok
        tot['bytes'] += sum(b.eind - b.adres for b in blokken)
        print('%-15s %4d routines, %4d direct bruikbaar' % (un, len(blokken), ok))
    print('%d units, %d routines (%d bytes); %d zonder LET OP -> %s'
          % (tot['units'], tot['routines'], tot['bytes'], tot['zonder_let_op'], uitmap))


if __name__ == '__main__':
    main()

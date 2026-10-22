"""Hernoem zelfbedachte identifiers in alle Pascal-bronnen volgens de vertaalvoorstellen.

Leest build/vertaling/*.json ({"OudeNaam": "NieuweNaam"}), controleert ze en past ze toe op
src/game, src/tests en src/web, en op symbols/names/*.json (zodat de Ghidra-symbolen meegaan).

* In code wordt hoofdletterongevoelig hernoemd (Pascal), nooit binnen stringliterals.
* In commentaar alleen exacte (hoofdlettergevoelige) vermeldingen van de naam.
* Geweigerd worden: beschermde namen (build/beschermd.txt), Pascal-sleutelwoorden, ongeldige
  identifiers, en nieuwe namen die al als andere identifier in de code voorkomen of die
  dubbel gebruikt worden.

Gebruik: python tools/pas-hernoem.py build/beschermd.txt build/vertaling [--droog]
"""
import glob
import json
import os
import re
import sys

from importlib import util as _util

_spec = _util.spec_from_file_location('kand', os.path.join(os.path.dirname(__file__), 'vertaal-kandidaten.py'))
_kand = _util.module_from_spec(_spec)
_spec.loader.exec_module(_kand)
KEYWORDS = _kand.KEYWORDS

IDENT = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
TOKEN = re.compile(r"'(?:[^']|'')*'|\{[^}]*\}|\(\*.*?\*\)|//[^\n]*|[A-Za-z_][A-Za-z0-9_]*|.", re.S)


def laad_voorstellen(map_):
    voorstel, bron = {}, {}
    conflicten = []
    for pad in sorted(glob.glob(os.path.join(map_, '*.json'))):
        unit = os.path.splitext(os.path.basename(pad))[0]
        try:
            d = json.load(open(pad))
        except ValueError as e:
            conflicten.append('%s: geen geldige JSON (%s)' % (pad, e))
            continue
        for oud, nieuw in d.items():
            k = oud.lower()
            if k in voorstel and voorstel[k][1].lower() != nieuw.lower():
                conflicten.append('%s: %s -> %s (%s) en %s (%s); eerste gekozen' % (
                    oud, oud, voorstel[k][1], bron[k], nieuw, unit))
                continue
            voorstel.setdefault(k, (oud, nieuw))
            bron.setdefault(k, unit)
    return voorstel, conflicten


def bestaande_identifiers(paden):
    namen = set()
    for pad in paden:
        for t in TOKEN.findall(open(pad, encoding='latin1').read()):
            if IDENT.match(t):
                namen.add(t.lower())
    return namen


def hernoem_tekst(tekst, kaart, exact):
    def comment(c):
        return re.sub(r'\b[A-Za-z_][A-Za-z0-9_]*\b', lambda m: exact.get(m.group(0), m.group(0)), c)
    uit = []
    for t in TOKEN.findall(tekst):
        if t.startswith("'"):
            uit.append(t)
        elif t.startswith('{$'):
            uit.append(t)                      # compilerrichtlijn
        elif t.startswith(('{', '(*', '//')):
            uit.append(comment(t))
        elif IDENT.match(t) and t.lower() in kaart:
            uit.append(kaart[t.lower()])
        else:
            uit.append(t)
    return ''.join(uit)


def main():
    beschermd = {l.strip().lower() for l in open(sys.argv[1]) if l.strip()}
    voorstel, meldingen = laad_voorstellen(sys.argv[2])
    droog = '--droog' in sys.argv
    paden = sorted(glob.glob('src/game/*.pas') + glob.glob('src/game/*.dpr') +
                   glob.glob('src/tests/*.pas') + glob.glob('src/tests/*.dpr') +
                   glob.glob('src/web/*.pas') + glob.glob('src/web/*.dpr'))
    bestaand = bestaande_identifiers(paden)
    kaart, exact, nieuw_gebruikt = {}, {}, {}
    for k, (oud, nieuw) in sorted(voorstel.items()):
        if oud == nieuw:
            continue
        reden = None
        if k in beschermd:
            reden = 'beschermd'
        elif not IDENT.match(nieuw) or nieuw.lower() in KEYWORDS:
            reden = 'ongeldige nieuwe naam'
        elif nieuw.lower() in beschermd:
            reden = 'nieuwe naam is beschermd (%s)' % nieuw
        elif nieuw.lower() != k and nieuw.lower() in bestaand:
            reden = 'nieuwe naam bestaat al in de code (%s)' % nieuw
        elif nieuw.lower() in nieuw_gebruikt and nieuw_gebruikt[nieuw.lower()] != k:
            reden = 'nieuwe naam %s ook gekozen voor %s' % (nieuw, nieuw_gebruikt[nieuw.lower()])
        if reden:
            meldingen.append('%s -> %s overgeslagen: %s' % (oud, nieuw, reden))
            continue
        kaart[k] = nieuw
        exact[oud] = nieuw
        nieuw_gebruikt[nieuw.lower()] = k
    for m in meldingen:
        print('let op:', m)
    print('%d hernoemingen' % len(kaart))
    if droog:
        return
    for pad in paden:
        oud = open(pad, encoding='latin1').read()
        nieuw = hernoem_tekst(oud, kaart, exact)
        if nieuw != oud:
            open(pad, 'w', encoding='latin1').write(nieuw)
    # symbols/names: "Klasse.Methode" en veldnamen
    for pad in glob.glob('symbols/names/*.json'):
        d = json.load(open(pad))

        def naam(s):
            return '.'.join(kaart.get(p.lower(), p) for p in s.split('.'))
        for sectie in ('functions', 'globals'):
            if sectie in d:
                d[sectie] = {a: naam(n) for a, n in d[sectie].items()}
        if 'fields' in d:
            d['fields'] = {kaart.get(c.lower(), c): {o: [kaart.get(x.lower(), x) for x in v]
                                                       for o, v in fl.items()}
                           for c, fl in d['fields'].items()}
        json.dump(d, open(pad, 'w'), indent=2, ensure_ascii=False)
        open(pad, 'a').write('\n')


if __name__ == '__main__':
    main()

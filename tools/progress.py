"""Voortgang van het matchen: per projectunit het deel van de bytes dat in gelijke routines zit.

Gebruikt de vergelijking van tools/diff.py. Een unit telt al haar bytes uit units-1.1.json
(routines plus de stringliterals, RTTI en VMT's die erbij horen, en de "kop" vóór de eerste
routine); een routine telt mee als ze na normalisatie van relocaties gelijk is.

Gebruik: python tools/progress.py ORIG.exe BUILD.exe [--map build/delphi/ROS.map]
                                  [--json uit.json] [--badge uit.svg]
                                  [--tsv ...] [--units ...]
"""
import argparse
import collections
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import diff  # noqa: E402


def per_unit(res, units):
    """{unit: dict(bytes, gelijk_bytes, routines, gelijk_routines)} voor de projectunits, in adresvolgorde."""
    uit = collections.OrderedDict()
    for u in sorted(diff.projectunits(units), key=lambda u: u['start']):
        uit[diff.unitnaam(u)] = dict(bytes=u['end'] - u['start'], gelijk_bytes=0, routines=0, gelijk_routines=0)
    for it in res.items:
        if not it.project or it.orig is None or it.unit not in uit:
            continue
        r = uit[it.unit]
        r['routines'] += 1
        if it.status == 'gelijk':
            r['gelijk_routines'] += 1
            r['gelijk_bytes'] += it.grootte
    return uit


def totaal(rijen):
    t = dict(bytes=0, gelijk_bytes=0, routines=0, gelijk_routines=0)
    for r in rijen.values():
        for k in t:
            t[k] += r[k]
    return t


def procent(r):
    return 100.0 * r['gelijk_bytes'] / r['bytes'] if r['bytes'] else 0.0


def badge(pct):
    """Een eenvoudige SVG-badge in de stijl van shields.io."""
    links, tekst = 'matching', '%.1f%%' % pct
    kleur = '#4c1' if pct >= 99.95 else '#97ca00' if pct >= 75 else '#dfb317' if pct >= 25 else '#e05d44'
    bl, br = 8 + 7 * len(links), 10 + 7 * len(tekst)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="20" role="img" aria-label="{l}: {t}">'
            '<title>{l}: {t}</title>'
            '<rect width="{bl}" height="20" fill="#555"/><rect x="{bl}" width="{br}" height="20" fill="{k}"/>'
            '<g fill="#fff" text-anchor="middle" font-family="Verdana,DejaVu Sans,sans-serif" font-size="11">'
            '<text x="{lx}" y="14">{l}</text><text x="{rx}" y="14">{t}</text></g></svg>\n').format(
                w=bl + br, bl=bl, br=br, k=kleur, l=links, t=tekst, lx=bl / 2, rx=bl + br / 2)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('orig')
    ap.add_argument('build')
    ap.add_argument('--map')
    ap.add_argument('--tsv', default=diff.STANDAARD_TSV)
    ap.add_argument('--units', default=diff.STANDAARD_UNITS)
    ap.add_argument('--json', help='schrijf de cijfers als JSON')
    ap.add_argument('--badge', help='schrijf een SVG-badge')
    args = ap.parse_args()

    res, _, _ = diff.laad(args.orig, args.build, args.map, args.tsv, args.units)
    units = diff.lees_json(args.units)['units']
    rijen = per_unit(res, units)
    t = totaal(rijen)
    print('%-15s %11s %17s %7s' % ('unit', 'routines', 'bytes', ''))
    for naam, r in rijen.items():
        print('%-15s %5d/%-5d %8d/%-8d %6.1f%%' % (naam, r['gelijk_routines'], r['routines'],
                                                  r['gelijk_bytes'], r['bytes'], procent(r)))
    print('%-15s %5d/%-5d %8d/%-8d %6.1f%%' % ('TOTAAL', t['gelijk_routines'], t['routines'],
                                              t['gelijk_bytes'], t['bytes'], procent(t)))
    bestand = bool(res.secties and res.secties[0][3])
    print('bestand: %s' % ('byte-identiek' if bestand else 'verschilt'))
    if args.json:
        with open(args.json, 'w') as f:
            json.dump(dict(units=[dict(unit=n, procent=round(procent(r), 2), **r) for n, r in rijen.items()],
                           totaal=dict(procent=round(procent(t), 2), **t), bestand_gelijk=bestand), f, indent=1)
    if args.badge:
        with open(args.badge, 'w') as f:
            f.write(badge(procent(t)))


if __name__ == '__main__':
    main()

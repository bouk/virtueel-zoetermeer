"""Schrijf een gedetailleerd mapbestand in Delphi-formaat (dcc32 -GD) voor het originele ROS.exe.

Er bestaat geen echt .map van het origineel; dit maakt er een uit symbols/ros-1.1.tsv en
symbols/units-1.1.json, zodat de map-route van tools/diff.py en tools/progress.py zonder Delphi
getest kan worden (origineel tegen zichzelf via het map).

Opgebouwd zoals een Delphi 5-map: segmenttabel, "Detailed map of segments" (één CODE-regel per
unit), "Publics by Name", "Publics by Value" en het startpunt. Namen zijn `Unit.Routine`;
stringliterals en VMT's komen er niet in (dcc32 zet ze ook niet bij de publics).

Gebruik: python tools/maak-testmap.py ROS.exe [-o uit.map] [--tsv ...] [--units ...]
                                      [--zonder-genest] [--weglaten N]
  --zonder-genest   laat geneste routines (Klasse.Methode.Lokaal) weg, zoals een map dat mogelijk doet;
                    diff.py moet ze dan via hun positie koppelen
  --weglaten N      laat bovendien elke N-de projectroutine weg (test van positiekoppeling)
"""
import argparse
import os
import sys

import pefile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import diff  # noqa: E402


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('exe')
    ap.add_argument('-o', '--uit')
    ap.add_argument('--tsv', default=diff.STANDAARD_TSV)
    ap.add_argument('--units', default=diff.STANDAARD_UNITS)
    ap.add_argument('--zonder-genest', action='store_true')
    ap.add_argument('--weglaten', type=int, default=0)
    args = ap.parse_args()

    pe = pefile.PE(args.exe, fast_load=True)
    base = pe.OPTIONAL_HEADER.ImageBase
    segs = []
    for naam, klasse in (('CODE', 'CODE'), ('DATA', 'DATA'), ('BSS', 'BSS'), ('.tls', 'TLS')):
        for s in pe.sections:
            if s.Name.rstrip(b'\0').decode('latin1') == naam:
                segs.append((len(segs) + 1, naam, klasse, base + s.VirtualAddress, s.Misc_VirtualSize))
    units = diff.lees_json(args.units)['units']
    project = {id(u) for u in diff.projectunits(units)}

    def seg_van(a):
        for nr, naam, _, start, grootte in segs:
            if start <= a < start + max(grootte, 1):
                return nr, a - start
        return None

    publics = []
    projectteller = 0
    for s in diff.lees_tsv(args.tsv):
        if s.soort not in ('f', 'd'):
            continue
        plek = seg_van(s.adres)
        if plek is None or (s.soort == 'd' and plek[0] == 1):
            continue      # RTTI-data in CODE staat niet als public in een Delphi-map
        if s.soort == 'f' and args.zonder_genest and s.naam.count('.') >= 2:
            continue
        if s.soort == 'f' and args.weglaten:
            u = next((u for u in units if u['start'] <= s.adres < u['end']), None)
            if u is not None and id(u) in project and not s.naam.endswith(('Initialization', 'Finalization')):
                projectteller += 1
                if projectteller % args.weglaten == 0:
                    continue
        publics.append((plek, s.volledig))

    uit = open(args.uit, 'w', newline='\r\n') if args.uit else sys.stdout
    w = uit.write
    w('\n Start         Length     Name                   Class\n')
    for nr, naam, klasse, _, grootte in segs:
        w(' %04X:%08X %08XH %-22s %s\n' % (nr, 0, grootte, naam, klasse))
    w('\n\nDetailed map of segments\n\n')
    code = segs[0]
    for u in sorted(units, key=lambda u: u['start']):
        w(' %04X:%08X %08X C=CODE     S=.text    G=(none)   M=%-10s ACBP=A9\n'
          % (code[0], u['start'] - code[3], u['end'] - u['start'], diff.unitnaam(u)))
    w('\n\n  Address         Publics by Name\n\n')
    for (nr, ofs), naam in sorted(publics, key=lambda p: p[1].lower()):
        w(' %04X:%08X       %s\n' % (nr, ofs, naam))
    w('\n\n  Address         Publics by Value\n\n')
    for (nr, ofs), naam in sorted(publics):
        w(' %04X:%08X       %s\n' % (nr, ofs, naam))
    entry = base + pe.OPTIONAL_HEADER.AddressOfEntryPoint
    w('\n\nProgram entry point at %04X:%08X\n' % (code[0], entry - code[3]))
    if args.uit:
        uit.close()


if __name__ == '__main__':
    main()

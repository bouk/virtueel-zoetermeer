"""Voeg de naamkaarten per unit (symbols/names/*.json) samen tot symbool- en veldtabellen.

Gebruik: python tools/merge_names.py symbols/names build/names.tsv build/fields.tsv

De rijen van names.tsv gebruiken het formaat van symbols.py (adres, soort, unit, naam) en
worden met de hoogste prioriteit toegepast; de rijen van fields.tsv zijn: klasse, offset, naam, type.
"""
import glob
import json
import os
import sys


def main():
    names_dir, names_out, fields_out = sys.argv[1:4]
    funcs, globs, fields = {}, {}, {}
    for path in sorted(glob.glob(os.path.join(names_dir, '*.json'))):
        unit = os.path.splitext(os.path.basename(path))[0]
        d = json.load(open(path))
        for a, n in d.get('functions', {}).items():
            funcs[int(a, 16)] = (unit, n)
        for a, n in d.get('globals', {}).items():
            globs[int(a, 16)] = (unit, n)
        for cls, fl in d.get('fields', {}).items():
            for ofs, (name, typ) in fl.items():
                fields[(cls, int(ofs, 16))] = (name, typ)
    with open(names_out, 'w') as f:
        for a, (unit, n) in sorted(funcs.items()):
            f.write('%08x\tf\t%s\t%s\n' % (a, unit, n))
        for a, (unit, n) in sorted(globs.items()):
            f.write('%08x\td\t%s\t%s\n' % (a, unit, n))
    with open(fields_out, 'w') as f:
        for (cls, ofs), (name, typ) in sorted(fields.items()):
            f.write('%s\t%d\t%s\t%s\n' % (cls, ofs, name, typ))


if __name__ == '__main__':
    main()

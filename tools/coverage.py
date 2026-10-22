"""Dekking van de decompilatie: welke routines van de projectunits Pascal-bron hebben.

Een routine telt als gedekt wanneer src/game een `{ @ADRES }`-annotatie bevat voor het
startadres; de routine-ingangen komen uit de Ghidra-export (koppen van build/decomp-<ver>/*.c).
Niet-geannoteerde initialisatie-/finalisatiestubs van units zijn door de compiler gegenereerd
en worden overgeslagen.

Gebruik: python tools/coverage.py [1.1]        (drukt een tabel per unit en de ontbrekende routines af)
"""
import glob
import os
import re
import sys

ver = sys.argv[1] if len(sys.argv) > 1 else '1.1'
root = os.path.join(os.path.dirname(__file__), '..')

annotated = set()
for path in glob.glob(os.path.join(root, 'src/game/*.pas')) + glob.glob(os.path.join(root, 'src/game/*.dpr')):
    for m in re.finditer(r'\{\s*@([0-9A-Fa-f]{8})\b', open(path, encoding='latin1').read()):
        annotated.add(int(m.group(1), 16))

total_b = covered_b = 0
missing = []
rows = []
for path in sorted(glob.glob(os.path.join(root, 'build/decomp-%s/*.c' % ver))):
    unit = os.path.splitext(os.path.basename(path))[0]
    funcs = [(m.group(1), int(m.group(2), 16), int(m.group(3)))
             for m in re.finditer(r'^// (\S+) @ ([0-9a-f]{8}) \((\d+) bytes\)', open(path).read(), re.M)]
    if not funcs:
        continue
    # Initialisatie-/finalisatiestubs van units worden door de compiler gegenereerd (InitCount-administratie,
    # het finaliseren van beheerde globals); ze hebben alleen bron nodig als de unit zulke secties heeft.
    stubs = [f for f in funcs if f[0].endswith(('.Initialization', '.Finalization')) and f[1] not in annotated]
    funcs = [f for f in funcs if f not in stubs]
    cov = [f for f in funcs if f[1] in annotated]
    ub = sum(f[2] for f in funcs)
    cb = sum(f[2] for f in cov)
    total_b += ub
    covered_b += cb
    rows.append((unit, len(cov), len(funcs), cb, ub))
    missing += [(unit, name, a, n) for name, a, n in funcs if a not in annotated]

print('%-15s %9s %15s' % ('unit', 'routines', 'bytes'))
for unit, nc, nf, cb, ub in rows:
    print('%-15s %4d/%-4d %7d/%-7d %5.1f%%' % (unit, nc, nf, cb, ub, 100.0 * cb / max(ub, 1)))
print('%-15s %9s %7d/%-7d %5.1f%%' % ('TOTAL', '', covered_b, total_b, 100.0 * covered_b / max(total_b, 1)))
if missing:
    print('\nRoutines zonder { @ADDR } in src/game:')
    for unit, name, a, n in missing:
        print('  %-14s %08x %5d  %s' % (unit, a, n, name))

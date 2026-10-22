"""Bepaal per unit welke zelfbedachte identifiers naar het Nederlands vertaald mogen worden.

Kandidaten zijn namen die een unit in src/game op unitniveau declareert (typen, klasseleden,
globale variabelen en constanten, routines) en die niet beschermd zijn (zie
tools/beschermde-namen.py). Lokale variabelen, parameters en geneste routines horen hier
niet bij: die hernoemt de vertaler binnen de routine zelf.

Gebruik: python tools/vertaal-kandidaten.py build/beschermd.txt build/vertaling
  schrijft build/vertaling/<Unit>.kandidaten.txt
"""
import glob
import os
import re
import sys

KEYWORDS = set('''and array as asm begin case class const constructor destructor div do downto
else end except exports file finalization finally for function goto if implementation in inherited
initialization inline interface is label library mod nil not object of or out packed procedure
program property raise record repeat resourcestring set shl shr string then threadvar to try type
unit until uses var while with xor private protected public published override virtual abstract
overload message dynamic default read write stored index absolute forward external cdecl stdcall
register pascal safecall reintroduce'''.split())

ROUTINE = re.compile(r'^(?:class\s+)?(procedure|function|constructor|destructor)\s+(?:\w+\.)?(\w+)', re.I)


def strip(regel):
    regel = re.sub(r"'(?:[^']|'')*'", "''", regel)
    regel = re.sub(r'//.*', '', regel)
    return regel


def kandidaten(pad):
    tekst = open(pad, encoding='latin1').read()
    tekst = re.sub(r'\{[^}]*\}|\(\*.*?\*\)', lambda m: '\n' * m.group(0).count('\n'), tekst, flags=re.S)
    namen = []
    in_routine = False
    sectie = None
    for ruw in tekst.split('\n'):
        regel = strip(ruw).rstrip()
        if not regel.strip():
            continue
        kol0 = not regel[0].isspace()
        woorden = regel.strip().lower()
        if kol0 and ROUTINE.match(regel):
            m = ROUTINE.match(regel)
            namen.append(m.group(2))
            in_routine = not regel.rstrip().endswith('forward;') and 'external' not in woorden
            continue
        if in_routine:
            if kol0 and woorden.startswith('end;'):
                in_routine = False
            continue
        if kol0 and woorden.split()[0] in ('type', 'var', 'const', 'threadvar', 'resourcestring'):
            sectie = woorden.split()[0]
            rest = regel.strip()[len(sectie):].strip()
            if not rest:
                continue
            regel = '  ' + rest
        elif kol0 and woorden.split()[0] in ('implementation', 'interface', 'initialization',
                                             'finalization', 'begin', 'uses', 'unit', 'program'):
            sectie = None
            continue
        if sectie is None:
            continue
        s = regel.strip()
        m = ROUTINE.match(s)
        if m:
            namen.append(m.group(2))
            continue
        m = re.match(r'property\s+(\w+)', s, re.I)
        if m:
            namen.append(m.group(1))
            continue
        m = re.match(r'(\w+(?:\s*,\s*\w+)*)\s*:\s*[^=]', s)
        if m:
            namen += [n.strip() for n in m.group(1).split(',')]
            continue
        m = re.match(r'(\w+)\s*=', s)
        if m:
            namen.append(m.group(1))
    return namen


def main():
    beschermd = {l.strip().lower() for l in open(sys.argv[1]) if l.strip()}
    uit = sys.argv[2]
    os.makedirs(uit, exist_ok=True)
    gezien = {}
    for pad in sorted(glob.glob('src/game/*.pas')):
        unit = os.path.splitext(os.path.basename(pad))[0]
        lijst = []
        for n in kandidaten(pad):
            if n.lower() in KEYWORDS or n.lower() in beschermd or len(n) < 2:
                continue
            if n not in lijst:
                lijst.append(n)
            gezien.setdefault(n, unit)
        with open(os.path.join(uit, unit + '.kandidaten.txt'), 'w') as f:
            f.write('\n'.join(lijst) + '\n')
        print('%-14s %3d' % (unit, len(lijst)))


if __name__ == '__main__':
    main()

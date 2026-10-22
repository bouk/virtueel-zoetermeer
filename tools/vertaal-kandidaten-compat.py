"""Kandidaten voor Nederlandse namen in de compat-laag (src/compat, src/web).

Beschermd blijft de Delphi/VCL/Win32-API: alles in de interface van de units die de Delphi 5-
units nabootsen (Windows, Messages, Graphics, Controls, Forms, ...), plus de RTL-namen uit
tools/beschermde-namen.py. (De compat-laag gebruikt geen namen uit de spelcode.) Kandidaat zijn de zelfbedachte namen:
de interface van de eigen ZM*-units en alles wat alleen in een implementatiegedeelte staat.

Gebruik: python tools/vertaal-kandidaten-compat.py build/vertaling-compat
"""
import glob
import importlib.util
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(__file__), '..')


def laad(naam, bestand):
    spec = importlib.util.spec_from_file_location(naam, os.path.join(ROOT, 'tools', bestand))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


kand = laad('kand', 'vertaal-kandidaten.py')
besch = laad('besch', 'beschermde-namen.py')

VCL = ['Windows', 'Messages', 'MMSystem', 'ddraw', 'Graphics', 'Controls', 'Forms', 'StdCtrls',
       'ExtCtrls', 'Buttons', 'ComCtrls', 'Dialogs', 'FileCtrl', 'Menus', 'Grids', 'ImgList',
       'IniFiles', 'SDL3']


def main():
    uit = sys.argv[1]
    os.makedirs(uit, exist_ok=True)
    beschermd = {n.lower() for n in besch.RTL}
    for unit in VCL:
        for pad in glob.glob(os.path.join(ROOT, 'src/compat/**/%s.pas' % unit), recursive=True):
            beschermd |= {n.lower() for n in besch.interface_names(pad)}
    with open(os.path.join(uit, 'beschermd.txt'), 'w') as f:
        f.write('\n'.join(sorted(beschermd)) + '\n')
    paden = sorted(glob.glob(os.path.join(ROOT, 'src/compat/**/*.pas'), recursive=True) +
                   glob.glob(os.path.join(ROOT, 'src/web/*.pas')))
    for pad in paden:
        unit = os.path.splitext(os.path.basename(pad))[0]
        lijst = []
        for n in kand.kandidaten(pad):
            if n.lower() in kand.KEYWORDS or n.lower() in beschermd or len(n) < 3:
                continue
            if n not in lijst:
                lijst.append(n)
        with open(os.path.join(uit, unit + '.kandidaten.txt'), 'w') as f:
            f.write('\n'.join(lijst) + ('\n' if lijst else ''))
        print('%-16s %3d' % (unit, len(lijst)))


if __name__ == '__main__':
    main()

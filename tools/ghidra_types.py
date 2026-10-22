"""Schrijf klasse-indelingen voor Ghidra: uit VMT's afgeleide groottes/ouders plus bekende veldnamen.

Gebruik: python tools/ghidra_types.py ROS.exe build/fields.tsv [kb5.bin] > build/ghidra-types.tsv
Rijen:  C <klasse> <instantiegrootte> <ouder>
       F <klasse> <offset> <naam> <pascal-type>
"""
import sys

import delphi
import idrkb
import units


def main():
    im = delphi.Image(sys.argv[1])
    vmts = im.find_vmts()
    fields = {}
    for v in vmts.values():
        for ofs, idx, name in v.published_fields:
            cls = vmts.get(v.field_classes[idx]) if idx < len(v.field_classes) else None
            fields[(v.name, ofs)] = (name, cls.name if cls else 'TObject')
    # Velden van bibliotheekklassen (VCL/RTL) uit de IDR-kennisbank.
    if len(sys.argv) > 3:
        kb = idrkb.KnowledgeBase(sys.argv[3])
        linked = {n.lower() for n in units.package_units(im)}
        for cls, fl in kb.class_fields(linked).items():
            for ofs, name, typ in fl:
                fields.setdefault((cls, ofs), (name, typ.split('.')[-1]))
    if len(sys.argv) > 2:
        for line in open(sys.argv[2]):
            cls, ofs, name, typ = line.rstrip('\n').split('\t')
            fields[(cls, int(ofs))] = (name, typ)
    by_name = {v.name: v for v in vmts.values()}
    for v in sorted(vmts.values(), key=lambda m: m.addr):
        parent = vmts.get(v.parent)
        print('C\t%s\t%d\t%s' % (v.name, v.instance_size, parent.name if parent else ''))
    for (cls, ofs), (name, typ) in sorted(fields.items()):
        if cls in by_name:
            print('F\t%s\t%d\t%s\t%s' % (cls, ofs, name, typ))


if __name__ == '__main__':
    main()

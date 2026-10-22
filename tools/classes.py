"""Schrijf een Markdown-catalogus van elke projectklasse die uit VMT's en RTTI is hersteld.

Gebruik: python tools/classes.py ROS.exe units.json symbols.tsv > symbols/classes.md
"""
import json
import sys

import delphi

TYPE_KINDS = ['tkUnknown', 'tkInteger', 'tkChar', 'tkEnumeration', 'tkFloat', 'tkString', 'tkSet',
              'tkClass', 'tkMethod', 'tkWChar', 'tkLString', 'tkWString', 'tkVariant', 'tkArray',
              'tkRecord', 'tkInterface', 'tkInt64', 'tkDynArray']


def typeinfo_name(im, pp):
    """PropType is een PPTypeInfo (pointer naar pointer)."""
    if not pp or not im.valid(pp):
        return '?'
    ti = im.u32(pp)
    if not ti or not im.valid(ti):
        return '?'
    return im.sstr(ti + 1)


def props(im, vmt):
    ti = vmt.type_info
    if not ti or im.u8(ti) != 7:
        return
    p = ti + 2 + im.u8(ti + 1) + 4 + 4 + 2
    p += 1 + im.u8(p)
    n = im.u16(p); p += 2
    for _ in range(n):
        ptype, get, set_, stored, index, default, nameidx = (
            im.u32(p), im.u32(p + 4), im.u32(p + 8), im.u32(p + 12),
            im.i32(p + 16), im.i32(p + 20), im.u16(p + 24))
        name = im.sstr(p + 26)
        yield name, typeinfo_name(im, ptype), get, set_, default
        p += 26 + 1 + len(name)


def accessor(v, syms):
    if v == 0:
        return '-'
    if v >> 24 == 0xFF:
        return 'field +%#x' % (v & 0xFFFFFF)
    if v >> 24 == 0xFE:
        return 'virtual slot +%#x' % (v & 0xFFFF)
    return syms.get(v, '%#x' % v)


def main():
    im = delphi.Image(sys.argv[1])
    units = json.load(open(sys.argv[2]))['units']
    syms = {}
    for line in open(sys.argv[3]):
        a, kind, _unit, name = line.rstrip('\n').split('\t')
        if kind != 's':
            syms[int(a, 16)] = name
    vmts = im.find_vmts()

    def unit_of(va):
        for u in units:
            if u['start'] <= va < u['end']:
                return u
        return None

    print('# Projectklassen (hersteld uit VMT en RTTI)\n')
    print('Offsets zijn hexadecimaal. Veldoffsets tellen de VMT-pointer op +0 mee.\n')
    for v in sorted(vmts.values(), key=lambda m: m.addr):
        u = unit_of(v.addr)
        if u is None or u['library']:
            continue
        parent = vmts.get(v.parent)
        print('## %s = class(%s)  — unit %s\n' % (v.name, parent.name if parent else '?', u['name'] or 'Unit%d' % u['init_order']))
        print('- VMT: `%#x`, instance size: `%#x` (parent: `%#x`)' % (
            v.addr, v.instance_size, parent.instance_size if parent else 0))
        if v.published_fields:
            print('- Gepubliceerde velden:')
            for ofs, idx, name in v.published_fields:
                cls = vmts.get(v.field_classes[idx]).name if idx < len(v.field_classes) and v.field_classes[idx] in vmts else '?'
                print('  - `+%#x` %s: %s' % (ofs, name, cls))
        if v.published_methods:
            print('- Gepubliceerde methoden:')
            for addr, name in v.published_methods:
                print('  - `%#x` %s' % (addr, name))
        pl = list(props(im, v))
        if pl:
            print('- Gepubliceerde properties:')
            for name, tname, get, set_, default in pl:
                d = '' if default == -2147483648 else ' default %d' % default
                print('  - %s: %s read %s write %s%s' % (name, tname, accessor(get, syms), accessor(set_, syms), d))
        std = []
        for i, slot in enumerate(v.std_virtuals):
            if parent is None or parent.std_virtuals[i] != slot:
                std.append('%s=`%#x`' % (delphi.VMT_STD_VIRTUALS[i], slot))
        if std:
            print('- Overrides van TObject-virtuals: ' + ', '.join(std))
        if v.virtuals:
            print('- Virtuele-methodetabel (slotoffset, adres, status):')
            for i, slot in enumerate(v.virtuals):
                inherited = parent is not None and i < len(parent.virtuals) and parent.virtuals[i] == slot
                status = 'geërfd' if inherited else ('override' if parent and i < len(parent.virtuals) else 'NIEUW')
                if inherited:
                    continue
                origin = ''
                if status == 'override':
                    anc = v
                    while anc.parent in vmts and i < len(vmts[anc.parent].virtuals):
                        anc = vmts[anc.parent]
                    origin = ' (slot introduced by %s: %s)' % (anc.name, syms.get(anc.virtuals[i], '%#x' % anc.virtuals[i]))
                print('  - `+%#04x` `%#x` %s %s%s' % (i * 4, slot, status, syms.get(slot, ''), origin))
            n_inh = sum(1 for i, s in enumerate(v.virtuals)
                        if parent and i < len(parent.virtuals) and parent.virtuals[i] == s)
            print('  - (%d geërfde slots weggelaten)' % n_inh)
        if v.dynamic_methods:
            print('- Dynamische/message-methoden: ' + ', '.join('%#x→`%#x`' % (i, a) for i, a in v.dynamic_methods))
        print()


if __name__ == '__main__':
    main()

"""Herstel unitgrenzen en -namen voor een Delphi 5-programma.

De initialisatieprocedure van elke unit staat als laatste routine in de code van die unit,
dus het sorteren van de InitTable-ingangen op adres levert de unitgrenzen op. Namen komen uit:
  * klasse-RTTI (tkClass-typegegevens bevatten de naam van de declarerende unit)
  * overeenkomsten met IDR-kennisbankhandtekeningen (dominante bibliotheekmodule binnen het bereik)
  * de unitlijst van PACKAGEINFO, voor eliminatie

Gebruik: python tools/units.py ROS.exe kb5.bin [names.json] > symbols/units.json

names.json koppelt init-tabelindex -> unitnaam voor units die de heuristieken niet kunnen benoemen.
"""
import collections
import json
import struct
import sys

import capstone

import delphi
import idrkb
import kbmatch


def proc_end(im, start):
    """Lineaire doorloop van een routine; stop bij een ret/jmp voorbij elk voorwaarts vertakkingsdoel."""
    md = capstone.Cs(capstone.CS_ARCH_X86, capstone.CS_MODE_32)
    md.detail = True
    code = bytes(im.bytes(start, 0x4000))
    reach = start
    for ins in md.disasm(code, start):
        end = ins.address + ins.size
        if ins.group(capstone.CS_GRP_JUMP) or ins.group(capstone.CS_GRP_CALL):
            op = ins.operands[0] if ins.operands else None
            if op is not None and op.type == capstone.x86.X86_OP_IMM and ins.group(capstone.CS_GRP_JUMP):
                if start <= op.imm < start + 0x4000:
                    reach = max(reach, op.imm)
        if ins.mnemonic in ('ret', 'jmp') and end > reach:
            return end
    raise ValueError('geen einde voor proc bij %#x' % start)


def align4(x):
    return (x + 3) & ~3


def package_units(im):
    pe = im.pe
    for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if t.id != 10:
            continue
        for n in t.directory.entries:
            if str(n.name) == 'PACKAGEINFO':
                d = n.directory.entries[0].data.struct
                b = pe.get_data(d.OffsetToData, d.Size)
    _flags, req = struct.unpack_from('<II', b, 0)
    o = 8
    for _ in range(req):
        o = b.index(b'\0', o + 1) + 1
    cnt, = struct.unpack_from('<I', b, o); o += 4
    names = []
    for _ in range(cnt):
        o += 2
        e = b.index(b'\0', o)
        names.append(b[o:e].decode('latin1'))
        o = e + 1
    return names


def class_unit(im, vmt):
    ti = vmt.type_info
    if not ti:
        return None
    name = im.sstr(ti + 1)
    return im.sstr(ti + 2 + len(name) + 10)


def string_literals(im, start, end):
    """Delphi long-string-constanten: refcount -1, lengte, tekens, NUL."""
    out = []
    b = bytes(im.bytes(start, end - start))
    i = b.find(b'\xff\xff\xff\xff')
    while i != -1:
        if i % 4 == 0 and i + 8 < len(b):
            n, = struct.unpack_from('<I', b, i + 4)
            s = b[i + 8:i + 8 + n]
            if 0 < n < 512 and len(s) == n and b[i + 8 + n:i + 9 + n] == b'\0':
                out.append(s.decode('latin1'))
        i = b.find(b'\xff\xff\xff\xff', i + 4)
    return out


def main():
    im = delphi.Image(sys.argv[1])
    kb = idrkb.KnowledgeBase(sys.argv[2])
    overrides = json.load(open(sys.argv[3])) if len(sys.argv) > 3 else {}
    code = bytes(im.bytes(im.code_start, im.code_end - im.code_start))
    linked = {n.lower() for n in package_units(im)}
    procs = [p for p in kb.procs() if kb.modules[p.module_id].lower() in linked]
    matches = dict(kbmatch.scan(code, kbmatch.build_index(procs)))

    # Bytes die door niet-triviale bibliotheekhandtekeningen gedekt worden, per module.
    covered = {}
    for pos, hits in matches.items():
        mods = {kb.modules[h.module_id] for h in hits}
        size = max(len(h.dump) for h in hits)
        if len(mods) == 1 and size >= 16:
            mod = mods.pop()
            for i in range(pos, pos + size):
                covered[im.code_start + i] = mod

    entries = sorted((init, final, order) for order, (init, final) in enumerate(im.init_table()) if init)
    vmts = sorted(im.find_vmts().values(), key=lambda m: m.addr)
    units = []
    start = im.code_start
    for init, final, order in entries:
        end = align4(proc_end(im, init))
        units.append(dict(start=start, end=end, init=init, final=final, init_order=order))
        start = end
    # Het hoofdblok van het programma loopt van de laatste unit tot het einde van CODE.
    units.append(dict(start=start, end=im.code_end, init=None, final=None, init_order=None))

    known = {n.lower(): n for n in package_units(im)}
    kb_names = ({m.lower() for m in kb.modules.values()} & linked) | {'sysinit', 'system'}
    for u in units:
        start, end = u['start'], u['end']
        in_range = [m for m in vmts if start <= m.addr < end]
        rtti = collections.Counter(class_unit(im, m) for m in in_range)
        rtti.pop(None, None)
        kbmods = collections.Counter(covered[a] for a in range(start, end) if a in covered)
        init_kb = {h.name for h in matches.get((u['init'] or 0) - im.code_start, [])
                   if h.name.lower() == kb.modules[h.module_id].lower()}
        u.update(classes=[m.name for m in in_range], rtti_units=dict(rtti),
                 kb_modules=dict(kbmods.most_common(3)), kb_bytes=sum(kbmods.values()),
                 strings=string_literals(im, start, end)[:20])

        name = overrides.get(str(u['init_order']))
        forced_lib = name == '!library'
        if forced_lib:
            name = None
        if u['init_order'] is None:
            name = name or 'Ros'
        elif name is None and len(init_kb) == 1:
            name = init_kb.pop()
        elif name is None and len(rtti) == 1:
            name = next(iter(rtti))
        elif name is None and kbmods:
            top, nbytes = kbmods.most_common(1)[0]
            if nbytes > 0.5 * (end - start):
                name = top
        u['name'] = known.get(name.lower(), name) if name else None
        u['library'] = forced_lib or (name or '').lower() in kb_names or (
            name is None and not in_range and u['kb_bytes'] > 0.3 * (end - start))

    json.dump(dict(package_units=package_units(im), units=units), sys.stdout, indent=1)


if __name__ == '__main__':
    main()

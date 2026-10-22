"""Build a symbol table for a Delphi 5 executable.

Sources, in decreasing priority:
  * RTTI: published methods, property getters/setters, class VMTs
  * VMT virtual slots (named after the overriding class)
  * IDR knowledge-base signature matches (library units only)
  * unit initialization/finalization procs

Usage: python tools/symbols.py ROS.exe kb5.bin units.json [names.tsv] > symbols/ros.tsv
Output columns: address  kind  unit  name
  kind: f = function, d = data label, v = VMT, s = string literal (name = length)
"""
import json
import struct
import sys

import delphi
import idrkb
import kbmatch
import units as units_mod

TK_CLASS = 7


def class_props(im, vmt):
    """Yield (name, get, set) for the published properties declared by this class."""
    ti = vmt.type_info
    if not ti or im.u8(ti) != TK_CLASS:
        return
    p = ti + 2 + im.u8(ti + 1)
    p += 4 + 4                       # ClassType, ParentInfo
    p += 2                           # PropCount (total, incl. inherited)
    p += 1 + im.u8(p)                # UnitName
    n = im.u16(p); p += 2            # props declared in this class
    for _ in range(n):
        get, set_ = im.u32(p + 4), im.u32(p + 8)
        name = im.sstr(p + 26)
        yield name, get, set_
        p += 26 + 1 + len(name)


def main():
    im = delphi.Image(sys.argv[1])
    kb = idrkb.KnowledgeBase(sys.argv[2])
    units = json.load(open(sys.argv[3]))['units']

    def unit_at(va):
        for u in units:
            if u['start'] <= va < u['end']:
                return u
        return None

    syms = {}

    def add(va, kind, name, prio):
        if not (im.in_code(va) or (kind == 'd' and im.valid(va))):
            return
        old = syms.get(va)
        if old is None or prio > old[2]:
            syms[va] = (kind, name, prio)

    for u in units:
        uname = u['name'] or 'Unit%s' % u['init_order']
        if u['init']:
            add(u['init'], 'f', '%s.Initialization' % uname, 50)
        if u['final']:
            add(u['final'], 'f', '%s.Finalization' % uname, 50)

    def section_range(name):
        sec = im.sections[name]
        return im.base + sec.VirtualAddress, im.base + sec.VirtualAddress + sec.Misc_VirtualSize

    data_lo, data_hi = section_range('DATA')
    bss_lo, bss_hi = section_range('BSS')

    def in_data(va):
        return data_lo <= va < data_hi

    def in_bss(va):
        return bss_lo <= va < bss_hi

    code = bytes(im.bytes(im.code_start, im.code_end - im.code_start))
    linked = {n.lower() for n in units_mod.package_units(im)}
    procs = [p for p in kb.procs() if kb.modules[p.module_id].lower() in linked]
    for pos, hits in kbmatch.scan(code, kbmatch.build_index(procs)):
        va = im.code_start + pos
        u = unit_at(va)
        if not u or not u.get('library'):
            continue
        uname = (u['name'] or '').lower()
        local = [h for h in hits if kb.modules[h.module_id].lower() == uname]
        cands = local or hits
        names = {h.name for h in cands}
        if len(names) != 1:
            longest = max(cands, key=lambda h: len(h.dump))
            if sum(1 for h in cands if len(h.dump) == len(longest.dump)) > 1:
                continue
            names = {longest.name}
        name = names.pop()
        mod = kb.modules[cands[0].module_id]
        if not local and len(cands[0].dump) < 24:
            continue      # short generic match from a foreign module: too unreliable
        prio = 80 if local else 40
        add(va, 'f', name if '.' in name or name.startswith('@') else '%s.%s' % (mod, name), prio)
        # Absolute fixups that point outside CODE name the globals this routine uses.
        if local:
            for p in cands[:1]:
                for fx in p.fixups:
                    if fx.kind not in ('A', 'D') or fx.name.startswith(('_D', '_NF_')) or fx.name == p.name:
                        continue
                    target = im.u32(va + fx.ofs)
                    if not im.valid(target) or im.in_code(target):
                        continue
                    pointee = im.u32(target) if in_data(target) else 0
                    if in_data(target) and in_bss(pointee):
                        add(target, 'd', 'PTR_' + fx.name, 31)
                        add(pointee, 'd', fx.name, 31)
                    else:
                        add(target, 'd', fx.name, 30)

    vmts = im.find_vmts()

    kb_slots = kb.vmt_slots()

    def slot_method(v, i):
        """Name of the method that the root-most ancestor declared at virtual slot i."""
        chain = []
        while v is not None:
            chain.append(v)
            v = vmts.get(v.parent)
        for anc in chain:
            known = kb_slots.get(anc.name, {}).get(i * 4) if i < len(anc.virtuals) else None
            if known and known != '(abstract)':
                return known.split('.')[-1]
        for anc in reversed(chain):
            if i < len(anc.virtuals):
                known = syms.get(anc.virtuals[i])
                if known and known[0] == 'f' and '.Virtual' not in known[1] and 'AbstractError' not in known[1]:
                    return known[1].split('.')[-1]
                return None
        return None

    for v in sorted(vmts.values(), key=lambda m: m.addr):
        add(v.addr, 'v', 'VMT_%s' % v.name, 100)
        parent = vmts.get(v.parent)
        for i, slot in enumerate(v.virtuals):
            if parent is None or i >= len(parent.virtuals) or parent.virtuals[i] != slot:
                method = slot_method(v, i)
                if method:
                    add(slot, 'f', '%s.%s' % (v.name, method), 65)
                else:
                    add(slot, 'f', '%s.Virtual%02X' % (v.name, i * 4), 20)
        for i, slot in enumerate(v.std_virtuals):
            if parent is None or parent.std_virtuals[i] != slot:
                add(slot, 'f', '%s.%s' % (v.name, delphi.VMT_STD_VIRTUALS[i]), 60)
        for addr, name in v.published_methods:
            add(addr, 'f', '%s.%s' % (v.name, name), 90)
        for idx, addr in v.dynamic_methods:
            add(addr, 'f', '%s.Dynamic%04X' % (v.name, idx), 25)
        for name, get, set_ in class_props(im, v):
            if get and (get >> 24) != 0xFF and im.in_code(get):
                add(get, 'f', '%s.Get%s' % (v.name, name), 70)
            if set_ and (set_ >> 24) != 0xFF and im.in_code(set_):
                add(set_, 'f', '%s.Set%s' % (v.name, name), 70)

    # Names assigned during decompilation (tools/merge_names.py) win over everything else.
    if len(sys.argv) > 4:
        for line in open(sys.argv[4]):
            a, kind, _unit, name = line.rstrip('\n').split('\t')
            add(int(a, 16), kind, name, 95)

    # Delphi reaches another unit's globals through a pointer stored in DATA.
    data = im.sections['DATA']
    lo = im.base + data.VirtualAddress
    for va in range(lo, lo + data.Misc_VirtualSize - 3, 4):
        t = im.u32(va)
        if t in syms and syms[t][0] == 'd' and va not in syms:
            add(va, 'd', 'PTR_' + syms[t][1], 10)

    # Delphi long-string literals (refcount -1, length, chars): code references point at
    # the characters, so mark those as strings.
    for u in units:
        b = bytes(im.bytes(u['start'], u['end'] - u['start']))
        i = b.find(b'\xff\xff\xff\xff')
        while i != -1:
            if i % 4 == 0 and i + 8 < len(b):
                n, = struct.unpack_from('<I', b, i + 4)
                if 0 < n < 4096 and b[i + 8 + n:i + 9 + n] == b'\0':
                    va = u['start'] + i + 8
                    if va not in syms:
                        syms[va] = ('s', str(n), 0)
            i = b.find(b'\xff\xff\xff\xff', i + 4)

    for va in sorted(syms):
        kind, name, _ = syms[va]
        u = unit_at(va)
        print('%08x\t%s\t%s\t%s' % (va, kind, (u['name'] or 'Unit%s' % u['init_order']) if u else '', name))


if __name__ == '__main__':
    main()

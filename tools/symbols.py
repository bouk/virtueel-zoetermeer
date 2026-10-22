"""Build a symbol table for a Delphi 5 executable.

Sources, in decreasing priority:
  * RTTI: published methods, property getters/setters, class VMTs
  * VMT virtual slots (named after the overriding class)
  * IDR knowledge-base signature matches (library units only)
  * unit initialization/finalization procs

Usage: python tools/symbols.py ROS.exe kb5.bin units.json > symbols/ros.tsv
Output columns: address  kind  unit  name
  kind: f = function, d = data label, v = VMT
"""
import json
import sys

import delphi
import idrkb
import kbmatch

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
        if not im.in_code(va):
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

    vmts = im.find_vmts()
    for v in vmts.values():
        add(v.addr, 'v', 'VMT_%s' % v.name, 100)
        parent = vmts.get(v.parent)
        for i, slot in enumerate(v.virtuals):
            if parent is None or i >= len(parent.virtuals) or parent.virtuals[i] != slot:
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

    code = bytes(im.bytes(im.code_start, im.code_end - im.code_start))
    for pos, hits in kbmatch.scan(code, kbmatch.build_index(kb.procs())):
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

    for va in sorted(syms):
        kind, name, _ = syms[va]
        u = unit_at(va)
        print('%08x\t%s\t%s\t%s' % (va, kind, (u['name'] or 'Unit%s' % u['init_order']) if u else '', name))


if __name__ == '__main__':
    main()

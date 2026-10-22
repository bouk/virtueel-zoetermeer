"""Reader for IDR (Interactive Delphi Reconstructor) knowledge base files (kb*.bin).

Format reverse-engineered from IDR's KnowledgeBase.cpp (crypto2011/IDR, GPL).
Only the parts needed for code signature matching are decoded: modules and procs.
"""
import struct
from dataclasses import dataclass, field


@dataclass
class Fixup:
    kind: str        # 'A' absolute address, 'J' relative jump/call, 'D' data
    ofs: int
    name: str


@dataclass
class Proc:
    idx: int
    module_id: int
    name: str
    embedded: int
    dump_type: str   # 'C' code, 'D' data
    method_kind: str
    call_kind: int
    vproc: int
    typedef: str
    dump: bytes
    relocs: bytes    # per-byte mask, nonzero where the byte is part of a fixup
    fixups: list = field(default_factory=list)


def _cstr(b, p):
    n, = struct.unpack_from('<H', b, p)
    return b[p + 2:p + 2 + n].decode('latin1'), p + 2 + n + 1


@dataclass
class Const:
    idx: int
    module_id: int
    name: str
    kind: str        # 'C' const, 'P' VMT, 'V' typed const/var
    typedef: str
    value: str
    dump: bytes
    relocs: bytes
    fixups: list = field(default_factory=list)



class KnowledgeBase:
    def __init__(self, path):
        b = self.b = open(path, 'rb').read()
        sig = b[:24].split(b'\0')[0]
        if sig not in (b'IDR Knowledge Base File', b'IDD Knowledge Base File'):
            raise ValueError('not an IDR knowledge base: %r' % sig)
        self.delphi_ver, = struct.unpack_from('<i', b, 25)
        p, = struct.unpack_from('<I', b, len(b) - 4)

        def section():
            nonlocal p
            count, _maxsize = struct.unpack_from('<II', b, p)
            p += 8
            offs = [struct.unpack_from('<IIii', b, p + 16 * i) for i in range(count)]
            p += 16 * count
            return offs

        self.module_offs = section()
        self.const_offs = section()
        self.type_offs = section()
        self.var_offs = section()
        self.resstr_offs = section()
        self.proc_offs = section()

        self.modules = {}
        for off, _size, _modid, _namid in self.module_offs:
            mid, = struct.unpack_from('<H', b, off)
            name, _ = _cstr(b, off + 2)
            self.modules[mid] = name

    def __len__(self):
        return len(self.proc_offs)

    def proc(self, idx):
        b = self.b
        p = self.proc_offs[idx][0]
        module_id, = struct.unpack_from('<H', b, p); p += 2
        name, p = _cstr(b, p)
        embedded, dump_type, method_kind, call_kind = b[p], chr(b[p + 1]), chr(b[p + 2]), b[p + 3]
        p += 4
        vproc, = struct.unpack_from('<i', b, p); p += 4
        typedef, p = _cstr(b, p)
        _dump_total, dump_sz, fixup_num = struct.unpack_from('<III', b, p); p += 12
        dump = b[p:p + dump_sz]; p += dump_sz
        relocs = b[p:p + dump_sz]; p += dump_sz
        fixups = []
        for _ in range(fixup_num):
            kind = chr(b[p]); ofs, = struct.unpack_from('<I', b, p + 1)
            fname, p = _cstr(b, p + 5)
            fixups.append(Fixup(kind, ofs, fname))
        return Proc(idx, module_id, name, embedded, dump_type, method_kind, call_kind,
                    vproc, typedef, dump, relocs, fixups)

    def procs(self):
        for i in range(len(self.proc_offs)):
            yield self.proc(i)

    def const(self, idx):
        b = self.b
        p = self.const_offs[idx][0]
        module_id, = struct.unpack_from('<H', b, p); p += 2
        name, p = _cstr(b, p)
        kind = chr(b[p]); p += 1
        typedef, p = _cstr(b, p)
        value, p = _cstr(b, p)
        _total, dump_sz, fixup_num = struct.unpack_from('<III', b, p); p += 12
        dump = b[p:p + dump_sz]; p += dump_sz
        relocs = b[p:p + dump_sz]; p += dump_sz
        fixups = []
        for _ in range(fixup_num):
            k = chr(b[p]); ofs, = struct.unpack_from('<I', b, p + 1)
            fname, p = _cstr(b, p + 5)
            fixups.append(Fixup(k, ofs, fname))
        return Const(idx, module_id, name, kind, typedef, value, dump, relocs, fixups)


    def consts(self):
        for i in range(len(self.const_offs)):
            yield self.const(i)

    def vmt_slots(self):
        """{class name: {slot offset: 'Class.Method'}} from the KB's VMT dumps."""
        out = {}
        for c in self.consts():
            if not c.name.startswith('_DV_') or not c.typedef.startswith('class of'):
                continue
            slots = {}
            for f in c.fixups:
                if f.ofs >= 0x4C and '.' in f.name:
                    slots[f.ofs - 0x4C] = f.name
                elif f.ofs >= 0x4C and 'AbstractError' in f.name:
                    slots[f.ofs - 0x4C] = '(abstract)'
            out[c.name[4:]] = slots
        return out

    def class_fields(self, modules=None):
        """{class name: [(offset, field name, type)]} for class types in the KB.

        modules: optional set of lower-case module names to restrict to.
        """
        b = self.b
        out = {}
        for off, _size, _m, _n in self.type_offs:
            p = off
            if self.version_new():
                p += 4                                   # Size
            module_id, = struct.unpack_from('<H', b, p); p += 2
            if modules is not None and self.modules.get(module_id, '').lower() not in modules:
                continue
            name, p = _cstr(b, p)
            kind = b[p]; p += 1
            p += 2                                       # VMCnt
            _decl, p = _cstr(b, p)
            dump_total, = struct.unpack_from('<I', b, p); p += 4 + dump_total
            _fields_total, n = struct.unpack_from('<IH', b, p); p += 6
            fields = []
            for _ in range(n):
                p += 1                                   # scope
                ofs, _case = struct.unpack_from('<ii', b, p); p += 8
                fname, p = _cstr(b, p)
                ftype, p = _cstr(b, p)
                fields.append((ofs, fname, ftype))
            if fields and kind == ord('F'):              # drClassDef
                out[name] = fields
        return out

    def version_new(self):
        return self.b[:24].split(b'\0')[0] == b'IDR Knowledge Base File'

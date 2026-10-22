"""Statische structuurherkenning voor Delphi 5-programma's.

Leest het PE-image en herstelt:
  * de unit-initialisatietabel (unitvolgorde en init-/finalisatieprocedures)
  * klasse-VMT's (naam, ouder, instantiegrootte, virtuele methoden)
  * tabellen van gepubliceerde methoden (namen van eventhandlers → adressen)
  * tabellen van gepubliceerde velden
"""
import struct
from dataclasses import dataclass, field

import pefile

# Delphi 5 VMT-indeling (offsets ten opzichte van de VMT-pointer)
VMT_SELF = -76
VMT_INTF_TABLE = -72
VMT_AUTO_TABLE = -68
VMT_INIT_TABLE = -64
VMT_TYPE_INFO = -60
VMT_FIELD_TABLE = -56
VMT_METHOD_TABLE = -52
VMT_DYNAMIC_TABLE = -48
VMT_CLASS_NAME = -44
VMT_INSTANCE_SIZE = -40
VMT_PARENT = -36
# -32 .. -4: SafeCallException, AfterConstruction, BeforeDestruction, Dispatch,
#            DefaultHandler, NewInstance, FreeInstance, Destroy
VMT_STD_VIRTUALS = ['SafeCallException', 'AfterConstruction', 'BeforeDestruction', 'Dispatch',
                    'DefaultHandler', 'NewInstance', 'FreeInstance', 'Destroy']


@dataclass
class VMT:
    addr: int
    name: str
    parent: int
    instance_size: int
    type_info: int
    field_table: int
    method_table: int
    dynamic_table: int
    std_virtuals: list
    virtuals: list = field(default_factory=list)
    published_methods: list = field(default_factory=list)   # (addr, name)
    published_fields: list = field(default_factory=list)    # (offset, class_idx, name)
    field_classes: list = field(default_factory=list)       # VMT-adressen uit de veldklassentabel
    dynamic_methods: list = field(default_factory=list)     # (index, addr)


class Image:
    def __init__(self, path):
        self.pe = pefile.PE(path, fast_load=False)
        self.base = self.pe.OPTIONAL_HEADER.ImageBase
        self.mem = self.pe.get_memory_mapped_image()
        self.entry = self.base + self.pe.OPTIONAL_HEADER.AddressOfEntryPoint
        self.sections = {s.Name.rstrip(b'\0').decode(): s for s in self.pe.sections}
        code = self.sections['CODE']
        self.code_start = self.base + code.VirtualAddress
        self.code_end = self.code_start + code.Misc_VirtualSize
        self.image_end = self.base + self.pe.OPTIONAL_HEADER.SizeOfImage

    def valid(self, va):
        return self.base <= va < self.image_end

    def in_code(self, va):
        return self.code_start <= va < self.code_end

    def bytes(self, va, n):
        o = va - self.base
        return self.mem[o:o + n]

    def u8(self, va):
        return self.mem[va - self.base]

    def u16(self, va):
        return struct.unpack_from('<H', self.mem, va - self.base)[0]

    def u32(self, va):
        return struct.unpack_from('<I', self.mem, va - self.base)[0]

    def i32(self, va):
        return struct.unpack_from('<i', self.mem, va - self.base)[0]

    def sstr(self, va):
        n = self.u8(va)
        return self.bytes(va + 1, n).decode('latin1')

    # ---- unit-initialisatietabel -------------------------------------------------

    def init_table(self):
        """Geef [(init_proc, final_proc), ...] in unit-initialisatievolgorde.

        Het programma-entrypoint doet `mov eax, offset InitTable; call @InitExe`.
        """
        p = self.entry
        for _ in range(32):
            if self.u8(p) == 0xB8:
                tbl = self.u32(p + 1)
                count = self.u32(tbl)
                entries = self.u32(tbl + 4)
                if 0 < count < 1000 and self.valid(entries):
                    return [(self.u32(entries + 8 * i), self.u32(entries + 8 * i + 4))
                            for i in range(count)]
            p += 1
        raise ValueError('InitTable niet gevonden nabij het entrypoint')

    # ---- VMT's ------------------------------------------------------------

    def find_vmts(self):
        vmts = {}
        lo, hi = self.code_start, self.code_end
        for va in range(lo, hi - 4, 4):
            if self.u32(va) == va - VMT_SELF:
                v = va - VMT_SELF
                name_p = self.u32(v + VMT_CLASS_NAME)
                if not self.valid(name_p):
                    continue
                try:
                    name = self.sstr(name_p)
                except UnicodeDecodeError:
                    continue
                if not name or not name.replace('_', 'a').isalnum():
                    continue
                parent_pp = self.u32(v + VMT_PARENT)
                parent = self.u32(parent_pp) if parent_pp and self.valid(parent_pp) else 0
                vmts[v] = VMT(
                    addr=v, name=name, parent=parent,
                    instance_size=self.i32(v + VMT_INSTANCE_SIZE),
                    type_info=self.u32(v + VMT_TYPE_INFO),
                    field_table=self.u32(v + VMT_FIELD_TABLE),
                    method_table=self.u32(v + VMT_METHOD_TABLE),
                    dynamic_table=self.u32(v + VMT_DYNAMIC_TABLE),
                    std_virtuals=[self.u32(v - 32 + 4 * i) for i in range(8)],
                )
        # Virtuele-methodeslots lopen van de VMT-pointer tot de eerste structuur die erop volgt
        # (klassenaam, tabellen, of de self-pointer van de volgende VMT).
        bounds = sorted(set(
            [p for m in vmts.values() for p in (
                self.u32(m.addr + VMT_CLASS_NAME), m.field_table, m.method_table,
                m.dynamic_table, self.u32(m.addr + VMT_INIT_TABLE),
                self.u32(m.addr + VMT_AUTO_TABLE), self.u32(m.addr + VMT_INTF_TABLE),
                m.type_info) if p]
            + [m.addr + VMT_SELF for m in vmts.values()]))
        import bisect
        for m in vmts.values():
            i = bisect.bisect_right(bounds, m.addr)
            end = bounds[i] if i < len(bounds) else m.addr
            slots = []
            p = m.addr
            while p < end:
                t = self.u32(p)
                if not self.in_code(t):
                    break
                slots.append(t)
                p += 4
            m.virtuals = slots
            self._parse_method_table(m)
            self._parse_field_table(m)
            self._parse_dynamic_table(m)
        return vmts

    def _parse_method_table(self, m):
        if not m.method_table:
            return
        p = m.method_table
        n = self.u16(p); p += 2
        for _ in range(n):
            size = self.u16(p)
            addr = self.u32(p + 2)
            name = self.sstr(p + 6)
            m.published_methods.append((addr, name))
            p += size

    def _parse_field_table(self, m):
        if not m.field_table:
            return
        p = m.field_table
        n = self.u16(p)
        classtab = self.u32(p + 2)
        p += 6
        for _ in range(n):
            ofs = self.u32(p)
            idx = self.u16(p + 4)
            name = self.sstr(p + 6)
            m.published_fields.append((ofs, idx, name))
            p += 6 + 1 + len(name)
        if classtab:
            cnt = self.u16(classtab)
            for i in range(cnt):
                pp = self.u32(classtab + 2 + 4 * i)
                m.field_classes.append(self.u32(pp) if self.valid(pp) else 0)

    def _parse_dynamic_table(self, m):
        if not m.dynamic_table:
            return
        p = m.dynamic_table
        n = self.u16(p)
        idxs = [self.u16(p + 2 + 2 * i) for i in range(n)]
        addrs = [self.u32(p + 2 + 2 * n + 4 * i) for i in range(n)]
        m.dynamic_methods = list(zip(idxs, addrs))

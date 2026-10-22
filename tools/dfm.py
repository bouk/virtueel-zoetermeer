"""Decodeer Delphi-binaire formulierresources (TPF0-streams) naar de tekstuele .dfm-syntaxis.

Gebruik:
  python tools/dfm.py ROS.exe uitvoermap [--full]
Schrijft per RCDATA-formulierresource een <FORM>.txt. Binaire eigenschapsdata (bitmaps,
glyphs) wordt als aantal bytes samengevat, tenzij --full is opgegeven.
"""
import os
import struct
import sys

import pefile

VA_NAMES = {}


class Reader:
    def __init__(self, b):
        self.b = b
        self.p = 0

    def u8(self):
        v = self.b[self.p]
        self.p += 1
        return v

    def unpack(self, fmt):
        v = struct.unpack_from(fmt, self.b, self.p)
        self.p += struct.calcsize(fmt)
        return v[0] if len(v) == 1 else v

    def sstr(self):
        n = self.u8()
        s = self.b[self.p:self.p + n].decode('cp1252')
        self.p += n
        return s

    def raw(self, n):
        s = self.b[self.p:self.p + n]
        self.p += n
        return s


def quote(s):
    out, inq = [], False
    for ch in s:
        if 32 <= ord(ch) < 127 and ch != "'":
            if not inq:
                out.append("'")
                inq = True
            out.append(ch)
        elif ch == "'":
            if not inq:
                out.append("'")
                inq = True
            out.append("''")
        else:
            if inq:
                out.append("'")
                inq = False
            out.append('#%d' % ord(ch))
    if inq:
        out.append("'")
    return ''.join(out) or "''"


def value(r, full, indent):
    t = r.u8()
    if t == 0:
        return 'nil?'
    if t == 1:  # vaList
        items = []
        while True:
            if r.b[r.p] == 0:
                r.p += 1
                break
            items.append(value(r, full, indent + 2))
        return '(\n' + '\n'.join(' ' * (indent + 2) + i for i in items) + ')'
    if t == 2:
        return str(r.unpack('<b'))
    if t == 3:
        return str(r.unpack('<h'))
    if t == 4:
        return str(r.unpack('<i'))
    if t == 5:
        raw = r.raw(10)
        mant, exp = struct.unpack('<QH', raw)
        sign = -1 if exp & 0x8000 else 1
        exp &= 0x7FFF
        v = 0.0 if exp == 0 and mant == 0 else sign * mant * 2.0 ** (exp - 16383 - 63)
        return repr(v)
    if t in (6, 7):
        s = r.sstr()
        return s if t == 7 else quote(s)
    if t == 8:
        return 'False'
    if t == 9:
        return 'True'
    if t == 10:
        n = r.unpack('<I')
        data = r.raw(n)
        if not full:
            return '{ %d bytes }' % n
        hexs = data.hex().upper()
        lines = [hexs[i:i + 64] for i in range(0, len(hexs), 64)]
        return '{\n' + '\n'.join(' ' * (indent + 2) + l for l in lines) + '}'
    if t == 11:
        items = []
        while True:
            s = r.sstr()
            if not s:
                break
            items.append(s)
        return '[' + ', '.join(items) + ']'
    if t == 12:
        n = r.unpack('<I')
        return quote(r.raw(n).decode('cp1252'))
    if t == 13:
        return 'nil'
    if t == 14:  # vaCollection
        items = []
        while True:
            c = r.b[r.p]
            if c == 0:
                r.p += 1
                break
            idx = ''
            if c in (2, 3, 4):
                idx = ' [%s]' % value(r, full, indent)
            r.u8()  # vaList marker
            props = []
            while True:
                name = r.sstr()
                if not name:
                    break
                props.append(' ' * (indent + 4) + '%s = %s' % (name, value(r, full, indent + 4)))
            items.append(' ' * (indent + 2) + 'item' + idx + '\n' + '\n'.join(props) + '\n' + ' ' * (indent + 2) + 'end')
        return '<\n' + '\n'.join(items) + '>'
    if t == 15:
        return repr(r.unpack('<f'))
    if t == 16:
        return '%gc' % (r.unpack('<q') / 10000)
    if t == 17:
        return 'date %r' % r.unpack('<d')
    if t == 18:
        n = r.unpack('<I')
        return quote(r.raw(2 * n).decode('utf-16le'))
    if t == 19:
        return str(r.unpack('<q'))
    raise ValueError('onbekend waardetype %d bij %#x' % (t, r.p - 1))


def obj(r, full, indent=0):
    flags = ''
    if r.b[r.p] & 0xF0 == 0xF0:
        f = r.u8()
        flags = ' [inherited]' if f & 1 else ''
        if f & 2:
            flags += ' [child %d]' % value(r, full, indent)
    cls = r.sstr()
    name = r.sstr()
    pad = ' ' * indent
    lines = ['%sobject %s: %s%s' % (pad, name, cls, flags)]
    while True:
        prop = r.sstr()
        if not prop:
            break
        lines.append('%s  %s = %s' % (pad, prop, value(r, full, indent + 2)))
    while True:
        if r.b[r.p] == 0:
            r.p += 1
            break
        lines.append(obj(r, full, indent + 2))
    lines.append(pad + 'end')
    return '\n'.join(lines)


def forms(path):
    pe = pefile.PE(path)
    for t in pe.DIRECTORY_ENTRY_RESOURCE.entries:
        if t.id != 10:
            continue
        for n in t.directory.entries:
            d = n.directory.entries[0].data.struct
            data = pe.get_data(d.OffsetToData, d.Size)
            if data[:4] == b'TPF0':
                yield str(n.name), data


def decode(data, full=False):
    r = Reader(data)
    assert r.raw(4) == b'TPF0'
    return obj(r, full) + '\n'


def main():
    full = '--full' in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    os.makedirs(args[1], exist_ok=True)
    for name, data in forms(args[0]):
        with open(os.path.join(args[1], name + '.txt'), 'w') as f:
            f.write(decode(data, full))


if __name__ == '__main__':
    main()

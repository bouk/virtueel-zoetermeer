#!/usr/bin/env python3
"""Generate the bitmap fonts of the compat layer (src/compat/fonts/zmfontdata.inc).

Renders Liberation Sans/Serif/Mono (SIL OFL, metric clones of Arial/Times New Roman/
Courier New; package `liberation_ttf` in flake.nix) without anti-aliasing at a set of
pixel sizes, for the Windows-1252 code page. The result is a Pascal include file read by
src/compat/ZMFonts.pas. Font faces are matched at run time by family/weight/em size.

The Windows 'System' font (a 16 px bold bitmap font) is approximated by Liberation Sans
Bold at 13 px, whose advance widths match the original label sizes in the DFMs exactly
(e.g. 'RAPPORTAGE' = 91 px), in a 13+3 px cell.

Usage: python tools/gen-fonts.py [output.inc]
"""
import os
import sys
import zlib

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, 'src/compat/fonts/zmfontdata.inc')


def find_font_dir():
    dirs = os.environ.get('XDG_DATA_DIRS', '').split(':') + ['/usr/share', '/run/current-system/sw/share']
    for d in dirs:
        for sub in ('fonts/truetype', 'fonts/truetype/liberation', 'fonts/liberation', 'fonts/TTF'):
            p = os.path.join(d, sub)
            if os.path.exists(os.path.join(p, 'LiberationSans-Regular.ttf')):
                return p
    sys.exit('Liberation fonts not found (run inside `nix develop`)')


SANS_SIZES = list(range(8, 21)) + [22, 24, 26, 28, 32, 36, 40, 48]
FACES = [
    # family, file, bold, italic, sizes, metrics override (ascent, descent) or None
    ('sans', 'LiberationSans-Regular.ttf', False, False, SANS_SIZES, None),
    ('sans', 'LiberationSans-Bold.ttf', True, False, SANS_SIZES, None),
    ('sans', 'LiberationSans-Italic.ttf', False, True, [11, 13, 16], None),
    ('system', 'LiberationSans-Bold.ttf', True, False, [13], (13, 3)),
    ('mono', 'LiberationMono-Regular.ttf', False, False, list(range(10, 17)) + [20], None),
    ('mono', 'LiberationMono-Bold.ttf', True, False, [12, 13, 16], None),
    ('serif', 'LiberationSerif-Regular.ttf', False, False, list(range(10, 17)) + [20, 24], None),
    ('serif', 'LiberationSerif-Bold.ttf', True, False, [13, 16], None),
]


def cp1252_char(c):
    try:
        return bytes([c]).decode('cp1252')
    except UnicodeDecodeError:
        return None


def words(*vals):
    out = bytearray()
    for v in vals:
        out += int(v & 0xFFFF).to_bytes(2, 'little')
    return out


def render_glyphs(font, em, asc, desc, yshift, aa):
    """Render the 256 cp1252 glyphs. aa=False: 1-bit glyphs with the hinted mono advances
    (what Wine/Windows use on <= 8 bpp DIBs); aa=True: 0..16 grey levels (GGO_GRAY4)
    with the normal hinted advances (Wine on deeper DIBs)."""
    mode = 'L' if aa else '1'
    glyphs = []
    for c in range(256):
        ch = cp1252_char(c) if c >= 32 else None
        if ch is None or c == 0x7F:
            glyphs.append((0 if c < 32 else round(font.getlength('?', mode=mode)), 0, 0, 0, 0, b''))
            continue
        adv = round(font.getlength(ch, mode=mode))
        pad = em
        w = adv + 3 * pad
        h = asc + desc + 2 * pad
        img = Image.new('L', (w, h), 0)
        dr = ImageDraw.Draw(img)
        dr.fontmode = mode
        base_x, base_y = pad, pad + asc - yshift
        dr.text((base_x, base_y), ch, font=font, fill=255, anchor='ls')
        bbox = img.getbbox()
        if bbox is None:
            glyphs.append((adv, 0, 0, 0, 0, b''))
            continue
        l, t, r, b = bbox
        crop = img.crop(bbox)
        gw, gh = r - l, b - t
        px = crop.load()
        if aa:
            bits = bytearray(gw * gh)
            for y in range(gh):
                for x in range(gw):
                    # zoals Wine (get_bitmap_outline): niveau = dekking * 17 / 256, naar
                    # beneden afgerond; niveau 1 tekent Wine niet (dibdrv draw_glyph)
                    bits[y * gw + x] = px[x, y] * 17 // 256
        else:
            stride = (gw + 7) // 8
            bits = bytearray(stride * gh)
            for y in range(gh):
                for x in range(gw):
                    if px[x, y] >= 128:
                        bits[y * stride + x // 8] |= 0x80 >> (x % 8)
        glyphs.append((adv, gw, gh, l - base_x, t - pad, bytes(bits)))
    return glyphs


def gasp_gray(path, ppem):
    """True when the font's 'gasp' table asks for grey-scale rendering at ppem
    (Windows and Wine only anti-alias where gasp says GASP_DOGRAY)."""
    import struct
    data = open(path, 'rb').read()
    num = struct.unpack('>H', data[4:6])[0]
    for i in range(num):
        tag, _, off, length = struct.unpack('>4sIII', data[12 + 16 * i:28 + 16 * i])
        if tag == b'gasp':
            n = struct.unpack('>H', data[off + 2:off + 4])[0]
            for j in range(n):
                maxppem, behavior = struct.unpack('>HH', data[off + 4 + 4 * j:off + 8 + 4 * j])
                if ppem <= maxppem:
                    return bool(behavior & 2)
            return False
    return True


def win_metrics(path, ppem):
    """tmAscent/tmDescent like Wine: usWinAscent/usWinDescent scaled to ppem, rounded."""
    import struct
    data = open(path, 'rb').read()
    num = struct.unpack('>H', data[4:6])[0]
    tables = {}
    for i in range(num):
        tag, _, off, length = struct.unpack('>4sIII', data[12 + 16 * i:28 + 16 * i])
        tables[tag] = off
    upem = struct.unpack('>H', data[tables[b'head'] + 18:tables[b'head'] + 20])[0]
    o = tables[b'OS/2']
    win_a, win_d = struct.unpack('>HH', data[o + 74:o + 78])
    return int(win_a * ppem / upem + 0.5), int(win_d * ppem / upem + 0.5)


def render_face(path, em, metrics):
    font = ImageFont.truetype(path, em, layout_engine=ImageFont.Layout.BASIC)
    asc, desc = win_metrics(path, em)
    fasc, _ = font.getmetrics()
    yshift = 0   # baseline at tmAscent
    if metrics:
        yshift = metrics[0] - fasc
        asc, desc = metrics
    mono = render_glyphs(font, em, asc, desc, yshift, False)
    aa = render_glyphs(font, em, asc, desc, yshift, True)
    # Windows' tmAveCharWidth for proportional fonts is the weighted average of a-z + space
    lower = 'abcdefghijklmnopqrstuvwxyz '
    avg = round(sum(mono[ord(ch)][0] for ch in lower) / len(lower))
    data = bytearray()
    # Grijs alleen waar de eigen 'gasp'-tabel van het font daarom vraagt (Liberation Sans
    # Bold: altijd; Regular: tot 8 en vanaf 18 ppem), zoals Wine.
    data += words(em, asc, desc, avg, max(g[0] for g in mono), 1 if gasp_gray(path, em) else 0)
    for glyphs in (mono, aa):
        for adv, gw, gh, xo, yo, bits in glyphs:
            data += words(adv, gw, gh, xo, yo)
            data += bits
    return data


def main():
    fdir = find_font_dir()
    infos = []
    blob = bytearray()
    for fam, fn, bold, italic, sizes, metrics in FACES:
        for em in sizes:
            infos.append((fam, bold, italic, len(blob), em))
            blob += render_face(os.path.join(fdir, fn), em, metrics)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        f.write('{ Generated by tools/gen-fonts.py from the Liberation fonts (SIL Open Font License 1.1).\n'
                '  Do not edit. %d faces, %d bytes. }\n\n' % (len(infos), len(blob)))
        f.write('const\n  ZMFontFaceCount = %d;\n\n' % len(infos))
        f.write('type\n  TZMFontFaceInfo = record\n    Family: string[8];\n    Bold, Italic: Boolean;\n'
                '    Offset: Integer;\n  end;\n\n')
        f.write('const\n  ZMFontFaceInfo: array[0..%d] of TZMFontFaceInfo = (\n' % (len(infos) - 1))
        f.write(',\n'.join("    (Family: '%s'; Bold: %s; Italic: %s; Offset: %d)  { em %d }" %
                           (fam, str(b), str(i), off, em) for fam, b, i, off, em in infos))
        f.write('\n  );\n\n')
        z = zlib.compress(bytes(blob), 9)
        f.write('  { zlib-compressed glyph data, %d bytes when inflated }\n' % len(blob))
        f.write('  ZMFontDataSize = %d;\n' % len(blob))
        f.write('  ZMFontDataZ: array[0..%d] of Byte = (\n' % (len(z) - 1))
        for i in range(0, len(z), 24):
            chunk = z[i:i + 24]
            f.write('    ' + ','.join('$%02x' % b for b in chunk) + (',' if i + 24 < len(z) else '') + '\n')
        f.write('  );\n')
    print('wrote %s: %d faces, %d bytes' % (OUT, len(infos), len(blob)))


if __name__ == '__main__':
    main()

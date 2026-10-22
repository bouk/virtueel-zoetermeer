#!/usr/bin/env python3
"""Genereer de bitmapfonts van de compat-laag (src/compat/fonts/zmfontdata.inc).

Rendert Liberation Sans/Serif/Mono (SIL OFL, metrische klonen van Arial/Times New Roman/
Courier New; pakket `liberation_ttf` in flake.nix) zonder anti-aliasing op een aantal
pixelgroottes, voor de Windows-1252-codepagina. Het resultaat is een Pascal-includebestand
dat src/compat/ZMFonts.pas inleest. Fontgezichten worden tijdens het draaien gevonden op
familie, gewicht en em-grootte.

Het Windows-lettertype 'System' (een vet bitmapfont van 16 px) wordt benaderd door
Liberation Sans Bold van 13 px, waarvan de tekenbreedtes exact overeenkomen met de
oorspronkelijke labelgroottes in de DFM's (bijv. 'RAPPORTAGE' = 91 px), in een cel van 13+3 px.

Gebruik: python tools/gen-fonts.py [uitvoer.inc]
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
    sys.exit('Liberation-fonts niet gevonden (draai binnen `nix develop`)')


SANS_SIZES = list(range(8, 21)) + [22, 24, 26, 28, 32, 36, 40, 48]
FACES = [
    # familie, bestand, vet, cursief, groottes, metrieke overschrijving (ascent, descent) of None
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
    """Render de 256 cp1252-glyphs. aa=False: 1-bit glyphs met de gehinte mono-advances
    (wat Wine/Windows gebruiken bij DIB's van <= 8 bpp); aa=True: 0..16 grijsniveaus (GGO_GRAY4)
    met de normale gehinte advances (Wine bij diepere DIB's)."""
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
    """Waar wanneer de 'gasp'-tabel van het font om grijswaardenrendering vraagt bij ppem
    (Windows en Wine anti-aliasen alleen waar gasp GASP_DOGRAY aangeeft)."""
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
    """tmAscent/tmDescent zoals Wine: usWinAscent/usWinDescent geschaald naar ppem, afgerond."""
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
    yshift = 0   # basislijn op tmAscent
    if metrics:
        yshift = metrics[0] - fasc
        asc, desc = metrics
    mono = render_glyphs(font, em, asc, desc, yshift, False)
    aa = render_glyphs(font, em, asc, desc, yshift, True)
    # Windows' tmAveCharWidth voor proportionele fonts is het gewogen gemiddelde van a-z + spatie
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
        f.write('{ Gegenereerd door tools/gen-fonts.py uit de Liberation-fonts (SIL Open Font License 1.1).\n'
                '  Niet bewerken. %d gezichten, %d bytes. }\n\n' % (len(infos), len(blob)))
        f.write('const\n  ZMFontFaceCount = %d;\n\n' % len(infos))
        f.write('type\n  TZMFontFaceInfo = record\n    Family: string[8];\n    Bold, Italic: Boolean;\n'
                '    Offset: Integer;\n  end;\n\n')
        f.write('const\n  ZMFontFaceInfo: array[0..%d] of TZMFontFaceInfo = (\n' % (len(infos) - 1))
        f.write(',\n'.join("    (Family: '%s'; Bold: %s; Italic: %s; Offset: %d)  { em %d }" %
                           (fam, str(b), str(i), off, em) for fam, b, i, off, em in infos))
        f.write('\n  );\n\n')
        z = zlib.compress(bytes(blob), 9)
        f.write('  { zlib-gecomprimeerde glyphdata, %d bytes na uitpakken }\n' % len(blob))
        f.write('  ZMFontDataSize = %d;\n' % len(blob))
        f.write('  ZMFontDataZ: array[0..%d] of Byte = (\n' % (len(z) - 1))
        for i in range(0, len(z), 24):
            chunk = z[i:i + 24]
            f.write('    ' + ','.join('$%02x' % b for b in chunk) + (',' if i + 24 < len(z) else '') + '\n')
        f.write('  );\n')
    print('geschreven %s: %d gezichten, %d bytes' % (OUT, len(infos), len(blob)))


if __name__ == '__main__':
    main()

"""Brute-force extract raw-deflate streams from a Wise installer.

Usage: python tools/wise-scan.py update.exe outdir
Every offset that inflates to a non-trivial stream is written to outdir as <offset>.bin.
"""
import os
import sys
import zlib

data = open(sys.argv[1], 'rb').read()
out = sys.argv[2]
os.makedirs(out, exist_ok=True)
pos = 0
while pos < len(data):
    d = zlib.decompressobj(-15)
    try:
        blob = d.decompress(data[pos:pos + 8 << 20])
    except zlib.error:
        pos += 1
        continue
    used = len(data[pos:pos + 8 << 20]) - len(d.unused_data)
    if d.eof and len(blob) >= 64 and used > 16:
        open(os.path.join(out, '%08x.bin' % pos), 'wb').write(blob)
        print('%08x  in=%8d out=%8d  %r' % (pos, used, len(blob), blob[:16]))
        pos += used
    else:
        pos += 1

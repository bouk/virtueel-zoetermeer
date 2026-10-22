"""Extract the v1.1 ROS.exe from the Wise upgrade installer (update.exe).

The payload is a raw deflate stream at a fixed offset (found with wise-scan.py).
Usage: python tools/wise-extract.py update.exe out/ROS.exe
"""
import sys
import zlib

ROS_OFFSET = 0x13877

data = open(sys.argv[1], 'rb').read()
d = zlib.decompressobj(-15)
blob = d.decompress(data[ROS_OFFSET:])
assert d.eof and blob[:2] == b'MZ'
open(sys.argv[2], 'wb').write(blob)

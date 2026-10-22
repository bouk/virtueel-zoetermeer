"""Pak het v1.1-ROS.exe uit het Wise-upgradeprogramma (update.exe).

De lading is een ruwe deflate-stream op een vaste offset (gevonden met wise-scan.py).
Gebruik: python tools/wise-extract.py update.exe uit/ROS.exe
"""
import sys
import zlib

ROS_OFFSET = 0x13877

data = open(sys.argv[1], 'rb').read()
d = zlib.decompressobj(-15)
blob = d.decompress(data[ROS_OFFSET:])
assert d.eof and blob[:2] == b'MZ'
open(sys.argv[2], 'wb').write(blob)

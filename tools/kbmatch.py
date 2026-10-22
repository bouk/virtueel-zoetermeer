"""Match IDR knowledge-base procedure signatures against an executable's CODE section.

Delphi aligns every routine to 4 bytes, so only aligned positions are tried.
A match requires every non-relocated byte of the KB dump to be identical.
"""
from collections import defaultdict

KEY_LEN = 8


def _mask_key(dump, relocs):
    return tuple(i for i in range(KEY_LEN) if relocs[i])


def build_index(procs, min_len=KEY_LEN):
    """Group code procs by the reloc pattern of their first KEY_LEN bytes."""
    index = defaultdict(lambda: defaultdict(list))
    for p in procs:
        if p.dump_type != 'C' or len(p.dump) < min_len:
            continue
        holes = _mask_key(p.dump, p.relocs)
        key = bytes(0 if i in holes else p.dump[i] for i in range(KEY_LEN))
        index[holes][key].append(p)
    return index


def full_match(code, pos, p):
    d, r = p.dump, p.relocs
    if pos + len(d) > len(code):
        return False
    seg = code[pos:pos + len(d)]
    for i in range(len(d)):
        if not r[i] and seg[i] != d[i]:
            return False
    return True


def scan(code, index, align=4):
    """Yield (pos, [procs]) for every aligned position with full matches."""
    patterns = list(index.items())
    for pos in range(0, len(code) - KEY_LEN, align):
        window = code[pos:pos + KEY_LEN]
        hits = []
        for holes, table in patterns:
            if holes:
                w = bytearray(window)
                for i in holes:
                    w[i] = 0
                key = bytes(w)
            else:
                key = bytes(window)
            for p in table.get(key, ()):
                if full_match(code, pos, p):
                    hits.append(p)
        if hits:
            yield pos, hits

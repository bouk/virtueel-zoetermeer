"""Regressietests voor de matching-pipeline (tools/diff.py, progress.py, maak-testmap.py, maak-stubs.py).

Er is geen Delphi 5-compiler, dus alles wordt getest met het originele ROS.exe:
  * diff/progress: origineel tegen zichzelf (100%), een gepatchte kopie (precies de gepatchte
    routines verschillen), dezelfde vergelijkingen via een uit de tsv gegenereerd Delphi-map
    (ook met weggelaten routines, die op positie gekoppeld moeten worden), en een synthetisch
    beeld waarin een routine verschoven is (geen adresruis bij de aanroeper);
  * maak-stubs: de gegenereerde db/dd/call-regels worden met een eigen mini-assembler (symbolen
    terug naar adressen via symbols/ros-1.1.tsv) opnieuw geassembleerd en met de originele bytes
    vergeleken; als Free Pascal er is, wordt de syntaxis van een stub-unit gecontroleerd.

Gebruik: nix develop --command python3 tools/test_matchpipeline.py [-v]
Zonder orig/game-1.1/ROS.exe (of $ZM_ORIG) worden de tests die het nodig hebben overgeslagen.
Tijdelijke bestanden komen in build/matchtest/.
"""
import importlib.util
import os
import re
import shutil
import struct
import subprocess
import sys
import unittest

HIER = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HIER)
import diff  # noqa: E402
import progress  # noqa: E402

ROOT = os.path.normpath(os.path.join(HIER, '..'))
ORIG = os.environ.get('ZM_ORIG', os.path.join(ROOT, 'orig', 'game-1.1', 'ROS.exe'))
WERK = os.path.join(ROOT, 'build', 'matchtest')
HEEFT_ORIG = os.path.exists(ORIG)


def schrijf(pad, data):
    with open(pad, 'wb') as f:
        f.write(data)


def laad_module(naam, bestand):
    spec = importlib.util.spec_from_file_location(naam, os.path.join(HIER, bestand))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


# Twee routines die in de test gepatcht worden: (naam in de tsv, afstand, xor-masker).
PATCHES = [('TTrein.Step', 0x11, 0xFF), ('TCell.Create', 0x08, 0x01)]


def symbool(naam):
    for s in diff.lees_tsv(diff.STANDAARD_TSV):
        if s.naam == naam and s.soort == 'f':
            return s
    raise KeyError(naam)


def maak_gepatcht():
    import pefile
    os.makedirs(WERK, exist_ok=True)
    doel = os.path.join(WERK, 'ROS-gepatcht.exe')
    data = bytearray(diff.lees_bytes(ORIG))
    pe = pefile.PE(ORIG, fast_load=True)
    for naam, afstand, masker in PATCHES:
        va = symbool(naam).adres + afstand
        data[pe.get_offset_from_rva(va - pe.OPTIONAL_HEADER.ImageBase)] ^= masker
    schrijf(doel, data)
    return doel


def maak_map(naam, *opties):
    pad = os.path.join(WERK, naam)
    os.makedirs(WERK, exist_ok=True)
    subprocess.run([sys.executable, os.path.join(HIER, 'maak-testmap.py'), ORIG, '-o', pad] + list(opties),
                   check=True)
    return pad


def statussen(res, alleen_project=False):
    return {it.naam: it for it in res.items if it.project or not alleen_project}


@unittest.skipUnless(HEEFT_ORIG, 'orig/game-1.1/ROS.exe ontbreekt')
class TestDiff(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.gepatcht = maak_gepatcht()
        cls.map_vol = maak_map('ROS.map')
        cls.map_gaten = maak_map('ROS-gaten.map', '--zonder-genest', '--weglaten', '7')

    def controleer_alles_gelijk(self, res):
        fout = [(it.naam, it.status) for it in res.items if it.status != 'gelijk']
        self.assertEqual(fout, [])
        self.assertTrue(all(g for _, _, _, g in res.secties))

    def controleer_patches(self, res):
        verschillend = {it.naam: it for it in res.items if it.status != 'gelijk'}
        verwacht = {}
        for naam, afstand, _ in PATCHES:
            s = symbool(naam)
            verwacht[s.volledig] = afstand
        self.assertEqual(set(verschillend), set(verwacht))
        for naam, afstand in verwacht.items():
            self.assertEqual(verschillend[naam].status, 'verschilt')
            self.assertEqual(verschillend[naam].verschil, afstand)
        secties = {n: g for n, _, _, g in res.secties}
        self.assertFalse(secties['(bestand)'])
        self.assertFalse(secties['CODE'])
        self.assertTrue(all(g for n, g in secties.items() if n not in ('(bestand)', 'CODE')))

    def test_a_zelf(self):
        res, _, _ = diff.laad(ORIG, ORIG)
        self.controleer_alles_gelijk(res)
        self.assertEqual(sum(1 for it in res.items if it.project), 762)

    def test_b_gepatcht(self):
        res, _, _ = diff.laad(ORIG, self.gepatcht)
        self.controleer_patches(res)

    def test_c_map_zelf(self):
        res, _, _ = diff.laad(ORIG, ORIG, self.map_vol)
        self.controleer_alles_gelijk(res)
        self.assertTrue(all(it.koppeling in ('naam', 'unit') for it in res.items))

    def test_c_map_gaten(self):
        res, _, _ = diff.laad(ORIG, ORIG, self.map_gaten)
        self.controleer_alles_gelijk(res)
        positie = [it for it in res.items if it.koppeling == 'positie']
        self.assertGreater(len(positie), 50)

    def test_c_map_gepatcht(self):
        res, _, _ = diff.laad(ORIG, self.gepatcht, self.map_gaten)
        self.controleer_patches(res)

    def test_reloc_doel(self):
        """Een relocatie die naar een ander symbool wijst, is een verschil in alleen die routine."""
        import pefile
        s = symbool('TTrein.Create')
        beeld = diff.Beeld.uit_pe(ORIG)
        r = next(x for x in beeld.relocs if s.adres <= x < s.adres + 0x100 and beeld.u32(x) == 0x48B150)
        data = bytearray(diff.lees_bytes(ORIG))
        pe = pefile.PE(ORIG, fast_load=True)
        o = pe.get_offset_from_rva(r - pe.OPTIONAL_HEADER.ImageBase)
        data[o:o + 4] = struct.pack('<I', 0x48B158)
        pad = os.path.join(WERK, 'ROS-reloc.exe')
        schrijf(pad, data)
        res, _, _ = diff.laad(ORIG, pad)
        anders = [(it.naam, it.verschil) for it in res.items if it.status != 'gelijk']
        self.assertEqual(len(anders), 1)
        self.assertEqual(anders[0][0], s.volledig)
        self.assertLessEqual(anders[0][1], r - s.adres)

    def test_cli(self):
        uit = os.path.join(WERK, 'diff.json')
        p = subprocess.run([sys.executable, os.path.join(HIER, 'diff.py'), ORIG, self.gepatcht,
                            '--map', self.map_vol, '--json', uit], capture_output=True, text=True)
        self.assertEqual(p.returncode, 1)
        self.assertIn('verschilt (eerste verschil op +0x11)', p.stdout)
        j = diff.lees_json(uit)
        self.assertEqual(j['samenvatting']['project'].get('verschilt'), 2)
        p = subprocess.run([sys.executable, os.path.join(HIER, 'diff.py'), ORIG, ORIG],
                           capture_output=True, text=True)
        self.assertEqual(p.returncode, 0)
        self.assertIn('byte-identiek', p.stdout)


@unittest.skipUnless(HEEFT_ORIG, 'orig/game-1.1/ROS.exe ontbreekt')
class TestProgress(unittest.TestCase):

    def test_zelf_en_gepatcht(self):
        units = diff.lees_json(diff.STANDAARD_UNITS)['units']
        res, _, _ = diff.laad(ORIG, ORIG)
        rijen = progress.per_unit(res, units)
        self.assertEqual(len(rijen), len(diff.projectunits(units)))
        t = progress.totaal(rijen)
        self.assertEqual(t['gelijk_bytes'], t['bytes'])
        self.assertEqual(progress.procent(t), 100.0)

        res, _, _ = diff.laad(ORIG, maak_gepatcht(), maak_map('ROS-gaten.map', '--zonder-genest', '--weglaten', '7'))
        rijen = progress.per_unit(res, units)
        minder = {n: r for n, r in rijen.items() if r['gelijk_bytes'] < r['bytes']}
        self.assertEqual(set(minder), {'uTrein', 'Uworld'})
        grootte = {it.naam: it.grootte for it in res.items}
        self.assertEqual(minder['uTrein']['bytes'] - minder['uTrein']['gelijk_bytes'], grootte['uTrein.TTrein.Step'])
        self.assertEqual(minder['Uworld']['bytes'] - minder['Uworld']['gelijk_bytes'], grootte['Uworld.TCell.Create'])

    def test_cli(self):
        os.makedirs(WERK, exist_ok=True)
        j, svg = os.path.join(WERK, 'progress.json'), os.path.join(WERK, 'progress.svg')
        subprocess.run([sys.executable, os.path.join(HIER, 'progress.py'), ORIG, ORIG, '--json', j, '--badge', svg],
                       check=True, capture_output=True)
        self.assertEqual(diff.lees_json(j)['totaal']['procent'], 100.0)
        self.assertIn('100.0%', diff.lees_bytes(svg).decode())


def synthetisch(h_grootte, f_roept=0x40):
    """Een klein beeld: F roept (call rel32) een routine aan en leest een global; H heeft een
    instelbare grootte, dus G verschuift. f_roept is de afstand van het aanroepdoel na H."""
    base = 0x400000
    mem = bytearray(0x3000)
    code = 0x1000
    h = 0x20
    g = h + h_grootte
    eind = g + 0x10
    f = bytearray()
    f += b'\xe8' + struct.pack('<i', (h + (h_grootte if f_roept else 0)) - 5)   # call G (of H)
    f += b'\xa1' + struct.pack('<I', base + 0x2010)                            # mov eax, [Var]
    f += b'\x68' + struct.pack('<I', base + code + 0x14)                       # push offset @intern
    f += b'\x90\x90\xc3'                                                         # ... ret
    f += b'\x8b\xc0'
    mem[code:code + len(f)] = f
    mem[code + h:code + g] = b'\x90' * (h_grootte - 1) + b'\xc3'
    mem[code + g:code + g + 4] = b'\x33\xc0\xc3\x90'
    relocs = [base + code + 6, base + code + 11]
    secties = [('CODE', base + code, base + code + eind), ('DATA', base + 0x2000, base + 0x3000)]
    beeld = diff.Beeld(base, bytes(mem), secties, relocs)
    syms = [diff.Symbool(base + code + a, 'f', 'Proef', n, 'proef.' + n.lower())
            for a, n in ((0, 'F'), (h, 'H'), (g, 'G'))]
    syms.append(diff.Symbool(base + 0x2010, 'd', 'Proef', 'Var', 'proef.var'))
    unit = dict(start=base + code, end=base + code + eind, name='Proef', init_order=1, library=False)
    return beeld, syms, unit


class TestNormalisatie(unittest.TestCase):

    def test_verschoven_routine(self):
        a, sa, ua = synthetisch(0x20)
        b, sb, _ = synthetisch(0x30)
        res = diff.vergelijk(a, sa, b, sb, [ua])
        st = {it.naam: it.status for it in res.items}
        self.assertEqual(st['Proef.F'], 'gelijk')      # andere rel32-bytes, zelfde doel G
        self.assertEqual(st['Proef.G'], 'gelijk')
        self.assertEqual(st['Proef.H'], 'verschilt')

    def test_ander_doel(self):
        a, sa, ua = synthetisch(0x20)
        b, sb, _ = synthetisch(0x30, f_roept=0)         # F roept nu H aan in plaats van G
        res = diff.vergelijk(a, sa, b, sb, [ua])
        f = next(it for it in res.items if it.naam == 'Proef.F')
        self.assertEqual((f.status, f.verschil), ('verschilt', 0))


# ---- mini-assembler voor de stubs ----------------------------------------------------------

BLOK = re.compile(r'\{ @([0-9A-F]{8}) [^}]*\}\n(?:\{ LET OP:[^}]*\}\n)?procedure (\w+); assembler;\nasm\n(.*?)\nend;',
                  re.S)


def assembleer(tekst, namen, unit):
    """Assembleer elk asm-blok (alleen db/dd/call/labels): [(adres, bytes, staart)]."""
    uit = []
    for m in BLOK.finditer(tekst):
        start = int(m.group(1), 16)
        regels = m.group(3).split('\n')
        labels, staart = {}, b''
        pos = 0
        for r in regels:                                   # eerste doorgang: labels
            r = r.strip()
            if r.startswith('@@'):
                labels[r.rstrip(':')] = pos
                assert int(r[3:-1], 16) == pos, 'labelnaam klopt niet met positie'
            elif r.startswith('db '):
                pos += len(r[3:].split('{')[0].split(','))
            elif r.startswith('dd '):
                pos += 4
            elif r.startswith(('call ', 'jmp ')):
                pos += 5
        code = bytearray()
        for r in regels:                                   # tweede doorgang: bytes
            r = r.strip()
            m2 = re.match(r'^\{ RET \+ opvulling \(([0-9A-F ]+)\)', r)
            if m2:
                staart = bytes.fromhex(m2.group(1))
                continue
            zonder = re.sub(r'\{[^}]*\}', '', r).strip()
            if zonder.startswith('db '):
                code += bytes(int(x.strip().lstrip('$'), 16) for x in zonder[3:].split(','))
            elif zonder.startswith('dd '):
                expr = zonder[3:].strip()
                if expr.startswith('@@'):
                    code += struct.pack('<I', start + labels[expr])
                else:
                    code += struct.pack('<I', namen.adres_van(expr, unit))
            elif zonder.startswith(('call ', 'jmp ')):
                mnemonic, expr = zonder.split(None, 1)
                doel = namen.adres_van(expr, unit)
                code += (b'\xe8' if mnemonic == 'call' else b'\xe9') + struct.pack('<i', doel - (start + len(code) + 5))
        uit.append((start, bytes(code), staart))
    return uit


@unittest.skipUnless(HEEFT_ORIG, 'orig/game-1.1/ROS.exe ontbreekt')
class TestStubs(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.stubs = laad_module('maak_stubs', 'maak-stubs.py')
        cls.beeld = cls.stubs.laad_beeld(ORIG)
        cls.symbolen = diff.lees_tsv(diff.STANDAARD_TSV)
        cls.units = diff.lees_json(diff.STANDAARD_UNITS)['units']

    def controleer(self, ruw):
        resultaat, namen = self.stubs.genereer(self.beeld, self.symbolen, self.units, ruw=ruw)
        self.assertEqual(len(resultaat), len(diff.projectunits(self.units)))
        blokken = dd = 0
        for unit, (tekst, info) in resultaat.items():
            geassembleerd = assembleer(tekst, namen, unit)
            self.assertEqual(len(geassembleerd), len(info), unit)
            for (start, code, staart), b in zip(geassembleerd, info):
                self.assertEqual(start, b.adres)
                origineel = self.beeld.lees(b.adres, b.eind - b.adres)
                self.assertEqual(code, origineel[:len(code)], '%s %08x' % (unit, start))
                self.assertEqual(len(code) + len(staart), len(origineel), '%s %08x' % (unit, start))
                self.assertEqual(staart, origineel[len(code):])
                if ruw:
                    self.assertEqual(staart, b'')
                else:
                    self.assertTrue(staart == b'' or (staart[:1] == b'\xc3' and staart[1:] in self.stubs.OPVULLING))
                blokken += 1
            dd += tekst.count('\n  dd ')
        return blokken, dd

    def test_herassembleren(self):
        blokken, dd = self.controleer(ruw=False)
        self.assertGreater(blokken, 700)
        self.assertGreater(dd, 1000)

    def test_herassembleren_ruw(self):
        self.controleer(ruw=True)

    def test_cli_en_uitvoermap(self):
        uit = os.path.join(WERK, 'stubs')
        shutil.rmtree(uit, ignore_errors=True)
        subprocess.run([sys.executable, os.path.join(HIER, 'maak-stubs.py'), ORIG, uit, '--unit', 'uLog',
                        '--unit', 'uTrein'], check=True, capture_output=True)
        self.assertEqual(sorted(os.listdir(uit)), ['uLog.pas', 'uTrein.pas'])
        p = subprocess.run([sys.executable, os.path.join(HIER, 'maak-stubs.py'), ORIG,
                            os.path.join(ROOT, 'src', 'stubs-test')], capture_output=True, text=True)
        self.assertNotEqual(p.returncode, 0)
        self.assertFalse(os.path.exists(os.path.join(ROOT, 'src', 'stubs-test')))

    @unittest.skipUnless(shutil.which('fpc'), 'fpc niet beschikbaar')
    def test_fpc_syntaxis(self):
        """FPC (x86_64; er is geen i386-compiler in de dev-shell) moet de asm-syntaxis accepteren.
        Verwijzingen naar andere units worden door 0 vervangen; lokale labels en procedures blijven."""
        resultaat, _ = self.stubs.genereer(self.beeld, self.symbolen, self.units, alleen=['uTrein', 'uLog'])
        map_ = os.path.join(WERK, 'fpc')
        shutil.rmtree(map_, ignore_errors=True)
        os.makedirs(map_)
        for unit, (tekst, _) in resultaat.items():
            procs = set(re.findall(r'^procedure (\w+);$', tekst, re.M))

            def dd(m):
                naam = m.group(2).split('+')[0].strip()
                return m.group(0) if naam.startswith('@@') or naam in procs else m.group(1) + '0 '

            def sprong(m):
                return m.group(0) if m.group(2).strip() in procs else '  db $E8; dd 0 '
            tekst = re.sub(r'^(  dd )([^{\n]*)', dd, tekst, flags=re.M)
            tekst = re.sub(r'^  (call|jmp) ([^{\n]*)', sprong, tekst, flags=re.M)
            tekst = re.sub(r'\nuses\n[^;]*;\n', '\n', tekst)
            tekst = tekst.replace('unit %s;' % unit, 'unit %s;\n{$mode delphi}{$asmmode intel}' % unit, 1)
            pad = os.path.join(map_, unit + '.pas')
            schrijf(pad, tekst.encode('latin1'))
            p = subprocess.run(['fpc', '-Cn', '-FU' + map_, pad], capture_output=True, text=True)
            self.assertEqual(p.returncode, 0, p.stdout[-2000:])


if __name__ == '__main__':
    unittest.main()

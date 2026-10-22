"""Stuur het originele ROS.exe onder Wine aan en lees de spelstatus uit (differentiële-testorakel).

Onder Wine is de Win32-adresruimte het Linux-proces zelf, dus de objecten van het spel kunnen
gelezen (en RandSeed geschreven) worden via /proc/<pid>/mem. Yama ptrace_scope=1 staat dat
alleen toe voor afstammelingen, en Wine forkt dubbel, dus dit script maakt zichzelf eerst
child subreaper.

Invoerscripts worden gedeeld met de draagbare build (zie docs/DIFFTEST.md):
    wait <ms>             slapen
    move <x> <y>          muisbeweging (clientcoördinaten van het hoofdvenster)
    click <x> <y> [right] muisklik
    key <xdotool-key>     toetsdruk (Return, Escape, plus, minus, Left, ...)
    seed <n>              System.RandSeed zetten vlak voor de volgende muisklik
    dump <naam>           de spelstatus schrijven naar <uitvoermap>/<naam>.state
    shot <naam>           schermafdruk naar <uitvoermap>/<naam>.png

Moet draaien op een X-display; tools/difftest.sh omhult het met xvfb-run.
Gebruik: python tools/orig_probe.py <rundir> <script> <uitvoermap>
"""
import os
import struct
import subprocess
import sys
import time

FRMMAIN_PTR = 0x0048950C      # DATA: pointer naar Fmain.frmMain
VMT_TFRMMAIN = 0x0047955C
RANDSEED = 0x0048A03C         # System.RandSeed

# Veldoffsets (zie src/game/Fmain.pas, Uworld.pas, Usett.pas)
FRM_WORLD, FRM_STATUS = 0x424, 0x42C
WORLD_CELLS, WORLD_REISTIJD, WORLD_SIZE = 0x10, 0x1FC8, 45
CELL_CONTENTS, CELL_PARAM, CELL_WIJK, CELL_WEGEN, CELL_BEREIKBAAR = 0x04, 0x08, 0x0C, 0x1C, 0x54
STATUS_SCORE, STATUS_GELD, STATUS_LEVEL = 0x04, 0x08, 0x1C


class Process:
    def __init__(self, pid):
        self.pid = pid
        self.f = open('/proc/%d/mem' % pid, 'rb', buffering=0)

    def read(self, va, n):
        self.f.seek(va)
        return self.f.read(n)

    def write(self, va, data):
        # Schrijven naar /proc/<pid>/mem faalt met EIO op Wine's image-pagina's; process_vm_writev werkt.
        import ctypes

        class IoVec(ctypes.Structure):
            _fields_ = [('base', ctypes.c_void_p), ('len', ctypes.c_size_t)]
        libc = ctypes.CDLL(None, use_errno=True)
        buf = ctypes.create_string_buffer(data, len(data))
        local = IoVec(ctypes.cast(buf, ctypes.c_void_p), len(data))
        remote = IoVec(va, len(data))
        n = libc.process_vm_writev(self.pid, ctypes.byref(local), 1, ctypes.byref(remote), 1, 0)
        if n != len(data):
            raise OSError(ctypes.get_errno(), 'process_vm_writev')

    def u32(self, va):
        return struct.unpack('<I', self.read(va, 4))[0]

    def i32(self, va):
        return struct.unpack('<i', self.read(va, 4))[0]

    def f64(self, va):
        return struct.unpack('<d', self.read(va, 8))[0]

    def dstr(self, va):
        """Delphi AnsiString: pointer naar tekens, lengte op -4."""
        if not va:
            return ''
        n = self.i32(va - 4)
        return self.read(va, n).decode('cp1252')


def state_text(p):
    """Canonieke statusdump; de draagbare build schrijft hetzelfde formaat (src/tests/ZMState.pas)."""
    frm = p.u32(p.u32(FRMMAIN_PTR))
    assert p.u32(frm) == VMT_TFRMMAIN
    world = p.u32(frm + FRM_WORLD)
    status = p.u32(frm + FRM_STATUS)
    out = ['level %d' % p.i32(status + STATUS_LEVEL),
           'geld %d' % p.i32(status + STATUS_GELD),
           'score %d' % p.i32(status + STATUS_SCORE),
           'reistijd %.6f' % p.f64(world + WORLD_REISTIJD)]
    for x in range(WORLD_SIZE):
        for y in range(WORLD_SIZE):
            c = p.u32(world + WORLD_CELLS + 4 * (x * WORLD_SIZE + y))
            out.append('cell %d %d %s %s %d %d %d' % (
                x, y, p.dstr(p.u32(c + CELL_CONTENTS)) or '-', p.dstr(p.u32(c + CELL_PARAM)) or '-',
                p.i32(c + CELL_WIJK), p.i32(c + CELL_WEGEN), p.read(c + CELL_BEREIKBAAR, 1)[0]))
    return '\n'.join(out) + '\n'


def find_game_pid():
    for _ in range(150):
        for d in os.listdir('/proc'):
            if not d.isdigit():
                continue
            try:
                cmd = open('/proc/%s/cmdline' % d, 'rb').read()
            except OSError:
                continue
            if b'ROS.exe' in cmd and b'wineserver' not in cmd:
                try:
                    p = Process(int(d))
                    if p.read(0x400000, 2) == b'MZ':
                        return p
                except OSError:
                    pass
        time.sleep(0.2)
    raise RuntimeError('spelproces niet gevonden')


def become_subreaper():
    import ctypes
    PR_SET_CHILD_SUBREAPER = 36
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'prctl(PR_SET_CHILD_SUBREAPER)')


def window_origin():
    """Schermpositie van het hoofdvenster (bsNone: venster = clientgebied)."""
    for _ in range(100):
        r = subprocess.run(['xdotool', 'search', '--name', '^Virtueel Zoetermeer$'],
                           capture_output=True, text=True)
        for wid in r.stdout.split():
            g = subprocess.run(['xdotool', 'getwindowgeometry', '--shell', wid],
                               capture_output=True, text=True).stdout
            kv = dict(l.split('=') for l in g.split())
            if int(kv['WIDTH']) >= 1000:
                return int(kv['X']), int(kv['Y'])
        time.sleep(0.2)
    raise RuntimeError('hoofdvenster niet gevonden')


def run_script(p, script, outdir):
    origin = []

    def org():
        if not origin:                       # zoek het venster pas op als het er zeker is
            origin.extend(window_origin())
        return origin

    pending_seed = []          # 'seed' werkt vlak voor de volgende muisklik
    for line in open(script):
        f = line.split('#')[0].split()
        if not f:
            continue
        cmd, args = f[0], f[1:]
        if cmd == 'wait':
            time.sleep(int(args[0]) / 1000)
        elif cmd == 'move':
            ox, oy = org()
            subprocess.run(['xdotool', 'mousemove', str(ox + int(args[0])), str(oy + int(args[1]))])
        elif cmd == 'click':
            # De knoppen van het spel zijn sprite-gedrag: ze hebben de hover (muisbeweging) nodig en een
            # echte indruk/loslaat-handeling, geen kortstondige klik.
            # Eén verspringing geeft geen hover: nader het doel van 60 px links in kleine
            # stapjes, zodat de sprite de aankomende aanwijzer ziet.
            button = '3' if args[2:3] == ['right'] else '1'
            ox, oy = org()
            x, y = ox + int(args[0]), oy + int(args[1])
            for i in range(20, -1, -1):
                subprocess.run(['xdotool', 'mousemove', str(x - 3 * i), str(y)])
                time.sleep(0.03)
            time.sleep(0.3)
            if pending_seed:
                p.write(RANDSEED, struct.pack('<i', pending_seed.pop()))
            subprocess.run(['xdotool', 'mousedown', button])
            time.sleep(0.15)
            subprocess.run(['xdotool', 'mouseup', button])
        elif cmd == 'key':
            subprocess.run(['xdotool', 'key', args[0]])
        elif cmd == 'seed':
            pending_seed[:] = [int(args[0])]
        elif cmd == 'dump':
            for attempt in range(20):        # objecten kunnen midden in een update zijn; kort opnieuw proberen
                try:
                    text = state_text(p)
                    break
                except (OSError, AssertionError):
                    time.sleep(0.25)
            else:
                raise RuntimeError('kon de spelstatus niet lezen')
            open(os.path.join(outdir, args[0] + '.state'), 'w').write(text)
        elif cmd == 'shot':
            subprocess.run(['import', '-window', 'root', os.path.join(outdir, args[0] + '.png')])
        else:
            raise ValueError('onbekend scriptcommando: %s' % line)


def main():
    rundir, script, outdir = sys.argv[1:4]
    os.makedirs(outdir, exist_ok=True)
    become_subreaper()
    env = dict(os.environ, WINEDEBUG='-all', WINEDLLOVERRIDES='mscoree,mshtml=')
    wine = subprocess.Popen(['wine', 'ROS.exe'], cwd=rundir, env=env)
    try:
        p = find_game_pid()
        run_script(p, script, outdir)
    finally:
        subprocess.run(['wineserver', '-k'], env=env)
        wine.wait()


if __name__ == '__main__':
    main()

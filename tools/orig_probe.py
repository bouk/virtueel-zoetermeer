"""Drive the original ROS.exe under Wine and dump its game state (differential-testing oracle).

Under Wine the Win32 address space is the Linux process itself, so the game's objects can be
read (and RandSeed written) through /proc/<pid>/mem.  Yama ptrace_scope=1 only permits that
for descendants, and Wine double-forks, so this script makes itself a child subreaper first.

Input scripts are shared with the portable build (see docs/DIFFTEST.md):
    wait <ms>             sleep
    move <x> <y>          mouse move (client coordinates of the main form)
    click <x> <y> [right] mouse click
    key <xdotool-key>     key press (Return, Escape, plus, minus, Left, ...)
    seed <n>              set System.RandSeed
    dump <name>           write the game state to <outdir>/<name>.state
    shot <name>           screenshot to <outdir>/<name>.png

Must run on an X display; tools/difftest.sh wraps it in xvfb-run.
Usage: python tools/orig_probe.py <rundir> <script> <outdir>
"""
import os
import struct
import subprocess
import sys
import time

FRMMAIN_PTR = 0x0048950C      # DATA: pointer to Fmain.frmMain
VMT_TFRMMAIN = 0x0047955C
RANDSEED = 0x0048A03C         # System.RandSeed

# Field offsets (see src/game/Fmain.pas, Uworld.pas, Usett.pas)
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
        with open('/proc/%d/mem' % self.pid, 'r+b', buffering=0) as f:
            f.seek(va)
            f.write(data)

    def u32(self, va):
        return struct.unpack('<I', self.read(va, 4))[0]

    def i32(self, va):
        return struct.unpack('<i', self.read(va, 4))[0]

    def f64(self, va):
        return struct.unpack('<d', self.read(va, 8))[0]

    def dstr(self, va):
        """Delphi AnsiString: pointer to chars, length at -4."""
        if not va:
            return ''
        n = self.i32(va - 4)
        return self.read(va, n).decode('cp1252')


def state_text(p):
    """Canonical state dump; the portable build writes the same format (src/tests/ZMState.pas)."""
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
    raise RuntimeError('game process not found')


def become_subreaper():
    import ctypes
    PR_SET_CHILD_SUBREAPER = 36
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'prctl(PR_SET_CHILD_SUBREAPER)')


def window_origin():
    """Screen position of the main form (bsNone: window = client area)."""
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
    raise RuntimeError('main window not found')


def run_script(p, script, outdir):
    origin = []

    def org():
        if not origin:                       # look the window up once it is surely there
            origin.extend(window_origin())
        return origin

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
            # The game's buttons are sprite behaviours: they need the hover (mouse move) and a
            # real press/release, not an instantaneous click.
            # A single warp produces no hover: enter the target from 60 px to the left in
            # small steps, so the sprite sees the pointer arrive.
            button = '3' if args[2:3] == ['right'] else '1'
            ox, oy = org()
            x, y = ox + int(args[0]), oy + int(args[1])
            for i in range(20, -1, -1):
                subprocess.run(['xdotool', 'mousemove', str(x - 3 * i), str(y)])
                time.sleep(0.03)
            time.sleep(0.3)
            subprocess.run(['xdotool', 'mousedown', button])
            time.sleep(0.15)
            subprocess.run(['xdotool', 'mouseup', button])
        elif cmd == 'key':
            subprocess.run(['xdotool', 'key', args[0]])
        elif cmd == 'seed':
            p.write(RANDSEED, struct.pack('<i', int(args[0])))
        elif cmd == 'dump':
            for attempt in range(20):        # objects may be mid-update; retry briefly
                try:
                    text = state_text(p)
                    break
                except (OSError, AssertionError):
                    time.sleep(0.25)
            else:
                raise RuntimeError('could not read game state')
            open(os.path.join(outdir, args[0] + '.state'), 'w').write(text)
        elif cmd == 'shot':
            subprocess.run(['import', '-window', 'root', os.path.join(outdir, args[0] + '.png')])
        else:
            raise ValueError('unknown script command: %s' % line)


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

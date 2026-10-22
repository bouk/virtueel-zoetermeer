"""Run the original ROS.exe under Wine and read its live memory (differential-testing oracle).

Under Wine the Win32 address space is the Linux process itself, so once the game runs we can
read globals and objects from /proc/<pid>/mem.  Yama ptrace_scope=1 only permits this for
descendants, which is why this script launches Wine itself.

Must run on an X display (use tools/orig-probe.sh, which wraps it in xvfb-run).

Usage: python tools/orig_probe.py <rundir> [seconds] [screenshot.png]
"""
import os
import struct
import subprocess
import sys
import time

FRMMAIN_PTR = 0x0048950C      # DATA: pointer to Fmain.frmMain
VMT_TFRMMAIN = 0x0047955C


class Process:
    def __init__(self, pid):
        self.pid = pid
        self.f = open('/proc/%d/mem' % pid, 'rb', buffering=0)

    def read(self, va, n):
        self.f.seek(va)
        return self.f.read(n)

    def u32(self, va):
        return struct.unpack('<I', self.read(va, 4))[0]

    def i32(self, va):
        return struct.unpack('<i', self.read(va, 4))[0]

    def dstr(self, va):
        """Delphi AnsiString: pointer to chars, length at -4."""
        if not va:
            return ''
        n = self.i32(va - 4)
        return self.read(va, n).decode('cp1252')


def find_game_pid(root_pid):
    """The Wine process whose cmdline mentions ROS.exe, among our descendants."""
    for _ in range(100):
        for d in os.listdir('/proc'):
            if not d.isdigit():
                continue
            try:
                cmd = open('/proc/%s/cmdline' % d, 'rb').read()
            except OSError:
                continue
            if b'ROS.exe' in cmd and b'wineserver' not in cmd and int(d) != root_pid:
                try:
                    p = Process(int(d))
                    if p.read(0x400000, 2) == b'MZ':
                        return p
                except OSError:
                    pass
        time.sleep(0.2)
    raise RuntimeError('game process not found')


def become_subreaper():
    """Wine double-forks, so the game is orphaned; adopt it so Yama lets us read its memory."""
    import ctypes
    PR_SET_CHILD_SUBREAPER = 36
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.prctl(PR_SET_CHILD_SUBREAPER, 1, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), 'prctl(PR_SET_CHILD_SUBREAPER)')


def main():
    become_subreaper()
    rundir = sys.argv[1]
    secs = float(sys.argv[2]) if len(sys.argv) > 2 else 20
    env = dict(os.environ, WINEDEBUG='-all', WINEDLLOVERRIDES='mscoree,mshtml=')
    wine = subprocess.Popen(['wine', 'ROS.exe'], cwd=rundir, env=env)
    try:
        p = find_game_pid(wine.pid)
        time.sleep(secs)
        frm = p.u32(p.u32(FRMMAIN_PTR))
        vmt = p.u32(frm)
        print('frmMain @ %#x, VMT %#x (%s)' % (frm, vmt, 'ok' if vmt == VMT_TFRMMAIN else 'UNEXPECTED'))
        if len(sys.argv) > 3:
            subprocess.run(['import', '-window', 'root', sys.argv[3]], check=False)
    finally:
        subprocess.run(['wineserver', '-k'], env=env)
        wine.wait()


if __name__ == '__main__':
    main()

// Browserhost voor de WebAssembly-build van Virtueel Zoetermeer (src/web/RosWeb.dpr).
//
//  * WASI (wasip1)-subset over een bestandssysteem in het geheugen met de spelgegevens
//    (data.json + data.pack). Paden zijn hoofdletterongevoelig en '\' is een scheidingsteken,
//    zoals op Windows. Bestanden die het spel schrijft (opgeslagen steden, highscore) blijven
//    bewaard in localStorage.
//  * De 'zm'-imports die src/web/ZMWasmBackend.pas gebruikt: framebuffer, invoer, tijd.
//  * Asyncify (binaryen): zm.wait, zm.delay en poll_oneoff pauzeren de module, zodat de
//    blokkerende lussen van het spel de besturing aan de browser teruggeven.
//  * Muisvangst: klikken op het spel vraagt pointer lock aan; terwijl de muis gevangen is ziet
//    het spel een virtuele aanwijzer die via relatieve beweging wordt aangestuurd; wij tekenen
//    die als softwarecursor.

'use strict';

const SCREEN_W = 1024, SCREEN_H = 768;
const DEBUG = /[?&]debug\b/.test(location.search);
// ?nolock: legt de muis nooit vast (geautomatiseerde tests sturen absolute, synthetische events).
const NO_LOCK = /[?&]nolock\b/.test(location.search);
const debug = (...a) => { if (DEBUG) console.log('[zm]', ...a); };

// ---------------------------------------------------------------- bestandssysteem

class FS {
  constructor() {
    this.root = { dir: new Map() };
  }

  static parts(path) {
    const out = [];
    for (const p of path.replace(/\\/g, '/').split('/')) {
      if (p === '' || p === '.') continue;
      if (p === '..') out.pop(); else out.push(p);
    }
    return out;
  }

  lookup(path, base = this.root) {
    let node = base;
    for (const p of FS.parts(path)) {
      if (!node.dir) return null;
      const e = node.dir.get(p.toLowerCase());
      if (!e) return null;
      node = e.node;
    }
    return node;
  }

  // Geeft [bovenliggende node, naam] om het pad aan te maken.
  parentOf(path, base = this.root) {
    const parts = FS.parts(path);
    const name = parts.pop();
    let node = base;
    for (const p of parts) {
      const e = node.dir && node.dir.get(p.toLowerCase());
      if (!e || !e.node.dir) return [null, name];
      node = e.node;
    }
    return [node, name];
  }

  mkdirp(path) {
    let node = this.root;
    for (const p of FS.parts(path)) {
      let e = node.dir.get(p.toLowerCase());
      if (!e) {
        e = { name: p, node: { dir: new Map() } };
        node.dir.set(p.toLowerCase(), e);
      }
      node = e.node;
    }
    return node;
  }

  addFile(path, data, persistent = false) {
    const [parent, name] = this.parentOf(path);
    const dir = parent || this.mkdirp(FS.parts(path).slice(0, -1).join('/'));
    const node = { data, size: data.length, path: '/' + FS.parts(path).join('/'), persistent };
    dir.dir.set(name.toLowerCase(), { name, node });
    return node;
  }
}

const PERSIST_PREFIX = 'zoetermeer:file:';

function persist(node) {
  try {
    let s = '';
    const d = node.data.subarray(0, node.size);
    for (let i = 0; i < d.length; i += 0x8000) s += String.fromCharCode.apply(null, d.subarray(i, i + 0x8000));
    localStorage.setItem(PERSIST_PREFIX + node.path.toLowerCase(), JSON.stringify([node.path, btoa(s)]));
  } catch (e) {
    console.warn('kon niet opslaan', node.path, e);
  }
}

function unpersist(path) {
  try { localStorage.removeItem(PERSIST_PREFIX + path.toLowerCase()); } catch (e) { /* negeren */ }
}

function restorePersisted(fs) {
  try {
    for (let i = 0; i < localStorage.length; i++) {
      const k = localStorage.key(i);
      if (!k.startsWith(PERSIST_PREFIX)) continue;
      const [path, b64] = JSON.parse(localStorage.getItem(k));
      const s = atob(b64);
      const data = new Uint8Array(s.length);
      for (let j = 0; j < s.length; j++) data[j] = s.charCodeAt(j);
      fs.addFile(path, data, true);
    }
  } catch (e) {
    console.warn('opgeslagen bestanden konden niet worden hersteld', e);
  }
}

// ---------------------------------------------------------------- WASI

const E = { SUCCESS: 0, BADF: 8, EXIST: 20, INVAL: 28, ISDIR: 31, NOENT: 44, NOSYS: 52, NOTDIR: 54, NOTEMPTY: 55 };
const FT = { DIR: 3, FILE: 4, CHAR: 2 };

class Wasi {
  constructor(fs, args, env, host) {
    this.fs = fs;
    this.args = args;
    this.env = Object.entries(env).map(([k, v]) => `${k}=${v}`);
    this.host = host;
    this.fds = new Map();
    this.fds.set(0, { kind: 'tty' });
    this.fds.set(1, { kind: 'tty', out: (s) => console.log(s) });
    this.fds.set(2, { kind: 'tty', out: (s) => console.warn(s) });
    this.fds.set(3, { kind: 'dir', node: fs.root, preopen: '/' });
    this.nextFd = 4;
    this.stdoutBuf = ['', '', ''];
  }

  get view() { return new DataView(this.host.memory.buffer); }
  get u8() { return new Uint8Array(this.host.memory.buffer); }

  str(ptr, len) {
    return new TextDecoder('latin1').decode(this.u8.subarray(ptr, ptr + len));
  }

  writeStrings(list, ptrs, buf) {
    const v = this.view, u8 = this.u8;
    for (const s of list) {
      v.setUint32(ptrs, buf, true); ptrs += 4;
      for (let i = 0; i < s.length; i++) u8[buf++] = s.charCodeAt(i) & 0xff;
      u8[buf++] = 0;
    }
  }

  filestat(buf, node) {
    const v = this.view;
    for (let i = 0; i < 64; i += 8) v.setBigUint64(buf + i, 0n, true);
    v.setUint8(buf + 16, node.dir ? FT.DIR : FT.FILE);
    v.setBigUint64(buf + 24, 1n, true);
    v.setBigUint64(buf + 32, BigInt(node.dir ? 0 : node.size), true);
  }

  imports() {
    const self = this;
    const ret = {
      args_sizes_get(argc, size) {
        self.view.setUint32(argc, self.args.length, true);
        self.view.setUint32(size, self.args.reduce((a, s) => a + s.length + 1, 0), true);
        return E.SUCCESS;
      },
      args_get(ptrs, buf) { self.writeStrings(self.args, ptrs, buf); return E.SUCCESS; },
      environ_sizes_get(cnt, size) {
        self.view.setUint32(cnt, self.env.length, true);
        self.view.setUint32(size, self.env.reduce((a, s) => a + s.length + 1, 0), true);
        return E.SUCCESS;
      },
      environ_get(ptrs, buf) { self.writeStrings(self.env, ptrs, buf); return E.SUCCESS; },
      clock_time_get(id, prec, out) {
        return self.host.maybeYield(() => {
          const ns = id === 0 ? BigInt(Date.now()) * 1000000n
                              : BigInt(Math.round(performance.now() * 1e6));
          self.view.setBigUint64(out, ns, true);
          return E.SUCCESS;
        });
      },
      random_get(buf, len) {
        crypto.getRandomValues(self.u8.subarray(buf, buf + len));
        return E.SUCCESS;
      },
      proc_exit(code) { throw new ProcExit(code); },
      sched_yield() { return E.SUCCESS; },

      fd_write(fd, iovs, n, written) {
        const f = self.fds.get(fd);
        if (!f) return E.BADF;
        const v = self.view;
        let total = 0;
        for (let i = 0; i < n; i++) {
          const p = v.getUint32(iovs + 8 * i, true), l = v.getUint32(iovs + 8 * i + 4, true);
          if (f.kind === 'tty') {
            let s = self.stdoutBuf[fd] + self.str(p, l);
            const lines = s.split('\n');
            self.stdoutBuf[fd] = lines.pop();
            for (const line of lines) (f.out || console.log)(line);
          } else if (f.kind === 'file') {
            const node = f.node;
            const pos = f.append ? node.size : f.pos;
            if (pos + l > node.data.length) {
              const nd = new Uint8Array(Math.max(pos + l, node.data.length * 2, 256));
              nd.set(node.data.subarray(0, node.size));
              node.data = nd;
            }
            node.data.set(self.u8.subarray(p, p + l), pos);
            f.pos = pos + l;
            node.size = Math.max(node.size, f.pos);
            f.dirty = true;
          } else return E.BADF;
          total += l;
        }
        v.setUint32(written, total, true);
        return E.SUCCESS;
      },
      fd_read(fd, iovs, n, nread) {
        const f = self.fds.get(fd);
        if (!f) return E.BADF;
        const v = self.view;
        let total = 0;
        if (f.kind === 'file') {
          for (let i = 0; i < n; i++) {
            const p = v.getUint32(iovs + 8 * i, true), l = v.getUint32(iovs + 8 * i + 4, true);
            const k = Math.max(0, Math.min(l, f.node.size - f.pos));
            self.u8.set(f.node.data.subarray(f.pos, f.pos + k), p);
            f.pos += k; total += k;
            if (k < l) break;
          }
        }
        v.setUint32(nread, total, true);
        return E.SUCCESS;
      },
      fd_seek(fd, offset, whence, out) {
        const f = self.fds.get(fd);
        if (!f || f.kind !== 'file') return E.BADF;
        const off = Number(offset);
        const base = whence === 0 ? 0 : whence === 1 ? f.pos : f.node.size;
        if (base + off < 0) return E.INVAL;
        f.pos = base + off;
        self.view.setBigUint64(out, BigInt(f.pos), true);
        return E.SUCCESS;
      },
      fd_tell(fd, out) {
        const f = self.fds.get(fd);
        if (!f || f.kind !== 'file') return E.BADF;
        self.view.setBigUint64(out, BigInt(f.pos), true);
        return E.SUCCESS;
      },
      fd_close(fd) {
        const f = self.fds.get(fd);
        if (!f) return E.BADF;
        if (f.kind === 'file' && f.dirty) persist(f.node);
        self.fds.delete(fd);
        return E.SUCCESS;
      },
      fd_fdstat_get(fd, buf) {
        const f = self.fds.get(fd);
        if (!f) return E.BADF;
        const v = self.view;
        v.setUint8(buf, f.kind === 'tty' ? FT.CHAR : f.kind === 'dir' ? FT.DIR : FT.FILE);
        v.setUint16(buf + 2, f.append ? 1 : 0, true);
        v.setBigUint64(buf + 8, 0xffffffffffffffffn, true);
        v.setBigUint64(buf + 16, 0xffffffffffffffffn, true);
        return E.SUCCESS;
      },
      fd_filestat_get(fd, buf) {
        const f = self.fds.get(fd);
        if (!f) return E.BADF;
        if (f.kind === 'tty') { self.filestat(buf, { size: 0 }); self.view.setUint8(buf + 16, FT.CHAR); return E.SUCCESS; }
        self.filestat(buf, f.node);
        return E.SUCCESS;
      },
      fd_filestat_set_size(fd, size) {
        const f = self.fds.get(fd);
        if (!f || f.kind !== 'file') return E.BADF;
        const n = Number(size);
        if (n > f.node.data.length) {
          const nd = new Uint8Array(n);
          nd.set(f.node.data.subarray(0, f.node.size));
          f.node.data = nd;
        }
        f.node.size = n;
        f.dirty = true;
        return E.SUCCESS;
      },
      fd_filestat_set_times() { return E.SUCCESS; },
      path_filestat_set_times() { return E.SUCCESS; },
      fd_prestat_get(fd, buf) {
        const f = self.fds.get(fd);
        if (!f || !f.preopen) return E.BADF;
        self.view.setUint8(buf, 0);
        self.view.setUint32(buf + 4, f.preopen.length, true);
        return E.SUCCESS;
      },
      fd_prestat_dir_name(fd, buf, len) {
        const f = self.fds.get(fd);
        if (!f || !f.preopen) return E.BADF;
        for (let i = 0; i < len; i++) self.u8[buf + i] = f.preopen.charCodeAt(i);
        return E.SUCCESS;
      },
      fd_readdir(fd, buf, len, cookie, used) {
        const f = self.fds.get(fd);
        if (!f || f.kind !== 'dir') return E.BADF;
        const entries = [['.', f.node], ['..', f.node], ...[...f.node.dir.values()].map(e => [e.name, e.node])];
        const v = self.view;
        let pos = 0;
        for (let i = Number(cookie); i < entries.length && pos < len; i++) {
          const [name, node] = entries[i];
          const head = new DataView(new ArrayBuffer(24));
          head.setBigUint64(0, BigInt(i + 1), true);
          head.setBigUint64(8, BigInt(i + 1), true);
          head.setUint32(16, name.length, true);
          head.setUint8(20, node.dir ? FT.DIR : FT.FILE);
          const bytes = new Uint8Array(24 + name.length);
          bytes.set(new Uint8Array(head.buffer), 0);
          for (let j = 0; j < name.length; j++) bytes[24 + j] = name.charCodeAt(j);
          const k = Math.min(bytes.length, len - pos);
          self.u8.set(bytes.subarray(0, k), buf + pos);
          pos += k;
        }
        v.setUint32(used, pos, true);
        return E.SUCCESS;
      },
      path_filestat_get(fd, flags, path, plen, buf) {
        const d = self.fds.get(fd);
        if (!d || d.kind !== 'dir') return E.BADF;
        const node = self.fs.lookup(self.str(path, plen), d.node);
        if (!node) return E.NOENT;
        self.filestat(buf, node);
        return E.SUCCESS;
      },
      path_open(fd, dirflags, path, plen, oflags, rbase, rinh, fdflags, out) {
        const d = self.fds.get(fd);
        if (!d || d.kind !== 'dir') return E.BADF;
        const p = self.str(path, plen);
        let node = self.fs.lookup(p, d.node);
        if (node && (oflags & 4)) return E.EXIST;                  // O_EXCL
        if (!node) {
          if (!(oflags & 1)) return E.NOENT;                      // O_CREAT
          const [parent, name] = self.fs.parentOf(p, d.node);
          if (!parent) return E.NOENT;
          node = { data: new Uint8Array(256), size: 0, path: '/' + FS.parts(p).join('/'), persistent: true };
          parent.dir.set(name.toLowerCase(), { name, node });
        }
        if ((oflags & 2) && !node.dir) return E.NOTDIR;            // O_DIRECTORY
        const nfd = self.nextFd++;
        if (node.dir) {
          self.fds.set(nfd, { kind: 'dir', node });
        } else {
          const f = { kind: 'file', node, pos: 0, append: !!(fdflags & 1) };
          if (oflags & 8) { node.size = 0; f.dirty = true; }       // O_TRUNC
          self.fds.set(nfd, f);
        }
        self.view.setUint32(out, nfd, true);
        return E.SUCCESS;
      },
      path_create_directory(fd, path, plen) {
        const d = self.fds.get(fd);
        if (!d || d.kind !== 'dir') return E.BADF;
        const p = self.str(path, plen);
        if (self.fs.lookup(p, d.node)) return E.EXIST;
        const [parent, name] = self.fs.parentOf(p, d.node);
        if (!parent) return E.NOENT;
        parent.dir.set(name.toLowerCase(), { name, node: { dir: new Map() } });
        return E.SUCCESS;
      },
      path_remove_directory(fd, path, plen) {
        const d = self.fds.get(fd);
        const p = self.str(path, plen);
        const node = self.fs.lookup(p, d.node);
        if (!node) return E.NOENT;
        if (!node.dir) return E.NOTDIR;
        if (node.dir.size) return E.NOTEMPTY;
        const [parent, name] = self.fs.parentOf(p, d.node);
        parent.dir.delete(name.toLowerCase());
        return E.SUCCESS;
      },
      path_unlink_file(fd, path, plen) {
        const d = self.fds.get(fd);
        const p = self.str(path, plen);
        const node = self.fs.lookup(p, d.node);
        if (!node) return E.NOENT;
        if (node.dir) return E.ISDIR;
        const [parent, name] = self.fs.parentOf(p, d.node);
        parent.dir.delete(name.toLowerCase());
        unpersist(node.path);
        return E.SUCCESS;
      },
      path_rename(fd, path, plen, fd2, path2, plen2) {
        const d = self.fds.get(fd), d2 = self.fds.get(fd2);
        const p = self.str(path, plen), p2 = self.str(path2, plen2);
        const node = self.fs.lookup(p, d.node);
        if (!node) return E.NOENT;
        const [parent, name] = self.fs.parentOf(p, d.node);
        const [parent2, name2] = self.fs.parentOf(p2, d2.node);
        if (!parent2) return E.NOENT;
        parent.dir.delete(name.toLowerCase());
        parent2.dir.set(name2.toLowerCase(), { name: name2, node });
        if (!node.dir) {
          unpersist(node.path);
          node.path = '/' + FS.parts(p2).join('/');
          persist(node);
        }
        return E.SUCCESS;
      },
      path_readlink() { return E.INVAL; },
      // Slapen: een klokabonnement; gepauzeerd via Asyncify, net als zm.delay.
      poll_oneoff(inPtr, outPtr, nsubs, nevents) {
        const v = self.view;
        let ms = 0;
        for (let i = 0; i < nsubs; i++) {
          const sub = inPtr + 48 * i;
          if (v.getUint8(sub + 8) === 0) ms = Math.max(ms, Number(v.getBigUint64(sub + 24, true)) / 1e6);
        }
        return self.host.suspend(ms, () => {
          const v2 = self.view;
          for (let i = 0; i < nsubs; i++) {
            const ev = outPtr + 32 * i;
            v2.setBigUint64(ev, v2.getBigUint64(inPtr + 48 * i, true), true);
            v2.setUint16(ev + 8, 0, true);
            v2.setUint8(ev + 10, v2.getUint8(inPtr + 48 * i + 8));
          }
          v2.setUint32(nevents, nsubs, true);
          return E.SUCCESS;
        });
      },
    };
    return new Proxy(ret, {
      get: (t, k) => t[k] || ((...a) => { console.warn('WASI niet geimplementeerd:', k, a); return E.NOSYS; }),
    });
  }
}

class ProcExit extends Error {
  constructor(code) { super('exit ' + code); this.code = code; }
}

// ---------------------------------------------------------------- invoer

// KeyboardEvent.code -> Windows-virtuele toetscode
const VK = {
  Backspace: 8, Tab: 9, Enter: 13, NumpadEnter: 13, ShiftLeft: 16, ShiftRight: 16,
  ControlLeft: 17, ControlRight: 17, AltLeft: 18, AltRight: 18, Pause: 19, CapsLock: 20,
  Escape: 27, Space: 32, PageUp: 33, PageDown: 34, End: 35, Home: 36,
  ArrowLeft: 37, ArrowUp: 38, ArrowRight: 39, ArrowDown: 40, Insert: 45, Delete: 46,
  NumpadMultiply: 106, NumpadAdd: 107, NumpadSubtract: 109, NumpadDecimal: 110, NumpadDivide: 111,
  Semicolon: 186, Equal: 187, Comma: 188, Minus: 189, Period: 190, Slash: 191, Backquote: 192,
  BracketLeft: 219, Backslash: 220, BracketRight: 221, Quote: 222,
};
function vkOf(code) {
  if (code in VK) return VK[code];
  let m;
  if ((m = /^Key([A-Z])$/.exec(code))) return m[1].charCodeAt(0);
  if ((m = /^Digit([0-9])$/.exec(code))) return 48 + +m[1];
  if ((m = /^Numpad([0-9])$/.exec(code))) return 96 + +m[1];
  if ((m = /^F([0-9]+)$/.exec(code))) return 111 + +m[1];
  return 0;
}
function cp1252(ch) {
  const c = ch.codePointAt(0);
  if (c < 0x80 || (c >= 0xa0 && c <= 0xff)) return c;
  const map = { 0x20ac: 0x80, 0x201a: 0x82, 0x0192: 0x83, 0x201e: 0x84, 0x2026: 0x85, 0x2018: 0x91,
                0x2019: 0x92, 0x201c: 0x93, 0x201d: 0x94, 0x2013: 0x96, 0x2014: 0x97 };
  return map[c] || 0x3f;
}

const EV = { QUIT: 1, MOVE: 2, DOWN: 3, UP: 4, WHEEL: 5, KEYDOWN: 6, KEYUP: 7, TEXT: 8,
             ACTIVATE: 9, DEACTIVATE: 10, EXPOSE: 11, LEAVE: 12 };

// ---------------------------------------------------------------- host

class Host {
  constructor(canvas, overlay, status) {
    this.canvas = canvas;
    this.overlay = overlay;
    this.status = status;
    this.ctx = canvas.getContext('2d');
    this.octx = overlay.getContext('2d');
    this.events = [];
    this.mouse = { x: SCREEN_W / 2, y: SCREEN_H / 2 };
    this.cursorShape = 0;
    this.locked = false;
    this.wake = null;
    this.image = null;
    this.audio = null;
    this.t0 = performance.now();
  }

  // ---- Asyncify
  //
  // Een import die wil blokkeren roept suspend(ms, finish) aan. De eerste keer begint hij met
  // unwinden en keert terug; JS spoelt later terug naar dezelfde import, die dan stopRewind
  // aanroept en de waarde van finish() teruggeeft.
  suspend(ms, finish, wakeOnEvent = false) {
    const ex = this.exports;
    if (this.rewinding) {
      this.rewinding = false;
      ex.asyncify_stop_rewind();
      return finish ? finish() : undefined;
    }
    if (wakeOnEvent && this.events.length) return finish ? finish() : undefined;
    if (!this.asyncData) return finish ? finish() : undefined;   // nog niet geregistreerd: niet opleveren
    const dv = new DataView(this.memory.buffer);
    dv.setUint32(this.asyncData, this.asyncData + 8, true);
    dv.setUint32(this.asyncData + 4, this.asyncData + this.asyncSize, true);
    if (this.runs < 30) debug('suspend', ms, wakeOnEvent, new Error().stack.split('\n')[2]);
    ex.asyncify_start_unwind(this.asyncData);
    this.sleeping = true;
    this.lastYield = performance.now();
    const resume = () => {
      if (this.wake !== resume) return;
      this.wake = null;
      clearTimeout(timer);
      this.rewinding = true;
      ex.asyncify_start_rewind(this.asyncData);
      this.run();
    };
    this.wake = wakeOnEvent ? resume : null;
    const timer = setTimeout(() => { this.wake = resume; resume(); },
                             ms < 0 ? 1e9 : Math.max(0, ms));
    if (!wakeOnEvent) this.wake = null;
    if (!wakeOnEvent) this.pendingTimerResume = resume;
    return finish ? 0 : undefined;
  }

  // Pollinglussen (PeekMessage-pompen, kloklezingen in busy-waits) blokkeren nooit, anders zou de
  // pagina vastlopen; geef de browser een beurt zodra er ~16 ms sinds de vorige is verstreken.
  maybeYield(finish) {
    if (this.rewinding) return this.suspend(0, finish);
    if (performance.now() - this.lastYield < 16) return finish();
    return this.suspend(0, finish);
  }

  run() {
    this.lastYield = performance.now();
    this.runs = (this.runs || 0) + 1;
    if (this.runs < 30 || this.runs % 100 === 1) debug('run', this.runs, 'events', this.events.length,
                                      'memory MiB', this.memory.buffer.byteLength >> 20);
    try {
      this.exports._start();
      if (this.sleeping) {
        this.sleeping = false;
        this.exports.asyncify_stop_unwind();
        return;
      }
      this.finished(0);
    } catch (e) {
      if (e instanceof ProcExit) this.finished(e.code);
      else { this.fail(e); }
    }
  }

  finished(code) {
    this.status.textContent = 'Het spel is afgesloten. Herlaad de pagina om opnieuw te spelen.';
    this.status.hidden = false;
    if (document.pointerLockElement) document.exitPointerLock();
  }

  fail(e) {
    console.error(e);
    this.status.textContent = 'Fout: ' + e;
    this.status.hidden = false;
  }

  push(ev) {
    if (DEBUG && ev.kind !== EV.MOVE) debug('event', JSON.stringify(ev));
    this.events.push(ev);
    if (this.events.length > 512) this.events.splice(0, this.events.length - 512);
    if (this.wake) { const w = this.wake; w(); }
  }

  // ---- importen
  zmImports() {
    const self = this;
    return {
      set_async_buffer(ptr, size) {
        self.asyncData = ptr;
        self.asyncSize = size;
      },
      open(w, h) {
        self.canvas.width = w; self.canvas.height = h;
        self.overlay.width = w; self.overlay.height = h;
        self.image = self.ctx.createImageData(w, h);
      },
      present(ptr, w, h, stride) {
        if (!self.image || self.image.width !== w || self.image.height !== h) self.zm.open(w, h);
        const src = new Uint32Array(self.memory.buffer, ptr, (stride >> 2) * h);
        const dst = new Uint32Array(self.image.data.buffer);
        const sw = stride >> 2;
        for (let y = 0, d = 0; y < h; y++) {
          let s = y * sw;
          for (let x = 0; x < w; x++, s++, d++) {
            const p = src[s];   // $00RRGGBB -> RGBA-bytes (little endian ABGR)
            dst[d] = 0xff000000 | ((p & 0xff) << 16) | (p & 0xff00) | ((p >> 16) & 0xff);
          }
        }
        self.ctx.putImageData(self.image, 0, 0);
      },
      poll_event(buf) {
        return self.maybeYield(() => self.pollEvent(buf));
      },
      ticks() {
        return self.maybeYield(() => performance.now() - self.t0);
      },

      wait(ms) { return self.suspend(ms, null, true); },
      delay(ms) { return self.suspend(ms, null, false); },
      set_title(p) {
        const u8 = new Uint8Array(self.memory.buffer);
        let s = '';
        while (u8[p]) s += String.fromCharCode(u8[p++]);
        if (s) document.title = s;
      },
      set_cursor(shape) { self.cursorShape = shape; self.drawCursor(); },
      beep() {
        try {
          self.audio = self.audio || new AudioContext();
          const o = self.audio.createOscillator(), g = self.audio.createGain();
          o.frequency.value = 800; g.gain.value = 0.05;
          o.connect(g).connect(self.audio.destination);
          o.start(); o.stop(self.audio.currentTime + 0.12);
        } catch (e) { /* geen audio */ }
      },
    };
  }

  pollEvent(buf) {
    const self = this;
    const ev = self.events.shift();
    if (!ev) return 0;
    const v = new DataView(self.memory.buffer);
    const f = [ev.kind, ev.x | 0, ev.y | 0, ev.button | 0, ev.key | 0, ev.scan | 0, ev.repeat ? 1 : 0,
               ev.wheel | 0, ev.shift ? 1 : 0, ev.ctrl ? 1 : 0, ev.alt ? 1 : 0, ev.text ? ev.text.length : 0];
    f.forEach((x, i) => v.setInt32(buf + 4 * i, x, true));
    const u8 = new Uint8Array(self.memory.buffer);
    for (let i = 0; i < 16; i++) u8[buf + 48 + i] = ev.text && i < ev.text.length ? ev.text[i] : 0;
    return 1;
  }

  // ---- aanwijzer
  toScreen(e) {
    const r = this.canvas.getBoundingClientRect();
    return { x: Math.floor((e.clientX - r.left) * SCREEN_W / r.width),
             y: Math.floor((e.clientY - r.top) * SCREEN_H / r.height) };
  }

  mods(e) { return { shift: e.shiftKey, ctrl: e.ctrlKey, alt: e.altKey }; }

  pointerMoved(e) {
    if (this.locked) {
      const r = this.canvas.getBoundingClientRect();
      this.mouse.x = Math.max(0, Math.min(SCREEN_W - 1, this.mouse.x + (e.movementX || 0) * SCREEN_W / r.width));
      this.mouse.y = Math.max(0, Math.min(SCREEN_H - 1, this.mouse.y + (e.movementY || 0) * SCREEN_H / r.height));
    } else {
      this.mouse = this.toScreen(e);
    }
    this.drawCursor();
    this.push({ kind: EV.MOVE, x: Math.round(this.mouse.x), y: Math.round(this.mouse.y), ...this.mods(e) });
  }

  button(e, kind) {
    const b = e.button === 0 ? 1 : e.button === 2 ? 2 : 3;
    if (!this.locked) this.mouse = this.toScreen(e);
    this.push({ kind, x: Math.round(this.mouse.x), y: Math.round(this.mouse.y), button: b, ...this.mods(e) });
  }

  // Terwijl de aanwijzer is vastgelegd verbergt de browser hem: de cursor van het spel tekenen we zelf.
  drawCursor() {
    const c = this.octx;
    c.clearRect(0, 0, this.overlay.width, this.overlay.height);
    if (!this.locked || this.cursorShape === 12) return;
    const x = Math.round(this.mouse.x), y = Math.round(this.mouse.y);
    c.save();
    c.translate(x + 0.5, y + 0.5);
    c.lineWidth = 1;
    c.strokeStyle = '#000';
    c.fillStyle = '#fff';
    c.beginPath();
    if (this.cursorShape === 4) {                       // hand
      c.translate(-5, 0);
      c.moveTo(5, 0); c.lineTo(8, 0); c.lineTo(8, 7); c.lineTo(14, 8); c.lineTo(15, 16);
      c.lineTo(12, 21); c.lineTo(5, 21); c.lineTo(0, 13); c.lineTo(2, 11); c.lineTo(5, 13);
    } else if (this.cursorShape === 1) {                // I-balk
      c.moveTo(-3, -8); c.lineTo(3, -8); c.moveTo(0, -8); c.lineTo(0, 8); c.moveTo(-3, 8); c.lineTo(3, 8);
      c.stroke(); c.restore(); return;
    } else {                                            // pijl
      c.moveTo(0, 0); c.lineTo(0, 16); c.lineTo(4, 12); c.lineTo(7, 19); c.lineTo(9, 18);
      c.lineTo(6, 11); c.lineTo(11, 11);
    }
    c.closePath(); c.fill(); c.stroke();
    c.restore();
  }

  cssCursor() {
    const css = ['default', 'text', 'wait', 'crosshair', 'pointer', 'move', 'ns-resize', 'ew-resize',
                 'nwse-resize', 'nesw-resize', 'not-allowed', 'progress', 'none'];
    this.canvas.style.cursor = css[this.cursorShape] || 'default';
  }

  installInput() {
    const cv = this.overlay;   // de overlay ligt boven het spelcanvas
    cv.addEventListener('contextmenu', (e) => e.preventDefault());
    cv.addEventListener('mousedown', (e) => {
      if (!this.locked && !NO_LOCK && cv.requestPointerLock) {
        // Vang de muis; de klik zelf gaat ook naar het spel.
        this.mouse = this.toScreen(e);
        const p = cv.requestPointerLock({ unadjustedMovement: false });
        if (p && p.catch) p.catch(() => {});
      }
      this.button(e, EV.DOWN);
      e.preventDefault();
    });
    window.addEventListener('mouseup', (e) => this.button(e, EV.UP));
    window.addEventListener('mousemove', (e) => {
      if (this.locked || e.target === cv) this.pointerMoved(e);
    });
    cv.addEventListener('wheel', (e) => {
      this.push({ kind: EV.WHEEL, x: Math.round(this.mouse.x), y: Math.round(this.mouse.y),
                  wheel: e.deltaY < 0 ? 120 : -120, ...this.mods(e) });
      e.preventDefault();
    }, { passive: false });
    document.addEventListener('pointerlockchange', () => {
      this.locked = document.pointerLockElement === cv;
      cv.style.cursor = this.locked ? 'none' : 'default';
      this.drawCursor();
    });
    window.addEventListener('keydown', (e) => {
      const key = vkOf(e.code);
      if (key) this.push({ kind: EV.KEYDOWN, key, repeat: e.repeat, ...this.mods(e) });
      if (e.key.length === 1 && !e.ctrlKey && !e.metaKey)
        this.push({ kind: EV.TEXT, text: [cp1252(e.key)] });
      if (!e.metaKey && !(e.ctrlKey && (e.key === 'r' || e.key === 'R')) && !/^F(5|11|12)$/.test(e.code))
        e.preventDefault();
    });
    window.addEventListener('keyup', (e) => {
      const key = vkOf(e.code);
      if (key) this.push({ kind: EV.KEYUP, key, ...this.mods(e) });
    });
    window.addEventListener('blur', () => this.push({ kind: EV.DEACTIVATE }));
    window.addEventListener('focus', () => this.push({ kind: EV.ACTIVATE }));
  }

  async start(wasmUrl, dataUrl) {
    this.status.textContent = 'Spel laden…';
    const fs = new FS();
    const [index, pack, wasm] = await Promise.all([
      fetch(dataUrl + '.json').then(r => r.json()),
      fetch(dataUrl + '.pack').then(r => r.arrayBuffer()),
      fetch(wasmUrl).then(r => r.arrayBuffer()),
    ]);
    const bytes = new Uint8Array(pack);
    for (const [path, off, size] of index.files) fs.addFile(path, bytes.subarray(off, off + size));
    debug('data loaded', index.files.length, 'files');
    restorePersisted(fs);

    const wasi = new Wasi(fs, ['ROS.exe'], { ZM_DATA: index.dataDir, ZM_EXE: index.exe }, this);
    this.zm = this.zmImports();
    const { instance } = await WebAssembly.instantiate(wasm, {
      wasi_snapshot_preview1: wasi.imports(),
      zm: this.zm,
    });
    this.exports = instance.exports;
    this.memory = instance.exports.memory;
    // De Asyncify-buffer staat in het datasegment van het programma; de eerste unit die wordt
    // geinitialiseerd (src/web/ZMAsyncStack.pas) registreert hem via zm.set_async_buffer.
    this.asyncData = 0;
    this.installInput();
    this.status.hidden = true;
    this.run();
  }
}

window.ZoetermeerHost = Host;

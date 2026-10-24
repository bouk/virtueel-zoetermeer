import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../zoetermeer.js', import.meta.url), 'utf8');

function browser(storage = new Map()) {
  const listeners = {};
  const context = vm.createContext({
    console, performance, TextDecoder, atob, btoa,
    location: { search: '' },
    window: { addEventListener: (name, handler) => { listeners[name] = handler; } },
    localStorage: {
      get length() { return storage.size; },
      key: i => [...storage.keys()][i],
      getItem: key => storage.get(key) ?? null,
      setItem: (key, value) => storage.set(key, value),
      removeItem: key => storage.delete(key),
    },
  });
  vm.runInContext(source + '\nglobalThis.testing = { FS, Wasi, restorePersisted };', context);
  return { ...context.testing, Host: context.window.ZoetermeerHost, listeners };
}

test('clicking an embedded game takes keyboard focus before forwarding input', () => {
  const { Host, listeners } = browser();
  let focused = false;
  const overlay = {
    style: {},
    addEventListener: (name, handler) => { listeners[name] = handler; },
    focus(options) {
      assert.equal(options.preventScroll, true);
      focused = true;
    },
  };
  const canvas = {
    getContext: () => ({}),
    getBoundingClientRect: () => ({ left: 100, top: 50, width: 512, height: 384 }),
  };
  const host = new Host(canvas, overlay, {});
  host.installInput();
  assert.equal(overlay.tabIndex, 0);
  host.wake = () => {
    assert.equal(focused, true, 'the iframe must have focus before the game handles the click');
  };
  listeners.mousedown({ clientX: 356, clientY: 242, button: 0, preventDefault() {} });
  const down = host.events.shift();
  assert.equal(down.x, 512);
  assert.equal(down.y, 384);
  for (const key of 'Mijn stad') {
    listeners.keydown({ key, code: key === ' ' ? 'Space' : 'Key' + key.toUpperCase(), preventDefault() {} });
  }
  assert.equal(host.events.filter(event => event.kind === 8)
    .map(event => String.fromCharCode(...event.text)).join(''), 'Mijn stad');
});

test('WASI saves survive a fresh host and can be reopened byte for byte', () => {
  const storage = new Map();
  function session() {
    const { FS, Wasi, restorePersisted } = browser(storage);
    const fs = new FS();
    fs.mkdirp('/data');
    restorePersisted(fs);
    const memory = new WebAssembly.Memory({ initial: 1 });
    const wasi = new Wasi(fs, [], {}, { memory });
    return { fs, wasi, api: wasi.imports(), bytes: new Uint8Array(memory.buffer), view: new DataView(memory.buffer) };
  }
  function open(s, path, flags) {
    s.bytes.set(Buffer.from(path), 128);
    assert.equal(s.api.path_open(3, 0, 128, path.length, flags, 0n, 0n, 0, 64), 0);
    return s.view.getUint32(64, true);
  }
  const first = session();
  const fd = open(first, 'data/Mijn stad.sav', 1 | 8);
  const contents = Buffer.from([0, 1, 13, 10, 127, 128, 255]);
  first.bytes.set(contents, 256);
  first.view.setUint32(16, 256, true);
  first.view.setUint32(20, contents.length, true);
  assert.equal(first.api.fd_write(fd, 16, 1, 32), 0);
  assert.equal(first.api.fd_close(fd), 0);
  assert.equal(storage.size, 1);

  const second = session();
  const saved = open(second, 'data/mijn STAD.sav', 0);
  second.view.setUint32(16, 256, true);
  second.view.setUint32(20, 32, true);
  assert.equal(second.api.fd_read(saved, 16, 1, 32), 0);
  assert.equal(second.view.getUint32(32, true), contents.length);
  assert.deepEqual(Buffer.from(second.bytes.subarray(256, 256 + contents.length)), contents);
  assert.equal(second.api.fd_close(saved), 0);
});

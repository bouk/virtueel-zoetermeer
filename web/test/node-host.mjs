// Draai de webversie in node (zonder browser) voor foutopsporing: DOM-objecten zijn nep.
// Gebruik: node web/test/node-host.mjs build/web [seconden]
import fs from 'fs';
import path from 'path';
import vm from 'vm';

const dir = process.argv[2] || 'build/web';
const seconds = +(process.argv[3] || 10);
const canvas = () => ({
  width: 0, height: 0, style: {},
  getContext: () => ({
    createImageData: (w, h) => ({ width: w, height: h, data: new Uint8ClampedArray(w * h * 4) }),
    putImageData() {}, clearRect() {}, save() {}, restore() {}, translate() {}, beginPath() {},
    moveTo() {}, lineTo() {}, closePath() {}, fill() {}, stroke() {},
  }),
  getBoundingClientRect: () => ({ left: 0, top: 0, width: 1024, height: 768 }),
  addEventListener() {}, requestPointerLock() {},
});
const ctx = {
  console, setTimeout, clearTimeout, performance, TextDecoder, crypto: globalThis.crypto,
  WebAssembly, URL, BigInt, DataView, Uint8Array, Uint32Array, Map, Promise, Error, JSON,
  atob, btoa, Math, Number, String, Object, Array, Proxy,
  location: { search: '?debug' },
  document: { title: '', pointerLockElement: null, addEventListener() {}, exitPointerLock() {} },
  window: { addEventListener() {} },
  localStorage: { length: 0, key: () => null, getItem: () => null, setItem() {}, removeItem() {} },
  fetch: async (u) => {
    const b = fs.readFileSync(path.join(dir, u));
    return { json: async () => JSON.parse(b), arrayBuffer: async () => b.buffer.slice(b.byteOffset, b.byteOffset + b.length) };
  },
};
ctx.window = ctx;
ctx.addEventListener = () => {};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(path.join(dir, 'zoetermeer.js'), 'utf8'), ctx);
const status = { textContent: '', hidden: false };
const host = new ctx.ZoetermeerHost(canvas(), canvas(), status);
host.start('zoetermeer.wasm', 'data').catch((e) => { console.error('start:', e); process.exit(1); });
setTimeout(() => { console.log('status:', status.textContent, 'runs:', host.runs); process.exit(0); }, seconds * 1000);

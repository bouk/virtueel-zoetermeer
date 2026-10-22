// Minimal Asyncify driver + WASI subset for testing an FPC wasip1 program under node.
import fs from 'fs';
const bytes = fs.readFileSync(process.argv[2]);
let inst, mem;
const DATA = 16; // asyncify data struct at a scratch address we allocate below
let dataPtr = 0, sleeping = false, resumeValue = 0;
const view = () => new DataView(mem.buffer);
const wasi = {
  fd_write(fd, iovs, n, nw) { let s = ''; for (let i = 0; i < n; i++) { const p = view().getUint32(iovs + 8*i, true), l = view().getUint32(iovs + 8*i + 4, true); s += Buffer.from(mem.buffer, p, l).toString('latin1'); } process.stdout.write(s); view().setUint32(nw, s.length, true); return 0; },
  proc_exit(c) { throw {exit: c}; },
  environ_sizes_get(a, b) { view().setUint32(a, 0, true); view().setUint32(b, 0, true); return 0; },
  environ_get() { return 0; }, args_sizes_get(a, b) { view().setUint32(a, 0, true); view().setUint32(b, 0, true); return 0; }, args_get() { return 0; },
  clock_time_get(id, prec, out) { view().setBigUint64(out, BigInt(Date.now()) * 1000000n, true); return 0; },
  fd_close() { return 0; }, fd_seek() { return 0; }, fd_fdstat_get() { return 0; }, random_get() { return 0; },
};
const zm = {
  wait(ms) {
    if (!sleeping) {               // first entry: start unwinding, resume later
      sleeping = true;
      inst.exports.asyncify_start_unwind(dataPtr);
      setTimeout(() => { resumeValue = ms * 2; inst.exports.asyncify_start_rewind(dataPtr); run(); }, ms);
      return 0;
    }
    sleeping = false;              // rewinding: return the value
    inst.exports.asyncify_stop_rewind();
    return resumeValue;
  },
};
const imports = { wasi_snapshot_preview1: new Proxy(wasi, { get: (t, k) => t[k] || (() => { return 52; }) }), zm };
const { instance } = await WebAssembly.instantiate(bytes, imports);
inst = instance; mem = inst.exports.memory;
// carve an asyncify buffer at the end of memory
const pages = mem.grow(4); dataPtr = pages * 65536;
view().setUint32(dataPtr, dataPtr + 8, true); view().setUint32(dataPtr + 4, dataPtr + 4 * 65536, true);
function run() {
  try { inst.exports._start(); } catch (e) { if (e.exit !== undefined) { console.log('exit', e.exit); return; } throw e; }
  if (sleeping) inst.exports.asyncify_stop_unwind();
}
run();

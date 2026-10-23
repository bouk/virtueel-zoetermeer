import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, stat, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { brotliDecompressSync, gunzipSync } from 'node:zlib';
import { test } from 'node:test';
import { prepareDeploy } from './prepare-deploy.mjs';
import worker from '../web/deploy-worker.mjs';

test('pack compression is lossless; code stays unchanged; data URLs track content', async t => {
  const root = await mkdtemp(path.join(os.tmpdir(), 'zoetermeer-deploy-'));
  t.after(() => rm(root, { recursive: true, force: true }));
  const source = path.join(root, 'source');
  const output = path.join(root, 'deploy');
  await mkdir(source);
  const wasm = Buffer.from([0, 97, 115, 109, 1, 0, 0, 0]);
  const pack = Buffer.from('a representative bitmap byte pattern\0'.repeat(10000));
  const files = {
    'index.html': '<script src="zoetermeer.js"></script><script>host.start(\'zoetermeer.wasm\', \'data\')</script>',
    'zoetermeer.js': '/* unmodified game host */',
    'zoetermeer.wasm': wasm,
    'data.json': '{"files":[["/data/test",0,36]]}',
    'data.pack': pack,
  };
  await Promise.all(Object.entries(files).map(([name, data]) => writeFile(path.join(source, name), data)));
  const first = await prepareDeploy(source, output);
  assert.ok(first.compressed < first.original / 10);
  assert.deepEqual(brotliDecompressSync(await readFile(path.join(output, first.dataName + '.pack.br'))), pack);
  for (const name of ['zoetermeer.js', 'zoetermeer.wasm'])
    assert.deepEqual(await readFile(path.join(output, name)), await readFile(path.join(source, name)));
  assert.equal(await readFile(path.join(output, first.dataName + '.json'), 'utf8'), files['data.json']);
  assert.match(await readFile(path.join(output, 'index.html'), 'utf8'), new RegExp(first.dataName));
  const headers = await readFile(path.join(output, '_headers'), 'utf8');
  assert.ok(!headers.includes('Content-Encoding'));
  assert.match(headers, /max-age=31536000, immutable/);
  assert.ok(!headers.includes('zoetermeer.wasm'));
  const env = { ASSETS: { fetch: async request => {
    const file = path.join(output, new URL(request.url).pathname);
    return new Response(await readFile(file));
  } } };
  for (const [accept, encoding] of [['br, gzip', 'br'], ['br;q=0, gzip', 'gzip'], ['identity', null]]) {
    const response = await worker.fetch(new Request(`https://example.com/${first.dataName}.pack`, {
      headers: { 'Accept-Encoding': accept },
    }), env);
    assert.equal(response.headers.get('Content-Encoding'), encoding);
    assert.equal(response.headers.get('Vary'), 'Accept-Encoding');
    const data = Buffer.from(await response.arrayBuffer());
    const decoded = encoding === 'br' ? brotliDecompressSync(data) : encoding === 'gzip' ? gunzipSync(data) : data;
    assert.deepEqual(decoded, pack);
  }
  const wasmResponse = await worker.fetch(new Request('https://example.com/zoetermeer.wasm'), env);
  assert.deepEqual(Buffer.from(await wasmResponse.arrayBuffer()), wasm);
  const normalized = new Request(`https://example.com/${first.dataName}.pack`, {
    headers: { 'Accept-Encoding': 'br, gzip' },
  });
  Object.defineProperty(normalized, 'cf', { value: { clientAcceptEncoding: 'gzip' } });
  assert.equal((await worker.fetch(normalized, env)).headers.get('Content-Encoding'), 'gzip');
  const before = await stat(path.join(output, first.dataName + '.pack.br'));
  assert.deepEqual(await prepareDeploy(source, output), first);
  assert.equal((await stat(path.join(output, first.dataName + '.pack.br'))).mtimeMs, before.mtimeMs);
  await writeFile(path.join(source, 'data.pack'), Buffer.concat([pack, Buffer.from('updated')]));
  const second = await prepareDeploy(source, output);
  assert.notEqual(second.dataName, first.dataName);
  const ignore = await readFile(path.join(output, '.assetsignore'), 'utf8');
  assert.ok(ignore.includes('!' + second.dataName + '.pack.br'));
  assert.ok(!ignore.includes(first.dataName));
  // Preparing production assets never modifies the development build.
  assert.deepEqual(await readFile(path.join(source, 'zoetermeer.wasm')), wasm);
});

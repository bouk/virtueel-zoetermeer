import assert from 'node:assert/strict';
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { test } from 'node:test';
import { prepareDeploy } from './prepare-deploy.mjs';

test('all assets stay unchanged, allow CDN compression, and use versioned caching', async t => {
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
  assert.deepEqual(await readFile(path.join(output, first.dataName + '.pack')), pack);
  for (const name of ['zoetermeer.js', 'zoetermeer.wasm'])
    assert.deepEqual(await readFile(path.join(output, name)), await readFile(path.join(source, name)));
  assert.deepEqual(await readFile(path.join(output, first.wasmName)), wasm);
  assert.equal(await readFile(path.join(output, first.scriptName), 'utf8'), files['zoetermeer.js']);
  assert.equal(await readFile(path.join(output, first.dataName + '.json'), 'utf8'), files['data.json']);
  assert.match(await readFile(path.join(output, 'index.html'), 'utf8'), new RegExp(first.dataName));
  const page = await readFile(path.join(output, 'index.html'), 'utf8');
  assert.ok(page.includes(`src="${first.scriptName}"`));
  assert.ok(page.includes(`host.start('${first.wasmName}', '${first.dataName}')`));
  const headers = await readFile(path.join(output, '_headers'), 'utf8');
  assert.ok(!headers.includes('Content-Encoding'));
  assert.ok(!headers.includes('no-transform'));
  assert.match(headers, /max-age=31536000, immutable/);
  const rules = headers.trim().split(/\n\n/).map(block => block.split('\n'));
  const policy = pathname => rules.find(([pattern]) => pattern === pathname)?.slice(1).join('\n');
  assert.match(policy('/assets/*'), /Cache-Control: public, max-age=31536000, immutable/);
  assert.match(policy('/'), /max-age=60, must-revalidate/);
  assert.match(policy('/index.html'), /max-age=60, must-revalidate/);
  assert.match(policy('/zoetermeer.wasm'), /max-age=3600/);
  assert.match(policy('/zoetermeer.js'), /max-age=3600/);
  assert.deepEqual(await prepareDeploy(source, output), first);
  await writeFile(path.join(source, 'data.pack'), Buffer.concat([pack, Buffer.from('updated')]));
  const second = await prepareDeploy(source, output);
  assert.notEqual(second.dataName, first.dataName);
  assert.equal(second.wasmName, first.wasmName);
  assert.equal(second.scriptName, first.scriptName);
  const ignore = await readFile(path.join(output, '.assetsignore'), 'utf8');
  assert.ok(ignore.includes('!' + second.dataName + '.pack'));
  assert.ok(!ignore.includes(first.dataName));
  assert.ok(!ignore.includes('.pack.br'));
  assert.ok(!ignore.includes('.pack.gz'));
  // Preparing production assets never modifies the development build.
  assert.deepEqual(await readFile(path.join(source, 'zoetermeer.wasm')), wasm);
  await writeFile(path.join(source, 'zoetermeer.js'), '// updated host');
  const third = await prepareDeploy(source, output);
  assert.notEqual(third.scriptName, second.scriptName);
  assert.equal(third.wasmName, second.wasmName);
  assert.equal(third.dataName, second.dataName);
  const updatedWasm = Buffer.concat([wasm, Buffer.from([0, 1, 0])]);
  await writeFile(path.join(source, 'zoetermeer.wasm'), updatedWasm);
  const fourth = await prepareDeploy(source, output);
  assert.notEqual(fourth.wasmName, third.wasmName);
  assert.equal(fourth.scriptName, third.scriptName);
  assert.equal(fourth.dataName, third.dataName);
  assert.deepEqual(await readFile(path.join(output, fourth.wasmName)), updatedWasm);
});

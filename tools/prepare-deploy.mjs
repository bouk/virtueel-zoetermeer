#!/usr/bin/env node
// Fingerprint the unmodified web assets. Cloudflare handles transfer compression.
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile, copyFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));

export async function prepareDeploy(source, output) {
  const [html, index, pack, script, wasm] = await Promise.all(
    ['index.html', 'data.json', 'data.pack', 'zoetermeer.js', 'zoetermeer.wasm']
      .map(name => readFile(path.join(source, name))),
  );
  // Version the index and pack together so a cached index cannot point into
  // another pack. Immutable URLs also avoid downloading this data after updates
  // that only change the game code.
  const hash = createHash('sha256').update(index).update(pack).digest('hex').slice(0, 16);
  const dataName = `assets/data.${hash}`;
  const fingerprint = data => createHash('sha256').update(data).digest('hex').slice(0, 16);
  const scriptName = `assets/zoetermeer.${fingerprint(script)}.js`;
  const wasmName = `assets/zoetermeer.${fingerprint(wasm)}.wasm`;
  const reference = "host.start('zoetermeer.wasm', 'data')";
  if (!html.toString().includes(reference) || !html.toString().includes('src="zoetermeer.js"'))
    throw new Error('Missing game asset reference in index.html');
  const page = html.toString()
    .replace(reference, `host.start('${wasmName}', '${dataName}')`)
    .replace('src="zoetermeer.js"', `src="${scriptName}"`);
  await mkdir(path.join(output, 'assets'), { recursive: true });
  // All asset bytes stay unchanged; compression belongs to Cloudflare.
  await Promise.all([
    ...['zoetermeer.js', 'zoetermeer.wasm'].map(name => copyFile(path.join(source, name), path.join(output, name))),
    writeFile(path.join(output, scriptName), script),
    writeFile(path.join(output, wasmName), wasm),
    writeFile(path.join(output, dataName + '.json'), index),
    writeFile(path.join(output, dataName + '.pack'), pack),
    writeFile(path.join(output, 'index.html'), page),
    writeFile(path.join(output, '_headers'),
      '/\n  Cache-Control: public, max-age=60, must-revalidate\n\n' +
      '/index.html\n  Cache-Control: public, max-age=60, must-revalidate\n\n' +
      '/zoetermeer.js\n  Cache-Control: public, max-age=3600, must-revalidate\n\n' +
      '/zoetermeer.wasm\n  Cache-Control: public, max-age=3600, must-revalidate\n\n' +
      '/assets/*\n  Cache-Control: public, max-age=31536000, immutable\n\n' +
      `/${dataName}.pack\n  Content-Type: application/octet-stream\n`),
    // Ignore previous generated packs as well as any unrelated files.
    writeFile(path.join(output, '.assetsignore'),
      '*\n!index.html\n!_headers\n!zoetermeer.js\n!zoetermeer.wasm\n!assets/\nassets/*\n' +
      `!${dataName}.pack\n!${dataName}.json\n!${scriptName}\n!${wasmName}\n`),
  ]);
  return { dataName, scriptName, wasmName, size: pack.length };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { dataName, size } = await prepareDeploy(
    path.resolve(process.argv[2] || path.join(root, 'build/web')),
    path.resolve(process.argv[3] || path.join(root, 'build/deploy')),
  );
  console.log(`${dataName}.pack: ${size.toLocaleString('en-US')} bytes (Cloudflare handles compression)`);
}

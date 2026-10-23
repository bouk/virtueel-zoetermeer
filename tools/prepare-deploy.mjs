#!/usr/bin/env node
// data.pack has no compressible MIME type on the CDN. Compress it once at
// deployment time; Content-Encoding lets the browser decode it transparently.
import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile, copyFile } from 'node:fs/promises';
import path from 'node:path';
import { brotliCompressSync, brotliDecompressSync, gzipSync, constants } from 'node:zlib';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));

export async function prepareDeploy(source, output) {
  const [html, index, pack] = await Promise.all(
    ['index.html', 'data.json', 'data.pack'].map(name => readFile(path.join(source, name))),
  );
  // Version the index and pack together so a cached index cannot point into
  // another pack. Immutable URLs also avoid downloading this data after updates
  // that only change the game code.
  const hash = createHash('sha256').update(index).update(pack).digest('hex').slice(0, 16);
  const dataName = `assets/data.${hash}`;
  const reference = "host.start('zoetermeer.wasm', 'data')";
  if (!html.toString().includes(reference)) throw new Error('Missing game asset reference in index.html');
  const page = html.toString().replace(reference, `host.start('zoetermeer.wasm', '${dataName}')`);
  await mkdir(path.join(output, 'assets'), { recursive: true });
  const packPath = path.join(output, dataName + '.pack.br');
  let compressed;
  try {
    const cached = await readFile(packPath);
    if (brotliDecompressSync(cached).equals(pack)) compressed = cached;
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  if (!compressed) {
    compressed = brotliCompressSync(pack, {
      params: {
        [constants.BROTLI_PARAM_QUALITY]: 11,
        [constants.BROTLI_PARAM_LGWIN]: 24,
      },
    });
    await writeFile(packPath, compressed);
  }
  // Keep the existing WASM and JS byte-for-byte. Only the pack is precompressed.
  await Promise.all([
    ...['zoetermeer.js', 'zoetermeer.wasm'].map(name => copyFile(path.join(source, name), path.join(output, name))),
    writeFile(path.join(output, dataName + '.json'), index),
    writeFile(path.join(output, dataName + '.pack.gz'), gzipSync(pack, { level: 9 })),
    writeFile(path.join(output, 'index.html'), page),
    writeFile(path.join(output, '_headers'),
      `/${dataName}.pack.*\n  Content-Type: application/octet-stream\n` +
      '  Cache-Control: public, max-age=31536000, immutable, no-transform\n\n' +
      `/${dataName}.json\n  Cache-Control: public, max-age=31536000, immutable\n`),
    // Ignore previous generated packs as well as any unrelated files.
    writeFile(path.join(output, '.assetsignore'),
      '*\n!index.html\n!_headers\n!zoetermeer.js\n!zoetermeer.wasm\n!assets/\nassets/*\n' +
      `!${dataName}.pack.br\n!${dataName}.pack.gz\n!${dataName}.json\n`),
  ]);
  return { dataName, original: pack.length, compressed: compressed.length };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const { dataName, original, compressed } = await prepareDeploy(
    path.resolve(process.argv[2] || path.join(root, 'build/web')),
    path.resolve(process.argv[3] || path.join(root, 'build/deploy')),
  );
  console.log(`${dataName}.pack: ${original.toLocaleString('en-US')} → ${compressed.toLocaleString('en-US')} bytes ` +
    `(${(100 * (1 - compressed / original)).toFixed(1)}% smaller)`);
}

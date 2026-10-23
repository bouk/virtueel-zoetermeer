// Serve the precompressed pack without making Workers encode it a second time.
// All existing static files (including WASM) still use asset-first delivery.
function quality(header, encoding) {
  const entries = header.toLowerCase().split(',').map(value => value.trim().split(';'));
  const entry = entries.find(([name]) => name === encoding) || entries.find(([name]) => name === '*');
  if (!entry) return 0;
  const q = entry.slice(1).map(value => value.trim()).find(value => value.startsWith('q='));
  return q ? Number(q.slice(2)) || 0 : 1;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (!/^\/assets\/data\.[a-f0-9]{16}\.pack$/.test(url.pathname))
      return env.ASSETS.fetch(request);
    // Cloudflare normalizes the header to "br, gzip"; use the client's original
    // preferences so gzip-only clients also receive a compressed response.
    const accept = request.cf?.clientAcceptEncoding ?? request.headers.get('Accept-Encoding') ?? '';
    const br = quality(accept, 'br');
    const gzip = quality(accept, 'gzip');
    const encoding = br > 0 && br >= gzip ? 'br' : gzip > 0 ? 'gzip' : null;
    url.pathname += encoding === 'br' ? '.br' : '.gz';
    const asset = await env.ASSETS.fetch(new Request(url, request));
    if (asset.status !== 200 && asset.status !== 304 && asset.status !== 206) return asset;
    const headers = new Headers(asset.headers);
    headers.set('Content-Type', 'application/octet-stream');
    headers.set('Cache-Control', 'public, max-age=31536000, immutable, no-transform');
    headers.set('Vary', 'Accept-Encoding');
    headers.delete('Content-Length');
    let body = asset.body;
    if (encoding) headers.set('Content-Encoding', encoding);
    else {
      // Keep non-Brotli clients working too, without uploading the 23 MB original.
      headers.delete('Content-Encoding');
      if (body) body = body.pipeThrough(new DecompressionStream('gzip'));
    }
    return new Response(body, { status: asset.status, headers, encodeBody: 'manual' });
  },
};

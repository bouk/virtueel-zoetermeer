# Cloudflare deployment

The WebAssembly game is hosted at https://virtueelzoetermeer.bou.ke using
Cloudflare Workers Static Assets. `wrangler.toml` configures the custom domain
and uploads only `build/deploy/`.

Build the game with the toolchain described in [WASM.md](WASM.md):

```sh
tools/bouw-web.sh /path/to/game /path/to/v1.1/ROS.exe
```

The output must contain `index.html`, `zoetermeer.js`, `zoetermeer.wasm`,
`data.json`, and `data.pack`. The data package includes the original game
resources and is uploaded with the game. Build outputs and original game files
remain ignored by Git.

With Wrangler authenticated to the configured Cloudflare account (deployment
verified with Wrangler 4.152.0):

```sh
npx --yes wrangler@4.152.0 deploy --dry-run
npx --yes wrangler@4.152.0 deploy
```

Wrangler runs `node tools/prepare-deploy.mjs` before deployment. It copies the
WASM and JavaScript unchanged from `build/web/`, and compresses `data.pack` with
Brotli quality 11. A small Worker serves the compressed pack with
`Content-Encoding: br` and `encodeBody: manual`, so the browser decodes it
automatically and Cloudflare does not compress it a second time. Gzip and
uncompressed responses are available for clients without Brotli support. No
client-side decompression code or game-data changes are needed. Other files,
including WASM, keep the existing asset-first delivery.

All game assets (WASM, JavaScript, pack, and data index) have content hashes in
their URLs and `Cache-Control: public, max-age=31536000, immutable`. Browser
revisits reuse them without network revalidation. Each URL changes only when
its contents change; the pack and index share a hash so they always match.
The homepage is cached for 60 seconds and then revalidated to discover updates.
The original unversioned JS/WASM URLs remain available with a one-hour cache
for compatibility. Their bytes remain unchanged by deployment packaging.
Previous assets and unrelated files are excluded from uploads using `.assetsignore`.
`build/web/` remains an ordinary uncompressed build for local development.

To prepare production files or test the packaging independently:

```sh
node tools/prepare-deploy.mjs
node --test tools/test-prepare-deploy.mjs
```

Wrangler provisions the custom domain's DNS record and TLS certificate.
Saved cities stay in each browser's local storage and are separate from saves
on localhost or other domains.

See Cloudflare's [Static Assets documentation](https://developers.cloudflare.com/workers/static-assets/)
and [Custom Domains documentation](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/).

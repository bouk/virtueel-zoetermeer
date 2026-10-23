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

With Wrangler installed and authenticated to the configured Cloudflare account:

```sh
wrangler deploy --dry-run
wrangler deploy
```

Wrangler runs `node tools/prepare-deploy.mjs` before deployment. It copies the
WASM and JavaScript unchanged from `build/web/`, and compresses `data.pack` with
Brotli quality 11. A small Worker serves the compressed pack with
`Content-Encoding: br` and `encodeBody: manual`, so the browser decodes it
automatically and Cloudflare does not compress it a second time. Gzip and
uncompressed responses are available for clients without Brotli support. No
client-side decompression code or game-data changes are needed. Other files,
including WASM, keep the existing asset-first delivery.

The pack and its index share a content hash in their filenames and can be
cached for a year. Changing either file produces new URLs. Previous packs and
unrelated files are excluded from uploads using the generated `.assetsignore`.
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

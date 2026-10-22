# Cloudflare deployment

The WebAssembly game is hosted at https://virtueelzoetermeer.bou.ke using
Cloudflare Workers Static Assets. `wrangler.toml` configures the custom domain
and uploads only `build/web/`.

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

Wrangler provisions the custom domain's DNS record and TLS certificate.
Saved cities stay in each browser's local storage and are separate from saves
on localhost or other domains.

See Cloudflare's [Static Assets documentation](https://developers.cloudflare.com/workers/static-assets/)
and [Custom Domains documentation](https://developers.cloudflare.com/workers/configuration/routing/custom-domains/).

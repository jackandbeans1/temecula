# temecula

Client-side chat app. Static files, no build step.

## run

    ./serve.ps1

Prints a localhost and a LAN URL. Open the LAN one on a phone.

Keys go in `.dev.vars` (gitignored), read by `serve.ps1`:

    VENICE_API_KEY=VENICE_INFERENCE_KEY_...
    OPEN_ROUTER=sk-or-v1-...

Without that file the proxy returns 502 and the app falls back to the key in `data.js`.

## proxy

`PROXY` in `data.js` ships `false` — the browser sends keys directly, which works on any static host including GitHub Pages.

Set it `true` and deploy to Cloudflare Pages and keys leave the bundle entirely:

    npx wrangler pages deploy . --project-name temecula

Set `VENICE_API_KEY` / `OPEN_ROUTER` as Pages secrets first. Pages Functions don't run on GitHub Pages.

## test

Desktop, Chrome, F12, Ctrl+Shift+M, iPhone 14 Pro, then reload with emulation already on. Check: two-column grid, chat opens full-screen, composer clears the keyboard, no horizontal scroll, no console 404s. Rotate to landscape and confirm the composer survives.

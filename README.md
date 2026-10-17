# Pinpoint

## Running the Buffer Map prototype

The prototype is a single static page at `prototypes/buffer-map/index.html`. It lives on the `prototype/buffer-map` branch only.

You need:

- Python 3 (any static file server works; Python's is used below)
- A Google Maps JavaScript API key

Steps:

1. Check out the prototype branch:

   ```sh
   git checkout prototype/buffer-map
   ```

2. From the repo root, serve the prototype folder:

   ```sh
   python -m http.server 8000 -d prototypes/buffer-map
   ```

3. Open <http://localhost:8000/?key=YOUR_GOOGLE_MAPS_KEY> in a browser.

   If you leave out `?key=`, the page asks you to paste a key. The key is only kept in the URL and is never stored.

### Live demo (GitHub Pages)

The `overlay-info` branch is published to <https://cl0udc0der.github.io/Pinpoint/> on every push, by `.github/workflows/pages.yml`. Only the `prototypes/buffer-map` folder is published. Open it with `?key=YOUR_GOOGLE_MAPS_KEY`, or paste a key when the page asks. Your key's website restrictions must allow `https://cl0udc0der.github.io/*`.

### Switching variants

There are four variants: **D** (hybrid, the default), **A** (click to drop), **B** (pin + results list) and **C** (Feature as centre). To switch between them, do one of these:

- add `&variant=A` (or `B`, `C`, `D`) to the URL
- use the floating bar at the bottom of the page
- press the ← / → keys

The map shows synthetic Features placed around Quezon City, not the real Dataset.

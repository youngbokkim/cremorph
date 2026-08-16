# Legacy web version (archived)

The original vanilla HTML/CSS/JS implementation of CREHOONI, kept for reference
after the Flutter rewrite. **Not deployed and not maintained.**

Its own documentation is preserved verbatim in
[`README-original.md`](README-original.md).

## What was here

| File | Role |
| --- | --- |
| `index.html` | Single-page shell with the three tab panels |
| `css/app.css` | The full design system — source of the colour tokens now in `lib/core/theme.dart` |
| `js/morphs.js` | The 18-morph catalog, now `lib/data/morph_catalog.dart` |
| `js/engine.js` | Genetics, Korean NLP, pixel analysis, quality/price |
| `js/vision.js` | Browser CLIP ViT-B/32 via `@huggingface/transformers` (WASM) |
| `js/library.js` | Photo library over IndexedDB + a GitHub-hosted JSON index |
| `js/github-store.js` | Uploads via the GitHub Contents API using a user-supplied PAT |
| `js/app.js` | DOM wiring |
| `data/library.json` | Shared photo index |
| `server.py` | Local dev server with a small photo CRUD API and git auto-commit |
| `start.bat` | Windows launcher |

## Why it was replaced

- **No mobile story.** It was browser-only, so iOS and Android needed a rewrite.
- **Contributions required a GitHub token.** Every contributor had to paste a PAT
  with `repo` scope into the page, which is unacceptable for an app store build.
- **Using a git repository as a database** meant every photo upload produced a
  commit, and deletes rewrote a shared JSON file.
- **The 80MB CLIP model** downloaded into every browser on first analysis. That
  now runs server-side in a Supabase edge function instead.

## Running it

The morph images it referenced live at the repository root (`assets/morphs/`),
so relative paths from this folder no longer resolve. To view it as it was:

```sh
cd legacy-web
ln -s ../assets assets
python3 -m http.server 5173
```

Then open <http://localhost:5173>.

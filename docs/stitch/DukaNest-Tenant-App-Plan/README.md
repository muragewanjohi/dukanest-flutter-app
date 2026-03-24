# DukaNest Tenant App Plan — Stitch exports

**Project ID:** `13184140852829986275`

Source: Google Stitch (via Cursor MCP `get_screen`). Each screen is stored under `screens/<slug>/`:

- `screenshot.png` — design preview
- `screen.html` — generated HTML

**Re-download:** URLs in `manifest.json` may expire; refresh by calling Stitch `get_screen` again and updating the manifest, or re-run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\download-screens.ps1
```

**Manual curl** (example for Order Fulfillment; quote URLs in your shell):

```bash
curl -L -o screenshot.png "<screenshotUrl from manifest.json>"
curl -L -o screen.html "<htmlUrl from manifest.json>"
```

# Firebase Storage CORS — web image loading

## Why this exists

On **Flutter web** (`flutter run -d chrome`, or the deployed web build), `Image.network`
fetches image **bytes over HTTP**, so the browser enforces the same-origin policy. The app
is served from `http://localhost:<port>` (or the Hosting domain) and requests images from
`https://firebasestorage.googleapis.com/...` — a cross-origin request.

If the Storage bucket does not return an `Access-Control-Allow-Origin` header for the
requesting origin, the browser blocks the response and Flutter reports:

```
NetworkImageLoadException: HTTP request failed, statusCode: 0
```

`statusCode: 0` = the browser refused to expose the response to JS (CORS), **not** a 403/404.
Native Android/iOS builds are **not** affected — `Image.network` there isn't subject to CORS.
Firestore works on web regardless because its SDK endpoints already send CORS headers; Storage
download URLs require the bucket CORS policy to be set manually (below).

## One-time fix (run once per bucket — requires bucket owner/editor access)

```bash
gsutil cors set cors.json gs://ecoswap-dev-kmutt.firebasestorage.app
# Verify:
gsutil cors get gs://ecoswap-dev-kmutt.firebasestorage.app
```

Or with the gcloud CLI:

```bash
gcloud storage buckets update gs://ecoswap-dev-kmutt.firebasestorage.app --cors-file=cors.json
```

After it applies (usually immediate, allow a minute), hard-refresh the Chrome tab.

## What [`cors.json`](../cors.json) allows

- `origin: ["*"]` — any web origin may **read** image bytes via `fetch`. This is acceptable
  for image assets: access is already gated by the per-object download `token` in the URL;
  CORS only governs *which web pages* may read bytes they already hold the URL for. The
  wildcard is also needed because `flutter run -d chrome` picks a **random port each run**, so
  a fixed `http://localhost:NNNN` entry would break on the next run.
- `method: ["GET"]` — read-only; no upload/delete is opened up by this policy.

### Locking down for production (optional)

If you'd rather not use `*`, pin a fixed dev port and list explicit origins:

```bash
flutter run -d chrome --web-port=5000
```

```json
[
  {
    "origin": [
      "http://localhost:5000",
      "https://ecoswap-dev-kmutt.web.app",
      "https://ecoswap-dev-kmutt.firebaseapp.com"
    ],
    "method": ["GET"],
    "responseHeader": ["Content-Type"],
    "maxAgeSeconds": 3600
  }
]
```

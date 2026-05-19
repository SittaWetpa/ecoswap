  # EcoSwap Cloud Functions

TypeScript Cloud Functions for the EcoSwap project. Scaffolded in **WBS 3.5**;
real bodies arrive in WBS 10.1, 10.2, and 10.6.

## Exported functions

| Name              | Type                       | Implemented in |
|-------------------|----------------------------|----------------|
| `issueQRToken`    | Callable (v2 `onCall`)     | WBS 10.1       |
| `validateQRToken` | Callable (v2 `onCall`)     | WBS 10.2       |
| `onTradeComplete` | Firestore `onDocumentCreated` | WBS 10.6 / 8.5 |

All three currently exist as stubs that pass the auth check and then return
`unimplemented`. The function signatures and the Secret Manager binding for
`JWT_SECRET` are stable from this point on.

## Local development

```bash
cd functions
npm install
npm run build      # tsc — must pass before commit
npm run lint       # eslint over src/ and test/
npm test           # jest, wrapped in firebase emulators:exec
```

`npm test` boots the storage emulator (used by the WBS 3.4 rules tests) before
running Jest with `--runInBand`. Pure unit tests that do not need an emulator
can be run with `npm run test:no-emulator`.

## JWT signing secret

The HS256 signing key for QR-exchange tokens comes from **Firebase Secret
Manager**, never from a `.env` file. This is a locked decision in
`CLAUDE.md`.

### One-time provisioning

```bash
# Generate a 256-bit random secret on your machine, then push to Secret Manager.
firebase functions:secrets:set JWT_SECRET
# (prompts for the value — paste the random key, do NOT echo it into the shell history)
```

Verify it landed:

```bash
firebase functions:secrets:access JWT_SECRET
```

### Using the secret in code

`src/index.ts` declares the binding once:

```ts
import { defineSecret } from 'firebase-functions/params';
export const JWT_SECRET = defineSecret('JWT_SECRET');
```

Any function that needs the secret declares it in its `onCall` options and
then reads it inside the handler:

```ts
export const issueQRToken = onCall(
  { secrets: [JWT_SECRET] },
  async (request) => {
    const key = JWT_SECRET.value();
    // ...
  },
);
```

`JWT_SECRET.value()` only works at runtime inside a deployed function (or the
Functions emulator with the secret stubbed in). Calling it at module top
level will throw.

### Rotation

Re-running `firebase functions:secrets:set JWT_SECRET` creates a new version
and points active deployments at it. Existing tokens signed with the old
secret will fail signature verification, which is the intended behaviour for
emergency rotation.

## Deploy

```bash
firebase deploy --only functions
```

The CI `deploy-dev` job (see `.github/workflows/ci.yml`) runs this on every
push to `main`, targeting the `ecoswap-dev` Firebase project.

## Notes

- This package is **TypeScript with `strict: true`**. No `any` types except
  where unavoidable, with a comment.
- Firestore writes from Cloud Functions go through `firebase-admin`, not the
  client SDK.
- Counter fields (`tradesCount`, `totalCo2Saved`, `totalWasteDiverted`) on
  `/users/` are written **only** by WBS 10.6 — never from a client.

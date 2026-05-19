/**
 * Cloud Storage security rules tests (WBS 3.4).
 *
 * Verifies the three Acceptance criteria from the WBS 3.4 entry:
 *   1. Unauthenticated upload denied
 *   2. Authenticated upload > 2 MB denied
 *   3. Authenticated user A cannot overwrite user B's photo
 *
 * Run via `npm test`, which wraps Jest inside `firebase emulators:exec
 * --only storage --project demo-ecoswap`.
 */

import * as fs from 'fs';
import * as path from 'path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  ref,
  uploadBytes,
  getBytes,
} from 'firebase/storage';

const PROJECT_ID = 'demo-ecoswap';
const STORAGE_RULES_PATH = path.resolve(__dirname, '../../storage.rules');

const ONE_MB = 1024 * 1024;
const TWO_MB = 2 * 1024 * 1024;

/** Build an in-memory image buffer of the requested size in bytes. */
function imageBytes(size: number): Uint8Array {
  return new Uint8Array(size);
}

let testEnv: RulesTestEnvironment;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {
      rules: fs.readFileSync(STORAGE_RULES_PATH, 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  await testEnv.clearStorage();
});

describe('storage rules — /user_photos/{uid}.jpg', () => {
  test('unauthenticated upload is denied (Acceptance #1)', async () => {
    const unauth = testEnv.unauthenticatedContext().storage();
    const fileRef = ref(unauth, 'user_photos/alice.jpg');
    await assertFails(
      uploadBytes(fileRef, imageBytes(1024), { contentType: 'image/jpeg' }),
    );
  });

  test('authenticated upload over 2 MB is denied (Acceptance #2)', async () => {
    const alice = testEnv.authenticatedContext('alice').storage();
    const fileRef = ref(alice, 'user_photos/alice.jpg');
    await assertFails(
      uploadBytes(fileRef, imageBytes(TWO_MB + 1), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('user A cannot overwrite user B photo (Acceptance #3)', async () => {
    // Seed user B's photo using the security-rules-bypassing admin context.
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const adminRef = ref(ctx.storage(), 'user_photos/bob.jpg');
      await uploadBytes(adminRef, imageBytes(1024), {
        contentType: 'image/jpeg',
      });
    });

    const alice = testEnv.authenticatedContext('alice').storage();
    const bobsPhoto = ref(alice, 'user_photos/bob.jpg');
    await assertFails(
      uploadBytes(bobsPhoto, imageBytes(1024), { contentType: 'image/jpeg' }),
    );
  });

  test('user can upload their own photo when authenticated and under 2 MB', async () => {
    const alice = testEnv.authenticatedContext('alice').storage();
    const fileRef = ref(alice, 'user_photos/alice.jpg');
    await assertSucceeds(
      uploadBytes(fileRef, imageBytes(ONE_MB), { contentType: 'image/jpeg' }),
    );
  });

  test('non-image content type is denied', async () => {
    const alice = testEnv.authenticatedContext('alice').storage();
    const fileRef = ref(alice, 'user_photos/alice.jpg');
    await assertFails(
      uploadBytes(fileRef, imageBytes(1024), {
        contentType: 'application/pdf',
      }),
    );
  });

  test('authenticated user can read any user photo', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const adminRef = ref(ctx.storage(), 'user_photos/bob.jpg');
      await uploadBytes(adminRef, imageBytes(1024), {
        contentType: 'image/jpeg',
      });
    });

    const alice = testEnv.authenticatedContext('alice').storage();
    const bobsPhoto = ref(alice, 'user_photos/bob.jpg');
    await assertSucceeds(getBytes(bobsPhoto));
  });

  test('unauthenticated read is denied', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      const adminRef = ref(ctx.storage(), 'user_photos/bob.jpg');
      await uploadBytes(adminRef, imageBytes(1024), {
        contentType: 'image/jpeg',
      });
    });

    const unauth = testEnv.unauthenticatedContext().storage();
    const bobsPhoto = ref(unauth, 'user_photos/bob.jpg');
    await assertFails(getBytes(bobsPhoto));
  });
});

describe('storage rules — /item_photos/{itemId}.jpg', () => {
  test('unauthenticated upload is denied', async () => {
    const unauth = testEnv.unauthenticatedContext().storage();
    const fileRef = ref(unauth, 'item_photos/item-1.jpg');
    await assertFails(
      uploadBytes(fileRef, imageBytes(1024), { contentType: 'image/jpeg' }),
    );
  });

  test('authenticated upload under 2 MB is allowed', async () => {
    const alice = testEnv.authenticatedContext('alice').storage();
    const fileRef = ref(alice, 'item_photos/item-1.jpg');
    await assertSucceeds(
      uploadBytes(fileRef, imageBytes(ONE_MB), { contentType: 'image/jpeg' }),
    );
  });

  test('authenticated upload over 2 MB is denied', async () => {
    const alice = testEnv.authenticatedContext('alice').storage();
    const fileRef = ref(alice, 'item_photos/item-1.jpg');
    await assertFails(
      uploadBytes(fileRef, imageBytes(TWO_MB + 1), {
        contentType: 'image/jpeg',
      }),
    );
  });

  test('non-image content type is denied', async () => {
    const alice = testEnv.authenticatedContext('alice').storage();
    const fileRef = ref(alice, 'item_photos/item-1.jpg');
    await assertFails(
      uploadBytes(fileRef, imageBytes(1024), {
        contentType: 'text/plain',
      }),
    );
  });
});

describe('storage rules — paths outside the allow-listed prefixes', () => {
  test('authenticated upload to an unknown path is denied', async () => {
    const alice = testEnv.authenticatedContext('alice').storage();
    const fileRef = ref(alice, 'random/foo.jpg');
    await assertFails(
      uploadBytes(fileRef, imageBytes(1024), { contentType: 'image/jpeg' }),
    );
  });
});

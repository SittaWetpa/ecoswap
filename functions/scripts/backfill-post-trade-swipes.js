/**
 * One-off maintenance script — backfill post-trade re-discovery (product
 * decision #3, WBS 8.5).
 *
 * WHY THIS EXISTS
 * ---------------
 * `onItemTraded` (functions/src/onItemTraded.ts) deletes the mutual right-
 * swipes that formed a match once both traded items flip to status:'traded',
 * which is what lets the two swappers rediscover each other in Discover (gated
 * by the counterparty having a fresh active item). That trigger only runs for
 * trades completed AFTER it was deployed. Any trade that completed earlier
 * leaves its two swipe docs in place, so the feed's already-swiped filter keeps
 * the counterparty hidden forever — even after they upload a new item.
 *
 * This script sweeps those stale swipes retroactively. It is idempotent: once
 * the swipes are gone a re-run finds nothing to do. It is also forward-safe —
 * running it has the same effect onItemTraded already produces for new trades.
 *
 * It does NOT touch /trades/, /matches/, /users/ counters, or any item status.
 * It only deletes right-swipe docs whose desiredItemId is an item that has
 * already been exchanged in a completed trade — the exact rows onItemTraded
 * would have swept.
 *
 * USAGE (run from the functions/ directory)
 * -----------------------------------------
 *   # Dry run (default) — prints what WOULD be deleted, changes nothing:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json \
 *     node scripts/backfill-post-trade-swipes.js --project=ecoswap-dev
 *
 *   # Apply — actually delete the stale swipes:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json \
 *     node scripts/backfill-post-trade-swipes.js --project=ecoswap-dev --apply
 *
 * Authenticate with a service account that has Firestore write access (or run
 * `gcloud auth application-default login` and pass --project). This is an
 * operational tool — it is intentionally outside src/ so it is never bundled
 * into the deployed Cloud Functions.
 */

"use strict";

const admin = require("firebase-admin");

function parseArgs(argv) {
  const args = { apply: false, project: undefined };
  for (const a of argv.slice(2)) {
    if (a === "--apply") args.apply = true;
    else if (a.startsWith("--project=")) args.project = a.slice("--project=".length);
  }
  return args;
}

async function main() {
  const { apply, project } = parseArgs(process.argv);

  admin.initializeApp(project ? { projectId: project } : undefined);
  const db = admin.firestore();

  const mode = apply ? "APPLY" : "DRY-RUN";
  console.log(`[backfill] mode=${mode} project=${project || "(default)"}`);

  // 1. Collect every item id that has already been exchanged in a completed
  //    trade. These are exactly the items whose right-swipes onItemTraded
  //    would have swept.
  const tradesSnap = await db.collection("trades").get();
  const tradedItemIds = new Set();
  for (const doc of tradesSnap.docs) {
    const ex = doc.data().itemsExchanged || {};
    if (ex.fromA) tradedItemIds.add(ex.fromA);
    if (ex.fromB) tradedItemIds.add(ex.fromB);
  }
  console.log(
    `[backfill] ${tradesSnap.size} trades → ${tradedItemIds.size} exchanged items`,
  );

  // 2. For each traded item, find lingering right-swipes that target it and
  //    delete them in batches. Mirrors onItemTraded's query exactly.
  let toDelete = 0;
  let deleted = 0;
  let batch = db.batch();
  let batchCount = 0;

  for (const itemId of tradedItemIds) {
    const swipes = await db
      .collection("swipes")
      .where("desiredItemId", "==", itemId)
      .where("direction", "==", "right")
      .get();

    for (const swipe of swipes.docs) {
      toDelete++;
      const d = swipe.data();
      console.log(
        `[backfill]  stale swipe ${swipe.id}: swiper=${d.swiperId} target=${d.targetUserId} item=${itemId}`,
      );
      if (apply) {
        batch.delete(swipe.ref);
        batchCount++;
        // Firestore batches cap at 500 ops; commit and start a fresh batch.
        if (batchCount === 500) {
          await batch.commit();
          deleted += batchCount;
          batch = db.batch();
          batchCount = 0;
        }
      }
    }
  }

  if (apply && batchCount > 0) {
    await batch.commit();
    deleted += batchCount;
  }

  if (apply) {
    console.log(`[backfill] DONE — deleted ${deleted} stale swipe doc(s).`);
  } else {
    console.log(
      `[backfill] DONE — ${toDelete} stale swipe doc(s) would be deleted. Re-run with --apply to delete.`,
    );
  }
}

main().catch((err) => {
  console.error("[backfill] FAILED:", err);
  process.exit(1);
});

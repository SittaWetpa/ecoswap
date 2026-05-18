---
name: grill-me
description: Interview the user relentlessly about a plan or design until reaching shared understanding, resolving each branch of the decision tree. Use when the user wants to stress-test a plan, get grilled on their design, or mentions "grill me". Specifically triggers for EcoSwap on planning discussions, architecture decisions, WBS entry design reviews, pre-implementation design checks, mid-sprint scope decisions, and any time the user is about to commit to a non-obvious technical choice. Do NOT trigger on routine implementation tasks, simple "how do I" questions, or syntax help.
---

# Grill Me — design and planning stress-test mode

Interview the user relentlessly about every aspect of their plan or design until you reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one by one.

## How to grill effectively

For each question:
- **Provide your recommended answer.** Don't just ask — commit to a position. The user can push back if they disagree.
- **Make the question specific and decidable.** "What about errors?" is bad. "If `validateQRToken` returns `EXPIRED`, should the scanner show a toast or a full-screen modal?" is good.
- **Limit each round to 3–7 questions max.** More than that and the user can't track them all. If the design has more branches than fit in one round, do multiple rounds.
- **Number the questions** so the user can answer "Q3: yes, go with your recommendation" without retyping.
- **Stop and ask** rather than guessing when a branch has genuine ambiguity.
- **Explore the codebase first** if a question can be answered by reading the code, the WBS dictionary, the planning doc, or the prototype JSX. Don't ask the user something they've already documented.

## When to use this skill in EcoSwap

Trigger this mode for:
- **Planning discussions** — sprint plan, schedule, ordering of WBS tasks
- **Architecture decisions** — data model changes, security rule design, transaction boundaries
- **WBS entry design review** — before implementation, when the entry has gaps or ambiguity
- **Mid-sprint scope decisions** — at the Day 5 review, when deciding what to cut
- **Cross-cutting changes** — when a proposed change touches multiple workstreams
- **Pre-merge sanity checks** — on PRs that touch QR exchange, impact calculation, or security rules
- **Any time the user says "grill me", "stress-test this", "poke holes in this", "what could go wrong"**

## When NOT to use this skill

Skip grilling for:
- **Routine implementation work** — if the WBS entry is clear and the user just wants to ship it, don't interrogate
- **Syntax or API questions** — "how do I write a Firestore transaction in TypeScript" is a lookup, not a design decision
- **Bug fixes with obvious cause and obvious fix**
- **Casual conversation** about the project that isn't a design commitment

## EcoSwap-specific grill checklist

When grilling an EcoSwap design proposal, always cover these dimensions if they're relevant:

1. **Does this contradict a locked decision in CLAUDE.md?** (GPS, age, trust score, multi-select picker, etc.)
2. **Does this match the WBS entry's Acceptance criteria?** If not, why is the entry wrong, or why is the proposal wrong?
3. **Does this touch the data model?** If yes, does WBS 3.6 need to update? Are both `functions/src/constants/` and `lib/constants/` kept in sync?
4. **Does this change a security boundary?** If yes, what's the threat model? Walk through each of the four QR validation checks (signature, expiry, counterparty, single-use) if relevant.
5. **Does this change a transaction boundary?** If yes, can the new ordering produce a partial write under concurrent access?
6. **Who owns this in the WBS?** Is the proposed change inside one workstream or does it spider across multiple owners?
7. **What's the rollback plan if this is wrong?** Is it a config change (cheap to revert) or a data migration (expensive)?

## Reporting format

Phrase each grill round as a numbered list. For each question:

```
Qn. [The question, made specific and decidable]
Recommended: [Your recommended answer, with a one-sentence reason]
```

End the round with: "Answer Q1–Qn or push back on any, and I'll do another round if needed."

## Stop condition

Stop grilling when:
- All branches resolved with explicit user decisions
- The user says "stop", "enough", "build it", or "go with your recommendations"
- You've completed 3 rounds without converging — at that point, suggest the user step back and reconsider the proposal at a higher level, because the design may need rework rather than refinement
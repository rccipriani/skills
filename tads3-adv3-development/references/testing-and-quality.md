# Testing and quality

## Layered validation

1. Compile the changed target.
2. Run a focused command transcript for the changed behavior.
3. Inspect actual output and state transitions.
4. Add stable regression assertions.
5. Run all project targets and transcript suites.
6. Build and test release mode; debug-only definitions can hide release failures.

Compilation alone does not prove parser resolution, implicit actions, inherited reports, containment, scope, or event timing.

## FrobTADS transcript pattern

For FrobTADS 2.0, a useful non-interactive invocation is:

```sh
frob -i plain -p build/game.t3 < tests/feature.txt > "$output"
```

Confirm options against `frob --help` on other versions. Capture output in `mktemp`, install a cleanup trap, and include any required quit confirmation so the process cannot wait for a person.

Plain output can wrap at a fixed width. Assert several stable semantic fragments rather than one complete prose line. Make assertions specific enough that an unrelated object cannot satisfy them.

## Test design

Use deterministic setup and explicit noun phrases when ambiguity is not under test. Cover:

- startup and basic room health separately from feature behavior;
- examine, take/drop, containment, state changes, preconditions, and invalid actions;
- obvious synonyms and natural commands suggested by descriptions;
- ambiguity and disambiguation deliberately;
- NPC dialogue, repetition, state dependence, presence, and event timing;
- puzzle prerequisites in multiple orders;
- recovery from plausible mistakes, alternate solutions, and endings;
- dead-end detection and reachability;
- scoring exactly once;
- debug-only command presence in debug and absence in release.
- both common player phrasings when several grammar words should dispatch the
  same standard action;
- locked travel from the starting side, synchronized paired-door state after
  a puzzle change, and traversal in both directions;
- ordinary-command reachability for every puzzle-critical object.

Preserve original player transcripts as evidence. Add derived regression transcripts separately so normalization or appended commands do not rewrite what the player actually did.

## Debug commands

Debug commands should inspect or establish test state narrowly, live under `#ifdef __DEBUG`, use `actionTime = 0` when non-fictional, and never be required for a release solution. Test their release exclusion.

## Fairness and parser review

For every noun or action emphasized by prose, ask:

- Can the parser resolve it?
- Are likely synonyms present?
- Does the described affordance have a sensible action or refusal?
- Does output reveal the actual state?
- Can the player diagnose a failed precondition without being handed a complete solution?

Blind-play evidence outranks author familiarity: a technically valid puzzle can still be unfair if vocabulary, feedback, or state visibility is poor.

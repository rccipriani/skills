# Events, time, and scoring

## Action time

Ordinary actions default to `actionTime = 1`. System, debugging, or meta actions can set `actionTime = 0` when they should not advance game time. Do this deliberately: a world-changing command that costs no time can break event and puzzle assumptions.

The scheduler advances according to action time. Nested and replacement actions have special handling; inspect `action.t` and `exec.t` rather than manually adjusting the global turn counter.

## Event classes

- `Fuse(obj, &method, turns)`: one execution after the scheduled number of game-clock turns.
- `Daemon(obj, &method, interval)`: repeated execution; an interval of one first runs on the current turn's event cycle.
- `SenseFuse` and `SenseDaemon`: messages execute in a specified sensory context.
- `PromptDaemon`: once per command prompt, independent of game-clock scheduling.
- `OneTimePromptDaemon`: one prompt-time callback, then removal.
- Real-time event classes: wall-clock behavior; avoid unless genuinely required and test separately.

Retain the event object when later cancellation is required and remove it through the event API. Guard state-dependent callbacks against stale assumptions.

## Debugging time

Put inspection-only developer commands behind `#ifdef __DEBUG` and set `actionTime = 0`. Compile both debug and release images; verify the grammar is absent in release, not merely rejected at runtime.

## Standard scoring

Use static `Achievement` objects for discrete milestones:

```tads
alignmentAchievement: Achievement
    points = 5
    desc = 'aligning the demonstration device'
;

// At the milestone:
alignmentAchievement.awardPointsOnce();
```

`awardPointsOnce()` returns true only on the first award and prevents duplicate points. If every score item is a static `Achievement` with `points`, the library can calculate the maximum score, subject to the constraints documented in `score.t`. Use `awardPoints()` only for intentionally repeatable achievements and define `maxPoints` appropriately.

Award meaningful accomplishments, not arbitrary parser commands. Avoid scores that unintentionally reveal undiscovered puzzle structure. Test score notification settings, `SCORE`, `FULL SCORE`, duplicate attempts, undo, restore, and every alternate path to the milestone.

## Primary evidence

- Installed standard-adv3 `action.t`, `exec.t`, `events.t`, `score.t`.
- Library reference entries for the event classes, `Achievement`, and scoring functions.

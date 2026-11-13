# Independent container skill evaluation

Run this protocol in a fresh Codex session. Do not preload an AI-IF repository,
prior game transcript, or story code. Install this skill, make the reusable
image available, and give Codex only the evaluation brief below. The evaluator
must not edit the skill during the run; record proposed guidance changes in the
workspace report.

## Brief for the fresh session

Create an original standard-adv3 game in a new, dedicated workspace. It must
have three interconnected rooms; at least five interactable objects; one NPC
with conversation; a locked passage and fair, solvable puzzle; a custom action
or verb; a timed event or daemon; an achievement awarded once; and an explicit
win. Do not copy existing AI-IF story, source, names, or prose.

Discover and follow the installed `tads3-adv3-development` skill. Use
`scripts/tads3-container.sh` and the existing reusable image for all compilation
and execution. Build distinct release and debug images, exercise a complete
winning transcript plus focused failure/state tests, and use semantic markers
for the lock transition, timed event, score, NPC state response, and victory.
Diagnose and correct defects until both configurations pass.

## Evidence and report

Keep all of this below the evaluation workspace on the host:

```text
evaluation-workspace/
  src/ and *.t3m
  build/
  tests/input/
  tests/container-results/
  evaluation-report.md
  proposed-skill-improvements.md
```

The report must give the image identity, toolchain versions, start/end time,
final release/debug commands and status, semantic markers checked, compilation
attempt count, failed compilation count, correction-cycle count, runtime test
count, defect/correction summary, and an inventory of preserved evidence.
Count a compilation attempt whenever `t3make` is invoked. Count a correction
cycle when source or a manifest is changed in response to a compile or gameplay
failure. Do not rewrite failed logs; the container wrapper stores mode-specific
logs, so copy or rename each before the next attempt when history matters.

`proposed-skill-improvements.md` must list every missing, incorrect, or
ambiguous instruction, the evidence that exposed it, and a proposed change.
Write `none observed` when appropriate. This file is feedback only: applying
it during the evaluation invalidates independence.

The evaluation passes only when source, manifests, all inputs, release/debug
images, transcripts, status files, and both reports remain on the host and the
winning path proves each required feature. Image building or source acquisition
is outside the evaluation and must not be silently authorized by the session.

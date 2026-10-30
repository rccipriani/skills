# Blind-playtest workflow

Activate this workflow only when the user explicitly requests secrecy or repository instructions require it.

## Before work

- Read the project's spoiler boundary and identify protected source, filenames, tests, logs, and scenario details.
- State the limits honestly: the client can expose tool calls, patch bodies, diffs, command output, or approval prompts independently of assistant narration.
- Do not promise secrecy the execution environment cannot enforce. If tools visibly echo sensitive content, use approved non-displaying mechanisms or ask how to proceed.

## Implementation and testing

- Continue full internal engineering rigor; secrecy is not a reason to reduce coverage.
- Keep progress descriptions generic.
- Redirect spoiler-bearing build/test output to temporary files and expose only neutral status when the interface supports that boundary.
- Test intended and alternate paths, plausible mistakes, recovery, parser affordances, fairness, and endings privately.
- Preserve the original player transcript unchanged. Store derived annotations and regression cases separately.

## Transcript analysis

Classify observed failures without exposing story content:

- unrecognized noun or synonym;
- missing scenery;
- reasonable unsupported action;
- ambiguous resolution;
- stale state description;
- inadequate prerequisite feedback;
- accidental dead end;
- conversation/scope/timing issue;
- evidence of unfair inference burden.

Fix the smallest model or feedback defect. Do not rewrite puzzle logic merely because one player explored differently unless the evidence indicates unfairness or a true blocker.

## Reporting

Report completion, build status, test status, preservation of existing targets, launch instructions, and spoiler-free caveats. Do not enumerate protected rooms, objects, commands, state transitions, dialogue, or outcomes. Warn and obtain confirmation before displaying requested protected source or transcripts.

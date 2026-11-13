# Common pitfalls and evidence status

The findings below are reusable and verified against standard adv3 3.1.3 source or runtime behavior. Re-check version-sensitive details.

## Static prose contradicts state

**Problem:** Examination or room prose remains unchanged after an object changes.

**Root cause:** The prose encodes an initial condition instead of reading the authoritative state.

**Pattern:** Derive descriptions and responses from the same property or library state changed by the action. Test before and after, including undo/restore when important.

## Inherited prose duplicates custom prose

**Problem:** A custom description states a condition and the class appends another state or contents sentence.

**Root cause:** adv3 listers and state descriptions remain active after custom `desc` output.

**Pattern:** Inspect runtime output and override the narrow lister/state hook on that object. Do not globally rewrite messages.

## Ambiguous vocabulary

**Problem:** A short noun phrase matches multiple visible objects.

**Root cause:** Legitimately shared nouns or overly broad vocabulary.

**Pattern:** Preserve useful vocabulary, improve distinguishing adjectives or contextual ranking when the player experience requires it, and use explicit phrases in unrelated tests.

## Missing prominent scenery

**Problem:** A room description names a concrete feature that the parser does not recognize.

**Root cause:** Narrative prose and object model were authored independently.

**Pattern:** Add `Decoration`, `Fixture`, or a fuller object according to the implied affordance; include expected synonyms and responses.

## Reasonable command gets a generic refusal

**Problem:** A player tries an obvious physical verb and receives misleading or generic output.

**Root cause:** Only the intended solution command was tested.

**Pattern:** Reuse or remap a standard action locally, or add an object-specific response. Avoid global grammar for a local problem.

## Direct movement bypasses travel

**Problem:** An actor changes rooms without expected hooks, messages, or travel memory.

**Root cause:** A containment API was used instead of connector travel.

**Pattern:** Select among `moveInto`, `moveIntoForTravel`, `travelTo`, and `scriptedTravelTo` based on the verified distinctions in `travel-and-containment.md`.

## Events advance during conversation

**Problem:** An NPC answers and then moves or another timed event fires in the same command.

**Root cause:** Conversation normally consumes a turn.

**Pattern:** Treat ordinary scheduling as authoritative, ensure combined output is coherent, and test dialogue with timed behavior. Pause time only for a deliberate game rule.

## Transcript assertions break on wrapping

**Problem:** Correct output fails a line-based assertion.

**Root cause:** Plain interpreters wrap output independently of source line breaks.

**Pattern:** Assert stable semantic fragments whose combination proves the intended result.

## Module basename collision

**Problem:** A project module conflicts with a library module despite different directories.

**Root cause:** TADS build intermediates and module identity can be basename-oriented.

**Pattern:** Use distinctive basenames and separate target output directories. Do not textually include implementation modules as a routine workaround.

## Overengineering

**Problem:** A small game accumulates generalized simulation, parser, dialogue, or state frameworks before concrete behavior needs them.

**Root cause:** Designing for hypothetical reuse instead of current playable behavior.

**Pattern:** Use standard adv3 classes, object-local overrides, and the smallest state machine that satisfies tested requirements. Extract abstractions only after repeated real use.

## Not yet universal

Treat these as project decisions unless independently verified: exact directory layout, one-module-per-region policy, transcript filename conventions, scoring policy, prose style, target count, and whether all modules must share one custom header.

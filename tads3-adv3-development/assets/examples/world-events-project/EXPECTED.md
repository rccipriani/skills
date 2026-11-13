# Expected gameplay evidence

`tests/world-events.sh` compiles the release image and runs both command
transcripts. The scenery transcript must prove recognition and meaningful
behavior for fixed scenery, decoration, a fixed surface, a portable object,
chair posture, looking under/moving furniture, an openable container, and a
`RoomPart`. It also checks inherited refusal to take the chandelier.

The event transcript must prove duplicate prevention; exactly one delayed
fuse firing; recurring daemon ticks; two conditional escalation stages;
explicit cancellation with no later ticks; persistent state mutation from a
remote `SenseFuse` with its narration absent; and two distinct return-entry
notifications. Runtime-error markers or any failed assertion fail the test.

Save/restore is intentionally a documented manual check because the current
non-interactive harness does not automate FrobTADS file prompts.

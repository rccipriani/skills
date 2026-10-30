# Validation expectations

The fixture is intentionally generic. Validation uses ordered, machine-readable
markers alongside player-facing text. Both builds must show, in order:

- the fixture introduction;
- the device's initial and changed state;
- successful custom-action output;
- state-dependent caretaker output;
- one event message;
- a rejected duplicate action and exactly five score points.

A debug build must accept `debugstatus`. A release build must echo and reject the
same command using the English adv3 parser's unknown-word/verb response. Each
state change, scheduled event, score report, and debug marker has an exact count;
compiler warnings and runtime-error markers fail validation.

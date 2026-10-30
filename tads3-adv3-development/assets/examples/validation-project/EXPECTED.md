# Validation expectations

The fixture is intentionally generic. A successful debug run must show:

- the fixture introduction;
- the device's initial and changed state;
- successful custom-action output;
- state-dependent caretaker output;
- one event message;
- five score points;
- the debug-status marker.

A release build must compile and run the same world without the debug-status marker. The exact parser rejection for the absent debug verb is not asserted because language-layer wording can vary.

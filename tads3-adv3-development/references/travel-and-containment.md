# Travel and containment

These methods are not interchangeable. The distinctions below are verified from the standard adv3 3.1.3 library source; re-check other versions.

| API | Verified behavior | Appropriate use |
|---|---|---|
| `baseMoveInto(dest)` | Changes containment lists and `location` only. Sends no notifications and does not mark the object moved. | Internal/library-style state manipulation where bypassing all side effects is intentional. Rare in game code. |
| `moveInto(dest)` | Notifies the movement/sense path, old and new containment trees, and the object; performs the move and marks it moved. | Ordinary programmatic object relocation. |
| `moveIntoForTravel(dest)` | Runs normal containment notifications and marks moved, but omits sense-path notification because travel and sense connections can differ. | Low-level movement performed as part of an already established travel operation. |
| `travelTo(dest, connector, backConnector)` | Delegates actor/traveler travel through a connector and its back connector. The travel machinery handles hooks, messages, and memory. | Connector-driven actor travel when the exact connector context is known. |
| `scriptedTravelTo(dest)` | Finds a connector to an adjacent destination, finds the reverse connector, and invokes a nested `TravelVia` action. It is omniscient, adjacency-only, and not route finding. | Pre-scripted NPC movement between known adjacent rooms. |

## Travel behavior to preserve

Normal adv3 travel can involve:

- connector barrier and darkness checks;
- traveler and actor hooks;
- departure and arrival notifications;
- sensory-context recalculation;
- room-entry behavior and descriptions;
- remembering the last destination/back connector for `GO BACK`;
- remembering a traversed door for later disambiguation.

Moving an actor directly with containment APIs can skip part or all of this behavior. Use it only when the fiction calls for relocation rather than travel and the missing hooks are understood.

## Hooks and testing

Inspect `beforeTravel`, traveler hooks, connector methods, `actorTravel`, room entry, and nested action behavior in the exact library version. Verify:

- departure/arrival messages from both observer sides;
- actor presence and scope after movement;
- door/connector state and barriers;
- `GO BACK` or other travel memory if promised;
- light and sensory changes;
- containment notifications for carried or nested actors;
- whether the action consumes a turn.

## Common failure

**Problem:** An NPC appears in the destination but emits no proper travel messages or fails later travel behavior.

**Root cause:** Direct containment movement was used where connector travel was intended.

**Pattern:** Use `scriptedTravelTo()` for simple adjacent scripted steps; use the full connector/traveler APIs for more specialized movement. Use `moveInto()` only for non-travel relocation.

## Primary evidence

- Installed standard-adv3 `thing.t`, `actor.t`, and `travel.t`.
- Library reference entries for `Thing`, `Actor`, travelers, and connectors.
- Tour Guide travel and actor chapters.

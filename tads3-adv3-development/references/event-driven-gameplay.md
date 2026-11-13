# Event-driven gameplay and lifecycle

This reference is verified against standard adv3 `events.t` from TADS 3.1.3
and the offline container fixture. These are game-clock events, not wall-clock
timers.

## Scheduler semantics

Ordinary actions normally consume one game-clock unit; `actionTime = 0`
commands do not advance turn events. The `eventManager` is a `Schedulable`
with order 1000, so it normally runs after actors at the same clock time.
Events at one time run by ascending `eventOrder` (default 100). A callback is
wrapped in an `EventAction` with `actionTime = 0` and therefore does not itself
consume another turn.

| Mechanism | Construction and first execution | Repetition |
|---|---|---|
| `Fuse(obj, &method, turns)` | current game clock + `turns`; zero is current event cycle | Removes itself after callback returns |
| `Daemon(obj, &method, interval)` | current clock + `interval - 1`; interval 1 runs in the current event cycle | Adds `interval` after each callback; values below 1 become 1 |
| `SenseFuse(obj, &method, turns, source, sense)` | `Fuse` timing in a sensory context | Once |
| `SenseDaemon(obj, &method, interval, source, sense)` | `Daemon` timing in a sensory context | Recurring |

The sensory variants always execute their callback. Their context suppresses
generated messages when the player cannot sense `source` via `sense`; it does
not suppress world-state changes. Use senses such as `sound`, `sight`, or
`smell` only after checking the intended sense path. The fixture proves that a
remote bell callback changes state while its message remains hidden.

`PromptDaemon` runs once before every command prompt independently of game
clock; `OneTimePromptDaemon` runs at one prompt and removes itself. Real-time
events use wall-clock facilities and are not substitutes for turn-based game
design.

## Lifecycle rules

Store each cancelable event reference on its owner:

```tads
controller: object
    pulseEvent = nil

    start()
    {
        if (pulseEvent == nil)
            pulseEvent = new Daemon(self, &pulse, 3);
    }

    stop()
    {
        if (pulseEvent != nil)
        {
            pulseEvent.removeEvent();
            pulseEvent = nil;
        }
    }
;
```

- Guard `start()` so repeated room entry or repeated triggers cannot register
  duplicates. `removeMatchingEvents(obj, &method)` removes every match and is
  convenient only when that pair uniquely identifies the intended event.
- `eventManager.removeCurrentEvent()` lets a daemon cancel itself, but does
  not abort the callback already in progress. A retained event's
  `removeEvent()` is clearer for outside cancellation.
- Clear a stored fuse reference in its callback. A `Fuse` removes itself only
  after the callback returns; an exception causes the manager to remove it.
- A `Daemon` reschedules after the callback. Explicitly remove it when its
  owner is disabled, destroyed, moved out of the relevant lifecycle, or the
  story ends. Destroying or disabling the callback owner does not, by itself,
  express cleanup to the event manager.
- Check current world state again inside callbacks. Scheduling, execution,
  message visibility, and persistent state changes are distinct operations.
- Use explicit fields (`started`, `stage`, `eventRef`) or a state machine for
  staged events. Do not infer stage solely from printed text or elapsed turns.
- Treat room transitions deliberately: decide whether an event continues,
  pauses, cancels, or merely becomes imperceptible. A sensory event is often
  better than canceling a world process just because the player leaves.

Turn-based dynamic events and their owner fields are ordinary VM state and
participate in save/restore and undo. Avoid rebuilding them unconditionally in
post-restore hooks or room entry; that creates duplicates or resets timing.
Real-time scheduling has separate pre-save/post-restore elapsed-time handling
in `events.t`. When save/restore correctness matters, test it in the target
interpreter because file prompts and harness support vary.

## Design patterns

- **Delayed one-shot:** schedule one `Fuse` at the trigger, retain it if the
  trigger can be revoked, and set a persistent `hasFired` flag in the callback.
- **Recurring:** create one `Daemon`; callback reads current state, performs
  one tick, and removes or is removed when no longer relevant.
- **Conditional:** either let a modest daemon check a condition, or schedule
  at the action that makes the condition true. Guard with a milestone flag.
- **Escalating:** keep an integer stage or enum-like state. Each callback
  validates prerequisites, performs at most the intended transition, and
  advances state exactly once.
- **Room entry:** override the verified room/travel hook (for standard `Room`,
  `enteringRoom(traveler)`), call `inherited`, identify the relevant traveler,
  and use visit/state fields to prevent duplicate scheduling. Test initial
  placement separately from travel entry.
- **NPC routine:** retain a daemon or staged fuses on a controller/NPC; verify
  the NPC's current location and state at every tick before movement or action.
- **Sensory:** use `SenseFuse`/`SenseDaemon` when the event happens regardless
  of the player but its narration depends on perception. Keep state mutation
  inside the callback and never assume hidden output means skipped execution.

Common mistakes are off-by-one daemon assumptions, treating `WAIT` and
zero-time meta commands alike, creating a new daemon on every entry, losing
the only cancellation reference, leaving recurring events orphaned, and
printing distant information from a plain `Fuse`.

## Validation checklist

Assert the first eligible turn, subsequent interval, one-shot count,
duplicate-trigger behavior, cancellation followed by several turns, and final
state. For sensory events assert both the persistent effect and absence of the
hidden message. Exercise leaving and returning. Save immediately before a
scheduled event, restore, and confirm remaining timing manually if automated
file-prompt control is unavailable.

The deterministic example is `assets/examples/world-events-project/`; run
`tests/world-events.sh`. Its automated coverage does not include save/restore.

## Primary evidence

- Installed `adv3/events.t`: `Schedulable`, `BasicEventManager`,
  `eventManager`, `Event`, `Fuse`, `Daemon`, `SenseFuse`, and `SenseDaemon`.
- Installed `adv3/action.t` and `exec.t`: action-time integration.
- Runtime behavior under FrobTADS 2.0 / TADS 3.1.3 in the bundled fixture.

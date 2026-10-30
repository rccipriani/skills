# adv3 object model

## Choose semantic classes

- `Room`: top-level locations and directional connections.
- `DarkRoom`: a room whose visibility depends on light.
- `Thing`: ordinarily portable physical objects.
- `Fixture`: attached, non-portable objects.
- `Component`: a part whose effective location follows its owner.
- `Decoration`: describable background detail with limited interaction; use a fuller class when players can reasonably manipulate it.
- `Container` and `Surface`: containment/support relationships.
- `OpenableContainer`, lockable classes, `Door`, `Switch`, `Button`, and other library mix-ins: standard state and actions.

Model identity, vocabulary, location, containment, state, and behavior separately. Avoid a prose-only object that merely prints the desired outcome while its adv3 state contradicts it.

## Vocabulary and parser affordance

Define useful adjectives and nouns in `vocabWords`. Include ordinary synonyms players will infer from room prose. Prominent concrete nouns in descriptions should normally resolve to an object or intentional decoration. Do not delete good vocabulary solely to make a regression command unambiguous; use a more explicit test noun phrase unless ambiguity is the defect.

Use disambiguation hooks only after inspecting the competing objects, scope, vocabulary, and ordinary parser result. Prefer clearer vocabulary and contextual distinctions to global parser changes.

## Stateful descriptions

Derive `desc`, `stateDesc`, room listing text, and responses from the authoritative property or library state:

```tads
sampleDial: Fixture 'brass sample dial' 'sample dial'
    "The pointer is <<isAligned ? 'aligned' : 'off center'>>. "
    isAligned = nil
;
```

When the class already reports open/closed, on/off, contents, or posture, inspect actual output before adding equivalent prose. Override the narrow object hook or lister responsible for duplication; do not globally replace library messages for a one-object issue.

## Scope, visibility, and senses

Location alone does not prove that the parser can resolve an object. Containment, open/closed state, illumination, sensory connectors, actor point of view, and special scope rules matter. Test the player-visible command in the relevant state.

Use `moveInto()` for ordinary programmatic containment changes so notifications and `moved` state occur. See `travel-and-containment.md` before moving actors or bypassing notifications.

## Nesting and accidental placement

The `+` nesting level in TADS source supplies an implicit location. This is
convenient for components and contents, but an extra `+` can place a later
object inside the preceding container or under another object instead of in
the room. For puzzle-critical objects, an explicit location makes intent
unambiguous even when the surrounding source is rearranged:

```tads
generatorRoom: Room 'Generator Room';

toolbox: OpenableContainer 'blue toolbox' 'toolbox' @generatorRoom;
+ spareFuse: Thing 'ceramic spare fuse' 'spare fuse';

generator: Fixture 'compact emergency generator' 'generator' @generatorRoom;
```

If `x generator` fails, separate two questions. First, does its vocabulary
contain the noun the player used? Second, is its actual location visible and
in scope from the actor's room? Try an exact known noun, inspect enclosing
containers and their open/closed state, and confirm the actor's location before
adding synonyms. A vocabulary change cannot repair an object nested in an
inaccessible container.

Exercise every puzzle-critical object through ordinary release-game commands,
not only debug inspection: examine it, perform its intended action, and repeat
after relevant containment or room changes. The stabilization fixture declares
its generator explicitly at `@workshop` and asserts that normal examination
reaches it from that room.

## Quality checks

- Examine every object before and after each state change.
- Test taking, dropping, inserting, removing, opening, closing, locking, switching, and invalid actions as applicable.
- Verify room listings and explicit examination agree.
- Test an object after moving it and after changing enclosing-container state.
- Test darkness or blocked senses where relevant.

## Primary evidence

- Tour Guide and Getting Started Guide sections on Things, Rooms, containment, senses, and state.
- Library reference entries for the concrete class.
- Installed `adv3/thing.t`, `objects.t`, `sense.t`, `travel.t`, and `lister.t`.

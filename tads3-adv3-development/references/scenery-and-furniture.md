# Scenery, furniture, and parser vocabulary

This guidance was checked against standard adv3 in TADS 3.1.3 and the
containerized `world-events-project` fixture. It extends, rather than replaces,
the general object-model and action guidance.

## Choose behavior first

| Player expectation | Normal class | Verified library behavior |
|---|---|---|
| carry, drop, insert | `Thing` | Ordinary portable physical object |
| fixed but fully interactive | `Fixture` | `NonPortable -> Thing`; rejects `Take`, `TakeFrom`, `Move`, and ordinary relocation |
| only examine/read/smell-style detail | `Decoration` | `Fixture` subclass; most actions are illogical with `notImportantMsg` |
| wall, floor, ceiling, arch, or other room fabric | `RoomPart` | `Fixture` subclass with room-part behavior; rooms can supply inherited default walls/floor/ceiling |
| put objects in | `Container` | `BasicContainer` with bulk limiting; add `OpenableContainer` when opening matters |
| put objects on | `Surface` | Support relationship and contents listing; combine with `Fixture` for a fixed table/piano |
| sit on and place objects on | `Chair` | `BasicChair, Surface`; a nested room with sitting posture |
| lie/sit on and place objects on | `Bed` | `BasicBed, Surface`; allows sitting and lying |
| stand/sit/lie on; dropped items remain there | `Platform` | `BasicPlatform, Surface`; defaults to standing and acts more like a mini-room |

Use `Fixture, Surface` for a fixed table, counter, or piano. Use
`OpenableContainer` for a cabinet whose door and contents matter; a plain
`Container` is not automatically openable. Consider library classes such as
`Door`, `Switch`, `Button`, and lockable mix-ins before writing handlers.
`Component` is preferable for a non-separable part whose effective location
follows an owner.

Furniture classes model actor posture, implicit movement, scope, and drop
destinations. A decorative chair that cannot be used may be a `Decoration`,
but prose should not invite `SIT ON CHAIR`. Do not use `Surface` alone for a
fixed support: surface behavior does not itself express immovability.

Use no object for abstract mood, light quality, distant history, or incidental
collective detail when players would not reasonably address it. Rewrite
misleading concrete prose or explicitly record the intentional exception.
Prominent, repeated, manipulable, blocking, or plot-relevant nouns should
normally be objects.

## English `vocabWords`

The installed English library parses:

```text
adj adj noun/alternateNoun*plural plural
```

Thus:

```tads
piano: Fixture, Surface
    'dusty grand piano/instrument' 'grand piano' @ballroom;

chairs: Decoration
    'overturned dusty chair/seat*chairs seats' 'overturned chairs' @ballroom
    isPlural = true;
```

Words before the final adjective-section token are adjectives; the last token
becomes a noun unless `/` or `*` changes sections. Slash introduces alternate
nouns and `*` introduces plurals. Multiword references work by combining
separately declared adjectives and nouns: `dusty grand piano` does not need to
be stored as one phrase. Put every concrete noun used in room prose into the
corresponding object's noun or plural vocabulary, and include natural
synonyms. Do not make every descriptive word a noun merely to accept it.

Overlapping vocabulary is legal. The resolver uses in-scope candidates,
grammar roles, vocabulary strength, verification results, and interactive
disambiguation. Give competing objects distinguishing adjectives and useful
`disambigName` values. Do not hide a real ambiguity by deleting vocabulary.
Test the short noun, each prose phrase, and the disambiguating phrase in the
actual room and containment state. Beware inherited default `RoomPart`
objects: defining another `north wall` can yield two matches.

## Plausible interactions

Start with inherited behavior and run the command before customizing it.

- A chandelier that can only be examined is a `Fixture`; inherited `TAKE`
  and `MOVE` refusals are useful. Use `Decoration` only if other interactions
  are intentionally unimportant.
- A usable chair is `Chair`, not a `Fixture` with a handwritten `SitOn`
  response. The class maintains actor posture and nested-room state.
- A cabinet is normally `OpenableContainer`; opening controls visibility and
  reachability of contents.
- A piano can be `Fixture, Surface`. TADS 3.1.3 standard English adv3 does not
  define `PLAY` grammar, so a game promising that action must define a focused
  `PlayAction` and handler (as the fixture demonstrates).
- Looking under or intentionally moving a special object can justify a narrow
  `dobjFor(LookUnder)` or `dobjFor(Move)`. Put mutations in `action()`, reject
  state-dependent attempts in `check()`, and use `verify()` for resolution.
- Prefer standard `Open`, `SitOn`, `LieOn`, `StandOn`, `Take`, and containment
  actions. Do not add a custom action merely to rephrase inherited output.

## Scenery coverage audit

Perform this review per room; it is intentionally human-guided and introduces
no LLM or NLP dependency into tests.

1. Extract concrete physical noun phrases from `desc`, first-visit text,
   special descriptions, and state-dependent variants.
2. Classify each as portable, fixed interactive, limited decoration,
   furniture/support/container, architectural part, or intentional atmosphere.
3. Map every addressable noun to one object and an appropriate semantic class.
   Note intentional non-addressable exceptions with the reason.
4. Compare prose words with `vocabWords`: test primary noun, synonyms,
   plurals, multiword forms, and distinguishing adjectives.
5. Exercise `EXAMINE` plus actions the prose affords: take/move, sit/lie/stand,
   look under, open/close, put in/on, or the object's signature verb.
6. Test scope before and after opening, travel, posture, or state changes.
   Investigate ambiguity, misleading refusals, duplicate room parts, and
   unimplemented references.
7. Keep a transcript with semantic output/state assertions. Compilation alone
   does not establish coverage.

The furnished-room fixture and automated audit examples are in
`assets/examples/world-events-project/` and `tests/world-events.sh`.

## Primary evidence

- Installed `adv3/objects.t`: `NonPortable`, `Fixture`, `Decoration`,
  `Container`, and `Surface`.
- Installed `adv3/travel.t`: `RoomPart`, `BasicChair`/`Chair`,
  `BasicBed`/`Bed`, and `BasicPlatform`/`Platform`.
- Installed `adv3/en_us/en_us.t`: `VocabObject.initializeVocabWith()`.

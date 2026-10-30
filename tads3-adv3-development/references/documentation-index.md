# Documentation and source index

Do not assume one installation prefix. First locate `t3make` and inspect nearby or configured data directories.

## Discovery

Useful commands:

```sh
command -v t3make
command -v frob
find "${TADS3_HOME:-/nonexistent}" -maxdepth 4 -name adv3.tl -o -name adv3.h
find /usr /usr/local "$HOME/.local" -path '*/tads3/lib/adv3/adv3.tl' 2>/dev/null
```

Also inspect project `.t3m` `-FI`, `-FL`, and `-I` entries. The compiler, interpreter, library, documentation, and examples can be installed in different prefixes.

## Authoritative hierarchy

1. Project instructions and reproducible runtime tests for project policy/behavior.
2. Installed standard-adv3 library source matching the build.
3. Official Library Reference for API signatures and inheritance.
4. Official Tour Guide and Getting Started Guide for usage patterns.
5. TADS System and Technical Manuals for language/compiler/runtime details.
6. Installed official samples.
7. Clearly identified standard-adv3 game source, with version/license review.
8. Conversation history or compiled-game observation only as a research lead.

Never transfer adv3Lite or TADS 2 APIs into standard adv3 because names look similar.

## Common local paths under a prefix

```text
share/frobtads/tads3/include/
share/frobtads/tads3/lib/adv3/
share/frobtads/tads3/lib/adv3/en_us/
share/frobtads/tads3/lib/samples/
share/frobtads/tads3/doc/
```

Other distributions can differ. Record discovered paths rather than hard-coding them.

## Manual map

- Language syntax and object model: System Manual and Technical Manual.
- Builds and `.t3m`: `sysman/build.htm`, `techman/t3start.htm`.
- Preprocessor and `__DEBUG`: `sysman/preproc.htm`.
- Initialization/debug preinit: `sysman/init.htm`.
- Objects, rooms, containment, senses: Tour Guide, GSG, Library Reference.
- Actions and verbs: Technical Manual verb/action chapters; `adv3.h`, `action.t`, language grammar source.
- Travel: `travel.t`, `actor.t`, `thing.t`, Library Reference.
- Conversation: Tour Guide/Technical Manual actor chapters; `actor.t`.
- Events: `events.t` and Library Reference.
- Scoring: `score.t` and Library Reference.

When uncertain, search class or method names in both the Library Reference and installed `.t` source. Record the library version supporting the conclusion.

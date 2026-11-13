# Language and build

## TADS source essentials

- Include `adv3.h` and the selected language header, normally `en_us.h`, in independently compiled game modules that use their declarations.
- Define static objects as `name: Superclass ... ;`. Use properties for data and methods for behavior. A double-quoted property value displays when evaluated; a single-quoted value is a string value.
- Use `inherited(...)` to invoke inherited implementation. Check multiple-inheritance ordering in the official language documentation before combining mix-ins; superclass order affects lookup.
- Use `modify objectName` to alter an existing object and `replace` only when intentionally replacing its definition. Prefer local object overrides to global library modification.
- Use `#include`, `#define`, `#ifdef`, and `#if` through the TADS preprocessor. `__DEBUG` is defined as `1` by compiler debug mode and is undefined in release mode.

## Standard adv3 build

A typical `.t3m` provides:

```text
-pre
-FI /path/to/tads3/include
-FL /path/to/tads3/lib
-I /path/to/tads3/lib/adv3
-I /path/to/tads3/lib/adv3/en_us
-DLANGUAGE=en_us
-DMESSAGESTYLE=neu
-Fo build/obj
-Fy build/obj
-o build/game.t3
-lib system
-lib adv3/adv3
-source game.t
```

Do not copy absolute paths blindly. Resolve a toolchain prefix from project configuration or environment. Keep object and symbol output separate from source. Distinct targets should have distinct output directories to prevent stale or basename-colliding intermediates.

`t3make -f game.t3m` performs an incremental release build. `t3make -d -f game.t3m` enables debugging information and `__DEBUG`. `-r` forces recompilation. Official compiler documentation notes that preinitialization timing differs in debug builds; use explicit `-pre` or `-nopre` only when the project understands the consequence.

## Manifest-relative paths

TADS 3.1.3 resolves relative manifest entries from the directory containing
the `.t3m`, not from the shell's current working directory. This applies to
source entries and to paths supplied to options such as `-Fo`, `-Fy`, and
`-o`. Consequently, a manifest at `config/release.t3m` for this layout:

```text
project/
  config/release.t3m
  src/game.t
  build/release/
```

uses paths that step out of `config/`:

```text
-Fo "../build/release/obj"
-Fy "../build/release/obj"
-o "../build/release/game.t3"
-source "../src/game.t"
```

Invoke it as `t3make -f config/release.t3m` from the project root or through a
wrapper; the entries still resolve from `config/`. Do not compensate for an
assumed caller working directory. Create required output directories before
compilation unless the surrounding build explicitly does so.

Give a debug manifest its own paths, for example
`../build/debug/obj` and `../build/debug/game-debug.t3`; sharing `-Fo` or `-Fy`
between release and debug permits stale or incompatible intermediates. The
verified manifests under `assets/examples/stabilization-project/config/`
exercise this layout with TADS Compiler 3.1.3.

## Diagnostics

When compilation fails:

1. Capture the first diagnostic and its source location; later errors can cascade.
2. Confirm the selected library is standard adv3 and the language paths match it.
3. Confirm every referenced module is listed and every include path exists.
4. When the manifest is below the project root, resolve every relative path
   from the manifest directory and inspect the diagnostic's attempted path.
5. Check missing semicolons, mismatched braces, property/method syntax, macro expansion, superclass names, and object identifiers.
6. Rebuild with `-r` if dependencies or compile options changed.
7. Separate each target's `-Fo` and `-Fy` directories. TADS intermediates are basename-oriented; duplicate source basenames can collide even when directories differ.

## Project-policy boundary

Explicit module lists, descriptive basenames, and a shared header are reliable practices, but exact directory names and file decomposition are project choices. Never force a particular repository layout on an existing project.

## Primary evidence

- System Manual: `sysman/build.htm`, `sysman/preproc.htm`, `sysman/init.htm`, `sysman/progstru.htm`.
- Technical Manual: `techman/t3start.htm`, `techman/t3inc.htm`, `techman/t3oop.htm`, `techman/t3mi.htm`.
- Installed `adv3.h`, `adv3.tl`, language `.tl`, and sample `.t3m` files.

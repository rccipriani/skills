---
name: tads3-adv3-development
description: Develop, debug, test, maintain, or provision interactive fiction written in TADS 3 with the standard adv3 library. Use for new or existing standard-adv3 projects, TADS source and .t3m build files, parser/action/object-model questions, actors and conversation, events and scoring, transcript regression tests, blind-playtest engineering, or checking/installing/validating/repairing a TADS 3 and FrobTADS toolchain. Do not use for adv3Lite or TADS 2 except to identify that they require different guidance.
---

# TADS 3 / adv3 development

Work from project evidence and installed standard-adv3 documentation. Do not infer APIs from adv3Lite or TADS 2 material.

## Installation and portability

Copy this entire directory to `${CODEX_HOME}/skills/tads3-adv3-development` or, when `CODEX_HOME` is unset, `~/.codex/skills/tads3-adv3-development`. Preserve executable permission on `scripts/tads3-toolchain.sh`. The skill contains no compiler or third-party manuals; discover or provision them separately.

## Core workflow

1. Read repository instructions and inspect its source layout, build manifests, scripts, tests, and working-tree state. Preserve local conventions unless technically harmful; do not impose this skill's examples as a layout.
2. Determine whether the project uses standard adv3. Check includes and `-lib` entries instead of guessing.
3. Run `scripts/tads3-toolchain.sh check` when toolchain locations or versions are unknown. Read [toolchain-provisioning.md](references/toolchain-provisioning.md) for installation, validation, or repair work.
4. Consult the relevant reference below before using an unfamiliar class, method, macro, hook, or compiler option. Prefer the installed library source and official manuals over memory.
5. Model the world with existing adv3 classes and one authoritative state representation. Add the smallest coherent customization.
6. Compile after meaningful changes. Add focused runtime coverage and exercise natural player phrasing, failure paths, state changes, and inherited behavior.
7. Run the complete project suite and a release build. Review output, not merely exit status. Report assumptions and unresolved uncertainty.

Do not install packages, invoke privilege escalation, download code, overwrite a working toolchain, or change global configuration without explicit authorization. `check`, `validate`, `fetch`, `install`, and `repair` are distinct operations; acquisition and installation require separate approval.

## Reference routing

- Language, object syntax, inheritance, modification, includes, `.t3m`, debug/release, and diagnostics: [language-and-build.md](references/language-and-build.md)
- Rooms, objects, containment, senses, vocabulary, state, descriptions, and disambiguation: [adv3-object-model.md](references/adv3-object-model.md)
- Actions, grammar, literals, remapping, verification, preconditions, and responses: [parser-and-actions.md](references/parser-and-actions.md)
- Movement API distinctions, connectors, room entry, and travel memory: [travel-and-containment.md](references/travel-and-containment.md)
- Actors, topics, conversation state, presence, and NPC testing: [actors-and-conversation.md](references/actors-and-conversation.md)
- Turn time, `actionTime`, daemons, fuses, and scoring: [events-and-scoring.md](references/events-and-scoring.md)
- Transcript harnesses, parser-affordance review, reachability, debug commands, and release QA: [testing-and-quality.md](references/testing-and-quality.md)
- Verified reusable lessons, limitations, and evidence status: [common-pitfalls.md](references/common-pitfalls.md)
- Blind-playtest handling and interface limitations: [blind-playtests.md](references/blind-playtests.md)
- Local documentation/source discovery and API lookup: [documentation-index.md](references/documentation-index.md)
- Supported provisioning operations and OS-specific procedures: [toolchain-provisioning.md](references/toolchain-provisioning.md)

## Toolchain operations

Run the bundled script from the skill directory:

```sh
scripts/tads3-toolchain.sh check
scripts/tads3-toolchain.sh plan
scripts/tads3-toolchain.sh validate
scripts/tads3-toolchain.sh repair
scripts/tads3-toolchain.sh fetch --authorize-download
scripts/tads3-toolchain.sh install
```

`check` and `plan` are read-only. `validate` writes only to a temporary directory and compiles the neutral fixture in `assets/examples/validation-project/`. `repair` diagnoses and proposes actions. `fetch` reuses a verified cache offline or, only with `--authorize-download`, retrieves the pinned FrobTADS commit and generates provenance. `install` prints a plan by default; execution requires `--execute`, verified provenance, an authorized user-owned root, a new prefix, and a separate record of prior approval for the exact source and destination. Read the provisioning reference first.

## Examples and validation assets

Use `assets/examples/validation-project/` as a neutral, standalone standard-adv3 fixture. It demonstrates a stateful object, custom action and grammar, actor topics, a daemon, an achievement, and a `__DEBUG`-guarded command. Keep copied examples generic and adapt them to the target project's conventions.

## Evidence rules

- Mark behavior verified only when supported by official documentation/library source or reproduced with a stated compiler/library version.
- Treat conversation-history recollections, compiled-game observations, and unexecuted snippets as leads, not proof.
- Inspect runtime output for inherited reports, implicit actions, scope, turn advancement, sensory effects, and wrapping.
- If evidence conflicts, preserve project behavior, cite the conflict, and investigate before generalizing.
- Never promise that blind-playtest content is invisible: clients can expose tool calls, patches, diffs, logs, or command output independently of narration.

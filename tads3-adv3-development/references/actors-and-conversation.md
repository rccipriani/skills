# Actors and conversation

## Start with standard actor machinery

Use `Actor`, appropriate `ActorState` subclasses, and ordinary topic entries before inventing a dialogue engine. Common entries include `AskTopic`, `TellTopic`, `AskTellTopic`, `ShowTopic`, `GiveTopic`, `HelloTopic`, `ByeTopic`, and stateful variants. Confirm names and nesting rules in the installed version.

Small interactions can keep topics directly under an actor. Use conversation nodes, suggested topics, agendas, or richer actor states when the conversation structure actually needs them.

## State-derived dialogue

Derive diagnostics or acknowledgements from world state rather than maintaining duplicate conversation flags:

```tads
+ AskTellTopic @sampleWidget
    "<<sampleWidget.isAligned
        ? 'The widget appears aligned.'
        : 'The widget still needs alignment.'>>"
;
```

Use separate knowledge or relationship state only when it represents genuinely different information, such as what the actor has learned or disclosed.

## Presence and scope

Topic availability does not make an absent actor conversationally reachable. Ordinary scope should reject dialogue after an actor leaves unless the game deliberately implements remote communication. Test the actor in range and out of range.

Conversation commands are ordinary actions and normally consume turns. Turn-based movement or events can therefore occur after a response, including an actor departing on the same command. Keep the response coherent with subsequent event output; do not freeze daemons merely to simplify dialogue tests.

## Initiation and termination

Use standard hello/goodbye topics and conversation-state hooks. If initiating conversation during startup, note that initialization lacks an ordinary action context; the library source documents `OneTimePromptDaemon` as one way to defer work until a safe prompt-time action environment.

## Regression matrix

Test:

- greeting, farewell, ask, tell, show, and give where supported;
- expected topic vocabulary and a reasonable unknown topic;
- repeated questions;
- dialogue before and after relevant state changes;
- actor movement during conversation;
- actor absence and scope rejection;
- conversation-node or state transitions;
- save/restore if conversation state is important.

## Primary evidence

- Technical Manual actor and conversation chapters, including `techman/t3actor.htm` and conversation background.
- Tour Guide actor/conversation chapters.
- Installed `actor.t`, `travel.t`, `events.t`, and library reference topic entries.

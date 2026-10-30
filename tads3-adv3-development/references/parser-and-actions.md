# Parser and actions

## Prefer existing actions

Before defining grammar, search standard action names and object handlers. Add object-specific handling with `dobjFor(Action)` or `iobjFor(Action)` when the player's wording already maps to a standard action. Use `remapTo()` for a true semantic alias; avoid remapping merely to suppress a useful precondition or report.

Parser words and action class names are different layers. In the standard
adv3 English grammar, ordinary `turn on generator`, `switch on generator`,
`turn generator on`, and `activate generator` all select `TurnOnAction`.
Handle the direct object with `dobjFor(TurnOn)`:

```tads
generator: Fixture 'compact test generator' 'generator' @generatorRoom
    isOn = nil

    dobjFor(TurnOn)
    {
        verify() { logical; }
        check()
        {
            if (isOn)
                failCheck('The generator is already running. ');
        }
        action()
        {
            isOn = true;
            "The generator starts. ";
        }
    }
;
```

Do not infer a `SwitchOn` action class merely because the player types the word
“switch.” A handler can compile yet never receive the intended command. When
dispatch is uncertain, search the installed language grammar—typically
`adv3/en_us/en_us.t`—for the `VerbRule` containing the player wording, then
follow its `: ...Action` target. TADS 3.1.3 defines `VerbRule(TurnOn)` with
`('turn' | 'switch') 'on'` and maps it to `TurnOnAction`. Confirm behavior with
both natural phrasings at runtime. The stabilization fixture does exactly this.

## Action processing

For a transitive object action, the ordinary order is broadly:

1. resolution and scope;
2. `verify()` to rank or reject logical objects;
3. preconditions, which can perform implicit actions;
4. `check()` for state-dependent refusal that should not alter the world;
5. `action()` for the state change;
6. reports and turn/event processing.

Use `illogical`, `illogicalNow`, or related verification results to guide resolution, not as a substitute for every runtime check. Put mutations in `action()`, not `verify()` or `check()`.

```tads
dobjFor(Polish)
{
    verify() { logical; }
    check() {
        if (isPolished)
            failCheck('It is already polished. ');
    }
    action() {
        isPolished = true;
        "You polish it. ";
    }
}
```

## Defining grammar

Use the library macros and associate the grammar with the action:

```tads
DefineTAction(Polish);

VerbRule(Polish)
    ('polish' | 'buff') singleDobj
    : PolishAction
    verbPhrase = 'polish/polishing (what)'
;
```

Use `DefineIAction` for no-object actions, `DefineTIAction` for direct and indirect objects, and literal-action macros when raw text is part of the command. Consult `adv3.h`, `action.t`, `parser.t`, and the language-layer `VerbRule` examples for exact macro and production forms.

Do not create custom grammar when a synonym can be added to an existing verb rule or vocabulary, or when an existing standard action plus object handler expresses the intent.

## Literal actions

Literal text is not a resolved world object. Use `DefineLiteralAction` or the appropriate literal-plus-object action class, then read the literal through the action's documented accessor. Verify the exact API in the installed library version; literal-action internals are easy to misremember.

## Reasonable-command coverage

Blind or ordinary play frequently reveals commands that are physically reasonable but unsupported. For each prominent object, test likely verbs suggested by its description and role. Give a specific refusal or safe synonym when it improves the model. Do not add a broad custom parser layer merely to catch isolated commands.

## Primary evidence

- Technical Manual: `techman/t3verb.htm`, `techman/t3action.htm` where installed.
- Library source: `adv3.h`, `action.t`, `actions.t`, `parser.t`, `precond.t`, `verify.t`, and language `en_us.t`.
- Library Reference for the action and precondition classes in use.

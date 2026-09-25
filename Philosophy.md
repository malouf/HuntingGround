# Philosophy

Design principles for this project, written for AI agents first. They apply to
code, specs and documents alike.

## Principles

| # | Principle | Rule |
|---|---|---|
| 1 | Data first | Settle the data structures before the code that handles them. |
| 2 | Data, flow, transform | Design the data structures and how they flow through the system; then design how the data is transformed, and by which code; then the rest. |
| 3 | Keep the parts separate | Nothing branches on which kind of thing it is handling; one code path handles every entry. |
| 4 | Minimalism | Before adding a system, look for a rule or limit to delete. |
| 5 | Keep one record | Each fact has one location; derive everything else. |
| 6 | Grow by addition | Add a directory, file or entry to an existing list; leave the core code untouched. |
| 7 | Reserve, don't implement | Give a deferred decision a named place, and no machinery. |
| 8 | Say why where it surprises | A deliberate choice a reader would "fix" gets its reason at that spot. |
| 9 | Rewrite only upward | A replacement must be better than what it removes; reuse a working part before inventing one. |
| 10 | State only what is decided | Do not present defaults as requirements; ask when unknown. |
| 11 | Write facts, plainly | No benefit claims, no restating the obvious, no corollaries. |
| 12 | Fix the source, not the spot | A mistake that shows up twice is fixed where it is produced, not at one place it appeared. |

Notes:

- 4: every system added is a rule the project keeps; capability often comes
  from deleting one.
- 7: deferred work is a named place in the structure, never a stub with
  guessed inputs and outputs.
- 9: the parts already in the project are the quality floor; a new one must
  beat them.
- 10: a default the agent chose is not a decision the user made.

## Examples

Each pair gives the context, the direct version, and the usual AI output.

### A definition

Context: the opening of TEMPO_CHAIN_PLAN.md, introducing the link window.

Direct:

> The link window is the stretch of a swing from 0.28s to 0.68s after the
> swing starts. A press inside it starts the next swing and cancels the
> remaining recovery.

AI output:

> The link window is the heart of the combat system, providing an elegant and
> responsive rhythm framework that empowers expressive player mastery.

Why the direct one wins: it names the window, the times, and what a press
does. The AI version replaces three facts with three adjectives.

### A table

Context: documenting which gesture maps to which sword move.

Direct:

> | Gesture | Move |
> |---------|------|
> | Left    | Slash left |
> | Up      | Slash up |
> | Circle  | Whirlwind (chain-scaled finisher) |

AI output:

> The gesture mapping is designed for flexibility and ease of use, with
> careful attention paid to player comfort on mobile.

Why: the reader needs the mapping and can copy it from the table. The
paragraph carries no usable information.

### A constraint

Context: what happens to a fourth press during the finisher.

Direct:

> A press during the finisher does nothing. The chain has exactly 3 hits;
> offer_input() returns "used" before any check that could stagger.

AI output:

> The input system guarantees that accidental extra presses can never disrupt
> the flow of combat.

Why: the direct version gives the rule, the code reason and the observable
result. The AI version claims a guarantee and says neither what it is nor why
it holds.

### Capability by removal

Context: classifying every press during a running swing.

Direct (the current tempo chain):

> A press during a swing is one of three things: on the beat (critical), in
> the 0.09s band before it (weak), or elsewhere (spam, stagger).
> offer_input() returns one classification; the caller applies it.

AI output (the earlier design):

> Separate branches for "recovery", "lapse", "window_early", "early" and
> "late" presses, each with its own timer and queue.

Why: the three zones already classify every press. The extra states added
branches, timers and bugs, and were deleted before the ring could show one
honest picture.

### An invented constraint

Context: how a new attack gets added to the sword.

Direct:

> Add an AttackDefinition .tres in resources/weapons/ and map it in the
> weapon's moves or finishers dictionary.

AI output:

> **No hardcoded attacks, ever. Data is not code.**

Why: nobody decided that as an absolute rule. The AI turned its own default
into a normative rule, and later work had to delete it from two documents.

### Abstraction against fact

Context: explaining that a weapon file shows up in the loadout screen.

Direct:

> The loadout screen lists every WeaponDefinition .tres in
> resources/weapons/.

AI output:

> Weapons discovered by convention participate in the loadout; participation
> is a property of the resources folder.

Why: "participates" and "participation" are invented words the reader has to
decode. The direct version names the folder, and the reader can act on it.
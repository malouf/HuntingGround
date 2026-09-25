---
name: speccing
description: Use when writing or editing specs and design documents in this project.
---

# Writing specs

Design principles that apply to specs and to everything else: see
`Philosophy.md` in the project root.

## What a spec is

A spec documents a system as it must exist: its data, structures, formats,
procedures, and limits. It is technical documentation written for specialists,
plus one part other docs do not have: a record of rejected alternatives.

A spec is not a plan, not a pitch, not a tutorial, not a task list.

## What goes in

- **Scope line**: "This document describes the sword tempo chain." Never
  "aims to", never "the goal is".
- **Terms**, defined the first time they are used, one line each. Example:
  "A swing is one attack, from windup start to recovery end."
- **Structures and formats**: file layouts, resource fields and their types,
  JSON shapes, tables, diagrams. Along with inputs and outputs, they form the
  data flow: the most important thing in software design.
- **Procedures**: what happens, in what order, with which values. Example:
  "A press inside the link window starts the next swing and cancels the
  remaining recovery."
- **Constraints as facts with their cause**: "A fourth press during the
  finisher does nothing, because the chain has exactly 3 hits" is a
  constraint with its cause. The cause is a fact, never a benefit.
- **Pointers to code** for details the spec does not cover: "See
  scripts/combat/tempo_chain.gd for the phase order."
- **Rejected alternatives**, in a dedicated section at the end of the file,
  or in a dedicated file when the record is long. One entry per alternative:
  what was rejected, and the reason. This is the only history a spec carries;
  it exists so the same dead end is not proposed twice.

## What stays out

- Goals, aims, intent, purpose, benefit, "what the reader gains", "what this
  prevents".
- Justifications of the chosen design. The only allowed "why" is the causal
  fact that forces a constraint.
- Comparisons to alternatives in the body: alternatives live only in the
  rejected-alternatives record.
- Quality adjectives, emphasis, selling.
- Abstractions without an operational definition, and vocabulary essays.
- Derivations a specialist produces themselves from the facts.
- Implementation history and logs, user documentation and how-to, task lists,
  temporary designs, POC workarounds.

## Register

Write like a design binder, not like a pitch. The voice carries the same
authority as the facts.

- Short declarative sentences, present tense, active voice. One idea per
  sentence.
- Concrete nouns only: files, scenes, nodes, resources, variables, signals,
  values. No metaphors, no invented words.
- Name the inputs and outputs of every procedure; they are what the reader
  has to reason about.
- Enumerations as tables or lists, never as prose paragraphs. Layouts as
  diagrams or tables.
- Facts first, consequence second, and only when a reader could be surprised
  or hurt by it.
- No quality adjectives, no emphasis, no exclamation, no rhetorical
  questions, no "it is important to note", no "as we have seen".
- Sections are named after their subject, not after an intent.

Register to avoid:

> The chain pips give a delightful sense of rhythm, keeping players engaged
> and making every combo feel rewarding.

Same content in register:

> The chain pips light one per landed hit. The next pip pulses while the link
> window is open: gold on the beat, gray in the weak band.

## Minimalism

Specs must be minimal; overspeccing is the main threat. Too much info means a
risk of wrong info. Missing info is no risk. Too little info is a useless
spec.

A spec is the ideal end state: it must tolerate temporary deviations,
simplifications and workarounds for a POC or MVP without becoming wrong. If it
cannot, it is overspecced — remove constraints.

## Reviewing

Review spec items with the user one by one, not in bulk. For each item ask:

- Does it describe the system: term, structure, format, procedure,
  constraint, or rejected alternative?
- Is every noun concrete (file, scene, node, resource, variable, signal) or
  operationally defined?
- Would a game developer already know it as a consequence? Then cut it.
- Is any "why" a causal fact rather than a justification?
- Is it minimal?

If an item fails, rewrite it or cut it. Do not soften it.
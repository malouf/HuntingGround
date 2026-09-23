# Tempo Chain Plan

A PSO-style rhythm layer combined with Monster Hunter commitment for Hunting Ground.

The core rule: **every combo is ALWAYS exactly 3 hits — input 1, input 2,
FINISHER input.** Example: `Left + Right + Up` is one complete combo. The
first input is always a normal hit (never a critical — there is nothing to
time against). Each swing has `windup -> active -> recovery` and a personal
**link window** whose final portion is the **yellow just-beat**; catching it
on inputs 2 and 3 grants a critical chain, off-beat presses still swing as
weak quick hits.

## Global tempo rules

| Rule | Behavior |
| --- | --- |
| Combo | ALWAYS 3 swings: input 1 (always normal) + input 2 + input 3 = FINISHER |
| Input 1 | Always NORMAL (full damage, never a critical) |
| Just-beat | Tightened final 25% of the link window; the ring lights yellow only there |
| Yellow press | Next swing starts immediately (recovery cancelled), FULL damage |
| Weak band | A narrow 0.09s band hugging the beat just before it: chains a WEAK hit (0.6x) |
| Spam | Anything further off (swing startup, early window, deep recovery, lapse): chain dies, STAGGER |
| Rooted | No movement while a swing runs AND while staggered; finishers unlock movement during their recovery |
| 4th input | Presses during the finisher do nothing (never stagger) |
| Stagger | Red flashing pips, no attacks, no movement, no dodging |
| Finisher | Always the 3rd input, mapped by input (flurry / heavy slash / back step / heavy whirlwind); weak version if weak tier |
| Fatigue | MH commitment layer; chain dying to fatigue also staggers |
| Dodge | Blocked while committed AND while staggered; roll-cancels recovery (chain dies, no stagger) |
| Input grace | 0.06s buffering around the beat + 0.08s double-tap guard |

Damage per swing: input 1 = 1.0x (normal), input 2 = 1.25x, weak tier
multiplies by 0.6, finisher = full finisher damage (weak finisher 0.6x).
Repeating the same technique keeps its falloff. Mashing yields stagger loops;
rhythm yields criticals; slightly-off presses yield weak chains.

## Sword chain (current)

Inputs per swing: L/R slash, U thrust, D back cut, circle whirlwind
(whirlwind scales 0.5x / 0.75x / 1.0x by slot).

| 3rd input | Finisher |
| --- | --- |
| UP | FLURRY: five ticks, 90 total, long committed recovery |
| LEFT / RIGHT | HEAVY SLASH: one committed heavy cut (42) |
| DOWN | BACK STEP: ends the chain with an invulnerable backward hop |
| CIRCLE | HEAVY WHIRLWIND: 60 with a strong push |

The old 2-input combos (D->U parry, D->D / D->L / D->R steps) were removed;
the parry may return later as a dodge-timing counter during the bosses
milestone.

## Bow chain table (step 2)

| Input | Chain role |
| --- | --- |
| L / R quick shot | Slots 1-2 rhythm shots |
| Slot 3 quick release | Power arrow finisher |
| Slot 3 hold down + release | Charged finisher (existing 1.4s charge) |
| Chain ending in circle | Volley: spread of 3 arrows |
| U | Bow bash (slot 1/2 input; chain continues) |

## Tuning: tempo_config.json

All global rhythm windows live in `resources/config/tempo_config.json`
(loaded at startup, missing keys fall back to defaults). Per-attack timings
(windup, active, link window, recovery, damage, fatigue) stay in the
`resources/weapons/*.tres` AttackDefinition resources — editable in the
Godot Inspector. Fields:

| Field | Meaning |
| --- | --- |
| early_grace / late_grace | Buffer around the beat that still counts as critical |
| input_cooldown | Double-tap guard at swing start |
| stagger_time | Full lockout after spam or a dropped combo |
| lapse_time | Grace before an unchained combo counts as dropped |
| yellow_fraction | Critical zone size as a fraction of the link window |
| weak_before | Weak band size in seconds (hugs the beat) |
| quick_scale | Weak-hit damage multiplier |
| fatigue_regen | Fatigue regenerated per second |

The ring shows the three windows in color as the window runs down:
red = stagger (too early), gray = weak, gold = critical.

## Feedback (no damage numbers)

- The chain reads plainly as **CHAIN 1/3 → 2/3 → 3/3 FINISHER** — every combo
  is exactly 3 hits (input 1, input 2, finisher input).
- 3 chain pips above the right stick, one per swing. Pip 1 lights the moment
  input 1 starts the combo; the pip after the last landed swing pulses gold
  only during its yellow beat; all pips flash red while staggered.
- A readout under the pips shows the state: "CHAIN 1/3" (input 1, no quality),
  "CHAIN 2/3 • CRITICAL" (gold), "CHAIN 2/3 • WEAK" (gray),
  "CHAIN 3/3 • ... FINISHER", "STAGGERED" (red).
- A floating "CRITICAL" (gold) or "WEAK" (gray) word pops above the boss on
  every hit that connects; normal input-1 hits stay silent.
- The joystick ring shows the window as it runs down in three colored zones:
  red = stagger (too early), gray = weak, gold = critical (press here).
- Floating "CRITICAL" (gold) / "WEAK" (gray) words pop above the boss ONLY
  when a hit actually connects — never on a whiff.
- Hit-stop, chained-hit flash + heavier sounds, camera micro-shake on finishers (step 3).
- Boss condition stays body-language only (no boss HP bar, per GAME_DESIGN.md).

## Implementation steps

1. [x] Foundation: tempo chain state machine, weapon controller, sword
   controller, weapon + attack resources, main.gd routing, chain pips + ring.
   [x] Revision pass: yellow end-beat only, quick-hit tier, stagger on dropped
   chains, finisher fixed to the 3rd input (flurry / heavy slash / back step /
   heavy whirlwind), 2-input combos removed.
   [x] Strict pass: ALWAYS 3 hits (fixed the off-by-one that made combos run
   4 swings), spam = stagger (weak tier removed), rooted during swings,
   pip 1 lights when the combo starts.
   [x] Tuned pass: weak tier restored with a TIGHT window (yellow beat 25% of
   the link window, weak band 0.12s hugging the beat), rooted during stagger
   too, finishers unlock movement during recovery (shortened per-finisher
   recoveries), 4th input during the finisher does nothing.
2. [ ] Bow tempo chain: bow controller, power arrow finisher, charged finisher, volley.
3. [ ] Juice: hit-stop, boss hit flash, finisher camera shake, sounds (needs audio assets;
   none exist in the repo yet).
4. [ ] Tuning + docs pass: window widths, fatigue regen, GAME_DESIGN.md / ARCHITECTURE.md.
5. [ ] Bosses milestone: boss definitions as resources, 2-3 telegraphed patterns, phase
   transitions, punish windows sized for a full 3-chain (~1.6-2.0s).

## Verification

- `C:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit` must run clean.
- Headless tempo test: `... --headless --path . -s <test_tempo_chain.gd>` prints ALL PASS.
- Playtest checklist: LEFT + RIGHT + UP = one complete 3-hit combo; input 1
  never shows CRITICAL; catch the tight yellow beat on inputs 2 and 3 ->
  criticals; press just before the beat -> WEAK chains; press way off (startup
  or late) -> STAGGER, rooted and no dodging; mash -> stagger loops; 4th input
  during the finisher does nothing; UP finisher -> flurry; DOWN finisher ->
  invulnerable hop back; circle finisher -> heavy whirlwind; you can move again
  during a finisher's recovery; dodge roll-cancels a regular recovery.

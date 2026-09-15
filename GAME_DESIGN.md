# Game Design

## Prototype promise

Hunting Ground is a portrait 3D boss-rush game about learning dangerous attack patterns and expressing intent through a weapon joystick instead of attack buttons.

The first vertical slice is deliberately small: one hub, one loadout screen, one hunter, one sword, one boss, and one complete fight loop.

## Player loop

1. Visit the hub.
2. Open the loadout.
3. Equip the Hunter's Sword.
4. Enter the Grave Brute hunt.
5. Read the boss telegraph, attack during recovery, and dodge committed strikes.
6. Win or return to the hub after defeat.

## Controls

- Left joystick: movement.
- Right joystick: choose attack direction; release to commit.
- Upper screen drag: third-person camera orbit.
- Lock: focus camera between hunter and boss; later cycles targets.
- Dodge: short movement burst with a brief invulnerability window.
- Desktop fallback: WASD/arrows, Space attack, Shift dodge, L lock.

## Sword prototype

- Horizontal input selects a left or right slash.
- Upward input selects a thrust.
- Downward input selects a back cut.
- The right joystick selects technique; movement-facing direction determines where the sword lands.
- `L → R → U → U` triggers a five-cut flurry.
- `D → U` attempts a strict parry; `D → D` backsteps; `D → L/R` sidesteps.
- Clockwise and counter-clockwise circles trigger opposite whirlwinds.
- Attacks consume fatigue, have grounded recovery, and leave the hunter vulnerable when committed.
- Repeating the same technique applies damage fall-off and increasing fatigue cost until the input chain resets.
- `D → D` is a backward dodge; `D → L/R` are side steps.
- Current damage targets are slash 22, thrust 28, back cut 18, parry counter 36, flurry 68, and whirlwind 48 before repetition fall-off.

## Boss prototype

The Grave Brute closes distance, telegraphs a committed melee strike, and punishes staying in range. Its internal health is never shown as a bar. At damage thresholds it changes color/posture, accelerates attack cadence, and becomes movement-impaired so the player reads its condition from the body and behavior.

## Progression

Bosses unlock linearly after defeat, but unlocked bosses are freely selectable. Progress is saved locally. The first slice stores the first boss defeat flag only.

## Bow prototype

The bow uses the same right-stick gesture language with different interpretation:

- Hold down to nock and charge; movement is locked while charging, horizontal right-stick movement turns the hunter in the opposite direction, and release fires a visible arrow along the final facing.
- The third charged shot is a finisher and resets the shot chain.
- Left/right fires a quick shot while dodging laterally.
- Up performs a short-range bow bash.
- Two-finger vertical swipes cycle the item roulette; horizontal swipes cycle elemental arrows.

## Future content

The full game can add nine more bosses, more weapon definitions, items without crafting, and a larger hub presentation. New weapons should reuse the same gesture contract while interpreting direction, hold duration, and multi-touch differently.

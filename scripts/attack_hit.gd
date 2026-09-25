class_name AttackHit
extends Resource

## One hit of a multi-hit attack: the five Flurry cuts, whirlwind ticks.
## When an AttackDefinition has hits, the list is the full hit sequence and
## the attack's own damage/timing describe the swing as a whole.

@export var delay := 0.13
@export var damage := 18.0
## AttackDefinition.HitShape value (0 sphere, 1 box, 2 capsule). -1 inherits.
@export var hitbox_shape := -1
## Effect applied by this hit; "" inherits the attack's status effect.
@export var status_effect := ""

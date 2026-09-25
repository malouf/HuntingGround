class_name BossPhase
extends Resource

## One phase of a boss fight. Phases are ordered by hp_below; the boss is in
## the last phase whose hp_below is at or above its health fraction.

## Phase applies while health fraction <= hp_below. The first phase owns 1.0.
@export var hp_below := 1.0
## Walk speed while stalking the player.
@export var walk_speed := 1.3
## Seconds between telegraph starts.
@export var attack_cadence := 2.8
## Multiplies move speed: telegraph, active and recovery are divided by this.
@export var attack_speed := 1.0
## Body color and tilt applied when the phase starts.
@export var body_color := Color("#8d514d")
@export var tilt_degrees := 0.0
## Shown after the boss display name in the state label.
@export var state_text := "FRESH"
class_name BossFollowUp
extends Resource

## One entry in a BossMove's follow-up chain: which move may come next.

@export var move_id := ""
## Pick weight among the parent move's follow-ups.
@export var weight := 1.0
## Seconds between this move's telegraph start and the previous move's end.
@export var delay := 0.0
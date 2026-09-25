class_name AttackFollowUp
extends Resource

## One ordered auto-combo step: after the parent entry, this attack runs on its
## own with no input. It may itself carry follow-ups, which run depth-first.

## The attack to run. May be a skill entry (an attack with a skill set).
@export var attack: AttackDefinition
## Seconds after the previous step ends (after the parent's hit for the first).
@export var delay := 0.0
## Seconds this step occupies before its own follow-ups start. 0 uses the
## attack's own length, or the skill's cast time.
@export var duration := 0.0

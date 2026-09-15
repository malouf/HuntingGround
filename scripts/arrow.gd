extends Area3D

signal struck(body: Node, damage: float)

var direction := Vector3.FORWARD
var speed := 18.0
var damage := 0.0
var lifetime := 3.0

func setup(flight_direction: Vector3, arrow_damage: float) -> void:
	direction = flight_direction.normalized()
	damage = arrow_damage
	look_at(global_position + direction, Vector3.UP)

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	struck.emit(body, damage)
	queue_free()

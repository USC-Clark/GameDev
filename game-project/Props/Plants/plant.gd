class_name Plant
extends Node2D

signal destroyed


func _ready() -> void:
	add_to_group("level1_plants")
	$HitBox.Damaged.connect(TakeDamage)


func TakeDamage(_damage: int) -> void:
	destroyed.emit()
	queue_free()

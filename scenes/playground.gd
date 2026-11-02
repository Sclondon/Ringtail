extends Node3D
## A test yard for his moves: flat ground, a wall to climb, a high box to glide
## off, crates to whip. Built in code; World 1 is the real level.

var player: Player


func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.62, 0.85)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	add_child(env)
	_box(Vector3(0.0, -1.0, 0.0), Vector3(60.0, 2.0, 60.0), Color(0.36, 0.55, 0.28))
	_box(Vector3(0.0, 1.05, 8.0), Vector3(6.0, 2.1, 4.0), Color(0.6, 0.5, 0.4))
	_box(Vector3(-8.0, 2.5, 4.0), Vector3(3.0, 5.0, 3.0), Color(0.6, 0.5, 0.4))
	for k in 4:
		_crate(Vector3(3.0 + k * 0.9, 0.3, -2.0))

	player = load("res://raccoon.tscn").instantiate()
	player.position = Vector3(0.0, 0.05, 0.0)
	add_child(player)
	var camera := FollowCamera.new()
	camera.target = player
	camera.mode = FollowCamera.Mode.ORBIT
	add_child(camera)
	add_child(N64Filter.new())


func _box(at: Vector3, size: Vector3, colour: Color) -> void:
	var body := StaticBody3D.new()
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(colour)
	body.add_child(visual)
	add_child(body)


func _crate(at: Vector3) -> void:
	var crate := RigidBody3D.new()
	crate.add_to_group(&"tail_hittable")
	crate.position = at
	crate.mass = 2.0
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE * 0.6
	var collider := CollisionShape3D.new()
	collider.shape = shape
	crate.add_child(collider)
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.6
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = Toon.surface(Color(0.7, 0.5, 0.25))
	crate.add_child(visual)
	add_child(crate)

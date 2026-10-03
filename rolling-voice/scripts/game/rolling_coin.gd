class_name RollingCoin
extends Node3D
## 굴러가는 동전.
## - instability(0~1): 누적 실수 비율. 클수록 크게, 빠르게 휘청인다.
## - live_off(0~1): 지금 이 순간 음이 틀린 정도. 잔떨림을 더한다.
## - hit(): 실수했을 때 순간적으로 크게 휘청.
## - fall(): 쓰러짐 (게임 오버 연출).

signal landed

const RADIUS := 1.0
const THICK := 0.16
const GOLD := Color("ffd04d")
const GOLD_DEEP := Color("d99a1e")

var instability := 0.0
var live_off := 0.0
var roll_speed := 7.0
var fallen := false

var _inst := 0.0
var _live := 0.0
var _impulse := 0.0
var _phase := 0.0
var _lean: Node3D
var _spin: Node3D


func _ready() -> void:
	_lean = Node3D.new()
	_lean.name = "Lean"
	add_child(_lean)
	_spin = Node3D.new()
	_spin.name = "Spin"
	_spin.position.y = RADIUS
	_lean.add_child(_spin)
	_build_mesh()


func _build_mesh() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = GOLD
	gold.metallic = 0.8
	gold.roughness = 0.3
	gold.emission_enabled = true
	gold.emission = Color("ffb020")
	gold.emission_energy_multiplier = 0.18
	gold.rim_enabled = true
	gold.rim = 0.4

	var deep := StandardMaterial3D.new()
	deep.albedo_color = GOLD_DEEP
	deep.metallic = 0.75
	deep.roughness = 0.4
	deep.emission_enabled = true
	deep.emission = Color("c27a00")
	deep.emission_energy_multiplier = 0.15

	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = RADIUS
	cyl.bottom_radius = RADIUS
	cyl.height = THICK
	cyl.radial_segments = 72
	cyl.rings = 1
	cyl.material = gold
	body.mesh = cyl
	body.rotation_degrees.z = 90.0
	_spin.add_child(body)

	var face := MeshInstance3D.new()
	var inset := CylinderMesh.new()
	inset.top_radius = RADIUS * 0.8
	inset.bottom_radius = RADIUS * 0.8
	inset.height = THICK + 0.03
	inset.radial_segments = 72
	inset.rings = 1
	inset.material = deep
	face.mesh = inset
	face.rotation_degrees.z = 90.0
	_spin.add_child(face)

	for side in [-1.0, 1.0]:
		var rim := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = RADIUS * 0.86
		torus.outer_radius = RADIUS * 0.99
		torus.rings = 72
		torus.ring_segments = 10
		torus.material = gold
		rim.mesh = torus
		rim.rotation_degrees.z = 90.0
		rim.position.x = side * THICK * 0.42
		rim.scale = Vector3(1.0, 0.5, 1.0)
		_spin.add_child(rim)

		var star := Label3D.new()
		star.text = "★"
		star.font = UiTheme.font()
		star.font_size = 240
		star.outline_size = 0
		star.pixel_size = 0.0042
		star.modulate = Color("ffe08a")
		star.shaded = true
		star.double_sided = false
		star.position.x = side * (THICK * 0.5 + 0.02)
		star.rotation_degrees.y = 90.0 * side
		_spin.add_child(star)


func reset() -> void:
	fallen = false
	instability = 0.0
	live_off = 0.0
	_inst = 0.0
	_live = 0.0
	_impulse = 0.0
	_lean.rotation = Vector3.ZERO
	_lean.position = Vector3.ZERO


func hit() -> void:
	_impulse = 1.0


func fall() -> void:
	if fallen:
		return
	fallen = true
	var dir := signf(_lean.rotation.z)
	if dir == 0.0:
		dir = 1.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_lean, "rotation:z", dir * PI * 0.5, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lean, "rotation:y", _lean.rotation.y + dir * 0.6, 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(_lean, "position:y", THICK * 0.5, 0.9).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "roll_speed", 0.0, 1.0).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(landed.emit)


func _process(delta: float) -> void:
	_spin.rotate_x(-roll_speed / RADIUS * delta)
	if fallen:
		return
	_inst = lerpf(_inst, instability, 1.0 - exp(-delta * 2.0))
	_live = lerpf(_live, live_off, 1.0 - exp(-delta * 6.0))
	_impulse = move_toward(_impulse, 0.0, delta * 0.8)
	var amp := deg_to_rad(1.5 + _inst * 24.0 + _live * 5.0 + _impulse * 14.0)
	var freq := 0.8 + _inst * 1.4 + _impulse * 1.2 + _live * 0.5
	_phase += delta * freq * TAU
	var jitter := deg_to_rad(_live * 1.8) * sin(_phase * 5.3)
	var lean := amp * sin(_phase) + jitter
	_lean.rotation.z = lean
	_lean.rotation.y = -lean * 0.45
	_lean.position.x = sin(_phase - 0.9) * (_inst * 0.8 + _impulse * 0.35)


## 지금 기울어진 정도(0~1). 파티클·카메라 연출용.
func wobble_amount() -> float:
	return clampf(absf(_lean.rotation.z) / deg_to_rad(30.0), 0.0, 1.0)


func contact_point() -> Vector3:
	return global_position + Vector3(_lean.position.x, 0.0, 0.0)

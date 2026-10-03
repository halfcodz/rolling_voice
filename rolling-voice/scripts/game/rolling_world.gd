class_name RollingWorld
extends Node3D
## 동전이 굴러가는 3D 무대.
## 동전은 제자리에 있고, 도로 타일(Kenney Racing Kit)과 주변 풍경이 뒤로 흘러간다.

enum CameraMode { MENU, GAME }

const TILE := 10.0
const ROWS := 15
const ROAD := preload("res://assets/models/racing/track-straight.glb")
const FINISH := preload("res://assets/models/racing/track-finish.glb")
const SIDE_TILES: Array[PackedScene] = [
	preload("res://assets/models/racing/decoration-forest.glb"),
	preload("res://assets/models/racing/decoration-forest.glb"),
	preload("res://assets/models/racing/decoration-empty.glb"),
	preload("res://assets/models/racing/decoration-tents.glb"),
]
const FOREST := preload("res://assets/models/racing/decoration-forest.glb")
const CLOUD := preload("res://assets/models/platformer/cloud.glb")
const GRASS := preload("res://assets/models/platformer/grass.glb")

var speed := 7.0
var camera_mode := CameraMode.MENU
var coin: RollingCoin
var camera: Camera3D

var _rows: Array[Node3D] = []
var _clouds: Array[Node3D] = []
var _finish: Node3D
var _finish_distance := -1.0
var _shake := 0.0
var _noise := FastNoiseLite.new()
var _time := 0.0
var _dust: GPUParticles3D
var _sparks: GPUParticles3D
var _confetti: GPUParticles3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	_noise.frequency = 1.4
	_build_environment()
	_build_ground()
	_build_rows()
	_build_clouds()
	coin = RollingCoin.new()
	coin.name = "Coin"
	add_child(coin)
	_build_particles()
	_finish = FINISH.instantiate()
	_finish.visible = false
	add_child(_finish)
	camera = Camera3D.new()
	camera.fov = 55.0
	add_child(camera)
	camera.make_current()
	_update_camera(1.0)


# ── 환경 ──────────────────────────────────────────────────
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3d7fe0")
	sky_mat.sky_horizon_color = Color("bfe2ff")
	sky_mat.sky_curve = 0.1
	sky_mat.ground_bottom_color = Color("2f6b45")
	sky_mat.ground_horizon_color = Color("bfe2ff")
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color("cde9ff")
	env.fog_depth_begin = 45.0
	env.fog_depth_end = 140.0
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.04

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	sun.light_color = Color("fff1d6")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 500)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("3c9a6a")
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position = Vector3(0, -0.03, -100)
	add_child(ground)


func _build_rows() -> void:
	for i in ROWS:
		var row := Node3D.new()
		row.position.z = 20.0 - i * TILE
		add_child(row)
		var road := ROAD.instantiate()
		road.name = "Road"
		row.add_child(road)
		_rows.append(row)
		_decorate_row(row)


func _decorate_row(row: Node3D) -> void:
	for child in row.get_children():
		if child.name != "Road":
			child.queue_free()
	for side in [-1.0, 1.0]:
		var near := SIDE_TILES[_rng.randi() % SIDE_TILES.size()].instantiate()
		near.position.x = side * TILE
		near.rotation_degrees.y = 180.0 * (_rng.randi() % 2)
		row.add_child(near)
		var far := FOREST.instantiate()
		far.position.x = side * TILE * 2.0
		far.rotation_degrees.y = 90.0 * (_rng.randi() % 4)
		row.add_child(far)
		for g in 2:
			var grass := GRASS.instantiate()
			grass.scale = Vector3.ONE * _rng.randf_range(1.6, 2.6)
			grass.position = Vector3(side * _rng.randf_range(5.3, 6.0), 0.0, _rng.randf_range(-4.5, 4.5))
			grass.rotation_degrees.y = _rng.randf_range(0, 360)
			row.add_child(grass)


func _build_clouds() -> void:
	for i in 14:
		var c := CLOUD.instantiate()
		var s := _rng.randf_range(4.0, 9.0)
		c.scale = Vector3(s * 1.6, s * 0.7, s)
		c.position = Vector3(_rng.randf_range(-70, 70), _rng.randf_range(16, 30), _rng.randf_range(-160, 10))
		add_child(c)
		_clouds.append(c)


# ── 파티클 ───────────────────────────────────────────────
func _soft_dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex


func _billboard_material(tex: Texture2D, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _build_particles() -> void:
	var dot := _soft_dot_texture()

	# 바퀴 자국 먼지
	_dust = GPUParticles3D.new()
	_dust.amount = 48
	_dust.lifetime = 0.9
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.6, 1)
	pm.spread = 25.0
	pm.initial_velocity_min = 1.5
	pm.initial_velocity_max = 3.0
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var sc := CurveTexture.new()
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 1.0))
	sc.curve = curve
	pm.scale_curve = sc
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.95, 0.92, 0.85, 0.28))
	ramp.set_color(1, Color(0.95, 0.92, 0.85, 0.0))
	var rt := GradientTexture1D.new()
	rt.gradient = ramp
	pm.color_ramp = rt
	_dust.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.32, 0.32)
	quad.material = _billboard_material(dot)
	_dust.draw_pass_1 = quad
	_dust.position = Vector3(0, 0.05, 0.3)
	add_child(_dust)

	# 휘청일 때 바닥에 긁히는 금빛 불꽃
	_sparks = GPUParticles3D.new()
	_sparks.amount = 60
	_sparks.lifetime = 0.5
	_sparks.emitting = false
	var spm := ParticleProcessMaterial.new()
	spm.direction = Vector3(0, 1, 1)
	spm.spread = 50.0
	spm.initial_velocity_min = 2.0
	spm.initial_velocity_max = 5.0
	spm.gravity = Vector3(0, -12, 0)
	spm.scale_min = 0.25
	spm.scale_max = 0.5
	var sramp := Gradient.new()
	sramp.set_color(0, Color(1.0, 0.85, 0.4, 1.0))
	sramp.set_color(1, Color(1.0, 0.5, 0.1, 0.0))
	var srt := GradientTexture1D.new()
	srt.gradient = sramp
	spm.color_ramp = srt
	_sparks.process_material = spm
	var squad := QuadMesh.new()
	squad.size = Vector2(0.18, 0.18)
	squad.material = _billboard_material(dot, true)
	_sparks.draw_pass_1 = squad
	add_child(_sparks)

	# 완주 축하 꽃가루
	_confetti = GPUParticles3D.new()
	_confetti.amount = 260
	_confetti.lifetime = 3.5
	_confetti.one_shot = true
	_confetti.explosiveness = 0.85
	_confetti.emitting = false
	var cpm := ParticleProcessMaterial.new()
	cpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	cpm.emission_box_extents = Vector3(4, 0.2, 2)
	cpm.direction = Vector3(0, 1, 0)
	cpm.spread = 40.0
	cpm.initial_velocity_min = 7.0
	cpm.initial_velocity_max = 12.0
	cpm.gravity = Vector3(0, -6, 0)
	cpm.damping_min = 1.0
	cpm.damping_max = 2.0
	cpm.angular_velocity_min = -540.0
	cpm.angular_velocity_max = 540.0
	cpm.angle_min = -180
	cpm.angle_max = 180
	cpm.hue_variation_min = -1.0
	cpm.hue_variation_max = 1.0
	cpm.color = Color("ff7aa8")
	_confetti.process_material = cpm
	var cquad := QuadMesh.new()
	cquad.size = Vector2(0.18, 0.28)
	var cmat := StandardMaterial3D.new()
	cmat.vertex_color_use_as_albedo = true
	cmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cquad.material = cmat
	_confetti.draw_pass_1 = cquad
	_confetti.position = Vector3(0, 0.5, -3)
	add_child(_confetti)


# ── 외부에서 부르는 함수 ─────────────────────────────────
func reset() -> void:
	coin.reset()
	speed = 7.0
	coin.roll_speed = speed
	_finish.visible = false
	_finish_distance = -1.0


## sec초 뒤 결승선이 동전 위치를 지나가도록 배치한다.
func show_finish_after(sec: float) -> void:
	_finish_distance = maxf(sec, 0.0) * speed


## 결승선까지 남은 거리를 직접 지정 (게임이 노래 시각에 맞춰 매 프레임 호출)
func set_finish_distance(d: float) -> void:
	_finish_distance = d


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func celebrate() -> void:
	_confetti.restart()
	_confetti.emitting = true


func stop_rolling(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "speed", 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


# ── 매 프레임 ────────────────────────────────────────────
func _process(delta: float) -> void:
	_time += delta
	if not coin.fallen:
		coin.roll_speed = speed
	var dz := speed * delta
	for row in _rows:
		row.position.z += dz
		if row.position.z > 25.0:
			row.position.z -= ROWS * TILE
			_decorate_row(row)
	for c in _clouds:
		c.position.z += dz * 0.08 + delta * 0.4
		if c.position.z > 20.0:
			c.position.z -= 180.0
	if _finish_distance >= 0.0:
		_finish_distance -= dz
		_finish.position = Vector3(0, 0.01, -_finish_distance)
		_finish.visible = _finish_distance < (ROWS - 3) * TILE and _finish_distance > -30.0

	var wobble := coin.wobble_amount()
	_dust.emitting = speed > 0.5 and not coin.fallen
	_dust.position.x = coin.contact_point().x
	_sparks.emitting = wobble > 0.35 and speed > 0.5 and not coin.fallen
	_sparks.amount_ratio = clampf((wobble - 0.35) * 2.0, 0.1, 1.0)
	_sparks.position = Vector3(coin.contact_point().x, 0.05, 0.2)
	_update_camera(delta)


func _update_camera(delta: float) -> void:
	var focus := Vector3(coin.contact_point().x * 0.6, 0.9, 0.0)
	var target_pos: Vector3
	var look: Vector3
	if camera_mode == CameraMode.MENU:
		var orbit := sin(_time * 0.15) * 0.6
		target_pos = focus + Vector3(-3.2 + orbit, 1.5, 4.6)
		look = focus + Vector3(-1.9, 0.5, -1.5)
	else:
		target_pos = focus + Vector3(3.0, 2.2, 5.6)
		look = focus + Vector3(-0.4, 0.4, -3.0)
	var k := 1.0 - exp(-delta * 3.0)
	camera.position = camera.position.lerp(target_pos, k) if delta < 1.0 else target_pos
	_shake = move_toward(_shake, 0.0, delta * 1.8)
	var shake_offset := Vector3(_noise.get_noise_2d(_time * 30.0, 0.0), _noise.get_noise_2d(0.0, _time * 30.0), 0.0) * _shake * 0.35
	camera.look_at_from_position(camera.position + shake_offset, look + shake_offset * 0.5)

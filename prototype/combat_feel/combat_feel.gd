extends Node3D
## PROTOTYPE — wayfinder #16 "Gray-box combat feel test". THROWAWAY, not game code.
##
## Run: Godot_v4.8-beta5_mono_win64.exe --path <repo> prototype/combat_feel/combat_feel.tscn
##
## Implements #6 (lane, march, aggro, fight slots, second rank), #7 (stats,
## wind-up, landing point, splash, death), #11 (base HP/fire), #12 (abilities)
## and #9's camera scale (48 px per metre, pan on the lane axis only).
##
## Shortcuts vs. the spec, all deliberate:
##   - no navmesh: straight steering + light separation instead of NavigationAgent3D
##   - no economy, upgrades or research cost: spawns are free, research is a checkbox
##   - no animations, audio, or auto-follow camera
##   - Fixed seed, so a reset replays the same rolls.

const LANE_HALF := 60.0          # lane is 120 m long on x
const LANE_HALF_W := 20.0        # and 40 m wide on z
const LANE_END := 50.0           # walkable x, inside the two 10 m base footprints
const BASE_X := 55.0
const BASE_HALF := 5.0
const BASE_HP := 10000.0
const BASE_DMG_MIN := 15.0
const BASE_DMG_MAX := 25.0
const BASE_INTERVAL := 1.2
const BASE_RANGE := 14.0         # must be >= the longest unit range (12 m), #6
const BASE_SLOTS := 8
const AGGRO := 20.0
const MARCH := 3.0
const TICK := 0.25
const PROJ_SPEED := 20.0
const SPREAD := 0.5
const PX_PER_M := 48.0
const UNIT_COLOR := Color(0.62, 0.62, 0.60)
const TEAM_COLOR := [Color(0.85, 0.25, 0.22), Color(0.28, 0.55, 0.95)]
const PLAYER_TEAM := 1           # blue; red (team 0) is the opponent

const CLS := [
	{"name": "Warrior", "hp": 240.0, "dmg_min": 22.0, "dmg_max": 32.0, "interval": 0.55,
		"range": 1.6, "radius": 0.55, "windup": 0.2, "cd": 10.0, "ability": "Shockwave"},
	{"name": "Archer", "hp": 150.0, "dmg_min": 22.0, "dmg_max": 32.0, "interval": 1.0,
		"range": 12.0, "radius": 0.45, "windup": 0.3, "cd": 12.0, "ability": "Called Shot"},
	{"name": "Mage", "hp": 130.0, "dmg_min": 20.0, "dmg_max": 30.0, "interval": 1.1,
		"range": 9.0, "radius": 0.45, "windup": 0.4, "cd": 15.0, "ability": "Meteor"},
]

# #13's ramp, reused as a watching aid: [seconds, total, [warriors, archers, mages]]
const RAMP := [
	[0.0, 3, [3, 0, 0]],
	[60.0, 5, [4, 1, 0]],
	[180.0, 8, [4, 3, 1]],
	[360.0, 12, [6, 4, 2]],
	[480.0, 15, [7, 5, 3]],
]


class Unit:
	var team := 0
	var cls := 0
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var hp := 1.0
	var max_hp := 1.0
	var dead := false
	var target_unit: Unit = null
	var target_base: Base = null
	var slot := -1
	var next_swing := 0.0
	var windup_end := -1.0
	var casting := false
	var cast_aim := Vector3.ZERO
	var swing_unit: Unit = null
	var swing_base: Base = null
	var cd_ready := 0.0
	var first_hit := -1.0
	var root: Node3D
	var mesh: MeshInstance3D
	var mat: StandardMaterial3D
	var bar: Node3D
	var bar_fill: MeshInstance3D
	var bar_hide := 0.0


class Base:
	var team := 0
	var pos := Vector3.ZERO
	var hp := BASE_HP
	var next_shot := 0.0
	var slots: Array = []
	var root: Node3D


class Proj:
	var pos := Vector3.ZERO
	var start := Vector3.ZERO
	var dest := Vector3.ZERO
	var t := 0.0
	var dur := 0.2
	var team := 0
	var dmg := 0.0
	var kind := "normal"        # normal | guaranteed | splash | base
	var splash := 0.0
	var target: Unit = null
	var base_target: Base = null
	var tint := Color.WHITE
	var root: Node3D


var time := 0.0
var next_tick := 0.0
var units: Array[Unit] = []
var bases: Array[Base] = []
var projectiles: Array[Proj] = []
var rng := RandomNumberGenerator.new()
var researched := [[false, false, false], [false, false, false]]
var auto_match := false
var auto_next := 0.0
var game_over := ""
var kills := [0, 0]
var clash_start := -1.0
var clash_durations: Array = []
var ttks: Array = []
var engaged_now := 0

var cam: Camera3D
var cam_x := 0.0
var follow_idle := 2.0
var cam_mode := 1        # 1 = down the lane (default, #9's 40 m width), 0 = side-on
var view_scale := 1.0    # 1 = #9's 48 px/m framing; 2/3 keys widen it
var last_view := Vector2.ZERO
var clock_label: Label
var army_label: Label
var clash_label: Label
var ttk_label: Label
var red_bar: ProgressBar
var blue_bar: ProgressBar
var red_pct: Label
var blue_pct: Label
var message: Label
var auto_check: CheckBox
var panel: PanelContainer


func _ready() -> void:
	rng.seed = 20260816
	_setup_world()
	_setup_ui()
	_resize_window()
	# Opens on a 15-a-side mixed clash; --auto watches #13's ramp instead.
	var squad := true
	for arg in OS.get_cmdline_user_args():
		if arg == "--auto":
			squad = false
			auto_match = true
			auto_check.button_pressed = true
		elif arg == "--cam2":
			cam_mode = 1
		elif arg == "--research":
			for team in 2:
				for cls in 3:
					researched[team][cls] = true
		elif arg == "--push":
			squad = false
			for i in 8:
				var w := _spawn(PLAYER_TEAM, 0)
				if w != null:
					w.pos.z = -7.0 + 2.0 * i
					w.root.position = w.pos
	if squad:
		_squad()
	print("PROTOTYPE #16 combat feel — A/D or arrows pan. Free spawns; research is a checkbox.")


func _setup_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.08, 0.10)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_energy = 2.2
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)

	_plane(Vector3(180, 0, 90), Color(0.13, 0.14, 0.15), 0.0)
	_plane(Vector3(120, 0, 40), Color(0.20, 0.21, 0.22), 0.01)
	for i in 12:
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(10.0, 0.01, 40.0)
		band.mesh = bm
		band.position = Vector3(-LANE_HALF + 5.0 + 10.0 * i, 0.015, 0.0)
		band.material_override = _lit(Color(0.17, 0.18, 0.19) if i % 2 == 0 else Color(0.24, 0.25, 0.26))
		add_child(band)
	for z in [-1.0, 1.0]:
		var curb := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(120, 0.25, 0.4)
		curb.mesh = cm
		curb.position = Vector3(0, 0.12, z * LANE_HALF_W)
		curb.material_override = _lit(Color(0.10, 0.11, 0.12))
		add_child(curb)

	bases = [_make_base(0), _make_base(1)]

	cam = Camera3D.new()
	cam.fov = 45.0
	cam.current = true
	add_child(cam)


func _make_base(team: int) -> Base:
	var b := Base.new()
	b.team = team
	b.pos = Vector3(-BASE_X if team == 0 else BASE_X, 0, 0)
	var root := Node3D.new()
	root.position = b.pos
	add_child(root)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(10, 6, 10)
	box.mesh = bm
	box.position.y = 3.0
	box.material_override = _lit(Color(0.34, 0.34, 0.35))
	root.add_child(box)
	var band := MeshInstance3D.new()
	var bandm := BoxMesh.new()
	bandm.size = Vector3(11, 0.7, 11)
	band.mesh = bandm
	band.position.y = 0.35
	band.material_override = _lit(TEAM_COLOR[team])
	root.add_child(band)
	b.root = root
	b.slots.resize(BASE_SLOTS)
	b.slots.fill(null)
	return b


func _plane(size: Vector3, color: Color, y: float) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size.x, size.z)
	mi.mesh = pm
	mi.position.y = y
	mi.material_override = _lit(color)
	add_child(mi)


func _lit(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.95
	return m


func _unshaded(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


# ---------------------------------------------------------------- spawning

func _spawn(team: int, cls: int) -> Unit:
	if game_over != "":
		return null
	var def: Dictionary = CLS[cls]
	var u := Unit.new()
	u.team = team
	u.cls = cls
	u.max_hp = def.hp
	u.hp = def.hp
	var dir := 1.0 if team == 0 else -1.0
	u.pos = Vector3(bases[team].pos.x + dir * (BASE_HALF + 4.0) + rng.randf_range(-1.0, 1.0),
		0.0, rng.randf_range(-3.0, 3.0))

	var root := Node3D.new()
	root.position = u.pos
	add_child(root)

	var mi := MeshInstance3D.new()
	var body: Mesh = null
	if cls == 0:
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 1.8, 0.7)
		body = box
		mi.position.y = 0.9
	elif cls == 1:
		var cap := CapsuleMesh.new()
		cap.radius = 0.35
		cap.height = 1.7
		body = cap
		mi.position.y = 0.85
	else:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.14
		cone.bottom_radius = 0.52
		cone.height = 1.8
		body = cone
		mi.position.y = 0.9
	mi.mesh = body
	var mat := StandardMaterial3D.new()
	mat.albedo_color = UNIT_COLOR
	mat.roughness = 0.9
	mi.material_override = mat
	root.add_child(mi)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.36
	tm.outer_radius = 0.55
	tm.rings = 20
	tm.ring_segments = 6
	ring.mesh = tm
	ring.position.y = 0.03
	var rm := _unshaded(Color(TEAM_COLOR[team].r, TEAM_COLOR[team].g, TEAM_COLOR[team].b, 0.85))
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	root.add_child(ring)

	var bar := Node3D.new()
	bar.position.y = 2.35
	bar.visible = false
	root.add_child(bar)
	var back := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(0.92, 0.11)
	back.mesh = bq
	back.material_override = _billboard(Color(0.05, 0.05, 0.06, 0.9))
	bar.add_child(back)
	var fill := MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(0.88, 0.08)
	fill.mesh = fq
	fill.position.z = 0.01
	fill.material_override = _billboard(TEAM_COLOR[team])
	bar.add_child(fill)

	u.root = root
	u.mesh = mi
	u.mat = mat
	u.bar = bar
	u.bar_fill = fill
	units.append(u)
	return u


func _billboard(color: Color) -> StandardMaterial3D:
	var m := _unshaded(color)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return m


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if game_over != "":
		return
	time += delta
	while time >= next_tick:
		next_tick += TICK
		_retarget()
		_rebuild_slots()
	if auto_match:
		_auto_step()
	_base_fire()
	for p in projectiles.duplicate():
		_step_projectile(p, delta)
	for u in units:
		if u.dead:
			continue
		_move_unit(u, delta)
		_attack_step(u)
	for u in units:
		if u.dead:
			continue
		if u.bar.visible and time > u.bar_hide:
			u.bar.visible = false
	_update_clash_state()
	_refresh_ui()


func _process(delta: float) -> void:
	_update_camera(delta)


# ---------------------------------------------------------------- targeting

func _retarget() -> void:
	for u in units:
		if u.dead:
			continue
		if u.target_unit != null and u.target_unit.dead:
			u.target_unit = null
		if u.target_unit != null:
			continue                                    # sticky until it dies
		var e := _nearest_enemy(u, AGGRO)
		if e != null:
			u.target_unit = e
			u.target_base = null
		else:
			u.target_base = _enemy_base(u.team)


func _nearest_enemy(u: Unit, max_dist: float) -> Unit:
	var best: Unit = null
	var bd := max_dist
	for e in units:
		if e.dead or e.team == u.team:
			continue
		var d := _flat(u.pos, e.pos)
		if d < bd:
			bd = d
			best = e
	return best


func _rebuild_slots() -> void:
	var claims := {}
	for u in units:
		u.slot = -1
	for b in bases:
		b.slots.fill(null)
	for u in units:
		if u.dead or u.cls != 0 or u.target_unit == null:
			continue
		var t := u.target_unit
		if not claims.has(t):
			claims[t] = []
		claims[t].append(u)
	for t in claims:
		var arr: Array = claims[t]
		var tu: Unit = t
		arr.sort_custom(func(a, c): return _flat(a.pos, tu.pos) < _flat(c.pos, tu.pos))
		for i in mini(arr.size(), 6):
			arr[i].slot = i
	for b in bases:
		var waiting: Array[Unit] = []
		for u in units:
			if u.dead or u.cls != 0 or u.target_unit != null:
				continue
			if u.target_base == b:
				waiting.append(u)
		waiting.sort_custom(func(a, c): return _flat(a.pos, b.pos) < _flat(c.pos, b.pos))
		for i in mini(waiting.size(), BASE_SLOTS):
			waiting[i].slot = i


# ---------------------------------------------------------------- movement

func _move_unit(u: Unit, dt: float) -> void:
	var def: Dictionary = CLS[u.cls]
	var goal := u.pos
	var wants := false
	if u.target_unit != null and not u.target_unit.dead:
		var t := u.target_unit
		if u.cls == 0:
			goal = _slot_pos(t, u, u.slot) if u.slot >= 0 else _second_rank(t, u)
		elif _surface(u.pos, t.pos, def.radius, CLS[t.cls].radius) > def.range:
			goal = t.pos
			wants = true
	elif u.target_base != null:
		var b := u.target_base
		if u.cls == 0:
			goal = _base_slot(b, u, u.slot) if u.slot >= 0 else _base_second_rank(b, u)
		elif _base_surface(u.pos, b) > def.range:
			goal = b.pos
			wants = true

	if wants or (u.cls == 0 and _flat(u.pos, goal) > 0.12):
		wants = true
		var d := goal - u.pos
		d.y = 0.0
		var dist := d.length()
		if dist > 0.001:
			var step := minf(MARCH * dt, dist)
			u.vel = d / dist * MARCH
			u.pos += d / dist * step
		else:
			u.vel = Vector3.ZERO
	else:
		u.vel = Vector3.ZERO

	if wants:
		_separate(u, dt)
	u.pos.x = clampf(u.pos.x, -LANE_END + def.radius + 0.05, LANE_END - def.radius - 0.05)
	u.pos.z = clampf(u.pos.z, -LANE_HALF_W + def.radius + 0.05, LANE_HALF_W - def.radius - 0.05)
	u.root.position = u.pos


func _separate(u: Unit, dt: float) -> void:
	for o in units:
		if o == u or o.dead:
			continue
		var d := u.pos - o.pos
		d.y = 0.0
		var want: float = CLS[u.cls].radius + CLS[o.cls].radius + 0.3
		var l := d.length()
		if l > 0.001 and l < want:
			u.pos += d / l * (want - l) * minf(1.0, 8.0 * dt)


func _slot_pos(t: Unit, u: Unit, i: int) -> Vector3:
	if i < 0:
		return _second_rank(t, u)
	var home := bases[u.team].pos
	var base_angle := atan2(home.z - t.pos.z, home.x - t.pos.x)
	var a: float = base_angle + TAU * float(i) / 6.0
	var r: float = CLS[t.cls].radius + CLS[u.cls].radius + 0.2
	return t.pos + Vector3(cos(a) * r, 0.0, sin(a) * r)


func _second_rank(t: Unit, u: Unit) -> Vector3:
	var d := u.pos - t.pos
	d.y = 0.0
	if d.length() < 0.01:
		d = Vector3(1, 0, 0)
	d = d.normalized()
	var r: float = CLS[t.cls].radius + CLS[u.cls].radius + 0.2 + 3.0
	return t.pos + d * r


func _base_slot(b: Base, u: Unit, i: int) -> Vector3:
	var dir := 1.0 if b.team == 0 else -1.0
	var r: float = CLS[u.cls].radius
	return Vector3(b.pos.x + dir * (BASE_HALF + r + 0.1), 0.0, -4.375 + 1.25 * float(maxi(i, 0)))


func _base_second_rank(b: Base, u: Unit) -> Vector3:
	var dir := 1.0 if b.team == 0 else -1.0
	var r: float = CLS[u.cls].radius
	return Vector3(b.pos.x + dir * (BASE_HALF + r + 3.4), 0.0, u.pos.z)


# ---------------------------------------------------------------- attacks

func _attack_step(u: Unit) -> void:
	var def: Dictionary = CLS[u.cls]
	if u.windup_end >= 0.0:
		if time >= u.windup_end:
			_resolve_swing(u)
		return
	if time < u.next_swing or not _can_attack(u):
		return
	u.next_swing = time + def.interval
	u.windup_end = time + def.windup
	u.mesh.rotation.x = -0.35
	u.swing_unit = u.target_unit
	u.swing_base = u.target_base
	u.casting = _can_cast(u)
	if u.casting and u.target_unit != null:
		var flight: float = _flat(u.pos, u.target_unit.pos) / PROJ_SPEED
		u.cast_aim = u.target_unit.pos + u.target_unit.vel * flight


func _can_attack(u: Unit) -> bool:
	var def: Dictionary = CLS[u.cls]
	if u.target_unit != null:
		if u.cls == 0 and u.slot < 0:
			return false
		return _surface(u.pos, u.target_unit.pos, def.radius, CLS[u.target_unit.cls].radius) <= def.range
	if u.target_base != null:
		if u.cls == 0 and u.slot < 0:
			return false
		return _base_surface(u.pos, u.target_base) <= def.range
	return false


func _can_cast(u: Unit) -> bool:
	if not researched[u.team][u.cls] or time < u.cd_ready:
		return false
	if u.target_unit == null:
		return false
	return _can_attack(u)


func _resolve_swing(u: Unit) -> void:
	var def: Dictionary = CLS[u.cls]
	u.windup_end = -1.0
	u.mesh.rotation.x = 0.0
	var t := u.swing_unit
	var b := u.swing_base
	u.swing_unit = null
	u.swing_base = null
	if u.casting:
		u.casting = false
		u.cd_ready = time + def.cd
		_cast(u)
		return
	if t != null:
		if t.dead:
			return                                  # swing dies with the target, no free hit
		if u.cls == 0:
			_damage_unit(u.team, t, rng.randf_range(def.dmg_min, def.dmg_max))
		else:
			_shot(u, t)
	elif b != null:
		if u.cls == 0:
			_damage_base(u.team, b, rng.randf_range(def.dmg_min, def.dmg_max))
		else:
			_launch(u, b.pos, rng.randf_range(def.dmg_min, def.dmg_max), "base", 0.0, null, b,
				Color(0.85, 0.85, 0.8))


func _shot(u: Unit, t: Unit) -> void:
	var def: Dictionary = CLS[u.cls]
	var dmg: float = rng.randf_range(def.dmg_min, def.dmg_max)
	var flight: float = _flat(u.pos, t.pos) / PROJ_SPEED
	var aim: Vector3 = t.pos + t.vel * flight + _spread()
	if u.cls == 2:
		_launch(u, aim, dmg, "splash", 2.5, t, null, Color(0.55, 0.75, 1.0))
	else:
		_launch(u, aim, dmg, "normal", 0.0, t, null, Color(0.92, 0.92, 0.85))


func _cast(u: Unit) -> void:
	print("CAST %s t=%.1f %s" % [CLS[u.cls].ability, time, "RED" if u.team == 0 else "BLUE"])
	match u.cls:
		0:
			for e in _living_enemies(u.team):
				if _flat(e.pos, u.pos) <= 2.5:
					_damage_unit(u.team, e, 15.0)
			_burst(u.pos, 2.5, Color("ffb347"), 0.45)
		1:
			var t := u.target_unit
			if t != null:
				_launch(u, t.pos, 70.0, "guaranteed", 0.0, t, null, Color("ff6fa5"))
		2:
			_launch(u, u.cast_aim + _spread(), 60.0, "splash", 4.0, u.target_unit, null,
				Color("a6e05a"))


func _launch(u: Unit, aim: Vector3, dmg: float, kind: String, splash: float,
		target: Unit, base_target: Base, tint: Color) -> void:
	var p := Proj.new()
	p.pos = u.pos
	p.start = u.pos
	p.dest = aim
	p.dur = maxf(0.06, _flat(u.pos, aim) / PROJ_SPEED)
	p.team = u.team
	p.dmg = dmg
	p.kind = kind
	p.splash = splash
	p.target = target
	p.base_target = base_target
	p.tint = tint
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.11 if kind != "splash" else 0.18
	sm.height = 0.22 if kind != "splash" else 0.36
	mi.mesh = sm
	mi.position.y = 1.0
	var m := _unshaded(tint)
	mi.material_override = m
	var root := Node3D.new()
	root.position = p.pos
	root.add_child(mi)
	add_child(root)
	p.root = root
	projectiles.append(p)


func _step_projectile(p: Proj, dt: float) -> void:
	if not is_instance_valid(p.root):
		projectiles.erase(p)
		return
	p.t += dt / p.dur
	var k := minf(p.t, 1.0)
	p.pos = p.start.lerp(p.dest, k)
	p.root.position = Vector3(p.pos.x, 0.0, p.pos.z)
	if p.t >= 1.0:
		_impact(p)


func _impact(p: Proj) -> void:
	projectiles.erase(p)
	if is_instance_valid(p.root):
		p.root.queue_free()
	match p.kind:
		"base":
			if p.base_target != null and p.base_target.hp > 0.0:
				_damage_base(p.team, p.base_target, p.dmg)
		"guaranteed":
			if p.target != null and not p.target.dead:
				_damage_unit(p.team, p.target, p.dmg)
		"splash":
			_burst(p.dest, p.splash, p.tint, 0.45)
			for e in _living_enemies(p.team):
				if _flat(e.pos, p.dest) <= p.splash:
					_damage_unit(p.team, e, p.dmg)
		_:
			var hit := false
			for e in _living_enemies(p.team):
				if _flat(e.pos, p.dest) <= CLS[e.cls].radius:
					_damage_unit(p.team, e, p.dmg)
					hit = true
					break
			if not hit:
				_burst(p.dest, 0.3, Color(0.45, 0.45, 0.42), 0.25)   # the visible miss


# ---------------------------------------------------------------- base

func _base_fire() -> void:
	for b in bases:
		if b.hp <= 0.0 or time < b.next_shot:
			continue
		var best: Unit = null
		var bd := BASE_RANGE
		for e in units:
			if e.dead or e.team == b.team:
				continue
			var d := _base_surface(e.pos, b)
			if d <= bd:
				bd = d
				best = e
		if best != null:
			b.next_shot = time + BASE_INTERVAL
			_damage_unit(b.team, best, rng.randf_range(BASE_DMG_MIN, BASE_DMG_MAX))


# ---------------------------------------------------------------- damage

func _damage_unit(team: int, t: Unit, amount: float) -> void:
	if t.dead:
		return
	t.hp -= amount
	if t.first_hit < 0.0:
		t.first_hit = time
	t.bar.visible = true
	t.bar_hide = time + 1.0
	var f: float = clampf(t.hp / t.max_hp, 0.0, 1.0)
	t.bar_fill.scale.x = maxf(f, 0.001)
	t.bar_fill.position.x = -0.44 + 0.44 * f
	var tw := create_tween()
	tw.tween_property(t.mat, "albedo_color", Color(1, 1, 1), 0.03)
	tw.tween_property(t.mat, "albedo_color", UNIT_COLOR, 0.1)
	if t.hp <= 0.0:
		_kill(t, team)


func _kill(t: Unit, killer_team: int) -> void:
	t.dead = true
	kills[killer_team] += 1
	if t.first_hit >= 0.0:
		ttks.append(time - t.first_hit)
		print("KILL t=%.1f %s %s took %.2fs to kill" % [
			time, "RED" if t.team == 0 else "BLUE", CLS[t.cls].name, time - t.first_hit])
	t.bar.visible = false
	if is_instance_valid(t.root):
		var tw := create_tween()
		tw.tween_property(t.root, "position:y", -1.6, 0.8)
		tw.tween_callback(t.root.queue_free)


func _damage_base(team: int, b: Base, amount: float) -> void:
	b.hp = maxf(0.0, b.hp - amount)
	if b.hp <= 0.0 and game_over == "":
		game_over = "VICTORY" if b.team != PLAYER_TEAM else "DEFEAT"
		message.text = "%s\nPress Reset to run it again." % game_over
		message.visible = true
		print("BASE DOWN t=%.1f %s" % [time, game_over])


# ---------------------------------------------------------------- measurement

func _update_clash_state() -> void:
	var engaged := 0
	for u in units:
		if not u.dead and u.target_unit != null:
			engaged += 1
	engaged_now = engaged
	if engaged > 0 and clash_start < 0.0:
		clash_start = time
	elif engaged == 0 and clash_start >= 0.0:
		var d := time - clash_start
		clash_start = -1.0
		if d >= 0.3:
			clash_durations.append(d)
			print("CLASH %.2fs" % d)


func _avg(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += v
	return s / float(a.size())


# ---------------------------------------------------------------- auto ramp

func _auto_step() -> void:
	if time < auto_next:
		return
	auto_next = time + 0.5
	var row: Array = RAMP[0]
	for r in RAMP:
		if time >= r[0]:
			row = r
	var target: Array = row[2]
	for team in 2:
		var c := _census(team)
		if c[0] + c[1] + c[2] >= 15:
			continue
		for cls in 3:
			if c[cls] < target[cls]:
				_spawn(team, cls)
				break


func _squad() -> void:
	for team in 2:
		for i in 15:
			var u := _spawn(team, 0 if i < 8 else (1 if i < 13 else 2))
			if u != null:
				u.pos.z = -14.0 + 2.0 * i
				u.root.position = u.pos


func _census(team: int) -> Array:
	var c := [0, 0, 0]
	for u in units:
		if not u.dead and u.team == team:
			c[u.cls] += 1
	return c


# ---------------------------------------------------------------- camera

func _update_camera(delta: float) -> void:
	var pan := 0.0
	if cam_mode == 0:
		# side-on: the lane axis runs left to right
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			pan -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			pan += 1.0
	else:
		# down the lane: the axis runs into the screen, so forward is W/up
		var march := -1.0 if PLAYER_TEAM == 1 else 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			pan += march
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			pan -= march
	if pan != 0.0:
		cam_x += pan * 30.0 * delta
		follow_idle = 0.0
	else:
		follow_idle += delta
	if follow_idle > 2.0:
		cam_x = lerpf(cam_x, _focus_x(), minf(1.0, 2.5 * delta))
	cam_x = clampf(cam_x, -LANE_HALF, LANE_HALF)
	_place_camera(get_viewport().get_visible_rect().size)


func _focus_x() -> float:
	var mine: Unit = null
	var theirs: Unit = null
	for u in units:
		if u.dead:
			continue
		if u.team == PLAYER_TEAM:
			if mine == null or u.pos.x < mine.pos.x:
				mine = u
		elif theirs == null or u.pos.x > theirs.pos.x:
			theirs = u
	if mine == null:
		return theirs.pos.x if theirs != null else cam_x
	if theirs == null:
		return mine.pos.x
	return (mine.pos.x + theirs.pos.x) * 0.5


func _place_camera(vs: Vector2) -> void:
	var vfov := deg_to_rad(cam.fov)
	var hfov := 2.0 * atan(tan(vfov * 0.5) * (vs.x / maxf(vs.y, 1.0)))
	var pitch := deg_to_rad(60.0)
	var look := Vector3(cam_x, 0.8, 0.0)
	var vis_w := (vs.x / PX_PER_M) if cam_mode == 0 else LANE_HALF_W * 2.0
	vis_w *= view_scale
	var dist := (vis_w * 0.5) / tan(hfov * 0.5)
	if cam_mode == 0:
		cam.position = look + Vector3(0.0, sin(pitch), cos(pitch)) * dist
	else:
		# look down the lane from behind the player's army: blue marches -x
		var march := -1.0 if PLAYER_TEAM == 1 else 1.0
		cam.position = look + Vector3(-march * cos(pitch), sin(pitch), 0.0) * dist
	cam.look_at(look, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_V:
				cam_mode = 1 - cam_mode
			KEY_1:
				view_scale = 1.0
			KEY_2:
				view_scale = 1.4
			KEY_3:
				view_scale = 1.8


func _resize_window() -> void:
	var screen := DisplayServer.screen_get_size()
	var w: int = mini(1600, screen.x - 120)
	var h: int = mini(900, screen.y - 160)
	get_window().size = Vector2i(w, h)


# ---------------------------------------------------------------- visuals

func _burst(pos: Vector3, radius: float, color: Color, dur: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.02
	mi.mesh = cm
	mi.position = Vector3(pos.x, 0.04, pos.z)
	var m := _unshaded(Color(color.r, color.g, color.b, 0.45))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, dur)
	tw.tween_callback(mi.queue_free)


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _surface(a: Vector3, b: Vector3, ra: float, rb: float) -> float:
	return maxf(0.0, _flat(a, b) - ra - rb)


func _base_surface(p: Vector3, b: Base) -> float:
	var dx := maxf(absf(p.x - b.pos.x) - BASE_HALF, 0.0)
	var dz := maxf(absf(p.z - b.pos.z) - BASE_HALF, 0.0)
	return Vector2(dx, dz).length()


func _spread() -> Vector3:
	var a := rng.randf() * TAU
	var r := SPREAD * sqrt(rng.randf())
	return Vector3(cos(a) * r, 0.0, sin(a) * r)


func _living_enemies(team: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if not u.dead and u.team != team:
			out.append(u)
	return out


func _enemy_base(team: int) -> Base:
	return bases[1 - team]


# ---------------------------------------------------------------- UI

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	clock_label = _label("0:00", 22)
	head.add_child(clock_label)
	head.add_child(_label("#16 gray-box feel test", 13))

	for i in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		v.add_child(row)
		row.add_child(_label("RED " if i == 0 else "BLUE", 14))
		var bar := ProgressBar.new()
		bar.max_value = BASE_HP
		bar.value = BASE_HP
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(150, 14)
		bar.add_theme_stylebox_override("fill", _style(TEAM_COLOR[i]))
		bar.add_theme_stylebox_override("background", _style(Color(0.15, 0.15, 0.16)))
		row.add_child(bar)
		var pct := _label("100%", 13)
		pct.custom_minimum_size = Vector2(40, 0)
		row.add_child(pct)
		if i == 0:
			red_bar = bar
			red_pct = pct
		else:
			blue_bar = bar
			blue_pct = pct

	army_label = _label("", 14)
	v.add_child(army_label)
	clash_label = _label("clash: —", 14)
	v.add_child(clash_label)
	ttk_label = _label("first hit→death: —", 14)
	v.add_child(ttk_label)
	v.add_child(HSeparator.new())

	for team in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 3)
		v.add_child(row)
		row.add_child(_label("R" if team == 0 else "B", 16))
		for cls in 3:
			var b := Button.new()
			b.text = ["W", "A", "M"][cls]
			b.custom_minimum_size = Vector2(32, 26)
			b.focus_mode = Control.FOCUS_NONE
			b.tooltip_text = "spawn " + CLS[cls].name
			b.pressed.connect(func(): _spawn(team, cls))
			row.add_child(b)
		row.add_child(_label(" res", 12))
		for cls in 3:
			var c := CheckBox.new()
			c.text = ["W", "A", "M"][cls]
			c.add_theme_font_size_override("font_size", 12)
			c.focus_mode = Control.FOCUS_NONE
			c.tooltip_text = "research " + CLS[cls].ability
			c.toggled.connect(func(on: bool): researched[team][cls] = on)
			row.add_child(c)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	v.add_child(controls)
	auto_check = CheckBox.new()
	auto_check.text = "auto ramp"
	auto_check.add_theme_font_size_override("font_size", 13)
	auto_check.focus_mode = Control.FOCUS_NONE
	auto_check.tooltip_text = "#13's ramp, both sides, no gold"
	auto_check.toggled.connect(func(on: bool): auto_match = on)
	controls.add_child(auto_check)
	var reset := Button.new()
	reset.text = "Reset"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset)
	controls.add_child(reset)

	v.add_child(_label("A/D or W/S pans · V camera · 1/2/3 zoom · spawns free", 12))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(center)
	message = _label("", 64)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.visible = false
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(message)


func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.05, 0.06, 0.78)
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	return s


func _style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	return s


func _refresh_ui() -> void:
	panel.position = Vector2(get_viewport().get_visible_rect().size.x - panel.size.x - 12.0, 12.0)
	clock_label.text = "%d:%02d" % [int(time) / 60, int(time) % 60]
	red_bar.value = bases[0].hp
	blue_bar.value = bases[1].hp
	red_pct.text = "%d%%" % roundi(bases[0].hp / BASE_HP * 100.0)
	blue_pct.text = "%d%%" % roundi(bases[1].hp / BASE_HP * 100.0)
	var r := _census(0)
	var b := _census(1)
	army_label.text = "armies   RED %d (%dW %dA %dM)   BLUE %d (%dW %dA %dM)   kills R%d B%d" % [
		r[0] + r[1] + r[2], r[0], r[1], r[2],
		b[0] + b[1] + b[2], b[0], b[1], b[2], kills[0], kills[1]]
	clash_label.text = "clash: %s   avg %s (%d)   engaged %d" % [
		"—" if clash_durations.is_empty() else "%.1fs" % clash_durations[-1],
		"—" if clash_durations.is_empty() else "%.1fs" % _avg(clash_durations),
		clash_durations.size(), engaged_now]
	ttk_label.text = "first hit→death: %s (%d)" % [
		"—" if ttks.is_empty() else "%.1fs" % _avg(ttks), ttks.size()]


func _reset() -> void:
	for u in units:
		if is_instance_valid(u.root):
			u.root.queue_free()
	units.clear()
	for p in projectiles:
		if is_instance_valid(p.root):
			p.root.queue_free()
	projectiles.clear()
	for b in bases:
		b.hp = BASE_HP
		b.next_shot = 0.0
		b.slots.fill(null)
	time = 0.0
	next_tick = 0.0
	auto_next = 0.0
	game_over = ""
	kills = [0, 0]
	clash_start = -1.0
	clash_durations.clear()
	ttks.clear()
	engaged_now = 0
	message.visible = false
	if auto_match:
		auto_check.button_pressed = false
		auto_match = false
	_squad()

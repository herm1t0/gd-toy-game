extends Node
## PROTOTYPE — wayfinder #17 "Base menu wireframe". THROWAWAY, not game code.
##
## Run: Godot_v4.8-beta5_mono_win64.exe --path <repo> prototype/base_menu/base_menu.tscn
##
## One question: does #14's HUD + Base menu fit 1080p and stay readable during a
## fight? #8's tree and #11's numbers are what the cells show; #16's clash runs
## underneath so "readable while the menu is open" can be judged.
##
## Three strip fits (F1/F2/F3) because the menu's structure is settled by #14 and
## the strip's is not. The menu itself has one layout.
##
## Faithful to #14 unless a line below says otherwise:
##   - bottom third only, strip then menu grows upward, menu never pauses
##   - 78% panels, 1 px separators, built-in font 16 px, flat shapes, text not icons
##   - the six upgrade-cell states, recruit greying, queue superscript, no cooldown UI
## Shortcuts (do not judge these):
##   - the HUD's gold, income, clock and build slot are a local stand-in for
##     MatchSnapshot; only army counts and Base HP come from #16's sim
##   - the queue drains when the clash frees a slot, not on a real sim event
##   - no slide-in, no audio, no Shell (#15), no AI (#13), enemy slot is a timer

const FIGHT_SCENE := preload("res://prototype/combat_feel/combat_feel.tscn")

const FONT := 16
const STRIP_H := 120.0
const MENU_H := 240.0
const BOTTOM_H := 360.0
const RECRUIT_ROW := 56.0
const CAP := 15
const PLAYER := 1                      # #16's PLAYER_TEAM (blue, bases[1])

const GOLD_RECRUIT := 100
const START_GOLD := 250
const START_CLOCK := 200.0
const UP_PRICE := [0, 0, 200, 400]
const UP_TIME := [0.0, 0.0, 20.0, 40.0]
const UP_EFFECT := ["", "", "+25% HP · +25% DMG", "+55% HP · +55% DMG"]
const RES_PRICE := 300
const RES_TIME := 30.0
const BOUNTY := 30
const CLASSES := ["Warrior", "Archer", "Mage"]
const HINTS := ["front line", "long range", "splash"]
const ABILITY := ["Shockwave", "Called Shot", "Meteor"]
const ABILITY_NUMS := ["15 · 2.5 m · 10 s", "70 · 12 s", "60 · 4.0 m · 15 s"]
const ROMAN := ["", "I", "II", "III"]

const INK := Color(0.88, 0.90, 0.92)
const MUTED := Color(0.60, 0.63, 0.66)
const DIM := Color(0.30, 0.32, 0.34)
const WARN := Color(0.96, 0.46, 0.40)
const ACCENT := Color(0.92, 0.78, 0.36)
const BLUE := Color(0.28, 0.55, 0.95)
const RED := Color(0.85, 0.25, 0.22)
const BG := Color(0.04, 0.05, 0.06, 0.78)

var fight: Node
var layer: CanvasLayer
var strip: PanelContainer
var strip_body: VBoxContainer
var menu: PanelContainer
var cell_boxes := {}
var clusters := {}
var rows: Array = []
var transient_lbl: Label
var dbg_lbl: Label

# ---------------------------------------------------------------- state
var fit := "B"
var menu_open := true
var gold := START_GOLD
var clock := START_CLOCK
var income := 40
var income_at := 210.0
var queue := [0, 0, 0]
var levels := [1, 1, 1]
var researched := [false, true, false]      # Archer owned, so OWNED shows on open
var build_cls := -1                     # -1 = slot idle
var build_lv := 0
var build_research := false
var build_left := 0.0
var build_total := 1.0
var e_levels := [2, 2, 1]
var e_researched := [false, false, true]
var e_build_name := "Archer II"
var e_build_left := 12.0
var e_build_total := 20.0
var clicks := 0
var frozen := false
var last_action := "—"
var transient_left := 0.0
var tick_left := 0.0
var tick_sum := 0
var pulse_cd := 0.0
var prev_enemy := 0
var prev_own_base := 10000.0

# ---------------------------------------------------------------- widgets
var w_own_bar: Control
var w_own_fill: ColorRect
var w_own_pct: Label
var w_own_frame: Control
var l_gold: Label
var l_tick: Label
var l_own_army: Label
var l_own_build: Label
var pb_own_build: ProgressBar
var l_clock: Label
var l_e_army: Label
var l_e_levels: Label
var l_e_build: Label
var pb_e_build: ProgressBar
var w_e_bar: Control
var w_e_fill: ColorRect
var w_e_pct: Label
var w_e_frame: Control
var rec: Array = []
var up := {}
var res: Array = []

# ---------------------------------------------------------------- run flags
var shot_frames := 0
var shot_at := -1.0
var shot_path := "res://prototype/base_menu/shots/shot.png"
var measure_queue: Array = []


func _ready() -> void:
	_parse_args()
	_add_fight()
	_fit_window()
	_build_hud()
	_apply_fit()
	_refresh()
	prev_enemy = _alive(0)
	print("PROTOTYPE #17 base menu wireframe — F1/F2/F3 strip fit, B menu, Esc close, 1/2/3 recruit, R clash, T +60 s")
	if shot_frames > 0:
		return
	_measure_all()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fit="):
			fit = arg.substr(6, 1)
		elif arg == "--menu=0":
			menu_open = false
		elif arg == "--shot":
			shot_frames = 4000
			shot_at = 24.0
			Engine.time_scale = 8.0               # a clash in the still, not a march
		elif arg.begins_with("--shot-path="):
			shot_path = arg.substr(12)
		elif arg == "--gold=1000":
			gold = 1000
		elif arg == "--freeze":
			frozen = true
		elif arg == "--busy":
			build_cls = 0
			build_lv = 2
			build_left = 12.4
			build_total = 20.0
		elif arg == "--clock=750":
			clock = 750.0
			income = 80


func _add_fight() -> void:
	fight = FIGHT_SCENE.instantiate()
	add_child(fight)
	for c in fight.get_children():
		if c is CanvasLayer:
			c.visible = false                    # #16's debug dashboard
	prev_own_base = fight.bases[PLAYER].hp
	income_at = floor(clock / 10.0) * 10.0 + 10.0


func _fit_window() -> void:
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	if DisplayServer.get_name() != "headless":
		win.size = Vector2i(1920, 1080)
		win.position = Vector2i(0, 0)


# ---------------------------------------------------------------- input
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			_set_fit("A")
		KEY_F2:
			_set_fit("B")
		KEY_F3:
			_set_fit("C")
		KEY_B:
			menu_open = not menu_open
			menu.visible = menu_open
		KEY_ESCAPE:
			menu_open = false
			menu.visible = false
		KEY_1:
			_recruit(0)
			get_viewport().set_input_as_handled()
		KEY_2:
			_recruit(1)
			get_viewport().set_input_as_handled()
		KEY_3:
			_recruit(2)
			get_viewport().set_input_as_handled()
		KEY_R:
			fight._reset()
		KEY_T:
			clock += 60.0
		KEY_F5:
			gold += 1000
		KEY_F12:
			_save_shot()
		_:
			return
	_refresh()


func _set_fit(f: String) -> void:
	fit = f
	_apply_fit()
	_refresh()


# ---------------------------------------------------------------- mock sim
func _alive(team: int) -> int:
	var n := 0
	for u in fight.units:
		if not u.dead and u.team == team:
			n += 1
	return n


func _slot_idle() -> bool:
	return build_cls == -1


func _next_step() -> String:
	if clock < 240.0:
		return "next +60 at 4:00"
	if clock < 480.0:
		return "next +80 at 8:00"
	return ""


func _recruit(c: int) -> void:
	clicks += 1
	last_action = "Recruit " + CLASSES[c]
	if gold < GOLD_RECRUIT:
		return
	gold -= GOLD_RECRUIT
	if _alive(PLAYER) < CAP:
		fight._spawn(PLAYER, c)
	else:
		queue[c] += 1


func _buy_upgrade(c: int, lv: int) -> void:
	clicks += 1
	last_action = "Upgrade " + CLASSES[c] + " " + ROMAN[lv]
	if levels[c] + 1 != lv or not _slot_idle() or gold < UP_PRICE[lv]:
		return
	gold -= UP_PRICE[lv]
	build_cls = c
	build_lv = lv
	build_research = false
	build_total = UP_TIME[lv]
	build_left = build_total


func _buy_research(c: int) -> void:
	clicks += 1
	last_action = "Research " + ABILITY[c]
	if researched[c] or not _slot_idle() or gold < RES_PRICE:
		return
	gold -= RES_PRICE
	build_cls = c
	build_lv = 0
	build_research = true
	build_total = RES_TIME
	build_left = build_total


func _toast(text: String) -> void:
	transient_lbl.text = text
	transient_left = 3.0


func _process(delta: float) -> void:
	if shot_frames > 0:
		shot_frames -= 1
		if fight.time >= shot_at or shot_frames == 0:
			_save_shot()
			return
	if frozen:
		_refresh()
		return
	clock += delta

	while clock >= income_at:
		income_at += 10.0
		gold += income
		tick_sum += income
		tick_left = 1.0
	if clock >= 240.0 and income == 40:
		income = 60
		_toast("income +60")
	elif clock >= 480.0 and income == 60:
		income = 80
		_toast("income +80")
	if clock >= 720.0 and transient_left <= 0.0 and not transient_lbl.text == "SUDDEN DEATH":
		_toast("SUDDEN DEATH")

	if not _slot_idle():
		build_left -= delta
		if build_left <= 0.0:
			if build_research:
				researched[build_cls] = true
				_toast(ABILITY[build_cls] + " researched")
			else:
				levels[build_cls] = build_lv
				_toast(CLASSES[build_cls] + " " + ROMAN[build_lv] + " complete")
			build_cls = -1

	if e_build_name != "":
		e_build_left -= delta
		if e_build_left <= 0.0:
			e_levels[1] = maxi(e_levels[1], 3)
			e_build_name = ""

	# a clash slot freed: queued units enter play
	var alive := _alive(PLAYER)
	for c in 3:
		if alive < CAP and queue[c] > 0:
			queue[c] -= 1
			fight._spawn(PLAYER, c)
			alive += 1

	# bounty on enemy deaths, aggregated into one tick (#14)
	var enemy := _alive(0)
	if enemy < prev_enemy:
		var k := (prev_enemy - enemy) * BOUNTY
		gold += k
		tick_sum += k
		tick_left = 1.0
	prev_enemy = enemy

	# own Base under attack: pulse the bar, at most once per 2 s
	var own_base: float = fight.bases[PLAYER].hp
	if own_base < prev_own_base and pulse_cd <= 0.0:
		pulse_cd = 2.0
	prev_own_base = own_base

	tick_left = maxf(0.0, tick_left - delta)
	pulse_cd = maxf(0.0, pulse_cd - delta)
	if transient_left > 0.0:
		transient_left -= delta
		transient_lbl.modulate.a = clampf(transient_left, 0.0, 1.0)
	else:
		transient_lbl.text = ""

	_refresh()


# ---------------------------------------------------------------- HUD build
func _box(key: String) -> StyleBoxFlat:
	if cell_boxes.has(key):
		return cell_boxes[key]
	var s := StyleBoxFlat.new()
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	match key:
		"band", "strip":
			s.bg_color = BG
			s.border_color = Color(1, 1, 1, 0.10)
			s.content_margin_left = 16
			s.content_margin_right = 16
			s.content_margin_top = 8
			s.content_margin_bottom = 8
		"bar_frame":
			s.bg_color = Color(0.10, 0.11, 0.12, 0.9)
			s.border_color = Color(1, 1, 1, 0.16)
			s.content_margin_left = 0
			s.content_margin_right = 0
			s.content_margin_top = 0
			s.content_margin_bottom = 0
		"afford":
			s.bg_color = BG
			s.border_color = Color(0.55, 0.58, 0.62)
		"busy":
			s.bg_color = Color(0.02, 0.03, 0.04, 0.78)
			s.border_color = Color(0.20, 0.21, 0.23)
		"building":
			s.bg_color = BG
			s.border_color = ACCENT
		"owned":
			s.bg_color = Color(0.10, 0.11, 0.13, 0.78)
			s.border_color = Color(0.22, 0.23, 0.25)
		"flash":
			s.bg_color = BG
			s.border_color = ACCENT
		"cell":
			s.bg_color = BG
			s.border_color = DIM
		"bar_bg":
			s.bg_color = Color(0.10, 0.11, 0.12, 0.9)
			s.border_color = Color(0, 0, 0, 0)
			s.set_border_width_all(0)
		"bar_fill":
			s.bg_color = BLUE
			s.border_color = Color(0, 0, 0, 0)
			s.set_border_width_all(0)
			s.content_margin_top = 2
			s.content_margin_bottom = 2
			s.content_margin_left = 0
			s.content_margin_right = 0
		"pb_bg":
			s.bg_color = Color(1, 1, 1, 0.10)
			s.border_color = Color(0, 0, 0, 0)
			s.set_border_width_all(0)
			s.content_margin_top = 2
			s.content_margin_bottom = 2
			s.content_margin_left = 0
			s.content_margin_right = 0
		"pb_fill":
			s.bg_color = ACCENT
			s.border_color = Color(0, 0, 0, 0)
			s.set_border_width_all(0)
			s.content_margin_top = 2
			s.content_margin_bottom = 2
			s.content_margin_left = 0
			s.content_margin_right = 0
		_:
			s.bg_color = BG
			s.border_color = DIM
	cell_boxes[key] = s
	return s


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return l


func _clickable(on_click: Callable) -> Array:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box("cell"))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on_click.call()
			_refresh())
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	p.add_child(v)
	return [p, v]


func _hex_w() -> float:
	return get_viewport().get_visible_rect().size.x


func _build_hud() -> void:
	layer = CanvasLayer.new()
	add_child(layer)

	# the one transient line, drawn in the lane band above the bottom third
	transient_lbl = _label("", FONT, INK)
	transient_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	transient_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	transient_lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	transient_lbl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	transient_lbl.offset_bottom = -BOTTOM_H - 8.0
	layer.add_child(transient_lbl)

	_build_strip()
	_build_menu()
	_build_debug()


func _build_strip() -> void:
	strip = PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _box("strip"))
	strip.anchor_left = 0.0
	strip.anchor_right = 1.0
	strip.anchor_top = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_left = 0.0
	strip.offset_right = 0.0
	strip.offset_bottom = 0.0
	strip.offset_top = -STRIP_H
	strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(strip)

	strip_body = VBoxContainer.new()
	strip_body.add_theme_constant_override("separation", 6)
	strip.add_child(strip_body)

	# --- own Base HP
	var hp := _hcluster()
	clusters["own_hp"] = hp
	w_own_frame = PanelContainer.new()
	w_own_frame.add_theme_stylebox_override("panel", _box("bar_frame"))
	w_own_frame.custom_minimum_size = Vector2(232, 18)
	var fill_box := Control.new()
	fill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w_own_frame.add_child(fill_box)
	w_own_fill = ColorRect.new()
	w_own_fill.color = BLUE
	w_own_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	w_own_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill_box.add_child(w_own_fill)
	hp.add_child(w_own_frame)
	w_own_pct = _label("100%", FONT, INK)
	w_own_pct.custom_minimum_size = Vector2(52, 0)
	hp.add_child(w_own_pct)

	# --- own gold + income + tick
	var g := _hcluster()
	clusters["own_gold"] = g
	l_gold = _label("", FONT, INK)
	g.add_child(l_gold)
	l_tick = _label("", FONT, ACCENT)
	g.add_child(l_tick)

	# --- own army
	var a := _hcluster()
	clusters["own_army"] = a
	l_own_army = _label("", FONT, INK)
	a.add_child(l_own_army)

	# --- own build slot
	var b := _vcluster()
	clusters["own_build"] = b
	l_own_build = _label("", FONT, INK)
	b.add_child(l_own_build)
	pb_own_build = _progress(150)
	b.add_child(pb_own_build)

	# --- three recruit buttons
	var r := _hcluster()
	r.add_theme_constant_override("separation", 8)
	clusters["recruits"] = r
	for c in 3:
		var pair := _clickable(func() -> void: _recruit(c))
		var p: PanelContainer = pair[0]
		var v: VBoxContainer = pair[1]
		p.custom_minimum_size = Vector2(150, 0)
		var l1 := _label(CLASSES[c] + " · 100 · " + str(c + 1), FONT, INK)
		var l2 := _label(HINTS[c], FONT, MUTED)
		v.add_child(l1)
		v.add_child(l2)
		r.add_child(p)
		rec.append({"panel": p, "l1": l1, "l2": l2})

	# --- clock
	var k := _vcluster()
	clusters["clock"] = k
	l_clock = _label("00:00", 26, INK)
	l_clock.custom_minimum_size = Vector2(170, 0)
	l_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	k.add_child(l_clock)

	# --- enemy army / levels / build
	var ea := _hcluster()
	clusters["e_army"] = ea
	l_e_army = _label("", FONT, INK)
	ea.add_child(l_e_army)

	var el := _vcluster()
	clusters["e_levels"] = el
	l_e_levels = _label("", FONT, INK)
	el.add_child(l_e_levels)

	var eb := _vcluster()
	clusters["e_build"] = eb
	l_e_build = _label("", FONT, INK)
	eb.add_child(l_e_build)
	pb_e_build = _progress(150)
	eb.add_child(pb_e_build)

	# --- enemy Base HP (mirrored)
	var ehp := _hcluster()
	clusters["e_hp"] = ehp
	w_e_pct = _label("100%", FONT, INK)
	w_e_pct.custom_minimum_size = Vector2(52, 0)
	w_e_pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ehp.add_child(w_e_pct)
	w_e_frame = PanelContainer.new()
	w_e_frame.add_theme_stylebox_override("panel", _box("bar_frame"))
	w_e_frame.custom_minimum_size = Vector2(232, 18)
	var efill_box := Control.new()
	efill_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w_e_frame.add_child(efill_box)
	w_e_fill = ColorRect.new()
	w_e_fill.color = RED
	w_e_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	w_e_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	efill_box.add_child(w_e_fill)
	ehp.add_child(w_e_frame)


func _hcluster() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return h


func _vcluster() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return v


func _progress(w: float) -> ProgressBar:
	var p := ProgressBar.new()
	p.max_value = 1.0
	p.value = 0.0
	p.show_percentage = false
	p.custom_minimum_size = Vector2(w, 4)
	p.add_theme_stylebox_override("background", _box("pb_bg"))
	p.add_theme_stylebox_override("fill", _box("pb_fill"))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.custom_minimum_size = Vector2(12, 0)
	return c


func _vline() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(1, 1, 1, 0.10)
	c.custom_minimum_size = Vector2(1, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


# ---------------------------------------------------------------- strip fits
const FITS := {
	"A": [["own_hp", "own_gold", "own_army", "own_build", "recruits", "clock", "e_army", "e_levels", "e_build", "e_hp"]],
	"B": [["own_hp", "*", "clock", "*", "e_hp"], ["own_gold", "own_army", "own_build", "recruits", "*", "e_army", "e_levels", "e_build"]],
	"C": [["recruits"], ["own_hp", "own_gold", "own_army", "own_build", "*", "clock", "*", "e_army", "e_levels", "e_build", "e_hp"]],
}


func _apply_fit() -> void:
	for c in clusters.values():
		if c.get_parent() != null:
			c.get_parent().remove_child(c)
	for child in strip_body.get_children():
		strip_body.remove_child(child)
		child.queue_free()
	rows.clear()

	var extra := RECRUIT_ROW if fit == "C" else 0.0
	strip.offset_top = -(STRIP_H + extra)
	menu.offset_bottom = -(STRIP_H + extra + 8.0)

	for i in FITS[fit].size():
		var spec: Array = FITS[fit][i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if fit == "C" and i == 0:
			row.custom_minimum_size = Vector2(0, RECRUIT_ROW)
		else:
			row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		strip_body.add_child(row)
		rows.append(row)
		for j in spec.size():
			var name: String = spec[j]
			if name == "*":
				row.add_child(_spacer())
				continue
			if j > 0 and spec[j - 1] != "*":
				row.add_child(_vline())
			row.add_child(clusters[name])


func _measure_all() -> void:
	# worst case, not the demo state: four-digit gold, a full army with a queue,
	# a long build name and a progress bar in both the strip and the menu
	var s_gold := gold
	var s_queue := queue.duplicate()
	var s_build := [build_cls, build_lv, build_research, build_left, build_total]
	gold = 4321
	queue = [4, 4, 4]
	build_cls = 1
	build_lv = 3
	build_research = false
	build_left = 39.4
	build_total = 40.0
	var lines: Array = []
	for f in ["A", "B", "C"]:
		fit = f
		_apply_fit()
		await get_tree().process_frame
		await get_tree().process_frame
		var need := 0.0
		for r in rows:
			need = maxf(need, r.get_combined_minimum_size().x)
		lines.append("fit %s: strip needs %.0f px of %.0f%s" % [f, need, _hex_w(), "" if need <= _hex_w() else "  OVER"])
	fit = "B"
	_apply_fit()
	await get_tree().process_frame
	await get_tree().process_frame
	var menu_h := menu.size.y
	for l in lines:
		print(l)
	print("menu content %.0f px of %.0f budget (%s)" % [menu_h, MENU_H, "fits" if menu_h <= MENU_H else "OVER"])
	gold = s_gold
	queue = s_queue
	build_cls = s_build[0]
	build_lv = s_build[1]
	build_research = s_build[2]
	build_left = s_build[3]
	build_total = s_build[4]
	_refresh()


# ---------------------------------------------------------------- menu
func _build_menu() -> void:
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", _box("band"))
	menu.anchor_left = 0.0
	menu.anchor_right = 1.0
	menu.anchor_top = 1.0
	menu.anchor_bottom = 1.0
	menu.offset_left = 0.0
	menu.offset_right = 0.0
	menu.offset_bottom = -(STRIP_H + 8.0)
	menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	menu.clip_contents = true
	menu.mouse_filter = Control.MOUSE_FILTER_STOP
	menu.visible = menu_open
	layer.add_child(menu)

	var body := HBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 20)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(body)

	var up_pane := VBoxContainer.new()
	up_pane.add_theme_constant_override("separation", 6)
	up_pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(up_pane)
	up_pane.add_child(_label("UPGRADE", FONT, MUTED))

	for c in 3:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		up_pane.add_child(r)
		var name_lbl := _label(CLASSES[c], FONT, INK)
		name_lbl.custom_minimum_size = Vector2(96, 0)
		r.add_child(name_lbl)
		var marker := PanelContainer.new()
		marker.add_theme_stylebox_override("panel", _box("owned"))
		marker.custom_minimum_size = Vector2(34, 0)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ml := _label("I", FONT, MUTED)
		ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		marker.add_child(ml)
		r.add_child(marker)
		for lv in [2, 3]:
			up["%d/%d" % [c, lv]] = _up_cell(c, lv)
			r.add_child(up["%d/%d" % [c, lv]]["panel"])

	body.add_child(_vline())

	var res_pane := VBoxContainer.new()
	res_pane.add_theme_constant_override("separation", 6)
	res_pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(res_pane)
	res_pane.add_child(_label("RESEARCH", FONT, MUTED))
	for c in 3:
		res.append(_res_cell(c))
		res_pane.add_child(res[c]["panel"])


func _up_cell(c: int, lv: int) -> Dictionary:
	var pair := _clickable(func() -> void: _buy_upgrade(c, lv))
	var p: PanelContainer = pair[0]
	var v: VBoxContainer = pair[1]
	p.custom_minimum_size = Vector2(210, 0)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 0)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l1 := _label(ROMAN[lv] + " — ", FONT, INK)
	var l1b := _label("%d · %d s" % [UP_PRICE[lv], int(UP_TIME[lv])], FONT, INK)
	head.add_child(l1)
	head.add_child(l1b)
	var l2 := _label(UP_EFFECT[lv], FONT, MUTED)
	l2.add_theme_font_size_override("font_size", FONT)
	var pb := _progress(150)
	pb.visible = false
	v.add_child(head)
	v.add_child(l2)
	v.add_child(pb)
	return {"panel": p, "l1": l1, "l1b": l1b, "l2": l2, "pb": pb}


func _res_cell(c: int) -> Dictionary:
	var pair := _clickable(func() -> void: _buy_research(c))
	var p: PanelContainer = pair[0]
	var v: VBoxContainer = pair[1]
	p.custom_minimum_size = Vector2(430, 0)
	var l1 := _label(CLASSES[c] + " · " + ABILITY[c] + " — " + ABILITY_NUMS[c], FONT, INK)
	var l2 := _label("", FONT, INK)
	var pb := _progress(150)
	pb.visible = false
	v.add_child(l1)
	v.add_child(l2)
	v.add_child(pb)
	return {"panel": p, "l1": l1, "l2": l2, "pb": pb}


func _build_debug() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box("band"))
	p.anchor_left = 0.0
	p.anchor_right = 0.0
	p.anchor_top = 0.0
	p.anchor_bottom = 0.0
	p.offset_left = 12.0
	p.offset_top = 12.0
	p.grow_horizontal = Control.GROW_DIRECTION_END
	p.grow_vertical = Control.GROW_DIRECTION_END
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(p)
	dbg_lbl = _label("", 14, MUTED)
	p.add_child(dbg_lbl)


# ---------------------------------------------------------------- refresh
func _money(n: int) -> String:
	var s := str(n)
	var out := ""
	var cnt := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		cnt += 1
		if cnt % 3 == 0 and i > 0:
			out = "," + out
	return out


func _clock_text() -> String:
	var t := int(clock)
	if t >= 720:
		return "SUDDEN DEATH"
	return "%02d:%02d" % [t / 60, t % 60]


func _set_cell(key: String, border: String, l1: String, l1_col: Color, l1b: String, l1b_col: Color, l2: String, l2_col: Color, frac := -1.0) -> void:
	var d: Dictionary = up[key]
	var panel: PanelContainer = d["panel"]
	panel.add_theme_stylebox_override("panel", _box(border))
	(d["l1"] as Label).text = l1
	(d["l1"] as Label).add_theme_color_override("font_color", l1_col)
	(d["l1b"] as Label).text = l1b
	(d["l1b"] as Label).add_theme_color_override("font_color", l1b_col)
	(d["l2"] as Label).text = l2
	(d["l2"] as Label).add_theme_color_override("font_color", l2_col)
	var pb: ProgressBar = d["pb"]
	pb.visible = frac >= 0.0
	if pb.visible:
		pb.value = frac


func _refresh() -> void:
	if strip == null:
		return
	# --- bases
	var own_hp: float = fight.bases[PLAYER].hp
	var e_hp: float = fight.bases[0].hp
	var own_pct := clampf(own_hp / 100.0, 0.0, 100.0)
	w_own_fill.anchor_right = own_pct / 100.0
	w_own_pct.text = "%d%%" % int(round(own_pct))
	w_e_fill.anchor_right = clampf(e_hp / 100.0, 0.0, 1.0)
	w_e_pct.text = "%d%%" % int(round(clampf(e_hp / 100.0, 0.0, 100.0)))
	w_own_frame.add_theme_stylebox_override("panel", _box("busy" if pulse_cd > 1.6 else "bar_frame"))

	# --- own reads
	var step := _next_step()
	l_gold.text = "%s gold · +%d per 10 s%s" % [_money(gold), income, (" · " + step) if step != "" else ""]
	l_tick.text = ("+%d" % tick_sum) if tick_left > 0.0 else ""
	l_own_army.text = "%d / %d%s" % [_alive(PLAYER), CAP, (" · %d queued" % (queue[0] + queue[1] + queue[2])) if queue[0] + queue[1] + queue[2] > 0 else ""]
	if _slot_idle():
		l_own_build.text = "idle"
		pb_own_build.visible = false
	else:
		var what: String = ("Research " + ABILITY[build_cls]) if build_research else (CLASSES[build_cls] + " " + ROMAN[build_lv])
		l_own_build.text = "%s · %d s" % [what, int(ceil(maxf(build_left, 0.0)))]
		pb_own_build.visible = true
		pb_own_build.value = 1.0 - clampf(build_left / build_total, 0.0, 1.0)

	l_clock.text = _clock_text()
	l_clock.add_theme_color_override("font_color", WARN if clock >= 720.0 else INK)

	# --- enemy reads
	l_e_army.text = "%d / %d" % [_alive(0), CAP]
	var lv_txt := "W %s · A %s · M %s" % [
		ROMAN[e_levels[0]] + ("+" if e_researched[0] else ""),
		ROMAN[e_levels[1]] + ("+" if e_researched[1] else ""),
		ROMAN[e_levels[2]] + ("+" if e_researched[2] else ""),
	]
	l_e_levels.text = lv_txt
	if e_build_name == "":
		l_e_build.text = "idle"
		pb_e_build.visible = false
	else:
		l_e_build.text = "building %s · %d s" % [e_build_name, int(ceil(maxf(e_build_left, 0.0)))]
		pb_e_build.visible = true
		pb_e_build.value = 1.0 - clampf(e_build_left / e_build_total, 0.0, 1.0)

	# --- recruit buttons
	var at_cap := _alive(PLAYER) >= CAP
	var flash := at_cap and Engine.get_process_frames() / 24 % 2 == 0
	for c in 3:
		var d: Dictionary = rec[c]
		var panel: PanelContainer = d["panel"]
		var afford := gold >= GOLD_RECRUIT
		var border := "afford" if afford else "busy"
		if at_cap:
			border = "flash" if flash else "afford"
		panel.add_theme_stylebox_override("panel", _box(border))
		(d["l1"] as Label).add_theme_color_override("font_color", INK if afford else MUTED)
		(d["l1"] as Label).text = _money(GOLD_RECRUIT).replace("100", "100")
		(d["l1"] as Label).text = CLASSES[c] + " · 100 · " + str(c + 1)
		if not afford:
			(d["l2"] as Label).text = "need %d g" % (GOLD_RECRUIT - gold)
			(d["l2"] as Label).add_theme_color_override("font_color", WARN)
		elif at_cap:
			(d["l2"] as Label).text = HINTS[c] + ((" · ×%d" % queue[c]) if queue[c] > 0 else "")
			(d["l2"] as Label).add_theme_color_override("font_color", ACCENT if queue[c] > 0 else MUTED)
		else:
			(d["l2"] as Label).text = HINTS[c]
			(d["l2"] as Label).add_theme_color_override("font_color", MUTED)

	# --- upgrade cells, six states
	for c in 3:
		for lv in [2, 3]:
			var key := "%d/%d" % [c, lv]
			var price: int = UP_PRICE[lv]
			var eff: String = UP_EFFECT[lv]
			var head: String = ROMAN[lv] + " — "
			var tail: String = "%d · %d s" % [price, int(UP_TIME[lv])]
			if levels[c] >= lv:
				if lv == 3:
					_set_cell(key, "owned", "MAX", MUTED, "", MUTED, "", MUTED)
				else:
					_set_cell(key, "owned", "II", INK, "", MUTED, "owned", MUTED)
			elif lv > levels[c] + 1:
				_set_cell(key, "busy", head, MUTED, tail, MUTED, "II first", MUTED)
			elif build_cls == c and build_lv == lv:
				_set_cell(key, "building", head, ACCENT, "building", ACCENT, "%d s" % int(ceil(maxf(build_left, 0.0))), ACCENT, 1.0 - clampf(build_left / build_total, 0.0, 1.0))
			elif not _slot_idle():
				_set_cell(key, "busy", head, MUTED, tail, MUTED, "slot busy", MUTED)
			elif gold < price:
				_set_cell(key, "busy", head, MUTED, tail, WARN, "need %d g" % (price - gold), WARN)
			else:
				_set_cell(key, "afford", head, INK, tail, INK, eff, MUTED)

	# --- research cells
	for c in 3:
		var d: Dictionary = res[c]
		var panel: PanelContainer = d["panel"]
		var l1: Label = d["l1"]
		var l2: Label = d["l2"]
		var pb: ProgressBar = d["pb"]
		pb.visible = false
		if researched[c]:
			panel.add_theme_stylebox_override("panel", _box("owned"))
			l1.add_theme_color_override("font_color", MUTED)
			l2.text = "OWNED"
			l2.add_theme_color_override("font_color", MUTED)
		elif build_research and build_cls == c:
			panel.add_theme_stylebox_override("panel", _box("building"))
			l1.add_theme_color_override("font_color", ACCENT)
			l2.text = "building · %d s" % int(ceil(maxf(build_left, 0.0)))
			l2.add_theme_color_override("font_color", ACCENT)
			pb.visible = true
			pb.value = 1.0 - clampf(build_left / build_total, 0.0, 1.0)
		elif not _slot_idle():
			panel.add_theme_stylebox_override("panel", _box("busy"))
			l1.add_theme_color_override("font_color", MUTED)
			l2.text = "slot busy"
			l2.add_theme_color_override("font_color", MUTED)
		elif gold < RES_PRICE:
			panel.add_theme_stylebox_override("panel", _box("busy"))
			l1.add_theme_color_override("font_color", MUTED)
			l2.text = "300 · 30 s · need %d g" % (RES_PRICE - gold)
			l2.add_theme_color_override("font_color", WARN)
		else:
			panel.add_theme_stylebox_override("panel", _box("afford"))
			l1.add_theme_color_override("font_color", INK)
			l2.text = "300 · 30 s"
			l2.add_theme_color_override("font_color", INK)

	# --- debug readout
	var need := 0.0
	for r in rows:
		need = maxf(need, r.get_combined_minimum_size().x)
	var bottom := STRIP_H + (RECRUIT_ROW if fit == "C" else 0.0) + (menu.size.y + 8.0 if menu_open else 0.0)
	dbg_lbl.text = "DEBUG  F1/F2/F3 strip fit · B menu · Esc close · 1/2/3 recruit · R clash · T +60 s · F5 +1000 g\n" \
		+ "fit %s · strip needs %.0f of %.0f px%s · menu %.0f of %.0f px%s · bottom third %.0f of %.0f px%s\n" \
		% [fit, need, _hex_w(), "" if need <= _hex_w() else "  OVER",
			menu.size.y, MENU_H, "" if menu.size.y <= MENU_H else "  OVER",
			bottom, BOTTOM_H, "" if bottom <= BOTTOM_H else "  OVER"] \
		+ "clicks %d · last %s · gold %d · queue %d" % [clicks, last_action, gold, queue[0] + queue[1] + queue[2]]


func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://prototype/base_menu/shots"))
	img.save_png(ProjectSettings.globalize_path(shot_path))
	print("shot %s %dx%d" % [shot_path, img.get_width(), img.get_height()])
	get_tree().quit()

extends Node2D
## Fishy (XGen Studios, 2003) remade in Godot.
##
## The game rules are a line-by-line port of the original ActionScript 2
## (frame 15 setup, the two-frame "walk" loop in sprite 189, and the button
## handlers). All art is the original vector art, baked to sprite sheets by
## tools/bake_assets.py. Everything runs at the original 30 frames per second
## in _physics_process, on a 550x400 stage in the original coordinates.

enum Screen { INTRO, TITLE, INSTRUCTIONS, GAME, GULP, AGAIN, SCORES, WIN }

const Atlas = preload("res://scripts/atlas_data.gd")
const Data = preload("res://scripts/stage_data.gd")

const STAGE_W := 550.0
const STAGE_H := 400.0
const SAVE_PATH := "user://fishy.cfg"
const MAX_SCORES := 10
const JOY_DEADZONE := 10.0
const BUTTON_PAD := 8.0

# Title letters "! F I S H Y !" inside sprite 166 at (282.4, 74.45).
const TITLE_ORIGIN := Vector2(282.4, 74.45)

# Button hit rectangles in stage coordinates (from the SWF hit-test states).
const BTN := {
	"title_play": Rect2(249.9, 202.0, 53.0, 20.0),
	"title_instructions": Rect2(191.2, 235.2, 170.4, 21.6),
	"title_scores": Rect2(205.1, 266.3, 149.0, 22.0),
	"instr_back": Rect2(242.4, 376.8, 50.4, 20.0),
	"gulp_ok": Rect2(273.0, 265.0, 36.0, 21.0),
	"again_play": Rect2(220.9, 150.1, 126.0, 20.0),
	"again_scores": Rect2(210.0, 190.1, 149.0, 22.0),
	"scores_ok": Rect2(272.8, 366.1, 36.0, 21.0),
	"win_play": Rect2(220.9, 240.1, 126.0, 20.0),
	"win_scores": Rect2(210.0, 280.1, 149.0, 22.0),
	"game_quality": Rect2(8.0, 368.7, 25.8, 25.8),
	"game_sound": Rect2(46.0, 368.0, 27.0, 27.0),
}

var screen: int = Screen.INTRO
var tick := 0

# Original game variables (frame 15 script).
var score := 0
var deadfish := 0
var xmove := 0.0
var ymove := 0.0
var swimspeed := 0.25
var f_swimming := 0
var f_size := 15.0
var fishsize: Array = []
var fishspeed: Array = []
var sound_on := true
var high_quality := true

var held_left := false
var held_right := false
var held_up := false
var held_down := false
var joy_touch := -1
var joy_origin := Vector2.ZERO
var joy_pos := Vector2.ZERO

var scores: Array = []

var backdrop: Node2D
var clip: Control
var stage: Node2D
var bg: Sprite2D
var sand_menu: Sprite2D
var sand_game: Sprite2D
var win_bg: Sprite2D
var side_nodes: Array = []
var back_plants: Array = []
var front_plants: Array = []
var enemies: Array = []
var player: Sprite2D
var player_frame := 0
var bubbles: Array = []
var pbones: Array = []
var bones: Array = []
var bbones: Array = []
var sound_btn: Sprite2D
var quality_btn: Sprite2D
var score_light: Label
var score_dark: Label
var overlays := {}
var letters: Array = []
var soul: Sprite2D
var soul_frame := 0
var name_edit: LineEdit
var score_rows: Array = []
var intro_text: Sprite2D
var intro_x: Sprite2D
var squares: Array = []
var joy_ring: Node2D

var music: AudioStreamPlayer
var sfx_eat: AudioStreamPlayer
var sfx_splash: AudioStreamPlayer
var sfx_sploosh: AudioStreamPlayer
var sfx_intro: AudioStreamPlayer

var font_comic: FontFile
var font_black: FontFile


func _ready() -> void:
	randomize()
	_load_save()
	_load_fonts()
	_build_audio()
	_build_scene()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_go(Screen.INTRO)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--shots")
	if at >= 0 and at + 1 < args.size():
		var driver: Node = load("res://scripts/shots.gd").new()
		add_child(driver)
		driver.start(self, args[at + 1])


# ---------------------------------------------------------------- building


func _load_fonts() -> void:
	font_black = load("res://assets/fonts/arialblack.ttf")
	font_black.multichannel_signed_distance_field = true
	font_comic = load("res://assets/fonts/comic.ttf")
	font_comic.multichannel_signed_distance_field = true
	# The embedded Comic Sans is a subset; fall back for missing glyphs.
	font_comic.fallbacks = [font_black]


func _player(path: String, loop := false) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var s: AudioStream = load(path)
	if loop and s is AudioStreamMP3:
		(s as AudioStreamMP3).loop = true
	p.stream = s
	add_child(p)
	return p


func _build_audio() -> void:
	music = _player("res://assets/sfx/koi.mp3", true)
	sfx_eat = _player("res://assets/sfx/eat.mp3")
	sfx_splash = _player("res://assets/sfx/splash.wav")
	sfx_sploosh = _player("res://assets/sfx/sploosh.mp3")
	sfx_intro = _player("res://assets/sfx/intro.mp3")


func _tex_path(sheet: String) -> String:
	var ext := "jpg" if sheet == "intro_x" else "png"
	return "res://assets/gfx/%s.%s" % [sheet, ext]


func _mk(sheet: String, parent: Node, pos: Vector2, sc := Vector2.ONE) -> Sprite2D:
	var m: Dictionary = Atlas.ATLAS[sheet]
	var s := Sprite2D.new()
	s.texture = load(_tex_path(sheet))
	s.centered = false
	s.hframes = m["cols"]
	s.vframes = m["rows"]
	s.offset = Vector2(m["ox"], m["oy"])
	s.set_meta("zoom", float(m["zoom"]))
	s.set_meta("frames", int(m["frames"]))
	s.position = pos
	_set_scale(s, sc)
	parent.add_child(s)
	return s


func _set_scale(s: Sprite2D, sc: Vector2) -> void:
	var z: float = s.get_meta("zoom")
	s.scale = sc / z


func _label(parent: Node, font: Font, size: int, col: Color, rect: Rect2) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.position = rect.position
	l.size = rect.size
	l.clip_text = false
	parent.add_child(l)
	return l


func _build_scene() -> void:
	# Mirrored copies of the backgrounds fill the extra width of wide phones.
	backdrop = Node2D.new()
	add_child(backdrop)
	for sheet in ["bg", "sand_menu", "sand_game", "win_bg"]:
		for dir in [-1, 1]:
			var s := _mk(sheet, backdrop, Vector2.ZERO, Vector2(-1, 1))
			s.set_meta("dir", dir)
			s.set_meta("sheet", sheet)
			side_nodes.append(s)

	clip = Control.new()
	clip.clip_contents = true
	clip.size = Vector2(STAGE_W, STAGE_H)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	stage = Node2D.new()
	clip.add_child(stage)

	bg = _mk("bg", stage, Vector2.ZERO)
	for p in Data.BACK_PLANTS:
		var s := _mk(p[0], stage, Vector2(p[1], p[2]), Vector2(p[3], p[4]))
		s.modulate = Color(1, 1, 1, p[5])
		back_plants.append(s)
	sand_menu = _mk("sand_menu", stage, Vector2.ZERO)
	sand_game = _mk("sand_game", stage, Vector2.ZERO)
	win_bg = _mk("win_bg", stage, Vector2.ZERO)

	for i in 10:
		enemies.append(_mk("enemy", stage, Vector2(-90, 0), Vector2(0.3, 0.3)))
	player = _mk("player", stage, Vector2(271.95, 7.1), Vector2(0.15, 0.15))
	sound_btn = _mk("sound", stage, Vector2(59.4, 381.1))
	quality_btn = _mk("quality", stage, Vector2(20.9, 381.6))
	for i in 3:
		var b := _mk("bubble", stage, Vector2(-144, 22 + 13 * i))
		b.modulate = Color(1, 1, 1, 0.5)
		bubbles.append(b)
	for p in Data.FRONT_PLANTS:
		front_plants.append(_mk(p[0], stage, Vector2(p[1], p[2]), Vector2(p[3], p[4])))

	for key in ["ov_title", "ov_instructions", "ov_gulp", "ov_again", "ov_scores", "ov_win"]:
		overlays[key] = _mk(key, stage, Vector2.ZERO)
	for i in Data.LETTERS.size():
		letters.append(_mk("letter_%d" % (i + 1), stage, TITLE_ORIGIN + Data.LETTERS[i]))

	soul = _mk("soul", stage, Vector2(282.35, 317.25), Vector2(-0.2, -0.2))
	soul.modulate = Color(1, 1, 1, 0.5)
	# The soul sits under the GULP text (depth 15 vs 17).
	stage.move_child(soul, stage.get_children().find(overlays["ov_gulp"]))

	_build_hud()
	_build_name_entry()
	_build_score_table()
	_build_intro()

	joy_ring = Node2D.new()
	joy_ring.draw.connect(_draw_joystick)
	stage.add_child(joy_ring)


func _build_hud() -> void:
	# Score: two Comic Sans 20 px fields, light blue under dark blue (depth 56/57).
	var r := Rect2(22.9, -2.0, 213.95, 32.0)
	score_light = _label(
		stage,
		font_comic,
		20,
		Color(45.0 / 255, 171.0 / 255, 1.0),
		Rect2(Vector2(156.2, 19.8) + r.position, r.size)
	)
	score_dark = _label(
		stage,
		font_comic,
		20,
		Color(0.0, 102.0 / 255, 153.0 / 255),
		Rect2(Vector2(154.7, 18.9) + r.position, r.size)
	)
	for l in [score_light, score_dark]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	for p in Data.PBONE_POS:
		pbones.append(_mk("pbone", stage, p, Vector2(1.0, 0.8)))
	for i in 4:
		bones.append(_mk("bone", stage, Vector2(15.85 + 27.0 * i, 43.55), Vector2(0.65, 0.65)))
		bbones.append(_mk("bone", stage, Vector2(18.25 + 31.5 * i, 29.4), Vector2(0.95, 0.95)))


func _build_name_entry() -> void:
	name_edit = LineEdit.new()
	name_edit.position = Vector2(151.95, 215.95)
	name_edit.size = Vector2(260.0, 31.9)
	name_edit.max_length = 12
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_font_override("font", font_comic)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.add_theme_color_override("font_color", Color(0, 0, 0))
	name_edit.add_theme_color_override("caret_color", Color(0, 0, 0))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1)
	box.border_color = Color(0, 0, 0)
	box.set_border_width_all(1)
	box.content_margin_left = 2
	box.content_margin_right = 2
	for state in ["normal", "focus", "read_only"]:
		name_edit.add_theme_stylebox_override(state, box)
	name_edit.text_submitted.connect(func(_t): _submit_name())
	clip.add_child(name_edit)


func _build_score_table() -> void:
	# hstext: Arial Black 20 px, #333333, box at (108.4, 73.7) 365 x 277.
	var grey := Color(0.2, 0.2, 0.2)
	for i in MAX_SCORES:
		var y := 80.0 + 26.5 * i
		var left := _label(stage, font_black, 17, grey, Rect2(118.0, y, 230.0, 26.0))
		var right := _label(stage, font_black, 17, grey, Rect2(300.0, y, 160.0, 26.0))
		right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_rows.append([left, right])


func _build_intro() -> void:
	intro_x = _mk("intro_x", stage, Vector2(277.1, 183.05), Vector2(0.25, 0.25))
	intro_text = _mk("intro_text", stage, Vector2(276.2, 198.85))
	for p in Data.SQUARE_POS:
		var sq := ColorRect.new()
		sq.size = Vector2(4, 4)
		sq.position = Vector2(-1.75, -2.2)
		var holder := Node2D.new()
		holder.position = p
		holder.add_child(sq)
		stage.add_child(holder)
		squares.append({"node": holder, "rect": sq})


func _layout() -> void:
	var vis := get_viewport_rect().size
	var origin := ((vis - Vector2(STAGE_W, STAGE_H)) * 0.5).floor()
	clip.position = origin
	for s in side_nodes:
		# A negative x scale mirrors about the node origin: x=0 or x=1100.
		var dir: int = s.get_meta("dir")
		s.position = origin + Vector2(STAGE_W * (dir + 1), 0)


# ------------------------------------------------------------------ screens


func _go(to: int) -> void:
	screen = to
	tick = 0
	for key in overlays:
		overlays[key].visible = false
	for l in letters:
		l.visible = false
	name_edit.visible = false
	name_edit.release_focus()
	_show_intro(false)
	_show_game_objects(false)
	_show_hud(false)
	_show_scores(false)
	soul.visible = false
	joy_touch = -1
	_clear_keys()
	var backdrop_sheet := "bg"
	var sand_sheet := "sand_menu"
	match to:
		Screen.INTRO:
			backdrop_sheet = ""
			sand_sheet = ""
			_show_intro(true)
			if sound_on:
				sfx_intro.play()
		Screen.TITLE:
			overlays["ov_title"].visible = true
			for l in letters:
				l.visible = true
				l.frame = 0
			_restart_plants()
		Screen.INSTRUCTIONS:
			overlays["ov_instructions"].visible = true
		Screen.GAME:
			sand_sheet = "sand_game"
			if sound_on:
				sfx_splash.play()
			_restart_plants()
			_start_game()
			_show_game_objects(true)
			_show_hud(true)
		Screen.GULP:
			sand_sheet = "sand_game"
			music.stop()
			if sound_on:
				sfx_sploosh.play()
			overlays["ov_gulp"].visible = true
			soul.visible = true
			soul_frame = 0
			_update_soul()
			name_edit.text = ""
			name_edit.visible = true
			_show_hud(true)
		Screen.AGAIN:
			sand_sheet = "sand_game"
			overlays["ov_again"].visible = true
			_show_hud(true)
		Screen.SCORES:
			sand_sheet = "sand_game"
			overlays["ov_scores"].visible = true
			_show_scores(true)
		Screen.WIN:
			backdrop_sheet = "win_bg"
			sand_sheet = ""
			music.stop()
			if sound_on:
				sfx_sploosh.play()
			overlays["ov_win"].visible = true
			_show_hud(true)
	var water := backdrop_sheet == "bg"
	bg.visible = water
	for p in back_plants:
		p.visible = water
	sand_menu.visible = sand_sheet == "sand_menu"
	sand_game.visible = sand_sheet == "sand_game"
	win_bg.visible = backdrop_sheet == "win_bg"
	for s in side_nodes:
		var sheet: String = s.get_meta("sheet")
		s.visible = sheet == backdrop_sheet or sheet == sand_sheet


func _show_intro(on: bool) -> void:
	intro_x.visible = on
	intro_text.visible = on
	for sq in squares:
		sq["node"].visible = on
	if on:
		intro_x.frame = 0
		intro_text.frame = 0
		for sq in squares:
			_init_square(sq)


func _show_game_objects(on: bool) -> void:
	for e in enemies:
		e.visible = on
	player.visible = on
	sound_btn.visible = on
	quality_btn.visible = on
	for b in bubbles:
		b.visible = on
	for p in front_plants:
		p.visible = on


func _show_hud(on: bool) -> void:
	score_light.visible = on
	score_dark.visible = on
	for b in pbones + bones + bbones:
		b.visible = on and b.get_meta("lit", false)


func _show_scores(on: bool) -> void:
	for i in score_rows.size():
		var row: Array = score_rows[i]
		row[0].visible = on
		row[1].visible = on
		if on:
			if i < scores.size():
				row[0].text = "%d. %s" % [i + 1, scores[i]["name"]]
				row[1].text = str(scores[i]["score"])
			else:
				row[0].text = "%d." % (i + 1)
				row[1].text = ""


func _restart_plants() -> void:
	# plant1..plant10.gotoAndPlay(random(160))
	for p in back_plants + front_plants:
		p.frame = (randi() % 160) % int(p.get_meta("frames"))


# --------------------------------------------------------------- game logic


func _randomize_fish(i: int) -> void:
	# Shared body of the frame 15 setup and the respawn in walk frame 1.
	fishsize[i] = randi() % 72 + 2
	fishspeed[i] = (randi() % 6 - 3) * 2
	if fishspeed[i] == 0:
		fishspeed[i] = 2
	var e: Sprite2D = enemies[i]
	var s: float = fishsize[i] / 100.0
	if fishspeed[i] > 0:
		e.position.x = -90
		_set_scale(e, Vector2(s, s))
	else:
		e.position.x = 640
		_set_scale(e, Vector2(-s, s))
	e.position.y = randi() % 400
	# Color.setTransform({ra: 255 - size*3.5, ga: 100, ba: size*3.5}), percents.
	e.modulate = Color((255.0 - fishsize[i] * 3.5) / 100.0, 1.0, fishsize[i] * 3.5 / 100.0)


func _start_game() -> void:
	deadfish = 0
	score = 0
	xmove = 0.0
	ymove = 7.0
	swimspeed = 1.0
	f_swimming = 0
	f_size = 15.0
	player.position = Vector2(271.95, 7.1)
	_set_scale(player, Vector2(f_size, f_size) / 100.0)
	player_frame = 0
	player.frame = 0
	fishsize.resize(10)
	fishspeed.resize(10)
	for i in 10:
		_randomize_fish(i)
		enemies[i].frame = 0
	var start := [Vector2(-143.55, 22.5), Vector2(-144.55, 36.5), Vector2(-143.55, 49.5)]
	for i in 3:
		bubbles[i].position = start[i]
		_set_scale(bubbles[i], Vector2.ONE)
	for b in pbones + bones + bbones:
		b.set_meta("lit", false)
	_update_score()
	sound_btn.frame = 0 if sound_on else 1


func _update_score() -> void:
	score_light.text = str(score)
	score_dark.text = str(score)


func _update_bones() -> void:
	for b in bones + bbones:
		b.set_meta("lit", false)
	var left := deadfish
	var b := 0
	while left >= 25:
		left -= 25
		if b < pbones.size():
			pbones[b].set_meta("lit", true)
		b += 1
	b = 0
	while left >= 5:
		left -= 5
		if b < bbones.size():
			bbones[b].set_meta("lit", true)
		b += 1
	b = 0
	while left >= 1:
		left -= 1
		if b < bones.size():
			bones[b].set_meta("lit", true)
		b += 1
	_show_hud(true)


func _face(dir: float) -> void:
	_set_scale(player, Vector2(f_size * dir, f_size) / 100.0)


func _game_tick() -> void:
	# The walk sprite alternates frame 1 (respawn) and frame 2 (collisions).
	var frame_one := tick % 2 == 0
	for i in 3:
		var b: Sprite2D = bubbles[i]
		if frame_one and b.position.y < -10:
			var xs: float = player.scale.x * player.get_meta("zoom") * 100.0
			b.position = Vector2(player.position.x + xs, player.position.y - 2 * i)
			_set_scale(b, Vector2(xs, f_size) / 100.0)
		b.position.y -= 2 + i / 4.0
	ymove *= 0.97
	xmove *= 0.97
	if frame_one:
		f_swimming = 0
		swimspeed = 0.25
	if held_left:
		_face(-1)
		xmove -= swimspeed
		if frame_one:
			f_swimming = 1
	elif held_right:
		_face(1)
		xmove += swimspeed
		if frame_one:
			f_swimming = 1
	if held_up:
		ymove -= swimspeed
		if frame_one:
			f_swimming = 1
	elif held_down:
		ymove += swimspeed
		if frame_one:
			f_swimming = 1
	player.position.x += xmove
	if player.position.x > 550:
		player.position.x = 0
	if player.position.x < 0:
		player.position.x = 550
	if player.position.y + ymove < 395 and player.position.y + ymove > 5:
		player.position.y += ymove
	else:
		ymove = 0
	for i in 10:
		var e: Sprite2D = enemies[i]
		e.position.x += fishspeed[i]
		if frame_one:
			if e.position.x > 650 or e.position.x < -100:
				_randomize_fish(i)
			continue
		var reach: float = f_size + fishsize[i]
		if absf(e.position.x - player.position.x) >= reach:
			continue
		if absf(e.position.y - player.position.y) >= reach / 3.0:
			continue
		if f_size > fishsize[i]:
			if sound_on:
				sfx_eat.play()
			player_frame = 6
			player.frame = 6
			e.position.x = 700
			f_size += fishsize[i] / 50.0
			_face(1)
			score += fishsize[i] * 6
			deadfish += 1
			_update_score()
			_update_bones()
			if f_size > 300:
				_go(Screen.WIN)
				return
		else:
			_go(Screen.GULP)
			return


func _animate_game() -> void:
	# Player sprite 179: frame 3 loops to 1 when idle, 6 loops to 1, 7-10 = gulp.
	var next := player_frame + 1
	if next >= 10:
		next = 0
	if next == 2 and f_swimming == 0:
		next = 0
	if next == 5:
		next = 0
	player_frame = next
	player.frame = player_frame
	for e in enemies:
		e.frame = (e.frame + 1) % 6


func _step_plants() -> void:
	for p in back_plants + front_plants:
		if p.visible:
			p.frame = (p.frame + 1) % int(p.get_meta("frames"))


func _update_soul() -> void:
	# Child shape 208 slides from y=-660 to y=520 over 71 frames, then stops.
	var y := -660.0 + (520.0 + 660.0) * soul_frame / 70.0
	soul.position = Vector2(282.35, 185.25 - 0.2 * y)


# -------------------------------------------------------------------- intro


func _init_square(sq: Dictionary) -> void:
	sq["xwalk"] = 0.0
	sq["ywalk"] = 0.0
	sq["xacc"] = (10 - (randi() % 2) * 20) * ((randi() % 20) / 100.0)
	sq["yacc"] = (10 - (randi() % 2) * 20) * ((randi() % 20) / 100.0)
	sq["pos"] = Vector2.ZERO
	sq["walk_frame"] = 0
	sq["twinkle"] = 0
	sq["rect"].position = Vector2(-1.75, -2.2)
	var c := Color(randi() % 255 / 100.0, randi() % 255 / 100.0, randi() % 255 / 100.0)
	sq["color"] = c
	sq["rect"].color = Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), 0.0)


func _step_square(sq: Dictionary) -> void:
	# Sprite 131: frame 2 runs every other frame (frame 3 jumps back to 2).
	sq["walk_frame"] += 1
	if sq["walk_frame"] % 2 == 1:
		var p: Vector2 = sq["pos"]
		p += Vector2(sq["xwalk"], sq["ywalk"])
		sq["xwalk"] += sq["xacc"]
		sq["ywalk"] += sq["yacc"]
		if sq["xwalk"] > 5:
			sq["xacc"] = -(randi() % 10) / 20.0
		if sq["xwalk"] < -5:
			sq["xacc"] = (randi() % 10) / 20.0
		if sq["ywalk"] > 5:
			sq["yacc"] = -(randi() % 10) / 20.0
		if sq["ywalk"] < -5:
			sq["yacc"] = (randi() % 10) / 20.0
		if p.x < -100:
			sq["xacc"] = 0.2
		if p.x > 100:
			sq["xacc"] = -0.2
		if p.y < -100:
			sq["yacc"] = 0.2
		if p.y > 100:
			sq["yacc"] = -0.2
		sq["pos"] = p
		sq["rect"].position = p + Vector2(-1.75, -2.2)
	# Sprite 130: twinkle over frames 1-30, then idle until frame 101.
	var t: int = sq["twinkle"]
	t += 1
	if t == 30:
		t = 30 + randi() % 70
	elif t >= 101:
		t = 1
	sq["twinkle"] = t
	var a: float = Data.TWINKLE[t] if t < 30 else 0.0
	var c: Color = sq["color"]
	sq["rect"].color = Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0), a)


func _intro_tick() -> void:
	intro_text.frame = mini(tick, 229)
	intro_x.frame = mini(tick, 218)
	for sq in squares:
		_step_square(sq)
	if tick >= 229:
		_go(Screen.TITLE)


# --------------------------------------------------------------------- loop


func _physics_process(_delta: float) -> void:
	match screen:
		Screen.INTRO:
			_intro_tick()
		Screen.TITLE:
			for l in letters:
				l.frame = (l.frame + 1) % int(l.get_meta("frames"))
			_step_plants()
		Screen.GAME:
			_step_plants()
			_animate_game()
			_game_tick()
		Screen.GULP:
			_step_plants()
			if soul_frame < 70:
				soul_frame += 1
				_update_soul()
		Screen.WIN:
			pass
		_:
			_step_plants()
	tick += 1
	joy_ring.queue_redraw()


# -------------------------------------------------------------------- input


func _clear_keys() -> void:
	held_left = false
	held_right = false
	held_up = false
	held_down = false


func _to_stage(p: Vector2) -> Vector2:
	return stage.get_global_transform_with_canvas().affine_inverse() * p


func _hit(key: String, p: Vector2) -> bool:
	return BTN[key].grow(BUTTON_PAD).has_point(p)


func _update_joystick() -> void:
	var d := joy_pos - joy_origin
	held_left = d.x < -JOY_DEADZONE
	held_right = d.x > JOY_DEADZONE
	held_up = d.y < -JOY_DEADZONE
	held_down = d.y > JOY_DEADZONE


func _draw_joystick() -> void:
	if screen != Screen.GAME or joy_touch < 0:
		return
	joy_ring.draw_arc(joy_origin, 28.0, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 2.0, true)
	var knob := joy_origin + (joy_pos - joy_origin).limit_length(28.0)
	joy_ring.draw_circle(knob, 9.0, Color(1, 1, 1, 0.25))


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_key(event)
		return
	if event is InputEventScreenTouch:
		var p := _to_stage(event.position)
		if event.pressed:
			_tap(p, event.index)
		elif event.index == joy_touch:
			joy_touch = -1
			_clear_keys()
	elif event is InputEventScreenDrag and event.index == joy_touch:
		joy_pos = _to_stage(event.position)
		_update_joystick()


func _key(event: InputEventKey) -> void:
	if screen == Screen.GAME:
		var on := event.pressed
		match event.keycode:
			KEY_LEFT:
				held_left = on
			KEY_RIGHT:
				held_right = on
			KEY_UP:
				held_up = on
			KEY_DOWN:
				held_down = on
	elif screen == Screen.INTRO and event.pressed:
		_go(Screen.TITLE)


func _tap(p: Vector2, index: int) -> void:
	match screen:
		Screen.INTRO:
			_go(Screen.TITLE)
		Screen.TITLE:
			if _hit("title_play", p):
				_play()
			elif _hit("title_instructions", p):
				_go(Screen.INSTRUCTIONS)
			elif _hit("title_scores", p):
				_go(Screen.SCORES)
		Screen.INSTRUCTIONS:
			if _hit("instr_back", p):
				_go(Screen.TITLE)
		Screen.GAME:
			if _hit("game_sound", p):
				_toggle_sound()
			elif _hit("game_quality", p):
				_toggle_quality()
			elif joy_touch < 0:
				joy_touch = index
				joy_origin = p
				joy_pos = p
				_update_joystick()
		Screen.GULP:
			if _hit("gulp_ok", p):
				_submit_name()
			elif not Rect2(name_edit.position, name_edit.size).has_point(p):
				name_edit.release_focus()
		Screen.AGAIN:
			if _hit("again_play", p):
				_play()
			elif _hit("again_scores", p):
				_go(Screen.SCORES)
		Screen.SCORES:
			if _hit("scores_ok", p):
				_go(Screen.TITLE)
		Screen.WIN:
			if _hit("win_play", p):
				_play()
			elif _hit("win_scores", p):
				_go(Screen.SCORES)


func _play() -> void:
	if sound_on:
		music.play()
	_go(Screen.GAME)


func _toggle_sound() -> void:
	sound_on = not sound_on
	if sound_on:
		music.play()
	else:
		music.stop()
	sound_btn.frame = 0 if sound_on else 1
	_save()


func _toggle_quality() -> void:
	high_quality = not high_quality
	if high_quality:
		clip.texture_filter = CanvasItem.TEXTURE_FILTER_PARENT_NODE
	else:
		clip.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _submit_name() -> void:
	if screen != Screen.GULP:
		return
	var who := name_edit.text.strip_edges().to_upper()
	if who.is_empty():
		who = "FISHY"
	scores.append({"name": who, "score": score})
	scores.sort_custom(func(a, b): return a["score"] > b["score"])
	if scores.size() > MAX_SCORES:
		scores.resize(MAX_SCORES)
	_save()
	_go(Screen.AGAIN)


# --------------------------------------------------------------------- save


func _load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	sound_on = cfg.get_value("prefs", "sound", true)
	scores = cfg.get_value("scores", "table", [])


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("prefs", "sound", sound_on)
	cfg.set_value("scores", "table", scores)
	cfg.save(SAVE_PATH)

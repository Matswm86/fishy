extends Node
## Test driver, active only when the game is launched with `-- --shots <dir>`.
## Walks every screen, holds keys during play and saves PNG screenshots.

var main: Node
var out_dir := ""


func start(owner_main: Node, dir: String) -> void:
	main = owner_main
	out_dir = dir
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s.png" % [out_dir, name])
	print("shot ", name)


func _wait(ticks: int) -> void:
	for i in ticks:
		await get_tree().physics_frame


func _run() -> void:
	await _wait(60)
	await _snap("01_intro")
	await _wait(175)
	await _snap("02_title")
	main._go(main.Screen.INSTRUCTIONS)
	await _wait(5)
	await _snap("03_instructions")
	main._play()
	await _wait(45)
	await _snap("04_game_start")
	main.held_right = true
	main.held_down = true
	await _wait(40)
	main.held_down = false
	await _wait(80)
	await _snap("05_game_swim")
	main.held_right = false
	main.f_size = 80.0
	main._face(1)
	main.deadfish = 33
	main.score = 4242
	main._update_score()
	main._update_bones()
	await _wait(30)
	await _snap("06_game_big")
	main._go(main.Screen.GULP)
	await _wait(35)
	await _snap("07_gulp")
	main.name_edit.text = "TESTER"
	main._submit_name()
	await _wait(5)
	await _snap("08_again")
	main._go(main.Screen.SCORES)
	await _wait(5)
	await _snap("09_scores")
	main._go(main.Screen.WIN)
	await _wait(5)
	await _snap("10_win")
	get_tree().quit()

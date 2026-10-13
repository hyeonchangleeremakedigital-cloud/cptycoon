extends Node2D
## Native Godot implementation of the HTML playable. No WebView or network.
signal sorted_item(kind: int, total: int)
signal shift_completed(total: int)

const INK = Color("29464d")
const CREAM = Color("fff8e7")
const COLORS = [Color("e6a85c"), Color("59ae8e"), Color("91b4d3")]
const DARKS = [Color("ac7449"), Color("347b6c"), Color("5b7f9e")]
const NAMES = ["A 박스", "B 프레시", "C 소포"]
const BIN_X = [60.0, 180.0, 300.0]
const WALK_RECT = Rect2(25, 281, 310, 89)
const SAVE_PATH = "user://progress.cfg"
var font: Font
var t := 0.0
var active := false
var paused_game := false
var finished := false
var player := Vector2(180, 325)
var destination := Vector2(180, 325)
var walking := false
var facing := 1.0
var held: Array[int] = []
var parcels: Array[Dictionary] = []
var counts := [0, 0, 0]
var particles: Array[Dictionary] = []
var score := 0
var goal := 8
var shift := 1
var coins := 0
var all_time := 0
var speed_level := 0
var capacity_level := 0
var cooldown := 0.0
var elapsed := 0.0
var touch_id := -1
var mouse_dragging := false
var hint := "레일에서 집고, 분류존에 쏙!"
var muted := true
var audio_player: AudioStreamPlayer
var safe_offset := Vector2.ZERO
var auto_test := false

func _ready() -> void:
	font = preload("res://assets/korean_font.tres")
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	auto_test = "--smoke-test" in OS.get_cmdline_user_args()
	if not auto_test:
		load_progress()
	seed_parcels()
	get_tree().auto_accept_quit = false
	get_viewport().size_changed.connect(update_layout)
	update_layout()
	if auto_test:
		run_smoke_test.call_deferred()
	if "--capture" in OS.get_cmdline_user_args():
		capture_preview.call_deferred()

func update_layout() -> void:
	var view := get_viewport_rect().size
	safe_offset = (view - Vector2(360, 640)) / 2.0
	position = safe_offset

func seed_parcels() -> void:
	parcels.clear()
	for i in range(6):
		parcels.append({"x": 20.0 + i * 58, "kind": i % 3})

func start_shift() -> void:
	active = true
	finished = false
	paused_game = false
	score = 0
	elapsed = 0
	counts = [0, 0, 0]
	held.clear()
	player = Vector2(180, 325)
	destination = player
	goal = 8 + (shift - 1) * 4
	seed_parcels()

func reset_shift() -> void:
	active = false
	finished = false
	paused_game = false
	score = 0
	counts = [0, 0, 0]
	held.clear()
	particles.clear()
	player = Vector2(180, 325)
	destination = player
	seed_parcels()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if active and not auto_test:
			paused_game = true
			save_progress()
		destination = player
		touch_id = -1
		mouse_dragging = false
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		paused_game = not paused_game
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_progress()
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			paused_game = not paused_game
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if finished:
				shift += 1
				start_shift()
			elif not active:
				start_shift()
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			handle_press(event.position - safe_offset)
		elif event.index == touch_id:
			touch_id = -1
	if event is InputEventScreenDrag and event.index == touch_id:
		set_destination(event.position - safe_offset)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_dragging = event.pressed
		if event.pressed:
			handle_press(event.position - safe_offset)
	if event is InputEventMouseMotion and mouse_dragging:
		set_destination(event.position - safe_offset)

func handle_press(p: Vector2) -> void:
	if Rect2(298, 10, 47, 36).has_point(p):
		muted = not muted
		beep(650)
		return
	if Rect2(247, 10, 46, 36).has_point(p):
		reset_shift()
		return
	if paused_game:
		paused_game = false
		return
	if finished:
		if Rect2(25, 563, 310, 50).has_point(p):
			shift += 1
			start_shift()
		return
	if not active:
		if Rect2(25, 563, 310, 50).has_point(p) or p.y < 505:
			start_shift()
		return
	if Rect2(20, 575, 154, 40).has_point(p):
		buy_upgrade(true)
		return
	if Rect2(186, 575, 154, 40).has_point(p):
		buy_upgrade(false)
		return
	set_destination(p)

func set_destination(p: Vector2) -> void:
	if active and not paused_game and not finished and p.y >= 135 and p.y < 505:
		destination = Vector2(clampf(p.x, 25, 335), clampf(p.y, 281, 370))

func buy_upgrade(speed: bool) -> void:
	var level: int = speed_level if speed else capacity_level
	var cost := 30 * (level + 1)
	if level >= 3:
		burst("최고 레벨!", Vector2(180, 345))
	elif coins >= cost:
		coins -= cost
		if speed:
			speed_level += 1
		else:
			capacity_level += 1
		burst("업그레이드!", Vector2(180, 345))
		beep(980)
		save_progress()
	else:
		burst("정리해서 코인을 모아요", Vector2(180, 345))

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if not paused_game:
		t += dt
		for p in parcels:
			p.x += dt * 24.0
			if p.x > 382:
				p.x = leftmost_x() - 58.0
		for effect in particles:
			effect.life -= dt
		particles = particles.filter(func(e): return e.life > 0)
	if active and not paused_game and not finished and not auto_test:
		advance(dt)
	queue_redraw()

func advance(dt: float) -> void:
	elapsed += dt
	cooldown = maxf(0, cooldown - dt)
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.y += 1
	if direction != Vector2.ZERO:
		destination = player + direction.normalized() * 100
	var old := player
	player = player.move_toward(destination, (130 + speed_level * 25) * dt)
	player.x = clampf(player.x, 25, 335)
	player.y = clampf(player.y, 281, 370)
	walking = old.distance_to(player) > 0.01
	if absf(player.x - old.x) > 0.01:
		facing = signf(player.x - old.x)
	interact()

func leftmost_x() -> float:
	var x := -30.0
	for p in parcels:
		x = minf(x, p.x)
	return x

func interact() -> void:
	if cooldown > 0:
		return
	if player.y < 300 and held.size() < 3 + capacity_level:
		for p in parcels:
			if absf(p.x - player.x) < 38:
				held.append(p.kind)
				p.x = leftmost_x() - 58
				cooldown = 0.25
				beep(520)
				burst("쏙!", player + Vector2(0, -68))
				return
	if player.y > 355:
		for i in range(3):
			if absf(player.x - BIN_X[i]) < 43 and held.has(i):
				held.erase(i)
				score += 1
				all_time += 1
				coins += 10
				counts[i] += 1
				cooldown = 0.18
				burst("정리 완료 +10", Vector2(BIN_X[i], 360))
				beep(780)
				sorted_item.emit(i, score)
				if score >= goal and not finished:
					finished = true
					walking = false
					shift_completed.emit(score)
					save_progress()
				return

func burst(message: String, at: Vector2) -> void:
	particles.append({"message": message, "at": at, "life": 1.2})

func save_progress() -> void:
	if auto_test:
		return
	var cfg := ConfigFile.new()
	for pair in [["coins", coins], ["total", all_time], ["speed", speed_level], ["capacity", capacity_level], ["shift", shift]]:
		cfg.set_value("progress", pair[0], pair[1])
	cfg.save(SAVE_PATH)

func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		coins = maxi(0, int(cfg.get_value("progress", "coins", 0)))
		all_time = maxi(0, int(cfg.get_value("progress", "total", 0)))
		speed_level = clampi(int(cfg.get_value("progress", "speed", 0)), 0, 3)
		capacity_level = clampi(int(cfg.get_value("progress", "capacity", 0)), 0, 3)
		shift = maxi(1, int(cfg.get_value("progress", "shift", 1)))

func beep(frequency: float) -> void:
	if muted or auto_test:
		return
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(4410)
	for i in range(2205):
		var sample := int(sin(TAU * frequency * i / 22050.0) * 3500 * (1.0 - i / 2205.0))
		bytes.encode_s16(i * 2, sample)
	wave.data = bytes
	audio_player.stream = wave
	audio_player.play()

func r(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(roundf(x), roundf(y), w, h), color)

func txt(s: String, x: float, y: float, size: int = 12, color: Color = INK, centered: bool = true) -> void:
	var width := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(x - width / 2 if centered else x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(x: float, y: float, w: float, h: float, fill: Color = CREAM, edge: Color = INK) -> void:
	r(x + 3, y + 4, w, h, edge)
	r(x, y, w, h, edge)
	r(x + 2, y + 2, w - 4, h - 4, fill)

func parcel(x: float, y: float, kind: int, small: bool = false) -> void:
	var s := 0.8 if small else 1.0
	r(x-13*s,y-13*s,26*s,23*s,DARKS[kind])
	r(x-12*s,y-14*s,24*s,21*s,COLORS[kind])
	r(x-2*s,y-14*s,4*s,21*s,Color("f4deb0"))
	r(x+3*s,y-6*s,7*s,7*s,CREAM)
	r(x+4*s,y-4*s,4*s,1*s,DARKS[kind])
	txt(["A","B","C"][kind],x-7*s,y+1,7,INK)

func worker(x: float, y: float, npc: bool = false, moving: bool = false) -> void:
	var bob := sin(t * 17) * 2 if moving else 0.0
	r(x-14,y,28,5,Color("b9b199"))
	r(x-10,y-8,7,11+bob,Color("394958"))
	r(x+3,y-8,7,11-bob,Color("394958"))
	r(x-12,y+1+bob,10,4,INK)
	r(x+3,y+1-bob,10,4,INK)
	r(x-13,y-29,26,23,Color("397b9d") if npc else Color("8359b7"))
	r(x-15,y-26,5,13,CREAM)
	r(x+10,y-26,5,13,CREAM)
	r(x-16,y-14+bob,6,7,Color("f1bb92"))
	r(x+11,y-14-bob,6,7,Color("f1bb92"))
	r(x-17,y-9+bob,7,5,INK)
	r(x+11,y-9-bob,7,5,INK)
	r(x-2,y-28,4,18,CREAM)
	r(x-10,y-16,6,5,Color("644297"))
	r(x+5,y-23,4,3,Color("b9dde0"))
	r(x-10,y-47,21,20,Color("493b43"))
	r(x+9*facing,y-38,7,17,Color("493b43"))
	r(x-8,y-38,16,14,Color("f5caa4"))
	r(x-8,y-40,8,4,Color("493b43"))
	r(x-6,y-34,2,3,INK)
	r(x+3,y-34,2,3,INK)
	r(x-3,y-28,5,1,Color("bb7f72"))
	if not npc:
		r(x-10,y-48,21,4,Color("9b75cc"))

func arrow(x: float, y: float) -> void:
	var yy := y + sin(t*5)*3
	r(x-4, yy-8, 8, 9, Color("ffcf68"))
	draw_colored_polygon(PackedVector2Array([Vector2(x-10, yy),Vector2(x+10, yy),Vector2(x, yy+10)]),Color("ffcf68"))

func rack(x: float) -> void:
	r(x,145,79,55,Color("88aaa4"))
	for i in range(3):
		r(x+5+i*25,149,19,17,Color("d6bb88"))
		r(x+5+i*25,176,19,17,Color("c3c9a9"))
	for yy in [142,169,196]:
		r(x-2,yy,83,5,Color("457f88"))
	r(x,145,4,58,Color("457f88"))
	r(x+75,145,4,58,Color("457f88"))

func _draw() -> void:
	if font == null:
		return
	r(0,0,360,640,CREAM)
	txt("coupang",20,27,20,Color("245e7b"),false)
	txt("물류센터 타이쿤",115,25,9,Color("689091"),false)
	panel(250,12,39,27,Color("e6e9d5"),Color("a6baa5"))
	txt("다시",270,30,10)
	panel(301,12,39,27,Color("e6e9d5"),Color("a6baa5"))
	txt("음소거" if muted else "소리",321,30,9)
	txt("오늘은 내가",20,56,16,INK,false)
	txt("분류의 달인!",19,89,29,INK,false)
	panel(245,55,94,37,Color.WHITE,Color("96b7b0"))
	txt("%02d / %02d" % [score,goal],292,79,18,Color("245e7b"))
	txt("SHIFT %02d" % shift,20,111,10,Color("6e817c"),false)
	txt("코인 %d   ·   누적 %d개" % [coins,all_time],253,111,10,Color("6e817c"))
	r(20,122,320,5,Color("dbe3d5"))
	r(20,122,320*minf(float(score)/goal,1),5,Color("66ac8c"))
	r(0,134,360,73,Color("b9d3cc"))
	rack(12)
	rack(268)
	panel(112,143,136,27,Color("f3ebcb"),Color("749e9c"))
	txt("CLS · SORTING CENTER",180,161,9)
	worker(145+sin(t*.8)*27,210,true,true)
	worker(232+sin(t*.6)*16,209,true,true)
	r(0,207,360,301,Color("e7ddc4"))
	for yy in range(216,510,30):
		r(0,yy,360,1,Color("d7cdb6"))
		for xx in range(0,360,45):
			r(xx,yy,1,30,Color("d7cdb6"))
	r(12,286,3,190,Color("f7cd65"))
	r(345,286,3,190,Color("f7cd65"))
	for xx in range(27,345,24):
		r(xx,350,12,2,Color("cabf9f"))
	r(0,217,360,48,Color("214a58"))
	r(0,222,360,29,Color("90a9a5"))
	for xx in range(-20,380,12):
		var roll: float = xx + fmod(t*24,12)
		r(roll,222,4,29,Color("c6d7cd"))
		r(roll+4,222,2,29,Color("638c93"))
	r(0,214,360,7,Color("398eae"))
	r(0,252,360,7,Color("398eae"))
	r(0,262,360,8,Color("245e7b"))
	for xx in range(8,360,25):
		r(xx,254,10,2,Color("ffcf68"))
	for xx in range(17,360,105):
		r(xx,270,7,12,Color("376c7a"))
		r(xx-3,280,13,4,INK)
	for p in parcels:
		if p.x > -20 and p.x < 380:
			parcel(p.x,239,p.kind)
	txt("PICK UP",180,299,9,Color("9a987e"))
	for i in range(3):
		var x: float = BIN_X[i]
		if held.has(i):
			draw_rect(Rect2(x-43,369,86,85),Color("ffcf68"),false,2)
			arrow(x,359)
		panel(x-29,374,58,23,CREAM,DARKS[i])
		txt(NAMES[i],x,390,10)
		r(x-38,445,78,7,Color("b7a787"))
		r(x-35,405,70,39,DARKS[i])
		r(x-29,409,58,23,INK)
		for j in range(mini(counts[i],4)):
			parcel(x-14+(j%2)*27,422-(j/2)*9,i,true)
		r(x-35,428,70,17,COLORS[i])
		r(x-37,403,74,6,COLORS[i])
		for xx in range(-25,30,12):
			r(x+xx,432,4,10,DARKS[i])
	txt("SORTING ZONE",180,477,9,Color("9a987e"))
	if active and player.distance_to(destination)>4:
		draw_arc(destination,9,0,TAU,16,Color("fff8e7"),2)
	worker(player.x,player.y,false,walking)
	for i in range(held.size()):
		parcel(player.x,player.y-30-i*14,held[i],true)
	if not held.is_empty():
		panel(player.x-16,player.y+10,32,16)
		txt("%d/%d" % [held.size(),3+capacity_level],player.x,player.y+22,8)
	elif active:
		arrow(player.x,player.y-64)
	for effect in particles:
		txt(effect.message,effect.at.x,effect.at.y-(1.2-effect.life)*20,12,Color("327e69"))
	r(0,507,360,133,CREAM)
	r(0,507,360,3,Color("d2c7ad"))
	if active:
		txt("같은 표시의 분류존으로 이동!" if not held.is_empty() else "레일 가까이 가면 자동으로 집어요",180,536,14)
		txt("터치 · 드래그로 이동 / 방향키 · WASD",180,556,10,Color("7a8b83"))
		panel(20,577,151,35,Color("e6e9d5"),Color("a6baa5"))
		panel(188,577,151,35,Color("e6e9d5"),Color("a6baa5"))
		txt("속도 MAX" if speed_level>=3 else "속도 UP · %d코인" % (30*(speed_level+1)),96,599,10)
		txt("가방 MAX" if capacity_level>=3 else "가방 UP · %d코인" % (30*(capacity_level+1)),263,599,10)
	else:
		txt("작은 물건도, 내 손으로 착착.",180,536,16)
		txt("직접 움직여 물류센터를 정리해 보세요",180,555,10,Color("7a8b83"))
		panel(25,565,310,48,Color("ffcf68"))
		txt("터치해서 출근하기 →",180,595,17)
	txt("PROTOTYPE 0.1 · 오프라인 플레이",180,634,8,Color("8a9588"))
	if finished:
		r(0,134,360,373,Color(0.1,0.2,0.22,0.7))
		panel(35,244,290,158,CREAM)
		txt("분류의 달인!",180,282,26)
		txt("%d개 정리 완료 · %.0f초" % [score,elapsed],180,315,15)
		txt("모은 코인으로 다음 작업을 더 빠르게",180,345,12)
		txt("잘했어요! 다음 근무도 도전해요",180,373,12,Color("327e69"))
		r(0,510,360,112,CREAM)
		txt("다음 목표: %d개" % (8+shift*4),180,545,14)
		panel(25,565,310,48,Color("ffcf68"))
		txt("다음 근무 시작 →",180,595,17)
	if paused_game:
		r(0,134,360,489,Color(0.1,0.2,0.22,0.75))
		panel(45,265,270,108)
		txt("잠깐 쉬는 중",180,307,23)
		txt("화면을 터치하면 이어서 플레이",180,344,12)

func capture_preview() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://../godot-preview.png"))
	get_tree().quit()

func run_smoke_test() -> void:
	start_shift()
	# Exercise the same touch route, pickup radius, matching bins and upgrade rules.
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.index = 0
	touch.position = Vector2(180,281) + safe_offset
	_input(touch)
	assert(destination == Vector2(180,281), "Touch did not set target")
	for i in range(80):
		advance(1.0/60.0)
	assert(player.y < 300, "Movement did not reach belt")
	held.clear()
	var completions := [0]
	shift_completed.connect(func(_n): completions[0] += 1)
	for n in range(8):
		var kind := n % 3
		player = Vector2(180,281)
		for p in parcels:
			p.x = -500
		parcels[0].x = 180
		parcels[0].kind = kind
		cooldown = 0
		interact()
		assert(held.has(kind), "Pickup failed")
		player = Vector2(BIN_X[(kind+1)%3],370)
		cooldown = 0
		interact()
		assert(held.has(kind), "Wrong bin accepted a parcel")
		player = Vector2(BIN_X[kind],370)
		interact()
		assert(not held.has(kind), "Correct bin rejected a parcel")
	assert(score == 8 and finished and completions[0] == 1, "Shift completion failed")
	assert(coins == 80, "Reward mismatch")
	buy_upgrade(true)
	assert(speed_level == 1 and coins == 50, "Upgrade mismatch")
	reset_shift()
	assert(score == 0 and held.is_empty() and not active, "Reset failed")
	print("SMOKE PASS: touch, movement, pickup, wrong/correct sorting, 8-item completion, rewards, upgrade, reset")
	get_tree().quit()

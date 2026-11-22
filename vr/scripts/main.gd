extends Node3D
## Embodiment Lab — Rubber Hand Illusion (prototype)
## Three counterbalanced stimulus conditions; haptic pulse != real skin brushing.

const CONDITION_NAMES := ["Synchronous", "Asynchronous", "Visual only"]
const DURATION := 45.0
const TOUCH_PERIOD := 1.5
const RESULTS_FILE := "user://embodiment_lab_results.csv"

@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
@onready var left_controller: XRController3D = $XROrigin3D/LeftController
@onready var right_controller: XRController3D = $XROrigin3D/RightController
@onready var desktop_camera: Camera3D = $DesktopCamera

var using_xr := false
var phase := 0 # 0 preparation, 1 stimulation, 2 questionnaire, 3 complete
var condition := 0
var rating := 4
var elapsed := 0.0
var last_touch := -1
var haptic_due := -1.0
var brush: Node3D
var title_label: Label3D
var detail_label: Label3D


func _ready() -> void:
	var xr_interface: XRInterface = XRServer.find_interface("OpenXR")
	if xr_interface != null:
		using_xr = xr_interface.initialize()
	get_viewport().use_xr = using_xr
	xr_camera.current = using_xr
	desktop_camera.current = not using_xr
	if using_xr:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_make_room()
	_make_hand()
	_make_brush()
	_make_hud()
	desktop_camera.look_at(Vector3(0.0, 0.98, -1.18), Vector3.UP)
	right_controller.button_pressed.connect(_on_right_button)
	left_controller.button_pressed.connect(_on_left_button)
	_update_hud()


func _mat(c: Color, roughness: float = 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = c
	material.roughness = roughness
	return material


func _box(part_name: String, pos: Vector3, size: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	result.mesh = mesh
	result.material_override = _mat(color)
	result.position = pos
	result.name = part_name
	parent.add_child(result)
	return result


func _oval(part_name: String, pos: Vector3, size: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	result.mesh = mesh
	result.scale = size * 0.5
	result.material_override = _mat(color)
	result.position = pos
	result.name = part_name
	parent.add_child(result)
	return result


func _make_room() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.16, 0.21)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72, 0.78, 0.86)
	environment.ambient_light_energy = 0.85
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -25.0, -10.0)
	light.light_energy = 1.15
	light.shadow_enabled = true
	add_child(light)
	_box("Floor", Vector3(0, -0.04, -1.0), Vector3(8, 0.08, 8), Color(0.24, 0.27, 0.30), self)
	_box("Back wall", Vector3(0, 1.55, -3.0), Vector3(8, 3.1, 0.08), Color(0.57, 0.64, 0.67), self)
	_box("Left wall", Vector3(-3.8, 1.55, -1.0), Vector3(0.08, 3.1, 8), Color(0.48, 0.57, 0.61), self)
	_box("Walnut table", Vector3(0, 0.78, -1.17), Vector3(1.92, 0.075, 1.04), Color(0.33, 0.19, 0.12), self)
	_box("Table leg L", Vector3(-0.81, 0.36, -1.50), Vector3(0.08, 0.72, 0.08), Color(0.16, 0.16, 0.17), self)
	_box("Table leg R", Vector3(0.81, 0.36, -1.50), Vector3(0.08, 0.72, 0.08), Color(0.16, 0.16, 0.17), self)
	_box("Silicone examination mat", Vector3(0.29, 0.830, -1.18), Vector3(0.68, 0.012, 0.69), Color(0.15, 0.24, 0.26), self)
	_box("Real hand occlusion", Vector3(-0.35, 1.02, -1.18), Vector3(0.53, 0.36, 0.69), Color(0.08, 0.12, 0.16), self)
	_box("Occlusion lid", Vector3(-0.35, 1.21, -1.18), Vector3(0.55, 0.024, 0.71), Color(0.14, 0.18, 0.22), self)


func _make_hand() -> void:
	var hand := Node3D.new()
	hand.name = "Virtual rubber right hand"
	add_child(hand)
	var skin := Color(0.78, 0.49, 0.39)
	var nail := Color(0.92, 0.71, 0.67)
	_oval("Palm", Vector3(0.31, 0.888, -1.17), Vector3(0.26, 0.09, 0.29), skin, hand)
	_oval("Wrist", Vector3(0.31, 0.89, -0.955), Vector3(0.19, 0.085, 0.20), skin, hand)
	for finger in range(4):
		var x := 0.196 + finger * 0.073
		var length := [0.19, 0.26, 0.245, 0.20][finger]
		var z := -1.395 - length * 0.42
		_oval("Finger %d" % finger, Vector3(x, 0.89, z), Vector3(0.058, 0.069, length), skin, hand)
		_oval("Fingernail %d" % finger, Vector3(x, 0.931, z - length * 0.30), Vector3(0.041, 0.008, 0.052), nail, hand)
	var thumb := _oval("Thumb", Vector3(0.452, 0.892, -1.27), Vector3(0.076, 0.08, 0.19), skin, hand)
	thumb.rotation_degrees.y = -45


func _make_brush() -> void:
	brush = Node3D.new()
	brush.name = "Brush stimulus"
	add_child(brush)
	var handle := _box("Wooden brush shaft", Vector3(0, 0.105, 0), Vector3(0.024, 0.21, 0.024), Color(0.42, 0.22, 0.10), brush)
	handle.rotation_degrees.z = 24
	_oval("Soft bristles", Vector3(-0.044, -0.006, 0), Vector3(0.100, 0.041, 0.085), Color(0.93, 0.86, 0.68), brush)
	brush.position = Vector3(0.31, 0.972, -1.27)


func _make_hud() -> void:
	_box("HUD board", Vector3(0.0, 1.57, -2.17), Vector3(1.94, 0.67, 0.04), Color(0.045, 0.075, 0.10), self)
	title_label = Label3D.new()
	title_label.position = Vector3(0, 1.76, -2.13)
	title_label.pixel_size = 0.00145
	title_label.font_size = 35
	title_label.modulate = Color(0.80, 0.93, 1.0)
	title_label.text = "EMBODIMENT LAB"
	add_child(title_label)
	detail_label = Label3D.new()
	detail_label.position = Vector3(0, 1.48, -2.13)
	detail_label.pixel_size = 0.00165
	detail_label.font_size = 24
	detail_label.width = 1000
	detail_label.modulate = Color(0.95, 0.97, 0.98)
	add_child(detail_label)


func _process(delta: float) -> void:
	if phase != 1:
		return
	elapsed += delta
	var turn := int(floor(elapsed / TOUCH_PERIOD))
	var t := fmod(elapsed, TOUCH_PERIOD) / TOUCH_PERIOD
	brush.position = Vector3(0.31 + 0.10 * sin(t * TAU), 0.969 + 0.01 * sin(t * PI), -1.25)
	if turn != last_touch:
		last_touch = turn
		if condition == 0:
			_pulse()
		elif condition == 1:
			haptic_due = elapsed + 0.70
	if haptic_due > 0.0 and elapsed >= haptic_due:
		_pulse()
		haptic_due = -1.0
	if elapsed >= DURATION:
		phase = 2
		_update_hud()
	elif int(elapsed * 2.0) != int((elapsed - delta) * 2.0):
		_update_hud()


func _pulse() -> void:
	if using_xr:
		right_controller.trigger_haptic_pulse("haptic", 0.0, 0.45, 0.10, 0.0)


func _on_right_button(_button: String) -> void:
	_advance()


func _on_left_button(_button: String) -> void:
	if phase == 0:
		condition = (condition + 1) % CONDITION_NAMES.size()
	elif phase == 2:
		rating = 1 + rating % 7
	_update_hud()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
		_advance()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_7:
		var number: int = event.keycode - KEY_0
		if phase == 0:
			condition = min(number - 1, 2)
		elif phase == 2:
			rating = number
		_update_hud()


func _advance() -> void:
	match phase:
		0:
			phase = 1
			elapsed = 0.0
			last_touch = -1
			haptic_due = -1.0
		1:
			phase = 2
		2:
			_save_result()
			phase = 3
		3:
			phase = 0
			rating = 4
	_update_hud()


func _save_result() -> void:
	var exists := FileAccess.file_exists(RESULTS_FILE)
	var file: FileAccess
	if exists:
		file = FileAccess.open(RESULTS_FILE, FileAccess.READ_WRITE)
	else:
		file = FileAccess.open(RESULTS_FILE, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open results CSV: " + str(FileAccess.get_open_error()))
		return
	if exists:
		file.seek_end()
	else:
		file.store_line("timestamp,condition,exposure_seconds,ownership_rating_1_to_7")
	file.store_line("%s,%s,%.2f,%d" % [Time.get_datetime_string_from_system(), CONDITION_NAMES[condition], elapsed, rating])
	file.close()


func _update_hud() -> void:
	match phase:
		0:
			detail_label.text = "РУКА / RUBBER HAND ILLUSION\nCondition: %s\nLeft trigger: change condition / Right trigger: START\nDesktop: 1-3 to choose, SPACE to start" % CONDITION_NAMES[condition]
			brush.visible = false
		1:
			detail_label.text = "STIMULATION (%s)\nObserve the hand and brush: %.0f / %.0f sec\nRight trigger / SPACE: skip" % [CONDITION_NAMES[condition], elapsed, DURATION]
			brush.visible = true
		2:
			detail_label.text = "QUESTIONNAIRE: The visible hand felt like my own.\nOwnership 1 (no) ... 7 (yes): %d\nLeft trigger: change rating / Right trigger: SAVE\nDesktop: keys 1-7, SPACE to save" % rating
			brush.visible = false
		3:
			detail_label.text = "SESSION SAVED\nuser://embodiment_lab_results.csv\nRight trigger / SPACE: new session\nDemo only: vibration does not equal skin stroking"
			brush.visible = false

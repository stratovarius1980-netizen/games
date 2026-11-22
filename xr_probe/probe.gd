extends Node3D

# Device-only OpenXR rendering probe. No external plugins.
@onready var xr_camera: XRCamera3D = $XROrigin3D/XRCamera3D
var frame_counter := 0

func _ready() -> void:
    print("QUEST_PROBE_BOOT: Godot scene started on ", OS.get_name())
    var xr: XRInterface = XRServer.find_interface("OpenXR")
    if xr == null:
        push_error("QUEST_PROBE_FATAL: OpenXR interface missing")
        if OS.has_feature("android"):
            get_tree().quit(2)
        return
    print("QUEST_PROBE_OPENXR_INITIALIZED=", xr.is_initialized(), " name=", xr.get_name())
    if not xr.is_initialized():
        push_error("QUEST_PROBE_FATAL: OpenXR never initialized before scene. Check logcat for xrCreateInstance error.")
        if OS.has_feature("android"):
            get_tree().quit(3)
        return
    get_viewport().use_xr = true
    xr_camera.current = true
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    if RenderingServer.get_rendering_device() != null:
        get_viewport().vrs_mode = Viewport.VRS_XR
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.06, 0.21, 0.45)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color.WHITE
    env.ambient_light_energy = 1.0
    var world := WorldEnvironment.new()
    world.environment = env
    add_child(world)
    _add_unshaded_box("GREEN VR STEREO TEST", Vector3(0, 0.03, -1.0), Vector3(0.65, 0.25, 0.04), Color(0.0, 1.0, 0.18))
    _add_unshaded_box("RED LEFT MARK", Vector3(-0.50, -0.26, -1.50), Vector3(0.15, 0.15, 0.15), Color(1.0, 0.05, 0.07))
    _add_unshaded_box("BLUE RIGHT MARK", Vector3(0.50, -0.26, -1.50), Vector3(0.15, 0.15, 0.15), Color(0.04, 0.32, 1.0))
    _add_text("STEREO VR ACTIVE", Vector3(0, 0.03, -0.95), Color(0,0,0), 28)
    _add_text("Move head: objects should stay in view", Vector3(0, -0.36, -1.0), Color.WHITE, 24)
    print("QUEST_PROBE_XR_VIEWPORT_ACTIVE; RENDERER=", ProjectSettings.get_setting("rendering/renderer/rendering_method"))
    
func _add_unshaded_box(label: String, pos: Vector3, size: Vector3, tint: Color) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = tint
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    instance.material_override = material
    instance.position = pos
    xr_camera.add_child(instance)

func _add_text(value: String, pos: Vector3, tint: Color, font_size: int) -> void:
    var label := Label3D.new()
    label.text = value
    label.font_size = font_size
    label.pixel_size = 0.0014
    label.no_depth_test = true
    label.modulate = tint
    label.position = pos
    xr_camera.add_child(label)

func _process(_delta: float) -> void:
    frame_counter += 1
    if frame_counter == 60:
        print("QUEST_PROBE_RENDER_LOOP_60_FRAMES: XR viewport active=", get_viewport().use_xr)

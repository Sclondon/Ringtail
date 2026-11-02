class_name PlantLook
## The look FlowerGen's flowers and BrambleGen's brambles are drawn with: their vertex colours, cel lit (one hard step,
## as the mushrooms and the house Toon), the same from both sides; swaying in the wind more towards their tops (UV.y,
## 0 at the foot to 1 at the top), the way the wind blows when there is one (`update(.., wind_dir)`), and pushed aside
## where anyone goes through them, as the grass and Undergrowth's plants are (Grass's pushers; plant_push.gdshaderinc).
##
##   PlantLook.shared()                          # the material (on every mesh the generators make)
##   PlantLook.update(viewport, wind_dir, gust)  # once a frame (the pushers near the camera, the wind)

const SHADER := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform vec4 pushers[8];
uniform int pusher_count = 0;
uniform float sway = 0.05;
uniform vec2 wind_dir = vec2(1.0, 0.0);
uniform float gust = 0.0;
uniform float wrap = 0.35;
uniform float flatness = 0.6;

#include "res://scripts/plant_push.gdshaderinc"

void vertex() {
	float up = UV.y;
	// (the wind's way, a lean that comes and goes, on top of the shared sway and push)
	vec3 here = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * 1.7 + dot(here.xz, vec2(0.31, 0.23));
	vec3 lean = vec3(wind_dir.x, 0.0, wind_dir.y) * (0.5 + 0.5 * sin(t)) * gust * 0.08 * up * up;
	VERTEX += bent(MODEL_MATRIX, VERTEX, up, sway, TIME) + inverse(mat3(MODEL_MATRIX)) * lean;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}

float cut(float value, float edge) {
	float pixel = max(fwidth(value), 0.0005);
	return smoothstep(edge - pixel, edge + pixel, value);
}

void light() {
	float reach = clamp(ATTENUATION, 0.0, 1.0);
	float facing = (dot(NORMAL, LIGHT) + wrap) / (1.0 + wrap);
	float lit = cut(facing * smoothstep(0.15, 0.6, reach), 0.04);
	DIFFUSE_LIGHT += mix(0.45, 1.0, lit) * mix(reach, 1.0, flatness) * LIGHT_COLOR / PI;
}
"""

static var _shared: ShaderMaterial
static var _frame := -1


static func shared() -> ShaderMaterial:
	if _shared == null:
		var shader := Shader.new()
		shader.code = SHADER
		_shared = ShaderMaterial.new()
		_shared.shader = shader
	return _shared


## The pushers nearest the camera (Grass.nearest_pushers) and the wind, once a frame however many call it.
static func update(viewport: Viewport, wind_dir := Vector2(1.0, 0.0), gust := 0.0) -> void:
	var frame := Engine.get_process_frames()
	if frame == _frame or _shared == null:
		return
	_frame = frame
	var camera := viewport.get_camera_3d()
	var found: Array = Grass.nearest_pushers(camera) if camera else []
	var packed := PackedVector4Array()
	packed.resize(Grass.MAX_PUSHERS)
	var n := mini(found.size(), Grass.MAX_PUSHERS)
	for i in n:
		var at: Vector3 = (found[i] as Node3D).global_position
		packed[i] = Vector4(at.x, at.y, at.z, (found[i] as Node).get_meta(&"grass_radius", 0.7))
	_shared.set_shader_parameter(&"pushers", packed)
	_shared.set_shader_parameter(&"pusher_count", n)
	_shared.set_shader_parameter(&"wind_dir", wind_dir.normalized() if wind_dir.length() > 0.001 else Vector2.RIGHT)
	_shared.set_shader_parameter(&"gust", gust)


## Many of a mesh at `places` (transforms in `parent`'s space), one MultiMesh drawn within `far` m (drawn with
## PlantLook, or `own_materials`: each surface its own). (Vertex colours
## kept: GL Compatibility drops them from a MultiMesh without instance colours.)
static func scatter(parent: Node3D, places: Array, mesh: Mesh, far := 45.0, shadows := false, own_materials := false) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = places.size()
	for i in places.size():
		multi.set_instance_transform(i, places[i])
		multi.set_instance_color(i, Color.WHITE)
	var shown := MultiMeshInstance3D.new()
	shown.multimesh = multi
	# (a mesh with surfaces of its own looks, a bramble's leaf cards, keeps them)
	if not own_materials:
		shown.material_override = shared()
	shown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shown.visibility_range_end = far
	shown.visibility_range_end_margin = 6.0
	shown.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(shown)
	return shown

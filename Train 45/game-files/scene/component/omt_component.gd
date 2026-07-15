extends Control
class_name OMTComponent

@export_category("Textures")
@export var piston: Array[CompressedTexture2D]
@export var hand: Array[CompressedTexture2D]
@export var fella: Array[CompressedTexture2D]
@export var kiss: Array[CompressedTexture2D]
@export var cum: Array[CompressedTexture2D]
@export var onaho: Array[CompressedTexture2D]
@export var orgasm: Array[CompressedTexture2D]
@export var piston_voice: Array[CompressedTexture2D]
@export var sumata: Array[CompressedTexture2D]
@export var breast_touch: Array[CompressedTexture2D]

@export var cum_ef: ColorRect
@export var texture_sample: TextureRect

@export_category("Limits")
@export var max_piston := 1
@export var max_hand := 1
@export var max_fella := 1
@export var max_kiss := 1
@export var max_cum := 1
@export var max_orgasm := 1
@export var max_piston_voice := 1
@export var max_onaho := 1
@export var max_sumata := 1
@export var max_breast_touch := 1

const SPAWN_CHANCE := 0.75
const SPAWN_RADIUS := 85.0
@export var spawn_min_radius := 75.0
@export var full_spawn_radius := 150.0
@export var full_spawn_min_radius := 120.0
const DISPLAY_TIME := 1.0
## piston_voice/orgasm 주기 스폰 간격(초)
const VOICE_INTERVAL := 1.5
## 겹침 방지: 두 말풍선 중심거리가 (반지름합 * 이 값)보다 가까우면 겹친 것으로 본다.
const OVERLAP_FACTOR := 0.8
## 겹치지 않는 위치를 찾기 위한 최대 재시도 횟수
const SPAWN_ATTEMPTS := 8
@export var spawn_y_offset := -140.0

@onready var omt_toggle_button: TextureButton = %OMTToggleButton
@onready var state_label: Label = %StateLabel

# HSceneTypes 값: NORMAL=0, HARD=1, FELLA_IN=2, FELLA_OUT=3, KISS=4, HAND=5, CUM=6, ORGASM=7, BREASE_TOUCH=8, NORMAL_SUMATA=9, ONAHO=10
const _TYPE_PISTON := [0, 1]
const _TYPE_FELLA  := [2] # 3은 제외, 너무 자주 나옴
const _TYPE_KISS   := [4]
const _TYPE_HAND   := [5]
const _TYPE_CUM    := [6]
const _TYPE_BREAST := [8]
const _TYPE_SUMATA := [9]
const _TYPE_ONAHO  := [10]

# OMTMarker.spawn_sides 비트 (좌=1, 우=2, 상=4, 하=8)
const _SIDE_LEFT  := 1
const _SIDE_RIGHT := 2
const _SIDE_UP    := 4
const _SIDE_DOWN  := 8

var _free_action: HSceneFreeActionComponent
var _active_counts := { "piston": 0, "hand": 0, "fella": 0, "kiss": 0, "cum": 0, "orgasm": 0, "piston_voice": 0, "onaho": 0, "sumata": 0, "breast_touch": 0 }
# 현재 화면에 떠 있는 말풍선들의 { center, radius }. 겹침 방지에 사용.
var _active_bubbles: Array = []
var _connected_players: Array = []
var _voice_timer: Timer
var _cum_ef_tween: Tween
var _current_npc_type: int = -1
var _current_scene_name: String = ""
var _current_h_scene: Node = null

# 관찰 모드 토글 디바운스용 상태. 아날로그 트리거(LT 등)를 천천히 당기면 임계값
# 근처에서 입력이 연속/떨림으로 들어와 토글이 고속 반복되므로, 라이징 엣지 + 쿨다운으로 막는다
const _OMT_TOGGLE_COOLDOWN_MS := 300
var _omt_toggle_held := false
var _last_omt_toggle_ms := 0


func _ready() -> void:
	cum_ef.hide()
	_free_action = get_parent().get_parent() as HSceneFreeActionComponent
	if not _free_action:
		push_warning("OMTComponent: HSceneFreeActionComponent를 찾을 수 없습니다.")
		return

	_free_action.anim_info_changed.connect(_on_anim_changed)

	# piston_voice/orgasm 주기 스폰용 타이머 (소리와 무관하게 동작)
	_voice_timer = Timer.new()
	_voice_timer.wait_time = VOICE_INTERVAL
	_voice_timer.autostart = true
	_voice_timer.timeout.connect(_on_voice_timeout)
	add_child(_voice_timer)

	var enabled: bool = MetaProgression.save_data.get("omt_enabled", true)
	omt_toggle_button.set_pressed_no_signal(enabled)
	visible = enabled
	_update_state_label(TranslationServer.get_locale())
	LanguageManager.lang_changed.connect(_update_state_label)


func _update_state_label(locale: String) -> void:
	var enabled := omt_toggle_button.button_pressed
	if locale.begins_with("ru"):
		state_label.text = "ВКЛ" if enabled else "ВЫКЛ"
	else:
		state_label.text = "ON" if enabled else "OFF"


func _on_anim_changed(npc_type: int, anim: AnimationPlayer, scene_name: String) -> void:
	_current_npc_type = npc_type
	_current_scene_name = scene_name
	_current_h_scene = anim.get_parent() if is_instance_valid(anim) else null
	_reconnect_audio_players(anim)


func _find_matching_marker(type: int, allow_fallback := true) -> OMTMarker:
	if not is_instance_valid(_current_h_scene):
		return null
	var event_num := _current_scene_name.trim_prefix("scene").split("_")[0]
	# h_type이 일치하는 마커를 우선 사용하고, 없으면 해당 씬의 첫 마커로 폴백한다.
	# allow_fallback=false이면 h_type이 정확히 일치하는 마커가 없을 때 null을 반환한다.
	var matched: OMTMarker = null
	var fallback: OMTMarker = null
	for child in _current_h_scene.get_children():
		if child is OMTMarker:
			child.hide()
			if child.npc_type == _current_npc_type and child.scene_name == event_num:
				if fallback == null:
					fallback = child
				if child.h_type == type:
					matched = child
	var result: OMTMarker = matched if matched else (fallback if allow_fallback else null)
	if result:
		result.show()
	return result


func _sample_marker_pos(marker: OMTMarker) -> Vector2:
	var xf := marker.get_global_transform_with_canvas()
	var shape := marker.shape as CapsuleShape2D
	if not shape:
		return xf.origin
	var r := shape.radius
	var hh := shape.height * 0.5
	# 밴드는 회전하지 않고 화면축 고정. 캡슐의 화면상 AABB 크기로 폭·높이를 잡아
	# 회전·스케일은 "크기"에만 반영한다.
	var half_w := r * absf(xf.x.x) + hh * absf(xf.y.x)
	var half_h := r * absf(xf.x.y) + hh * absf(xf.y.y)
	# 마커에 체크된 방향(좌=1, 우=2, 상=4, 하=8) 중 하나를 골라 그 가장자리에 스폰
	var enabled: Array[int] = []
	if marker.spawn_sides & _SIDE_LEFT:  enabled.append(_SIDE_LEFT)
	if marker.spawn_sides & _SIDE_RIGHT: enabled.append(_SIDE_RIGHT)
	if marker.spawn_sides & _SIDE_UP:    enabled.append(_SIDE_UP)
	if marker.spawn_sides & _SIDE_DOWN:  enabled.append(_SIDE_DOWN)
	if enabled.is_empty():
		return xf.origin
	var x := 0.0
	var y := 0.0
	match enabled.pick_random():
		_SIDE_LEFT:
			x = -half_w * randf_range(1.0, 1.3)
			y = randf_range(-half_h, half_h)
		_SIDE_RIGHT:
			x = half_w * randf_range(1.0, 1.3)
			y = randf_range(-half_h, half_h)
		_SIDE_UP:
			x = randf_range(-half_w, half_w)
			y = -half_h * randf_range(1.0, 1.3)
		_SIDE_DOWN:
			x = randf_range(-half_w, half_w)
			y = half_h * randf_range(1.0, 1.3)
	return xf.origin + Vector2(x, y)


func _overlaps_active(center: Vector2, radius: float) -> bool:
	for b in _active_bubbles:
		if center.distance_to(b.center) < (radius + b.radius) * OVERLAP_FACTOR:
			return true
	return false


func _reconnect_audio_players(anim: AnimationPlayer) -> void:
	for player in _connected_players:
		if is_instance_valid(player):
			player.h_sfx_played.disconnect(_on_h_sfx_played)
	_connected_players.clear()

	if not is_instance_valid(anim):
		return
	var h_scene := anim.get_parent()
	if not is_instance_valid(h_scene):
		return
	_find_audio_players(h_scene)


func _find_audio_players(node: Node) -> void:
	for child in node.get_children():
		if child.has_method("play_h_sfx"):
			child.h_sfx_played.connect(_on_h_sfx_played)
			_connected_players.append(child)
		_find_audio_players(child)


func _on_h_sfx_played(type: int) -> void:
	var key := _get_type_key(type)
	if not key.is_empty():
		_spawn_omt(key, type)
	if type in _TYPE_CUM:
		_play_cum_ef()


func _play_cum_ef() -> void:
	if not cum_ef:
		return
	if _cum_ef_tween and _cum_ef_tween.is_running():
		return
	var skip: Array = Constants.CUM_EF_SKIP_SCENES.get(_free_action.npc.npc_name, [])
	if _free_action.current_event in skip:
		return
	cum_ef.modulate.a = 0.0
	cum_ef.show()
	_cum_ef_tween = create_tween()
	_cum_ef_tween.tween_property(cum_ef, "modulate:a", 1.0, 0.1)
	_cum_ef_tween.tween_property(cum_ef, "modulate:a", 0.0, 1.2)
	_cum_ef_tween.tween_callback(cum_ef.hide)


func _on_voice_timeout() -> void:
	# 소리와 무관하게 주기적으로 ORGASM 마커(h_type=7)에 띄운다.
	# 행위(play=2) 중엔 piston_voice, 사정/절정 중엔 orgasm으로 교체.
	if not _free_action or not _free_action.is_event:
		return
	var key: String
	if _free_action.scene_progress == 3 or _free_action.is_climax:
		key = "orgasm"
	elif _free_action.scene_progress == 2:
		key = "piston_voice"
	else:
		return
	# ORGASM(h_type=7) 마커가 지정된 씬에서만 piston_voice/orgasm을 띄운다.
	_spawn_omt(key, HSfxStream.HSceneTypes.ORGASM, true)


func _get_type_key(type: int) -> String:
	if type in _TYPE_PISTON: return "piston"
	if type in _TYPE_FELLA:  return "fella"
	if type in _TYPE_KISS:   return "kiss"
	if type in _TYPE_HAND:   return "hand"
	if type in _TYPE_CUM:    return "cum"
	if type in _TYPE_BREAST: return "breast_touch"
	if type in _TYPE_SUMATA: return "sumata"
	if type in _TYPE_ONAHO:  return "onaho"
	return ""


func _get_textures(key: String) -> Array:
	match key:
		"piston":       return piston
		"fella":        return fella
		"kiss":         return kiss
		"hand":         return hand
		"cum":          return cum
		"orgasm":       return orgasm
		"piston_voice": return piston_voice
		"onaho":        return onaho
		"sumata":       return sumata
		"breast_touch": return breast_touch
	return []


func _get_max(key: String) -> int:
	match key:
		"piston":       return max_piston
		"fella":        return max_fella
		"kiss":         return max_kiss
		"hand":         return max_hand
		"cum":          return max_cum
		"orgasm":       return max_orgasm
		"piston_voice": return max_piston_voice
		"onaho":        return max_onaho
		"sumata":       return max_sumata
		"breast_touch": return max_breast_touch
	return 0


func _get_npc_screen_pos() -> Vector2:
	if not is_instance_valid(_free_action.npc):
		return Vector2.ZERO
	return _free_action.npc.get_global_transform_with_canvas().origin


func _spawn_omt(key: String, type: int, require_marker := false) -> void:
	if randf() > SPAWN_CHANCE:
		return
	var textures := _get_textures(key)
	if textures.is_empty():
		return
	if _active_counts[key] >= _get_max(key):
		return

	# require_marker=true면 h_type이 일치하는 마커가 없을 때 스폰하지 않는다(반경 폴백도 막음).
	var marker := _find_matching_marker(type, not require_marker)
	if require_marker and not marker:
		return

	var tex: CompressedTexture2D = textures.pick_random()
	var img := TextureRect.new()
	img.texture = tex
	img.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var target_scale := Vector2.ONE
	if texture_sample:
		img.expand_mode = texture_sample.expand_mode
		img.stretch_mode = texture_sample.stretch_mode
		img.size = texture_sample.size
		target_scale = texture_sample.scale
	else:
		img.size = tex.get_size()
	img.pivot_offset = img.size / 2.0
	img.scale = Vector2.ZERO

	# 이미 떠 있는 말풍선과 겹치지 않는 위치를 찾는다.
	# SPAWN_ATTEMPTS 안에 못 찾으면 마지막 후보를 그대로 사용한다.
	var radius := maxf(img.size.x * target_scale.x, img.size.y * target_scale.y) * 0.5
	var center: Vector2
	var rotation_sign: float
	for _i in SPAWN_ATTEMPTS:
		if marker:
			center = _sample_marker_pos(marker)
			rotation_sign = 1.0 if center.x >= _get_npc_screen_pos().x else -1.0
		else:
			var angle := randf() * TAU
			var spawn_dir := Vector2(cos(angle), sin(angle))
			var is_full := _free_action.is_full_mode
			var dist := randf_range(
				full_spawn_min_radius if is_full else spawn_min_radius,
				full_spawn_radius if is_full else SPAWN_RADIUS
			)
			center = _get_npc_screen_pos() + Vector2(0, spawn_y_offset) + spawn_dir * dist
			rotation_sign = 1.0 if spawn_dir.x >= 0.0 else -1.0
		if not _overlaps_active(center, radius):
			break
	img.position = center - img.pivot_offset
	img.rotation = rotation_sign * randf_range(0.0, 0.349)

	add_child(img)
	_active_counts[key] += 1
	var bubble := { "center": center, "radius": radius }
	_active_bubbles.append(bubble)

	var target_pos := img.position + Vector2(0, -1).rotated(img.rotation) * 20.0

	var float_tween := create_tween()
	float_tween.tween_property(img, "position", target_pos, DISPLAY_TIME) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var tween := create_tween()
	tween.tween_property(img, "scale", target_scale, 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(DISPLAY_TIME - 0.65)
	tween.tween_property(img, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		float_tween.kill()
		_active_counts[key] -= 1
		_active_bubbles.erase(bubble)
		img.queue_free()
	)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action("omt_toggle"):
		return
	# Input.is_action_pressed는 바인딩된 모든 입력의 현재 눌림 상태(집계값)
	var pressed := Input.is_action_pressed("omt_toggle")
	# 눌림이 처음 켜지는 순간(라이징 엣지)에만, 그리고 쿨다운이 지났을 때만 토글한다.
	# 아날로그 트리거를 천천히 당겨 임계값 근처에서 떨려도 한 번만 반응한다.
	if pressed and not _omt_toggle_held:
		var now := Time.get_ticks_msec()
		if now - _last_omt_toggle_ms >= _OMT_TOGGLE_COOLDOWN_MS:
			if _free_action and _free_action.is_event:
				omt_toggle_button.button_pressed = not omt_toggle_button.button_pressed
				_last_omt_toggle_ms = now
				get_viewport().set_input_as_handled()
	_omt_toggle_held = pressed

func _on_omt_toggle_button_toggled(toggled_on: bool) -> void:
	visible = toggled_on
	_update_state_label(TranslationServer.get_locale())
	MetaProgression.save_data["omt_enabled"] = toggled_on

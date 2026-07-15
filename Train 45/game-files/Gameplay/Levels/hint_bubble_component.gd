extends Control
class_name HintBubbleComponent

# 힌트 텍스트를 표시하는 RichTextLabel 노드
@export var hint_label: RichTextLabel
# 플레이어 진입을 감지하는 Area2D 노드
@export var hint_area: Area2D
# 글자가 나올 때마다 재생할 타이핑 효과음
@export var typing_sound: AudioStreamPlayer

# 텍스트 페이드 인/아웃에 사용하는 트윈 객체
var label_tween: Tween
# 층 전체를 관리하는 FloorManager 참조
var floor_manager: FloorManager

# 힌트 버블 활성화 여부 (현재 미사용)
var is_enable:= false

var _is_typing := false
var _prev_visible_chars := -1
var _sound_cooldown := 0.0

# 집사가 사람(인간) 형태일 때 힌트 버블을 위로 올리는 오프셋.
# 사람 형태에서는 TalkBubble이 idle(-145) → idle_2(-226)로 81px 위로 올라가므로
# (talk_bubble.gd 참고) 힌트 버블도 동일하게 올려 머리 위에 맞춘다.
const BUTLER_HUMAN_Y_OFFSET := -34.0

# 에디터에 배치된 기본 Y 위치 (집사 사람 형태 보정의 기준값)
var _base_position_y: float

func _ready() -> void:
	# 씬 트리에서 FloorManager를 찾아 참조 저장
	floor_manager = get_tree().get_first_node_in_group("floormanager")
	# 기본 Y 위치 저장 (집사 형태에 따라 보정할 때 기준으로 사용)
	_base_position_y = position.y
	_update_hint_badge(TranslationServer.get_locale())
	LanguageManager.lang_changed.connect(_update_hint_badge)
	# 초기에는 텍스트를 완전히 숨김 (visible_ratio 0 = 글자 없음)
	hint_label.visible_ratio = 0.0
	hide()

## Локализует жёстко заданный заголовок Hint! внутри пузыря.
func _update_hint_badge(locale: String) -> void:
	var badge := hint_label.get_node_or_null("NinePatchRect/Label") as Label
	if badge:
		badge.text = "Совет!" if locale.begins_with("ru") else "Hint!"

func _process(delta: float) -> void:
	if not _is_typing:
		return
	_sound_cooldown -= delta
	var cur := hint_label.visible_characters
	if cur != _prev_visible_chars:
		_prev_visible_chars = cur
		if cur > 0 and _sound_cooldown <= 0.0 and typing_sound:
			typing_sound.pitch_scale = randf_range(0.9, 1.1)
			typing_sound.play()
			_sound_cooldown = 0.05


func show_hint():
	if Dialogic.current_timeline:
		return
	if MetaProgression.get_current_chapter() < 2:
		# 집사가 없으면 힌트 대신 노션 알림으로 안내
		notify_no_butler()
		return

	# 이전 스테이지에서 실패한 경우의 힌트 문자열을 가져옴
	var before_hint:String = floor_manager.floor_hint_manager.get_before_stage_description()
	if before_hint != "":
		# 힌트 버블을 화면에 표시
		active_hint_bubble(before_hint)
		# 표시한 힌트를 실패 힌트로 기록 (다음 판단에 활용)
		floor_manager.floor_hint_manager.set_failed_stage_hint(before_hint)

func notify_no_butler():
	# 옵션에서 탐색 실패 힌트를 껐다면 노션 알림도 띄우지 않는다
	if not is_hint_bubble_enabled():
		return
	# 집사가 없는 챕터에서는 힌트 버블 대신 노션 알림으로 힌트를 출력
	var before_hint: String = floor_manager.floor_hint_manager.get_before_stage_description()
	if before_hint != "":
		floor_manager.floor_hint_manager.set_failed_stage_hint(before_hint)
		NotionEvent.notion("NOTI_WISPER_HINT", Constants.UNKNOWN_SD_ICON)
		await get_tree().create_timer(1.5).timeout
		NotionEvent.notion(before_hint, Constants.UNKNOWN_SD_ICON)


# 옵션 '게임' 탭에서 힌트 버블을 껐는지 여부. 기본값 켜짐(true).
# 일반/스테이지 힌트 버블 표시가 모두 active_hint_bubble로 모이므로 여기서 한 번에 막는다.
static func is_hint_bubble_enabled() -> bool:
	return ConfigFileHandler.config.get_value("gameplay", "hint_bubble_enabled", true)

func active_hint_bubble(before_hint: String):
	# 옵션에서 힌트 버블을 껐다면 표시하지 않는다
	if not is_hint_bubble_enabled():
		return
	# base 스테이지에서 집사가 사람 형태일 때만 TextBubble이 올라가는 만큼 힌트 버블도 위로 올림
	if _is_base_stage() and _is_butler_human():
		position.y = _base_position_y + BUTLER_HUMAN_Y_OFFSET
	else:
		position.y = _base_position_y
	show()
	hint_label.text = before_hint
	_prev_visible_chars = 0
	_is_typing = true
	# 1초에 걸쳐 텍스트를 서서히 나타냄 (visible_ratio 0 → 1)
	label_tween = create_tween()
	label_tween.tween_property(hint_label, "visible_ratio", 1.0, 2.0).from(0.0)
	label_tween.tween_callback(func(): _is_typing = false)
	# 8초 동안 힌트를 유지
	await get_tree().create_timer(8.0).timeout
	# 0.3초에 걸쳐 텍스트를 서서히 사라지게 함 (visible_ratio 1 → 0)
	label_tween = create_tween()
	label_tween.tween_property(hint_label, "visible_ratio", 0.0, 0.3)
	# 페이드 아웃 완료 후 Control 노드 자체를 숨김
	label_tween.tween_callback(hide)

func _is_butler_human() -> bool:
	# 집사가 사람(인간) 형태인지 여부. npc.gd의 idle_2 전환 조건과 동일.
	return MetaProgression.has_read_event("chapter4_butler3")

func _is_base_stage() -> bool:
	# 현재 레벨이 base 스테이지인지 여부.
	return floor_manager != null \
		and floor_manager.current_level != null \
		and floor_manager.current_level.stage_type == Constants.TYPE_BASE

func _on_hint_area_body_entered(body: Node2D) -> void:
	# 진입한 오브젝트가 플레이어일 때만 힌트 표시
	if body is Player:
		show_hint()
		# 중복 감지 방지: 힌트 표시 후 Area2D 모니터링 비활성화
		hint_area.call_deferred("set_monitoring", false)

extends Sprite2D
class_name TalkBubble

var owner_npc: Npc
var tween: Tween
@onready var new_label: Label = $NewLabel

var npc_data := NpcData.new()
var partner_manager : PartnerManager
var floor_manager : FloorManager

func _ready() -> void:
	owner_npc = get_parent() as Npc
	partner_manager = get_tree().get_first_node_in_group("partnermanager")
	floor_manager = get_tree().get_first_node_in_group("floormanager") as FloorManager
	new_label.hide()
	_update_new_label(TranslationServer.get_locale())
	LanguageManager.lang_changed.connect(_update_new_label)
	hide()
	scale = Vector2.ZERO

## Локализует жёстко заданную в сцене метку NEW, не меняя остальные языки.
func _update_new_label(locale: String) -> void:
	new_label.text = "НОВОЕ" if locale.begins_with("ru") else "NEW"

## 애니메이션이 변경될 때 말풍선 위치를 재조정
func set_bubble_position():
	var y: int
	var current_anim: String = owner_npc.animation_player.current_animation
	match owner_npc.npc_name:
		Constants.NPC_OL:
			match current_anim:
				"idle", "idle_anomaly1", "idle_anomaly2", "idle_anomaly3", "idle_anomaly4": y = -226
				"find1": y = -123
				"find2", "find_anomaly1": y = -200
				"find3", "find_anomaly2": y = -129
				"chibi_idle": y = -100
		Constants.NPC_GYARU:
			match current_anim:
				"idle", "idle_anomaly1", "idle_anomaly2", "idle_anomaly3", "idle_anomaly4": y = -226
				"find1", "find_anomaly1": y = -226
				"find2", "find_anomaly2": y = -126
				"find3": y = -191
				"chibi_idle": y = -100
		Constants.NPC_KONIAL:
			match current_anim:
				"idle": y = -226
				"bind": y = -166
		Constants.NPC_BUTLER:
			match current_anim:
				"idle": y = -145
				"idle_2": y = -226
	
	position.y = y

func is_show(state: bool):
	if tween:
		tween.kill()
	if state:
		check_new_talk()
		show()
		tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ONE, 0.5)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	else:
		tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ZERO, 0.2)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(hide)

## 새로운 대화가 있는지 확인
func check_new_talk():
	var current_partner = partner_manager.partner[owner_npc.npc_name] as Npc

	if floor_manager.current_level == null:
		return

	var has_new := npc_data.new_read_event(current_partner)

	# 코니알은 npc_info에 등록된 일반 대화 외에 konial_talk1 전용 조건을 추가 체크.
	# 다이얼로그 조건(npc.love == 1)이 정확히 1일 때만 유효하므로 별도 처리.
	if owner_npc.npc_name == Constants.NPC_KONIAL:
		if MetaProgression.has_read_event("konial_love_1") \
		and not MetaProgression.has_read_event("konial_talk1"):
			has_new = true

	if has_new \
	and floor_manager.current_level.stage_type == Constants.TYPE_BASE \
	and floor_manager.current_level.prologue_stage == false:
		new_label.show()
	else:
		new_label.hide()

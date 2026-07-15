## 스테이지 전용 힌트 버블 컴포넌트.
## [HintBubbleComponent]를 상속하며, 영역 진입이 아닌 [method show_stage_hint]로 직접 활성화한다.
extends HintBubbleComponent
class_name StageHintBubbleComponent

## 초기화 — [FloorManager]를 탐색하고 힌트 라벨을 숨긴 상태로 설정한다.
func _ready() -> void:
	floor_manager = get_tree().get_first_node_in_group("floormanager")
	_base_position_y = position.y
	_update_hint_badge(TranslationServer.get_locale())
	LanguageManager.lang_changed.connect(_update_hint_badge)
	hint_label.visible_ratio = 0.0
	hide()

## [param stage_hint] 텍스트로 힌트 버블을 표시한다.
func show_stage_hint(stage_hint: String):
	active_hint_bubble(stage_hint)

## 부모 클래스의 영역 진입 콜백을 비활성화하기 위해 빈 오버라이드.
func _on_hint_area_body_entered(_body: Node2D) -> void:
	pass

## 재사용 가능한 확인 다이얼로그 박스 컴포넌트.
## [br][br]
## [method customize]로 제목, 설명, 버튼 텍스트를 설정하고,
## [method prompt]를 [code]await[/code]하여 사용자의 확인/취소 결과를 [code]bool[/code]로 받는다.
## 체이닝 패턴을 지원하여 [code]await confirm_box.customize(...).prompt()[/code] 형태로 사용할 수 있다.
class_name ConfirmBox extends CanvasLayer

## 모달의 확인 상태를 [param is_confirmed] 불리언으로 전달하는 시그널.
signal confirmed(is_confirmed: bool)


## 헤더(제목) 텍스트를 표시하는 [Label] 노드.
@onready var header_label: Label = %HeaderLabel
## 본문 메시지를 표시하는 [Label] 노드.
@onready var message_label: Label = %MessageLabel
## 부제목(영문 헤더)을 표시하는 [Label] 노드.
@onready var header_eng_label: Label = %SubMessageLabel
## 확인 버튼 [Button] 노드.
@onready var confirm_button: Button = %ConfirmButton
## 취소 버튼 [Button] 노드.
@onready var cancel_button: Button = %CancelButton
@onready var confirm_sub_label: Label = $Panel/ConfirmButton/SubMessageLabel2
@onready var cancel_sub_label: Label = $Panel/CancelButton/SubMessageLabel3
## 모달 열림/닫힘 애니메이션을 재생하는 [AnimationPlayer].
@onready var animation_player = $Panel/AnimationPlayer


## 모달이 현재 열려 있는지 추적하는 변수.
var is_open: bool = false

# Internal variable tracking if we should unpause after closing the modal.
var _should_unpause: bool = false


# Internal ready function for setup.
func _ready() -> void:
	if confirm_button:
		confirm_button.pressed.connect(_on_confirm_button_pressed)
	if cancel_button:
		cancel_button.pressed.connect(_on_cancel_button_pressed)
	hide()


# Internal handler for key input.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc") and is_open:
		cancel()
		get_viewport().set_input_as_handled()


## 확인 모달을 표시하고 사용자의 확인/취소 응답을 기다린다.[br]
## [br]
## [param pause]가 [code]true[/code]이면 모달이 열릴 때 게임을 일시정지하고,
## 닫힐 때 자동으로 해제한다. 반환값은 확인 시 [code]true[/code], 취소 시 [code]false[/code].[br]
## [br]
## 사용 예시:
## [codeblock]
## func _on_quit_button_pressed() -> void:
##     var conf = ConfirmationModalScene.instantiate()
##     var confirmed = await conf.customize(
##         "정말요?",
##         "Are You Sure?",
##         "게임을 종료하고 데스크톱으로 돌아갑니다.",
##         "종료"
##     ).prompt()
##     if confirmed:
##         get_tree().quit()
## [/codeblock]
func prompt(pause: bool = false) -> bool:
	_should_unpause = get_tree().paused == false and pause
	if pause:
		get_tree().paused = true
	
	animation_player.stop()
	animation_player.play("in")
	show()
	is_open = true
	# Panel을 씬에서 항상 visible로 두어 버튼이 즉시 visible_in_tree가 되므로,
	# grab한 포커스가 어떤 입력(패드 상시 노이즈 등)이 와도 풀리지 않는다.
	# (혹시 위치가 한 프레임 번쩍이면 play 직후 animation_player.seek(0.0, true)를 추가)
	cancel_button.call_deferred("grab_focus")
	var is_confirmed = await confirmed
	return is_confirmed


## 확인 모달의 텍스트를 커스터마이즈한다.[br]
## [br]
## [param header]는 헤더 텍스트, [param header_eng]는 영문 부제목,
## [param message]는 본문 메시지를 설정한다.
## 선택적으로 [param confirm_text]와 [param cancel_text]로 버튼 텍스트를 변경할 수 있다.[br]
## [br]체이닝을 위해 자기 자신([ConfirmBox])을 반환한다.
func customize(header: String, header_eng: String, message: String, confirm_text: String = "Yes", cancel_text: String = "No") -> ConfirmBox:
	var is_russian := TranslationServer.get_locale().begins_with("ru")
	header_label.text = header
	header_eng_label.text = _localized_subtitle(header_eng)
	message_label.text = message
	confirm_button.text = confirm_text
	cancel_button.text = cancel_text
	# Английские декоративные подписи под кнопками дублируют русский основной текст.
	confirm_sub_label.visible = not is_russian
	cancel_sub_label.visible = not is_russian
	cancel_button.grab_focus()
	return self


## Локализует декоративный английский подзаголовок подтверждения, который не проходит через tr().
func _localized_subtitle(value: String) -> String:
	if not TranslationServer.get_locale().begins_with("ru"):
		return value
	return {
		"Exit": "Выход",
		"Overwrite": "Перезапись",
		"Replay": "Повтор",
		"Return": "Возврат",
		"Unlock": "Открытие",
	}.get(value, value)


## 모달을 닫고 [param is_confirmed] 불리언 값에 따라 확인 또는 취소 처리한다.
func close(is_confirmed: bool = false) -> void:
	if is_confirmed:
		confirm()
	else:
		cancel()


## 확인을 선택하고 모달을 닫는다.
func confirm() -> void:
	_close_modal(true)


## 확인을 취소하고 모달을 닫는다.
func cancel() -> void:
	_close_modal(false)


# Internal function to close the modal and cleanup
func _close_modal(is_confirmed: bool) -> void:
	confirmed.emit(is_confirmed)
	set_deferred("is_open", false)
	hide()
	if _should_unpause:
		get_tree().paused = false


# Internal handler for the confirm button being pressed.
func _on_confirm_button_pressed() -> void:
	confirm()


# Internal handler for the cancel button being pressed.
func _on_cancel_button_pressed() -> void:
	cancel()

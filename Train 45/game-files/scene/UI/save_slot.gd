## 세이브/로드 슬롯 버튼 컴포넌트.
## [br][br]
## 각 슬롯은 저장 데이터의 챕터명, 날짜, 플레이타임 등을 표시하며,
## [member mode]에 따라 저장 또는 불러오기 동작을 수행한다.
## 덮어쓰기 시 [ConfirmBox]를 통해 사용자 확인을 거친다.
extends Button
class_name SaveSlot

## 슬롯 저장이 완료되었음을 알리는 시그널.
signal slot_save_update

## 저장 정보(챕터, 날짜 등)를 표시하는 [Control] 노드.
@export var save_info_node : Control
## 덮어쓰기 확인에 사용하는 [ConfirmBox].
@onready var confirm_box = $ConfirmBox
## "저장하기" / "불러오기" 텍스트를 표시하는 노드.
@onready var save_confirm = %SaveConfirm
## 슬롯 선택 애니메이션을 재생하는 [AnimationPlayer].
@onready var animation_player = $AnimationPlayer
## 포커스/클릭 시 랜덤 효과음을 재생하는 [AudioStreamPlayer].
@onready var random_stream_player: AudioStreamPlayer = $RandomStreamPlayerGlobalComponent


## 슬롯 번호를 표시하는 노드 (오토세이브 슬롯은 "AUTO SAVE" 텍스트).
@onready var count = %Count
## 저장된 챕터 제목을 표시하는 [Label].
@onready var chapter_title: Label = %ChapterTitle
## 저장 날짜를 표시하는 노드.
@onready var save_date = %SaveDate
## 저장 시간을 표시하는 노드.
@onready var save_time = %SaveTime
## 플레이타임을 표시하는 노드.
@onready var play_time = %PlayTime
## 엔딩 클리어 여부를 표시하는 [Label].
@onready var clear_lable: Label = %ClearLable

## 이 슬롯의 번호 (인덱스).
var slot_num : int
## 현재 동작 모드. [code]"save"[/code] 또는 [code]"load"[/code].
var mode : String
## 이 슬롯에 저장된 데이터 딕셔너리.
var save_info : Dictionary = {}

## 슬롯 초기화. 저장 정보를 불러오고 확인 텍스트를 설정한다.
func _ready():
	save_info_node.hide()
	save_confirm.hide()
	slot_info_load()
	set_confirm_text()
	if is_auto_slot():
		var auto_index = slot_num - Constants.AUTO_SAVE_INDEX + 1
		count.text = _auto_slot_text(auto_index, TranslationServer.get_locale())
		count.add_theme_font_size_override("font_size", 9)
		count.add_theme_constant_override("line_spacing", -2)
		count.add_theme_constant_override("outline_size", 1)
	else:
		count.text = str(slot_num+1)
	_update_static_locale_text(TranslationServer.get_locale())
	LanguageManager.lang_changed.connect(_update_static_locale_text)

## Локализует две жёстко заданные служебные метки слота без изменения формата сохранений.
func _update_static_locale_text(locale: String) -> void:
	clear_lable.text = "ФИНАЛ" if locale.begins_with("ru") else "Clear"
	if is_auto_slot():
		var auto_index = slot_num - Constants.AUTO_SAVE_INDEX + 1
		count.text = _auto_slot_text(auto_index, locale)

func _auto_slot_text(auto_index: int, locale: String) -> String:
	var title := "АВТО" if locale.begins_with("ru") else "AUTO"
	return title + "\n%d" % auto_index
	
## 버튼 다운 이벤트 핸들러 (미사용).
func _on_button_down():
	pass
## 슬롯 버튼 토글 시 [member mode]에 따라 저장 또는 로드를 수행한다.[br]
## 저장 모드에서 기존 데이터가 있으면 [ConfirmBox]로 덮어쓰기 확인을 요청한다.
func _on_toggled(toggled_on):
	if is_auto_slot() and mode == "save":
		return
	if toggled_on or not has_focus():
		save_confirm.show()
		return
		
	if mode == "save":
		if save_info:
			confirm_box.customize(
				"SAVE_OVERLAP",
				"Overwrite",
				"SAVE_OVERLAP_DESCRIPTION",
				"YES",
				"NO"
			)
			var is_confirmed = await confirm_box.prompt(true)
			if is_confirmed:
				slot_save()
			grab_focus()
		else:
			slot_save()
	elif mode == "load":
		slot_load()
		
	save_confirm.hide()


## 포커스 진입 시 선택 애니메이션과 효과음을 재생한다.
func _on_focus_entered():
	animation_player.play("select")
	random_stream_player.play_random()
	
## 포커스 해제 시 애니메이션을 리셋하고 확인 UI를 숨긴다.
func _on_focus_exited():
	animation_player.play("RESET")
	button_pressed = false
	save_confirm.hide()


## 슬롯 버튼 클릭 시 효과음을 재생한다.
func _on_pressed():
	random_stream_player.play_random()


## 현재 게임 상태를 이 슬롯에 저장한다. 오토세이브 슬롯에는 수동 저장이 불가능하다.
func slot_save():
	if is_auto_slot(): # 오토세이브 슬롯일 경우 이 슬롯에 수동저장 안됨
		return
		
	MetaProgression.game_save(slot_num)
	slot_info_load()
	slot_save_update.emit()

## 이 슬롯의 저장 데이터를 불러와 게임을 재개한다.[br]
## 빈 슬롯이면 무시하고, 현재 씬에 따라 씬 전환 또는 리로드를 수행한다.
func slot_load():
	MetaProgression.load_save_file(slot_num)
	var scene_name = get_tree().current_scene.name
	if not save_info:
		print("Slot is empty")
		return
	
	set_focus_mode(Control.FOCUS_NONE)
	TransitionScreen.transition()
	await TransitionScreen.on_transition_finishied
	if scene_name != "Gameplay":
		get_tree().change_scene_to_file("res://Gameplay/gameplay.tscn")
	else:
		get_tree().reload_current_scene()

## [MetaProgression]에서 이 슬롯의 저장 데이터를 읽어 UI에 반영한다.[br]
## 챕터 제목, 저장 날짜/시간, 플레이타임, 엔딩 클리어 여부 등을 표시한다.
func slot_info_load():
	save_info = MetaProgression.get_slot_save_data(slot_num)
	if save_info.has("last_save_date"):
		text = ""
		if save_info.has("chapter"):
			chapter_title.text = get_chapter_title(save_info["chapter"])
			#chapter_title.text = 
		if save_info["last_save_date"].has("year"):
			save_date.text = "%04d/%02d/%02d"% [
				save_info["last_save_date"]["year"],
				save_info["last_save_date"]["month"],
				save_info["last_save_date"]["day"],
				]
			save_time.text = "%02d:%02d" % [
				save_info["last_save_date"]["hour"],
				save_info["last_save_date"]["minute"]
			]
		if save_info.has("play_time"):
			play_time.text = Time.get_time_string_from_unix_time(save_info["play_time"])
		
		if save_info.has("is_ending"):
			if save_info["is_ending"] == true:
				clear_lable.show()
			else:
				clear_lable.hide()
		
		save_info_node.show()
		

## [member mode]에 따라 확인 버튼 텍스트를 "SAVE_GAME" 또는 "LOAD_GAME"으로 설정한다.
func set_confirm_text():
	if mode == "save":
		save_confirm.text = "SAVE_GAME"
	elif mode == "load":
		save_confirm.text = "LOAD_GAME"

## [param chapter] 번호에 해당하는 챕터 제목 문자열을 반환한다.
func get_chapter_title(chapter: int)-> String:
	var chapter_data : ChapterInfo
	chapter_data = ChapterInfo.new()
	return chapter_data.get_chapter_title(chapter)

## 이 슬롯이 오토세이브 슬롯인지 반환한다.
func is_auto_slot()-> bool:
	return slot_num >= Constants.AUTO_SAVE_INDEX \
		and slot_num < Constants.AUTO_SAVE_INDEX + Constants.AUTO_SAVE_SLOT_COUNT

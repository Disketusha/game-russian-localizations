## 메인 메뉴 화면을 관리하는 루트 스크립트.
## 로고 인트로 재생, 버튼 네비게이션, 옵션/로드/회상방 진입 등을 담당한다.
extends Node2D

const TITLE_TEXTURES := {
	"ko": "res://resources/ui/title_kr.png",
	"jp": "res://resources/ui/title_jp.png",
	"zh": "res://resources/ui/title_zh.png",
	"cn": "res://resources/ui/title_cn.png",
	"en": "res://resources/ui/title_en.png",
	"ru": "res://resources/ui/title_ru.png",
}

## 인트로 애니메이션이 종료되었는지 여부. [code]false[/code]면 버튼 입력을 무시한다.
var intro_end:= false
## 게임 실행 후 최초 메인메뉴 진입 여부.
static var _intro_played := false

## 옵션 메뉴 [PackedScene].
@export var option_menu : PackedScene
## 로드 메뉴 [PackedScene].
@export var load_menu : PackedScene
## 회상방(Recollection) 진입 버튼.
@export var recollect_button: Button
## 종료 확인용 [ConfirmBox].
@export var confirm_box: ConfirmBox


## 게임 시작(Play) 버튼.
@onready var play = $CanvasLayer/MarginContainer/VBoxContainer/Play
## 로드(Load) 버튼. 세이브 데이터가 없으면 숨긴다.
@onready var load_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/Load
## 보이스 QA 뷰어 진입 버튼. 디버그 빌드에서만 노출한다.
@onready var qa_button: Button = $CanvasLayer/MarginContainer/VBoxContainer/QA

## 메인 메뉴 버튼들을 담고 있는 [VBoxContainer].
@onready var button_container: VBoxContainer = %VBoxContainer

## 로고 연출용 [CanvasLayer].
@onready var logo_canvas_layer: CanvasLayer = $LogoCanvasLayer
## 로고 애니메이션 [AnimationPlayer].
@onready var logo_anim: AnimationPlayer = $LogoCanvasLayer/LogoAnim

## 일반 메인 메뉴 배경(클리어 전).
@onready var train_main_menu: TrainBackGround = %TrainMainMenu
## 엔딩 클리어 후 메인 메뉴 배경.
@onready var train_ending: TrainBackGround = %TrainEnding
## 버전 정보 표시용 [Label].
@onready var ver_label: Label = %Ver
@onready var title_texture_rect: TextureRect = $CanvasLayer2/TextureRect


## 초기화 — 버전 라벨 설정, 인트로 재생, 세이브 데이터 확인, 회상방 잠금 해제 여부 처리.
func _ready():
	var version: String = ProjectSettings.get_setting("application/config/version")
	ver_label.text = "v" + version
	LanguageManager.lang_changed.connect(_apply_title_texture)
	_apply_title_texture(LanguageManager.get_current_locale())
	
	# 출시(익스포트) 빌드에서는 보이스 QA 뷰어 진입 버튼을 숨긴다.
	if not OS.is_debug_build():
		qa_button.hide()

	logo_anim.animation_finished.connect(_on_anim_finished)
	if not Constants.INTRO_SKIP and not _intro_played:
		_intro_played = true
		set_buttons_disable(true)
		logo_anim.play("logo")
	else:
		if Constants.INTRO_SKIP:
			push_error("intro skip 상태입니다.")
		logo_anim.play("RESET")
		set_intro_end()
	
	MetaProgression.new_game()
	
	if MetaProgression.has_anyone_save_data():
		load_button.show()
	else:
		load_button.hide()
	
	#회상방 잠금
	if MetaProgression.is_unlock_recollect():
		#클리어 상태에 따라 배경화면 변경
		train_main_menu.hide()
		train_ending.show()
		
		recollect_button.show()
	else:
		#클리어 상태에 따라 배경화면 변경
		train_main_menu.show()
		train_ending.hide()
		
		recollect_button.hide()
	
	## 메인 화면으로 복귀할 때 이전 스테이지 플래그를 초기화한다.
	GameEvents.is_recollection_room = false
	GameEvents.is_epilogue_room = false

## Play 버튼이 눌리면 트랜지션 후 게임플레이 씬으로 전환한다.
func _on_play_pressed():
	if not intro_end:
		return
	
	disable_input() # 입력 비활성화
	TransitionScreen.transition()
	await TransitionScreen.on_transition_finishied
	get_tree().change_scene_to_file("res://Gameplay/gameplay.tscn")

## Load 버튼이 눌리면 로드 메뉴를 인스턴스화하여 표시한다.
func _on_load_pressed():
	if not intro_end:
		return
	
	var load_instance = load_menu.instantiate()
	load_instance.set_mode("load")
	add_child(load_instance)
	load_instance.tree_exited.connect(on_option_exit)

## 회상방 버튼이 눌리면 회상 모드 플래그를 설정한 뒤 게임플레이 씬으로 전환한다.
func _on_recollect_pressed() -> void:
	if not intro_end:
		return
	
	GameEvents.is_recollection_room = true
	disable_input() # 입력 비활성화
	TransitionScreen.transition()
	await TransitionScreen.on_transition_finishied
	get_tree().change_scene_to_file("res://Gameplay/gameplay.tscn")

## 옵션 버튼이 눌리면 옵션 메뉴를 인스턴스화하여 표시한다.
func _on_option_pressed():
	if not intro_end:
		return
	
	var option_instance = option_menu.instantiate()
	option_instance.tree_exited.connect(on_option_exit)
	add_child(option_instance)

## QA 버튼이 눌리면 보이스 QA 뷰어를 열어 음성 파일을 확인할 수 있다.
func _on_qa_pressed() -> void:
	if not intro_end:
		return
	var qa_scene := load("res://Gameplay/qa/voice_qa_viewer.tscn") as PackedScene
	add_child(qa_scene.instantiate())

## 종료 버튼이 눌리면 [member confirm_box]로 확인을 받은 뒤 게임을 종료한다.
func _on_exit_pressed():
	if not intro_end:
		return
	
	confirm_box.customize(
	"SYSTEM_EXIT_CONFIRM",
	"Exit",
	"SYSTEM_EXIT_CONFIRM_DESCRIPTION",
	"YES",
	"NO"
	)
	var is_confirmed = await confirm_box.prompt(true)
	if is_confirmed:
		get_tree().quit()
	else:
		_grab_first_button()

## 옵션/로드 메뉴가 닫힌 뒤 포커스를 첫 번째 버튼으로 복원한다.
func on_option_exit():
	if not intro_end:
		return
	
	_grab_first_button()
	

## 씬 전환 중 Play 버튼의 포커스를 제거하여 추가 입력을 방지한다.
func disable_input():
	play.set_focus_mode(Control.FOCUS_NONE)


## 로고 애니메이션 종료 콜백. [code]"logo"[/code] 애니메이션이 끝나면 인트로 완료 처리를 한다.
func _on_anim_finished(anim_name: String):
	if anim_name == "logo":
		set_intro_end()

## 인트로 종료 상태를 설정하고 버튼 활성화 + 포커스 + 로고 레이어 해제를 수행한다.
func set_intro_end():
	intro_end = true
	set_buttons_disable(false)
	_grab_first_button()
	
	logo_canvas_layer.queue_free()

## 버튼 컨테이너 내 모든 버튼의 [code]disabled[/code] 상태를 [param state]로 일괄 설정한다.
func set_buttons_disable(state: bool):
	for i in button_container.get_children():
		var _button = i as Button
		_button.disabled = state

## 버튼 컨테이너에서 보이는 첫 번째 버튼에 포커스를 부여한다.
func _grab_first_button():
	for i in button_container.get_children():
		var current_button: Button = i
		if current_button.visible and current_button.is_inside_tree():
			current_button.grab_focus()
			break


func _apply_title_texture(locale: String) -> void:
	var path: String = TITLE_TEXTURES.get(locale, TITLE_TEXTURES["en"])
	var texture: Texture2D = load(path)
	if texture:
		title_texture_rect.texture = texture

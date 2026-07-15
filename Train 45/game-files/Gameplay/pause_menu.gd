## 일시정지 메뉴 UI.
## 게임을 일시정지하고 재개, 저장, 불러오기, 옵션, 메인 메뉴 복귀 기능을 제공한다.
extends Control
class_name PauseMenu

signal exit_pause_menu
signal sub_menu_closed

## 일시정지 메뉴 사운드 재생용 [UiSoundStreamPlayer].
@onready var pause_menu_stream_player: UiSoundStreamPlayer = $PauseMenuStreamPlayer

## 옵션 메뉴 씬.
@export var option_menu: PackedScene
## 저장/불러오기 메뉴 씬.
@export var save_load_menu: PackedScene
## 도움말 씬
@export var help_book: PackedScene
@onready var help_button: Button = %HelpButton
## Заголовок листа для заметок. В исходной сцене это непереводимая строка `NOTE`.
@onready var note_title: Label = $CanvasLayer/NotePaper/Label


## 저장 버튼 노드.
@onready var save_button = %Save
## 현재 [FloorManager] 참조.
var floor_manager : FloorManager
## 확인 다이얼로그 박스.
@onready var confirm_box = $ConfirmBox

## 메뉴 패널 컨테이너.
@onready var panel = $CanvasLayer/Panel
## 게임 재개 버튼.
@onready var resume: Button = %Resume
## 패널 애니메이션 플레이어.
@onready var animation_player = $CanvasLayer/Panel/AnimationPlayer
## 퀘스트 아이콘 텍스처.
@onready var quest_rect: TextureRect = %QuestRect
## 퀘스트 설명 라벨.
@onready var quest_label: Label = %QuestLabel

## 일시정지 메뉴를 초기화한다.
## 윈도우 상태를 설정하고, 진입 애니메이션을 재생하며, 저장 버튼 활성화 여부를 결정한다.
func _ready():
	GameEvents.set_window_state(Constants.WINDOW_STATE_PAUSE_MENU, true)
	pause_menu_stream_player.set_stream_play_to_file(UiSoundStreamPlayer.SOUND_MENU_IN)
	animation_player.play("in")
	floor_manager = get_tree().get_first_node_in_group("floormanager") as FloorManager
	var save_button_color := Color.WHITE
	if floor_manager and floor_manager.current_stage_type == Constants.TYPE_BASE and \
		!floor_manager.current_prologue:
		save_button.disabled = false
	else:
		save_button.disabled = true
		save_button_color = Color.WEB_GRAY


	#버튼 활성화 여부에 따른 색 변경
	var save_button_parent = save_button.get_parent() as TextureRect
	save_button_parent.modulate = save_button_color
	
	pause_game(true)
	resume.call_deferred("grab_focus")
	help_button.visible = _has_any_read_tuto()
	help_button.pressed.connect(func(): _instantiate_menu(help_book))
	_update_note_title(TranslationServer.get_locale())
	LanguageManager.lang_changed.connect(_update_note_title)
	
	set_quest_label()

## Сохраняет исходный английский заголовок для остальных локалей и локализует его в русской.
func _update_note_title(locale: String) -> void:
	note_title.text = "ЗАМЕТКИ" if locale.begins_with("ru") else "NOTE"

## ESC 키 입력 시 일시정지 메뉴를 닫는다. (노트 편집 중이면 노트 포커스만 해제)
func _input(event):
	if GameEvents.get_window_state(Constants.WINDOW_STATE_BUG_REPORTER):
		return
	if event.is_action_pressed("esc"):
		if %NoteText.has_focus():
			# [KR] 노트 편집 중: 메뉴를 닫지 않고 노트에서만 빠져나온다
			%NoteText.release_focus()
			resume.grab_focus()
			get_viewport().set_input_as_handled()
		else:
			_on_resume_pressed()
	elif event.is_action_pressed("note_focus") and not %NoteText.has_focus():
		# [KR] 패드 Y/Shift: 노트로 포커스 이동 (편집 중엔 무시 → Shift 대문자 입력 보존)
		%NoteText.grab_focus()
		get_viewport().set_input_as_handled()

## 게임 재개 버튼이 눌렸을 때 메뉴 닫기 애니메이션을 재생한다.
func _on_resume_pressed():
	pause_menu_stream_player.set_stream_play_to_file(UiSoundStreamPlayer.SOUND_MENU_OUT)
	exit_pause_menu.emit()
	animation_player.play("out")

## 저장 버튼 콜백. 저장 메뉴를 연다.
func _on_save_pressed():
	_instantiate_menu(save_load_menu, "save")

## 불러오기 버튼 콜백. 불러오기 메뉴를 연다.
func _on_load_pressed():
	_instantiate_menu(save_load_menu, "load")

## 옵션 버튼 콜백. 옵션 메뉴를 연다.
func _on_option_pressed():
	_instantiate_menu(option_menu)

## [param menu_scene]을 인스턴스화하여 자식으로 추가한다.
## [param mode]가 지정되면 [method set_mode]를 호출하여 메뉴 모드를 설정한다.
func _instantiate_menu(menu_scene: PackedScene, mode: String = ""):
	#panel.visible = false
	var menu_instance = menu_scene.instantiate()
	
	if mode != "":
		menu_instance.set_mode(mode)
	
	add_child(menu_instance)
	menu_instance.tree_exited.connect(on_menu_exit)

## 하위 메뉴가 트리에서 빠져나왔을 때 패널을 다시 표시하고 포커스를 복원한다.
func on_menu_exit():
	if is_inside_tree():
		panel.visible = true
		resume.grab_focus()
		sub_menu_closed.emit()

## 메인 메뉴로 나가기 버튼 콜백. 확인 다이얼로그를 표시하고, 수락 시 메인 메뉴 씬으로 전환한다.
func _on_main_exit_pressed():
	confirm_box.customize(
	"EXIT_CONFIRM",
	"Exit",
	"EXIT_CONFIRM_DESCRIPTION",
	"YES",
	"NO"
	)
	var is_confirmed = await confirm_box.prompt(true)
	if is_confirmed:
		DropItem.exiting_to_menu = true # 씬 해체 중 드롭아이템 _exit_tree 보상 발사 방지
		get_tree().change_scene_to_file("res://Gameplay/main_menu.tscn")
	else:
		resume.grab_focus()

## [param pause]가 [code]true[/code]이면 게임을 일시정지하고, [code]false[/code]이면 재개한다.
func pause_game(pause: bool):
	get_tree().paused = pause
	if pause:
		Engine.time_scale = 1.0
	else:
		Engine.time_scale = 1.0

## 트리에서 제거될 때 윈도우 상태를 해제하고 일시정지를 풀어준다.
func _exit_tree():
	GameEvents.set_window_state(Constants.WINDOW_STATE_PAUSE_MENU, false)
	pause_game(false)

## 읽은 튜토리얼이 하나라도 있는지 확인한다.
func _has_any_read_tuto() -> bool:
	if Constants.TUTORIAL_BOOK_TEST:
		return true
	var valid_tuto_ids: Array = TrainUtil.get_res_from_path("res://Gameplay/GameData/Tutorials/") \
		.filter(func(r): return r is Tutos and r.id != "") \
		.map(func(r): return r.id)
	return MetaProgression.get_read_event().any(func(e): return valid_tuto_ids.has(e))

## 현재 퀘스트 라벨 텍스트를 설정한다.
func set_quest_label():
	#var chapter_info := ChapterInfo.new()
	#var current_chapter_data = chapter_info.get_current_chapter_data() as Dictionary
	#quest_label.text = current_chapter_data["description"]
	pass

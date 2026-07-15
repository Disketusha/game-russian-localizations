extends Control
## 옵션/설정 메뉴 화면.
## [br]언어·해상도·전체화면·볼륨 등의 설정을 변경할 수 있다.
## 탭 컨테이너로 화면/볼륨 설정을 구분하며, 변경 사항은 [code]ConfigFileHandler[/code]에 즉시 저장된다.

## 언어 선택 드롭다운.
@onready var option_button = %OptionButton
## 전체화면 토글 버튼.
@onready var full_screen_button = %FullScreen
## 조명 품질 토글 버튼.
@onready var lighting_button: CheckBox = %LightingQuality
## 해상도 선택 드롭다운.
@onready var resolution_button = %Resolution
## 현재 포커스된 UI 요소를 강조하는 사각형.
@export var focus_rect : NinePatchRect
@onready var animation_player = $CanvasLayer/Panel/AnimationPlayer
@onready var ui_stream_player: UiSoundStreamPlayer = $UiStreamPlayer
@onready var ui_button_stream_player: UiSoundStreamPlayer = $UiButtonStreamPlayer
## 화면/볼륨 탭 컨테이너.
@onready var tab_container: TabContainer = %TabContainer
## 음성 언어 선택 드롭다운.
@onready var vo_option_button: OptionButton = %VOOptionButton
## 마스터 음성 볼륨 슬라이더. (언어 잠금 시 볼륨 탭 포커스 대상)
@onready var master_vo_slider: HSlider = %MasterVoSlider
## 방송 주기 선택 드롭다운. (방송 탭이 아직 없을 수 있어 null 허용)
@onready var broadcast_option: OptionButton = get_node_or_null("%BroadcastOption")
## 힌트 버블 표시 토글. (게임 탭이 아직 없을 수 있어 null 허용)
@onready var hint_bubble_toggle: CheckBox = get_node_or_null("%HintBubbleToggle")
## CRT 필터 강도 슬라이더. (게임 탭이 아직 없을 수 있어 null 허용)
@onready var crt_filter_slider: HSlider = get_node_or_null("%CRTFilterSlider")
## 각 언어별 타이틀 라벨 배열.
@export var title_labels: Array[Label]

## 방송 탭 OptionButton 항목 id ↔ 저장 모드 문자열 매핑.
## 항목 id: 표준=0, 길게=1, 끄기=2 (train_broadcast의 INTERVAL_MODE_* 와 일치)
const BROADCAST_MODE_BY_ID := {0: "standard", 1: "long", 2: "off"}
const BROADCAST_ID_BY_MODE := {"standard": 0, "long": 1, "off": 2}
const LANGUAGE_ID_BY_LOCALE := {"ko": 0, "jp": 1, "zh": 2, "cn": 3, "en": 4, "ru": 5}
const RUSSIAN_LANGUAGE_ID := 5

## 대화 중 열렸을 때 언어 변경을 막을지 여부. (인스턴스화 직후 외부에서 설정)
var language_locked: bool = false

## 지원 해상도 딕셔너리. [code]"표시 텍스트" : Vector2i[/code] 형태.
const RESOLUTION_DICTIONARY : Dictionary = {
	"1280 x 720" : Vector2i(1280,720),
	"1366 x 768" : Vector2i(1366,768),	
	"1920 x 1080" : Vector2i(1920,1080),
	"2560 x 1440" : Vector2i(2560,1440),
	"3840 x 2160" : Vector2i(3840,2160)
}

## 진입 애니메이션을 재생하고, 저장된 비디오 설정으로 UI를 초기화한다.
func _ready():
	animation_player.play("in")
	# 애니메이션 중 포커스된 UI(드롭다운 등)에 키 입력이 적용되는 것을 방지
	animation_player.animation_started.connect(func(_n): get_viewport().gui_release_focus())
	ui_stream_player.set_stream_play_to_file(UiSoundStreamPlayer.SOUND_OPTION_PAGE_IN)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	
	_tab_title_update()

	# 에디터에서 다른 탭을 보이게 둔 채 저장돼도, 실행 시엔 항상 첫 탭(ScTab)부터 표시
	tab_container.current_tab = 0
	option_button.grab_focus()
	if focus_rect:
		focus_rect.call_deferred("focus_box_set", option_button)
	var video_settings = ConfigFileHandler.load_video_setting()
	
	for resorution_size_text in RESOLUTION_DICTIONARY:
		resolution_button.add_item(resorution_size_text)
		if RESOLUTION_DICTIONARY[resorution_size_text] == video_settings.resolution:
			var index = resolution_button.get_item_count() - 1
			resolution_button.select(index)
	
	
	if ConfigFileHandler.is_steam_deck:
		# [KR] 스팀덱: 디스플레이 설정은 기기 고정 — 실제 상태(전체화면)로 표시하고 조작을 잠근다
		full_screen_button.set_pressed_no_signal(true)
		full_screen_button.disabled = true
	else:
		full_screen_button.button_pressed = video_settings.fullscreen
	lighting_button.set_pressed_no_signal(not video_settings.get("light_quality", true))
	resolution_button_show()
	
	
	# ID 기반으로 항목을 선택한다 (순서가 바뀌어도 안전)
	# ID: ko=0, jp=1, zh=2, cn=3, en=4, ru=5
	if option_button.get_item_index(RUSSIAN_LANGUAGE_ID) < 0:
		option_button.add_item("Русский", RUSSIAN_LANGUAGE_ID)
	var lang_id: int = LANGUAGE_ID_BY_LOCALE.get(video_settings.language, 4)
	option_button.select(option_button.get_item_index(lang_id))
	_set_title_labels_visible(lang_id)
	_hide_small_text(lang_id == 4 or lang_id == RUSSIAN_LANGUAGE_ID)
	
	_init_broadcast_option()
	_init_hint_bubble_toggle()
	_init_crt_filter_slider()

	tab_container.tab_changed.connect(_on_tab_container_tab_changed)
	LanguageManager.lang_changed.connect(_on_lang_changed)

	if language_locked:
		_lock_language()

## 저장된 방송 주기 모드에 맞춰 방송 탭 드롭다운의 초기 선택을 설정한다.
func _init_broadcast_option():
	if not broadcast_option:
		return
	var mode: String = SoundManager.get_broadcast_interval_mode()
	var id: int = BROADCAST_ID_BY_MODE.get(mode, 0)
	broadcast_option.select(broadcast_option.get_item_index(id))

## 방송 주기 드롭다운 변경 콜백. 선택한 모드를 즉시 저장한다. (일반·신음 방송 공통)
func _on_broadcast_option_item_selected(index: int):
	var id: int = broadcast_option.get_item_id(index)
	SoundManager.set_broadcast_interval_mode(BROADCAST_MODE_BY_ID.get(id, "standard"))

## 저장된 값에 맞춰 힌트 버블 토글의 초기 상태를 설정한다. (체크=표시)
func _init_hint_bubble_toggle():
	if not hint_bubble_toggle:
		return
	hint_bubble_toggle.set_pressed_no_signal(HintBubbleComponent.is_hint_bubble_enabled())

## 힌트 버블 토글 콜백. 표시 여부를 즉시 저장한다. (켜진 컴포넌트는 다음 표시 때 반영)
func _on_hint_bubble_toggled(toggled_on: bool):
	ConfigFileHandler.save_gameplay_setting("hint_bubble_enabled", toggled_on)

## 저장된 강도에 맞춰 CRT 필터 슬라이더의 초기값을 설정한다.
func _init_crt_filter_slider():
	if not crt_filter_slider:
		return
	crt_filter_slider.set_value_no_signal(FilterScreen.get_intensity())

## CRT 필터 슬라이더 콜백. 강도를 즉시 적용·저장한다. (0=끄기, 최고치=현재 설정)
func _on_crt_filter_slider_value_changed(value: float):
	FilterScreen.set_intensity(value)

## 언어/음성언어 변경을 비활성화한다. (대화 중 호출)
## [br]Why: 이미 출력된 대사와 재생 중인 음성은 즉시 갱신되지 않아 자막·음성이 불일치하기 때문.
func _lock_language():
	option_button.disabled = true
	vo_option_button.disabled = true
	option_button.focus_mode = Control.FOCUS_NONE
	vo_option_button.focus_mode = Control.FOCUS_NONE
	# 비활성화된 언어 드롭다운 대신 전체화면 버튼으로 초기 포커스를 옮긴다.
	full_screen_button.grab_focus()
	if focus_rect:
		focus_rect.call_deferred("focus_box_set", full_screen_button)

## ESC로 뒤로가기, 좌우 방향키/LB·RB로 탭 전환을 처리한다.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("esc"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
		return
	var tab_count := tab_container.get_tab_count()
	# 물리 키 위치 기준: 왼쪽 키(소지품·Q)=이전 탭, 오른쪽 키(네비·E)=다음 탭
	if event.is_action_pressed("shotcut_kankan"):
		tab_container.current_tab = wrapi(tab_container.current_tab + 1, 0, tab_count)
	elif event.is_action_pressed("shotcut_inventory"):
		tab_container.current_tab = wrapi(tab_container.current_tab - 1, 0, tab_count)

## 언어 선택 드롭다운 변경 콜백. [param index]에 따라 게임 언어를 변경하고 설정을 저장한다.
## [br]Why: 중문 간체(index 4)와 번체(index 2)는 타이틀 라벨을 공유하므로 별도 매핑이 필요하다.
func _on_option_button_item_selected(index: int):
	_hide_small_text(false) # 기본값
	var id: int = option_button.get_item_id(index)
	# ID: ko=0, jp=1, zh=2, cn=3, en=4, ru=5
	match id:
		0:
			LanguageManager.change_language("ko")
		1:
			LanguageManager.change_language("jp")
		2:
			# 중문 번체
			LanguageManager.change_language("zh")
		3:
			# 중문 간체
			LanguageManager.change_language("cn")
		4:
			LanguageManager.change_language("en")
			_hide_small_text(true) # 영어일때만 작은 글자 숨김
		5:
			LanguageManager.change_language("ru")
			_hide_small_text(true)

	_set_title_labels_visible(id)
	_tab_title_update()

## 해상도 선택 변경 콜백. 창 크기를 변경하고 화면 중앙에 재배치한다.
func _on_resolution_item_selected(index):
	var new_size = RESOLUTION_DICTIONARY.values()[index]

	var mode = DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_MAXIMIZED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		full_screen_button.set_pressed_no_signal(false)
		ConfigFileHandler.save_video_setting("fullscreen", false)
		resolution_button_show()

	DisplayServer.window_set_size(new_size)
	
	await get_tree().process_frame  # 창 크기 반영을 한 프레임 기다림
	
	var screen_pos = DisplayServer.screen_get_position()
	var screen_center = screen_pos + DisplayServer.screen_get_size() / 2
	var client_size = get_window().size
	var decoration_height = get_window().get_size_with_decorations().y - client_size.y
	var new_pos = screen_center - client_size / 2
	new_pos.y = max(new_pos.y, screen_pos.y + decoration_height)
	get_window().set_position(new_pos)

	ConfigFileHandler.save_video_setting("resolution", new_size)

## 전체화면 토글 콜백. 전체화면 ↔ 창 모드를 전환하고 설정을 저장한다.
func _on_full_screen_toggled(toggled_on):
	var mode = DisplayServer.window_get_mode()
	if toggled_on:
		if mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			ConfigFileHandler.save_video_setting("fullscreen", true)
	else:
		if mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			ConfigFileHandler.save_video_setting("fullscreen", false)
	resolution_button_show()


## 조명 품질 토글 콜백. 조명을 켜거나 끄고 설정을 저장한다.
func _on_lighting_toggled(toggled_on: bool) -> void:
	LightOptimizer.set_quality(not toggled_on)


## 뒤로가기 처리. 퇴장 애니메이션을 재생하고 포커스 콜백을 해제한다.
func _on_back_pressed():
	if animation_player.is_playing():
		return
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)
	animation_player.play("out")
	ui_stream_player.set_stream_play_to_file(UiSoundStreamPlayer.SOUND_OPTION_PAGE_OUT)

## 전체화면 모드일 때 해상도 버튼을 비활성화한다.
func resolution_button_show():
	if full_screen_button.button_pressed:
		resolution_button.disabled = true
	else:
		resolution_button.disabled = false


## UI 포커스 변경 시 포커스 사각형을 이동시키고 효과음을 재생한다.
func _on_focus_changed(button : Control):
	if !focus_rect:
		return
	
	ui_button_stream_player.set_stream_play_to_file(UiSoundStreamPlayer.SOUND_OPTION_BUTTON_FOCUS)
	if animation_player.is_playing():
		focus_rect.hide()
		await animation_player.animation_finished
		focus_rect.focus_box_set(button)
		focus_rect.show()
	else:
		focus_rect.focus_box_set(button)


## 탭 전환 시 해당 탭의 첫 번째 버튼에 포커스를 설정한다.
func _on_tab_container_tab_changed(tab: int) -> void:
	
	match tab:
		0:
			focus_rect.hide()
			await get_tree().create_timer(0.1).timeout
			focus_rect.show()
			# 언어 잠금 시 비활성화된 드롭다운 대신 전체화면 버튼으로 포커스
			if language_locked:
				full_screen_button.grab_focus()
			else:
				option_button.grab_focus()
		1:
			focus_rect.hide()
			await get_tree().create_timer(0.1).timeout
			focus_rect.show()
			# 언어 잠금 시 비활성화된 음성언어 드롭다운 대신 볼륨 슬라이더로 포커스
			if language_locked:
				master_vo_slider.grab_focus()
			else:
				vo_option_button.grab_focus()
		2:
			focus_rect.hide()
			await get_tree().create_timer(0.1).timeout
			focus_rect.show()
			if broadcast_option:
				broadcast_option.grab_focus()


## 현재 언어에 맞게 탭 타이틀 텍스트를 갱신한다.
func _tab_title_update():
	tab_container.set_tab_title(0, tr("OPTION_TAB_SCREEN"))
	tab_container.set_tab_title(1, tr("OPTION_TAB_VOLUME"))
	if tab_container.get_tab_count() > 2:
		tab_container.set_tab_title(2, tr("OPTION_TAB_GAMEPLAY"))

## [param locale_num]에 해당하는 타이틀 라벨만 표시하고 나머지는 숨긴다.
func _set_title_labels_visible(locale_num: int):
	for i in title_labels:
		i.hide()
	var label_index := locale_num if locale_num < title_labels.size() else 4
	title_labels[label_index].show()

## 외부(F1 디버그 등)에서 언어가 변경됐을 때 옵션 메뉴 UI를 동기화한다.
func _on_lang_changed(locale: String) -> void:
	var id: int = LANGUAGE_ID_BY_LOCALE.get(locale, 4)
	option_button.select(option_button.get_item_index(id))
	_set_title_labels_visible(id)
	_tab_title_update()
	_hide_small_text(id == 4 or id == RUSSIAN_LANGUAGE_ID)

## 영어 UI일 때 [code]"OptionSmallText"[/code] 그룹의 작은 글자를 숨긴다.
## [br]Why: 영어는 글자 폭이 넓어 작은 보조 텍스트가 레이아웃을 깨뜨릴 수 있기 때문.
func _hide_small_text(state: bool):
	var small_texts = get_tree().get_nodes_in_group("OptionSmallText") as Array[Label]
	
	if state:
		for i in small_texts:
			i.hide()
	else:
		for i in small_texts:
			i.show()

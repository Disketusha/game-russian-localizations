## [KR] 게임 설정(비디오, 오디오)을 INI 파일로 저장/로드하는 오토로드 싱글톤.
##
## 설정 파일이 없으면 기본값으로 생성하고, 있으면 로드하여 적용한다.
## 저장 경로는 [code]user://settings.ini[/code]이다.
## [method save_video_setting] / [method save_audio_setting]으로 개별 항목을 즉시 저장한다.
## [EN] Autoload singleton that saves/loads game settings (video, audio) to an INI file.
##
## Creates with default values if the config file does not exist; loads and applies if it exists.
## Storage path is [code]user://settings.ini[/code].
## Individual items are saved immediately via [method save_video_setting] / [method save_audio_setting].
extends Node

## [KR] Godot [ConfigFile] 인스턴스. INI 형식으로 설정을 관리한다.
## [EN] Godot [ConfigFile] instance. Manages settings in INI format.
var config = ConfigFile.new()
## [KR] 설정 파일 저장 경로.
## [EN] Config file storage path.
const SETTING_FILE_PATH = "user://settings.ini"

## [KR] 스팀덱에서 실행 중인지 여부. Steam이 스팀덱의 모든 게임 프로세스에 SteamDeck=1 환경변수를 설정한다.
## (이 오토로드는 SteamManager보다 먼저 _ready되므로 Steam API 대신 환경변수로 감지)
var is_steam_deck: bool = OS.get_environment("SteamDeck") == "1"
## [KR] 스팀덱 네이티브 해상도.
const STEAM_DECK_RESOLUTION := Vector2i(1280, 800)

## [KR] OS 로케일을 게임 지원 언어 키로 변환한다. 미지원 언어는 "en" 반환.
## [EN] Converts OS locale to a supported language key. Returns "en" for unsupported locales.
func _detect_system_language() -> String:
	var locale := OS.get_locale()
	if locale.begins_with("ko"):
		return "ko"
	elif locale.begins_with("ja"):
		return "jp"
	elif locale.begins_with("ru"):
		return "ru"
	elif locale == "zh_TW" or locale == "zh_HK":
		return "zh"
	elif locale.begins_with("zh"):
		return "cn"
	else:
		return "en"

func _ready():
	if !FileAccess.file_exists(SETTING_FILE_PATH): # [KR] 초기 설정값 / [EN] Initial setting value
		# [KR] video / [EN] video
		config.set_value("video", "language", _detect_system_language())
		config.set_value("video", "fullscreen", false)
		config.set_value("video", "resolution", Vector2i(1920,1080))
		config.set_value("video", "light_quality", true)
		
		# [KR] audio / [EN] audio
		config.set_value("audio", "voice_lang", "jp")
		config.set_value("audio", "volume_master", 0.7)
		config.set_value("audio", "volume_char", 1.0)
		config.set_value("audio", "volume_sfx", 1.0)
		config.set_value("audio", "volume_bg", 1.0)
		
		config.save(SETTING_FILE_PATH)
	else:
		config.load(SETTING_FILE_PATH)
		
		### [KR] 기존 파일 실행자용을 위한 언어 강제 ko 변경 코드, 언어 추가시 제거해야 함.
		### [EN] Legacy code to force language to ko for existing file runners; remove when adding languages.
		#config.set_value("video", "language", "ko")
		#config.save(SETTING_FILE_PATH)
		####################################################################
		
	init_config()

## [KR] 비디오 설정 항목을 저장한다.
##
## [param key]는 설정 키(예: "language", "fullscreen", "resolution"),
## [param value]는 해당 설정값이다. 호출 즉시 파일에 기록된다.
## [EN] Saves a video setting item.
##
## [param key] is the setting key (e.g. "language", "fullscreen", "resolution"),
## [param value] is the corresponding setting value. Written to file immediately on call.
func save_video_setting(key: String, value):
	config.set_value("video", key, value)
	config.save(SETTING_FILE_PATH)

## [KR] 모든 비디오 설정을 Dictionary로 로드한다.
##
## 반환값은 [code]{ "language": "ko", "fullscreen": false, "resolution": Vector2i(...) }[/code] 형태이다.
## [EN] Loads all video settings as a Dictionary.
##
## Return value is in the form [code]{ "language": "ko", "fullscreen": false, "resolution": Vector2i(...) }[/code].
func load_video_setting():
	var video_setting = {}
	for key in config.get_section_keys("video"):
		video_setting[key] = config.get_value("video", key)
	return video_setting

## [KR] 오디오 설정 항목을 저장한다.
##
## [param key]는 설정 키(예: "volume_master", "volume_sfx", "voice_lang"),
## [param value]는 해당 설정값이다. 호출 즉시 파일에 기록된다.
## [EN] Saves an audio setting item.
##
## [param key] is the setting key (e.g. "volume_master", "volume_sfx", "voice_lang"),
## [param value] is the corresponding setting value. Written to file immediately on call.
func save_audio_setting(key: String, value):
	config.set_value("audio", key, value)
	config.save(SETTING_FILE_PATH)

## [KR] 모든 오디오 설정을 Dictionary로 로드한다.
##
## 반환값은 [code]{ "volume_master": 1.0, "volume_sfx": 1.0, ... }[/code] 형태이다.
## [EN] Loads all audio settings as a Dictionary.
##
## Return value is in the form [code]{ "volume_master": 1.0, "volume_sfx": 1.0, ... }[/code].
func load_audio_setting():
	var audio_setting = {}
	for key in config.get_section_keys("audio"):
		audio_setting[key] = config.get_value("audio", key)
	return audio_setting

## [KR] 게임플레이 설정 항목을 저장한다. (옵션 '게임' 탭: 힌트 버블 표시 여부 등)
##
## [param key]는 설정 키, [param value]는 설정값이다. 호출 즉시 파일에 기록된다.
## 읽을 때는 [code]config.get_value("gameplay", key, 기본값)[/code]으로 직접 조회한다.
## [EN] Saves a gameplay setting item (options "Gameplay" tab: hint bubble visibility, etc.).
func save_gameplay_setting(key: String, value):
	config.set_value("gameplay", key, value)
	config.save(SETTING_FILE_PATH)

## [KR] 저장된 설정값을 실제 시스템(해상도, 전체화면, 오디오 볼륨, 언어)에 적용한다.
##
## Dialogic 번역 테스트 모드가 활성화되어 있으면 언어 설정을 건너뛰고,
## [code]push_error[/code]로 테스트 중임을 알린다.
## [EN] Applies stored settings to the actual system (resolution, fullscreen, audio volume, language).
##
## If Dialogic translation test mode is enabled, skips language setting and
## reports that testing is in progress via [code]push_error[/code].
func init_config():
	var video_settings = load_video_setting()
	if is_steam_deck:
		# [KR] 스팀덱: 저장·동기화된 값과 무관하게 네이티브 해상도 전체화면을 적용한다.
		# 파일에는 저장하지 않음 — settings.ini는 클라우드 동기화되므로 기기 전용 값이 역류하면 안 됨.
		video_settings.resolution = STEAM_DECK_RESOLUTION
		video_settings.fullscreen = true
	#var current_locale: String = TranslationServer.get_locale()
	if not ProjectSettings.get_setting('internationalization/locale/test', "").is_empty():
		push_error("Dialogic 번역 테스트중 : ", ProjectSettings.get_setting('internationalization/locale/test'))
	else:
		# _ready() 중 set_locale() 호출 시 폰트 미초기화로 인한 에러 방지
		LanguageManager.set_language.call_deferred(video_settings.language)
	DisplayServer.window_set_size(video_settings.resolution)
	if video_settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	var audio_settings = load_audio_setting()
	var bus_index_master:int = AudioServer.get_bus_index("Master")
	var bus_index_sfx:int = AudioServer.get_bus_index("Sfx")
	var bus_index_char:int = AudioServer.get_bus_index("Character")
	var bus_index_music:int = AudioServer.get_bus_index("Music")
	
	AudioServer.set_bus_volume_db(bus_index_master, linear_to_db(audio_settings.volume_master))
	AudioServer.set_bus_volume_db(bus_index_sfx, linear_to_db(audio_settings.volume_sfx))
	AudioServer.set_bus_volume_db(bus_index_char, linear_to_db(audio_settings.volume_char))
	AudioServer.set_bus_volume_db(bus_index_music, linear_to_db(audio_settings.volume_bg))

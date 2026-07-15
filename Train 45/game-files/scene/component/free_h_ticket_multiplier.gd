## [KR] 무료 티켓 배율 보너스 UI를 관리하는 컨트롤.
## 티켓 스택이 쌓일 때마다 배율 표시를 갱신하고,
## 드롭 시 지연 후 아이템 드롭 이벤트를 발행한다.
## [EN] Control managing free ticket multiplier bonus UI.
## Updates multiplier display whenever ticket stacks accumulate,
## and issues item drop events after a delay on drop.
extends Control
class_name FreeTicketMultiplier

## [KR] 현재 보너스 스택 수를 표시하는 라벨.
## [EN] Label displaying the current bonus stack count.
@onready var ticket_bonus_stack: Label = $TicketBonusStack
## [KR] 보너스 타이틀 및 하트 이모지를 표시하는 라벨.
## [EN] Label displaying the bonus title and heart emojis.
@onready var ticket_bonus_title: Label = $TicketBonusTitle

## [KR] 현재 누적된 티켓 스택 수.
## [EN] Current accumulated ticket stack count.
var current_stack_ticket: int = 0


## [KR] 노드 준비 시 UI를 숨긴다. 첫 스택이 추가될 때 표시된다.
## [EN] Hides UI on node ready. Shown when the first stack is added.
func _ready() -> void:
	self.hide()
	LanguageManager.lang_changed.connect(_update_bonus_title)
	_update_bonus_title(TranslationServer.get_locale())

## [KR] 티켓 스택을 [param num]만큼 추가하고 UI를 갱신한다.
## 최초 호출 시 숨겨진 UI를 표시한다.
## [param num]: 추가할 티켓 스택 수
## [EN] Adds [param num] to ticket stacks and updates UI.
## Shows hidden UI on first call.
## [param num]: number of ticket stacks to add
func add_stack_ticket(num: int):
	if self.visible == false:
		self.show()
	current_stack_ticket += num
	
	update_ui(num)

## [KR] 누적된 티켓 스택을 전부 드롭하고 UI를 초기화한다.
## [method _drop_ticket_delayd]를 비동기로 호출한 뒤 스택을 리셋한다.
## [EN] Drops all accumulated ticket stacks and resets UI.
## Calls [method _drop_ticket_delayd] asynchronously then resets the stack.
func drop_stack_ticket():
	# [KR] await 이후 current_stack_ticket이 0으로 초기화되므로, 드롭할 수량을 미리 인자로 넘긴다.
	# [EN] current_stack_ticket is reset to 0 right after, so pass the drop count as an argument before the await.
	#print("[BONUS] drop_stack_ticket 호출 시점 current_stack_ticket = ", current_stack_ticket)
	_drop_ticket_delayd(current_stack_ticket)
	current_stack_ticket = 0
	#print("[BONUS] _drop_ticket_delayd 호출 직후 current_stack_ticket = ", current_stack_ticket)
	update_ui()
	
	#await get_tree().create_timer(3.0).timeout
	#self.hide()

## [KR] 보상 없이 누적된 티켓 스택을 초기화하고 UI를 숨긴다.
## 사정하지 않고 H를 중단(ESC)했을 때 호출되어 다음 진입 시 Bonus가 남아있지 않도록 한다.
## [EN] Resets accumulated ticket stacks without granting a reward and hides the UI.
## Called when an H is aborted (ESC) without climax, so the Bonus does not carry over to the next entry.
func reset_stack_ticket():
	current_stack_ticket = 0
	update_ui()
	self.hide()

## [KR] 2초 지연 후 누적된 티켓을 아이템 드롭 이벤트로 발행한다.
## [EN] Issues accumulated tickets as an item drop event after a 2-second delay.
func _drop_ticket_delayd(amount: int):
	await get_tree().create_timer(2.0).timeout
	#print("[BONUS] 2초 await 종료 후 실제 드롭되는 amount = ", amount)
	GameEvents.emit_drop_item(Constants.PC_PLAYER, DropItemManager.ItemType.TICKET, amount)

## [KR] UI 라벨을 현재 스택 수와 배율 하트로 갱신한다.
## [param multiplier]: 하트(♥) 이모지 반복 횟수 ([code]0[/code]이면 하트 없음)
## [EN] Updates UI labels with current stack count and multiplier hearts.
## [param multiplier]: heart (♥) emoji repeat count ([code]0[/code] means no hearts)
func update_ui(multiplier: int = 0):
	ticket_bonus_stack.text = "x" + str(current_stack_ticket)
	
	var hearts: String = ""
	for i in multiplier:
		hearts += "♥"
	var title := "Бонус" if TranslationServer.get_locale().begins_with("ru") else "Bonus"
	ticket_bonus_title.text = title + hearts

## Сохраняет уже показанные сердечки при смене языка во время открытого интерфейса.
func _update_bonus_title(locale: String) -> void:
	var hearts := ticket_bonus_title.text.replace("Бонус", "").replace("Bonus", "")
	var title := "Бонус" if locale.begins_with("ru") else "Bonus"
	ticket_bonus_title.text = title + hearts

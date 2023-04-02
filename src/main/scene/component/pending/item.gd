#============================================================
#    Item
#============================================================
# - author: zhangxuetu
# - datetime: 2023-03-31 21:44:10
# - version: 4.0
#============================================================
extends MarginContainer


signal selected(state: bool)
signal right_clicked
signal double_clicked
## 开始拖拽
##[br][code]callback_data_list[/code]  回调数据列表。如果想要增加拖拽的数据，则对这个信号
##的参数列表进行增加 [Dictionary] 类型的数据，且这个数据要有一个 texture 的 key 的数据
signal dragged(callback_data_list: Array)


const DEFAULT_COLOR = Color8(255, 255, 255, int(255 * 0.2))
const SELECTED_COLOR = Color8(255, 255, 255, int(255 * 0.5))


@onready var texture_rect = $TextureRect
@onready var border = $border
@onready var border_style : StyleBoxFlat = border["theme_override_styles/panel"]
@onready var group_label = $group_label


var _data : Dictionary
var _selected : bool = false: set = set_selected
var _pressed_pos: Vector2 = Vector2()
var _groups : Array[String] = []


#============================================================
#  SetGet
#============================================================
func get_data() -> Dictionary:
	return _data 


func set_data(data: Dictionary):
	var texture = data['texture'] as Texture2D
	if not is_inside_tree(): await ready
	texture_rect.texture = texture
	_data = data
	_update_tooltip()
 

func is_selected() -> bool:
	return _selected


func set_selected(v: bool):
	if _selected != v:
		_selected = v
		if border_style:
			border_style.bg_color = SELECTED_COLOR \
				if _selected \
				else DEFAULT_COLOR
			border.visible = _selected
		self.selected.emit(_selected)


func add_texture_group(group: String):
	_groups.append(group)
	group_label.text = ", ".join(_groups)


func _update_tooltip():
	if _data:
		tooltip_text = """
index: {index}
size: {size}
	""".format({
			"index": get_index(),
			"size": str(_data['texture'].get_size() if _data.get("texture") else Vector2i(0, 0)),
		}).strip_edges()
	


#============================================================
#  内置
#============================================================
func _ready():
	_update_tooltip()


func _gui_input(event):
	if event is InputEventMouseButton:
		if event.pressed:
			_pressed_pos = get_global_mouse_position()
		else:
			if event.double_click:
				self.double_clicked.emit()
			else:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if _pressed_pos.distance_to(get_global_mouse_position()) < 8:
						_selected = not _selected
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					self.right_clicked.emit()


func _get_drag_data(at_position):
	var callback_data_list : Array[Dictionary] = []
	self.dragged.emit(callback_data_list)
	
	if not callback_data_list.is_empty():
		# 拖拽显示
		var drag_node = TextureRect.new()
#		drag_node.custom_minimum_size = Vector2(32, 32)
#		drag_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		drag_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		drag_node.texture = callback_data_list[0]['texture']
		set_drag_preview(drag_node)
		return {
			"type": "texture_data_list",
			"data": callback_data_list,
		}
		
	else:
		printerr("没有数据")



#============================================================
#  连接信号
#============================================================
func _on_mouse_entered():
	border.visible = true


func _on_mouse_exited():
	if not _selected:
		border.visible = false

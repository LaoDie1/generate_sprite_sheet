#============================================================
#    Sprite Sheet
#============================================================
# - author: zhangxuetu
# - datetime: 2023-03-31 00:21:22
# - version: 4.0
#============================================================
## 合并图片为一个精灵表
@tool
class_name SpriteSheetMain
extends MarginContainer


const MAIN_NODE_META_KEY = &"SpriteSheetMain_main_node"


## 导出了文件
signal exported


var __init_node__ = SpriteSheetUtil.auto_inject(self, "")

# 菜单列表
var menu_list : HBoxContainer
# 文件树
var file_tree : SpriteSheet_FileTree
# 等待处理文件列表，拖拽进去，选中这个文件，可以从操作台中进行开始处理这个图片
# 处理后的文件在这里面保存，然后生成会从这个列表里生成处理
var pending : SpriteSheet_Pending
# 预览图片
var preview_container : SpriteSheet_PreviewContainer
# 操作处理容器
var handle_container : TabContainer
var export_panding_dialog : FileDialog
var scan_dir_dialog : FileDialog
var export_preview_dialog : FileDialog
var prompt_info_label : Label
var prompt_info_anim_player : AnimationPlayer
var bottom_panel : HBoxContainer

@onready var anim_panel := %ANIM as SpriteSheet_AnimationPanel


#============================================================
#  内置
#============================================================
func _ready():
	# 初始化菜单
	menu_list.init_menu({
		"FILE": ["SCAN_DIR", "SAVE_DATA"],
		"EXPORT": ["EXPORT_PENDING_IMAGE"]
	})
	
	# 边距
	for child in handle_container.get_children():
		if child is MarginContainer:
			for dir in ["left", "right", "top", "bottom"]:
				child.set("theme_override_constants/margin_" + dir, 8)
	
	# 提示信息
	Engine.set_meta(MAIN_NODE_META_KEY, self)
	prompt_info_label.modulate.a = 0
	
	
	# 底部按钮
	var bottom_first_button : Button = bottom_panel.get_node("ScrollContainer/VBoxContainer").get_child(0)
	var bottom_button_group : ButtonGroup = bottom_first_button.button_group
	bottom_button_group.pressed.connect(func(button: BaseButton):
		var tab_container = bottom_panel.get_node("TabContainer") as TabContainer
		tab_container.current_tab = button.get_index()
	)


func _exit_tree():
	if (Engine.is_editor_hint() 
		and not get_parent() is SubViewport
	):
		# 是场景根节点时则代表正在编辑中，所以退出节点不保存数据
		SpriteSheetUtil.save_cache_data()
	elif not Engine.is_editor_hint():
		SpriteSheetUtil.save_cache_data()


#============================================================
#  自定义
#============================================================
## 显示消息内容
static func show_message(message: String):
	if Engine.has_meta(MAIN_NODE_META_KEY):
		var node = Engine.get_meta(MAIN_NODE_META_KEY) as SpriteSheetMain
		var label := node.prompt_info_label as Label
		label.text = " " + message
		# 闪烁动画
		var anim_player = node.prompt_info_anim_player as AnimationPlayer
		anim_player.stop()
		anim_player.play("twinkle")


class IfTrue:
	var _value
	
	func _init(value):
		_value = value
	
	func else_show_message(message: String) -> void:
		if _value:
			pass
		else:
			SpriteSheetMain.show_message(message)
	
	##  如果值为 [code]true[/code] 则执行回调方法
	##[br]
	##[br][code]callback[/code] 这个方法需要有一个参数用于接收上个回调的值 
	func if_true(callback: Callable) -> IfTrue:
		if _value:
			return IfTrue.new(callback.call(_value))
		return IfTrue.new(null)


##  如果值为 [code]true[/code] 则执行回调方法
##[br]
##[br][code]callback[/code]  这个方法没有任何参数，可以有一个返回值用于下一个 if_true 方法的执行，如果没有返回值，
##则默认为 value 参数值
##[br][code]return[/code]  返回一个 IfTrue 对象用以链式调用执行功能
static func if_true(value, callback: Callable) -> IfTrue:
	if value:
		var r = callback.call()
		return IfTrue.new(r if r else value)
	return IfTrue.new(null)


## 如果存在预览图像则执行回调
func if_has_texture_else_show_message(callback: Callable):
	if_true(preview_container.has_texture(), callback).else_show_message("没有预览图像")



#============================================================
#  连接信号
#============================================================
func _on_file_tree_added_item(item: TreeItem):
	# 文件树添加新的 item 时
	var data = item.get_metadata(0) as Dictionary
	if data.path_type == SpriteSheet_FileTree.PathType.FILE:
		var path = data.path
		var texture = SpriteSheetUtil.load_image(path)
		item.set_icon(0, texture)
		item.set_icon_max_width(0, 16)


func _on_preview_container_created_texture(texture: Texture2D):
	pending.add_data({
		"texture": texture,
		"path": "",
	})


func _on_add_selected_rect_pressed():
	if_has_texture_else_show_message(func():
		# 添加选中的表格区域的图片到待处理区
		var texture_list = preview_container.get_selected_texture_list()
		if texture_list.is_empty():
			show_message("没有选中块！")
			return
		
		for image_texture in texture_list:
			pending.add_data({ texture = image_texture })
		preview_container.clear_select()
		show_message("添加 %d 张图块到处理区" % texture_list.size())
		
	)


func _on_clear_select_pressed():
	if_has_texture_else_show_message(func():
		preview_container.clear_select()
	)


func _on_select_all_pressed():
	if_has_texture_else_show_message(func():
		if_true(preview_container.get_preview_grid_visible(), func():
			var grid = preview_container.get_cell_grid()
			for x in grid.x:
				for y in grid.y:
					var coordinate = Vector2i(x, y)
					preview_container.select(coordinate)
		).else_show_message("还未进行切分！")
	)


func _on_menu_list_menu_pressed(idx, menu_path):
	match menu_path:
		"/FILE/SCAN_DIR":
			scan_dir_dialog.popup_centered()
		
		"/EXPORT/EXPORT_PENDING_IMAGE":
			if_true(pending.get_data_list().size() > 0, func():
				export_panding_dialog.popup_centered()
			).else_show_message("没有待处理的图像")
		
		"/FILE/SAVE_DATA":
			SpriteSheetUtil.save_cache_data()
			



func _on_item_double_clicked(data):
	# 预览双击的图片
	var texture = data["texture"]
	preview_container.preview(texture)


func _on_export_panding_dialog_dir_selected(dir: String):
	if_true(DirAccess.dir_exists_absolute(dir), func():
		var list = pending.get_texture_list()
		var idx = -1
		var exported_file_list : Array[String] = []
		var filename : String 
		for texture in list:
			while true:
				idx += 1
				filename = "subtexture_%04d.png" % idx
				if not FileAccess.file_exists(filename):
					break
			exported_file_list.append(dir.path_join(filename))
			ResourceSaver.save(texture, exported_file_list.back() )
		
		show_message("已导出文件：" + str(exported_file_list))
		print(exported_file_list)
		print()
		
		self.exported.emit()
	).else_show_message("没有这个目录")


func _on_export_preview_pressed():
	if_has_texture_else_show_message(func():
		export_preview_dialog.popup_centered()
	)


func _on_export_preview_dialog_file_selected(path):
	# 导出预览图像
	if preview_container.get_texture():
		var texture = preview_container.get_texture()
		ResourceSaver.save(texture, path)
		show_message("已保存预览图像")
		self.exported.emit()


func _on_git_new_version_meta_clicked(meta):
	OS.shell_open(meta)


func _on_add_preview_texture_pressed():
	if_has_texture_else_show_message(func():
		pending.add_data({ texture = preview_container.get_texture() })
	)


func _on_pending_previewed(texture: Texture2D):
	if_true(is_instance_valid(texture), func():
		preview_container.preview(texture)
	).else_show_message("错误的预览图像")


func _on_pending_exported_texture(texture_list):
	self.exported.emit()


func _on_add_to_anim_pressed():
	var texture_list = preview_container.get_selected_texture_list()
	if texture_list.is_empty():
		show_message("没有选中图像")
		return
	
	anim_panel.add_animation_items(texture_list)
	preview_container.clear_select()
	show_message("已添加为动画")


func _on_segment_split_column_row(column_row: Vector2i):
	if_has_texture_else_show_message(func():
		if_true(column_row.x > 0 and column_row.y > 0, func():
			var texture_size = Vector2i(preview_container.get_texture().get_size())
			var cell_size : Vector2i = texture_size / column_row
			preview_container.split(cell_size)
		).else_show_message("行列大小不能小于 0！")
	)


func _on_segment_split_grid_changed(margin, separator):
	preview_container.update_grid_margin(margin)
	preview_container.update_grid_separator(separator)


func _on_segment_split_size(cell_size):
	if_has_texture_else_show_message(func():
		if_true(cell_size.x > 0 and cell_size.y > 0, func():
			preview_container.split(cell_size)
		).else_show_message("大小必须超过 0！")
	)


func _on_anim_played(animation):
	preview_container.play(animation)


func _on_anim_stopped():
	preview_container.stop()


func _on_merge_handle_merged(data: SpriteSheet_PendingHandle.Merge):
	var texture_list : Array[Texture2D] = pending.get_selected_texture_list()
	if_true(texture_list.size() > 0, func():
		# 预览
		var merge_texture = data.execute(texture_list)
		if merge_texture:
			preview_container.preview(merge_texture)
		
	).else_show_message("没有选中任何图像")


func _on_image_handle_handled(handle: SpriteSheet_PreviewHandle.Handle):
	match handle.update_type:
		handle.PREVIEW:
			if_has_texture_else_show_message(func():
				handle.execute([preview_container.get_texture()], func(list: Array[Texture2D]):
					preview_container.preview(list[0])
				)
			)
		
		handle.PENDING_SELECTED:
			handle.execute(pending.texture_item_group.get_selected_texture_list(), func(list: Array[Texture2D]):
				var idx = 0
				for data in pending.texture_item_group.get_selected_data_list():
					var item = data['node'] as SpriteSheetTextureItem
					item.update_texture(list[idx])
					item.set_selected(false)
					idx += 1
				
			)


func _on_anim_added_to_pending(texture_list):
	for texture in texture_list:
		pending.add_data({
			"texture": texture
		})


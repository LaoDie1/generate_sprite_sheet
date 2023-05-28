#============================================================
#    Preview Handle
#============================================================
# - author: zhangxuetu
# - datetime: 2023-04-03 13:54:37
# - version: 4.0
#============================================================
@tool
class_name SpriteSheet_PreviewHandle
extends MarginContainer


## 处理
signal handled(handle: Handle)


## 更新的对象的类型
enum {
	## 预览图像
	PREVIEW,
	## 选中的待处理图像
	PENDING_SELECTED,
}


var __init_node__ = SpriteSheetUtil.auto_inject(self, "")

var from_color : ColorPickerButton
var to_color : ColorPickerButton
var color_threshold : Slider
var outline_color : ColorPickerButton
var color_threshold_label : Label

var button_group : ButtonGroup


class Handle:
	
	## 更新的对象的类型
	enum {
		## 预览图像
		PREVIEW,
		## 选中的待处理图像
		PENDING_SELECTED,
	}
	
	var update_type : int = PREVIEW
	
	var _callable: Callable
	
	func _init(type: int, callable: Callable):
		update_type = type
		_callable = callable
	
	## 执行处理图片
	##[br][code]texture_list[/code] 要修改的图片列表
	##[br][code]callback[/code] 处理完成之后调用的方法，这个方法需要有一个 Array[Texture2D] 类型的参数，接收处理后的图片
	func execute(texture_list: Array, callback: Callable) -> void:
		var list : Array[Texture2D] = []
		for texture in texture_list:
			list.append(_callable.call(texture))
		callback.call(list)



#============================================================
#  内置
#============================================================
func _ready():
	var first_button = %operate_target.get_child(0) as Button
	button_group = first_button.button_group as ButtonGroup
	
	var button_list = %node_container.get_children().filter(func(node): return node is Button )
	SpriteSheetUtil.set_width_by_max_width(button_list)
	


# 执行这个方法处理图片
#[br][code]callback[/code] 这个回调需要有一个 [Texture2D] 参数，用于处理回调传入的每个图片
#[br][code]condition[/code] 没有参数，这个需要返回一个字符串，不返回则默认通过，用于检查是否继续执行的方法，以及不通过时提示的文字消息
func _emit_handle(callback: Callable):
	self.handled.emit(Handle.new(button_group.get_pressed_button().get_index(), callback))


#============================================================
#  连接信号
#============================================================
func _on_resize_pressed():
	var _size = %size.get_value()
	if _size.x <= 0 or _size.y <= 0:
		SpriteSheetMain.show_message("大小不能为 0！")
		return
	
	_emit_handle(func(texture: Texture2D):
		return SpriteSheetUtil.resize_texture(texture, _size)
	)


func _on_rescale_pressed():
	var scale_v = %scale.get_value()
	if scale_v.x <= 0 or scale_v.y <= 0:
		SpriteSheetMain.show_message("缩放不能为 0！")
		return
	
	_emit_handle(func(texture: Texture2D):
		if scale_v.x == 1 or scale_v.y == 1:
			return texture
		return SpriteSheetUtil.scale_texture(texture, scale_v)
	)


func _on_recolor_pressed():
	_emit_handle(func(texture: Texture2D):
		return SpriteSheetUtil.replace_color(texture, from_color.color, to_color.color, color_threshold.value)
	)


func _on_color_swap_pressed():
	var tmp = from_color.color
	from_color.color = to_color.color
	to_color.color = tmp


func _on_outline_pressed():
	_emit_handle(func(texture: Texture2D):
		return SpriteSheetUtil.outline(texture, outline_color.color)
	)


func _on_clear_transparency_pressed():
	_emit_handle(func(texture: Texture2D):
		var image = texture.get_image() as Image
		var rect = image.get_used_rect()
		var new_image = image.get_region(rect)
		return ImageTexture.create_from_image(new_image)
	)


func _on_cut_btn_pressed():
	var rect = Rect2i(%cut.get_value())
	if rect.size.x <= 0 or rect.size.y <= 0:
		SpriteSheetMain.show_message("剪切图像大小不能为 0！")
		return
	
	_emit_handle(func(texture: Texture2D):
		var new_image = texture.get_image().get_region(rect)
		return ImageTexture.create_from_image(new_image)
	)


func _on_color_threshold_value_changed(value):
	color_threshold_label.text = str(value)


func _on_rot_pressed():
	_emit_handle(func(texture: Texture2D):
		# 旋转图片
		var new_image = SpriteSheetUtil.create_image_from(texture.get_image())
		var r = %rotation.value
		if r != 0:
			if abs(r) == 180:
				new_image.rotate_180()
			else:
				if r > 0:
					new_image.rotate_90(CLOCKWISE)
				else:
					new_image.rotate_90(COUNTERCLOCKWISE)
			return ImageTexture.create_from_image(new_image)
		else:
			SpriteSheetMain.show_message("旋转角度不能为 0！")
			return texture
	)


func _on_rotation_value_changed(value):
	%rotation_label.text = str(value)


func _on_mix_pressed():
	_emit_handle(func(texture: Texture2D):
		var new_image : Image = SpriteSheetUtil.create_image_from(texture.get_image())
		var mix_image : Image = SpriteSheetUtil.create_image_from(texture.get_image())
		var mix_color : Color = %mix_color.color
		var color : Color
		for x in mix_image.get_width():
			for y in mix_image.get_height():
				color = mix_image.get_pixel(x, y)
				if color.a > 0:
					mix_image.set_pixel(x, y, color.blend(mix_color))
		
		# 混合
		new_image.blend_rect(mix_image, Rect2i(Vector2i(), new_image.get_size()), Vector2i())
		return ImageTexture.create_from_image(new_image)
	)

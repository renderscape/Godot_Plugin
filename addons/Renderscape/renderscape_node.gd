## Docks the panel
@tool
extends EditorPlugin

var panel: RenderscapePanel


func _enter_tree() -> void:
	panel = RenderscapePanel.new()
	panel.name = "Renderscape"
	panel.custom_minimum_size = Vector2(280, 400)
	add_control_to_dock(DOCK_SLOT_LEFT_UL, panel)


func _exit_tree() -> void:
	if panel:
		remove_control_from_docks(panel)
		panel.queue_free()
		panel = null
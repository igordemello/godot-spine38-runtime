@tool
extends EditorPlugin

var _dock: Control


func _enter_tree() -> void:
	_dock = preload("dock.gd").new()
	add_control_to_dock(DOCK_SLOT_LEFT_UR, _dock) # ao lado das abas Cena/Importar


func _exit_tree() -> void:
	remove_control_from_docks(_dock)
	_dock.free()

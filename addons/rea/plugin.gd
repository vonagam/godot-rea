@tool
extends EditorPlugin


func _enter_tree():
  add_autoload_singleton( 'REA', 'res://addons/rea/sources/Internal.gd' )

func _exit_tree():
  remove_autoload_singleton( 'REA' )

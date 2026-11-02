class_name OverlayView
extends Node2D
## Draws telegraphs and preview markers above the units.

var board_view: BoardView


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if board_view == null:
		return
	board_view.draw_telegraphs(self)
	board_view.draw_preview(self)

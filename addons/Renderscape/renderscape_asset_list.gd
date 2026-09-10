## Custom ItemList that knows how to drag its items into the 3D/2D viewport,
## mirroring FAssetDragDropOp on the Unreal side. Godot's editor recognizes a
## drag payload shaped like {"type": "files", "files": [...]} — the same
## contract used when dragging a file out of the native FileSystem dock — so
## returning that from _get_drag_data() gets us "drag onto viewport to place"
## for free, without needing a custom drop target.
##
## Godot's stock ItemList doesn't support per-row custom widgets the way Slate's
## STableRow does, so "already imported" / "downloading" status is communicated
## via a text suffix on the item label rather than a separate sub-widget — a
## deliberate, honest simplification versus the Unreal panel's per-row layout.
class_name RenderscapeAssetList
extends ItemList

## Set by the owning panel. Signature: (index: int) -> RenderscapeAsset
var asset_for_index: Callable
## Signature: (asset: RenderscapeAsset) -> bool
var is_asset_imported: Callable
## Called when the user tries to drag an asset that hasn't been downloaded yet.
## Signature: (asset: RenderscapeAsset) -> void
var request_download: Callable
## Signature: (asset: RenderscapeAsset) -> String  (returns the tier-appropriate local path)
var get_local_path: Callable

signal asset_right_clicked(asset: RenderscapeAsset, at_position: Vector2)
signal asset_double_clicked(asset: RenderscapeAsset)


func _ready() -> void:
	item_clicked.connect(_on_item_clicked)
	item_activated.connect(_on_item_activated)


func _on_item_clicked(index: int, at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index != MOUSE_BUTTON_RIGHT:
		return
	var asset := _get_asset(index)
	if asset:
		asset_right_clicked.emit(asset, at_position)


func _on_item_activated(index: int) -> void:
	var asset := _get_asset(index)
	if asset:
		asset_double_clicked.emit(asset)


func _get_asset(index: int) -> RenderscapeAsset:
	if index < 0 or not asset_for_index.is_valid():
		return null
	return asset_for_index.call(index)


func _get_drag_data(at_position: Vector2) -> Variant:
	var index := get_item_at_position(at_position, true)
	if index < 0:
		return null

	var asset := _get_asset(index)
	if not asset:
		return null

	# Not downloaded yet — kick off the download instead of dragging, same as the
	# Unreal panel's OnDragDetected behavior when IsAssetImported() is false.
	if not is_asset_imported.call(asset):
		if request_download.is_valid():
			request_download.call(asset)
		return null

	var local_path: String = get_local_path.call(asset) if get_local_path.is_valid() else ""
	if local_path.is_empty() or not FileAccess.file_exists(local_path):
		return null

	set_drag_preview(_make_drag_preview(asset.file_name))

	return {
		"type": "files",
		"files": [local_path],
	}


func _make_drag_preview(label_text: String) -> Control:
	var label := Label.new()
	label.text = label_text
	label.add_theme_color_override("font_color", Color.WHITE)
	return label

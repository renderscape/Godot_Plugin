## Note on view toggling: Godot's ItemList natively supports both a row layout
## (ICON_MODE_LEFT) and a grid layout (ICON_MODE_TOP) as a single control, so
## unlike the Unreal panel's SListView/STileView pair swapped via an SOverlay,
## this uses one ItemList and just flips icon_mode.
class_name RenderscapePanel
extends Control

const LIST_URL := "https://renderscape.io/server/plugins/godot/godot_user_downloads.php"
const ASSET_URL := "https://renderscape.io/server/plugins/godot/serve_asset.php"
const ASSET_DIR := "res://renderscape_assets"

const QUALITY_OPTIONS := ["Production (High)", "Medium", "Low Poly"]
const QUALITY_CODES := ["prod", "med", "lowpoly"]
const SORT_OPTIONS := ["Newest First", "A \u2192 Z"]

var auth_manager: RenderscapeAuthManager

var asset_list: Array = []          # Array[RenderscapeAsset]
var filtered_asset_list: Array = [] # Array[RenderscapeAsset]
var previous_asset_names: Dictionary = {}
var downloading_assets: Dictionary = {}
var available_categories: Array = []
var selected_category: String = ""
var current_search_text: String = ""
var selected_sort_index: int = 0
var selected_quality_index: int = 0
var grid_view: bool = false
var is_initial_load: bool = true

# UI
var notification_badge: Label
var toast_label: Label
var toast_timer: Timer
var title_label: Label
var login_container: VBoxContainer
var email_input: LineEdit
var password_input: LineEdit
var login_button: Button
var quality_option: OptionButton
var refresh_button: Button
var sort_option: OptionButton
var list_view_btn: Button
var grid_view_btn: Button
var category_container: HBoxContainer
var search_box: LineEdit
var asset_list_control: RenderscapeAssetList
var context_menu: PopupMenu
var context_menu_asset: RenderscapeAsset
var refresh_timer: Timer


func _ready() -> void:
	auth_manager = RenderscapeAuthManager.new()
	auth_manager.login_completed.connect(_on_login_completed)

	_build_ui()

	var creds := auth_manager.load_credentials()
	if not creds.is_empty():
		email_input.text = creds["email"]
		password_input.text = creds["password"]
		auth_manager.login(self, creds["email"], creds["password"])


func _exit_tree() -> void:
	if refresh_timer:
		refresh_timer.stop()


# ── UI construction ─────────────────────────────────────────────────────────

func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	add_child(root)

	notification_badge = Label.new()
	notification_badge.text = RenderscapeStyle.NEW_ASSET_BADGE_TEXT
	notification_badge.add_theme_color_override("font_color", RenderscapeStyle.NEW_ASSET_COLOR)
	notification_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_badge.visible = false
	root.add_child(notification_badge)

	toast_label = Label.new()
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	toast_label.visible = false
	root.add_child(toast_label)

	toast_timer = Timer.new()
	toast_timer.one_shot = true
	toast_timer.timeout.connect(_on_toast_timeout)
	add_child(toast_timer)

	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", RenderscapeStyle.TITLE_COLOR)
	title_label.add_theme_font_size_override("font_size", 16)
	root.add_child(title_label)

	# Login form — hidden once authenticated, mirrors GetLoginFormVisibility
	login_container = VBoxContainer.new()
	root.add_child(login_container)

	email_input = LineEdit.new()
	email_input.placeholder_text = "Email"
	login_container.add_child(email_input)

	password_input = LineEdit.new()
	password_input.placeholder_text = "Password"
	password_input.secret = true
	login_container.add_child(password_input)

	login_button = Button.new()
	login_button.text = "Login & Save"
	login_button.pressed.connect(_on_login_pressed)
	login_container.add_child(login_button)

	login_container.add_child(HSeparator.new())

	# Quality selector
	var quality_row := HBoxContainer.new()
	var quality_label := Label.new()
	quality_label.text = "Quality:"
	quality_row.add_child(quality_label)

	quality_option = OptionButton.new()
	for opt in QUALITY_OPTIONS:
		quality_option.add_item(opt)
	quality_option.item_selected.connect(func(index: int): selected_quality_index = index)
	quality_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_row.add_child(quality_option)
	root.add_child(quality_row)

	# Refresh
	refresh_button = Button.new()
	refresh_button.text = "Get My Assets"
	refresh_button.disabled = true
	refresh_button.pressed.connect(_on_refresh_pressed)
	root.add_child(refresh_button)

	# Sort + view toggle
	var sort_row := HBoxContainer.new()
	var sort_label := Label.new()
	sort_label.text = "Sort:"
	sort_row.add_child(sort_label)

	sort_option = OptionButton.new()
	for opt in SORT_OPTIONS:
		sort_option.add_item(opt)
	sort_option.item_selected.connect(_on_sort_changed)
	sort_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sort_row.add_child(sort_option)

	list_view_btn = Button.new()
	list_view_btn.text = "\u2261"
	list_view_btn.tooltip_text = "List view"
	list_view_btn.pressed.connect(_on_list_view_pressed)
	sort_row.add_child(list_view_btn)

	grid_view_btn = Button.new()
	grid_view_btn.text = "\u229e"
	grid_view_btn.tooltip_text = "Grid view"
	grid_view_btn.pressed.connect(_on_grid_view_pressed)
	sort_row.add_child(grid_view_btn)

	root.add_child(sort_row)
	_update_view_toggle_colors()

	# Category chips
	var chip_scroll := ScrollContainer.new()
	chip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chip_scroll.custom_minimum_size = Vector2(0, 32)
	category_container = HBoxContainer.new()
	chip_scroll.add_child(category_container)
	root.add_child(chip_scroll)
	_build_category_chips()

	# Search
	search_box = LineEdit.new()
	search_box.placeholder_text = "Search assets..."
	search_box.text_changed.connect(_on_search_text_changed)
	root.add_child(search_box)

	# Asset list/grid
	asset_list_control = RenderscapeAssetList.new()
	asset_list_control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	asset_list_control.custom_minimum_size = Vector2(0, 200)
	asset_list_control.select_mode = ItemList.SELECT_SINGLE
	asset_list_control.icon_mode = ItemList.ICON_MODE_LEFT
	asset_list_control.fixed_icon_size = RenderscapeStyle.THUMBNAIL_SIZE
	asset_list_control.asset_for_index = func(index: int) -> RenderscapeAsset:
		return asset_list_control.get_item_metadata(index)
	asset_list_control.is_asset_imported = is_asset_imported
	asset_list_control.request_download = download_asset
	asset_list_control.get_local_path = _get_local_path_for_drag
	asset_list_control.asset_double_clicked.connect(_on_asset_double_clicked)
	asset_list_control.asset_right_clicked.connect(_on_asset_right_clicked)
	root.add_child(asset_list_control)

	# Context menu
	context_menu = PopupMenu.new()
	context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	add_child(context_menu)

	# Background refresh — 120s. (The Unreal plugin defaults to 300s / 5 min;
	# lowered here per request for a faster "new asset" turnaround after purchase.)
	refresh_timer = Timer.new()
	refresh_timer.wait_time = 120.0
	refresh_timer.one_shot = false
	refresh_timer.timeout.connect(_on_refresh_timeout)
	add_child(refresh_timer)

	_update_title()
	_update_login_form_visibility()


# ── Login ────────────────────────────────────────────────────────────────────

func _on_login_pressed() -> void:
	var email := email_input.text.strip_edges()
	var password := password_input.text.strip_edges()
	if email.is_empty() or password.is_empty():
		_show_toast("Please enter email and password", 3.0)
		return

	auth_manager.save_credentials(email, password)
	auth_manager.login(self, email, password)


func _on_login_completed(success: bool, message: String) -> void:
	if success:
		refresh_button.disabled = false
		_update_title()
		_update_login_form_visibility()
		_show_toast(message, 3.0)
		refresh_timer.start()
		fetch_asset_list()
	else:
		_show_toast("Login failed: %s" % message, 5.0)


func _update_title() -> void:
	if auth_manager.is_authenticated():
		title_label.text = ("Welcome, %s!" % auth_manager.user_name) if not auth_manager.user_name.is_empty() else "Renderscape Assets"
	else:
		title_label.text = "Renderscape \u2014 Login"


func _update_login_form_visibility() -> void:
	login_container.visible = not auth_manager.is_authenticated()


# ── Asset list fetching ──────────────────────────────────────────────────────

func _on_refresh_pressed() -> void:
	if auth_manager.is_authenticated():
		fetch_asset_list()


func fetch_asset_list() -> void:
	if not auth_manager.is_authenticated():
		return
	var body := JSON.stringify({"uid": auth_manager.user_id})
	RenderscapeHTTPClient.request_json(self, LIST_URL, HTTPClient.METHOD_POST, body, auth_manager.auth_token, _on_asset_list_response)


func _on_asset_list_response(success: bool, _response_code: int, body_text: String) -> void:
	if not success:
		return

	var json := JSON.new()
	if json.parse(body_text) != OK:
		return

	var data = json.data
	if not (data is Array):
		return

	var new_assets: Array = []
	var has_new := false

	for entry in data:
		if not (entry is Dictionary):
			continue
		var asset := RenderscapeAsset.from_dict(entry)

		if is_initial_load:
			asset.is_new = false
		else:
			asset.is_new = not previous_asset_names.has(asset.file_name)
			if asset.is_new:
				has_new = true

		new_assets.append(asset)

		RenderscapeHTTPClient.download_image(self, asset.thumbnail_url, func(ok: bool, img_data: PackedByteArray):
			_on_thumbnail_downloaded(ok, img_data, asset)
		)

	if not is_initial_load:
		_update_notification_badge(has_new)
		if has_new:
			_show_toast("New assets available!", 5.0)

	previous_asset_names.clear()
	for asset in new_assets:
		previous_asset_names[asset.file_name] = true

	is_initial_load = false
	asset_list = new_assets
	_update_available_categories()
	update_filtered_asset_list()


func _on_thumbnail_downloaded(success: bool, data: PackedByteArray, asset: RenderscapeAsset) -> void:
	if not success or data.is_empty():
		return
	var image := Image.new()
	if image.load_png_from_buffer(data) != OK:
		return
	asset.thumbnail_texture = ImageTexture.create_from_image(image)
	_refresh_list_view()


# ── Search ───────────────────────────────────────────────────────────────────

func _on_search_text_changed(text: String) -> void:
	current_search_text = text
	update_filtered_asset_list()


# ── Category filtering ───────────────────────────────────────────────────────

func _update_available_categories() -> void:
	var categories: Array = []
	for asset in asset_list:
		if not asset.main_category.is_empty() and not categories.has(asset.main_category):
			categories.append(asset.main_category)
	categories.sort()
	available_categories = categories
	_build_category_chips()


func _build_category_chips() -> void:
	if not category_container:
		return
	for child in category_container.get_children():
		child.queue_free()

	_add_chip("All", "")
	for cat in available_categories:
		_add_chip(cat, cat)


func _add_chip(label_text: String, value: String) -> void:
	var is_active := selected_category.is_empty() if value.is_empty() else (value == selected_category)
	var btn := Button.new()
	btn.text = label_text
	_style_flat_button(btn, RenderscapeStyle.ACCENT_COLOR if is_active else RenderscapeStyle.INACTIVE_COLOR)
	btn.pressed.connect(func(): _on_category_selected(value))
	category_container.add_child(btn)


func _on_category_selected(category: String) -> void:
	selected_category = category
	update_filtered_asset_list()
	_build_category_chips()


# ── Sort ─────────────────────────────────────────────────────────────────────

func _on_sort_changed(index: int) -> void:
	selected_sort_index = index
	update_filtered_asset_list()


# ── Filtering / view refresh ────────────────────────────────────────────────

func update_filtered_asset_list() -> void:
	var source: Array = asset_list.duplicate()

	if not selected_category.is_empty():
		source = source.filter(func(a: RenderscapeAsset): return a.main_category == selected_category)

	if not current_search_text.is_empty():
		var lower := current_search_text.to_lower()
		source = source.filter(func(a: RenderscapeAsset):
			return a.file_name.to_lower().contains(lower) or a.main_category.to_lower().contains(lower)
		)

	if selected_sort_index == 1: # A -> Z
		source.sort_custom(func(a: RenderscapeAsset, b: RenderscapeAsset): return a.file_name.naturalnocasecmp_to(b.file_name) < 0)
	# else: keep API order (newest first)

	filtered_asset_list = source
	_refresh_list_view()


func _on_list_view_pressed() -> void:
	grid_view = false
	_update_view_toggle_colors()
	_refresh_list_view()


func _on_grid_view_pressed() -> void:
	grid_view = true
	_update_view_toggle_colors()
	_refresh_list_view()


func _update_view_toggle_colors() -> void:
	if not list_view_btn or not grid_view_btn:
		return
	_style_flat_button(list_view_btn, RenderscapeStyle.INACTIVE_COLOR if grid_view else RenderscapeStyle.ACCENT_COLOR)
	_style_flat_button(grid_view_btn, RenderscapeStyle.ACCENT_COLOR if grid_view else RenderscapeStyle.INACTIVE_COLOR)


func _refresh_list_view() -> void:
	if not asset_list_control:
		return

	asset_list_control.clear()
	asset_list_control.icon_mode = ItemList.ICON_MODE_TOP if grid_view else ItemList.ICON_MODE_LEFT
	asset_list_control.fixed_icon_size = RenderscapeStyle.GRID_ICON_SIZE if grid_view else RenderscapeStyle.THUMBNAIL_SIZE
	# max_columns defaults to 1, which silently prevents wrapping into a real
	# grid no matter how wide the panel is. 0 = auto-fit as many columns as fit.
	asset_list_control.max_columns = 0 if grid_view else 1
	asset_list_control.same_column_width = grid_view

	for asset in filtered_asset_list:
		var is_downloading := downloading_assets.has(asset.file_name)
		var imported := is_asset_imported(asset)

		var label_text: String = asset.file_name
		if is_downloading:
			label_text += RenderscapeStyle.DOWNLOADING_SUFFIX
		elif imported:
			label_text += RenderscapeStyle.IMPORTED_SUFFIX

		var idx := asset_list_control.add_item(label_text, asset.thumbnail_texture)
		asset_list_control.set_item_metadata(idx, asset)

		if is_downloading:
			asset_list_control.set_item_custom_fg_color(idx, RenderscapeStyle.DOWNLOADING_TEXT_COLOR)
		elif asset.is_new:
			asset_list_control.set_item_custom_fg_color(idx, RenderscapeStyle.NEW_ASSET_COLOR)
		elif imported:
			asset_list_control.set_item_custom_fg_color(idx, RenderscapeStyle.IMPORTED_TEXT_COLOR)



# ── Already-imported / local paths ──────────────────────────────────────────

func is_asset_imported(asset: RenderscapeAsset) -> bool:
	for tier in QUALITY_CODES:
		if FileAccess.file_exists(_local_path(asset, tier)):
			return true
	return false


func _local_path(asset: RenderscapeAsset, tier: String) -> String:
	return ASSET_DIR.path_join("%s_%s.glb" % [asset.file_name, tier])


func _get_local_path_for_drag(asset: RenderscapeAsset) -> String:
	# Prefer the currently selected quality tier; fall back to whatever tier is
	# actually on disk, mirroring the Unreal panel's on-disk-tier fallback.
	var preferred := _local_path(asset, get_quality_string())
	if FileAccess.file_exists(preferred):
		return preferred
	for tier in QUALITY_CODES:
		var path := _local_path(asset, tier)
		if FileAccess.file_exists(path):
			return path
	return ""


func get_quality_string() -> String:
	return QUALITY_CODES[selected_quality_index]


func get_quality_display() -> String:
	return QUALITY_OPTIONS[selected_quality_index]


# ── Download ─────────────────────────────────────────────────────────────────

func _on_asset_double_clicked(asset: RenderscapeAsset) -> void:
	download_asset(asset)


func download_asset(asset: RenderscapeAsset) -> void:
	if downloading_assets.has(asset.file_name):
		return

	var tier := get_quality_string()
	downloading_assets[asset.file_name] = true
	_refresh_list_view()

	var body := JSON.stringify({
		"uid": auth_manager.user_id,
		"pid": asset.product_id,
		"fileName": asset.file_name,
		"mainCategory": asset.main_category,
		"quality": tier,
	})

	_show_toast("Downloading %s (%s)..." % [asset.file_name, get_quality_display()])

	RenderscapeHTTPClient.request_binary(self, ASSET_URL, HTTPClient.METHOD_POST, body, auth_manager.auth_token,
		func(success: bool, response_code: int, data: PackedByteArray):
			_on_asset_downloaded(success, response_code, data, asset, tier)
	)


func _on_asset_downloaded(success: bool, response_code: int, data: PackedByteArray, asset: RenderscapeAsset, tier: String) -> void:
	downloading_assets.erase(asset.file_name)

	if not success or data.is_empty():
		_show_toast("Download failed (%d)" % response_code, 5.0)
		_refresh_list_view()
		return

	var abs_dir := ProjectSettings.globalize_path(ASSET_DIR)
	if not DirAccess.dir_exists_absolute(abs_dir):
		DirAccess.make_dir_recursive_absolute(abs_dir)

	var path := _local_path(asset, tier)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		_show_toast("Failed to save file", 5.0)
		_refresh_list_view()
		return

	file.store_buffer(data)
	file.close()

	# Non-blocking rescan so the .glb import is picked up promptly. No polling
	# loop needed — Godot's own drag payload (see RenderscapeAssetList) is what
	# actually places the asset in the viewport, once the user drags it in.
	EditorInterface.get_resource_filesystem().scan()

	_show_toast("\u2713 %s (%s) downloaded \u2014 drag it into the viewport to place it" % [asset.file_name, get_quality_display()], 5.0)
	_refresh_list_view()


# ── Context menu ─────────────────────────────────────────────────────────────

func _on_asset_right_clicked(asset: RenderscapeAsset, at_position: Vector2) -> void:
	context_menu_asset = asset
	context_menu.clear()
	context_menu.add_item("Import", 0)
	context_menu.set_item_disabled(0, downloading_assets.has(asset.file_name))
	context_menu.add_separator()
	context_menu.add_item("Open on Renderscape.io", 1)
	context_menu.add_item("Copy Asset Name", 2)
	context_menu.position = Vector2i(asset_list_control.get_screen_position() + at_position)
	context_menu.popup()


func _on_context_menu_id_pressed(id: int) -> void:
	if not context_menu_asset:
		return
	match id:
		0:
			download_asset(context_menu_asset)
		1:
			OS.shell_open("https://renderscape.io/shop/products/%s" % context_menu_asset.product_id)
		2:
			DisplayServer.clipboard_set(context_menu_asset.file_name)
			_show_toast("Copied: %s" % context_menu_asset.file_name, 2.0)


# ── Notifications ────────────────────────────────────────────────────────────

func _update_notification_badge(should_show: bool) -> void:
	notification_badge.visible = should_show


func _show_toast(text: String, duration: float = 3.0) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_timer.start(duration)


func _on_toast_timeout() -> void:
	toast_label.visible = false


# ── Shared button styling ───────────────────────────────────────────────────

## modulate() tints a button's text/icon/background together, which is why a
## dark bg_color also darkened the label text into unreadability. Styling the
## background via a StyleBoxFlat and the font color separately (mirroring
## Unreal's separate ButtonColorAndOpacity / ForegroundColor properties) keeps
## text readable regardless of the background tint.
func _style_flat_button(btn: Button, bg_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	for state in ["normal", "hover", "pressed", "focus"]:
		btn.add_theme_stylebox_override(state, style)
	for color_key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(color_key, Color.WHITE)


# ── Background refresh ───────────────────────────────────────────────────────

func _on_refresh_timeout() -> void:
	if auth_manager.is_authenticated():
		fetch_asset_list()
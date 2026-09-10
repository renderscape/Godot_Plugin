class_name RenderscapeAsset
extends RefCounted

var file_name: String = ""
var product_id: String = ""
var main_category: String = ""
var thumbnail_url: String = ""
var thumbnail_texture: ImageTexture = null
var is_new: bool = false

static func from_dict(data: Dictionary) -> RenderscapeAsset:
	var asset := RenderscapeAsset.new()
	asset.file_name = str(data.get("filename", ""))
	asset.product_id = str(data.get("pid", ""))
	asset.main_category = str(data.get("main_category", ""))

	var safe_name := "%s-%s" % [asset.main_category, asset.file_name]
	asset.thumbnail_url = "https://renderscape.io/miner/thumbnails/dark/%s.png" % safe_name.uri_encode()

	return asset

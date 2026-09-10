class_name RenderscapeHTTPClient
extends RefCounted

## result/response_code alone aren't enough — result can report "success" for
## a request that completed transport but came back 404/500. This is the same
## fix applied to the Unreal HTTP client, which previously only checked
## "did we get a response" and not the actual status code.
static func _is_success(result: int, response_code: int) -> bool:
	return result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300

## JSON request. callback signature: (success: bool, response_code: int, body_text: String)
static func request_json(parent: Node, url: String, method: int, body: String, auth_token: String, callback: Callable) -> void:
	var http := HTTPRequest.new()
	parent.add_child(http)

	var headers := ["Content-Type: application/json"]
	if not auth_token.is_empty():
		headers.append("Authorization: Bearer " + auth_token)

	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray):
		http.queue_free()
		callback.call(_is_success(result, response_code), response_code, body_bytes.get_string_from_utf8())
	)

	var err := http.request(url, headers, method, body)
	if err != OK:
		push_error("Renderscape: failed to start request to %s (error %d)" % [url, err])
		http.queue_free()
		callback.call(false, 0, "")

## Binary request (asset download). callback signature: (success: bool, response_code: int, data: PackedByteArray)
static func request_binary(parent: Node, url: String, method: int, body: String, auth_token: String, callback: Callable) -> void:
	var http := HTTPRequest.new()
	parent.add_child(http)

	var headers := ["Content-Type: application/json"]
	if not auth_token.is_empty():
		headers.append("Authorization: Bearer " + auth_token)

	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray):
		http.queue_free()
		callback.call(_is_success(result, response_code), response_code, body_bytes)
	)

	var err := http.request(url, headers, method, body)
	if err != OK:
		push_error("Renderscape: failed to start request to %s (error %d)" % [url, err])
		http.queue_free()
		callback.call(false, 0, PackedByteArray())

## Plain GET for thumbnails. callback signature: (success: bool, data: PackedByteArray)
static func download_image(parent: Node, url: String, callback: Callable) -> void:
	var http := HTTPRequest.new()
	parent.add_child(http)

	http.request_completed.connect(func(result: int, response_code: int, _headers: PackedStringArray, body_bytes: PackedByteArray):
		http.queue_free()
		callback.call(_is_success(result, response_code), body_bytes)
	)

	var err := http.request(url)
	if err != OK:
		http.queue_free()
		callback.call(false, PackedByteArray())

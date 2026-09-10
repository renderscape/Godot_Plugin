class_name RenderscapeAuthManager
extends RefCounted

const CONFIG_PATH := "user://renderscape_config.cfg"
const LOGIN_URL := "https://renderscape.io/server/plugins/godot/godot_login.php"

signal login_completed(success: bool, message: String)

var auth_token: String = ""
var user_id: String = ""
var user_name: String = ""


func is_authenticated() -> bool:
	return not auth_token.is_empty()


func login(parent: Node, email: String, password: String) -> void:
	var body := JSON.stringify({"email": email, "password": password})
	RenderscapeHTTPClient.request_json(parent, LOGIN_URL, HTTPClient.METHOD_POST, body, "", _on_login_response)


func _on_login_response(success: bool, _response_code: int, body_text: String) -> void:
	if not success:
		login_completed.emit(false, "Network error")
		return

	var json := JSON.new()
	if json.parse(body_text) != OK:
		login_completed.emit(false, "Invalid server response")
		return

	var data = json.data
	if data is Array and data.size() > 0:
		var user_data: Dictionary = data[0]
		if str(user_data.get("result", "")) == "OK":
			auth_token = str(user_data.get("token", ""))
			user_id = str(user_data.get("sub", ""))
			user_name = str(user_data.get("given_name", ""))
			login_completed.emit(true, "Welcome, %s!" % user_name)
			return
		elif user_data.has("result"):
			login_completed.emit(false, str(user_data.get("result")))
			return

	login_completed.emit(false, "Invalid credentials")


func logout() -> void:
	auth_token = ""
	user_id = ""
	user_name = ""


# ── Credential storage ──────────────────────────────────────────────────────

func save_credentials(email: String, password: String) -> void:
	var config := ConfigFile.new()
	config.set_value("auth", "email", _encrypt(email))
	config.set_value("auth", "password", _encrypt(password))
	config.save(CONFIG_PATH)


## Returns {"email": String, "password": String} or {} if nothing valid is saved.
func load_credentials() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return {}

	var email := _decrypt(str(config.get_value("auth", "email", "")))
	var password := _decrypt(str(config.get_value("auth", "password", "")))
	if email.is_empty() or password.is_empty():
		return {}

	return {"email": email, "password": password}


func clear_saved_credentials() -> void:
	var abs_path := ProjectSettings.globalize_path(CONFIG_PATH)
	if FileAccess.file_exists(CONFIG_PATH):
		DirAccess.remove_absolute(abs_path)


func _get_encryption_key() -> PackedByteArray:
	var project_name: String = ProjectSettings.get_setting("application/config/name", "RenderscapeProject")
	var project_dir := ProjectSettings.globalize_path("res://")
	var seed_string := project_name + project_dir

	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(seed_string.to_utf8_buffer())
	return ctx.finish() # 32 bytes — a full AES-256 key


func _encrypt(plain_text: String) -> String:
	if plain_text.is_empty():
		return ""

	var key := _get_encryption_key()
	var iv := Crypto.new().generate_random_bytes(16)

	var data := plain_text.to_utf8_buffer()
	var pad_len := 16 - (data.size() % 16)
	for i in pad_len:
		data.append(pad_len)

	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv)
	var encrypted := aes.update(data)
	aes.finish()

	# IV isn't secret; prepending it lets decrypt recover it without a second store.
	return Marshalls.raw_to_base64(iv + encrypted)


func _decrypt(cipher_text: String) -> String:
	if cipher_text.is_empty():
		return ""

	var combined := Marshalls.base64_to_raw(cipher_text)
	if combined.size() <= 16 or (combined.size() - 16) % 16 != 0:
		return ""

	var iv := combined.slice(0, 16)
	var encrypted := combined.slice(16)

	var key := _get_encryption_key()
	var aes := AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, key, iv)
	var decrypted := aes.update(encrypted)
	aes.finish()

	if decrypted.is_empty():
		return ""

	var pad_len := decrypted[decrypted.size() - 1]
	if pad_len <= 0 or pad_len > 16 or pad_len > decrypted.size():
		return "" # bad key (e.g. project moved) — treat as "no saved credentials"

	return decrypted.slice(0, decrypted.size() - pad_len).get_string_from_utf8()

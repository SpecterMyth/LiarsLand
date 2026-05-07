extends Node
class_name LlmClient

signal log_message(message: String)
signal stream_delta(section: String, delta: String)
signal stream_field_delta(section: String, field_name: String, delta: String)

const CONFIG_LOCAL_PATH := "res://config.local.json"
const CONFIG_EXAMPLE_PATH := "res://config.example.json"
const WEB_CHAT_PROXY_PATH := "/api/chat"

var config: Dictionary = {}
var player_http: HTTPRequest
var npc_http: HTTPRequest
var last_error := ""
var cancelled_sections := {}


func _ready() -> void:
	if config.is_empty():
		config = load_config()
	player_http = HTTPRequest.new()
	npc_http = HTTPRequest.new()
	add_child(player_http)
	add_child(npc_http)


func use_mock_llm() -> bool:
	return bool(config.get("game", {}).get("use_mock_llm", false))


func chat_json(section: String, system_prompt: String, user_prompt: String, fallback: Dictionary, stream_text := false) -> Dictionary:
	last_error = ""
	cancelled_sections[section] = false
	if _should_mock(section):
		if stream_text:
			await _emit_mock_response_stream(section, fallback)
		if _is_cancelled(section):
			var cancelled_mock := fallback.duplicate(true)
			cancelled_mock["cancelled"] = true
			return cancelled_mock
		return fallback
	var http := player_http if section == "player_llm" else npc_http
	var raw := ""
	if stream_text:
		raw = await _call_chat_stream(section, system_prompt, user_prompt)
	else:
		raw = await _call_chat(http, section, system_prompt, user_prompt, false)
	if _is_cancelled(section):
		var cancelled_response := fallback.duplicate(true)
		cancelled_response["cancelled"] = true
		return cancelled_response
	if not last_error.is_empty():
		var error_response := fallback.duplicate(true)
		error_response["error"] = last_error
		return error_response
	return parse_json_response(raw, fallback)


func cancel_section(section: String) -> void:
	cancelled_sections[section] = true
	if section == "player_llm" and player_http != null:
		player_http.cancel_request()
	elif section == "npc_llm" and npc_http != null:
		npc_http.cancel_request()


func _is_cancelled(section: String) -> bool:
	return bool(cancelled_sections.get(section, false))


func parse_json_response(raw: String, fallback: Dictionary) -> Dictionary:
	var cleaned := extract_json(raw)
	if cleaned.is_empty():
		log_message.emit("LLM 返回为空，已使用安全默认回复。")
		return fallback
	var parsed = JSON.parse_string(cleaned)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	log_message.emit("JSON 解析失败，已使用安全默认回复。原始输出：%s" % raw.left(360))
	return fallback


func extract_json(raw: String) -> String:
	var text := raw.strip_edges()
	if text.begins_with("```"):
		var first_newline := text.find("\n")
		var last_fence := text.rfind("```")
		if first_newline >= 0 and last_fence > first_newline:
			text = text.substr(first_newline + 1, last_fence - first_newline - 1).strip_edges()
	var start := text.find("{")
	var end := text.rfind("}")
	if start >= 0 and end > start:
		return text.substr(start, end - start + 1)
	return text


func _should_mock(section: String) -> bool:
	if use_mock_llm():
		return true
	if OS.has_feature("web"):
		return false
	var cfg: Dictionary = _section_config(section)
	var key := String(cfg.get("api_key", ""))
	return key.is_empty() or key.begins_with("YOUR_")


func _call_chat(http: HTTPRequest, section: String, system_prompt: String, user_prompt: String, stream_text: bool) -> String:
	var body := {
		"section": section,
		"system_prompt": system_prompt,
		"user_prompt": user_prompt,
		"stream": stream_text
	}
	var url := _web_proxy_url()
	var headers := ["Content-Type: application/json"]
	if not OS.has_feature("web"):
		var cfg := _section_config(section)
		url = String(cfg.get("base_url", "")).trim_suffix("/") + "/chat/completions"
		body = {
			"model": cfg.get("model", ""),
			"messages": [
				{"role": "system", "content": system_prompt},
				{"role": "user", "content": user_prompt}
			],
			"temperature": 0.75
		}
		headers.append("Authorization: Bearer %s" % String(cfg.get("api_key", "")))
	var err := http.request(url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		last_error = "请求启动失败：%s" % str(err)
		log_message.emit(last_error)
		return ""
	var completed: Array = await http.request_completed
	if _is_cancelled(section):
		return ""
	var status_code := int(completed[1])
	var bytes: PackedByteArray = completed[3]
	var text := bytes.get_string_from_utf8()
	if status_code < 200 or status_code >= 300:
		last_error = "LLM API 错误 %d：%s" % [status_code, text]
		log_message.emit(last_error)
		return ""
	var content := _extract_content(text)
	if stream_text and not content.is_empty():
		await _emit_mock_stream(section, _preview_stream_text(content))
	return content


func _call_chat_stream(section: String, system_prompt: String, user_prompt: String) -> String:
	var url := _web_proxy_url()
	var body := {
		"section": section,
		"system_prompt": system_prompt,
		"user_prompt": user_prompt,
		"stream": true
	}
	var headers := [
		"Content-Type: application/json",
		"Accept: text/event-stream"
	]
	if not OS.has_feature("web"):
		var cfg := _section_config(section)
		url = String(cfg.get("base_url", "")).trim_suffix("/") + "/chat/completions"
		body = {
			"model": cfg.get("model", ""),
			"messages": [
				{"role": "system", "content": system_prompt},
				{"role": "user", "content": user_prompt}
			],
			"temperature": 0.75,
			"stream": true
		}
		headers.append("Authorization: Bearer %s" % String(cfg.get("api_key", "")))

	var parsed_url := _parse_url(url)
	if parsed_url.is_empty():
		last_error = "LLM API 错误：无法解析 URL：%s" % url
		log_message.emit(last_error)
		return ""

	var client := HTTPClient.new()
	var tls_options = TLSOptions.client() if bool(parsed_url.get("tls", false)) else null
	var connect_err := client.connect_to_host(String(parsed_url.get("host", "")), int(parsed_url.get("port", 80)), tls_options)
	if connect_err != OK:
		last_error = "请求启动失败：%s" % str(connect_err)
		log_message.emit(last_error)
		return ""
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		if _is_cancelled(section):
			client.close()
			return ""
		client.poll()
		await get_tree().process_frame
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		last_error = "LLM API 错误：连接失败，状态 %s" % str(client.get_status())
		log_message.emit(last_error)
		return ""

	var request_err := client.request(HTTPClient.METHOD_POST, String(parsed_url.get("path", "/")), headers, JSON.stringify(body))
	if request_err != OK:
		last_error = "请求启动失败：%s" % str(request_err)
		log_message.emit(last_error)
		return ""

	var raw := ""
	var sse_buffer := ""
	var visible_fields := {}
	var status_code := 0
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		if _is_cancelled(section):
			client.close()
			return ""
		client.poll()
		await get_tree().process_frame
	if client.has_response():
		status_code = client.get_response_code()
		while client.get_status() == HTTPClient.STATUS_BODY:
			if _is_cancelled(section):
				client.close()
				return ""
			client.poll()
			var chunk := client.read_response_body_chunk()
			if chunk.size() > 0:
				var text := chunk.get_string_from_utf8()
				if status_code >= 200 and status_code < 300:
					sse_buffer += text
					var parsed := _consume_sse_buffer(sse_buffer, raw, visible_fields, section)
					sse_buffer = parsed.get("buffer", "")
					raw = parsed.get("raw", "")
					visible_fields = parsed.get("visible_fields", {})
				else:
					raw += text
			await get_tree().process_frame
	if status_code < 200 or status_code >= 300:
		last_error = "LLM API 错误 %d：%s" % [status_code, raw]
		log_message.emit(last_error)
		return ""
	if not sse_buffer.is_empty():
		var parsed_tail := _consume_sse_buffer(sse_buffer + "\n\n", raw, visible_fields, section)
		raw = parsed_tail.get("raw", raw)
	return raw


func _consume_sse_buffer(buffer: String, raw: String, visible_fields: Dictionary, section: String) -> Dictionary:
	while true:
		var split_at := buffer.find("\n\n")
		var separator_len := 2
		if split_at < 0:
			split_at = buffer.find("\r\n\r\n")
			separator_len = 4
		if split_at < 0:
			break
		var event := buffer.substr(0, split_at)
		buffer = buffer.substr(split_at + separator_len)
		for line in event.split("\n"):
			var clean := line.strip_edges()
			if not clean.begins_with("data:"):
				continue
			var data := clean.substr(5).strip_edges()
			if data == "[DONE]":
				continue
			var packet := _parse_stream_delta(data)
			var delta: String = packet.get("content", "")
			var reasoning_delta: String = packet.get("visible", "")
			if delta.is_empty() and reasoning_delta.is_empty():
				continue
			if not reasoning_delta.is_empty():
				_emit_stream_field(section, "thinking", reasoning_delta)
				visible_fields["thinking"] = String(visible_fields.get("thinking", "")) + reasoning_delta
			if not delta.is_empty():
				raw += delta
				for field_name in ["thinking", "reasoning", "speech"]:
					var emitted_field: String = "thinking" if field_name == "reasoning" else field_name
					var visible_delta: String = _visible_stream_delta(raw, String(visible_fields.get(field_name, "")), field_name)
					if not visible_delta.is_empty():
						_emit_stream_field(section, emitted_field, visible_delta)
						visible_fields[field_name] = String(visible_fields.get(field_name, "")) + visible_delta
	return {"buffer": buffer, "raw": raw, "visible_fields": visible_fields}


func _parse_stream_delta(data: String) -> Dictionary:
	var parsed = JSON.parse_string(data)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"content": data, "visible": ""}
	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		return {"content": "", "visible": ""}
	var delta: Dictionary = choices[0].get("delta", {})
	if delta.has("reasoning_content"):
		return {"content": "", "visible": String(delta.get("reasoning_content", ""))}
	if delta.has("reasoning"):
		return {"content": "", "visible": String(delta.get("reasoning", ""))}
	if delta.has("content"):
		return {"content": String(delta.get("content", "")), "visible": ""}
	return {"content": "", "visible": ""}


func _visible_stream_delta(current_raw: String, visible_text: String, field_name: String) -> String:
	var value := _partial_json_string_value(current_raw, field_name)
	if value.length() <= visible_text.length():
		return ""
	return value.substr(visible_text.length())


func _emit_stream_field(section: String, field_name: String, delta: String) -> void:
	if delta.is_empty():
		return
	stream_field_delta.emit(section, field_name, delta)
	if field_name == "thinking":
		stream_delta.emit(section, delta)


func _partial_json_string_value(text: String, field_name: String) -> String:
	var key := "\"%s\"" % field_name
	var key_at := text.find(key)
	if key_at < 0:
		return ""
	var colon_at := text.find(":", key_at + key.length())
	if colon_at < 0:
		return ""
	var quote_at := text.find("\"", colon_at + 1)
	if quote_at < 0:
		return ""
	var result := ""
	var escaped := false
	for i in range(quote_at + 1, text.length()):
		var ch := text.substr(i, 1)
		if escaped:
			match ch:
				"n":
					result += "\n"
				"r":
					result += "\r"
				"t":
					result += "\t"
				"\"":
					result += "\""
				"\\":
					result += "\\"
				_:
					result += ch
			escaped = false
		elif ch == "\\":
			escaped = true
		elif ch == "\"":
			break
		else:
			result += ch
	return result


func _parse_url(url: String) -> Dictionary:
	var regex := RegEx.new()
	regex.compile("^(https?)://([^/:]+)(?::([0-9]+))?(/.*)?$")
	var result := regex.search(url)
	if result == null:
		return {}
	var scheme := result.get_string(1)
	var host := result.get_string(2)
	var port_text := result.get_string(3)
	var path := result.get_string(4)
	var tls := scheme == "https"
	var port := 443 if tls else 80
	if not port_text.is_empty():
		port = int(port_text)
	if path.is_empty():
		path = "/"
	return {"tls": tls, "host": host, "port": port, "path": path}


func _extract_content(text: String) -> String:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("error"):
			last_error = "LLM API 错误：%s" % String(parsed.get("error", ""))
			log_message.emit(last_error)
			return ""
		if parsed.has("content"):
			return String(parsed.get("content", ""))
		var choices: Array = parsed.get("choices", [])
		if choices.size() > 0:
			var msg: Dictionary = choices[0].get("message", {})
			return String(msg.get("content", ""))
	return text


func _preview_stream_text(content: String) -> String:
	var parsed = JSON.parse_string(extract_json(content))
	if typeof(parsed) == TYPE_DICTIONARY:
		if parsed.has("thinking"):
			return String(parsed.get("thinking", ""))
		if parsed.has("speech"):
			return String(parsed.get("speech", ""))
	return content


func _emit_mock_stream(section: String, text: String) -> void:
	for i in range(0, text.length(), 6):
		if _is_cancelled(section):
			return
		_emit_stream_field(section, "thinking", text.substr(i, 6))
		await get_tree().create_timer(0.035).timeout


func _emit_mock_response_stream(section: String, response: Dictionary) -> void:
	if response.has("thinking"):
		await _emit_mock_field_stream(section, "thinking", String(response.get("thinking", "")))
	if _is_cancelled(section):
		return
	if response.has("speech"):
		await _emit_mock_field_stream(section, "speech", String(response.get("speech", "")))


func _emit_mock_field_stream(section: String, field_name: String, text: String) -> void:
	for i in range(0, text.length(), 6):
		if _is_cancelled(section):
			return
		_emit_stream_field(section, field_name, text.substr(i, 6))
		await get_tree().create_timer(0.035).timeout


func _section_config(section: String) -> Dictionary:
	if section == "npc_llm" and not config.has("npc_llm"):
		return config.get("opponent_llm", {})
	return config.get(section, {})


func _web_proxy_url() -> String:
	if OS.has_feature("web"):
		var origin = JavaScriptBridge.eval("window.location.origin")
		return String(origin).trim_suffix("/") + WEB_CHAT_PROXY_PATH
	return WEB_CHAT_PROXY_PATH


static func load_config() -> Dictionary:
	if OS.has_feature("web"):
		return {}
	var path := CONFIG_LOCAL_PATH if FileAccess.file_exists(CONFIG_LOCAL_PATH) else CONFIG_EXAMPLE_PATH
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

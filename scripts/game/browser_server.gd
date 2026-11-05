extends Node
## The browser's worker owns the match; this node only transfers packets and saves its recording.
signal available(metadata: Dictionary)
signal failed(message: String)

var bridge: JavaScriptObject
var recording := ""
var _started := false
var _closing := false
var _reported := false
var _deadline := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	JavaScriptBridge.eval(FileAccess.get_file_as_string("res://tools/web/simulation-bridge.js"), true)
	bridge = JavaScriptBridge.create_object("FrontlineSimulation")
	set_process(false)

func start(bytes: PackedByteArray, replay: bool, seek: int) -> void:
	if bridge == null or not bridge.allocate(bytes.size()):
		_fail("Could not allocate the browser simulation.")
		return
	_started = true
	_deadline = Time.get_ticks_msec() + 600000
	set_process(true)
	for offset in range(0, bytes.size(), 65536):
		if _closing:
			return
		bridge.append(Marshalls.raw_to_base64(bytes.slice(offset, mini(offset + 65536, bytes.size()))))
		if offset % (1024 * 1024) == 0:
			await get_tree().process_frame
	bridge.start(replay, seek)

func _process(_delta: float) -> void:
	if not String(bridge.error).is_empty():
		_fail(String(bridge.error))
		return
	if _closing:
		if not bool(bridge.finished):
			return
		if not recording.is_empty():
			var bytes := JavaScriptBridge.js_buffer_to_packed_byte_array(bridge.recording)
			var file := FileAccess.open(recording, FileAccess.WRITE)
			if file == null:
				_fail("Could not save the battle recording.")
				return
			file.store_buffer(bytes)
			var error := file.get_error()
			file.close()
			if error != OK:
				_fail("Could not finish saving the battle recording.")
				return
		queue_free()
	elif not _reported:
		if Time.get_ticks_msec() > _deadline:
			_fail("The browser simulation did not become ready within ten minutes.")
			return
		var metadata: Variant = JSON.parse_string(String(bridge.metadata)) if not String(bridge.metadata).is_empty() else null
		if metadata is Dictionary:
			_reported = true
			available.emit(metadata)

func read() -> PackedByteArray:
	var buffer: Variant = bridge.read()
	return JavaScriptBridge.js_buffer_to_packed_byte_array(buffer) if buffer is JavaScriptObject else PackedByteArray()

func open() -> void:
	bridge.open()

func send(bytes: PackedByteArray) -> Error:
	return OK if bridge.send(Marshalls.raw_to_base64(bytes)) else ERR_INVALID_DATA

func set_speed(value: float) -> void:
	bridge.set_speed(clampf(value, 0.0, 4.0))

func stop() -> void:
	if _closing:
		return
	_closing = true
	if _started and _reported:
		bridge.stop()
	else:
		bridge.terminate()
		queue_free()

func _fail(message: String) -> void:
	set_process(false)
	_closing = true
	if bridge:
		bridge.terminate()
	failed.emit(message)
	queue_free()

func _exit_tree() -> void:
	if bridge:
		bridge.terminate()

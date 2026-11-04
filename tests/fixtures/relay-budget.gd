extends Node

class Relay extends SimulationClient:
	var acknowledgements := []
	var delivered := []
	var failures := []
	var slow := false

	func open() -> void:
		_relay = true
		connected = true
		identity = 7
		Net.simulation_packet.connect(_relay_packet)
		Net.simulation_failed.connect(_error)

	func _send(kind: int, _payload: PackedByteArray, sequence := 0) -> Error:
		assert(kind == ACK)
		acknowledgements.append(sequence)
		return OK

	func _dispatch(kind: int, payload: PackedByteArray) -> bool:
		if slow:
			OS.delay_usec(3000)
		return super._dispatch(kind, payload)


func snapshot(sequence: int) -> PackedByteArray:
	var data := PackedByteArray()
	data.resize(4)
	data.encode_float(0, sequence)
	return SimulationClient.packet(SimulationClient.SNAPSHOT, sequence, data)


func _ready() -> void:
	var closed := SimulationClient.new()
	closed.host = ENetConnection.new()
	assert(closed.host.create_host(1, 3) == OK)
	closed.peer = closed.host.connect_to_host("127.0.0.1", 9, 3)
	assert(closed.peer != null and closed.peer.is_active())
	closed.peer.reset()
	assert(not closed.peer.is_active())
	closed.close()
	closed.close()
	closed.free()
	var client := Relay.new()
	client.received.connect(func(_kind, data): client.delivered.append(int(data.decode_float(0))))
	client.failed.connect(func(message): client.failures.append(message))
	client.open()
	for i in range(1, 601):
		client._relay_packet(0, snapshot(i))
	assert(client.delivered.is_empty() and client.acknowledgements.is_empty(), "Network callbacks must not decode or acknowledge queued packets")
	client._process(0.0)
	assert(not client.delivered.is_empty() and client.delivered.size() <= 256, "One frame drains a bounded packet count")
	assert(client._relay_pending.size() == 600 - client.delivered.size())
	assert(client._relay_bytes == client._relay_pending.size() * 20)
	assert(client.acknowledgements.back() == client.delivered.back(), "Acknowledge only state actually decoded")
	while not client._relay_pending.is_empty():
		client._process(0.0)
	assert(client.delivered == range(1, 601), "Bursts retain reliable packet order across frames")
	assert(client._relay_bytes == 0 and client.failures.is_empty())
	client.close()
	client.open()
	client.delivered.clear()
	client.acknowledgements.clear()
	client.slow = true
	for i in range(1, 4):
		client._relay_packet(0, snapshot(i))
	client._process(0.0)
	assert(client.delivered == [1] and client.acknowledgements == [1], "An expensive packet finishes, then yields the rest of the burst")
	assert(client._relay_pending.size() == 2)
	client.close()
	assert(client._relay_pending.is_empty() and client._relay_bytes == 0 and client._sequence == 0, "Closing discards queued state before reconnect")
	client.slow = false
	client.open()
	client._relay_packet(0, snapshot(3))
	client._process(0.0)
	assert(not client.connected and client.failures.size() == 1, "Queued decoding still rejects reordered reliable packets")
	assert(client._relay_pending.is_empty() and client._relay_bytes == 0)
	client.open()
	var large := snapshot(1)
	large.resize(SimulationClient.MAX_PACKET)
	while client.connected:
		client._relay_packet(0, large)
	assert(client.failures.size() == 2 and client._relay_bytes == 0, "Byte overflow closes and frees a stalled relay")
	client.open()
	for i in SimulationClient.MAX_RELAY_PACKETS:
		client._relay_packet(0, snapshot(1))
	assert(client.connected)
	client._relay_packet(0, snapshot(1))
	assert(not client.connected and client.failures.size() == 3 and client._relay_pending.is_empty(), "Tiny packets cannot bypass the queue's count limit")
	client.open()
	client.delivered.clear()
	client.acknowledgements.clear()
	client.received.connect(func(_kind, data):
		if int(data.decode_float(0)) == 2:
			client.close())
	for i in range(1, 4):
		client._relay_packet(0, snapshot(i))
	while client.connected:
		client._process(0.0)
	assert(client.delivered == [1, 2] and client._relay_pending.is_empty(), "Closing from a received event must discard the rest of the burst")
	assert(client.acknowledgements.is_empty() or client.acknowledgements.back() == 1)
	client.free()
	print("RELAY_BUDGET passed")
	get_tree().quit()

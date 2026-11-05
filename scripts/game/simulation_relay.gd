extends Node
## The existing lobby port forwards opaque simulation packets through its established NAT mapping.

var player := 0
var host: ENetConnection
var peer: ENetPacketPeer
var connection := {}

func start(id: int, config: Dictionary) -> Error:
	player = id
	connection = config
	host = ENetConnection.new()
	var error := host.create_host(1, 3)
	if error != OK:
		return error
	peer = host.connect_to_host(String(config.address), int(config.port), 3)
	if peer == null:
		return ERR_CANT_CONNECT
	peer.set_timeout(32, 10000, 30000)
	return OK

func receive(data: PackedByteArray, presence := false) -> void:
	if data.size() < 16 or data.size() > SimulationClient.MAX_PACKET or data[6] == SimulationClient.AUTH:
		_fail("Invalid simulation request.")
		return
	if presence and data[6] != SimulationClient.SEND_PRESENCE:
		_fail("Invalid screen presence.")
		return
	if peer and peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
		peer.send(1 if presence else 0, data, 0 if presence else ENetPacketPeer.FLAG_RELIABLE)

func _process(_dt: float) -> void:
	if not host:
		return
	var started := Time.get_ticks_usec()
	for _i in 256:
		var event := host.service(0)
		match int(event[0]):
			ENetConnection.EVENT_NONE:
				break
			ENetConnection.EVENT_CONNECT:
				peer.send(0, SimulationClient.packet(SimulationClient.AUTH, 0, JSON.stringify({"token": connection.token, "engine": connection.engine}).to_utf8_buffer()), ENetPacketPeer.FLAG_RELIABLE)
			ENetConnection.EVENT_RECEIVE:
				var data := peer.get_packet()
				match int(event[3]):
					0: Net._simulation_down.rpc_id(player, data)
					1: Net._simulation_snapshot.rpc_id(player, data)
					2: Net._simulation_effects.rpc_id(player, data)
			ENetConnection.EVENT_DISCONNECT, ENetConnection.EVENT_ERROR:
				_fail("The simulation connection closed.")
				return
		if Time.get_ticks_usec() - started >= 1000:
			break
	host.flush()

func _fail(message: String) -> void:
	if Net.players.has(player):
		Net._simulation_failed.rpc_id(player, message)
	close()

func close() -> void:
	if host:
		if peer:
			peer.peer_disconnect_now()
		host.destroy()
	host = null
	peer = null

func _exit_tree() -> void:
	close()

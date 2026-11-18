extends Node
## Online co-op over ENet (LAN or direct IP). The host runs the whole game and sends
## snapshots; clients send their input and button presses. Steam lobbies can replace
## ENet later by swapping the peer in host() and join().

const PORT := 7777
const MAX_PLAYERS := 4
const SNAP_RATE := 20.0

var main: Node
var mode := "offline"          # offline, host, client
var lobby_peers: Array = []    # host: peer ids in join order, host (1) first
var smith_of_peer := {}        # host: peer id -> smith index
var my_smith := 0
var autostart := 0             # host: start automatically at this many players
var snap_t := 0.0
var last_move := Vector2.ZERO
var last_sprint := false
var last_hold := false
var scripted_input := false   # tests drive last_move themselves

func host(port: int = PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "host"
	lobby_peers = [1]
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return OK

func join(ip: String, port: int = PORT) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "client"
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_host_left)
	return OK

func _on_connected() -> void:
	main.hud.show_lobby("Connected", "Waiting for the host to start...", false)

func _on_failed() -> void:
	main.hud.show_big("Couldn't connect", "Check the IP and that the host is running. Restart to try again.")

func _on_host_left() -> void:
	main.over = true
	main.hud.show_big("The host left", "Restart the game to play again.")

func lobby_text() -> String:
	return "Players: %d/%d\nOthers join with your IP address, port %d." % [lobby_peers.size(), MAX_PLAYERS, PORT]

# ---------------------------------------------------------------- host side

func _on_peer_connected(id: int) -> void:
	if main.run_started or lobby_peers.size() >= MAX_PLAYERS:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
		return
	lobby_peers.append(id)
	main.hud.show_lobby("Hosting", lobby_text(), true)
	_lobby.rpc(lobby_peers.size())
	if autostart > 0 and lobby_peers.size() >= autostart:
		host_start()

func _on_peer_disconnected(id: int) -> void:
	lobby_peers.erase(id)
	if smith_of_peer.has(id):
		var p = main.players[smith_of_peer[id]]
		p.in_move = Vector2.ZERO
		p.in_sprint = false
		p.in_hold = false
		main.toast(p.role["name"] + " disconnected")
		smith_of_peer.erase(id)
	elif not main.run_started:
		main.hud.show_lobby("Hosting", lobby_text(), true)

func host_start() -> void:
	smith_of_peer.clear()
	for i in lobby_peers.size():
		smith_of_peer[lobby_peers[i]] = i
	my_smith = 0
	main.start_run(lobby_peers.size())
	for id in lobby_peers:
		if id != 1:
			_start.rpc_id(id, lobby_peers.size(), smith_of_peer[id])
	main.send_area()

func peer_of(smith: int) -> int:
	for id in smith_of_peer:
		if smith_of_peer[id] == smith:
			return id
	return 0

func send_event(kind: String, data = null) -> void:
	if mode == "host" and lobby_peers.size() > 1:
		_event.rpc(kind, data)

func say_to(smith: int, msg: String) -> void:
	var id := peer_of(smith)
	if id > 1:
		_event.rpc_id(id, "say", msg)

func _physics_process(delta: float) -> void:
	if mode == "host" and main.run_started and lobby_peers.size() > 1:
		snap_t += delta
		if snap_t >= 1.0 / SNAP_RATE:
			snap_t = 0.0
			_snapshot.rpc(main.make_snapshot())
	elif mode == "client" and main.run_started:
		_net_input.rpc_id(1, last_move, last_sprint, last_hold)

# ---------------------------------------------------------------- RPCs

@rpc("authority", "call_remote", "reliable")
func _lobby(count: int) -> void:
	main.hud.show_lobby("Connected", "Players: %d/%d\nWaiting for the host to start..." % [count, MAX_PLAYERS], false)

@rpc("authority", "call_remote", "reliable")
func _start(count: int, smith: int) -> void:
	my_smith = smith
	main.start_client(count, smith)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _net_input(move: Vector2, sprint: bool, hold: bool) -> void:
	var id := multiplayer.get_remote_sender_id()
	if mode != "host" or not smith_of_peer.has(id):
		return
	var p = main.players[smith_of_peer[id]]
	p.in_move = move.limit_length(1.0)
	p.in_sprint = sprint
	p.in_hold = hold

@rpc("any_peer", "call_remote", "reliable")
func _action(action_name: String, extra: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if mode != "host" or not smith_of_peer.has(id):
		return
	main.do_action(main.players[smith_of_peer[id]], action_name, extra)

func send_action(action_name: String, extra: Dictionary) -> void:
	_action.rpc_id(1, action_name, extra)

@rpc("authority", "call_remote", "unreliable_ordered")
func _snapshot(s: Dictionary) -> void:
	main.apply_snapshot(s)

@rpc("authority", "call_remote", "reliable")
func _event(kind: String, data) -> void:
	main.apply_event(kind, data)

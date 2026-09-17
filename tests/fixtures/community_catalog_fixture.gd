extends Node
## In-process HTTP service fixture. Numeric loopback only; never a deployment.
var server := TCPServer.new()
var replies: Array[Dictionary] = []
var requests: Array[String] = []
var _peers: Array[Dictionary] = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func start() -> String:
	if server.listen(0, "127.0.0.1") != OK: return ""
	return "http://127.0.0.1:%d" % server.get_local_port()


func enqueue(body: PackedByteArray, options: Dictionary = {}) -> void:
	var response: Dictionary = options.duplicate(true)
	response["body"] = body
	replies.append(response)


func stop() -> void:
	server.stop()
	for peer: Dictionary in _peers: peer.stream.disconnect_from_host()
	_peers.clear()
	replies.clear()


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	while server.is_connection_available():
		_peers.append({"stream": server.take_connection(), "input": "", "sent": false, "held": false})
	for index in range(_peers.size() - 1, -1, -1):
		var peer: Dictionary = _peers[index]
		var stream: StreamPeerTCP = peer.stream
		stream.poll()
		if stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_peers.remove_at(index)
			continue
		if peer.sent or peer.held: continue
		var available: int = stream.get_available_bytes()
		if available <= 0: continue
		var data: Array = stream.get_data(available)
		peer.input += data[1].get_string_from_utf8()
		if not peer.input.contains("\r\n\r\n"): continue
		requests.append(peer.input.split("\r\n")[0])
		var reply: Dictionary = replies.pop_front() if not replies.is_empty() else {"body": PackedByteArray(), "status": 500}
		if reply.get("hold", false):
			peer.held = true
			continue
		var body: PackedByteArray = reply.body
		var header: String = "HTTP/1.1 %d Fixture\r\nContent-Type: application/json\r\nConnection: close\r\n" % int(reply.get("status", 200))
		if reply.has("location"): header += "Location: %s\r\n" % reply.location
		if reply.get("chunked", false):
			header += "Transfer-Encoding: chunked\r\n\r\n"
			stream.put_data(header.to_utf8_buffer())
			stream.put_data(("%x\r\n" % body.size()).to_utf8_buffer())
			stream.put_data(body)
			stream.put_data("\r\n0\r\n\r\n".to_utf8_buffer())
		else:
			header += "Content-Length: %d\r\n\r\n" % int(reply.get("length", body.size()))
			stream.put_data(header.to_utf8_buffer())
			stream.put_data(body)
		peer.sent = true

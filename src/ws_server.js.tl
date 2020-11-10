@*=
@requires
@script_variables
@create_http_server
@create_ws_server

@requires+=
const http = require("http");

@create_http_server+=
const server = http.createServer((req, res) => {
	console.log("Received request for " + req.url);
	res.writeHead(404);
	res.end();
});

const port = process.env.PORT || 8080;
const host = "127.0.0.1"
// const host = "0.0.0.0"
server.listen(port, host, () => {
	console.log(`Server is listening on port ${port}`);
});

@requires+=
const WebSocketServer = require('websocket').server;

@create_ws_server+=
const wsserver = new WebSocketServer({
	httpServer : server,
	autoAcceptConnections: false
});

wsserver.on('request', (req) => {
	const conn = req.accept(null, req.origin);
	conn.on('message', (msg) => {
		console.log("Received message type ", msg.type);
		if(msg.type == "utf8") {
			console.log("Received message: " + msg.utf8Data);
			@decode_message
			@if_request_send_to_first_client_in_list
			@if_text_broadcast_to_others
			@if_initial_broadcast_to_others
			@if_available_send_response_back
			@if_check_status_send_response_back
		}
	});
	conn.on('close', (reasonCode, desc) => {
		console.log("Peer disconnected!");
		@remove_client_list
		console.log(clients.length, " clients remaining");
	});
	console.log("Peer connected");
	@add_to_client_list
});

@script_variables+=
let clients = []

@add_to_client_list+=
clients.push(conn)

@remove_client_list+=
const clientidx = clients.indexOf(conn);
if(clientidx != -1) {
	clients.splice(clientidx, 1);
}

@if_text_broadcast_to_others+=
if(decoded.type == "text") {
	for(let o of clients) {
		if(o != conn) {
			o.sendUTF(msg.utf8Data);
		}
	}
}

@decode_message+=
const decoded = JSON.parse(msg.utf8Data);

@if_request_send_to_first_client_in_list+=
if(decoded.type == "request") {
	if(clients.length <= 1) {
		@if_no_other_client_return_empty_initial
	} else {
		for(let o of clients) {
			if(o != conn) {
				o.sendUTF(msg.utf8Data);
				break;
			}
		}
	}
}

@if_initial_broadcast_to_others+=
if(decoded.type == "initial") {
	for(let o of clients) {
		if(o != conn) {
			o.sendUTF(msg.utf8Data);
		}
	}
}

@script_variables+=
let client_id = 100;

@if_available_send_response_back+=
if(decoded.type == "available") {
	const response = {
		type: "response",
		is_first: clients.length == 1,
		client_id: client_id
	};
	client_id++;
	conn.sendUTF(JSON.stringify(response));
}

@if_check_status_send_response_back+=
if(decoded.type == "status") {
	const response = {
		type: "status",
		num_clients: clients.length
	};
	conn.sendUTF(JSON.stringify(response));
}

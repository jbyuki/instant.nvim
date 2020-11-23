@../server/ws_server.js=
@requires
@messages_types
@script_variables
@create_http_server
@listen_http_server
@create_ws_server


@requires+=
const http = require('http');

@create_http_server+=
const server = http.createServer((req, res) => {
 	res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end("#users: " + clients.length + "\nsession-share: " + sessionshare);
});

@listen_http_server+=
const port = process.env.PORT || 8080
// const host = "0.0.0.0"; // remote usage
const host = "127.0.0.1"; // remote usage
server.listen(port, host, () => console.log(`Server is listening on port ${port}`))

@requires+=
const WebSocketServer = require('websocket').server;

@script_variables+=
var clients = [];

@create_ws_server+=
const wss = new WebSocketServer({ 
	httpServer : server,
	autoAcceptConnections: false
});
 
wss.on('request', (req) => {
    const ws = req.accept(null, req.origin);
	clients.push(ws);

	ws.on('message', (msg) => {
		if(msg.type == "utf8") {
			@decode_message
			if(decoded !== undefined) {
				@if_request_send_to_first_client_in_list
				@if_text_broadcast_to_others
				@if_initial_broadcast_to_others
				@if_available_send_response_back
				@if_info_save_client_info
			}
		}
	});
	ws.on('close', (reasonCode, desc) => {
		@remove_client_from_clients
		console.log("Peer disconnected!");
		console.log(clients.length, " clients remaining");
		@check_if_no_more_peer
		@send_client_disconnect
	});
	console.log("Peer connected");
});

@if_text_broadcast_to_others+=
if(decoded[0] == MSG_TEXT) {
	clients.forEach((client) => {
		if(client != ws) {
			client.sendUTF(msg.utf8Data);
		}
	});
}

@decode_message+=
const decoded = JSON.parse(msg.utf8Data);
// console.log(decoded)

@if_request_send_to_first_client_in_list+=
if(decoded[0] == MSG_REQUEST) {
	if(clients.length <= 1) {
		@if_no_other_client_return_empty_initial
	} else {
		let sent = false;
		// only send request to one other client
		clients.forEach((client) => {
			if(!sent && client != ws) {
				client.sendUTF(msg.utf8Data);
				sent = true;
			}
		});
	}
}

@if_initial_broadcast_to_others+=
if(decoded[0] == MSG_INITIAL) {
	clients.forEach((client) => {
		if(client != ws) {
			client.sendUTF(msg.utf8Data);
		}
	});
}

@script_variables+=
let client_id = 100;

@if_available_send_response_back+=
if(decoded[0] == MSG_INFO) {
	if(!is_initialized) {
		sessionshare = decoded[1];
		is_initialized = true;
	}

	const is_first = clients.length == 1;
	const response = [
		MSG_AVAILABLE,
		is_first,
		client_id,
		sessionshare
	];

	@send_current_connected_client_to_client
	@send_client_connect_to_other_clients
	@save_client_id

	client_id++;
	ws.sendUTF(JSON.stringify(response));
}

@script_variables+=
let is_initialized = false;
let sessionshare = false;

@check_if_no_more_peer+=
if(clients.length == 0) {
	is_initialized = false;
}

@messages_types+=
const MSG_TEXT = 1;
const MSG_AVAILABLE = 2;
const MSG_REQUEST = 3;
const MSG_INITIAL = 6;
const MSG_INFO = 5;
const MSG_CONNECT = 7;
const MSG_DISCONNECT = 8;

@remove_client_from_clients+=
var pos = clients.indexOf(ws);
clients.splice(pos, 1);

@send_client_connect_to_other_clients+=
const connect = [
	MSG_CONNECT,
	client_id,
	decoded[2],
];

clients.forEach((client) => {
	if(client != ws) {
		client.sendUTF(JSON.stringify(connect));
	}
});

@script_variables+=
const clientIDs = new Map();
const clientUsernames = new Map();

@save_client_id+=
clientIDs.set(ws, client_id);
clientUsernames.set(client_id, decoded[2]);

@send_client_disconnect+=
const remove_id = clientIDs.get(ws);
clientIDs.delete(ws);
clientUsernames.delete(remove_id);
const disconnect = [
	MSG_DISCONNECT,
	remove_id,
];

clients.forEach((client) => {
	if(client != ws) {
		client.sendUTF(JSON.stringify(disconnect));
	}
});

@send_current_connected_client_to_client+=
for(var v of clientUsernames) {
	const connect = [
		MSG_CONNECT,
		v[0],
		v[1],
	];
	ws.sendUTF(JSON.stringify(connect));
}

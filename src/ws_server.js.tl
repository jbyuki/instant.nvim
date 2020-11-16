@*=
@requires
@script_variables
@create_http_server
@create_ws_server

@requires+=
const WebSocket = require('ws');

@create_ws_server+=
const port = process.env.PORT || 8080
const wss = new WebSocket.Server({ 
	port : port,
});

wss.on('connection', (ws) => {
	ws.on('message', (msg) => {
		@decode_message
		@if_request_send_to_first_client_in_list
		@if_text_broadcast_to_others
		@if_initial_broadcast_to_others
		@if_available_send_response_back
		@if_check_status_send_response_back
		@if_info_save_client_info
	});
	ws.on('close', (reasonCode, desc) => {
		console.log("Peer disconnected!");
		console.log(wss.clients.size, " clients remaining");
		@check_if_no_more_peer
	});
	console.log("Peer connected");
});

@if_text_broadcast_to_others+=
if(decoded.type == "text") {
	wss.clients.forEach((client) => {
		if(client.readyState == WebSocket.OPEN && client != ws) {
			client.send(msg);
		}
	});
}

@decode_message+=
const decoded = JSON.parse(msg);
// console.log(decoded);

@if_request_send_to_first_client_in_list+=
if(decoded.type == "request") {
	if(wss.clients.size <= 1) {
		@if_no_other_client_return_empty_initial
	} else {
		let sent = false;
		// only send request to one other client
		wss.clients.forEach((client) => {
			if(!sent && client.readyState == WebSocket.OPEN && client != ws) {
				client.send(msg);
				sent = true;
			}
		});
	}
}

@if_initial_broadcast_to_others+=
if(decoded.type == "initial") {
	wss.clients.forEach((client) => {
		if(client.readyState == WebSocket.OPEN && client != ws) {
			client.send(msg);
		}
	});
}

@script_variables+=
let client_id = 100;

@if_available_send_response_back+=
if(decoded.type == "available") {
	const response = {
		type: "response",
		is_first: wss.clients.size == 1,
		client_id: client_id,
		sessionshare: sessionshare
	};
	client_id++;
	ws.send(JSON.stringify(response));
}

@if_check_status_send_response_back+=
if(decoded.type == "status") {
	const response = {
		type: "status",
		num_clients: wss.clients.size
	};
	ws.send(JSON.stringify(response));
}

@script_variables+=
let is_initialized = false;
let sessionshare = false;

@check_if_no_more_peer+=
if(wss.clients.size == 0) {
	is_initialized = false;
}

@if_info_save_client_info+=
if(decoded.type == "info") {
	if(!is_initialized) {
		sessionshare = decoded.sessionshare;
		is_initialized = true;
	}
}

@create_ws_server+=
wss.on('listening', () => console.log(`Server is listening on port ${port}`))

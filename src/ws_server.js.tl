@*=
@requires
@script_variables
@create_http_server
@create_ws_server

@requires+=
const WebSocket = require('ws');

@create_ws_server+=
const wss = new WebSocket.Server({ 
	port : process.env.PORT || 8080,
});

wss.on('connection', (ws) => {
	ws.on('message', (msg) => {
		@decode_message
		@if_request_send_to_first_client_in_list
		@if_text_broadcast_to_others
		@if_initial_broadcast_to_others
		@if_available_send_response_back
		@if_check_status_send_response_back
	});
	ws.on('close', (reasonCode, desc) => {
		console.log("Peer disconnected!");
		console.log(wss.clients.size, " clients remaining");
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
		client_id: client_id
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

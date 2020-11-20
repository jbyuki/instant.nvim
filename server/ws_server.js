const WebSocket = require('ws');

const MSG_TEXT = 1;
const MSG_AVAILABLE = 2;
const MSG_REQUEST = 3;
const MSG_INITIAL = 6;
const MSG_STATUS = 4;
const MSG_INFO = 5;
let client_id = 100;

let is_initialized = false;
let sessionshare = false;

const port = process.env.PORT || 8080
const wss = new WebSocket.Server({ 
	port : port,
});

wss.on('connection', (ws) => {
	ws.on('message', (msg) => {
		const decoded = JSON.parse(msg);
		// console.log(decoded)
		
		if(decoded !== undefined) {
			if(decoded[0] == MSG_REQUEST) {
				if(wss.clients.size <= 1) {
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
			
			if(decoded[0] == MSG_TEXT) {
				wss.clients.forEach((client) => {
					if(client.readyState == WebSocket.OPEN && client != ws) {
						client.send(msg);
					}
				});
			}
			
			if(decoded[0] == MSG_INITIAL) {
				wss.clients.forEach((client) => {
					if(client.readyState == WebSocket.OPEN && client != ws) {
						client.send(msg);
					}
				});
			}
			
			if(decoded[0] == MSG_AVAILABLE) {
				const is_first = wss.clients.size == 1;
				const response = [
					MSG_AVAILABLE,
					is_first,
					client_id,
					sessionshare
				];
			
				client_id++;
				ws.send(JSON.stringify(response));
			}
			
			if(decoded[0] == MSG_STATUS) {
				const num_clients = wss.clients.size;
				const response = [
					MSG_STATUS,
					num_clients
				];
				ws.send(JSON.stringify(response));
			}
			
			if(decoded[0] == MSG_INFO) {
				if(!is_initialized) {
					sessionshare = decoded[1];
					is_initialized = true;
				}
			
			}
			
		}
	});
	ws.on('close', (reasonCode, desc) => {
		console.log("Peer disconnected!");
		console.log(wss.clients.size, " clients remaining");
		if(wss.clients.size == 0) {
			is_initialized = false;
		}
		
	});
	console.log("Peer connected");
});

wss.on('listening', () => console.log(`Server is listening on port ${port}`))



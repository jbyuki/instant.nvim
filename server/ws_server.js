const WebSocket = require('ws');

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
		console.log(decoded);
		
		if(decoded.type == "request") {
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
		
		if(decoded.type == "text") {
			wss.clients.forEach((client) => {
				if(client.readyState == WebSocket.OPEN && client != ws) {
					client.send(msg);
				}
			});
		}
		
		if(decoded.type == "initial") {
			wss.clients.forEach((client) => {
				if(client.readyState == WebSocket.OPEN && client != ws) {
					client.send(msg);
				}
			});
		}
		
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
		
		if(decoded.type == "status") {
			const response = {
				type: "status",
				num_clients: wss.clients.size
			};
			ws.send(JSON.stringify(response));
		}
		
		if(decoded.type == "info") {
			if(!is_initialized) {
				sessionshare = decoded.sessionshare;
				is_initialized = true;
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


const WebSocket = require('ws');

let client_id = 100;

const wss = new WebSocket.Server({ 
	port : process.env.PORT || 8080,
});

wss.on('connection', (ws) => {
	ws.on('message', (msg) => {
		const decoded = JSON.parse(msg);
		
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
				client_id: client_id
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
	});
	ws.on('close', (reasonCode, desc) => {
		console.log("Peer disconnected!");
		console.log(wss.clients.size, " clients remaining");
	});
	console.log("Peer connected");
});



const http = require('http');

const WebSocketServer = require('websocket').server;

const MSG_TEXT = 1;
const MSG_AVAILABLE = 2;
const MSG_REQUEST = 3;
const MSG_INITIAL = 6;
const MSG_STATUS = 4;
const MSG_INFO = 5;
const MSG_CONNECT = 7;
const MSG_DISCONNECT = 8;

var clients = [];

let client_id = 100;

let is_initialized = false;
let sessionshare = false;

const clientIDs = new Map();
const clientUsernames = new Map();

const server = http.createServer((req, res) => {
 	res.writeHead(200, { 'Content-Type': 'text/plain' });
    res.end("#users: " + clients.length + "\nsession-share: " + sessionshare);
});

const port = process.env.PORT || 8080
// const host = "0.0.0.0"; // remote usage
const host = "127.0.0.1"; // remote usage
server.listen(port, host, () => console.log(`Server is listening on port ${port}`))

const wss = new WebSocketServer({ 
	httpServer : server,
	autoAcceptConnections: false
});
 
wss.on('request', (req) => {
    const ws = req.accept(null, req.origin);
	clients.push(ws);

	ws.on('message', (msg) => {
		if(msg.type == "utf8") {
			const decoded = JSON.parse(msg.utf8Data);
			// console.log(decoded)
			
			if(decoded !== undefined) {
				if(decoded[0] == MSG_REQUEST) {
					if(clients.length <= 1) {
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
				
				if(decoded[0] == MSG_TEXT) {
					clients.forEach((client) => {
						if(client != ws) {
							client.sendUTF(msg.utf8Data);
						}
					});
				}
				
				if(decoded[0] == MSG_INITIAL) {
					clients.forEach((client) => {
						if(client != ws) {
							client.sendUTF(msg.utf8Data);
						}
					});
				}
				
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
				
					for(var v of clientUsernames) {
						const connect = [
							MSG_CONNECT,
							v[0],
							v[1],
						];
						ws.sendUTF(JSON.stringify(connect));
					}
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
					
					clientIDs.set(ws, client_id);
					clientUsernames.set(client_id, decoded[2]);
					
				
					client_id++;
					ws.sendUTF(JSON.stringify(response));
				}
				
				if(decoded[0] == MSG_STATUS) {
					const num_clients = clients.length;
					const response = [
						MSG_STATUS,
						num_clients
					];
					ws.sendUTF(JSON.stringify(response));
				}
				
			}
		}
	});
	ws.on('close', (reasonCode, desc) => {
		var pos = clients.indexOf(ws);
		clients.splice(pos, 1);
		
		console.log("Peer disconnected!");
		console.log(clients.length, " clients remaining");
		if(clients.length == 0) {
			is_initialized = false;
		}
		
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
		
	});
	console.log("Peer connected");
});




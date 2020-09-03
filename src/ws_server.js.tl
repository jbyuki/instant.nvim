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
			@broadcast_to_others
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

@broadcast_to_others+=
for(let o of clients) {
	if(o != conn) {
		o.sendUTF(msg.utf8Data);
	}
}

const WebSocketClient = require('websocket').client;

const MSG_TEXT = 1;
const MSG_AVAILABLE = 2;
const MSG_REQUEST = 3;
const MSG_INITIAL = 6;
const MSG_STATUS = 4;
const MSG_INFO = 5;

const OP_DEL = 1;
const OP_INS = 2;


let session_share;

let allprev = {};
let prev = [ "" ];
let client_id;

let MAXINT = 2**20;
let allpids = {};
let pids = [];

let allbufname = {};


function findCharPositionBefore(opid)
{
	let y1 = 0;
	let y2 = pids.length-1;
	while(true) {
		let ym = Math.floor((y2 + y1)/2);
		if(ym == y1) {
			break;
		}
	
		if(isLowerOrEqual(pids[ym][0], opid)) {
			y1 = ym
		} else {
			y2 = ym
		}
	}
	
	let px = 0;
	let py = 0;

	for(let y=y1; y<pids.length; ++y) {
		for(let x=0; x<pids[y].length; ++x) {
			let pid = pids[y][x];
			if(!isLowerOrEqual(pid, opid)) {
				return [px, py];
			}
			px = x;
			py = y;
		}
	}
}

function isLowerOrEqual(a, b)
{
	for(let i=0; i<a.length; ++i) {
		if(i >= b.length) return false;
		let ai = a[i];
		let bi = b[i];
		if(ai[0] < bi[0]) return true;
		else if(ai[0] > bi[0]) return false;
		else if(ai[1] < bi[1]) return true;
		else if(ai[1] > bi[1]) return false;
	}
	return true;
}

function splitAt(a, x)
{
	return [
		a.slice(0, x),
		a.slice(x)
	];
}

function stringInsertAt(s, pos, c)
{
	const [l, r] = splitAt(s, pos)
	return l + c + r;
}

function findCharPositionExact(opid)
{
	let y1 = 0;
	let y2 = pids.length-1;
	while(true) {
		let ym = Math.floor((y2 + y1)/2);
		if(ym == y1) {
			break;
		}
	
		if(isLowerOrEqual(pids[ym][0], opid)) {
			y1 = ym
		} else {
			y2 = ym
		}
	}
	
	let y = y1;
	for(var x = 0; x < pids[y].length; ++x) {
		let pid = pids[y][x];
		if(isPIDEqual(pid, opid)) {
			return [x, y];
		}
	
		if(!isLowerOrEqual(pid, opid)) {
			return [-1, -1];
		}
	}
	
	return [-1, -1];
}

function isPIDEqual(a, b)
{
	if(a.length != b.length) return false
	for(let i=0; i<a.length; ++i) {
		if(a[i][0] != b[i][0]) return false
		if(a[i][1] != b[i][1]) return false
	}
	return true;
}

function stringRemoveAt(s, pos)
{
	return s.slice(0, pos) + s.slice(pos+1);
}


if(process.argv.length <= 3 && process.argv.length > 5) {
	console.error("INFO: node dummy_client.js [SHARE_TYPE] [HOST] (PORT)");
	console.error("SHARE_TYPE: session | single");
	console.error("PORT: optional, defaults to 80");
	process.exit(1);
}

const host = process.argv[3];

let port = 80;
if(process.argv.length == 5) {
	port = parseInt(process.argv[4]);
}

switch(process.argv[2]) {
case "session":
	session_share = true;
	break;
case "single":
	session_share = false;
	break;
default:
	console.error("Invalid SHARE_TYPE : " + process.argv[2]);
	console.error("Expected session or single");
	process.exit(1);
}

const client = new WebSocketClient();


client.on('connectFailed', (error) => {
	console.log("Connect Error: " + error.toString());
});

client.on('connect', (ws) => {
	console.log("Connected!");

	ws.on('error', (error) => {
		console.log("Connection error: " + error.toString());
	});

	ws.on('close', (error) => {
		console.log('Connection Closed.');
	});

	ws.on('message', (msg) => {
		if(msg.type == "utf8") {
			const decoded = JSON.parse(msg.utf8Data);
			
			if(decoded !== undefined) {
				console.log(decoded);
				if(decoded[0] == MSG_AVAILABLE) {
					if(decoded[3] != session_share) {
						console.error("Server already initialised with a different SHARE_TYPE")
						console.error("Server: session_share " + decoded[3]);
						console.error("Client: session_share " + session_share);
						process.exit(1);
					}
					
					client_id = decoded[2];
					
					if(decoded[1]) { // check if first
						let startpos = [[0, 0]], endpos = [[MAXINT, 0]]
						let middlepos = [[Math.floor(MAXINT/2), client_id]]
						
						pids = [
							[ startpos ],
							[ middlepos ],
							[ endpos ],
						];
						
						let remote = [client_id, 1];
						let bufname = ""
						allprev[remote] = prev
						allpids[remote] = pids
						
						allbufname[remote] = bufname
						
						
					} else {
						if(decoded[1] == false) {
							const request = [
								MSG_REQUEST
							];
							ws.sendUTF(JSON.stringify(request));
						}
						
					}
				}
				
				if(decoded[0] == MSG_INITIAL) {
					const [, bufname, remote, pidslist, content] = decoded;
					const [ag, bufid] = remote
				
					if(!session_share)  {
						remote = 1; // ignore remote buffer id
					}
				
					prev = content
					
					let pidindex = 0;
					pids = [];
					
					pids.push([[[ pidslist[pidindex], 0 ]]])
					
					pidindex++;
					
					for(let line of content) {
						let lpid = [];
						for(let i=0; i<line.length; ++i) {
							lpid.push([[ pidslist[pidindex], ag ]])
							pidindex++;
						}
						pids.push(lpid);
					}
					
					pids.push([ [ [ pidslist[pidindex], 0 ] ] ])
					
					allbufname[remote] = bufname
					
				
					allprev[remote] = prev
					allpids[remote] = pids
					
				}
				
				
				if(decoded[0] == MSG_TEXT) {
					const [, op, remote, other_agent] = decoded
				
					pids = allpids[remote];
					prev = allprev[remote];
					
				
					if(op[0] == OP_INS) {
						const [x, y] = findCharPositionBefore(op[2]);
						console.log("char position: " + JSON.stringify([x,y]));
						
						if(op[1] == "\n") {
							const [py, py1] = splitAt(pids[y], x+1)
							pids[y] = py
							py1.splice(0, 0, op[2]);
							pids.splice(y+1, 0, py1);
						} else {
							pids[y].splice(x+1, 0, op[2]);
						}
						
						if(op[1] == "\n") {
							if(y-1 >= 0) {
								const [l, r] = splitAt(prev[y-1], x)
								prev[y-1] = l
								prev.splice(y, 0, r)
							} else {
								prev.splice(y, 0, "")
							}
						} else {
							prev[y-1] = stringInsertAt(prev[y-1], x, op[1])
						}
						
						
					} else if(op[0] == OP_DEL) {
						const [sx, sy] = findCharPositionExact(op[1])
						
						if(sx != -1) {
							if(sx == 0) {
								if(sy-2 >= 0) {
									prev[sy-2] = prev[sy-2] + prev[sy-1]
								}
								prev.splice(sy-1, 1)
							} else {
								if(sy > 0) {
									prev[sy-1] = stringRemoveAt(prev[sy-1], sx-1);
								}
							}
							
							if(sx == 0) {
								for(var i = 0; i < pids[sy].length; ++i) {
									let pid = pids[sy][i];
									if(i > 0) {
										pids[sy-1].push(pid)
									}
								}
								pids.splice(sy, 1);
							} else {
								pids[sy].splice(sx, 1);
							}
						}
						
					}
					console.log(prev);
					for(let lpid of pids) {
						console.log(lpid)
					}
					allprev[remote] = prev
					allpids[remote] = pids
					
				}
				
				if(decoded[0] == MSG_REQUEST) {
					for(let rem in allprev) {
						prev = allprev[rem]
						pids = allpids[rem]
						bufname = allbufname[rem]
				
						let pidslist = [];
						for(let lpid of pids) {
							for(let pid of lpid) {
								pidslist.push(pid[0][0])
							}
						}
						
						const [ag, bufid] = rem.split(",");
						
						let initial = [
							MSG_INITIAL,
							bufname,
							[parseInt(ag), parseInt(bufid)],
							pidslist,
							prev,
						];
						
						ws.sendUTF(JSON.stringify(initial));
					}
				}
				
			}
		}
	});
	const info = [
		MSG_INFO,
		session_share,
		"BUFFER_KEEPER",
	];
	
	ws.sendUTF(JSON.stringify(info));
	
});

client.connect(`${host}:${port}`);



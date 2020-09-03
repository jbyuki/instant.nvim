NTrance Client-Client Protocol
==============================

**This is a prototype. All protocol decisions are subject to change rapidely!**

Protocol
--------

The protocol is as follows:

* The first client connects to the server via `NTranceStart`
    * Websocket handshake
	* Send an `available` message from client
	* The server responds if server is available or not
		* If not available: close client with error
		* If available, everything OK

* A second client connects to the server via `NTraceJoin`
    * Websocket handshake
	* Send an `available` message from client
		* If available: close client with error
	* If available send `request` message from client
	* Server sends the request to another already connected client
	* Client responds with `initial` message which contains the whole content
	* Server broadcasts to clients
	* Client receives `initial` message and sets the buffer content
		* Note: other clients also receives it but discards it

* During text edit:
	* Client send `text` message with edits
	* Server broadcast to other clients
	* Client receive and edit the text accordingly


Messages
--------

All messages are encoded in JSON.

The `available` message

'''
{
	type: "available"
}
'''

The `response` message sent by the server when an `available` message is received

'''
{
	type: "response",
	is_first: boolean
}
'''

The `request` message
'''
{
	type: "request"
}
'''

The `initial` message
'''
{
	type: "initial",
	text: string
}
'''

The `text` message
'''
{
	type: "text",
	firstline: integer,
	lastline: integer,
	text: string
}
'''

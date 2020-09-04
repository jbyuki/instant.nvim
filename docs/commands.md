Commands 
========

This is a list of commands defined by the ntrance plugin.

### `NTranceStart [host] [port (default: 80]`

This command is used by the first client which connects to the server.
The ntrance instance is attached to the current buffer.
At the moment, it doesn't support attaching multiple instances of ntrance 
on different buffers in the same neovim instance.

To connect to the local host:

```
:NTranceStart 127.0.0.1 8080
```

To connect to a remote server:

```
:NTranceStart remoteserver.com
```

Prints a `connected!` message in case of a successful connection. Otherwise it should display an error.

### `NTranceJoin [host] [port (default: 80]`

This command is used by subsequent clients who wants to connect to a server. It will
issue a special `request` message which will tell the other clients to send the initial content.

The syntax is identical to `NTranceStart`.


### `NTranceStop`

Interrupts the connection to the server. It also detaches ntrance from the buffer.

### `NTranceRefresh`

It forces a full content resync on the current buffer.

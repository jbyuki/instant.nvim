Commands 
========

This is a list of commands defined by the instant.nvim plugin.

### `InstantStartSingle [host] [port (default: 80)]`

This command is used to share the current buffer only. It is convenient for single file sharing as it does not require any settings.

### `InstantJoinSingle [host] [port (default: 80)]`

Joins a server where a `InstantStartSingle` was initiated. Overwrites the current buffer with the shared content.

### `InstantStopSingle`

Interrupts the connection to the server. It also detaches instant.nvim from the buffer. This command is automatically called on exit.

### `InstantStatus`

Shows the current connection status. In case the client is connected, it shows how many clients are connected on the server.

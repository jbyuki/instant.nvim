Commands 
========

This is a list of commands defined by the instant.nvim plugin.

### `InstantStopSingle`

Interrupts the connection to the server. It also detaches instant.nvim from the buffer. This command is automatically called on exit.

### `InstantStartSingle [host] [port (default: 80)]`

This command is used to share the current buffer only. It is convenient for single file sharing as it does not require any settings.

### `InstantJoinSingle [host] [port (default: 80)]`

Joins a server where a `InstantStartSingle` was initiated. Overwrites the current buffer with the shared content.

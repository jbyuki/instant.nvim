Commands 
========

This is a list of commands defined by the instant.nvim plugin.

### `InstantStart [host] [port (default: 80)]`

This command is used by the first client which connects to the server.
The current working directory should be either:
* empty
* contain instant.json and other files

Otherwise, an error is returned.

When invoked on a empty folder, the plugin will create a instant.json. This file contains various informations and settings. It has two purpose:

* Set sharing settings and save some infos ( author, creation date,... )
* Ensure that the folder is meant to be shared

To connect to the local host:

```
:InstantStart 127.0.0.1 8080
```

To connect to a remote server:

```
:InstantStart remoteserver.com
```

Prints a `connected!` message in case of a successful connection. Otherwise it should display an error.

### `InstantJoin [host] [port (default: 80)]`

This command is used by subsequent clients who wants to connect to a server. Similarly to `InstantStart` the folder should already contain a instant.json or be empty.


### `InstantStop`

Interrupts the connection to the server. It also detaches instant.nvim from the buffer. This command is automatically called on exit.

### `InstantRefresh`

It forces a full content resync on the current buffer.

### `InstantStartSingle [host] [port (default: 80)]`

This command is used to share the current buffer only. It is convenient for single file sharing as it does not require any settings.

### `InstantJoinSingle [host] [port (default: 80)]`

Joins a server where a `InstantStartSingle` was initiated. Overwrites the current buffer with the shared content.

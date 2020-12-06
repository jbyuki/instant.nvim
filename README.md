instant.nvim
============

**instant.nvim** is a **collaborative editing** plugin for **Neovim** written in **Lua** with no dependencies.

> A minimalist plugin for collaborative editing

* [Design document](https://github.com/jbyuki/instant.nvim/wiki/Design-Document)
* [Protocol](https://github.com/jbyuki/instant.nvim/wiki/Protocol)
* [Deploy a server](https://github.com/jbyuki/instant.nvim/wiki/Deploy-a-server)
* [API](https://github.com/jbyuki/instant.nvim/wiki/API)
* [Commands](https://github.com/jbyuki/instant.nvim/wiki/Commands)
* [Technical Overview](https://github.com/jbyuki/instant.nvim/wiki/Technical-Overview)

[![Untitled-Project.gif](https://i.postimg.cc/wxDFX40G/Untitled-Project.gif)](https://postimg.cc/fkTxZC4c)

Features
--------

* Powerful collaborative editing algorithm

* UTF-8 Support

* Single or multiple buffer sharing

* Virtual cursors with username of other clients

* Spectate actions of a user

* Built-in localhost server

* Separated undo/redo for each user

* Different color for each user

Requirements
------------

* Neovim 0.4.4 or above

Install
-------

Install using a plugin manager such as [vim-plug](https://github.com/junegunn/vim-plug).

```
Plug 'jbyuki/instant.nvim'
```

Configurations
--------------

* Set your username in `init.vim`:

```
let g:instant_username = "USERNAME"
```

See [here](https://github.com/jbyuki/instant.nvim/wiki/Customization) for more customization options.

Usage
-----

The collaborative editing plugin works with a server which connects together the clients. Thus, a server must be running which must be reachable by all clients.

### Server (Neovim or node.js)

For a localhost or LAN network, you can simple use the built-in server included in the plugin.

* Start it with `:InstantStartServer`
* When done stop it with `:InstantStopServer`

For a more advanced (remote server) overview see [Deploy a server](https://github.com/jbyuki/instant.nvim/wiki/Deploy-a-server)

### Client (Neovim)

To start the client, the first user to connect to the server must initiates the share with a special commands with has the form `InstantStart...`. Subsequent joining clients, use a different command `InstantJoin...`. Having distinct commands to start and join a server ensures that files are not overwritten by accident on connection.

There are essentially two modes of sharing at the moment.

* **Single buffer sharing**: This will only share the current buffer. 
* **Session sharing**: This will share all opened (and newly opened) buffers with the other clients. This can be thought of directory sharing without implicit writing on the file system.

For single buffer sharing use:
* `:InstantStartSingle [host] [port]` : Host is the URL or IP address. Port is 80 by default. Use this command if you're the first client to connect.
* `:InstantJoinSingle [host] [port]` : Use this command if another client already initiated a single share.
* `:InstantStop` : This will stop the client

For session sharing:

* `:InstantStartSession [host] [port]` : If you're the first client to connect.
* `:InstantJoinSession [host] [port]` : Use this command if another client already initiated a session share
* `:InstantStop`

Additional useful sharing commands are:

* `:InstantStatus` : Display the current connected clients as well as their locations
* `:InstantFollow [user]`
* `:InstantStopFollow`
* `:InstantOpenAll` : Open all files in buffers in the current directory. Useful to share the whole directory in session sharing.
* `:InstantSaveAll` : Save all opened buffers automatically. This will also create missing subdirectories.

### Tips and Tricks

* If there is an issue, you can resync by stopping and reconnecting.
* In session sharing, view all the available buffers with `:ls`.

### Help

* If you encounter any problem, please don't hesitate to open an [Issue](https://github.com/jbyuki/instant.nvim/issues)
* All contributions are welcome

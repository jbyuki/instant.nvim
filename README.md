instant.nvim
============

> instant.nvim is a **collaborative editing** plugin for Neovim.

[![Untitled-Project.gif](https://i.postimg.cc/wxDFX40G/Untitled-Project.gif)](https://postimg.cc/fkTxZC4c)

Features
--------

* Powerful collaborative editing algorithm

* Single buffer sharing

* Multiple buffer sharing (Session sharing)

* Virtual cursors with username of other clients

* Spectate a user while he edits

* Builtin localhost server

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

* Set your username in your `init.vim`

```
let g:instant_username = "USERNAME"
```

See [here](https://github.com/jbyuki/instant.nvim/wiki/Customization) for more customization options.

Usage
-----

### Server (Neovim or node.js)

Start the server in localhost

1. `:InstantStartServer`
2. When the message `Server is listening on port 8080...` appears, the server is ready

For a more advanced (remote server) overview see [Deploy a server](https://github.com/jbyuki/instant.nvim/wiki/Deploy-a-server)

**Note**: The server will stop automatically when closing. To stop the server explicitely use `:InstantStopServer`.

### Client (Neovim)

Depending on your usage, buffer can be shared in two modes:

* [Single buffer sharing](#buffer-sharing)

* [Multiple buffer sharing](#session-sharing)


#### Buffer sharing

The will only share the current buffer with the other clients.

##### Client 1
1. `:InstantStartSingle 127.0.0.1 8080`
2. A `Connected!` notification should appear

##### Client 2
1. `:InstantJoinSingle 127.0.0.1 8080`
2. Now the two current buffers are synced

When done the connection can be stopped with `:InstantStop`

#### Session sharing

For a more advanced sharing setup. It shares all opened buffers (including hidden, not special) with
the other user. Newly created buffers are automatically synced.

[![Untitled-Project.gif](https://i.postimg.cc/ydM961f3/Untitled-Project.gif)](https://postimg.cc/gXKrNWbG)

##### Client 1
1. `:InstantStartSession 127.0.0.1 8080`

##### Client 2
1. `:InstantJoinSession 127.0.0.1 8080`

Like with single buffer share, stop the connection with `:InstantStop`

**Note**: 

* The current connection status can be printed with `:InstantStatus`
* A user can be followed through its text edits with `:InstantFollow [username]`
* To stop the follow, call `:InstantStopFollow`
* For convenience, there are `InstantOpenAll` and `InstantSaveAll` which will open or save all files in the current directory


### Further Links

* [Deploy a server](https://github.com/jbyuki/instant.nvim/wiki/Deploy-a-server)
* [API](https://github.com/jbyuki/instant.nvim/wiki/API)
* [Design document](https://github.com/jbyuki/instant.nvim/wiki/Design-Document)
* [Protocol](https://github.com/jbyuki/instant.nvim/wiki/Protocol)
* [Commands](https://github.com/jbyuki/instant.nvim/wiki/Commands)
* [Technical Overview](https://github.com/jbyuki/instant.nvim/wiki/Technical-Overview)

### Others

* If you encounter any problem, please don't hesitate to open an [Issue](https://github.com/jbyuki/instant.nvim/issues)

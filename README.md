ntrance.nvim
============

ntrance is a collaborative remote editing plugin for Neovim written in Lua with no dependencies.

**This is in prototype stage. It should work but some important features are still missing!**

* [Design document](docs/design.md)
* [Protocol](docs/protocol.md)
* [Commands](docs/commands.md)

Requirements
------------

* Neovim (tested on 0.5 but should work on previous versions)

Install
-------

The easiest is to install using a plugin manager such as [vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'jbuyki/ntrance.nvim'
```

Usage
-----

* First time user, you have to setup your username. Put this in your $MYVIMRC

```
lua vim.g.ntrance_username = "YOUR USERNAME"
```

* Fire up the websocket server (server/ws_server.js)
* Connect the first client with:
	* `:NTranceStart 127.0.0.1 8080`
* Connect another client with:
	* `:NTranceJoin 127.0.0.1 8080`
* To stop the connection:
	* `:NTranceStop`

Todo
----

* Should display a message when connection is lost

Known Issues
------------

* The connection cannot be per-buffer because for some reason the handle returned by the TCP connection `vim.loop.new_tcp` cannot be assigned to a buffer scope variable `vim.b`. It returns `Cannot convert userdata`.

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

* Fire up the websocket server (server/ws_server.js)
* Connect the first client with `NTranceStart 127.0.0.1 8080`
* `NTranceJoin 127.0.0.1 8080` on other clients
* To stop `NTranceStop`

Todo
----

* Should display a message when connection is lost
* Show id when editing

Known Issues
------------

* The connection cannot be per-buffer because for some reason the handle returned by the TCP connection `vim.loop.new_tcp` cannot be assigned to a buffer scope variable `vim.b`. It returns `Cannot convert userdata`.

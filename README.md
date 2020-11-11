instant.nvim
============

**instant.nvim** is a **collaborative** editing plugin for **Neovim** written in **Lua** with no dependencies.

**This is in prototype stage. It should work but some important features are still missing!**
**The transfer protocol is not optimized for large files transfer!**

* [Design document](docs/design.md)
* [Protocol](docs/protocol.md)
* [Commands](docs/commands.md)

[![showcase.gif](https://i.postimg.cc/d3rcgL4K/showcase.gif)](https://postimg.cc/ZvbQdYGf)

Features
--------

* Live editing with multiple users

* Share a buffer

* See who is editing

Requirements
------------

* Neovim 0.5 (but might work on previous versions)

Install
-------

Install using a plugin manager such as [vim-plug](https://github.com/junegunn/vim-plug).

```
Plug 'jbyuki/instant.nvim'
```

Configurations
--------------

* Set your username in your $MYVIMRC. This **must be** set to start or join a server.

```
let g:instant_username = "USERNAME"
```

Usage
-----

### Buffer sharing

1. Fire up [ws_server.js](server/ws_server.js) using [node.js](https://nodejs.org/en/).
2. Open an instance and connect to the server.
```
:InstantStartSingle 127.0.0.1 8080
```
3. Open another instance and join.
```
:InstantJoinSingle 127.0.0.1 8080
```
4. Now the two buffers are synced

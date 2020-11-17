instant.nvim
============

**instant.nvim** is a **collaborative** editing plugin for **Neovim** written in **Lua** with no dependencies.

**This is in prototype stage. It should work but some important features are still missing!**
**The transfer protocol is not optimized for large files transfer!**

* [Design document](https://github.com/jbyuki/instant.nvim/wiki/Design-Document)
* [Protocol](https://github.com/jbyuki/instant.nvim/wiki/Protocol)
* [Commands](https://github.com/jbyuki/instant.nvim/wiki/Commands)

[![Untitled-Project.gif](https://i.postimg.cc/jjnrHMjY/Untitled-Project.gif)](https://postimg.cc/qtrY0Xn1)

Features
--------

* Live editing with multiple users

* Share a buffer

* See who is editing

* Share a session

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

* Set your username in your $MYVIMRC. This **must be** set to start or join a server.

```
let g:instant_username = "USERNAME"
```

See [here](https://github.com/jbyuki/instant.nvim/wiki/Customization) for more customization options.

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

### Session sharing

[![Untitled-Project.gif](https://i.postimg.cc/ydM961f3/Untitled-Project.gif)](https://postimg.cc/gXKrNWbG)

1. Fire up [ws_server.js](server/ws_server.js) using [node.js](https://nodejs.org/en/).
2. Open an instance and connect to the server.
```
:InstantStartSession 127.0.0.1 8080
```
3. Open another instance and join.
```
:InstantJoinSession 127.0.0.1 8080
```
4. Now all the buffers are synced

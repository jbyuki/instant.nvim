instant.nvim
============

**instant.nvim** is a **collaborative** remote editing plugin for **Neovim** written in **Lua** with no dependencies.

**This is in prototype stage. It should work but some important features are still missing!**
**The transfer protocol is not optimized for large files transfer!**

* [Design document](docs/design.md)
* [Protocol](docs/protocol.md)
* [Commands](docs/commands.md)


Features
--------

* Live editing with multiple users

* Share a whole directory

* See who is editing

Requirements
------------

* Neovim (tested on 0.5 but should work on previous versions)

Install
-------

The easiest is to install using a plugin manager such as [vim-plug](https://github.com/junegunn/vim-plug)

```
Plug 'jbuyki/instant.nvim'
```

Configurations
--------------

* To configure your username, put this in your $MYVIMRC. This **must be** set to start or join a server.

```
lua vim.g.instant_username = "YOUR USERNAME"
```

Usage
-----

1. Fire up the websocket server using [node.js (server/ws_server.js)
2. Create a sharing folder **client1**
```
mkdir client1
```
3. Start neovim into this folder
```
cd client1/
neovim
```
4. Make sure the current folder is correct with `:pwd`. The sharing folder needs to be correct otherwise it will put the wrong files on the server! Don't worry if the folder is not empty, it will not be able to create the server.

5. Connect the first client with `InstantStart`
```
:InstantStart 127.0.0.1 8080
```

6. Create another folder **client2** and start the other instance of neovim
```
mkdir client2
cd client2/
neovim
```

7. Join the connection with the second client with `InstantJoin`
```
:InstantJoin 127.0.0.1 8080
```

8. Now all files should be sync up!

Todo
----

* Multiple sessions on the same server
* Try to reconnect after connection failure

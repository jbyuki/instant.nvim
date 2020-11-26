instant.nvim
============

**instant.nvim** is a **collaborative** editing plugin for **Neovim** written in **Lua** with no dependencies.

The plugin is still highly **unstable** and probably not suitable for normal usage.

**The transfer protocol is not optimized for large files transfer!**

* [Quickstart](https://github.com/jbyuki/instant.nvim/wiki/Quickstart)
* [Deploy a server](https://github.com/jbyuki/instant.nvim/wiki/Deploy-a-server)
* [API](https://github.com/jbyuki/instant.nvim/wiki/API)
* [Design document](https://github.com/jbyuki/instant.nvim/wiki/Design-Document)
* [Protocol](https://github.com/jbyuki/instant.nvim/wiki/Protocol)
* [Commands](https://github.com/jbyuki/instant.nvim/wiki/Commands)
* [Technical Overview](https://github.com/jbyuki/instant.nvim/wiki/Technical-Overview)

[![Untitled-Project.gif](https://i.postimg.cc/wxDFX40G/Untitled-Project.gif)](https://postimg.cc/fkTxZC4c)

Features
--------

* Powerful collaborative editing algorithm

* Single buffer sharing

* Multiple buffer sharing (Session sharing)

* Virtual cursors with username of other clients

* Follow/Spectate a user while he edits

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

* Set your username in your `init.vim`. This **must be** set to start or join a server.

```
let g:instant_username = "USERNAME"
```

See [here](https://github.com/jbyuki/instant.nvim/wiki/Customization) for more customization options.

Usage
-----

### Start server

A server in localhost (127.0.0.1) can be started easily using the builtin server.

1. `:InstantStartServer`

For a more advanced (remote server) overview see [Deploy a server](https://github.com/jbyuki/instant.nvim/wiki/Deploy-a-server)

### Buffer sharing

For a similar experience to Google Docs. Simply share the current buffer.

#### Client 1
1. `:InstantStartSingle 127.0.0.1 8080`
2. A `Connected!` notification should appear

#### Client 2
1. `:InstantJoinSingle 127.0.0.1 8080`
2. Now the two current buffers are synced

When done the connection can be stopped with `:InstantStop`

### Session sharing

For a more advanced sharing setup. It shares all opened buffers (including hidden, not special) with
the other user. Newly created buffers are automatically synced. There are still some issues
with renaming but should be fixed soon.

[![Untitled-Project.gif](https://i.postimg.cc/ydM961f3/Untitled-Project.gif)](https://postimg.cc/gXKrNWbG)

#### Client 1
1. `:InstantStartSession 127.0.0.1 8080`

#### Client 2
1. `:InstantJoinSession 127.0.0.1 8080`

Now all the buffers are synced.

Like with single buffer share, stop the connection with `:InstantStop`

**Note**: 

* The current connection status can be print with `:InstantStatus`
* A user can be followed through its text edits with `:InstantFollow [username]`
* To stop the follow, call `:InstantStopFollow`

### Share current directory

To provide a more similar experience to programming project sharing which is done
for example to do remote pair programming, a session share can be initiated. As a strategic choice,
it was decided that the plugin doesn't directly write to the filesystem implicitly.

As such, the session share can be to share the whole project directory. For larger
projects, it can be problematic and a more advanced solution (more granular control) will be required.

[![Untitled-Project.gif](https://i.postimg.cc/cLXwWr14/Untitled-Project.gif)](https://postimg.cc/3k0dCrDP)

#### Client 1

Navigate to the project directory:

```
cd project-dir
```

1. `:InstantStartSession 127.0.0.1 8080`
2. `:InstantOpenAll` - instant.nvim will open **all** files in the current directory as buffers

#### Client 2

Create a share directory and navigate to it:

```
mkdir share-dir
cd share-dir
```

1. `:InstantJoinSession 127.0.0.1 8080`
2. `:InstantSaveAll` - instant.nvim will save the files (and also create missing directories).

**Note**:

* Use `:InstantSaveAll!` to overwrite files
* This is just an example workflow and it can be adapted for your needs of course.
* Use `qall` or `qall!` to close all buffers at once

```  
███╗   ██╗██╗   ██╗██╗███╗   ███╗      ██╗██████╗ ███████╗
████╗  ██║██║   ██║██║████╗ ████║      ██║██╔══██╗██╔════╝
██╔██╗ ██║██║   ██║██║██╔████╔██║█████╗██║██║  ██║█████╗  
██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║╚════╝██║██║  ██║██╔══╝  
██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║      ██║██████╔╝███████╗
╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝      ╚═╝╚═════╝ ╚══════╝
```
![nvim-ide](./contrib/screenshot.png)

`nvim-ide` is a complete IDE layer for Neovim, heavily inspired by `vscode`.

It provides a default set of components, an extensible API for defining your
own, IDE-like panels and terminal/utility windows, and the ability to swap between
user defined panels. 

This plugin is for individuals who are looking for a cohesive IDE experience 
from Neovim and are less concerned with missing and matching from the awesome
ecosystem of Neovim plugins.

The current set of default components include:
* Bookmarks - Per-workspace collections of bookmarks with sticky support.
* Branches  - Checkout and administer the workspaces's git branches
* CallHierarchy - Display an LSP's CallHierarchy request in an intuitive tree.
* Changes - Display the current git status and stage/restore/commit/ammend the diff.
* Commits - Display the list of commits from HEAD, view a read only diff or checkout a commit and view a modifiable diff.
* Explorer - A file explorer which supports file selection and recursive operations.
* Outline - A real-time LSP powered source code outline supporing jumping and tracking.
* TerminalBrowser - A terminal manager for creating, renaming, jumping-to, and deleting terminal instances.
* Timeline - Displays the git history of a file, showing you how the file was manipulated over several commits.

We put a lot of efforts into writing `docs/nvim-ide.txt`, so please refer to this 
file for introduction, usage, and development information.

## Getting started 

1. Get the plugin via your favorite plugin manager.

2. Call the setup function (optionally with the default config):
```lua
require('ide').setup({
    -- the global icon set to use.
    -- values: "nerd", "codicon", "default"
    icon_set = "default",
    -- place Component config overrides here. 
    -- they key to this table must be the Component's unique name and the value 
    -- is a table which overrides any default config values.
    components = {},
    -- default panel groups to display on left and right.
    panels = {
        left = "explorer",
        right = "git"
    },
    -- panels defined by groups of components, user is free to redefine these
    -- or add more.
    panel_groups = {
        explorer = { outline.Name, explorer.Name, bookmarks.Name, callhierarchy.Name, terminalbrowser.Name },
        terminal = { terminal.Name },
        git = { changes.Name, commits.Name, timeline.Name, branches.Name }
    }
})
```

3. Issue the "Workspace" command to begin discovering what's available.

4. Begin reading "h: nvim-ide"

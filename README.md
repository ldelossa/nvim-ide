███╗   ██╗██╗   ██╗██╗███╗   ███╗      ██╗██████╗ ███████╗
████╗  ██║██║   ██║██║████╗ ████║      ██║██╔══██╗██╔════╝
██╔██╗ ██║██║   ██║██║██╔████╔██║█████╗██║██║  ██║█████╗  
██║╚██╗██║╚██╗ ██╔╝██║██║╚██╔╝██║╚════╝██║██║  ██║██╔══╝  
██║ ╚████║ ╚████╔╝ ██║██║ ╚═╝ ██║      ██║██████╔╝███████╗
╚═╝  ╚═══╝  ╚═══╝  ╚═╝╚═╝     ╚═╝      ╚═╝╚═════╝ ╚══════╝

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

We put a lot of efforts into writing `docs/nvim-ide.txt`, so please refer to
this file for introduction, usage, and development information.

![nvim-ide](./contrib/screenshot.png)

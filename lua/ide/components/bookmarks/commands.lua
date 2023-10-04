local libcmd = require("ide.lib.commands")

local Commands = {}

Commands.new = function(bookmarks)
	assert(bookmarks ~= nil, "Cannot construct Commands without an Bookmarks instance.")
	local self = {
		-- An instance of an Explorer component which Commands delegates to.
		bookmarks = bookmarks,
	}

	-- returns a list of @Command(s) defined in 'ide.lib.commands'
	--
	-- @return: @table, an array of @Command(s) which export an Bookmarks's
	-- command set.
	function self.get()
		local commands = {
			libcmd.new(
				libcmd.KIND_ACTION,
				"BookmarksFocus",
				"Focus",
				self.bookmarks.focus,
				{ desc = "Open and focus the Bookmarks." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BookmarksHide",
				"Hide",
				self.bookmarks.hide,
				{ desc = "Hide the bookmarks in its current panel. Use Focus to unhide." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BookmarksMinimize",
				"Minimize",
				self.bookmarks.minimize,
				{ desc = "Minimize the bookmarks window in its panel." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BookmarksMaximize",
				"Maximize",
				self.bookmarks.maximize,
				{ desc = "Maximize the bookmarks window in its panel." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BookmarksCreateNotebook",
				"CreateNotebook",
				self.bookmarks.create_notebook,
				{ desc = "Create a new Notebook for the current project." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BookmarksOpenNotebook",
				"OpenNotebook",
				self.bookmarks.open_notebook,
				{ desc = "Create a new Notebook for the current project." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BookmarksRemoveNotebook",
				"RemoveNotebook",
				self.bookmarks.remove_notebook,
				{ desc = "Remove a Notebook for the current project." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BookmarksCreate",
				"CreateBookmark",
				self.bookmarks.create_bookmark,
				{ desc = "Create a bookmark within the opened Notebook." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BookmarksRemove",
				"RemoveBookmark",
				self.bookmarks.remove_bookmark,
				{ desc = "Create a bookmark within the opened Notebook." }
			),
		}
		return commands
	end

	return self
end

return Commands

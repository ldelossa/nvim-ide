local libcmd = require("ide.lib.commands")

local Commands = {}

Commands.new = function(branches)
	assert(branches ~= nil, "Cannot construct Commands without an branches instance.")
	local self = {
		-- An instance of an Explorer component which Commands delegates to.
		branches = branches,
	}

	-- returns a list of @Command(s) defined in 'ide.lib.commands'
	--
	-- @return: @table, an array of @Command(s) which export an branches's
	-- command set.
	function self.get()
		local commands = {
			libcmd.new(
				libcmd.KIND_ACTION,
				"BranchesFocus",
				"Focus",
				self.branches.focus,
				{ desc = "Open and focus the branches." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BranchesHide",
				"Hide",
				self.branches.hide,
				{ desc = "Hide the branches in its current panel. Use Focus to unhide." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BranchesMinimize",
				"Minimize",
				self.branches.minimize,
				{ desc = "Minimize the branches window in its panel." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BranchesMaximize",
				"Maximize",
				self.branches.maximize,
				{ desc = "Maximize the branches window in its panel." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BranchesCreateBranch",
				"CreateBranch",
				self.branches.create_branch,
				{ desc = "Create a branch" }
			),
		}
		return commands
	end

	return self
end

return Commands

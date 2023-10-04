local libcmd = require("ide.lib.commands")

local Commands = {}

Commands.new = function(callhierarchy)
	assert(callhierarchy ~= nil, "Cannot construct Commands without an CallHierarchyComponent instance.")
	local self = {
		-- An instance of an Explorer component which Commands delegates to.
		callhierarchy = callhierarchy,
	}

	-- returns a list of @Command(s) defined in 'ide.lib.commands'
	--
	-- @return: @table, an array of @Command(s) which export an Outline's
	-- command set.
	function self.get()
		local commands = {
			libcmd.new(
				libcmd.KIND_ACTION,
				"CallHierarchyFocus",
				"Focus",
				self.callhierarchy.focus,
				{ desc = "Open and focus the CallHierarchy." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"CallHierarchyHide",
				"Hide",
				self.callhierarchy.hide,
				{ desc = "Hide the callhierarchy in its current panel. Use Focus to unhide." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"CallHierarchyExpand",
				"Expand",
				self.callhierarchy.expand,
				{ desc = "Expand the symbol under the current cursor." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"CallHierarchyCollapse",
				"Collapse",
				self.callhierarchy.collapse,
				{ desc = "Collapse the symbol under the current cursor." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"CallHierarchyCollapseAll",
				"CollapseAll",
				self.callhierarchy.collapse_all,
				{ desc = "Collapse the symbol under the current cursor." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"CallHierarchyMinimize",
				"Minimize",
				self.callhierarchy.minimize,
				{ desc = "Minimize the callhierarchy window in its panel." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"CallHierarchyMaximize",
				"Maximize",
				self.callhierarchy.maximize,
				{ desc = "Maximize the CallHierarchy window in its panel." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"CallHierarchyIncomingCalls",
				"IncomingCalls",
				self.callhierarchy.incoming_calls,
				{ desc = "Show the incoming call hierarchy for the symbol under the cursor." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"CallHierarchyOutgoingCalls",
				"OutgoingCalls",
				self.callhierarchy.outgoing_calls,
				{ desc = "Show the outgoing call hierarchy for the symbol under the cursor." }
			),
		}
		return commands
	end

	return self
end

return Commands

local node = require("ide.trees.node")
local icons = require("ide.icons")

local TerminalNode = {}

TerminalNode.new = function(id, name, depth)
	-- extends 'ide.trees.Node' fields.

	local self = node.new("terminal", name, id, depth)
	self.id = id

	-- Marshal a symbolnode into a buffer line.
	--
	-- @return: @icon - @string, icon for symbol's kind
	--          @name - @string, symbol's name
	--          @details - @string, symbol's detail if exists.
	function self.marshal()
		local icon = icons.global_icon_set.get_icon("Terminal")
		local name = self.name
		local detail = ""
		return icon, name, detail
	end

	return self
end

return TerminalNode

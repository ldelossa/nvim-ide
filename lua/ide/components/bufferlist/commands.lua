local libcmd = require("ide.lib.commands")

local Commands = {}

Commands.new = function(buflist)
	assert(buflist ~= nil, "Cannot construct Commands without a BufferList instance")
	local self = {
		-- Instnace of BufferList component
		bufferlist = buflist,
	}

	-- returns a list of @Command(s) defined in 'ide.lib.commands'
	--
	-- @return: @table, an array of @Command(s) which export an Explorer's
	-- command set.
	function self.get()
		return {
			libcmd.new(
				libcmd.KIND_ACTION,
				"BufferListFocus",
				"Focus",
				self.bufferlist.focus,
				{ desc = "Open and focus the buffer list" }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BufferListHide",
				"Hide",
				self.bufferlist.hide,
				{ desc = "Hide the buffer list in its current panel. Use Focus to unhide." }
			),
			libcmd.new(
				libcmd.KIND_ACTION,
				"BufferListEdit",
				"EditFile",
				self.bufferlist.open_buf,
				{ desc = "Open the file for editing under the current cursor." }
			),
		}
	end

	return self
end

return Commands

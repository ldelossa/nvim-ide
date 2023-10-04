local Command = {}

local prototype = {
	name = nil,
	shortname = nil,
	callback = nil,
	kind = "action",
	opts = {
		desc = "",
	},
}

-- Signifies the command performs an action when its callback field is invoked.
Command.KIND_ACTION = "action"
-- Signifies the command returns another list of @Command.prototype tables when
-- its callback field is invoked.
Command.KIND_SUBCOMMAND = "subcommand"

-- A command is a description of a user command.
--
-- Commands have a `kind` field informing callers how to handle the specific
-- command.
--
-- @kind        - @string, one of the above KIND_* enums
-- @name        - @string, a unique name for the command outside the context of a
--                submenu
-- @shortname   - @string, a non-unique name for the command in the context of a
--                submenu
-- @callback    - a callback function to invoke the command.
--                typically, if this is an "action" the function will receive the
--                'args' field explained in ":h nvim_create_user_command".
--                if the type of "subcommand" the callback will return a list of
--                @Command.prototype tables describing a another set of commands
--                that exist under @Command.name.
-- @opts        - an options table as described in ":h nvim_create_user_command".
Command.new = function(kind, name, shortname, callback, opts)
	local self = vim.deepcopy(prototype)
	self.kind = kind
	self.name = name
	self.shortname = shortname
	self.callback = callback
	self.opts = opts

	return self
end

return Command

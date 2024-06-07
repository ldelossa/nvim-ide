local base = require("ide.panels.component")
local tree = require("ide.trees.tree")
local callnode = require("ide.components.callhierarchy.callnode")
local commands = require("ide.components.callhierarchy.commands")
local libwin = require("ide.lib.win")
local libbuf = require("ide.lib.buf")
local liblsp = require("ide.lib.lsp")
local logger = require("ide.logger.logger")
local icons = require("ide.icons")

local CallHierarchyComponent = {}

local config_prototype = {
	default_height = nil,
	disabled_keymaps = false,
	keymaps = {
		expand = "zo",
		collapse = "zc",
		collapse_all = "zM",
		jump = "<CR>",
		jump_split = "s",
		jump_vsplit = "v",
		jump_tab = "t",
		hide = "H",
		close = "X",
		next_reference = "n",
		switch_directions = "s",
		help = "?",
	},
}

-- CallHierarchyComponent is a derived @Component implementing a tree of incoming
-- or outgoing calls.
-- Must implement:
--  @Component.open
--  @Component.post_win_create
--  @Component.close
--  @Component.get_commands
CallHierarchyComponent.new = function(name, config)
	-- extends 'ide.panels.Component' fields.
	local self = base.new(name)

	-- a @Tree containing the current buffer's document symbols.
	self.tree = tree.new("callhierarchy")

	-- a logger that will be used across this class and its base class methods.
	self.logger = logger.new("callhierarchy")

	-- seup config, use default and merge in user config if not nil
	self.config = vim.deepcopy(config_prototype)
	if config ~= nil then
		self.config = vim.tbl_deep_extend("force", config_prototype, config)
	end

	-- Set to hidden at first, only display once the hierarchy is created.
	self.hidden = true

	self.fromRangeIndex = -1

	local function setup_buffer()
		local log = self.logger.logger_from(nil, "Component._setup_buffer")
		local buf = vim.api.nvim_create_buf(false, true)

		vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
		vim.api.nvim_buf_set_option(buf, "filetype", "filetree")
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "modifiable", false)
		vim.api.nvim_buf_set_option(buf, "swapfile", false)
		vim.api.nvim_buf_set_option(buf, "textwidth", 0)
		vim.api.nvim_buf_set_option(buf, "wrapmargin", 0)

		local keymaps = {
			{
				self.config.keymaps.expand,
				function()
					self.expand()
				end,
			},
			{
				self.config.keymaps.collapse,
				function()
					self.collapse()
				end,
			},
			{
				self.config.keymaps.collapse_all,
				function()
					self.collapse_all()
				end,
			},
			{
				self.config.keymaps.jump,
				function()
					self.jump_callnode({ fargs = {} })
				end,
			},
			{
				self.config.keymaps.jump_split,
				function()
					self.jump_callnode({ fargs = { "split" } })
				end,
			},
			{
				self.config.keymaps.jump_vsplit,
				function()
					self.jump_callnode({ fargs = { "vsplit" } })
				end,
			},
			{
				self.config.keymaps.jump_tab,
				function()
					self.jump_callnode({ fargs = { "tab" } })
				end,
			},
			{
				self.config.keymaps.next_reference,
				function()
					self.next_reference()
				end,
			},
			{
				self.config.keymaps.hide,
				function()
					self.hide()
				end,
			},
			{
				self.config.keymaps.help,
				function()
					self.help_keymaps()
				end,
			},
		}

		if not self.config.disable_keymaps then
			for _, keymap in ipairs(keymaps) do
				libbuf.set_keymap_normal(buf, keymap[1], keymap[2])
			end
		end

		return buf
	end

	self.buf = setup_buffer()

	self.tree.set_buffer(self.buf)

	-- implements @Component.open()
	function self.open()
		if self.tree.root ~= nil then
			self.tree.marshal({})
		end
		return self.buf
	end

	-- implements @Component interface
	function self.post_win_create()
		local log = self.logger.logger_from(nil, "Component.post_win_create")
		icons.global_icon_set.set_win_highlights()
	end

	-- implements @Component interface
	function self.get_commands()
		local log = self.logger.logger_from(nil, "Component.get_commands")
		return commands.new(self).get()
	end

	-- implements optional @Component interface
	-- Expand the @CallNode at the current cursor location
	--
	-- @args - @table, user command table as described in ":h nvim_create_user_command()"
	-- @callnode - @CallNode, an override which expands the given @CallNode, ignoring the
	--          node under the current position.
	function self.expand(args, callnode)
		local log = self.logger.logger_from(nil, "Component.expand")
		if not libwin.win_is_valid(self.win) then
			return
		end
		if callnode == nil then
			callnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
			if callnode == nil then
				return
			end
		end
		callnode.expand()
		self.tree.marshal({})
		self.state["cursor"].restore()
	end

	-- Collapse the @CallNode at the current cursor location
	--
	-- @args - @table, user command table as described in ":h nvim_create_user_command()"
	-- @callnode - @CallNode, an override which collapses the given @CallNode, ignoring the
	--           node under the current position.
	function self.collapse(args, callnode)
		local log = self.logger.logger_from(nil, "Component.collapse")
		if not libwin.win_is_valid(self.win) then
			return
		end
		if callnode == nil then
			callnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
			if callnode == nil then
				return
			end
		end
		self.tree.collapse_subtree(callnode)
		self.tree.marshal({})
		self.state["cursor"].restore()
	end

	-- Collapse the call hierarchy up to the root.
	--
	-- @args - @table, user command table as described in ":h nvim_create_user_command()"
	function self.collapse_all(args)
		local log = self.logger.logger_from(nil, "Component.collapse_all")
		if not libwin.win_is_valid(self.win) then
			return
		end
		if callnode == nil then
			callnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
			if callnode == nil then
				return
			end
		end
		self.tree.collapse_subtree(self.tree.root)
		self.tree.marshal({})
		self.state["cursor"].restore()
	end

	local function _set_winbar_direction(direction)
		if libwin.win_is_valid(self.win) then
			vim.api.nvim_win_set_option(self.win, "winbar", string.format("CallHierarchy (%s)", direction))
		end
	end

	local function _build_call_hierarchy(direction, root_item, calls)
		local synthetic_item_call = liblsp.item_to_call_hierarchy_call(direction, root_item)

		local root = callnode.new(self, direction, synthetic_item_call, 0)
		-- always expand root
		root.expanded = true

		if root == nil then
			error("failed to create root")
			return
		end

		local children = {}
		for _, call in ipairs(calls) do
			local child = callnode.new(self, direction, call)
			table.insert(children, child)
		end

		self.tree.add_node(root, children)
		self.tree.marshal({})
		-- focus ourselves
		self.focus()
		-- set the winbar header to the current direction
		_set_winbar_direction(direction)
		self.state["cursor"].restore()
	end

	local function _call_hierarchy_prepare(direction, call_hierarchy_request)
		local log = self.logger.logger_from(nil, "Component._call_hierarchy_prepare")

		local cur_buf = vim.api.nvim_get_current_buf()
		local cur_win = vim.api.nvim_get_current_win()

		if not libbuf.has_lsp_clients(libwin.get_buf(0)) then
			log.debug("no lsp clients for current buffer, returning.")
			return
		end

		-- don't bother performing a call hierarchy request in any of our
		-- component windows.
		if libwin.is_component_win(0) then
			log.debug("current window was a component win, returning.")
			return
		end

		local text_doc_pos = vim.lsp.util.make_position_params()
		if text_doc_pos == nil then
			log.debug("retrieved nil TextDocumentPositionParam")
			return
		end

		log.debug("retrieved TextDocumentPositionParam")

		log.debug("performing textDocument/prepareCallHierarchy LSP request")
		liblsp.make_prepare_call_hierarchy_request(nil, { buf = cur_buf }, function(call_hierarchy_items, client_id)
			if call_hierarchy_items == nil then
				return
			end
			if #call_hierarchy_items == 0 then
				return
			end
			-- stuff our state with the win, buf, and lsp client id used to prepare
			-- the call hierarchy.
			self.state["invoking_buf"] = cur_buf
			self.state["invoking_win"] = cur_win
			self.state["client_id"] = client_id
			-- send the cur_buf, since these are async, user may change buffer
			-- on us before this async chain resolves.
			call_hierarchy_request(client_id, cur_buf, call_hierarchy_items[1])
		end)
	end

	function self.incoming_calls(args)
		local callback = function(direction, call_hierarchy_item, call_hierarchy_calls)
			if call_hierarchy_calls == nil then
				vim.notify(string.format("%s\n", "LSP returned zero incoming calls."), vim.log.levels.WARN, {
					title = "CallHierarchy",
				})
				return
			end
			_build_call_hierarchy(direction, call_hierarchy_item, call_hierarchy_calls)
		end

		_call_hierarchy_prepare("incoming", function(client_id, buf, call_hierarchy_item)
			liblsp.make_incoming_calls_request(call_hierarchy_item, { buf = buf }, callback)
		end)
	end

	function self.outgoing_calls(args)
		local callback = function(direction, call_hierarchy_item, call_hierarchy_calls)
			if call_hierarchy_calls == nil then
				vim.notify(string.format("%s\n", "LSP returned zero outgoing calls."), vim.log.levels.WARN, {
					title = "CallHierarchy",
				})
				return
			end
			_build_call_hierarchy(direction, call_hierarchy_item, call_hierarchy_calls)
		end

		_call_hierarchy_prepare("outgoing", function(client_id, buf, call_hierarchy_item)
			liblsp.make_outgoing_calls_request(call_hierarchy_item, { buf = buf }, callback)
		end)
	end

	function self.next_reference()
		if not libwin.win_is_valid(self.state["jumped_win"]) then
			return
		end
		if self.state["reference_index"] > #self.state["ranges"] then
			self.state["reference_index"] = 1
		end
		local range = self.state["ranges"][self.state["reference_index"]]
		vim.api.nvim_win_set_cursor(self.state["jumped_win"], {
			range["start"]["line"] + 1,
			range["start"]["character"] + 1,
		})
		self.state["reference_index"] = self.state["reference_index"] + 1
	end

	function self.jump_callnode(args)
		log = self.logger.logger_from(nil, "Component.open_filenode")

		local split = false
		local vsplit = false
		local tab = false
		for _, arg in ipairs(args.fargs) do
			if arg == "split" then
				split = true
			end
			if arg == "vsplit" then
				vsplit = true
			end
			if arg == "tab" then
				tab = true
			end
		end

		local callnode = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if callnode == nil then
			return
		end

		local win_to_use = nil
		if libwin.win_is_valid(self.state["invoking_win"]) then
			win_to_use = self.state["invoking_win"]
		else
			win_to_use = self.workspace.get_win()
		end

		local call_hierarchy_item =
			liblsp.call_hierarchy_call_to_item(callnode.direction, callnode.call_hierarchy_item_call)
		if call_hierarchy_item == nil then
			return
		end

		vim.api.nvim_set_current_win(win_to_use)
		self.state["jumped_win"] = win_to_use
		if callnode.direction == "outgoing" then
			-- for outgoint calls, they fromRanges are always relative to the parent node, to grab the parent
			-- to use for the actual file to jump to.
			local parent = callnode.parent
			local parent_call_hierarchy_item =
				liblsp.call_hierarchy_call_to_item(parent.direction, parent.call_hierarchy_item_call)
			if parent_call_hierarchy_item == nil then
				return
			end

			vim.cmd("edit " .. vim.fn.fnamemodify(vim.uri_to_fname(parent_call_hierarchy_item.uri), ":."))
			vim.lsp.util.jump_to_location({
				uri = parent_call_hierarchy_item.uri,
				range = callnode.call_hierarchy_item_call.fromRanges[1],
			})
			self.state["reference_index"] = 2
			self.state["ranges"] = vim.deepcopy(callnode.call_hierarchy_item_call.fromRanges)
		else
			vim.cmd("edit " .. vim.fn.fnamemodify(vim.uri_to_fname(call_hierarchy_item.uri), ":."))
			vim.lsp.util.jump_to_location(
				{ uri = call_hierarchy_item.uri, range = call_hierarchy_item.selectionRange },
				"utf-8"
			)
			self.state["reference_index"] = 1
			self.state["ranges"] = vim.deepcopy(callnode.call_hierarchy_item_call.fromRanges)
			table.insert(self.state["ranges"], call_hierarchy_item.selectionRange)
		end
		local clear_hl = liblsp.highlight_call_hierarchy_call(0, callnode.direction, callnode.call_hierarchy_item_call)

		vim.api.nvim_set_current_win(self.win)

		-- one time autocmd which clears the jumped node after cursor move.
		-- the idea here is that they are in the CallHierarchy UI, issue a jump
		-- then issue subsequent "next_reference" calls. Once the source buffer
		-- is there they want, they'll jump out of the UI and into it, un-jumping
		-- this node.
		local id = nil
		id = vim.api.nvim_create_autocmd({ "CursorMoved" }, {
			callback = function()
				self.state["jumped_win"] = nil
				self.state["reference_index"] = nil
				self.state["ranges"] = nil
				clear_hl()
				vim.api.nvim_del_autocmd(id)
			end,
		})
	end

	return self
end

return CallHierarchyComponent

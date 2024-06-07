local base = require("ide.panels.component")
local tree = require("ide.trees.tree")
local commands = require("ide.components.outline.commands")
local logger = require("ide.logger.logger")
local libwin = require("ide.lib.win")
local libbuf = require("ide.lib.buf")
local liblsp = require("ide.lib.lsp")
local libws = require("ide.lib.workspace")
local symbolnode = require("ide.components.outline.symbolnode")
local icons = require("ide.icons")

local OutlineComponent = {}

local config_prototype = {
	default_height = nil,
	disabled_keymaps = false,
	hidden = false,
	keymaps = {
		close = "X",
		collapse = "zc",
		collapse_all = "zM",
		details = "d",
		expand = "zo",
		help = "?",
		hide = "H",
		jump = "<CR>",
		jump_split = "s",
		jump_tab = "t",
		jump_vsplit = "v",
	},
}

-- OutlineComponent is a derived @Component implementing a file explorer.
-- Must implement:
--  @Component.open
--  @Component.post_win_create
--  @Component.close
--  @Component.get_commands
--
-- This component will use the following keys in its state field
--
-- self.state.outlined_win - the win ID that the the current outline was created
-- for.
OutlineComponent.new = function(name, config)
	-- extends 'ide.panels.Component' fields.
	local self = base.new(name)

	-- a @Tree containing the current buffer's document symbols.
	self.tree = tree.new("document_symbol")

	-- a logger that will be used across this class and its base class methods.
	self.logger = logger.new("outline")

	-- seup config, use default and merge in user config if not nil
	self.config = vim.deepcopy(config_prototype)
	if config ~= nil then
		self.config = vim.tbl_deep_extend("force", config_prototype, config)
	end

	self.hidden = self.config.hidden

	self.debouncing = false

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
					self.jump_symbolnode({ fargs = {} })
				end,
			},
			{
				self.config.keymaps.jump_split,
				function()
					self.jump_symbolnode({ fargs = { "split" } })
				end,
			},
			{
				self.config.keymaps.jump_vsplit,
				function()
					self.jump_symbolnode({ fargs = { "vsplit" } })
				end,
			},
			{
				self.config.keymaps.jump_tab,
				function()
					self.jump_symbolnode({ fargs = { "tab" } })
				end,
			},
			{
				self.config.keymaps.details,
				function()
					self.details()
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

	-- -- hide until an LSP call is made for the current buffer.
	-- self.hidden = true

	-- implements @Component.open()
	function self.open()
		if self.tree.root ~= nil then
			self.tree.marshal({ no_guides_leaf = true })
		end
		return self.buf
	end

	-- implements @Component interface
	function self.post_win_create()
		local log = self.logger.logger_from(nil, "Component.post_win_create")
		icons.global_icon_set.set_win_highlights()
	end

	local function _build_outline_recursive(cur_node, document_symbols)
		local log = self.logger.logger_from(nil, "Component._build_outline_recursive")

		for _, doc_sym in ipairs(document_symbols) do
			local cNode = symbolnode.new(doc_sym)
			log.debug("created node %s %s", cNode.name, cNode.key)
			log.debug("adding child %s to parent %s", cNode.key, cur_node.key)
			self.tree.add_node(cur_node, { cNode }, { append = true })
			if doc_sym.children ~= nil and #doc_sym.children > 0 then
				-- recurse to add children to the node we just created.
				_build_outline_recursive(cNode, doc_sym.children)
			end
		end
	end

	-- Populates the @Tree of this Outline component with the returned
	-- `textDocument/documentSymbol` response and marshals the @Tree into the
	-- component's buffer.
	local function _build_outline(document_symbols, buffer_name)
		local log = self.logger.logger_from(nil, "Component._build_outline")

		-- root is a synthetic document symbol of kind "file".
		local document_symbol = {
			name = vim.fn.fnamemodify(buffer_name, ":t"),
			range = {
				start = {
					line = 0,
					character = 0,
				},
				["end"] = {
					line = 0,
					character = 0,
				},
			},
			kind = 1, -- LSP SymbolKind File
		}
		local root = symbolnode.new(document_symbol, 0)
		log.debug("created synthetic root %s %s", root.name, root.key)

		self.tree.add_node(root, {})
		log.debug("added root to tree")

		_build_outline_recursive(root, document_symbols)

		self.tree.marshal({ no_guides_leaf = true })
		self.state["cursor"].restore()
	end

	function self.create_outline()
		local log = self.logger.logger_from(nil, "Component.create_outline")
		local cur_buf = vim.api.nvim_get_current_buf()
		local cur_win = vim.api.nvim_get_current_win()

		log.debug(
			"creating outline for workspace %d buffer %d %s",
			self.workspace.tab,
			cur_buf,
			vim.api.nvim_buf_get_name(cur_buf)
		)
		if #vim.lsp.get_clients({ bufnr = cur_buf }) == 0 then
			log.debug("buffer had no LSP client attached, returning.")
			return
		end

		log.debug("issuing textDocument/documentSymbol LSP request for buffer.")
		local tdi = vim.lsp.util.make_text_document_params(cur_buf)
		if tdi == nil then
			log.error("failed to make TextDocumentIdentifier for buffer %d", cur_buf)
			return
		end

		local lsp_method = "textDocument/documentSymbol"

		local supports_method = #(
				vim.tbl_filter(function(client)
					return client.supports_method(lsp_method)
				end, vim.lsp.get_clients({ bufnr = cur_buf }))
			) > 0
		if not supports_method then
			return
		end

		vim.lsp.buf_request_all(cur_buf, lsp_method, { textDocument = tdi }, function(resp)
			local result = liblsp.request_all_first_result(resp)
			if result ~= nil then
				_build_outline(result, vim.api.nvim_buf_get_name(cur_buf))
				self.state["outlined_win"] = cur_win
				return
			end
			_build_outline({}, vim.api.nvim_buf_get_name(cur_buf))
			self.state["outlined_win"] = cur_win
		end)
	end

	function self.create_outline_prepare(args)
		local log = self.logger.logger_from(nil, "Component.create_outline_prepare")

		if not libbuf.is_regular_buffer(0) then
			log.debug("event was for a non file buffer, returning.")
			return
		end

		if self.workspace == nil then
			log.warning("no workspace set for component, returning.")
			return
		end

		local cur_tab = vim.api.nvim_get_current_tabpage()
		if self.workspace.tab ~= cur_tab then
			log.debug("event for tab %d does not pertain to us, workspace[%d]", cur_tab, self.workspace.tab)
			return
		end

		if libwin.is_component_win(0) then
			log.debug("event was for a component window, returning.")
			return
		end
		-- create the outline.
		log.debug("creating outline")
		self.create_outline()
	end

	function self.sync_source_buffer()
		local log = self.logger.logger_from(nil, "Component.sync_source_buffer")

		log.debug("syncing the outline with its source buffer.")

		if not libwin.win_is_valid(self.state["outlined_win"]) then
			log.debug("outlined win %s is not valid", vim.inspect(self.state["outlined_win"]))
			return
		end
		local symbol_cursor = vim.api.nvim_win_get_cursor(self.win)
		if symbol_cursor == nil then
			log.error("received nil cursor for outlin win. returning")
			return
		end
		local symnode = self.tree.unmarshal(symbol_cursor[1])
		-- ignore root too.
		if symnode == nil or symnode.depth == 0 then
			log.debug("failed to unmarshal symbol node for line %d", symbol_cursor[1])
			return
		end

		local range = liblsp.get_document_symbol_range(symnode.document_symbol)
		if range == nil then
			return
		end

		log.debug("setting source buffer's cursor to line %d", range["start"]["line"] + 1)

		local outlined_buf = vim.api.nvim_win_get_buf(self.state["outlined_win"])
		vim.api.nvim_win_set_cursor(
			self.state["outlined_win"],
			{ range["start"]["line"] + 1, range["start"]["character"] + 1 }
		)

		vim.lsp.util.buf_highlight_references(outlined_buf, { { range = range } }, "utf-8")

		local id = nil
		id = vim.api.nvim_create_autocmd({ "BufLeave", "CursorMoved" }, {
			callback = function()
				vim.lsp.util.buf_clear_references(outlined_buf)
				vim.api.nvim_del_autocmd(id)
			end,
		})
	end

	function self.sync_symbol_buffer()
		local log = self.logger.logger_from(nil, "Component.sync_symbol_buffer")

		local cursor = vim.api.nvim_win_get_cursor(0)
		local prev_node = nil
		local exact_match = nil
		local diff = nil
		self.tree.walk_subtree(self.tree.root, function(node)
			local range = liblsp.get_document_symbol_range(node.document_symbol)
			if range == nil then
				range = node.document_symbol.range
			end

			-- don't consider root
			if node.depth == 0 then
				return true
			end
			local start_line = range["start"]["line"] + 1
			diff = cursor[1] - start_line
			-- exact match
			if diff == 0 then
				exact_match = node
				return false
			end
			-- didn't cross cursor threshold yet, record the closest node seen so far.
			if diff > 0 then
				prev_node = node
				return true
			end
			-- crossed cursor threshold, stop iterating.
			if diff < 0 then
				return false
			end
		end)
		if exact_match ~= nil then
			if libwin.win_is_valid(self.win) then
				vim.api.nvim_win_set_cursor(self.win, { exact_match.line, 1 })
			end
			-- didn't find an exact match, so grab the closet node and find its parent
			-- to keep the symbol buffer in scope.
		elseif prev_node ~= nil then
			if libwin.win_is_valid(self.win) then
				if prev_node.parent.depth ~= 0 then
					vim.api.nvim_win_set_cursor(self.win, { prev_node.parent.line, 1 })
				else
					vim.api.nvim_win_set_cursor(self.win, { prev_node.line, 1 })
				end
			end
		end
	end

	function self.event_handler(args)
		if not self.is_displayed then
			return
		end

		if args.event == "CursorHold" then
			if not libws.is_current_ws(self.workspace) then
				return
			end
			local cur_win = vim.api.nvim_get_current_win()
			if cur_win == self.win then
				self.sync_source_buffer()
				return
			end
			if libwin.win_is_valid(self.state["outlined_win"]) and cur_win == self.state["outlined_win"] then
				if not self.debouncing then
					self.debouncing = true
					self.sync_symbol_buffer()
					vim.defer_fn(function()
						self.debouncing = false
					end, 350)
				end
				return
			end
		end
		if args.event == "LspAttach" or args.event == "TextChanged" or args.event == "BufEnter" then
			self.create_outline_prepare(args)
		end
	end

	function self.expand(args)
		local log = self.logger.logger_from(nil, "Component.expand")
		if not libwin.win_is_valid(self.win) then
			return
		end
		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		self.tree.expand_node(node)
		self.tree.marshal({ no_guides_leaf = true })
		self.state["cursor"].restore()
	end

	function self.collapse(args)
		local log = self.logger.logger_from(nil, "Component.collapse")
		if not libwin.win_is_valid(self.win) then
			return
		end
		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		self.tree.collapse_node(node)
		self.tree.marshal({ no_guides_leaf = true })
		self.state["cursor"].restore()
	end

	function self.collapse_all(args)
		local log = self.logger.logger_from(nil, "Component.collapse_all")
		if not libwin.win_is_valid(self.win) then
			return
		end
		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end
		self.tree.collapse_subtree(self.tree.root)
		self.tree.marshal({ no_guides_leaf = true })
		self.state["cursor"].restore()
	end

	function self.jump_symbolnode(args)
		local log = self.logger.logger_from(nil, "Component.jump_symbolnode")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		local range = liblsp.get_document_symbol_range(node.document_symbol)
		if range == nil then
			return
		end

		if not libwin.win_is_valid(self.state["outlined_win"]) then
			return
		end

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

		vim.api.nvim_set_current_win(self.state["outlined_win"])
		local reuse_win = true
		if split then
			vim.cmd("split")
			reuse_win = false
		elseif vsplit then
			vim.cmd("vsplit")
			reuse_win = false
		elseif tab then
			vim.cmd("tabnew")
			reuse_win = false
		end

		vim.lsp.util.jump_to_location({
			uri = vim.uri_from_bufnr(vim.api.nvim_win_get_buf(self.state["outlined_win"])),
			range = range,
		}, "utf-8", reuse_win)
	end

	function self.details(args)
		local log = self.logger.logger_from(self.name, "Component.details")

		local node = self.tree.unmarshal(self.state["cursor"].cursor[1])
		if node == nil then
			return
		end

		if node.depth == 0 then
			return
		end

		node.details()
	end

	function self.get_commands()
		log = self.logger.logger_from(self.name, "Component.get_commands")
		return commands.new(self).get()
	end

	vim.api.nvim_create_autocmd(
		{ "CursorHold", "LspAttach", "BufEnter", "TextChanged" },
		{ callback = self.event_handler }
	)

	return self
end

return OutlineComponent

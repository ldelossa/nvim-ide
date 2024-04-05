local workspace = require("ide.workspaces.workspace")
local workspace_registry = require("ide.workspaces.workspace_registry")
local libcmd = require("ide.lib.commands")
local libwin = require("ide.lib.win")
local logger = require("ide.logger.logger")

local WorkspaceController = {}

-- WorkspaceController is responsible for creating and removing workspaces during
-- Neovim's runtime.
--
-- A single WorkspaceController should be created per Neovim session.
--
-- The controller will attach workspaces to all existing tabs when its `init`
-- method is invoked.
--
-- Additionally, it will register an autocommand on the TabNew event,
-- creating workspaces for each all new tabs that are created.
--
-- The WorkspaceController will register a high level user command: "Workspace".
--
-- This command allows dynamic lookup of the current Workspaces components and
-- subsequently those component's commands, along with some Workspace specific
-- commands.
function WorkspaceController.new(config)
	local self = {
		-- The autocommand ID used to the newtab_assign autocommand.
		tabnew_autocmd_id = nil,
		-- The autocommand ID used to the newtab_assign autocommand.
		tabclosed_autocmd_id = nil,
		win_history_autocmd_id = nil,

		auto_close_autocmd_id = nil,

		config = {
			auto_close = nil,
		},
	}

	if config then
		self.config = vim.deepcopy(config)
	end

	local function recursive_ws_handler_completion(cmds, cmdline, cmdline_index)
		local log = logger.new("workspaces", "WorkspaceController.recursive_ws_handler_completion")
		if cmds == nil then
			return
		end
		local args = vim.fn.split(cmdline)
		local shortnames = {}
		-- if we have an exact match at our arg index, recurse to provide
		-- subcommand completion
		for _, cmd in ipairs(cmds) do
			table.insert(shortnames, cmd.shortname)
			if vim.fn.match(args[cmdline_index], cmd.shortname) == 0 then
				log.debug("handling exact match for %s command", cmd.shortname)
				return recursive_ws_handler_completion(cmd.callback(), cmdline, cmdline_index + 1)
			end
		end
		local matches = {}
		if args[cmdline_index] == nil then
			log.debug("handling prefix completion for empty prefix, returning all subcommands.")
			for _, sn in ipairs(shortnames) do
				table.insert(matches, sn)
			end
			return matches
		end
		-- there was no exact match, perform prefix match for current arglead_index
		log.debug("handling prefix completion for %s", args[cmdline_index])
		for _, sn in ipairs(shortnames) do
			if vim.fn.match(sn, args[cmdline_index]) == 0 then
				table.insert(matches, sn)
			end
		end
		return matches
	end

	local function ws_handler_completion(arglead, cmdline, cursorpos)
		local log = logger.new("workspaces", "WorkspaceController.ws_handler_completion")
		log.debug(
			string.format("starting completion. arglead: %s cmdline: %s cursorpos: %d", arglead, cmdline, cursorpos)
		)
		local cur_tab = vim.api.nvim_get_current_tabpage()
		local ws = workspace_registry.get_workspace(cur_tab)
		if ws == nil then
			return
		end
		log.debug(string.format("discovered current workspace:  %d", cur_tab))
		local cmds = ws.get_commands()
		return recursive_ws_handler_completion(cmds, cmdline, 2)
	end

	-- The handler for the high level "Workspace" command.
	-- If ws_handler detects that no arguments are present to the "Workspace"
	-- command a recursive vim.ui.select method will be invoked asking the user
	-- for options over a set of sub command menus.
	--
	-- If ws_handler detects that an argument is specified
	local function ws_handler(args)
		local log = logger.new("workspaces", "WorkspaceController.ws_handler")
		log.info("handling Workspace command")

		local cur_tab = vim.api.nvim_get_current_tabpage()
		local ws = workspace_registry.get_workspace(cur_tab)
		if ws == nil then
			return
		end

		local cmds = ws.get_commands()
		log.debug("Current workspace: %d, discovered %d commands", cur_tab, #cmds)

		local function recursive_fuzzy_selection(cmds, fargs)
			log.debug("recursive fuzzy selection: prompting user for input")
			vim.ui.select(cmds, {
				prompt = "Select a command: ",
				format_item = function(cmd)
					return string.format("%s - %s", cmd.shortname, cmd.opts.desc)
				end,
			}, function(cmd)
				log.debug("user input: %s", cmd.shortname)
				if cmd.kind == libcmd.KIND_ACTION then
					log.debug("issuing %s command's action", cmd.shortname)
					cmd.callback(fargs)
					return
				end
				if cmd.kind == libcmd.KIND_SUBCOMMAND then
					log.debug("getting %s command's subcommands", cmd.shortname)
					recursive_fuzzy_selection(cmd.callback(), fargs)
				end
			end)
		end

		local function recursive_argument_selection(cmds, args, arg_index)
			local to_match = args.fargs[arg_index]
			for _, cmd in ipairs(cmds) do
				if to_match == nil then
					return
				end
				log.debug("recursive argument selection: comparing %s %s", cmd.shortname, to_match)
				if cmd.shortname == to_match then
					if cmd.kind == "action" then
						log.debug("matched, issuing %s command's action", cmd.shortname)
						cmd.callback(args)
					end
					if cmd.kind == "subcommand" then
						log.debug("matched, getting %s command's subcommands and recursing.", cmd.shortname)
						recursive_argument_selection(cmd.callback(), args, arg_index + 1)
					end
					return
				end
			end
		end

		if #args.fargs > 0 then
			log.info("performing argument selection due to fargs")
			recursive_argument_selection(cmds, args, 1)
		else
			log.info("performing fuzzy selection due to no fargs")
			recursive_fuzzy_selection(cmds, args)
		end
	end

	local function assign_ws(tab)
		local log = logger.new("workspaces", "WorkspaceController.assign_ws")
		local cur_win = vim.api.nvim_get_current_win()
		local ws = workspace.new(tab)
		ws.init()
		-- since this is triggered from a TabNewEnter
		ws.append_win_history(cur_win)
		log.info("assigned and initialized workspace for tab %d", tab)
	end

	function self.win_history_autocmd(args)
		local log = logger.new("workspaces", "WorkspaceController.win_history_autocmd")

		local cur_tab = vim.api.nvim_get_current_tabpage()
		local cur_win = vim.api.nvim_get_current_win()
		local buf = vim.api.nvim_win_get_buf(cur_win)
		local buf_name = vim.api.nvim_buf_get_name(buf)

		log.debug("received WinEnter event for win %d buf %d %s", cur_win, buf, buf_name)

		if vim.fn.match(args.file, "component://") > 0 then
			log.debug("event was for component window, returning.")
			return
		end

		if string.sub(args.file, 1, 7) == "diff://" then
			log.debug("event was for a diff window, returning.")
			return
		end

		-- only consider normal buffers with files loaded into them.
		if vim.api.nvim_buf_get_option(buf, "buftype") ~= "" then
			log.debug("event was for non file buffer. returning")
			return
		end

		local ws = workspace_registry.get_workspace(cur_tab)
		if ws == nil then
			log.debug("no workspace for tab %d. returning.", cur_tab)
			return
		end

		log.debug("recording visited window " .. cur_win)
		ws.append_win_history(cur_win)
	end

	-- Designed to be ran as an autocommand on the "TabNew" event.
	--
	-- Creates and assigns a workspace for a new tab.
	function self.tabnew_autocmd(args)
		local log = logger.new("workspaces", "WorkspaceController.tabnew_autocmd")
		local cur_win = vim.api.nvim_get_current_win()
		local cur_tab = vim.api.nvim_get_current_tabpage()
		assign_ws(cur_tab)
		log.debug("assigning workspace to tab %d due to new tab event", cur_tab)
		vim.api.nvim_set_current_win(cur_win)
	end

	-- Designed to be ran as an autocommand on the "TabClose" event.
	--
	-- Closes and unregisters a workspace for the closed tab if one exists.
	function self.tabclosed_autocmd(args)
		local log = logger.new("workspaces", "WorkspaceController.tabclosed_autocmd")
		local ws = workspace_registry.get_workspace(args.file)
		log.debug("closing workspace %s due to tab closed event", args.file)
		if ws ~= nil then
			ws.close()
		end
	end

	-- Initializes and starts the WorkSpace controller.
	--
	-- Once this method exists all existing and new tabs will be assigned
	-- workspaces by the controller.
	--
	-- Should only be called once during Neovim's runtime.
	function self.init()
		local log = logger.new("workspaces", "WorkspaceController.init")

		log.info("WorkspaceController init starting...")

		-- do this little dance to ensure we get back to the initial empty buffer
		-- on vim start.
		--
		-- if we try to restore the starting win too early we get weird startup
		-- issues, so do it only after "VimEnter" fires.
		local restore = libwin.restore_cur_win()
		local init_autocmd = nil
		local function init_callback()
			-- do not assign if we are git tool.
			local buf_name = vim.api.nvim_buf_get_name(0)
			if vim.fn.match(buf_name, "\\.git/") > -1 then
				return
			end

			-- check if manpager
			local args = vim.v.argv or {}
			for idx, arg in ipairs(args) do
				if arg == "-c" and (args[idx + 1] == "Man" or args[idx + 1] == "Man!") then
					return
				end

				if arg == "+Man" or arg == "+Man!" then
					return
				end
			end

			for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
				assign_ws(tab)
			end
			restore()
			if init_autocmd then
				vim.api.nvim_del_autocmd(init_autocmd)
			end
		end

		if vim.v.vim_did_enter then
			vim.defer_fn(init_callback, 1)
		else
			init_autocmd = vim.api.nvim_create_autocmd({ "VimEnter" }, {
				callback = init_callback,
			})
		end

		self.tabnew_autocmd_id = vim.api.nvim_create_autocmd({ "TabNewEntered" }, {
			callback = self.tabnew_autocmd,
		})
		log.info("WorkspaceController now handling new tab events.")

		self.tabclosed_autocmd_id = vim.api.nvim_create_autocmd({ "TabClosed" }, {
			callback = self.tabclosed_autocmd,
		})
		log.info("WorkspaceController now handling closed tab events.")

		self.win_history_autocmd_id = vim.api.nvim_create_autocmd({ "WinEnter" }, {
			callback = self.win_history_autocmd,
		})
		log.info("WorkspaceController now handling recording viewed window history")

		vim.api.nvim_create_user_command("Workspace", ws_handler, {
			nargs = "*",
			complete = ws_handler_completion,
		})

		-- add an autocommand which closes all panels before vim exits.
		-- this plays nice with most session manager plugins and ensures nvim-ide
		-- windows are not saved in sessions on vim's exit.
		vim.api.nvim_create_autocmd("VimLeavePre", {
			callback = function()
				vim.api.nvim_command("Workspace LeftPanelClose")
				vim.api.nvim_command("Workspace RightPanelClose")
				vim.api.nvim_command("Workspace BottomPanelClose")
			end
		})

		log.info("Workspace command now registered.")
	end

	-- Stops the WorkspaceController.
	--
	-- Once this method exists all tabs will have their Workspaces closed and
	-- all new tabs will not be assigned workspaces.
	function self.stop()
		local log = logger.new("workspaces", "WorkspaceController.stop")
		vim.api.nvim_del_autocmd(self.tabclosed_autocmd_id)
		vim.api.nvim_del_autocmd(self.tabnew_autocmd_id)
		log.info("WorkspaceController stopped")
	end

	return self
end

return WorkspaceController

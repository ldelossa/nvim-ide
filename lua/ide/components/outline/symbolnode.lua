local node = require("ide.trees.node")
local icons = require("ide.icons")
local liblsp = require("ide.lib.lsp")
local libpopup = require("ide.lib.popup")

local SymbolNode = {}

SymbolNode.new = function(document_symbol, depth)
	-- extends 'ide.trees.Node' fields.

	-- range should not be nil per LSP spec, but some LSPs will return nil
	-- range, if so fill it in so we can create a unique key.
	if document_symbol.range == nil then
		document_symbol.range = {
			start = {
				line = 1,
				character = 1,
			},
			["end"] = {
				line = 1,
				character = 1,
			},
		}
	end

	local key =
		string.format("%s:%s:%s", document_symbol.name, document_symbol.range["start"], document_symbol.range["end"])
	local self = node.new("symbol", document_symbol.name, key, depth)

	-- clear the child's field of document_symbol, it'll be duplicate info once
	-- this node is in a @Tree.
	local symbol = vim.deepcopy(document_symbol)
	symbol.children = (function()
		return {}
	end)()

	self.document_symbol = symbol

	function self.details()
		local icon = " "
		local kind = vim.lsp.protocol.SymbolKind[self.document_symbol.kind]
		if kind ~= "" then
			icon = icons.global_icon_set.get_icon(kind) or "[" .. kind .. "]"
		end

		local range = liblsp.get_document_symbol_range(self.document_symbol)

		local lines = {}
		table.insert(lines, string.format("%s %s %s", icon, "Symbol:", self.document_symbol.name))
		table.insert(lines, string.format("%s %s %s", icon, "Kind:", kind))
		if range ~= nil then
			table.insert(
				lines,
				string.format(
					"%s %s L%d:%d",
					icons.global_icon_set.get_icon("File"),
					"Start:",
					range.start.line,
					range.start.character
				)
			)
			table.insert(
				lines,
				string.format(
					"%s %s L%d:%d",
					icons.global_icon_set.get_icon("File"),
					"End:",
					range["end"].line,
					range["end"].character
				)
			)
		end
		table.insert(lines, string.format(""))
		if (self.document_symbol.detail ~= nil) then
					table.insert(lines, string.format("%s", self.document_symbol.detail))
		end

		libpopup.until_cursor_move(lines)
	end

	-- Marshal a symbolnode into a buffer line.
	--
	-- @return: @icon - @string, icon for symbol's kind
	--          @name - @string, symbol's name
	--          @details - @string, symbol's detail if exists.
	function self.marshal()
		local icon = "s"
		local kind = vim.lsp.protocol.SymbolKind[self.document_symbol.kind]
		if kind ~= "" then
			icon = icons.global_icon_set.get_icon(kind) or "[" .. kind .. "]"
		end

		local name = self.document_symbol.name
		local detail = ""
		if self.document_symbol.detail ~= nil then
			detail = self.document_symbol.detail
		end

		return icon, name, detail
	end

	return self
end

return SymbolNode

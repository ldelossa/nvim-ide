local LSP = {}

function LSP.request_all_first_result(resp)
	for id, r in pairs(resp) do
		if r.result ~= nil and not vim.tbl_isempty(r.result) then
			return r.result, id
		end
	end
	return nil
end

function LSP.call_hierarchy_call_to_item(direction, call)
	if direction == "incoming" then
		return call["from"]
	end
	if direction == "outgoing" then
		return call["to"]
	end
	return nil
end

function LSP.item_to_call_hierarchy_call(direction, item)
	if direction == "incoming" then
		return {
			from = item,
			fromRanges = {},
		}
	end
	if direction == "outgoing" then
		return {
			to = item,
			fromRanges = {},
		}
	end
end

function LSP.make_prepare_call_hierarchy_request(text_document_pos, opts, callback)
	if text_document_pos == nil then
		text_document_pos = vim.lsp.util.make_position_params()
		if text_document_pos == nil then
			return
		end
	end

	local method = "textDocument/prepareCallHierarchy"

	-- perform on current buffer
	if opts == nil then
		vim.lsp.buf_request_all(0, method, text_document_pos, function(resp)
			local call_hierarchy_item, client_id = LSP.request_all_first_result(resp)
			callback(call_hierarchy_items, client_id)
		end)
		return
	end

	-- get client and make a request with this
	if opts.client_id ~= nil then
		local client = vim.lsp.get_client_by_id(opts.client_id)
		if client == nil then
			return
		end
		client.request(method, text_document_pos, function(err, call_hierarchy_item, _, _)
			if err ~= nil then
				error(vim.inspect(err))
			end
			callback(call_hierarchy_items)
		end)
		return
	end

	-- perform a request with all active clients for the provided buffer.
	if opts.buf ~= nil then
		vim.lsp.buf_request_all(opts.buf, method, text_document_pos, function(resp)
			local call_hierarchy_items, client_id = LSP.request_all_first_result(resp)
			callback(call_hierarchy_items, client_id)
		end)
		return
	end
end

function LSP.make_call_hierarchy_request(direction, call_hierarchy_item, opts, callback)
	local method = nil
	if direction == "outgoing" then
		method = "callHierarchy/outgoingCalls"
	end
	if direction == "incoming" then
		method = "callHierarchy/incomingCalls"
	end
	if method == nil then
		error("direction must be `incoming` or `outgoing`: direction=" .. direction)
	end
	assert(call_hierarchy_item ~= nil, "call_hierarchy_item cannot be nil")

	local params = { item = call_hierarchy_item }

	-- perform on current buffer
	if opts == nil then
		vim.lsp.buf_request_all(0, method, params, function(resp)
			local call_hierarchy_calls = LSP.request_all_first_result(resp)
			callback(direction, call_hierarchy_item, call_hierarchy_calls)
		end)
		return
	end

	-- get client and make a request with this
	if opts.client_id ~= nil then
		local client = vim.lsp.get_client_by_id(opts.client_id)
		if client == nil then
			return
		end
		client.request(method, params, function(err, call_hierarchy_calls, _, _)
			if err ~= nil then
				error(vim.inspect(err))
			end
			callback(direction, call_hierarchy_item, call_hierarchy_calls)
		end)
		return
	end

	-- perform a request with all active clients for the provided buffer.
	if opts.buf ~= nil then
		vim.lsp.buf_request_all(opts.buf, method, params, function(resp)
			local call_hierarchy_calls = LSP.request_all_first_result(resp)
			callback(direction, call_hierarchy_item, call_hierarchy_calls)
		end)
		return
	end
end

function LSP.make_outgoing_calls_request(call_hierarchy_item, opts, callback)
	LSP.make_call_hierarchy_request("outgoing", call_hierarchy_item, opts, callback)
end

function LSP.make_incoming_calls_request(call_hierarchy_item, opts, callback)
	LSP.make_call_hierarchy_request("incoming", call_hierarchy_item, opts, callback)
end

function LSP.highlight_call_hierarchy_call(buf, direction, call_hierarchy_item_call)
	local highlights = {}
	local call_hierarchy_item = LSP.call_hierarchy_call_to_item(direction, call_hierarchy_item_call)
	if call_hierarchy_item == nil then
		return
	end

	table.insert(highlights, { range = call_hierarchy_item.selectionRange })

	for _, range in ipairs(call_hierarchy_item_call.fromRanges) do
		table.insert(highlights, { range = range })
	end

	vim.lsp.util.buf_highlight_references(buf, highlights, "utf-8")

	return function()
		vim.lsp.util.buf_clear_references(buf)
	end
end

function LSP.get_document_symbol_range(document_symbol)
	if document_symbol.selectionRange ~= nil then
		return document_symbol.selectionRange
	end
	if document_symbol.location ~= nil and document_symbol.location["range"] ~= nil then
		return document_symbol.location["range"]
	end
	if document_symbol.range ~= nil then
		return document_symbol.selectionRange
	end
	return nil
end

function LSP.detach_all_clients_buf(buf)
	vim.lsp.for_each_buffer_client(buf, function(_, client_id, bufnr)
		vim.lsp.buf_detach_client(bufnr, client_id)
	end)
end

return LSP

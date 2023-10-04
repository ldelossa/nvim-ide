local Web = {}

-- Opens the `url` with either `xdg-open` for linux or `open` for macOS.
--
-- @url - @string, an http(s) protocol url.
function Web.open_link(url)
	if vim.fn.has("mac") == 1 then
		vim.fn.system({ "open", url })
	else
		vim.fn.system({ "xdg-open", url })
	end
end

return Web

local git = require("ide.lib.git.client")

local M = {}

function M.test_functionality()
	local client = git.new()
	-- client.log_file_history(
	--     "lua/ide/lib/buf.lua",
	--     0,
	--     10,
	--     function(commits)
	--         print(vim.inspect(commits))
	--     end
	-- )
	-- client.log(
	--     "HEAD",
	--     1,
	--     function(commits)
	--         print(vim.inspect(commits))
	--     end
	-- )
	-- client.status(function(stats)
	--     print(vim.inspect(stats))
	-- end)
	-- client.show_rev_paths("HEAD", function(paths)
	--     print(vim.inspect(paths))
	-- end)
	-- client.log_commits(0, 10, function(commits)
	--     print(vim.inspect(commits))
	-- end)
	-- print(vim.inspect(git.compare_sha("abcde", "abcd")))
	-- print(vim.inspect(git.compare_sha("abcde", "abcdg")))
	client.head(function(rev)
		print(rev)
	end)
end

return M

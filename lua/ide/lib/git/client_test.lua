local git = require('ide.lib.git.client')

M = {}

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
    client.status(function(stats)
        print(vim.inspect(stats))
    end)
end

return M

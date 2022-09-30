local async_client = require('ide.lib.async_client')

Client = {}

Client.RECORD_SEP = '␞'
Client.GROUP_SEP = '␝'

Client.new = function()
    local self = async_client.new("git")

    local function handle_req(callback)
        return function(req)
            if req.error then
                return
            end
            if req.exit_code ~= 0 then
                callback(nil)
                return
            end
            callback(req.stdout)
        end
    end

    -- issues a git log with a specified --format string.
    --
    -- the @format param must be an array of format specifiers as outlined in
    -- `man git log`. 
    --
    -- each format specifier will be concat'd into a format string with the 
    -- ASCII record separator character "␞" as a delimiter.
    --
    -- the returned output can then be split on the record separator character
    -- to obtain each field in the format specifier.
    --
    -- @format - @table, an array of format specifies as outlined in `man git log`
    -- @args   - @string, any additional arguments to supply to the `git log` command.
    -- @cb     - @function(table|nil) - an array of `git log` lines or nil if 
    --           if a non zero exit code was encountered.
    function self.log_format(format, args, cb)
        local separated = ""
        for i, fspec in ipairs(format) do
            separated = separated .. fspec
            if i ~= #format then
                separated = separated .. Client.RECORD_SEP
            end
        end
        self.make_nl_request(
            string.format("log --format=%s %s", separated, args),
            nil,
            handle_req(cb)
        )
    end

    -- Return the information retrieved by a default `git log` command.
    --
    -- @rev - @string, a git revision as described by `man gitrevision.7`
    -- @n   - @int, the number of commits to retrieve starting from `rev`. 
    --        -1 can be used to return all commits relative to `rev`.
    -- @cb  - function(table|nil) - an array of tables with the following 
    --        fields:
    --        - sha     - @string, the full commit sha
    --        - author  - @sting, the author's full name
    --        - email   - @string, the author's email
    --        - date    - @string, date of the commit in ISO format.
    --        - subject - @string, the subject of the commit
    --        - body    - @string, body of the commit
    function self.log(rev, n, cb)
        local separated = ""
        local format = {"%H", "%an", "%ae", "%aD", "%s", "%b"}
        for i, fspec in ipairs(format) do
            separated = separated .. fspec
            if i ~= #format then
                separated = separated .. Client.RECORD_SEP
            else
                separated = separated .. Client.GROUP_SEP
            end
        end
        self.make_request(
        string.format("log -n %d --format=%s %s", n, separated, rev),
        nil,
        function(resp)
            if resp == nil then
                cb(nil)
            end
            local out = {}
            local commits = vim.fn.split(resp.stdout, Client.GROUP_SEP)
            for _, commit in ipairs(commits) do
                local parts = vim.fn.split(commit, Client.RECORD_SEP)
                if #parts ~= 6 then
                    goto continue
                end
                table.insert(out, {
                    sha = parts[1],
                    author = parts[2],
                    email = parts[3],
                    date = parts[4],
                    subject = parts[5],
                    body = parts[6]
                })
                ::continue::
            end
            cb(out)
        end)
    end

    -- Get all commits with have manipulated the file at `path` in reverse
    -- chronological order.
    --
    -- @path - @string, a path, relative to the root of the git repository, 
    -- @skip - @int, the number of returned commits to skip, used for paging.
    -- @n    - @int, the number of commits to return, used for paging.
    -- @cb   - function(table|nil), a callback function issued with the results.
    --         if not nil, an array of tables describing the
    --         commit in the context of a history.
    --         table fields:
    --          sha     - @string, the abbreviated commit sha
    --          author  - @string, the name of the author of the commit
    --          subject - @string, the single line subject header of the commit
    --                    messages
    --          date    - @string, the relative time (from time of the issued command)
    --                    the commit was created.
    function self.log_file_history(path, skip, n, cb)
        self.log_format(
            -- abbrev sha, author name, subject, relative date.
            {"%H", "%an", "%s", "%cr"},
            string.format("--skip=%d -n %d -- %s", skip, n, path),
            function(stdout)
                if stdout == nil then
                    cb(nil)
                end
                local commits = {}
                for _, commit in ipairs(stdout) do
                    local parts = vim.fn.split(commit, Client.RECORD_SEP)
                    table.insert(commits, {
                        sha = parts[1], author = parts[2], subject = parts[3], date = parts[4]
                    })
                end
                cb(commits)
            end
        )
    end

    -- Returns the contents of file `path` at `rev` as an array of lines.
    --
    -- @rev     - @string, a git revision as defined in `man gitrevision.7` 
    -- @path    - @string, a path, relative to the root, of the repository of a file
    --            to display at `rev`.
    -- @cb      - function(table|nil), a callback called with an array of strings,
    --            each of which are a line within `path` at `rev`.
    --            nil if a non-zero exit code is encountered.
    function self.show_file(rev, path, cb)
        self.make_nl_request(
            string.format("show %s:%s", rev, path),
            nil,
            handle_req(cb)
        )
    end

    -- Returns a list of tables expressing any changed files status for the
    -- current repository.
    --
    -- This command uses the --porcelain flag to obtain a stripped down
    -- list of statuses.
    function self.status(cb)
        local parse = function(data)
            local out = {}
            for _, d in ipairs(data) do
                local staged_status = vim.fn.strpart(d, 0, 1)
                local unstaged_status = vim.fn.strpart(d, 1, 1)
                local path = vim.fn.strpart(d, 3)
                local status = (function()
                    local status = nil
                    if staged_status == "" then
                        status = " "
                    else
                        status = staged_status
                    end
                    if unstaged_status == "" then
                        status = status .. " "
                    else
                        status = status .. unstaged_status
                    end
                    return status
                end)()
                local stat = {
                    staged_status = staged_status,
                    unstaged_status = unstaged_status,
                    status = status,
                    path = path
                }
                table.insert(out, stat)
            end
            return out
        end

        self.make_nl_request(
            string.format("status --porcelain"),
            nil,
            handle_req(function(stats)
                cb(parse(stats))
            end)
        )
    end

    function self.git_add(path, cb)
        self.make_request(string.format("add %s", path), nil, handle_req(cb))
    end

    function self.git_restore(staged, path, cb)
        local cmd = ""
        if staged then
            cmd = string.format("restore --staged %s", path)
        else
            cmd = string.format("restore %s", path)
        end
        self.make_request(cmd, nil, handle_req(cb))
    end

    function self.branch(cb)
        local function parse(refs)
            local branches = {}
            local head_sha = ""
            for _, ref in ipairs(refs) do
                local is_head = false
                local parts = vim.fn.split(ref)
                local sha = parts[1]
                local branch = vim.fn.split(parts[2], "refs/heads/")[1]
                if branch == "HEAD" then
                    head_sha = sha
                    goto continue
                end
                if sha == head_sha then
                    is_head = true
                end
                table.insert(branches, {
                    sha = sha,
                    branch = branch,
                    is_head = is_head
                })
                ::continue::
            end
            return branches
        end
        self.make_nl_request(
            "show-ref --heads --head",
            nil,
            handle_req(function(refs)
                cb(parse(refs))
            end)
        )
    end

    return self
end

return Client

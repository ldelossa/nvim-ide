local uv = vim.loop
local logger = require('ide.logger.logger')

local Client = {}

Client.new = function(cmd)
    local self = {
        cmd = cmd,
        -- a default logger that's set on construction.
        -- a derived class can set this logger instance and base class methods will
        -- derive a new logger from it to handle base class component level log fields.
        logger = logger.new("async_client"),
    }

    -- a basic stderr reader which concats reads into req.stdout or sets
    -- an error if reading fails.
    local function _basic_stdout_read(req)
        return function(err, data)
            -- error reading stdout, capture and return.
            if err then
                req.error = true
                req.reason = string.format("error reading from stdout: %s", err)
                return
            end
            -- more data to read, concat it to stdout buffer.
            if data then
                req.stdout = req.stdout .. data
                return
            end
        end
    end

    -- a basic stderr reader which concats reads into req.stderr or sets
    -- an error if reading fails.
    local function _basic_stderr_read(req)
        return function(err, data)
            -- error reading stdout, capture and return.
            if err then
                req.error = true
                req.reason = string.format("error reading from stderr: %s", err)
                req.stderr_eof = true
                return
            end
            -- more data to read, concat it to stdout buffer.
            if data then
                req.stderr = req.stderr .. data
                return
            end
        end
    end

    -- helper functions to create a formatted string for logging a req.
    function self.log_req(req, with_output)
        if with_output then
            return string.format("\n [pid]: %s [cmd]: %s [args]: %s [error]: %s [reason]: %s [exit_code]: %s [signal]: %s \n [stderr]:\n%s \n [stdout]:\n%s"
                ,
                vim.inspect(req.pid),
                req.cmd,
                req.args,
                vim.inspect(req.error),
                req.reason,
                vim.inspect(req.exit_code),
                req.signal,
                req.stderr,
                req.stdout
            )
        end
        return string.format("\n [pid]: %s [cmd]: %s [args]: %s [error]: %s [reason]: %s [exit_code]: %s [signal]: %s",
            vim.inspect(req.pid),
            req.cmd,
            req.args,
            vim.inspect(req.error),
            req.reason,
            vim.inspect(req.exit_code),
            req.signal
        )

    end

    -- makes an async request with the given arguments.
    --
    -- @args        - (@table|@string), if a table, an array of arguments.
    --              if a string is provided it will be split on white-space to
    --              resolve an array of arguments.
    -- @opts        - @table, - options for future usage.
    -- @callback    - @function(@table), A callback issued on request finish,
    --                called with a `request` table.
    --                request table fields:
    --                  cmd - @string, the cli command
    --                  args- @string, the joined arguments to the cli
    --                  stdout - @string, the raw stdout
    --                  stderr - @string, the raw stderr
    --                  error - @bool, if there was an error involved in issuing the command
    --                  reason - @string, if error is true, the reason there was an error
    --                  exit_code - @int, the exit code of the command
    -- @processor   - @function(@table), a callback, called with a `req` table described,
    --                just before the `callback` is issued. provides a hook to manipulate
    --                the `req` object before the callback is issued.
    function self.make_request(args, opts, callback, processor)
        local log = self.logger.logger_from(nil, "Client.make_request")

        if opts == nil then opts = {} end
        if args == nil then args = {} end
        -- be a nice client, and split strings for the caller.
        if type(args) == "string" then
            args = vim.fn.split(args)
        end

        local req = {
            cmd = self.cmd,
            args = vim.fn.join(args),
            stdout = "",
            stderr = "",
            error = false,
            reason = "",
            exit_code = nil,
            signal = nil,
        }

        local stdout = vim.loop.new_pipe()
        local stderr = vim.loop.new_pipe()
        local handle = nil
        local pid = nil

        local callback_wrap = function(exit_code)
            req.exit_code = exit_code
            if exit_code ~= 0 then
                req.error = true
                req.reason = "non-zero status code: " .. exit_code
            end
            req.signal = signal
            vim.schedule(function()
                log.debug("finished request, handling callbacks and closing handles %s", self.log_req(req, true))
                if processor ~= nil then
                    processor(req)
                end
                callback(req)
                -- close all pipes and handles only after we run our processor
                -- and callback to avoid close-before-read timing bugs.
                stdout:read_stop()
                stderr:read_stop()
                stdout:close()
                stderr:close()
                handle:close()
            end)
        end

        handle, pid = uv.spawn(
            self.cmd,
            {
                stdio = { nil, stdout, stderr },
                args = args,
                verbatim = true
            },
            callback_wrap
        )
        req.pid = pid
        log.debug("made request %s", self.log_req(req))

        stdout:read_start(_basic_stdout_read(req))
        stderr:read_start(_basic_stderr_read(req))
    end

    function self.make_json_request(args, opts, callback)
        self.make_request(args, opts, callback, function(req)
            local ok, out = pcall(vim.fn.json_decode, req.stdout)
            if not ok then
                req.error = true
                req.reason = string.format("error decoding json: %s", out)
                return
            end
            req.stdout = out
        end)
    end

    function self.make_nl_request(args, opts, callback)
        self.make_request(args, opts, callback, function(req)
            local ok, out = pcall(vim.fn.split, req.stdout, "\n")
            if not ok then
                req.error = true
                req.reason = string.format("error splitting text by new lines: %s", out)
                return
            end
            req.stdout = out
        end)
    end

    return self
end

return Client

local Logger = {}

Logger.session_id = string.format("nvim-ide-log://%s-%s", "nvim-ide", vim.fn.rand())

Logger.log_level = vim.log.levels.INFO

Logger.buffer = (function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, Logger.session_id)
    return buf
end)()

Logger.set_log_level = function(level)
    if level == 'debug' then
        Logger.log_level = vim.log.levels.DEBUG
        return
    end
    if level == 'warn' then
        Logger.log_level = vim.log.levels.WARN
        return
    end
    if level == 'info' then
        Logger.log_level = vim.log.levels.INFO
        return
    end
    if level == 'error' then
        Logger.log_level = vim.log.levels.ERROR
        return
    end
    Logger.log_level = vim.log.levels.INFO
end

function Logger.open_log()
    vim.cmd("tabnew")
    vim.api.nvim_win_set_buf(0, Logger.buffer)
end

Logger.new = function(subsys, component)
    assert(subsys ~= nil, "Cannot construct a Logger without a subsys field.")
    local self = {
        -- the subsystem for this logger instance
        subsys = subsys,
        -- the component within the subsystem producing the log.
        component = "",
    }
    if component ~= nil then
        self.component = component
    end

    local function _log(level, fmt, ...)
        local arg = { ... }
        local str = string.format("[%s] [%s] [%s] [%s]: ", os.date("!%Y-%m-%dT%H:%M:%S"), level, self.subsys, self.component)
        if arg ~= nil then
            str = str .. string.format(fmt, unpack(arg))
        else
            str = str .. string.format(fmt)
        end
        local lines = vim.fn.split(str, "\n")
        vim.api.nvim_buf_set_lines(Logger.buffer, -1, -1, false, lines)
    end

    function self.error(fmt, ...)
        if vim.log.levels.ERROR >= Logger.log_level then
            _log("error", fmt, ...)
        end
    end

    function self.warning(fmt, ...)
        if vim.log.levels.WARN >= Logger.log_level then
            _log("warning", fmt, ...)
        end
    end

    function self.info(fmt, ...)
        if vim.log.levels.INFO >= Logger.log_level then
            _log("info", fmt, ...)
        end
    end

    function self.debug(fmt, ...)
        if vim.log.levels.DEBUG >= Logger.log_level then
            _log("debug", fmt, ...)
        end
    end

    function self.logger_from(subsys, component)
        local cur_subsys = self.subsys
        if subsys ~= nil then
            cur_subsys = subsys
        end
        local cur_comp = self.component
        if component ~= nil then
            cur_comp = component
        end
        return Logger.new(cur_subsys, cur_comp)
    end

    return self
end

return Logger

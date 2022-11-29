local async_client = require('ide.lib.async_client')

local GH = {}

GH.RECORD_SEP = '␞'
GH.GROUP_SEP = '␝'

GH.new = function()
    local self = async_client.new("gh")

    local function handle_req(req)

    end
end

return GH

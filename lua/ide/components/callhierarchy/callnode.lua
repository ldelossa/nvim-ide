local node     = require('ide.trees.node')
local icons = require('ide.icons')
local liblsp   = require('ide.lib.lsp')
local prompts  = require('ide.components.explorer.prompts')
local logger   = require('ide.logger.logger')

local CallNode = {}

CallNode.new = function(component, direction, call_hierarchy_item_call, depth)
    -- extends 'ide.trees.Node' fields.

    local call_hierarchy_item = liblsp.call_hierarchy_call_to_item(direction, call_hierarchy_item_call)
    assert(call_hierarchy_item ~= nil, "could not extract a CallHierarchyItem from the provided CallHierarchyCall")

    -- range should not be nil per LSP spec, but some LSPs will return nil
    -- range, if so fill it in so we can create a unique key.
    if call_hierarchy_item.range == nil then
        call_hierarchy_item.range = {
            start = {
                line = 1,
                character = 1
            },
            ['end'] = {
                line = 1,
                character = 1
            }
        }
    end

    local key = string.format("%s:%s:%s", call_hierarchy_item.name, call_hierarchy_item.range["start"],
        call_hierarchy_item.range["end"])

    local self = node.new(direction .. "_call_hierarchy", call_hierarchy_item.name, key, depth)

    -- important, the base class defaults to nodes being expanded on creation.
    -- we don't want this for CallNodes, since we dynamically fill a CallNode's
    -- children on expand.
    self.expanded = false
    -- keep a reference to the component which created self, we'll reuse the
    -- method set.
    self.component = component
    -- one of "incoming" or "outgoing", the orientation of this node.
    self.direction = direction
    -- the result from a "callHierarchy/*Calls" LSP request.
    -- see: https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/#callHierarchy_outgoingCalls
    self.call_hierarchy_item_call = call_hierarchy_item_call

    -- Marshal a callnode into a buffer line.
    --
    -- @return: @icon - @string, icon used for call hierarchy item
    --          @name - @string, the name of the call hierarchy item
    --          @details - @string, the details of the call hierarchy item
    function self.marshal()
        local guide = nil
        if self.expanded and #self.children == 0 then
            guide = ""
        end

        local call_hierarchy_item = liblsp.call_hierarchy_call_to_item(self.direction, self.call_hierarchy_item_call)
        local icon = "s"
        local kind = vim.lsp.protocol.SymbolKind[call_hierarchy_item.kind]
        if kind ~= "" then
            icon = icons.global_icon_set.get_icon(kind) or "[" .. kind .. "]"
        end

        local name = call_hierarchy_item.name
        local detail = ""
        if call_hierarchy_item.detail ~= nil then
            detail = call_hierarchy_item.detail
        end

        return icon, name, detail, guide
    end

    -- Expands a callnode.
    -- This will perform an additional callHierarchy/* call and and its children
    -- to self.
    --
    -- @opts - @table, options for the expand, for future use.
    --
    -- return: void
    function self.expand(opts)
        local item = liblsp.call_hierarchy_call_to_item(self.direction, self.call_hierarchy_item_call)
        local callback = function(direction, call_hierarchy_item, call_hierarchy_calls)
            if call_hierarchy_calls == nil then
                self.expanded = true
                self.tree.marshal({  })
                self.component.state["cursor"].restore()
                return
            end
            local children = {}
            for _, call in ipairs(call_hierarchy_calls) do
                table.insert(children, CallNode.new(self.component, direction, call))
            end
            self.tree.add_node(self, children)
            self.expanded = true
            self.tree.marshal({  })
            self.component.state["cursor"].restore()
        end
        if self.direction == "incoming" then
            liblsp.make_incoming_calls_request(item, { client_id = self.component.state["client_id"] }, callback)
            return
        end
        if self.direction == "outgoing" then
            liblsp.make_outgoing_calls_request(item, { client_id = self.component.state["client_id"] }, callback)
            return
        end
    end

    return self
end

return CallNode

-- ComponentFactory registers @Component's constructor functions.
-- This allows uncoupled modules to request the creation of known @Component(s)
--
-- This is a global singleton resource that other modules can use after import.
local ComponentFactory = {}

local factory = {}

-- Register a @Component's constructor with the @Component's unique name.
--
-- @name - The unique name for the @Component being registered.
-- @constructor - The constructor method for the component.
--                This method must be the same signature as @Component.new method.
--
-- @return void
function ComponentFactory.register(name, constructor)
	if factory[name] ~= nil then
		error(string.format("A constructor for %s has already been registered", name))
	end
	factory[name] = constructor
end

function ComponentFactory.unregister(name)
	factory[name] = nil
end

function ComponentFactory.get_constructor(name)
	return factory[name]
end

return ComponentFactory

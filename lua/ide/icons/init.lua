local Icons = {}

-- Set the global IconSet to the default IconSet.
-- This can be overwritten later to change the icon set used across all components
-- which use this global.
Icons.global_icon_set = require("ide.icons.codicon_icon_set").new()

return Icons

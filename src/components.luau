local jecs = require("./dependencies/jecs")
local replecs = require("./dependencies/replecs")

local action = jecs.tag()
jecs.meta(action, jecs.Exclusive)

local session_custom_id = replecs.create_custom_id("wcs_session", function()
	return nil
end)

return table.freeze({
	action = action,
	action_player = jecs.component<<Player>>(),
	unavailable = jecs.tag(),
	action_request = jecs.component<<{ any }?>>(),
	continuous_request = jecs.component<<{ any }?>>(),
	processed = jecs.tag(),
	session = jecs.tag(),
	session_custom_id = session_custom_id,
})

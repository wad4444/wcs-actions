local jecs = require(script.Parent.Parent.jecs)

local action = jecs.tag()
jecs.meta(action, jecs.Exclusive)

return {
	action = action,
	action_player = jecs.component<<Player>>(),
	unavailable = jecs.tag(),
	action_request = jecs.component<<{ any }?>>(),
	continuous_request = jecs.component<<{ any }?>>(),
	processed = jecs.tag(),
}

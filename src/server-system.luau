local jecs = require("./dependencies/jecs")
local replecs = require("./dependencies/replecs")
local collect = require("./dependencies/jecs-utils").collect :: types.Collect
local ct = require("./components")
local constants = require("./constants")
local remotes = require("./remotes")
local types = require("./types")

local function is_valid_entity(world: types.World, entity: any): boolean
	if type(entity) ~= "number" then
		return false
	end
	return world:contains(entity :: types.Entity)
end

local function is_valid_request(
	world: types.World,
	registry: types.AnyActionRegistry,
	player: Player,
	entity: any
): boolean
	if not is_valid_entity(world, entity) then
		return false
	end

	local action_marker = world:target(entity, ct.action)
	if not action_marker then
		return false
	end

	local action_table = registry.get_config(action_marker :: any)
	if action_table.action_type ~= "server" and action_table.action_type ~= "predicted" then
		return false
	end

	return world:get(entity, ct.action_player) == player
end

local function should_replicate_session<T>(action_table: types.ActionTable<T>): boolean
	return action_table.action_type == "predicted" or action_table.action_type == "shared"
end

local function server_system<T>(props: types.ServerSystemProps<T>)
	local world = props.world
	local state = props.state
	local registry = props.registry
	local replicator = props.replicator
	local cleanup = props.cleanup

	local use_requests, cleanup_requests = collect(remotes.use_request.OnServerEvent)
	local continuous_starts, cleanup_continuous_starts = collect(remotes.start_continuous.OnServerEvent)
	local continuous_stops, cleanup_continuous_stops = collect(remotes.stop_continuous.OnServerEvent)
	local mispredictions, cleanup_mispredictions = collect(remotes.misprediction.OnServerEvent)
	local messages, cleanup_messages = collect(remotes.message.OnServerEvent)
	local messages_urel, cleanup_messages_urel = collect(remotes.message_urel.OnServerEvent)

	local action_wildcard = jecs.pair(ct.action, jecs.Wildcard)
	local processed_continuous = jecs.pair(ct.processed, ct.continuous_request)

	local continuous_query = world:query(ct.continuous_request):with(action_wildcard):cached()
	local action_request_query = world:query(ct.action_request):with(action_wildcard):cached()
	local new_continuous_query =
		world:query(ct.continuous_request):with(action_wildcard):without(processed_continuous):cached()
	local stopped_continuous_query =
		world:query(action_wildcard):with(processed_continuous):without(ct.continuous_request):cached()
	local message_query = world:query(ct.session_message):with(ct.session):cached()
	local message_urel_query = world:query(ct.session_message_urel):with(ct.session):cached()

	local sessions: { [any]: any } = {}

	replicator:register_custom_id(ct.session_custom_id)

	local function dispatch_incoming_message(player: Player, entity: any, data: { any }?)
		if not is_valid_entity(world, entity) then
			return
		end
		if world:get(entity, ct.action_player) ~= player then
			return
		end

		local session = sessions[entity]
		if not session or not world:contains(session) or not world:has(session, ct.session) then
			return
		end

		local action_marker = world:target(entity, ct.action)
		if not action_marker then
			return
		end

		local action_table = registry.get_config(action_marker :: any)
		local on_message = action_table.on_message
		if not on_message then
			local action_name = world:get(action_marker :: any, jecs.Name)
			warn(`[wcs-actions] received message for action '{action_name}' but no on_message handler is set`)
			return
		end

		on_message(state, entity, session, data)
	end

	cleanup(function()
		continuous_query:fini()
		action_request_query:fini()
		new_continuous_query:fini()
		stopped_continuous_query:fini()
		message_query:fini()
		message_urel_query:fini()

		cleanup_requests()
		cleanup_continuous_starts()
		cleanup_continuous_stops()
		cleanup_mispredictions()
		cleanup_messages()
		cleanup_messages_urel()
	end)

	return function()
		for _, player, entity, data in messages do
			dispatch_incoming_message(player, entity, data)
		end

		for _, player, entity, data in messages_urel do
			dispatch_incoming_message(player, entity, data)
		end

		for _, player, entity, data in use_requests do
			if not is_valid_request(world, registry, player, entity) then
				continue
			end
			world:set(entity, ct.action_request, data)
		end

		for _, player, entity, data in continuous_starts do
			if not is_valid_request(world, registry, player, entity) then
				continue
			end
			world:set(entity, ct.continuous_request, data)
		end

		for _, player, entity in continuous_stops do
			if not is_valid_request(world, registry, player, entity) then
				continue
			end
			world:remove(entity, ct.continuous_request)
		end

		for _, player, entity in mispredictions do
			if not is_valid_entity(world, entity) then
				continue
			end
			if world:get(entity, ct.action_player) ~= player then
				continue
			end
			local action_marker = world:target(entity, ct.action)
			if not action_marker then
				continue
			end
			local action_table = registry.get_config(action_marker :: any)
			if action_table.action_type ~= "predicted" then
				continue
			end
			local session = sessions[entity]
			if not session then
				continue
			end
			if world:contains(session) then
				world:delete(session)
			end
		end

		for entity, data in continuous_query do
			local action_marker = world:target(entity, ct.action)
			assert(action_marker, "Action marker not found")

			local action_table = registry.get_config(action_marker)
			if action_table.action_type == "client" then
				continue
			end

			local is_unavailable = world:has(entity, ct.unavailable) or action_table.can_start(state, entity) == false
			if is_unavailable then
				continue
			end

			world:set(entity, ct.action_request, data)
		end

		local to_end: { any } = {}
		for action, session in sessions do
			if not world:contains(action) or not world:contains(session) or not world:has(session, ct.session) then
				table.insert(to_end, action)
				table.insert(to_end, session)
			end
		end

		for i = 1, #to_end, 2 do
			local action = to_end[i]
			local session = to_end[i + 1]
			local session_alive = world:contains(session)
			local action_marker = if world:contains(action) then world:target(action, ct.action) else nil
			local action_table = if action_marker then registry.get_config(action_marker :: any) else nil

			local replicate = action_table and session_alive and should_replicate_session(action_table)

			if action_table and session_alive and action_table.on_end then
				action_table.on_end(state, action, session)
			end

			if replicate then
				replicator:stop_networked(session, true)
			end

			if session_alive then
				world:delete(session)
			end
			sessions[action] = nil
		end

		for action, session in sessions do
			local action_marker = world:target(action, ct.action)
			assert(action_marker, "Action marker not found")

			local action_table = registry.get_config(action_marker)
			if action_table.on_tick then
				action_table.on_tick(state, action, session)
			end
		end

		for entity, data in action_request_query do
			world:remove(entity, ct.action_request)

			local action_marker = world:target(entity, ct.action)
			assert(action_marker, "Action marker not found")

			local action_table = registry.get_config(action_marker)

			if sessions[entity] then
				continue
			end

			local is_unavailable = world:has(entity, ct.unavailable) or action_table.can_start(state, entity) == false
			local should_reject = is_unavailable and action_table.action_type == "predicted"
			local reject_player = if should_reject then world:get(entity, ct.action_player) else nil

			if reject_player then
				remotes.misprediction:FireClient(reject_player, entity)
			end

			if is_unavailable then
				continue
			end

			if action_table.action_type == "shared" or action_table.action_type == "client" then
				local player = world:get(entity, ct.action_player)
				if not player then
					continue
				end

				remotes.use_request:FireClient(player, entity, data)
				if action_table.action_type == "client" then
					continue
				end
			end

			local handler = action_table.handler
			if not handler then
				continue
			end

			local session = world:entity()
			world:add(session, ct.session)
			world:add(session, jecs.pair(jecs.ChildOf, entity))
			if data then
				world:set(session, ct.session_data, data)
			end
			sessions[entity] = session

			local replicate = should_replicate_session(action_table)
			if replicate then
				world:add(session, jecs.pair(replecs.Relation, jecs.ChildOf))
				world:set(session, replecs.Networked, world:get(entity, ct.action_player))
				replicator:set_custom(session, ct.session_custom_id)
			end

			local result = handler(state, entity, session)
			if result ~= constants.HANDLER_CONTINUE then
				if replicate then
					replicator:stop_networked(session, true)
				end
				world:delete(session)
				sessions[entity] = nil
			end
		end

		for entity, data in new_continuous_query do
			world:add(entity, processed_continuous)

			local action_marker = world:target(entity, ct.action)
			assert(action_marker, "Action marker not found")

			local action_table = registry.get_config(action_marker)
			if action_table.action_type ~= "client" then
				continue
			end

			local player = world:get(entity, ct.action_player)
			if not player then
				continue
			end

			remotes.start_continuous:FireClient(player, entity, data)
		end

		for entity in stopped_continuous_query do
			local action_marker = world:target(entity, ct.action)
			assert(action_marker, "Action marker not found")

			local action_table = registry.get_config(action_marker)
			if action_table.action_type ~= "client" then
				continue
			end

			world:remove(entity, processed_continuous)

			local player = world:get(entity, ct.action_player)
			if not player then
				continue
			end

			remotes.stop_continuous:FireClient(player, entity)
		end

		for session, data in message_query do
			world:remove(session, ct.session_message)
			local action = world:target(session, jecs.ChildOf)
			if not action then
				continue
			end
			local player = world:get(action, ct.action_player)
			if not player then
				continue
			end
			remotes.message:FireClient(player, action, data)
		end

		for session, data in message_urel_query do
			world:remove(session, ct.session_message_urel)
			local action = world:target(session, jecs.ChildOf)
			if not action then
				continue
			end
			local player = world:get(action, ct.action_player)
			if not player then
				continue
			end
			remotes.message_urel:FireClient(player, action, data)
		end
	end
end

return server_system

local Players = game:GetService("Players")

local jecs = require("./dependencies/jecs")
local types = require("./types")
local collect = require("./dependencies/jecs-utils").collect :: types.Collect
local ct = require("./components")
local constants = require("./constants")
local remotes = require("./remotes")

local function is_valid_request(
	world: types.World,
	registry: types.AnyActionRegistry,
	entity: types.Entity,
	local_player: Player
): boolean
	local action_marker = world:target(entity, ct.action)
	if not action_marker then
		return false
	end

	local action_table = registry.get_config(action_marker :: any)
	if action_table.action_type ~= "client" and action_table.action_type ~= "shared" then
		return false
	end

	return world:get(entity, ct.action_player) == local_player
end

local function client_system<T>(props: types.ClientSystemProps<T>)
	local world = props.world
	local state = props.state
	local replicator = props.replicator
	local registry = props.registry
	local cleanup = props.cleanup

	local use_requests, cleanup_use_requests = collect(remotes.use_request.OnClientEvent)
	local continuous_starts, cleanup_continuous_starts = collect(remotes.start_continuous.OnClientEvent)
	local continuous_stops, cleanup_continuous_stops = collect(remotes.stop_continuous.OnClientEvent)
	local reject_sessions, cleanup_reject_sessions = collect(remotes.reject_session.OnClientEvent)
	local end_sessions, cleanup_end_sessions = collect(remotes.end_session.OnClientEvent)
	local messages, cleanup_messages = collect(remotes.message.OnClientEvent)
	local messages_urel, cleanup_messages_urel = collect(remotes.message_urel.OnClientEvent)

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

	ct.session_custom_id:handle(function(ctx)
		local client_action = ctx.target(jecs.ChildOf)
		if not client_action then
			return nil
		end
		return sessions[client_action]
	end)

	replicator:register_custom_id(ct.session_custom_id)

	local function dispatch_incoming_message(entity: any, data: { any }?)
		local client_entity = replicator:get_client_entity(entity) :: types.Entity?
		if not client_entity then
			return
		end

		local session = sessions[client_entity]
		if not session or not world:contains(session) or not world:has(session, ct.session) then
			return
		end

		local action_marker = world:target(client_entity, ct.action)
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

		on_message(state, client_entity, session, data)
	end

	cleanup(function()
		continuous_query:fini()
		action_request_query:fini()
		new_continuous_query:fini()
		stopped_continuous_query:fini()
		message_query:fini()
		message_urel_query:fini()

		cleanup_use_requests()
		cleanup_continuous_starts()
		cleanup_continuous_stops()
		cleanup_reject_sessions()
		cleanup_end_sessions()
		cleanup_messages()
		cleanup_messages_urel()
	end)

	return function()
		local local_player = Players.LocalPlayer

		for _, entity, data in messages do
			dispatch_incoming_message(entity, data)
		end

		for _, entity, data in messages_urel do
			dispatch_incoming_message(entity, data)
		end

		for _, entity in reject_sessions do
			local client_entity = replicator:get_client_entity(entity) :: types.Entity
			if not client_entity then
				continue
			end

			local session = sessions[client_entity]
			if not session then
				continue
			end

			local session_alive = world:contains(session)
			local action_marker = world:target(client_entity, ct.action)
			local action_table = if action_marker and session_alive
				then registry.get_config(action_marker :: any)
				else nil

			if action_table and action_table.on_mispredicted then
				action_table.on_mispredicted(state, client_entity, session)
			end

			if action_table and action_table.on_end then
				action_table.on_end(state, client_entity, session)
			end

			if session_alive then
				world:delete(session)
			end
			sessions[client_entity] = nil
		end

		for _, entity in end_sessions do
			local client_entity = replicator:get_client_entity(entity) :: types.Entity
			if not client_entity then
				continue
			end

			local session = sessions[client_entity]
			if not session then
				continue
			end

			local session_alive = world:contains(session)
			local action_marker = world:target(client_entity, ct.action)
			local action_table = if action_marker and session_alive
				then registry.get_config(action_marker :: any)
				else nil

			if action_table and action_table.on_end then
				action_table.on_end(state, client_entity, session)
			end

			if session_alive then
				world:delete(session)
			end
			sessions[client_entity] = nil
		end

		for _, entity, data in use_requests do
			local client_entity = replicator:get_client_entity(entity)
			if not client_entity then
				continue
			end
			if not is_valid_request(world, registry, client_entity, local_player) then
				continue
			end
			world:set(client_entity, ct.action_request, data)
		end

		for _, entity, data in continuous_starts do
			local client_entity = replicator:get_client_entity(entity)
			if not client_entity then
				continue
			end
			if not is_valid_request(world, registry, client_entity, local_player) then
				continue
			end
			world:set(client_entity, ct.continuous_request, data)
		end

		for _, entity in continuous_stops do
			local client_entity = replicator:get_client_entity(entity)
			if not client_entity then
				continue
			end
			if not is_valid_request(world, registry, client_entity, local_player) then
				continue
			end
			world:remove(client_entity, ct.continuous_request)
		end

		for entity, data in continuous_query do
			local action_marker = world:target(entity, ct.action)
			assert(action_marker, "Action marker not found")

			local action_table = registry.get_config(action_marker)
			if action_table.action_type == "server" then
				continue
			end
			if action_table.action_type == "predicted" then
				continue
			end

			local is_unavailable = world:has(entity, ct.unavailable) or action_table.can_start(state, entity) == false
			if action_table.action_type == "client" and is_unavailable then
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

			if action_table and session_alive and action_table.on_end then
				action_table.on_end(state, action, session)
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
			local check_state = action_table.action_type == "client"
				or action_table.action_type == "predicted"
				or action_table.check_local_state

			local is_unavailable = world:has(entity, ct.unavailable) or action_table.can_start(state, entity) == false

			if check_state and is_unavailable then
				continue
			end

			if action_table.action_type == "server" or action_table.action_type == "predicted" then
				local server_entity = replicator:get_server_entity(entity)
				assert(server_entity, "Server entity not found")

				remotes.use_request:FireServer(server_entity, data)
				if action_table.action_type == "server" then
					continue
				end
			end

			if sessions[entity] then
				continue
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

			local result = handler(state, entity, session)
			if result ~= constants.HANDLER_CONTINUE then
				world:delete(session)
				sessions[entity] = nil
			end
		end

		for entity, data in new_continuous_query do
			local action_marker = world:target(entity, ct.action)
			assert(action_marker, "Action marker not found")

			local action_table = registry.get_config(action_marker)
			if action_table.action_type ~= "server" then
				continue
			end

			world:add(entity, processed_continuous)

			local server_entity = replicator:get_server_entity(entity)
			if not server_entity then
				continue
			end

			remotes.start_continuous:FireServer(server_entity, data)
		end

		for entity in stopped_continuous_query do
			local action_marker = world:target(entity, ct.action)
			assert(action_marker, "Action marker not found")

			local action_table = registry.get_config(action_marker)
			if action_table.action_type ~= "server" then
				continue
			end

			world:remove(entity, processed_continuous)

			local server_entity = replicator:get_server_entity(entity)
			if not server_entity then
				continue
			end

			remotes.stop_continuous:FireServer(server_entity)
		end

		for session, data in message_query do
			world:remove(session, ct.session_message)
			local action = world:target(session, jecs.ChildOf)
			if not action then
				continue
			end
			local server_entity = replicator:get_server_entity(action)
			if not server_entity then
				continue
			end
			remotes.message:FireServer(server_entity, data)
		end

		for session, data in message_urel_query do
			world:remove(session, ct.session_message_urel)
			local action = world:target(session, jecs.ChildOf)
			if not action then
				continue
			end
			local server_entity = replicator:get_server_entity(action)
			if not server_entity then
				continue
			end
			remotes.message_urel:FireServer(server_entity, data)
		end
	end
end

return client_system

local Players = game:GetService("Players")

local jecs = require("./dependencies/jecs")
local collect = require("./dependencies/jecs-utils").collect :: types.Collect
local ct = require("./components")
local types = require("./types")

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
	local remotes = props.remotes
	local cleanup = props.cleanup

	local use_requests, cleanup_use_requests = collect(remotes.use_request.OnClientEvent)
	local continuous_starts, cleanup_continuous_starts = collect(remotes.start_continuous.OnClientEvent)
	local continuous_stops, cleanup_continuous_stops = collect(remotes.stop_continuous.OnClientEvent)

	local action_wildcard = jecs.pair(ct.action, jecs.Wildcard)
	local processed_continuous = jecs.pair(ct.processed, ct.continuous_request)

	local continuous_query = world:query(ct.continuous_request):with(action_wildcard):cached()
	local action_request_query = world:query(ct.action_request):with(action_wildcard):cached()
	local new_continuous_query =
		world:query(ct.continuous_request):with(action_wildcard):without(processed_continuous):cached()
	local stopped_continuous_query =
		world:query(action_wildcard):with(processed_continuous):without(ct.continuous_request):cached()

	cleanup(function()
		continuous_query:fini()
		action_request_query:fini()
		new_continuous_query:fini()
		stopped_continuous_query:fini()

		cleanup_use_requests()
		cleanup_continuous_starts()
		cleanup_continuous_stops()
	end)

	return function()
		local local_player = Players.LocalPlayer

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

			local handler = action_table.handler
			if handler then
				handler(state, entity, data)
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
	end
end

return client_system

local jecs = require("./dependencies/jecs")
local replecs = require("./dependencies/replecs")
local types = require("./types")

local function always_true()
	return true
end

local DEFAULT_CONFIG: types.ActionTable<any> = {
	action_type = "server",
	check_local_state = false,
	can_start = always_true,
}

local function create_action_registry<T>(custom_defaults: types.PartialTableConfig<T>?): types.ActionRegistry<T>
	local defaults = table.clone(DEFAULT_CONFIG) :: any
	if custom_defaults then
		for key, value in custom_defaults :: any do
			defaults[key] = value
		end
	end

	local registry: { [types.Entity<unknown>]: types.ActionTable<T> } = {}
	local registered_names: { [string]: boolean } = {}

	local function marker(name: string, config: types.PartialTableConfig<T>): types.Entity<unknown>
		assert(not registered_names[name], `Action {name} already registered`)
		registered_names[name] = true

		local id = jecs.tag() :: types.Entity<unknown>
		jecs.meta(id, jecs.Name, name)
		jecs.meta(id, replecs.Shared)

		local merged = table.clone(defaults)
		for key, value in config :: any do
			merged[key] = value
		end

		registry[id] = merged
		return id
	end

	local function get_config(id: types.Entity<unknown>): any
		local config = registry[id]
		assert(config ~= nil, "Action config not found")
		return config
	end

	local function set<K>(
		id: types.Entity<unknown>,
		name: K & keyof<types.EnvironmentSpecific<T>>,
		value: index<types.EnvironmentSpecific<T>, K>
	)
		local config = registry[id] :: any
		assert(config ~= nil, "Action config not found")

		config[name] = value
	end

	return table.freeze({
		marker = marker,
		get_config = get_config,
		set = set,
	}) :: types.ActionRegistry<T>
end

return create_action_registry

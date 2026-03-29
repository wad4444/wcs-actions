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
	local defaults = table.clone(DEFAULT_CONFIG)
	if custom_defaults then
		for key, value in custom_defaults do
			defaults[key] = value
		end
	end

	local registry: { [jecs.Entity<unknown>]: types.ActionTable<T> } = {}
	local registered_names: { [string]: boolean } = {}

	local function marker(name: string, config: types.PartialTableConfig<T>): jecs.Entity<unknown>
		assert(not registered_names[name], `Action {name} already registered`)
		registered_names[name] = true

		local id = jecs.tag() :: jecs.Entity<unknown>
		jecs.meta(id, jecs.Name, name)
		jecs.meta(id, replecs.Shared)

		local merged = table.clone(defaults)
		for key, value in config do
			merged[key] = value
		end

		registry[id] = merged
		return id
	end

	local function get_config(id: jecs.Entity<unknown>): any
		local config = registry[id]
		assert(config ~= nil, "Action config not found")
		return config
	end

	local function set<K>(
		id: jecs.Entity<unknown>,
		name: K & keyof<types.EnvironmentSpecific<T>>,
		value: index<types.EnvironmentSpecific<T>, K>
	)
		local config = registry[id]
		assert(config ~= nil, "Action config not found")

		config[name] = value
	end

	return table.freeze({
		marker = marker,
		get_config = get_config,
		set = set,
	})
end

return create_action_registry

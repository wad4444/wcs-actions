local types = require("@self/types")
local components = require("@self/components")
local create_action_registry = require("@self/action-registry")
local server_system = require("@self/server-system")
local client_system = require("@self/client-system")

export type ActionType = types.ActionType
export type ActionHandler<T> = types.ActionHandler<T>
export type ActionInitializer<T> = types.ActionInitializer<T>
export type ActionReplicator<T> = types.ActionReplicator<T>
export type ActionTable<T> = types.ActionTable<T>
export type ActionRegistry<T> = types.ActionRegistry<T>
export type ServerEventLike<T...> = types.ServerEventLike<T...>
export type ClientEventLike<T...> = types.ClientEventLike<T...>
export type ServerSystemProps = types.ServerSystemProps
export type ClientSystemProps = types.ClientSystemProps

local returns = {
	components = components,
	create_action_registry = create_action_registry,
	server_system = server_system,
	client_system = client_system,
}
returns.default = returns

return table.freeze(returns)

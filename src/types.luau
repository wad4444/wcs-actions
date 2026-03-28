export type Entity<T = unknown> = typeof((function()
	local jecs = require(script.Parent.Parent.jecs)
	return (nil :: any) :: jecs.Entity<T>
end)())

export type World = typeof((function()
	local jecs = require(script.Parent.Parent.jecs)
	return (nil :: any) :: jecs.World
end)())

export type ReplecsServer = typeof((function()
	local replecs = require(script.Parent.Parent.replecs)
	return (nil :: any) :: replecs.Server
end)())

export type ReplecsClient = typeof((function()
	local replecs = require(script.Parent.Parent.replecs)
	return (nil :: any) :: replecs.Client
end)())

export type Collect = <T...>(event: RBXScriptSignal<T...>) -> (() -> (number, T...), () -> ())

export type ActionType = "server" | "predicted" | "client" | "shared"

export type ActionHandler<T> = (state: T, entity: Entity, data: { any }?) -> ()
export type ActionInitializer<T> = (state: T, entity: Entity) -> ()
export type ActionReplicator<T> = (state: T, entity: Entity, player: Player) -> ()

export type TableConfig<T> = {
	action_type: ActionType,
	check_local_state: boolean,
	can_start: (state: T, entity: Entity) -> boolean,
}

export type EnvironmentSpecific<T> = {
	handler: ActionHandler<T>?,
	initialize: ActionInitializer<T>?,
	replicate: ActionReplicator<T>?,
}

export type ActionTable<T> = {
	action_type: ActionType,
	check_local_state: boolean,
	can_start: (state: T, entity: Entity) -> boolean,
	handler: ActionHandler<T>?,
	initialize: ActionInitializer<T>?,
	replicate: ActionReplicator<T>?,
}

export type function PartialTable(table: type)
	local result = types.newtable()
	for key, value in table:properties() do
		local read = value.read
		local write = value.write
		if read then
			result:setreadproperty(key, types.optional(read))
		end
		if write then
			result:setwriteproperty(key, types.optional(write))
		end
	end
	return result
end

export type PartialTableConfig<T> = {
	action_type: ActionType?,
	check_local_state: boolean?,
	can_start: ((state: T, entity: Entity) -> boolean)?,
}

export type AnyActionRegistry = ActionRegistry<any>

export type ActionRegistry<T> = {
	marker: (name: string, config: PartialTableConfig<T>) -> Entity,
	get_config: (marker: Entity<unknown>) -> ActionTable<T>,
	set: <K>(
		marker: Entity,
		name: K & keyof<EnvironmentSpecific<T>>,
		value: index<EnvironmentSpecific<T>, K>
	) -> (),
}

export type ServerEventLike<T...> = {
	OnServerEvent: RBXScriptSignal<(Player, T...)>,
	FireClient: (self: ServerEventLike<T...>, player: Player, T...) -> (),
}

export type ClientEventLike<T...> = {
	OnClientEvent: RBXScriptSignal<T...>,
	FireServer: (self: ClientEventLike<T...>, T...) -> (),
}

export type ServerSystemProps<T> = {
	world: World,
	replicator: ReplecsServer,
	state: T,
	registry: ActionRegistry<T>,
	cleanup: (...any) -> (),
	remotes: {
		use_request: ServerEventLike<Entity, { any }?>,
		start_continuous: ServerEventLike<Entity, { any }?>,
		stop_continuous: ServerEventLike<Entity>,
	},
}

export type ClientSystemProps<T> = {
	world: World,
	replicator: ReplecsClient,
	state: T,
	registry: ActionRegistry<T>,
	cleanup: (...any) -> (),
	remotes: {
		use_request: ClientEventLike<number, { any }?>,
		start_continuous: ClientEventLike<number, { any }?>,
		stop_continuous: ClientEventLike<number>,
	},
}

return {}

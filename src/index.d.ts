import type { Entity, Tag, World } from "@rbxts/jecs";
import type Replecs from "@rbxts/replecs";

export type ActionType = "server" | "predicted" | "client" | "shared";

export type HandlerContinue = { readonly _nominal_HandlerContinue: unique symbol };
export type ActionHandler<T> = (state: T, action: Entity, session: Entity, data?: defined[]) => HandlerContinue | void;
export type ActionTickHandler<T> = (state: T, action: Entity, session: Entity) => void;
export type ActionEndHandler<T> = (state: T, action: Entity, session: Entity) => void;
export type ActionMispredictedHandler<T> = (state: T, action: Entity, session: Entity) => void;
export type ActionInitializer<T> = (state: T, action: Entity) => void;
export type ActionReplicator<T> = (state: T, action: Entity, player: Player) => void;

export interface TableConfig<T> {
	action_type: ActionType;
	check_local_state: boolean;
	can_start: (state: T, action: Entity) => boolean;
}

export interface EnvironmentSpecific<T> {
	handler?: ActionHandler<T>;
	initialize?: ActionInitializer<T>;
	replicate?: ActionReplicator<T>;
	on_tick?: ActionTickHandler<T>;
	on_end?: ActionEndHandler<T>;
	on_mispredicted?: ActionMispredictedHandler<T>;
}

export type ActionTable<T> = TableConfig<T> & EnvironmentSpecific<T>;

export interface ActionRegistry<T> {
	marker: (name: string, config?: Partial<TableConfig<T>>) => Entity;
	get_config: (marker: Entity) => ActionTable<T>;
	set: <K extends keyof EnvironmentSpecific<T>>(
		marker: Entity,
		name: K,
		value: EnvironmentSpecific<T>[K],
	) => void;
}

export interface ServerEventLike<T extends unknown[]> {
	readonly OnServerEvent: RBXScriptSignal<(player: Player, ...args: T) => void>;
	FireClient(this: ServerEventLike<T>, player: Player, ...args: T): void;
}

export interface ClientEventLike<T extends unknown[]> {
	readonly OnClientEvent: RBXScriptSignal<(...args: T) => void>;
	FireServer(this: ClientEventLike<T>, ...args: T): void;
}

export interface ServerSystemProps<T> {
	world: World;
	replicator: Replecs.Server;
	state: T;
	registry: ActionRegistry<T>;
	cleanup: (...args: any[]) => any;
	remotes: {
		use_request: ServerEventLike<[entity: Entity, data?: defined[]]>;
		start_continuous: ServerEventLike<[entity: Entity, data?: defined[]]>;
		stop_continuous: ServerEventLike<[entity: Entity]>;
		reject_session: ServerEventLike<[entity: Entity]>;
		end_session: ServerEventLike<[entity: Entity]>;
	};
}

export interface ClientSystemProps<T> {
	world: World;
	replicator: Replecs.Client;
	state: T;
	registry: ActionRegistry<T>;
	cleanup: (...args: any[]) => void;
	remotes: {
		use_request: ClientEventLike<[entity: number, data?: defined[]]>;
		start_continuous: ClientEventLike<[entity: number, data?: defined[]]>;
		stop_continuous: ClientEventLike<[entity: number]>;
		reject_session: ClientEventLike<[entity: number]>;
		end_session: ClientEventLike<[entity: number]>;
	};
}

export interface Components {
	action: Tag;
	action_player: Entity<Player>;
	unavailable: Tag;
	action_request: Entity<defined[] | undefined>;
	continuous_request: Entity<defined[] | undefined>;
	processed: Tag;
	session: Tag;
	session_custom_id: Replecs.CustomId;
}

declare const WCSActions: {
	components: Components;
	HANDLER_CONTINUE: HandlerContinue;
	create_action_registry: <T>(custom_defaults?: Partial<TableConfig<T>>) => ActionRegistry<T>;
	server_system: <T>(props: ServerSystemProps<T>) => () => void;
	client_system: <T>(props: ClientSystemProps<T>) => () => void;
};

export default WCSActions;

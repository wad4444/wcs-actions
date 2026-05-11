import type { Entity, Tag, World } from "@rbxts/jecs";
import type Replecs from "@rbxts/replecs";

export type ActionType = "server" | "predicted" | "client" | "shared";

export type HandlerContinue = { readonly _nominal_HandlerContinue: unique symbol };
export type ActionHandler<T> = (state: T, action: Entity, session: Entity) => HandlerContinue | void;
export type ActionTickHandler<T> = (state: T, action: Entity, session: Entity) => void;
export type ActionEndHandler<T> = (state: T, action: Entity, session: Entity) => void;
export type ActionMispredictedHandler<T> = (state: T, action: Entity, session: Entity) => void;
export type ActionInitializer<T> = (state: T, action: Entity) => void;
export type ActionReplicator<T> = (state: T, action: Entity, player: Player) => void;
export type ActionMessageHandler<T> = (state: T, action: Entity, session: Entity, data: defined[] | undefined) => void;

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
	on_message?: ActionMessageHandler<T>;
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
}

export interface ClientSystemProps<T> {
	world: World;
	replicator: Replecs.Client;
	state: T;
	registry: ActionRegistry<T>;
	cleanup: (...args: any[]) => void;
}

export interface Components {
	action: Tag;
	action_player: Entity<Player>;
	unavailable: Tag;
	action_request: Entity<defined[] | undefined>;
	continuous_request: Entity<defined[] | undefined>;
	processed: Tag;
	session: Tag;
	session_data: Entity<defined[]>;
	session_message: Entity<defined[]>;
	session_message_urel: Entity<defined[]>;
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

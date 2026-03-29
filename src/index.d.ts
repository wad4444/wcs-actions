import type { Entity, Tag, World } from "@rbxts/jecs";
import type Replecs from "@rbxts/replecs";

export type ActionType = "server" | "predicted" | "client" | "shared";

export type ActionHandler<T> = (state: T, entity: Entity, data?: defined[]) => void;
export type ActionInitializer<T> = (state: T, entity: Entity) => void;
export type ActionReplicator<T> = (state: T, entity: Entity, player: Player) => void;

export interface TableConfig<T> {
	action_type: ActionType;
	check_local_state: boolean;
	can_start: (state: T, entity: Entity) => boolean;
}

export interface EnvironmentSpecific<T> {
	handler?: ActionHandler<T>;
	initialize?: ActionInitializer<T>;
	replicate?: ActionReplicator<T>;
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
	};
}

export interface Components {
	action: Tag;
	action_player: Entity<Player>;
	unavailable: Tag;
	action_request: Entity<defined[] | undefined>;
	continuous_request: Entity<defined[] | undefined>;
	processed: Tag;
}

declare const WCSActions: {
	components: Components;
	create_action_registry: <T>(custom_defaults?: Partial<TableConfig<T>>) => ActionRegistry<T>;
	server_system: <T>(props: ServerSystemProps<T>) => () => void;
	client_system: <T>(props: ClientSystemProps<T>) => () => void;
};

export default WCSActions;

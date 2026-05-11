local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "wcs_actions_remotes"

local is_server = RunService:IsServer()

local folder: Instance
if is_server then
	local new_folder = Instance.new("Folder")
	new_folder.Name = FOLDER_NAME
	new_folder.Parent = ReplicatedStorage
	folder = new_folder
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function create<T>(name: string, class_name: T & string): RemoteEvent
	if is_server then
		local remote = Instance.new(class_name)
		remote.Name = name
		remote.Parent = folder
		return remote :: RemoteEvent
	else
		return folder:WaitForChild(name) :: RemoteEvent
	end
end

return table.freeze({
	use_request = create("use_request", "RemoteEvent"),
	start_continuous = create("start_continuous", "RemoteEvent"),
	stop_continuous = create("stop_continuous", "RemoteEvent"),
	reject_session = create("reject_session", "RemoteEvent"),
	end_session = create("end_session", "RemoteEvent"),
	message = create("message", "RemoteEvent"),
	message_urel = create("message_urel", "UnreliableRemoteEvent"),
})

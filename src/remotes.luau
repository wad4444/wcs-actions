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

local function create_reliable(name: string): RemoteEvent
	if is_server then
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	else
		return folder:WaitForChild(name) :: RemoteEvent
	end
end

local function create_unreliable(name: string): UnreliableRemoteEvent
	if is_server then
		local remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	else
		return folder:WaitForChild(name) :: UnreliableRemoteEvent
	end
end

return table.freeze({
	use_request = create_reliable("use_request"),
	start_continuous = create_reliable("start_continuous"),
	stop_continuous = create_reliable("stop_continuous"),
	misprediction = create_reliable("misprediction"),
	end_session = create_reliable("end_session"),
	message = create_reliable("message"),
	message_urel = create_unreliable("message_urel"),
})

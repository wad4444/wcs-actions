--!nonstrict
local package_module = script.Parent.Parent

if package_module.Parent:FindFirstChild("replecs") and package_module.Parent.replecs:IsA("ModuleScript") then
	return require(package_module.Parent.replecs)
else
	return require(package_module.Parent.replecs.out.replecs)
end

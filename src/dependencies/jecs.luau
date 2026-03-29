--!nonstrict
local package_module = script.Parent.Parent

if package_module.Parent:FindFirstChild("jecs") and package_module.Parent.jecs:IsA("ModuleScript") then
	return require(package_module.Parent.jecs)
else
	return require(package_module.Parent.jecs.src.jecs)
end

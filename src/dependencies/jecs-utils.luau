--!nonstrict
local package_module = script.Parent.Parent

if package_module.Parent:FindFirstChild("jecs-utils") then
	return require(package_module.Parent["jecs-utils"])
else
	return require(package_module.Parent["jecs-utils"].src["jecs-utils"])
end

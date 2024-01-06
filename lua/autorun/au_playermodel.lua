local amongUsModels = {
	["Among Us Crewmate"] = "models/amongus/player/player.mdl",
	["Among Us Corpse"] = "models/amongus/player/corpse.mdl",
}

for modelName, modelPath in pairs(amongUsModels) do
	player_manager.AddValidModel(modelName, modelPath)
	list.Set("PlayerOptionsModel", modelName, modelPath)
end

if SERVER then
	hook.Add("PlayerSpawn", "AmongUsPlayermodelViewHeight", function(ply)
		timer.Simple(1, function()
			if not IsValid(ply) then return end

			for _, model in pairs(amongUsModels) do
				if ply:GetModel() == model then
					ply:SetViewOffset(Vector(0, 0, 48))
					break
				else
					ply:SetViewOffset(Vector(0, 0, 64))
				end
			end
		end)
	end)
end
local MODELS_TO_REGISTER = {
	["Among Us Crewmate"] = "models/amongus/player/player.mdl",
	["Among Us Corpse"] = "models/amongus/player/corpse.mdl",
}
local PLAYER_VIEW_HEIGHT = 48

for k, v in pairs(MODELS_TO_REGISTER) do
	player_manager.AddValidModel(k, v)
	list.Set( "PlayerOptionsModel", k, v)
end

if SERVER then
	hook.Add('PlayerSpawn', 'AU playermodel view height', function (ply)
		if not IsValid(ply) then return end

		timer.Simple(1, function ()
			for _, v in pairs(MODELS_TO_REGISTER) do
				if ply:GetModel() == v then
					ply:SetViewOffset(Vector(0, 0, PLAYER_VIEW_HEIGHT))
					break
				else
					ply:SetViewOffset(Vector(0, 0, 64))
				end
			end
		end)
	end)
end
